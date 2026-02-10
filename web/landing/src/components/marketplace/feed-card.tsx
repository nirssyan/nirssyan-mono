'use client'

import Image from 'next/image'
import Link from 'next/link'
import { motion } from 'framer-motion'
import { Layers2, Newspaper } from 'lucide-react'
import { QRCodeSVG } from 'qrcode.react'
import { MarketplaceFeed } from '@/types/marketplace'

interface FeedCardProps {
  feed: MarketplaceFeed
  openAppLabel: string
  noDescriptionLabel: string
  onOpenApp: (feed: MarketplaceFeed) => void
}

export function FeedCard({
  feed,
  openAppLabel,
  noDescriptionLabel,
  onOpenApp,
}: FeedCardProps) {
  const visibleTags = feed.tags.slice(0, 3)
  const hiddenTagsCount = Math.max(0, feed.tags.length - visibleTags.length)
  const isDigest = feed.type === 'DIGEST'
  const feedPath = feed.slug ?? feed.id

  return (
    <motion.article
      layout
      initial={{ opacity: 0, y: 18 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25, ease: 'easeOut' }}
      className="group relative overflow-hidden rounded-3xl border border-white/10 bg-black/35 p-6 backdrop-blur-xl"
    >
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_100%_0%,rgba(56,189,248,0.15),transparent_45%)] opacity-0 transition-opacity duration-300 group-hover:opacity-100" />

      <div className="relative flex h-full flex-col">
        <div className="mb-5 flex items-center justify-between gap-3">
          <span
            className={`inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs font-semibold tracking-wide ${
              isDigest
                ? 'border-emerald-300/30 bg-emerald-300/10 text-emerald-200'
                : 'border-sky-300/30 bg-sky-300/10 text-sky-200'
            }`}
          >
            {isDigest ? <Layers2 className="h-3.5 w-3.5" /> : <Newspaper className="h-3.5 w-3.5" />}
            {feed.type}
          </span>

          <div className="hidden sm:block">
            <QRCodeSVG
              value={`makefeed://feed/${feed.id}`}
              size={64}
              bgColor="transparent"
              fgColor="rgba(255,255,255,0.8)"
              level="M"
              imageSettings={{
                src: '/jellyfish.png',
                width: 16,
                height: 16,
                excavate: true,
              }}
            />
          </div>
        </div>

        <Link
          href={`/marketplace/${feedPath}`}
          className="text-xl font-semibold leading-tight tracking-tight text-white transition-colors hover:text-sky-300"
        >
          {feed.name}
        </Link>
        <p className="mt-3 text-sm leading-relaxed text-white/70 [display:-webkit-box] [-webkit-box-orient:vertical] [-webkit-line-clamp:3]">
          {feed.description?.trim() || noDescriptionLabel}
        </p>

        <div className="mt-5 flex flex-wrap gap-2">
          {visibleTags.map((tag) => (
            <span
              key={`${feed.id}-${tag}`}
              className="rounded-full border border-white/15 bg-white/[0.04] px-2.5 py-1 text-xs text-white/75"
            >
              #{tag}
            </span>
          ))}
          {hiddenTagsCount > 0 && (
            <span className="rounded-full border border-white/15 bg-white/[0.04] px-2.5 py-1 text-xs text-white/75">
              +{hiddenTagsCount}
            </span>
          )}
        </div>

        <div className="mt-6">
          <button
            onClick={() => onOpenApp(feed)}
            className="inline-flex items-center gap-2 rounded-full bg-white px-4 py-2 text-sm font-medium text-black transition-all duration-200 hover:bg-white/90 hover:shadow-[0_0_30px_rgba(255,255,255,0.15)]"
          >
            {openAppLabel}
            <Image src="/jellyfish.png" width={18} height={18} alt="" />
          </button>
        </div>
      </div>
    </motion.article>
  )
}
