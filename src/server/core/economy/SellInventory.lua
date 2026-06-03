--!strict
-- Продажа всего инвентаря по OreDatabase.value + бонус multiSell.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")

local OreTypes = require(shared.types.OreTypes)
local UpgradeLogic = require(shared.util.UpgradeLogic)
local RebirthLogic = require(shared.util.RebirthLogic)
-- Phase 11: coinBoost экипированных петов (аддитивно в boost-стадию).
local PetLogic = require(shared.util.PetLogic)
-- Phase 10: boost multiplier из активных daily-бустов.
-- script.Parent (economy) -> script.Parent.Parent (core) -> PlayerBoosts.
local PlayerBoosts = require(script.Parent.Parent.PlayerBoosts)

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
    -- Phase 9: prestige-множитель к цене продажи. Источник истины —
    -- RebirthLogic.valueMultiplier; playerData.rebirthMultiplier — только
    -- денормализованный кэш для скорости. Здесь читаем именно поле, чтобы
    -- не зависеть от состояния кэша между двумя продажами (RebirthManager
    -- пересчитывает кэш сразу после ребёрта и при загрузке профиля).
    local rebirthMult = playerData.rebirthMultiplier
        or RebirthLogic.valueMultiplier(playerData.rebirths or 0)
    -- Phase 10: boost-множитель из активных daily-бустов. Чистим истёкшие
    -- здесь же, чтобы значение не получалось «фантомным» (boost истёк, а
    -- payout всё ещё с x2). cleanup мутирует список — после продажи
    -- syncPlayerHud отрисует свежий activeBoosts на BoostChip.
    PlayerBoosts.cleanup(playerData.activeBoosts)
    -- Phase 11: coinBoost петов складывается с daily-boost'ами аддитивно в
    -- ту же стадию (1 + Σ(daily) + Σ(pet coinBoost)) — порядок multiSell →
    -- rebirth → boost из Фазы 10 не меняем. Пет с +25% и daily x2 дают
    -- boostMult = 1 + 1.0 + 0.25 = 2.25 (Pet Sim style additive stack).
    local boostMult = PlayerBoosts.totalMultiplier(playerData.activeBoosts, "coins")
        + PetLogic.coinBoostSum(playerData)
    -- Порядок: gross * multiSell * rebirth * boost. Rebirth — permanent,
    -- boost — temporary. Если применять boost ДО rebirth, при разных
    -- rebirth-уровнях boost даст разный эффект, что не интуитивно.
    local payout = math.floor(gross * multiplier * rebirthMult * boostMult)

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
