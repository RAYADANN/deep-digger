--!strict
-- DiscoveryManager.lua — Phase 13 (Ore Discovery Index).
--
-- Серверная часть журнала находок. Структура совпадает с MonetizationManager /
-- DailyReward: DI через Deps, onProfileLoaded идемпотентен.
--
-- Отвечает за:
--   1) recordDiscovery(player, oreId) — пометить руду как найденную при
--      успешной добыче (loot.added > 0 в MineBlock-лупе). Первая находка →
--      notify kind="ore_discovered". Полный слой → milestone coins + notify
--      kind="layer_milestone".
--   2) onProfileLoaded — ensure-поля + бэкфилл discoveredOres из инвентаря
--      (миграция опытных профилей без отдельной миграции).
--   3) DevHooks — discover / discoverAll / resetJournal.
--
-- Формулы и каталог — shared/util/DiscoveryLogic.lua. RebirthManager поле
-- discoveredOres НЕ сбрасывает (коллекция переживает prestige).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")

local Logger = require(shared.util.Logger)
local DiscoveryLogic = require(shared.util.DiscoveryLogic)
local OreDatabase = require(shared.data.OreDatabase)

export type Deps = {
    profileManager: any,
    onProfileChanged: ((player: Player) -> ())?,
    notify: ((player: Player, payload: any) -> ())?,
}

local DiscoveryManager = {}
DiscoveryManager.__index = DiscoveryManager

local GOLD = { r = 255, g = 210, b = 50 }

local function rarityColor(rarity: string): { r: number, g: number, b: number }
    local map = require(shared.constants).RARITY_COLORS or {}
    local c = map[rarity] or Color3.fromRGB(200, 200, 200)
    return { r = math.floor(c.R * 255), g = math.floor(c.G * 255), b = math.floor(c.B * 255) }
end

function DiscoveryManager.new(deps: Deps)
    local self = setmetatable({}, DiscoveryManager)
    self._log = Logger.new("DiscoveryManager")
    self._profileManager = deps.profileManager
    self._onProfileChanged = deps.onProfileChanged
    self._notify = deps.notify
    self._log:info("DiscoveryManager initialized")
    return self
end

function DiscoveryManager:_data(player: Player)
    return self._profileManager:getData(player)
end

function DiscoveryManager:_sync(player: Player)
    if self._onProfileChanged then
        self._onProfileChanged(player)
    end
end

local function ensureFields(data: any)
    if typeof(data.discoveredOres) ~= "table" then
        data.discoveredOres = {}
    end
    if typeof(data.discoveredMilestones) ~= "table" then
        data.discoveredMilestones = {}
    end
end

--[[
    Пометить руду как открытую. Возвращает:
      * newlyDiscovered — true если это ПЕРВАЯ находка этой руды.
      * layerCompleted — layerId если слой стал полным СЕЙЧАС (и milestone
        ещё не был выдан).
]]
function DiscoveryManager:recordDiscovery(player: Player, oreId: string): (boolean, string?)
    if not DiscoveryLogic.isDiscoverable(oreId) then
        return false, nil
    end
    local data = self:_data(player)
    if not data then
        return false, nil
    end
    ensureFields(data)

    if DiscoveryLogic.isDiscovered(data, oreId) then
        return false, nil
    end

    data.discoveredOres[oreId] = true

    local layerId = DiscoveryLogic.layerOfOre(oreId)
    local layerCompleted: string? = nil
    if layerId and DiscoveryLogic.isLayerComplete(data, layerId) then
        if not data.discoveredMilestones[layerId] then
            layerCompleted = layerId
        end
    end

    if layerCompleted then
        self:_grantLayerMilestone(player, data, layerCompleted)
    end

    self:_notifyOreDiscovered(player, oreId)

    self._log:info("Ore discovered:", player.UserId, oreId, layerCompleted and ("layer:" .. layerCompleted) or "")
    return true, layerCompleted
end

function DiscoveryManager:_notifyOreDiscovered(player: Player, oreId: string)
    if not self._notify then
        return
    end
    local def = OreDatabase.new():getOre(oreId)
    if not def then
        return
    end
    self._notify(player, {
        text = ("Новая руда: %s!"):format(def.name or oreId),
        icon = "icon_sparkle",
        color = rarityColor(def.rarity or "common"),
        duration = 3.5,
        kind = "ore_discovered",
        oreId = oreId,
        oreName = def.name,
        rarity = def.rarity,
    })
end

function DiscoveryManager:_grantLayerMilestone(player: Player, data: any, layerId: string)
    local reward = DiscoveryLogic.milestoneReward(layerId)
    data.discoveredMilestones[layerId] = true

    if reward > 0 then
        data.coins = (data.coins or 0) + reward
        data.totalCoinsEarned = (data.totalCoinsEarned or 0) + reward
    end

    if self._notify then
        local layerName = layerId
        for _, layer in ipairs(DiscoveryLogic.getLayers()) do
            if layer.layerId == layerId then
                layerName = layer.name
                break
            end
        end
        self._notify(player, {
            text = if reward > 0
                then ("Слой «%s» полностью открыт! +%d монет"):format(layerName, reward)
                else ("Слой «%s» полностью открыт!"):format(layerName),
            icon = "tab_journal",
            color = GOLD,
            duration = 5,
            kind = "layer_milestone",
            layerId = layerId,
            coinsAwarded = reward,
        })
    end

    self._log:info("Layer milestone:", player.UserId, layerId, "coins:", reward)
end

--[[
    onProfileLoaded: ensure-поля + бэкфилл. Если у опытного игрока в инвентаре
    уже есть руды, но discoveredOres пуст — помечаем их найденными (без тостов
    и без milestone — только тихая миграция). Milestone за уже полные слои
    НЕ выдаём ретроактивно (иначе раздача миллионов монет при первом заходе
    после апдейта).
]]
function DiscoveryManager:onProfileLoaded(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    ensureFields(data)

    local migrated = false
    for oreId, count in pairs(data.inventory or {}) do
        if type(count) == "number" and count > 0 and DiscoveryLogic.isDiscoverable(oreId) then
            if not DiscoveryLogic.isDiscovered(data, oreId) then
                data.discoveredOres[oreId] = true
                migrated = true
            end
        end
    end

    if migrated then
        self:_sync(player)
        self._log:info("Discovery backfill from inventory for", player.UserId)
    end
end

----------------------------------------------------------------------
-- DevHooks (DevCommands, только Studio)
----------------------------------------------------------------------

function DiscoveryManager:devDiscover(player: Player, oreId: string): boolean
    local data = self:_data(player)
    if not data or not DiscoveryLogic.isDiscoverable(oreId) then
        return false
    end
    ensureFields(data)
    local wasNew = not DiscoveryLogic.isDiscovered(data, oreId)
    data.discoveredOres[oreId] = true
    if wasNew then
        local layerId = DiscoveryLogic.layerOfOre(oreId)
        if layerId and DiscoveryLogic.isLayerComplete(data, layerId) and not data.discoveredMilestones[layerId] then
            self:_grantLayerMilestone(player, data, layerId)
        end
        self:_notifyOreDiscovered(player, oreId)
    end
    self:_sync(player)
    return true
end

function DiscoveryManager:devDiscoverAll(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    ensureFields(data)
    for _, oreId in ipairs(DiscoveryLogic.allOreIds()) do
        data.discoveredOres[oreId] = true
    end
    self:_sync(player)
end

function DiscoveryManager:devResetJournal(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    data.discoveredOres = {}
    data.discoveredMilestones = {}
    self:_sync(player)
end

return DiscoveryManager
