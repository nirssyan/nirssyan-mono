import { MarketplaceFeed } from '@/types/marketplace'

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL

export async function getMarketplaceFeeds(): Promise<MarketplaceFeed[]> {
  const res = await fetch(`${API_BASE}/marketplace?limit=50`, {
    next: { revalidate: 300 },
  })
  if (!res.ok) return []
  const json = await res.json()
  return json.data ?? []
}

export async function getMarketplaceFeedBySlug(slug: string): Promise<MarketplaceFeed | null> {
  const res = await fetch(`${API_BASE}/marketplace/${slug}`, {
    next: { revalidate: 300 },
  })
  if (!res.ok) return null
  return res.json()
}
