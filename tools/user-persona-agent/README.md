# User Persona Agent

Внутренний инструмент для product-исследований. Агент симулирует реального пользователя-энтузиаста определённой тематики: ищет Telegram-каналы через TG STAT, а затем продумывает оптимальную настройку ленты в приложении.

## Установка

```bash
cd tools/user-persona-agent
npm install
```

Также нужен [agent-browser](https://github.com/AIMobileAction/agent-browser) — CLI для браузерной автоматизации:

```bash
agent-browser install
```

Убедитесь, что вы залогинены в `claude` CLI (агент использует OAuth-аутентификацию через CLI):

```bash
claude login
```

## Запуск

```bash
npx tsx src/index.ts "Тема"
```

Примеры:

```bash
npx tsx src/index.ts "Кибербезопасность"
npx tsx src/index.ts "Машинное обучение"
npx tsx src/index.ts "Криптовалюты"
```

## Что на выходе

Markdown-файл в `output/` с:
- Описанием персоны пользователя
- Таблицей найденных Telegram-каналов (5-15 штук)
- Рекомендациями по настройке ленты (тип, views, фильтры)
- Обоснованием выбранной конфигурации
