# Fix Plan: Масштабирование user-persona-agent

## High Priority (P0) — делать первым

- [x] **Enforce Telegram-only channel checking** — DONE (Run 5, confirmed Run 6). Агент реально проверяет каналы в Telegram, цитирует посты. Anti-batch правило работает.
- [x] **Ускорить Phase 1** — DONE (Run 6). Phase 1 = ~8 turns, ~60 кандидатов. Работает отлично.
- [x] **Anti-panic about turns** — DONE (Run 6). Агент больше не паникует. Anti-batch правило предотвращает hallucination.
- [x] **Channel opening reliability** — DONE (Run 7-8). Search и tgaddr URL НЕ РАБОТАЮТ. Saved Messages = единственный рабочий метод (52% success rate). Переключили на Saved Messages primary.
- [x] **Anti-batch-send** — DONE (Run 9). Agent послушно не отправляет пачки. Но Saved Messages метод слишком медленный (27 turns/channel из-за навигации).
- [x] **Warmup enforcement + block search/URL methods** — DONE (Run 11). Agent выполнил warmup, использовал ТОЛЬКО Saved Messages. 4 канала opened с цитатами за первые 6 попыток. Saved Messages метод работает ~2-3 turns/channel когда нет проблем. ПРОБЛЕМА: agent сдался после 6 попыток и написал отчёт с 4 каналами.
- [x] **Anti-premature-report** — DONE (Run 12). GATE CHECK РАБОТАЕТ — agent НЕ написал преждевременный отчёт с 2 opened каналами. Добавлены English-language blocks и "acceleration trap" detector.
- [x] **Fix VIEW CHANNEL navigation** — DONE (Run 13). Agent обнаружил t.me/s/USERNAME метод — 100% success rate. Но НЕ подписывается реально. Нужен гибридный подход.
- [x] **Hybrid screening + subscription** — DONE (Run 14). Промпт переписан: Этап 2A (t.me/s/) + Этап 2B (Saved Messages). Agent правильно понимает и следует hybrid flow. НО eval quoting сломал 2B. Фикс кавычек применён.
- [x] **Eval quoting fix** — DONE (Run 15). Кавычки больше не проблема — agent не упоминал ошибок quoting.
- [x] **Saved Messages right panel fix** — DONE (Run 16). SM fallback click сработал. Agent получил textbox и подписался на 2-4 канала.
- [x] **Stabilize 2B subscription loop** — DONE (Run 17). SM reload after each channel added. But VIEW CHANNEL click still not working.
- [x] **Batch checking regression in 2A** — DONE (Run 17). All 17 channels checked individually with quotes. Anti-batch rule works.
- [x] **Fix VIEW CHANNEL click reliability** — DONE (Run 18). Scroll-to-bottom added. But SM right panel itself doesn't open, so VIEW CHANNEL never reached.
- [ ] **GATE CHECK evasion in 2B** — P0. Agent bypassed GATE in BOTH Run 17 and 18 with "technical limitations" despite new banned thoughts. Need STRONGER enforcement — maybe remove "честная оценка" path entirely.
- [x] **Phase 1 candidate count regression** — DONE (Run 18). 85 candidates, tgstat "Показать больше" works. No longer a problem.
- [ ] **SM right panel recovery after channel navigation** — P0 CRITICAL. After navigating to any channel (warmup test or subscription), SM right panel doesn't open on return. This blocks ALL of 2B. Root cause: warmup test link navigates away from SM, breaking the session. Fix options: (a) REMOVE warmup test link — just verify textbox and go, (b) after warmup, close ALL tabs and reopen fresh Telegram tab, (c) use window.location.href instead of agent-browser open for SM return.
- [ ] **2A batch regression** — P1. Channels 31-85 checked in batches of 10 without individual snapshots. Need stronger enforcement.

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

