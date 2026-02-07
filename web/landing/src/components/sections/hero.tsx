'use client'

import { motion, useMotionValue, useTransform, animate, AnimationPlaybackControls } from 'framer-motion'
import { useEffect, useState, memo } from 'react'
import { ChevronDown } from 'lucide-react'
import { useMatomo } from '@/hooks/use-matomo'
import { useIntersectionTracking } from '@/hooks/use-intersection-tracking'
import { useIsMobile } from '@/hooks/use-is-mobile'
import { useLanguage } from '@/lib/language-context'

// Ultra-modern typewriter component - optimized with animate() to prevent lag
function TypewriterText({ phrases, prefix }: { phrases: readonly string[], prefix: string }) {
  const [currentPhraseIndex, setCurrentPhraseIndex] = useState(0)
  const [isDeleting, setIsDeleting] = useState(false)
  const [displayedText, setDisplayedText] = useState('')

  const currentPhrase = phrases[currentPhraseIndex]
  const charCount = currentPhrase.length

  // Motion value for animation progress (0 → charCount)
  const progress = useMotionValue(0)

  // Transform progress into number of characters to display
  const displayedChars = useTransform(progress, (latest) =>
    Math.floor(Math.max(0, Math.min(latest, charCount)))
  )

  // Subscribe to displayedChars changes
  useEffect(() => {
    const unsubscribe = displayedChars.on('change', (value) => {
      setDisplayedText(currentPhrase.substring(0, value))
    })
    return unsubscribe
  }, [currentPhrase, displayedChars])

  // Typing/deleting animation
  useEffect(() => {
    let controls: AnimationPlaybackControls | undefined

    if (!isDeleting) {
      // Typing: 0 → charCount at 60ms/char
      controls = animate(progress, charCount, {
        duration: (60 * charCount) / 1000,
        ease: 'linear',
        onComplete: () => {
          // Pause 2 seconds, then start deleting
          setTimeout(() => setIsDeleting(true), 2000)
        }
      })
    } else {
      // Deleting: charCount → 0 at 25ms/char
      controls = animate(progress, 0, {
        duration: (25 * charCount) / 1000,
        ease: 'linear',
        onComplete: () => {
          setIsDeleting(false)
          setCurrentPhraseIndex((prev) => (prev + 1) % phrases.length)
        }
      })
    }

    return () => controls?.stop()
  }, [currentPhraseIndex, isDeleting, charCount, phrases.length, progress])

  return (
    <div className="relative min-h-[3rem] sm:min-h-[4rem] flex items-center justify-center px-4">
      <motion.div
        className="text-2xl xs:text-3xl sm:text-4xl md:text-5xl lg:text-6xl font-light text-white tracking-tight"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 1 }}
      >
        <span className="relative block text-center">
          <span className="text-white/50">{prefix}</span>
          <span className="ml-0 sm:ml-3 relative inline-block mt-2 sm:mt-0 w-full sm:w-auto text-center sm:text-left min-h-[1.5rem] sm:min-h-[2rem]">
            {displayedText || '\u00A0'}
            {/* Blinking cursor - independent animation */}
            <motion.span
              className="hidden sm:inline-block w-[2px] bg-white ml-1 align-middle"
              style={{ height: '1em', verticalAlign: 'middle' }}
              animate={{ opacity: [1, 0, 1] }}
              transition={{
                duration: 0.7,
                repeat: Infinity,
                ease: 'linear'
              }}
            />
          </span>
        </span>
      </motion.div>
    </div>
  )
}

const MemoizedTypewriterText = memo(TypewriterText)

