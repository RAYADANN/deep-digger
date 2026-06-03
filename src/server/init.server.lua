--!strict
-- init.server.lua — точка входа сервера.
-- Запускает все core-модули, подключает события игроков.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local LayerUtil = require(shared.util.LayerUtil)
local Net = require(modules.Net)
local OreDatabase = require(shared.data.OreDatabase)
local ProfileManager = require(script.core.ProfileManager)
local MiningEngine = require(script.core.MiningEngine)
local EconomyManager = require(script.core.EconomyManager)
local MiningLoot = require(script.core.MiningLoot)
local AntiCheat = require(script.core.AntiCheat)
local Leaderboard = require(script.core.Leaderboard)
local DevCommands = require(script.core.DevCommands)
local TutorialManager = require(script.core.TutorialManager)
local RebirthManager = require(script.core.RebirthManager)
local DailyReward = require(script.core.DailyReward)
local PlayerBoosts = require(script.core.PlayerBoosts)
local PetManager = require(script.core.PetManager)
local PetLogic = require(shared.util.PetLogic)
local MonetizationManager = require(script.core.MonetizationManager)
local DiscoveryManager = require(script.core.DiscoveryManager)
local DiscoveryLogic = require(shared.util.DiscoveryLogic)

local log = Logger.new("Server:Init")

-- Дефолтный FallenPartsDestroyHeight = -500: персонаж умирает на глубине
-- ~110 м (BLOCK_SIZE_STUDS = 4.5). Шахта у нас бесконечная вниз, поэтому
-- порог опускаем до -50000 студов — это лимит Roblox для этого свойства
-- (single-precision floats теряют точность ниже).
--
-- -50000 / 4.5 ≈ 11 110 блоков глубины — больше чем когда-либо понадобится:
-- void-слой начинается на y=1200, дальше — пост-MVP контент.
--
-- В новой capability-модели Roblox это свойство read-only из server-скрипта
-- (нужен Plugin-capability). Правильное место — Studio Properties панель
-- Workspace.FallenPartsDestroyHeight = -50000 (значение сохранится в .rbxl).
-- Здесь оставлен pcall-фолбэк на случай, если контекст имеет права
-- (Run Mode, плагин-окружение): попытка не критична, ошибки не должны
-- валить сервер.
pcall(function()
    workspace.FallenPartsDestroyHeight = -50000
end)

-- Инициализация модулей
local oreDb = OreDatabase.new()
local profileManager = ProfileManager.new()
local miningEngine = MiningEngine.new(oreDb:getAll())
local antiCheat = AntiCheat.new()

local remoteSync = Net:RemoteEvent("SyncBlocks")
local remoteStats = Net:RemoteEvent("PlayerStats")
local remoteInv = Net:RemoteEvent("PlayerInventory")
-- Лёгкая дельта HUD при копании: только coins/inventory/stats вместо полного
-- payload (~30 Fusion-полей ×2 события). syncPlayerHud остаётся для sell/buy/
-- rebirth/join, где меняются upgrades/pets/discovery.
local remoteHudDelta = Net:RemoteEvent("PlayerHudDelta")
local remoteNotify = Net:RemoteEvent("Notify")

-- Phase 9: payload.kind — опциональный «тип» нотификации. Клиент использует
-- его для запуска специфичных FX (kind="rebirth" → RebirthFX.burst()).
-- Notification.show игнорирует это поле, поэтому обратной совместимости не
-- ломаем.
type NotifyPayload = {
    text: string,
    color: { r: number, g: number, b: number }?,
    icon: string?,
    duration: number?,
    kind: string?,
}
local function notify(player: Player, payload: NotifyPayload)
    remoteNotify:FireClient(player, payload)
end

local NOTIFY_COOLDOWN = 4
local lastNotifyAt: { [string]: number } = {}
local function notifyOnce(player: Player, key: string, payload: NotifyPayload)
    local id = key .. "_" .. player.UserId
    local now = os.clock()
    if lastNotifyAt[id] and now - lastNotifyAt[id] < NOTIFY_COOLDOWN then
        return
    end
    lastNotifyAt[id] = now
    notify(player, payload)
end

--[[
    Полный snapshot блоков (только при первом заходе / resetPlayer).
    На лету используется delta — см. MineBlock-хендлер.
]]
local function sendBlocksSnapshot(player: Player)
    local playerData = profileManager:getData(player)
    if not playerData then return end

    local blocks = miningEngine:getVisibleBlocks(player, playerData)
    remoteSync:FireClient(player, { kind = "snapshot", payload = blocks })
