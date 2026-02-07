'use client'

import { useState, useRef, useEffect, memo } from 'react'
import { motion, useMotionValue, useSpring, useTransform, AnimatePresence } from 'framer-motion'
import {
  Layers,
  Bot,
  ScrollText,
  Volume2,
  TrendingUp,
  Quote
} from 'lucide-react'
import { useIntersectionTracking } from '@/hooks/use-intersection-tracking'
import { useMatomo } from '@/hooks/use-matomo'
import { useIsMobile } from '@/hooks/use-is-mobile'
import { useLanguage } from '@/lib/language-context'
import { throttle } from '@/lib/throttle'
import { useIsSafari } from '@/hooks/use-safari-detect'

const problemIcons = [Layers, Bot, ScrollText, Volume2]
const problemGradients = [
  "from-red-500/20 via-orange-500/20 to-yellow-500/20",
  "from-purple-500/20 via-violet-500/20 to-indigo-500/20",
  "from-cyan-500/20 via-teal-500/20 to-emerald-500/20",
  "from-pink-500/20 via-rose-500/20 to-red-500/20",
]

const sourceUrls = [
  "https://realnoevremya.ru/news/367324-cifrovoy-detoks-nabiraet-populyarnost-sredi-rossiyan",
  "https://foresight.hse.ru/news/961750598.html",
  undefined
]

// Floating Particles Component
const FloatingParticles = memo(({ isHovered }: { isHovered: boolean }) => {
  // Pre-generate random values for each particle to avoid hydration issues
  const [particles] = useState(() =>
    [...Array(4)].map(() => ({
      initialX: Math.random() * 100 - 50,
      initialY: Math.random() * 100 - 50,
      animateX1: Math.random() * 40 - 20,
      animateX2: Math.random() * 60 - 30,
    }))
  )

  return (
    <AnimatePresence>
      {isHovered && (
        <>
          {particles.map((particle, i) => (
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
                y: [0, -40, -80],
                x: [0, particle.animateX1, particle.animateX2],
                scale: [0, 1, 0.5]
              }}
              exit={{ opacity: 0 }}
              transition={{
                duration: 2.5,
                delay: i * 0.1,
                repeat: Infinity,
                repeatDelay: 0.5
              }}
              className="absolute w-1 h-1 bg-white/60 rounded-full pointer-events-none"
              style={{
                left: `${20 + i * 10}%`,
                top: '50%'
              }}
            />
          ))}
        </>
      )}
    </AnimatePresence>
  )
})

FloatingParticles.displayName = 'FloatingParticles'

type ProblemItem = {
  title: string
  description: string
  problem: string
  solution: string
}

