# Настройка Xcode для параллельной установки Dev и Prod

## Цель

После настройки на iPhone можно установить одновременно:
- **infatium** (prod) - Bundle ID: `com.nirssyan.makefeed`
- **порнахаб** (dev) - Bundle ID: `com.nirssyan.makefeed.dev`

**Важно**: OAuth (Google и Apple) уже настроен и работает для обоих приложений. Дополнительная настройка OAuth НЕ требуется.

---

## Шаг 1: Открыть проект

```bash
open ios/Runner.xcworkspace
```

⚠️ Открывать `.xcworkspace`, НЕ `.xcodeproj`

---

## Шаг 2: Создать конфигурации

1. **Выбрать проект**
   - Левая панель → синяя иконка `Runner` (самый верхний)

2. **Вкладка Info**
   - Правая панель → вкладка `Info`
   - Прокрутить до секции `Configurations`

3. **Создать Dev конфигурацию**
   - Развернуть `Release`
   - Нажать `+` под списком конфигураций
   - Выбрать `Duplicate "Release" Configuration`
   - Назвать: `Dev` (точно так, с большой буквы)

4. **Создать Prod конфигурацию**
   - Снова нажать `+`
   - Выбрать `Duplicate "Release" Configuration`
   - Назвать: `Prod` (точно так, с большой буквы)

**Результат**: 5 конфигураций (Debug, Release, Profile, Dev, Prod)

---

## Шаг 3: Привязать к xcconfig файлам

**Во вкладке Info, в секции Configurations:**

1. **Конфигурация Dev**
   - Строка `Dev` → колонка `Runner`
   - Выбрать из выпадающего списка: `Flutter/Dev`

2. **Конфигурация Prod**
   - Строка `Prod` → колонка `Runner`
   - Выбрать из выпадающего списка: `Flutter/Prod`

**Результат**: Dev → Flutter/Dev.xcconfig, Prod → Flutter/Prod.xcconfig

---

## Шаг 4: Проверить Bundle ID (опционально)

1. **Build Settings**
   - Выбрать таргет `Runner` (под TARGETS)
   - Вкладка `Build Settings`
   - Переключить на `All` и `Combined`

2. **Найти Product Bundle Identifier**
   - В поиске ввести: `bundle identifier`
   - Развернуть строку `Product Bundle Identifier`

3. **Проверить значения**
   - Dev: `com.nirssyan.makefeed.dev` ✅
   - Prod: `com.nirssyan.makefeed` ✅

---

## Шаг 5: Создать схемы для Dev и Prod

### Схема для Dev

1. **Manage Schemes**
   - Меню Xcode → `Product` → `Scheme` → `Manage Schemes...`

2. **Дублировать Runner**
   - Выбрать схему `Runner`
   - Нажать ⚙️ (шестеренка внизу) → `Duplicate`
   - Назвать: `Runner-Dev`
   - ✅ Поставить галочку `Shared`
   - Закрыть

3. **Настроить Archive**
   - Выбрать схему `Runner-Dev`
   - Нажать `Edit...` (или двойной клик)
   - Левая панель → `Archive`
   - `Build Configuration` → выбрать `Dev`
   - Закрыть

### Схема для Prod

1. **Дублировать Runner еще раз**
   - `Product` → `Scheme` → `Manage Schemes...`
   - Выбрать `Runner`
   - ⚙️ → `Duplicate`
   - Назвать: `Runner-Prod`
   - ✅ Галочка `Shared`
   - Закрыть

2. **Настроить Archive**
   - Выбрать `Runner-Prod` → `Edit...`
   - Левая панель → `Archive`
   - `Build Configuration` → выбрать `Prod`
   - Закрыть

**Результат**: 3 схемы (Runner, Runner-Dev, Runner-Prod)

---

## Шаг 6: Проверить настройку

### Dev билд

1. **Выбрать схему**
   - Меню `Product` → `Scheme` → `Runner-Dev`

2. **Создать архив**
   - Меню `Product` → `Archive`
   - Дождаться завершения

3. **Проверить в Organizer**
   - Должно быть: `порнахаб`
   - Bundle ID: `com.nirssyan.makefeed.dev`

