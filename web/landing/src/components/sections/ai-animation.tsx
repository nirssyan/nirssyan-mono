'use client'

import { useState, useEffect, useRef } from 'react'
import { motion, AnimatePresence, useScroll, useTransform, MotionValue } from 'framer-motion'
import {
  ArrowRight,
  Sparkles,
  Send,
  Code
} from 'lucide-react'
import { useIntersectionTracking } from '@/hooks/use-intersection-tracking'
import { useMatomo } from '@/hooks/use-matomo'
import { useLanguage } from '@/lib/language-context'
import { useIsSafari } from '@/hooks/use-safari-detect'

const availableSources = [
  {
    id: 'telegram',
    name: 'Telegram',
    description: 'Каналы и чаты',
    icon: Send,
    color: '#229ED9',
    exampleContent: '@durov, @techcrunch_ru'
  },
  {
    id: 'rss',
    name: 'Любой источник',
    description: 'Сайты, блоги, RSS',
    icon: Code,
    color: '#FF9500',
    exampleContent: 'Блоги, новости, подкасты'
  }
]

interface Post {
  id: number
  sourceId: string
  source: string
  topic: string
  category: string
  isAd: boolean
  isDuplicate: boolean
  isSpam: boolean
  timestamp: string
  brief: string
  fullText: string
}

const allPosts: Post[] = [
  // Telegram посты (6 штук)
  {
    id: 1,
    sourceId: 'telegram',
    source: "Telegram",
    topic: 'ai',
    category: "ИИ",
    isAd: false,
    isDuplicate: false,
    isSpam: false,
    timestamp: "1 час назад",
    brief: "OpenAI выпустила GPT-5 с революционными возможностями",
    fullText: "OpenAI официально представила GPT-5 — новую флагманскую модель с возможностями reasoning на уровне человека. Модель способна решать сложные математические задачи, писать научные статьи и проводить многошаговый анализ данных. По словам Сэма Альтмана, GPT-5 прошла тесты на уровне PhD в физике, математике и биологии. API доступен для разработчиков с сегодняшнего дня."
  },
  {
    id: 2,
    sourceId: 'telegram',
    source: "Telegram",
    topic: 'crypto',
    category: "Крипто",
    isAd: true,
    isDuplicate: false,
    isSpam: false,
    timestamp: "2 часа назад",
    brief: "🔥 Успей купить новый токен со скидкой 90%!",
    fullText: "🚀 МЕГА-ВОЗМОЖНОСТЬ! Новый токен $MOONSHOT уже на пресейле! Скидка 90% только первым 1000 инвесторам! Наша команда из бывших сотрудников Google и Tesla. Листинг на Binance через 2 недели! Не упусти шанс стать миллионером! Ссылка в био 👆"
  },
  {
    id: 3,
    sourceId: 'telegram',
    source: "Telegram",
    topic: 'startups',
    category: "Стартапы",
    isAd: false,
    isDuplicate: false,
    isSpam: false,
    timestamp: "3 часа назад",
    brief: "Y Combinator выбрал 200 стартапов для батча 2025",
    fullText: "Y Combinator объявил список участников зимнего батча 2025 года. Из 200 отобранных стартапов 45 работают в сфере искусственного интеллекта, 30 — в fintech, 25 — в healthtech. Примечательно, что 12 проектов основаны выходцами из России и СНГ. Средний возраст основателей — 28 лет. Demo Day запланирован на март 2025 года."
  },
  {
    id: 4,
    sourceId: 'telegram',
    source: "Telegram",
    topic: 'ai',
    category: "ИИ",
    isAd: false,
    isDuplicate: true,
    isSpam: false,
    timestamp: "4 часа назад",
    brief: "GPT-5 от OpenAI — прорыв в AI",
    fullText: "Компания OpenAI анонсировала выход GPT-5. Новая модель показывает значительное улучшение в задачах рассуждения и способна решать сложные научные проблемы. Подробности на сайте OpenAI."
  },
  {
    id: 5,
    sourceId: 'telegram',
    source: "Telegram",
    topic: 'tech',
    category: "Технологии",
    isAd: true,
    isDuplicate: false,
    isSpam: false,
    timestamp: "5 часов назад",
    brief: "Лучший VPN 2025 года — скидка 70%!",
    fullText: "⚡ NordVPN — выбор миллионов! Защити свои данные прямо сейчас. Скидка 70% + 3 месяца бесплатно при годовой подписке. Более 5000 серверов в 60 странах. Скорость до 10 Гбит/с. Используй промокод TECHBLOG для дополнительной скидки. Переходи по ссылке!"
  },
  {
    id: 6,
    sourceId: 'telegram',
    source: "Telegram",
    topic: 'tech',
    category: "Технологии",
    isAd: false,
    isDuplicate: false,
    isSpam: false,
    timestamp: "6 часов назад",
    brief: "Apple анонсировала новые MacBook с M4",
    fullText: "Apple представила обновлённую линейку MacBook Pro на базе чипа M4. Новые ноутбуки получили на 50% более быстрый CPU и в 2 раза более производительный GPU по сравнению с M3. Время автономной работы увеличено до 22 часов. Базовая модель 14\" стартует от $1599, поставки начнутся на следующей неделе."
  },
  // Веб посты (6 штук)
  {
    id: 7,
    sourceId: 'rss',
    source: "Веб",
    topic: 'ai',
    category: "ИИ",
    isAd: false,
    isDuplicate: false,
    isSpam: false,
    timestamp: "1 час назад",
    brief: "Claude показывает улучшение в понимании кода",
    fullText: "Anthropic выпустила крупное обновление Claude, значительно улучшающее способности модели в анализе и генерации кода. Согласно внутренним бенчмаркам, точность выполнения задач по программированию выросла на 40%. Claude теперь лучше понимает контекст больших кодовых баз, может отлаживать сложные ошибки и предлагать оптимизации. Особенно заметны улучшения в работе с Python, TypeScript и Rust."
  },
  {
    id: 8,
    sourceId: 'rss',
    source: "Веб",
    topic: 'tech',
    category: "Технологии",
    isAd: true,
    isDuplicate: false,
    isSpam: false,
    timestamp: "2 часа назад",
    brief: "Курсы программирования со скидкой 50%",
    fullText: "🎓 Skillbox приглашает на курсы веб-разработки! Скидка 50% до конца месяца. Программы от Junior до Senior: React, Node.js, Python, DevOps. Диплом государственного образца. Помощь в трудоустройстве — 87% выпускников находят работу в первые 3 месяца. Рассрочка 0% на 24 месяца. Запишись на бесплатный вебинар!"
  },
  {
    id: 9,
    sourceId: 'rss',
    source: "Веб",
    topic: 'science',
    category: "Наука",
    isAd: false,
    isDuplicate: false,
    isSpam: false,
    timestamp: "3 часа назад",
    brief: "Квантовый компьютер с 1000 кубитами",
    fullText: "IBM объявила о создании квантового процессора Condor с 1121 кубитами — это первый процессор, преодолевший барьер в 1000 кубитов. Новый чип использует улучшенную архитектуру подавления ошибок, что позволяет выполнять вычисления с беспрецедентной точностью. Компания планирует интегрировать Condor в облачную платформу IBM Quantum в первом квартале 2025 года."
  },
  {
    id: 10,
    sourceId: 'rss',
    source: "Веб",
    topic: 'ai',
    category: "ИИ",
    isAd: false,
    isDuplicate: true,
    isSpam: false,
    timestamp: "4 часа назад",
    brief: "Anthropic улучшила Claude для работы с кодом",
    fullText: "Anthropic представила обновление своей модели Claude с улучшенными возможностями работы с программным кодом. Новая версия показывает прирост производительности на 40% в задачах анализа кода."
  },
  {
    id: 11,
    sourceId: 'rss',
    source: "Веб",
    topic: 'startups',
    category: "Стартапы",
    isAd: false,
    isDuplicate: false,
    isSpam: false,
    timestamp: "5 часов назад",
    brief: "Стартап привлёк $10M на развитие AI-платформы",
    fullText: "Российский стартап Neural Labs закрыл раунд Series A на $10 млн от Sequoia Capital и местных инвесторов. Компания разрабатывает платформу для автоматизации бизнес-процессов с использованием LLM. Среди клиентов — Сбербанк, Яндекс и несколько крупных ритейлеров. Инвестиции пойдут на расширение команды до 50 человек и выход на рынки Европы и Азии."
  },
  {
    id: 12,
    sourceId: 'rss',
    source: "Веб",
    topic: 'tech',
    category: "Технологии",
    isAd: false,
    isDuplicate: true,
    isSpam: false,
    timestamp: "6 часов назад",
    brief: "Apple представила MacBook на чипе M4",
    fullText: "Apple показала новые MacBook Pro с процессором M4. Производительность выросла на 50% по сравнению с предыдущим поколением. Цены начинаются от $1599."
  }
]

