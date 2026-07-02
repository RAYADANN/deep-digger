# MVP — Deep Digger 🪨

> **Цель:** Launch-ready версия с критическими механиками Roblox-жанра. У игры один шанс при запуске — выпускаем сразу с pets, rebirth, монетизацией и polish, иначе не зайдёт в перенасыщенном mining-сегменте.
> **Срок:** ~10–13 недель ежедневной работы (2–3 ч/день). Без жёстких дедлайнов, но без расширения scope в процессе.
> **Архитектура:** 3D Neighbor Reveal (текущая). К вертикальной сетке 6×N не возвращаемся.
> **Кто пишет код:** AI-агент в Cursor.
> **Кто тестирует:** разработчик (Roblox Studio + Rojo).
> **Статус:** Фазы 0–14 + 16 + **17** закоммичены 🟢. Помимо MVP реализованы и закоммичены **пост-MVP системы вне исходного scope**: промокоды, соц-награда, egg shop с 6 типами яиц, баффы, мутации руды, повторяемые ежедневки, hub-зоны, world-leaderboard, mine-deck collision, responsive-layout HUD. Фаза 5 — ждёт плейтест-профайл. Фаза 14 — финальные PNG в Creator Hub грузит разработчик. **Фаза 15 (soft launch) — 🔴** (блокеры: реальные id монетизации, непройденный плейтест Фазы 5).
> **Обновлено:** 2026-07-02
> **⚠️ Честно про scope:** пост-MVP системы (см. выше) добавлены **после** закрытия MVP-скоупа и **до** первого плейтеста/soft-launch — это нарушение правила против scope creep в конце документа. Игра написана на ~35k строк без единого живого игрока. Правильнее было бы выпустить ядро через unlisted soft launch и раздать эти системы апдейтами 1.1/1.2.
> **Scope-добавление (Фаза 16):** взвешенное распределение руды (Minecraft-style), цели/квесты + подключены достижения и освещение шахты (свет на курсоре).
>
> **Правило документа:** цифры контента, навигация HUD и поведение механик сверяются с **кодом** (`src/`), а не с устаревшими записями в STATUS. При расхождении — правда в коде.

---

## Снимок актуального состояния (код, 2026-07-02)

| Область | Факт в коде | Было в старых версиях MVP |
|---------|-------------|---------------------------|
| **Руды** | **55** записей в `OreDatabase` (**54** discoverable в журнале + `test_glow` weight=0) | «31 руда» |
| **Слои** | 7 (dirt → void), milestone 2.5k → 25M coins | Совпадает |
| **Питомцы** | **30** playable (`PetDatabaseEntries.lua`), 3D-модели через `PetModelKit` | «10 петов» |
| **Яйца** | **6** типов в `EggPoolDatabase` (`basic`, `desert`, `candy`, `ocean`, `lava`, `explosive_hydro`), по 6 взвешенных петов; egg shop + Robux-прайсинг (`EggMonetization`) | Раньше: «1 рабочее, остальные ждут» — **добавлено вне MVP** |
| **Апгрейды** | 7 | Совпадает |
| **Квесты** | 10 sequential (`QuestLogic.lua`) + **3 повторяемых ежедневки** (`DailyQuestLogic`) | Раньше: только 10 |
| **Достижения** | 7 (`AchievementManager.lua`, server-only); `boss_slayer` hidden | Совпадает |
| **Промокоды** | **2** (`PromoCodes.lua` + `PromoCodeManager` + `RedeemCode`) — **вне MVP** | Не было |
| **Соц-награда** | join группы + favorite → награда (`SocialRewardManager`) — **вне MVP** | Не было |
| **Баффы** | 5 видов (`BuffMeta`: damage/luck/coin/multiMine/speed), `BuffBar` — **вне MVP** | Не было |
| **Мутации руды** | `MutationLogic` + `Constants.MUTATIONS` (шанс + вариант + бонус монет) — **вне MVP** | Не было |
| **HUD layout** | `CurrencyRibbon` + `InventoryWidget` + `LeftSidebar` dock + modal `MainPanel`; **responsive** (`ViewportLayout`: phone/tablet/desktop) | Старый `TabBar`/`TopBar` deprecated |
| **Навигация** | Dock: inventory / upgrades / goals / journal / more + sell; **More → pets, stats, rebirth, leaderboard, shop**; hub-зоны SELL/UPGRADE + world-leaderboard на поверхности | Ранее «pets без кнопки» — исправлено |
| **Освещение шахты** | `Constants.HEADLAMP.enabled = false`; активен **`CURSOR_LIGHT`** в `MiningRenderer` | «Фонарик на персонаже» |
| **Визуал руд** | Low-poly: `color` + `protrusion="crystal"`, `OreShellMeshes`, `OreFXPalette`, `OreBlockDecor`; **material/reflectance/glow сняты** | Фаза 14: материалы Slate/Foil/Glass |
| **Иконки руд** | 54 baked `OreIconPixels/*.lua` + PNG в `assets/ui/ores/` | Не описано |
| **Монетизация** | 3 gamepass + 3 devproduct + egg-devproducts (авто-инжект), все **`id = 0`** (блокер покупок) | Совпадает |
| **Гемы** | Начисляются (квесты/ачивки/промокоды), **нет UI и трат** | Совпадает (скрыты) |
| **Античит** | CPS/batch/swing для копания; глубина — **server-clamp** к позиции персонажа (`serverDepthFor` + slack), reach-хелпер `MiningReach` есть (проверить wiring в `MineBlock`) | Раньше: «глубина client-trusted» |
| **Тесты / CI** | **0 тестов, нет CI**; `selene`/`stylua` в `rokit.toml`, но без конфигов и не форсятся | Не описано — **долг качества** |
| **Объём** | **~35k строк / 230 .lua** в `src/` (client 109 / shared 96 / server 25); `MiningRenderer` ~1.8k строк | «~19k / ~176» (устарело) |

