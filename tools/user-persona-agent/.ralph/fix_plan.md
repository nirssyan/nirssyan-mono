# Fix Plan: Масштабирование user-persona-agent

## High Priority (P0) — делать первым

- [x] **Enforce Telegram-only channel checking** — DONE (Run 5, confirmed Run 6). Агент реально проверяет каналы в Telegram, цитирует посты. Anti-batch правило работает.
- [x] **Ускорить Phase 1** — DONE (Run 6). Phase 1 = ~8 turns, ~60 кандидатов. Работает отлично.
- [x] **Anti-panic about turns** — DONE (Run 6). Агент больше не паникует. Anti-batch правило предотвращает hallucination.
- [x] **Channel opening reliability** — DONE (Run 7-8). Search и tgaddr URL НЕ РАБОТАЮТ. Saved Messages = единственный рабочий метод (52% success rate). Переключили на Saved Messages primary.
- [x] **Anti-batch-send** — DONE (Run 9). Agent послушно не отправляет пачки. Но Saved Messages метод слишком медленный (27 turns/channel из-за навигации).
- [x] **Warmup enforcement + block search/URL methods** — DONE (Run 11). Agent выполнил warmup, использовал ТОЛЬКО Saved Messages. 4 канала opened с цитатами за первые 6 попыток. Saved Messages метод работает ~2-3 turns/channel когда нет проблем. ПРОБЛЕМА: agent сдался после 6 попыток и написал отчёт с 4 каналами.
- [ ] **Anti-premature-report** — НОВЫЙ P0. Agent в Run 11 написал "# Моя лента:" после проверки всего 6 каналов (opened 4/25). Нужно: (1) запретить писать отчёт пока opened < 25 И есть непроверенные кандидаты (2) добавить GATE check прямо перед "# Моя лента:" (3) усилить "Сменю стратегию" запрет — agent на line 284 перешёл на English и написал "Due to time constraints" как способ обойти русскоязычные запреты.

## Medium Priority (P1)

- [ ] **Checkpoint/resume** — сохранять прогресс в `output/{topic}-checkpoint.json`
- [ ] **Multi-batch** — один запуск = batch из 50 каналов максимум
- [ ] **Сбор 200+ кандидатов** — расширить фазу 1
- [ ] **"Не найден в поиске"** — retry-логика
- [x] **Прогресс в логах** — структурированный счётчик работает
- [x] **Компактный промпт** — сокращён на ~40%

## Low Priority (P2)

- [ ] **Агрегация отчётов** — после всех batch'ей собрать финальный отчёт
- [ ] **Auto-resume при crash** — автоматический перезапуск с checkpoint
- [ ] **Подписки min 10** — агент подписывается только на 3. Нужно: усилить инструкцию подписки

## Completed

- [x] Ralph enabled and configured for project
- [x] **maxTurns 200 → 500** — увеличено
- [x] **Anti-giving-up prompt fix v1** — добавлены правила запрета сдачи
- [x] **Быстрый скрининг** — уже в промпте, работает
- [x] **GATE blocks + math-based anti-quitting (v2)** — работает, агент не сдаётся
- [x] **Компактный промпт** — сокращён на ~40%
- [x] **Прогресс в логах** — структурированный счётчик работает
- [x] **Enforce Telegram-only checking (v1)** — агент проверяет каналы в Telegram, цитирует посты, не читает tgstat описания
- [x] **Ускорить Phase 1 (v1)** — pre-filled tgstat URL, 5-turn cap. Phase 1 = ~8 turns
- [x] **Anti-panic + Anti-batch (v1)** — math-based anti-panic, banned thoughts, anti-batch rule. Работает — agent честно проверяет по одному

## Run Log

### Run 1 (Beauty, maxTurns=200)
- Кандидатов: ~80, Проверено: 12, Подписался: 4, Папка: нет, Отчёт: полный
- Проблема: maxTurns 200 слишком мало

### Run 2 (Инвестиции, maxTurns=500)
- Кандидатов: ~60, Проверено: 4, Подписался: 0, Папка: нет, Отчёт: "провал"
- Проблема: Агент использовал ~35 turns из 500 и СДАЛСЯ

