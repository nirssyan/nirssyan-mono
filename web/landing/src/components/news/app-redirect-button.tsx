'use client';

import { useState } from 'react';
import { Sparkles, Loader2 } from 'lucide-react';
import { reachGoal } from '@/lib/yandex-metrika';

interface AppRedirectButtonProps {
  postId: string;
}

export function AppRedirectButton({ postId }: AppRedirectButtonProps) {
  const [isRedirecting, setIsRedirecting] = useState(false);

  const handleOpenInApp = () => {
    setIsRedirecting(true);
    reachGoal('open_in_app', { post_id: postId });

    // Deep link URL
    const deepLink = `infatium://news/${postId}`;

    // Определяем платформу
    const userAgent = typeof window !== 'undefined' ? navigator.userAgent : '';
    const isIOS = /iPhone|iPad|iPod/.test(userAgent);
    const isAndroid = /Android/.test(userAgent);

    // Пытаемся открыть приложение через deep link
    window.location.href = deepLink;

    // Если приложение не открылось, редиректим на сторы
    setTimeout(() => {
      if (isIOS) {
        const appStoreUrl = process.env.NEXT_PUBLIC_APPMETRICA_IOS_TRACKER_URL;
        if (appStoreUrl) {
          window.location.href = appStoreUrl;
        } else {
          const appStoreId = process.env.NEXT_PUBLIC_APP_STORE_ID;
          if (appStoreId && appStoreId !== 'your_app_store_id_here') {
            window.location.href = `https://apps.apple.com/app/id${appStoreId}`;
          } else {
            window.location.href = 'https://apps.apple.com/search?term=infatium';
          }
        }
      } else if (isAndroid) {
        const androidUrl = process.env.NEXT_PUBLIC_APPMETRICA_ANDROID_TRACKER_URL;
        if (androidUrl) {
          window.location.href = androidUrl;
        } else {
          const playStoreId = process.env.NEXT_PUBLIC_PLAY_STORE_ID || 'com.infatium';
          window.location.href = `https://play.google.com/store/apps/details?id=${playStoreId}`;
        }
      } else {
        // Desktop - показываем ссылки
        setIsRedirecting(false);
        showDesktopLinks();
      }
    }, 500);
  };

  const showDesktopLinks = () => {
    const appStoreId = process.env.NEXT_PUBLIC_APP_STORE_ID;
    const playStoreId = process.env.NEXT_PUBLIC_PLAY_STORE_ID || 'com.infatium';

    const appStoreUrl = process.env.NEXT_PUBLIC_APPMETRICA_IOS_TRACKER_URL
      || (appStoreId && appStoreId !== 'your_app_store_id_here'
        ? `https://apps.apple.com/app/id${appStoreId}`
        : 'https://apps.apple.com/search?term=infatium');

    const playStoreUrl = process.env.NEXT_PUBLIC_APPMETRICA_ANDROID_TRACKER_URL
      || `https://play.google.com/store/apps/details?id=${playStoreId}`;

    alert(
      `Скачайте infatium:\n\n` +
      `iOS: ${appStoreUrl}\n\n` +
      `Android: ${playStoreUrl}`
    );
  };

  return (
    <button
      onClick={handleOpenInApp}
      disabled={isRedirecting}
      className="
        group relative px-8 py-4 bg-white text-black rounded-full
        text-base sm:text-lg font-semibold
        shadow-lg hover:shadow-xl
        transition-all duration-300 hover:scale-105
        disabled:opacity-50 disabled:cursor-not-allowed
        focus:outline-none focus:ring-2 focus:ring-white/20
        overflow-hidden
      "
    >
      {/* Hover gradient effect */}
      <div className="absolute inset-0 bg-gradient-to-r from-white via-gray-100 to-white opacity-0 group-hover:opacity-100 transition-opacity duration-300" />

      {/* Button content */}
      <span className="relative z-10 flex items-center justify-center gap-2">
        {isRedirecting ? (
          <>
            <Loader2 className="w-5 h-5 animate-spin" />
            <span>Открываем...</span>
          </>
        ) : (
          <>
            <Sparkles className="w-5 h-5" />
            <span>Открыть в infatium</span>
          </>
        )}
      </span>
    </button>
  );
}
