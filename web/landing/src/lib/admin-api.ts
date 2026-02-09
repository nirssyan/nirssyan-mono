const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL

function authHeaders(): HeadersInit {
  const token = typeof window !== 'undefined' ? sessionStorage.getItem('admin_token') : null
  return {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  }
}

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: { ...authHeaders(), ...options?.headers },
  })

  if (res.status === 401) {
    if (typeof window !== 'undefined') {
      sessionStorage.removeItem('admin_token')
      window.location.href = '/admin/login'
    }
    throw new Error('Unauthorized')
  }

  if (res.status === 204) return undefined as T

  if (!res.ok) {
    const text = await res.text()
    throw new Error(text || `Request failed: ${res.status}`)
  }

  return res.json()
}

// Auth

export async function verifyAdmin(): Promise<boolean> {
  try {
    await request<{ admin: boolean }>('/admin/me')
    return true
  } catch {
    return false
  }
}

// Suggestions

export interface SuggestionName {
  en: string
  ru: string
}

export interface Suggestion {
  id: string
  name: SuggestionName
  type: string
  source_type?: string | null
}

export function listSuggestions(type?: string): Promise<Suggestion[]> {
  const params = type ? `?type=${type}` : ''
  return request(`/admin/suggestions${params}`)
}

export function createSuggestion(data: {
  type: string
  name: SuggestionName
  source_type?: string
}): Promise<Suggestion> {
  return request('/admin/suggestions', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export function updateSuggestion(
  id: string,
  data: { name?: SuggestionName; source_type?: string }
): Promise<Suggestion> {
  return request(`/admin/suggestions/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export function deleteSuggestion(id: string): Promise<void> {
  return request(`/admin/suggestions/${id}`, { method: 'DELETE' })
}

// Tags

export interface Tag {
  id: string
  name: string
  slug: string
}

export function listTags(): Promise<Tag[]> {
  return request('/admin/tags')
}

export function createTag(data: { name: string; slug: string }): Promise<Tag> {
  return request('/admin/tags', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export function updateTag(id: string, data: { name?: string; slug?: string }): Promise<Tag> {
  return request(`/admin/tags/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export function deleteTag(id: string): Promise<void> {
  return request(`/admin/tags/${id}`, { method: 'DELETE' })
}

// Marketplace

export interface MarketplaceFeedSource {
  name: string
  url: string
  type: string
}

export interface MarketplaceFeed {
  id: string
  slug: string
  name: string
  type: string
  description?: string | null
  tags: string[]
  sources: MarketplaceFeedSource[]
  story?: string | null
  created_at: string
}

export function listMarketplaceFeeds(): Promise<MarketplaceFeed[]> {
  return request('/admin/marketplace')
}

export function getMarketplaceFeed(id: string): Promise<MarketplaceFeed> {
  return request(`/admin/marketplace/${id}`)
}

export function createMarketplaceFeed(data: {
  name: string
  feed_type: string
  description?: string
  tags?: string[]
  sources?: MarketplaceFeedSource[]
  story?: string
}): Promise<MarketplaceFeed> {
  return request('/admin/marketplace', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export function updateMarketplaceFeed(
  id: string,
  data: {
    name?: string
    feed_type?: string
    description?: string
    tags?: string[]
    sources?: MarketplaceFeedSource[]
    story?: string
  }
): Promise<MarketplaceFeed> {
  return request(`/admin/marketplace/${id}`, {
    method: 'PUT',
    body: JSON.stringify(data),
  })
}

export function deleteMarketplaceFeed(id: string): Promise<void> {
  return request(`/admin/marketplace/${id}`, { method: 'DELETE' })
}
