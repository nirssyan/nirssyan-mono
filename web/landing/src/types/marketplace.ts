export interface MarketplaceFeed {
  id: string
  name: string
  type: 'SINGLE_POST' | 'DIGEST' | string
  description?: string | null
  tags: string[]
}

export type MarketplaceFeedTypeFilter = 'ALL' | 'SINGLE_POST' | 'DIGEST'
