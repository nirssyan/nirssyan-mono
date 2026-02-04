'use client'

import { useState, useEffect } from 'react'

/**
 * Hook to detect mobile devices based on viewport width.
 * Does NOT listen for resize events to prevent re-renders from URL bar changes on mobile.
 * The value is determined once on mount.
 *
 * @param breakpoint - The width threshold for mobile (default: 640px, matches Tailwind's 'sm')
 * @returns boolean indicating if the viewport is mobile-sized
 */
export function useIsMobile(breakpoint = 640): boolean {
  const [isMobile, setIsMobile] = useState(false)

  useEffect(() => {
    setIsMobile(window.innerWidth < breakpoint)
    // Intentionally no resize listener - prevents re-renders from iOS URL bar
  }, [breakpoint])

  return isMobile
}