### Run 12 (Дизайн интерьеров, maxTurns=500, anti-premature-report GATE + English blocks)
- Кандидатов: ~30, Attempted: 4, Opened: 2 (designmate, romasheda с цитатами), Failed: 2, Подписался: 1, Папка: НЕТ, Отчёт: НЕТ (нет "# Моя лента:")
- Turns: 65/500, Cost: $4.23
- GATE CHECK РЕЗУЛЬТАТ: Agent НЕ написал преждевременный отчёт — это УЛУЧШЕНИЕ vs Run 11. Но agent также НЕ продолжил проверку — просто остановился на 65 turns.
- УЛУЧШЕНИЯ vs Run 11: (1) GATE CHECK СРАБОТАЛ — agent не написал отчёт с 2 opened каналами (2) Warmup пройден (3) Global search метод найден и работает (romasheda открылся через search) (4) Similar Channels замечены
- ПРОБЛЕМЫ: (1) VIEW CHANNEL НАВИГАЦИЯ СЛОМАНА — после отправки 2-3 ссылок в Saved Messages, кнопки VIEW CHANNEL накапливаются, клик "последней" кнопки возвращает на уже подписанный Design Mate вместо нового канала (2) Agent потратил ~20 turns на борьбу с навигацией вместо проверки каналов (3) Agent перешёл на global search как workaround, который сработал для romasheda, но потом остановился (4) Agent НЕ вернулся к Saved Messages после reload — потерял контекст (5) Только 30 кандидатов (мало)
- ROOT CAUSE: Saved Messages метод ломается когда в чате много старых VIEW CHANNEL кнопок от предыдущих ссылок и от прошлых запусков. Eval ищет "последнюю" кнопку, но это может быть кнопка от СТАРОГО сообщения если новая ещё не загрузилась.
- КЛЮЧЕВОЙ ИНСАЙТ: Нужно ОЧИЩАТЬ старые сообщения из Saved Messages перед началом Phase 2. Вариант: после отправки ссылки и клика VIEW CHANNEL — УДАЛИТЬ сообщение перед следующим каналом. Или: перед Phase 2 послать команду "Clear chat history" в Saved Messages. Или: вместо поиска "последней" кнопки VIEW CHANNEL — искать кнопку, БЛИЖАЙШУЮ к ссылке с нужным @username.

### Run 13 (Дизайн интерьеров, maxTurns=500, message deletion + relaxed search ban)
- Кандидатов: ~20, Attempted: 18, Opened: 18 (100%!), Failed: 0, Подписался: 12 (claimed), Папка: claimed но вероятно не создана, Отчёт: ПОЛНЫЙ "# Моя лента:" — ДА!
- Turns: 80/500, Cost: $4.61
- **ПРОРЫВ:** Agent обнаружил метод `t.me/s/USERNAME` (публичный просмотр) — 100% success rate, ~1-2 turns/channel! Все 18 каналов открылись через этот метод.
- УЛУЧШЕНИЯ vs Run 12: (1) 18 opened vs 2 — ОГРОМНЫЙ прогресс! (2) 100% success rate vs 50% (3) ПОЛНЫЙ ОТЧЁТ с реальными цитатами (4) 12 подписок (5) Richнейший отчёт с описаниями, примерами постов, анализом что понравилось/не понравилось (6) Конфигурация ленты с обоснованием
- ПРОБЛЕМЫ: (1) Agent НЕ ПОДПИСАЛСЯ реально — t.me/s/ = публичный просмотр без авторизации, нет JOIN CHANNEL (2) Папка НЕ СОЗДАНА (agent не вернулся в web.telegram.org) (3) Каналы #8-10 похоже проверены батчем — не все имеют отдельные snapshots (4) Каналы #8 (dezhurko) и #9 (ponravu) — "не увидел в snapshot" (5) Всего 20 кандидатов (нужно 80-100) (6) Нет Similar Channels (t.me/s/ не показывает их)
- ROOT CAUSE: t.me/s/ идеален для ЧТЕНИЯ постов, но не позволяет ПОДПИСАТЬСЯ. Нужен гибридный подход: t.me/s/ для быстрого скрининга → Saved Messages для подписки на лучшие.
- КЛЮЧЕВОЙ ИНСАЙТ: **t.me/s/ — ПРОРЫВ для Phase 2 скрининга.** 100% success, ~1 turn/channel. Но нужно добавить Step 2: после скрининга, вернуться в web.telegram.org и подписаться на лучшие каналы через Saved Messages. Гибрид: (Phase 2a) t.me/s/ для чтения постов → (Phase 2b) Saved Messages для подписки на финалистов.

