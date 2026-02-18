import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Политика конфиденциальности | infatium',
  description: 'Политика конфиденциальности мобильного приложения Infatium. Узнайте, как мы собираем, используем и защищаем ваши персональные данные в соответствии с 152-ФЗ.',
  openGraph: {
    title: 'Политика конфиденциальности | infatium',
    description: 'Политика конфиденциальности мобильного приложения Infatium',
    locale: 'ru_RU',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Политика конфиденциальности | infatium',
    description: 'Политика конфиденциальности мобильного приложения Infatium',
  },
}

export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-black text-white">
      {/* Header spacer */}
      <div className="h-16 sm:h-20" />

      {/* Content */}
      <article className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16 lg:py-24">
        {/* Header */}
        <header className="mb-12 sm:mb-16">
          <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold mb-6 bg-gradient-to-b from-white to-white/60 bg-clip-text text-transparent">
            Политика конфиденциальности
          </h1>
          <div className="inline-block px-4 py-2 rounded-full bg-white/5 border border-white/10 text-sm text-white/60">
            Дата последнего обновления: 18 февраля 2026
          </div>
        </header>

        {/* Content sections */}
        <div className="space-y-8">
          {/* Section 1 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              1. Общие положения
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Настоящая Политика конфиденциальности (далее — «Политика») определяет порядок обработки и защиты персональных данных пользователей мобильного приложения Infatium (далее — «Приложение»).
              </p>
              <div className="mt-4 p-4 bg-white/[0.03] rounded-xl border border-white/10">
                <p className="text-white/90 font-medium mb-2">Оператор персональных данных:</p>
                <p>ФИО: Квартовкин Святослав Константинович</p>
                <p>
                  Email:{' '}
                  <a href="mailto:slava1kvartovkin@gmail.com" className="text-blue-400 hover:text-blue-300 underline transition-colors">
                    slava1kvartovkin@gmail.com
                  </a>
                </p>
              </div>
              <p>
                Политика разработана в соответствии с Федеральным законом от 27.07.2006 № 152-ФЗ «О персональных данных».
              </p>
              <p>
                Используя Приложение и предоставляя свои персональные данные, Пользователь выражает согласие с условиями настоящей Политики.
              </p>
            </div>
          </section>

          {/* Section 2 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              2. Какие данные мы собираем
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>Мы собираем следующие персональные данные:</p>

              <div className="overflow-x-auto mt-4">
                <table className="w-full text-left">
                  <thead>
                    <tr className="border-b border-white/10">
                      <th className="py-3 pr-4 text-white/90 font-semibold">Категория</th>
                      <th className="py-3 pr-4 text-white/90 font-semibold">Данные</th>
                      <th className="py-3 text-white/90 font-semibold">Обязательность</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr className="border-b border-white/5">
                      <td className="py-3 pr-4">Контактные данные</td>
                      <td className="py-3 pr-4">Адрес электронной почты (email)</td>
                      <td className="py-3 text-green-400">Обязательно</td>
                    </tr>
                    <tr className="border-b border-white/5">
                      <td className="py-3 pr-4">Идентификаторы</td>
                      <td className="py-3 pr-4">Telegram ID (числовой идентификатор)</td>
                      <td className="py-3 text-white/50">Опционально</td>
                    </tr>
                    <tr>
                      <td className="py-3 pr-4">Рекламные идентификаторы</td>
                      <td className="py-3 pr-4">IDFA (Identifier for Advertisers) на устройствах Apple</td>
                      <td className="py-3 text-white/50">С вашего согласия</td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <div className="mt-6">
                <h3 className="text-lg font-semibold text-white/90 mb-3">
                  Мы НЕ собираем:
                </h3>
                <ul className="space-y-2 pl-6">
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Данные о здоровье
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Биометрические данные
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Данные о расовой/национальной принадлежности
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Политические или религиозные взгляды
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Данные банковских карт
                  </li>
                </ul>
              </div>
            </div>
          </section>

          {/* Section 3 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              3. Цели обработки данных
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>Ваши персональные данные обрабатываются в следующих целях:</p>

              <div className="overflow-x-auto mt-4">
                <table className="w-full text-left">
                  <thead>
                    <tr className="border-b border-white/10">
                      <th className="py-3 pr-4 text-white/90 font-semibold">Цель</th>
                      <th className="py-3 text-white/90 font-semibold">Правовое основание</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr className="border-b border-white/5">
                      <td className="py-3 pr-4">Регистрация и идентификация в Приложении</td>
                      <td className="py-3">Согласие пользователя</td>
                    </tr>
                    <tr className="border-b border-white/5">
                      <td className="py-3 pr-4">Отправка уведомлений о работе сервиса</td>
                      <td className="py-3">Согласие пользователя</td>
                    </tr>
                    <tr className="border-b border-white/5">
                      <td className="py-3 pr-4">Восстановление доступа к аккаунту</td>
                      <td className="py-3">Исполнение договора</td>
                    </tr>
                    <tr className="border-b border-white/5">
                      <td className="py-3 pr-4">Интеграция с Telegram-ботом</td>
                      <td className="py-3">Согласие пользователя</td>
                    </tr>
                    <tr className="border-b border-white/5">
                      <td className="py-3 pr-4">Техническая поддержка пользователей</td>
                      <td className="py-3">Законный интерес оператора</td>
                    </tr>
                    <tr>
                      <td className="py-3 pr-4">Анализ эффективности рекламных кампаний (IDFA)</td>
                      <td className="py-3">Явное согласие пользователя (ATT)</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </section>

          {/* Section 4 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              4. Способы обработки данных
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>Обработка персональных данных осуществляется:</p>
              <ul className="space-y-2 pl-6 mt-4">
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Автоматизированным способом с использованием средств вычислительной техники
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  С соблюдением принципов конфиденциальности
                </li>
              </ul>
              <p className="mt-4">
                Действия с данными включают: сбор, запись, систематизацию, накопление, хранение, уточнение (обновление, изменение), извлечение, использование, блокирование, удаление, уничтожение.
              </p>
            </div>
          </section>

          {/* Section 5 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              5. Хранение данных
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                <strong className="text-white/90">Персональные данные хранятся на серверах, расположенных на территории Российской Федерации.</strong>
              </p>
              <div className="mt-4">
                <h3 className="text-lg font-semibold text-white/90 mb-3">
                  Сроки хранения:
                </h3>
                <ul className="space-y-3 pl-6">
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    <strong className="text-white/90">При активном аккаунте:</strong> до момента удаления аккаунта пользователем
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    <strong className="text-white/90">После удаления аккаунта:</strong> данные удаляются в течение 30 дней
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    <strong className="text-white/90">После отзыва согласия:</strong> данные удаляются в течение 30 дней
                  </li>
                </ul>
              </div>
            </div>
          </section>

          {/* Section 6 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              6. Передача данных третьим лицам
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                <strong className="text-white/90">Мы НЕ продаём и НЕ передаём ваши персональные данные третьим лицам в коммерческих целях.</strong>
              </p>
              <p>Данные могут быть переданы третьим лицам только в случаях:</p>
              <ul className="space-y-2 pl-6 mt-4">
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  По требованию законодательства РФ (запрос правоохранительных органов, суда)
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  Для защиты прав и законных интересов Оператора
                </li>
              </ul>
            </div>
          </section>

          {/* Section 7 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              7. Защита данных
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>Мы применяем следующие меры защиты:</p>
              <ul className="space-y-3 pl-6 mt-4">
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  <strong className="text-white/90">Шифрование данных</strong> при передаче (HTTPS/TLS)
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  <strong className="text-white/90">Ограничение доступа</strong> к персональным данным
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  <strong className="text-white/90">Хранение паролей</strong> в хешированном виде
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  <strong className="text-white/90">Регулярное резервное копирование</strong>
                </li>
              </ul>
            </div>
          </section>

          {/* Section 8 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              8. Права пользователя
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>Вы имеете право:</p>
              <ul className="space-y-3 pl-6 mt-4">
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  <strong className="text-white/90">Получить информацию</strong> об обработке ваших данных
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  <strong className="text-white/90">Запросить доступ</strong> к вашим персональным данным
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  <strong className="text-white/90">Потребовать исправления</strong> неточных данных
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  <strong className="text-white/90">Потребовать удаления</strong> ваших данных
                </li>
                <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                  <strong className="text-white/90">Отозвать согласие</strong> на обработку данных
                </li>
              </ul>
              <p className="mt-4">
                Для реализации своих прав направьте запрос на email:{' '}
                <a href="mailto:slava1kvartovkin@gmail.com" className="text-blue-400 hover:text-blue-300 underline transition-colors">
                  slava1kvartovkin@gmail.com
                </a>
              </p>
              <p>
                Срок ответа на запрос — до 30 дней.
              </p>
            </div>
          </section>

          {/* Section 9 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              9. Использование cookies
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                <strong className="text-white/90">Приложение НЕ использует файлы cookies.</strong>
              </p>
            </div>
          </section>

          {/* Section 10 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              10. Отслеживание и рекламные идентификаторы (App Tracking Transparency)
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                На устройствах Apple (iOS/iPadOS) Приложение может запрашивать доступ к рекламному идентификатору вашего устройства (IDFA) в соответствии с политикой Apple App Tracking Transparency (ATT).
              </p>
              <p>
                <strong className="text-white/90">При первом запуске Приложение отображает системный запрос на разрешение отслеживания.</strong> Вы можете разрешить или запретить доступ к IDFA.
              </p>
              <div className="mt-4">
                <h3 className="text-lg font-semibold text-white/90 mb-3">
                  Для чего используется IDFA:
                </h3>
                <ul className="space-y-2 pl-6">
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Измерение эффективности рекламных кампаний
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Анализ привлечения пользователей (атрибуция)
                  </li>
                </ul>
              </div>
              <div className="mt-4">
                <h3 className="text-lg font-semibold text-white/90 mb-3">
                  Ваш контроль:
                </h3>
                <ul className="space-y-2 pl-6">
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Вы можете отказать в доступе при появлении системного запроса
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Вы можете изменить решение в любой момент: <strong className="text-white/90">Настройки → Конфиденциальность и безопасность → Отслеживание</strong>
                  </li>
                  <li className="relative before:content-['•'] before:absolute before:-left-4 before:text-white/50">
                    Отказ от отслеживания не влияет на функциональность Приложения
                  </li>
                </ul>
              </div>
              <p className="mt-4">
                <strong className="text-white/90">Без вашего явного согласия мы не получаем доступ к IDFA и не отслеживаем вашу активность в других приложениях и на сайтах.</strong>
              </p>
            </div>
          </section>

          {/* Section 11 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              11. Изменения в Политике
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Оператор вправе вносить изменения в настоящую Политику.
              </p>
              <p>
                При внесении существенных изменений пользователи будут уведомлены через Приложение.
              </p>
              <p>
                Продолжение использования Приложения после изменения Политики означает согласие с новой редакцией.
              </p>
            </div>
          </section>

          {/* Section 12 */}
          <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8">
            <h2 className="text-2xl sm:text-3xl font-semibold mb-4 text-white">
              12. Контактная информация
            </h2>
            <div className="space-y-4 text-white/70 leading-relaxed">
              <p>
                Для вопросов, связанных с обработкой персональных данных:
              </p>
              <div className="mt-4 p-4 bg-white/[0.03] rounded-xl border border-white/10">
                <p className="text-white/90">
                  Email:{' '}
                  <a href="mailto:slava1kvartovkin@gmail.com" className="text-blue-400 hover:text-blue-300 underline transition-colors">
                    slava1kvartovkin@gmail.com
                  </a>
                </p>
                <p className="text-white/90 mt-2">
                  Оператор: Квартовкин Святослав Константинович
                </p>
              </div>
              <p className="mt-6">
                Также ознакомьтесь с{' '}
                <a href="/consent" className="text-blue-400 hover:text-blue-300 underline transition-colors">
                  Согласием на обработку персональных данных
                </a>
                {' '}и{' '}
                <a href="/terms" className="text-blue-400 hover:text-blue-300 underline transition-colors">
                  Пользовательским соглашением
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
