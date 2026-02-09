'use client'

import { LoginForm } from '@/components/marketplace/admin/login-form'
import { useAdminAuth } from '@/hooks/use-admin-auth'

export default function AdminLoginPage() {
  const { login } = useAdminAuth()

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a]">
      <div className="w-full max-w-sm">
        <h1 className="mb-8 text-center text-2xl font-bold text-white">Admin Login</h1>
        <LoginForm onSuccess={login} />
      </div>
    </div>
  )
}
