# STATUS.md — Deep Digger 🪨

> Состояние проекта, заглушки и планы.
> Обновлено: 2026-06-02 (Фаза 10 закрыта — Daily Reward + Global Leaderboard через MemoryStoreSortedMap)
> **Scope расширен:** MVP теперь launch-ready (pets, rebirth, monetization, leaderboard, daily). См. MVP.md.

---

## 🏗 Архитектура

```
Движок:      Neighbor Reveal — блоки генерируются при разрушении соседних
Поверхность: 15×15×10 (2250 блоков) при старте
Расширение:  бесконечное по X, Z, Y (6 направлений по 3D-граням)
Блок:        4.5×4.5×4.5 студа, CanCollide = true
Позиция:     Z=30 перед игроком, Y=0 на уровне ног
Ключи:       "x_z_y"
UI:          Fusion 0.3 (scope: Value, New, Computed, OnEvent)
Сеть:        SyncBlocks { kind = "snapshot" | "delta", payload }
             snapshot → один раз при заходе/reset
             delta    → { created, updated, removed } после каждого удара
Данные руд:  shared/data/OreDatabase — единственный источник правды.
             Сервер: oreDb:getAll/getOre для спавна и продажи.
             Клиент: client/core/OreLookup строит O(1) мапу oreId→OreDef
             поверх него; цвет / редкость / иконка только через лукап.
```

---

## ✅ Готово

