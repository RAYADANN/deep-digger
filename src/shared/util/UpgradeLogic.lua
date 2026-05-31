--!strict
-- Формулы апгрейдов (единый источник для сервера и клиента).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local UpgradeLogic = {}

function UpgradeLogic.upgradeCost(upgradeId: string, currentLevel: number): number
    local cfg = Constants.UPGRADES[upgradeId]
    if not cfg then
        return 0
    end
    return math.floor(cfg.baseCost * ((cfg.exponent or 1.5) ^ (currentLevel - 1)))
end

function UpgradeLogic.swingDelaySeconds(speedLevel: number): number
    local cfg = Constants.UPGRADES.speed
    local reductionMs = cfg.reductionMs or 20
    local delayMs = Constants.BASE_SWING_DELAY_MS - (math.max(1, speedLevel) - 1) * reductionMs
    return math.max(Constants.MIN_SWING_DELAY_SECONDS, delayMs / 1000)
end

function UpgradeLogic.pickaxePower(pickaxeLevel: number): number
    local cfg = Constants.UPGRADES.pickaxe
    return 1 + (math.max(1, pickaxeLevel) - 1) * (cfg.powerPerLevel or 2)
end

function UpgradeLogic.critChance(critLevel: number): number
    local cfg = Constants.UPGRADES.crit
    local base = cfg.baseChance or 0.05
    local perLevel = cfg.chancePerLevel or 0.03
    return base + (math.max(1, critLevel) - 1) * perLevel
end

function UpgradeLogic.fortuneBonusChance(fortuneLevel: number): number
    local cfg = Constants.UPGRADES.fortune
    return (math.max(1, fortuneLevel) - 1) * (cfg.chancePerLevel or 0.02)
end

function UpgradeLogic.inventoryCapacity(inventoryLevel: number): number
    local cfg = Constants.UPGRADES.inventory
    return Constants.BASE_INVENTORY_SLOTS + math.max(1, inventoryLevel) * (cfg.slotsPerLevel or 5)
end

function UpgradeLogic.multiSellMultiplier(multiSellLevel: number): number
    local cfg = Constants.UPGRADES.multiSell
    local level = math.max(1, multiSellLevel)
    return 1 + (level - 1) * (cfg.bonusPerLevel or 0.05)
end

function UpgradeLogic.levelField(upgradeId: string): string?
    if upgradeId == "autoSell" then
        return nil
    end
    return upgradeId .. "Level"
end

return UpgradeLogic
