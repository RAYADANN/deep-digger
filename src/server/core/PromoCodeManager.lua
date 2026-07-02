--!strict
-- PromoCodeManager.lua — серверная активация промокодов.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local PromoCodeLogic = require(shared.util.PromoCodeLogic)
local PlayerBoosts = require(script.Parent.PlayerBoosts)
local Net = require(modules.Net)

export type Deps = {
	profileManager: any,
	onProfileChanged: ((player: Player) -> ())?,
	notify: ((player: Player, payload: any) -> ())?,
}

local GLOBAL_STORE = "PromoCodeGlobal_v1"
local GOLD = { r = 255, g = 210, b = 50 }

local PromoCodeManager = {}
PromoCodeManager.__index = PromoCodeManager

function PromoCodeManager.new(deps: Deps)
	local self = setmetatable({}, PromoCodeManager)
	self._log = Logger.new("PromoCode")
	self._profileManager = deps.profileManager
	self._onProfileChanged = deps.onProfileChanged
	self._notify = deps.notify
	self._globalStore = DataStoreService:GetDataStore(GLOBAL_STORE)

	Net:Handle("RedeemCode", function(player: Player, rawCode: string)
		return self:_handleRedeem(player, rawCode)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self._redeemBusy[player.UserId] = nil
	end)

	self._redeemBusy = {} :: { [number]: boolean }
	self._log:info("PromoCodeManager initialized")
	return self
end

function PromoCodeManager:_data(player: Player)
	return self._profileManager:getData(player)
end

function PromoCodeManager:_sync(player: Player)
	if self._onProfileChanged then
		self._onProfileChanged(player)
	end
end

function PromoCodeManager:onProfileLoaded(player: Player)
	local data = self:_data(player)
	if data then
		PromoCodeLogic.ensureRedeemed(data)
	end
end

function PromoCodeManager:_reserveGlobalSlot(code: string, maxRedemptions: number): (boolean, string?)
	local key = "code_" .. code
	local ok, result = pcall(function()
		return self._globalStore:UpdateAsync(key, function(old)
			local count = if typeof(old) == "number" then old else 0
			if count >= maxRedemptions then
				return nil
			end
			return count + 1
		end)
	end)
	if not ok then
		self._log:warn("Global promo DS failed for", code, result)
		return false, "store_error"
	end
	if result == nil then
		return false, "exhausted"
	end
	return true, nil
end

function PromoCodeManager:_grantReward(data: any, reward: any): string
	local parts: { string } = {}
	if reward.coins and reward.coins > 0 then
		local amt = math.floor(reward.coins)
		data.coins = (data.coins or 0) + amt
		data.totalCoinsEarned = (data.totalCoinsEarned or 0) + amt
		table.insert(parts, ("+%d монет"):format(amt))
	end
	if reward.gems and reward.gems > 0 then
		local amt = math.floor(reward.gems)
		data.gems = (data.gems or 0) + amt
		table.insert(parts, ("+%d крист."):format(amt))
	end
	if reward.boost and typeof(reward.boost) == "table" then
		local boosts = data.activeBoosts
		if typeof(boosts) ~= "table" then
			boosts = {}
			data.activeBoosts = boosts
		end
		PlayerBoosts.addBoost(boosts, {
			kind = reward.boost.kind or "coins",
			multiplier = reward.boost.multiplier or 2,
			durationSec = reward.boost.durationSec or 600,
			source = "promo_code",
		})
		table.insert(parts, ("буст x%d"):format(math.floor(reward.boost.multiplier or 2)))
	end
	if #parts == 0 then
		return "Награда получена"
	end
	return table.concat(parts, ", ")
end

function PromoCodeManager:_handleRedeem(player: Player, rawCode: string)
	if self._redeemBusy[player.UserId] then
		return { success = false, error = "busy", message = "Подождите…" }
	end
	if typeof(rawCode) ~= "string" then
		return { success = false, error = "bad_input", message = "Некорректный код" }
	end

	local data = self:_data(player)
	if not data then
		return { success = false, error = "no_profile", message = "Профиль не загружен" }
	end

	local check = PromoCodeLogic.validate(data, rawCode)
	if not check.ok or not check.def or not check.normalizedCode then
		return {
			success = false,
			error = check.error or "invalid",
			message = check.message or "Код недействителен",
		}
	end

	local def = check.def
	local code = check.normalizedCode
	self._redeemBusy[player.UserId] = true

	if def.maxRedemptions then
		local reserved, err = self:_reserveGlobalSlot(code, def.maxRedemptions)
		if not reserved then
			self._redeemBusy[player.UserId] = nil
			if err == "exhausted" then
				return { success = false, error = "exhausted", message = "Лимит активаций исчерпан" }
			end
			return { success = false, error = "store_error", message = "Ошибка сервера, попробуйте позже" }
		end
	end

	local redeemed = PromoCodeLogic.ensureRedeemed(data)
	redeemed[code] = true
	local grantText = self:_grantReward(data, def.reward)
	self._redeemBusy[player.UserId] = nil

	if self._notify then
		self._notify(player, {
			text = grantText,
			icon = "icon_gift",
			color = GOLD,
			duration = 4,
			kind = "promo_redeemed",
		})
	end
	self:_sync(player)
	self._log:info("Redeemed", code, "for", player.UserId)
	return { success = true, message = grantText, code = code }
end

return PromoCodeManager
