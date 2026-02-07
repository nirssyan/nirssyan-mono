'use client'

import { motion, useMotionValue, useSpring, AnimatePresence } from 'framer-motion'
import { useEffect, useState, useRef } from 'react'
import { Menu, X } from 'lucide-react'
import Link from 'next/link'
import { useRouter, usePathname } from 'next/navigation'
import { useMatomo } from '@/hooks/use-matomo'
import { useLanguage } from '@/lib/language-context'
import { LanguageSwitcher } from '@/components/ui/language-switcher'
import { throttle } from '@/lib/throttle'

// Magnetic button component
function MagneticButton({
  children,
  className = '',
  onClick,
}: {
  children: React.ReactNode
  className?: string
  onClick?: () => void
}) {
  const ref = useRef<HTMLButtonElement>(null)
  const x = useMotionValue(0)
  const y = useMotionValue(0)

  const springConfig = { damping: 15, stiffness: 150 }
  const springX = useSpring(x, springConfig)
  const springY = useSpring(y, springConfig)

  const handleMouseMove = (e: React.MouseEvent<HTMLButtonElement>) => {
    if (!ref.current) return
    const rect = ref.current.getBoundingClientRect()
    const centerX = rect.left + rect.width / 2
    const centerY = rect.top + rect.height / 2
    const distanceX = e.clientX - centerX
    const distanceY = e.clientY - centerY

    x.set(distanceX * 0.3)
    y.set(distanceY * 0.3)
  }

  const handleMouseLeave = () => {
    x.set(0)
    y.set(0)
  }

  return (
    <motion.button
      ref={ref}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      onClick={onClick}
      style={{ x: springX, y: springY }}
      className={className}
    >
      {children}
    </motion.button>
  )
}

// Nav link with animated underline
function NavLink({
  href,
  children,
  onClick,
  router,
  pathname,
  onTrack
}: {
  href: string
  children: React.ReactNode
  onClick?: () => void
  router: ReturnType<typeof useRouter>
  pathname: string
  onTrack?: (linkText: string, destination: string) => void
}) {
  const [isHovered, setIsHovered] = useState(false)
  const isHashLink = href.startsWith('#')

  const handleClick = (e: React.MouseEvent) => {
    e.preventDefault()
    onTrack?.(children as string, href.replace('#', '').replace('/', ''))

    if (isHashLink) {
      if (pathname === '/') {
        // На главной странице - скроллим к секции
        const element = document.getElementById(href.replace('#', ''))
        if (element) {
          element.scrollIntoView({ behavior: 'smooth' })
          onClick?.()
        }
      } else {
        // На других страницах - переходим на главную с хешем
        router.push(`/${href}`)
        onClick?.()
      }

      return
    }

    if (pathname !== href) {
      router.push(href)
      onClick?.()
      return
    }

    onClick?.()
  }

  return (
    <a
      href={href}
      onClick={handleClick}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      className="relative text-white/70 hover:text-white transition-colors duration-300 text-sm font-medium tracking-wide"
    >
      {children}
      <motion.div
        className="absolute -bottom-1 left-0 right-0 h-[1px] bg-white origin-left"
        initial={{ scaleX: 0 }}
        animate={{ scaleX: isHovered ? 1 : 0 }}
        transition={{ duration: 0.3, ease: "easeOut" }}
      />
    </a>
  )
}

