# ======================================
# Stage 1: Dependencies
# ======================================
FROM node:20-alpine AS deps

# Install libc6-compat for Alpine compatibility
RUN apk add --no-cache libc6-compat

WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./

# Install dependencies with clean cache
RUN npm ci && \
    npm cache clean --force

# ======================================
# Stage 2: Builder
# ======================================
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy source code
COPY . .

# Build arguments for Next.js public environment variables
# These will be baked into the bundle at build time
ARG NEXT_PUBLIC_API_BASE_URL
ARG NEXT_PUBLIC_APP_STORE_ID
ARG NEXT_PUBLIC_PLAY_STORE_ID
ARG NEXT_PUBLIC_POSTHOG_KEY
ARG NEXT_PUBLIC_POSTHOG_HOST
ARG NEXT_PUBLIC_ENABLE_ANALYTICS
ARG NEXT_PUBLIC_MATOMO_URL
ARG NEXT_PUBLIC_MATOMO_SITE_ID
ARG NEXT_PUBLIC_YANDEX_METRIKA_ID
ARG NEXT_PUBLIC_ENABLE_YANDEX_METRIKA
ARG NEXT_PUBLIC_APPMETRICA_IOS_TRACKER_URL
ARG NEXT_PUBLIC_APPMETRICA_ANDROID_TRACKER_URL

# Build argument for server-side API key
ARG API_KEY

# Set environment variables for build
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Pass build args as environment variables for Next.js
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
ENV NEXT_PUBLIC_APP_STORE_ID=$NEXT_PUBLIC_APP_STORE_ID
ENV NEXT_PUBLIC_PLAY_STORE_ID=$NEXT_PUBLIC_PLAY_STORE_ID
ENV NEXT_PUBLIC_POSTHOG_KEY=$NEXT_PUBLIC_POSTHOG_KEY
ENV NEXT_PUBLIC_POSTHOG_HOST=$NEXT_PUBLIC_POSTHOG_HOST
ENV NEXT_PUBLIC_ENABLE_ANALYTICS=$NEXT_PUBLIC_ENABLE_ANALYTICS
ENV NEXT_PUBLIC_MATOMO_URL=$NEXT_PUBLIC_MATOMO_URL
ENV NEXT_PUBLIC_MATOMO_SITE_ID=$NEXT_PUBLIC_MATOMO_SITE_ID
ENV NEXT_PUBLIC_YANDEX_METRIKA_ID=$NEXT_PUBLIC_YANDEX_METRIKA_ID
ENV NEXT_PUBLIC_ENABLE_YANDEX_METRIKA=$NEXT_PUBLIC_ENABLE_YANDEX_METRIKA
ENV NEXT_PUBLIC_APPMETRICA_IOS_TRACKER_URL=$NEXT_PUBLIC_APPMETRICA_IOS_TRACKER_URL
ENV NEXT_PUBLIC_APPMETRICA_ANDROID_TRACKER_URL=$NEXT_PUBLIC_APPMETRICA_ANDROID_TRACKER_URL
ENV API_KEY=$API_KEY

# Build the application
# Next.js will create a standalone build in .next/standalone
RUN npm run build

# ======================================
# Stage 3: Runner (Production)
# ======================================
FROM node:20-alpine AS runner

WORKDIR /app

# Set to production environment
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create a non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy necessary files from builder
# Standalone build includes minimal required files
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Switch to non-root user
USER nextjs

# Expose port 3000
EXPOSE 3000

# Set port environment variable
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/api/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})" || exit 1

# Start the application
CMD ["node", "server.js"]
