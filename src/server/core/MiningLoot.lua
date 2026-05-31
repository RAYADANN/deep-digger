--!strict
-- Добавление руды в инвентарь: лимит, fortune, авто-продажа.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")

local OreTypes = require(shared.types.OreTypes)
local UpgradeLogic = require(shared.util.UpgradeLogic)
local InventoryUtil = require(shared.util.InventoryUtil)
local SellInventory = require(script.Parent.economy.SellInventory)

export type OreDatabaseLike = SellInventory.OreDatabaseLike

export type AddOreResult = {
    added: number,
    fortuneBonus: boolean,
    autoSold: boolean,
    rejected: number,
}

local MiningLoot = {}

function MiningLoot.rollFortuneBonus(fortuneLevel: number): boolean
    local chance = UpgradeLogic.fortuneBonusChance(fortuneLevel)
    if chance <= 0 then
        return false
    end
    return math.random() < chance
end

function MiningLoot.tryAddOre(
    oreDb: OreDatabaseLike,
    playerData: OreTypes.PlayerData,
    oreId: string,
    baseAmount: number,
    fortuneBonus: boolean
): AddOreResult
    local amount = baseAmount + (if fortuneBonus then 1 else 0)
    local capacity = UpgradeLogic.inventoryCapacity(playerData.inventoryLevel or 1)
    playerData.inventory = playerData.inventory or {}

    local current = InventoryUtil.totalCount(playerData.inventory)
    local autoSold = false

    if current + amount > capacity then
        if playerData.autoSellUnlocked then
            SellInventory.execute(oreDb, playerData)
            autoSold = true
            current = InventoryUtil.totalCount(playerData.inventory)
        end
    end

    local space = math.max(0, capacity - current)
    local toAdd = math.min(amount, space)
    local rejected = amount - toAdd

    if toAdd > 0 then
        InventoryUtil.addOre(playerData.inventory, oreId, toAdd)
    end

    return {
        added = toAdd,
        fortuneBonus = fortuneBonus,
        autoSold = autoSold,
        rejected = rejected,
    }
end

return MiningLoot
