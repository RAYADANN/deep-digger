--!strict
-- Кнопка промокодов под счётчиком инвентаря (правый верх).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local ChromeIconButton = require(script.Parent.ChromeIconButton)
local PromoCodeModal = require(script.Parent.Parent.Parent.PromoCodeModal)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local peek = Fusion.peek

local ACCENT = theme.TAB_ACCENTS.goals

export type CreateOpts = {
	layoutOrder: number?,
}

local PromoCodeButton = {}

function PromoCodeButton.create(
	s: ScopeFactory.HudScope,
	_state: HudStateModule.HudState,
	opts: CreateOpts?
)
	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local size = s:Computed(function(use)
		use(layoutEpoch)
		local btnSz = ViewportLayout.chromePx(40)
		return UDim2.fromOffset(btnSz, btnSz)
	end)

	local function openModal()
		PromoCodeModal.show({ scope = s })
	end

	return ChromeIconButton.create(s, {
		name = "PromoCodeButton",
		iconKey = "icon_promo_code",
		accent = ACCENT,
		size = size,
		layoutOrder = opts and opts.layoutOrder,
		visible = s:Value(true),
		onActivated = openModal,
		zIndex = 8,
	})
end

return PromoCodeButton
