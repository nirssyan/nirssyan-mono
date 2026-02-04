'use client'

import { useEffect, useState, useCallback, Suspense } from 'react'
import { usePathname, useSearchParams } from 'next/navigation'
import { yandexMetrikaConfig, hit } from '@/lib/yandex-metrika'
import { getConsentStatus, type ConsentStatus } from '@/components/ui/cookie-consent'

function YandexMetrikaTracker() {
  const pathname = usePathname()
  const searchParams = useSearchParams()

  useEffect(() => {
    const url = pathname + (searchParams?.toString() ? `?${searchParams.toString()}` : '')
    hit(url)
  }, [pathname, searchParams])

  return null
}

function loadYandexMetrika(metrikaId: string) {
  if (typeof window === 'undefined') return
  if (window.ym) return

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  ;(window as any).ym = function(...args: unknown[]) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const ymFunc = (window as any).ym
    ymFunc.a = ymFunc.a || []
    ymFunc.a.push(args)
  }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  ;(window as any).ym.l = Date.now()

  const script = document.createElement('script')
  script.async = true
  script.src = 'https://mc.yandex.ru/metrika/tag.js'

  script.onload = () => {
    if (window.ym) {
      window.ym(Number(metrikaId), 'init', {
        clickmap: true,
        trackLinks: true,
        accurateTrackBounce: true,
        webvisor: true,
        ecommerce: 'dataLayer'
      })
    }
  }

  const firstScript = document.getElementsByTagName('script')[0]
  if (firstScript?.parentNode) {
    firstScript.parentNode.insertBefore(script, firstScript)
  } else {
    document.head.appendChild(script)
  }
}

export function YandexMetrikaProvider({ children }: { children: React.ReactNode }) {
  const [consent, setConsent] = useState<ConsentStatus>('pending')
  const [isLoaded, setIsLoaded] = useState(false)

  const checkConsent = useCallback(() => {
    const status = getConsentStatus()
    setConsent(status)
    return status
  }, [])

  useEffect(() => {
    checkConsent()

    const handleConsentChange = (event: CustomEvent<ConsentStatus>) => {
      setConsent(event.detail)
    }

    window.addEventListener('cookie-consent-change', handleConsentChange as EventListener)
    return () => {
      window.removeEventListener('cookie-consent-change', handleConsentChange as EventListener)
    }
  }, [checkConsent])

  useEffect(() => {
    if (!yandexMetrikaConfig.enabled) return
    if (consent !== 'accepted') return
    if (isLoaded) return

    loadYandexMetrika(yandexMetrikaConfig.id)
    setIsLoaded(true)
  }, [consent, isLoaded])

  if (!yandexMetrikaConfig.enabled) {
    return <>{children}</>
  }

  return (
    <>
      {consent === 'accepted' && isLoaded && (
        <Suspense fallback={null}>
          <YandexMetrikaTracker />
        </Suspense>
      )}
      {children}
    </>
  )
}