end

type BlockDeltaAgg = {
    created: { [string]: { key: string, oreId: string, hp: number, maxHp: number } },
    updated: { [string]: number },
    removed: { [string]: boolean },
}

local function newDeltaAgg(): BlockDeltaAgg
    return { created = {}, updated = {}, removed = {} }
end

--[[
    Влить дельту одного удара в аккумулятор. Конфликты:
      - created→removed:  отмена создания, removed не пишем (нечего удалять у клиента).
      - removed→created:  заменяем — у клиента блок исчезнет и появится заново.
      - created→updated:  правим hp у уже созданного блока, отдельный updated не нужен.
]]
local function mergeDelta(agg: BlockDeltaAgg, hitDelta)
    if not hitDelta then return end
    for _, k in ipairs(hitDelta.removed or {}) do
        if agg.created[k] then
            agg.created[k] = nil
        else
            agg.removed[k] = true
        end
        agg.updated[k] = nil
    end
    for _, b in ipairs(hitDelta.created or {}) do
        agg.created[b.key] = b
        agg.removed[b.key] = nil
        agg.updated[b.key] = nil
    end
    for _, u in ipairs(hitDelta.updated or {}) do
        if agg.created[u.key] then
            agg.created[u.key].hp = u.hp
        else
            agg.updated[u.key] = u.hp
        end
    end
end

local function flushDelta(player: Player, agg: BlockDeltaAgg)
    local createdList = {}
    local updatedList = {}
    local removedList = {}
    for _, b in pairs(agg.created) do table.insert(createdList, b) end
    for k, hp in pairs(agg.updated) do table.insert(updatedList, { key = k, hp = hp }) end
    for k, _ in pairs(agg.removed) do table.insert(removedList, k) end

    if #createdList == 0 and #updatedList == 0 and #removedList == 0 then
        return
    end

    remoteSync:FireClient(player, {
        kind = "delta",
        payload = { created = createdList, updated = updatedList, removed = removedList },
    })
end

-- Phase 10: shared/util модули — формулы для daily-стейта в payload'е.
local DailyLogic = require(shared.util.DailyLogic)

