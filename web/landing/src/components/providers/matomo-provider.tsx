'use client'

import { useEffect, useState, Suspense } from 'react'
import { usePathname, useSearchParams } from 'next/navigation'
import Script from 'next/script'
import { initMatomo, trackPageView, matomoConfig } from '@/lib/matomo'

function MatomoTracker() {
  const pathname = usePathname()
  const searchParams = useSearchParams()

  useEffect(() => {
    const url = pathname + (searchParams?.toString() ? `?${searchParams.toString()}` : '')
    trackPageView(url)
  }, [pathname, searchParams])

  return null
}

export function MatomoProvider({ children }: { children: React.ReactNode }) {
  const [scriptLoaded, setScriptLoaded] = useState(false)

  useEffect(() => {
    if (!matomoConfig.enabled) return

    window._paq = window._paq || []
    window._paq.push(['disableCookies'])
    window._paq.push(['setTrackerUrl', `${matomoConfig.url}/matomo.php`])
    window._paq.push(['setSiteId', matomoConfig.siteId])
  }, [])

  useEffect(() => {
    if (scriptLoaded) {
      initMatomo()
    }
  }, [scriptLoaded])

  if (!matomoConfig.enabled) {
    return <>{children}</>
  }

  return (
    <>
      <Script
        id="matomo-script"
        strategy="afterInteractive"
        src={`${matomoConfig.url}/matomo.js`}
        onLoad={() => setScriptLoaded(true)}
      />
      {scriptLoaded && (
        <Suspense fallback={null}>
          <MatomoTracker />
        </Suspense>
      )}
      {children}
    </>
  )
}
