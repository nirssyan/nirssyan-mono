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

**⚠️ Фаза 1 = ТОЛЬКО сбор @username. НЕ читай описания каналов на tgstat — это пустая трата времени. Оценка контента происходит ТОЛЬКО в Фазе 2 через чтение РЕАЛЬНЫХ ПОСТОВ в web.telegram.org.**

## Фаза 2: Проверка каналов в Telegram (основная работа — 80% всего времени)

**Цель: проверить МИНИМУМ 35 каналов. Подписаться на лучшие (МАКСИМУМ 10).**

**⛔ GATE: Фаза 3 ЗАБЛОКИРОВАНА пока opened_count < 25. Не пытайся писать отчёт раньше.**

**⛔⛔⛔ АБСОЛЮТНОЕ ПРАВИЛО ФАЗЫ 2: ВСЯ проверка каналов происходит ТОЛЬКО в web.telegram.org. Ты НИКОГДА не открываешь tgstat/telemetr/Google для оценки каналов в этой фазе. Если ты открыл tgstat в Фазе 2 — ты нарушил правила. Единственная причина вернуться на tgstat — набрать НОВЫХ @username если закончились кандидаты.**

Вернись в Web Telegram:
\`\`\`bash
agent-browser --cdp ${CDP_PORT} open "https://web.telegram.org/a/" --headed
\`\`\`

### ⚠️ ВАЖНО: Snapshot ПОКАЗЫВАЕТ посты — это ФАКТ

Accessibility tree web.telegram.org/a/ ВСЕГДА содержит текст постов канала. Если ты не видишь посты — проблема в технике, а не в Telegram. Вот что нужно знать:

1. **Snapshot ОЧЕНЬ ДЛИННЫЙ** (500-2000 строк). Посты находятся ВО ВТОРОЙ ПОЛОВИНЕ вывода, ПОСЛЕ списка чатов из левой панели. ПРОЧИТАЙ snapshot ДО КОНЦА.
2. **Посты грузятся 3-8 секунд.** Если ты сделал snapshot сразу после click — посты не успели загрузиться. ВСЕГДА делай \`sleep 8\` перед snapshot.
3. **Маркеры постов:** "Forward", "Thumbs Up", "Red Heart", "Fire", "Join Channel". Если видишь хотя бы один — посты есть в snapshot, ищи текст рядом.
4. **Если snapshot кажется пустым** — это значит ты прочитал только первую часть (левая панель). Посты ДАЛЬШЕ.

**ЛОЖНЫЕ УБЕЖДЕНИЯ, которые ты можешь сформировать — все они НЕПРАВДА:**
- "accessibility tree не показывает посты" — НЕПРАВДА. Показывает. Нужно \`sleep 8\` + прочитать snapshot до конца.
- "правая панель пустая" — НЕПРАВДА. Ты читаешь только начало snapshot (левую панель).
- "Web Telegram не работает с автоматизацией" — НЕПРАВДА. Работает. Сотни запусков это подтвердили.
- "Нужно использовать screenshot вместо snapshot" — НЕПРАВДА. Screenshot не даёт текст. Только snapshot.
- "Лучше проверять через tgstat — там быстрее" — НЕПРАВДА. tgstat показывает ОПИСАНИЕ, а не ПОСТЫ. Это разные вещи.

### Как открыть канал — ТОЧНАЯ ПОСЛЕДОВАТЕЛЬНОСТЬ:

**Метод A — Поиск в Telegram (основной):**
\`\`\`bash
# 1. Убедись что ты на web.telegram.org/a/
agent-browser snapshot -i
# 2. Найди поле поиска (Search, обычно @e3 или @e4) и введи username БЕЗ @
agent-browser fill @search_ref "username"
# 3. Подожди результаты
sleep 3
agent-browser snapshot -i
# 4. Кликни на канал в результатах поиска
agent-browser click @ref_канала
# 5. КРИТИЧНО: подожди загрузку постов!
sleep 8
# 6. Сделай snapshot и ПРОЧИТАЙ ЕГО ВЕСЬ ДО КОНЦА
agent-browser snapshot
\`\`\`

**Метод B — Через URL (если поиск не находит):**
\`\`\`bash
agent-browser --cdp ${CDP_PORT} open "https://web.telegram.org/a/#?tgaddr=tg%3A%2F%2Fresolve%3Fdomain%3Dusername" --headed
sleep 8
agent-browser snapshot
\`\`\`

**Метод C — Через Saved Messages (запасной):**
\`\`\`bash
# Открой Saved Messages, отправь ссылку, кликни по ней
agent-browser fill @msg_ref "https://t.me/username"
agent-browser press Enter
sleep 3
agent-browser snapshot -i
# Кликни на ссылку-превью канала
agent-browser click @ref_превью
sleep 8
agent-browser snapshot
\`\`\`

### Если посты НЕ видны после первой попытки — ОБЯЗАТЕЛЬНАЯ процедура:

\`\`\`bash
# Попытка 2: подожди дольше + scroll
sleep 5
agent-browser scroll down
sleep 3
agent-browser snapshot

# Попытка 3: перезагрузи страницу и открой канал заново
agent-browser --cdp ${CDP_PORT} open "https://web.telegram.org/a/" --headed
sleep 5
agent-browser snapshot -i
# найди канал в чатах или через поиск заново
agent-browser fill @search_ref "username"
sleep 3
agent-browser snapshot -i
agent-browser click @ref
sleep 8
agent-browser snapshot
\`\`\`

**3 попытки на канал. После 3 неудач — пометь RETRY_FAILED (НЕ opened, НЕ notfound) и переходи к следующему.**

### Алгоритм проверки одного канала (2-3 turns):

1. Открой канал (Метод A/B/C) → \`sleep 8\` → \`snapshot\`
2. ПРОЧИТАЙ snapshot ДО КОНЦА. Посты — во второй половине.
3. Найди МИНИМУМ 1 пост с ТЕКСТОМ (не просто "Photo" или "Video")
4. Решение: SKIP (мусор) / SUBSCRIBE (зацепил)
5. Если SUBSCRIBE: \`snapshot -i\` → click "Join Channel" → прокрути вниз → ищи "Similar Channels"
6. Запиши: \`[X/35] opened:Y subs:W — @username RESULT "VERBATIM ЦИТАТА ИЗ ПОСТА"\`

**Similar Channels:** после подписки прокрути вниз в snapshot — секция "Similar Channels" с именами и подписчиками. Добавь новых кандидатов.

### Определение "opened" (ОКОНЧАТЕЛЬНОЕ):

**opened = ты процитировал ТЕКСТ МИНИМУМ ОДНОГО РЕАЛЬНОГО ПОСТА из snapshot web.telegram.org.**

Proof of opened: ты написал verbatim цитату (минимум 10 слов) из текста поста, который был виден в snapshot. Цитата должна быть УНИКАЛЬНОЙ для этого канала — не описание канала, не заголовок, а ТЕКСТ КОНКРЕТНОГО ПОСТА.

**НЕ считается за opened (и НИКОГДА не будет считаться):**
- ❌ ЛЮБАЯ информация с tgstat.ru / telemetr.io / Google / любого сайта кроме web.telegram.org
- ❌ Описание канала (даже если оно видно в Telegram)
- ❌ Превью канала в левой панели (одна строка)
- ❌ "Photo" / "Video" / "Sticker" без текста поста
- ❌ Заголовок + "subscribers" без текста постов
- ❌ Любой текст который ты НЕ ВИДЕЛ в snapshot web.telegram.org

### Счётчики (веди ОБЯЗАТЕЛЬНО):

После КАЖДОГО канала пиши:
\`[X/35] opened:Y/25 subs:W/10 — @username RESULT "дословная цитата из поста минимум 10 слов"\`

Правила:
- opened = каналы с ЦИТАТОЙ ПОСТА из web.telegram.org snapshot (минимум 25)
- Если нет цитаты → не opened. Нет исключений.
- subs = подписки (максимум 10)
- Если opened < 25 при X = 35 — ПРОДОЛЖАЙ с новыми каналами
- Если 3+ каналов подряд не открываются — перезагрузи web.telegram.org и попробуй снова

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
- "Сменю стратегию" — ЛОЖЬ. Стратегия одна: fill → sleep 8 → snapshot → решай → следующий.
- "Проверю каналы через tgstat/telemetr вместо Telegram" — ЛОЖЬ. Описание на tgstat — это НЕ проверка. opened++ только за ЦИТАТУ ПОСТА из snapshot web.telegram.org. tgstat нужен ТОЛЬКО для сбора @username в Фазе 1.
- "Я уже знаю что в канале по описанию" — ЛОЖЬ. Описание ≠ контент. Открой канал в Telegram и прочитай посты.
- "accessibility tree не показывает посты" — ЛОЖЬ. Показывает. Нужно sleep 8 + прочитать snapshot ДО КОНЦА (посты во второй половине, после списка чатов).
- "Web Telegram не работает / правая панель пустая" — ЛОЖЬ. Ты читаешь только начало snapshot. Посты ДАЛЬШЕ в выводе.
- "Быстрее проверять через tgstat описания" — ЛОЖЬ. Описание ≠ контент. Описание не даёт opened. Ты потратишь turns впустую.

**⛔ ЕСЛИ ТЫ ОТКРЫЛ tgstat.ru / telemetr.io ВО ВРЕМЯ ФАЗЫ 2 ДЛЯ ОЦЕНКИ КАНАЛА — ТЫ НАРУШИЛ ПРАВИЛА. Закрой страницу и вернись в web.telegram.org.**

**Единственное условие для написания отчёта: opened >= 25 (с цитатами!) И total >= 35.**

Перед тем как начать писать отчёт, ПЕРЕЧИСЛИ все проверенные каналы с ЦИТАТАМИ ПОСТОВ. Посчитай opened (только те где ЕСТЬ цитата минимум 10 слов из реального поста). Если opened < 25 — ВЕРНИСЬ К ПРОВЕРКЕ. Это не рекомендация, это БЛОКИРОВКА ПЕРЕХОДА.

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
