--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local PanelScale = require(script.Parent.Parent.PanelScale)

local Children = Fusion.Children
local C = theme.C
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text

export type Props = {
	kind: any,
	valueText: string,
	width: number?,
	height: number?,
	layoutOrder: number?,
}

local BuffEffectChip = {}

function BuffEffectChip.create(s: ScopeFactory.HudScope, props: Props)
	local BuffMeta = require(ReplicatedStorage:WaitForChild("shared").data.BuffMeta)
	local BuffIcon = require(script.Parent.BuffIcon)
	local w = sc(props.width or 88)
	local h = sc(props.height or 28)
	local accent = BuffMeta.ACCENT[props.kind]

	return s:New("Frame")({
		Name = "BuffChip_" .. props.kind,
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = C.bgChip,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder or 0,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
			s:New("UIStroke")({
				Color = accent,
				Thickness = sc(1.5),
				Transparency = 0.4,
			}),
			s:New("Frame")({
				Size = UDim2.fromOffset(sc(3), h - sc(10)),
				Position = UDim2.new(0, 0, 0.5, -((h - sc(10)) // 2)),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = { s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
			}),
			BuffIcon.create(s, {
				kind = props.kind,
				size = UDim2.fromOffset(sc(22), sc(22)),
				position = UDim2.new(0, sc(6), 0.5, -sc(11)),
				zIndex = 3,
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, -sc(32), 1, 0),
				Position = UDim2.new(0, sc(30), 0, 0),
				BackgroundTransparency = 1,
				Text = props.valueText,
				TextSize = text(12),
				Font = theme.FONT.title,
				TextColor3 = C.textMain,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
			}),
		},
	})
end

return BuffEffectChip
