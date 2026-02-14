# Web Share Service - Документация для реализации

## Обзор

Этот документ содержит инструкции для создания отдельного веб-сервиса для шаринга новостей с красивыми превью в Telegram, WhatsApp и других мессенджерах.

## URL структура

```
https://share.makefeed.com/news/{postId}
```

Где `{postId}` - это ID новости из базы данных Supabase.

## Технологический стек (рекомендации)

### Backend
- **Next.js** (рекомендуется) - для Server-Side Rendering (SSR)
- **Nuxt.js** - альтернатива для Vue.js
- **Vite + Express** - минималистичный вариант

### База данных
- **Supabase Client** - прямой доступ к базе данных через Supabase JS SDK
- Альтернатива: API endpoint на makefeed.nirssyan.ru

### Hosting
- **Vercel** - рекомендуется для Next.js (бесплатный plan)
- **Netlify** - альтернатива
- **Cloudflare Pages** - для статических сайтов

### UI
- **Tailwind CSS** - для быстрой верстки
- **Markdown renderer** - `marked` или `remark` для отображения контента

## Структура базы данных Supabase

Таблицы для получения данных новости:

```sql
-- Основная таблица с новостями
posts {
  id: string (UUID)
  title: string
  subtitle: string (краткое описание)
  content: string (полный текст в Markdown)
  image_url: string (основное изображение)
  media_urls: string[] (дополнительные медиа)
  category: string
  published_at: timestamp
  feed_id: string
}

-- Таблица с источниками
sources {
  id: string
  source_url: string
  created_at: timestamp
  post_id: string (FK -> posts.id)
}

-- Таблица с лентами
feeds {
  id: string
  name: string
  created_at: timestamp
}
```

## OpenGraph метатеги (КРИТИЧНО!)

### Минимальный набор для Telegram

```html
<!DOCTYPE html>
<html lang="ru">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- Основные OpenGraph теги -->
  <meta property="og:type" content="article">
  <meta property="og:title" content="{news.title}">
  <meta property="og:description" content="{news.subtitle}">
  <meta property="og:image" content="{news.imageUrl}">
  <meta property="og:url" content="https://share.makefeed.com/news/{postId}">
  <meta property="og:site_name" content="Makefeed">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{news.title}">
  <meta name="twitter:description" content="{news.subtitle}">
  <meta name="twitter:image" content="{news.imageUrl}">

  <!-- iOS Smart App Banner -->
  <meta name="apple-itunes-app" content="app-id={YOUR_APP_STORE_ID}">

  <!-- Title -->
  <title>{news.title} - Makefeed</title>
</head>
```

### Пример с Next.js

```typescript
// app/news/[postId]/page.tsx
import { Metadata } from 'next'
import { supabase } from '@/lib/supabase'

export async function generateMetadata({ params }): Promise<Metadata> {
  const { data: post } = await supabase
    .from('posts')
    .select('*')
    .eq('id', params.postId)
    .single()

  if (!post) {
    return { title: 'Новость не найдена' }
  }

  return {
    title: post.title,
    description: post.subtitle,
    openGraph: {
      type: 'article',
      title: post.title,
      description: post.subtitle,
      images: [
        {
          url: post.image_url,
          width: 1200,
          height: 630,
          alt: post.title,
        },
      ],
      url: `https://share.makefeed.com/news/${params.postId}`,
      siteName: 'Makefeed',
    },
    twitter: {
      card: 'summary_large_image',
      title: post.title,
      description: post.subtitle,
      images: [post.image_url],
    },
    appleWebApp: {
      capable: true,
      title: 'Makefeed',
      statusBarStyle: 'default',
    },
  }
}
```

## HTML структура страницы

```html
<body>
  <!-- Header с логотипом -->
  <header class="sticky top-0 bg-white border-b">
    <div class="container mx-auto px-4 py-4">
      <img src="/logo.svg" alt="Makefeed" class="h-8">
    </div>
  </header>

  <!-- Основной контент -->
  <article class="container mx-auto px-4 py-8 max-w-3xl">
    <!-- Категория -->
    <span class="inline-block bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm mb-4">
      {news.category}
    </span>

    <!-- Заголовок -->
    <h1 class="text-4xl font-bold mb-4">{news.title}</h1>

    <!-- Метаданные -->
    <div class="flex items-center text-gray-600 text-sm mb-6">
      <span>{news.source}</span>
      <span class="mx-2">•</span>
      <time>{formatDate(news.publishedAt)}</time>
    </div>

    <!-- Изображение -->
    <img
      src="{news.imageUrl}"
      alt="{news.title}"
      class="w-full rounded-2xl mb-6"
    >

    <!-- Краткое описание (ЗАБЛЮРЕННОЕ для не-пользователей) -->
    <div class="relative mb-8">
      <div class="prose max-w-none blur-sm">
        {news.subtitle}
      </div>

      <!-- Градиентный оверлей -->
      <div class="absolute inset-0 bg-gradient-to-b from-transparent to-white"></div>

      <!-- CTA кнопка -->
      <div class="absolute inset-x-0 bottom-0 flex justify-center pb-8">
        <button
          onclick="openInApp()"
          class="bg-blue-600 text-white px-8 py-4 rounded-full text-lg font-semibold shadow-lg hover:bg-blue-700 transition"
        >
          📱 Читать полностью в Makefeed
        </button>
      </div>
    </div>

    <!-- Альтернатива: показать первые 2-3 абзаца нормально, остальное заблюрить -->
    <!-- Это можно сделать через CSS или JavaScript -->
  </article>

  <!-- Footer -->
  <footer class="bg-gray-100 py-8 mt-12">
    <div class="container mx-auto px-4 text-center text-gray-600">
      <p>© 2025 Makefeed. Персонализированные новости с AI.</p>
      <div class="mt-4 space-x-4">
        <a href="#" class="hover:text-blue-600">App Store</a>
        <a href="#" class="hover:text-blue-600">Google Play</a>
      </div>
    </div>
  </footer>
