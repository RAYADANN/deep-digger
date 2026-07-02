--!strict
-- Левый верхний угол: монеты + глубина + статус-чипы.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory   = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme          = require(script.Parent.Parent.theme)
local ResourceChip   = require(script.Parent.Parent.components.ResourceChip)
local DepthBar       = require(script.Parent.Parent.components.DepthBar)
local StreakChip     = require(script.Parent.Parent.components.StreakChip)
local UiAssets       = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C

local CurrencyRibbon = {}

function CurrencyRibbon.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local ribbonSize = s:Computed(function(use)
		use(layoutEpoch)
		local w, _ = ViewportLayout.coinChipSize()
		return UDim2.new(0, w, 0, 0)
	end)

	local coinSize = s:Computed(function(use)
		use(layoutEpoch)
		local w, h = ViewportLayout.coinChipSize()
		return UDim2.fromOffset(w, h)
	end)

	local coinW = s:Computed(function(use)
		use(layoutEpoch)
		local w, _ = ViewportLayout.coinChipSize()
		return w
	end)

	local statusRowH = s:Computed(function(use)
		use(layoutEpoch)
		return ViewportLayout.chromePx(22)
	end)

	return s:New("Frame")({
		Name            = "CurrencyRibbon",
		Size            = ribbonSize,
		AutomaticSize   = Enum.AutomaticSize.Y,
		Position = s:Computed(function(use)
			use(layoutEpoch)
			return UDim2.new(0, ViewportLayout.sidePad(), 0, ViewportLayout.topHudY())
		end),
		BackgroundTransparency = 1,
		[Children] = {
			s:New("UIListLayout")({
				Padding             = s:Computed(function(use)
					use(layoutEpoch)
					return UDim.new(0, ViewportLayout.chromePx(4))
				end),
				SortOrder           = Enum.SortOrder.LayoutOrder,
				VerticalAlignment   = Enum.VerticalAlignment.Top,
			}),
			ResourceChip.coin(s, UDim2.new(), state.coinsDisplay, coinSize, 1),
			DepthBar.create(s, state),
			s:New("Frame")({
				Name            = "StatusRow",
				Size = s:Computed(function(use)
					local cw = use(coinW)
					local h = use(statusRowH)
					return UDim2.fromOffset(cw, h)
				end),
				BackgroundTransparency = 1,
				LayoutOrder     = 3,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection       = Enum.FillDirection.Horizontal,
						Padding             = s:Computed(function(use)
							use(layoutEpoch)
							return UDim.new(0, ViewportLayout.chromePx(3))
						end),
						VerticalAlignment   = Enum.VerticalAlignment.Center,
					}),
					s:New("Frame")({
						Name            = "RebirthChip",
						Size = s:Computed(function(use)
							local h = use(statusRowH)
							return UDim2.fromOffset(math.floor(78 * h / 22 + 0.5), h)
						end),
						BackgroundColor3 = C.bgChip,
						BackgroundTransparency = 0,
						BorderSizePixel = 0,
						Visible         = s:Computed(function(use)
							return (use(state.rebirths) or 0) > 0
						end),
						[Children] = {
							s:New("UICorner")({ CornerRadius = theme.RADIUS.chip }),
							s:New("UIStroke")({ Color = C.dockBorder, Thickness = theme.STROKE.medium }),
							s:New("ImageLabel")({
								Size = UDim2.fromScale(12 / 78, 12 / 22),
								Position = UDim2.fromScale(3 / 78, 0.5),
								AnchorPoint = Vector2.new(0, 0.5),
								BackgroundTransparency = 1,
								Image = UiAssets.tab("rebirth"),
								ScaleType = Enum.ScaleType.Fit,
							}),
							s:New("TextLabel")({
								Size = UDim2.new(1 - 18 / 78, 0, 1, 0),
								Position = UDim2.fromScale(16 / 78, 0),
								BackgroundTransparency = 1,
								Text = s:Computed(function(use)
									local r    = math.floor(use(state.rebirths) or 0)
									local mult = use(state.rebirthMultiplier) or 1
									return ("%d  ×%.1f"):format(r, mult)
								end),
								TextSize        = s:Computed(function(use)
									return math.max(8, math.floor(10 * use(statusRowH) / 22 + 0.5))
								end),
								Font            = theme.FONT.body,
								TextColor3      = C.textSub,
								TextXAlignment  = Enum.TextXAlignment.Center,
								TextYAlignment  = Enum.TextYAlignment.Center,
								TextTruncate    = Enum.TextTruncate.AtEnd,
							}),
						},
					}),
					StreakChip.create(s, state, statusRowH),
				},
			}),
		},
	})
end

return CurrencyRibbon
