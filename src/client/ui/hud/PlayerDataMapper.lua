--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local UpgradeMeta = require(script.Parent.UpgradeMeta)

export type InventoryEntry = { oreId: string, count: number }

export type UpgradeLevels = { [string]: { level: number } }

-- Phase 10: payload-секции для daily / boosts / leaderboard. Сервер
-- (init.server.lua buildHudPayload) формирует их через DailyLogic /
-- PlayerBoosts.toPayloadList. Клиент сюда складывает as-is, без логики.
export type DailyStatePayload = {
    canClaim: boolean?,
    currentStreak: number?,
    nextDay: number?,
    totalDaysClaimed: number?,
    secondsUntilNextDay: number?,
}

export type ActiveBoostPayload = {
    kind: string?,
    multiplier: number?,
    remaining: number?,
    source: string?,
    expiresAt: number?,
}

export type LeaderboardPlacementPayload = {
    coinsRank: number?,
    depthRank: number?,
    coinsValue: number?,
    depthValue: number?,
}

-- Phase 11: pet payload-секции.
export type PetRecordPayload = {
    uid: string,
    petId: string,
}

export type PetEffectsPayload = {
    damage: number?,
    luck: number?,
    coin: number?,
    multiMine: number?,
    equippedCount: number?,
}

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
    -- Phase 8: 0..3, см. Constants.TUTORIAL_STEPS.
    tutorialStep: number?,
    -- Phase 9: prestige. rebirths — счётчик, rebirthMultiplier —
    -- денормализованный множитель к value руд (1 + rebirths * 0.1).
    rebirths: number?,
    rebirthMultiplier: number?,
    -- Phase 10: retention-state.
    dailyState: DailyStatePayload?,
    activeBoosts: { ActiveBoostPayload }?,
    leaderboardPlacement: LeaderboardPlacementPayload?,
    -- Phase 11: pets.
    pets: { PetRecordPayload }?,
    equippedPet: string?,
    petEffects: PetEffectsPayload?,
    -- Phase 12: монетизация.
    gamepasses: { [string]: boolean }?,
    equippedUids: { string }?,
    petMaxEquipped: number?,
    -- Phase 13: журнал находок.
    discoveredOres: { [string]: boolean }?,
    discoveredMilestones: { [string]: boolean }?,
    discoveryProgress: { found: number?, total: number? }?,
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
    tutorialStep: number,
    rebirths: number,
    rebirthMultiplier: number,
    dailyState: DailyStatePayload,
    activeBoosts: { ActiveBoostPayload },
    leaderboardPlacement: LeaderboardPlacementPayload,
    pets: { PetRecordPayload },
    equippedPet: string?,
    petEffects: PetEffectsPayload,
    gamepasses: { [string]: boolean },
    equippedUids: { string },
    petMaxEquipped: number,
    discoveredOres: { [string]: boolean },
    discoveredMilestones: { [string]: boolean },
    discoveryProgress: { found: number, total: number },
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

local DEFAULT_DAILY_STATE: DailyStatePayload = {
    canClaim = false,
    currentStreak = 0,
    nextDay = 1,
    totalDaysClaimed = 0,
    secondsUntilNextDay = 0,
}

local DEFAULT_LEADERBOARD: LeaderboardPlacementPayload = {
    coinsRank = nil,
    depthRank = nil,
    coinsValue = 0,
    depthValue = 0,
}

local DEFAULT_PET_EFFECTS: PetEffectsPayload = {
    damage = 1,
    luck = 1,
    coin = 0,
    multiMine = 0,
    equippedCount = 0,
}

-- Нормализует список pet-записей. Сервер шлёт { uid, petId } (без def'ов —
-- их PetsPanel резолвит через PetDatabase). Битые записи отбрасываем.
local function normalizePets(pets: any): { PetRecordPayload }
    local result: { PetRecordPayload } = {}
    if typeof(pets) ~= "table" then
        return result
    end
    for _, rec in ipairs(pets) do
        if typeof(rec) == "table" and typeof(rec.uid) == "string" and typeof(rec.petId) == "string" then
            table.insert(result, { uid = rec.uid, petId = rec.petId })
        end
    end
    return result
end

function PlayerDataMapper.fromServer(payload: ServerPlayerPayload): MappedPlayerData
    local rebirths = payload.rebirths or 0
    local daily = payload.dailyState or DEFAULT_DAILY_STATE
    local boosts = payload.activeBoosts or {}
    local placement = payload.leaderboardPlacement or DEFAULT_LEADERBOARD
    return {
        coins = payload.coins or 0,
        gems = 0,
        inventory = PlayerDataMapper.normalizeInventory(payload.inventory),
        upgrades = PlayerDataMapper.mapUpgrades(payload),
        totalBlocksMined = payload.totalBlocksMined or 0,
        totalCoinsEarned = payload.totalCoinsEarned or 0,
        bossesDefeated = payload.bossesDefeated or 0,
        maxDepthReached = payload.maxDepthReached or 0,
        tutorialStep = payload.tutorialStep or 0,
        rebirths = rebirths,
        -- Если сервер не прислал — считаем от rebirths (1 + r*0.1). Это
        -- последний рубеж: предыдущая Phase 8-совместимость + быстрый
        -- фолбэк, если PlayerStats прилетит ДО Phase-9-апа.
        rebirthMultiplier = payload.rebirthMultiplier or (1 + rebirths * 0.1),
        dailyState = {
            canClaim = daily.canClaim or false,
            currentStreak = daily.currentStreak or 0,
            nextDay = daily.nextDay or 1,
            totalDaysClaimed = daily.totalDaysClaimed or 0,
            secondsUntilNextDay = daily.secondsUntilNextDay or 0,
        },
        activeBoosts = boosts,
        leaderboardPlacement = {
            coinsRank = placement.coinsRank,
            depthRank = placement.depthRank,
            coinsValue = placement.coinsValue or 0,
            depthValue = placement.depthValue or 0,
        },
        pets = normalizePets(payload.pets),
        equippedPet = payload.equippedPet,
        petEffects = payload.petEffects or DEFAULT_PET_EFFECTS,
        gamepasses = if typeof(payload.gamepasses) == "table" then payload.gamepasses else {},
        equippedUids = if typeof(payload.equippedUids) == "table" then payload.equippedUids else {},
        petMaxEquipped = payload.petMaxEquipped or 1,
        discoveredOres = if typeof(payload.discoveredOres) == "table" then payload.discoveredOres else {},
        discoveredMilestones = if typeof(payload.discoveredMilestones) == "table" then payload.discoveredMilestones else {},
        discoveryProgress = {
            found = (payload.discoveryProgress and payload.discoveryProgress.found) or 0,
            total = (payload.discoveryProgress and payload.discoveryProgress.total) or 0,
        },
    }
end

return PlayerDataMapper
