--!strict
-- Чип глубины: иконка, текст, прогресс-бар.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local HudStateModule = require(script.Parent.Parent.HudState)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
local ICON = theme.ICON

local DepthBar = {}

function DepthBar.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local fillRatio = s:Computed(function(use)
		local depth = use(state.depth)
		for _, layer in ipairs(Constants.LAYERS) do
			if layer.id == use(state.layerId) then
				local range = layer.depthEnd - layer.depthStart
				if range <= 0 or layer.depthEnd == math.huge then
					return 0.5
				end
				return math.clamp((depth - layer.depthStart) / range, 0, 1)
			end
		end
		return 0
	end)

	local layerColor = s:Computed(function(use)
		return theme.LAYER_COLORS[use(state.layerId)] or C.depthFill
	end)

	local bar = s:New("Frame")({
		Name = "DepthBar",
		Size = s:Computed(function(use)
			use(layoutEpoch)
			local w, h = ViewportLayout.coinChipSize()
			return UDim2.fromOffset(w, h)
		end),
		BackgroundColor3 = C.bgChip,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		LayoutOrder = 2,
		[Children] = {
			s:New("UICorner")({ CornerRadius = theme.RADIUS.chip }),
			s:New("UIStroke")({ Color = C.dockBorder, Thickness = theme.STROKE.medium }),
			s:New("ImageLabel")({
				Name = "DepthIcon",
				Size = s:Computed(function(use)
					use(layoutEpoch)
					local sz = ViewportLayout.chromePx(20)
					return UDim2.fromOffset(sz, sz)
				end),
				Position = s:Computed(function(use)
					use(layoutEpoch)
					return UDim2.new(0, ViewportLayout.chromePx(8), 0, ViewportLayout.chromePx(4))
				end),
				BackgroundTransparency = 1,
				Image = UiAssets.image("depth"),
				ImageColor3 = ICON.tint,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}),
			s:New("TextLabel")({
				Size = s:Computed(function(use)
					use(layoutEpoch)
					return UDim2.new(1, -ViewportLayout.chromePx(38), 0, ViewportLayout.chromePx(16))
				end),
				Position = s:Computed(function(use)
					use(layoutEpoch)
					return UDim2.new(0, ViewportLayout.chromePx(32), 0, ViewportLayout.chromePx(3))
				end),
				BackgroundTransparency = 1,
				Text = s:Computed(function(use)
					return math.floor(use(state.depth)) .. "м · " .. use(state.layerName)
				end),
				TextSize = s:Computed(function(use)
					use(layoutEpoch)
					return math.max(10, ViewportLayout.chromePx(11))
				end),
				Font = theme.FONT.body,
				TextColor3 = C.textSub,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 2,
			}),
			s:New("Frame")({
				Name = "ProgressBg",
				Size = s:Computed(function(use)
					use(layoutEpoch)
					return UDim2.new(1, -ViewportLayout.chromePx(40), 0, ViewportLayout.chromePx(5))
				end),
				Position = s:Computed(function(use)
					use(layoutEpoch)
					local _, h = ViewportLayout.coinChipSize()
					return UDim2.new(0, ViewportLayout.chromePx(32), 0, h - ViewportLayout.chromePx(8))
				end),
				BackgroundColor3 = C.depthBg,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					s:New("Frame")({
						Name = "Fill",
						Size = UDim2.new(peek(fillRatio), 0, 1, 0),
						BackgroundColor3 = layerColor,
						BorderSizePixel = 0,
						[Children] = { s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
					}),
				},
			}),
		},
	})

	UiMotion.defer(s, bar, function(frame)
		local progressBg = frame:FindFirstChild("ProgressBg") :: Frame?
		local fill = if progressBg then progressBg:FindFirstChild("Fill") :: Frame? else nil
		local icon = frame:FindFirstChild("DepthIcon") :: ImageLabel?
		if fill then
			UiMotion.watch(s, function()
				return peek(fillRatio)
			end, function(ratio)
				UiMotion.play(fill, { Size = UDim2.new(ratio, 0, 1, 0) }, UiMotion.SLIDE)
			end)
		end
		if icon then
			UiMotion.watchNumber(s, function()
				return peek(state.depth)
			end, function(_, _, delta)
				if delta > 0.5 then
					UiMotion.pop(icon, 1.15)
				end
			end)
		end
		return nil
	end)

	return bar
end

return DepthBar
