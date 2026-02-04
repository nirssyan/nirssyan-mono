'use client'

import { motion } from 'framer-motion'
import { Send, Mail } from 'lucide-react'
import Image from 'next/image'
import { useMatomo } from '@/hooks/use-matomo'
import { useLanguage } from '@/lib/language-context'

const socialLinks = [
  { name: 'Telegram', icon: Send, href: 'https://t.me/infatiumbot?start=from:landing' },
  { name: 'Email', icon: Mail, href: 'mailto:contact@nirssyan.ru' }
]

export function Footer() {
  const { t } = useLanguage()
  const { trackExternalLink } = useMatomo()

  return (
    <footer className="bg-black border-t border-white/5">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
          className="py-6 sm:py-8"
        >
          <div className="flex flex-col md:flex-row items-center justify-between gap-6">
            {/* Left: Logo + Tagline */}
            <div className="flex items-center gap-3">
              <Image
                src="/jellyfish.png"
                alt="infatium"
                width={32}
                height={32}
                className="rounded-lg"
              />
              <div>
                <span className="text-lg font-bold text-white">infatium</span>
                <p className="text-xs text-white/40">{t.footer.tagline}</p>
              </div>
            </div>

            {/* Center: Social Links */}
            <div className="flex items-center gap-3">
              {socialLinks.map((social) => (
                <motion.a
                  key={social.name}
                  href={social.href}
                  target={social.name === 'Email' ? '_self' : '_blank'}
                  rel="noopener noreferrer"
                  onClick={() => {
                    trackExternalLink({
                      link_text: social.name,
                      destination: social.href,
                      section: 'footer',
                    })
                  }}
                  whileHover={{ y: -2 }}
                  whileTap={{ scale: 0.95 }}
                  className="p-2.5 bg-white/5 rounded-xl hover:bg-white/10 border border-white/5 hover:border-white/10 transition-all duration-200"
                  aria-label={social.name}
                >
                  <social.icon className="w-4 h-4 text-white/50 hover:text-white transition-colors" />
                </motion.a>
              ))}
            </div>

            {/* Right: Copyright */}
            <p className="text-xs text-white/30">
              © 2026 infatium
            </p>
          </div>
        </motion.div>
      </div>
    </footer>
  )
}