</body>
```

## Deep Linking и редирект

### JavaScript для открытия приложения

```javascript
// public/js/app-redirect.js

const APP_STORE_ID = 'YOUR_APP_STORE_ID'; // Получить из App Store Connect
const PLAY_STORE_ID = 'com.makefeed'; // Package name из Android
const POST_ID = window.location.pathname.split('/').pop();

function openInApp() {
  const deepLink = `makefeed://news/${POST_ID}`;

  // Определяем платформу
  const userAgent = navigator.userAgent || navigator.vendor || window.opera;
  const isIOS = /iPhone|iPad|iPod/.test(userAgent);
  const isAndroid = /Android/.test(userAgent);

  // Пытаемся открыть приложение
  window.location.href = deepLink;

  // Если приложение не открылось - редирект на сторы
  setTimeout(() => {
    if (isIOS) {
      window.location.href = `https://apps.apple.com/app/id${APP_STORE_ID}`;
    } else if (isAndroid) {
      window.location.href = `https://play.google.com/store/apps/details?id=${PLAY_STORE_ID}`;
    } else {
      // Desktop - показать QR код или ссылки на оба стора
      showStoreLinks();
    }
  }, 500);
}

function showStoreLinks() {
  // Показать модальное окно с ссылками на App Store и Google Play
  const modal = document.createElement('div');
  modal.innerHTML = `
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white p-8 rounded-2xl max-w-md">
        <h2 class="text-2xl font-bold mb-4">Скачайте Makefeed</h2>
        <div class="space-y-4">
          <a href="https://apps.apple.com/app/id${APP_STORE_ID}" class="block">
            <img src="/badges/app-store.svg" alt="Download on App Store">
          </a>
          <a href="https://play.google.com/store/apps/details?id=${PLAY_STORE_ID}" class="block">
            <img src="/badges/google-play.svg" alt="Get it on Google Play">
          </a>
        </div>
        <button onclick="this.parentElement.remove()" class="mt-4 text-gray-500">
          Закрыть
        </button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);
}

// Автоматическая попытка открыть приложение при загрузке (опционально)
window.addEventListener('load', () => {
  const autoOpen = new URLSearchParams(window.location.search).get('autoOpen');
  if (autoOpen === 'true') {
    openInApp();
  }
});
```

## Пример API endpoint для получения данных (Next.js)

```typescript
// app/api/news/[postId]/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)

export async function GET(
  request: NextRequest,
  { params }: { params: { postId: string } }
) {
  try {
    // Получаем новость с join на feeds и sources
    const { data: post, error } = await supabase
      .from('posts')
      .select(`
        *,
        feeds (
          id,
          name
        ),
        sources (
          id,
          source_url
        )
      `)
      .eq('id', params.postId)
      .single()

    if (error) {
      return NextResponse.json(
        { error: 'Post not found' },
        { status: 404 }
      )
    }

    return NextResponse.json(post)
  } catch (error) {
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
```

## Пример полной страницы (Next.js App Router)

```typescript
// app/news/[postId]/page.tsx
import { supabase } from '@/lib/supabase'
import { notFound } from 'next/navigation'
import ReactMarkdown from 'react-markdown'

interface NewsPageProps {
  params: {
    postId: string
  }
}

export default async function NewsPage({ params }: NewsPageProps) {
  const { data: post, error } = await supabase
    .from('posts')
    .select('*, feeds(*), sources(*)')
    .eq('id', params.postId)
    .single()

  if (error || !post) {
    notFound()
  }

  return (
    <main className="min-h-screen bg-white">
      {/* Header */}
      <header className="sticky top-0 bg-white border-b backdrop-blur-sm bg-opacity-90 z-50">
        <div className="container mx-auto px-4 py-4">
          <h1 className="text-xl font-bold">Makefeed</h1>
        </div>
      </header>

      {/* Article */}
      <article className="container mx-auto px-4 py-8 max-w-3xl">
        {/* Category */}
        <span className="inline-block bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm mb-4">
          {post.category}
        </span>

        {/* Title */}
        <h1 className="text-4xl font-bold mb-4 leading-tight">
          {post.title}
        </h1>

        {/* Meta */}
        <div className="flex items-center text-gray-600 text-sm mb-6">
          <span>{post.feeds?.name || 'Unknown'}</span>
          <span className="mx-2">•</span>
          <time>{new Date(post.published_at).toLocaleDateString('ru-RU')}</time>
        </div>

        {/* Image */}
        {post.image_url && (
          <img
            src={post.image_url}
            alt={post.title}
            className="w-full rounded-2xl mb-8 shadow-lg"
          />
        )}

        {/* Blurred preview */}
        <div className="relative mb-12">
          {/* First 2 paragraphs visible */}
          <div className="prose max-w-none mb-6">
            <ReactMarkdown>
              {post.subtitle}
            </ReactMarkdown>
          </div>

          {/* Blurred content */}
          <div className="relative">
            <div className="prose max-w-none blur-md select-none">
              <ReactMarkdown>
                {post.content.substring(0, 500)}
              </ReactMarkdown>
            </div>

            {/* Gradient overlay */}
            <div className="absolute inset-0 bg-gradient-to-b from-transparent via-white to-white"></div>

            {/* CTA Button */}
            <div className="absolute inset-x-0 bottom-0 flex flex-col items-center pb-8 space-y-4">
              <button
                onClick={() => window.openInApp?.()}
                className="bg-blue-600 text-white px-8 py-4 rounded-full text-lg font-semibold shadow-lg hover:bg-blue-700 transition-all hover:scale-105"
              >
                📱 Читать полностью в Makefeed
              </button>
              <p className="text-sm text-gray-500">
                Или скачайте приложение в App Store / Google Play
              </p>
            </div>
          </div>
        </div>

        {/* Sources */}
        {post.sources && post.sources.length > 0 && (
          <div className="border-t pt-6 mt-8">
            <h3 className="text-lg font-semibold mb-4">Источники:</h3>
            <ul className="space-y-2">
              {post.sources.map((source: any) => (
                <li key={source.id}>
                  <a
                    href={source.source_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-600 hover:underline"
                  >
                    {source.source_url}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        )}
      </article>

      {/* Footer */}
      <footer className="bg-gray-100 py-8 mt-12">
        <div className="container mx-auto px-4 text-center text-gray-600">
          <p className="mb-4">© 2025 Makefeed. Персонализированные новости с AI.</p>
          <div className="flex justify-center space-x-6">
            <a href="#" className="hover:text-blue-600">App Store</a>
            <a href="#" className="hover:text-blue-600">Google Play</a>
          </div>
        </div>
      </footer>

      {/* JavaScript for app opening */}
      <script src="/js/app-redirect.js" />
    </main>
  )
}
```

## Деплой на Vercel

### 1. Подготовка

```bash
# Установить Vercel CLI
npm i -g vercel

# Инициализировать проект
vercel init

# Выбрать Next.js template
```

### 2. Environment Variables

В Vercel Dashboard добавить:

```
NEXT_PUBLIC_SUPABASE_URL=https://dev.service.infatium.ru
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 3. Деплой

```bash
# Production
vercel --prod
```

### 4. Custom Domain

В Vercel Dashboard:
1. Settings → Domains
2. Добавить `share.makefeed.com`
3. Настроить DNS записи в вашем регистраторе

## Тестирование OpenGraph

### 1. Facebook Sharing Debugger
https://developers.facebook.com/tools/debug/

### 2. Twitter Card Validator
https://cards-dev.twitter.com/validator

### 3. Telegram
Просто отправьте ссылку себе в Saved Messages

## Обновление URL в приложении

После деплоя веб-сервиса, обновите `SHARE_BASE_URL` при сборке приложения:

```bash
flutter build apk --release \
  --dart-define=SHARE_BASE_URL=https://share.makefeed.com \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=API_KEY=... \
  --dart-define=POSTHOG_API_KEY=...
```

## Важные замечания

1. **SSR обязателен**: Telegram и другие мессенджеры не выполняют JavaScript, поэтому метатеги должны быть в исходном HTML.

2. **Размер изображения**: Для `og:image` рекомендуется 1200x630px. Убедитесь, что изображения доступны по HTTPS.

3. **Cache**: OpenGraph кэшируется мессенджерами. Используйте Facebook Debugger для очистки кэша.

4. **Deep links**: Проверьте, что deep link схема `makefeed://` работает на устройствах. Настройки в:
   - iOS: `ios/Runner/Info.plist`
   - Android: `android/app/src/main/AndroidManifest.xml`

5. **Analytics**: Добавьте Google Analytics или PostHog для отслеживания открытий веб-страницы.

## Пример package.json для Next.js

```json
{
  "name": "makefeed-share",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^14.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@supabase/supabase-js": "^2.38.0",
    "react-markdown": "^9.0.0",
    "tailwindcss": "^3.3.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/react": "^18.2.0",
    "typescript": "^5.0.0"
  }
}
```

## Поддержка

При возникновении проблем:
1. Проверьте SSR - метатеги должны быть в исходном HTML
2. Проверьте CORS - Supabase должен разрешать запросы с вашего домена
3. Проверьте изображения - они должны быть доступны по HTTPS
4. Используйте инструменты для отладки OpenGraph (см. раздел "Тестирование")