local function buildHudPayload(playerData)
    local invList = {}
    for oreId, count in pairs(playerData.inventory or {}) do
        if count > 0 then
            table.insert(invList, { oreId = oreId, count = count })
        end
    end
    -- Phase 10: формируем dailyState для клиента.
    --   * canClaim — true если игрок может забрать сегодня.
    --   * currentStreak — текущий стрик (для отображения «🔥 N» в StreakChip).
    --   * nextDay — какой день будет при следующем claim'е (DailyRewardModal
    --     подсветит эту карточку).
    --   * secondsUntilNextDay — для countdown'a «Следующая через 23ч 14м».
    local dailyStateRaw = playerData.dailyState or {}
    local canClaim = DailyLogic.canClaim(dailyStateRaw)
    local nextStreak = DailyLogic.nextStreak(dailyStateRaw)
    local nextDay = DailyLogic.streakToCycleDay(nextStreak)
    local until_ = DailyLogic.timeUntilNextDay()
    local dailyStatePayload = {
        canClaim = canClaim,
        currentStreak = dailyStateRaw.currentStreak or 0,
        nextDay = nextDay,
        totalDaysClaimed = dailyStateRaw.totalDaysClaimed or 0,
        secondsUntilNextDay = until_.total,
    }
    -- Phase 10: serialize active boosts для BoostChip. remaining (в сек) —
    -- единственная вещь, по которой клиент тикает локально (server os.time
    -- не nudge'ит каждую секунду).
    local activeBoostsPayload = PlayerBoosts.toPayloadList(playerData.activeBoosts)
    return {
        coins = playerData.coins or 0,
        gems = 0,
        inventory = invList,
        pickaxeLevel = playerData.pickaxeLevel or 1,
        speedLevel = playerData.speedLevel or 1,
        fortuneLevel = playerData.fortuneLevel or 1,
        inventoryLevel = playerData.inventoryLevel or 1,
        critLevel = playerData.critLevel or 1,
        multiSellLevel = playerData.multiSellLevel or 1,
        autoSellUnlocked = playerData.autoSellUnlocked or false,
        totalBlocksMined = playerData.totalBlocksMined or 0,
        totalCoinsEarned = playerData.totalCoinsEarned or 0,
        bossesDefeated = playerData.bossesDefeated or 0,
        maxDepthReached = playerData.maxDepthReached or 0,
        -- Phase 8: текущий шаг туториала. Клиент по нему решает «показывать
        -- ли подсказки». firstSession не отдаётся клиенту — это
        -- внутренний серверный флаг.
        tutorialStep = playerData.tutorialStep or 0,
        -- Phase 9: prestige. rebirths используется RebirthPanel /
        -- StatsPanel / TopBar-chip; rebirthMultiplier — справочно для
        -- описания «теперь x1.X», основные расчёты идут на сервере в
        -- SellInventory.
        rebirths = playerData.rebirths or 0,
        rebirthMultiplier = playerData.rebirthMultiplier
            or (1 + (playerData.rebirths or 0) * 0.1),
        -- Phase 10: retention-state.
        dailyState = dailyStatePayload,
        activeBoosts = activeBoostsPayload,
        leaderboardPlacement = playerData.leaderboardPlacement or {
            coinsRank = nil, depthRank = nil,
            coinsValue = 0, depthValue = 0,
        },
        -- Phase 11: pets. pets — список { uid, petId } (PetsPanel резолвит
        -- def через PetDatabase на клиенте); equippedPet — uid; petEffects —
        -- сводка бустов (PetLogic.summary) для индикатора в панели и
        -- мгновенного отображения без пересчёта на клиенте.
        pets = playerData.pets or {},
        equippedPet = playerData.equippedPet,
        petEffects = PetLogic.summary(playerData),
        -- Phase 12: монетизация. gamepasses — кэш владения по key (ShopPanel,
        -- TopBar VIP-chip, SellInventory VIP-boost через MonetizationLogic).
        -- equippedUids — нормализованный список uid'ов (multi-slot после
        -- gamepass «+2 pet slots»); PetsPanel использует для equip-check.
        gamepasses = playerData.gamepasses or {},
        equippedUids = PetLogic.getEquippedUids(playerData),
        petMaxEquipped = PetLogic.maxEquipped(playerData),
        -- Phase 13: журнал находок (кор-механика retention). Клиент резолвит
        -- имена/иконки через OreLookup + DiscoveryLogic.getLayers().
        discoveredOres = playerData.discoveredOres or {},
        discoveredMilestones = playerData.discoveredMilestones or {},
        discoveryProgress = DiscoveryLogic.totalProgress(playerData),
    }
end

local function syncPlayerHud(player: Player)
    local playerData = profileManager:getData(player)
    if not playerData then
        return
    end
    local payload = buildHudPayload(playerData)
    remoteStats:FireClient(player, payload)
    remoteInv:FireClient(player, payload)
end

--[[
    Горячая дельта HUD после копания. Меняются только coins, inventory и
    счётчики stats — всё остальное (pets, gamepasses, discovery, daily…)
    не трогаем. Клиент обновляет 4 Fusion Value вместо ~30 ×2.
]]
local function buildInventoryList(playerData): { { oreId: string, count: number } }
    local invList = {}
    for oreId, count in pairs(playerData.inventory or {}) do
        if count > 0 then
            table.insert(invList, { oreId = oreId, count = count })
        end
    end
    return invList
end

local function syncMiningHud(player: Player)
    local playerData = profileManager:getData(player)
    if not playerData then return end
    remoteHudDelta:FireClient(player, {
        coins = playerData.coins or 0,
        inventory = buildInventoryList(playerData),
        totalBlocksMined = playerData.totalBlocksMined or 0,
        totalCoinsEarned = playerData.totalCoinsEarned or 0,
    })
end

local function processDepthUpdate(player: Player, depth: number)
    local playerData = profileManager:getData(player)
    if not playerData then
        return
    end

    depth = math.max(0, math.floor(depth))
    local prevDepth = playerData.depth or 0
    local newLayer = LayerUtil.layerFromDepth(depth)
    local stoneLayer = LayerUtil.getLayer("stone")

    playerData.depth = depth
    playerData.layer = newLayer.id

    if stoneLayer and prevDepth < stoneLayer.depthStart and depth >= stoneLayer.depthStart and not playerData._stoneLayerNotified then
        playerData._stoneLayerNotified = true
        notify(player, {
            text = "Вы вошли в " .. stoneLayer.name .. "!",
            icon = "🪨",
            color = LayerUtil.colorToPayload(stoneLayer.bgColor),
            duration = 3.5,
        })
    end

    local record = playerData.maxDepthReached or 0
    if depth > record then
        playerData.maxDepthReached = depth
        syncPlayerHud(player)
    end