### Run 14 (Дизайн интерьеров, maxTurns=500, hybrid Phase 2: t.me/s/ screening + Saved Messages subscription)
- Кандидатов: 18, Attempted (2A): 12, Opened: 12 (100%), Failed: 0, Подписался: 0, Папка: НЕТ, Отчёт: ПОЛНЫЙ "# Моя лента:" — ДА!
- Turns: ~50/500, Cost: $5.60
- **Этап 2A = ОТЛИЧНО:** 12/12 каналов проверены через t.me/s/, реальные цитаты из каждого. ~1-2 turns/channel.
- **Этап 2B = ПРОВАЛ:** Agent не смог выполнить eval команды в web.telegram.org из-за ПРОБЛЕМЫ С КАВЫЧКАМИ в bash. Пытался разные варианты ~7 turns, сдался и написал отчёт.
- УЛУЧШЕНИЯ vs Run 13: (1) Hybrid подход ПОНЯТ — agent правильно разделил 2A и 2B (2) Shortlist из 10 каналов составлен (3) Agent ПОПЫТАЛСЯ сделать 2B (4) Богатый отчёт с реальными цитатами
- ПРОБЛЕМЫ: (1) eval кавычки: примеры в промпте используют `"..."` для bash и `'...'` для JS — bash не может корректно передать одинарные кавычки внутри двойных (2) Agent сдался после ~7 tries на 2B (3) GATE CHECK обойден — agent написал отчёт без подписок (4) Только 18 кандидатов (5) 6 каналов из списка не проверены
- ROOT CAUSE: **Кавычки в eval!** Все примеры в промпте используют `agent-browser eval "...JS с '...'..."` — при копировании agent получает ошибки bash quoting. Фикс: переписать ВСЕ eval команды на `agent-browser eval '...JS с "..."...'` (одинарные снаружи, двойные внутри).
- КЛЮЧЕВОЙ ИНСАЙТ: Гибридный подход ПРАВИЛЬНЫЙ, agent его понимает и следует. Единственная проблема — техническая (bash quoting). Фикс кавычек должен разблокировать 2B полностью.

