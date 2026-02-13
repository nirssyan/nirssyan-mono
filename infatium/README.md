# Makefeed

Кросс-платформенное Flutter-приложение (iOS, Android, Web, macOS, Windows, Linux) для персонализированных новостных лент и AI-чата. Приложение использует собственную систему аутентификации, n8n webhooks для backend-обработки, и Yandex AppMetrica для аналитики.

## Основные возможности

- **Custom Auth Service with JWT**: безопасная авторизация с автопродлением сессии, логированием событий безопасности
- **OAuth**: Sign in with Apple (iOS/macOS), Google Sign-In (все платформы)
- **Персонализированные новостные ленты**: подписка, создание и управление лентами через AI-чат
- **AI-powered чат**: интеграция с n8n webhooks для обработки сообщений и генерации контента
- **Маркетплейс**: поиск и подписка на новые ленты
- **Монетизация (опционально)**: система заработка для создателей лент (для RuStore)
- **Локализация**: поддержка русского и английского языков
- **Yandex AppMetrica**: отслеживание событий с GDPR-compliant хешированием и неограниченными properties
- **iOS-First дизайн**: Cupertino виджеты, строгая черно-белая цветовая схема, плавные анимации

## Требования

- **Flutter**: 3.24+ (Dart 3.8.1+)
- **iOS/macOS**: Xcode 15+, capability "Sign in with Apple" для Apple OAuth
- **Android**: Android Studio/SDK 34+, настроенный SHA-1 fingerprint для Google Sign-In
- **Web**: Настроенные CORS на backend API и n8n endpoints

## Установка

1. Установите Flutter SDK и инструменты платформы
2. Клонируйте репозиторий:
```bash
git clone <repository-url>
cd aichat
```
3. Установите зависимости:
```bash
flutter pub get
```

## Конфигурация

### Переменные окружения

Приложение требует compile-time переменные через `--dart-define`:

**Обязательные**:
- `API_KEY` - Backend API key
- `APPMETRICA_API_KEY` - Yandex AppMetrica API key

**Опциональные**:
- `ENABLE_MONETIZATION` - Включить функции монетизации (по умолчанию `false`)
- `API_BASE_URL` - Backend API base URL (по умолчанию `https://dev.api.infatium.ru`)
- `CUSTOM_AUTH_BASE_URL` - Custom auth service URL (по умолчанию `https://dev.api.infatium.ru/auth`)

### Sign in with Apple (iOS/macOS)

1. В Xcode включите capability "Sign in with Apple"
2. Настройте Service ID в Apple Developer Console
3. Добавьте Redirect URL `makefeed://auth/callback` в настройки Apple OAuth
4. Проверьте entitlements в `ios/Runner/Runner.entitlements`

## Запуск приложения

### Development

```bash
# Запуск на любой платформе
flutter run \
  --dart-define=API_KEY=your_api_key \
  --dart-define=APPMETRICA_API_KEY=your_appmetrica_key

# Запуск на конкретной платформе
flutter run -d chrome --dart-define=API_KEY=... --dart-define=APPMETRICA_API_KEY=...
flutter run -d ios --dart-define=API_KEY=... --dart-define=APPMETRICA_API_KEY=...
flutter run -d android --dart-define=API_KEY=... --dart-define=APPMETRICA_API_KEY=...
```

### Production builds

**ВАЖНО**: Разные магазины требуют разные feature flags. iOS App Store сборки НЕ ДОЛЖНЫ включать функции монетизации.

#### iOS App Store (БЕЗ монетизации)
```bash
flutter build ipa --release \
  --dart-define=API_KEY=... \
  --dart-define=APPMETRICA_API_KEY=...
  # ENABLE_MONETIZATION НЕ устанавливается (по умолчанию false)
```

#### Android RuStore (С монетизацией)
```bash
# APK
flutter build apk --release \
  --dart-define=API_KEY=... \
  --dart-define=APPMETRICA_API_KEY=... \
  --dart-define=ENABLE_MONETIZATION=true

# App Bundle
flutter build appbundle --release \
  --dart-define=API_KEY=... \
  --dart-define=APPMETRICA_API_KEY=... \
  --dart-define=ENABLE_MONETIZATION=true
```

