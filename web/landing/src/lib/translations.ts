export type Language = 'ru' | 'en'

export const translations = {
  ru: {
    // Header
    header: {
      howItWorks: 'Как это работает',
      marketplace: 'Маркетплейс',
      tryIt: 'Попробовать',
    },

    // Hero
    hero: {
      tagline: 'Твоё время. Твоя лента. Твои правила.',
      iDecide: 'Я сам решаю,',
      cta: 'Попробовать',
      phrases: [
        'что читать',
        'что важно',
        'что в моей ленте',
        'когда хватит',
        'сколько скроллить',
        'на что тратить время',
        'когда остановиться',
        'что стоит моего внимания',
        'чем кормить свой мозг',
        'что меня формирует',
      ],
    },

    // Problems section
    problems: {
      badge: 'Информационная перегрузка — проблема эпохи',
      title: 'Проблема',
      subtitle: 'Контент перестал быть ресурсом — он стал шумом. ',
      subtitle2: 'Люди теряют контроль над своим вниманием и временем',
      insightParts: [
        { text: 'Важно ', bold: false },
        { text: 'самому выбирать источники информации', bold: true },
        { text: ', чтобы не зависеть от ', bold: false },
        { text: 'алгоритмов', bold: true },
        { text: ', которые решают за тебя, что важно — иначе ты потребляешь ', bold: false },
        { text: 'тот же контент', bold: true },
        { text: ', те же мемы, те же новости, ', bold: false },
        { text: 'что и все остальные', bold: true },
      ],
      insight: 'Важно самому выбирать источники информации, чтобы не зависеть от алгоритмов, которые решают за тебя, что важно — иначе ты потребляешь тот же контент, те же мемы, те же новости, что и все остальные',
      insightAuthor: '— Павел Дуров, интервью Lex Fridman (12:47)',
      insightHighlight: '',
      stats: [
        {
          value: '76%',
          label: 'устали от информационного потока',
          source: 'Реальное время, 2024',
        },
        {
          value: '40.8%',
          label: 'практикуют цифровой детокс',
          source: 'НИУ ВШЭ, 2024',
        },
        {
          value: '11-15',
          label: 'источников информации проверяет человек ежедневно',
          source: 'Исследование infatium',
        },
      ],
      items: [
        {
          title: 'Фрагментация источников',
          description: 'Telegram, новости, Twitter, RSS, подкасты — информация разбросана по 10+ приложениям',
          problem: 'Постоянное переключение между приложениями отнимает время и внимание',
          solution: 'Telegram + RSS + новости в одном месте с единым интерфейсом',
        },
        {
          title: 'Алгоритмы решают за вас',
          description: 'Ленты формируются для engagement, а не для вашей пользы',
          problem: 'Clickbait и сенсации вместо глубокого контента. Вы видите не то, что нужно',
          solution: 'Лента работает по вашим правилам, а не ради рекламодателей',
        },
        {
          title: 'Бесконечный скроллинг',
          description: '«Открыл на 5 минут — очнулся через час». Нет точки остановки',
          problem: 'Потеря времени, чувство вины, невозможно вспомнить полезное',
          solution: 'Конечные дайджесты и краткие сводки — вы контролируете время',
        },
        {
          title: 'Шум превышает сигнал',
          description: 'Реклама, репосты, дубли, хайп — слишком много контента, мало ценности',
          problem: 'Ценный контент теряется в потоке из 150-600 постов ежедневно',
          solution: 'Фильтрация оставляет только релевантное по вашим критериям',
        },
      ],
    },

    // How it works (AI Animation)
    howItWorks: {
      badge: 'Как это работает',
      title: 'Простой процесс',
      subtitle: '3 шага к персональной ленте',
      steps: [
        {
          label: 'Источники',
          title: 'Выбор источников',
          description: 'Выберите, откуда получать информацию',
        },
        {
          label: 'Настройки',
          title: 'Настройка параметров',
          description: 'Укажите, как фильтровать контент',
        },
        {
          label: 'Лента',
          title: 'Получение ленты',
          description: 'Персонализированный поток новостей',
        },
      ],
      sources: {
        telegram: { name: 'Telegram', description: 'Каналы' },
        rss: { name: 'Любой источник', description: 'Сайты, блоги, RSS' },
      },
      filters: [
        { id: 'no-ads', label: 'Убрать рекламу' },
        { id: 'no-duplicates', label: 'Удалить дубликаты' },
      ],
      topics: [
        { id: 'productivity', label: 'Продуктивность' },
        { id: 'crypto', label: 'Крипто' },
        { id: 'tech', label: 'Технологии' },
        { id: 'startups', label: 'Стартапы' },
        { id: 'science', label: 'Наука' },
      ],
      feedItems: [
        { title: 'OpenAI представила GPT-5', source: 'Веб' },
        { title: 'Apple разрабатывает собственный ИИ-чип', source: 'Веб' },
        { title: 'Новый фреймворк для машинного обучения', source: 'Веб' },
      ],
      demo: {
        sourceSelection: 'Выбор источников',
        of: 'из',
        disabled: 'Выключено',
        settingsTitle: 'Настройки ленты',
        willBeFiltered: 'Будет отфильтровано',
        contentFilters: 'Фильтры контента',
        topics: 'Темы',
        customPrompt: 'Свой запрос',
        customPromptPlaceholder: 'Например: показывай только позитивные новости про технологии, игнорируй политику...',
        customPromptHint: 'Опишите своими словами, какой контент вы хотите видеть',
        yourFeed: 'Ваша лента',
        posts: 'постов',
        noPostsTitle: 'Нет постов, соответствующих фильтрам',
        noPostsHint: 'Попробуйте выбрать другие источники или темы',
        allNewsVerified: 'Все новости проверены и актуализированы за последние 24 часа',
        ad: 'Реклама',
        duplicate: 'Дубликат',
        spam: 'Спам',
        briefTab: 'Кратко',
        fullTab: 'Полный',
      },
    },

    // Marketplace
    marketplace: {
      badge: 'Подборки лент',
      title: 'Маркетплейс готовых лент',
      subtitle:
        'Выбирайте тематические ленты, комбинируйте DIGEST и SINGLE_POST и открывайте их в приложении infatium.',
      searchPlaceholder: 'Поиск по названию, описанию или тегам',
      allTypes: 'Все типы',
      allTags: 'Все теги',
      singlePost: 'SINGLE_POST',
      digest: 'DIGEST',
      openApp: 'Открыть приложение',
      noDescription: 'Описание скоро появится',
      resultsLabel: 'лент в каталоге',
      clearFilters: 'Сбросить фильтры',
      emptyTitle: 'По вашему запросу ничего не найдено',
      emptyHint: 'Попробуйте изменить фильтры или поисковый запрос.',
      errorTitle: 'Каталог временно недоступен',
      errorHint: 'Не удалось загрузить ленты. Обновите страницу и попробуйте снова.',
      retry: 'Обновить',
      desktopDownload: 'Скачайте infatium',
      partialDataWarning: 'Показаны последние доступные данные.',
    },

    // About
    about: {
      comparison: {
        title: 'Экранное время',
        subtitle: 'Потрать его с пользой',
        before: 'Сейчас',
        after: 'С infatium',
      },
      platforms: 'Платформы',
      platformItems: [
        { name: 'iOS', description: 'Нативное приложение для iPhone и iPad', status: 'App Store' },
        { name: 'Android', description: 'Нативное приложение для Android устройств', status: 'RuStore' },
      ],
    },

    // FAQ
    faq: {
      title: 'Частые вопросы',
      subtitle: 'Всё, что нужно знать о infatium',
      howItWorks: {
        question: 'Как это работает?',
        answer: 'Вы выбираете источники информации — Telegram-каналы, новостные сайты, RSS-ленты. Указываете свои интересы и предпочтения. Приложение анализирует контент, фильтрует шум и формирует персональную ленту только с тем, что действительно важно для вас.',
      },
      whatSources: {
        question: 'Какие источники поддерживаются?',
        answer: 'Telegram-каналы, RSS-ленты, новостные сайты. Мы постоянно добавляем новые источники. Если вам нужен конкретный источник — напишите нам, и мы добавим его в приоритетном порядке.',
      },
      isItFree: {
        question: 'Это бесплатно?',
        answer: 'Сейчас весь функционал infatium полностью бесплатен. В будущем появятся платные тарифы с расширенными возможностями — больше лент, источников и фильтров. Базовый функционал останется бесплатным.',
      },
      noAds: {
        question: 'А как насчёт рекламы?',
        answer: 'infatium принципиально не показывает рекламу — это фундамент нашей философии. Ваша лента существует только для вас, а не для рекламодателей. Мы зарабатываем на подписках, а не на вашем внимании.',
      },
      privacy: {
        question: 'Как насчёт приватности?',
        answer: 'Мы не продаём ваши данные. Ваши предпочтения используются только для персонализации ленты. Вы можете удалить все данные в любой момент.',
      },
      howToStart: {
        question: 'Как начать пользоваться?',
        answer: 'Скачайте приложение, выберите интересующие темы и добавьте источники. Персональная лента сформируется автоматически. Чем больше вы взаимодействуете с контентом, тем точнее становятся рекомендации.',
      },
      webAndTelegram: {
        question: 'Будет ли веб-версия или Telegram Mini App?',
        answer: 'Да, веб-версия и Telegram Mini App сейчас в разработке. Следите за обновлениями — мы сообщим, когда они станут доступны.',
      },
    },

    // Footer
    footer: {
      tagline: 'ты — что ты читаешь',
    },
  },

  en: {
    // Header
    header: {
      howItWorks: 'How it works',
      marketplace: 'Marketplace',
      tryIt: 'Try it',
    },

    // Hero
    hero: {
      tagline: 'Your time. Your feed. Your rules.',
      iDecide: 'I decide',
      cta: 'Try it',
      phrases: [
        'what to read',
        'what matters',
        'what\'s in my feed',
        'when enough is enough',
        'how much to scroll',
        'how to spend my time',
        'when to stop',
        'what deserves my attention',
        'what feeds my mind',
        'what shapes me',
      ],
    },

    // Problems section
    problems: {
      badge: 'Information overload — the problem of our era',
      title: 'Problems',
      subtitle: 'Content is no longer a resource — it\'s noise.',
      subtitle2: 'People are losing control of their attention and time',
      insightParts: [
        { text: 'It\'s crucial to ', bold: false },
        { text: 'curate your own information sources', bold: true },
        { text: ' so you\'re not left to the will of ', bold: false },
        { text: 'AI-based algorithmic feeds', bold: true },
        { text: ' telling you what\'s important — otherwise you end up consuming ', bold: false },
        { text: 'the same content', bold: true },
        { text: ', the same memes, the same news ', bold: false },
        { text: 'as everybody else', bold: true },
      ],
      insight: 'It\'s crucial to curate your own information sources so you\'re not left to the will of AI-based algorithmic feeds telling you what\'s important — otherwise you end up consuming the same content, the same memes, the same news as everybody else',
      insightAuthor: '— Pavel Durov, Lex Fridman Interview (12:47)',
      insightHighlight: '',
      stats: [
        {
          value: '76%',
          label: 'are tired of information overload',
          source: 'Realnoevremya, 2024',
        },
        {
          value: '40.8%',
          label: 'practice digital detox',
          source: 'HSE, 2024',
        },
        {
          value: '11-15',
          label: 'sources a person checks daily',
          source: 'infatium research',
        },
      ],
      items: [
        {
          title: 'Fragmented sources',
          description: 'Telegram, news, Twitter, RSS, podcasts — information scattered across 10+ apps',
          problem: 'Constant switching between apps takes time and attention',
          solution: 'Telegram + RSS + news in one place with a unified interface',
        },
        {
          title: 'Algorithms decide for you',
          description: 'Feeds are optimized for engagement, not for your benefit',
          problem: 'Clickbait and sensations instead of deep content. You see what they want',
          solution: 'Your feed works by your rules, not for advertisers',
        },
        {
          title: 'Endless scrolling',
          description: '"Opened for 5 minutes — woke up an hour later". No stopping point',
          problem: 'Wasted time, guilt, can\'t remember anything useful',
          solution: 'Finite digests and brief summaries — you control your time',
        },
        {
          title: 'Noise exceeds signal',
          description: 'Ads, reposts, duplicates, hype — too much content, little value',
          problem: 'Valuable content gets lost in a flow of 150-600 posts daily',
          solution: 'Filtering leaves only what\'s relevant by your criteria',
        },
      ],
    },

    // How it works (AI Animation)
    howItWorks: {
      badge: 'How it works',
      title: 'Simple process',
      subtitle: '3 steps to your personal feed',
      steps: [
        {
          label: 'Sources',
          title: 'Choose sources',
          description: 'Select where to get information from',
        },
        {
          label: 'Settings',
          title: 'Configure settings',
          description: 'Specify how to filter content',
        },
        {
          label: 'Feed',
          title: 'Get your feed',
          description: 'Personalized news stream',
        },
      ],
      sources: {
        telegram: { name: 'Telegram', description: 'Channels' },
        rss: { name: 'Any source', description: 'Websites, blogs, RSS' },
      },
      filters: [
        { id: 'no-ads', label: 'Remove ads' },
        { id: 'no-duplicates', label: 'Remove duplicates' },
      ],
      topics: [
        { id: 'productivity', label: 'Productivity' },
        { id: 'crypto', label: 'Crypto' },
        { id: 'tech', label: 'Tech' },
        { id: 'startups', label: 'Startups' },
        { id: 'science', label: 'Science' },
      ],
      feedItems: [
        { title: 'OpenAI introduces GPT-5', source: 'Web' },
        { title: 'Apple developing its own AI chip', source: 'Web' },
        { title: 'New machine learning framework released', source: 'Web' },
      ],
      demo: {
        sourceSelection: 'Source selection',
        of: 'of',
        disabled: 'Disabled',
        settingsTitle: 'Feed settings',
        willBeFiltered: 'Will be filtered',
        contentFilters: 'Content filters',
        topics: 'Topics',
        customPrompt: 'Custom prompt',
        customPromptPlaceholder: 'E.g.: show only positive tech news, ignore politics...',
        customPromptHint: 'Describe in your own words what content you want to see',
        yourFeed: 'Your feed',
        posts: 'posts',
        noPostsTitle: 'No posts matching your filters',
        noPostsHint: 'Try selecting different sources or topics',
        allNewsVerified: 'All news verified and updated within the last 24 hours',
        ad: 'Ad',
        duplicate: 'Duplicate',
        spam: 'Spam',
        briefTab: 'Brief',
        fullTab: 'Full',
      },
    },

    // Marketplace
    marketplace: {
      badge: 'Feed collections',
      title: 'Marketplace of ready-to-use feeds',
      subtitle:
        'Browse curated feeds, combine DIGEST and SINGLE_POST formats, and open them in the infatium app.',
      searchPlaceholder: 'Search by name, description, or tags',
      allTypes: 'All types',
      allTags: 'All tags',
      singlePost: 'SINGLE_POST',
      digest: 'DIGEST',
      openApp: 'Open app',
      noDescription: 'Description coming soon',
      resultsLabel: 'feeds in catalog',
      clearFilters: 'Reset filters',
      emptyTitle: 'Nothing found for your request',
      emptyHint: 'Try adjusting filters or your search query.',
      errorTitle: 'Catalog is temporarily unavailable',
      errorHint: 'We could not load feeds right now. Please refresh and try again.',
      retry: 'Refresh',
      desktopDownload: 'Download infatium',
      partialDataWarning: 'Showing the last available data snapshot.',
    },

    // About
    about: {
      comparison: {
        title: 'Screen Time',
        subtitle: 'Spend it wisely',
        before: 'Now',
        after: 'With infatium',
      },
      platforms: 'Platforms',
      platformItems: [
        { name: 'iOS', description: 'Native app for iPhone and iPad', status: 'App Store' },
        { name: 'Android', description: 'Native app for Android devices', status: 'RuStore' },
      ],
    },

    // FAQ
    faq: {
      title: 'FAQ',
      subtitle: 'Everything you need to know about infatium',
      howItWorks: {
        question: 'How does it work?',
        answer: 'You choose your information sources — Telegram channels, news sites, RSS feeds. Set your interests and preferences. The app analyzes content, filters noise, and creates a personalized feed with only what truly matters to you.',
      },
      whatSources: {
        question: 'What sources are supported?',
        answer: 'Telegram channels, RSS feeds, news sites. We constantly add new sources. If you need a specific source — contact us and we\'ll add it as a priority.',
      },
      isItFree: {
        question: 'Is it free?',
        answer: 'Right now all infatium features are completely free. In the future, paid plans with extended capabilities will be available — more feeds, sources, and filters. The core functionality will remain free.',
      },
      noAds: {
        question: 'What about ads?',
        answer: 'infatium fundamentally does not show ads — this is the foundation of our philosophy. Your feed exists only for you, not for advertisers. We earn through subscriptions, not your attention.',
      },
      privacy: {
        question: 'What about privacy?',
        answer: 'We don\'t sell your data. Your preferences are only used for feed personalization. You can delete all data at any time.',
      },
      howToStart: {
        question: 'How do I get started?',
        answer: 'Download the app, choose topics that interest you, and add sources. Your personalized feed will form automatically. The more you interact with content, the more accurate recommendations become.',
      },
      webAndTelegram: {
        question: 'Will there be a web version or Telegram Mini App?',
        answer: 'Yes, a web version and Telegram Mini App are currently in development. Stay tuned — we\'ll announce when they become available.',
      },
    },

    // Footer
    footer: {
      tagline: 'you are what you read',
    },
  },
} as const

type DeepWriteable<T> = { -readonly [P in keyof T]: DeepWriteable<T[P]> }

export type Translations = DeepWriteable<typeof translations.ru>
