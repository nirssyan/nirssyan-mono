'use client'

import { useRef, useEffect, useState } from 'react'

export function ScrollVideo() {
  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  const [duration, setDuration] = useState(0)

  useEffect(() => {
    const video = videoRef.current
    const canvas = canvasRef.current
    if (!video || !canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    const handleLoadedMetadata = () => {
      setDuration(video.duration)
      canvas.width = video.videoWidth
      canvas.height = video.videoHeight
      video.currentTime = 0
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
    }

    const handleSeeked = () => {
      if (ctx && video.readyState >= 2) {
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
      }
    }

    video.addEventListener('loadedmetadata', handleLoadedMetadata)
    video.addEventListener('seeked', handleSeeked)

    if (video.readyState >= 1) {
      handleLoadedMetadata()
    }

    return () => {
      video.removeEventListener('loadedmetadata', handleLoadedMetadata)
      video.removeEventListener('seeked', handleSeeked)
    }
  }, [])

  useEffect(() => {
    const video = videoRef.current
    const container = containerRef.current
    if (!video || !container || !duration) return

    const handleScroll = () => {
      const scrollTop = window.scrollY
      const viewportHeight = window.innerHeight

      // Video progress based on first 3 viewport heights
      const videoScrollRange = viewportHeight * 3
      const videoProgress = Math.max(0, Math.min(1, scrollTop / videoScrollRange))
      const targetTime = videoProgress * duration

      if (Math.abs(video.currentTime - targetTime) > 0.03) {
        video.currentTime = targetTime
      }

      // Fade out over first 1.5 viewport heights
      const fadeRange = viewportHeight * 1.5
      const opacity = Math.max(0, 1 - (scrollTop / fadeRange))

      // Scale up slightly as you scroll (creates depth)
      const scale = 1 + (scrollTop / viewportHeight) * 0.15

      container.style.opacity = String(opacity)
      container.style.setProperty('--scroll-scale', String(scale))
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    handleScroll()

    return () => window.removeEventListener('scroll', handleScroll)
  }, [duration])

  return (
    <div
      ref={containerRef}
      className="fixed inset-0 pointer-events-none z-[1] flex items-center justify-center"
      style={{ willChange: 'opacity, transform' }}
    >
      {/* Subtle ethereal glow */}
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="w-[600px] h-[600px] sm:w-[800px] sm:h-[800px] lg:w-[1000px] lg:h-[1000px] bg-gradient-radial from-white/[0.03] via-transparent to-transparent rounded-full blur-3xl" />
      </div>

      <video
        ref={videoRef}
        src="/hero-video.mp4"
        muted
        playsInline
        preload="auto"
        className="hidden"
      />
      <canvas
        ref={canvasRef}
        className="w-[300px] h-[300px] sm:w-[450px] sm:h-[450px] md:w-[600px] md:h-[600px] lg:w-[750px] lg:h-[750px] object-contain"
        style={{ transform: 'scale(var(--scroll-scale, 1))' }}
      />
    </div>
  )
}