// ============= Feed Card Component (2025 Style) =============
function FeedCard({
  feed,
  opacity,
  translations,
  isMobile = false,
  onTrackTabChange
}: {
  feed: Post
  opacity: MotionValue<number>
  translations: DemoTranslations
  isMobile?: boolean
  onTrackTabChange?: (tab: 'brief' | 'full') => void
}) {
  const [activeTab, setActiveTab] = useState<'brief' | 'full'>('brief')
  const [isHovered, setIsHovered] = useState(false)

  const isSafari = useIsSafari()

  const [particles] = useState(() =>
    [...Array(isMobile ? 0 : 5)].map(() => ({
      initialX: Math.random() * 100 - 50,
      initialY: Math.random() * 100 - 50,
    }))
  )

  // Плавное появление карточек с задержкой
  const cardOpacity = useTransform(
    opacity,
    [0, 0.5, 1],
    [0, 0, 1]
  )

  return (
    <motion.div
      style={{
        opacity: cardOpacity,
        y: useTransform(opacity, [0, 1], [20, 0])
      }}
      className="relative group"
      onHoverStart={() => setIsHovered(true)}
      onHoverEnd={() => setIsHovered(false)}
    >
      {/* Main card with gradient border */}
      <motion.div
        whileHover={{ x: 4 }}
        transition={{ type: "spring", stiffness: 300, damping: 25 }}
        className="relative bg-[#1a1a2e]/90 rounded-xl sm:rounded-2xl p-4 sm:p-5 overflow-hidden border border-white/10"
      >
        {/* Animated gradient border on hover */}
        <motion.div
          className="absolute inset-0 rounded-xl sm:rounded-2xl opacity-0 pointer-events-none"
          animate={{
            opacity: isHovered ? 1 : 0,
            background: isHovered
              ? 'linear-gradient(135deg, rgba(255,255,255,0.1) 0%, transparent 50%, rgba(255,255,255,0.05) 100%)'
              : 'transparent'
          }}
          transition={{ duration: 0.4 }}
        />

        {/* Glow effect */}
        <AnimatePresence>
          {isHovered && (
            <motion.div
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 0.15, scale: 1 }}
              exit={{ opacity: 0, scale: 0.8 }}
              transition={{ duration: 0.3 }}
              className="absolute inset-0 bg-white/5 blur-2xl pointer-events-none"
            />
          )}
        </AnimatePresence>

        {/* Header */}
        <motion.div layout="position" className="flex items-start justify-between mb-4">
          {/* Source info */}
          <motion.div layout="position" className="flex items-center gap-2">
            <motion.div
              className="w-7 h-7 rounded-lg bg-white/5 flex items-center justify-center border border-white/10"
              whileHover={{ scale: 1.1, rotate: 5 }}
              transition={{ type: "spring", stiffness: 400 }}
            >
              <Sparkles className="w-3.5 h-3.5 text-white/70" />
            </motion.div>
            <div>
              <div className="flex items-center gap-2">
                <motion.span
                  className="text-white text-xs font-semibold"
                  whileHover={{ scale: 1.05 }}
                >
                  {feed.source}
                </motion.span>
                <span className="text-white/20 text-[10px]">•</span>
                <span className="text-white/50 text-[10px] font-medium">{feed.category}</span>
              </div>
              <span className="text-white/40 text-[10px]">{feed.timestamp}</span>
            </div>
          </motion.div>

          {/* Modern toggle switch with glow */}
          <motion.div
                       className="relative flex items-center bg-white/[0.02] rounded-full p-1 border border-white/10"
          >
            {/* Animated glow background */}
            <motion.div
              className="absolute top-0.5 bottom-0.5 rounded-full"
              animate={{
                left: activeTab === 'brief' ? '2px' : 'calc(50% - 2px)',
                width: 'calc(50% + 2px)',
                background: 'linear-gradient(135deg, rgba(255,255,255,0.15), rgba(255,255,255,0.05))',
                boxShadow: '0 0 20px rgba(255,255,255,0.2), inset 0 1px 0 rgba(255,255,255,0.2)'
              }}
              transition={{
                type: "spring",
                stiffness: 500,
                damping: 35
              }}
            />

            <motion.button
              onClick={() => {
                setActiveTab('brief')
                onTrackTabChange?.('brief')
              }}
              whileTap={{ scale: 0.95 }}
              className={`relative z-10 px-5 py-1.5 text-[10px] font-semibold rounded-full transition-all duration-200 ${
                activeTab === 'brief'
                  ? 'text-white'
                  : 'text-white/40 hover:text-white/70'
              }`}
            >
              {translations.briefTab}
            </motion.button>
            <motion.button
              onClick={() => {
                setActiveTab('full')
                onTrackTabChange?.('full')
              }}
              whileTap={{ scale: 0.95 }}
              className={`relative z-10 px-5 py-1.5 text-[10px] font-semibold rounded-full transition-all duration-200 ${
                activeTab === 'full'
                  ? 'text-white'
                  : 'text-white/40 hover:text-white/70'
              }`}
            >
              {translations.fullTab}
            </motion.button>
          </motion.div>
        </motion.div>

        {/* Content with smooth height transition */}
        <motion.div layout="position" className="relative overflow-hidden">
          <AnimatePresence mode="wait" initial={false}>
            {activeTab === 'brief' ? (
              <motion.div
                key="brief"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{
                  duration: 0.4,
                  ease: [0.25, 0.1, 0.25, 1]
                }}
              >
                <p className="text-white/90 text-sm sm:text-base font-medium leading-relaxed tracking-tight">
                  {feed.brief}
                </p>
              </motion.div>
            ) : (
              <motion.div
                key="full"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{
                  duration: 0.4,
                  ease: [0.25, 0.1, 0.25, 1]
                }}
              >
                <p className="text-white/70 text-xs sm:text-sm leading-relaxed font-light tracking-wide">
                  {feed.fullText}
                </p>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>

        {/* Floating particles on hover — reduced on Safari */}
        <AnimatePresence>
          {isHovered && !isSafari && (
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
                    y: [0, -20, -40],
                    scale: [0, 1, 0.5]
                  }}
                  exit={{ opacity: 0 }}
                  transition={{
                    duration: 2,
                    delay: i * 0.1,
                    repeat: Infinity,
                    repeatDelay: 1
                  }}
                  className="absolute w-1 h-1 bg-white/40 rounded-full pointer-events-none"
                  style={{
                    left: `${20 + i * 15}%`,
                    top: '50%'
                  }}
                />
              ))}
            </>
          )}
        </AnimatePresence>

        {/* Radial gradient hover effect */}
        <motion.div
          className="absolute inset-0 rounded-xl sm:rounded-2xl opacity-0 pointer-events-none"
          animate={{
            opacity: isHovered ? 0.05 : 0
          }}
          style={{
            background: 'radial-gradient(circle at 50% 50%, rgba(255,255,255,0.1), transparent 70%)'
          }}
          transition={{ duration: 0.3 }}
        />
      </motion.div>
    </motion.div>
  )
}

