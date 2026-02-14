# GlitchTip Error Tracking Integration

## Обзор

GlitchTip — это self-hosted система error tracking, совместимая с Sentry API. Интеграция позволяет автоматически отслеживать и анализировать все ошибки в продакшене.

## Текущий статус

✅ **Интеграция завершена:**
- Sentry Flutter SDK установлен (`sentry_flutter: ^9.12.0`)
- `ErrorLoggingService` реализован с breadcrumbs, user context, деdupликацией
- `main.dart` обновлён с обработчиками всех типов ошибок
- Privacy фильтрация (GDPR compliance)
- Конфигурация через `GLITCHTIP_DSN` environment variable

## Архитектура

```
┌─────────────────────────────────────────────────────┐
│           Flutter App Error Sources                 │
├─────────────────────────────────────────────────────┤
│ 1. Flutter Framework Errors (FlutterError.onError) │
│ 2. Dart Zone Errors (runZonedGuarded)              │
│ 3. Platform Errors (PlatformDispatcher.instance)   │
│ 4. Manual Capture (ErrorLoggingService)            │
└────────────┬────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────┐
│         ErrorLoggingService                         │
│  - Breadcrumb tracking                              │
│  - User context (from AuthService)                  │
│  - Device/platform context                          │
│  - Privacy filtering (GDPR)                         │
│  - Rate limiting (50 errors/min)                    │
│  - Deduplication                                    │
└────────┬────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│     GlitchTip (Self-Hosted)                         │
│  https://glitchtip.infra.makekod.ru                 │
│  Project ID: 1                                      │
└────────┬────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│           GlitchTip Dashboard                       │
│  - Error grouping по fingerprint                    │
│  - Stack traces + breadcrumbs                       │
│  - User context                                     │
│  - Trends/graphs                                    │
└─────────────────────────────────────────────────────┘
```

## Конфигурация

### DSN (Data Source Name)

**Production:**
```
GLITCHTIP_DSN=https://f3a86334caf4467da51f2f4d60ae7186@glitchtip.infra.makekod.ru/1
```

DSN уже добавлен в:
- `config/dev.local.json`
- `config/prod.local.json`
- `config/dev.local.json.example`
- `config/prod.local.json.example`

### Настройки

Конфигурация в `lib/config/glitchtip_config.dart`:
- **DSN:** Загружается из `GLITCHTIP_DSN` environment variable
- **Dashboard URL:** `https://glitchtip.infra.makekod.ru`
- **Validation:** Автоматическая проверка DSN при запуске

## Использование

### Автоматический захват ошибок

Все uncaught ошибки автоматически отправляются в GlitchTip:

```dart
// Flutter framework errors
FlutterError.onError = (details) {
  Sentry.captureException(details.exception, stackTrace: details.stack);
};

// Dart zone errors
runZonedGuarded(() {
  runApp(MyApp());
}, (error, stack) {
  Sentry.captureException(error, stackTrace: stack);
});

// Platform errors (iOS/Android native)
PlatformDispatcher.instance.onError = (error, stack) {
  Sentry.captureException(error, stackTrace: stack);
  return true;
};
```

### Ручной захват ошибок

В сервисах используйте `ErrorLoggingService`:

```dart
import 'package:makefeed/services/error_logging_service.dart';

try {
  await fetchData();
} catch (e, stack) {
  await ErrorLoggingService().captureException(
    e,
    stack,
    context: 'news_fetch',
    extraData: {'feed_id': feedId},
    severity: ErrorSeverity.error,
  );
  rethrow; // или обработать
}
```

### HTTP ошибки

Для API errors используйте `captureHttpError`:

```dart
if (response.statusCode >= 400) {
  await ErrorLoggingService().captureHttpError(
    endpoint: '/api/chats',
    statusCode: response.statusCode,
    method: 'POST',
    errorMessage: response.body,
    service: 'chat',
  );
}
```

### Breadcrumbs (User Actions)

Добавляйте breadcrumbs в критических точках:

```dart
void _sendMessage() {
  ErrorLoggingService().addBreadcrumb(
    'send_message',
    'chat_page',
    data: {
      'chat_id': widget.chatId,
      'message_length': _messageController.text.length,
    },
  );

  // ... existing code
}
```

### Set Current Route

Обновляйте текущий маршрут при навигации:

```dart
@override
void initState() {
  super.initState();
  ErrorLoggingService().setCurrentRoute('/home');
}
```

## Тестирование

### 1. Локальный тест (Debug Mode)

Запустите приложение и проверьте консоль:

```bash
./scripts/run-dev.sh
```

В консоли должно появиться:
```
Makefeed: GlitchTip error tracking enabled
Makefeed: Dashboard at https://glitchtip.infra.makekod.ru
Makefeed: ErrorLoggingService initialized
```

### 2. Тест manual error

Добавьте тестовую кнопку в `ProfilePage` (только в debug mode):

```dart
import 'package:flutter/foundation.dart';

// В build():
if (kDebugMode) {
  CupertinoButton(
    child: Text('Test Error Logging'),
    onPressed: () async {
      // Test exception
      await ErrorLoggingService().captureException(
        Exception('Test error from ProfilePage'),
        StackTrace.current,
        context: 'test',
        extraData: {'test_key': 'test_value'},
        severity: ErrorSeverity.warning,
      );

      // Show confirmation
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Error Sent'),
          content: Text('Check GlitchTip dashboard in 1-2 minutes'),
          actions: [
            CupertinoButton(
              child: Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    },
  );
}
```

### 3. Проверка в GlitchTip Dashboard

