import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import { Header } from "@/components/sections/header";
import { MatomoProvider } from "@/components/providers/matomo-provider";
import { YandexMetrikaProvider } from "@/components/providers/yandex-metrika-provider";
import { LanguageProvider } from "@/lib/language-context";
import { JsonLd } from "@/components/seo/json-ld";
import { CookieConsent } from "@/components/ui/cookie-consent";
import { SplashScreen } from "@/components/ui/splash-screen";

const inter = Inter({
  variable: "--font-sans",
  subsets: ["latin", "cyrillic"],
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-mono",
  subsets: ["latin", "cyrillic"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "infatium — верни контроль над информацией",
  description: "Одно приложение вместо десяти источников. Персональная лента новостей без шума, рекламы и бесконечного скроллинга. Читай осознанно — трать время на то, что действительно важно.",
  keywords: "персональная лента новостей, информационная гигиена, осознанное потребление контента, продуктивность, фильтрация новостей, infatium, цифровой детокс, контроль информации",
  authors: [{ name: "Infatium Team" }],
  creator: "infatium",
  publisher: "infatium",
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  metadataBase: new URL('https://infatium.ru'),
  alternates: {
    canonical: '/',
  },
  openGraph: {
    title: "infatium — верни контроль над информацией",
    description: "Одно приложение вместо десяти источников. Персональная лента без шума и бесконечного скроллинга.",
    url: "https://infatium.ru",
    siteName: "infatium",
    locale: "ru_RU",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "infatium — верни контроль над информацией",
    description: "Одно приложение вместо десяти источников. Персональная лента без шума и бесконечного скроллинга.",
    creator: "@infatium",
  },
  manifest: '/manifest.json',
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
  verification: {
    yandex: "226026fbaa36529d",
    google: "JBiudylpH7HEgGTOpXGMFIcYSWTr_IkpEKX2JRsuc-c",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ru" className="dark">
      <head>
        {/* Preconnect to external services for faster loading */}
        <link rel="preconnect" href="https://mc.yandex.ru" />
        <link rel="dns-prefetch" href="https://mc.yandex.ru" />
        {/* Preload hero video - browser selects appropriate asset based on media query */}
        <link
          rel="preload"
          href="/hero-video.mp4"
          as="video"
          type="video/mp4"
          media="(min-width: 640px)"
        />
        <link
          rel="preload"
          href="/hero-video-mobile.mp4"
          as="video"
          type="video/mp4"
          media="(max-width: 639px)"
        />
        <link
          rel="preload"
          href="/hero-poster-mobile.jpg"
          as="image"
          media="(max-width: 639px)"
        />
      </head>
      <body
        className={`${inter.variable} ${jetbrainsMono.variable} antialiased`}
      >
        <SplashScreen />
        <JsonLd />
        <LanguageProvider>
          <MatomoProvider>
            <YandexMetrikaProvider>
              <Header />
              {children}
              <CookieConsent />
            </YandexMetrikaProvider>
          </MatomoProvider>
        </LanguageProvider>
      </body>
    </html>
  );
}