#### Android Google Play (настраиваемо)
```bash
flutter build appbundle --release \
  --dart-define=API_KEY=... \
  --dart-define=APPMETRICA_API_KEY=...
  # ENABLE_MONETIZATION может быть true или false в зависимости от требований
```

## Архитектура

### Структура проекта

Приложение следует сервис-ориентированной архитектуре с четким разделением UI (pages/widgets), бизнес-логики (services) и данных (models).

**Точки входа**:
- `lib/main.dart` - точка входа приложения
- `lib/app.dart` - корневой виджет с темой, локализацией, инициализацией auth
- `lib/navigation/main_tab_scaffold.dart` - основная навигация (home, chat, feeds manager, profile)

### Сервисы (Singletons)

**Core Services** (все используют паттерн Singleton):
- `AuthService` - состояние аутентификации, OAuth, управление сессиями
- `NewsService` - получение и управление новостными лентами из backend API
- `ChatService` - HTTP клиент для chat API endpoints
- `ChatCacheService` - локальное кэширование сообщений чата
- `FeedManagementService` - управление подписками на ленты
- `ThemeService` - переключение и сохранение темной/светлой темы
- `LocaleService` - переключение языков (ru/en)
- `AnalyticsService` - отслеживание событий AppMetrica с идентификацией пользователей
- `NavigationService` - глобальное состояние навигации

### State Management

Приложение использует **ChangeNotifier pattern**:
- Сервисы наследуют `ChangeNotifier` и вызывают `notifyListeners()` при изменении состояния
- Виджеты подписываются на сервисы через `addListener()` и перестраиваются при изменениях
- Без внешних библиотек state management (нет Provider, Riverpod, Bloc)

### Backend API Integration

Приложение взаимодействует с **backend API** на `https://dev.api.infatium.ru`:

#### Authentication API (`lib/services/custom_auth_client.dart`)
- Базовый URL: `https://dev.api.infatium.ru/auth`
- Endpoints:
  - `POST /auth/google` - Google OAuth вход
  - `POST /auth/apple` - Apple OAuth вход
  - `POST /auth/magic-link` - отправка magic link
  - `POST /auth/verify` - верификация magic link
  - `POST /auth/refresh` - обновление токенов
  - `POST /auth/logout` - выход

#### Chat API (`lib/services/chat_service.dart`)
- Базовый URL: `https://dev.api.infatium.ru`
- Endpoints:
  - `GET /chats` - получить все чаты пользователя
  - `POST /chats/chat_message` - отправить сообщение в чат
  - `POST /chats/create_feed` - создать ленту из чата

#### News/Feed API (`lib/services/news_service.dart`)
- Endpoints:
  - `DELETE /users_feeds?feed_id={feedId}` - отписаться от ленты
  - `POST /feeds/rename` - переименовать ленту

#### Аутентификация API
Все запросы включают заголовки:
```dart
{
  'Content-Type': 'application/json',
  'X-API-Key': '<API_KEY>',  // из environment variable
  'user-id': '<user_id>',    // из custom auth
  'Authorization': 'Bearer <JWT>',  // access token из custom auth
}
```

### Структура данных Backend

```
users_feeds (join table)
  └── feeds (1:N)
      ├── name, created_at
      └── posts (1:N)
          ├── title, summary, full_text, image_urls
          └── sources (N:M)
              └── source_url, created_at
```

### UI Architecture

**iOS-First Design** с Cupertino виджетами:
- Использует `CupertinoApp`, `CupertinoPageScaffold`, `CupertinoNavigationBar`
- Строгая черно-белая цветовая схема (`lib/theme/colors.dart`)
- Кастомные модальные окна в iOS-стиле
- Плавные анимации и переходы

**Основные страницы**:
- `lib/pages/auth_page.dart` - авторизация/регистрация с email и OAuth
- `lib/pages/home_page.dart` - отображение новостной ленты
- `lib/pages/chat_page.dart` - интерфейс AI-чата
- `lib/pages/chat_list_page.dart` - история чатов
- `lib/pages/profile_page.dart` - настройки пользователя, тема, язык, выход
- `lib/pages/fullscreen_input_page.dart` - полноэкранный ввод текста для чата
- `lib/pages/monetization_page.dart` - отслеживание заработка (условно, только RuStore)

