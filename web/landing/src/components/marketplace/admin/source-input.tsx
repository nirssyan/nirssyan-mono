'use client'

import { X } from 'lucide-react'

interface SourceInputProps {
  index: number
  url: string
  name: string
  type: string
  onUrlChange: (value: string) => void
  onNameChange: (value: string) => void
  onTypeChange: (value: string) => void
  onRemove: () => void
  canRemove: boolean
}

export function SourceInput({
  index,
  url,
  name,
  type,
  onUrlChange,
  onNameChange,
  onTypeChange,
  onRemove,
  canRemove,
}: SourceInputProps) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.02] p-4">
      <div className="mb-3 flex items-center justify-between">
        <span className="text-sm font-medium text-white/50">Source {index + 1}</span>
        {canRemove && (
          <button
            type="button"
            onClick={onRemove}
            className="rounded-lg p-1 text-white/40 transition-colors hover:bg-white/10 hover:text-white"
          >
            <X className="h-4 w-4" />
          </button>
        )}
      </div>

      <div className="space-y-3">
        <input
          type="url"
          value={url}
          onChange={(e) => onUrlChange(e.target.value)}
          placeholder="https://example.com/feed or https://t.me/channel"
          className="w-full rounded-xl border border-white/15 bg-white/[0.05] px-4 py-2.5 text-sm text-white placeholder-white/30 outline-none transition-colors focus:border-white/30"
        />

        <div className="flex gap-3">
          <input
            type="text"
            value={name}
            onChange={(e) => onNameChange(e.target.value)}
            placeholder="Source name"
            className="flex-1 rounded-xl border border-white/15 bg-white/[0.05] px-4 py-2.5 text-sm text-white placeholder-white/30 outline-none transition-colors focus:border-white/30"
          />

          <select
            value={type}
            onChange={(e) => onTypeChange(e.target.value)}
            className="rounded-xl border border-white/15 bg-white/[0.05] px-3 py-2.5 text-sm text-white outline-none transition-colors focus:border-white/30"
          >
            <option value="rss">RSS</option>
            <option value="telegram">Telegram</option>
            <option value="web">Web</option>
          </select>
        </div>
      </div>
    </div>
  )
}
