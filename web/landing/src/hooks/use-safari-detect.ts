'use client'

import { useState, useEffect } from 'react'

export function useIsSafari(): boolean {
  const [isSafari, setIsSafari] = useState(false)
  useEffect(() => {
    setIsSafari(/^((?!chrome|android).)*safari/i.test(navigator.userAgent))
  }, [])
  return isSafari
}
