import { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Image from 'next/image';
import { Calendar, ExternalLink } from 'lucide-react';
import { LockedSummary } from '@/components/news/locked-summary';
import { AppRedirectButton } from '@/components/news/app-redirect-button';
import ReactMarkdown from 'react-markdown';

// Типы для API ответа
interface MediaObject {
  type: 'photo' | 'video' | 'animation' | 'document';
  url: string;
  mime_type?: string;
  width?: number;
  height?: number;
  duration?: number;
  preview_url?: string;
  file_name?: string;
}

interface Source {
  id: string;
  created_at: string;
  post_id: string;
  source_url: string;
}

interface Post {
  id: string;
  created_at: string;
  feed_id: string;
  full_text: string;
  summary: string | null;
  image_url: string | null;
  title: string | null;
  media_objects: MediaObject[];
  sources: Source[];
}

// Получение данных новости через API
async function getPost(postId: string): Promise<Post | null> {
  try {
    const response = await fetch(
      `${process.env.NEXT_PUBLIC_API_BASE_URL}/posts/${postId}`,
      {
        headers: {
          'X-API-Key': process.env.API_KEY || '',
        },
        next: { revalidate: 3600 }, // Cache for 1 hour
      }
    );

    if (!response.ok) {
      return null;
    }

    return response.json();
  } catch (error) {
    console.error('Error fetching post:', error);
    return null;
  }
}

// Функция нормализации текста для сравнения (удаляет все пробелы, табы, переносы)
function normalizeText(text: string): string {
  return text.replace(/\s+/g, '').toLowerCase();
}

// Генерация OpenGraph метатегов для Telegram/WhatsApp
export async function generateMetadata({
  params,
}: {
  params: Promise<{ postId: string }>;
}): Promise<Metadata> {
  const { postId } = await params;
  const post = await getPost(postId);

  if (!post) {
    return {
      title: 'Новость не найдена',
      description: 'Запрашиваемая новость не найдена',
    };
  }

  // Получаем первое изображение из media_objects или используем image_url
  const imageUrl = post.media_objects.find((obj) => obj.type === 'photo')?.url || post.image_url;

  const title = post.title || 'Новость в infatium';
  const description = post.summary || post.full_text.substring(0, 200) + '...';
  const url = `https://infatium.ru/news/${postId}`;

  return {
    title,
    description,
    openGraph: {
      type: 'article',
      title,
      description,
      images: imageUrl ? [
        {
          url: imageUrl,
          width: 1200,
          height: 630,
          alt: title,
        },
      ] : [],
      url,
      siteName: 'infatium',
      locale: 'ru_RU',
    },
    twitter: {
      card: 'summary_large_image',
      title,
      description,
      images: imageUrl ? [imageUrl] : [],
    },
    // iOS Smart App Banner
    appleWebApp: {
      capable: true,
      title: 'infatium',
      statusBarStyle: 'default',
    },
  };
}

// Компонент страницы
export default async function NewsPage({
  params,
}: {
  params: Promise<{ postId: string }>;
}) {
  const { postId } = await params;
  const post = await getPost(postId);

  if (!post) {
    notFound();
  }

  // Получаем первое изображение
  const mainImage = post.media_objects.find((obj) => obj.type === 'photo')?.url || post.image_url;

  // Форматируем дату
  const publishedDate = new Date(post.created_at).toLocaleDateString('ru-RU', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  // Проверяем, одинаковы ли summary и full_text
  const areTextsEqual = post.summary
    ? normalizeText(post.summary) === normalizeText(post.full_text)
    : false;

  return (
    <main className="min-h-screen bg-black text-white">
      {/* Subtle background gradient */}
      <div className="fixed inset-0 bg-gradient-to-b from-black via-black to-gray-900 -z-10" />

      {/* Article Container */}
      <article className="relative max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16 lg:py-24">

        {/* Date Badge */}
        <div className="flex items-center gap-2 mb-6 sm:mb-8">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 backdrop-blur-sm border border-white/10">
            <Calendar className="w-4 h-4 text-white/60" />
            <time dateTime={post.created_at} className="text-sm text-white/60">
              {publishedDate}
            </time>
          </div>
        </div>

        {/* Title with gradient */}
        <h1 className="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-bold mb-8 sm:mb-12 leading-tight tracking-tight bg-gradient-to-r from-white to-white/70 bg-clip-text text-transparent">
          {post.title || 'Новость в infatium'}
        </h1>

        {/* Main Image */}
        {mainImage && (
          <div className="relative mb-12 sm:mb-16 rounded-2xl sm:rounded-3xl overflow-hidden shadow-2xl border border-white/10 bg-white/5 backdrop-blur-sm">
            <div className="relative w-full aspect-video">
              <Image
                src={mainImage}
                alt={post.title || 'Изображение новости'}
                fill
                className="object-cover"
                sizes="(max-width: 768px) 100vw, 896px"
                priority
              />
            </div>
            {/* Image gradient overlay */}
            <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent pointer-events-none" />
          </div>
        )}

        {/* Locked Summary Section - показываем только если тексты разные */}
        {post.summary && !areTextsEqual && (
          <div className="mb-12 sm:mb-16">
            <LockedSummary summary={post.summary} postId={postId} />
          </div>
        )}

        {/* Full Text Section */}
        <div className="relative mb-12 sm:mb-16 rounded-2xl sm:rounded-3xl overflow-hidden bg-white/[0.02] backdrop-blur-sm border border-white/5 p-6 sm:p-8 md:p-10">
          <div className="prose prose-invert prose-lg sm:prose-xl max-w-none">
            <div className="text-base sm:text-lg leading-relaxed text-white/80">
              <ReactMarkdown>{post.full_text}</ReactMarkdown>
            </div>
          </div>
        </div>

        {/* App Redirect Section - показываем только если тексты одинаковые */}
        {areTextsEqual && (
          <div className="relative mb-12 sm:mb-16 rounded-2xl sm:rounded-3xl overflow-hidden bg-gradient-to-br from-white/5 to-white/[0.02] backdrop-blur-sm border border-white/10 p-8 sm:p-10">
            <div className="text-center space-y-6">
              <div className="space-y-2">
                <h3 className="text-xl sm:text-2xl font-semibold text-white">
                  Читайте в приложении infatium
                </h3>
                <p className="text-sm sm:text-base text-white/60">
                  Получайте персонализированные новости и AI-сводки в удобном формате
                </p>
              </div>
              <AppRedirectButton postId={postId} />
            </div>
            {/* Decorative gradient border effect */}
            <div className="absolute inset-0 rounded-2xl sm:rounded-3xl bg-gradient-to-br from-blue-500/10 via-transparent to-purple-500/10 pointer-events-none" />
          </div>
        )}

        {/* Sources Section */}
        {post.sources && post.sources.length > 0 && (
          <div className="relative rounded-2xl sm:rounded-3xl overflow-hidden bg-white/[0.02] backdrop-blur-sm border border-white/5 p-6 sm:p-8">
            <h3 className="text-xl sm:text-2xl font-bold text-white mb-6">Источники</h3>
            <ul className="space-y-3">
              {post.sources.map((source) => (
                <li key={source.id}>
                  <a
                    href={source.source_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="group flex items-center gap-3 text-sm sm:text-base text-white/60 hover:text-white transition-colors duration-200"
                  >
                    <ExternalLink className="w-4 h-4 flex-shrink-0 group-hover:text-blue-400 transition-colors" />
                    <span className="break-all group-hover:underline">{source.source_url}</span>
                  </a>
                </li>
              ))}
            </ul>
          </div>
        )}
      </article>

      {/* Minimal Footer */}
      <footer className="relative border-t border-white/5 py-8 sm:py-12 mt-12 sm:mt-20">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center space-y-4">
            <p className="text-sm sm:text-base text-white/40">
              © 2026 infatium. Персональный ИИ-помощник для поиска информации.
            </p>
            <div className="flex justify-center items-center gap-6 text-xs sm:text-sm">
              <a
                href="https://infatium.ru"
                className="text-white/50 hover:text-white transition-colors duration-200"
              >
                Главная
              </a>
              <span className="text-white/20">•</span>
              <a
                href="mailto:hello@infatium.ai"
                className="text-white/50 hover:text-white transition-colors duration-200"
              >
                Контакты
              </a>
            </div>
          </div>
        </div>
      </footer>
    </main>
  );
}
