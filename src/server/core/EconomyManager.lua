--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Net = require(modules.Net)
local OreTypes = require(shared.types.OreTypes)

local ProfileManager = require(script.Parent.ProfileManager)
local SellInventory = require(script.Parent.economy.SellInventory)
local BuyUpgrade = require(script.Parent.economy.BuyUpgrade)

export type Deps = {
    profileManager: typeof(ProfileManager.new()),
    oreDatabase: SellInventory.OreDatabaseLike,
    onEconomyChanged: ((player: Player) -> ())?,
}

local EconomyManager = {}
EconomyManager.__index = EconomyManager

function EconomyManager.new(deps: Deps)
    local self = setmetatable({}, EconomyManager)
    self._log = Logger.new("EconomyManager")
    self._profileManager = deps.profileManager
    self._oreDatabase = deps.oreDatabase
    self._onEconomyChanged = deps.onEconomyChanged

    Net:Handle("BuyUpgrade", function(player, upgradeId)
        return self:buyUpgrade(player, upgradeId)
    end)

    Net:Handle("SellOres", function(player)
        return self:sellAll(player)
    end)

    self._log:info("EconomyManager initialized")
    return self
end

function EconomyManager:_syncPlayer(player: Player)
    if self._onEconomyChanged then
        self._onEconomyChanged(player)
    end
end

function EconomyManager:_getData(player: Player): OreTypes.PlayerData?
    return self._profileManager:getData(player)
end

function EconomyManager:sellAll(player: Player)
    local playerData = self:_getData(player)
    if not playerData then
        return { success = false, error = "no_profile", message = "Профиль не загружен" }
    end

    local result = SellInventory.execute(self._oreDatabase, playerData)
    if result.success then
        self._log:info("Sold ores for", player.UserId, "- coins:", result.coinsEarned, "items:", result.itemsSold)
        self:_syncPlayer(player)
    end

    return result
end

function EconomyManager:buyUpgrade(player: Player, upgradeId: string)
    if type(upgradeId) ~= "string" then
        return { success = false, error = "invalid_request", message = "Неверный запрос" }
    end

    local playerData = self:_getData(player)
    if not playerData then
        return { success = false, error = "no_profile", message = "Профиль не загружен" }
    end

    local result = BuyUpgrade.execute(playerData, upgradeId)
    if result.success then
        self._log:info("Upgrade bought:", player.UserId, upgradeId, "->", result.newLevel)
        self:_syncPlayer(player)
    end

    return result
end

function EconomyManager:addCoins(player: Player, amount: number): boolean
    if amount <= 0 then
        return false
    end
    local playerData = self:_getData(player)
    if not playerData then
        return false
    end
    playerData.coins = (playerData.coins or 0) + amount
    self:_syncPlayer(player)
    return true
end

function EconomyManager:removeCoins(player: Player, amount: number): boolean
    if amount <= 0 then
        return false
    end
    local playerData = self:_getData(player)
    if not playerData then
        return false
    end
    if (playerData.coins or 0) < amount then
        return false
    end
    playerData.coins -= amount
    self:_syncPlayer(player)
    return true
end

return EconomyManager
