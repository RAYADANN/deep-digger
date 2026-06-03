--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local peek = Fusion.peek

local ScopeFactory = require(script.Parent.ScopeFactory)
local PlayerDataMapper = require(script.Parent.PlayerDataMapper)
-- script.Parent.Parent.Parent = client (StarterGui.client → PlayerScripts.client)
local OreLookup = require(script.Parent.Parent.Parent.core.OreLookup)
local theme = require(script.Parent.theme)
local AnimatedNumber = require(script.Parent.components.AnimatedNumber)

-- Phase 8: счётчики, которые `tween` в HUD ровно так, как ожидает игрок —
-- coin pop из блока подразумевает, что итог плавно дотикает до новой суммы.
-- Уровни / глубина / счётчики статов остаются дискретными.
local COIN_TWEEN_SECONDS = 0.4

export type HudState = {
    scope: ScopeFactory.HudScope,
    -- `coins` — авторитативное (integer), обновляется мгновенно.
    -- Используется логикой апгрейдов (canAfford / canAffordNow).
    coins: any,
    -- `coinsDisplay` — плавно «тикающее» значение для TopBar. НЕ используется
    -- в проверках «хватит ли монет»: иначе во время count-up игрок не сможет
    -- купить апгрейд сразу после продажи, хотя по факту монет хватает.
    coinsDisplay: any,
    gems: any,
    depth: any,
    layerId: any,
    layerName: any,
    inventory: any,
    upgrades: any,
    panelOpen: any,
    activeTab: any,
    statBlocksMined: any,
    statTotalCoins: any,
    -- statTotalCoinsDisplay — тот же приём для Stats-таба.
    statTotalCoinsDisplay: any,
    statBossesDefeated: any,
    statMaxDepth: any,
    tutorialStep: any,
    -- Phase 9: prestige-стейт. `rebirths` — счётчик, `rebirthMultiplier` —
    -- денормализованный множитель к value руд. Оба `set()` мгновенно, без
    -- tween: ребёрт — это редкое дискретное событие.
    rebirths: any,
    rebirthMultiplier: any,
    -- Phase 10: retention-стейт.
    --   dailyCanClaim          — true → DailyRewardModal должен показаться.
    --   dailyStreak            — текущий стрик (0..7, 0 = новичок).
    --   dailyNextDay           — какой день будет при следующем claim'е (1..7).
    --   dailySecondsUntilNext  — для countdown'a в модале / chip'е.
    --   activeBoosts           — список { kind, multiplier, remaining, source, expiresAt }
    --                            BoostChip тикает remaining раз в секунду локально.
    --   leaderboardPlacement   — кэш ранка (для StatsPanel + footer'a leaderboard'a).
    dailyCanClaim: any,
    dailyStreak: any,
    dailyNextDay: any,
    dailySecondsUntilNext: any,
    dailyTotalClaimed: any,
    activeBoosts: any,
    leaderboardPlacement: any,
    -- Phase 11: pets.
    --   pets        — список { uid, petId } (PetsPanel резолвит def'ы).
    --   equippedPet — uid экипированного пета (nil = ничего).
    --   petEffects  — сводка бустов { damage, luck, coin, multiMine, equippedCount }.
    pets: any,
    equippedPet: any,
    petEffects: any,
    -- Phase 12: монетизация.
    --   gamepasses   — кэш владения { vip=true, ... } для ShopPanel / VIP-chip.
    --   equippedUids — список uid экипированных петов (multi-slot).
    gamepasses: any,
    equippedUids: any,
    petMaxEquipped: any,
    -- Phase 13: журнал находок (retention — цель охоты = руда).
    discoveredOres: any,
    discoveredMilestones: any,
    discoveryFound: any,
    discoveryTotal: any,
}

local HudState = {}

-- Обновить Value только если значение реально изменилось — лишний :set()
-- триггерит пересчёт всех Fusion Computed, зависящих от этого Value.
local function setIfDiff(valueObj: any, newVal: any, eq: ((any, any) -> boolean)?)
    local cur = peek(valueObj)
    local same = if eq then eq(cur, newVal) else cur == newVal
    if not same then
        valueObj:set(newVal)
    end
end

local function inventoryEqual(a: { PlayerDataMapper.InventoryEntry }, b: { PlayerDataMapper.InventoryEntry }): boolean
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i].oreId ~= b[i].oreId or a[i].count ~= b[i].count then
            return false
        end
    end
    return true
