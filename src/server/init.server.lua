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
local AntiCheat = require(script.core.AntiCheat)
local Leaderboard = require(script.core.Leaderboard)

local log = Logger.new("Server:Init")

-- Инициализация модулей
local oreDb = OreDatabase.new()
local profileManager = ProfileManager.new()
local miningEngine = MiningEngine.new(oreDb:getAll())
local economyManager = EconomyManager.new(miningEngine)
local antiCheat = AntiCheat.new()
local leaderboard = Leaderboard.new()

-- RemoteEvents для клиента
local remoteSync = Net:RemoteEvent("SyncBlocks")
local remoteStats = Net:RemoteEvent("PlayerStats")
local remoteInv = Net:RemoteEvent("PlayerInventory")

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

local function syncStats(player: Player)
    local playerData = profileManager:getData(player)
    if not playerData then return end
    remoteStats:FireClient(player, {
        coins = playerData.coins,
        gems = playerData.gems or 0,
        depth = playerData.depth,
        layer = layerName(playerData.layer or "dirt"),
    })
end

local function syncInventory(player: Player)
    local playerData = profileManager:getData(player)
    if not playerData then return end
    -- Преобразуем инвентарь в массив { oreId, count }
    local invList = {}
    for oreId, count in pairs(playerData.inventory or {}) do
        if count > 0 then
            table.insert(invList, { oreId = oreId, count = count })
        end
    end
    remoteInv:FireClient(player, {
        inventory = invList,
        upgrades = playerData,
    })
end

--[[
    Обработчик клика по блоку от клиента.
    Принимает пачку кликов: [ {x, y}, ... ].
]]
Net:Handle("MineBlock", function(player: Player, clicks: { { x: number, z: number, y: number } })
    -- Anti-cheat
    if not antiCheat:checkClick(player) then
        return { { success = false, error = "Too many clicks" } }
    end

    local playerData = profileManager:getData(player)
    if not playerData then return {} end

    local results = {}
    local blocksChanged = false

    for _, click in ipairs(clicks) do
        local result = miningEngine:hitBlock(player, playerData, click.x, click.z, click.y, false)
        table.insert(results, result)
        if result.mined then
            blocksChanged = true
            -- Инвентарь
            if result.oreDef then
                if not playerData.inventory[result.oreDef.id] then
                    playerData.inventory[result.oreDef.id] = 0
                end
                playerData.inventory[result.oreDef.id] += 1
                playerData.totalBlocksMined += 1
            end
        end
    end

    -- Синхронизируем чанки (загрузка/выгрузка) + отправляем клиенту
    if blocksChanged then
        syncVisibleBlocks(player)
        syncStats(player)
        syncInventory(player)
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

    -- 2. Ждём клиент
    task.wait(2)

    -- 3. Загружаем чанки и синхронизируем
    syncVisibleBlocks(player)

    -- 4. Отправляем статы на HUD
    syncStats(player)
    syncInventory(player)

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
