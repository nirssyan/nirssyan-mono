'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { Badge } from '@/components/ui/badge'
import {
  Terminal,
  Code,
  Cpu,
  Brain,
  Zap,
  Globe,
  BookOpen,
  Rocket,
  Leaf,
  TrendingUp
} from 'lucide-react'

const typingPhrases = [
  { text: "хочу ленту без политики", category: "Технологии" },
  { text: "хочу все про юристов", category: "Бизнес" },
  { text: "нужны новости про технологии", category: "Технологии" },
  { text: "покажи только научные статьи", category: "Наука" },
  { text: "хочу следить за ИИ новостями", category: "ИИ" },
  { text: "нужна лента про космос", category: "Космос" },
  { text: "покажи экологические новости", category: "Экология" },
  { text: "хочу новости про стартапы", category: "Бизнес" }
]

const categories = [
  { name: "Технологии", icon: Cpu, color: "from-blue-500 to-cyan-500" },
  { name: "ИИ", icon: Brain, color: "from-purple-500 to-pink-500" },
  { name: "Наука", icon: BookOpen, color: "from-green-500 to-emerald-500" },
  { name: "Космос", icon: Rocket, color: "from-indigo-500 to-blue-500" },
  { name: "Экология", icon: Leaf, color: "from-green-600 to-teal-500" },
  { name: "Бизнес", icon: TrendingUp, color: "from-orange-500 to-red-500" }
]

