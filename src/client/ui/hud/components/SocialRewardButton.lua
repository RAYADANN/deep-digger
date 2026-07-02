--!strict
-- Кнопка бесплатной соц-награды (правый верх, под инвентарём).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local ChromeIconButton = require(script.Parent.ChromeIconButton)
local SocialRewardModal = require(script.Parent.Parent.Parent.SocialRewardModal)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local peek = Fusion.peek

local ACCENT = theme.TAB_ACCENTS.shop

export type CreateOpts = {
	layoutOrder: number?,
}

local SocialRewardButton = {}

function SocialRewardButton.create(
	s: ScopeFactory.HudScope,
	state: HudStateModule.HudState,
	opts: CreateOpts?
)
	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local visible = s:Computed(function(use)
		local social = use(state.socialReward) or {}
		return social.claimed ~= true
	end)

	local showPulse = s:Computed(function(use)
		local social = use(state.socialReward) or {}
		if social.claimed == true then
			return false
		end
		return social.canClaim == true
			or social.inGroup ~= true
			or social.favoriteConfirmed ~= true
	end)

	local showBadge = showPulse

	local size = s:Computed(function(use)
		use(layoutEpoch)
		local btnSz = ViewportLayout.chromePx(40)
		return UDim2.fromOffset(btnSz, btnSz)
	end)

	local function openModal()
		SocialRewardModal.show({ scope = s, state = state })
	end

	return ChromeIconButton.create(s, {
		name = "SocialRewardButton",
		iconKey = "icon_social_reward",
		accent = ACCENT,
		size = size,
		layoutOrder = opts and opts.layoutOrder,
		visible = visible,
		showPulse = showPulse,
		showBadge = showBadge,
		tooltip = "Бесплатная награда",
		onActivated = openModal,
		zIndex = 8,
	})
end

return SocialRewardButton
