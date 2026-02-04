import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Пользовательское соглашение | infatium',
  description: 'Пользовательское соглашение сервиса infatium. Условия использования, права и обязанности пользователей.',
  openGraph: {
    title: 'Пользовательское соглашение | infatium',
    description: 'Пользовательское соглашение сервиса infatium',
    locale: 'ru_RU',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Пользовательское соглашение | infatium',
    description: 'Пользовательское соглашение сервиса infatium',
  },
}

export default function TermsPage() {
  return (
    <main className="min-h-screen bg-black text-white">
      {/* Header spacer */}
      <div className="h-16 sm:h-20" />

      {/* Content */}
      <article className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16 lg:py-24">
        {/* Header */}
        <header className="mb-12 sm:mb-16">
          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold mb-6 bg-gradient-to-b from-white to-white/60 bg-clip-text text-transparent">
            Пользовательское соглашение
          </h1>
          <div className="inline-block px-4 py-2 rounded-full bg-white/5 border border-white/10 text-sm text-white/60">
            Дата последнего обновления: 2 ноября 2025
          </div>
        </header>

        {/* Content sections */}
        <div className="space-y-8">
          {/* Section 1 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              1. Принятие условий
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Настоящее Пользовательское соглашение (далее — «Соглашение») регулирует использование сервиса infatium (далее — «Сервис») и устанавливает права и обязанности между вами (пользователем) и администрацией Сервиса.
              </p>
              <p>
                Начиная использовать Сервис, вы подтверждаете, что прочитали, поняли и согласны соблюдать условия настоящего Соглашения.
              </p>
              <p>
                Если вы не согласны с какими-либо положениями данного Соглашения, пожалуйста, немедленно прекратите использование Сервиса.
              </p>
            </div>
          </section>

          {/* Section 2 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              2. Описание сервиса
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                infatium — это AI-powered сервис для агрегирования и персонализации новостного контента.
              </p>
              <p>Сервис предоставляет следующие функции:</p>
              <ul className="space-y-2 pl-6 mt-4">
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Персонализированная новостная лента на основе ваших интересов и предпочтений
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Интеграция с внешними источниками новостей (Telegram, RSS и др.)
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Интеллектуальный поиск и фильтрация новостей с использованием AI-алгоритмов
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Возможность сохранения и организации контента
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Взаимодействие через чат-интерфейс для более удобного управления
                </li>
              </ul>
              <p className="mt-4 text-white/60 italic">
                Функциональность Сервиса может изменяться и дополняться без предварительного уведомления.
              </p>
            </div>
          </section>

          {/* Section 3 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              3. Регистрация и аккаунт
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Для использования Сервиса вам необходимо пройти регистрацию, предоставив адрес электронной почты и другую требуемую информацию.
              </p>

              <div className="mt-4">
                <h3 className="text-lg font-semibold text-white/90 mb-3">
                  3.1. Вы обязуетесь:
                </h3>
                <ul className="space-y-2 pl-6">
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Предоставлять достоверную, актуальную и полную информацию при регистрации
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Поддерживать актуальность своих регистрационных данных
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Сохранять конфиденциальность своего пароля и не передавать доступ к аккаунту третьим лицам
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Немедленно уведомить нас о любом несанкционированном использовании вашего аккаунта
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Нести ответственность за все действия, совершенные через ваш аккаунт
                  </li>
                </ul>
              </div>

              <div className="mt-6">
                <h3 className="text-lg font-semibold text-white/90 mb-3">
                  3.2. Мы оставляем за собой право:
                </h3>
                <ul className="space-y-2 pl-6">
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Отказать в регистрации без объяснения причин
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Приостановить или удалить ваш аккаунт при нарушении условий Соглашения
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Запросить дополнительную верификацию личности при необходимости
                  </li>
                </ul>
              </div>

              <p className="mt-4">
                Минимальный возраст для использования Сервиса — 16 лет.
              </p>
            </div>
          </section>

          {/* Section 4 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              4. Права и обязанности пользователей
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <div>
                <h3 className="text-lg font-semibold text-white/90 mb-3">
                  4.1. Вы имеете право:
                </h3>
                <ul className="space-y-2 pl-6">
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Использовать все доступные функции Сервиса в соответствии с настоящим Соглашением
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Получать техническую поддержку по вопросам использования Сервиса
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    В любое время удалить свой аккаунт
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Экспортировать свои данные из Сервиса
                  </li>
                </ul>
              </div>

              <div className="mt-6">
                <h3 className="text-lg font-semibold text-white/90 mb-3">
                  4.2. Вы обязуетесь НЕ:
                </h3>
                <ul className="space-y-2 pl-6">
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Использовать Сервис для незаконных целей или нарушения прав третьих лиц
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Пытаться получить несанкционированный доступ к системам или данным Сервиса
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Осуществлять автоматизированный сбор данных (парсинг, скрейпинг) без письменного разрешения
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Загружать вредоносное ПО, вирусы или любой код, наносящий вред Сервису
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Создавать множественные аккаунты для обхода ограничений или злоупотребления функциями
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Использовать Сервис для рассылки спама или нежелательного контента
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Нарушать интеллектуальные права Сервиса или третьих лиц
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Проводить действия, которые могут перегрузить или нарушить работу инфраструктуры Сервиса
                  </li>
                </ul>
              </div>
            </div>
          </section>

          {/* Section 5 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              5. Интеллектуальная собственность
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Все права на Сервис, включая его дизайн, логотипы, графику, код, алгоритмы AI и другие элементы, принадлежат администрации infatium и защищены законодательством об интеллектуальной собственности.
              </p>
              <p>
                Вы получаете ограниченную, неэксклюзивную, непередаваемую лицензию на использование Сервиса в личных некоммерческих целях в соответствии с настоящим Соглашением.
              </p>
              <p>
                Контент, создаваемый вами в Сервисе (сохраненные новости, заметки, настройки), остается вашей интеллектуальной собственностью. Однако, используя Сервис, вы предоставляете нам неэксклюзивную лицензию на использование этого контента для обеспечения работы и улучшения Сервиса.
              </p>
              <p>
                Новостной контент, агрегируемый Сервисом из внешних источников, является собственностью соответствующих правообладателей. Мы не несем ответственности за авторские права на контент, полученный из внешних источников.
              </p>
            </div>
          </section>

          {/* Section 6 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              6. Ограничения использования
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Мы можем устанавливать лимиты на использование Сервиса, включая, но не ограничиваясь:
              </p>
              <ul className="space-y-2 pl-6 mt-4">
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Количество запросов к AI-алгоритмам в единицу времени
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Объем хранимых данных
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Частоту обновления новостных лент
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Количество подключаемых внешних источников
                </li>
              </ul>
              <p className="mt-4">
                Эти ограничения могут изменяться в зависимости от тарифного плана и технических возможностей Сервиса.
              </p>
            </div>
          </section>

          {/* Section 7 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              7. Отказ от гарантий
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                <strong className="text-white/90">Сервис предоставляется «как есть» и «как доступно»</strong> без каких-либо гарантий, явных или подразумеваемых.
              </p>
              <p>Мы не гарантируем:</p>
              <ul className="space-y-2 pl-6 mt-4">
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Бесперебойную или безошибочную работу Сервиса
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Точность, полноту или актуальность предоставляемого контента
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Соответствие Сервиса вашим специфическим требованиям
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Отсутствие вирусов или других вредоносных компонентов
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Сохранность данных при технических сбоях
                </li>
              </ul>
              <p className="mt-4 text-white/60 italic">
                AI-алгоритмы могут совершать ошибки в анализе и персонализации контента. Мы постоянно работаем над улучшением их точности, но не можем гарантировать идеальный результат.
              </p>
            </div>
          </section>

          {/* Section 8 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              8. Ограничение ответственности
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                В максимальной степени, разрешенной применимым законодательством, мы не несем ответственности за:
              </p>
              <ul className="space-y-3 pl-6 mt-4">
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Любые прямые, косвенные, случайные, специальные или штрафные убытки, возникшие в результате использования или невозможности использования Сервиса
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Потерю данных, прибыли, репутации или другие нематериальные потери
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Действия третьих лиц, включая источники новостного контента
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Несанкционированный доступ к вашим данным или их изменение
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Временную недоступность Сервиса из-за технических работ или сбоев
                </li>
              </ul>
              <p className="mt-4">
                Наша совокупная ответственность перед вами по любым претензиям, связанным с Сервисом, не может превышать сумму, уплаченную вами за использование Сервиса за последние 12 месяцев (или 100 рублей, если Сервис предоставлялся бесплатно).
              </p>
            </div>
          </section>

          {/* Section 9 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              9. Приостановка и прекращение доступа
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Мы оставляем за собой право в любое время приостановить или прекратить ваш доступ к Сервису без предварительного уведомления в следующих случаях:
              </p>
              <ul className="space-y-2 pl-6 mt-4">
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Нарушение условий настоящего Соглашения
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Подозрение в мошеннической или незаконной деятельности
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  По требованию правоохранительных органов или суда
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Длительное неиспользование аккаунта (более 12 месяцев)
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Прекращение работы Сервиса по любым причинам
                </li>
              </ul>
              <p className="mt-4">
                Вы можете в любое время прекратить использование Сервиса и удалить свой аккаунт через настройки профиля или обратившись в службу поддержки.
              </p>
            </div>
          </section>

          {/* Section 10 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              10. Изменение условий
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Мы оставляем за собой право изменять настоящее Соглашение в любое время. Все изменения вступают в силу с момента их публикации на данной странице.
              </p>
              <p>
                Существенные изменения будут дополнительно доведены до вашего сведения через Сервис или по электронной почте.
              </p>
              <p>
                Продолжение использования Сервиса после внесения изменений означает ваше согласие с новыми условиями. Если вы не согласны с изменениями, вам следует прекратить использование Сервиса.
              </p>
              <p className="mt-4 text-white/60 italic">
                Дата последнего обновления указана в начале документа.
              </p>
            </div>
          </section>

          {/* Section 11 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              11. Применимое право и разрешение споров
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Настоящее Соглашение регулируется и толкуется в соответствии с законодательством Российской Федерации.
              </p>
              <p>
                Все споры, возникающие из настоящего Соглашения или в связи с ним, подлежат разрешению путем переговоров. В случае невозможности достижения соглашения споры подлежат рассмотрению в судебном порядке по месту нахождения администрации Сервиса.
              </p>
            </div>
          </section>

          {/* Section 12 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              12. Прочие условия
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Если какое-либо положение настоящего Соглашения будет признано недействительным или не имеющим юридической силы, это не влияет на действительность остальных положений.
              </p>
              <p>
                Непринятие нами мер в ответ на нарушение вами условий Соглашения не означает отказа от наших прав требовать соблюдения этих условий в дальнейшем.
              </p>
              <p>
                Настоящее Соглашение представляет собой полное соглашение между вами и администрацией Сервиса относительно использования Сервиса.
              </p>
            </div>
          </section>

          {/* Section 13 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              13. Контактная информация
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Если у вас есть вопросы или комментарии относительно настоящего Соглашения, пожалуйста, свяжитесь с нами:
              </p>
              <div className="mt-4 p-4 bg-white/[0.03] rounded-xl border border-white/10">
                <p className="text-white/90">
                  Email:{' '}
                  <a href="mailto:contact@nirssyan.ru" className="text-blue-400 hover:text-blue-300 underline transition-colors">
                    contact@nirssyan.ru
                  </a>
                </p>
              </div>
              <p className="mt-6">
                Также ознакомьтесь с нашей{' '}
                <a href="/privacy" className="text-blue-400 hover:text-blue-300 underline transition-colors">
                  Политикой конфиденциальности
                </a>
              </p>
            </div>
          </section>
        </div>

        {/* Footer */}
        <footer className="mt-16 pt-8 border-t border-white/10 text-center text-white/40 text-sm">
          <p>© 2026 infatium. Все права защищены.</p>
        </footer>
      </article>
    </main>
  )
}
