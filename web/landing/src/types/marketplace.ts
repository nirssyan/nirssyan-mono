export interface MarketplaceFeedSource {
  name: string
  url: string
  type: 'telegram' | 'rss' | 'web'
}

export interface MarketplaceFeed {
  id: string
  name: string
  type: 'SINGLE_POST' | 'DIGEST' | string
  description?: string | null
  tags: string[]
  sources?: MarketplaceFeedSource[]
  viewCount?: number
  story?: string
  initialVotes?: number
}

export type MarketplaceFeedTypeFilter = 'ALL' | 'SINGLE_POST' | 'DIGEST'
