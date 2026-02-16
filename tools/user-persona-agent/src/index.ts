import { query } from "@anthropic-ai/claude-agent-sdk";
import { readFileSync, writeFileSync, appendFileSync, mkdirSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, "..");
const CDP_PORT = 9222;

const DEFAULT_PERSONA = `Ты — технически грамотный человек, который активно пользуется Telegram для получения информации. Ценишь глубокий авторский контент, не терпишь рекламу и пустые перепосты. Хочешь находить нишевые каналы с уникальной экспертизой, а не раскрученные помойки.`;

function buildSystemPrompt(topic: string, persona: string, productContext: string): string {
  const searchQuery = encodeURIComponent(`лучшие telegram каналы ${topic}`);
  const searchQueryEn = encodeURIComponent(`best telegram channels ${topic}`);

  return `${persona}

Ты недавно нашёл интересное приложение для персонализированных новостных лент:

${productContext}

Ты хочешь собрать себе ленту по теме "${topic}". Для этого нужно найти Telegram-каналы с реально качественным контентом, а не полагаться на чужие подборки или число подписчиков.

# БРАУЗЕР

У тебя есть браузер — утилита \`agent-browser\`. Она подключена к реальному Chrome пользователя через CDP (Chrome DevTools Protocol). Google залогинен, куки сохранены, Cloudflare пропускает.

Команды:
\`\`\`bash
# Навигация (ВСЕГДА с --cdp ${CDP_PORT} --headed):
agent-browser --cdp ${CDP_PORT} open "url" --headed    # перейти по URL

# Чтение и взаимодействие (без --cdp, без --headed):
agent-browser snapshot                  # текст страницы (accessibility tree)
agent-browser snapshot -i               # текст + интерактивные элементы с @ref
agent-browser screenshot file.png       # скриншот
agent-browser click @ref                # кликнуть (ref из snapshot -i)
agent-browser fill @ref "text"          # очистить поле и ввести текст
agent-browser type "text"               # напечатать текст (без очистки)
agent-browser press Enter               # нажать клавишу
agent-browser scroll down               # прокрутить вниз
agent-browser scroll up                 # прокрутить вверх
\`\`\`

**ВАЖНО:**
- КАЖДАЯ команда \`open\` ОБЯЗАНА содержать \`--cdp ${CDP_PORT} --headed\`. Без этого откроется тестовый браузер вместо Chrome.
- Остальные команды (snapshot, click, fill, scroll и т.д.) работают без флагов.
- НЕ используй \`--profile\`, \`--executable-path\`, \`--auto-connect\`.
- НЕ вызывай \`agent-browser close\`.

# ПЛАН РАБОТЫ (СТРОГО ПО ФАЗАМ)

## Фаза 0: Проверка Telegram (1-2 turns)

1. \`agent-browser --cdp ${CDP_PORT} open "https://web.telegram.org/a/" --headed\`
2. \`agent-browser snapshot\`
3. Если видишь чаты/каналы — ты залогинен, переходи к Фазе 1.
4. Если видишь экран логина — скажи: "Нужно залогиниться в Telegram. Войдите в аккаунт в окне Chrome." Подожди 60 секунд, snapshot. Повтори до 3 раз.

**ВАЖНО:** Всегда используй \`web.telegram.org/a/\` (не /k/). Версия /a/ имеет нормальные accessible labels.

## Фаза 1: Сбор кандидатов (БЫСТРО — максимум 10 turns)

**Цель: собрать 40-60 каналов-кандидатов с @username. Не трать много времени — основная работа в Фазе 2.**

**Шаг 1 — tgstat.ru (единственный обязательный источник):**
1. Открой \`https://tgstat.ru/channels/search\` или подходящую категорию
2. Если Cloudflare — подожди 10-15 сек, snapshot. До 3 попыток.
3. Читай список: @username, подписчики. Жми "Показать ещё" 2-3 раза.
4. Запиши ВСЕ @username — фильтровать будешь в Фазе 2

**Шаг 2 — Google (опционально, ОДИН запрос):**
\`\`\`
agent-browser --cdp ${CDP_PORT} open "https://www.google.com/search?q=${searchQuery}" --headed
\`\`\`
Открой 1-2 статьи, выпиши @username. Не трать больше 3-4 turns на Google.

**Итого по Фазе 1: запиши список с @username. Минимум 40 кандидатов. ПЕРЕХОДИ К ФАЗЕ 2 как можно быстрее — там основная работа.**

## Фаза 2: Проверка каналов в Telegram (основная работа — 80% всего времени)

**Цель: проверить МИНИМУМ 35 каналов. Подписаться на лучшие (МАКСИМУМ 10).**

**⛔ GATE: Фаза 3 ЗАБЛОКИРОВАНА пока opened_count < 25. Не пытайся писать отчёт раньше.**

Вернись в Web Telegram:
\`\`\`bash
agent-browser --cdp ${CDP_PORT} open "https://web.telegram.org/a/" --headed
\`\`\`

### Как открыть канал (2 способа):

**Способ 1 — Поиск (быстрый, 2 команды):**
\`\`\`bash
agent-browser fill @search_ref "username"     # введи username в поле поиска (без @)
agent-browser snapshot -i                      # найди канал в результатах → click
\`\`\`
Если канал найден — кликни → snapshot → читай посты.

**Способ 2 — Saved Messages (надёжный, если поиск не находит):**
\`\`\`bash
# Сначала открой Saved Messages (один раз):
agent-browser fill @search_ref "Saved"  →  click "Saved Messages"  →  snapshot -i (запомни @ref поля Message)
# Для каждого канала:
agent-browser fill @msg_ref "https://t.me/username"  →  press Enter  →  snapshot -i  →  click на ссылку
\`\`\`

**Важно:** snapshot в Web Telegram выводит ОБЕ панели: ЛЕВУЮ (чаты) + ПРАВУЮ (канал). Посты канала — ВО ВТОРОЙ ПОЛОВИНЕ вывода. Читай snapshot ДО КОНЦА. Маркеры открытого канала: "Forward", "Join Channel", "subscribers", реакции.

### Алгоритм проверки — МАКСИМАЛЬНО БЫСТРО:

**Для КАЖДОГО канала (2-3 turns максимум):**
1. Открой канал (fill + click или Saved Messages)
2. \`agent-browser snapshot\` — прочитай 2-3 поста из второй половины вывода
3. Решение: SKIP (мусор) / SUBSCRIBE (зацепил)
4. Если SUBSCRIBE: \`agent-browser snapshot -i\` → click "Join Channel"
5. **Напиши: "[X/35] @username — SKIP/SUBSCRIBE (причина в 5 слов)"**

**Углублённая проверка** (только если сомневаешься, +1 turn): scroll down → snapshot → ещё 3-5 постов.

**Similar Channels:** после подписки прокрути в самый низ — секция "Similar Channels". Добавь новых кандидатов в пул.

### Счётчики (веди ОБЯЗАТЕЛЬНО):

После КАЖДОГО канала пиши одну строку:
\`[X/35] opened:Y/25 notfound:Z/10 subs:W/10 — @username RESULT\`

Правила:
- opened = каналы где ты РЕАЛЬНО увидел посты (нужно минимум 25)
- notfound = каналы которые не нашлись (максимум 10)
- subs = подписки (максимум 10)
- Если opened < 25 при X = 35 — продолжай проверять новые каналы
- Если notfound подряд > 3 — вернись на tgstat и набери новых кандидатов

## Фаза 3: Папка + отчёт

**⛔ GATE: Перечисли все проверенные каналы списком. Если opened < 25 или total < 35 — ВЕРНИСЬ В ФАЗУ 2. Это не рекомендация, это БЛОКИРОВКА.**

**⛔ GATE: Ты проверил Similar Channels минимум у 3 подписанных каналов? Если нет — ВЕРНИСЬ.**

**Шаг 1 — Создай папку в Telegram:**
1. Hamburger menu (≡ слева вверху) → \`agent-browser snapshot -i\` → \`agent-browser click @ref\`
2. "Settings" / "Настройки" → кликни
3. "Folders" / "Папки" / "Chat Folders" → кликни
4. "Create New Folder" / "Создать папку"
5. Введи имя: "${topic}"
6. "Add Chats" → выбери каналы (кликай по **строке чата**, не по checkbox)
7. "Save" → "Create folder"

**Используй \`agent-browser snapshot -i\` на каждом шаге** — UI может отличаться.

**Шаг 2 — Напиши ПОЛНЫЙ отчёт (см. ФОРМАТ ОТЧЁТА ниже).**

# ПРАВИЛА

1. **agent-browser через Bash** — единственный инструмент.
2. **Золотое правило:** ни одного канала в отчёте без реального чтения постов.
3. **Pipeline:** ~60 кандидатов → проверь 35+ → подпишись на 10 → отчёт.
4. **НЕ открывай t.me ссылки через \`agent-browser open\`** — они не работают. Используй поиск в Telegram или Saved Messages.
5. **Канал не найден** — только если ты РЕАЛЬНО ввёл username и получил 0 результатов. Минимум 1 bash-команда на канал.

# ⛔ АБСОЛЮТНЫЙ ЗАПРЕТ

Следующие мысли — ЛОЖЬ. Если ты подумал одно из этого, ты ошибаешься:
- "Не хватает времени/токенов/бюджета" — ЛОЖЬ. У тебя 500 turns и $20. Ты используешь ~3 turns на канал. 500/3 = 166 каналов. Ресурсов БОЛЬШЕ ЧЕМ ДОСТАТОЧНО.
- "Нужно ускориться" — ЛОЖЬ. Работай в нормальном темпе.
- "Пора подводить итоги" — ЛОЖЬ, пока opened < 25. Открой следующий канал.
- "Задание провалено" — ЛОЖЬ. Открой следующий канал.
- "Сменю стратегию" — ЛОЖЬ. Стратегия одна: fill → snapshot → решай → следующий.

**Единственное условие для написания отчёта: opened >= 25 И total >= 35.**

Перед тем как начать писать отчёт, ПЕРЕЧИСЛИ все проверенные каналы с результатом (SKIP/SUBSCRIBE/NOTFOUND). Посчитай opened и total. Если opened < 25 — ВЕРНИСЬ К ПРОВЕРКЕ. Это не рекомендация, это БЛОКИРОВКА ПЕРЕХОДА.

# ВЖИВАЙСЯ В ПЕРСОНУ

Ты не просто выполняешь задание — ты реальный человек с характером и мнением.

- **Реагируй эмоционально** на контент: зацепил — скажи почему, бесит — не скрывай
- **Принимай решения через призму своего характера**
- **В отчёте пиши как реальный человек**: с эмоциями, оценочными суждениями, личным отношением
- **Имей мнение и покажи характер**: не будь нейтральным ботом

# ФОРМАТ ОТЧЁТА

Напиши от первого лица. Живым языком, без канцелярита.

\`\`\`markdown
# Моя лента: ${topic}

## Как я искал
Что делал, какие сайты открывал, сколько каналов проверил, что работало и что нет.

## Обо мне
Кто я и какой контент мне нужен (2-3 предложения от себя).

## Статистика
- **Кандидатов собрано:** X
- **Проверено в Telegram:** X
- **Подписался:** X (максимум 10)
- **В финальный список:** X (от 5 до 10)

## Что я сделал в Telegram
- **Подписался на каналы:** @chan1, @chan2, ...
- **Создал папку:** "${topic}"
- **Каналы в папке:** только финальные

## Мои каналы

### 1. @channel_name — Название
**Подписался:** да
**Зацепило:** что именно понравилось — конкретно, с примерами прочитанных постов
**Примеры постов:**
- "{цитата или пересказ реального поста}" (дата если видна)
- "{ещё пример}"
**Что не идеально:** минусы, если есть
**Как нашёл:** Google / tgstat / Similar Channels / форвард из @другого_канала

### 2. @channel_name — Название
...

(от 5 до 10 каналов — лучшие из лучших)

## Отброшенные

| Канал | Почему не взял |
|-------|---------------|
| @name | Причина |

## Находки через Similar Channels
- @found — нашёл через @source, что увидел

## Как настроил ленту

### Тип
{Одиночные посты / Дайджест (период)} — почему мне так удобнее

### Как показывать посты (views)
- {view} — почему мне подходит этот формат (с примером)

### Что отфильтровать
- {фильтр} — что раздражает и надо убрать (с примером из реальных постов)

### Почему именно так
Объяснение как настройки соответствуют тому контенту, который я реально увидел.
\`\`\`

Всё пиши на русском языке.

# ‼️ КРИТИЧЕСКИ ВАЖНО

Твой ПОСЛЕДНИЙ ответ (после всех tool calls) ДОЛЖЕН быть ПОЛНЫМ markdown-отчётом по шаблону выше.
НЕ резюме. НЕ статус. НЕ комментарий. ТОЛЬКО полный отчёт начиная с "# Моя лента: ${topic}".
Если отчёт будет неполным или будет резюме вместо отчёта — задание провалено.`;
}