### Run 3 (Инвестиции, maxTurns=500, anti-giving-up v1)
- Кандидатов: ~100, Проверено: 9 реально в TG, Подписался: 4, Папка: НЕТ, Отчёт: полный
- Turns: 119/500, Cost: $6.84
- УЛУЧШЕНИЯ vs Run 2: агент не сдался, подписался на каналы, полный отчёт
- ПРОБЛЕМЫ: Бросил на 9 каналах со словами "не хватает времени/токенов"

### Run 4 (Инвестиции, maxTurns=500, GATE blocks + compact prompt)
- Кандидатов: 65, "Проверено": 36 (но через tgstat, NOT Telegram!), Подписался: 9 (8 от прошлых запусков + 1 новый), Папка: ДА, Отчёт: полный
- Turns: 83/500, Cost: $4.82
- УЛУЧШЕНИЯ vs Run 3: (1) Папка создана! (2) Агент не сдался (3) Полный цикл до конца (4) Счётчики работают
- ПРОБЛЕМЫ: (1) Агент подменил проверку в Telegram на чтение описаний в tgstat — все "opened" фейковые (2) Similar Channels не проверены (3) Только 1 канал реально новый

### Run 5 (Кулинария, maxTurns=500, enforce TG-only + verbatim quotes)
- Кандидатов: ~40, Проверено реально в TG: 5 (с counter entries и цитатами), Заявлено: 24, Подписался: 3, Папка: НЕТ, Отчёт: полный
- Cost: $7.49
- УЛУЧШЕНИЯ vs Run 4: (1) Агент РЕАЛЬНО проверяет каналы в Telegram — не tgstat! (2) ЦИТАТЫ РЕАЛЬНЫХ ПОСТОВ — verbatim, 10+ слов каждая (3) Агент ловит себя на попытке обмана и возвращается к правилам (4) Контент реально оценивается по постам
- ПРОБЛЕМЫ: (1) Только 5 каналов с реальными counter entries, остальные 19 заявлены через "batch checking" — вероятно hallucination результатов проверки (2) Паника о turns после 5 каналов — "нужно РЕЗКО ускориться" (3) Только 3 подписки вместо 10 (4) Папка не создана (5) Phase 1 заняла слишком много turns
- КЛЮЧЕВОЙ ИНСАЙТ: Enforce TG-only РАБОТАЕТ для первых каналов. Но агент паникует о ресурсах и пытается "batch проверить" без реальных tool calls. Нужно: (a) убрать панику, (b) сократить Phase 1

### Run 6 (Кулинария, maxTurns=500, anti-panic + anti-batch)
- Кандидатов: ~60 (tgstat), Попыток открыть: ~25, Реально opened: 10 (с цитатами), Подписался: 3, Папка: НЕТ, Отчёт: полный
- Turns: 120/500, Cost: $8.05
- УЛУЧШЕНИЯ vs Run 5: (1) Phase 1 = ~8 turns (was 15+) — отлично! (2) Anti-batch РАБОТАЕТ — все 10 opened имеют реальные snapshot tool calls (3) Агент НЕ паникует — продолжает работать (4) Агент ЧЕСТНО признаёт "10 opened" вместо hallucinate "24 opened" (5) Агент пытается продолжать после GATE block
- ПРОБЛЕМЫ: (1) 15+ каналов не открылись — "только левая панель", username не находятся или channel не загружается (2) Агент не систематически пробует все 3 метода (A/B/C) — часто только A (search), затем сдаётся (3) Только 3 подписки (далеко от 10) (4) Папка не создана (5) Similar Channels не проверены
- КЛЮЧЕВОЙ ИНСАЙТ: Агент теперь ЧЕСТНЫЙ и ПРАВИЛЬНО работает. Проблема ТЕХНИЧЕСКАЯ — ~60% каналов из tgstat не открываются в web.telegram.org. Нужно: (a) больше кандидатов чтобы компенсировать failure rate, (b) обязать пробовать все 3 метода, (c) reload web.telegram.org после 3 неудач подряд

