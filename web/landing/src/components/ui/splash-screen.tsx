'use client'

import { motion, AnimatePresence, useMotionValue, useTransform, animate } from 'framer-motion'
import { useEffect, useState, useRef } from 'react'
import { usePathname } from 'next/navigation'
import { startCriticalPreloading } from '@/lib/preload-resources'

/**
 * SplashScreen component with typing animation
 * Inspired by aichat Flutter implementation
 * Uses animate() from Framer Motion to prevent race conditions
 */
export function SplashScreen() {
  const pathname = usePathname()
  const [isVisible, setIsVisible] = useState(!pathname.startsWith('/admin'))
  const text = 'infatium'
  const charCount = text.length
  const preloadStarted = useRef(false)

  // Start preloading critical assets immediately on mount
  useEffect(() => {
    if (preloadStarted.current) return
    preloadStarted.current = true
    startCriticalPreloading()
  }, [])

  // Motion value for animation progress (0 → charCount)
  const progress = useMotionValue(0)

  // Transform progress into number of characters to display
  const displayedChars = useTransform(progress, (latest) =>
    Math.floor(Math.max(0, Math.min(latest, charCount)))
  )

  // Compute displayed text
  const [displayedText, setDisplayedText] = useState('')

  useEffect(() => {
    const unsubscribe = displayedChars.on('change', (value) => {
      setDisplayedText(text.substring(0, value))
    })
    return unsubscribe
  }, [displayedChars])

  useEffect(() => {
    // Typing animation: 0 → charCount at 80ms per character
    const controls = animate(progress, charCount, {
      duration: (80 * charCount) / 1000, // 80ms per char = ~640ms total for "infatium"
      ease: 'linear'
    })

    // Fade out after typing completes + 600ms delay
    const timeout = setTimeout(() => {
      setIsVisible(false)
    }, (80 * charCount) + 600)

    return () => {
      controls.stop()
      clearTimeout(timeout)
    }
  }, [charCount, progress])

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.5, ease: 'easeInOut' }}
          className="fixed inset-0 z-[9999] bg-black flex items-center justify-center"
        >
          <div className="flex items-center gap-1">
            {/* Typing text */}
            <span className="text-6xl sm:text-8xl font-bold text-white tracking-tight">
              {displayedText || '\u00A0'}
            </span>

            {/* Blinking cursor */}
            <motion.div
              className="w-1 bg-white"
              style={{ height: '4rem' }} // Match text height
              animate={{
                opacity: [1, 0, 1]
              }}
              transition={{
                duration: 0.7,
                repeat: Infinity,
                ease: 'linear'
              }}
            />
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
