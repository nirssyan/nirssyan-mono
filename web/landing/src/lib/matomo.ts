export interface MatomoConfig {
  url: string
  siteId: string
  enabled: boolean
}

export const matomoConfig: MatomoConfig = {
  url: process.env.NEXT_PUBLIC_MATOMO_URL || '',
  siteId: process.env.NEXT_PUBLIC_MATOMO_SITE_ID || '',
  enabled: Boolean(
    process.env.NEXT_PUBLIC_MATOMO_URL &&
    process.env.NEXT_PUBLIC_MATOMO_SITE_ID &&
    process.env.NEXT_PUBLIC_ENABLE_ANALYTICS === 'true'
  ),
}

let isInitialized = false

function getPaq(): typeof window._paq | null {
  if (typeof window === 'undefined') return null
  window._paq = window._paq || []
  return window._paq
}

export function initMatomo() {
  if (typeof window === 'undefined' || isInitialized || !matomoConfig.enabled) {
    return
  }

  const _paq = getPaq()
  if (!_paq) return

  _paq.push(['enableLinkTracking'])
  _paq.push(['trackPageView'])

  isInitialized = true
}

export function trackPageView(url?: string) {
  const _paq = getPaq()
  if (!_paq) return

  if (url) {
    _paq.push(['setCustomUrl', url])
  }
  _paq.push(['trackPageView'])
}

export function trackEvent(
  category: string,
  action: string,
  name?: string,
  value?: number
) {
  const _paq = getPaq()
  if (!_paq) return

  if (name !== undefined && value !== undefined) {
    _paq.push(['trackEvent', category, action, name, value])
  } else if (name !== undefined) {
    _paq.push(['trackEvent', category, action, name])
  } else {
    _paq.push(['trackEvent', category, action])
  }
}

export function setUserId(userId: string) {
  const _paq = getPaq()
  if (!_paq) return
  _paq.push(['setUserId', userId])
}

export function resetUserId() {
  const _paq = getPaq()
  if (!_paq) return
  _paq.push(['resetUserId'])
}

export function isMatomoEnabled(): boolean {
  return matomoConfig.enabled
}
