import type { Metadata } from 'next'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { ArrowLeft, Globe, Layers2, MessageCircle, Newspaper, Rss } from 'lucide-react'
import { QRCodeSVG } from 'qrcode.react'
import { getMarketplaceFeedBySlug } from '@/lib/marketplace-api'
import { FeedDetailClient } from '@/components/marketplace/feed-detail-client'

interface PageProps {
  params: Promise<{ feedId: string }>
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { feedId } = await params
  const feed = await getMarketplaceFeedBySlug(feedId)

  if (!feed) {
    return { title: 'Лента не найдена | infatium' }
  }

  return {
    title: `${feed.name} | infatium`,
    description: feed.description ?? 'Лента infatium',
    alternates: {
      canonical: `/marketplace/${feed.slug}`,
    },
    openGraph: {
      title: `${feed.name} | infatium`,
      description: feed.description ?? 'Лента infatium',
      url: `https://infatium.ru/marketplace/${feed.slug}`,
      siteName: 'infatium',
      type: 'website',
      locale: 'ru_RU',
    },
  }
}

const SOURCE_ICONS = {
  telegram: MessageCircle,
  rss: Rss,
  web: Globe,
} as const

export default async function FeedDetailPage({ params }: PageProps) {
  const { feedId } = await params
  const feed = await getMarketplaceFeedBySlug(feedId)

  if (!feed) {
    notFound()
  }

  const isDigest = feed.type === 'DIGEST'

  return (
    <main className="relative min-h-screen bg-black text-white">
      <div className="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_15%_20%,rgba(255,255,255,0.08),transparent_40%),radial-gradient(circle_at_80%_0%,rgba(56,189,248,0.14),transparent_38%),linear-gradient(to_bottom,#020617,#000000_40%,#020617)]" />

      <div className="mx-auto max-w-4xl px-4 pb-16 pt-8 sm:px-6 sm:pb-24 sm:pt-10 lg:px-8">
        <Link
          href="/marketplace"
          className="inline-flex items-center gap-2 text-sm text-white/60 transition-colors hover:text-white"
        >
          <ArrowLeft className="h-4 w-4" />
          <span className="hidden sm:inline">Back to catalog</span>
          <span className="sm:hidden">Back</span>
        </Link>

        <section className="relative mt-6 overflow-hidden rounded-3xl border border-white/10 bg-black/35 p-7 backdrop-blur-xl sm:p-10">
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_10%_15%,rgba(56,189,248,0.18),transparent_40%),radial-gradient(circle_at_90%_0%,rgba(255,255,255,0.08),transparent_45%)]" />

          <div className="relative flex flex-col gap-6 sm:flex-row sm:items-start sm:justify-between">
            <div className="flex-1">
              <span
                className={`inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs font-semibold tracking-wide ${
                  isDigest
                    ? 'border-emerald-300/30 bg-emerald-300/10 text-emerald-200'
                    : 'border-sky-300/30 bg-sky-300/10 text-sky-200'
                }`}
              >
                {isDigest ? (
                  <Layers2 className="h-3.5 w-3.5" />
                ) : (
                  <Newspaper className="h-3.5 w-3.5" />
                )}
                {feed.type}
              </span>

              <h1 className="mt-4 text-3xl font-semibold tracking-tight text-white sm:text-4xl">
                {feed.name}
              </h1>

              <p className="mt-3 text-sm leading-relaxed text-white/70 sm:text-base">
                {feed.description}
              </p>

              <div className="mt-5">
                <FeedDetailClient feed={feed} />
              </div>
            </div>

            <div className="hidden sm:block">
              <QRCodeSVG
                value={`infatium://marketplace/${feed.slug}`}
                size={120}
                bgColor="transparent"
                fgColor="rgba(255,255,255,0.8)"
                level="M"
                imageSettings={{
                  src: '/jellyfish.png',
                  width: 24,
                  height: 24,
                  excavate: true,
                }}
              />
            </div>
          </div>
        </section>

        {feed.sources && feed.sources.length > 0 && (
          <section className="mt-8 rounded-3xl border border-white/10 bg-black/35 p-7 backdrop-blur-xl sm:p-8">
            <h2 className="text-lg font-semibold text-white">Sources</h2>
            <div className="mt-5 space-y-3">
              {feed.sources.map((source) => {
                const Icon = SOURCE_ICONS[source.type as keyof typeof SOURCE_ICONS] ?? Globe
                return (
                  <div
                    key={source.url}
                    className="flex items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3"
                  >
                    <Icon className="h-4 w-4 shrink-0 text-white/50" />
                    <span className="text-sm font-medium text-white">{source.name}</span>
                    <span className="rounded-full border border-white/15 bg-white/[0.04] px-2 py-0.5 text-xs text-white/50">
                      {source.type}
                    </span>
                  </div>
                )
              })}
            </div>
          </section>
        )}

        {feed.story && (
          <section className="mt-8 rounded-3xl border border-white/10 bg-black/35 p-7 backdrop-blur-xl sm:p-8">
            <h2 className="text-lg font-semibold text-white">Personal Story</h2>
            <p className="mt-4 whitespace-pre-line text-sm leading-relaxed text-white/70 sm:text-base">
              {feed.story}
            </p>
          </section>
        )}

        <div className="mt-5 flex flex-wrap gap-2">
          {feed.tags.map((tag) => (
            <span
              key={tag}
              className="rounded-full border border-white/15 bg-white/[0.04] px-3 py-1.5 text-sm text-white/75"
            >
              #{tag}
            </span>
          ))}
        </div>
      </div>
    </main>
  )
}
