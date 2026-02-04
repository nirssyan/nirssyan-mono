'use client'

import { motion } from 'framer-motion'
import { ArrowRight } from 'lucide-react'
import { useIntersectionTracking } from '@/hooks/use-intersection-tracking'
import { useMatomo } from '@/hooks/use-matomo'

const stats = [
  { value: "1K+", label: "Пользователей" },
  { value: "100", label: "Категорий" },
  { value: "500+", label: "Источников" }
]

const categories = [
  "Технологии",
  "Здоровье",
  "Наука",
  "Космос",
  "Экология",
  "Бизнес"
]

export function SocialProof() {
  const { trackCTAClick } = useMatomo()
  const sectionRef = useIntersectionTracking({
    sectionName: 'social-proof',
    threshold: 0.3,
    trackOnce: true
  })

  return (
    <section ref={sectionRef} className="py-16 sm:py-24 md:py-32 bg-black relative overflow-hidden">
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
        
        {/* Main content - split layout */}
        <div className="grid lg:grid-cols-2 gap-12 sm:gap-16 md:gap-20 items-center mb-16 sm:mb-24 md:mb-32">
          
          {/* Left: Social proof */}
          <motion.div
            initial={{ opacity: 0, x: -30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.8 }}
          >
            <h2 className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-bold text-white mb-8 sm:mb-10 md:mb-12 tracking-tight leading-none">
              Доверяют<br />тысячи<br />пользователей
            </h2>
            
            {/* Stats - minimal */}
            <div className="space-y-6 sm:space-y-8">
              {stats.map((stat, index) => (
                <motion.div
                  key={stat.label}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ duration: 0.6, delay: index * 0.1 }}
                  className="flex items-baseline gap-3 sm:gap-4 border-l-2 border-white/10 pl-4 sm:pl-6"
                >
                  <span className="text-3xl sm:text-4xl md:text-5xl font-bold text-white">
                    {stat.value}
                  </span>
                  <span className="text-base sm:text-lg text-white/40 font-light">
                    {stat.label}
                  </span>
                </motion.div>
              ))}
            </div>
          </motion.div>

          {/* Right: CTA */}
          <motion.div
            initial={{ opacity: 0, x: 30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.8 }}
            className="space-y-8 sm:space-y-10 md:space-y-12"
          >
            <div>
              <h3 className="text-3xl sm:text-4xl md:text-5xl font-bold text-white mb-4 sm:mb-5 md:mb-6 tracking-tight">
                Создайте свою<br />персональную ленту
              </h3>
              <p className="text-base sm:text-lg md:text-xl text-white/40 font-light leading-relaxed">
                Выберите темы — и получайте только то, что важно
              </p>
            </div>

            {/* Categories pills */}
            <div className="flex flex-wrap gap-2 sm:gap-3">
              {categories.map((category, index) => (
                <motion.div
                  key={category}
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ duration: 0.5, delay: index * 0.05 }}
                  className="px-4 sm:px-5 py-1.5 sm:py-2 bg-white/5 border border-white/10 rounded-full text-white/60 text-xs sm:text-sm font-light hover:bg-white/10 hover:border-white/20 transition-all duration-300"
                >
                  {category}
                </motion.div>
              ))}
            </div>

            {/* CTA Button */}
            <motion.button
              onClick={() => {
                trackCTAClick({
                  button_text: 'Попробовать бесплатно',
                  section: 'social-proof',
                  destination: 'about'
                })
                const aboutSection = document.getElementById('about')
                if (aboutSection) {
                  aboutSection.scrollIntoView({ behavior: 'smooth' })
                }
              }}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              className="group flex items-center justify-center w-full sm:w-auto gap-3 px-8 sm:px-10 py-4 sm:py-5 bg-white text-black rounded-full text-base sm:text-lg font-medium transition-all duration-500 hover:bg-gray-200 cursor-pointer"
            >
              <span>Попробовать бесплатно</span>
              <ArrowRight className="w-4 h-4 sm:w-5 sm:h-5 group-hover:translate-x-1 transition-transform" />
            </motion.button>

            {/* Trust indicator */}
            <p className="text-xs sm:text-sm text-white/30 font-light text-center sm:text-left">
              Присоединяйтесь к сообществу тех, кто уже экономит время с infatium
            </p>
          </motion.div>
        </div>

      </div>
    </section>
  )
}