---

## Что вне scope MVP

**Принцип:** добавляем только то, что **обязательно** для жанра на Roblox в 2026. Всё «усиливающее» работающую игру → патчи 1.1, 1.2.

- Боссы (в оригинальной игре их нет).
- Trading между игроками (требует античита + UI, патч 1.1).
- Гильдии / кланы (жирная фича, патч 1.2+).
- ~~Achievements~~ — **подключены в Фазе 16** (модуль `AchievementManager` + UI в табе 🎯 ЦЕЛИ).
- Limited-time events (работают только когда есть аудитория).
- NPC в шахте, сейсмические события, биом-вариации (атмосферные фичи на потом).
- Mine Shafts как отдельная механика — используем уже реализованные **скрытые комнаты**.
- Полировка **игрового ощущения** слоёв глубже Stone — в коде уже есть `LayerProfile` + `LayerAmbience` + звуки для **всех 7 слоёв**, но QA/баланс и «feel pass» ориентированы на Dirt + Stone (limestone+ без отдельного плейтест-чеклиста).
- Нефть, ауры, крафт, расходники (молоток, бомба).

Всё это — **post-MVP** контент.

> ⚠️ **Что фактически построено вопреки этому разделу (до soft-launch):** промокоды, соц-награда, egg shop с 6 типами яиц, баффы, мутации руды, повторяемые ежедневки, hub-зоны, world-leaderboard, responsive-layout. Это ретроспективный урок: перечисленное следовало держать в патчах 1.1/1.2 и выпустить ядро раньше. Раздел оставлен как есть — расхождение между планом и фактом само по себе документирует scope creep.

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
8. Купить **gamepass** или **coin pack** через Roblox (3 gamepass + 3 devproduct — логика готова, **реальные id в Creator Hub ещё 0**).
9. Выйти и вернуться — прогресс тот же (ProfileService), питомцы и ребёрты сохранены.
10. **Открыть журнал находок** (таб 📖 в dock): видеть «???» до первой добычи, после удара — имя/иконка руды (pixel/PNG); при полном слое — milestone-монеты и тост. Каталог: **54 руды**.
11. Играть 30+ минут подряд с **ощутимым «соком»** ударов (звуки, screen shake, particles) без утечек FPS.
12. Получить **3 туториал-подсказки** в первые 30 секунд (клик → продай → купи кирку).
13. **Видеть цель** (таб 🎯 ЦЕЛИ в dock): активный квест с прогрессом, забрать награду, разблокировать достижения — есть ради чего копать. Цепочка: **10 квестов**.
14. Видеть блок под курсором (**свет на курсоре**, `CURSOR_LIGHT` в `MiningRenderer`); атмосфера глубины — тёмная (`LayerEnvironment` + fog). Модуль `Headlamp` есть, но **`HEADLAMP.enabled = false`**.

**Retention-принцип (не Pet Simulator):** цель охоты — **руда и слои глубины**, петы — инструмент. Без **Ore Discovery Index** нет долгосрочной мотивации «найти всё» → удержание падает.

---

## Дефолты (зафиксированы)

