# MVP — Deep Digger 🪨

> **Цель:** Launch-ready версия с критическими механиками Roblox-жанра. У игры один шанс при запуске — выпускаем сразу с pets, rebirth, монетизацией и polish, иначе не зайдёт в перенасыщенном mining-сегменте.
> **Срок:** ~10–13 недель ежедневной работы (2–3 ч/день). Без жёстких дедлайнов, но без расширения scope в процессе.
> **Архитектура:** 3D Neighbor Reveal (текущая). К вертикальной сетке 6×N не возвращаемся.
> **Кто пишет код:** AI-агент в Cursor.
> **Кто тестирует:** разработчик (Roblox Studio + Rojo).
> **Статус:** Фазы 0–11 закрыты 🟢 (Фаза 5 ждёт плейтест-профайл), Фаза 12 (Монетизация) — 🔴 на очереди.
> **Обновлено:** 2026-06-03

---

## Что вне scope MVP

**Принцип:** добавляем только то, что **обязательно** для жанра на Roblox в 2026. Всё «усиливающее» работающую игру → патчи 1.1, 1.2.

- Боссы (в оригинальной игре их нет).
- Trading между игроками (требует античита + UI, патч 1.1).
- Гильдии / кланы (жирная фича, патч 1.2+).
- Achievements как полноценная фича (модуль есть, но не подключаем — патч 1.1).
- Limited-time events (работают только когда есть аудитория).
- NPC в шахте, сейсмические события, биом-вариации (атмосферные фичи на потом).
- Mine Shafts как отдельная механика — используем уже реализованные **скрытые комнаты**.
- Полировка слоёв глубже Stone — Limestone+ остаются в `OreDatabase` для прогрессии после ребёрта, но без отдельного полишинга UI/звуков.
- Нефть, ауры, крафт, расходники (молоток, бомба).

Всё это — **post-MVP** контент.

---

## Критерии «MVP готов» (launch-ready)

Игрок может:

1. Зайти в игру и копать без рассинхрона с сервером.
2. Накопить руду, нажать «ПРОДАТЬ ВСЁ» → получить монеты по `value` из `OreDatabase`.
3. Купить **7 апгрейдов** и почувствовать эффект уже в следующем ударе.
4. Пройти **Dirt → Stone** (50+ м) с понятным переходом слоя.
5. Сделать **ребёрт** хотя бы раз и почувствовать множитель.
6. Открыть яйцо, получить **питомца**, экипировать, увидеть бонус к damage/luck.
7. Зайти на следующий день, забрать **daily reward**, увидеть себя в **лидерборде**.
8. Купить **gamepass** или **coin pack** через Roblox (минимум 3 пасса + 2 девпродукта).
9. Выйти и вернуться — прогресс тот же (ProfileService), питомцы и ребёрты сохранены.
10. Играть 30+ минут подряд с **ощутимым «соком»** ударов (звуки, screen shake, particles) без утечек FPS.
11. Получить **3 туториал-подсказки** в первые 30 секунд (клик → продай → купи кирку).

---

## Дефолты (зафиксированы)

- **Все 7 апгрейдов** из `Constants.UPGRADES`: pickaxe, speed, fortune, inventory, crit, multiSell, autoSell.
- **Штраф x0.5** урона по Stone при `pickaxeLevel < 5`.
- **Гемы** в HUD скрыты до post-MVP (поле остаётся в профиле, но UI и покупки за гемы — позже).
- **Скрытые комнаты** уже в коде — доводим, отдельные shafts не добавляем.

---

## Ритм работы (2–3 ч/день)

| Этап в дне | Время |
|------------|-------|
| Реализация фазы (агент) | ~30–90 мин |
| Sync через Rojo + Play Solo | ~30–45 мин |
| Фидбек → правки | ~30–60 мин |

Одна **фаза** ниже = **1–2 календарных дня** при таком ритме (фазы 3 и 5 — **2–3 дня**). Если день получился только тестовый, без новой фазы — нормально, сдвиг 2–3 дня в конце не страшен.

---

## Календарь (~10–13 недель до релиза)

