import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Output for Docker deployment
  output: 'standalone',

  // Performance optimizations
  experimental: {
    optimizePackageImports: ['lucide-react', 'framer-motion'],
  },

  // Image optimization
  // SECURITY: No remote patterns - external images use unoptimized mode
  // This prevents SSRF via /_next/image endpoint
  images: {
    formats: ['image/webp', 'image/avif'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    remotePatterns: [],
  },

  // Compression and caching
  compress: true,
  poweredByHeader: false,

  // Production optimizations
  productionBrowserSourceMaps: false,
  generateEtags: false,

  // Headers for security and performance
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'Content-Security-Policy',
            value: "frame-ancestors 'self' https://metrika.yandex.ru https://metrika.yandex.by https://metrica.yandex.com https://metrica.yandex.com.tr https://*.webvisor.com https://webvisor.com",
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin',
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
        ],
      },
    ]
  },

  // Bundle analyzer (uncomment for analysis)
  ...(process.env.ANALYZE === 'true' ? {} : {}),
};

export default nextConfig;