### Prod билд

1. **Выбрать схему**
   - `Product` → `Scheme` → `Runner-Prod`

2. **Создать архив**
   - `Product` → `Archive`

3. **Проверить в Organizer**
   - Должно быть: `infatium`
   - Bundle ID: `com.nirssyan.makefeed`

---

## Шаг 7: Apple Developer Portal

### 1. Зарегистрировать Dev Bundle ID

1. Открыть: https://developer.apple.com/account/resources/identifiers/list
2. Нажать `+`
3. Выбрать `App IDs` → Continue
4. Type: `App` → Continue
5. Заполнить:
   - **Description**: `Makefeed Development`
   - **Bundle ID**: **Explicit** → `com.nirssyan.makefeed.dev`
6. **Capabilities** (включить то же, что в проде):
   - ✅ Sign in with Apple
   - ✅ Push Notifications
   - ✅ Associated Domains
7. `Continue` → `Register`

### 2. Создать Provisioning Profile

1. Открыть: https://developer.apple.com/account/resources/profiles/list
2. Нажать `+`
3. Выбрать: **Distribution** → **App Store** → Continue
4. **App ID**: выбрать `com.nirssyan.makefeed.dev`
5. Выбрать **Distribution Certificate**
6. **Profile Name**: `Makefeed Dev App Store`
7. `Generate`
8. **Download** и двойной клик для установки в Xcode

### 3. App Store Connect (опционально)

Если нужно отдельное приложение в TestFlight:

1. Открыть: https://appstoreconnect.apple.com/apps
2. Нажать `+` → `New App`
3. Заполнить:
   - **Platform**: iOS
   - **Name**: `порнахаб` (или оставить то же имя)
   - **Bundle ID**: `com.nirssyan.makefeed.dev`
   - **SKU**: `makefeed-dev`
4. Submit

---

## Шаг 8: Push Notifications (если нужно)

1. Открыть: https://developer.apple.com/account/resources/authkeys/list
2. Создать новый **APNs Key** (или использовать существующий)
3. Загрузить на бэкенд для Bundle ID: `com.nirssyan.makefeed.dev`

---

## Готово! Как использовать

### Dev билд (TestFlight)

```bash
./scripts/build-ios-dev.sh
```

Или в Xcode:
1. Схема: `Runner-Dev`
2. `Product` → `Archive`
3. `Distribute App` → `App Store Connect` → `Upload`

### Prod билд (App Store)

```bash
./scripts/build-ios-prod.sh
```

Или в Xcode:
1. Схема: `Runner-Prod`
2. `Product` → `Archive`
3. `Distribute App` → `App Store Connect` → `Upload`

---

## Проверка на iPhone

1. Загрузить dev билд в TestFlight → установить
2. Загрузить prod билд в App Store → установить
3. На экране должны быть ДВА приложения:
   - `infatium` (продакшн)
   - `порнахаб` (разработка)

✅ Оба работают одновременно
✅ Разные данные (пользователи, ленты, авторизация)

---

## Частые проблемы

| Проблема | Решение |
|----------|---------|
| "No matching provisioning profiles found" | Создать provisioning profile для `com.nirssyan.makefeed.dev` |
| "Invalid Bundle ID" | Зарегистрировать `com.nirssyan.makefeed.dev` в Apple Developer |
| Оба приложения открываются от magic link | Нужны разные deep link схемы (`makefeeddev://` для dev) |

---

## Чеклист

После настройки проверить:

- [ ] 5 конфигураций в Xcode (Debug, Release, Profile, Dev, Prod)
- [ ] Dev → Flutter/Dev.xcconfig
- [ ] Prod → Flutter/Prod.xcconfig
- [ ] 3 схемы (Runner, Runner-Dev, Runner-Prod)
- [ ] Dev архив имеет Bundle ID `com.nirssyan.makefeed.dev`
- [ ] Prod архив имеет Bundle ID `com.nirssyan.makefeed`
- [ ] Dev Bundle ID зарегистрирован в Apple Developer
- [ ] Provisioning profile создан и установлен
- [ ] Оба приложения установлены на iPhone