end

Net:Handle("UpdateDepth", function(player: Player, depth: number)
    if typeof(depth) ~= "number" then
        return
    end
    processDepthUpdate(player, depth)
end)

-- Phase 10: Leaderboard поднимаем РАНЬШЕ EconomyManager, чтобы передать
-- его write-хук в onEconomyChanged. После каждой продажи / ребёрта
-- writeIfChanged через MemoryStoreSortedMap апдейтит глобальный топ.
local leaderboard = Leaderboard.new({
    profileManager = profileManager,
    onProfileChanged = syncPlayerHud,
})

-- Phase 10: combined hook — syncPlayerHud + leaderboard:writeIfChanged.
-- Обёртку держим тут (а не в EconomyManager), чтобы EconomyManager не
-- знал про лидерборд (изоляция Phase 3).
local function onEconomyChanged(player: Player)
    syncPlayerHud(player)
    leaderboard:writeIfChanged(player)
end

local economyManager = EconomyManager.new({
    profileManager = profileManager,
    oreDatabase = oreDb,
    onEconomyChanged = onEconomyChanged,
})

local tutorialManager = TutorialManager.new({
    profileManager = profileManager,
    onProfileChanged = syncPlayerHud,
    notify = notify,
})

-- Phase 9: prestige-петля. onResetBlocks ресетит визуальный slice шахты,
-- чтобы после ребёрта игрок видел свежий ландшафт (а не уже разрушенные
-- блоки). MiningEngine:resetPlayer стирает данные, sendBlocksSnapshot
-- доставляет новый snapshot клиенту. onProfileChanged тут включает
-- leaderboard:writeIfChanged — после ребёрта totalCoinsEarned остаётся,
-- но depth обнуляется; писать в лидерборд не критично, но полезно для
-- depth-доски.
local rebirthManager = RebirthManager.new({
    profileManager = profileManager,
    onProfileChanged = onEconomyChanged,
    notify = notify,
    onResetBlocks = function(player: Player)
        miningEngine:resetPlayer(player)
        sendBlocksSnapshot(player)
    end,
})

