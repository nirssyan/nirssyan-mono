import { Metadata } from "next";

export const metadata: Metadata = {
  title: "Согласие на обработку персональных данных | Infatium",
  description:
    "Согласие на обработку персональных данных пользователей приложения Infatium в соответствии с 152-ФЗ",
};

export default function ConsentPage() {
  return (
    <article className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12 sm:py-16 lg:py-24">
      {/* Header */}
      <header className="text-center mb-12 sm:mb-16">
        <div className="inline-block px-4 py-2 rounded-full bg-white/5 border border-white/10 text-sm text-white/60 mb-6">
          Редакция от 3 января 2026 г.
        </div>
        <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold mb-6 bg-gradient-to-b from-white to-white/60 bg-clip-text text-transparent leading-tight">
          Согласие на обработку персональных данных
        </h1>
        <p className="text-lg text-white/60">мобильного приложения Infatium</p>
      </header>

      {/* Introduction */}
      <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8 mb-6">
        <p className="text-white/70 leading-relaxed">
          Я, субъект персональных данных (далее — Пользователь), действуя
          свободно, своей волей и в своём интересе, даю согласие{" "}
          <strong className="text-white">
            Квартовкину Святославу Константиновичу
          </strong>{" "}
          (далее — Оператор) на обработку моих персональных данных на следующих
          условиях:
        </p>
      </section>

      {/* Section 1 */}
      <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8 mb-6">
        <h2 className="text-xl sm:text-2xl font-semibold mb-4 text-white">
          1. Оператор персональных данных
        </h2>
        <div className="space-y-3 text-white/70">
          <p>
            <strong className="text-white/90">ФИО:</strong> Квартовкин Святослав
            Константинович
          </p>
          <p>
            <strong className="text-white/90">Email:</strong>{" "}
            <a
              href="mailto:slava1kvartovkin@gmail.com"
              className="text-blue-400 hover:text-blue-300 transition-colors"
            >
              slava1kvartovkin@gmail.com
            </a>
          </p>
        </div>
      </section>

      {/* Section 2 */}
      <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8 mb-6">
        <h2 className="text-xl sm:text-2xl font-semibold mb-4 text-white">
          2. Перечень персональных данных
        </h2>
        <p className="text-white/70 mb-4">
          Настоящее согласие распространяется на обработку следующих данных:
        </p>
        <ul className="space-y-2 text-white/70 ml-4">
          <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
            Адрес электронной почты (email)
          </li>
          <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
            Telegram ID (числовой идентификатор пользователя Telegram)
          </li>
        </ul>
      </section>

      {/* Section 3 */}
      <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8 mb-6">
        <h2 className="text-xl sm:text-2xl font-semibold mb-4 text-white">
          3. Цели обработки
        </h2>
        <p className="text-white/70 mb-4">
          Персональные данные обрабатываются в целях:
        </p>
        <ul className="space-y-2 text-white/70 ml-4">
          <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
            Регистрации и идентификации Пользователя в мобильном приложении
            Infatium
          </li>
          <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
            Отправки уведомлений о работе сервиса
          </li>
          <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
            Восстановления доступа к аккаунту
          </li>
          <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
            Интеграции с Telegram-ботом для доставки контента
          </li>
          <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
            Технической поддержки Пользователя
          </li>
        </ul>
      </section>

      {/* Section 4 */}
      <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8 mb-6">
        <h2 className="text-xl sm:text-2xl font-semibold mb-4 text-white">
          4. Действия с персональными данными
        </h2>
        <p className="text-white/70 leading-relaxed">
          Оператору разрешается осуществлять следующие действия: сбор, запись,
          систематизацию, накопление, хранение, уточнение (обновление,
          изменение), извлечение, использование, блокирование, удаление,
          уничтожение персональных данных.
        </p>
      </section>

      {/* Section 5 */}
      <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8 mb-6">
        <h2 className="text-xl sm:text-2xl font-semibold mb-4 text-white">
          5. Способы обработки
        </h2>
        <p className="text-white/70 leading-relaxed">
          Обработка осуществляется автоматизированным способом с использованием
          средств вычислительной техники.
        </p>
      </section>

      {/* Section 6 */}
      <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8 mb-6">
        <h2 className="text-xl sm:text-2xl font-semibold mb-4 text-white">
          6. Срок действия согласия
        </h2>
        <p className="text-white/70 mb-4">Настоящее согласие действует:</p>
        <ul className="space-y-2 text-white/70 ml-4">
          <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
            До момента его отзыва Пользователем, или
          </li>
          <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
            До момента удаления аккаунта Пользователем, или
          </li>
          <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
            До достижения целей обработки
          </li>
        </ul>
      </section>

      {/* Section 7 */}
      <section className="bg-white/[0.02] backdrop-blur-sm border border-white/5 rounded-2xl p-6 sm:p-8 mb-6">
        <h2 className="text-xl sm:text-2xl font-semibold mb-4 text-white">
          7. Порядок отзыва согласия
        </h2>
        <div className="space-y-4 text-white/70 leading-relaxed">
          <p>
            <strong className="text-white/90">7.1.</strong> Пользователь вправе
            отозвать настоящее согласие в любое время одним из способов:
          </p>
          <ul className="space-y-2 ml-4">
            <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
              Направить запрос на email:{" "}
              <a
                href="mailto:slava1kvartovkin@gmail.com"
                className="text-blue-400 hover:text-blue-300 transition-colors"
              >
                slava1kvartovkin@gmail.com
              </a>
            </li>
            <li className="relative pl-4 before:content-['•'] before:absolute before:left-0 before:text-white/50">
              Удалить аккаунт через настройки Приложения
            </li>
          </ul>
          <p>
            <strong className="text-white/90">7.2.</strong> При отзыве согласия
            Оператор прекращает обработку персональных данных и удаляет их в
            течение 30 (тридцати) дней.
          </p>
          <p>
            <strong className="text-white/90">7.3.</strong> Отзыв согласия не
            влияет на законность обработки, осуществлявшейся до момента отзыва.
          </p>
        </div>
      </section>

      {/* Confirmation Block */}
      <section className="bg-gradient-to-r from-blue-500/10 to-purple-500/10 backdrop-blur-sm border border-white/10 rounded-2xl p-6 sm:p-8 mb-6">
        <h2 className="text-xl sm:text-2xl font-semibold mb-4 text-white">
          Подтверждение согласия
        </h2>
        <p className="text-white/70 mb-4">
          Принимая настоящее согласие (отмечая соответствующий чекбокс), я
          подтверждаю, что:
        </p>
        <ul className="space-y-2 text-white/70 ml-4">
          <li className="relative pl-4 before:content-['✓'] before:absolute before:left-0 before:text-green-400">
            Ознакомлен(а) с условиями обработки моих персональных данных
          </li>
          <li className="relative pl-4 before:content-['✓'] before:absolute before:left-0 before:text-green-400">
            Ознакомлен(а) с{" "}
            <a
              href="/privacy"
              className="text-blue-400 hover:text-blue-300 underline transition-colors"
            >
              Политикой конфиденциальности
            </a>
          </li>
          <li className="relative pl-4 before:content-['✓'] before:absolute before:left-0 before:text-green-400">
            Даю согласие добровольно, без принуждения
          </li>
          <li className="relative pl-4 before:content-['✓'] before:absolute before:left-0 before:text-green-400">
            Понимаю свои права и порядок их реализации
          </li>
        </ul>
      </section>

      {/* Footer */}
      <footer className="text-center pt-8 border-t border-white/10">
        <p className="text-white/40 text-sm">
          © 2026 Infatium. Все права защищены.
        </p>
        <div className="mt-4 flex justify-center gap-6 text-sm">
          <a
            href="/privacy"
            className="text-white/50 hover:text-white/70 transition-colors"
          >
            Политика конфиденциальности
          </a>
          <a
            href="/terms"
            className="text-white/50 hover:text-white/70 transition-colors"
          >
            Пользовательское соглашение
          </a>
        </div>
      </footer>
    </article>
  );
}
