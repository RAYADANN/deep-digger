--!strict
-- DiscoveryLogic.lua — Phase 13 (Ore Discovery Index).
--
-- Единственный источник формул журнала находок (как RebirthLogic / PetLogic /
-- MonetizationLogic). Цель охоты в игре — сама руда: журнал «Открыто N/M»
-- превращает копание в коллекционирование кор-ресурса, не смещая акцент на
-- петов (петы остаются инструментом).
--
-- Каталог руд строится один раз из OreDatabase (shared, реплицируется), так
-- что и сервер (DiscoveryManager), и клиент (JournalPanel) видят один список.
-- Тестовые руды (id содержит "test") исключаются — они не часть коллекции.
--
-- Структуры в playerData (см. OreTypes.PlayerData):
--   discoveredOres        — { [oreId] = true } — какие руды найдены (>=1 раз).
--   discoveredMilestones  — { [layerId] = true } — за какие слои уже выдана
--                           milestone-награда (защита от двойного начисления).
--
-- API:
--   DiscoveryLogic.getLayers()                 -> { { layerId, name, ores={oreId,...} } } (ordered)
--   DiscoveryLogic.allOreIds()                 -> { oreId }
--   DiscoveryLogic.layerOfOre(oreId)           -> layerId?
--   DiscoveryLogic.isDiscoverable(oreId)       -> boolean
--   DiscoveryLogic.isDiscovered(data, oreId)   -> boolean
--   DiscoveryLogic.layerProgress(data, layerId)-> { found, total }
--   DiscoveryLogic.totalProgress(data)         -> { found, total }
--   DiscoveryLogic.isLayerComplete(data, layerId) -> boolean
--   DiscoveryLogic.milestoneReward(layerId)    -> number (coins)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local Constants = require(shared.constants)
local OreDatabase = require(shared.data.OreDatabase)

local DiscoveryLogic = {}

-- Тестовые руды (Фаза 6) не участвуют в коллекции.
local function isTestOre(oreId: string): boolean
    return string.find(oreId, "test", 1, true) ~= nil
end

-- Строим каталог один раз при загрузке модуля. OreDatabase.new() — это просто
-- статичные данные (реплицируются), instance дешёвый.
local _layers: { { layerId: string, name: string, ores: { string } } } = {}
local _layerOfOre: { [string]: string } = {}
local _allOreIds: { string } = {}
local _discoverableSet: { [string]: boolean } = {}

do
    local catalog = OreDatabase.new():getAll()
    -- Порядок слоёв — как в Constants.LAYERS (Dirt → Void).
    for _, layerDef in ipairs(Constants.LAYERS) do
        local pool = catalog[layerDef.id]
        if pool then
            local ores: { string } = {}
            for _, ore in ipairs(pool) do
                if not isTestOre(ore.id) then
                    table.insert(ores, ore.id)
                    _layerOfOre[ore.id] = layerDef.id
                    _discoverableSet[ore.id] = true
                    table.insert(_allOreIds, ore.id)
                end
            end
            if #ores > 0 then
                table.insert(_layers, { layerId = layerDef.id, name = layerDef.name, ores = ores })
            end
        end
    end
end

function DiscoveryLogic.getLayers()
    return _layers
end

function DiscoveryLogic.allOreIds(): { string }
    return _allOreIds
end

function DiscoveryLogic.layerOfOre(oreId: string): string?
    return _layerOfOre[oreId]
end

function DiscoveryLogic.isDiscoverable(oreId: string): boolean
    return _discoverableSet[oreId] == true
end

function DiscoveryLogic.isDiscovered(data: any, oreId: string): boolean
    if not data or typeof(data.discoveredOres) ~= "table" then
        return false
    end
    return data.discoveredOres[oreId] == true
end

function DiscoveryLogic.layerProgress(data: any, layerId: string): { found: number, total: number }
    local found = 0
    local total = 0
    for _, layer in ipairs(_layers) do
        if layer.layerId == layerId then
            for _, oreId in ipairs(layer.ores) do
                total += 1
                if DiscoveryLogic.isDiscovered(data, oreId) then
                    found += 1
                end
            end
            break
        end
    end
    return { found = found, total = total }
end

function DiscoveryLogic.totalProgress(data: any): { found: number, total: number }
    local found = 0
    for _, oreId in ipairs(_allOreIds) do
        if DiscoveryLogic.isDiscovered(data, oreId) then
            found += 1
        end
    end
    return { found = found, total = #_allOreIds }
end

function DiscoveryLogic.isLayerComplete(data: any, layerId: string): boolean
    local p = DiscoveryLogic.layerProgress(data, layerId)
    return p.total > 0 and p.found >= p.total
end

-- Разовая coins-награда за полностью открытый слой.
function DiscoveryLogic.milestoneReward(layerId: string): number
    local map = (Constants.DISCOVERY or {}).layerMilestoneCoins or {}
    return math.max(0, math.floor(map[layerId] or 0))
end

return DiscoveryLogic
