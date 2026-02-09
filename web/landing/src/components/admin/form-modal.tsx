'use client'

import { useEffect, useRef } from 'react'

interface FormModalProps {
  open: boolean
  title: string
  onClose: () => void
  onSubmit: (e: React.FormEvent) => void
  loading?: boolean
  children: React.ReactNode
}

export function FormModal({ open, title, onClose, onSubmit, loading, children }: FormModalProps) {
  const formRef = useRef<HTMLFormElement>(null)

  useEffect(() => {
    if (open) {
      const handleKeyDown = (e: KeyboardEvent) => {
        if (e.key === 'Escape') onClose()
      }
      window.addEventListener('keydown', handleKeyDown)
      return () => window.removeEventListener('keydown', handleKeyDown)
    }
  }, [open, onClose])

  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm">
      <div className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-xl border border-white/10 bg-[#111] p-6">
        <h3 className="mb-6 text-lg font-semibold text-white">{title}</h3>
        <form ref={formRef} onSubmit={onSubmit} className="space-y-4">
          {children}
          <div className="flex justify-end gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="rounded-lg border border-white/10 px-4 py-2 text-sm text-white/70 transition-colors hover:bg-white/5 disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="rounded-lg bg-white px-4 py-2 text-sm font-medium text-black transition-colors hover:bg-white/90 disabled:opacity-50"
            >
              {loading ? 'Saving...' : 'Save'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export function FormField({
  label,
  children,
}: {
  label: string
  children: React.ReactNode
}) {
  return (
    <div>
      <label className="mb-1.5 block text-sm font-medium text-white/70">{label}</label>
      {children}
    </div>
  )
}

export const inputClassName =
  'w-full rounded-lg border border-white/15 bg-white/[0.05] px-3 py-2 text-sm text-white placeholder-white/30 outline-none transition-colors focus:border-white/30'

export const selectClassName =
  'w-full rounded-lg border border-white/15 bg-white/[0.05] px-3 py-2 text-sm text-white outline-none transition-colors focus:border-white/30'
