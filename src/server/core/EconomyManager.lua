--!strict
-- EconomyManager.lua — ЗАГЛУШКА
-- Управление экономикой: монеты, продажа руд, покупка улучшений
-- MVP: базовая версия, без расширенных механик

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local Net = require(modules.Net)

local EconomyManager = {}
EconomyManager.__index = EconomyManager

function EconomyManager.new(miningEngine: any)
    local self = setmetatable({}, EconomyManager)
    self._log = Logger.new("EconomyManager")
    self._miningEngine = miningEngine

    -- RemoteFunctions (через Net:Handle)
    Net:Handle("BuyUpgrade", function(player, upgradeId)
        return self:buyUpgrade(player, upgradeId)
    end)

    Net:Handle("SellOres", function(player)
        return self:sellAll(player)
    end)

    self._log:info("EconomyManager initialized (MVP stub)")
    return self
end

function EconomyManager:buyUpgrade(player, upgradeId: string)
    if not Constants.UPGRADES[upgradeId] then
        return { success = false, error = "Unknown upgrade" }
    end
    return { success = false, error = "Not implemented yet" }
end

function EconomyManager:sellAll(player)
    return { success = false, error = "Not implemented yet" }
end

function EconomyManager:addCoins(player, amount: number)
    return false
end

function EconomyManager:removeCoins(player, amount: number)
    return false
end

return EconomyManager
