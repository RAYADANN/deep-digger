--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.ScopeFactory)
local PlayerDataMapper = require(script.Parent.PlayerDataMapper)
local OreCatalog = require(script.Parent.OreCatalog)
local theme = require(script.Parent.theme)

export type HudState = {
    scope: ScopeFactory.HudScope,
    coins: any,
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
    statBossesDefeated: any,
    statMaxDepth: any,
}

local HudState = {}

function HudState.create(scope: ScopeFactory.HudScope): HudState
    return {
        scope = scope,
        coins = scope:Value(0),
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
        statBossesDefeated = scope:Value(0),
        statMaxDepth = scope:Value(0),
    }
end

function HudState.sortInventory(inv: { PlayerDataMapper.InventoryEntry })
    table.sort(inv, function(a, b)
        local ra = theme.RARITY_ORDER[OreCatalog.getRarity(a.oreId)] or 6
        local rb = theme.RARITY_ORDER[OreCatalog.getRarity(b.oreId)] or 6
        return ra < rb
    end)
end

function HudState.applyServerPayload(state: HudState, payload: PlayerDataMapper.ServerPlayerPayload)
    local mapped = PlayerDataMapper.fromServer(payload)
    HudState.sortInventory(mapped.inventory)
    state.coins:set(mapped.coins)
    state.gems:set(mapped.gems)
    state.inventory:set(mapped.inventory)
    state.upgrades:set(mapped.upgrades)
    state.statBlocksMined:set(mapped.totalBlocksMined)
    state.statTotalCoins:set(mapped.totalCoinsEarned)
    state.statBossesDefeated:set(mapped.bossesDefeated)
    state.statMaxDepth:set(mapped.maxDepthReached)
end

function HudState.applyDepth(state: HudState, depth: number, layerId: string, layerName: string)
    state.depth:set(depth)
    state.layerId:set(layerId)
    state.layerName:set(layerName)
end

return HudState
