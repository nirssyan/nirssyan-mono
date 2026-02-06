'use client'

import { AlertCircle, RotateCcw } from 'lucide-react'

interface EmptyStateProps {
  title: string
  description: string
  actionLabel?: string
  onAction?: () => void
}

export function EmptyState({ title, description, actionLabel, onAction }: EmptyStateProps) {
  return (
    <div className="relative overflow-hidden rounded-3xl border border-white/10 bg-white/[0.03] p-8 sm:p-10">
      <div className="absolute inset-0 bg-[radial-gradient(circle_at_15%_20%,rgba(255,255,255,0.1),transparent_45%)]" />
      <div className="relative flex flex-col items-center text-center">
        <div className="mb-5 inline-flex h-14 w-14 items-center justify-center rounded-2xl border border-white/15 bg-black/30">
          <AlertCircle className="h-6 w-6 text-white/75" />
        </div>

        <h3 className="text-xl font-semibold tracking-tight text-white sm:text-2xl">{title}</h3>
        <p className="mt-3 max-w-xl text-sm text-white/65 sm:text-base">{description}</p>

        {actionLabel && onAction && (
          <button
            onClick={onAction}
            className="mt-7 inline-flex items-center gap-2 rounded-full border border-white/20 bg-white/10 px-5 py-2.5 text-sm font-medium text-white transition-colors duration-200 hover:bg-white/20"
          >
            <RotateCcw className="h-4 w-4" />
            {actionLabel}
          </button>
        )}
      </div>
    </div>
  )
}
