'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { LoginForm } from '@/components/marketplace/admin/login-form'

const JWT_KEY = 'marketplace_admin_jwt'

export default function AdminLoginPage() {
  const router = useRouter()
  const [checked, setChecked] = useState(false)

  useEffect(() => {
    const token = sessionStorage.getItem(JWT_KEY)
    if (token) {
      router.replace('/marketplace/admin/create')
    } else {
      setChecked(true)
    }
  }, [router])

  const handleSuccess = (token: string) => {
    sessionStorage.setItem(JWT_KEY, token)
    router.push('/marketplace/admin/create')
  }

  if (!checked) return null

  return (
    <main className="relative flex min-h-screen items-center justify-center bg-black text-white">
      <div className="pointer-events-none fixed inset-0 -z-10 bg-[radial-gradient(circle_at_15%_20%,rgba(255,255,255,0.08),transparent_40%),radial-gradient(circle_at_80%_0%,rgba(56,189,248,0.14),transparent_38%),linear-gradient(to_bottom,#020617,#000000_40%,#020617)]" />

      <div className="w-full max-w-md px-4">
        <div className="rounded-3xl border border-white/10 bg-black/35 p-8 backdrop-blur-xl">
          <h1 className="mb-6 text-2xl font-semibold tracking-tight text-white">Admin Login</h1>
          <LoginForm onSuccess={handleSuccess} />
        </div>
      </div>
    </main>
  )
}
