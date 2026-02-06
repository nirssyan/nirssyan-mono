import type { Metadata } from 'next'
import { MarketplaceCatalog } from '@/components/marketplace/marketplace-catalog'
import { MarketplaceFeed } from '@/types/marketplace'

export const metadata: Metadata = {
  title: 'Маркетплейс лент | infatium',
  description:
    'Публичная витрина готовых лент infatium. Выбирайте тематические потоки и открывайте их в приложении.',
  alternates: {
    canonical: '/marketplace',
  },
  openGraph: {
    title: 'Маркетплейс лент | infatium',
    description:
      'Публичная витрина готовых лент infatium. Подберите формат SINGLE_POST или DIGEST под свои интересы.',
    url: 'https://infatium.ru/marketplace',
    siteName: 'infatium',
    type: 'website',
    locale: 'ru_RU',
  },
}

interface MarketplaceResponse {
  data?: unknown
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function normalizeFeed(raw: unknown): MarketplaceFeed | null {
  if (!isObject(raw)) {
    return null
  }

  const id = typeof raw.id === 'string' ? raw.id : null
  const name = typeof raw.name === 'string' ? raw.name : null
  const type = typeof raw.type === 'string' ? raw.type : null
  const description = typeof raw.description === 'string' ? raw.description : null
  const tags = Array.isArray(raw.tags)
    ? raw.tags.filter((item): item is string => typeof item === 'string')
    : []

  if (!id || !name || !type) {
    return null
  }

  return {
    id,
    name,
    type,
    description,
    tags,
  }
}

async function getMarketplaceFeeds(): Promise<{
  feeds: MarketplaceFeed[]
  hasError: boolean
}> {
  try {
    const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL
    if (!baseUrl) {
      console.error('NEXT_PUBLIC_API_BASE_URL is not configured for marketplace page')
      return { feeds: [], hasError: true }
    }

    const headers: HeadersInit = {}
    if (process.env.API_KEY) {
      headers['X-API-Key'] = process.env.API_KEY
    }

    const response = await fetch(`${baseUrl}/marketplace?limit=100&offset=0`, {
      headers,
      next: { revalidate: 300 },
    })

    if (!response.ok) {
      return { feeds: [], hasError: true }
    }

    const payload = (await response.json()) as MarketplaceResponse | unknown

    const rawData = Array.isArray(payload)
      ? payload
      : isObject(payload) && Array.isArray(payload.data)
        ? payload.data
        : []

    const feeds = rawData
      .map((item) => normalizeFeed(item))
      .filter((item): item is MarketplaceFeed => item !== null)

    return { feeds, hasError: false }
  } catch (error) {
    console.error('Failed to load marketplace feeds', error)
    return { feeds: [], hasError: true }
  }
}

export default async function MarketplacePage() {
  const { feeds, hasError } = await getMarketplaceFeeds()

  return (
    <main className="relative min-h-screen bg-black text-white">
      <div className="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_15%_20%,rgba(255,255,255,0.08),transparent_40%),radial-gradient(circle_at_80%_0%,rgba(56,189,248,0.14),transparent_38%),linear-gradient(to_bottom,#020617,#000000_40%,#020617)]" />

      <div className="mx-auto max-w-7xl px-4 pb-16 pt-8 sm:px-6 sm:pb-24 sm:pt-10 lg:px-8">
        <MarketplaceCatalog initialFeeds={feeds} hasError={hasError} />
      </div>
    </main>
  )
}