// ============= Toggle Switch Component =============
function ToggleSwitch({
  enabled,
  onToggle,
  onTrack
}: {
  enabled: boolean
  onToggle: () => void
  onTrack?: (newState: boolean) => void
}) {
  return (
    <motion.button
      onClick={() => {
        onTrack?.(!enabled)
        onToggle()
      }}
      className="relative w-12 h-7 rounded-full bg-white/5 border border-white/10 p-1 flex-shrink-0"
      whileTap={{ scale: 0.95 }}
    >
      <motion.div
        className="absolute inset-0 rounded-full"
        animate={{
          background: enabled
            ? 'linear-gradient(135deg, rgba(255,255,255,0.15), rgba(255,255,255,0.05))'
            : 'transparent',
          boxShadow: enabled
            ? '0 0 10px rgba(255,255,255,0.2)'
            : 'none'
        }}
        transition={{ duration: 0.3 }}
      />
      <motion.div
        className="relative w-5 h-5 rounded-full bg-white"
        animate={{
          x: enabled ? 20 : 0,
          opacity: enabled ? 1 : 0.6
        }}
        transition={{ type: "spring", stiffness: 500, damping: 30 }}
      />
    </motion.button>
  )
}

// ============= Topic Chip Component =============
function TopicChip({
  label,
  selected,
  onToggle,
  delay = 0,
  onTrack
}: {
  label: string
  selected: boolean
  onToggle: () => void
  delay?: number
  onTrack?: (topicLabel: string, newState: boolean) => void
}) {
  return (
    <motion.button
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.3, delay }}
      whileHover={{ scale: 1.05 }}
      whileTap={{ scale: 0.95 }}
      onClick={() => {
        onTrack?.(label, !selected)
        onToggle()
      }}
      className={`px-3 py-1.5 rounded-full text-xs font-medium transition-all duration-300 ${
        selected
          ? 'bg-white text-black'
          : 'bg-white/5 text-white/60 border border-white/10 hover:border-white/20'
      }`}
    >
      {label}
    </motion.button>
  )
}