export function Hero() {
  const { trackCTAClick } = useMatomo()
  const { t } = useLanguage()
  const isMobile = useIsMobile()
  const sectionRef = useIntersectionTracking({
    sectionName: 'hero',
    threshold: 0.3,
    trackOnce: true
  })

  return (
    <section ref={sectionRef} className="relative min-h-[100svh] flex items-center justify-center overflow-hidden bg-black">
      {/* Ultra-minimal background - single subtle orb (desktop only, conditionally rendered) */}
      {!isMobile && (
        <div className="absolute inset-0">
          {/* Extremely subtle grid */}
          <motion.div
            className="absolute inset-0 opacity-[0.015]"
            animate={{
              backgroundPosition: ['0px 0px', '80px 80px'],
            }}
            transition={{
              duration: 50,
              repeat: Infinity,
              ease: "linear",
            }}
            style={{
              backgroundImage: `radial-gradient(circle at 1px 1px, white 1px, transparent 0)`,
              backgroundSize: '80px 80px'
            }}
          />

          {/* Single floating orb — reduced size for GPU performance */}
          <motion.div
            className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-white/[0.02] rounded-full blur-2xl"
            animate={{
              scale: [1, 1.03, 1],
              opacity: [0.02, 0.04, 0.02],
            }}
            transition={{
              duration: 25,
              repeat: Infinity,
              ease: "easeInOut",
            }}
          />
        </div>
      )}

      {/* Full-screen video background - conditional rendering (only one video loads) */}
      <div className="absolute inset-0 pointer-events-none z-[1]">
        {isMobile ? (
          <video
            src="/hero-video-mobile.mp4"
            autoPlay
            loop
            muted
            playsInline
            preload="metadata"
            className="w-full h-full object-cover"
          />
        ) : (
          <video
            src="/hero-video.mp4"
            autoPlay
            loop
            muted
            playsInline
            preload="metadata"
            className="w-full h-full object-cover"
          />
        )}
        {/* Dark overlay for mobile readability */}
        <div className="absolute inset-0 bg-black/30 sm:bg-transparent" />
        {/* Bottom gradient for smooth transition to next section */}
        <div className="absolute inset-x-0 bottom-0 h-40 sm:h-60 bg-gradient-to-t from-black via-black/80 to-transparent" />
      </div>

      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1.2, ease: "easeOut" }}
          className="space-y-6 sm:space-y-12 md:space-y-20"
        >
          {/* Brand name - ultra minimal */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 1.5, delay: 0.3 }}
            className="relative"
          >
            <h1 className="relative z-10 text-[3.5rem] xs:text-7xl sm:text-8xl md:text-9xl lg:text-[11rem] font-bold text-white leading-none tracking-tighter mb-3 sm:mb-6 md:mb-8">
              infatium
            </h1>
            <p className="relative z-10 text-base xs:text-lg sm:text-xl md:text-2xl text-white/70 font-light tracking-wide px-4 sm:px-0">
              {t.hero.tagline}
            </p>
          </motion.div>

          {/* Typewriter demo - the hero */}
          <motion.div
            className="relative"
          >
            <MemoizedTypewriterText phrases={t.hero.phrases} prefix={t.hero.iDecide} />
          </motion.div>

          {/* Single minimal CTA */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 1, delay: 2 }}
            className="pt-4 sm:pt-12"
          >
            <button
              onClick={() => {
                trackCTAClick({
                  button_text: t.hero.cta,
                  section: 'hero',
                  destination: '#about',
                })
                const aboutSection = document.getElementById('about')
                if (aboutSection) {
                  aboutSection.scrollIntoView({ behavior: 'smooth' })
                }
              }}
              className="group relative inline-block px-12 sm:px-14 py-4 sm:py-5 bg-white text-black rounded-full text-base sm:text-base font-semibold transition-all duration-500 hover:bg-gray-200 hover:scale-105 focus:outline-none focus:ring-2 focus:ring-white/20 active:scale-95 cursor-pointer"
            >
              <span className="relative z-10">{t.hero.cta}</span>
              <div className="absolute inset-0 rounded-full bg-white/10 opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
            </button>
          </motion.div>
        </motion.div>
      </div>

      {/* Ultra-minimal scroll indicator - static on mobile */}
      {isMobile ? (
        <div className="absolute bottom-8 left-1/2 transform -translate-x-1/2">
          <ChevronDown className="w-4 h-4 text-white/25" />
        </div>
      ) : (
        <motion.div
          className="absolute bottom-12 left-1/2 transform -translate-x-1/2"
          animate={{
            y: [0, 8, 0],
          }}
          transition={{
            duration: 2.5,
            repeat: Infinity,
            ease: "easeInOut",
          }}
        >
          <ChevronDown className="w-5 h-5 text-white/25" />
        </motion.div>
      )}
    </section>
  )
}