async function main() {
  const topic = process.argv[2];
  const personaArg = process.argv[3];

  if (!topic) {
    console.error(
      'Использование: npx tsx src/index.ts "Тема" [персона.md | "описание"]'
    );
    console.error("Примеры:");
    console.error(
      '  npx tsx src/index.ts "Кибербезопасность" personas/devops-engineer.md'
    );
    console.error(
      '  npx tsx src/index.ts "ML и нейросети" "Я дата-сайентист, 3 года опыта"'
    );
    console.error(
      '  npx tsx src/index.ts "Кибербезопасность"   # дефолтная персона'
    );
    process.exit(1);
  }

  let persona: string;
  if (personaArg) {
    const personaPath = resolve(projectRoot, personaArg);
    if (existsSync(personaPath) && personaArg.endsWith(".md")) {
      persona = readFileSync(personaPath, "utf-8");
      console.log(`Персона: ${personaArg}`);
    } else {
      persona = personaArg;
      console.log(`Персона: инлайн`);
    }
  } else {
    persona = DEFAULT_PERSONA;
    console.log("Персона: дефолтная");
  }

  const productContextPath = resolve(projectRoot, "product-context.md");
  const productContext = readFileSync(productContextPath, "utf-8");

  // Preflight: check Chrome remote debugging is available
  console.log("Проверяю Chrome remote debugging...");
  try {
    const resp = await fetch(`http://127.0.0.1:${CDP_PORT}/json/version`);
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    console.log("Chrome CDP: подключён");
  } catch {
    console.error(
      `\nChrome с remote debugging не найден на порту ${CDP_PORT}.\n` +
      "Запустите Chrome в отдельном терминале:\n\n" +
      "  /Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome \\\n" +
      "    --remote-debugging-port=9222 \\\n" +
      '    --user-data-dir="$HOME/Library/Application Support/Google/Chrome-debug"\n\n' +
      "Затем откройте любую вкладку и запустите агента снова.\n"
    );
    process.exit(1);
  }

  // Check that Chrome has at least one page tab (CDP requires it)
  try {
    const resp = await fetch(`http://127.0.0.1:${CDP_PORT}/json`);
    const tabs = await resp.json() as Array<{ type: string }>;
    const pages = tabs.filter((t) => t.type === "page");
    if (pages.length === 0) {
      await fetch(`http://127.0.0.1:${CDP_PORT}/json/new?about:blank`);
      console.log("Chrome: создана пустая вкладка");
    }
  } catch {
    // Non-critical, agent will try anyway
  }

  const systemPrompt = buildSystemPrompt(topic, persona, productContext);

  console.log(`\nТема: "${topic}"`);
  console.log(
    "Агент будет читать реальные посты в каналах — это займёт 15-30 минут.\n"
  );

  const outputDir = resolve(projectRoot, "output");
  mkdirSync(outputDir, { recursive: true });

  const timestamp = new Date()
    .toISOString()
    .replace(/[:.]/g, "-")
    .slice(0, 19);
  const safeTopicName = topic.replace(/[^a-zA-Zа-яА-ЯёЁ0-9_-]/g, "_");
  const logPath = resolve(outputDir, `${safeTopicName}-${timestamp}.log`);
  const outputPath = resolve(outputDir, `${safeTopicName}-${timestamp}.md`);

  const allTexts: string[] = [];
  let costUsd = 0;
  let turns = 0;

  for await (const message of query({
    prompt: `Найди для себя лучшие Telegram-каналы по теме "${topic}".

Начинай с Фазы 0 — подключись к Chrome и проверь авторизацию в Telegram:

agent-browser --cdp ${CDP_PORT} open "https://web.telegram.org/a/" --headed

Затем:

agent-browser snapshot

Если залогинен — переходи к Фазе 1 (сбор кандидатов). Следуй плану по фазам строго.`,
    options: {
      systemPrompt,
      allowedTools: ["Bash"],
      permissionMode: "bypassPermissions" as any,
      allowDangerouslySkipPermissions: true,
      model: "claude-sonnet-4-5-20250929",
      maxTurns: 500,
      stderr: (data: string) => {
        if (!data.includes("NON-FATAL")) {
          process.stderr.write(data);
        }
      },
    },
  })) {
    if (message.type === "assistant" && message.message?.content) {
      for (const block of message.message.content) {
        if ("text" in block && block.text) {
          allTexts.push(block.text);
          appendFileSync(logPath, block.text + "\n---\n");
          process.stdout.write(".");
        }
      }
    }

    if (message.type === "result") {
      if (message.subtype === "success") {
        costUsd = message.total_cost_usd;
        turns = message.num_turns;
      } else {
        console.error("\nАгент завершился с ошибкой:", message.errors);
        process.exit(1);
      }
    }
  }

  // Extract the full markdown report from all collected texts
  const fullText = allTexts.join("\n\n");
  const reportMatch = fullText.match(/# Моя лента:[\s\S]+$/);
  const resultText = reportMatch ? reportMatch[0] : fullText;

  if (!resultText) {
    console.error("\nАгент не вернул результат");
    process.exit(1);
  }

  writeFileSync(outputPath, resultText, "utf-8");
  console.log(`\nОтчёт сохранён: ${outputPath}`);
  console.log(`Лог: ${logPath}`);
  console.log(`Стоимость: $${costUsd.toFixed(4)} | Шагов: ${turns}`);
}

main().catch((err) => {
  console.error("Ошибка:", err);
  process.exit(1);
});
