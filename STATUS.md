# STATUS.md — Deep Digger 🪨

> Состояние проекта, заглушки и планы.
> Обновлено: **2026-07-02** (синхронизировано с кодом и `MVP.md`)
> **Текущая стадия:** gameplay-MVP (фазы 0–16) + Фаза 17 (UI/визуальный оверхол) + пост-MVP системы **в коде и закоммичены**. Помимо запланированного MVP реализованы (вне исходного scope): промокоды, соц-награда, egg shop с 6 типами яиц, система баффов, мутации руды, повторяемые ежедневки, hub-зоны, world-leaderboard на поверхности, responsive-layout HUD. До релиза: закрыть P0-блокеры (реальные id монетизации, playtest Фазы 5) → Фаза 15 (плейтест + unlisted).
>
> **Правило:** цифры контента и поведение механик — из **кода** (`src/`). Сводная таблица совпадает с `MVP.md` § «Снимок актуального состояния».
>
> ⚠️ **Честная заметка о scope:** значительная часть систем ниже (промокоды, соц-награда, мутации, баффы, ежедневки, доп. яйца) добавлена **после** закрытия MVP-скоупа и **до** первого плейтеста/soft-launch. Это нарушение собственного правила против scope creep (см. `MVP.md` в конце). Правильнее было бы часть из этого раздать апдейтами 1.1/1.2 после релиза.

---

## 📦 Контент (цифры из кода)

| | |
|--|--|
| Руды | **55** в `OreDatabase` (**54** discoverable + `test_glow` weight=0) |
| Слои | 7 (dirt → void) |
| Питомцы | **30** (`PetDatabaseEntries.lua`), 3D через `PetModelKit` |
| Яйца | **6** типов в `EggPoolDatabase` (`basic`, `desert`, `candy`, `ocean`, `lava`, `explosive_hydro`), по 6 взвешенных петов в пуле |
| Квесты | 10 sequential (`QuestLogic.lua`) + **3 повторяемых ежедневки** (`DailyQuestLogic.lua`) |
| Достижения | 7 (`AchievementManager.lua`, server-only) |
| Апгрейды | 7 |
| Промокоды | **2** (`PromoCodes.lua`: `LAUNCH2026`, `WELCOME`) |
| Баффы | 5 видов в `BuffMeta` (`damage`, `luck`, `coin`, `multiMine`, `speed`) |
| Мутации руды | `MutationLogic` + `Constants.MUTATIONS` (шанс + взвешенный вариант) |
| Иконки руд | 54 baked `OreIconPixels/*.lua` + PNG в `assets/ui/ores/` |
| Объём `src/` | **~35k строк / 230 .lua файлов** (client 109 / shared 96 / server 25); `MiningRenderer` ~1.8k строк |

---

## 🏗 Архитектура

```
Движок:      Neighbor Reveal — блоки генерируются при разрушении соседних
Поверхность: 15×15×10 (2250 блоков) при старте
Расширение:  бесконечное по X, Z, Y (6 направлений по 3D-граням)
Блок:        4.5×4.5×4.5 студа, CanCollide = true
Позиция:     Z=30 перед игроком, Y=0 на уровне ног
Ключи:       "x_z_y"
UI:          Fusion 0.3. Layout (Фаза 17):
             CurrencyRibbon (левый верх) + InventoryWidget (правый верх)
             + LeftSidebar dock (низ, центр) + modal MainPanel.
             Иконки: shared/data/UiAssets + assets/ui → ReplicatedStorage.uiAssets.
             Legacy (не монтируются): TabBar, TopBar-stub, BottomDock.
Сеть:        SyncBlocks { kind = "snapshot" | "delta", payload }
             snapshot → один раз при заходе/reset
             delta    → { created, updated, removed } после каждого удара
Данные руд:  shared/data/OreDatabase — единственный источник правды.
             Сервер: oreDb:getAll/getOre для спавна и продажи.
             Клиент: client/core/OreLookup строит O(1) мапу oreId→OreDef
             поверх него; цвет / редкость / иконка только через лукап.
Спавн руды:  взвешенный ролл по полю OreDef.weight внутри слоя (Фаза 16).
             Наполнитель ~900, uncommon изредка, rare+ очень редко.
             weight=0 = не спавнится (test_glow).
Освещение:  Constants.HEADLAMP.enabled = false; активен CURSOR_LIGHT
             в MiningRenderer (свет на блок под курсором/тачем).
Иконки руд: OreAssets + OreIconPixelLoader + 54× OreIconPixels/*.lua
             (tools/bake_ore_icons.py); PNG в assets/ui/ores/.
```

---

## ✅ Готово