- **Все 7 апгрейдов** из `Constants.UPGRADES`: pickaxe, speed, fortune, inventory, crit, multiSell, autoSell.
- **Штраф x0.5** урона по Stone при `pickaxeLevel < 5`.
- **Гемы** в HUD скрыты до post-MVP (поле `playerData.gems` копится с квестов/ачивок, UI и sink'и — позже).
- **Скрытые комнаты** уже в коде (`SHAFT_*` в Constants) — отдельные Mine Shafts не добавляем.
- **Мёртвые поля данных** (не трогаем до post-MVP): `OreDef.xp` (нигде не читается), `oil_deposit` (`value=0`, `dropsOil=true`), `playTime` (не инкрементируется), `shaftsFound[]` (используется `shaftRoomCount`).

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
| 8–9 | 11 | ✅ **Pets MVP**: **30 питомцев** (3D `PetModelKit`), 1 egg type, multi-slot equip, hatch FX |
| 10 | 12 | ✅ Монетизация: 3 game-passes, 3 DevProducts (coin packs + egg10) |
| 11 | **13** | ✅ **Ore Discovery Index**: таб 📖 ЖУРНАЛ, **54 discoverable руды**, milestone за полный слой |
| 12 | 14 | ✅ Визуальный пасс: low-poly идентичность руд, lighting по слоям, Creator Hub бриф (PNG — вне кода) |
| 12 | **16** | ✅ Распределение руды (взвешенный спавн) + Цели (квесты, достижения) + свет на курсоре |
| 13 | **17** | **UI/UX overhaul**: dock-HUD, кастомные иконки, LayerAmbience, ore-shell meshes |
| 13–14 | 15 | Soft launch: 2-player playtest, balance fixes, релиз unlisted → public |

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
- **`shared/data/UiAssets.lua`** + `assets/ui/*.png` (Rojo → `ReplicatedStorage.uiAssets`) — единый реестр иконок HUD/апгрейдов; rbxassetid в проде, локальные PNG для итерации.
- **`shared/data/OreAssets.lua`** + `OreIconPixelLoader` + `OreIconPixels/*.lua` (54 модуля) — baked 64×64 иконки руд; пайплайн `tools/bake_ore_icons.py`.
- **`shared/data/LayerProfile.lua`** — идентичность слоёв (ambient, туман, пыль, block-glow); читают `LayerAmbience` и `MiningRenderer`.
- **`shared/util/PetModelKit.lua`** — монтирование 3D-моделей петов (viewport + followers).
- **`client/core/EggMachines.lua`** — ProximityPrompt на `Workspace.Eggs` (только `basic` реально открывает hatch).
- **`client/ui/HomeFX.lua`** + `Net:Invoke("GoHome")` — iris-wipe телепорт на spawn.
- **`server/core/PlayerTag.lua`** — BillboardGui над головой: rebirth tier + VIP override.
- **`client/ui/util/{UiInteract,UiMotion}.lua`** — hover/press для dock-кнопок (desktop hover, mobile press-only).
- **`shared/util/{OreFXPalette,OreShellMeshes}.lua`** — палитра VFX руды и mesh-накладки rare/epic+ на блоки.

Балансные числа жить только в `shared/constants.lua` (Constants.UPGRADES, Constants.LAYERS, и т.п.). Профили слоёв для атмосферы — в `LayerProfile.lua`.

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
- [x] `OreDef` расширен полями `weight` (Фаза 16), `protrusion` (Фаза 17), опциональными `dropsOil` / `isGeode`. Поля `material`/`reflectance`/`glow` в типе остались, но **в данных не заполняются** (low-poly pass).
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
- [x] **Мини-задания** (`client/ui/tutorial/TutorialTracker.lua`): квест-трекер справа с заголовком «Задание N из 3», описанием и опциональным progress bar. На выполнение — заполнение до конца, цвет → зелёный, анимированный ✓ (Back/Out 0.3с), auto-hide через 1.4с.
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
- [x] **Что сохраняется при ребёрте**: `rebirths`, `rebirthMultiplier`, `totalCoinsEarned`, `totalBlocksMined`, `maxDepthReached`, `bossesDefeated`, `playTime`, `tutorialStep`, `firstSession`, **`pets` / `equippedPet`**, **`discoveredOres` / `discoveredMilestones`**, `claimedQuests`, `unlockedAchievements`, `gamepasses`, `dailyState`, `activeBoosts`. **Сбрасывается**: `coins=0`, `inventory={}`, все `*Level=1`, `autoSellUnlocked=false`, `depth/layer/_stoneLayerNotified`.
- [x] **Что усиливается**: множитель `1 + rebirths * 0.1` к value руд в `SellInventory.execute` (после `multiSellMultiplier`); `UpgradeLogic.maxLevel(upgradeId, rebirths)` даёт +1 к maxLevel pickaxe на каждом перейденном пороге `Constants.REBIRTH.pickaxeMaxBonusAt = {5, 10, 25}`.
- [x] **UI**: таб REBIRTH в modal `MainPanel` (доступ через dock → «Ещё» → rebirth), `RebirthPanel.lua` с заголовком «Ребёрты: N / Множитель: x1.X», крупной кнопкой REBIRTH (disabled при недостатке монет, текст «Не хватает X 💰»), описанием «Что сохранится / сбросится / следующий бонус кирки». Чип ребёрта в `CurrencyRibbon` при `rebirths > 0`.
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
- [x] **TopBar чипы** → **`CurrencyRibbon` чипы** (Фаза 17): `BoostChip.lua` (visible при `#activeBoosts > 0`, локальный countdown «⚡ x2 · 29:42», RGB-cycle `UIStroke` через `RunService.Heartbeat`), `StreakChip.lua` (visible при `streak >= 2`, «🔥 N дней»). StatsPanel показывает streak + ранги лидерборда.
- [x] **Глобальный лидерборд** (`server/core/Leaderboard.lua` переписан): `MemoryStoreSortedMap` × 2 (`Leaderboard_Coins_v1`, `Leaderboard_Depth_v1`), ключ = `"user_<userId>"`, значение = integer score, `expirationSeconds = 30 days` TTL. `writeIfChanged` через `LeaderboardLogic.shouldWrite` (delta >= `writeThresholdCoins=100`/`writeThresholdDepth=5`). Дёргается из `onEconomyChanged` (после продажи) и `RebirthManager`. Имена игроков — `Players:GetNameFromUserIdAsync` + локальный `nameCache`. Refresh раз в 30с с retry exp-backoff `2/4/8с` на ошибки MemoryStore. `Net:Function("RequestLeaderboard")` с server-side throttle 5с на игрока.
- [x] **UI лидерборда** (`client/ui/hud/panels/LeaderboardPanel.lua` + `hud/components/LeaderRow.lua`): таб 🏆 в `MainPanel` (dock → «Ещё» → leaderboard), toggle «💰 Монеты / ⬇ Глубина», spotlight-карточка топ-1 с короной 👑 + золотой gradient + pulse-glow, ScrollingFrame top-2..top-50, footer «Вы: #N» если игрок вне топ-50, countdown «Обновится через Ns» справа сверху. **Avatar thumbnails**: `Players:GetUserThumbnailAsync(userId, HeadShot, Size150x150)` async, кэш в module-level `{ [userId] = imageId }`, skeleton-placeholder до загрузки, fade-in при готовности. Loading skeleton (10 строк) до первого fetch'a, «Сервис недоступен, обновляем...» при ошибке.
- [x] **HUD-payload расширен**: `buildHudPayload` шлёт `dailyState { canClaim, currentStreak, nextDay, secondsUntilNextDay, totalDaysClaimed }`, `activeBoosts` (с `remainingSeconds` на момент payload'а) и `leaderboardPlacement` ({coinsRank, depthRank, coinsValue, depthValue}). `PlayerDataMapper` + `HudState` синкают мгновенно. ProfileService template-мердж добавил поля старым профилям без миграции.
- [x] **`Net:Connect("PlayerStats")`** в `init.client.lua`: при `dailyState.canClaim == true` и `_autoOpenedThisSession == false` автоматически открывает `DailyRewardModal`. `kind="daily_available"` в Notify — переоткрытие модала после полуночи без перезахода.
- [x] **`Constants.DAILY`** (`cycleDays=7`, `grantBoostAtDay7=true`, `streakResetAfterMissedDays=2`, `rolloverCheckInterval=60`) + **`Constants.LEADERBOARD`** (`COINS_MAP/DEPTH_MAP` ключи, `topSize=50`, `refreshIntervalSeconds=30`, `expirationSeconds=30 дней`, `writeThresholdCoins=100`, `writeThresholdDepth=5`). Версионируем `_v1` — при изменении схемы старый лидерборд остаётся как archive.

**Тест:** свежий профиль → автоoпен `DailyRewardModal` с Day 1 highlighted → [ЗАБРАТЬ] (после 0.4с) → coin-rain + sell_success звук + закрытие → `CurrencyRibbon` показывает 🔥 1 + +500 монет через AnimatedNumber. `/setday +1` → перезаход → Day 2 (Day 1 ✓). `/setday +3` → стрик сброшен в 1. 7 итераций `/setday +1` → Day 7 даёт +50k + 30-min x2 boost → `BoostChip ⚡ x2 · 29:59` тикает → продажа руды на +100% монет. Реальное время: вход в 23:55 UTC → ждать → notify «Новая награда!» без перезахода. Dock → Ещё → leaderboard → skeleton ~2с → топ-50 с avatar'ами. Toggle монеты/глубина — оба board'a в state. Перезаход в boost'е — выживает (expiresAt в профиле). `/reset` НЕ трогает dailyState/activeBoosts; `/resetdaily` отдельно.

**Дата закрытия:** 2026-06-02.

---

### █ Фаза 11 — Pets MVP 🟢

**Цель:** жанро-определяющая механика. Без неё mining-игра не выживает на Roblox.

- [x] **`shared/data/PetDatabaseEntries.lua`** + **`PetDatabase.lua`**: **30 питомцев**, rarity common×6 / uncommon×6 / rare×6 / epic×5 / legendary×4 / mythic×3. Эффекты: `damageBoost`, `luckBoost`, `coinBoost`, `multiMine`. Каждый пет — `{ id, name, rarity, icon, modelName, color, effect }`. 3D `modelName` для `PetModelKit`.
- [x] **`server/core/PetManager.lua`**: DI-менеджер (паттерн RebirthManager/DailyReward). `Net:Handle("HatchEgg", count)` (валидация монет, weighted roll, append в `playerData.pets`, авто-equip первого), `Net:Handle("EquipPet", uid)`, `Net:Handle("UnequipPet")` — **multi-slot** (до `PetLogic.maxEquipped`, +2 через gamepass). `onProfileLoaded` (ensure-поля + чистка битых equipped uid). Dev: `devHatch/devGivePet/devClearPets`, `grantHatch` для dev products.
- [x] **`server/core/PetAssetBootstrap.lua`**: клон `Workspace.Pets`/`Eggs` → `ReplicatedStorage.PetKit`.
- [x] **`server/core/EggManager.lua`**: 1 рабочий egg type («basic», 1000 coins), `clampCount` (batch 1..10), `totalCost`, `hatch` → `PetLogic.rollHatch`.
- [x] **`client/ui/hud/panels/PetsPanel.lua`**: hatch Basic Egg 1×/10×, грид owned-петов, equip/unequip. Доступ: **dock → «Ещё» → pets** (`LeftSidebar.MORE_TABS`).
- [x] **`client/ui/hud/components/PetCard.lua`** — карточка пета (rarity-stroke, ZIndex 2+ на тексте).
- [x] **Pet visual** (`client/ui/PetVisual.lua`): **3D-клоны** через `PetModelKit.clonePetDisplay`, follow за игроком (arc slots, bobbing). Не emoji-сфера.
- [x] **Hatch animation** (`client/ui/PetHatchFX.lua`): полноэкранный overlay — ViewportFrame яйцо, тряска → rarity shockwave → reveal-карточки с 3D preview. 1× и 10×, tap-to-skip, авто-закрытие ~2.8с.
- [x] **`client/core/EggMachines.lua`**: ProximityPrompt на моделях в `Workspace.Eggs`; только **Basic** реально hatch'ит, остальные — toast «скоро» / «используй меню питомцев».
- [x] **`Net:Handle("HatchEgg", count)`** — батч до 10 (`Constants.PETS.hatchBatchMax`).
- [x] **Эффекты** (`shared/util/PetLogic.lua`): damage → `MiningEngine`; luck → комнаты; multiMine → bonus block; coinBoost → `SellInventory` (аддитивно в boost-стадию).
- [x] **DevCommands**: `/egg [N]`, `/hatch`, `/pet <id>`, `/clearpets`.

**Тест:** купил Basic Egg → HATCH → анимация → пет в инвентаре → equip → урон вырос. 10× работает. Dock → Ещё → pets открывает панель.

**Дата закрытия:** 2026-06-03 (контент расширен до 30 петов + 3D — Фаза 17 WIP).

---

### █ Фаза 12 — Монетизация 🟢

**Цель:** revenue stream для итераций после запуска.

- [x] **Game-passes** (`Constants.GAMEPASSES`, id=0 плейсхолдер до Creator Hub):
  - VIP (399 Robux): +10% монет (`MonetizationLogic.coinBoost` → boost-стадия SellInventory аддитивно с daily/pet), титул «👑 VIP» + золотой ник (BillboardGui на Head).
  - Auto-sell (599 Robux): `autoSellUnlocked = true` навсегда при владении.
  - +2 pet slots (799 Robux): `PetLogic.maxEquipped(data)` = 1 + 2 = 3; multi-slot equip (список uid'ов).
- [x] **DevProducts** (`Constants.DEVPRODUCTS`):
  - Small Coin Pack (99 Robux): 10k coins.
  - Medium Coin Pack (399 Robux): 100k coins.
  - Egg 10x (199 Robux): 10 яиц через `PetManager:grantHatch` + `kind="egg_purchase"` → PetHatchFX.
- [x] **`server/core/MonetizationManager.lua`**: DI (profileManager, onProfileChanged, notify, petManager). `ProcessReceipt` + DataStore `PurchaseHistory_v1` (защита от двойного начисления). `PromptGamePassPurchaseFinished` + `onProfileLoaded` → `UserOwnsGamePassAsync` (source of truth) → кэш `playerData.gamepasses`. DevHooks: `devGrantPass` / `devGrantProduct`.
- [x] **`shared/util/MonetizationLogic.lua`**: единый источник формул (ownsGamepass, coinBoost, petSlotBonus, lookup by id).
- [x] **UI Shop**: `ShopPanel` (dock → «Ещё» → shop) + `ShopCard`, PURCHASE → `PromptGamePassPurchase` / `PromptProductPurchase` (disabled при id=0 + подсказка Studio).
- [x] **Owned status**: gamepasses в payload → VIP через `PlayerTag`/`MonetizationManager` (BillboardGui на Head), ShopPanel «✓ КУПЛЕНО», PetsPanel «слотов N/3», auto-sell через `autoSellUnlocked` в upgrades.
- [x] **DevCommands**: `/grantpass <key>`, `/grantproduct <key> [N]` (эмуляция в Studio).

**Тест:** `/grantpass vip` → VIP tag на голове, продажа +10% монет. `/grantpass autoSell` → auto-sell при полном инвентаре. `/grantpass petSlots` → экип 3 петов, «слотов 3/3». `/grantproduct coinsSmall` → +10k. `/grantproduct egg10` → PetHatchFX 10×. В проде: подставить реальные id в Constants → unlisted → тест-Robux.

**Дата закрытия:** 2026-06-03.

---

### █ Фаза 13 — Ore Discovery Index (Журнал находок) 🟢

**Цель:** ключевое удержание — коллекционирование **руды** (не петов). Игрок видит прогресс «Открыто N/M», охотится за редкими находками и закрывает слои ради milestone-монет.

- [x] **`shared/util/DiscoveryLogic.lua`**: каталог **54 discoverable** руд из `OreDatabase` (без `test_*`), прогресс по слою/всего, `milestoneReward(layerId)`.
- [x] **`Constants.DISCOVERY.layerMilestoneCoins`**: разовая награда за **полностью** открытый слой (dirt → void), без ретро-выдачи при миграции.
- [x] **`playerData`**: `discoveredOres`, `discoveredMilestones` — **не сбрасываются** при ребёрте.
- [x] **`server/core/DiscoveryManager.lua`**: `recordDiscovery` при `loot.added > 0` (основная + bonus multiMine руда), notify `kind="ore_discovered"` / `kind="layer_milestone"`, `onProfileLoaded` бэкфилл из инвентаря (тихо).
- [x] **MineBlock** (`init.server.lua`): хук после `MiningLoot.tryAddOre`, `buildHudPayload` шлёт `discoveredOres`, `discoveredMilestones`, `discoveryProgress`.
- [x] **UI**: таб 📖 **ЖУРНАЛ** в dock (`JournalPanel` + `OreEntry` с pixel/PNG иконками через `OreIcon`), заголовок «Открыто X/Y» по слоям.
- [x] **DevCommands** (Studio): `/discover <oreId>`, `/discoverall`, `/resetjournal`.
- [x] **Клиент Notify**: `OreDiscoveryFX` (reveal «НОВАЯ НАХОДКА» + очередь), `RewardFX` на milestone; звук break/sell.
- [x] **Визуал блоков по редкости** (эволюция Фаз 13→17): low-poly `color` + jitter, `protrusion="crystal"` на самоцветах, `OreShellMeshes` накладки, `LayerProfile.BLOCK_GLOW` caps, proximity PointLights (epic+), ambient particles из `ReplicatedStorage.OreAmbientFX`, `OreFXPalette` tint. Старые `OreDef.material/reflectance/glow` **сняты** в low-poly pass.

**Тест:** `/discover coal` → запись в журнале + тост. Добыть новую руду в игре → тост + слот открыт. Закрыть все руды слоя Dirt → milestone-монеты + тост. Ребёрт → журнал на месте. Перезаход → тот же журнал.

**Дата закрытия:** 2026-06-03 (коммит `55b6a7c`, вместе с Фазой 12).

---

### █ Фаза 14 — Визуальная идентичность 🟢

**Цель:** игра выделяется в Roblox Discover и узнаётся как mining-sim; спуск вглубь ощущается атмосферой.

- [x] **Материалы по слоям** (Фаза 14, **заменено в Фазе 17**): изначально заполнялись `OreDef.material/reflectance/glow`; в low-poly pass перешли на `color` + `protrusion` + shell meshes. Коммит Фазы 14 (`e1ce55e`) — исторический; актуальный визуал — Фаза 17.
- [x] **Lighting по слоям** (`Constants.LAYER_LIGHTING` + `client/core/LayerEnvironment`): твин `Brightness`, `ClockTime`, `FogEnd` и `Atmosphere` — dirt (полдень) → void (почти тьма). Без fullscreen post-processing.
- [x] **Creator Hub бриф** (`docs/marketing/CreatorHub.md`): название RU/EN, описание, genre tags, pipeline загрузки.
- [x] **Чеклист ассетов** (`docs/marketing/assets/`): icon, thumbnails, key art brief.
- [ ] **Финальные PNG в Creator Hub** (вне кода): icon, thumbnails — загружает разработчик.
- [ ] **icon-тест 5 людей** (плейтест): угадывают «копание/шахта» по 64×64.

**Тест (Studio smoke):** Play Solo → смена освещения Dirt→Stone; rare-руды визуально отличаются (shell/glow/protrusion). Полный чеклист — `STATUS.md`.

**Критерий готовности:** 5 человек по иконке понимают «копание/шахта»; rare-руды отличимы от common; переход Dirt→Stone ощущается атмосферой.

---

### █ Фаза 16 — Распределение руды + Цели 🟢

**Цель:** дать шахте узнаваемое Minecraft-распределение руды (наполнитель доминирует, редкости — редки) и понятную цель/прогрессию — игроку должно быть ради чего копать. Плюс убрать жалобу «в шахте темно». Добавлено по запросу разработчика до soft-launch.

**Распределение руды (Minecraft-style):**
- [x] **`OreDef.weight`** в `shared/data/OreDatabase.lua` — вес спавна внутри слоя: наполнитель ~900, вторичные common 60–130, uncommon 14–30, rare 3–6, epic 2–4, legendary/mythic 1. `test_glow` weight=0 (не спавнится). В каждом слое доминирует «свой» наполнитель (Dirt ≈78% грязи).
- [x] **`MiningEngine:_roll`** переписан на единый взвешенный ролл по пулу слоя (`_oreWeight` = `weight` или fallback `Constants.RARITY_DEFAULT_WEIGHT[rarity]`, `weight<=0` пропускается). Старый двухшаговый rarity-ролл убран.
- [x] **`Constants.RARITY_DEFAULT_WEIGHT`** — fallback-веса для руд без явного `weight`.

**Цели / квесты:**
- [x] **`shared/util/QuestLogic.lua`** — единственный источник цепочки квестов (~10 шт), `metric` ∈ blocksMined / coinsEarned / depth / oresDiscovered / rebirths / shaftRooms. Прогресс выводится из существующих счётчиков профиля (без отдельного per-event трекинга). `activeQuest` / `isComplete` / `buildActivePayload` / `claimedCount` / `totalCount`.
- [x] **`server/core/QuestManager.lua`** — DI (паттерн DiscoveryManager). `onProfileLoaded` (ensure `claimedQuests`), `evaluate` (тост «забери награду» один раз на квест), `claim` (валидирует активный+выполненный+незабранный, начисляет `reward.coins/gems`, `claimedQuests[id]=true`). DevHooks `devResetQuests` / `devCompleteActive`.
- [x] **`playerData.claimedQuests`** — список забранных квестов, **не сбрасывается** при ребёрте.
- [x] **UI** (`client/ui/hud/panels/GoalsPanel.lua`): таб 🎯 ЦЕЛИ в dock — активный квест с прогресс-баром, наградой (coins + gems, gems в UI награды видны, в ribbon — нет) и кнопкой [ЗАБРАТЬ] (`Net:Invoke("ClaimQuest", id)`), «✅ Все цели выполнены!» в конце. Badge на иконке goals при claimable.
- [x] **`Net:Handle("ClaimQuest")`** + хуки `questManager:evaluate` в MineBlock / processDepthUpdate / onEconomyChanged.

**Достижения (подключение существующего модуля):**
- [x] **`server/core/AchievementManager.lua`** — был заглушкой, подключён: персист в `playerData.unlockedAchievements`, `check` начисляет награды + тост `kind="achievement_unlocked"`. Починены заглушки `check` (`collector_10` → DiscoveryLogic, depth → `maxDepthReached`, `shaft_finder` → `shaftRoomCount`); `boss_slayer` `hidden=true` (боссов в MVP нет).
- [x] **`playerData.unlockedAchievements`, `shaftRoomCount`** — персист, переживают ребёрт. `shaftRoomCount++` при `roomGenerated` в MineBlock.
- [x] **UI**: список достижений в `GoalsPanel` (✓ для разблокированных, награда для остальных), `buildHudPayload` шлёт `achievements` (только видимые).

**Освещение шахты (видимость):**
- [x] **`Constants.CURSOR_LIGHT`** + реализация в **`MiningRenderer`** — `PointLight` следует за лучом мыши/тача, освещает блок под прицелом. **Активный способ** видимости в шахте.
- [x] **`client/core/Headlamp.lua`** — модуль сохранён, но **`Constants.HEADLAMP.enabled = false`** (свет перенесён на курсор). При включении: PointLight на HRP, масштаб с глубиной.
- [x] **Интеграция** (`init.client.lua`): `Headlamp.attach/setDepth` вызывается, но no-op пока `enabled=false`.

- [x] **DevCommands**: `/resetquests`, `/completequest`.

**Тест:** копать Dirt → доминирует грязь; таб 🎯 → квест растёт; collector_10 при 10 находках; **свет на курсоре** освещает блок под прицелом; перезаход/ребёрт → квесты/журнал на месте. Полный smoke — `STATUS.md`.

**Дата закрытия:** 2026-06-03 (коммит `2d311dd`).

---

### █ Фаза 17 — UI/UX Overhaul (discovery-ready polish) 🟢 (закоммичено)

**Цель:** HUD уровня топовых Roblox mining-sim — читаемый dock, кастомные иконки, модальные панели, атмосфера слоёв. Без этого игра выглядит «прототипом» в Discover.

**Новый layout HUD** (заменяет TopBar + горизонтальный TabBar):
- [x] **`CurrencyRibbon`** — левый верх: монеты (`ResourceChip` + `UiAssets.coin`), `DepthBar` (глубина + прогресс слоя), чипы ребёрта / boost / streak.
- [x] **`InventoryWidget`** — правый верх: заполненность рюкзака (суммарный count / capacity), цвет fill-bar по заполнению.
- [x] **`LeftSidebar`** — нижний центрированный dock: 5 nav (рюкзак, кирка, цели, журнал, «ещё») + кнопка **ПРОДАТЬ** + **Home pill** (`GoHome` + `HomeFX`); popup «Ещё» → **pets**, stats, rebirth, leaderboard, shop.
- [x] **`MainPanel`** — модальное окно 600×450 с backdrop, scale-in анимацией, цветной header по активному табу; все 9 content-панелей внутри (`panelOpen` / `activeTab` в `HudState`).
- [x] **`DockIcon`** + **`UiInteract`/`UiMotion`** — иконка 30px + hover/press scale; sell-вариант — зелёный CTA.
- [x] **`theme.lua`** — modern dark navy палитра, `TAB_ACCENTS`, `TAB_LABELS`, `LAYER_COLORS`.
- [x] **`shared/data/UiAssets.lua`** — реестр 19 иконок (coin, depth, tab_*, upg_*); rbxassetid в `ROBLOX_IMAGES`, fallback на `ReplicatedStorage.uiAssets` (`tab_pets` rbxassetid пуст — PNG fallback).
- [x] **`assets/ui/`** + **`assets/ui/ores/`** — PNG 256×256 + `prepare_icons.py` / `prepare_ore_icons.py`; Rojo → `uiAssets`.
- [x] **`UpgRow`** — кастомные иконки апгрейдов через `UiAssets.upgrade()`.
- [x] **`SellButton.activate()`** — логика продажи отвязана от виджета; вызывается из dock.

**Атмосфера и визуал блоков:**
- [x] **`LayerProfile.lua`** — `IDENTITY` (music, enter-sound, particles, fog, breakDust) + `BLOCK_GLOW` (per-layer rarity glow); `Constants.LAYER_PROFILE` — алиас.
- [x] **`LayerAmbience.lua`** — ambient при смене слоя: enter-звук, ParticleEmitter (sparkle + fog) на персонаже, интеграция в `init.client.lua`.
- [x] **`OreFXPalette.lua`** — единая палитра VFX для `MiningRenderer` и `OreDiscoveryFX`.
- [x] **`OreShellMeshes.lua`** — mesh-накладки rare/epic+ (Kit в Workspace/ReplicatedStorage).
- [x] **`MiningRenderer`** — shell meshes, layer-aware block glow, layer break-dust, `OreFXPalette` tint, cursor light, create-budget 25/frame, ~1.9k строк.
- [x] **30 питомцев** + **3D PetVisual** + **PetModelKit** (расширение Фазы 11).
- [x] **54 baked ore icons** (`OreIconPixels/`).

**Техдолг / блокеры до закрытия фазы:**
- [ ] **Legacy-панели** — `TabBar.lua`, `TopBar.lua`, `BottomDock.lua` не монтируются; удалить после smoke.
- [ ] **Tutorial smoke** — сцены ищут `Tab_inventory` / `SellButton`; `DockIcon` сохраняет `Tab_<tabId>` — нужен плейтест нового layout.
- [ ] **Mobile layout** — fixed 600×450 modal, dock ~446px; только `DailyRewardModal` адаптивен. Post-MVP или до soft launch — решить.
- [ ] **OreDiscoveryFX** — проверить fade-out (возможная ссылка на неверную переменную).
- [ ] Studio smoke + **коммит** незакоммиченных изменений Фазы 17.

**Тест:** Play Solo → dock снизу, ribbon сверху; клик таба → модалка; ПРОДАТЬ → монеты; Ещё → pets; смена слоя → ambient; rare-руда с shell. Чеклист — `STATUS.md`.

---

## Известные пробелы до soft launch (код, не scope creep)

Это **не новые фичи**, а дыры между «MVP по чеклисту» и «можно пускать игроков»:

| Приоритет | Проблема | Где в коде |
|-----------|----------|------------|
| **P0** | Глубина **client-trusted** — spoof `maxDepthReached`, depth leaderboard, квесты | `init.server.lua` → `UpdateDepth` |
| **P0** | Gamepass/DevProduct **`id = 0`** — реальные покупки невозможны | `constants.GAMEPASSES`, `DEVPRODUCTS` |
| **P0** | Фаза 17 **не закоммичена** | git working copy |
| **P1** | Нет reach-validation для mine clicks | `AntiCheat` + `MiningEngine` |
| **P1** | Плейтест Фазы 5 (FPS, delta traffic) не пройден | `STATUS.md` чеклист |
| **P1** | Sound IDs — `TODO playtest`, broken → тишина | `SoundDatabase` |
| **P1** | `millionaire` aura reward не применяется | `AchievementManager` |
| **P2** | Достижения только на server (не в `shared/`) | архитектурный долг |
| **P2** | Pets за 2 тапа (dock → Ещё) — слабая discoverability | `LeftSidebar` |
| **P2** | После 10 квестов — мало долгосрочных целей | контент, патч 1.1 |

---

### █ Фаза 15 — Soft Launch & Стабилизация 🔴

**Цель:** релиз с минимальным риском.

**Предусловия (из таблицы пробелов выше):** P0 закрыты — depth validation, Creator Hub ids, коммит Фазы 17.

- [ ] Solo плейтест 30+ минут подряд (сам разработчик).
- [ ] Тест с 2 игроками (одновременно копают, проверка `playerData` изоляции).
- [ ] Перезаход: прогресс совпадает, питомцы на месте, gamepasses активны.
- [ ] Стресс быстрых кликов: античит срабатывает.
- [ ] Выход во время автосейва: профиль не теряется.
- [ ] **Unlisted release**: 10–20 друзей/Discord-знакомых играют 3 дня.
- [ ] Сбор фидбека → 1 баланс-патч.
- [ ] **Public release** + первые 1–2 промо-поста в Roblox-сообществах.
- [ ] Чек по списку «MVP готов» — все **14** пунктов зелёные (включая реальные id монетизации).

---

## После MVP (патчи 1.1, 1.2)

**Патч 1.1** (через 2 недели после релиза):
- Trading между игроками (P2P UI, античит).
- 2-й и 3-й egg types (desert, candy — `EggMachines` уже ждут) + баланс hatch weights.
- Расширение цепочки квестов (сейчас **10**) + новые достижения (сейчас **7** видимых).
- Server-side depth validation (если не успели до launch).
- Gem UI + первый sink за гемы.

**Патч 1.2** (через месяц):
- Limestone+ **feel pass** (отдельный QA; данные/ambient уже в коде).
- Гильдии / кланы.
- Limited-time event: «Lucky Hour» — x2 luck комнат на 60 минут раз в день.

**Большие обновления (post-MVP):**
- Crimson → Marble → Obsidian → Void — контент-пассы (руды уже в `OreDatabase`).
- Mine Shafts как отдельная фича (сейчас — скрытые комнаты `SHAFT_*`).
- Расходники: молоток, бомба, auto-mine.
- Полноценная gem-экономика (сейчас только accrue).
- Боссы (`boss_slayer` achievement уже ждёт).
- Pet meta: delete/fuse/level, лимит инвентаря петов.
- NPC, сейсмические события, биом-вариации каверн.

---

## Примечания

- Сейчас в `src/` **~35k строк / 230 .lua файлов** (client 109 / shared 96 / server 25). `MiningRenderer` ~1.8k строк, `init.server.lua` ~870, `Tutorial.lua` ~850, `GoalsPanel.lua` ~635 — кандидаты на разбиение (правило ≤300 строк нарушено).
- Коммиты: `2d311dd` — Фаза 16 (2026-06). Далее ~месяц работы копился незакоммиченным; текущий коммит вносит Фазу 17 + все пост-MVP системы + синхронизацию доков. Урок: коммитить мелко и ежедневно, не копить месяц изменений в рабочей копии.
- **Долг качества:** 0 автотестов, нет CI. `selene`/`stylua` установлены (`rokit.toml`), но без конфигов и не в CI → фактически не форсятся. `--!strict` во всех файлах, но ~346 `: any` в 84 файлах (границы модулей/DI не типизированы).
- **Синхронизация документов:** при изменении контента править цифры в таблице «Снимок актуального состояния» в начале этого файла; `STATUS.md` — технический журнал, может отставать.
- AI-агент пишет код фазами; разработчик — Studio, Rojo, плейтест, фидбек по чеклисту фазы.
- Баланс настраиваем после первого 30-минутного прогона; rebirth cost ×5^N и void HP 2500 — **не playtested at scale**.
- Звуки на MVP — бесплатная библиотека Roblox; кастомные ассеты — post-MVP.

## Правило защиты от scope creep

Каждый понедельник задавать вопрос (из `.cursor/rules/code-quality.mdc`):

> «Если бы я выпустил это сегодня, что бы остановило игроков?»

- Ответ типа «нет звуков», «нет питомцев», «нет ребёрта» → продолжаем фазы.
- Ответ типа «нет trading», «нет limited events», «нет 50 питомцев» → **scope creep, в патч**.
- Ответ типа «всё нормально, можно играть» → **запускаем сейчас**, не доводим до перфекционизма.

Дисциплина: не добавлять фичу в MVP **в процессе** работы. Если идея появилась — записать в «После MVP», вернуться к ней после релиза.
