'use client'

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X } from 'lucide-react'
import Link from 'next/link'

const CONSENT_KEY = 'cookie-consent'

export type ConsentStatus = 'pending' | 'accepted' | 'declined'

export function getConsentStatus(): ConsentStatus {
  if (typeof window === 'undefined') return 'pending'
  const stored = localStorage.getItem(CONSENT_KEY)
  if (stored === 'accepted' || stored === 'declined') return stored
  return 'pending'
}

export function CookieConsent() {
  const [status, setStatus] = useState<ConsentStatus>('pending')
  const [isVisible, setIsVisible] = useState(false)

  useEffect(() => {
    const stored = getConsentStatus()
    setStatus(stored)
    if (stored === 'pending') {
      const timer = setTimeout(() => setIsVisible(true), 1500)
      return () => clearTimeout(timer)
    }
  }, [])

  const handleAccept = () => {
    localStorage.setItem(CONSENT_KEY, 'accepted')
    setStatus('accepted')
    setIsVisible(false)
    window.dispatchEvent(new CustomEvent('cookie-consent-change', { detail: 'accepted' }))
  }

  const handleDecline = () => {
    localStorage.setItem(CONSENT_KEY, 'declined')
    setStatus('declined')
    setIsVisible(false)
    window.dispatchEvent(new CustomEvent('cookie-consent-change', { detail: 'declined' }))
  }

  if (status !== 'pending') return null

  return (
    <AnimatePresence>
      {isVisible && (
        <motion.div
          initial={{ y: 100, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 100, opacity: 0 }}
          transition={{
            type: 'spring',
            damping: 25,
            stiffness: 300,
            mass: 0.8
          }}
          className="fixed bottom-6 left-4 right-4 z-50 mx-auto max-w-lg"
        >
          <div className="relative overflow-hidden rounded-2xl border border-white/10 bg-black/80 p-5 shadow-2xl backdrop-blur-xl">
            {/* Close button */}
            <button
              onClick={handleDecline}
              className="absolute right-3 top-3 rounded-full p-1.5 text-white/40 transition-colors hover:bg-white/10 hover:text-white"
              aria-label="Закрыть"
            >
              <X className="h-4 w-4" />
            </button>

            <div className="space-y-4">
              {/* Content */}
              <div className="pr-6">
                <h3 className="text-sm font-medium text-white">
                  Мы используем cookies
                </h3>
                <p className="mt-1 text-sm text-white/50">
                  Для улучшения работы сайта и аналитики.{' '}
                  <Link
                    href="/privacy"
                    className="text-white/70 underline underline-offset-2 transition-colors hover:text-white"
                  >
                    Подробнее
                  </Link>
                </p>
              </div>

              {/* Actions */}
              <div className="flex items-center gap-3">
                <button
                  onClick={handleAccept}
                  className="rounded-full bg-white px-6 py-2.5 text-sm font-medium text-black transition-all duration-300 hover:bg-gray-200 hover:scale-105 active:scale-95"
                >
                  Принять
                </button>

                <button
                  onClick={handleDecline}
                  className="rounded-full px-6 py-2.5 text-sm font-medium text-white/60 transition-all duration-300 hover:text-white"
                >
                  Отклонить
                </button>
              </div>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
