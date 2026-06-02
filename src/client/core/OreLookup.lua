--!strict
-- OreLookup.lua — клиентский O(1) доступ к данным руд.
-- Источник правды — shared/data/OreDatabase. Один раз при загрузке модуля
-- строит плоскую { [oreId] = OreDef } мапу, дальше все геттеры — за O(1).
--
-- Этот модуль — единственный путь к данным руд на клиенте. Никаких
-- хардкод-таблиц цветов/редкостей/иконок в рендере или HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")

local Constants = require(shared.constants)
local OreDatabase = require(shared.data.OreDatabase)
local OreTypes = require(shared.types.OreTypes)

type OreDef = OreTypes.OreDef

local OreLookup = {}

local DEFAULT_COLOR = Color3.fromRGB(140, 140, 150)
local DEFAULT_RARITY = "common"
local DEFAULT_ICON = "?"

local _byId: { [string]: OreDef } = {}

local function buildIndex()
    local db = OreDatabase.new()
    for _, pool in pairs(db:getAll()) do
        for _, ore in ipairs(pool) do
            _byId[ore.id] = ore
        end
    end
end

buildIndex()

function OreLookup.getDef(oreId: string): OreDef?
    return _byId[oreId]
end

function OreLookup.getColor(oreId: string): Color3
    local d = _byId[oreId]
    if d and d.color then
        return d.color
    end
    return DEFAULT_COLOR
end

function OreLookup.getRarity(oreId: string): string
    local d = _byId[oreId]
    if d and d.rarity then
        return d.rarity
    end
    return DEFAULT_RARITY
end

function OreLookup.getIcon(oreId: string): string
    local d = _byId[oreId]
    if d and d.icon and d.icon ~= "" then
        return d.icon
    end
    return DEFAULT_ICON
end

function OreLookup.getName(oreId: string): string
    local d = _byId[oreId]
    if d and d.name then
        return d.name
    end
    return oreId
end

function OreLookup.getRarityColor(oreId: string): Color3
    local rarity = OreLookup.getRarity(oreId)
    return Constants.RARITY_COLORS[rarity] or Constants.RARITY_COLORS.common
end

return OreLookup