### Сервер
| Файл | Что делает |
|------|------------|
| `init.server.lua` | Точка входа, MineBlock + дельта-флаш, depth-sync, notify; Phase 8 — поднимает `TutorialManager` и зовёт `onProfileLoaded` при заходе игрока (миграция опытных + first-time bonus); **Phase 9:** поднимает `RebirthManager` с DI `onResetBlocks` (`MiningEngine:resetPlayer` + `sendBlocksSnapshot` после ребёрта), `buildHudPayload` шлёт `rebirths` / `rebirthMultiplier`, `notify` payload расширен опциональным `kind` для FX-триггеров; **Phase 10:** Leaderboard поднимается РАНЬШЕ EconomyManager, `onEconomyChanged = syncPlayerHud + leaderboard:writeIfChanged` оборачивает write-хук (EconomyManager про лидерборд не знает — изоляция Phase 3); поднимает `DailyReward` (DI как RebirthManager), `PlayerBoosts.cleanup(activeBoosts)` в `onPlayerAdded` чистит истёкшие бусты, `leaderboard:onPlayerLeaving` в `PlayerRemoving` финализирует write + throttle-cleanup; `buildHudPayload` шлёт `dailyState { canClaim, currentStreak, nextDay, secondsUntilNextDay, totalDaysClaimed }`, `activeBoosts` (с `remainingSeconds`) и `leaderboardPlacement`; **Phase 11:** поднимает `PetManager` (DI `onProfileChanged=onEconomyChanged` — hatch списывает монеты), `petManager:onProfileLoaded` в `onPlayerAdded`, `buildHudPayload` шлёт `pets` / `equippedPet` / `petEffects` (PetLogic.summary), MineBlock-луп начисляет `result.bonusOreDefs` (multiMine) через MiningLoot; **Phase 12:** поднимает `MonetizationManager` (DI + petManager для egg10), `monetization:onProfileLoaded` в `onPlayerAdded`, `buildHudPayload` шлёт `gamepasses` / `equippedUids` / `petMaxEquipped`; **Phase 13:** поднимает `DiscoveryManager`, `discoveryManager:onProfileLoaded` + `recordDiscovery` в MineBlock при `loot.added > 0` (основная и bonus руда), `buildHudPayload` шлёт `discoveredOres` / `discoveredMilestones` / `discoveryProgress`; **Phase 16:** поднимает `QuestManager` + `AchievementManager` (DI `onProfileChanged=onEconomyChanged`, `notify`), `onPlayerAdded` зовёт `questManager:onProfileLoaded` + `achievementManager:loadUnlocked`, MineBlock после `flushDelta` дёргает `achievementManager:check` + `questManager:evaluate` (полный HUD-sync только если что-то изменилось, иначе лёгкая `syncMiningHud`), `processDepthUpdate` тоже проверяет цели/достижения на новом рекорде глубины, `Net:Handle("ClaimQuest")` → `questManager:claim`, `buildHudPayload` шлёт `questActive` / `questClaimedCount` / `questTotalCount` / `achievements`, `syncMiningHud` шлёт `questActive`, `onEconomyChanged` (продажа/ребёрт/покупка) тоже триггерит проверку целей |
| `core/MiningEngine.lua` | Neighbor Reveal, валидация exposed-блоков, дельта в `blockDelta`; **Phase 11:** `dmg *= PetLogic.damageMultiplier`, `roomChance *= PetLogic.luckMultiplier`, multiMine — `_multiMineBreak` мгновенно ломает один соседний открытый блок при `math.random() < PetLogic.multiMineChance`, его OreDef уходит в `result.bonusOreDefs` (всё в общий snapshot/дельту); **Phase 16:** `_roll` переписан на единый взвешенный ролл по `OreDef.weight` внутри пула слоя (`_oreWeight` = `weight` или fallback `Constants.RARITY_DEFAULT_WEIGHT[rarity]`, `weight<=0` пропускается) — наполнитель доминирует. Логика комнат/сундуков с rarity-лестницей не изменилась |
| `core/ProfileManager.lua` | ProfileService, автосохранение, данные игрока; **Phase 8:** в TEMPLATE добавлены `tutorialStep = 0` и `firstSession = true`; **Phase 9:** добавлены `rebirths = 0` и `rebirthMultiplier = 1.0` (денормализованный кэш `1 + rebirths * multiplierPerRebirth`); **Phase 10:** в TEMPLATE добавлены `dailyState { lastClaimYday=0, lastClaimYear=0, currentStreak=0, totalDaysClaimed=0 }`, `activeBoosts = {}` (массив `{ kind, multiplier, expiresAt }`), `leaderboardPlacement { coinsRank=nil, depthRank=nil, coinsValue=0, depthValue=0 }`. ProfileService template-мердж добавляет поля старым профилям без миграции; **Phase 11:** добавлены `pets = {}` (записи `{ uid, petId }`), `equippedPet = nil` (uid экипированного пета), `petUidCounter = 0` (монотонный счётчик uid'ов); **Phase 12:** `gamepasses = {}` (кэш владения по key, source of truth — UserOwnsGamePassAsync); **Phase 13:** `discoveredOres = {}`, `discoveredMilestones = {}`; **Phase 16:** `claimedQuests = {}` (id забранных квестов), `unlockedAchievements = {}` (id разблокированных достижений), `shaftRoomCount = 0` (счётчик найденных скрытых комнат — для достижения shaft_finder) |
| `core/AntiCheat.lua` | CPS (20/s), batch cap 16, swing cooldown. **Нет:** reach-check кликов, server-side depth validation |
| `core/EconomyManager.lua` | BuyUpgrade/SellOres, multiSell, autoSell |
| `core/economy/BuyUpgrade.lua` | Покупка апгрейда; Phase 8 — конкретный `message = "Не хватает N монет"`; **Phase 9:** `effectiveMax = UpgradeLogic.maxLevel(upgradeId, playerData.rebirths)` — pickaxe-MAX дрейфует с ребёртами, без правок BuyUpgrade-протокола |
| `core/economy/SellInventory.lua` | Продажа всего инвентаря по OreDatabase.value + multiSell бонус; **Phase 9:** `payout = floor(gross * multiSellMult * rebirthMultiplier)` — prestige-множитель применяется ПОСЛЕ multiSell бонуса, источник истины — `playerData.rebirthMultiplier` с фолбэком на `RebirthLogic.valueMultiplier(rebirths)`; **Phase 10:** добавлен `boostMult = PlayerBoosts.totalMultiplier(activeBoosts, "coins")` (с предварительным `PlayerBoosts.cleanup`), итоговая формула `payout = floor(gross * multiSellMult * rebirthMult * boostMult)` — порядок persistent → temporary; **Phase 11:** `boostMult = PlayerBoosts.totalMultiplier(...) + PetLogic.coinBoostSum(playerData)` — coinBoost петов аддитивно в ту же boost-стадию, порядок не меняется; **Phase 12:** `+ MonetizationLogic.coinBoost(playerData)` (VIP +10%) в ту же boost-стадию |
| `core/MiningLoot.lua` | Fortune-ролл, capacity + autoSell |
| `core/TutorialManager.lua` | **Phase 8 (онбординг):** `Net:Handle("UpdateTutorialStep")` с валидацией (0..3, монотонный рост), миграция опытных профилей (totalBlocksMined>0 или totalCoinsEarned>0 → tutorialStep=3), first-time bonus (`Constants.STARTER_COINS` через `profile.firstSession`), `:reset()` для DevCommands |
| `core/RebirthManager.lua` | **Phase 9:** prestige loop. **Сохраняет** pets, journal, quests, achievements, gamepasses, daily. **Сбрасывает** coins/inventory/upgrades/depth. `devRebirth` для Studio |
| `core/PetAssetBootstrap.lua` | **Phase 17:** клон `Workspace.Pets`/`Eggs` → `ReplicatedStorage.PetKit`; валидация против `PetDatabase` |
| `core/PlayerTag.lua` | Rebirth-tier BillboardGui над головой + Highlight/Particles; VIP gold override (пересекается с MonetizationManager VIP tag) |
| `core/DailyReward.lua` | **Phase 10 (retention):** DI как RebirthManager (`profileManager`, `onProfileChanged`, `notify`). `Net:Handle("ClaimDaily")` — серверная валидация через `DailyLogic.canClaim`, начисление монет / boost'ов через `PlayerBoosts.addBoost`, инкремент `currentStreak` (gap==1 → +1, gap==0 → already_claimed, gap >= streakResetAfterMissedDays → 1), `lastClaimYday/lastClaimYear` обновляются после grant'a, `totalDaysClaimed += 1`. `onProfileLoaded` шлёт `kind="daily_available"` если можно claim'ить (не автоclaim — игрок должен видеть satisfaction). Серверный `task.spawn(rolloverCheckInterval=60s)` watcher шлёт notify когда новый день стал доступен в активной сессии (без перезахода). `_availabilityNotified` чистится в `PlayerRemoving`. DI-методы: `devGrantDay(player, day)`, `devSetLastClaim(player, ydayOffset)`, `reset(player)`, `devAddBoost(player, kind, multiplier, durationSec)`. UTC через `os.date("!*t")` |
| `core/PlayerBoosts.lua` | **Phase 10:** модуль чистых функций. `totalMultiplier(activeBoosts, kind)` — `1 + sum(boost.multiplier - 1)` (аддитивный стек, две x2 → x3). `addBoost(activeBoosts, { kind, multiplier, durationSec })` — стек по `kind` (продлевает existing если новый expiresAt дальше). `cleanup(activeBoosts, now?)` — мутирует на месте, возвращает true если что-то удалили; вызывается в `onProfileLoaded` и в `SellInventory.execute` перед расчётом. `activeFor(activeBoosts, kind)`, `toPayload(boost, now)`, `toPayloadList(activeBoosts, now)` — для buildHudPayload (расчёт `remainingSeconds`). Истёкшие boost'ы переживают рестарт через `expiresAt` в профиле |
| `core/PetManager.lua` | **Phase 11 (Pets MVP):** DI как RebirthManager/DailyReward (`profileManager`, `onProfileChanged=onEconomyChanged`, `notify`). `Net:Handle("HatchEgg", count)` — валидация `coins >= EggManager.totalCost`, списание монет, `EggManager.hatch` (weighted roll), append записей `{ uid, petId }` в `playerData.pets` (uid через монотонный `petUidCounter`), авто-equip первого пета если слот пуст, возврат `hatched`-списка для клиентского PetHatchFX. `Net:Handle("EquipPet", uid)` / `UnequipPet` — multi-slot (Phase 12: до `PetLogic.maxEquipped(data)` слотов, FIFO-вытеснение). `grantHatch(player, count)` — публичный хук для MonetizationManager «Egg 10x». `onProfileLoaded` — ensure-поля + чистка битых equipped uid'ов (string/list). DI-методы `devHatch` / `devGivePet` / `devClearPets`. Эффекты НЕ применяет — это MiningEngine/SellInventory через PetLogic |
| `core/MonetizationManager.lua` | **Phase 12 (Монетизация):** DI (`profileManager`, `onProfileChanged`, `notify`, `petManager`). `MarketplaceService.ProcessReceipt` → `_grantProduct` (coins / eggs) + DataStore `PurchaseHistory_v1` (ключ `userId_purchaseId`). `PromptGamePassPurchaseFinished` + `onProfileLoaded` → `UserOwnsGamePassAsync` → кэш `gamepasses[key]` + `_applyGamepassEffects` (autoSell, VIP-тег). VIP BillboardGui на Head (титул + золотой ник). DevHooks: `devGrantPass`, `devRevokePass`, `devGrantProduct`. Формулы — `MonetizationLogic` |
| `core/DiscoveryManager.lua` | **Phase 13 (Ore Discovery Index):** DI (`profileManager`, `onProfileChanged`, `notify`). `recordDiscovery(player, oreId)` — первая добыча → `kind="ore_discovered"`; полный слой → milestone coins + `kind="layer_milestone"` (`discoveredMilestones` anti-double). `onProfileLoaded` — ensure-поля + тихий бэкфилл из `inventory` (без ретро-milestone). DevHooks: `devDiscover`, `devDiscoverAll`, `devResetJournal`. Формулы — `DiscoveryLogic` |
| `core/QuestManager.lua` | **Phase 16 (Цели):** DI (`profileManager`, `onProfileChanged`, `notify`, `notifyOnce`). Цепочка квестов (прогресс выводится из счётчиков профиля — отдельный per-event трекинг не нужен). `onProfileLoaded` — ensure `claimedQuests`. `evaluate(player)` — если активный квест стал выполним, шлёт тост «забери награду» один раз на квест (`notifyOnce` + `_readyNotified`). `claim(player, questId)` — валидирует что это активный + выполненный + не забранный квест, начисляет `reward.coins/gems` (+`totalCoinsEarned`), `claimedQuests[id]=true`, тост, `_sync`. DevHooks: `devResetQuests`, `devCompleteActive`. Формулы/каталог — `QuestLogic` |
| `core/AchievementManager.lua` | **Phase 16 (подключён, был заглушкой):** DI (`profileManager`, `onProfileChanged`, `notify`). Разблокировки персистятся в `playerData.unlockedAchievements`. `check(player, data)` — проверяет все ачивки, начисляет `reward.coins/gems`, тост `kind="achievement_unlocked"`, возвращает `changed` (caller сам делает HUD-sync). Заглушки починены: `collector_10` → `DiscoveryLogic.totalProgress(data).found >= 10`, depth-чеки → `data.maxDepthReached`, `shaft_finder` → `data.shaftRoomCount >= 10`; `boss_slayer` помечен `hidden=true` (боссов в MVP нет — не показывается/не выдаётся). `buildPayload(data)` для HUD (только видимые). `loadUnlocked` — ensure-поля |
| `core/EggManager.lua` | **Phase 11:** plain-модуль (без .new/DI). Экономика яиц: `getEgg(eggId)` (из `Constants.PETS.eggs`), `totalCost(eggId, count)`, `clampCount(count)` (батч 1..`hatchBatchMax`, серверный античит на «open 10×»), `hatch(eggId, count, rng?)` — оркестрация count, weighted roll делегирован `PetLogic.rollHatch`. MVP: один тип «basic» (Basic Egg) |
| `core/Leaderboard.lua` | **Phase 10 (наполнен, был пустышкой):** `MemoryStoreSortedMap` × 2 (`Leaderboard_Coins_v1` для `totalCoinsEarned`, `Leaderboard_Depth_v1` для `maxDepthReached`). Ключ = `"user_<userId>"`, значение = integer score (через `LeaderboardLogic.toScore`), `expirationSeconds = 30 дней` TTL. `writeIfChanged(player)` пишет только при `LeaderboardLogic.shouldWrite(boardId, lastWritten, current)` (delta >= `writeThresholdCoins=100`/`writeThresholdDepth=5`) — `lastWritten` живёт в `data.leaderboardPlacement.coinsValue/depthValue` (auto-cleanup при profile release). `fetchTop(boardId)` через `GetRangeAsync(Descending, topSize)`, имена через `Players:GetNameFromUserIdAsync` + `nameCache`. `_startRefreshLoop` обновляет snapshot раз в `refreshIntervalSeconds=30`, при ошибке MemoryStore — exp-backoff `2/4/8с`. `Net:Function("RequestLeaderboard")` — server-side throttle 5с на игрока, возвращает `{ coins = { entries, myRank, error? }, depth = { ... }, nextRefreshAt }`. `_updateOnlineRanks` обновляет `data.leaderboardPlacement.coinsRank/depthRank` после refresh'a — клиент видит свой ранг в StatsPanel. `onPlayerLeaving` финализирует write + чистит throttle. `nil`-fallback на MemoryStore failure (UI рисует «загрузка / сервис недоступен») |
| `core/DevCommands.lua` | `/coins`, `/reset`, `/maxlvl`, `/skiptut`, `/devhelp` (Studio); Phase 8 — `/reset` через `tutorialManager:reset()` снова выдаёт стартовый бонус и сбрасывает шаги, `/skiptut` принудительно ставит `tutorialStep=3` + `firstSession=false` (для теста не-онбординг-фич); **Phase 9:** `/rebirth [N]` через `rebirthManager:devRebirth(player, N)` (без проверки цены); `/reset` НЕ трогает rebirths (для теста tutorial flow); **Phase 10:** `/daily` (шлёт `kind="daily_available"`, открывает модал немедленно), `/setday <N>` (сдвигает `lastClaimYday` на N дней назад для теста streak'а), `/resetdaily` (через `dailyReward:reset(player)`), `/boost <minutes>` (даёт x2 coins boost на N минут), `/leaderboard refresh` (форс `leaderboard:_refresh("coins")` + `"depth"`). `/reset` НЕ трогает dailyState / activeBoosts (для них `/resetdaily` отдельно); **Phase 11:** `/egg [N]` (free-hatch N петов через `petManager:devHatch`), `/hatch` (алиас `/egg 1`), `/pet <id>` (выдать пета по petId), `/clearpets` (очистить петов + снять экипировку); **Phase 12:** `/grantpass <vip|autoSell|petSlots>`, `/grantproduct <coinsSmall|coinsMedium|egg10> [N]`; **Phase 13:** `/discover <oreId>`, `/discoverall`, `/resetjournal`; **Phase 16:** `/resetquests` (сброс цепочки квестов), `/completequest` (подогнать счётчик активного квеста под target — для теста claim) |

### Сервер — системы вне исходного MVP-скоупа
| Файл | Что делает |
|------|------------|
| `core/PromoCodeManager.lua` | DI (`profileManager`, `onProfileChanged?`, `notify?`). `Net:Handle("RedeemCode")` — валидация через `PromoCodeLogic`, резерв слота глобального лимита через `PromoCodeGlobal_v1` DataStore `UpdateAsync`, начисление coins/gems/boosts (`PlayerBoosts.addBoost`), per-player anti-spam лок. `onProfileLoaded` |
| `core/SocialRewardManager.lua` | DI. Бесплатная награда за «вступить в группу + добавить в избранное». `Net:Handle`: `ConfirmSocialFavorite`, `ClaimSocialReward`, `RefreshSocialStatus`; членство в группе через `GroupService:GetRankInGroupAsync` (кэш), favorite — honor-system. Выдаёт `Constants.SOCIAL_REWARD.rewards`. `buildPayload`, `refreshGroup`, `onProfileLoaded` |
| `core/MineDeckCollision.lua` | `start(hasSurfaceBlock)` — позволяет игроку проваливаться сквозь выкопанные ячейки shared-пола (Union). Регистрирует collision-группы `MineDeck`/`MinePass`, санитайзит workspace через `MineZoneWorkspace`, каждый Heartbeat переключает персонажа pass/solid по колонке (`MiningReach`) + инжектированный предикат |
| `core/PetAssetBootstrap.lua` | `run()` — клон `Workspace.Pets`/`Eggs` → `ReplicatedStorage.PetKit` (клиент клонирует без гонки с workspace), валидация `PetDatabase`↔модели, затем прячет исходный `Pets` в `ServerStorage` |
| `core/PlayerTag.lua` | DI (`achievementManager?`). Реплицируемый `BillboardGui`-титул + аура (`Highlight`/`PointLight`/`ParticleEmitter`) по 6-тировой ребёрт-лестнице (0→50+) + золотой VIP-оверрайд (`MonetizationLogic.isVip`); кэш последнего состояния. `apply`/`onCharacterAdded`/`onPlayerRemoving` |

### Клиент
| Файл | Что делает |
|------|------------|
| `init.client.lua` | Orchestrator: renderer, HUD, Notify, Tutorial, FX. `LayerAmbience`, `EggMachines` (lazy), `HomeFX`+`GoHome`, `Headlamp` (no-op: `HEADLAMP.enabled=false`), `FreezeDiagnostics`, coalesced HUD updates, hot `PlayerHudDelta` path |
| `core/EggMachines.lua` | **Phase 17:** ProximityPrompt на `Workspace.Eggs`; только **Basic** hatch'ит, остальные — toast «скоро» |
| `ui/HomeFX.lua` | Iris-wipe телепорт на spawn (`GoHome`) |
| `core/LayerAmbience.lua` | **Phase 17:** ambient при смене слоя — enter-звук, sparkle + fog particles на персонаже. Данные: `LayerProfile.IDENTITY` |
| `ui/OreDiscoveryFX.lua` | **Phase 13:** reveal «✦ НОВАЯ НАХОДКА ✦» — аура, shockwave-кольца, pop-in иконки руды, имя/редкость, ✦-искры, очередь до 6 находок, non-blocking overlay (DisplayOrder 94), hold дольше для rare+ |
| `core/MiningRenderer.lua` | 3D-блоки, juice (Phase 7), **low-poly** визуал + `OreShellMeshes` + `OreFXPalette` + `LayerProfile.BLOCK_GLOW` + **CURSOR_LIGHT** + create-budget 25/frame (~1.9k строк) |
| `core/OreLookup.lua` | O(1) лукап `oreId → OreDef` поверх `shared/data/OreDatabase` (color/rarity/icon/name/rarityColor) |
| `core/DepthTracker.lua` | Клиентский трекер глубины по `HumanoidRootPart.Y` |
| `core/LayerEnvironment.lua` | Твин `Lighting.Ambient/OutdoorAmbient/FogColor` по слою; **Phase 14:** + твин `Brightness`/`ClockTime`/`FogEnd` и ленивый `Atmosphere` (Density/Haze/Color/Decay) по `Constants.LAYER_LIGHTING` — ощущение «спуска вглубь» (dirt = яркий полдень → void = почти тьма). Без fullscreen post-processing |
| `core/Headlamp.lua` | PointLight на HRP, масштаб с глубиной. **`Constants.HEADLAMP.enabled = false`** — модуль вызывается, но свет выключен; активен `CURSOR_LIGHT` в `MiningRenderer` |
| `core/SoundManager.lua` | Кэш Sound-инстансов в SoundService под `DeepDigger_Sounds`, 2 SoundGroup (sfx/ui), 3D-звуки через временный Attachment + Debris, API: `start / play / playForOre / setVolume` |
| `core/CameraShake.lua` | Перезаписываемый offset CFrame на RenderStepped, авто-откат прошлого кадра (не накапливается). Пресеты `hit / crit / rare_break / break / legendary_break` — но из MiningRenderer вызываются только break-пресеты (на rare+), hit/crit пресеты в API «на потом» (бои в патчах) |
| `core/Haptics.lua` | `pulse("hit"\|"crit"\|"break"\|"legendary_break")`, hit-пульс ОЧЕНЬ мягкий (0.12/0.03 — копание = 4 клика/сек), `pcall` вокруг `HapticService:SetMotor`, no-op на десктопе |
| `ui/HUD.lua` | **Phase 17:** Fusion-фасад. Монтирует `CurrencyRibbon` + `InventoryWidget` + `LeftSidebar` (dock + sell) + modal `MainPanel`. `destroy()` при выходе. Старый TopBar/TabBar не используется |
| `ui/hud/panels/LeftSidebar.lua` | **Phase 17:** dock (5 nav + sell + Home pill). Popup «Ещё» → **pets**, stats, rebirth, leaderboard, shop |
| `ui/hud/panels/MainPanel.lua` | **Phase 17:** full-screen modal 600×450, backdrop, scale-in, цветной header. Все 9 content-панелей внутри; видимость через `state.panelOpen` |
| `ui/hud/components/{CurrencyRibbon,InventoryWidget,DockIcon,DepthBar}.lua` | **Phase 17:** верхние чипы валюты/глубины/рюкзака; dock-кнопки с `UiAssets` иконками; depth progress bar |
| `ui/hud/components/SellButton.lua` | **Phase 17:** только логика `SellButton.activate()` → `Net:Invoke("SellOres")` + Notification; UI sell — в `LeftSidebar` |
| `ui/util/{UiInteract,UiMotion}.lua` | **Phase 17:** hover/press scale для GuiButton; `ensureScale` + tween через TweenService |
| `ui/hud/panels/{TabBar,TopBar,BottomDock}.lua` | **Legacy (Фаза 17):** не монтируются в `HUD.lua`. `TopBar` — stub; `BottomDock` — альтернативный прототип dock |
| `ui/Notification.lua` | Переиспользуемая всплывашка (используется для error-UX тостов в Phase 8); Phase 9 — тост «REBIRTH! Ребёрт #N, x1.X к ценам руд» приходит сюда через тот же канал, RebirthFX триггерится отдельно по `payload.kind == "rebirth"` |
| `ui/RebirthFX.lua` | **Phase 9 (prestige FX):** локальный mining-style эффект в позиции игрока — 3 золотых shockwave-кольца (ForceField-сфера, размеры 22/32/40 студов с задержками 0/0.15/0.35с) + 30 золотых физических chunks (Neon, gravity-affected, fade через Debris). **Без camera-shake / slow-mo / fullscreen flash** — соблюдены Phase 7 mining-принципы. Падение FX не сорвёт сам ребёрт (pcall в init.client.lua) |
| `ui/RewardFX.lua` | **Phase 10 (daily claim FX):** full-screen overlay (PlayerGui `DeepDigger_RewardFX`, DisplayOrder=92) — НЕ block-position, в отличие от RebirthFX. Coin/gem rain: 60 спрайтов 💰 (TextLabel + UIStroke) с physics-падением сверху + rotation + fade на дне (~1.2с/шт). 3 rarity-цветных shockwave кольца в центре (ImageLabel + UIStroke, scale 0→2.8 с задержками 0/0.15/0.3с). Total ~1.5с. `pcall`-обёртки, no-op fallback при отсутствии PlayerGui. Триггерится только из `Net:Connect("Notify")` с `payload.kind="daily_reward"` (rarity-aware из сервера) |
| `ui/PetVisual.lua` | **Phase 11/17:** 3D followers через `PetModelKit.clonePetDisplay`, arc slots + bobbing. Не emoji-сфера |
| `ui/PetHatchFX.lua` | ViewportFrame яйцо, shake, shockwaves, 3D pet preview cards, tap-to-skip, ~2.8с auto-close |
| `ui/DailyRewardModal.lua` | **Phase 10:** full-screen overlay (ScreenGui `DeepDigger_DailyModal`, DisplayOrder=95 как RebirthConfirmModal). Header «🎁 Награда за день · Стрик: 🔥 N», сетка 7 `DailyCard`'ов (4×2 desktop / 2×4 mobile при `Camera.ViewportSize.X < 800`), footer с кнопками [ЗАБРАТЬ] (золотая, glow-pulse через `UIStroke` tween) и [ПОЗЖЕ] (серая). **Anti-misclick 0.4с** — кнопка claim'а disabled первые 0.4с (как Phase 9 RebirthConfirmModal). ESC / [ПОЗЖЕ] / клик по backdrop закрывают без claim'a. На клик [ЗАБРАТЬ] → `Net:Invoke("ClaimDaily")` (без аргументов — сервер сам вычисляет день/streak/награду) → success: SoundManager.play("sell_success") + закрытие через 0.8с (FX триггерится сервером через Notify, не из модала — избегаем двойного burst'a). Каждое `show()` создаёт собственный `parentScope:innerScope()` + `Fusion.doCleanup(s)` после закрытия — предотвращает накопление Value/Computed между показами. `_activeHandle` защищает от одновременных модалов |
| `ui/hud/components/DailyCard.lua` | **Phase 10:** 100×140px карточка дня в `DailyRewardModal`. Rarity-цветной `UIStroke` (common=серый, uncommon=зелёный, rare=синий, epic=фиолет, legendary=оранжевый, mythic=золотой + gradient). Иконка типа награды (💰 coins / ⚡ boost / 🎁 mythic), label «День N», текст награды (`reward.label`). Состояния: past (✓ галочка зелёная + затемнение), current (full opacity + `startPulse` tween 0.8→1.2с на UIStroke по rarity-цвету), future (~0.4 transparency + greyed out). Принимает `layoutOrder` в Props — устанавливается внутри Fusion-create чтобы не конфликтовать с UIGridLayout |
| `ui/hud/panels/LeaderboardPanel.lua` | Toggle coins/depth, spotlight #1, top 2–50, avatars, skeleton loading. Доступ: dock → «Ещё» → leaderboard |
| `ui/hud/panels/RebirthPanel.lua` | Prestige UI + RebirthConfirmModal. Доступ: dock → «Ещё» → rebirth |
| `ui/hud/components/LeaderRow.lua` | **Phase 10:** строка лидерборда. Async avatar через `Players:GetUserThumbnailAsync(userId, HeadShot, Size150x150)`, module-level `avatarCache: { [userId] = imageId }` (не дёргаем дважды для одного userId). Skeleton-placeholder (серый круг) пока фото грузится, fade-in при готовности. Rank (`LeaderboardLogic.formatRank(rank)` → "#42" / "👑#1"), Name, Value (`LeaderboardLogic.formatValue(boardId, value)` → "1.2k" / "500м"). Подсветка если `userId == LocalPlayer.UserId` — золотая обводка |
| `ui/hud/components/BoostChip.lua` | **Phase 10 / 17:** чип активного boost'a. **Phase 17:** встроен в `CurrencyRibbon` (не TopBar) |
| `ui/hud/components/StreakChip.lua` | **Phase 10 / 17:** чип streak «🔥 N дней». **Phase 17:** встроен в `CurrencyRibbon` |
| `ui/Tutorial.lua` | **Phase 8 (онбординг, polish):** singleton-orchestrator над `tutorial/TutorialFlow` (data-driven сцены) + `TutorialDialog` (бот-диалог) + `TutorialTracker` (квест-трекер) + `TutorialArrow`. Серверная семантика та же (0/1/2/3), клиентский flow развёрнут в `welcome → step_0_task → step_0_success → step_1_open_inventory → step_1_sell → step_1_success → step_2_open_upgrades → step_2_buy_pickaxe → finale`. Listener PlayerStats отслеживает `totalBlocksMined / totalCoinsEarned / pickaxeLevel` для авто-продвижения; tab-click listener для перехода inventory/upgrades. `Net:Invoke("UpdateTutorialStep")` шлётся ровно в success/finale scenes. `Tutorial.skip()` (✕ в диалоге) ставит шаг=3 и destroy. Polling реатачит arrow и tab-listener, если HUD ещё не был готов на момент enterScene. `refresh()` после respawn |
| `ui/TutorialArrow.lua` | **Phase 8:** `pointAt(target, text) → handle`. GuiObject → пульсирующий золотой UIStroke + label, RenderStepped «приклеивает» к target. BasePart → BillboardGui ⬇ с bounce-tween. Общий ScreenGui `DeepDigger_Tutorial`, `Active=false` (клик проходит сквозь) |
| `ui/tutorial/TutorialFlow.lua` | **Phase 8 polish:** data-driven последовательность сцен онбординга. `STEPS[]` (welcome / *_task / *_success / finale) с `speaker / name / text / kind / task / target / arrowText / completeOn / hideAdvanceButton / next`. `SERVER_STEP_AFTER` → когда какая сцена триггерит `UpdateTutorialStep`. `ENTRY_BY_SERVER_STEP` → точка входа при загрузке профиля с tutorialStep N. `getById / findIndex / getNext` — навигация. Все тексты диалогов и формулировки заданий ТОЛЬКО здесь — править язык/тон без правок логики |
| `ui/tutorial/TutorialDialog.lua` | **Phase 8 polish:** боттом-центр диалог наставника. Аватар (emoji ⛏️), имя, текст с typewriter-эффектом (~42 char/sec, UTF-8 safe через `utf8.offset`), кнопка [Понятно ✓], кнопка [✕] skip. `kind` управляет цветом stroke/avatar-ring/button (intro=gold, task=cyan, success=green, finale=mythic). Slide-in снизу 0.28с (Quad/Out), slide-out 0.2с. Клик где угодно по диалогу → мгновенно дописать typewriter. `Active=false` снаружи → геймплей не блокируется. `handle:update(opts)` без destroy для смены содержимого. Парентится в общий `DeepDigger_Tutorial` ScreenGui |
| `ui/tutorial/TutorialTracker.lua` | Квест-трекер справа. «Задание N из M», progress bar, ✓ на complete |
| `ui/hud/components/Tooltip.lua` | **Phase 8:** `Tooltip.attach(scope, target, getText)`. Hover-tooltip с RichText, fade 0.1с, edge-clamping. Cleanup через Fusion scope. Применён в `UpgRow` |
| `ui/hud/components/AnimatedNumber.lua` | **Phase 8:** `tween(state, target, dur)` плавно меняет Fusion.Value<number> через Heartbeat + Quad/Out (дефолт 0.3с). `snap` / `cancel`. Используется для `coinsDisplay` и `statTotalCoinsDisplay` в HudState |
| `ui/hud/components/RebirthConfirmModal.lua` | **Phase 9:** модальное окно подтверждения ребёрта. Затемнение фона (ScreenGui `DeepDigger_RebirthModal`, DisplayOrder=95), центрированный фрейм 420×280 с золотым stroke. Кнопка [РЕБЁРТ] disabled первые **0.3с** (anti-misclick задержка) — игрок не может «слепо» прокликать. ESC / клик по backdrop / [ОТМЕНА] закрывают без действия; Modal Frame `Active=true` чтобы клик по голому телу не проваливался на backdrop. Fade-in 0.18с, fade-out 0.12с |
| `ui/hud/theme.lua`, … | **Phase 17:** `theme.lua` переписан — dark navy, `TAB_ACCENTS`, `TAB_LABELS`, `LAYER_COLORS` |
| `ui/hud/components/{InvSlot,TabBtn,UpgRow,ResourceChip,StatRow}.lua` | Атомарные виджеты. **Phase 17:** `UpgRow` + `UiAssets` иконки; `ResourceChip` + coin image; `TabBtn` legacy (TabBar не монтируется) |
| `ui/hud/panels/{InventoryPanel,UpgradesPanel,StatsPanel,MainPanel,TabBar,TopBar}.lua` | Content-панели (Phase 1–6). **Phase 9–16:** аддитивные табы в `MainPanel`. **Phase 17:** `MainPanel` стал modal-overlay; `TabBar`/`TopBar` deprecated |
| `ui/hud/panels/JournalPanel.lua` | Журнал **54** руд по слоям. Dock → journal. `OreEntry` + pixel icons |
| `ui/hud/panels/GoalsPanel.lua` | 10 квестов + 7 достижений. Dock → goals (badge при claimable). Gems в тексте награды, не в ribbon |
| `ui/hud/components/OreEntry.lua` | Ячейка руды в журнале; `OreIcon` (pixel/PNG) |
| `ui/hud/components/OreIcon.lua` | **Phase 17:** иконка руды из `OreAssets` / baked pixels |
| `ui/hud/panels/ShopPanel.lua` | Gamepasses + DevProducts. Dock → «Ещё» → shop. id=0 → disabled |
| `ui/hud/components/ShopCard.lua` | Карточка товара; PURCHASE → Marketplace prompts |
| `ui/hud/panels/PetsPanel.lua` | Hatch/equip/grid. Dock → **«Ещё» → pets** |
| `ui/hud/components/PetCard.lua` | **Phase 11:** карточка пета в PetsPanel |

### Клиент — системы/компоненты вне исходного MVP-скоупа
| Файл | Что делает |
|------|------------|
| `core/HubZones.lua` | Обвязка `Workspace.SELL`/`UPGRADE` hub-моделей `ZoneBillboard`-пиллами; Heartbeat distance-check (enter 17 / exit 22) дёргает `onSell`/`onUpgrades` при входе, закрывает upgrades при выходе |
| `core/WorldLeaderboard.lua` | Fusion-`LeaderboardPanel` на `SurfaceGui` физического leaderboard-`Model` в Workspace (авто-поиск модели/экрана, 3D-текст inset, ретрай до 45с) |
| `core/PlayerTagScale.lua` | Ресейл over-head `PlayerTag` BillboardGui по тиру устройства: читает server-baked `Base…` атрибуты, ужимает size/text/badge через `ViewportLayout.tagTitleMult()` на phone/tablet |
| `core/MiningBlockDecor.lua` | Чистый матем-хелпер (без инстансов): видимость блока (дистанция + FOV dot) и выбор блоков под decor в рамках count-бюджета, hover-приоритет |
| `ui/EggShopModal.lua` + `ui/EggShopLayout.lua` | Полноэкранный egg-shop: 3D-превью яйца, cost-box, drop-odds список, грид пула петов, footer 1×/10× (coins + Robux). `Net:Invoke("HatchEgg")` + `PetHatchFX`. Геометрия вынесена в `EggShopLayout` |
| `ui/PromoCodeModal.lua` | Модал ввода промокода на `HudModalChrome`: reward-preview, TextBox кода, Activate → `PromoCodeActions.tryRedeem`; viewport-reactive |
| `ui/SocialRewardModal.lua` | Модал бесплатной соц-награды: статус группы/favorite, reward-preview, кнопки join/favorite/claim через `SocialRewardActions` |
| `ui/HomeFX.lua` | Мультяшный iris-wipe: чёрный круг закрывает экран, `onPeak()` (телепорт) в полной темноте, светлый круг открывает; re-entrant no-op |
| `ui/tutorial/TutorialPathGuide.lua` | Наземный path-guide (`.follow`): raycast по террейну кладёт до 9 fading directional-маркеров от игрока к цели + пульсирующий goal-pin BillboardGui, апдейт каждый Heartbeat |
| `ui/world/ZoneBillboard.lua` | Компактный pill-BillboardGui (accent bar + icon + title) на hub-зоне; handle с `setInZone` для подсветки внутри зоны |
| `ui/util/ViewportLayout.lua` | Центральный responsive-модуль: классификация phone/tablet/desktop, UI scale, text/chrome/dock множители, modal-sizing/centering, subscribe на viewport/safe-area |
| `ui/util/UiScreen.lua` | Фабрика ScreenGui (`apply`/`ensure`): DisplayOrder + safe-area insets по профилю (hud/modal/toast/tutorial/tooltip/fx), backdrop-хелперы |
| `ui/util/VerifyHudLayout.lua` | Studio-only smoke: после сборки HUD варнит, если ScreenGui/ключевые узлы под топбаром, за границами экрана, или inventory-widget пустой/мелкий |
| `ui/hud/PanelScale.lua` | Text/geometry-скейл для панелей/модалок поверх `ViewportLayout` (readability-floor, desktop ×2 `gsc`, price-boost, `modal*`-варианты) |
| `ui/hud/panels/LeftSidebar.lua` | **Активный** нижний dock (root Frame `LeftSidebar`): 7 `DockIcon`-табов, shop как центр-hero, пульсирующий «🏠 Домой» pill при depth>0; viewport-reactive |
| `ui/hud/panels/BottomDock.lua` | Отдельный/старый фикс-dock: центр-ряд primary-табов + «ЕЩЁ» → `MoreMenu` popout (не активен) |
| `ui/hud/components/CurrencyRibbon.lua` | Верхне-левый стек HUD: coin `ResourceChip` + `DepthBar` + строка статуса (rebirth-чип + `StreakChip`) |
| `ui/hud/components/InventoryWidget.lua` | Верхне-правый чип рюкзака: fill = used/max (capacity из `UpgradeLogic`), цвет по заполнению, «ПОЛНЫЙ» |
| `ui/hud/components/DockIcon.lua` | Мульти-вариант dock/nav-кнопки: sell CTA, shop hero, nav (icon+label+active-bar), legacy square; hover/press motion |
| `ui/hud/components/TopRightActionRow.lua` | Ряд под inventory-чипом: `PromoCodeButton` + `SocialRewardButton` |
| `ui/hud/components/BuffBar.lua` + `BuffSlot`/`BuffIcon`/`BuffEffectChip` | Нижне-левый бар активных баффов: сбор pet/boost/gamepass-эффектов через `BuffLogic`, ряд `BuffSlot` c локальным countdown таймеров; `BuffMeta` для icon/color/label |
| `ui/hud/components/QuestTracker.lua` | Карточка активного квеста (right-center desktop / под ribbon phone): имя/desc/прогресс-бар + claimable-badge; клик → таб goals; скрыт при открытой панели |
| `ui/hud/components/OreIcon.lua` | Иконка руды с фолбэком: rbxassetid → baked pixel `ImageContent` → emoji |
| `ui/hud/components/UiIcon.lua` | Обобщённая HUD-иконка (`UiAssets.resolve`) + `titleRow`-хелпер |
| `ui/hud/components/HudModalChrome.lua` | Общий каркас модалки: градиент-фон, accent-stroke/bar, close-кнопка, опц. `UIScale`-design-space |
| `ui/hud/components/RobuxPrice.lua` | Robux-иконка + цена, опц. strikethrough «было», горизонт/вертикаль |
| `ui/hud/components/ShopBoostCard`/`ShopFeaturedCard`/`ShopPurchase.lua` | Карточки магазина (boost 2-col, hero-pack с discount/strikethrough) + `ShopPurchase.prompt` (Marketplace / «not configured» при id=0) |
| `ui/hud/components/RewardPreviewChip`/`RewardPreviewRow.lua` | Reward-таблица (coins/gems/boost) → набор reward-чипов в modal-design-px |
| `ui/hud/components/ChromeIconButton.lua` | Переиспользуемая square top-chrome кнопка (glow, pulse/badge, hover/press, `onActivated`) — база для promo/social кнопок |
| `ui/hud/components/{PromoCodeButton,PromoCodeCard,SocialRewardButton,SocialRewardCard}.lua` | Кнопки в top-chrome + карточки в панелях (Goals/Shop) для промокодов и соц-награды |
| `ui/hud/components/{EggShopEggPreview,EggShopPetTile,EggHatchFooter}.lua` | Компоненты egg-shop: 3D-превью яйца, tile пула пета с drop-%, footer 2×2 (coins + Robux) |

### Shared
| Файл | Что делает |
|------|------------|
| `data/UiAssets.lua` | **Phase 17:** реестр UI-иконок (`IconKey`). `ROBLOX_IMAGES` (rbxassetid) + fallback `ReplicatedStorage.uiAssets`. API: `image(key)`, `coin()`, `tab(tabId)`, `upgrade(upgradeId)` |
| `data/LayerProfile.lua` | **Phase 17:** `IDENTITY` (music, enter, particles, fog, breakDust per layer) + `BLOCK_GLOW` (per-layer rarity glow caps). Читают `LayerAmbience`, `MiningRenderer`; алиас в `Constants.LAYER_PROFILE` |
| `util/OreFXPalette.lua` | **Phase 17:** палитра VFX руды (`fromColors`, `particleGradient`, `tintDescendants`). `MiningRenderer` + `OreDiscoveryFX` |
| `util/OreShellMeshes.lua` | **Phase 17:** mesh/scale накладки OreShell по rarity (rare/epic отдельные meshId). Резолв из Workspace Kit / ReplicatedStorage |
| `data/OreAssets.lua` | **Phase 17:** реестр иконок руд (rbxassetid + uiAssets fallback) |
| `data/OreIconPixelLoader.lua` | Загрузка baked 64×64 RGBA из `OreIconPixels/*.lua` |
| `data/PetDatabaseEntries.lua` | **30** сырых записей петов с `modelName` для 3D |
| `util/PetModelKit.lua` | Клон/монтирование 3D pet models (viewport + world followers) |
| `constants.lua` | LAYERS, UPGRADES, REBIRTH, PETS, GAMEPASSES, DEVPRODUCTS. `HEADLAMP.enabled=false`, `CURSOR_LIGHT` active. `LAYER_PROFILE` алиас на `LayerProfile` |
| `util/DiscoveryLogic.lua` | Каталог **54** discoverable руд по слоям, milestones, progress |
| `util/QuestLogic.lua` | **Phase 16 (Цели):** единственный источник цепочки квестов (как DiscoveryLogic). ~10 квестов `{ id, name, desc, metric, target, reward }`, `metric` ∈ blocksMined / coinsEarned / depth / oresDiscovered / rebirths / shaftRooms. `progressValue(data, metric)` читает счётчик профиля (`totalBlocksMined` / `totalCoinsEarned` / `maxDepthReached` / `DiscoveryLogic.totalProgress().found` / `rebirths` / `shaftRoomCount`), `activeQuest(data)` (первый незабранный), `isComplete`, `buildActivePayload(data)` (для HUD: progress/target/claimable), `claimedCount` / `totalCount` |
| `util/MonetizationLogic.lua` | **Phase 12:** единственный источник формул монетизации. `ownsGamepass`, `isVip`, `coinBoost` (аддитив +10% VIP), `petSlotBonus` (+2), `gamepassById` / `productById`, `vipNameColor` |
| `data/PetDatabase.lua` | **30 питомцев** (из `PetDatabaseEntries`), лукапы byId/byRarity/getAll. Эффекты damage/luck/coin/multiMine |
| `data/OreDatabase.lua` | **55** записей (**54** discoverable + `test_glow`), 7 слоёв. **Low-poly:** `color` + `weight` + `protrusion="crystal"`; `material/reflectance/glow` не используются. `oil_deposit`: value=0, dropsOil=true (post-MVP) |
| `data/SoundDatabase.lua` | ~38 sound events (hit/break/layer music/enter/UI). Roblox stock audio, `TODO playtest` |
| `data/DailyRewardDatabase.lua` | **Phase 10:** 7-дневный цикл наград. `[1..6] = { type, amount, [duration], rarity, label }`, `[7] = { type="coins", amount=50000, rarity="mythic", bonusBoost = { multiplier=2, duration=1800 }, label="+50,000 + x2/30мин" }`. Rarity ramp: common → common → uncommon → rare → epic → legendary → mythic. Helper'ы `get(day)` (с fallback в Day 1 для невалидных) и `iconForReward(reward)` (💰 coins / ⚡ boost / 🎁 mythic). Чистый data-модуль без логики claim'а — последняя в `shared/util/DailyLogic.lua` |
| `util/LayerUtil.lua` | depth↔layer, colorToPayload |
| `util/UpgradeLogic.lua` | Все формулы апгрейдов; **Phase 8:** `describeCurrentLevel(id, lvl) → "урон 11"` и `describeNextLevel(id, lvl) → "урон 11 → 13"` для Tooltip'ов; **Phase 9:** `UpgradeLogic.maxLevel(upgradeId, rebirths?)` — динамический потолок (pickaxe = `cfg.maxLevel + RebirthLogic.pickaxeMaxLevelBonus(rebirths)`); `describeNextLevel` принимает опциональный `rebirths` чтобы tooltip pickaxe после R5/R10/R25 показывал next-level вместо «MAX» |
| `util/RebirthLogic.lua` | **Phase 9 (prestige):** единственный источник формул ребёрта. `cost(rebirths) = floor(baseCost * exponent^rebirths)`, `valueMultiplier(rebirths) = 1 + rebirths * multiplierPerRebirth`, `pickaxeMaxLevelBonus(rebirths)` — количество перейденных порогов из `Constants.REBIRTH.pickaxeMaxBonusAt`, `nextPickaxeBonusThreshold(rebirths)` — ближайший непройденный порог, `describeReward(currentRebirths) → "К ценам руд: x1.0 → x1.1"` для RebirthPanel. Запрещены дубликаты этих формул в RebirthManager / SellInventory / RebirthPanel — только вызов отсюда |
| `util/DailyLogic.lua` | **Phase 10 (retention):** единственный источник формул дня. `currentDay(now?)` → `{ yday, year }` через `os.date("!*t")` (UTC, восклицательный знак — обязателен). `daysBetween(prev, curr)` — diff в днях с учётом перехода через границу года (через `os.time({...12:00})`). `canClaim(dailyState, now?)` — `gap > 0` (не today). `nextStreak(dailyState, now?)` — `1` если gap==0 (already), `currentStreak+1` если gap==1, `1` если gap >= streakResetAfterMissedDays. `streakToCycleDay(streak)` — `(streak - 1) % cycleDays + 1` (1..7). `timeUntilNextDay(now?)` → `{ hours, minutes, seconds }` до полуночи UTC. Запрещены дубликаты `os.date("!*t").yday` в нескольких местах — только через эти helper'ы |
| `util/LeaderboardLogic.lua` | **Phase 10:** единственный источник формул лидерборда. `toScore(value)` — округляет в integer для MemoryStoreSortedMap. `formatRank(rank)` → `"#42"` / `"👑#1"` / `"—"` (для nil). `formatValue(boardId, value)` — short-format `"1.2k"`/`"500m"`/`"1.5b"` для монет, `"123м"` для глубины. `crownForRank(rank)` → `"👑"` если rank==1, иначе nil. `shouldWrite(boardId, lastWritten, current)` — `current > lastWritten + writeThreshold` (delta-based throttle, чтобы не спамить MemoryStore при каждой продаже) |
| `util/PetLogic.lua` | **Phase 11 (Pets MVP):** единственный источник формул пет-системы (как RebirthLogic/DailyLogic). `maxEquipped(data?)` — base + `MonetizationLogic.petSlotBonus` (Phase 12), `rollHatch(rng?)` (weighted random по `Constants.PETS.basicEggWeights` → равновероятно внутри пула rarity, с фолбэком вниз), `getEquippedUids(data)` (поддерживает string и list — multi-slot), `getEquippedPets(data)`, `damageMultiplier` (1+Σ damageBoost), `luckMultiplier` (clamp `luckMaxMultiplier`), `coinBoostSum` (аддитив), `multiMineChance` (clamp `multiMineMaxChance`), `summary(data)` (для HUD-payload), `effectShort`/`describeEffect`. Аккумуляция additive (как PlayerBoosts: два +20% = +40%). Запрещены дубликаты этих формул в менеджерах |
| `util/InventoryUtil.lua` | totalCount, addOre |
| `util/Logger.lua`, `util/Signal.lua` | Утилиты |
| `types/OreTypes.lua` | Типы `OreDef`, `PlayerData`. `OreDef.xp` — мёртвое поле. `gems` в профиле без UI sink. `bossesDefeated` без boss system |

### Shared — системы вне исходного MVP-скоупа
| Файл | Что делает |
|------|------------|
| `util/PromoCodeLogic.lua` | Чистая валидация промокодов (client+server): `normalize`, `ensureRedeemed`, `isRedeemed`, `validate(data, rawCode, now?)` (существование/expiry/повтор) |
| `util/SocialRewardLogic.lua` | Хелпер соц-награды поверх `Constants.SOCIAL_REWARD`: `groupId`/`universeId`/`isConfigured`, `ensureFields`, `buildPayload(data, inGroup)` (гейт `canClaim`) |
| `util/MutationLogic.lua` | Единый источник мутаций руды (`Constants.MUTATIONS`): `roll(rng?)` (rollChance-гейт + взвешенный вариант), `get`/`valueMultiplier`/`tint`/`label`. Сервер роллит и считает бонус, клиент — tint/label для FX |
| `util/DailyQuestLogic.lua` | Повторяемые ежедневки (3 шт: 300 блоков / 8000 монет / 2 комнаты), сброс по UTC-дню, прогресс = дельта от дневного baseline монотонных счётчиков. `getAll`/`ensureReset`/`progress`/`isComplete`/`isClaimed`/`buildPayload`/`secondsUntilReset` |
| `util/EggMonetization.lua` | Robux-прайсинг + devproduct-ключи для покупки яиц: `productKey`, `robuxPrice` (1×/10× per egg), `registerDevProducts()` авто-инжектит `egg_<id>_<n>` в `Constants.DEVPRODUCTS` (на require) |
| `util/MiningReach.lua` | Grid↔world координаты + reach из `Constants`: `maxStuds`/`slackStuds`/`blockCenter`/`resolveOrigin(ws)`/`surfaceTopY`/`worldToColumn`/`isWithinReach` |
| `util/MineZoneWorkspace.lua` | Санитайзер mine-зоны: `sanitize(ws)` (non-query маркеры, deck-parts), `columnInSurfaceGrid`. Используется `MineDeckCollision` |
| `util/OreBlockDecor.lua` | Единый визуал ore-блоков (reference-блоки + `MiningRenderer`): host/shell/rarity цвета, mesh-shell грани, rarity-gated ambient FX + glow PointLight. Зависит от `OreFXPalette`/`OreShellMeshes` |
| `util/Base64.lua` | Минимальный base64→`buffer` декодер для Studio-окружений без `buffer.frombase64` |
| `util/PerfBeacon.lua` | Ультра-лёгкий per-frame счётчик активности для атрибуции фризов: `bump`/`addTime`/`drain`/`peek`/`reset`, гейт `enabled` |
| `data/PromoCodes.lua` | Таблица промокодов (`DEFINITIONS`): **2 кода** — `LAUNCH2026` (15k coins + 25 gems + x2 boost 30мин, cap 10000) и `WELCOME` (5k coins + 10 gems, unlimited) |
| `data/EggPoolDatabase.lua` | Gacha-пулы: `getPool(eggId)`/`getAllEggIds()`. **6 типов яиц**, по 6 взвешенных петов в каждом |
| `data/ShopCatalog.lua` | Layout/порядок магазина (6 секций: starter/featured/boosts/coins/eggs/gamepasses); данные товаров — из `Constants.DEVPRODUCTS`/`GAMEPASSES` |
| `data/BuffMeta.lua` | Icon/color/label баффов + мапперы: **5 видов** (`damage`/`luck`/`coin`/`multiMine`/`speed`), `BOOST_KIND`, `kindFromPetEffect` |
| `data/OreAssets.lua` | Резолвер иконок руд ~55 id → rbxassetid, фолбэк через `uiAssets/ores` + baked pixels. `image`/`iconContent`/`pixelContent` |

---

## 🟠 Заглушки и известные пробелы

### Post-MVP (задумано)
- `boss_slayer` — `hidden=true`, `bossesDefeated` всегда 0
- Гемы: начисляются, **нет UI и трат**
- `oil_deposit`, `OreDef.xp`, `playTime`, `shaftsFound[]` — мёртвые/неиспользуемые поля
- Достижения только в `server/` (не в `shared/` как `QuestLogic`)
- `millionaire` aura reward не применяется

### P0 — блокеры soft launch
- **Gamepass/DevProduct `id = 0`** — реальные покупки невозможны (блокер монетизации; egg-devproducts тоже через `Constants.DEVPRODUCTS`)
- **Плейтест Фазы 5 не пройден** — FPS/delta-трафик на 10+ мин копания не замерены

### P1 — launch quality
- **Depth**: `processDepthUpdate` теперь клампит client-trusted глубину к серверной позиции персонажа + slack (`Constants.DEPTH_VALIDATION.slackBlocks`, `serverDepthFor`) — грубый spoof обрезается, но это clamp, а не полноценная authoritative-модель
- **Reach**: `MiningReach.isWithinReach` есть в shared, но проверь, что он реально вызывается в `MineBlock`-хендлере (в `init.server.lua` reach-гейт на клики не виден)
- Плейтест Фазы 5 не пройден (чеклист ниже)
- Sound IDs — `TODO playtest`
- **OreDiscoveryFX** — проверить fade-out bug
- **Mobile HUD** — fixed 600×450 modal, dock ~446px

### P2 — техдолг
- Legacy HUD: `TabBar.lua`, `TopBar.lua`, `BottomDock.lua` — не монтируются, удалить после smoke
- Pets за 2 тапа (dock → Ещё) — слабая discoverability
- Дублирование VIP tag: `PlayerTag` + `MonetizationManager`
- `MiningRenderer` ~1.9k строк — кандидат на split post-launch
- Финальные PNG Creator Hub — вне кода

---

## 🔴 Post-MVP (патчи 1.1, 1.2 и большие апдейты)
- Trading между игроками.
- BossEngine (`boss_slayer` achievement ждёт).
- Server-side depth validation (если не до launch).
- 2–3 новых egg types (EggMachines уже ждут модели).
- Расширение квестов (сейчас 10) + достижений (сейчас 7).
- Gem UI + shop sink.
- Limestone+ feel pass (данные/ambient уже в коде).
- Гильдии / кланы, limited events.
- Расходники (молоток/бомба), auto-mine.
- Pet meta: fuse/level, inventory cap.

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
| 11. Pets MVP (**30** петов, 3D, egg, hatch FX) | 🟢 |
| 12. Монетизация (3 gamepass + 3 devproduct) | 🟢 (id=0) |
| 13. Ore Discovery Index (**54** руды, журнал) | 🟢 |
| 14. Визуальная идентичность (low-poly + lighting) | 🟢 (PNG Creator Hub — вне кода) |
| 16. Взвешенный спавн + квесты + достижения + cursor light | 🟢 (`2d311dd`) |
| 17. UI/UX overhaul (dock, icons, responsive-layout, LayerAmbience, ore shells/pixels) | 🟢 (закоммичено) |
| 18+. Пост-MVP системы **вне исходного scope** (промокоды, соц-награда, egg shop ×6, баффы, мутации, ежедневки, hub-зоны, world-leaderboard, mine-deck collision) | 🟢 в коде (следовало раздать апдейтами после релиза) |
| 15. Soft launch и стабилизация | 🔴 (блокирует id=0 монетизации + непройденный плейтест) |

---

## 🎮 Команды
- `/rarity` — полоски редкости
- `/hpbar` — HP бар при наведении
- `/coins <N>`, `/reset`, `/maxlvl`, `/skiptut`, `/rebirth [N]`, `/daily`, `/setday <N>`, `/resetdaily`, `/boost <min>`, `/leaderboard refresh`, `/egg [N]`, `/hatch`, `/pet <id>`, `/clearpets`, `/grantpass <key>`, `/grantproduct <key> [N]`, `/discover <oreId>`, `/discoverall`, `/resetjournal`, `/resetquests`, `/completequest`, `/devhelp` — только Studio
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
- Ветка: `main` (tracks `origin/main`)
- Предыдущий коммит: `2d311dd` — MVP phase 16 (2026-06). Между ним и текущим накопился **~месяц незакоммиченной работы** (Фаза 17 + все пост-MVP системы) — крупный процессный долг: коммитить нужно мелко и ежедневно.
- Текущий коммит: Фаза 17 (HUD redesign, responsive-layout, UiAssets, LayerProfile/LayerAmbience, OreFX/ShellMeshes, OreIconPixels ×54, PetModelKit/30 pets 3D, `assets/ui/`) + пост-MVP системы (промокоды, соц-награда, egg shop ×6, баффы, мутации, ежедневки, hub-зоны, world-leaderboard, mine-deck collision) + синхронизация доков с реальным состоянием.
- GitHub: `github.com/RAYADANN/deep-digger`
- Объём `src/`: **~35k строк / 230 .lua файлов** (client 109 / shared 96 / server 25; `MiningRenderer` ~1.8k строк — кандидат на split)

## 📊 Чек-лист smoke Фазы 13 (Studio)

- [ ] `DiscoveryManager initialized` в Output при старте сервера
- [ ] Таб 📖 **ЖУРНАЛ** в dock, панель «Открыто X/Y» в модалке.
- [ ] `/discover coal` → **OreDiscoveryFX** «НОВАЯ НАХОДКА» (без дублирующего тоста), слот Coal в журнале
- [ ] Rare+ блоки: shell meshes, proximity glow, particles; low-poly color (не Slate/Foil материалы)
- [ ] Добыть руду в игре (первая находка) → `kind=ore_discovered` + HUD sync
- [ ] `/discoverall` → все слоты открыты; полный слой → milestone (если milestone ещё не был)
- [ ] `/rebirth` → журнал не сброшен
- [ ] `/resetjournal` → журнал пуст, milestone сброшен

## 📊 Чек-лист smoke Фазы 14 (Studio + плейтест)

**Визуал руд (low-poly, актуально):**
- [ ] Play Solo → common руды: цвет + jitter, без material Slate/Foil/Glass.
- [ ] Rare+ с `protrusion="crystal"` — кристаллические накладки / shell meshes.
- [ ] Rare-руда отличается от common по shell/glow/protrusion, не только по rarity-полоске.

**Lighting «спуск вглубь»:**
- [ ] Переход **Dirt → Stone**: Brightness/ClockTime темнеют, Atmosphere сгущается.
- [ ] Спуск глубже: каждый слой темнее; Void почти чёрный.
- [ ] `LayerAmbience`: enter-sound + particles на смене слоя (все 7 слоёв в данных).
- [ ] Респавн → `LayerEnvironment:reset()` возвращает Dirt-профиль.

**Creator Hub (вне Studio):**
- [ ] Финальные PNG в `docs/marketing/assets/`.
- [ ] icon-тест: 5 человек угадывают «копание/шахта».
- [ ] Title/Description + genre tags в Creator Hub.

## 📊 Чек-лист smoke Фазы 16 (Studio)

**Распределение руды:**
- [ ] Копать поверхность Dirt 50+ блоков → подавляющее большинство Dirt, изредка Pebble/Clay/Root/Coal, очень редко Fossil. `test_glow` НЕ появляется (weight=0).
- [ ] `/maxlvl` + докопать до Stone → доминирует Stone, металлы/самоцветы редкие.

**Цели (квесты):**
- [ ] Таб **ЦЕЛИ** в dock (иконка `tab_goals`), активный квест с прогресс-баром в модалке.
- [ ] Копать до выполнения первого квеста → тост «забери награду» (один раз), кнопка [ЗАБРАТЬ] активна.
- [ ] [ЗАБРАТЬ] → монеты начислены, следующий квест стал активным.
- [ ] `/completequest` → активный квест выполнен; `/resetquests` → цепочка сброшена в начало.
- [ ] Пройти все квесты → «✅ Все цели выполнены!».

**Достижения:**
- [ ] В GoalsPanel список достижений, заблокированные с наградой, разблокированные с ✓.
- [ ] Открыть 10 руд (`/discoverall` или копание) → `collector_10` разблокировано + тост.
- [ ] Глубина/комнаты триггерят соответствующие ачивки; `boss_slayer` НЕ виден.
- [ ] Перезаход → забранные квесты и разблокированные достижения на месте (персист), ребёрт их не сбрасывает.

**Освещение шахты (cursor light):**
- [ ] Блок под курсором/тачем подсвечен (`CURSOR_LIGHT` в MiningRenderer).
- [ ] Вдали сохраняется атмосфера тьмы (fog + layer lighting).
- [ ] `Headlamp` не дублирует свет (`HEADLAMP.enabled=false`).

## 📊 Чек-лист smoke Фазы 17 (Studio)

**Новый HUD:**
- [ ] Левый верх: монеты (иконка coin) + depth bar + чипы rebirth/boost/streak при наличии.
- [ ] Правый верх: чип рюкзака (fill-bar меняет цвет при 70%/90%).
- [ ] Низ по центру: dock с 5 иконками + зелёная **ПРОДАТЬ**.
- [ ] Клик nav → модалка 600×450 с цветным header; ✕ / backdrop закрывают.
- [ ] «Ещё» → popup: **pets**, stats, rebirth, leaderboard, shop.
- [ ] **Pets:** dock → Ещё → pets → панель открывается, hatch/equip работает.
- [ ] Home pill → `HomeFX` iris wipe + телепорт.
- [ ] ПРОДАТЬ → монеты, инвентарь пуст, звук sell_success.

**Иконки:**
- [ ] Все dock/upg иконки грузятся — `UiAssets` rbxassetid или `assets/ui` через Rojo.
- [ ] Иконки руд в журнале — pixel/PNG через `OreIcon`.

**Регрессии:**
- [ ] Tutorial `/reset` → стрелки находят `Tab_inventory`, `SellButton`, `UpgRow_pickaxe`.
- [ ] VIP tag на голове + owned badges в магазине.
- [ ] 3D pet followers видны после equip.

**Атмосфера / блоки:**
- [ ] Dirt → Stone: `LayerEnvironment` + `LayerAmbience` (enter-sound, particles).
- [ ] Rare/epic блоки: mesh-shell накладка (`OreShellMeshes`).
- [ ] Crimson/Obsidian/Void: layer-specific block glow (`LayerProfile.BLOCK_GLOW`).

**Perf:**
- [ ] 10+ мин копания, FPS ≥50, `/diagreport` без монотонного роста задач.
