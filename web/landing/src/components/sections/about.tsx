'use client'

import { useState, useRef, useEffect, memo, useMemo, useCallback } from 'react'
import { motion, useMotionValue, useSpring, useTransform, AnimatePresence } from 'framer-motion'
import { Smartphone, Tablet, LucideIcon } from 'lucide-react'
import { useIntersectionTracking } from '@/hooks/use-intersection-tracking'
import { useMatomo } from '@/hooks/use-matomo'
import { useLanguage } from '@/lib/language-context'
import { throttle } from '@/lib/throttle'
import { useIsSafari } from '@/hooks/use-safari-detect'
import Image from 'next/image'

const platformStyles = [
  {
    id: 'ios',
    icon: Tablet,
    tech: 'Swift + SwiftUI',
    gradient: 'from-blue-500/20 via-cyan-500/20 to-blue-600/20',
    glowColor: 'rgba(59, 130, 246, 0.3)',
    iconColor: 'text-blue-400',
    href: 'https://apps.apple.com/us/app/infatium/id6749490917'
  },
  {
    id: 'android',
    icon: Smartphone,
    tech: 'Kotlin + Compose',
    gradient: 'from-green-500/20 via-emerald-500/20 to-green-600/20',
    glowColor: 'rgba(34, 197, 94, 0.3)',
    iconColor: 'text-green-400',
    href: 'https://www.rustore.ru/catalog/app/com.nirssyan.makefeed'
  },
]

type PlatformData = {
  id: string
  name: string
  description: string
  status: string
  icon: LucideIcon
  tech: string
  gradient: string
  glowColor: string
  iconColor: string
  href?: string
}

// Floating Particles Component - disabled on mobile for performance
const FloatingParticles = memo(({ isHovered, glowColor }: { isHovered: boolean; glowColor: string }) => {
  const [isMobile, setIsMobile] = useState(false)
  const isSafari = useIsSafari()

  useEffect(() => {
    setIsMobile(window.innerWidth < 640)
  }, [])

  const particleCount = isMobile ? 0 : isSafari ? 2 : 6

  const [particles] = useState(() =>
    [...Array(6)].map(() => ({
      initialX: Math.random() * 100 - 50,
      initialY: Math.random() * 100 - 50,
      animateX1: Math.random() * 60 - 30,
      animateX2: Math.random() * 80 - 40,
    }))
  )

  if (particleCount === 0) return null

  return (
    <AnimatePresence>
      {isHovered && (
        <>
          {particles.slice(0, particleCount).map((particle, i) => (
            <motion.div
              key={i}
              initial={{
                opacity: 0,
                x: particle.initialX,
                y: particle.initialY,
                scale: 0
              }}
              animate={{
                opacity: [0, 1, 0],
                y: [0, -60, -120],
                x: [0, particle.animateX1, particle.animateX2],
                scale: [0, 1, 0.5]
              }}
              exit={{ opacity: 0 }}
              transition={{
                duration: 3,
                delay: i * 0.08,
                repeat: Infinity,
                repeatDelay: 0.3
              }}
              className="absolute w-1 h-1 rounded-full pointer-events-none"
              style={{
                backgroundColor: glowColor,
                boxShadow: `0 0 10px ${glowColor}`,
                left: `${25 + i * 10}%`,
                top: '60%'
              }}
            />
          ))}
        </>
      )}
    </AnimatePresence>
  )
})

FloatingParticles.displayName = 'FloatingParticles'

