'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { ChevronDown } from 'lucide-react'
import { useLanguage } from '@/lib/language-context'

interface FAQItem {
  question: string
  answer: string
}

function FAQAccordion({ item, isOpen, onClick }: { item: FAQItem; isOpen: boolean; onClick: () => void }) {
  return (
    <div className="border-b border-white/10">
      <button
        onClick={onClick}
        className="w-full py-6 flex items-center justify-between text-left group"
      >
        <span className="text-lg sm:text-xl font-medium text-white group-hover:text-white/80 transition-colors pr-4">
          {item.question}
        </span>
        <motion.div
          animate={{ rotate: isOpen ? 180 : 0 }}
          transition={{ duration: 0.3 }}
          className="flex-shrink-0"
        >
          <ChevronDown className="w-5 h-5 text-white/60" />
        </motion.div>
      </button>
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="overflow-hidden"
          >
            <p className="pb-6 text-white/70 text-base sm:text-lg leading-relaxed">
              {item.answer}
            </p>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

export function FAQ() {
  const { t } = useLanguage()
  const [openIndex, setOpenIndex] = useState<number | null>(0)

  const faqItems: FAQItem[] = [
    {
      question: t.faq?.howItWorks?.question || 'Как это работает?',
      answer: t.faq?.howItWorks?.answer || 'Вы выбираете источники информации — Telegram-каналы, новостные сайты, RSS-ленты. Указываете свои интересы и предпочтения. ИИ анализирует контент, фильтрует шум и формирует персональную ленту только с тем, что действительно важно для вас.',
    },
    {
      question: t.faq?.whatSources?.question || 'Какие источники поддерживаются?',
      answer: t.faq?.whatSources?.answer || 'Telegram-каналы, RSS-ленты, новостные сайты. Мы постоянно добавляем новые источники. Если вам нужен конкретный источник — напишите нам, и мы добавим его в приоритетном порядке.',
    },
    {
      question: t.faq?.isItFree?.question || 'Это бесплатно?',
      answer: t.faq?.isItFree?.answer || 'Есть бесплатный тариф с базовыми возможностями. Для полного доступа ко всем функциям — подписка от 299₽/мес. Первые 7 дней Pro-версии бесплатно.',
    },
    {
      question: t.faq?.noAds?.question || 'А как насчёт рекламы?',
      answer: t.faq?.noAds?.answer || 'infatium принципиально не показывает рекламу — это фундамент нашей философии. Ваша лента существует только для вас, а не для рекламодателей. Мы зарабатываем на подписках, а не на вашем внимании.',
    },
    {
      question: t.faq?.privacy?.question || 'Как насчёт приватности?',
      answer: t.faq?.privacy?.answer || 'Мы не продаём ваши данные. Ваши предпочтения используются только для персонализации ленты. Вы можете удалить все данные в любой момент.',
    },
    {
      question: t.faq?.howToStart?.question || 'Как начать пользоваться?',
      answer: t.faq?.howToStart?.answer || 'Скачайте приложение, выберите интересующие темы и добавьте источники. ИИ начнёт формировать вашу персональную ленту. Чем больше вы взаимодействуете с контентом, тем точнее становятся рекомендации.',
    },
    {
      question: t.faq?.webAndTelegram?.question || 'Будет ли веб-версия или Telegram Mini App?',
      answer: t.faq?.webAndTelegram?.answer || 'Да, веб-версия и Telegram Mini App сейчас в разработке. Следите за обновлениями — мы сообщим, когда они станут доступны.',
    },
  ]

  return (
    <section className="relative py-20 sm:py-32 bg-black">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center mb-12 sm:mb-16"
        >
          <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold text-white mb-4">
            {t.faq?.title || 'Частые вопросы'}
          </h2>
          <p className="text-white/60 text-lg">
            {t.faq?.subtitle || 'Всё, что нужно знать о infatium'}
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.2 }}
        >
          {faqItems.map((item, index) => (
            <FAQAccordion
              key={index}
              item={item}
              isOpen={openIndex === index}
              onClick={() => setOpenIndex(openIndex === index ? null : index)}
            />
          ))}
        </motion.div>
      </div>
    </section>
  )
}
