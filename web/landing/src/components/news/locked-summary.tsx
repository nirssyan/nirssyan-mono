'use client';

import { AppRedirectButton } from './app-redirect-button';

interface LockedSummaryProps {
  summary: string;
  postId: string;
}

// Функция для извлечения первого предложения
function getFirstSentence(text: string): string {
  // Ищем первое предложение (заканчивающееся на . ! или ?)
  const match = text.match(/^[^.!?]+[.!?]+/);
  return match ? match[0].trim() : text.split('\n')[0];
}

// Функция для получения остального текста
function getRemainingText(text: string, firstSentence: string): string {
  return text.substring(firstSentence.length).trim();
}

export function LockedSummary({ summary, postId }: LockedSummaryProps) {
  const firstSentence = getFirstSentence(summary);
  const remainingText = getRemainingText(summary, firstSentence);
  const hasMore = remainingText.length > 0;

  return (
    <div className="relative rounded-2xl sm:rounded-3xl overflow-hidden bg-gradient-to-br from-white/5 to-white/[0.02] backdrop-blur-sm border border-white/10 p-6 sm:p-8 md:p-10">
      {/* Summary content */}
      <div className="mb-6">
        {/* Первое предложение - видимое и читаемое */}
        <p className="text-base sm:text-lg leading-relaxed text-white/90 mb-3">
          {firstSentence}
        </p>

        {/* Остальной текст - размытый */}
        {hasMore && (
          <div className="relative">
            <p className="text-base sm:text-lg leading-relaxed text-white/30 blur-sm select-none pointer-events-none line-clamp-4">
              {remainingText}
            </p>
            {/* Gradient overlay */}
            <div className="absolute inset-0 bg-gradient-to-b from-transparent via-black/30 to-black/60 pointer-events-none" />
          </div>
        )}
      </div>

      {/* CTA */}
      <div className="text-center space-y-4">
        <AppRedirectButton postId={postId} />
        <p className="text-xs sm:text-sm text-white/40">
          Краткие AI-сводки доступны только в приложении infatium
        </p>
      </div>

      {/* Decorative gradient border effect */}
      <div className="absolute inset-0 rounded-2xl sm:rounded-3xl bg-gradient-to-br from-blue-500/10 via-transparent to-purple-500/10 pointer-events-none" />
    </div>
  );
}
