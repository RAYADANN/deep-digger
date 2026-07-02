--!strict
-- Иконка бафа через UiAssets (rbxassetid, стиль HUD).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local BuffMeta     = require(ReplicatedStorage:WaitForChild("shared").data.BuffMeta)
local UiAssets     = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local Children = Fusion.Children
local ICON = theme.ICON

export type Props = {
	kind: BuffMeta.BuffKind,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
}

local BuffIcon = {}

function BuffIcon.create(s: ScopeFactory.HudScope, props: Props)
	local iconKey = BuffMeta.ICON[props.kind]
	local rbxImage = UiAssets.image(iconKey :: any)

	return s:New("Frame")({
		Name                   = "BuffIcon",
		Size                   = props.size or UDim2.fromOffset(30, 30),
		Position               = props.position,
		AnchorPoint            = props.anchorPoint,
		BackgroundTransparency = 1,
		ZIndex                 = props.zIndex or 3,
		[Children] = {
			s:New("ImageLabel")({
				Name                   = "Icon",
				Size                   = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image                  = rbxImage,
				ImageColor3            = ICON.tint,
				ScaleType              = Enum.ScaleType.Fit,
				ZIndex                 = 1,
			}),
		},
	})
end

return BuffIcon