// Typewriter Logo component
function TypewriterLogo({ onClick, onTrack }: { onClick: () => void; onTrack?: () => void }) {
  const fullText = 'infatium'
  const [displayText, setDisplayText] = useState(fullText)
  const [isAnimating, setIsAnimating] = useState(false)
  const [showCursor, setShowCursor] = useState(false)
  const [isHovered, setIsHovered] = useState(false)
  const timeoutRefs = useRef<NodeJS.Timeout[]>([])

  // Clear all timeouts on unmount
  useEffect(() => {
    return () => {
      timeoutRefs.current.forEach(timeout => clearTimeout(timeout))
    }
  }, [])

  // Cursor blink effect
  useEffect(() => {
    if (!showCursor) return

    const interval = setInterval(() => {
      setShowCursor(prev => !prev)
    }, 530)

    return () => clearInterval(interval)
  }, [showCursor])

  const startTypewriterEffect = () => {
    if (isAnimating) return

    setIsAnimating(true)
    setShowCursor(false)
    timeoutRefs.current.forEach(timeout => clearTimeout(timeout))
    timeoutRefs.current = []

    // Phase 1: Erase
    for (let i = fullText.length; i >= 0; i--) {
      const timeout = setTimeout(() => {
        setDisplayText(fullText.slice(0, i))
      }, (fullText.length - i) * 30)
      timeoutRefs.current.push(timeout)
    }

    // Phase 2: Type
    const eraseDelay = fullText.length * 30 + 150

    for (let i = 0; i <= fullText.length; i++) {
      const timeout = setTimeout(() => {
        setDisplayText(fullText.slice(0, i))
        if (i === 0) {
          setShowCursor(true)
        }
        if (i === fullText.length) {
          setShowCursor(false)
          setIsAnimating(false)
        }
      }, eraseDelay + i * 50)
      timeoutRefs.current.push(timeout)
    }
  }

  return (
    <motion.button
      onClick={() => {
        onTrack?.()
        onClick()
      }}
      onMouseEnter={() => {
        setIsHovered(true)
        startTypewriterEffect()
      }}
      onMouseLeave={() => {
        setIsHovered(false)
      }}
      className="relative text-white font-bold text-xl sm:text-2xl tracking-tighter group"
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
    >
      {/* Invisible text to maintain fixed width */}
      <span className="invisible">{fullText}</span>
      {/* Visible animated text positioned on top */}
      <span className="absolute left-0 top-0 inline-flex items-center">
        {displayText || '\u00A0'}
        <AnimatePresence>
          {showCursor && (
            <motion.span
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="inline-block w-[2px] h-5 sm:h-6 bg-white ml-0.5"
            />
          )}
        </AnimatePresence>
      </span>
      <motion.div
        className="absolute -bottom-1 left-0 h-[1px] bg-white/50"
        initial={{ width: 0 }}
        animate={{ width: isHovered ? '100%' : 0 }}
        transition={{ duration: 0.3 }}
      />
    </motion.button>
  )
}

