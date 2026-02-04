# Makelanding Deployment Setup

## ✅ Что уже сделано

1. ✅ Создан `docker-compose.makelanding.yml` в cloud-infra/
2. ✅ Создан `.github/workflows/docker-build.yml` для автоматического build/push
3. ✅ Создан `.env.production.example` с документацией переменных
4. ✅ Обновлен `Dockerfile` с поддержкой build args
5. ✅ Добавлена nginx конфигурация для **infatium.nirssyan.ru** в `cloud-infra/configs/nginx/nirssyan.conf`

## 📋 Следующие шаги

### 1. Настроить GitHub Secrets

Перейдите в настройки репозитория makelanding на GitHub:

```
GitHub Repository → Settings → Secrets and variables → Actions → New repository secret
```

Добавьте следующие secrets:

| Secret Name | Описание | Где взять |
|------------|----------|-----------|
| `DOCKER_REGISTRY_USERNAME` | Имя пользователя Docker registry | registry.nirssyan.ru credentials |
| `DOCKER_REGISTRY_PASSWORD` | Пароль Docker registry | registry.nirssyan.ru credentials |
| `NEXT_PUBLIC_API_BASE_URL` | API URL | `https://makefeed.nirssyan.ru` |
| `NEXT_PUBLIC_APP_STORE_ID` | iOS App Store ID | App Store Connect |
| `NEXT_PUBLIC_PLAY_STORE_ID` | Android Package ID | `com.infatium` |
| `API_KEY` | Backend API Key | Из makefeed-service конфигурации |

### 2. Протестировать GitHub Actions

После настройки secrets:

```bash
# В репозитории makelanding
git add .
git commit -m "Add deployment configuration"
git push origin main
```

GitHub Actions автоматически запустится и:
- Соберет Docker образ
- Загрузит его в `registry.nirssyan.ru/makelanding:latest`
- Отправит webhook в n8n

Проверить статус:
```
GitHub Repository → Actions → Build and Push Image
```

### 3. Деплой на сервер

#### Подготовка сервера

```bash
# Скопировать docker-compose файл на сервер
scp cloud-infra/docker-compose.makelanding.yml root@SERVER_IP:/home/infra/makelanding/docker-compose.yml

# Или создать директорию и скопировать
ssh root@SERVER_IP "mkdir -p /home/infra/makelanding"
scp cloud-infra/docker-compose.makelanding.yml root@SERVER_IP:/home/infra/makelanding/docker-compose.yml
```

#### Первый деплой

```bash
# Подключиться к серверу
ssh root@SERVER_IP

# Перейти в директорию
cd /home/infra/makelanding

# Запустить контейнер
docker compose up -d

# Проверить статус
docker compose ps
docker compose logs -f
```

#### Обновление (после новых коммитов)

После push в main, GitHub Actions автоматически собирает новый образ. Обновить на сервере:

```bash
ssh root@SERVER_IP "cd /home/infra/makelanding && docker compose pull && docker compose up -d"
```

Или настроить Watchtower для автоматического обновления (уже включен в docker-compose.yml).

### 4. Проверить работу

```bash
# Проверить healthcheck
curl http://SERVER_IP:8082/api/health

# Проверить новостную страницу
curl http://SERVER_IP:8082/news/TEST_POST_ID
```

В браузере:
```
http://SERVER_IP:8082
http://SERVER_IP:8082/news/[postId]
```

### 5. Настроить nginx

Конфигурация для **infatium.nirssyan.ru** уже добавлена в `cloud-infra/configs/nginx/nirssyan.conf`.

Применить на сервере:

```bash
# Скопировать обновленную конфигурацию на сервер
scp cloud-infra/configs/nginx/nirssyan.conf root@SERVER_IP:/etc/nginx/sites-available/nirssyan.conf

# Проверить конфигурацию nginx
ssh root@SERVER_IP "nginx -t"

# Перезагрузить nginx
ssh root@SERVER_IP "systemctl reload nginx"

# Или если используется docker nginx:
ssh root@SERVER_IP "docker exec nginx nginx -s reload"
```

После применения, приложение будет доступно по адресу:
- ✅ https://infatium.nirssyan.ru (HTTPS с SSL)
- HTTP автоматически редиректится на HTTPS

**Важно**: Убедитесь что:
1. SSL сертификаты установлены в `/etc/nginx/ssl/cert.pem` и `/etc/nginx/ssl/key.pem`
2. DNS запись для infatium.nirssyan.ru указывает на SERVER_IP
3. Порт 80 и 443 открыты в firewall

## 🔧 Troubleshooting

### Build failed в GitHub Actions

Проверьте:
1. Все secrets настроены правильно
2. Docker registry доступен
3. Логи в GitHub Actions для деталей ошибки

### Контейнер не запускается

```bash
# Посмотреть логи
docker compose logs makelanding

# Проверить healthcheck
docker inspect makelanding | grep -A 10 Health
```

### Healthcheck fails

Убедитесь что:
1. Port 3000 доступен внутри контейнера
2. Next.js приложение успешно стартовало
3. `/api/health` endpoint существует

### Переменные окружения не работают

Для NEXT_PUBLIC_* переменных:
- Они должны быть заданы при BUILD времени (build-args)
- Пересоберите образ после изменения secrets

Для API_KEY:
- Это runtime переменная
- Можно передать через environment в docker-compose.yml

## 📊 Мониторинг

### Логи

```bash
# Просмотр логов
docker compose logs -f makelanding

# Последние 100 строк
docker compose logs --tail=100 makelanding
```

### Статус контейнера

```bash
docker compose ps
docker stats makelanding
```

### Watchtower (авто-обновления)

Watchtower уже настроен в docker-compose.yml. Он автоматически:
- Проверяет наличие новых образов
- Обновляет контейнер при наличии новой версии
- Сохраняет старый образ для отката

## 🎯 Итоговый workflow

1. Developer: `git push origin main`
2. GitHub Actions: Build → Push to registry
3. n8n: Получает webhook (опционально можно настроить авто-деплой)
4. Watchtower: Автоматически подтягивает новый образ (или вручную)
5. Container: Перезапускается с новым кодом

## 📁 Структура файлов

```
makelanding/
├── .github/
│   └── workflows/
│       └── docker-build.yml          # GitHub Actions workflow
├── Dockerfile                        # С build args
├── .env.production.example           # Документация env переменных
└── DEPLOYMENT_SETUP.md              # Этот файл

cloud-infra/
├── docker-compose.makelanding.yml    # Docker Compose конфигурация
└── configs/
    └── nginx/
        └── nirssyan.conf             # Nginx конфигурация (обновлена с infatium.nirssyan.ru)
```
