--!strict
-- SocialRewardManager.lua — награда за группу + избранное.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local SocialRewardLogic = require(shared.util.SocialRewardLogic)
local PlayerBoosts = require(script.Parent.PlayerBoosts)
local Net = require(modules.Net)

export type Deps = {
	profileManager: any,
	onProfileChanged: ((player: Player) -> ())?,
	notify: ((player: Player, payload: any) -> ())?,
}

local GOLD = { r = 255, g = 210, b = 50 }

local SocialRewardManager = {}
SocialRewardManager.__index = SocialRewardManager

function SocialRewardManager.new(deps: Deps)
	local self = setmetatable({}, SocialRewardManager)
	self._log = Logger.new("SocialReward")
	self._profileManager = deps.profileManager
	self._onProfileChanged = deps.onProfileChanged
	self._notify = deps.notify
	self._groupCache = {} :: { [number]: boolean }

	Net:Handle("ConfirmSocialFavorite", function(player: Player)
		return self:_handleConfirmFavorite(player)
	end)

	Net:Handle("ClaimSocialReward", function(player: Player)
		return self:_handleClaim(player)
	end)

	Net:Handle("RefreshSocialStatus", function(player: Player)
		local inGroup = self:refreshGroup(player)
		return { success = true, inGroup = inGroup }
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self._groupCache[player.UserId] = nil
	end)

	return self
end

function SocialRewardManager:_data(player: Player)
	return self._profileManager:getData(player)
end

function SocialRewardManager:_sync(player: Player)
	if self._onProfileChanged then
		self._onProfileChanged(player)
	end
end

function SocialRewardManager:isInGroup(player: Player): boolean
	local cached = self._groupCache[player.UserId]
	if cached ~= nil then
		return cached
	end
	local groupId = SocialRewardLogic.groupId()
	if groupId <= 0 then
		self._groupCache[player.UserId] = false
		return false
	end
	local ok, rank = pcall(function()
		return GroupService:GetRankInGroupAsync(player.UserId, groupId)
	end)
	local inGroup = ok and typeof(rank) == "number" and rank > 0
	self._groupCache[player.UserId] = inGroup
	return inGroup
end

function SocialRewardManager:refreshGroup(player: Player)
	self._groupCache[player.UserId] = nil
	local inGroup = self:isInGroup(player)
	self:_sync(player)
	return inGroup
end

function SocialRewardManager:buildPayload(player: Player)
	local data = self:_data(player)
	if not data then
		return SocialRewardLogic.buildPayload({}, false)
	end
	return SocialRewardLogic.buildPayload(data, self:isInGroup(player))
end

function SocialRewardManager:_grantRewards(data: any): string
	local cfg = Constants.SOCIAL_REWARD or {}
	local rewards = cfg.rewards or {}
	local parts: { string } = {}

	if rewards.coins and rewards.coins > 0 then
		local amt = math.floor(rewards.coins)
		data.coins = (data.coins or 0) + amt
		data.totalCoinsEarned = (data.totalCoinsEarned or 0) + amt
		table.insert(parts, ("+%d монет"):format(amt))
	end
	if rewards.gems and rewards.gems > 0 then
		local amt = math.floor(rewards.gems)
		data.gems = (data.gems or 0) + amt
		table.insert(parts, ("+%d крист."):format(amt))
	end
	if rewards.boost and typeof(rewards.boost) == "table" then
		local boosts = data.activeBoosts
		if typeof(boosts) ~= "table" then
			boosts = {}
			data.activeBoosts = boosts
		end
		PlayerBoosts.addBoost(boosts, {
			kind = rewards.boost.kind or "coins",
			multiplier = rewards.boost.multiplier or 2,
			durationSec = rewards.boost.durationSec or 600,
			source = "social_reward",
		})
		table.insert(parts, ("буст x%d"):format(math.floor(rewards.boost.multiplier or 2)))
	end

	if #parts == 0 then
		return "Награда получена!"
	end
	return table.concat(parts, ", ")
end

function SocialRewardManager:_handleConfirmFavorite(player: Player)
	local data = self:_data(player)
	if not data then
		return { success = false, error = "no_profile", message = "Профиль не загружен" }
	end
	SocialRewardLogic.ensureFields(data)
	if data.socialRewardClaimed then
		return { success = false, error = "claimed", message = "Награда уже получена" }
	end
	-- Honor-system: сервер не может проверить избранное; доверяем клиенту
	-- после успешного PromptSetFavorite.
	data.socialFavoriteConfirmed = true
	self:_sync(player)
	return { success = true }
end

function SocialRewardManager:_handleClaim(player: Player)
	local data = self:_data(player)
	if not data then
		return { success = false, error = "no_profile", message = "Профиль не загружен" }
	end
	SocialRewardLogic.ensureFields(data)

	if data.socialRewardClaimed then
		return { success = false, error = "claimed", message = "Награда уже получена" }
	end
	if not SocialRewardLogic.isConfigured() then
		return { success = false, error = "not_configured", message = "Награда ещё не настроена" }
	end
	if not data.socialFavoriteConfirmed then
		return { success = false, error = "favorite", message = "Добавьте игру в избранное" }
	end

	self._groupCache[player.UserId] = nil
	if not self:isInGroup(player) then
		return { success = false, error = "group", message = "Вступите в группу Roblox" }
	end

	data.socialRewardClaimed = true
	local grantText = self:_grantRewards(data)

	if self._notify then
		self._notify(player, {
			text = grantText,
			icon = "icon_gift",
			color = GOLD,
			duration = 4.5,
			kind = "social_reward",
		})
	end
	self:_sync(player)
	self._log:info("Claimed by", player.UserId)
	return { success = true, message = grantText }
end

function SocialRewardManager:onProfileLoaded(player: Player)
	local data = self:_data(player)
	if not data then
		return
	end
	SocialRewardLogic.ensureFields(data)

	task.spawn(function()
		self:refreshGroup(player)
	end)

	if data.socialRewardClaimed or not SocialRewardLogic.isConfigured() then
		return
	end

	if not data.socialRewardPromptSeen then
		data.socialRewardPromptSeen = true
		if self._notify then
			self._notify(player, {
				text = "🎁 Бесплатная награда: вступи в группу и добавь игру в избранное!",
				icon = "icon_gift",
				color = GOLD,
				duration = 6,
				kind = "social_reward_available",
			})
		end
	end
end

return SocialRewardManager