export function Header() {
  const [isScrolled, setIsScrolled] = useState(false)
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)
  const router = useRouter()
  const pathname = usePathname()
  const { trackCTAClick } = useMatomo()
  const { t } = useLanguage()

  useEffect(() => {
    const handleScroll = throttle(() => {
      setIsScrolled(window.scrollY > 20)
    }, 100)

    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  const goToHome = () => {
    setIsMobileMenuOpen(false)

    if (pathname === '/') {
      // На главной странице - просто скроллим вверх
      window.scrollTo({ top: 0, behavior: 'smooth' })
    } else {
      // На других страницах - переходим на главную
      router.push('/')
    }
  }

  const scrollToSection = (sectionId: string) => {
    const element = document.getElementById(sectionId)
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' })
      setIsMobileMenuOpen(false)
    }
  }

  return (
    <>
      <motion.header
        initial={{ y: -100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.6, ease: "easeOut" }}
        className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${
          isScrolled
            ? 'bg-black/50 backdrop-blur-xl border-b border-white/5'
            : 'bg-transparent'
        }`}
        style={{ transform: 'translate3d(0,0,0)' }}
      >
        <nav className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="relative flex items-center justify-between h-16 sm:h-20">
            {/* Logo - wrapper prevents scale from affecting flex layout */}
            <div className="flex-shrink-0 w-[120px]">
              <TypewriterLogo
                onClick={goToHome}
                onTrack={() => trackCTAClick({
                  button_text: 'infatium (logo)',
                  section: 'header',
                  destination: 'home'
                })}
              />
            </div>

            {/* Desktop Navigation - Centered */}
            <ul className="hidden md:flex items-center justify-center gap-8 absolute left-1/2 -translate-x-1/2 list-none m-0 p-0">
              <li>
                <NavLink
                  href="#ai-animation"
                  router={router}
                  pathname={pathname}
                  onTrack={(linkText, destination) => trackCTAClick({
                    button_text: linkText,
                    section: 'navigation',
                    destination
                  })}
                >
                  {t.header.howItWorks}
                </NavLink>
              </li>
              <li>
                <NavLink
                  href="/marketplace"
                  router={router}
                  pathname={pathname}
                  onTrack={(linkText, destination) => trackCTAClick({
                    button_text: linkText,
                    section: 'navigation',
                    destination,
                  })}
                >
                  {t.header.marketplace}
                </NavLink>
              </li>
            </ul>

            {/* CTA Button + Language Switcher - Desktop */}
            <div className="hidden md:flex items-center gap-4">
              <MagneticButton
                onClick={() => {
                  trackCTAClick({
                    button_text: t.header.tryIt,
                    section: 'header',
                    destination: 'about',
                  })
                  const aboutSection = document.getElementById('about')
                  if (aboutSection) {
                    aboutSection.scrollIntoView({ behavior: 'smooth' })
                  }
                }}
                className="group relative px-6 py-2.5 bg-white text-black rounded-full text-sm font-medium transition-all duration-300 hover:bg-white/90 overflow-hidden cursor-pointer"
              >
                <span className="relative z-10">{t.header.tryIt}</span>
                {/* Hover effect */}
                <motion.div
                  className="absolute inset-0 bg-gradient-to-r from-white via-gray-100 to-white"
                  initial={{ x: '-100%' }}
                  whileHover={{ x: '100%' }}
                  transition={{ duration: 0.6, ease: "easeInOut" }}
                />
              </MagneticButton>
              <LanguageSwitcher />
            </div>

            {/* Mobile Menu Button */}
            <motion.button
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
              className="md:hidden text-white p-2"
              whileTap={{ scale: 0.95 }}
            >
              <AnimatePresence mode="wait">
                {isMobileMenuOpen ? (
                  <motion.div
                    key="close"
                    initial={{ rotate: -90, opacity: 0 }}
                    animate={{ rotate: 0, opacity: 1 }}
                    exit={{ rotate: 90, opacity: 0 }}
                    transition={{ duration: 0.2 }}
                  >
                    <X className="w-6 h-6" />
                  </motion.div>
                ) : (
                  <motion.div
                    key="menu"
                    initial={{ rotate: 90, opacity: 0 }}
                    animate={{ rotate: 0, opacity: 1 }}
                    exit={{ rotate: -90, opacity: 0 }}
                    transition={{ duration: 0.2 }}
                  >
                    <Menu className="w-6 h-6" />
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.button>
          </div>
        </nav>

        {/* Mobile Menu */}
        <AnimatePresence>
          {isMobileMenuOpen && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.3, ease: "easeInOut" }}
              className="md:hidden border-t border-white/5 bg-gray-950/95 overflow-hidden"
            >
              <ul className="px-4 py-6 space-y-6 list-none m-0 p-0">
                <motion.li
                  initial={{ x: -20, opacity: 0 }}
                  animate={{ x: 0, opacity: 1 }}
                  transition={{ delay: 0.1 }}
                >
                  <a
                    href="#ai-animation"
                    onClick={(e) => {
                      e.preventDefault()
                      trackCTAClick({
                        button_text: t.header.howItWorks,
                        section: 'navigation-mobile',
                        destination: 'ai-animation'
                      })
                      setIsMobileMenuOpen(false)

                      if (pathname === '/') {
                        scrollToSection('ai-animation')
                      } else {
                        router.push('/#ai-animation')
                      }
                    }}
                    className="block text-white/70 hover:text-white transition-colors duration-300 text-lg font-medium"
                  >
                    {t.header.howItWorks}
                  </a>
                </motion.li>
                <motion.li
                  initial={{ x: -20, opacity: 0 }}
                  animate={{ x: 0, opacity: 1 }}
                  transition={{ delay: 0.15 }}
                >
                  <Link
                    href="/marketplace"
                    onClick={() => {
                      trackCTAClick({
                        button_text: t.header.marketplace,
                        section: 'navigation-mobile',
                        destination: 'marketplace'
                      })
                      setIsMobileMenuOpen(false)
                    }}
                    className="block text-white/70 hover:text-white transition-colors duration-300 text-lg font-medium"
                  >
                    {t.header.marketplace}
                  </Link>
                </motion.li>

              </ul>

              <div className="px-4 pb-6 space-y-6">
                <motion.div
                  initial={{ x: -20, opacity: 0 }}
                  animate={{ x: 0, opacity: 1 }}
                  transition={{ delay: 0.2 }}
                  className="flex items-center justify-center"
                >
                  <LanguageSwitcher />
                </motion.div>

                <motion.div
                  initial={{ x: -20, opacity: 0 }}
                  animate={{ x: 0, opacity: 1 }}
                  transition={{ delay: 0.25 }}
                  className="pt-4"
                >
                  <button
                    onClick={() => {
                      trackCTAClick({
                        button_text: t.header.tryIt,
                        section: 'header-mobile',
                        destination: 'about',
                      })
                      setIsMobileMenuOpen(false)
                      const aboutSection = document.getElementById('about')
                      if (aboutSection) {
                        aboutSection.scrollIntoView({ behavior: 'smooth' })
                      }
                    }}
                    className="w-full px-6 py-3 bg-white text-black rounded-full text-base font-medium transition-all duration-300 hover:bg-white/90 cursor-pointer"
                  >
                    {t.header.tryIt}
                  </button>
                </motion.div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.header>

      {/* Spacer to prevent content from hiding under fixed header */}
      <div className="h-16 sm:h-20" />
    </>
  )
}