export function TypingText() {
  const [currentPhraseIndex, setCurrentPhraseIndex] = useState(0)
  const [displayedText, setDisplayedText] = useState('')
  const [isTyping, setIsTyping] = useState(true)
  const [showCursor, setShowCursor] = useState(true)

  const currentPhrase = typingPhrases[currentPhraseIndex]

  useEffect(() => {
    setDisplayedText('')
    setIsTyping(true)

    const text = currentPhrase.text
    let charIndex = 0

    const typeInterval = setInterval(() => {
      if (charIndex < text.length) {
        setDisplayedText(text.slice(0, charIndex + 1))
        charIndex++
      } else {
        clearInterval(typeInterval)
        setIsTyping(false)

        // Pause before erasing
        setTimeout(() => {
          const eraseInterval = setInterval(() => {
            if (charIndex > 0) {
              charIndex--
              setDisplayedText(text.slice(0, charIndex))
            } else {
              clearInterval(eraseInterval)
              setCurrentPhraseIndex((prev) => (prev + 1) % typingPhrases.length)
            }
          }, 50)
        }, 2000)
      }
    }, 100)

    return () => clearInterval(typeInterval)
  }, [currentPhraseIndex, currentPhrase.text])

  // Cursor blinking effect
  useEffect(() => {
    const cursorInterval = setInterval(() => {
      setShowCursor(prev => !prev)
    }, 500)

    return () => clearInterval(cursorInterval)
  }, [])

  return (
    <section className="py-20 bg-gradient-to-br from-slate-900 via-gray-900 to-slate-900 relative overflow-hidden">
      {/* Animated background elements */}
      <div className="absolute inset-0">
        <div
          className="absolute top-1/4 left-1/4 w-32 h-32 border border-blue-500/20 rounded-full animate-shimmer-rotate"
          style={{ animationDuration: '20s' }}
        />
        <div
          className="absolute bottom-1/4 right-1/4 w-24 h-24 border border-purple-500/20 rounded-full animate-shimmer-rotate"
          style={{ animationDuration: '15s', animationDirection: 'reverse' }}
        />
      </div>

      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8 }}
          className="text-center mb-16"
        >
          <Badge variant="gradient" className="mb-4">
            Персонализация через ИИ
          </Badge>
          <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">
            Создайте свою ленту новостей
          </h2>
          <p className="text-xl text-gray-300 max-w-3xl mx-auto">
            Просто скажите ИИ, какие новости вас интересуют, и получите персонализированную подборку
          </p>
        </motion.div>

        <div className="grid lg:grid-cols-2 gap-16 items-center">
          {/* Terminal mockup */}
          <motion.div
            initial={{ opacity: 0, x: -50 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.8 }}
            className="relative"
          >
            <div className="bg-black/90 rounded-2xl border border-slate-700 p-6 shadow-2xl">
              {/* Terminal header */}
              <div className="flex items-center gap-2 mb-6 pb-4 border-b border-slate-700">
                <div className="flex gap-2">
                  <div className="w-3 h-3 bg-red-500 rounded-full"></div>
                  <div className="w-3 h-3 bg-yellow-500 rounded-full"></div>
                  <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                </div>
                <span className="text-green-400 text-sm font-mono ml-4">
                  infatium-ai:~$ personalize_news
                </span>
              </div>

              {/* Terminal content */}
              <div className="space-y-4 font-mono text-sm">
                <div className="text-green-400">
                  <span className="text-blue-400">infatium@ai</span>:~$ <span className="text-white">Расскажите, какие новости вас интересуют?</span>
                </div>

                <div className="text-gray-300">
                  <span className="text-blue-400">user</span>:~$ <span className="text-green-400">{displayedText}</span>
                  {isTyping && showCursor && (
                    <motion.span
                      animate={{ opacity: [1, 0, 1] }}
                      transition={{ duration: 1, repeat: Infinity }}
                      className="inline-block w-2 h-4 bg-blue-400 ml-1"
                    />
                  )}
                </div>

                {!isTyping && (
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.5 }}
                    className="text-blue-400"
                  >
                    <span className="text-blue-400">infatium@ai</span>:~$ Создаю персонализированную ленту...
                    <motion.div
                      animate={{ opacity: [0.3, 1, 0.3] }}
                      transition={{ duration: 1.5, repeat: Infinity }}
                      className="inline-block ml-2"
                    >
                      █
                    </motion.div>
                  </motion.div>
                )}
              </div>

              {/* Terminal footer */}
              <div className="mt-6 pt-4 border-t border-slate-700">
                <div className="flex items-center gap-2 text-xs text-gray-500">
                  <Terminal className="w-4 h-4" />
                  <span>Infatium Terminal v2.1.0</span>
                  <span className="ml-auto">AI-Powered</span>
                </div>
              </div>
            </div>

            <div className="absolute -top-6 -left-6 bg-slate-800/90 p-3 rounded-lg border border-slate-700">
              <Code className="w-6 h-6 text-green-400" />
            </div>

            <div className="absolute -bottom-6 -right-6 bg-slate-800/90 p-3 rounded-lg border border-slate-700">
              <Zap className="w-6 h-6 text-yellow-400" />
            </div>
          </motion.div>

          {/* Categories */}
          <motion.div
            initial={{ opacity: 0, x: 50 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.8 }}
            className="space-y-8"
          >
            <div>
              <h3 className="text-2xl font-bold text-white mb-6">
                Доступные категории
              </h3>
              <div className="grid grid-cols-2 gap-4">
                {categories.map((category, index) => (
                  <motion.div
                    key={category.name}
                    initial={{ opacity: 0, scale: 0.8 }}
                    whileInView={{ opacity: 1, scale: 1 }}
                    viewport={{ once: true }}
                    transition={{ duration: 0.6, delay: index * 0.1 }}
                    whileHover={{ scale: 1.05, y: -5 }}
                    className={`relative p-4 rounded-xl bg-gradient-to-r ${category.color} text-white cursor-pointer transition-all duration-300 hover:shadow-lg`}
                  >
                    <div className="flex items-center gap-3">
                      <category.icon className="w-6 h-6" />
                      <span className="font-semibold">{category.name}</span>
                    </div>
                    <div className="absolute inset-0 bg-white/10 opacity-0 hover:opacity-100 transition-opacity duration-300 rounded-xl" />
                  </motion.div>
                ))}
              </div>
            </div>

            {/* Current phrase highlight */}
            <motion.div
              key={currentPhraseIndex}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5 }}
              className="p-6 bg-slate-800/50 rounded-xl border border-slate-700"
            >
              <div className="flex items-center gap-3 mb-3">
                <Globe className="w-5 h-5 text-blue-400" />
                <span className="text-white font-medium">Пример запроса:</span>
              </div>
              <p className="text-gray-300 italic">
                &ldquo;{currentPhrase.text}&rdquo;
              </p>
              <div className="mt-3">
                <Badge
                  variant="gradient"
                  className={`bg-gradient-to-r ${categories.find(c => c.name === currentPhrase.category)?.color}`}
                >
                  {currentPhrase.category}
                </Badge>
              </div>
            </motion.div>

            {/* Stats */}
            <div className="grid grid-cols-3 gap-4 text-center">
              {[
                { label: "Категорий", value: "6" },
                { label: "Источников", value: "50+" },
                { label: "Языков", value: "2" }
              ].map((stat, index) => (
                <motion.div
                  key={stat.label}
                  initial={{ opacity: 0, scale: 0.8 }}
                  whileInView={{ opacity: 1, scale: 1 }}
                  viewport={{ once: true }}
                  transition={{ duration: 0.6, delay: index * 0.1 }}
                  className="p-4 bg-slate-800/30 rounded-lg border border-slate-700"
                >
                  <div className="text-2xl font-bold text-white mb-1">
                    {stat.value}
                  </div>
                  <div className="text-sm text-gray-400">
                    {stat.label}
                  </div>
                </motion.div>
              ))}
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  )
}
