'use client'

import { motion } from 'framer-motion'
import { useLanguage } from '@/lib/language-context'

export function LanguageSwitcher() {
  const { language, setLanguage } = useLanguage()

  return (
    <div className="relative flex items-center p-1 rounded-full bg-white/5 border border-white/10">
      {/* Sliding indicator */}
      <motion.div
        className="absolute top-1 bottom-1 rounded-full bg-white"
        animate={{
          left: language === 'ru' ? '4px' : 'calc(50% + 2px)',
          width: 'calc(50% - 6px)',
        }}
        transition={{
          type: "spring",
          stiffness: 500,
          damping: 35
        }}
      />

      <motion.button
        onClick={() => setLanguage('ru')}
        className={`relative z-10 px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
          language === 'ru'
            ? 'text-black'
            : 'text-white/60 hover:text-white'
        }`}
        whileTap={{ scale: 0.95 }}
      >
        RU
      </motion.button>
      <motion.button
        onClick={() => setLanguage('en')}
        className={`relative z-10 px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
          language === 'en'
            ? 'text-black'
            : 'text-white/60 hover:text-white'
        }`}
        whileTap={{ scale: 0.95 }}
      >
        EN
      </motion.button>
    </div>
  )
}
