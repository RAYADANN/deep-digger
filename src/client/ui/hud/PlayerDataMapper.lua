--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local UpgradeMeta = require(script.Parent.UpgradeMeta)

export type InventoryEntry = { oreId: string, count: number }

export type UpgradeLevels = { [string]: { level: number } }

export type ServerPlayerPayload = {
    coins: number?,
    gems: number?,
    depth: number?,
    layer: string?,
    layerName: string?,
    inventory: { InventoryEntry } | { [string]: number }?,
    pickaxeLevel: number?,
    speedLevel: number?,
    fortuneLevel: number?,
    inventoryLevel: number?,
    critLevel: number?,
    multiSellLevel: number?,
    autoSellUnlocked: boolean?,
    totalBlocksMined: number?,
    totalCoinsEarned: number?,
    bossesDefeated: number?,
    maxDepthReached: number?,
}

export type MappedPlayerData = {
    coins: number,
    gems: number,
    inventory: { InventoryEntry },
    upgrades: UpgradeLevels,
    totalBlocksMined: number,
    totalCoinsEarned: number,
    bossesDefeated: number,
    maxDepthReached: number,
}

local PlayerDataMapper = {}

function PlayerDataMapper.normalizeInventory(inv: any): { InventoryEntry }
    local result: { InventoryEntry } = {}
    if typeof(inv) ~= "table" then
        return result
    end
    local first = inv[1]
    if first and typeof(first) == "table" and first.oreId then
        for _, item in ipairs(inv) do
            if item.oreId and item.count and item.count > 0 then
                table.insert(result, { oreId = item.oreId, count = item.count })
            end
        end
    else
        for oId, c in pairs(inv) do
            if type(c) == "number" and c > 0 then
                table.insert(result, { oreId = oId, count = c })
            end
        end
    end
    return result
end

function PlayerDataMapper.resolveLayerName(layerId: string, layerName: string?): string
    if layerName then
        return layerName
    end
    for _, layer in ipairs(Constants.LAYERS) do
        if layer.id == layerId then
            return layer.name
        end
    end
    return layerId
end

local function upgradeLevel(payload: ServerPlayerPayload, id: string): number
    if id == "pickaxe" then
        return payload.pickaxeLevel or 1
    elseif id == "speed" then
        return payload.speedLevel or 1
    elseif id == "fortune" then
        return payload.fortuneLevel or 1
    elseif id == "inventory" then
        return payload.inventoryLevel or 1
    elseif id == "crit" then
        return payload.critLevel or 1
    elseif id == "multiSell" then
        return payload.multiSellLevel or 1
    end
    return 1
end

function PlayerDataMapper.mapUpgrades(payload: ServerPlayerPayload): UpgradeLevels
    local ups: UpgradeLevels = {}
    for _, id in ipairs(UpgradeMeta.ORDER) do
        if id == "autoSell" then
            ups[id] = { level = if payload.autoSellUnlocked then 1 else 0 }
        else
            ups[id] = { level = upgradeLevel(payload, id) }
        end
    end
    return ups
end

function PlayerDataMapper.fromServer(payload: ServerPlayerPayload): MappedPlayerData
    return {
        coins = payload.coins or 0,
        gems = 0,
        inventory = PlayerDataMapper.normalizeInventory(payload.inventory),
        upgrades = PlayerDataMapper.mapUpgrades(payload),
        totalBlocksMined = payload.totalBlocksMined or 0,
        totalCoinsEarned = payload.totalCoinsEarned or 0,
        bossesDefeated = payload.bossesDefeated or 0,
        maxDepthReached = payload.maxDepthReached or 0,
    }
end

return PlayerDataMapper
