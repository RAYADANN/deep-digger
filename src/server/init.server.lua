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
local OreDatabase = require(script.core.OreDatabase)
local ProfileManager = require(script.core.ProfileManager)
local MiningEngine = require(script.core.MiningEngine)
local EconomyManager = require(script.core.EconomyManager)
local MiningLoot = require(script.core.MiningLoot)
local AntiCheat = require(script.core.AntiCheat)
local Leaderboard = require(script.core.Leaderboard)
local DevCommands = require(script.core.DevCommands)

local log = Logger.new("Server:Init")

-- Дефолтный FallenPartsDestroyHeight = -500: персонаж умирает на глубине
-- ~110 м (BLOCK_SIZE_STUDS = 4.5). Шахта у нас бесконечная вниз,
-- поэтому опускаем порог практически в минус бесконечность.
workspace.FallenPartsDestroyHeight = -1e6

-- Инициализация модулей
local oreDb = OreDatabase.new()
local profileManager = ProfileManager.new()
local miningEngine = MiningEngine.new(oreDb:getAll())
local antiCheat = AntiCheat.new()
local leaderboard = Leaderboard.new()

local remoteSync = Net:RemoteEvent("SyncBlocks")
local remoteStats = Net:RemoteEvent("PlayerStats")
local remoteInv = Net:RemoteEvent("PlayerInventory")
local remoteNotify = Net:RemoteEvent("Notify")

local function notify(player: Player, payload: { text: string, color: { r: number, g: number, b: number }?, icon: string?, duration: number? })
    remoteNotify:FireClient(player, payload)
end

local NOTIFY_COOLDOWN = 4
local lastNotifyAt: { [string]: number } = {}
local function notifyOnce(player: Player, key: string, payload: { text: string, color: { r: number, g: number, b: number }?, icon: string?, duration: number? })
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

local function buildHudPayload(playerData)
    local invList = {}
    for oreId, count in pairs(playerData.inventory or {}) do
        if count > 0 then
            table.insert(invList, { oreId = oreId, count = count })
        end
    end
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

local economyManager = EconomyManager.new({
    profileManager = profileManager,
    oreDatabase = oreDb,
    onEconomyChanged = syncPlayerHud,
})

DevCommands.new({
    profileManager = profileManager,
    onEconomyChanged = syncPlayerHud,
    notify = notify,
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
    if blocksChanged then
        syncPlayerHud(player)
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

    -- 3. Полный snapshot блоков для начального состояния клиента
    sendBlocksSnapshot(player)

    -- 4. Отправляем данные на HUD
    syncPlayerHud(player)

    -- 5. Автосохранение
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
