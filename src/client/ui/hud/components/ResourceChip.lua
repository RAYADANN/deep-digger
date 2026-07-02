--!strict
-- Чип монет: масштабируется через ViewportLayout.coinChipSize().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
local ICON = theme.ICON

export type Props = {
	position: UDim2,
	amount: Fusion.Value<number>,
	size: UDim2?,
	layoutOrder: number?,
}

local ResourceChip = {}

function ResourceChip.create(s: ScopeFactory.HudScope, props: Props)
	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local chipSize = s:Computed(function(use)
		use(layoutEpoch)
		if props.size ~= nil then
			return use(props.size)
		end
		local w, h = ViewportLayout.coinChipSize()
		return UDim2.fromOffset(w, h)
	end)

	local iconId = UiAssets.coin()

	local chip = s:New("Frame")({
		Name = "CoinChip",
		Size = chipSize,
		Position = props.position,
		LayoutOrder = props.layoutOrder or 0,
		BackgroundColor3 = C.bgChip,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		[Children] = {
			s:New("UICorner")({ CornerRadius = theme.RADIUS.chip }),
			s:New("UIStroke")({ Color = C.dockBorder, Thickness = theme.STROKE.medium }),
			s:New("Frame")({
				Size = s:Computed(function(use)
					use(layoutEpoch)
					local _, h = ViewportLayout.coinChipSize()
					local barH = math.max(12, h - ViewportLayout.chromePx(10))
					return UDim2.fromOffset(ViewportLayout.chromePx(3), barH)
				end),
				Position = s:Computed(function(use)
					use(layoutEpoch)
					local _, h = ViewportLayout.coinChipSize()
					local barH = math.max(12, h - ViewportLayout.chromePx(10))
					return UDim2.new(0, ViewportLayout.chromePx(8), 0.5, -barH * 0.5)
				end),
				BackgroundColor3 = C.gold,
				BorderSizePixel = 0,
				[Children] = { s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
			}),
			s:New("ImageLabel")({
				Name = "Icon",
				Size = s:Computed(function(use)
					use(layoutEpoch)
					local sz = ViewportLayout.chromePx(28)
					return UDim2.fromOffset(sz, sz)
				end),
				Position = s:Computed(function(use)
					use(layoutEpoch)
					local sz = ViewportLayout.chromePx(28)
					return UDim2.new(0, ViewportLayout.chromePx(14), 0.5, -math.floor(sz * 0.5 + 0.5))
				end),
				BackgroundTransparency = 1,
				Image = iconId,
				ImageColor3 = ICON.tint,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}),
			s:New("TextLabel")({
				Name = "Amount",
				Size = s:Computed(function(use)
					use(layoutEpoch)
					return UDim2.new(1, -ViewportLayout.chromePx(50), 1, 0)
				end),
				Position = s:Computed(function(use)
					use(layoutEpoch)
					return UDim2.new(0, ViewportLayout.chromePx(48), 0, 0)
				end),
				BackgroundTransparency = 1,
				Text = s:Computed(function(use)
					return Formatters.shortNumber(use(props.amount))
				end),
				TextSize = s:Computed(function(use)
					use(layoutEpoch)
					return math.max(14, ViewportLayout.chromePx(20))
				end),
				Font = theme.FONT.currency,
				TextColor3 = C.gold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 2,
				[Children] = {
					s:New("UIStroke")({ Color = C.outlineDark, Thickness = 1, Transparency = 0.4 }),
				},
			}),
		},
	})

	UiMotion.defer(s, chip, function(frame)
		local icon = frame:FindFirstChild("Icon") :: ImageLabel?
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			local pulse = UiMotion.pulseStroke(stroke, 0.35, 0.65, 2.4)
			table.insert(s, pulse.cancel)
		end
		if icon then
			UiMotion.watchNumber(s, function()
				return peek(props.amount)
			end, function(_, _, delta)
				if delta > 0.5 then
					UiMotion.pop(icon, 1.2)
				end
			end)
		end
		return nil
	end)

	return chip
end

function ResourceChip.coin(
	s: ScopeFactory.HudScope,
	position: UDim2,
	amount: Fusion.Value<number>,
	size: UDim2?,
	layoutOrder: number?
)
	return ResourceChip.create(s, {
		position = position,
		amount = amount,
		size = size,
		layoutOrder = layoutOrder,
	})
end

return ResourceChip
