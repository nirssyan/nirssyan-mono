import Link from 'next/link'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: '404 — Страница не найдена | infatium',
  description: 'Запрашиваемая страница не найдена. Вернитесь на главную страницу infatium.',
}

export default function NotFound() {
  return (
    <main className="min-h-screen flex items-center justify-center bg-black">
      <div className="text-center px-4">
        <h1 className="text-8xl sm:text-9xl font-bold text-white/10 mb-4">404</h1>
        <h2 className="text-2xl sm:text-3xl font-bold text-white mb-4">
          Страница не найдена
        </h2>
        <p className="text-white/60 mb-8 max-w-md mx-auto">
          К сожалению, запрашиваемая страница не существует или была перемещена.
        </p>
        <Link
          href="/"
          className="inline-flex items-center justify-center px-6 py-3 bg-white text-black rounded-full text-base font-medium transition-all duration-300 hover:bg-white/90"
        >
          Вернуться на главную
        </Link>
      </div>
    </main>
  )
}