| Неделя | Фазы | Цель недели |
|--------|------|-------------|
| 1–3 | 0 → 1 → 2 → 3 | ✅ Сделано: копание, HUD, продажа, все 7 апгрейдов |
| 4 | 4 → 5 | ✅ Сделано: переход слоёв, дельта-синк блоков |
| 5 | 6 → 7 | ✅ Единый источник руд (Фаза 6); ✅ **game feel pass** — звуки, screen shake, juicy dmg numbers, rarity-ramp break, slow-mo crit, mobile haptics |
| 6 | 8 → 9 | ✅ Туториал + Error UX + tooltip + count-up (Фаза 8); ✅ **Rebirth/Prestige** loop (Фаза 9) |
| 7 | 10 | ✅ **Daily reward** (7-day cycle, streak, x2 boost'ы) + **глобальный leaderboard** (MemoryStoreSortedMap, top-50 coins/depth, avatar thumbnails) |
| 8–9 | 11 | **Pets MVP**: 5–10 питомцев, egg-система, equip slot, эффекты |
| 10 | 12 | Монетизация: 3–4 game-passes, 2–3 DevProducts (coin packs) |
| 11 | 13 | Визуальный пасс: материалы по слоям, key art, иконка, thumbnail |
| 12–13 | 14 | Soft launch: 2-player playtest, balance fixes, релиз unlisted → public |

---

## Сделано вне фаз (инфраструктура для будущих чатов)

Эти модули уже есть в коде, не дублировать:

- **`shared/util/UpgradeLogic.lua`** — все формулы апгрейдов (cost, swing delay, pickaxe power, crit, fortune, inventory cap, multiSell). **Единственный источник** для клиента и сервера.
- **`shared/util/InventoryUtil.lua`** — `totalCount`, `addOre`.
- **`server/core/MiningLoot.lua`** — `rollFortuneBonus`, `tryAddOre` (учёт capacity + auto-sell).
- **`server/core/economy/BuyUpgrade.lua`**, **`SellInventory.lua`** — изолированные операции экономики.
- **`server/core/DevCommands.lua`** — `/coins`, `/reset`, `/maxlvl`, `/devhelp` (только в Studio).
- **`client/core/DepthTracker.lua`** — клиентский трекер глубины по позиции игрока.
- **`client/ui/Notification.lua`** — переиспользуемая всплывашка (`Notification.show({ text, color, icon, duration })`).
- **`Net:Connect("Notify")`** — серверный `notify(player, payload)` уже подключён в `init.server.lua`.
- **HUD модуляризован**: `client/ui/HUD.lua` — фасад, всё остальное в `client/ui/hud/{components,panels,*.lua}`.

Балансные числа жить только в `shared/constants.lua` (Constants.UPGRADES, Constants.LAYERS, и т.п.).

---

## Фазы

### █ Фаза 0 — Зафиксировать scope 🟢

- [x] Обновить MVP.md под 3D и без боссов.
- [x] Согласовать список апгрейдов v1 (все 7).
- [x] Решение: комнаты, не shafts.
- [x] Решение: 2 слоя в полировке (Dirt + Stone).
- [x] Дефолты подтверждены работой по Фазам 1–3.

---

### █ Фаза 1 — Фундамент и баги 🟢

- [x] Убрать двойной счётчик `totalBlocksMined` (`MiningEngine:hitBlock` + `init.server`).
- [x] Античит: лимит **на каждый удар** в батче + макс. размер батча в `MineBlock`.
- [x] Синк HUD: формат инвентаря (массив ↔ словарь) совпадает с тем, что отдаёт сервер.
- [x] Синк HUD: уровни апгрейдов (`pickaxeLevel`, `speedLevel`, …) реально приходят с сервера.
- [x] Один HUD на игрока: `destroy()` старого HUD при респавне.
- [x] Fusion: cleanup scope при разрушении HUD (без утечек).
- [x] `EconomyManager.new(...)` получает доступ к `profileManager`.
- [x] `.cursorignore`: `Packages/`, билды, кеши.

**Тест:** копание, HUD после копания не врёт, респавн персонажа — один HUD, статы корректны.

---

### █ Фаза 2 — Экономика 🟢

- [x] `Net:Handle("SellOres")` — продаёт весь инвентарь.
- [x] Цена = `OreDef.value`, монеты в `playerData.coins`.
- [x] Учёт `multiSellLevel` (бонус % к продаже).
- [x] `playerData.totalCoinsEarned += sum`.
- [x] Серверная валидация (нельзя продать руду, которой нет).
- [x] Синк монет/инвентаря клиенту после продажи.
- [x] Кнопка «ПРОДАТЬ» в HUD: фидбек (успех / «инвентарь пуст»).

**Тест:** набил инвентарь → продал → монеты, инвентарь пуст; перезаход — то же.

---

### █ Фаза 3 — Апгрейды 🟢

- [x] `Net:Handle("BuyUpgrade", upgradeId)`:
  - проверка цены (`baseCost * exponent^(level-1)`),
  - проверка `maxLevel`,
  - списание монет, инкремент уровня в профиле,
  - возврат результата клиенту.
- [x] **pickaxe** → урон: `1 + (lvl-1) * powerPerLevel` в `MiningEngine:hitBlock`.
- [x] **speed** → задержка между ударами (клиент-кулдаун + проверка на сервере).
- [x] **crit** → шанс крита, x3 урон.
- [x] **fortune** → шанс выпадения двух руд за удар.
- [x] **inventory** → лимит слотов (`BASE_INVENTORY_SLOTS + lvl * slotsPerLevel`).
- [x] **multiSell** → бонус % при `SellOres`.
- [x] **autoSell** → одноразовая покупка, авто-продажа при заполнении инвентаря.
- [x] HUD: кнопки Buy, корректные цены/уровни, состояние «не хватает монет».

**Тест:** купил кирку — бьёшь сильнее; speed — сервер не пускает спам; auto-sell при полном инвентаре включается.

---

### █ Фаза 4 — Прогрессия слоёв 🟢

- [x] Единая логика глубины — клиентский `DepthTracker` (по `HumanoidRootPart.Y`), сервер `playerData.depth/layer` сбрасывается на спавне (depth — визуальное, не персистится).
- [x] Переход **Dirt → Stone** (50 м): клиент шлёт `UpdateDepth`, сервер шлёт `notify()` при первом пересечении (`Notification` стек).
- [x] Цвет фона / окружения по слою — `client/core/LayerEnvironment.lua` твинит `Lighting.Ambient/OutdoorAmbient/FogColor` по `Constants.LAYERS.bgColor`.
- [x] Штраф **x0.5** урона по Stone при `pickaxeLevel < 5` (`Constants.STONE_PICKAXE_MIN_LEVEL`, `STONE_DAMAGE_PENALTY`) + уведомление «кирка слабая».
- [x] Рекорд `maxDepthReached` в профиле, обновляется на сервере при `UpdateDepth`, отображается в Stats.
- [x] Бонус: уведомление о найденной скрытой комнате (`roomGenerated` + цвет редкости из `Constants.RARITY_COLORS`).

**Тест:** докопал до 50 м → уведомление, руды стали Stone, слабая кирка ощутимо медленнее по Stone.

---

### █ Фаза 5 — Сеть и производительность 🟢

- [x] **Дельта-синк блоков**: `SyncBlocks { kind = "snapshot" | "delta", payload }`. Snapshot — раз при заходе, дальше только `{ created, updated, removed }` из `MiningEngine:hitBlock.blockDelta`. Клиент: `MiningRenderer.applySnapshot/applyDelta` — клиент верит серверу, никаких diff-расчётов.
- [x] Сервер: удар только по существующему **открытому** блоку (`MiningEngine:_isExposed` — есть air-сосед, либо `y < SURFACE_H`).
- [x] Лимит размера батча кликов в `MineBlock` (`Constants.MAX_MINE_BATCH_SIZE = 16`, `AntiCheat:validateMineBatch`) — сделано в Фазе 1.
- [x] Доводка скрытых комнат: всё в `Constants` — `SHAFT_BASE_CHANCE = 0.08`, `SHAFT_DEPTH_BONUS = 0.0001`, `SHAFT_EXPAND_CHANCE = 0.7`, `SHAFT_RARITY_BOOST_MAX = 2`.
- [x] Уведомление по rarity для комнат — сделано в Фазе 4.
- [ ] Профилирование: 10+ минут копания без просадок FPS — чек-лист в `STATUS.md`, ждёт плейтест разработчика.

**Тест:** 10+ минут копания без лагов; второй аккаунт играет параллельно без поломок.

---

### █ Фаза 6 — Один источник данных по рудам 🟢

- [x] `OreDatabase` перенесён в `shared/data/OreDatabase.lua` — реплицируется через ReplicatedStorage без RemoteFunction (статичные данные, race-condition исключён).
- [x] Клиент (`MiningRenderer`, `HUD/InvSlot`, `HUD/HudState`) берёт цвет / редкость / иконку через `client/core/OreLookup` — единый O(1) лукап по `oreId`.
- [x] Удалены дубли: `ORE_C` / `ORE_R` / `RAR_C` из `MiningRenderer`, файл `client/ui/hud/OreCatalog.lua` целиком.
- [x] Emoji-иконки переехали в `OreDatabase` (поле `icon`, было `""`).
- [x] `OreDef` расширен опциональными полями `material` / `reflectance` / `atlasIndex` / `meshId` / `glow` — задел под Фазу 13 (Blender + Substance Painter texture atlas), без изменений в рендере.
- [x] Добавление новой руды = правка только `OreDatabase` + перезапуск сервера.

**Тест:** добавлена `test_glow` (mythic, dirt, фиолетовая, 🟪) — появляется на поверхности, красный rarity-tag, mythic-частицы, в инвентаре отображается с правильной иконкой и цветом полоски — без единой правки клиентского кода.

---

### █ Фаза 7 — Game Feel & Juice 🟢

**Цель:** превратить функциональные клики в **сочные**. Без этого игра умирает в первые 30 секунд.

- [x] **Звуки** (`shared/data/SoundDatabase` + `client/core/SoundManager`): hit_dirt/stone/metal/gem по rarity-тиру, break_common…mythic, crit, sell_success/fail, buy_upgrade/fail — Roblox audio library, free. ID помечены `TODO playtest` для свапа во время теста. 3D-звук в точке блока, 2D для UI. Один Sound-инстанс per eventId, random pitch ±0.1.
- [x] **Camera shake** (`client/core/CameraShake.lua`): только на разрушении и только начиная с **rare** (`rare_break 0.05/0.08`, `break 0.09/0.12`, `legendary_break 0.22/0.25`). На каждом hit'е и крите камера НЕ трясётся. Реализация — суммарный offset CFrame на RenderStepped, авто-откат прошлого кадра, не накапливается.
- [x] **Juicy damage numbers**: pop-in `TextSize 0 → final` за 0.1с (Quad/Out, мягко), `UIStroke` + adaptive stroke color (тёмный/светлый по luminance руды), цвет цифры = цвет руды, золото при крите, размер скейлится от `dmg / maxHp`.
- [x] **Block squash на ударе**: блок упруго приплющивается (`Size BSv → 1.07/0.88/1.07 → BSv` за 0.14с) — замена шутерному camera shake. Фидбек идёт от блока, не от глаз.
- [x] **Break-эффект (mining-style)**: разлетающиеся **физические chunks** цвета руды (6→30 по rarity, gravity-affected, fade через Debris), облако пыли через `smoke_main` (8→32 частицы, scale 1.0→1.6), **shockwave-сфера** ForceField-материала цвета редкости для rare+ (BS×2.8 → BS×8), у mythic — два кольца: rarity-цвет + золотое с задержкой 0.15с. Никакого fullscreen flash.
- [x] **Coin-pop** (новое): `+X 💰` золотом всплывает из точки блока на 1.3с, размер крупнее на rare+. Главный mining-фидбек — игрок видит награду, ради которой копал.
- [x] **Hover-фидбек**: `Size BSv ↔ HOVER_BSv (×1.05)` за 0.1с поверх существующих glow + SelectionBox; `_destroying` / `_squashing` / `_hovered` атрибуты разрешают конфликт между hover-, squash- и destroy-tween'ами.
- [x] **Crit-эффект (mining-style)**: золотое shockwave-кольцо в точке блока + 6 золотых chunks, отдельный звук `crit`, золотая `dmgNumber` ×1.4 размера. **Без slow-mo** (это шутерный эффект, в mining ломает темп).
- [x] **Mobile haptics** (`client/core/Haptics.lua`): pulse-пресеты `hit 0.12/0.03` (очень мягко, копание = много кликов), `crit 0.4/0.06`, `break 0.6/0.08`, `legendary_break 1.0/0.15`. `pcall`-обёртка вокруг `HapticService:SetMotor`, no-op на десктопе.

**Тест:** записать gif/видео — выглядит «как в топовых Roblox-играх», а не как unity-тутор.

---

### █ Фаза 8 — Онбординг и UX 🟢

**Цель:** новый игрок понимает что делать за 30 секунд, без чтения.

- [x] **3 подсказки** (`client/ui/Tutorial.lua` orchestrator + `tutorial/TutorialFlow.lua` data-driven сцены): 1) «Кликни блок» (стрелка на ближайший block-part), 2) «Открой инвентарь» → «Продай руду» (стрелка на Tab_inventory, потом SellButton), 3) «Купи кирку» (Tab_upgrades → UpgRow_pickaxe). Прогресс — `playerData.tutorialStep` (0..3), сервер валидирует монотонный рост в `TutorialManager.lua`.
- [x] **Стрелки/highlights** (`client/ui/TutorialArrow.lua`): пульсирующий золотой UIStroke поверх GuiObject и BillboardGui-стрелка ⬇ с bounce-tween над BasePart. Стрелка следит за target через RenderStepped, не блокирует ввод (`Active = false`).
- [x] **Диалоговые окна** (`client/ui/tutorial/TutorialDialog.lua`): боттом-центр диалог наставника «Шахтёр Бородач ⛏️» с typewriter-эффектом (~42 char/sec, UTF-8 safe), кнопкой [Понятно ✓] и [✕] skip. Цвет stroke зависит от kind (intro=gold, task=cyan, success=green, finale=mythic). Slide-in/out, клик по диалогу мгновенно дописывает текст. `Active=false` снаружи — геймплей не блокируется.
- [x] **Мини-задания** (`client/ui/tutorial/TutorialTracker.lua`): квест-трекер справа под TopBar с заголовком «Задание N из 3», описанием и опциональным progress bar. На выполнение — заполнение до конца, цвет → зелёный, анимированный ✓ (Back/Out 0.3с), auto-hide через 1.4с.
- [x] **Data-driven flow** (`client/ui/tutorial/TutorialFlow.lua`): все 9 сцен (`welcome → step_0_task → step_0_success → step_1_open_inventory → step_1_sell → step_1_success → step_2_open_upgrades → step_2_buy_pickaxe → finale`) описаны декларативно — `speaker / text / kind / task / target / arrowText / completeOn`. Тексты диалогов переписываются без правок логики. `SERVER_STEP_AFTER` маппит scene → серверный шаг (`UpdateTutorialStep` шлётся только на success/finale).
- [x] **Sound feedback**: `ui_click` на advance диалога, `sell_success` на завершение задачи и финал.
- [x] **Skip Tutorial**: кнопка [✕] в диалоге → `Tutorial.skip()` → `UpdateTutorialStep(3)`. DevCommand `/skiptut` ставит `tutorialStep=3` для тестирования не-онбординг-фич.
- [x] **Error UX**: тосты через `Notification.show` при «не хватает X монет» (с конкретным дефицитом), серверная ошибка покупки, пустой инвентарь при SELL. Inline-фидбек на кнопке остаётся как secondary-channel.
- [x] **Tooltip** (`client/ui/hud/components/Tooltip.lua`): hover на `UpgRow` показывает имя/описание/текущий эффект/«Далее:» через `UpgradeLogic.describeCurrentLevel` + `describeNextLevel`. RichText, edge-clamping, fade 0.1с, авто-очистка через scope.
- [x] **Count-up tween цифр**: `client/ui/hud/components/AnimatedNumber.lua` плавно «тикает» coins / totalCoinsEarned за 0.4с (Quad/Out). Авторитативный `state.coins` остаётся integer-ом для `canAffordNow` — игрок может покупать сразу после продажи, не дожидаясь tween'a.
- [x] **First-time bonus**: `Constants.STARTER_COINS = 100`. `TutorialManager:onProfileLoaded` начисляет один раз через `profile.firstSession` флаг (защита от двойного начисления), миграция опытных профилей (totalBlocksMined>0 или totalCoinsEarned>0) сразу выставляет `tutorialStep = 3`.

