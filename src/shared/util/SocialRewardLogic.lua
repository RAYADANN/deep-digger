--!strict
-- SocialRewardLogic.lua — статус соц-награды (группа + избранное).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

export type SocialPayload = {
	claimed: boolean,
	promptSeen: boolean,
	favoriteConfirmed: boolean,
	inGroup: boolean,
	canClaim: boolean,
}

local SocialRewardLogic = {}

function SocialRewardLogic.config()
	return Constants.SOCIAL_REWARD or {}
end

function SocialRewardLogic.groupId(): number
	local cfg = SocialRewardLogic.config()
	return math.floor(cfg.groupId or 0)
end

function SocialRewardLogic.universeId(): number
	local cfg = SocialRewardLogic.config()
	return math.floor(cfg.universeId or 0)
end

function SocialRewardLogic.isConfigured(): boolean
	return SocialRewardLogic.groupId() > 0 and SocialRewardLogic.universeId() > 0
end

function SocialRewardLogic.ensureFields(data: any)
	if typeof(data.socialRewardClaimed) ~= "boolean" then
		data.socialRewardClaimed = false
	end
	if typeof(data.socialRewardPromptSeen) ~= "boolean" then
		data.socialRewardPromptSeen = false
	end
	if typeof(data.socialFavoriteConfirmed) ~= "boolean" then
		data.socialFavoriteConfirmed = false
	end
end

--[[
	inGroup — серверный кэш (GroupService:GetRankInGroupAsync).
	Избранное Roblox не отдаёт серверу: favoriteConfirmed — honor-system
	после AvatarEditorService:PromptSetFavorite на клиенте.
]]
function SocialRewardLogic.buildPayload(data: any, inGroup: boolean): SocialPayload
	SocialRewardLogic.ensureFields(data)
	local claimed = data.socialRewardClaimed == true
	local favoriteConfirmed = data.socialFavoriteConfirmed == true
	local canClaim = not claimed
		and SocialRewardLogic.isConfigured()
		and inGroup
		and favoriteConfirmed
	return {
		claimed = claimed,
		promptSeen = data.socialRewardPromptSeen == true,
		favoriteConfirmed = favoriteConfirmed,
		inGroup = inGroup,
		canClaim = canClaim,
	}
end

return SocialRewardLogic
