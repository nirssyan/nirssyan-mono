# Архитектура аутентификации в Makefeed

## Текущая система авторизации

**Backend**: Supabase Auth (PKCE OAuth flow)

**Файлы**:
- `lib/services/auth_service.dart` - основной сервис аутентификации
- `lib/config/supabase_config.dart` - конфигурация Supabase
- `lib/pages/auth_page.dart` - UI страница логина/регистрации

## Поддерживаемые методы входа

### 1. Email & Password
- Нативная поддержка Supabase
- Регистрация через `auth.signUp()`
- Вход через `auth.signInWithPassword()`
- Валидация пароля (мин 8 символов, спецсимволы, и т.д.)

### 2. Google OAuth
- **Платформы**: iOS, Android, Web
- **Нативная интеграция**: `google_sign_in` пакет для iOS/Android
- **OAuth fallback**: WebView для Web
- **Supabase**: `auth.signInWithIdToken(provider: OAuthProvider.google)`
- **Client IDs**:
  - iOS: `715376087095-b1rsvvumtrilroc1n6285j531rp81trh.apps.googleusercontent.com`
  - Android: `715376087095-bl8qcgde9ck9bb747vrdtiuod8t2k9v4.apps.googleusercontent.com`
  - Server: `715376087095-efe3d3fldj3tt23f6a77mnp3792864k3.apps.googleusercontent.com`

### 3. Sign in with Apple
- **Платформы**: ТОЛЬКО iOS и macOS
- **Нативная интеграция**: `sign_in_with_apple` пакет
- **Supabase**: `auth.signInWithIdToken(provider: OAuthProvider.apple)`
- **OAuth fallback**: WebView для других платформ
- **UI**: Кнопка показывается только на iOS/macOS

## Платформенная логика отображения кнопок OAuth

```dart
// iOS/macOS: Google + Apple рядом
if (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
  Row([Google Button, Apple Button])

// Android/Web: только Google на всю ширину
else
  Google Button (full width)
```

## VK ID интеграция (планируется)

⚠️ **ВАЖНО**: Supabase НЕ поддерживает VK ID как нативного OAuth провайдера!

### Требуется кастомная интеграция через backend:

1. **Frontend** (`vkid_flutter_sdk`):
   - Получает VK ID access token через SDK
   - Отправляет токен на backend endpoint

2. **Backend** (n8n webhook `/auth/vk`):
   - Валидирует VK токен через VK ID API
   - Получает данные пользователя (email, имя, VK ID)
   - Создает/находит пользователя в Supabase через Admin API
   - Генерирует Supabase JWT токен
   - Возвращает токен клиенту

3. **Frontend** (продолжение):
   - Получает Supabase JWT от backend
   - Авторизуется через `auth.setSession()`

### Платформенная логика с VK ID:

```dart
// Android: Google + VK рядом
if (!kIsWeb && Platform.isAndroid)
  Row([Google Button, VK Button])

// iOS/macOS: Google + Apple рядом
else if (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
  Row([Google Button, Apple Button])

// Web: только Google на всю ширину
else
  Google Button (full width)
```

## Конфигурация

**Supabase credentials** (через `--dart-define`):
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

**OAuth credentials** (захардкожены в коде):
- Google Client IDs (iOS, Android, Server)
- Apple Service ID (настроено через Xcode entitlements)

**VK ID credentials** (через `android/local.properties` - будущее):
- `VKIDClientID`
- `VKIDClientSecret`

## Особенности

- **Session Management**: Автоматическое обновление токена за 5 минут до истечения
- **Analytics**: Идентификация пользователя в PostHog при входе
- **Security Logging**: Логирование всех событий безопасности
- **Error Handling**: Детальная обработка ошибок с локализованными сообщениями
- **Cache Clearing**: Очистка кэша тегов и чатов при выходе