-- Phase 10: daily reward retention-петля. Использует тот же syncPlayerHud,
-- что и остальные модули; leaderboard не пишется при daily (totalCoinsEarned
-- растёт от claim'а монет, и следующая продажа всё равно дёрнет write).
local dailyReward = DailyReward.new({
    profileManager = profileManager,
    onProfileChanged = syncPlayerHud,
    notify = notify,
})

-- Phase 11: pet-система. onProfileChanged = onEconomyChanged, потому что
-- hatch списывает монеты (нужен HUD-sync + потенциально leaderboard write).
local petManager = PetManager.new({
    profileManager = profileManager,
    onProfileChanged = onEconomyChanged,
    notify = notify,
})

-- Phase 12: монетизация. PetManager нужен для девпродукта «Egg 10x».
local monetizationManager = MonetizationManager.new({
    profileManager = profileManager,
    onProfileChanged = onEconomyChanged,
    notify = notify,
    petManager = petManager,
})

-- Phase 13: журнал находок. onProfileChanged = onEconomyChanged — milestone
-- за полный слой начисляет монеты.
local discoveryManager = DiscoveryManager.new({
    profileManager = profileManager,
    onProfileChanged = onEconomyChanged,
    notify = notify,
})

DevCommands.new({
    profileManager = profileManager,
    onEconomyChanged = syncPlayerHud,
    notify = notify,
    tutorialManager = tutorialManager,
    rebirthManager = rebirthManager,
    dailyReward = dailyReward,
    leaderboard = leaderboard,
    petManager = petManager,
    monetizationManager = monetizationManager,
    discoveryManager = discoveryManager,
})

--[[
    Обработчик клика по блоку от клиента.
    Принимает пачку кликов: [ {x, y}, ... ].
]]
Net:Handle("MineBlock", function(player: Player, clicks: { { x: number, z: number, y: number } })
    local playerData = profileManager:getData(player)
    if not playerData then
        return {}
    end

    if not antiCheat:validateSwing(player, playerData) then
        return { { success = false, error = "Too fast" } }
    end

    if not antiCheat:validateMineBatch(player, #clicks) then
        return { { success = false, error = "Too many clicks" } }
    end

    local results = {}
    local blocksChanged = false
    local discoveryChanged = false
    local deltaAgg = newDeltaAgg()

    for _, click in ipairs(clicks) do
        local result = miningEngine:hitBlock(player, playerData, click.x, click.z, click.y, nil)
        if result.blockDelta then
            mergeDelta(deltaAgg, result.blockDelta)
            result.blockDelta = nil
        end
        if result.mined and result.oreDef then
            blocksChanged = true
            local fortuneBonus = MiningLoot.rollFortuneBonus(playerData.fortuneLevel or 1)
            local loot = MiningLoot.tryAddOre(oreDb, playerData, result.oreDef.id, 1, fortuneBonus)
            result.fortuneBonus = fortuneBonus
            result.autoSold = loot.autoSold
            result.inventoryFull = loot.rejected > 0
            if loot.added > 0 then
                playerData.totalBlocksMined += 1
                -- Phase 13: первая добыча руды → журнал находок.
                if discoveryManager:recordDiscovery(player, result.oreDef.id) then
                    discoveryChanged = true
                end
            end
            -- Phase 11 (multiMine): дополнительные блоки, сломанные петом.
            -- Каждый кладём в инвентарь тем же путём (capacity + autoSell).
            if result.bonusOreDefs then
                for _, bonusDef in ipairs(result.bonusOreDefs) do
                    local bonusLoot = MiningLoot.tryAddOre(oreDb, playerData, bonusDef.id, 1, false)
                    if bonusLoot.added > 0 then
                        playerData.totalBlocksMined += 1
                        if discoveryManager:recordDiscovery(player, bonusDef.id) then
                            discoveryChanged = true
                        end
                    end
                    if bonusLoot.autoSold then
                        result.autoSold = true
                    end
                end
            end
            if loot.autoSold then
                notifyOnce(player, "auto_sell", {
                    text = "Авто-продажа сработала",
                    icon = "💰",
                    color = { r = 255, g = 210, b = 50 },
                })
            elseif loot.rejected > 0 then
                notifyOnce(player, "inventory_full", {
                    text = "Инвентарь полон!",
                    icon = "⚠",
                    color = { r = 255, g = 90, b = 60 },
                })
            end
            if result.roomGenerated then
                local roomText
                local roomColor
                if result.roomRarity then
                    local rarityLabel = Constants.RARITY_LABELS[result.roomRarity] or result.roomRarity
                    roomColor = Constants.RARITY_COLORS[result.roomRarity] or Constants.RARITY_COLORS.common
                    roomText = "Вам повезло! Скрытая комната — внутри " .. rarityLabel .. " руда!"
                else
                    roomColor = Constants.RARITY_COLORS.uncommon
                    roomText = "Вам повезло! Найдена скрытая комната!"
                end
                notify(player, {
                    text = roomText,
                    icon = "✨",
                    color = LayerUtil.colorToPayload(roomColor),
                    duration = 4.5,
                })
            end
        elseif result.success then
            blocksChanged = true
        end
        if result.weakPickaxe then
            notifyOnce(player, "weak_pickaxe", {
                text = "Кирка слишком слабая для Stone! Прокачайте её (ур. " .. Constants.STONE_PICKAXE_MIN_LEVEL .. "+)",
                icon = "⛏",
                color = { r = 255, g = 140, b = 60 },
                duration = 3.5,
            })
        end
        table.insert(results, result)
    end

    flushDelta(player, deltaAgg)
    if discoveryChanged then
        -- Редкое событие (новая руда) — нужны discovery-поля, шлём полный HUD.
        syncPlayerHud(player)
    elseif blocksChanged then
        syncMiningHud(player)
    end

    return results
end)

--[[
    Инициализация при заходе игрока.
]]
local function onPlayerAdded(player: Player)
    log:info("Player joined:", player.UserId, player.Name)

    -- 1. Загружаем профиль
    local profile = profileManager:loadProfile(player)
    if not profile then return end
    local playerData = profile.Data

    -- Глубина — текущая позиция, не сохраняется между сессиями
    playerData.depth = 0
    playerData.layer = "dirt"
    playerData._stoneLayerNotified = false

    -- 2. Ждём клиент
    task.wait(2)

    -- 3a. Phase 9: пересчитать rebirthMultiplier из rebirths. Идемпотентно;
    --   делается раньше Tutorial-хука, чтобы первый HUD-пейлоад содержал
    --   уже актуальный множитель (RebirthPanel читает его при первом рендере).
    rebirthManager:onProfileLoaded(player)

    -- 3b. Phase 10: чистим истёкшие boost'ы. Если игрок зашёл через сутки
    --   после daily-claim Day 7, его x2 boost уже истёк — UI не должен
    --   показать «⚡ x2 · -200с».
    if playerData.activeBoosts then
        PlayerBoosts.cleanup(playerData.activeBoosts)
    end

    -- 3c. Phase 8: миграция опытных + первый бонус. ВАЖНО делать ДО snapshot/HUD,
    --   чтобы стартовые монеты уже были в первом PlayerStats-пейлоаде.
    --   notify() ниже всё равно успеет — Net:RemoteEvent буферизуется до того
    --   как клиент сделает Net:Connect (PlayerScripts стартует раньше).
    tutorialManager:onProfileLoaded(player)

    -- 3d. Phase 10: daily-availability notify. Тост шлётся ТОЛЬКО если
    --   игрок может claim'нуть сегодня (новый день / никогда не забирал).
    --   Сам модал откроется клиентом по dailyState.canClaim в первом
    --   PlayerStats-пейлоаде или по kind="daily_available" в Notify.
    dailyReward:onProfileLoaded(player)

    -- 3e. Phase 11: гарантируем поля петов и чиним «висячий» equippedPet
    --   (uid удалённого пета). Идемпотентно.
    petManager:onProfileLoaded(player)

    -- 3f. Phase 12: синк gamepasses из MarketplaceService (source of truth) +
    --   применение эффектов (autoSell, VIP-тег). Yield'ит в task.spawn —
    --   не блокирует snapshot/HUD; _sync придёт когда проверка завершится.
    monetizationManager:onProfileLoaded(player)

    -- 3g. Phase 13: ensure журнал находок + бэкфилл из инвентаря (миграция).
    discoveryManager:onProfileLoaded(player)

    -- 4. Полный snapshot блоков для начального состояния клиента
    sendBlocksSnapshot(player)

    -- 4b. Респавн: клиентские скрипты перезагружаются (PlayerGui reset),
    -- новый renderer пустой и ждёт snapshot. Начальный snapshot уже отправлен
    -- выше; CharacterAdded НЕ стреляет для уже существующего персонажа при
    -- Connect — только на респавны, поэтому firstCharacter-флаг не нужен.
    player.CharacterAdded:Connect(function()
        task.wait(0.5) -- дать клиенту перезагрузить скрипты и вызвать start()
        if player.Parent then
            sendBlocksSnapshot(player)
        end
    end)

    -- 5. Отправляем данные на HUD
    syncPlayerHud(player)

    -- 6. Phase 10: первая запись в глобальный лидерборд. Если игрок —
    --   опытный (totalCoinsEarned > 0), он сразу появится в топе.
    leaderboard:writeIfChanged(player)

    -- 7. Автосохранение
    task.spawn(function()
        while player.Parent do
            task.wait(Constants.AUTOSAVE_INTERVAL)
            profileManager:saveProfile(player)
        end
    end)

    log:info("Player initialized:", player.UserId)
end

local function onPlayerRemoving(player: Player)
    log:info("Player left:", player.UserId)
    local data = profileManager:getData(player)
    if data then
        -- Глубина не сохраняется
        data.depth = 0
        data.layer = "dirt"
    end
    -- Phase 10: финальная запись в лидерборд + cleanup throttle-state.
    leaderboard:onPlayerLeaving(player)
    profileManager:saveProfile(player)
    antiCheat:reset(player)
    miningEngine:resetPlayer(player)
end

local PlayersService = game:GetService("Players")
PlayersService.PlayerAdded:Connect(onPlayerAdded)
PlayersService.PlayerRemoving:Connect(onPlayerRemoving)

game:BindToClose(function()
    log:info("Shutting down, saving all...")
    profileManager:saveAll()
end)

log:info("Server initialized")
