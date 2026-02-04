'use client'

import { useEffect, useRef } from 'react'
import { useMatomo } from './use-matomo'

interface UseIntersectionTrackingOptions {
  sectionName: string
  threshold?: number
  trackOnce?: boolean
}

export function useIntersectionTracking({
  sectionName,
  threshold = 0.5,
  trackOnce = true,
}: UseIntersectionTrackingOptions) {
  const ref = useRef<HTMLElement>(null)
  const hasTracked = useRef(false)
  const startTime = useRef<number>(Date.now())
  const { trackSectionView } = useMatomo()

  useEffect(() => {
    const element = ref.current
    if (!element) {
      return
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && (!trackOnce || !hasTracked.current)) {
            const timeToView = Date.now() - startTime.current

            trackSectionView({
              section: sectionName,
              time_to_view: timeToView,
            })

            hasTracked.current = true

            if (trackOnce) {
              observer.disconnect()
            }
          }
        })
      },
      {
        threshold,
        rootMargin: '0px',
      }
    )

    observer.observe(element)

    return () => {
      observer.disconnect()
    }
  }, [sectionName, threshold, trackOnce, trackSectionView])

  return ref
}