### Сервер
| Файл | Что делает |
|------|------------|
| `init.server.lua` | Точка входа, MineBlock + дельта-флаш, depth-sync, notify; Phase 8 — поднимает `TutorialManager` и зовёт `onProfileLoaded` при заходе игрока (миграция опытных + first-time bonus); **Phase 9:** поднимает `RebirthManager` с DI `onResetBlocks` (`MiningEngine:resetPlayer` + `sendBlocksSnapshot` после ребёрта), `buildHudPayload` шлёт `rebirths` / `rebirthMultiplier`, `notify` payload расширен опциональным `kind` для FX-триггеров; **Phase 10:** Leaderboard поднимается РАНЬШЕ EconomyManager, `onEconomyChanged = syncPlayerHud + leaderboard:writeIfChanged` оборачивает write-хук (EconomyManager про лидерборд не знает — изоляция Phase 3); поднимает `DailyReward` (DI как RebirthManager), `PlayerBoosts.cleanup(activeBoosts)` в `onPlayerAdded` чистит истёкшие бусты, `leaderboard:onPlayerLeaving` в `PlayerRemoving` финализирует write + throttle-cleanup; `buildHudPayload` шлёт `dailyState { canClaim, currentStreak, nextDay, secondsUntilNextDay, totalDaysClaimed }`, `activeBoosts` (с `remainingSeconds`) и `leaderboardPlacement` |
| `core/MiningEngine.lua` | Neighbor Reveal, валидация exposed-блоков, дельта в `blockDelta` |
| `core/ProfileManager.lua` | ProfileService, автосохранение, данные игрока; **Phase 8:** в TEMPLATE добавлены `tutorialStep = 0` и `firstSession = true`; **Phase 9:** добавлены `rebirths = 0` и `rebirthMultiplier = 1.0` (денормализованный кэш `1 + rebirths * multiplierPerRebirth`); **Phase 10:** в TEMPLATE добавлены `dailyState { lastClaimYday=0, lastClaimYear=0, currentStreak=0, totalDaysClaimed=0 }`, `activeBoosts = {}` (массив `{ kind, multiplier, expiresAt }`), `leaderboardPlacement { coinsRank=nil, depthRank=nil, coinsValue=0, depthValue=0 }`. ProfileService template-мердж добавляет поля старым профилям без миграции |
| `core/AntiCheat.lua` | CPS, лимит батча `MAX_MINE_BATCH_SIZE`, swing-кулдаун |
| `core/EconomyManager.lua` | BuyUpgrade/SellOres, multiSell, autoSell |
| `core/economy/BuyUpgrade.lua` | Покупка апгрейда; Phase 8 — конкретный `message = "Не хватает N монет"`; **Phase 9:** `effectiveMax = UpgradeLogic.maxLevel(upgradeId, playerData.rebirths)` — pickaxe-MAX дрейфует с ребёртами, без правок BuyUpgrade-протокола |
| `core/economy/SellInventory.lua` | Продажа всего инвентаря по OreDatabase.value + multiSell бонус; **Phase 9:** `payout = floor(gross * multiSellMult * rebirthMultiplier)` — prestige-множитель применяется ПОСЛЕ multiSell бонуса, источник истины — `playerData.rebirthMultiplier` с фолбэком на `RebirthLogic.valueMultiplier(rebirths)`; **Phase 10:** добавлен `boostMult = PlayerBoosts.totalMultiplier(activeBoosts, "coins")` (с предварительным `PlayerBoosts.cleanup`), итоговая формула `payout = floor(gross * multiSellMult * rebirthMult * boostMult)` — порядок persistent → temporary |
| `core/MiningLoot.lua` | Fortune-ролл, capacity + autoSell |
| `core/TutorialManager.lua` | **Phase 8 (онбординг):** `Net:Handle("UpdateTutorialStep")` с валидацией (0..3, монотонный рост), миграция опытных профилей (totalBlocksMined>0 или totalCoinsEarned>0 → tutorialStep=3), first-time bonus (`Constants.STARTER_COINS` через `profile.firstSession`), `:reset()` для DevCommands |
| `core/RebirthManager.lua` | **Phase 9 (prestige):** `Net:Handle("Rebirth")` с серверной валидацией `coins >= RebirthLogic.cost(rebirths)`, `_applyRebirth` (coins=0, inventory={}, *Level=1, autoSell=false, depth=0, layer=dirt, _stoneLayerNotified=false; rebirths++, rebirthMultiplier=valueMultiplier(rebirths)), `_notifyRebirth` шлёт тост с `kind="rebirth"` для клиентского RebirthFX, `onProfileLoaded` идемпотентно пересчитывает кэш из rebirths, `devRebirth(player, n)` — DI для DevCommands. **НЕ трогает** tutorialStep / firstSession / totalCoinsEarned / maxDepthReached / bossesDefeated / shaftsFound / playTime / dailyState / activeBoosts |
| `core/DailyReward.lua` | **Phase 10 (retention):** DI как RebirthManager (`profileManager`, `onProfileChanged`, `notify`). `Net:Handle("ClaimDaily")` — серверная валидация через `DailyLogic.canClaim`, начисление монет / boost'ов через `PlayerBoosts.addBoost`, инкремент `currentStreak` (gap==1 → +1, gap==0 → already_claimed, gap >= streakResetAfterMissedDays → 1), `lastClaimYday/lastClaimYear` обновляются после grant'a, `totalDaysClaimed += 1`. `onProfileLoaded` шлёт `kind="daily_available"` если можно claim'ить (не автоclaim — игрок должен видеть satisfaction). Серверный `task.spawn(rolloverCheckInterval=60s)` watcher шлёт notify когда новый день стал доступен в активной сессии (без перезахода). `_availabilityNotified` чистится в `PlayerRemoving`. DI-методы: `devGrantDay(player, day)`, `devSetLastClaim(player, ydayOffset)`, `reset(player)`, `devAddBoost(player, kind, multiplier, durationSec)`. UTC через `os.date("!*t")` |
| `core/PlayerBoosts.lua` | **Phase 10:** модуль чистых функций. `totalMultiplier(activeBoosts, kind)` — `1 + sum(boost.multiplier - 1)` (аддитивный стек, две x2 → x3). `addBoost(activeBoosts, { kind, multiplier, durationSec })` — стек по `kind` (продлевает existing если новый expiresAt дальше). `cleanup(activeBoosts, now?)` — мутирует на месте, возвращает true если что-то удалили; вызывается в `onProfileLoaded` и в `SellInventory.execute` перед расчётом. `activeFor(activeBoosts, kind)`, `toPayload(boost, now)`, `toPayloadList(activeBoosts, now)` — для buildHudPayload (расчёт `remainingSeconds`). Истёкшие boost'ы переживают рестарт через `expiresAt` в профиле |
| `core/Leaderboard.lua` | **Phase 10 (наполнен, был пустышкой):** `MemoryStoreSortedMap` × 2 (`Leaderboard_Coins_v1` для `totalCoinsEarned`, `Leaderboard_Depth_v1` для `maxDepthReached`). Ключ = `"user_<userId>"`, значение = integer score (через `LeaderboardLogic.toScore`), `expirationSeconds = 30 дней` TTL. `writeIfChanged(player)` пишет только при `LeaderboardLogic.shouldWrite(boardId, lastWritten, current)` (delta >= `writeThresholdCoins=100`/`writeThresholdDepth=5`) — `lastWritten` живёт в `data.leaderboardPlacement.coinsValue/depthValue` (auto-cleanup при profile release). `fetchTop(boardId)` через `GetRangeAsync(Descending, topSize)`, имена через `Players:GetNameFromUserIdAsync` + `nameCache`. `_startRefreshLoop` обновляет snapshot раз в `refreshIntervalSeconds=30`, при ошибке MemoryStore — exp-backoff `2/4/8с`. `Net:Function("RequestLeaderboard")` — server-side throttle 5с на игрока, возвращает `{ coins = { entries, myRank, error? }, depth = { ... }, nextRefreshAt }`. `_updateOnlineRanks` обновляет `data.leaderboardPlacement.coinsRank/depthRank` после refresh'a — клиент видит свой ранг в StatsPanel. `onPlayerLeaving` финализирует write + чистит throttle. `nil`-fallback на MemoryStore failure (UI рисует «загрузка / сервис недоступен») |
| `core/DevCommands.lua` | `/coins`, `/reset`, `/maxlvl`, `/skiptut`, `/devhelp` (Studio); Phase 8 — `/reset` через `tutorialManager:reset()` снова выдаёт стартовый бонус и сбрасывает шаги, `/skiptut` принудительно ставит `tutorialStep=3` + `firstSession=false` (для теста не-онбординг-фич); **Phase 9:** `/rebirth [N]` через `rebirthManager:devRebirth(player, N)` (без проверки цены); `/reset` НЕ трогает rebirths (для теста tutorial flow); **Phase 10:** `/daily` (шлёт `kind="daily_available"`, открывает модал немедленно), `/setday <N>` (сдвигает `lastClaimYday` на N дней назад для теста streak'а), `/resetdaily` (через `dailyReward:reset(player)`), `/boost <minutes>` (даёт x2 coins boost на N минут), `/leaderboard refresh` (форс `leaderboard:_refresh("coins")` + `"depth"`). `/reset` НЕ трогает dailyState / activeBoosts (для них `/resetdaily` отдельно) |

### Клиент
| Файл | Что делает |
|------|------------|
| `init.client.lua` | Точка входа, рендер + HUD + PlayerStats + Notify; стартует SoundManager и CameraShake до первого CharacterAdded; **Phase 8:** запускает `Tutorial.start(tutorialStep, payload)` на каждый PlayerStats (Tutorial.start идемпотентен), `Tutorial.refresh()` после CharacterAdded, `Tutorial.destroy()` при выходе; **Phase 10:** `Net:Connect("PlayerStats")` — при `dailyState.canClaim == true` и `_autoOpenedThisSession == false` автоматически открывает `DailyRewardModal.show()` через выделенный `modalScope`; `Net:Connect("Notify")` обрабатывает `payload.kind == "daily_available"` (переоткрытие модала после полуночи) и `payload.kind == "daily_reward"` (запуск `RewardFX.burst(rarity)` ровно один раз — server-authoritative по rarity, без двойного coin-rain'a) |
| `core/MiningRenderer.lua` | 3D-блоки, applySnapshot/applyDelta, HP-bar, hover (Size 1.0↔1.05); **Phase 7 (mining-style juice):** dmg numbers с adaptive UIStroke + цвет руды + pop-in (Quad/Out, мягко), block-squash на ударе (замена шутерному shake), break = физические chunks (6→30 по rarity, gravity) + dust cloud (smoke_main, 8→32) + shockwave-сфера (ForceField, цвет редкости, rare+) + coin-pop (`+X 💰` всплывает из блока), crit = золотое shockwave + 6 золотых chunks (без slow-mo, без фуллскрин-flash), hooks → SoundManager / CameraShake / Haptics |
| `core/OreLookup.lua` | O(1) лукап `oreId → OreDef` поверх `shared/data/OreDatabase` (color/rarity/icon/name/rarityColor) |
| `core/DepthTracker.lua` | Клиентский трекер глубины по `HumanoidRootPart.Y` |
| `core/LayerEnvironment.lua` | Твин `Lighting.Ambient/OutdoorAmbient/FogColor` по слою |
| `core/SoundManager.lua` | Кэш Sound-инстансов в SoundService под `DeepDigger_Sounds`, 2 SoundGroup (sfx/ui), 3D-звуки через временный Attachment + Debris, API: `start / play / playForOre / setVolume` |
| `core/CameraShake.lua` | Перезаписываемый offset CFrame на RenderStepped, авто-откат прошлого кадра (не накапливается). Пресеты `hit / crit / rare_break / break / legendary_break` — но из MiningRenderer вызываются только break-пресеты (на rare+), hit/crit пресеты в API «на потом» (бои в патчах) |
| `core/Haptics.lua` | `pulse("hit"\|"crit"\|"break"\|"legendary_break")`, hit-пульс ОЧЕНЬ мягкий (0.12/0.03 — копание = 4 клика/сек), `pcall` вокруг `HapticService:SetMotor`, no-op на десктопе |
| `ui/HUD.lua` | Fusion-фасад: монеты, глубина, уровни, кнопки апгрейдов, SELL |
| `ui/Notification.lua` | Переиспользуемая всплывашка (используется для error-UX тостов в Phase 8); Phase 9 — тост «REBIRTH! Ребёрт #N, x1.X к ценам руд» приходит сюда через тот же канал, RebirthFX триггерится отдельно по `payload.kind == "rebirth"` |
| `ui/RebirthFX.lua` | **Phase 9 (prestige FX):** локальный mining-style эффект в позиции игрока — 3 золотых shockwave-кольца (ForceField-сфера, размеры 22/32/40 студов с задержками 0/0.15/0.35с) + 30 золотых физических chunks (Neon, gravity-affected, fade через Debris). **Без camera-shake / slow-mo / fullscreen flash** — соблюдены Phase 7 mining-принципы. Падение FX не сорвёт сам ребёрт (pcall в init.client.lua) |
| `ui/RewardFX.lua` | **Phase 10 (daily claim FX):** full-screen overlay (PlayerGui `DeepDigger_RewardFX`, DisplayOrder=92) — НЕ block-position, в отличие от RebirthFX. Coin/gem rain: 60 спрайтов 💰 (TextLabel + UIStroke) с physics-падением сверху + rotation + fade на дне (~1.2с/шт). 3 rarity-цветных shockwave кольца в центре (ImageLabel + UIStroke, scale 0→2.8 с задержками 0/0.15/0.3с). Total ~1.5с. `pcall`-обёртки, no-op fallback при отсутствии PlayerGui. Триггерится только из `Net:Connect("Notify")` с `payload.kind="daily_reward"` (rarity-aware из сервера) |
| `ui/DailyRewardModal.lua` | **Phase 10:** full-screen overlay (ScreenGui `DeepDigger_DailyModal`, DisplayOrder=95 как RebirthConfirmModal). Header «🎁 Награда за день · Стрик: 🔥 N», сетка 7 `DailyCard`'ов (4×2 desktop / 2×4 mobile при `Camera.ViewportSize.X < 800`), footer с кнопками [ЗАБРАТЬ] (золотая, glow-pulse через `UIStroke` tween) и [ПОЗЖЕ] (серая). **Anti-misclick 0.4с** — кнопка claim'а disabled первые 0.4с (как Phase 9 RebirthConfirmModal). ESC / [ПОЗЖЕ] / клик по backdrop закрывают без claim'a. На клик [ЗАБРАТЬ] → `Net:Invoke("ClaimDaily")` (без аргументов — сервер сам вычисляет день/streak/награду) → success: SoundManager.play("sell_success") + закрытие через 0.8с (FX триггерится сервером через Notify, не из модала — избегаем двойного burst'a). Каждое `show()` создаёт собственный `parentScope:innerScope()` + `Fusion.doCleanup(s)` после закрытия — предотвращает накопление Value/Computed между показами. `_activeHandle` защищает от одновременных модалов |
| `ui/hud/components/DailyCard.lua` | **Phase 10:** 100×140px карточка дня в `DailyRewardModal`. Rarity-цветной `UIStroke` (common=серый, uncommon=зелёный, rare=синий, epic=фиолет, legendary=оранжевый, mythic=золотой + gradient). Иконка типа награды (💰 coins / ⚡ boost / 🎁 mythic), label «День N», текст награды (`reward.label`). Состояния: past (✓ галочка зелёная + затемнение), current (full opacity + `startPulse` tween 0.8→1.2с на UIStroke по rarity-цвету), future (~0.4 transparency + greyed out). Принимает `layoutOrder` в Props — устанавливается внутри Fusion-create чтобы не конфликтовать с UIGridLayout |
| `ui/hud/panels/LeaderboardPanel.lua` | **Phase 10:** содержимое 5-го таба HUD. Toggle вверху «💰 Монеты» / «⬇ Глубина» (две `s:Value<BoardId>` snapshot'a, переключение мгновенное — оба массива в state). Spotlight-карточка топ-1 (корона 👑, золотой gradient через UIGradient, animated `UIStroke` pulse 0.8→1.2с). ScrollingFrame top-2..top-50 через `LeaderRow.create` (рендер через `s:Computed`, не `s:ForValues` — паттерн как InventoryPanel). Footer «Вы: #N» если игрок вне топ-50. Countdown «Обновится через Ns» справа сверху (RunService.Heartbeat раз в секунду пересчитывает). При первой активации таба (`hasFetchedOnce=false`) → `fetchLeaderboard()` сразу, потом по countdown'у на нуле. Loading state: 10 skeleton-плейсхолдеров; error state: «Сервис недоступен. Обновляем...». Cleanup heartbeat connection через `table.insert(s, fn)` — корректно регистрируется со scope без участия в `[Children]` |
| `ui/hud/components/LeaderRow.lua` | **Phase 10:** строка лидерборда. Async avatar через `Players:GetUserThumbnailAsync(userId, HeadShot, Size150x150)`, module-level `avatarCache: { [userId] = imageId }` (не дёргаем дважды для одного userId). Skeleton-placeholder (серый круг) пока фото грузится, fade-in при готовности. Rank (`LeaderboardLogic.formatRank(rank)` → "#42" / "👑#1"), Name, Value (`LeaderboardLogic.formatValue(boardId, value)` → "1.2k" / "500м"). Подсветка если `userId == LocalPlayer.UserId` — золотая обводка |
| `ui/hud/components/BoostChip.lua` | **Phase 10:** TopBar-чип активного boost'a справа от ResourceChip'ов. `Visible = #activeBoosts > 0` через `s:Computed`. `pickPrimaryBoost` выбирает самый сильный (или скорый-к-истечению при равенстве). «⚡ x2 · 29:42» — локальный countdown через `RunService.Heartbeat` (раз в секунду, format MM:SS). RGB-cycle `UIStroke` (HSV-cycle цвета через Heartbeat) — Pet Sim style. `pcall`-обёртки, корректный cleanup heartbeat connection при destroy |
| `ui/hud/components/StreakChip.lua` | **Phase 10:** TopBar-чип streak'a. `Visible = streak >= 2` (новички не видят шума при streak=1). «🔥 N дней» с правильной русской плюрализацией («1 день», «2 дня», «5 дней»). Минимальный фрейм, без анимаций — статус-индикатор |
| `ui/Tutorial.lua` | **Phase 8 (онбординг, polish):** singleton-orchestrator над `tutorial/TutorialFlow` (data-driven сцены) + `TutorialDialog` (бот-диалог) + `TutorialTracker` (квест-трекер) + `TutorialArrow`. Серверная семантика та же (0/1/2/3), клиентский flow развёрнут в `welcome → step_0_task → step_0_success → step_1_open_inventory → step_1_sell → step_1_success → step_2_open_upgrades → step_2_buy_pickaxe → finale`. Listener PlayerStats отслеживает `totalBlocksMined / totalCoinsEarned / pickaxeLevel` для авто-продвижения; tab-click listener для перехода inventory/upgrades. `Net:Invoke("UpdateTutorialStep")` шлётся ровно в success/finale scenes. `Tutorial.skip()` (✕ в диалоге) ставит шаг=3 и destroy. Polling реатачит arrow и tab-listener, если HUD ещё не был готов на момент enterScene. `refresh()` после respawn |
| `ui/TutorialArrow.lua` | **Phase 8:** `pointAt(target, text) → handle`. GuiObject → пульсирующий золотой UIStroke + label, RenderStepped «приклеивает» к target. BasePart → BillboardGui ⬇ с bounce-tween. Общий ScreenGui `DeepDigger_Tutorial`, `Active=false` (клик проходит сквозь) |
| `ui/tutorial/TutorialFlow.lua` | **Phase 8 polish:** data-driven последовательность сцен онбординга. `STEPS[]` (welcome / *_task / *_success / finale) с `speaker / name / text / kind / task / target / arrowText / completeOn / hideAdvanceButton / next`. `SERVER_STEP_AFTER` → когда какая сцена триггерит `UpdateTutorialStep`. `ENTRY_BY_SERVER_STEP` → точка входа при загрузке профиля с tutorialStep N. `getById / findIndex / getNext` — навигация. Все тексты диалогов и формулировки заданий ТОЛЬКО здесь — править язык/тон без правок логики |
| `ui/tutorial/TutorialDialog.lua` | **Phase 8 polish:** боттом-центр диалог наставника. Аватар (emoji ⛏️), имя, текст с typewriter-эффектом (~42 char/sec, UTF-8 safe через `utf8.offset`), кнопка [Понятно ✓], кнопка [✕] skip. `kind` управляет цветом stroke/avatar-ring/button (intro=gold, task=cyan, success=green, finale=mythic). Slide-in снизу 0.28с (Quad/Out), slide-out 0.2с. Клик где угодно по диалогу → мгновенно дописать typewriter. `Active=false` снаружи → геймплей не блокируется. `handle:update(opts)` без destroy для смены содержимого. Парентится в общий `DeepDigger_Tutorial` ScreenGui |
| `ui/tutorial/TutorialTracker.lua` | **Phase 8 polish:** квест-трекер справа (под TopBar). Иконка `📜`, заголовок «Задание N из M», описание, опциональный progress bar `[████░░░░] X / Y`. `handle:setProgress(current, goal?)` твинит ширину fill. `handle:complete()` — заполняет до конца, меняет цвет на зелёный, показывает анимированный ✓ (Back/Out 0.3с), через 1.4с auto-destroy. Slide-in справа 0.3с (Quad/Out) |
| `ui/hud/components/Tooltip.lua` | **Phase 8:** `Tooltip.attach(scope, target, getText)`. Hover-tooltip с RichText, fade 0.1с, edge-clamping. Cleanup через Fusion scope. Применён в `UpgRow` |
| `ui/hud/components/AnimatedNumber.lua` | **Phase 8:** `tween(state, target, dur)` плавно меняет Fusion.Value<number> через Heartbeat + Quad/Out (дефолт 0.3с). `snap` / `cancel`. Используется для `coinsDisplay` и `statTotalCoinsDisplay` в HudState |
| `ui/hud/components/RebirthConfirmModal.lua` | **Phase 9:** модальное окно подтверждения ребёрта. Затемнение фона (ScreenGui `DeepDigger_RebirthModal`, DisplayOrder=95), центрированный фрейм 420×280 с золотым stroke. Кнопка [РЕБЁРТ] disabled первые **0.3с** (anti-misclick задержка) — игрок не может «слепо» прокликать. ESC / клик по backdrop / [ОТМЕНА] закрывают без действия; Modal Frame `Active=true` чтобы клик по голому телу не проваливался на backdrop. Fade-in 0.18с, fade-out 0.12с |
| `ui/hud/panels/RebirthPanel.lua` | **Phase 9:** содержимое 4-го таба HUD. Заголовок «Ребёрты: N / Множитель: x1.X», крупная кнопка REBIRTH (цена через `RebirthLogic.cost(rebirths)`, золотая при `canAfford`, иначе disabled с текстом «Не хватает X 💰»), описание «✓ сохранится / ✗ сбросится / ⛏ следующий бонус кирки». На Activated → RebirthConfirmModal, по подтверждению → `Net:Invoke("Rebirth")`. SoundManager.play на ошибках, Notification.show при отказе сервера |

### Shared
| Файл | Что делает |
|------|------------|
| `constants.lua` | Слои, сетка, апгрейды, RARITY_*, SHAFT_*; **Phase 8:** `STARTER_COINS = 100` (first-time bonus), `TUTORIAL_STEPS = { NOT_STARTED=0, MINED_FIRST_BLOCK=1, SOLD_FIRST_ORE=2, COMPLETED=3 }`; **Phase 9:** `REBIRTH = { baseCost=50000, exponent=5, multiplierPerRebirth=0.1, pickaxeMaxBonusAt={5,10,25} }` (формулы в `shared/util/RebirthLogic.lua`); **Phase 10:** `DAILY = { cycleDays=7, grantBoostAtDay7=true, streakResetAfterMissedDays=2, rolloverCheckInterval=60 }` + `LEADERBOARD = { COINS_MAP="Leaderboard_Coins_v1", DEPTH_MAP="Leaderboard_Depth_v1", topSize=50, refreshIntervalSeconds=30, expirationSeconds=30 days, writeThresholdCoins=100, writeThresholdDepth=5 }`. Версионирование `_v1` — при изменении схемы старый лидерборд остаётся как archive |
| `data/OreDatabase.lua` | 31 руда + `test_glow`, 7 слоёв (Dirt → Void) — единственный источник правды по рудам, читают и сервер, и клиент |
| `data/SoundDatabase.lua` | Маппинг событий (hit / break / crit / sell / buy / ui_click) → `{ soundId, volume, pitchRange }`. Rarity-маппинги `RARITY_HIT` / `RARITY_BREAK`. Все ID — Roblox audio library (free), помечены `TODO playtest` |
| `data/DailyRewardDatabase.lua` | **Phase 10:** 7-дневный цикл наград. `[1..6] = { type, amount, [duration], rarity, label }`, `[7] = { type="coins", amount=50000, rarity="mythic", bonusBoost = { multiplier=2, duration=1800 }, label="+50,000 + x2/30мин" }`. Rarity ramp: common → common → uncommon → rare → epic → legendary → mythic. Helper'ы `get(day)` (с fallback в Day 1 для невалидных) и `iconForReward(reward)` (💰 coins / ⚡ boost / 🎁 mythic). Чистый data-модуль без логики claim'а — последняя в `shared/util/DailyLogic.lua` |
| `util/LayerUtil.lua` | depth↔layer, colorToPayload |
| `util/UpgradeLogic.lua` | Все формулы апгрейдов; **Phase 8:** `describeCurrentLevel(id, lvl) → "урон 11"` и `describeNextLevel(id, lvl) → "урон 11 → 13"` для Tooltip'ов; **Phase 9:** `UpgradeLogic.maxLevel(upgradeId, rebirths?)` — динамический потолок (pickaxe = `cfg.maxLevel + RebirthLogic.pickaxeMaxLevelBonus(rebirths)`); `describeNextLevel` принимает опциональный `rebirths` чтобы tooltip pickaxe после R5/R10/R25 показывал next-level вместо «MAX» |
| `util/RebirthLogic.lua` | **Phase 9 (prestige):** единственный источник формул ребёрта. `cost(rebirths) = floor(baseCost * exponent^rebirths)`, `valueMultiplier(rebirths) = 1 + rebirths * multiplierPerRebirth`, `pickaxeMaxLevelBonus(rebirths)` — количество перейденных порогов из `Constants.REBIRTH.pickaxeMaxBonusAt`, `nextPickaxeBonusThreshold(rebirths)` — ближайший непройденный порог, `describeReward(currentRebirths) → "К ценам руд: x1.0 → x1.1"` для RebirthPanel. Запрещены дубликаты этих формул в RebirthManager / SellInventory / RebirthPanel — только вызов отсюда |
| `util/DailyLogic.lua` | **Phase 10 (retention):** единственный источник формул дня. `currentDay(now?)` → `{ yday, year }` через `os.date("!*t")` (UTC, восклицательный знак — обязателен). `daysBetween(prev, curr)` — diff в днях с учётом перехода через границу года (через `os.time({...12:00})`). `canClaim(dailyState, now?)` — `gap > 0` (не today). `nextStreak(dailyState, now?)` — `1` если gap==0 (already), `currentStreak+1` если gap==1, `1` если gap >= streakResetAfterMissedDays. `streakToCycleDay(streak)` — `(streak - 1) % cycleDays + 1` (1..7). `timeUntilNextDay(now?)` → `{ hours, minutes, seconds }` до полуночи UTC. Запрещены дубликаты `os.date("!*t").yday` в нескольких местах — только через эти helper'ы |
| `util/LeaderboardLogic.lua` | **Phase 10:** единственный источник формул лидерборда. `toScore(value)` — округляет в integer для MemoryStoreSortedMap. `formatRank(rank)` → `"#42"` / `"👑#1"` / `"—"` (для nil). `formatValue(boardId, value)` — short-format `"1.2k"`/`"500m"`/`"1.5b"` для монет, `"123м"` для глубины. `crownForRank(rank)` → `"👑"` если rank==1, иначе nil. `shouldWrite(boardId, lastWritten, current)` — `current > lastWritten + writeThreshold` (delta-based throttle, чтобы не спамить MemoryStore при каждой продаже) |
| `util/InventoryUtil.lua` | totalCount, addOre |
| `util/Logger.lua`, `util/Signal.lua` | Утилиты |
| `types/OreTypes.lua` | Типы данных (`OreDef` с заделом под Фазу 13: `material`/`reflectance`/`atlasIndex`/`meshId`/`glow`); **Phase 8:** `PlayerData` расширен `tutorialStep: number` + `firstSession: boolean`; **Phase 9:** `PlayerData` расширен `rebirths: number` + `rebirthMultiplier: number` (денормализованный кэш); **Phase 10:** `PlayerData` расширен `dailyState: DailyState` (`{ lastClaimYday, lastClaimYear, currentStreak, totalDaysClaimed }`), `activeBoosts: { ActiveBoost }` (`{ kind, multiplier, expiresAt }`), `leaderboardPlacement: LeaderboardPlacement` (`{ coinsRank?, depthRank?, coinsValue, depthValue }`) |

---

## 🟠 Заглушки
- `AchievementManager.lua` — не подключён в MVP (после).

---

## 🔴 Чего нет в коде, но **должно быть к релизу** (Фазы 11-13)

| Модуль | Фаза |
|--------|------|
| `shared/data/PetDatabase.lua` | 11 (pets) |
| `server/core/PetManager.lua` | 11 (pets) |
| `server/core/EggManager.lua` | 11 (pets) |
| `client/ui/PetsPanel.lua` | 11 (pets) |
| `server/core/MonetizationManager.lua` | 12 (revenue) |
| `Constants.GAMEPASSES`, `Constants.DEVPRODUCTS` | 12 |

## 🔴 Post-MVP (патчи 1.1, 1.2 и большие апдейты)
- Trading между игроками.
- Achievements (`AchievementManager` есть, подключить).
- BossEngine, Mine Shafts как отдельная фича.
- Limestone+ контент-пасс.
- Гильдии / кланы, limited events.
- Расходники (молоток/бомба), гемы и магазин за гемы.

---

## 📋 MVP по фазам

| Фаза | Статус |
|------|--------|
| 0. Scope | 🟢 |
| 1. Фундамент и баги | 🟢 |
| 2. Экономика | 🟢 |
| 3. Апгрейды | 🟢 |
| 4. Прогрессия слоёв | 🟢 |
| 5. Сеть и производительность | 🟢 (требуется плейтест-профайл) |
| 6. Один источник данных по рудам | 🟢 |
| 7. Game Feel & Juice (звуки, screen shake) | 🟢 |
| 8. Онбординг и UX (туториал, error UX, tooltip, count-up) | 🟢 |
| 9. Rebirth / Prestige | 🟢 |
| 10. Daily reward + Leaderboard | 🟢 |
| 11. Pets MVP (5-10 петов, egg) | 🔴 |
| 12. Монетизация (3-4 gamepass + 2-3 devproduct) | 🔴 |
| 13. Визуальная идентичность (материалы, key art) | 🔴 |
| 14. Soft launch и стабилизация | 🔴 |

---

## 🎮 Команды
- `/rarity` — полоски редкости
- `/hpbar` — HP бар при наведении
- `/coins <N>`, `/reset`, `/maxlvl`, `/skiptut`, `/rebirth [N]`, `/daily`, `/setday <N>`, `/resetdaily`, `/boost <min>`, `/leaderboard refresh`, `/devhelp` — только Studio
- `/help` — список

---

## 📊 Чек-лист профилирования Фазы 5

Пройти 10+ минут активного копания в Studio с MicroProfiler и убедиться:

- [ ] **ScriptContext (Server)** — нет монотонного роста времени на тик. Спайки только в моменты `MineBlock` (норма).
- [ ] **RemoteEvent OutgoingDataKB/s** — после первого `snapshot` (~2250 блоков) исходящий трафик резко падает. На активном копании держится десятки B/s на дельту, не килобайты.
- [ ] **FPS** — клиент не проседает <50 FPS на ~2000 видимых партах. Если проседает — смотреть `MiningRenderer:_createPart` (BillboardGui/ParticleEmitter).
- [ ] **Memory (Server)** — `self._blocks[uid]` растёт линейно с количеством раскопанных блоков. Освобождается при `resetPlayer` (выход игрока).
- [ ] **Tasks scheduled** — `_animateDestroy` через 0.3 с чистит partы; в `_parts`/`_blockData` нет осиротевших ключей после серии разрушений.
- [ ] **Второй аккаунт** — два игрока на одном сервере, дельты идут только своему игроку (`FireClient`, не `FireAllClients`).
- [ ] **Античит** — фастклик `/onclick` (или AutoHotkey) триггерит `Too many clicks` / `Too fast` уже на батч >16 или CPS >20.

Если все галочки зелёные → Фаза 5 закрыта окончательно, можно переходить к Фазе 6 (`OreDatabase` как единственный источник для клиентских цветов/редкостей).

---

## 📊 Git
- `main`
- GitHub: `github.com/RAYADANN/deep-digger`