// Platform Card Component with 3D Tilt
const PlatformCard = memo(({
  platform,
  index,
  onTrackClick
}: {
  platform: PlatformData
  index: number
  onTrackClick?: (name: string, href: string) => void
}) => {
  const cardRef = useRef<HTMLElement>(null)
  const rectRef = useRef<DOMRect | null>(null)
  const [isHovered, setIsHovered] = useState(false)

  // Mouse position tracking for 3D tilt
  const mouseX = useMotionValue(0)
  const mouseY = useMotionValue(0)

  // Spring animation for smooth 3D movement
  const springConfig = { damping: 20, stiffness: 120 }
  const rotateX = useSpring(useTransform(mouseY, [-0.5, 0.5], [8, -8]), springConfig)
  const rotateY = useSpring(useTransform(mouseX, [-0.5, 0.5], [-8, 8]), springConfig)

  // Cache rect calculation on mount and resize
  useEffect(() => {
    const updateRect = () => {
      if (cardRef.current) {
        rectRef.current = cardRef.current.getBoundingClientRect()
      }
    }
    updateRect()
    window.addEventListener('resize', updateRect)
    return () => window.removeEventListener('resize', updateRect)
  }, [])

  // Handle mouse move for 3D tilt (throttled to ~60fps)
  const handleMouseMove = useMemo(
    () => throttle((e: React.MouseEvent<HTMLElement>) => {
      if (!rectRef.current) return

      const rect = rectRef.current
      const centerX = rect.left + rect.width / 2
      const centerY = rect.top + rect.height / 2

      const percentX = (e.clientX - centerX) / (rect.width / 2)
      const percentY = (e.clientY - centerY) / (rect.height / 2)

      mouseX.set(percentX)
      mouseY.set(percentY)
    }, 16),
    [mouseX, mouseY]
  )

  const handleMouseLeave = () => {
    mouseX.set(0)
    mouseY.set(0)
    setIsHovered(false)
  }

  const Icon = platform.icon

  const CardWrapper = platform.href ? motion.a : motion.div
  const linkProps = platform.href ? {
    href: platform.href,
    target: "_blank",
    rel: "noopener noreferrer",
    onClick: () => onTrackClick?.(platform.name, platform.href!)
  } : {}

  return (
    <CardWrapper
      {...linkProps}
      ref={cardRef as unknown as React.RefObject<HTMLAnchorElement> & React.RefObject<HTMLDivElement>}
      initial={{ opacity: 0.3, y: 15 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.2 }}
      transition={{
        duration: 0.5,
        delay: index * 0.05,
        ease: [0.25, 0.1, 0.25, 1]
      }}
      onMouseMove={handleMouseMove}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={handleMouseLeave}
      style={{
        rotateX,
        rotateY,
        transformStyle: "preserve-3d",
      }}
      className={`group relative overflow-hidden rounded-2xl sm:rounded-3xl bg-gray-900/90 border border-white/10 hover:border-white/20 transition-colors duration-500 ${platform.href ? 'cursor-pointer block' : ''}`}
    >
      {/* Animated gradient background */}
      <motion.div
        className={`absolute inset-0 bg-gradient-to-br ${platform.gradient} opacity-0 group-hover:opacity-100 transition-opacity duration-700`}
      />

      {/* Main glow effect */}
      <motion.div
        className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500"
        style={{
          background: `radial-gradient(circle at 50% 0%, ${platform.glowColor}, transparent 70%)`,
        }}
      />

      {/* Floating particles */}
      <FloatingParticles isHovered={isHovered} glowColor={platform.glowColor} />

      {/* Ripple effect */}
      <AnimatePresence>
        {isHovered && (
          <motion.div
            initial={{ scale: 0.8, opacity: 0.5 }}
            animate={{ scale: 2.8, opacity: 0 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 1.3, ease: "easeOut" }}
            className="absolute inset-0 rounded-2xl sm:rounded-3xl border-2 border-white/30"
            style={{ boxShadow: `0 0 30px ${platform.glowColor}` }}
          />
        )}
      </AnimatePresence>

      {/* Card content */}
      <div className="relative z-10 p-3 sm:p-4 md:p-5 flex flex-col items-center text-center h-full min-h-[150px] xs:min-h-[160px] sm:min-h-[180px] md:min-h-[200px]">
        {/* Animated icon with glow */}
        <motion.div
          className="relative mb-3 sm:mb-4"
          whileHover={{ scale: 1.1, rotate: [0, -5, 5, 0] }}
          transition={{
            scale: { type: "spring", stiffness: 300, damping: 15 },
            rotate: { type: "tween", duration: 0.6, ease: "easeInOut" }
          }}
        >
          {/* Icon glow background */}
          <motion.div
            className="absolute inset-0 rounded-xl blur-xl opacity-0 group-hover:opacity-60 transition-opacity duration-500"
            style={{
              background: `radial-gradient(circle, ${platform.glowColor}, transparent 70%)`,
              transform: 'scale(1.5)'
            }}
          />

          {/* Icon container */}
          <div
            className={`relative w-10 h-10 xs:w-12 xs:h-12 sm:w-14 sm:h-14 md:w-16 md:h-16 rounded-lg sm:rounded-xl bg-white/5 border border-white/10 flex items-center justify-center group-hover:border-white/30 transition-all duration-300 ${
              isHovered ? (platform.id === 'ios' ? 'shadow-glow-blue' : 'shadow-glow-green') : ''
            }`}
          >
            {platform.id === 'ios' ? (
              <svg
                className={`w-5 h-5 xs:w-6 xs:h-6 sm:w-7 sm:h-7 md:w-8 md:h-8 ${platform.iconColor} group-hover:scale-110 transition-transform duration-300`}
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
              </svg>
            ) : platform.id === 'android' ? (
              <svg
                className={`w-5 h-5 xs:w-6 xs:h-6 sm:w-7 sm:h-7 md:w-8 md:h-8 ${platform.iconColor} group-hover:scale-110 transition-transform duration-300`}
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path d="M6 18c0 .55.45 1 1 1h1v3.5c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5V19h2v3.5c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5V19h1c.55 0 1-.45 1-1V8H6v10zM3.5 8C2.67 8 2 8.67 2 9.5v7c0 .83.67 1.5 1.5 1.5S5 17.33 5 16.5v-7C5 8.67 4.33 8 3.5 8zm17 0c-.83 0-1.5.67-1.5 1.5v7c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5v-7c0-.83-.67-1.5-1.5-1.5zm-4.97-5.84l1.3-1.3c.2-.2.2-.51 0-.71-.2-.2-.51-.2-.71 0l-1.48 1.48A5.84 5.84 0 0 0 12 1c-.96 0-1.86.23-2.66.63L7.85.15c-.2-.2-.51-.2-.71 0-.2.2-.2.51 0 .71l1.31 1.31A5.983 5.983 0 0 0 6 7h12c0-1.99-.97-3.75-2.47-4.84zM10 5H9V4h1v1zm5 0h-1V4h1v1z"/>
              </svg>
            ) : (
              <Icon
                className={`w-5 h-5 xs:w-6 xs:h-6 sm:w-7 sm:h-7 md:w-8 md:h-8 ${platform.iconColor} group-hover:scale-110 transition-transform duration-300`}
                strokeWidth={1.5}
              />
            )}
          </div>

          {/* Rotating ring */}
          <motion.div
            className="absolute inset-0 rounded-xl border-2 border-white/0 group-hover:border-white/20"
            animate={isHovered ? {
              rotate: 360,
              scale: [1, 1.1, 1]
            } : {
              rotate: 0,
              scale: 1
            }}
            transition={{
              rotate: { duration: 4, repeat: Infinity, ease: "linear" },
              scale: { duration: 2, repeat: Infinity, ease: "easeInOut" }
            }}
          />
        </motion.div>

        {/* Platform name */}
        <motion.p
          className="text-sm xs:text-base sm:text-lg md:text-xl font-bold text-white mb-1 sm:mb-1.5 md:mb-2 tracking-tight"
          style={{ transform: "translateZ(20px)" }}
        >
          {platform.name}
        </motion.p>

        {/* Description */}
        <motion.p
          className="text-[10px] xs:text-xs sm:text-sm text-white/50 mb-2 sm:mb-3 md:mb-4 font-light leading-relaxed"
          style={{ transform: "translateZ(15px)" }}
        >
          {platform.description}
        </motion.p>

        {/* Status badge */}
        <motion.div
          className="mt-auto inline-flex items-center gap-1.5 px-2.5 sm:px-3 py-1 sm:py-1.5 rounded-full bg-gray-800/60 border border-white/10"
          whileHover={{ scale: 1.05 }}
          style={{ transform: "translateZ(10px)" }}
        >
          {platform.id === 'android' ? (
            <svg className="w-3 h-3 text-white/60" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2c-2.5 0-4.71-1.28-6-3.22.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08-1.29 1.94-3.5 3.22-6 3.22z"/>
            </svg>
          ) : (
            <div
              className="w-1.5 h-1.5 rounded-full animate-pulse-dot"
              style={{ backgroundColor: platform.glowColor }}
            />
          )}
          <span className="text-[10px] sm:text-xs text-white/60 font-medium">{platform.status}</span>
        </motion.div>

        {/* Animated border gradient — CSS animation for Safari performance */}
        <div
          className={`absolute inset-0 rounded-2xl sm:rounded-3xl opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none ${isHovered ? 'animate-gradient-shift' : ''}`}
          style={{
            background: `linear-gradient(135deg, ${platform.glowColor}, transparent, ${platform.glowColor})`,
            backgroundSize: '200% 200%'
          }}
        />
      </div>
    </CardWrapper>
  )
})