**Тест:** новый игрок (друг, никогда не видевший игру) играет 2 минуты молча, не задавая вопросов. В Studio: `/reset` → диалог «Здорóво, новичок!» → клик «Понятно» → задание «Добыть руду 0/1» + стрелка на блок → клик блок → ✓ + диалог «Молодец!» → следующая сцена. По шагу 3 finale-диалог автоматически закрывается через 5.5с.

**Дата закрытия:** 2026-06-02. **Polish-итерация:** 2026-06-02 — добавлены диалоговые окна, квест-трекер и data-driven flow по фидбеку плейтеста.

---

### █ Фаза 9 — Rebirth / Prestige 🟢

**Цель:** долгосрочная петля. После первого ребёрта игрок видит «куда расти».

- [x] **`server/core/RebirthManager.lua`**: DI (`profileManager`, `onProfileChanged`, `notify`, `onResetBlocks`), `Net:Handle("Rebirth")` с серверной валидацией `coins >= RebirthLogic.cost(rebirths)`, `_applyRebirth` сбрасывает прогресс, инкрементирует `rebirths`, денормализует `rebirthMultiplier`, шлёт тост `kind="rebirth"` для клиентского FX, `onProfileLoaded` идемпотентно пересчитывает кэш, `devRebirth(player, n)` — для DevCommands.
- [x] **Что сохраняется при ребёрте**: `rebirths`, `rebirthMultiplier`, `totalCoinsEarned`, `totalBlocksMined`, `maxDepthReached`, `bossesDefeated`, `shaftsFound`, `playTime`, `tutorialStep`, `firstSession`. **Сбрасывается**: `coins=0`, `inventory={}`, все `*Level=1`, `autoSellUnlocked=false`, `depth/layer/_stoneLayerNotified`.
- [x] **Что усиливается**: множитель `1 + rebirths * 0.1` к value руд в `SellInventory.execute` (после `multiSellMultiplier`); `UpgradeLogic.maxLevel(upgradeId, rebirths)` даёт +1 к maxLevel pickaxe на каждом перейденном пороге `Constants.REBIRTH.pickaxeMaxBonusAt = {5, 10, 25}`.
- [x] **UI**: 4-й таб REBIRTH в `TabBar` (`Tab_rebirth`), `RebirthPanel.lua` с заголовком «Ребёрты: N / Множитель: x1.X», крупной кнопкой REBIRTH (disabled при недостатке монет, текст «Не хватает X 💰»), описанием «Что сохранится / сбросится / следующий бонус кирки». Опциональный TopBar-чип `💠 N x1.X` появляется при `rebirths > 0`.
- [x] **`RebirthConfirmModal.lua`**: затемнение + центрированный фрейм, RichText body с разделением «✓ сохранится / ✗ сбросится / ⛏ следующий бонус», кнопка [РЕБЁРТ] disabled первые **0.3с** (anti-misclick), ESC / клик по backdrop / [ОТМЕНА] закрывают без действия. Modal `Active=true` — клик мимо кнопок не проваливается на backdrop.
- [x] **`client/ui/RebirthFX.lua`**: mining-style локальный FX в позиции игрока — 3 золотых shockwave-кольца (volumes 22/32/40 студов, ForceField-сфера) + 30 золотых физических chunks с gravity. **Без camera-shake, slow-mo, fullscreen flash** — соблюдены Phase 7 mining-принципы.
- [x] **Notification**: тост «REBIRTH! Ребёрт #N, теперь x1.X к ценам руд», icon=💠, duration=5с. `kind="rebirth"` в payload триггерит `RebirthFX.burst()` на клиенте.
- [x] **`Net:Handle("Rebirth")`** в отдельном `RebirthManager`. `EconomyManager` не тронут — изоляция Phase 3.
- [x] **`Constants.REBIRTH = { baseCost = 50000, exponent = 5, multiplierPerRebirth = 0.1, pickaxeMaxBonusAt = {5, 10, 25} }`**. Формулы — в `shared/util/RebirthLogic.lua` (`cost`, `valueMultiplier`, `pickaxeMaxLevelBonus`, `nextPickaxeBonusThreshold`, `describeReward`).
- [x] **HUD-payload**: `buildHudPayload` шлёт `rebirths` + `rebirthMultiplier`; `PlayerDataMapper` мапит их в `MappedPlayerData`; `HudState.rebirths` / `state.rebirthMultiplier` обновляются мгновенно (без tween — ребёрт дискретное событие). `StatsPanel` показывает обе строки.
- [x] **DevCommands `/rebirth [N]`** через DI `rebirthManager:devRebirth(player, N)` — даёт N ребёртов без проверки цены. `/reset` НЕ трогает rebirths (теперь явно прописано).
- [x] **UpgradesPanel + UpgRow**: `maxLevel` и `describeNextLevel` rebirth-aware — pickaxe после R5/R10/R25 показывает корректный новый макс в tooltip'е, кнопка [+] не блокируется ложным «MAX».

