export interface MarketplaceFeedSource {
  name: string
  url: string
  type: 'telegram' | 'rss' | 'web'
}

export interface MarketplaceFeed {
  id: string
  slug: string
  name: string
  type: 'SINGLE_POST' | 'DIGEST' | string
  description?: string | null
  tags: string[]
  sources?: MarketplaceFeedSource[]
  story?: string | null
  created_at?: string
}

export type MarketplaceFeedTypeFilter = 'ALL' | 'SINGLE_POST' | 'DIGEST'
