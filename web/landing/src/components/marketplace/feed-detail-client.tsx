'use client'

import Image from 'next/image'
import { useLanguage } from '@/lib/language-context'
import { openInAppWithStoreFallback } from '@/lib/open-app'
import { useMatomo } from '@/hooks/use-matomo'
import { MarketplaceFeed } from '@/types/marketplace'

interface FeedDetailClientProps {
  feed: MarketplaceFeed
}

export function FeedDetailClient({ feed }: FeedDetailClientProps) {
  const { t } = useLanguage()
  const { trackCTAClick, trackCustomEvent } = useMatomo()

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
    openInAppWithStoreFallback(feed.id, t.marketplace.desktopDownload)
  }

  return (
    <button
      onClick={handleOpenApp}
      className="inline-flex items-center gap-2 rounded-full bg-white px-5 py-2.5 text-sm font-medium text-black transition-all duration-200 hover:bg-white/90 hover:shadow-[0_0_30px_rgba(255,255,255,0.15)]"
    >
      {t.marketplace.openApp}
      <Image src="/jellyfish.png" width={18} height={18} alt="" />
    </button>
  )
}