end

local function shallowTableEqual(a: { [string]: any }, b: { [string]: any }): boolean
    for k, v in pairs(a) do
        if b[k] ~= v then return false end
    end
    for k, _ in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

export type MiningHudDelta = {
    coins: number?,
    inventory: { PlayerDataMapper.InventoryEntry }?,
    totalBlocksMined: number?,
    totalCoinsEarned: number?,
}

function HudState.create(scope: ScopeFactory.HudScope): HudState
    return {
        scope = scope,
        coins = scope:Value(0),
        coinsDisplay = scope:Value(0),
        gems = scope:Value(0),
        depth = scope:Value(0),
        layerId = scope:Value("dirt"),
        layerName = scope:Value("Dirt Layer"),
        inventory = scope:Value({} :: { PlayerDataMapper.InventoryEntry }),
        upgrades = scope:Value({} :: PlayerDataMapper.UpgradeLevels),
        panelOpen = scope:Value(false),
        activeTab = scope:Value("inventory"),
        statBlocksMined = scope:Value(0),
        statTotalCoins = scope:Value(0),
        statTotalCoinsDisplay = scope:Value(0),
        statBossesDefeated = scope:Value(0),
        statMaxDepth = scope:Value(0),
        tutorialStep = scope:Value(0),
        rebirths = scope:Value(0),
        rebirthMultiplier = scope:Value(1.0),
        dailyCanClaim = scope:Value(false),
        dailyStreak = scope:Value(0),
        dailyNextDay = scope:Value(1),
        dailySecondsUntilNext = scope:Value(0),
        dailyTotalClaimed = scope:Value(0),
        activeBoosts = scope:Value({} :: { PlayerDataMapper.ActiveBoostPayload }),
        leaderboardPlacement = scope:Value({
            coinsRank = nil,
            depthRank = nil,
            coinsValue = 0,
            depthValue = 0,
        } :: PlayerDataMapper.LeaderboardPlacementPayload),
        pets = scope:Value({} :: { PlayerDataMapper.PetRecordPayload }),
        equippedPet = scope:Value(nil :: string?),
        petEffects = scope:Value({
            damage = 1, luck = 1, coin = 0, multiMine = 0, equippedCount = 0,
        } :: PlayerDataMapper.PetEffectsPayload),
        gamepasses = scope:Value({} :: { [string]: boolean }),
        equippedUids = scope:Value({} :: { string }),
        petMaxEquipped = scope:Value(1),
        discoveredOres = scope:Value({} :: { [string]: boolean }),
        discoveredMilestones = scope:Value({} :: { [string]: boolean }),
        discoveryFound = scope:Value(0),
        discoveryTotal = scope:Value(0),
    }
end

function HudState.sortInventory(inv: { PlayerDataMapper.InventoryEntry })
    table.sort(inv, function(a, b)
        local ra = theme.RARITY_ORDER[OreLookup.getRarity(a.oreId)] or 6
        local rb = theme.RARITY_ORDER[OreLookup.getRarity(b.oreId)] or 6
        return ra < rb
    end)
end

function HudState.applyMiningDelta(state: HudState, delta: MiningHudDelta)
    if delta.coins ~= nil then
        local prevCoins = peek(state.coins)
        setIfDiff(state.coins, delta.coins)
        if prevCoins ~= delta.coins then
            AnimatedNumber.tween(state.coinsDisplay, delta.coins, COIN_TWEEN_SECONDS)
        end
    end
    if delta.inventory then
        local inv = delta.inventory
        HudState.sortInventory(inv)
        if not inventoryEqual(peek(state.inventory), inv) then
            state.inventory:set(inv)
        end
    end
    if delta.totalBlocksMined ~= nil then
        setIfDiff(state.statBlocksMined, delta.totalBlocksMined)
    end
    if delta.totalCoinsEarned ~= nil then
        local prevTotal = peek(state.statTotalCoins)
        setIfDiff(state.statTotalCoins, delta.totalCoinsEarned)
        if prevTotal ~= delta.totalCoinsEarned then
            AnimatedNumber.tween(state.statTotalCoinsDisplay, delta.totalCoinsEarned, COIN_TWEEN_SECONDS)
        end
    end