// ============= Post Preview Mini Card =============
function PostPreviewMini({
  post,
  index,
  translations
}: {
  post: Post
  index: number
  translations: DemoTranslations
}) {
  const getBadge = () => {
    if (post.isAd) return { label: translations.ad, color: 'text-red-400 bg-red-500/10' }
    if (post.isDuplicate) return { label: translations.duplicate, color: 'text-yellow-400 bg-yellow-500/10' }
    if (post.isSpam) return { label: translations.spam, color: 'text-orange-400 bg-orange-500/10' }
    return null
  }

  const badge = getBadge()

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, delay: index * 0.1 }}
      className="py-2.5 px-3 rounded-lg bg-white/[0.02] border border-white/5"
    >
      <div className="flex items-start justify-between gap-2">
        <p className="text-white/70 text-sm line-clamp-1 flex-1">{post.brief}</p>
        {badge && (
          <span className={`px-2 py-0.5 rounded text-xs font-medium whitespace-nowrap ${badge.color}`}>
            {badge.label}
          </span>
        )}
      </div>
    </motion.div>
  )
}

type DemoTranslations = {
  sourceSelection: string
  of: string
  disabled: string
  settingsTitle: string
  willBeFiltered: string
  contentFilters: string
  topics: string
  customPrompt: string
  customPromptPlaceholder: string
  customPromptHint: string
  yourFeed: string
  posts: string
  noPostsTitle: string
  noPostsHint: string
  allNewsVerified: string
  ad: string
  duplicate: string
  spam: string
  briefTab: string
  fullTab: string
}

type SourceTranslations = {
  telegram: { name: string; description: string }
  rss: { name: string; description: string }
}