### Система монетизации (Distribution-Specific)

**Feature Flag System** (`lib/config/app_config.dart`):

Приложение использует compile-time feature flags для включения/отключения монетизации для разных магазинов.

**Почему это важно**:
- **iOS App Store**: функции монетизации ДОЛЖНЫ быть отключены для прохождения review Apple
- **RuStore**: функции монетизации могут быть включены для создателей лент
- **Google Play**: настраивается в зависимости от политики магазина

**Как это работает**:
1. `AppConfig.enableMonetization` - compile-time константа, устанавливаемая через `--dart-define=ENABLE_MONETIZATION=true`
2. Когда `false`, Flutter tree shaker **физически удаляет** весь код монетизации из бинарника
3. Это гарантирует, что Apple review не найдет скрытые функции монетизации
4. Паттерн кода:
```dart
if (AppConfig.enableMonetization) {
  // Этот код ФИЗИЧЕСКИ удаляется из iOS сборок
  Navigator.push(...MonetizationPage());
}
```

**Условные функции**:
- Пункт монетизации в профиле (показывается только при `enableMonetization = true`)
- `MonetizationPage` с dashboard заработка
- Отслеживание продаж лент и история транзакций

**Гарантия Tree Shaking**:
При сборке для iOS без флага, release бинарник НЕ СОДЕРЖИТ:
- Класс `MonetizationPage`
- Строки типа "monetization", "earnings", "sales"
- Связанные analytics события
- Код навигации к экранам монетизации

### Data Models

Ключевые модели в `lib/models/`:
- `chat_models.dart` - `Chat`, `ChatMessage` для чат-разговоров
- `news_item.dart` - `NewsItem` для новостных постов
- `feed_models.dart` - `Feed`, `Post`, `Source` для структуры данных backend
- `custom_auth_models.dart` - `CustomAuthState`, `CustomUser`, `CustomSession` для аутентификации

### Analytics

**Yandex AppMetrica** (`lib/services/analytics_service.dart`, `lib/config/appmetrica_config.dart`):
- Идентификация пользователя при входе с хешированным email (GDPR compliance)
- Автоматическое отслеживание экранов
- Отслеживание событий для ключевых действий пользователя
- Неограниченное количество properties для событий
- User profile атрибуты (platform, app_version, locale, user_id)
- Privacy controls (opt-in/opt-out с queryable state)
- Встроенная crash reporting
- Сброс при выходе

## Локализация

**Поддерживаемые языки**: Русский (ru), Английский (en)

**Добавление новых строк**:
1. Добавьте в `lib/l10n/app_en.arb` и `lib/l10n/app_ru.arb`
2. Запустите `flutter gen-l10n` или любую команду `flutter run/build`
3. Используйте через `AppLocalizations.of(context)!.yourKey`

Сгенерированный код находится в `lib/l10n/generated/`.

## Platform-Specific Notes

### iOS/macOS
- **Sign in with Apple** требует включенной capability в Xcode
- Проверьте entitlements в `ios/Runner/Runner.entitlements`
- Service ID и Redirect URL должны быть настроены в Apple Developer Console
- **UI**: страница авторизации показывает кнопки Google и Apple рядом
- **Примечание**: кнопка Apple автоматически скрывается на не-Apple платформах через `Platform.isIOS || Platform.isMacOS`

### Android
- Minimum SDK: см. `android/app/build.gradle.kts`
- Использует Kotlin для нативного кода
- Google Sign-In требует SHA-1 certificate fingerprint в Firebase Console
- **UI**: страница авторизации показывает только кнопку Google на всю ширину (Apple скрыта)
- **RuStore billing**: интеграция для монетизации при `ENABLE_MONETIZATION=true`