**Тест:** /coins 50000 → REBIRTH активна → клик → confirm-modal с anti-misclick 0.3с → подтверждение → тост «REBIRTH! Ребёрт #1, теперь x1.1 к ценам руд» + золотой shockwave вокруг игрока. После: монеты 0, инвентарь пуст, все апгрейды на lvl 1, autoSell выключен; totalCoinsEarned/maxDepthReached/tutorialStep=3 сохранены. Накопал руду → продал → монет на +10%. Второй ребёрт стоит 250k. /rebirth 5 → pickaxe maxLevel 100→101, /rebirth 25 → 100→103.

**Дата закрытия:** 2026-06-02.

---

### █ Фаза 10 — Retention loops (Daily + Leaderboard) 🟢

**Цель:** причина вернуться завтра и сравнить себя с другими.

- [x] **Daily reward** (`server/core/DailyReward.lua`): DI как `RebirthManager` — `Net:Handle("ClaimDaily")`, серверная валидация через `DailyLogic.canClaim`, начисление монет / boost'ов, инкремент `currentStreak` (`gap == 1 → +1`, `gap == 0 → already`, `gap >= streakResetAfterMissedDays → 1`), `os.date("!*t")` UTC, `lastClaimYday/lastClaimYear` для перехода через границу года, серверный `task.spawn(rolloverCheckInterval=60s)` watcher шлёт `kind="daily_available"` без перезахода. Девкоманды: `/daily`, `/setday <N>`, `/resetdaily`, `/boost <min>`.
- [x] **`shared/data/DailyRewardDatabase.lua`**: 7-дневный цикл, rarity common→mythic. Day 7 = +50k монет + автоматический `bonusBoost { multiplier=2, duration=1800 }`. Все формулы — в `shared/util/DailyLogic.lua` (`currentDay`, `daysBetween`, `canClaim`, `nextStreak`, `streakToCycleDay`, `timeUntilNextDay`).
- [x] **`server/core/PlayerBoosts.lua`**: чистые функции `totalMultiplier` (multiplier - 1 суммируется аддитивно), `addBoost` (стек по kind, продлевает expiresAt), `cleanup` (вызывается в `onProfileLoaded` и в `SellInventory.execute` перед расчётом). Boost'ы хранятся в `playerData.activeBoosts` как `{ kind, multiplier, expiresAt }` — переживают рестарт.
- [x] **`SellInventory.execute`**: `payout = floor(gross * multiSellMult * rebirthMult * boostMult)` — порядок: persistent → temporary. `PlayerBoosts.cleanup` чистит истёкшие перед расчётом.
- [x] **UI daily** (`client/ui/DailyRewardModal.lua` + `hud/components/DailyCard.lua`): full-screen overlay `DisplayOrder=95`, сетка 7 карточек (4×2 desktop / 2×4 mobile при `viewport.X < 800`), rarity-цветной `UIStroke`, pulse-glow на текущем дне, ✓ на прошлых, затемнение на будущих. Anti-misclick **0.4с** перед `[ЗАБРАТЬ]`, ESC / `[ПОЗЖЕ]` закрывают. Каждое `show()` создаёт собственный `innerScope` + `Fusion.doCleanup` на закрытии — без накопления реактивов.
- [x] **`client/ui/RewardFX.lua`**: full-screen coin/gem rain (60 спрайтов 💰 с physics + rotation, fade) + 3 rarity-цветных shockwave кольца в центре. ~1.5с total, `pcall`-обёртки. Триггерится через `Net:Connect("Notify")` с `payload.kind="daily_reward"` — server-authoritative по rarity (избегаем двойного burst'a).
- [x] **TopBar чипы**: `BoostChip.lua` (visible при `#activeBoosts > 0`, локальный countdown «⚡ x2 · 29:42», RGB-cycle `UIStroke` через `RunService.Heartbeat`), `StreakChip.lua` (visible при `streak >= 2`, «🔥 N дней»). StatsPanel показывает streak + ранги лидерборда.
- [x] **Глобальный лидерборд** (`server/core/Leaderboard.lua` переписан): `MemoryStoreSortedMap` × 2 (`Leaderboard_Coins_v1`, `Leaderboard_Depth_v1`), ключ = `"user_<userId>"`, значение = integer score, `expirationSeconds = 30 days` TTL. `writeIfChanged` через `LeaderboardLogic.shouldWrite` (delta >= `writeThresholdCoins=100`/`writeThresholdDepth=5`). Дёргается из `onEconomyChanged` (после продажи) и `RebirthManager`. Имена игроков — `Players:GetNameFromUserIdAsync` + локальный `nameCache`. Refresh раз в 30с с retry exp-backoff `2/4/8с` на ошибки MemoryStore. `Net:Function("RequestLeaderboard")` с server-side throttle 5с на игрока.
- [x] **UI лидерборда** (`client/ui/hud/panels/LeaderboardPanel.lua` + `hud/components/LeaderRow.lua`): 5-й таб 🏆 в `TabBar` (ширина 5*58+4*6=320), toggle «💰 Монеты / ⬇ Глубина», spotlight-карточка топ-1 с короной 👑 + золотой gradient + pulse-glow, ScrollingFrame top-2..top-50, footer «Вы: #N» если игрок вне топ-50, countdown «Обновится через Ns» справа сверху. **Avatar thumbnails**: `Players:GetUserThumbnailAsync(userId, HeadShot, Size150x150)` async, кэш в module-level `{ [userId] = imageId }`, skeleton-placeholder до загрузки, fade-in при готовности. Loading skeleton (10 строк) до первого fetch'a, «Сервис недоступен, обновляем...» при ошибке.
- [x] **HUD-payload расширен**: `buildHudPayload` шлёт `dailyState { canClaim, currentStreak, nextDay, secondsUntilNextDay, totalDaysClaimed }`, `activeBoosts` (с `remainingSeconds` на момент payload'а) и `leaderboardPlacement` ({coinsRank, depthRank, coinsValue, depthValue}). `PlayerDataMapper` + `HudState` синкают мгновенно. ProfileService template-мердж добавил поля старым профилям без миграции.
- [x] **`Net:Connect("PlayerStats")`** в `init.client.lua`: при `dailyState.canClaim == true` и `_autoOpenedThisSession == false` автоматически открывает `DailyRewardModal`. `kind="daily_available"` в Notify — переоткрытие модала после полуночи без перезахода.
- [x] **`Constants.DAILY`** (`cycleDays=7`, `grantBoostAtDay7=true`, `streakResetAfterMissedDays=2`, `rolloverCheckInterval=60`) + **`Constants.LEADERBOARD`** (`COINS_MAP/DEPTH_MAP` ключи, `topSize=50`, `refreshIntervalSeconds=30`, `expirationSeconds=30 дней`, `writeThresholdCoins=100`, `writeThresholdDepth=5`). Версионируем `_v1` — при изменении схемы старый лидерборд остаётся как archive.

**Тест:** свежий профиль → автоoпен `DailyRewardModal` с Day 1 highlighted → [ЗАБРАТЬ] (после 0.4с) → coin-rain + sell_success звук + закрытие → TopBar показывает 🔥 1 + +500 монет через AnimatedNumber. `/setday +1` → перезаход → Day 2 (Day 1 ✓). `/setday +3` → стрик сброшен в 1. 7 итераций `/setday +1` → Day 7 даёт +50k + 30-min x2 boost → `BoostChip ⚡ x2 · 29:59` тикает → продажа руды на +100% монет. Реальное время: вход в 23:55 UTC → ждать → notify «Новая награда!» без перезахода. 🏆 таб → skeleton ~2с → топ-50 с avatar'ами, спотлайт топ-1 короной, своя строка золотом подсвечена. Toggle монеты/глубина — оба board'a в state. Перезаход в boost'е — выживает (expiresAt в профиле). `/reset` НЕ трогает dailyState/activeBoosts; `/resetdaily` отдельно.

**Дата закрытия:** 2026-06-02.

---

### █ Фаза 11 — Pets MVP 🟢

**Цель:** жанро-определяющая механика. Без неё mining-игра не выживает на Roblox.

- [x] **`shared/data/PetDatabase.lua`**: 10 питомцев, разные rarity (common → mythic), эффекты: `damageBoost`, `luckBoost` (шанс комнат), `coinBoost`, `multiMine` (шанс ломать 2 блока). Каждый пет — `{ id, name, rarity, icon, color, effect = { kind, value } }`. Лукапы `byId` / `byRarity` строятся один раз.
- [x] **`server/core/PetManager.lua`**: DI-менеджер (паттерн RebirthManager/DailyReward). `Net:Handle("HatchEgg", count)` (валидация монет, weighted roll, append в `playerData.pets`, авто-equip первого), `Net:Handle("EquipPet", uid)`, `Net:Handle("UnequipPet")`, `onProfileLoaded` (ensure-поля + чистка «висячего» equippedPet), dev-методы `devHatch/devGivePet/devClearPets`. 1 equip slot на старте (`Constants.PETS.maxEquipped`).
- [x] **`server/core/EggManager.lua`**: 1 egg type («Basic Egg», `Constants.PETS.eggs.basic`), цена в монетах, `clampCount` (batch 1..10), `totalCost`, `hatch` делегирует weighted roll в `PetLogic.rollHatch`.
- [x] **`client/ui/hud/panels/PetsPanel.lua`** (6-й таб 🐾): индикатор активных бустов, Basic Egg + кнопки «Открыть 1× / 10×», грид owned-петов через `s:Computed` ВНУТРИ `[Children]`, equip/unequip по клику. `client/ui/hud/components/PetCard.lua` — карточка пета (rarity-stroke, ZIndex 2+ на тексте).
- [x] **Pet visual** (`client/ui/PetVisual.lua`): Neon-сфера rarity-цвета + BillboardGui-иконка парит сбоку от HumanoidRootPart, RenderStepped: орбита + bobbing (sin) + вращение. Респавн обрабатывается автоматически.
- [x] **Hatch animation** (`client/ui/PetHatchFX.lua`): полноэкранный overlay — трясущееся 🥚 → rarity-цветной shockwave-burst → reveal-карточки с pop-in (Back/Out, stagger). Поддержка 1× и 10× (грид), tap-to-skip, авто-закрытие.
- [x] **`Net:Handle("HatchEgg", count)`** — батч до 10 яиц за раз (`Constants.PETS.hatchBatchMax`), для «open 10×». Сервер клампит count.
- [x] **Эффекты влияют на расчёты** (формулы — единый источник `shared/util/PetLogic.lua`): `damageBoost` → урон в `MiningEngine:hitBlock`; `luckBoost` → множитель шанса комнат; `multiMine` → доп. блок ломается мгновенно, кладётся в инвентарь; `coinBoost` → `SellInventory` аддитивно в boost-стадию (порядок multiSell→rebirth→boost сохранён).
- [x] **DevCommands**: `/egg [N]`, `/hatch`, `/pet <id>`, `/clearpets`.

**Тест:** купил Basic Egg → нажал HATCH → анимация → пет в инвентаре → equip → урон вырос. 10x работает.

**Дата закрытия:** 2026-06-03.

---

### █ Фаза 12 — Монетизация 🔴

**Цель:** revenue stream для итераций после запуска.

- [ ] **Game-passes** (создать в Creator Hub, ID в `Constants.GAMEPASSES`):
  - VIP (399 Robux): +10% монет, эксклюзивный титул, VIP-цвет ника.
  - Auto-sell (599 Robux): unlocks `autoSellUnlocked = true` сразу.
  - +2 pet slots (799 Robux): максимум 3 пета вместо 1.
- [ ] **DevProducts**:
  - Small Coin Pack (99 Robux): 10k coins.
  - Medium Coin Pack (399 Robux): 100k coins.
  - Egg 10x (199 Robux): 10 яиц.
- [ ] **`server/core/MonetizationManager.lua`**: подключение `MarketplaceService.ProcessReceipt`, выдача наград, защита от двойного начисления через DataStore.
- [ ] **UI Shop**: вкладка в HUD с пассами и девпродуктами, кнопка PURCHASE → `MarketplaceService:PromptPurchase`.
- [ ] **Owned status**: gamepasses подгружаются на заходе, отражаются в HUD (VIP-значок, auto-sell всегда on).

**Тест:** в Studio нельзя покупать пассы; настроить ID в Creator Hub, опубликовать unlisted → тест-аккаунт покупает за тест-Robux → награда приходит.

---

### █ Фаза 13 — Визуальная идентичность 🔴

**Цель:** игра выделяется в Roblox Discover.

- [ ] **Материалы по слоям** (используя задел в `OreDef.material`): Dirt → `Ground`, Stone → `Slate`, Gold → `Foil`, Diamond → `Glass` + reflectance, Obsidian → `Glass` тёмный, Mythic → `Neon`.
- [ ] **Lighting**: тонкая настройка `Lighting.Brightness`, `ClockTime`, `Atmosphere` для каждого слоя — атмосфера «спускания вглубь».
- [ ] **Key art** (превью игры): 3D-рендер шахты с гигантской киркой и питомцем на переднем плане. Хук, на который кликают в Discover.
- [ ] **Icon**: 512×512, узнаваемая, читается в 64×64 (мобильные превью).
- [ ] **Thumbnail set** (4 штуки): копание, ребёрт-эффект, открытие яйца, лидерборд.
- [ ] **Название и описание** в Creator Hub: финальный текст с ключевыми словами «mining», «pets», «rebirth», «simulator».
- [ ] **Genre tags** в Creator Hub: Simulator, Adventure.

**Тест:** показать иконку 5 случайным людям → угадывают что игра про копание/добычу.

---

### █ Фаза 14 — Soft Launch & Стабилизация 🔴

**Цель:** релиз с минимальным риском.

- [ ] Solo плейтест 30+ минут подряд (сам разработчик).
- [ ] Тест с 2 игроками (одновременно копают, проверка `playerData` изоляции).
- [ ] Перезаход: прогресс совпадает, питомцы на месте, gamepasses активны.
- [ ] Стресс быстрых кликов: античит срабатывает.
- [ ] Выход во время автосейва: профиль не теряется.
- [ ] **Unlisted release**: 10–20 друзей/Discord-знакомых играют 3 дня.
- [ ] Сбор фидбека → 1 баланс-патч.
- [ ] **Public release** + первые 1–2 промо-поста в Roblox-сообществах.
- [ ] Чек по списку «MVP готов» — все 11 пунктов зелёные.

---

## После MVP (патчи 1.1, 1.2)

**Патч 1.1** (через 2 недели после релиза):
- Trading между игроками (P2P UI, античит).
- Achievements (`AchievementManager` уже есть — подключить).
- 2-й egg type (Gold Egg) + 5 новых питомцев.

**Патч 1.2** (через месяц):
- Limestone Layer полировка (новые материалы, звуки, балансы).
- Гильдии / кланы.
- Limited-time event: «Lucky Hour» — x2 luck комнат на 60 минут раз в день.

**Большие обновления (post-MVP):**
- Limestone → Crimson → Marble → Obsidian → Void (полировка контента слоёв).
- Mine Shafts как отдельная фича (постоянные проходы вниз, бонусы к редкости).
- Расходники: молоток, бомба.
- Гемы и магазин за гемы.
- Боссы (если решим — против исходного решения Фазы 0).
- NPC, сейсмические события, биом-вариации каверн.

---

## Примечания

- Сейчас в `src/` ~11.8k строк в 74 файлах (после Фазы 10); ожидаемый объём к концу MVP — **~15–18k строк** (Pets MVP добавит ~1500–2000, Monetization ~800–1200, визуальный пасс ~500).
- AI-агент пишет код фазами; разработчик — Studio, Rojo, плейтест, фидбек по чеклисту фазы.
- Баланс настраиваем после первого 30-минутного прогона по чек-листу «MVP готов».
- Звуки на MVP — бесплатная библиотека Roblox; кастомные ассеты — post-MVP.
- Лимиты Cursor (Pro+ ~$70 кредитов): на каждую новую фазу — новый чат, для рутины — Auto, для тяжёлых рефакторингов (фазы 3, 5, 11) — премиум-модель точечно.

## Правило защиты от scope creep

Каждый понедельник задавать вопрос (из `.cursor/rules/code-quality.mdc`):

> «Если бы я выпустил это сегодня, что бы остановило игроков?»

- Ответ типа «нет звуков», «нет питомцев», «нет ребёрта» → продолжаем фазы.
- Ответ типа «нет trading», «нет limited events», «нет 50 питомцев» → **scope creep, в патч**.
- Ответ типа «всё нормально, можно играть» → **запускаем сейчас**, не доводим до перфекционизма.

Дисциплина: не добавлять фичу в MVP **в процессе** работы. Если идея появилась — записать в «После MVP», вернуться к ней после релиза.
