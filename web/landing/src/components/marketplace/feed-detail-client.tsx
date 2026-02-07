'use client'

import Image from 'next/image'
import { motion } from 'framer-motion'
import { ArrowBigUp } from 'lucide-react'
import { AnimatePresence } from 'framer-motion'
import { useLanguage } from '@/lib/language-context'
import { useMatomo } from '@/hooks/use-matomo'
import { useUpvotes } from '@/hooks/use-upvotes'
import { MarketplaceFeed } from '@/types/marketplace'

interface FeedDetailClientProps {
  feed: MarketplaceFeed
}

function openInAppWithStoreFallback(desktopDownloadLabel: string) {
  const deepLink = 'infatium://'
  const appStoreId = process.env.NEXT_PUBLIC_APP_STORE_ID
  const playStoreId = process.env.NEXT_PUBLIC_PLAY_STORE_ID || 'com.infatium'

  const appStoreUrl =
    appStoreId && appStoreId !== 'your_app_store_id_here'
      ? `https://apps.apple.com/app/id${appStoreId}`
      : 'https://apps.apple.com/search?term=infatium'
  const playStoreUrl = `https://play.google.com/store/apps/details?id=${playStoreId}`

  const userAgent = navigator.userAgent
  const isIOS = /iPhone|iPad|iPod/.test(userAgent)
  const isAndroid = /Android/.test(userAgent)

  window.location.href = deepLink

  window.setTimeout(() => {
    if (isIOS) {
      window.location.href = appStoreUrl
      return
    }

    if (isAndroid) {
      window.location.href = playStoreUrl
      return
    }

    alert(`${desktopDownloadLabel}\n\niOS: ${appStoreUrl}\n\nAndroid: ${playStoreUrl}`)
  }, 500)
}

export function FeedDetailClient({ feed }: FeedDetailClientProps) {
  const { t } = useLanguage()
  const { trackCTAClick, trackCustomEvent } = useMatomo()

  const { votes, toggleVote, hasVoted, mounted } = useUpvotes({
    [feed.id]: feed.initialVotes ?? 0,
  })

  const displayVotes = mounted ? (votes[feed.id] ?? 0) : (feed.initialVotes ?? 0)
  const voted = hasVoted(feed.id)

  const handleOpenApp = () => {
    trackCTAClick({
      button_text: t.marketplace.openApp,
      section: 'marketplace-detail',
      destination: 'app_store_redirect',
    })
    trackCustomEvent('marketplace_open_app', {
      feed_id: feed.id,
      feed_type: feed.type,
    })
    openInAppWithStoreFallback(t.marketplace.desktopDownload)
  }

  const handleToggleVote = () => {
    toggleVote(feed.id)
    trackCustomEvent('marketplace_upvote', {
      feed_id: feed.id,
      action: voted ? 'remove' : 'add',
    })
  }

  return (
    <div className="flex items-center gap-3">
      <button
        onClick={handleOpenApp}
        className="inline-flex items-center gap-2 rounded-full bg-white px-5 py-2.5 text-sm font-medium text-black transition-all duration-200 hover:bg-white/90 hover:shadow-[0_0_30px_rgba(255,255,255,0.15)]"
      >
        {t.marketplace.openApp}
        <Image src="/jellyfish.png" width={18} height={18} alt="" />
      </button>

      <motion.button
        onClick={handleToggleVote}
        whileTap={{ scale: 0.9 }}
        className={`inline-flex items-center gap-1.5 rounded-full border px-4 py-2.5 text-sm font-medium transition-colors duration-200 ${
          voted
            ? 'border-sky-400/40 bg-sky-400/10 text-sky-400'
            : 'border-white/15 bg-white/[0.03] text-white/70 hover:border-white/30 hover:text-white'
        }`}
      >
        <ArrowBigUp className={`h-4 w-4 ${voted ? 'fill-sky-400' : ''}`} />
        <AnimatePresence mode="popLayout">
          <motion.span
            key={displayVotes}
            initial={{ y: -10, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 10, opacity: 0 }}
            transition={{ duration: 0.15 }}
          >
            {displayVotes}
          </motion.span>
        </AnimatePresence>
      </motion.button>
    </div>
  )
}
