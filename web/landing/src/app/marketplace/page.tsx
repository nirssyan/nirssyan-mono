import type { Metadata } from 'next'
import { MarketplaceCatalog } from '@/components/marketplace/marketplace-catalog'
import { getMarketplaceFeeds } from '@/lib/marketplace-api'
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

export default async function MarketplacePage() {
  let feeds: MarketplaceFeed[] = []
  let hasError = false
  try {
    feeds = await getMarketplaceFeeds()
  } catch {
    hasError = true
  }

  return (
    <main className="relative min-h-screen bg-black text-white">
      <div className="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_15%_20%,rgba(255,255,255,0.08),transparent_40%),radial-gradient(circle_at_80%_0%,rgba(56,189,248,0.14),transparent_38%),linear-gradient(to_bottom,#020617,#000000_40%,#020617)]" />

      <div className="mx-auto max-w-7xl px-4 pb-16 pt-8 sm:px-6 sm:pb-24 sm:pt-10 lg:px-8">
        <MarketplaceCatalog initialFeeds={feeds} hasError={hasError} />
      </div>
    </main>
  )
}
