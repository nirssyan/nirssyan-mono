'use client'

import { usePathname } from 'next/navigation'
import Link from 'next/link'
import { useAdminAuth } from '@/hooks/use-admin-auth'

const navItems = [
  { href: '/admin/suggestions', label: 'Suggestions' },
  { href: '/admin/tags', label: 'Tags' },
  { href: '/admin/marketplace', label: 'Marketplace' },
]

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const { isAdmin, loading, logout } = useAdminAuth()

  if (pathname === '/admin/login') {
    return <>{children}</>
  }

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#0a0a0a]">
        <div className="text-white/50">Loading...</div>
      </div>
    )
  }

  if (!isAdmin) {
    return null
  }

  return (
    <div className="flex min-h-screen bg-[#0a0a0a]">
      <aside className="fixed left-0 top-0 flex h-full w-56 flex-col border-r border-white/10 bg-[#0a0a0a]">
        <div className="border-b border-white/10 px-5 py-4">
          <Link href="/admin" className="text-lg font-semibold text-white">
            infatium admin
          </Link>
        </div>
        <nav className="flex-1 space-y-1 p-3">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={`block rounded-lg px-3 py-2 text-sm transition-colors ${
                pathname.startsWith(item.href)
                  ? 'bg-white/10 text-white'
                  : 'text-white/60 hover:bg-white/5 hover:text-white'
              }`}
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="border-t border-white/10 p-3">
          <button
            onClick={logout}
            className="w-full rounded-lg px-3 py-2 text-left text-sm text-white/60 transition-colors hover:bg-white/5 hover:text-white"
          >
            Logout
          </button>
        </div>
      </aside>
      <main className="ml-56 flex-1 p-8">{children}</main>
    </div>
  )
}