// ============= Source Selection Demo Component =============
function SourceSelectionDemo({
  enabledSources,
  setEnabledSources,
  translations,
  sourceTranslations,
  onTrackToggle
}: {
  enabledSources: Record<string, boolean>
  setEnabledSources: React.Dispatch<React.SetStateAction<Record<string, boolean>>>
  translations: DemoTranslations
  sourceTranslations: SourceTranslations
  onTrackToggle?: (sourceName: string, enabled: boolean) => void
}) {
  const handleToggle = (sourceId: string) => {
    setEnabledSources(prev => ({ ...prev, [sourceId]: !prev[sourceId] }))
  }

  const enabledCount = Object.values(enabledSources).filter(Boolean).length

  const getSourcePosts = (sourceId: string) => {
    return allPosts.filter(post => post.sourceId === sourceId).slice(0, 6)
  }

  const sourcesWithTranslations = availableSources.map(source => ({
    ...source,
    name: sourceTranslations[source.id as keyof SourceTranslations]?.name || source.name,
    description: sourceTranslations[source.id as keyof SourceTranslations]?.description || source.description,
  }))

  return (
    <div className="max-w-5xl mx-auto">
      <div className="mb-4 pb-4 border-b border-white/5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-2 h-2 bg-white rounded-full animate-pulse-dot" />
            <span className="text-white/60 text-xs font-light">{translations.sourceSelection}</span>
          </div>
          <span className="text-white/30 text-[10px] font-light">
            {enabledCount} {translations.of} {availableSources.length}
          </span>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {sourcesWithTranslations.map((source, index) => {
          const sourcePosts = getSourcePosts(source.id)
          const isEnabled = enabledSources[source.id] || false

          return (
            <motion.div
              key={source.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: index * 0.1 }}
              className={`relative bg-[#1a1a2e]/90 rounded-xl p-3 border transition-all duration-300 flex flex-col ${
                isEnabled
                  ? 'border-white/20 bg-white/5'
                  : 'border-white/10'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <div
                    className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
                    style={{ backgroundColor: `${source.color}20` }}
                  >
                    <source.icon
                      className="w-4 h-4"
                      style={{ color: source.color }}
                    />
                  </div>

                  <div className="min-w-0">
                    <h4 className="text-white text-sm font-semibold truncate">{source.name}</h4>
                    <p className="text-white/40 text-xs truncate">{source.description}</p>
                  </div>
                </div>

                <ToggleSwitch
                  enabled={isEnabled}
                  onToggle={() => handleToggle(source.id)}
                  onTrack={(newState) => onTrackToggle?.(source.name, newState)}
                />
              </div>

              <div className="flex-1 space-y-1.5 min-h-[60px]">
                <AnimatePresence>
                  {isEnabled && sourcePosts.map((post, postIndex) => (
                    <PostPreviewMini key={post.id} post={post} index={postIndex} translations={translations} />
                  ))}
                </AnimatePresence>
                {!isEnabled && (
                  <div className="text-white/20 text-[10px] text-center py-4">
                    {translations.disabled}
                  </div>
                )}
              </div>
            </motion.div>
          )
        })}
      </div>
    </div>
  )
}

type SettingsType = {
  contentFilters: Array<{ id: string; label: string; enabled: boolean }>
  topicFilters: Array<{ id: string; label: string; selected: boolean }>
  customPrompt: string
}

// ============= Settings Demo Component =============
function SettingsDemo({
  settings,
  setSettings,
  posts,
  enabledSources,
  translations,
  onTrackFilterToggle,
  onTrackTopicToggle
}: {
  settings: SettingsType
  setSettings: React.Dispatch<React.SetStateAction<SettingsType>>
  posts: Post[]
  enabledSources: Record<string, boolean>
  translations: DemoTranslations
  onTrackFilterToggle?: (filterLabel: string, enabled: boolean) => void
  onTrackTopicToggle?: (topicLabel: string, selected: boolean) => void
}) {
  const toggleContentFilter = (id: string) => {
    setSettings(prev => ({
      ...prev,
      contentFilters: prev.contentFilters.map(f =>
        f.id === id ? { ...f, enabled: !f.enabled } : f
      )
    }))
  }

  const toggleTopic = (id: string) => {
    setSettings(prev => ({
      ...prev,
      topicFilters: prev.topicFilters.map(f =>
        f.id === id ? { ...f, selected: !f.selected } : f
      )
    }))
  }

  const getFilteredCount = () => {
    const sourcePosts = posts.filter(p => enabledSources[p.sourceId])
    const selectedTopics = settings.topicFilters.filter(t => t.selected).map(t => t.id)

    const filteredOut = sourcePosts.filter(post => {
      if (settings.contentFilters.find(f => f.id === 'no-ads')?.enabled && post.isAd) return true
      if (settings.contentFilters.find(f => f.id === 'no-duplicates')?.enabled && post.isDuplicate) return true
      if (settings.contentFilters.find(f => f.id === 'no-spam')?.enabled && post.isSpam) return true

      if (selectedTopics.length === 0 || !selectedTopics.includes(post.topic)) return true

      return false
    })
    return filteredOut.length
  }

  const filteredCount = getFilteredCount()
  const totalFromSources = posts.filter(p => enabledSources[p.sourceId]).length

  return (
    <div className="max-w-4xl mx-auto">
      <div className="mb-4 pb-4 border-b border-white/5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-2 h-2 bg-white rounded-full animate-pulse-dot" />
            <span className="text-white/60 text-xs font-light">{translations.settingsTitle}</span>
          </div>
          <motion.span
            key={filteredCount}
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            className="text-white/40 text-[10px] font-light"
          >
            {translations.willBeFiltered}: <span className="text-white/60">{filteredCount}</span> {translations.of} {totalFromSources}
          </motion.span>
        </div>
      </div>

      <div className="space-y-6">
        {/* Content Filters */}
        <div>
          <p className="text-white/40 text-xs uppercase tracking-wider mb-3">
            {translations.contentFilters}
          </p>
          <div className="space-y-2">
            {settings.contentFilters.map((filter, index) => (
              <motion.div
                key={filter.id}
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.3, delay: index * 0.1 }}
                className="flex items-center justify-between py-2 px-3 rounded-lg bg-white/[0.02] border border-white/5"
              >
                <span className="text-white/70 text-sm">{filter.label}</span>
                <ToggleSwitch
                  enabled={filter.enabled}
                  onToggle={() => toggleContentFilter(filter.id)}
                  onTrack={(newState) => onTrackFilterToggle?.(filter.label, newState)}
                />
              </motion.div>
            ))}
          </div>
        </div>

        {/* Topic Filters */}
        <div>
          <p className="text-white/40 text-xs uppercase tracking-wider mb-3">
            {translations.topics}
          </p>
          <div className="flex flex-wrap gap-2">
            {settings.topicFilters.map((topic, index) => (
              <TopicChip
                key={topic.id}
                label={topic.label}
                selected={topic.selected}
                onToggle={() => toggleTopic(topic.id)}
                delay={index * 0.05}
                onTrack={onTrackTopicToggle}
              />
            ))}
          </div>
        </div>

      </div>
    </div>
  )
}

// ============= Filtered Feed Demo Component =============
function FilteredFeedDemo({
  posts,
  enabledSources,
  settings,
  translations,
  isMobile = false,
  onTrackTabChange
}: {
  posts: Post[]
  enabledSources: Record<string, boolean>
  settings: SettingsType
  translations: DemoTranslations
  isMobile?: boolean
  onTrackTabChange?: (tab: 'brief' | 'full') => void
}) {
  const staticOpacity = useTransform(() => 1)

  const selectedTopics = settings.topicFilters.filter(t => t.selected).map(t => t.id)

  const filteredPosts = posts.filter(post => {
    if (!enabledSources[post.sourceId]) return false

    if (settings.contentFilters.find(f => f.id === 'no-ads')?.enabled && post.isAd) return false
    if (settings.contentFilters.find(f => f.id === 'no-duplicates')?.enabled && post.isDuplicate) return false
    if (settings.contentFilters.find(f => f.id === 'no-spam')?.enabled && post.isSpam) return false

    if (selectedTopics.length === 0 || !selectedTopics.includes(post.topic)) return false

    return true
  })

  return (
    <div className="max-w-4xl mx-auto">
      <div className="relative bg-black">
        <div className="mb-4 pb-4 border-b border-white/5">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-2 h-2 bg-white rounded-full animate-pulse-dot" />
              <span className="text-white/60 text-xs font-light">{translations.yourFeed}</span>
            </div>
            <span className="text-white/30 text-[10px] font-light">
              {filteredPosts.length} {translations.posts}
            </span>
          </div>

          <div className="mt-3 flex items-center gap-2">
            <Code className="w-4 h-4 text-white/60" />
            <span className="text-white/80 text-sm font-medium">Технологии</span>
          </div>
        </div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="space-y-4"
        >

          {filteredPosts.length === 0 ? (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="text-center py-8"
            >
              <p className="text-white/40 text-sm">{translations.noPostsTitle}</p>
              <p className="text-white/20 text-xs mt-2">{translations.noPostsHint}</p>
            </motion.div>
          ) : (
            filteredPosts.map((post, index) => (
              <motion.div
                key={post.id}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.4, delay: index * 0.1 }}
              >
                <FeedCard feed={post} opacity={staticOpacity} translations={translations} isMobile={isMobile} onTrackTabChange={onTrackTabChange} />
              </motion.div>
            ))
          )}

          {filteredPosts.length > 0 && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.6, delay: 0.6 }}
              className="mt-6 pt-6 border-t border-white/5"
            >
              <div className="text-center">
                <p className="text-white/30 text-xs font-light">
                  {translations.allNewsVerified}
                </p>
              </div>
            </motion.div>
          )}
        </motion.div>
      </div>
    </div>
  )
}

// ============= Process Step Item Component =============
function ProcessStepItem({
  step,
  index,
  currentStep,
  scrollProgress,
  totalSteps
}: {
  step: StepType
  index: number
  currentStep: number
  scrollProgress: MotionValue<number>
  totalSteps: number
}) {
  // Плавная scale для каждого кружка
  const stepScale = useTransform(
    scrollProgress,
    [index - 0.3, index, index + 0.3],
    [1, 1.15, 1]
  )

  // Анимация наполнения кружка (от 0 до 1)
  const fillProgress = useTransform(
    scrollProgress,
    [index - 0.5, index - 0.1],
    [0, 1]
  )
  
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.6, delay: index * 0.1 }}
      className="relative z-10"
    >
      <div className="flex flex-col items-center mb-4">
        <motion.div
          className={`relative w-10 h-10 rounded-full border-2 flex items-center justify-center mb-3 transition-all duration-500 bg-black overflow-hidden ${
            index === currentStep
              ? 'border-white shadow-[0_0_20px_rgba(59,130,246,0.5),0_0_40px_rgba(139,92,246,0.3)]'
              : index < currentStep
              ? 'border-white/40 shadow-[0_0_10px_rgba(59,130,246,0.2)]'
              : 'border-white/10'
          }`}
          style={{
            scale: stepScale,
          }}
        >
          {/* Fill animation - градиентное наполнение */}
          <motion.div
            className="absolute inset-0 rounded-full z-0"
            style={{
              scale: fillProgress,
              background: index < currentStep || index === currentStep
                ? 'radial-gradient(circle at 30% 30%, rgba(59, 130, 246, 0.6), rgba(139, 92, 246, 0.4) 50%, rgba(59, 130, 246, 0.3))'
                : 'transparent'
            }}
          />

          {/* Shimmer effect — CSS animation for Safari performance */}
          {index === currentStep && (
            <div
              className="absolute inset-0 rounded-full z-[1] animate-shimmer-rotate"
              style={{
                background: 'linear-gradient(135deg, transparent 20%, rgba(255, 255, 255, 0.4) 50%, transparent 80%)'
              }}
            />
          )}

          {/* Pulsing glow overlay — CSS animation */}
          {index === currentStep && (
            <div
              className="absolute inset-0 rounded-full z-0 animate-glow-pulse"
              style={{
                background: 'radial-gradient(circle, rgba(139, 92, 246, 0.4), transparent 70%)'
              }}
            />
          )}

          <span className={`relative z-10 text-xs font-bold transition-colors ${
            index === currentStep ? 'text-white' : 'text-white/30'
          }`}>
            {String(index + 1).padStart(2, '0')}
          </span>

        </motion.div>
      </div>

      {/* Step content */}
      <div className="text-center space-y-1">
        <p className={`text-[10px] uppercase tracking-wider transition-colors ${
          index === currentStep ? 'text-white/60' : 'text-white/20'
        }`}>
          {step.label}
        </p>
        <h3 className={`text-sm font-semibold transition-colors ${
          index === currentStep ? 'text-white' : 'text-white/30'
        }`}>
          {step.title}
        </h3>
        <p className={`text-xs font-light transition-colors ${
          index === currentStep ? 'text-white/40' : 'text-white/20'
        }`}>
          {step.description}
        </p>
      </div>

      {/* Arrow */}
      {index < totalSteps - 1 && (
        <ArrowRight className="absolute top-3 -right-6 w-3 h-3 text-white/10" />
      )}
    </motion.div>
  )
}

type StepType = { label: string; title: string; description: string }

// ============= Process Timeline Component =============
function ProcessTimeline({
  currentStep,
  scrollProgress,
  steps
}: {
  currentStep: number
  scrollProgress: MotionValue<number>
  steps: readonly StepType[]
}) {
  const progressWidth = useTransform(scrollProgress,
    [0, 1, 2],
    ['0%', 'calc(33.33%)', 'calc(66.66%)'],
    { clamp: true }
  )

  return (
    <div className="mb-6 sm:mb-8">
      {/* Desktop: horizontal grid */}
      <div className="hidden sm:grid grid-cols-3 gap-4 relative">
        {/* Background line */}
        <div
          className="absolute h-[2px] bg-white/5 rounded-full z-0"
          style={{
            top: '20px',
            left: 'calc(16.66%)',
            right: 'calc(16.66%)'
          }}
        />

        {/* Animated progress line */}
        <motion.div
          className="absolute h-[2px] rounded-full z-0"
          style={{
            top: '20px',
            left: 'calc(16.66%)',
            width: progressWidth,
            background: 'linear-gradient(90deg, rgba(255,255,255,0.2), rgba(255,255,255,0.6))',
            boxShadow: '0 0 20px rgba(255,255,255,0.4)'
          }}
        />

        {steps.map((step, index) => (
          <ProcessStepItem
            key={index}
            step={step}
            index={index}
            currentStep={currentStep}
            scrollProgress={scrollProgress}
            totalSteps={steps.length}
          />
        ))}
      </div>

      {/* Mobile: vertical list */}
      <div className="sm:hidden flex flex-col gap-4 relative">
        {steps.map((step, index) => (
          <motion.div
            key={index}
            initial={{ opacity: 0, x: -20 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, delay: index * 0.1 }}
            className="relative z-10 flex items-center gap-4"
          >
            <motion.div
              className={`relative w-10 h-10 rounded-full border-2 flex items-center justify-center transition-all duration-500 bg-black flex-shrink-0 ${
                index === currentStep
                  ? 'border-white bg-white/10'
                  : index < currentStep
                  ? 'border-white/40 bg-white/5'
                  : 'border-white/10 bg-transparent'
              }`}
            >
              <span className={`relative z-10 text-xs font-bold transition-colors ${
                index === currentStep ? 'text-white' : 'text-white/30'
              }`}>
                {String(index + 1).padStart(2, '0')}
              </span>
            </motion.div>

            <div className="flex-1">
              <p className={`text-[10px] uppercase tracking-wider transition-colors mb-0.5 ${
                index === currentStep ? 'text-white/60' : 'text-white/20'
              }`}>
                {step.label}
              </p>
              <h3 className={`text-sm font-semibold transition-colors ${
                index === currentStep ? 'text-white' : 'text-white/30'
              }`}>
                {step.title}
              </h3>
              <p className={`text-xs font-light transition-colors ${
                index === currentStep ? 'text-white/40' : 'text-white/20'
              }`}>
                {step.description}
              </p>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  )
}

// ============= Main Component =============
export function AIAnimation() {
  const containerRef = useRef<HTMLDivElement>(null)
  const sectionRef = useIntersectionTracking({
    sectionName: 'ai-animation',
    threshold: 0.2,
    trackOnce: true
  })
  const { t } = useLanguage()
  const { trackCTAClick } = useMatomo()
  const [currentStep, setCurrentStep] = useState(0)
  const [isMobile, setIsMobile] = useState(false)
  const [isShortScreen, setIsShortScreen] = useState(false)

  // Lifted state for interactive demo
  const [enabledSources, setEnabledSources] = useState<Record<string, boolean>>({
    telegram: true,
    rss: true
  })

  // Create settings from translations
  const [settings, setSettings] = useState<SettingsType>(() => ({
    contentFilters: t.howItWorks.filters.map(f => ({ id: f.id, label: f.label, enabled: true })),
    topicFilters: t.howItWorks.topics.map((topic, i) => ({ id: topic.id, label: topic.label, selected: i !== 1 })),
    customPrompt: ''
  }))

  // Tracking functions
  const handleTrackSourceToggle = (sourceName: string, enabled: boolean) => {
    trackCTAClick({
      button_text: `${sourceName} toggle: ${enabled ? 'on' : 'off'}`,
      section: 'ai-demo',
      destination: 'source-toggle'
    })
  }

  const handleTrackFilterToggle = (filterLabel: string, enabled: boolean) => {
    trackCTAClick({
      button_text: `${filterLabel}: ${enabled ? 'on' : 'off'}`,
      section: 'ai-demo',
      destination: 'filter-toggle'
    })
  }

  const handleTrackTopicToggle = (topicLabel: string, selected: boolean) => {
    trackCTAClick({
      button_text: `${topicLabel}: ${selected ? 'selected' : 'deselected'}`,
      section: 'ai-demo',
      destination: 'topic-toggle'
    })
  }

  const handleTrackTabChange = (tab: 'brief' | 'full') => {
    trackCTAClick({
      button_text: `View: ${tab}`,
      section: 'ai-demo',
      destination: 'tab-change'
    })
  }

  const handleTrackStepChange = (stepIndex: number, stepTitle: string) => {
    trackCTAClick({
      button_text: `Step ${stepIndex + 1}: ${stepTitle}`,
      section: 'ai-demo',
      destination: 'step-change'
    })
  }

  // Определяем ширину и высоту экрана на клиенте
  useEffect(() => {
    const checkScreenSize = () => {
      setIsMobile(window.innerWidth < 640)
      setIsShortScreen(window.innerHeight < 700)
    }

    checkScreenSize()
    window.addEventListener('resize', checkScreenSize)
    return () => window.removeEventListener('resize', checkScreenSize)
  }, [])

  // На мобильных используем упрощённый режим без scroll-анимации
  const useMobileMode = isMobile

  // Scroll-driven animation
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"]
  })

  // Transform scroll progress - плавные переходы для 3 шагов
  const scrollProgress = useTransform(
    scrollYProgress,
    [0.15, 0.5, 0.85],
    [0, 1, 2]
  )

  // Handle step progression
  useEffect(() => {
    const unsubscribe = scrollProgress.on("change", (latest) => {
      const step = Math.max(0, Math.min(2, Math.round(latest)))
      setCurrentStep(step)
    })

    return () => unsubscribe()
  }, [scrollProgress])

  // Mobile version - простой tap-based интерфейс без scroll-анимации
  if (useMobileMode) {
    return (
      <section
        ref={(el) => {
          if (sectionRef) {
            (sectionRef as React.MutableRefObject<HTMLElement | null>).current = el
          }
        }}
        id="ai-animation"
        className="relative bg-black py-8 overflow-hidden"
      >
        <div className="relative z-10 max-w-6xl mx-auto px-4">
          {/* Header - компактный на мобильных */}
          <div className="text-center mb-6">
            <h2 className="text-2xl font-bold text-white tracking-tight mb-2">
              {t.howItWorks.title}
            </h2>
            <p className="text-white/40 text-sm font-light">
              {t.howItWorks.subtitle}
            </p>
          </div>

          {/* Mobile Step Tabs */}
          <div className="flex justify-center gap-2 mb-6">
            {t.howItWorks.steps.map((step, index) => (
              <button
                key={index}
                onClick={() => {
                  handleTrackStepChange(index, step.title)
                  setCurrentStep(index)
                }}
                className={`flex items-center gap-2 px-4 py-2.5 rounded-full text-sm font-medium transition-all duration-300 ${
                  index === currentStep
                    ? 'bg-white text-black'
                    : 'bg-white/5 text-white/50 border border-white/10'
                }`}
              >
                <span className="w-5 h-5 rounded-full bg-current/20 flex items-center justify-center text-xs">
                  {index + 1}
                </span>
                <span className="hidden xs:inline">{step.title}</span>
              </button>
            ))}
          </div>

          {/* Current step description */}
          <div className="text-center mb-4">
            <p className="text-white/60 text-xs">
              {t.howItWorks.steps[currentStep].description}
            </p>
          </div>

          {/* Content - без absolute позиционирования для мобильных */}
          <div className="min-h-[400px]">
            <AnimatePresence mode="wait">
              {currentStep === 0 && (
                <motion.div
                  key="sources-mobile"
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  transition={{ duration: 0.25 }}
                >
                  <SourceSelectionDemo
                    enabledSources={enabledSources}
                    setEnabledSources={setEnabledSources}
                    translations={t.howItWorks.demo}
                    sourceTranslations={t.howItWorks.sources}
                    onTrackToggle={handleTrackSourceToggle}
                  />
                </motion.div>
              )}
              {currentStep === 1 && (
                <motion.div
                  key="settings-mobile"
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  transition={{ duration: 0.25 }}
                >
                  <SettingsDemo
                    settings={settings}
                    setSettings={setSettings}
                    posts={allPosts}
                    enabledSources={enabledSources}
                    translations={t.howItWorks.demo}
                    onTrackFilterToggle={handleTrackFilterToggle}
                    onTrackTopicToggle={handleTrackTopicToggle}
                  />
                </motion.div>
              )}
              {currentStep === 2 && (
                <motion.div
                  key="feed-mobile"
                  initial={{ opacity: 0, x: 20 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  transition={{ duration: 0.25 }}
                >
                  <FilteredFeedDemo
                    posts={allPosts}
                    enabledSources={enabledSources}
                    settings={settings}
                    translations={t.howItWorks.demo}
                    isMobile={true}
                    onTrackTabChange={handleTrackTabChange}
                  />
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
      </section>
    )
  }

  // Desktop version - scroll-based animation
  return (
    <div
      ref={(el) => {
        containerRef.current = el
        if (sectionRef) {
          (sectionRef as React.MutableRefObject<HTMLElement | null>).current = el
        }
      }}
      id="ai-animation"
      className="relative"
      style={{ height: '250vh' }}
    >
      {/* Sticky контейнер */}
      <div className={`sticky left-0 right-0 h-screen flex items-center justify-center overflow-hidden ${
        isShortScreen ? 'top-16 sm:top-20' : 'top-20 sm:top-24'
      }`}>
        <div className={`w-full ${
          isShortScreen ? 'py-2 sm:py-3' : 'py-4 sm:py-6 md:py-8'
        }`}>
          {/* Subtle background pattern */}
          <div className="absolute inset-0 pointer-events-none">
            <div
              className="absolute inset-0 opacity-[0.01]"
              style={{
                backgroundImage: `radial-gradient(circle at 1px 1px, white 1px, transparent 0)`,
                backgroundSize: '60px 60px'
              }}
            />
          </div>

          <div className="relative z-10 max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
            {/* Header */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.8 }}
              className={`text-center ${
                isShortScreen ? 'mb-2 sm:mb-4' : 'mb-4 sm:mb-6 md:mb-8'
              } ${
                isShortScreen ? 'pt-1 sm:pt-2' : 'pt-2 sm:pt-4'
              }`}
            >
              <h2 className={`font-bold text-white tracking-tight ${
                isShortScreen
                  ? 'text-xl sm:text-2xl md:text-3xl mb-1 sm:mb-2'
                  : 'text-2xl sm:text-3xl md:text-4xl lg:text-5xl mb-2 sm:mb-3 md:mb-4'
              }`}>
                {t.howItWorks.title}
              </h2>
              <p className={`text-white/40 max-w-2xl mx-auto font-light ${
                isShortScreen
                  ? 'text-xs sm:text-sm'
                  : 'text-xs sm:text-sm md:text-base'
              }`}>
                {t.howItWorks.subtitle}
              </p>
            </motion.div>

            {/* Process Timeline */}
            <ProcessTimeline
              currentStep={currentStep}
              scrollProgress={scrollProgress}
              steps={t.howItWorks.steps}
            />

            {/* Dynamic Content */}
            <div className={`relative ${
              isShortScreen
                ? 'min-h-[350px] sm:min-h-[400px]'
                : 'min-h-[400px] sm:min-h-[500px] md:min-h-[600px]'
            }`}>
              <AnimatePresence mode="wait">
                {currentStep === 0 && (
                  <motion.div
                    key="sources"
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -20 }}
                    transition={{ duration: 0.4 }}
                    className="absolute inset-0"
                  >
                    <SourceSelectionDemo
                      enabledSources={enabledSources}
                      setEnabledSources={setEnabledSources}
                      translations={t.howItWorks.demo}
                      sourceTranslations={t.howItWorks.sources}
                      onTrackToggle={handleTrackSourceToggle}
                    />
                  </motion.div>
                )}
                {currentStep === 1 && (
                  <motion.div
                    key="settings"
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -20 }}
                    transition={{ duration: 0.4 }}
                    className="absolute inset-0"
                  >
                    <SettingsDemo
                      settings={settings}
                      setSettings={setSettings}
                      posts={allPosts}
                      enabledSources={enabledSources}
                      translations={t.howItWorks.demo}
                      onTrackFilterToggle={handleTrackFilterToggle}
                      onTrackTopicToggle={handleTrackTopicToggle}
                    />
                  </motion.div>
                )}
                {currentStep === 2 && (
                  <motion.div
                    key="feed"
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -20 }}
                    transition={{ duration: 0.4 }}
                    className="absolute inset-0"
                  >
                    <FilteredFeedDemo
                      posts={allPosts}
                      enabledSources={enabledSources}
                      settings={settings}
                      translations={t.howItWorks.demo}
                      onTrackTabChange={handleTrackTabChange}
                    />
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
