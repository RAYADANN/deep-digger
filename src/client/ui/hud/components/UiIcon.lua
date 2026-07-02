--!strict
-- Универсальная HUD-иконка: emoji, iconKey или rbxassetid → ImageLabel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local Children = Fusion.Children
local ICON = theme.ICON

export type Props = {
	source: string?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
	imageTransparency: any?,
	visible: any?,
	name: string?,
}

local UiIcon = {}

function UiIcon.image(source: string?): string
	return UiAssets.resolve(source)
end

function UiIcon.create(s: ScopeFactory.HudScope, props: Props)
	local rbxImage = UiAssets.resolve(props.source)

	return s:New("ImageLabel")({
		Name = props.name or "UiIcon",
		Size = props.size or UDim2.fromOffset(24, 24),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		Image = rbxImage,
		ImageColor3 = ICON.tint,
		ImageTransparency = props.imageTransparency,
		ScaleType = Enum.ScaleType.Fit,
		Visible = if props.visible ~= nil then props.visible elseif rbxImage ~= "" then true else false,
		ZIndex = props.zIndex or 2,
	})
end

-- Заголовок: иконка слева + текст справа (для панелей и модалок).
export type TitleProps = {
	source: string?,
	text: string | any,
	textSize: number?,
	font: Enum.Font?,
	textColor: Color3 | any?,
	size: UDim2?,
	position: UDim2?,
	iconSize: number?,
	gap: number?,
	zIndex: number?,
	layoutOrder: number?,
}

function UiIcon.titleRow(s: ScopeFactory.HudScope, props: TitleProps)
	local iconPx = props.iconSize or 22
	local gap = props.gap or 6
	local z = props.zIndex or 3

	return s:New("Frame")({
		Name = "TitleRow",
		Size = props.size or UDim2.new(1, 0, 0, 28),
		Position = props.position,
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		ZIndex = z,
		[Children] = {
			UiIcon.create(s, {
				source = props.source,
				size = UDim2.fromOffset(iconPx, iconPx),
				position = UDim2.new(0, 0, 0.5, -iconPx / 2),
				zIndex = z + 1,
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, -(iconPx + gap), 1, 0),
				Position = UDim2.new(0, iconPx + gap, 0, 0),
				BackgroundTransparency = 1,
				Text = props.text,
				TextSize = props.textSize or 18,
				Font = props.font or Enum.Font.GothamBlack,
				TextColor3 = props.textColor,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = z + 1,
			}),
		},
	})
end

return UiIcon