// Problem Card Component with problem/solution structure
const ProblemCard = memo(({
  problem,
  index,
  icon: Icon,
  gradient,
  isMobile,
}: {
  problem: ProblemItem
  index: number
  icon: typeof Layers
  gradient: string
  isMobile: boolean
}) => {
  const cardRef = useRef<HTMLDivElement>(null)
  const rectRef = useRef<DOMRect | null>(null)
  const [isHovered, setIsHovered] = useState(false)

  const mouseX = useMotionValue(0)
  const mouseY = useMotionValue(0)

  const springConfig = { damping: 25, stiffness: 150 }
  const rotateX = useSpring(useTransform(mouseY, [-0.5, 0.5], [5, -5]), springConfig)
  const rotateY = useSpring(useTransform(mouseX, [-0.5, 0.5], [-5, 5]), springConfig)

  // Cache rect calculation - only needed on desktop
  useEffect(() => {
    if (isMobile) return
    if (cardRef.current) {
      rectRef.current = cardRef.current.getBoundingClientRect()
    }
  }, [isMobile])

  const handleMouseMove = throttle((e: React.MouseEvent<HTMLDivElement>) => {
    if (isMobile || !rectRef.current) return

    const rect = rectRef.current
    const centerX = rect.left + rect.width / 2
    const centerY = rect.top + rect.height / 2

    const percentX = (e.clientX - centerX) / (rect.width / 2)
    const percentY = (e.clientY - centerY) / (rect.height / 2)

    mouseX.set(percentX)
    mouseY.set(percentY)
  }, 16)

  const handleMouseLeave = () => {
    if (isMobile) return
    mouseX.set(0)
    mouseY.set(0)
    setIsHovered(false)
  }

  return (
    <motion.div
      ref={cardRef}
      initial={{ opacity: 0, y: 40 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-100px" }}
      transition={{ duration: 0.6, delay: index * 0.1 }}
      onMouseMove={isMobile ? undefined : handleMouseMove}
      onMouseEnter={isMobile ? undefined : () => setIsHovered(true)}
      onMouseLeave={isMobile ? undefined : handleMouseLeave}
      style={isMobile ? undefined : {
        rotateX,
        rotateY,
        transformStyle: "preserve-3d",
      }}
      className="group relative overflow-hidden rounded-2xl sm:rounded-3xl bg-gray-900/80 border border-white/10"
    >
      <motion.div
        className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500 rounded-2xl sm:rounded-3xl"
        style={{
          background: `linear-gradient(135deg, rgba(255,255,255,0.1), transparent, rgba(255,255,255,0.05))`,
        }}
      />

      <motion.div
        className={`absolute inset-0 bg-gradient-to-br ${gradient} opacity-0 group-hover:opacity-100 transition-opacity duration-700`}
      />

      <motion.div
        className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500"
        style={{
          background: 'radial-gradient(circle at 50% 0%, rgba(255,255,255,0.1), transparent 50%)',
        }}
      />

      <FloatingParticles isHovered={isHovered} />

      <div className="relative z-10 p-6 md:p-8 h-full flex flex-col">
        <motion.div
          className="relative mb-4 sm:mb-6"
          whileHover={{ scale: 1.1, rotate: 5 }}
          transition={{ type: "spring", stiffness: 400 }}
        >
          <motion.div
            className="absolute inset-0 rounded-2xl blur-xl opacity-0 group-hover:opacity-50 transition-opacity duration-500"
            style={{
              background: `linear-gradient(135deg, rgba(255,255,255,0.3), rgba(255,255,255,0.1))`,
            }}
          />
          <div className="relative w-14 h-14 sm:w-16 sm:h-16 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center group-hover:border-white/30 transition-colors duration-300">
            <Icon className="w-7 h-7 sm:w-8 sm:h-8 text-white/70 group-hover:text-white transition-colors duration-300" strokeWidth={1.5} />
          </div>
        </motion.div>

        <h3 className="font-bold text-white mb-3 tracking-tight text-xl sm:text-2xl">
          {problem.title}
        </h3>

        <p className="text-white/50 mb-4 font-light leading-relaxed text-sm sm:text-base">
          {problem.description}
        </p>

        <div className="space-y-3 mt-auto">
          <div className="flex items-start gap-3 group/item">
            <div className="mt-0.5 w-5 h-5 rounded-full bg-red-500/20 border border-red-500/30 flex items-center justify-center flex-shrink-0">
              <span className="text-red-400 text-xs">✕</span>
            </div>
            <span className="text-xs sm:text-sm text-white/40 group-hover/item:text-white/60 transition-colors font-light">
              {problem.problem}
            </span>
          </div>

          <div className="flex items-start gap-3 group/item">
            <div className="mt-0.5 w-5 h-5 rounded-full bg-emerald-500/20 border border-emerald-500/30 flex items-center justify-center flex-shrink-0">
              <span className="text-emerald-400 text-xs">✓</span>
            </div>
            <span className="text-xs sm:text-sm text-white/50 group-hover/item:text-white/80 transition-colors font-light">
              {problem.solution}
            </span>
          </div>
        </div>

        <div className="absolute top-6 right-6 text-6xl sm:text-7xl font-bold text-white/[0.02] group-hover:text-white/[0.05] transition-colors duration-300">
          {String(index + 1).padStart(2, '0')}
        </div>

      </div>
    </motion.div>
  )
})

ProblemCard.displayName = 'ProblemCard'

type StatItem = {
  value: string
  label: string
  source: string
}

// Statistics Card Component
function StatCard({
  stat,
  sourceUrl,
  onTrackClick
}: {
  stat: StatItem
  sourceUrl?: string
  onTrackClick?: (sourceText: string, url: string) => void
}) {
  return (
    <div className="text-center p-6 rounded-2xl bg-gray-800/60 border border-white/10 hover:border-white/20 transition-colors">
      <div className="text-4xl sm:text-5xl lg:text-6xl font-bold text-white mb-2">
        {stat.value}
      </div>
      <p className="text-white/60 text-sm sm:text-base font-light mb-2">{stat.label}</p>
      {sourceUrl ? (
        <a
          href={sourceUrl}
          target="_blank"
          rel="noopener noreferrer"
          onClick={() => onTrackClick?.(stat.source, sourceUrl)}
          className="text-white/30 text-xs hover:text-white/50 transition-colors"
        >
          {stat.source}
        </a>
      ) : (
        <span className="text-white/30 text-xs">{stat.source}</span>
      )}
    </div>
  )
}

export function Features() {
  const { t } = useLanguage()
  const { trackExternalLink } = useMatomo()
  const isMobile = useIsMobile()
  const isSafari = useIsSafari()
  const cursorRef = useRef<HTMLDivElement>(null)
  const sectionRef = useIntersectionTracking({
    sectionName: 'problems',
    threshold: 0.3,
    trackOnce: true,
  })

  const handleSourceClick = (sourceText: string, url: string) => {
    trackExternalLink({
      link_text: sourceText,
      destination: url,
      section: 'problems-stats'
    })
  }

  useEffect(() => {
    if (isMobile || isSafari) return

    const handleMouseMove = throttle((e: MouseEvent) => {
      if (cursorRef.current) {
        cursorRef.current.style.left = `${e.clientX - 200}px`
        cursorRef.current.style.top = `${e.clientY - 200}px`
      }
    }, 16)

    window.addEventListener('mousemove', handleMouseMove)
    return () => window.removeEventListener('mousemove', handleMouseMove)
  }, [isMobile, isSafari])

  return (
    <section
      ref={sectionRef}
      id="problems"
      className="relative pb-20 sm:pb-32 lg:pb-40 bg-black overflow-hidden"
    >

      {/* Seamless color gradient - animated on desktop, static on mobile */}
      <div
        className={`absolute inset-0 opacity-20 z-[0] ${isMobile ? '' : 'animate-gradient-shift blur-[60px]'}`}
        style={{
          background: isMobile
            ? 'linear-gradient(90deg, rgba(168,85,247,0.3) 0%, rgba(59,130,246,0.3) 50%, rgba(168,85,247,0.3) 100%)'
            : 'linear-gradient(90deg, rgba(168,85,247,0.3) 0%, rgba(59,130,246,0.3) 25%, rgba(6,182,212,0.3) 50%, rgba(236,72,153,0.3) 75%, rgba(168,85,247,0.3) 100%)',
          backgroundSize: isMobile ? '100% 100%' : '300% 100%',
          maskImage: 'linear-gradient(to bottom, black 0%, black 40%, transparent 100%)',
          WebkitMaskImage: 'linear-gradient(to bottom, black 0%, black 40%, transparent 100%)',
        }}
      />

      {/* Animated color blobs — disabled on Safari for GPU performance */}
      {!isMobile && !isSafari && (
        <div className="absolute inset-0">
          {/* Purple blob - top left */}
          <motion.div
            className="absolute w-[400px] h-[400px] rounded-full opacity-30 blur-[60px]"
            style={{
              background: 'radial-gradient(circle, rgba(168, 85, 247, 0.4) 0%, rgba(147, 51, 234, 0.2) 50%, transparent 100%)',
            }}
            animate={{
              x: ['-20%', '10%', '-20%'],
              y: ['-10%', '20%', '-10%'],
              scale: [1, 1.2, 1],
            }}
            transition={{
              duration: 20,
              repeat: Infinity,
              ease: 'easeInOut',
            }}
          />

          {/* Blue blob - top right */}
          <motion.div
            className="absolute right-0 w-[350px] h-[350px] rounded-full opacity-30 blur-[50px]"
            style={{
              background: 'radial-gradient(circle, rgba(59, 130, 246, 0.4) 0%, rgba(37, 99, 235, 0.2) 50%, transparent 100%)',
            }}
            animate={{
              x: ['10%', '-15%', '10%'],
              y: ['-15%', '15%', '-15%'],
              scale: [1, 1.15, 1],
            }}
            transition={{
              duration: 18,
              repeat: Infinity,
              ease: 'easeInOut',
              delay: 2,
            }}
          />
        </div>
      )}

      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8 }}
          className="text-center mb-12 sm:mb-16"
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.8 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6 }}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gray-800/60 border border-white/10 mb-6 sm:mb-8"
          >
            <TrendingUp className="w-4 h-4 text-white/60" />
            <span className="text-xs sm:text-sm text-white/60 font-light">{t.problems.badge}</span>
          </motion.div>

          <motion.h2
            className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-bold text-white mb-6 tracking-tight"
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            {t.problems.title}
          </motion.h2>

          <motion.p
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.6 }}
            className="text-base sm:text-lg md:text-xl text-white/50 max-w-3xl mx-auto font-light leading-relaxed"
          >
            {t.problems.subtitle}<br className="hidden sm:block" />
            {t.problems.subtitle2}
          </motion.p>
        </motion.div>

        {/* Statistics */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-6 mb-12 sm:mb-16"
        >
          {t.problems.stats.map((stat, index) => (
            <StatCard
              key={index}
              stat={stat}
              sourceUrl={sourceUrls[index]}
              onTrackClick={handleSourceClick}
            />
          ))}
        </motion.div>

        {/* Problems Grid */}
        <div className="grid md:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
          {t.problems.items.map((problem, index) => (
            <ProblemCard
              key={index}
              problem={problem}
              index={index}
              icon={problemIcons[index]}
              gradient={problemGradients[index]}
              isMobile={isMobile}
            />
          ))}
        </div>

        {/* Key insight */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ delay: 0.8 }}
          className="text-center mt-16 sm:mt-24"
        >
          <div className="inline-flex flex-col items-start gap-3 px-6 py-5 rounded-2xl bg-gray-800/60 border border-white/10 max-w-3xl">
            <div className="flex items-start gap-3">
              <Quote className="w-5 h-5 text-white/30 flex-shrink-0 mt-0.5" />
              <p className="text-sm sm:text-base text-white/60 font-light italic text-left">
                «{t.problems.insightParts.map((part, idx) => (
                  part.bold ? (
                    <span key={idx} className="text-white font-medium not-italic">{part.text}</span>
                  ) : (
                    <span key={idx}>{part.text}</span>
                  )
                ))}»
              </p>
            </div>
            <a
              href="https://www.youtube.com/watch?v=qjPH9njnaVU&t=767s"
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs sm:text-sm text-white/40 font-medium ml-8 hover:text-white/60 transition-colors"
            >
              {t.problems.insightAuthor}
            </a>
          </div>
        </motion.div>
      </div>

      {/* Cursor glow — direct DOM positioning, no React re-render */}
      {!isMobile && !isSafari && (
        <div
          ref={cursorRef}
          className="pointer-events-none fixed rounded-full blur-3xl opacity-20 animate-glow-pulse"
          style={{
            width: 400,
            height: 400,
            background: 'radial-gradient(circle, rgba(100, 150, 255, 0.3), transparent 70%)',
          }}
        />
      )}
    </section>
  )
}
