'use client'

import { useEffect, useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { verifyAdmin } from '@/lib/admin-api'

export function useAdminAuth() {
  const router = useRouter()
  const [isAdmin, setIsAdmin] = useState<boolean | null>(null)
  const [loading, setLoading] = useState(true)

  const checkAuth = useCallback(async () => {
    const token = sessionStorage.getItem('admin_token')
    if (!token) {
      setIsAdmin(false)
      setLoading(false)
      return
    }

    const ok = await verifyAdmin()
    setIsAdmin(ok)
    setLoading(false)

    if (!ok) {
      sessionStorage.removeItem('admin_token')
      router.push('/admin/login')
    }
  }, [router])

  useEffect(() => {
    checkAuth()
  }, [checkAuth])

  const login = useCallback(
    async (token: string) => {
      sessionStorage.setItem('admin_token', token)
      const ok = await verifyAdmin()
      if (ok) {
        setIsAdmin(true)
        router.push('/admin/suggestions')
      } else {
        sessionStorage.removeItem('admin_token')
        throw new Error('Not an admin account')
      }
    },
    [router]
  )

  const logout = useCallback(() => {
    sessionStorage.removeItem('admin_token')
    setIsAdmin(false)
    router.push('/admin/login')
  }, [router])

  return { isAdmin, loading, login, logout }
}
