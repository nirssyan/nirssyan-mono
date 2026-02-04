'use client'

import { useCallback } from 'react'
import { trackEvent, setUserId, resetUserId } from '@/lib/matomo'

export interface CTAClickEvent {
  button_text: string
  section: string
  destination: string
}

export interface SectionViewEvent {
  section: string
  time_to_view?: number
}

export interface ExternalLinkEvent {
  link_text: string
  destination: string
  section: string
}

export interface NewsletterEvent {
  email_domain: string
  source: string
}

export function useMatomo() {
  const trackCTAClick = useCallback((data: CTAClickEvent) => {
    trackEvent('CTA', 'click', `${data.section}:${data.button_text}`)
  }, [])

  const trackSectionView = useCallback((data: SectionViewEvent) => {
    trackEvent('Section', 'view', data.section, data.time_to_view)
  }, [])

  const trackExternalLink = useCallback((data: ExternalLinkEvent) => {
    trackEvent('External Link', 'click', `${data.section}:${data.link_text}`)
  }, [])

  const trackNewsletter = useCallback((email: string, source: string) => {
    const emailDomain = email.split('@')[1] || 'unknown'
    trackEvent('Newsletter', 'subscribe', `${source}:${emailDomain}`)
  }, [])

  const trackCustomEvent = useCallback(
    (eventName: string, properties?: Record<string, unknown>) => {
      const name = properties ? JSON.stringify(properties) : undefined
      trackEvent('Custom', eventName, name)
    },
    []
  )

  const identifyUser = useCallback((userId: string) => {
    setUserId(userId)
  }, [])

  const resetUser = useCallback(() => {
    resetUserId()
  }, [])

  return {
    trackCTAClick,
    trackSectionView,
    trackExternalLink,
    trackNewsletter,
    trackCustomEvent,
    identifyUser,
    resetUser,
  }
}
