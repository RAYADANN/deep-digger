--!strict
-- Продажа всего инвентаря по OreDatabase.value + бонус multiSell.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")

local OreTypes = require(shared.types.OreTypes)
local UpgradeLogic = require(shared.util.UpgradeLogic)

export type OreDatabaseLike = {
    getOre: (self: any, oreId: string) -> OreTypes.OreDef?,
}

export type SellResult = {
    success: boolean,
    coinsEarned: number?,
    itemsSold: number?,
    error: string?,
    message: string?,
}

local SellInventory = {}

local function inventoryIsEmpty(inventory: { [string]: number }): boolean
    for _, count in pairs(inventory) do
        if type(count) == "number" and count > 0 then
            return false
        end
    end
    return true
end

function SellInventory.execute(oreDb: OreDatabaseLike, playerData: OreTypes.PlayerData): SellResult
    local inventory = playerData.inventory or {}
    if inventoryIsEmpty(inventory) then
        return {
            success = false,
            error = "empty_inventory",
            message = "Инвентарь пуст",
        }
    end

    local gross = 0
    local itemsSold = 0
    local keptInventory: { [string]: number } = {}

    for oreId, count in pairs(inventory) do
        if type(count) == "number" and count > 0 then
            local ore = oreDb:getOre(oreId)
            if ore then
                gross += (ore.value or 0) * count
                itemsSold += count
            else
                keptInventory[oreId] = count
            end
        end
    end

    if itemsSold == 0 then
        return {
            success = false,
            error = "empty_inventory",
            message = "Инвентарь пуст",
        }
    end

    local multiplier = UpgradeLogic.multiSellMultiplier(playerData.multiSellLevel or 1)
    local payout = math.floor(gross * multiplier)

    playerData.inventory = keptInventory
    playerData.coins = (playerData.coins or 0) + payout
    playerData.totalCoinsEarned = (playerData.totalCoinsEarned or 0) + payout

    return {
        success = true,
        coinsEarned = payout,
        itemsSold = itemsSold,
        message = ("+%d монет"):format(payout),
    }
end

return SellInventory