PlatformCard.displayName = 'PlatformCard'

export function About() {
  const { t } = useLanguage()
  const { trackExternalLink } = useMatomo()
  const sectionRef = useIntersectionTracking({
    sectionName: 'about',
    threshold: 0.3,
    trackOnce: true,
  })

  const handlePlatformClick = useCallback((platformName: string, href: string) => {
    trackExternalLink({
      link_text: platformName,
      destination: href,
      section: 'about-platforms'
    })
  }, [trackExternalLink])

  const platforms: PlatformData[] = useMemo(() =>
    platformStyles.map((style, index) => ({
      ...style,
      name: t.about.platformItems[index].name,
      description: t.about.platformItems[index].description,
      status: t.about.platformItems[index].status,
    })),
    [t]
  )

  return (
    <section id="about" ref={sectionRef} className="pt-8 sm:pt-12 md:pt-16 pb-16 sm:pb-24 md:pb-32 bg-black relative overflow-hidden">
      {/* Ultra-subtle background */}
      <div className="absolute inset-0">
        <motion.div
          className="absolute inset-0 opacity-[0.01]"
          style={{
            backgroundImage: `radial-gradient(circle at 1px 1px, white 1px, transparent 0)`,
            backgroundSize: '60px 60px'
          }}
        />
      </div>

      <div className="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">

        {/* Platforms with iPhone mockup */}
        <motion.div
          initial={{ opacity: 0.5, y: 10 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.1 }}
          transition={{ duration: 0.4, ease: [0.25, 0.1, 0.25, 1] }}
        >
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 lg:gap-12 items-center">
            {/* Left side - Platforms */}
            <div className="lg:order-1">
              {/* SEO: Hidden section heading for proper hierarchy */}
              <h2 className="sr-only">О приложении infatium</h2>

              {/* Header */}
              <div className="flex items-center gap-3 sm:gap-4 mb-6 sm:mb-8">
                <Smartphone className="w-5 h-5 sm:w-6 sm:h-6 text-white/60" />
                <h3 className="text-2xl sm:text-3xl font-bold text-white">{t.about.platforms}</h3>
              </div>

              {/* Platform Cards Grid - 2x2 */}
              <div className="grid grid-cols-2 gap-3 sm:gap-4">
                {platforms.map((platform, index) => (
                  <PlatformCard
                    key={platform.id}
                    platform={platform}
                    index={index}
                    onTrackClick={handlePlatformClick}
                  />
                ))}
              </div>
            </div>

            {/* Right side - iPhone mockup (hidden on mobile) */}
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: 0.2 }}
              className="relative hidden lg:flex lg:justify-end lg:order-2"
            >
              <div className="relative w-[220px] xs:w-[260px] sm:w-[300px] md:w-[340px] lg:w-[360px]">
                {/* iPhone frame */}
                <div className="relative rounded-[2.5rem] sm:rounded-[3rem] overflow-hidden bg-black border-[6px] sm:border-[8px] border-gray-800 shadow-2xl">
                  {/* Dynamic Island */}
                  <div className="absolute top-1.5 sm:top-2 left-1/2 -translate-x-1/2 w-20 sm:w-24 h-5 sm:h-6 bg-black rounded-full z-20" />

                  {/* Screen */}
                  <div className="relative aspect-[9/19.5] overflow-hidden rounded-[2rem] sm:rounded-[2.5rem]">
                    <Image
                      src="/app-screenshot.png"
                      alt="infatium app"
                      fill
                      className="object-cover object-top"
                      priority
                      placeholder="blur"
                      blurDataURL="data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAIAAoDASIAAhEBAxEB/8QAFgABAQEAAAAAAAAAAAAAAAAAAAUH/8QAIRAAAgIBAwUBAAAAAAAAAAAAAQIDBAAFESEGEhMxQVH/xAAVAQEBAAAAAAAAAAAAAAAAAAADBP/EABkRAAIDAQAAAAAAAAAAAAAAAAECABEhMf/aAAwDAQACEQMRAD8Ax2tptVoNDmezLFFNLGVjR3AZl9EgHkZVg6h1CCJIotTsJGoCqqzkAAehjGJLEDqYEpx2Z//Z"
                    />
                  </div>
                </div>

                {/* Glow effect behind phone - simplified on mobile */}
                <div className="absolute inset-0 -z-10 blur-3xl opacity-20 sm:opacity-30">
                  <div className="absolute inset-0 bg-gradient-to-br from-blue-500 via-purple-500 to-cyan-500 rounded-full scale-75" />
                </div>
              </div>
            </motion.div>
          </div>
        </motion.div>

      </div>
    </section>
  )
}
