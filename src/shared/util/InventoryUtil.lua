--!strict

local InventoryUtil = {}

function InventoryUtil.totalCount(inventory: { [string]: number }): number
    local total = 0
    for _, count in pairs(inventory) do
        if type(count) == "number" and count > 0 then
            total += count
        end
    end
    return total
end

function InventoryUtil.addOre(inventory: { [string]: number }, oreId: string, amount: number): { [string]: number }
    if amount <= 0 then
        return inventory
    end
    inventory[oreId] = (inventory[oreId] or 0) + amount
    return inventory
end

return InventoryUtil
