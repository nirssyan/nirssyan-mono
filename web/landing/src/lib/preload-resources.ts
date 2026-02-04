import { preload } from 'react-dom'

/**
 * Critical assets for preloading during splash screen
 * Centralized configuration for all hero assets
 */
export const CRITICAL_ASSETS = {
  heroVideo: {
    desktop: '/hero-video.mp4',
    mobile: '/hero-video-mobile.mp4',
  },
  heroPoster: {
    mobile: '/hero-poster-mobile.jpg',
  },
} as const

export type DeviceType = 'mobile' | 'desktop'

/**
 * Preload status shared across components
 * Updated by splash-screen, consumed by hero
 */
const preloadStatus = {
  deviceType: 'desktop' as DeviceType,
  preloadStarted: false,
}

/**
 * Get current preload status
 * Use this in components to access the pre-determined device type
 */
export function getPreloadStatus() {
  return preloadStatus
}

/**
 * Detect device type based on viewport width
 * Uses 640px breakpoint (Tailwind's sm) to match CSS media queries
 */
export function detectDeviceType(): DeviceType {
  if (typeof window === 'undefined') return 'desktop'
  return window.innerWidth < 640 ? 'mobile' : 'desktop'
}

/**
 * Check if browser supports HEVC (H.265) codec
 * Useful for iOS which has better HEVC hardware decoding
 */
export function supportsHEVC(): boolean {
  if (typeof document === 'undefined') return false
  const video = document.createElement('video')
  return video.canPlayType('video/mp4; codecs="hvc1"') !== ''
}

/**
 * Preload a video resource using link element
 * Creates a high-priority preload hint for video files
 */
export function preloadVideo(src: string): void {
  if (typeof document === 'undefined') return

  // Check if already preloaded
  const existing = document.querySelector(`link[rel="preload"][href="${src}"]`)
  if (existing) return

  const link = document.createElement('link')
  link.rel = 'preload'
  link.href = src
  link.as = 'video'
  link.type = 'video/mp4'
  link.setAttribute('fetchpriority', 'high')
  document.head.appendChild(link)
}

/**
 * Start preloading critical assets for the current device type
 * Should be called immediately on splash screen mount
 *
 * This function:
 * 1. Detects device type once
 * 2. Preloads the appropriate video
 * 3. Preloads poster image on mobile
 */
export function startCriticalPreloading(): void {
  if (preloadStatus.preloadStarted) return
  preloadStatus.preloadStarted = true

  const device = detectDeviceType()
  preloadStatus.deviceType = device

  if (device === 'mobile') {
    preloadVideo(CRITICAL_ASSETS.heroVideo.mobile)
    preload(CRITICAL_ASSETS.heroPoster.mobile, { as: 'image', fetchPriority: 'high' })
  } else {
    preloadVideo(CRITICAL_ASSETS.heroVideo.desktop)
  }
}
