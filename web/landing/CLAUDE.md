# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

infatium is a landing page for an AI-powered personal assistant app, built as a single-page application using Next.js 15 with the App Router, React 19, and TypeScript. The site features a dark theme with animated sections showcasing the product.

## Development Commands

```bash
# Development
npm run dev              # Start dev server on http://localhost:3000

# IMPORTANT: Always ensure port 3000 is available before starting dev server
# If port 3000 is in use, kill the process and restart on port 3000:
lsof -ti:3000 | xargs kill -9 && npm run dev

# Production
npm run build           # Build for production
npm run start           # Run production server

# Code Quality
npm run lint            # Run ESLint
npm run lint:fix        # Auto-fix linting issues
npm run type-check      # TypeScript type checking without emitting files

# Analysis
npm run analyze         # Analyze bundle size (requires ANALYZE=true env var)
```

### Development Workflow

**Before starting development:**
1. Always kill any existing process on port 3000
2. Start the dev server on port 3000 (never use alternative ports)
3. This ensures consistency and prevents port conflicts

```bash
# Check if port 3000 is in use
lsof -i:3000

# Kill the process and start dev server
lsof -ti:3000 | xargs kill -9 && npm run dev
```

## Architecture

### Project Structure

- **`src/app/`** - Next.js App Router pages and layouts
  - `layout.tsx` - Root layout with metadata, fonts (Inter, JetBrains Mono), and dark mode class
  - `page.tsx` - Main page that composes all sections
  - `globals.css` - Global styles with CSS variables for dark theme

- **`src/components/sections/`** - Main landing page sections (imported in order):
  - `hero.tsx` - Hero section with typewriter effect and gradient background
  - `ai-animation.tsx` - Animated AI demonstration
  - `features.tsx` - Feature cards grid
  - `social-proof.tsx` - Testimonials and statistics
  - `about.tsx` - About section
  - `waitlist.tsx` - Email signup form
  - `footer.tsx` - Footer with links and contact info

- **`src/components/ui/`** - Reusable UI components:
  - `button.tsx` - Button component with CVA variants
  - `badge.tsx` - Badge component with CVA variants
  - `lazy-video.tsx` - Video component with lazy loading via IntersectionObserver and responsive src support

- **`src/lib/`** - Utilities:
  - `utils.ts` - Contains `cn()` helper for merging Tailwind classes with clsx and tailwind-merge

### Key Technologies

- **Next.js 15** with App Router - File-based routing with `src/app/`
- **React 19** - Client components use `'use client'` directive
- **TypeScript** - Strict mode enabled, paths alias `@/*` maps to `./src/*`
- **Tailwind CSS v4** - Utility-first styling with custom dark theme
- **Framer Motion** - Animations and transitions (optimized imports via next.config)
- **Lucide React** - Icon library (optimized imports via next.config)
- **CVA** - Class Variance Authority for component variants

### Styling System

- **Dark theme only** - Root html element has `className="dark"`
- **CSS Variables** - Defined in `globals.css` for colors: `--background`, `--foreground`, `--primary`, `--accent`, etc.
- **Tailwind Extensions** - Custom animations (fade-in, float, glow, orb, typing), keyframes, and colors
- **Custom scrollbar** - Styled webkit scrollbar matching the dark theme
- **Responsive breakpoints** - Mobile-first with special handling for mobile (<640px) and large screens (>1920px)
- **Reduced motion** - Respects `prefers-reduced-motion` media query

### Component Patterns

- All interactive components use `'use client'` directive at the top
- UI components in `src/components/ui/` follow shadcn/ui patterns with CVA for variants
- The `cn()` utility from `src/lib/utils.ts` is used for conditional class merging
- Section components are self-contained and imported into `page.tsx`

### Environment Variables

Expected in `.env.local` (reference `.env.production.example`):
- `NEXT_PUBLIC_MATOMO_URL` - Self-hosted Matomo instance URL
- `NEXT_PUBLIC_MATOMO_SITE_ID` - Site ID from Matomo dashboard
- `NEXT_PUBLIC_ENABLE_ANALYTICS` - Analytics toggle (true/false)

### Analytics (Matomo)

The project uses self-hosted Matomo for privacy-focused cookieless analytics:

- **`src/lib/matomo.ts`** - Matomo configuration and initialization (cookieless mode)
- **`src/hooks/use-matomo.ts`** - React hook for event tracking (trackCTAClick, trackSectionView, trackExternalLink)
- **`src/hooks/use-intersection-tracking.ts`** - Automatic section visibility tracking
- **`src/components/providers/matomo-provider.tsx`** - Provider component

**Event Tracking:**
```typescript
const { trackCTAClick, trackSectionView, trackExternalLink } = useMatomo()

trackCTAClick({ button_text: 'Get Started', section: 'hero', destination: '/signup' })
trackSectionView({ section: 'features', time_to_view: 1500 })
trackExternalLink({ link_text: 'GitHub', destination: 'https://github.com', section: 'footer' })
```

### Performance Optimizations

- Package imports optimized in `next.config.ts` for lucide-react and framer-motion
- Image optimization configured for WebP/AVIF formats with multiple device sizes
- Security headers configured (X-Frame-Options, X-Content-Type-Options, etc.)
- Animation complexity reduced on mobile devices via CSS media queries
- Font optimization with `display: swap` for Inter and JetBrains Mono

### Video Assets

The landing page uses video backgrounds for enhanced visual experience:

#### Hero Section (`src/components/sections/hero.tsx`)
- **Desktop** (`hero-video.mp4`, ~2.2MB): Landscape orientation (16:9), jellyfish animation
- **Mobile** (`hero-video-mobile.mp4`, ~1.2MB): Portrait orientation (9:16), optimized jellyfish framing
- Responsive breakpoint: `sm` (640px) - mobile uses `sm:hidden`, desktop uses `hidden sm:block`
- Dark overlay on mobile (`bg-black/30`) for text readability
- Bottom gradient for seamless transition to next section

#### Problems Section (`src/components/sections/features.tsx`)
- **Desktop**: Static image (`problem-bg.jpg`) - underwater scene with plastic waste
- **Mobile** (`problem-video-mobile.mp4`, ~995KB): Portrait orientation video, optimized with lazy loading
- Same responsive pattern as hero section

**Performance Notes:**
- Hero videos use `autoPlay`, `loop`, `muted`, `playsInline` with `preload="auto"`
- Features section video uses lazy loading with IntersectionObserver
- LazyVideo component (`src/components/ui/lazy-video.tsx`) provides conditional loading
- Videos load only for current device (mobile OR desktop, not both)
- Mobile overlays enhance readability on smaller screens
- Videos are served directly from `/public` directory

### Deployment

**IMPORTANT:** The project uses automated GitHub Actions deployment to Kubernetes. This is the primary deployment method.

#### GitHub Actions + Kubernetes (Production)

The project is automatically deployed to Kubernetes cluster via GitHub Actions workflows.

**Workflows:**

1. **`.github/workflows/deploy-develop.yml`** - Deploy to DEV environment
   - **Trigger:** Push to `develop` branch
   - **Registry:** `registry.infra.makekod.ru/infatium-landing:dev`
   - **Kubernetes:**
     - Namespace: `infatium-dev`
     - Deployment: `landing`
     - Strategy: Rolling restart
   - **Notifications:** Telegram bot sends deployment status

2. **`.github/workflows/docker-build.yml`** - Build production image
   - **Trigger:** Push to `main` branch or manual workflow dispatch
   - **Registry:** `registry.infra.makekod.ru/makelanding`
   - **Tags:** `latest` and commit SHA
   - **Integration:** Sends webhook to n8n for automation

**Monitoring Kubernetes:**

```bash
# Check deployment status in DEV
kubectl get deployment landing -n infatium-dev

# View pods
kubectl get pods -n infatium-dev -l app=landing

# View logs
kubectl logs -f deployment/landing -n infatium-dev

# Check recent events
kubectl get events -n infatium-dev --sort-by='.lastTimestamp' | tail -20

# Restart deployment manually (if needed)
kubectl rollout restart deployment/landing -n infatium-dev
```

**Required GitHub Secrets:**
- `DOCKER_REGISTRY_USERNAME` - Registry authentication
- `DOCKER_REGISTRY_PASSWORD` - Registry authentication
- `KUBECONFIG` - Base64 encoded kubeconfig file
- `TELEGRAM_DEPLOY_BOT_TOKEN` - Telegram notifications
- `NEXT_PUBLIC_*` - All public environment variables
- `API_KEY` - Server-side API key

**Deployment Flow:**
1. Push code to `develop` or `main` branch
2. GitHub Actions builds Docker image with all secrets
3. Image pushed to private registry
4. Kubernetes deployment automatically updated (develop) or webhook triggered (main)
5. Telegram notification sent with status

#### Vercel Deployment (Alternative)

- Configured for Vercel deployment with `vercel.json` and `.vercelignore`
- Manual deployment script available at `./deploy.sh`
- Automatic deployment via Vercel Dashboard when connected to Git repository

#### Docker Deployment (VPS/Self-hosted - Manual)

The project includes Docker configuration for deployment to VPS or self-hosted environments.

**Prerequisites:**
- Docker and Docker Compose installed on your server
- Node.js >=18.0.0 and npm >=9.0.0 required

**Configuration:**

1. Copy `.env.production.example` to `.env.production`:
   ```bash
   cp .env.production.example .env.production
   ```

2. Edit `.env.production` with your production values:
   ```bash
   NEXT_PUBLIC_SITE_URL=https://your-domain.com
   NEXT_PUBLIC_SITE_NAME=infatium
   NEXT_PUBLIC_ENABLE_ANALYTICS=false
   ```

**Build and Deploy:**

```bash
# Build the Docker image
docker-compose build

# Start the container in detached mode
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the container
docker-compose down

# Restart the container
docker-compose restart
```

**Updating the Application:**

```bash
# Pull latest code
git pull origin main

# Rebuild and restart
docker-compose up -d --build

# Remove old unused images
docker image prune -f
```

**Docker Architecture:**
- **Multi-stage build** - Optimized for minimal image size (~150MB)
- **Standalone output** - Next.js standalone mode for production
- **Non-root user** - Security best practice with dedicated nodejs user
- **Health checks** - Automatic container health monitoring
- **Auto-restart** - Container restarts unless explicitly stopped
- **Log rotation** - JSON logs with 10MB max size, 3 file retention

**Ports:**
- Container exposes port 3000
- Mapped to host port 3000 (configurable in docker-compose.yml)

**Resource Limits:**
- Default: No limits (uses available resources)
- Optional limits can be uncommented in docker-compose.yml (1 CPU, 1GB RAM)

**Nginx Reverse Proxy (Recommended):**
For production, use nginx as reverse proxy with SSL:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## Notes for Development

- The site is in Russian (locale: ru_RU)
- SEO metadata is configured in `layout.tsx` with OpenGraph and Twitter cards
- All sections use Framer Motion for animations - maintain consistent animation patterns
- When adding new sections, import them in `page.tsx` in the desired order
- When adding new UI components, follow the CVA pattern from existing components
- TypeScript strict mode is enabled - ensure all types are properly defined
- **Brand name "infatium" is always lowercase** - never capitalize, even at the beginning of sentences
