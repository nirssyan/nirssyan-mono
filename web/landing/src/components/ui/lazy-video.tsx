'use client'

import { useEffect, useRef, useState, useMemo } from 'react'
import { cn } from '@/lib/utils'

export interface LazyVideoProps
  extends Omit<React.VideoHTMLAttributes<HTMLVideoElement>, 'src'> {
  /**
   * Источник видео или объект с mobile/desktop вариантами
   */
  src: string | { mobile?: string; desktop?: string }

  /**
   * Стратегия загрузки видео
   * - 'none': не загружать до видимости
   * - 'metadata': загрузить только метаданные
   * - 'auto': загрузить сразу (по умолчанию)
   */
  preloadStrategy?: 'none' | 'metadata' | 'auto'

  /**
   * Включить ленивую загрузку через IntersectionObserver
   * Если false, видео загружается согласно preloadStrategy
   */
  lazy?: boolean

  /**
   * Порог видимости для IntersectionObserver (0-1)
   * 0.3 = начать загрузку при 30% видимости элемента
   */
  threshold?: number

  /**
   * Запас до viewport для начала загрузки
   * Например, '200px' начнет загрузку за 200px до viewport
   */
  rootMargin?: string

  /**
   * Изображение-плейсхолдер до загрузки видео
   */
  poster?: string

  /**
   * Breakpoint для переключения между mobile/desktop (в пикселях)
   * По умолчанию 640px (Tailwind 'sm' breakpoint)
   */
  mobileBreakpoint?: number
}

export function LazyVideo({
  src,
  preloadStrategy = 'auto',
  lazy = false,
  threshold = 0.3,
  rootMargin = '200px',
  autoPlay = false,
  loop = false,
  muted = false,
  playsInline = false,
  poster,
  className,
  mobileBreakpoint = 640,
  ...props
}: LazyVideoProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [isLoaded, setIsLoaded] = useState(!lazy)
  const [isMobile, setIsMobile] = useState(false)
  const hasStartedPlaying = useRef(false)

  // Определяем mobile/desktop один раз при монтировании (без resize listener)
  useEffect(() => {
    setIsMobile(window.innerWidth < mobileBreakpoint)
  }, [mobileBreakpoint])

  // Получаем правильный src на основе устройства
  const videoSrc = useMemo(() => {
    if (typeof src === 'string') {
      return src
    }

    // Если src - объект с mobile/desktop вариантами
    return isMobile ? src.mobile : src.desktop
  }, [src, isMobile])

  // IntersectionObserver для ленивой загрузки
  useEffect(() => {
    if (!lazy || isLoaded) return

    const element = videoRef.current
    if (!element) return

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && !isLoaded) {
            setIsLoaded(true)
            observer.disconnect()
          }
        })
      },
      {
        threshold,
        rootMargin,
      }
    )

    observer.observe(element)

    return () => {
      observer.disconnect()
    }
  }, [lazy, isLoaded, threshold, rootMargin])

  // Сбросить hasStartedPlaying при смене src
  useEffect(() => {
    hasStartedPlaying.current = false
  }, [videoSrc])

  // Автоплей при загрузке (если включен)
  useEffect(() => {
    if (!isLoaded || !autoPlay || hasStartedPlaying.current) return

    const video = videoRef.current
    if (!video) return

    const attemptPlay = async () => {
      try {
        // Ждем, пока видео будет готово к воспроизведению
        if (video.readyState < 2) {
          video.addEventListener('loadeddata', attemptPlay, { once: true })
          return
        }

        await video.play()
        hasStartedPlaying.current = true
      } catch (error) {
        // Autoplay failed (user interaction may be required)
      }
    }

    attemptPlay()
  }, [isLoaded, autoPlay, videoSrc])

  // Если lazy loading не включен или видео уже загружено
  const shouldLoadVideo = !lazy || isLoaded

  return (
    <video
      ref={videoRef}
      src={shouldLoadVideo ? videoSrc : undefined}
      preload={shouldLoadVideo ? preloadStrategy : 'none'}
      autoPlay={false} // Управляем autoplay через useEffect для надежности
      loop={loop}
      muted={muted}
      playsInline={playsInline}
      poster={poster}
      className={cn(className)}
      {...props}
    />
  )
}
