--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UpgradeLogic = require(ReplicatedStorage:WaitForChild("shared").util.UpgradeLogic)

local Formatters = {}

function Formatters.shortNumber(n: number): string
    if n >= 1e9 then
        return ("%.1fB"):format(n / 1e9)
    elseif n >= 1e6 then
        return ("%.1fM"):format(n / 1e6)
    elseif n >= 1e3 then
        return ("%.1fK"):format(n / 1e3)
    end
    return tostring(math.floor(n))
end

function Formatters.upgradeCost(upgradeId: string, level: number): number
    if upgradeId == "autoSell" and level < 1 then
        level = 1
    end
    return UpgradeLogic.upgradeCost(upgradeId, level)
end

return Formatters