end

function HudState.applyServerPayload(state: HudState, payload: PlayerDataMapper.ServerPlayerPayload)
    local mapped = PlayerDataMapper.fromServer(payload)
    HudState.sortInventory(mapped.inventory)
    -- Diffing: :set() только на изменившиеся Value — иначе каждый PlayerStats
    -- пересчитывает весь Fusion-граф (~30 полей), даже если изменились coins.
    local prevCoins = peek(state.coins)
    setIfDiff(state.coins, mapped.coins)
    if prevCoins ~= mapped.coins then
        AnimatedNumber.tween(state.coinsDisplay, mapped.coins, COIN_TWEEN_SECONDS)
    end
    setIfDiff(state.gems, mapped.gems)
    if not inventoryEqual(peek(state.inventory), mapped.inventory) then
        state.inventory:set(mapped.inventory)
    end
    setIfDiff(state.upgrades, mapped.upgrades, shallowTableEqual)
    local prevStatCoins = peek(state.statTotalCoins)
    setIfDiff(state.statTotalCoins, mapped.totalCoinsEarned)
    if prevStatCoins ~= mapped.totalCoinsEarned then
        AnimatedNumber.tween(state.statTotalCoinsDisplay, mapped.totalCoinsEarned, COIN_TWEEN_SECONDS)
    end
    setIfDiff(state.statBlocksMined, mapped.totalBlocksMined)
    setIfDiff(state.statBossesDefeated, mapped.bossesDefeated)
    setIfDiff(state.statMaxDepth, mapped.maxDepthReached)
    setIfDiff(state.tutorialStep, mapped.tutorialStep)
    setIfDiff(state.rebirths, mapped.rebirths)
    setIfDiff(state.rebirthMultiplier, mapped.rebirthMultiplier)
    setIfDiff(state.dailyCanClaim, mapped.dailyState.canClaim or false)
    setIfDiff(state.dailyStreak, mapped.dailyState.currentStreak or 0)
    setIfDiff(state.dailyNextDay, mapped.dailyState.nextDay or 1)
    setIfDiff(state.dailySecondsUntilNext, mapped.dailyState.secondsUntilNextDay or 0)
    setIfDiff(state.dailyTotalClaimed, mapped.dailyState.totalDaysClaimed or 0)
    setIfDiff(state.activeBoosts, mapped.activeBoosts, shallowTableEqual)
    setIfDiff(state.leaderboardPlacement, mapped.leaderboardPlacement, shallowTableEqual)
    setIfDiff(state.pets, mapped.pets, shallowTableEqual)
    setIfDiff(state.petEffects, mapped.petEffects, shallowTableEqual)
    setIfDiff(state.gamepasses, mapped.gamepasses, shallowTableEqual)
    setIfDiff(state.equippedUids, mapped.equippedUids, shallowTableEqual)
    setIfDiff(state.petMaxEquipped, mapped.petMaxEquipped)
    local newEquipped = if #mapped.equippedUids > 0 then mapped.equippedUids[1] else mapped.equippedPet
    setIfDiff(state.equippedPet, newEquipped)
    setIfDiff(state.discoveredOres, mapped.discoveredOres, shallowTableEqual)
    setIfDiff(state.discoveredMilestones, mapped.discoveredMilestones, shallowTableEqual)
    setIfDiff(state.discoveryFound, mapped.discoveryProgress.found)
    setIfDiff(state.discoveryTotal, mapped.discoveryProgress.total)
end

function HudState.applyDepth(state: HudState, depth: number, layerId: string, layerName: string)
    state.depth:set(depth)
    state.layerId:set(layerId)
    state.layerName:set(layerName)
end

return HudState
