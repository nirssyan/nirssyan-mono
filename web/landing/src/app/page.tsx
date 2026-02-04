import { Hero } from '@/components/sections/hero'
import { Footer } from '@/components/sections/footer'
import dynamic from 'next/dynamic'
import { SectionSkeleton } from '@/components/ui/section-skeleton'

// Frame 2: High priority - SSR enabled, loads after Hero
const Features = dynamic(() => import('@/components/sections/features').then(mod => ({ default: mod.Features })), {
  ssr: true,
  loading: () => <SectionSkeleton />
})

// Frame 3: Deferred - loads as separate chunks
const About = dynamic(() => import('@/components/sections/about').then(mod => ({ default: mod.About })), {
  loading: () => <SectionSkeleton />
})

const FAQ = dynamic(() => import('@/components/sections/faq').then(mod => ({ default: mod.FAQ })), {
  loading: () => <SectionSkeleton />
})

export default function Home() {
  return (
    <main>
      <Hero />
      <Features />
      <About />
      <FAQ />
      <Footer />
    </main>
  )
}
