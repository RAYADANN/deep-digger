--!strict
-- init.server.lua — точка входа сервера.
-- Запускает все core-модули, подключает события игроков.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
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
    Отправить клиенту все блоки из загруженных чанков.
]]
local function syncVisibleBlocks(player: Player)
    local playerData = profileManager:getData(player)
    if not playerData then return end

    local blocks = miningEngine:getVisibleBlocks(player, playerData)
    remoteSync:FireClient(player, blocks)
end

local function layerName(layerId: string): string
    for _, l in ipairs(Constants.LAYERS) do
        if l.id == layerId then return l.name end
    end
    return layerId
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
    }
end

local _ = layerName -- зарезервировано для будущей логики (Фаза 4)

local function syncPlayerHud(player: Player)
    local playerData = profileManager:getData(player)
    if not playerData then
        return
    end
    local payload = buildHudPayload(playerData)
    remoteStats:FireClient(player, payload)
    remoteInv:FireClient(player, payload)
end

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

    for _, click in ipairs(clicks) do
        local result = miningEngine:hitBlock(player, playerData, click.x, click.z, click.y, nil)
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
        elseif result.success then
            blocksChanged = true
        end
        table.insert(results, result)
    end

    if blocksChanged then
        syncVisibleBlocks(player)
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

    -- 2. Ждём клиент
    task.wait(2)

    -- 3. Загружаем чанки и синхронизируем
    syncVisibleBlocks(player)

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
