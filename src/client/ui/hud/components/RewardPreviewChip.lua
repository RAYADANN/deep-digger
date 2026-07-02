--!strict
-- Компактный чип награды для модалок (монеты / кристаллы / буст).
-- Размеры в дизайн-пикселях: родительский модал масштабирует через UIScale.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local PanelScale = require(script.Parent.Parent.PanelScale)
local UiIcon = require(script.Parent.UiIcon)

local Children = Fusion.Children
local C = theme.C

export type Props = {
	label: string,
	iconKey: string,
	accent: Color3,
	layoutOrder: number?,
	fitScale: any?,
}

local RewardPreviewChip = {}

function RewardPreviewChip.create(s: ScopeFactory.HudScope, props: Props)
	local fitScale = props.fitScale

	return s:New("Frame")({
		Name = "RewardChip",
		LayoutOrder = props.layoutOrder or 0,
		Size = if fitScale
			then UDim2.fromOffset(
				s:Computed(function(use)
					return PanelScale.modalGsc(108, use(fitScale))
				end),
				s:Computed(function(use)
					return PanelScale.modalGsc(34, use(fitScale))
				end)
			)
			else UDim2.fromOffset(108, 34),
		BackgroundColor3 = C.panelInner,
		BorderSizePixel = 0,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			s:New("UIStroke")({ Color = props.accent, Thickness = 1, Transparency = 0.55 }),
			s:New("Frame")({
				Size = UDim2.new(0, 3, 1, -8),
				Position = UDim2.new(0, 6, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = props.accent,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				},
			}),
			UiIcon.create(s, {
				source = props.iconKey,
				size = if fitScale
					then UDim2.fromOffset(
						s:Computed(function(use)
							return PanelScale.modalGsc(20, use(fitScale))
						end),
						s:Computed(function(use)
							return PanelScale.modalGsc(20, use(fitScale))
						end)
					)
					else UDim2.fromOffset(20, 20),
				position = UDim2.new(0, 14, 0.5, 0),
				anchorPoint = Vector2.new(0, 0.5),
				zIndex = 3,
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, -40, 1, 0),
				Position = UDim2.new(0, 38, 0, 0),
				BackgroundTransparency = 1,
				Text = props.label,
				TextSize = if fitScale
					then s:Computed(function(use)
						return PanelScale.modalText(12, use(fitScale))
					end)
					else 12,
				Font = theme.FONT.body,
				TextColor3 = C.textMain,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 3,
			}),
		},
	})
end

return RewardPreviewChip
