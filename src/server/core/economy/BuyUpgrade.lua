--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")

local Constants = require(shared.constants)
local OreTypes = require(shared.types.OreTypes)
local UpgradeLogic = require(shared.util.UpgradeLogic)

export type BuyResult = {
    success: boolean,
    upgradeId: string?,
    newLevel: number?,
    coinsSpent: number?,
    error: string?,
    message: string?,
}

local BuyUpgrade = {}

local function getLevel(playerData: OreTypes.PlayerData, upgradeId: string): number
    if upgradeId == "autoSell" then
        return if playerData.autoSellUnlocked then 1 else 0
    end
    local field = UpgradeLogic.levelField(upgradeId)
    if not field then
        return 0
    end
    return (playerData :: any)[field] or 1
end

function BuyUpgrade.execute(playerData: OreTypes.PlayerData, upgradeId: string): BuyResult
    local cfg = Constants.UPGRADES[upgradeId]
    if not cfg then
        return { success = false, error = "unknown_upgrade", message = "Неизвестный апгрейд" }
    end

    local currentLevel = getLevel(playerData, upgradeId)

    if upgradeId == "autoSell" then
        if playerData.autoSellUnlocked then
            return { success = false, error = "max_level", message = "Уже куплено" }
        end
        local cost = cfg.baseCost
        local coins = playerData.coins or 0
        if coins < cost then
            return {
                success = false,
                error = "not_enough_coins",
                message = ("Не хватает %d монет"):format(cost - coins),
            }
        end
        playerData.coins -= cost
        playerData.autoSellUnlocked = true
        return {
            success = true,
            upgradeId = upgradeId,
            newLevel = 1,
            coinsSpent = cost,
            message = "Авто-продажа включена",
        }
    end

    -- Phase 9: maxLevel у pickaxe растёт с количеством ребёртов
    -- (см. RebirthLogic.pickaxeMaxLevelBonus). UpgradeLogic.maxLevel —
    -- единственный источник, чтобы клиентский tooltip и сервер совпадали.
    local effectiveMax = UpgradeLogic.maxLevel(upgradeId, playerData.rebirths or 0)
    if currentLevel >= effectiveMax then
        return { success = false, error = "max_level", message = "Максимальный уровень" }
    end

    local cost = UpgradeLogic.upgradeCost(upgradeId, currentLevel)
    local coins = playerData.coins or 0
    if coins < cost then
        return {
            success = false,
            error = "not_enough_coins",
            message = ("Не хватает %d монет"):format(cost - coins),
        }
    end

    local field = UpgradeLogic.levelField(upgradeId)
    if not field then
        return { success = false, error = "invalid_upgrade", message = "Нельзя улучшить" }
    end

    playerData.coins -= cost
    local newLevel = currentLevel + 1
    local data = playerData :: any
    data[field] = newLevel

    return {
        success = true,
        upgradeId = upgradeId,
        newLevel = newLevel,
        coinsSpent = cost,
        message = ("Уровень %d"):format(newLevel),
    }
end

return BuyUpgrade
