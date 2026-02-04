# Инструкция по деплою страницы шаринга новостей

## ✅ Что уже сделано:

1. ✅ Создана dynamic route `/news/[postId]`
2. ✅ Реализован SSR с OpenGraph метатегами
3. ✅ Создан компонент deep linking кнопки
4. ✅ Исправлены ESLint warnings
5. ✅ Проект успешно собирается

---

## 🔧 Шаги для завершения:

### 1. Обновить `.env.local` с реальными значениями

Откройте `.env.local` и замените placeholder значения:

```bash
# Makefeed API Configuration
NEXT_PUBLIC_API_BASE_URL=https://makefeed.nirssyan.ru
API_KEY=ВАШ_РЕАЛЬНЫЙ_N8N_API_KEY  # ⚠️ Замените!

# App Store Links
NEXT_PUBLIC_APP_STORE_ID=ВАШ_APP_STORE_ID  # ⚠️ Замените!
NEXT_PUBLIC_PLAY_STORE_ID=com.makefeed  # ✅ Уже правильно
```

**Где взять значения:**
- `API_KEY` - из Flutter проекта (lib/config/api_config.dart) или из .env файла
- `NEXT_PUBLIC_APP_STORE_ID` - из App Store Connect (например: 1234567890)

---

### 2. Локальное тестирование

```bash
cd /Users/danilakiva/work/aichatnewlanding/makefeed-landing

# Запустить dev сервер
npm run dev

# Открыть в браузере
# http://localhost:3000/news/0422d1e9-1dbc-4f75-9fc7-afbf8896f656
```

**Что проверить:**
- [ ] Страница загружается
- [ ] Отображается заголовок, изображение, текст
- [ ] Контент заблюрен
- [ ] Кнопка "Читать в Makefeed" работает
- [ ] OpenGraph теги присутствуют (View Page Source → проверить `<meta property="og:title"`)

---

### 3. Деплой на Vercel

#### Вариант A: Автоматический деплой (рекомендуется)

```bash
cd /Users/danilakiva/work/aichatnewlanding/makefeed-landing

# Добавить изменения
git add .
git commit -m "Add news share page with OpenGraph support"
git push origin main

# Vercel автоматически задеплоит (если подключен GitHub)
```

#### Вариант B: Ручной деплой через Vercel CLI

```bash
cd /Users/danilakiva/work/aichatnewlanding/makefeed-landing

# Установить Vercel CLI (если еще не установлен)
npm i -g vercel

# Логин
vercel login

# Production деплой
vercel --prod
```

---

### 4. Добавить env переменные в Vercel Dashboard

После деплоя, добавьте переменные окружения в Vercel:

1. Откройте: https://vercel.com/dashboard
2. Выберите проект `makefeed-landing`
3. Settings → Environment Variables
4. Добавьте:

```
API_KEY = ваш_реальный_api_key
NEXT_PUBLIC_API_BASE_URL = https://makefeed.nirssyan.ru
NEXT_PUBLIC_APP_STORE_ID = ваш_app_store_id
NEXT_PUBLIC_PLAY_STORE_ID = com.makefeed
```

5. Нажмите "Save"
6. Redeploy проект (Deployments → ... → Redeploy)

---

### 5. Настроить custom domain (опционально)

Если хотите использовать `share.makefeed.com` вместо `infatium.ai/news`:

1. Vercel Dashboard → Settings → Domains
2. Добавить `share.makefeed.com`
3. Настроить DNS (CNAME запись):
   ```
   CNAME share.makefeed.com → cname.vercel-dns.com
   ```

**Или** использовать существующий домен:
- URL будет: `https://infatium.ai/news/{postId}`

---

### 6. Обновить Flutter приложение

После деплоя, обновите `SHARE_BASE_URL` в Flutter app:

**Файл:** `/Users/danilakiva/work/aichat/lib/pages/news_detail_page.dart`

Замените:
```dart
const String shareBaseUrl = String.fromEnvironment(
  'SHARE_BASE_URL',
  defaultValue: 'https://share.makefeed.com',  // Старое значение
);
```

На:
```dart
const String shareBaseUrl = String.fromEnvironment(
  'SHARE_BASE_URL',
  defaultValue: 'https://infatium.ai',  // ИЛИ ваш custom domain
);
```

**Пересобрать Flutter app:**
```bash
cd /Users/danilakiva/work/aichat

flutter build apk --release \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=API_KEY=... \
  --dart-define=POSTHOG_API_KEY=...
```

---

### 7. Тестирование в Telegram

1. Откройте приложение Makefeed
2. Откройте любую новость
3. Нажмите кнопку "Поделиться"
4. Отправьте ссылку себе в Telegram Saved Messages
5. Проверьте, что Telegram показывает:
   - ✅ Заголовок новости
   - ✅ Описание (summary)
   - ✅ Изображение новости

**Если превью не появилось:**
- Очистите кэш Telegram: https://developers.facebook.com/tools/debug/
- Проверьте OpenGraph теги: View Page Source → `<meta property="og:..."`

---

## 🎉 Готово!

После выполнения всех шагов:
- ✅ Страница шаринга работает на production
- ✅ Telegram показывает красивое превью
- ✅ Deep linking открывает приложение
- ✅ Заблюренный контент мотивирует установку

---

## 🐛 Troubleshooting

### Проблема: OpenGraph не работает в Telegram

**Решение:**
1. Проверьте что страница доступна публично (не требует auth)
2. Проверьте OpenGraph теги: https://developers.facebook.com/tools/debug/
3. Очистите кэш через Facebook Debugger
4. Убедитесь что SSR работает (View Page Source должен показывать реальные данные)

### Проблема: API Key error в логах

**Решение:**
1. Проверьте что `API_KEY` добавлен в Vercel Environment Variables
2. Redeploy проект после добавления переменных
3. Проверьте что ключ правильный (скопируйте из Flutter проекта)

### Проблема: Изображения не загружаются

**Решение:**
1. Проверьте что в `next.config.ts` есть `remotePatterns: [{ hostname: '**' }]`
2. Проверьте консоль браузера на ошибки CORS
3. Убедитесь что URL изображения доступен

---

## 📞 Контакты

Если возникли проблемы - проверьте логи:
- Vercel Dashboard → Deployments → [latest] → Function Logs
- Browser Console (F12)
