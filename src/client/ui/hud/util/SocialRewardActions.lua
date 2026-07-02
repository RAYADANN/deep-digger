--!strict
-- Клиентские действия соц-награды (группа + избранное + claim).

local GroupService = game:GetService("GroupService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local peek = Fusion.peek
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)

local Notification = require(script.Parent.Parent.Parent.Notification)
local theme = require(script.Parent.Parent.theme)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local SocialRewardLogic = require(ReplicatedStorage:WaitForChild("shared").util.SocialRewardLogic)

local C = theme.C

local SocialRewardActions = {}

function SocialRewardActions.statusMark(done: boolean): string
	return if done then "✓" else "✗"
end

function SocialRewardActions.rewardSummary(): string
	local rewards = (Constants.SOCIAL_REWARD or {}).rewards or {}
	local parts: { string } = {}
	if rewards.coins and rewards.coins > 0 then
		table.insert(parts, ("+%d монет"):format(rewards.coins))
	end
	if rewards.gems and rewards.gems > 0 then
		table.insert(parts, ("+%d крист."):format(rewards.gems))
	end
	if rewards.boost then
		table.insert(parts, ("буст x%d"):format(math.floor(rewards.boost.multiplier or 2)))
	end
	return table.concat(parts, "  ·  ")
end

function SocialRewardActions.promptGroup(isBusy: any)
	if peek(isBusy) then
		return
	end
	local groupId = SocialRewardLogic.groupId()
	if groupId <= 0 then
		Notification.show({ text = "Группа ещё не настроена", color = C.closeBg, duration = 3 })
		return
	end
	isBusy:set(true)
	task.spawn(function()
		pcall(function()
			GroupService:PromptGroupMembership(groupId)
		end)
		task.wait(2)
		pcall(function()
			Net:Invoke("RefreshSocialStatus")
		end)
		isBusy:set(false)
	end)
end

function SocialRewardActions.promptFavorite(isBusy: any)
	if peek(isBusy) then
		return
	end
	local universeId = SocialRewardLogic.universeId()
	if universeId <= 0 then
		Notification.show({ text = "Игра ещё не настроена", color = C.closeBg, duration = 3 })
		return
	end
	isBusy:set(true)
	task.spawn(function()
		local prompted = pcall(function()
			AvatarEditorService:PromptSetFavorite(universeId, true)
		end)
		if prompted then
			pcall(function()
				Net:Invoke("ConfirmSocialFavorite")
			end)
		end
		isBusy:set(false)
	end)
end

function SocialRewardActions.tryClaim(isBusy: any, onComplete: ((boolean) -> ())?)
	if peek(isBusy) then
		return
	end
	isBusy:set(true)
	task.spawn(function()
		local ok, result = pcall(function()
			return Net:Invoke("ClaimSocialReward")
		end)
		isBusy:set(false)
		if not ok then
			Notification.show({ text = "Ошибка сети", color = C.closeBg, duration = 3 })
			if onComplete then
				onComplete(false)
			end
			return
		end
		if typeof(result) == "table" and result.success then
			if onComplete then
				onComplete(true)
			end
			return
		end
		local msg = if typeof(result) == "table" and typeof(result.message) == "string"
			then result.message
			else "Условия не выполнены"
		Notification.show({ text = msg, color = C.closeBg, duration = 3.5 })
		if onComplete then
			onComplete(false)
		end
	end)
end

return SocialRewardActions
