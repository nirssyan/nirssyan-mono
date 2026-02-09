'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { ArrowLeft } from 'lucide-react'
import { CreateFeedForm } from '@/components/marketplace/admin/create-feed-form'

const JWT_KEY = 'marketplace_admin_jwt'

export default function AdminCreatePage() {
  const router = useRouter()
  const [token, setToken] = useState<string | null>(null)

  useEffect(() => {
    const jwt = sessionStorage.getItem(JWT_KEY)
    if (!jwt) {
      router.replace('/marketplace/admin')
    } else {
      setToken(jwt)
    }
  }, [router])

  if (!token) return null

  return (
    <main className="relative min-h-screen bg-black text-white">
      <div className="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_15%_20%,rgba(255,255,255,0.08),transparent_40%),radial-gradient(circle_at_80%_0%,rgba(56,189,248,0.14),transparent_38%),linear-gradient(to_bottom,#020617,#000000_40%,#020617)]" />

      <div className="mx-auto max-w-2xl px-4 pb-16 pt-8 sm:px-6 sm:pb-24 sm:pt-10">
        <Link
          href="/marketplace"
          className="inline-flex items-center gap-2 text-sm text-white/60 transition-colors hover:text-white"
        >
          <ArrowLeft className="h-4 w-4" />
          Back to marketplace
        </Link>

        <div className="mt-6 rounded-3xl border border-white/10 bg-black/35 p-7 backdrop-blur-xl sm:p-10">
          <h1 className="mb-8 text-2xl font-semibold tracking-tight text-white">
            Create Marketplace Feed
          </h1>
          <CreateFeedForm token={token} />
        </div>
      </div>
    </main>
  )
}
