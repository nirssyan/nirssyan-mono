'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { AlertTriangle } from 'lucide-react'
import { useLanguage } from '@/lib/language-context'
import { useMatomo } from '@/hooks/use-matomo'
import { MarketplaceFeed, MarketplaceFeedTypeFilter } from '@/types/marketplace'
import { FeedCard } from './feed-card'
import { FiltersBar } from './filters-bar'
import { EmptyState } from './empty-state'

interface MarketplaceCatalogProps {
  initialFeeds: MarketplaceFeed[]
  hasError: boolean
}

function normalize(value: string): string {
  return value.trim().toLowerCase()
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

export function MarketplaceCatalog({ initialFeeds, hasError }: MarketplaceCatalogProps) {
  const { t } = useLanguage()
  const { trackCTAClick, trackCustomEvent } = useMatomo()

  const [searchQuery, setSearchQuery] = useState('')
  const [selectedType, setSelectedType] = useState<MarketplaceFeedTypeFilter>('ALL')
  const [selectedTag, setSelectedTag] = useState<string>('ALL')

  const searchTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    return () => {
      if (searchTimerRef.current) {
        clearTimeout(searchTimerRef.current)
      }
    }
  }, [])

  const tags = useMemo(() => {
    const counts = new Map<string, number>()

    for (const feed of initialFeeds) {
      for (const tag of feed.tags) {
        const trimmed = tag.trim()
        if (!trimmed) continue
        counts.set(trimmed, (counts.get(trimmed) ?? 0) + 1)
      }
    }

    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .map(([tag]) => tag)
  }, [initialFeeds])

  const filteredFeeds = useMemo(() => {
    const query = normalize(searchQuery)

    const filtered = initialFeeds.filter((feed) => {
      if (selectedType !== 'ALL' && feed.type !== selectedType) {
        return false
      }

      if (selectedTag !== 'ALL' && !feed.tags.includes(selectedTag)) {
        return false
      }

      if (!query) {
        return true
      }

      const haystack = normalize(`${feed.name} ${feed.description ?? ''} ${feed.tags.join(' ')}`)
      return haystack.includes(query)
    })

    return filtered.sort(
      (a, b) => new Date(b.created_at ?? '').getTime() - new Date(a.created_at ?? '').getTime()
    )
  }, [initialFeeds, searchQuery, selectedType, selectedTag])

  const hasActiveFilters =
    searchQuery.trim().length > 0 || selectedType !== 'ALL' || selectedTag !== 'ALL'

  const handleSearchChange = (value: string) => {
    setSearchQuery(value)

    if (searchTimerRef.current) {
      clearTimeout(searchTimerRef.current)
    }

    searchTimerRef.current = setTimeout(() => {
      trackCustomEvent('marketplace_search', {
        query: value.trim(),
      })
    }, 300)
  }

  const handleTypeChange = (value: MarketplaceFeedTypeFilter) => {
    setSelectedType(value)
    trackCustomEvent('marketplace_filter_type', { type: value })
  }

  const handleTagChange = (value: string) => {
    setSelectedTag(value)
    trackCustomEvent('marketplace_filter_tag', { tag: value })
  }

  const handleClearFilters = () => {
    setSearchQuery('')
    setSelectedType('ALL')
    setSelectedTag('ALL')
    trackCustomEvent('marketplace_filters_reset')
  }

  const handleOpenApp = (feed: MarketplaceFeed) => {
    trackCTAClick({
      button_text: t.marketplace.openApp,
      section: 'marketplace-card',
      destination: 'app_store_redirect',
    })
    trackCustomEvent('marketplace_open_app', {
      feed_id: feed.id,
      feed_type: feed.type,
    })

    openInAppWithStoreFallback(t.marketplace.desktopDownload)
  }

  return (
    <>
      <section className="relative overflow-hidden rounded-3xl border border-white/10 bg-black/35 p-7 backdrop-blur-xl sm:p-10">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_10%_15%,rgba(56,189,248,0.18),transparent_40%),radial-gradient(circle_at_90%_0%,rgba(255,255,255,0.08),transparent_45%)]" />
        <div className="relative">
          <span className="inline-flex rounded-full border border-white/20 bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-white/80">
            {t.marketplace.badge}
          </span>
          <h1 className="mt-5 text-3xl font-semibold tracking-tight text-white sm:text-5xl">
            {t.marketplace.title}
          </h1>
          <p className="mt-4 max-w-3xl text-sm leading-relaxed text-white/70 sm:text-lg">
            {t.marketplace.subtitle}
          </p>
        </div>
      </section>

      <div className="sticky top-16 z-20 mt-8 sm:top-20">
        <FiltersBar
          searchQuery={searchQuery}
          selectedType={selectedType}
          selectedTag={selectedTag}
          tags={tags}
          searchPlaceholder={t.marketplace.searchPlaceholder}
          allTypesLabel={t.marketplace.allTypes}
          allTagsLabel={t.marketplace.allTags}
          singlePostLabel={t.marketplace.singlePost}
          digestLabel={t.marketplace.digest}
          filtersLabel={t.marketplace.filtersLabel}
          onSearchChange={handleSearchChange}
          onTypeChange={handleTypeChange}
          onTagChange={handleTagChange}
        />
      </div>

      {hasError && initialFeeds.length > 0 && (
        <div className="mt-4 inline-flex items-center gap-2 rounded-full border border-amber-300/35 bg-amber-300/10 px-3 py-1.5 text-xs text-amber-100">
          <AlertTriangle className="h-3.5 w-3.5" />
          {t.marketplace.partialDataWarning}
        </div>
      )}

      <div className="mt-7 flex flex-wrap items-center justify-between gap-3">
        <p className="text-sm text-white/65 sm:text-base">
          <span className="font-semibold text-white">{filteredFeeds.length}</span>{' '}
          {t.marketplace.resultsLabel}
        </p>

        {hasActiveFilters && (
          <button
            onClick={handleClearFilters}
            className="rounded-full border border-white/20 bg-white/[0.04] px-4 py-2 text-sm text-white/80 transition-colors duration-200 hover:bg-white/15"
          >
            {t.marketplace.clearFilters}
          </button>
        )}
      </div>

      <section className="mt-6">
        {hasError && initialFeeds.length === 0 ? (
          <EmptyState
            title={t.marketplace.errorTitle}
            description={t.marketplace.errorHint}
            actionLabel={t.marketplace.retry}
            onAction={() => window.location.reload()}
          />
        ) : filteredFeeds.length === 0 ? (
          <EmptyState
            title={t.marketplace.emptyTitle}
            description={t.marketplace.emptyHint}
            actionLabel={hasActiveFilters ? t.marketplace.clearFilters : undefined}
            onAction={hasActiveFilters ? handleClearFilters : undefined}
          />
        ) : (
          <div className="grid grid-cols-1 gap-5 md:grid-cols-2 xl:grid-cols-3">
            {filteredFeeds.map((feed) => (
              <FeedCard
                key={feed.id}
                feed={feed}
                openAppLabel={t.marketplace.openApp}
                noDescriptionLabel={t.marketplace.noDescription}
                onOpenApp={handleOpenApp}
              />
            ))}
          </div>
        )}
      </section>
    </>
  )
}
