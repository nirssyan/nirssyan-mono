'use client'

import { useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { Search, SlidersHorizontal } from 'lucide-react'
import { MarketplaceFeedTypeFilter } from '@/types/marketplace'

interface FiltersBarProps {
  searchQuery: string
  selectedType: MarketplaceFeedTypeFilter
  selectedTag: string
  tags: string[]
  searchPlaceholder: string
  allTypesLabel: string
  allTagsLabel: string
  singlePostLabel: string
  digestLabel: string
  filtersLabel: string
  onSearchChange: (value: string) => void
  onTypeChange: (value: MarketplaceFeedTypeFilter) => void
  onTagChange: (value: string) => void
}

function ToggleButton({
  active,
  children,
  onClick,
}: {
  active: boolean
  children: React.ReactNode
  onClick: () => void
}) {
  return (
    <button
      onClick={onClick}
      className={`rounded-full border px-4 py-2 text-sm font-medium transition-all duration-200 ${
        active
          ? 'border-white/45 bg-white text-black'
          : 'border-white/15 bg-white/[0.03] text-white/75 hover:border-white/30 hover:text-white'
      }`}
    >
      {children}
    </button>
  )
}

export function FiltersBar({
  searchQuery,
  selectedType,
  selectedTag,
  tags,
  searchPlaceholder,
  allTypesLabel,
  allTagsLabel,
  singlePostLabel,
  digestLabel,
  filtersLabel,
  onSearchChange,
  onTypeChange,
  onTagChange,
}: FiltersBarProps) {
  const [filtersOpen, setFiltersOpen] = useState(false)
  const hasActiveFilters = selectedType !== 'ALL' || selectedTag !== 'ALL'

  return (
    <div className="rounded-3xl border border-white/10 bg-black/50 p-4 shadow-[0_12px_50px_rgba(0,0,0,0.45)] backdrop-blur-xl sm:p-5">
      <div className="relative">
        <Search className="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-white/40" />
        <input
          type="text"
          value={searchQuery}
          onChange={(event) => onSearchChange(event.target.value)}
          placeholder={searchPlaceholder}
          className="w-full rounded-2xl border border-white/15 bg-black/35 py-3 pl-11 pr-4 text-sm text-white placeholder:text-white/40 outline-none transition-colors focus:border-white/35"
        />
      </div>

      <button
        onClick={() => setFiltersOpen((prev) => !prev)}
        className="mt-3 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/[0.03] px-4 py-2 text-sm font-medium text-white/75 transition-all duration-200 hover:border-white/30 hover:text-white"
      >
        <SlidersHorizontal className="h-4 w-4" />
        {filtersLabel}
        {hasActiveFilters && (
          <span className="h-2 w-2 rounded-full bg-sky-400" />
        )}
      </button>

      <AnimatePresence initial={false}>
        {filtersOpen && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.25, ease: 'easeInOut' }}
            className="overflow-hidden"
          >
            <div className="mt-4 flex flex-wrap gap-2.5">
              <ToggleButton active={selectedType === 'ALL'} onClick={() => onTypeChange('ALL')}>
                {allTypesLabel}
              </ToggleButton>
              <ToggleButton
                active={selectedType === 'SINGLE_POST'}
                onClick={() => onTypeChange('SINGLE_POST')}
              >
                {singlePostLabel}
              </ToggleButton>
              <ToggleButton active={selectedType === 'DIGEST'} onClick={() => onTypeChange('DIGEST')}>
                {digestLabel}
              </ToggleButton>
            </div>

            <div className="mt-4 flex flex-wrap gap-2">
              <ToggleButton active={selectedTag === 'ALL'} onClick={() => onTagChange('ALL')}>
                {allTagsLabel}
              </ToggleButton>
              {tags.map((tag) => (
                <ToggleButton key={tag} active={selectedTag === tag} onClick={() => onTagChange(tag)}>
                  #{tag}
                </ToggleButton>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
