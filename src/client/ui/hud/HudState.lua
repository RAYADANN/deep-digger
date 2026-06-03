--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

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

function HudState.applyServerPayload(state: HudState, payload: PlayerDataMapper.ServerPlayerPayload)
    local mapped = PlayerDataMapper.fromServer(payload)
    HudState.sortInventory(mapped.inventory)
    -- Phase 8: монеты обновляем в двух Value-объектах:
    --   * state.coins — авторитативная цифра, мгновенно равная серверу.
    --     По ней работают canAffordNow / canAfford в UpgradesPanel.
    --   * state.coinsDisplay — отрендеренная (через AnimatedNumber)
    --     плавная цифра. По ней рисуется TopBar / любой UI.
    -- Если бы мы тянули один state.coins, то 0.4с после продажи нельзя было
    -- бы купить апгрейд — Computed увидел бы дробное значение меньше cost.
    state.coins:set(mapped.coins)
    AnimatedNumber.tween(state.coinsDisplay, mapped.coins, COIN_TWEEN_SECONDS)
    state.gems:set(mapped.gems)
    state.inventory:set(mapped.inventory)
    state.upgrades:set(mapped.upgrades)
    state.statTotalCoins:set(mapped.totalCoinsEarned)
    AnimatedNumber.tween(state.statTotalCoinsDisplay, mapped.totalCoinsEarned, COIN_TWEEN_SECONDS)
    state.statBlocksMined:set(mapped.totalBlocksMined)
    state.statBossesDefeated:set(mapped.bossesDefeated)
    state.statMaxDepth:set(mapped.maxDepthReached)
    state.tutorialStep:set(mapped.tutorialStep)
    state.rebirths:set(mapped.rebirths)
    state.rebirthMultiplier:set(mapped.rebirthMultiplier)
    -- Phase 10: retention-state. Все .set() мгновенно (без tween) — daily
    -- claim — дискретное событие, как rebirth. Count-up монет внутри
    -- claim-анимации делается отдельно через AnimatedNumber.tween на
    -- state.coinsDisplay.
    state.dailyCanClaim:set(mapped.dailyState.canClaim or false)
    state.dailyStreak:set(mapped.dailyState.currentStreak or 0)
    state.dailyNextDay:set(mapped.dailyState.nextDay or 1)
    state.dailySecondsUntilNext:set(mapped.dailyState.secondsUntilNextDay or 0)
    state.dailyTotalClaimed:set(mapped.dailyState.totalDaysClaimed or 0)
    state.activeBoosts:set(mapped.activeBoosts)
    state.leaderboardPlacement:set(mapped.leaderboardPlacement)
    -- Phase 11: pets. Мгновенно (без tween) — hatch/equip дискретны.
    state.pets:set(mapped.pets)
    state.petEffects:set(mapped.petEffects)
    -- Phase 12: монетизация + multi-slot equip.
    state.gamepasses:set(mapped.gamepasses)
    state.equippedUids:set(mapped.equippedUids)
    state.petMaxEquipped:set(mapped.petMaxEquipped)
    -- equippedPet — первый uid для PetVisual / backward-compat; PetsPanel
    -- читает equippedUids для multi-slot.
    if #mapped.equippedUids > 0 then
        state.equippedPet:set(mapped.equippedUids[1])
    else
        state.equippedPet:set(mapped.equippedPet)
    end
    -- Phase 13: журнал находок.
    state.discoveredOres:set(mapped.discoveredOres)
    state.discoveredMilestones:set(mapped.discoveredMilestones)
    state.discoveryFound:set(mapped.discoveryProgress.found)
    state.discoveryTotal:set(mapped.discoveryProgress.total)
end

function HudState.applyDepth(state: HudState, depth: number, layerId: string, layerName: string)
    state.depth:set(depth)
    state.layerId:set(layerId)
    state.layerName:set(layerName)
end

return HudState