1. Откройте https://glitchtip.infra.makekod.ru
2. Войдите в аккаунт
3. Выберите проект "Makefeed Production" (Project ID: 1)
4. Проверьте список Issues - должна появиться новая ошибка "Test error from ProfilePage"
5. Откройте Issue и проверьте:
   - ✅ Stack trace
   - ✅ User context (user_id, email_hash)
   - ✅ Device info (platform, OS version, app version)
   - ✅ Breadcrumbs (последние действия пользователя)
   - ✅ Extra context (test_key: test_value)

### 4. Production Test

После деплоя в TestFlight/App Store:

1. Вызовите ошибку (например, отключите интернет и обновите ленту)
2. Подождите 1-2 минуты
3. Проверьте GlitchTip dashboard
4. Убедитесь что ошибка появилась с правильным контекстом

## Privacy & GDPR

### Автоматическая фильтрация

В `main.dart` реализована функция `_sanitizeMessage()`, которая удаляет:

- ✅ API keys (`API_KEY=***`)
- ✅ JWT tokens (`Bearer ***`, `eyJ...`)
- ✅ Email addresses (`***@***.***`)
- ✅ Refresh tokens (`rt_***`)
- ✅ Phone numbers (`***PHONE***`)

### User Context

- ✅ User ID отправляется (для связи ошибок с пользователем)
- ✅ Email НЕ отправляется напрямую (используется hash)
- ✅ `sendDefaultPii: false` (нет автоматической отправки PII)

### Opt-out (будущая функция)

Добавить в `ProfilePage` настройку:

```dart
CupertinoListTile(
  title: Text('Error Reporting'),
  subtitle: Text('Help improve the app by sending crash reports'),
  trailing: CupertinoSwitch(
    value: _errorReportingEnabled,
    onChanged: (value) async {
      // Disable/enable Sentry
      await Sentry.close();
      if (value) {
        await SentryFlutter.init(/* ... */);
      }
      setState(() => _errorReportingEnabled = value);
    },
  ),
);
```

## Rate Limiting & Deduplication

### Rate Limiting

- **Limit:** 50 errors per minute per device
- **Purpose:** Предотвратить флуд при error loops
- **Implementation:** В `ErrorLoggingService._shouldCaptureError()`

### Deduplication

- **Mechanism:** Fingerprint-based (error type + top 3 stack trace lines)
- **Cache:** Последние 100 unique fingerprints
- **Purpose:** Не отправлять одну и ту же ошибку многократно

## Метрики и Мониторинг

### Performance Monitoring

В `main.dart` настроен performance monitoring:

```dart
options.tracesSampleRate = kDebugMode ? 1.0 : 0.1; // 10% в prod
options.profilesSampleRate = kDebugMode ? 1.0 : 0.1;
```

- **Development:** 100% транзакций отслеживаются
- **Production:** 10% sampling для снижения overhead

### Alerts (рекомендуется настроить)

В GlitchTip Dashboard → Project Settings → Alerts:

1. **New Issue Alert**
   - Условие: New issue created
   - Action: Email notification

2. **High Frequency Alert**
   - Условие: Issue count > 100 in 1 hour
   - Action: Slack webhook

3. **User Impact Alert**
   - Условие: Affected users > 10
   - Action: Email + webhook

## Troubleshooting

### Ошибки не появляются в GlitchTip

1. **Проверьте DSN:**
   ```bash
   cat config/dev.local.json | grep GLITCHTIP_DSN
   ```

2. **Проверьте консоль при запуске:**
   ```
   Makefeed: GlitchTip error tracking enabled ← Должно быть
   ```

3. **Проверьте firewall:**
   ```bash
   curl https://glitchtip.infra.makekod.ru
   ```

4. **Проверьте debug logs:**
   - В debug mode все captured errors выводятся в консоль
   - Ищите `[ErrorLoggingService] Captured error`

### Rate limit exceeded

Если видите `[ErrorLoggingService] Rate limit exceeded, skipping error`:

- Это нормально при error loops
- Проверьте почему происходит так много ошибок
- Limit можно увеличить в `ErrorLoggingService.maxErrorsPerMinute`

### Duplicate errors skipped

Если видите `[ErrorLoggingService] Duplicate error, skipping`:

- Это нормально - деdupликация работает
- Одна и та же ошибка не отправляется повторно в течение сессии
- Кеш очищается при перезапуске приложения

## Next Steps

### Рекомендуемые улучшения:

1. **Интеграция с HTTP Client:**
   - Обновить `AuthenticatedHttpClient` для автоматического захвата HTTP errors
   - Добавить в каждый HTTP метод (get, post, patch, delete)

2. **Breadcrumbs в key flows:**
   - `ChatPage._sendMessage()` - отправка сообщения
   - `NewsService.fetchUserFeeds()` - загрузка ленты
   - `AuthService.signInWithGoogle()` - авторизация

3. **LogService Integration:**
   - Обновить `LogService` для делегирования ERROR/CRITICAL в ErrorLoggingService
   - Автоматическая отправка всех `LogLevel.error` в GlitchTip

4. **Alerts Configuration:**
   - Настроить email alerts для critical issues
   - Интеграция со Slack/Telegram для real-time notifications

5. **Opt-out UI:**
   - Добавить в ProfilePage настройку "Error Reporting"
   - Сохранять preference в SharedPreferences

## Документация

- **GlitchTip Docs:** https://glitchtip.com/documentation
- **Sentry Flutter SDK:** https://docs.sentry.io/platforms/flutter/
- **Конфигурация проекта:** `/Users/danilakiva/work/aichat/config/README.md`
- **CLAUDE.md:** Обновлён с документацией по error tracking

## Support

- **Dashboard:** https://glitchtip.infra.makekod.ru
- **Production Project ID:** 1
- **DSN:** `https://f3a86334caf4467da51f2f4d60ae7186@glitchtip.infra.makekod.ru/1`
