export function JsonLd() {
  const organizationSchema = {
    "@context": "https://schema.org",
    "@type": "Organization",
    "name": "infatium",
    "url": "https://infatium.ru",
    "logo": "https://infatium.ru/icon.png",
    "description": "Персональная лента новостей — читай осознанно",
    "foundingDate": "2024",
    "sameAs": [
      "https://t.me/infatium"
    ],
    "contactPoint": {
      "@type": "ContactPoint",
      "contactType": "customer support",
      "availableLanguage": ["Russian", "English"]
    }
  }

  const websiteSchema = {
    "@context": "https://schema.org",
    "@type": "WebSite",
    "name": "infatium",
    "url": "https://infatium.ru",
    "description": "Одно приложение вместо десяти источников. Персональная лента без шума и бесконечного скроллинга.",
    "inLanguage": "ru-RU",
    "publisher": {
      "@type": "Organization",
      "name": "infatium"
    }
  }

  const softwareSchema = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "infatium",
    "applicationCategory": "UtilitiesApplication",
    "operatingSystem": ["iOS", "Android"],
    "description": "Персональная лента новостей без шума и рекламы. Все ваши источники в одном месте — Telegram, RSS, сайты. Читайте только то, что действительно важно.",
    "offers": {
      "@type": "Offer",
      "price": "0",
      "priceCurrency": "RUB"
    },
    "aggregateRating": {
      "@type": "AggregateRating",
      "ratingValue": "4.8",
      "ratingCount": "1000"
    }
  }

  const faqSchema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": [
      {
        "@type": "Question",
        "name": "Как это работает?",
        "acceptedAnswer": {
          "@type": "Answer",
          "text": "Вы выбираете источники информации — Telegram-каналы, новостные сайты, RSS-ленты. Указываете свои интересы и предпочтения. Приложение анализирует контент, фильтрует шум и формирует персональную ленту только с тем, что действительно важно для вас."
        }
      },
      {
        "@type": "Question",
        "name": "Какие источники поддерживаются?",
        "acceptedAnswer": {
          "@type": "Answer",
          "text": "Telegram-каналы, RSS-ленты, новостные сайты. Мы постоянно добавляем новые источники. Если вам нужен конкретный источник — напишите нам, и мы добавим его в приоритетном порядке."
        }
      },
      {
        "@type": "Question",
        "name": "Это бесплатно?",
        "acceptedAnswer": {
          "@type": "Answer",
          "text": "Есть бесплатный тариф с базовыми возможностями. Для полного доступа ко всем функциям — подписка от 299₽/мес. Первые 7 дней Pro-версии бесплатно."
        }
      },
      {
        "@type": "Question",
        "name": "Как насчёт приватности?",
        "acceptedAnswer": {
          "@type": "Answer",
          "text": "Мы не продаём ваши данные и не показываем рекламу. Ваши предпочтения используются только для персонализации ленты. Вы можете удалить все данные в любой момент."
        }
      },
      {
        "@type": "Question",
        "name": "Как начать пользоваться?",
        "acceptedAnswer": {
          "@type": "Answer",
          "text": "Скачайте приложение, выберите интересующие темы и добавьте источники. Персональная лента сформируется автоматически. Чем больше вы взаимодействуете с контентом, тем точнее становятся рекомендации."
        }
      }
    ]
  }

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(organizationSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(websiteSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }}
      />
    </>
  )
}