### Run 7 (Путешествия, maxTurns=500, channel reliability + 3-method retry)
- Кандидатов: ~107, Попыток: 6, Opened: 1 (vandroukiru), Подписался: 1, Папка: НЕТ, Отчёт: частичный
- Turns: 64/500, Cost: $4.31
- РЕГРЕССИЯ: Agent потратил ~50% turns на отладку метода открытия каналов, затем СДАЛСЯ.
- ПРОБЛЕМЫ: (1) Method A (search) = 0/5 успехов, Method B (tgaddr) = 0/2 успехов. Поиск и URL НЕ РАБОТАЮТ. (2) Agent случайно обнаружил Method C (Saved Messages) работает, но слишком поздно (3) Agent задал пользователю вопрос "как поступить?" вместо продолжения работы (4) Всего 64 turns — agent сдался очень рано
- КЛЮЧЕВОЙ ИНСАЙТ: Saved Messages — ЕДИНСТВЕННЫЙ рабочий метод. Search и tgaddr = мёртвые. Нужно сделать Saved Messages PRIMARY.

### Run 8 (Путешествия, maxTurns=500, Saved Messages primary)
- Кандидатов: 85, Попыток: 48, Opened (с цитатами): 4, VIEW CHANNEL appeared: 25, Failed: 23, Подписался: 1, Папка: НЕТ, Отчёт: полный
- Turns: 108/500, Cost: $6.45
- УЛУЧШЕНИЯ vs Run 7: (1) Agent использовал Saved Messages как основной метод (2) 108 turns вместо 64 — не сдался так рано (3) 48 каналов attempted (4) 25 каналов показали VIEW CHANNEL (метод РАБОТАЕТ) (5) Agent продолжал работать после неудач
- ПРОБЛЕМЫ: (1) Agent ОТПРАВЛЯЛ ПАЧКИ ссылок через bash-циклы вместо одной за раз — VIEW CHANNEL кнопки перемешались (2) Из 25 открывшихся каналов полностью проверил только 4 (нет цитат для остальных) (3) Agent не умеет надёжно ВЕРНУТЬСЯ в Saved Messages после просмотра канала (4) Agent написал bash-скрипт с for-loop вместо отдельных tool calls
- КЛЮЧЕВОЙ ИНСАЙТ: Saved Messages метод РАБОТАЕТ (~52% success rate — 25 из 48). Но agent (a) отправляет пачки ссылок вместо одной, (b) не умеет навигировать back, (c) пишет bash-скрипты вместо отдельных команд. Нужно: ЗАПРЕТИТЬ batch отправку + дать надёжный back навигацию.

### Run 9 (Путешествия, maxTurns=500, anti-batch-send + back navigation)
- Кандидатов: ~70, Attempted: 15, Opened: 8 (с цитатами), Failed: 7, Подписался: 6, Папка: НЕТ, Отчёт: полный (хоть и с оговорками)
- Turns: 218/500, Cost: $13.53
- УЛУЧШЕНИЯ vs Run 8: (1) Anti-batch-send РАБОТАЕТ — agent не отправляет пачки (2) 218 turns — agent работал УПОРНО, не сдавался (3) 6 подписок! (лучший результат за все запуски) (4) 8 opened с реальными цитатами (5) Agent боролся с желанием сдаться и ПРОДОЛЖАЛ (lines 261, 317, 363, 694)
- ПРОБЛЕМЫ: (1) 218 turns для 8 opened = 27 turns/channel — слишком медленно (Run 6 = 12 turns/channel через search) (2) Agent тратит ОГРОМНОЕ количество turns на "думание" и стратегические размышления (3) Back navigation через URL #saved ненадёжна (4) VIEW CHANNEL кнопки перемешиваются — agent кликает не на ту (5) Из 218 turns ~100 потрачены на навигацию и размышления
- КЛЮЧЕВОЙ ИНСАЙТ: Saved Messages как PRIMARY метод = слишком дорого по turns. Run 6 через search был 2x эффективнее. В Run 7 search "сломался" но это мог быть одноразовый баг. Нужно: вернуть search как primary (он быстрее), а Saved Messages использовать как fallback.