### Web
- CORS должен быть настроен на backend API endpoints для разрешения web origin
- Deep linking для OAuth callbacks требует правильной конфигурации redirect URL (`makefeed://auth/callback`)
- **UI**: страница авторизации показывает только кнопку Google на всю ширину (Apple скрыта)
- Google Sign-In на web требует правильной конфигурации OAuth client ID

## Команды разработки

### Тестирование
```bash
# Запустить все тесты
flutter test

# Запустить конкретный тест
flutter test test/widget_test.dart
```

### Качество кода
```bash
# Анализ кода на проблемы
flutter analyze

# Получить зависимости
flutter pub get

# Обновить зависимости
flutter pub upgrade
```

### Локализация
```bash
# Вручную регенерировать файлы локализации
flutter gen-l10n
```

## Основные зависимости

См. полный список в `pubspec.yaml`:

- **Auth & Backend**:
  - `sign_in_with_apple` - нативный Apple Sign-In
  - `google_sign_in` - Google OAuth
  - `dio` - HTTP клиент
  - `shared_preferences` - локальное хранилище токенов

- **Analytics**:
  - `appmetrica_plugin` - Yandex AppMetrica аналитика

- **UI & Media**:
  - `flutter_markdown` - рендеринг Markdown
  - `lottie` - анимации
  - `loading_animation_widget` - индикаторы загрузки
  - `photo_view` - просмотр изображений с зумом
  - `cached_network_image` - кэшированные изображения
  - `video_player` + `chewie` - видео плеер

- **Monetization**:
  - `flutter_rustore_billing` - RuStore платежи (Android)

## Паттерны разработки

### Добавление нового API endpoint

1. Добавьте метод в соответствующий сервис (`ChatService`, `NewsService` и т.д.)
2. Включите заголовки аутентификации: `X-API-Key`, `user-id`, `Authorization`
3. Обработайте ошибки с try-catch и логированием
4. Возвращайте типизированные модели, не сырой JSON

### Добавление новой страницы

1. Создайте в `lib/pages/`
2. Используйте `CupertinoPageScaffold` для iOS-стиль layout
3. Передайте необходимые сервисы через конструктор
4. Добавьте навигацию в `MainTabScaffold` или существующую страницу
5. Зарегистрируйте route observer для аналитики при необходимости

### Выполнение аутентифицированных запросов

```dart
import '../config/api_config.dart';

final user = AuthService().currentUser;
if (user == null) return; // Обработка неаутентифицированного состояния

final headers = {
  ...ApiConfig.commonHeaders,  // Включает 'Content-Type' и 'X-API-Key'
  'user-id': user.id,
  'Authorization': 'Bearer ${AuthService().currentSession?.accessToken}',
};

final response = await dio.post(url,
  data: data,
  options: Options(headers: headers),
);
```

## Отладка

- Приложение использует `LogService` для структурированного логирования (см. `lib/services/log_service.dart`)
- События безопасности логируются через `LogService.security()` в `AuthService`
- Проверяйте консоль для логов API запросов/ответов включая URLs, headers, bodies
- AppMetrica аналитику можно мониторить в AppMetrica dashboard: https://appmetrica.yandex.com/

## Траблшутинг

- **Нет авторизации?** Проверьте значения `--dart-define` для API_KEY и APPMETRICA_API_KEY, убедитесь что backend API доступен
- **iOS Sign in with Apple?** Убедитесь, что capability включена и правильные идентификаторы настроены в Apple Developer Console
- **CORS/Web?** Настройте backend API для разрешения нужных origins
- **Monetization не работает?** Проверьте, установлен ли `--dart-define=ENABLE_MONETIZATION=true` при сборке
- **RuStore billing?** Убедитесь, что приложение подписано правильным ключом и зарегистрировано в RuStore
- **Токены не обновляются?** Проверьте `TokenStorageService` и убедитесь что refresh token rotation работает корректно

## Конфигурация

- **Git branch**: `master` (основная ветка)
- **Package**: `publish_to: 'none'` в `pubspec.yaml` (приватный пакет)
- **iOS/macOS**: app identifier настроен в Xcode project
- **Android**: package name настроен в `android/app/build.gradle.kts`

## Лицензия

Проект закрытый. Используйте по назначению в рамках вашей команды/организации.
