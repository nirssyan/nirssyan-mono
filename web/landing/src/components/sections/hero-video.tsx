'use client'

import { useRef, useEffect } from 'react'

export function HeroVideo() {
  const containerRef = useRef<HTMLDivElement>(null)
  const videoCreated = useRef(false)

  useEffect(() => {
    if (containerRef.current && !videoCreated.current) {
      videoCreated.current = true
      const video = document.createElement('video')
      video.src = '/hero-video.mp4'
      video.autoplay = true
      video.loop = true
      video.muted = true
      video.playsInline = true
      video.preload = 'auto'
      video.className = 'w-full h-full object-contain opacity-30'
      containerRef.current.appendChild(video)
      video.play()
    }
  }, [])

  return (
    <div
      ref={containerRef}
      className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none z-[1] w-[320px] h-[320px] sm:w-[500px] sm:h-[500px] md:w-[700px] md:h-[700px] lg:w-[900px] lg:h-[900px]"
    />
  )
}