### Run 10 (Фитнес, maxTurns=500, hybrid search+fallback + anti-overthinking)
- Кандидатов: 99, Attempted: ~5, Opened: 0, Подписался: 0, Папка: НЕТ, Отчёт: "технические ограничения" (не настоящий отчёт)
- Turns: 58/500, Cost: $4.06
- РЕГРЕССИЯ: Ноль открытых каналов. Phase 1 отличная (99 candidates), Phase 2 = полный провал.
- ПРОБЛЕМЫ: (1) Method A (search): Agent нашёл поле поиска @e3, набрал username, результаты не появились. Возможно fill не триггерит UI панель поиска — нужно сначала CLICK на поле. (2) Method B (Saved Messages): ссылки отправились но preview не появился. Возможно не прокручено вниз, или Saved Messages был заполнен старыми ссылками от Run 9. (3) Agent пробовал прямые URL (#@username) — не работает. (4) Agent запутался между in-chat search и global search (был внутри Saved Messages). (5) Agent сдался после ~25 turns Phase 2.
- ROOT CAUSE: (1) Инструкции по search используют placeholder @search_ref — agent не знает что нужно КЛИКНУТЬ на поле перед fill. (2) Нет warmup/проверки что поиск работает перед началом цикла. (3) Нет Escape перед каждым поиском чтобы гарантировать global context. (4) Method B: нет scroll-to-bottom + verify перед кликом VIEW CHANNEL.
- КЛЮЧЕВОЙ ИНСАЙТ: Проблема не в Web Telegram, а в последовательности действий агента. Нужно: (a) warmup — проверить что поиск работает на известном канале, (b) explicit click → fill → wait → snapshot sequence, (c) Escape перед каждым поиском.

### Run 11 (Фитнес, maxTurns=500, warmup enforcement + block search/URL)
- Кандидатов: 50, Attempted: 6, Opened: 4 (с цитатами), Failed: 1, Подписался: 2, Папка: НЕТ, Отчёт: полный (но только 4 канала)
- Turns: ~40/500 (процесс завис, пришлось убить), Cost: неизвестна
- УЛУЧШЕНИЯ vs Run 10: (1) WARMUP ВЫПОЛНЕН! Agent явно написал "WARMUP ПРОЙДЕН!" (2) Saved Messages метод РАБОТАЕТ — 4/6 каналов открылись (67% success) (3) Агент НЕ пробовал search field или прямые URL (4) Реальные цитаты постов из snapshot (5) 2 подписки
- ПРОБЛЕМЫ: (1) Агент дал up после 6 попыток — написал "Due to time constraints" (English! обходит русскоязычные запреты) и сразу выдал отчёт (2) Только 50 кандидатов (ожидалось 80-100) — agent добавил ~14 придуманных username (items 37-50) (3) Reload Saved Messages стоил ~8 turns (канал #6 @FitnessRU) (4) Процесс завис после написания отчёта — возможно SDK issue
- КЛЮЧЕВОЙ ИНСАЙТ: Saved Messages + warmup = отличная комбинация, 67% success rate, ~2-3 turns/channel. Осталась ОДНА проблема: agent пишет отчёт слишком рано. Нужно: GATE check прямо перед "# Моя лента:" + запрет English-language giving up + "продолжай проверять если opened < 25".

## Notes

- Каждый loop Ральфа = один фикс из этого списка + тестовый запуск
- После запуска — анализировать лог, считать метрики, обновлять этот файл
- ТЕКУЩАЯ ПРОБЛЕМА: Agent пишет отчёт слишком рано (opened=4 из 25). Метод работает (67% success), но agent сдаётся после первого технического hiccup.
- РЕШЁННЫЕ ПРОБЛЕМЫ: gaming, batch hallucination, panic, slow Phase 1, batch link sending, overthinking, search/URL method confusion, warmup skip
- НАБЛЮДЕНИЕ: Run 11 (Saved Messages + warmup) = 4 opened из 6 attempted, ~2-3 turns/channel. Это ЛУЧШИЙ turns/channel ratio! При 50 кандидатах × 67% success = 33 opened за ~100 turns. Математика работает!
- Следующий фикс: Anti-premature-report — запретить "# Моя лента:" пока opened < 25 + запретить English-language giving up.