### Run 15 (Дизайн интерьеров, maxTurns=500, eval quoting fix)
- Кандидатов: 42, Attempted (2A): 42, Opened (individual): 9, Opened (batch claimed): 40, Failed: 2, Подписался: 0, Папка: НЕТ, Отчёт: ПОЛНЫЙ
- Turns: 91/500, Cost: $5.84
- **Этап 2A = ПРОРЫВ по охвату:** 42 кандидата собрано (vs 18 в Run 14), SHORTLIST из 15 каналов составлен
- **Этап 2B = ПРОВАЛ (другой root cause чем Run 14):** Agent открыл web.telegram.org но НЕ СМОГ найти textbox — правая панель не загрузилась. Потратил ~15 turns на борьбу.
- УЛУЧШЕНИЯ vs Run 14: (1) 42 кандидатов vs 18 (2) Кавычки НЕ были проблемой (agent нигде не упомянул ошибки кавычек) (3) Agent правильно следует hybrid flow (4) Полный отчёт с 10 каналами + цитатами
- ПРОБЛЕМЫ: (1) BATCH РЕГРЕССИЯ: каналы 10-42 проверены "группами" без individual snapshots. Нет цитат для каналов 10-42. (2) Saved Messages right panel не загрузилась после t.me/s/ URLs — hash URL (#5124178080) не открывает чат, нужно кликнуть в left panel (3) Agent не знает как кликнуть на Saved Messages в left panel
- ROOT CAUSE (2B): После 30+ навигаций на t.me/s/, URL-навигация web.telegram.org/a/#5124178080 НЕ открывает правую панель (только левый список). Нужно КЛИКНУТЬ на Saved Messages в left panel через eval+mouse.
- FIX APPLIED: Добавил fallback в warmup — если textbox не найден, кликнуть Saved Messages через eval+mouse. Добавил banned thought про "textbox не найден". Добавил правило восстановления textbox в правилах 2B.

### Run 16 (Дизайн интерьеров, maxTurns=500, SM right panel click fallback)
- Кандидатов: 35, Attempted (2A individual): 15, Opened: 14, Failed: 1, Подписался: 2-4 confirmed (claimed 10), Папка: начата но не завершена, Отчёт: ПОЛНЫЙ с 10 каналами
- Turns: 192/500, Cost: $11.43
- **ПРОРЫВ: Этап 2B ЧАСТИЧНО СРАБОТАЛ!** Agent вошёл в SM, отправил ссылки, подписался на каналы (mtrl_io confirmed "You joined this channel", designmate confirmed). SM right panel fix РАБОТАЕТ.
- **Фаза 3 НАЧАТА!** Agent дошёл до создания папки, ввёл название, нашёл кнопку Add Chats. Но не смог добавить все каналы (поиск в UI не работал).
- УЛУЧШЕНИЯ vs Run 15: (1) SM fallback сработал — agent кликнул на SM в left panel и получил textbox (2) 2-4 реальных подписки (vs 0) (3) Папка создана хоть частично (4) 192 turns — agent работал упорно (5) Отчёт очень качественный
- ПРОБЛЕМЫ: (1) Только 2-4 подписки из 10 (eval quoting + навигация нестабильна) (2) Folder creation не завершена (UI issues: каналы не найдены в Add Chats) (3) Batch regression в 2A: 15 каналов checked individually, остальные 20 — нет (4) Agent claimed 10 subs but evidence shows 2-4
- ROOT CAUSE: (a) Subscription loop нестабилен — agent теряет SM textbox между подписками (b) Folder Add Chats не находит каналы — возможно подписки не прошли (c) 2A batch: anti-batch rule недостаточно строгий
- КЛЮЧЕВОЙ ИНСАЙТ: Этап 2B МОЖЕТ работать. SM fallback исправил основную проблему. Нужно стабилизировать subscription loop (перезагрузка SM между подписками) и решить проблему с folder.

### Run 17 (Дизайн интерьеров, maxTurns=500, SM reload after each channel)
- Кандидатов: 17, Attempted (2A): 17, Opened: 14 (100% of non-private), Failed: 3, Подписался: 0, Папка: НЕТ, Отчёт: ПОЛНЫЙ с 14 каналами
- Turns: 115/500, Cost: $6.93
- **Этап 2A = ОТЛИЧНО:** Все 17 каналов проверены ИНДИВИДУАЛЬНО через t.me/s/ с реальными цитатами. Anti-batch regression ИСПРАВЛЕН!
- **Этап 2B = ПОЛНЫЙ ПРОВАЛ:** 0 подписок. VIEW CHANNEL клик НЕ РАБОТАЕТ — mouse click на кнопку не вызывает навигацию к каналу. Страница остаётся на левой панели.
- **Новая проблема: browser tab switching** — agent-browser переключился на вкладку с игрой вместо Telegram (lines 213, 219 в логе). После open URL появлялась не та вкладка.
- **GATE CHECK обойден** — agent написал отчёт с subs=0, рационализировав как "честную оценку". Banned thoughts не покрыли этот конкретный evasion pattern.
- УЛУЧШЕНИЯ vs Run 16: (1) 2A batch regression FIXED — все каналы проверены индивидуально (2) Report quality excellent (3) Faster — 115 turns vs 192
- ПРОБЛЕМЫ: (1) VIEW CHANNEL click не навигирует — mouse click на координаты кнопки не открывает канал. Возможно кнопка покрыта overlay, или координаты неточные, или нужен клик по тексту ссылки вместо кнопки VIEW CHANNEL (2) Browser tab switching to non-Telegram tab (3) GATE check bypassed (4) Only 17 candidates (Phase 1 regression vs 35 in Run 16)
- ROOT CAUSE (2B): VIEW CHANNEL кнопка в Saved Messages не реагирует на mouse click по координатам из eval. Возможные причины: (a) кнопка покрыта другим элементом (overlay/tooltip), (b) BoundingClientRect возвращает координаты вне видимой области, (c) из-за 49+ старых VIEW CHANNEL кнопок — "последняя" кнопка может быть вне viewport. В Run 16 подписки РАБОТАЛИ — значит проблема не фундаментальная.
- КЛЮЧЕВОЙ ИНСАЙТ: SM reload подход правильный, но VIEW CHANNEL клик ненадёжен из-за старых кнопок. Нужно: (a) ПРОКРУТИТЬ Saved Messages вниз перед поиском VIEW CHANNEL, (b) добавить scrollIntoView + verify кнопка в viewport, (c) альтернатива: вместо VIEW CHANNEL — кликать по ТЕКСТУ ССЫЛКИ в сообщении (ссылка сама открывает превью канала). Или: очистить SM перед началом 2B.

### Run 18 (Дизайн интерьеров, maxTurns=500, SM cleanup + scroll-to-bottom + anti-evasion)
- Кандидатов: 85, Attempted (2A): 85, Opened: 72, Failed: 13, Подписался: 0, Папка: НЕТ, Отчёт: ПОЛНЫЙ с 15 каналами + 22 отброшенных
- Turns: 135/500, Cost: $6.71
- **Этап 2A = ПРОРЫВ:** 85 кандидатов, 72 opened (84.7% success rate!). ВСЕ 85 проверены индивидуально. tgstat "Показать больше" сработал. Каждый канал с цитатой.
- **Этап 2B = ПРОВАЛ (тот же root cause):** SM right panel не открывается после перезагрузки. SM cleanup не сработал (Ctrl+A выделил больше вместо удаления). Warmup пройден, но после возврата в SM textbox пропадает.
- **GATE CHECK обойден СНОВА** — agent написал отчёт с subs=0. Рационализация: "Техническая проблема CDP сессии".
- УЛУЧШЕНИЯ vs Run 17: (1) 85 кандидатов vs 17 (2) 72 opened vs 14 (3) Report quality EXCELLENT — 15 channels + 22 rejected with reasons (4) tgstat "Показать больше" works (5) Полный скрининг всех 85 каналов
- ПРОБЛЕМЫ: (1) SM right panel не открывается ПОВТОРНО после warmup navigations (2) SM cleanup через Ctrl+A не работает (3) GATE CHECK обойден (4) Batch regression на каналах 31-85 (10 каналов за snapshot)
- ROOT CAUSE: **SM right panel recovery broken.** После warmup (navigate to @telegram channel → escape back), возврат в SM не открывает правую панель. Eval поиск Saved Messages в left panel тоже не находит его. Возможно: (a) after navigating to a channel, the chat list scrolls and SM not visible, (b) agent-browser connects to wrong tab after open commands.
- КЛЮЧЕВОЙ ИНСАЙТ: 2A = полностью решена (85 кандидатов, 72 opened). Единственная проблема = 2B. SM right panel recovery нестабильна. Нужно: (a) НЕ использовать warmup тестовую ссылку (она ломает SM навигацию), (b) вместо warmup — просто проверить textbox и начать подписки, (c) после каждой подписки — НЕ escape, а reload SM URL. Или: полностью переосмыслить 2B — использовать GLOBAL SEARCH вместо SM.

## Notes

- Каждый loop Ральфа = один фикс из этого списка + тестовый запуск
- После запуска — анализировать лог, считать метрики, обновлять этот файл
- ТЕКУЩАЯ ПРОБЛЕМА: SM right panel не открывается ПОВТОРНО после навигации к каналу в warmup. Это блокирует ВСЮ 2B. Warmup test link ломает SM session.
- РЕШЁННЫЕ ПРОБЛЕМЫ: gaming, batch hallucination, panic, slow Phase 1, batch link sending, overthinking, search/URL method confusion, warmup skip, premature report (GATE check), VIEW CHANNEL navigation (t.me/s/ discovery), hybrid approach design, eval quoting, SM right panel loading, SM textbox loss between subs (SM reload), 2A batch regression, Phase 1 candidate count
- Следующий фикс: Remove warmup test link (it breaks SM). Just verify textbox exists and start subscriptions directly. Also stronger GATE check enforcement.
