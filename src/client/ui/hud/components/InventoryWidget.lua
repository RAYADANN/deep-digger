--!strict
-- Чип заполненности рюкзака (правый верх). Заливка фона = % заполнения.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local UpgradeLogic = require(ReplicatedStorage:WaitForChild("shared").util.UpgradeLogic)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
local ICON = theme.ICON

local InventoryWidget = {}

local function resolveMaxSlots(upgrades: any, rebirths: number): number
	if typeof(upgrades) ~= "table" then
		return UpgradeLogic.inventoryCapacity(1, rebirths)
	end
	local invUpg = upgrades["inventory"]
	local level = if invUpg and typeof(invUpg.level) == "number" then invUpg.level else 1
	return UpgradeLogic.inventoryCapacity(math.max(1, level), rebirths)
end

function InventoryWidget.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local chipSize = s:Computed(function(use)
		use(layoutEpoch)
		local w, h = ViewportLayout.inventoryChipSize()
		return UDim2.fromOffset(w, h)
	end)

	local chipW = s:Computed(function(use)
		use(layoutEpoch)
		local w, _ = ViewportLayout.inventoryChipSize()
		return w
	end)

	local maxSlots = s:Computed(function(use)
		return resolveMaxSlots(use(state.upgrades), use(state.rebirths) or 0)
	end)

	local usedSlots = state.inventoryUsed

	local ratio = s:Computed(function(use)
		local m = use(maxSlots)
		if m <= 0 then
			return 0
		end
		return math.clamp(use(usedSlots) / m, 0, 1)
	end)

	local isFull = s:Computed(function(use)
		return use(usedSlots) >= use(maxSlots)
	end)

	local accentColor = s:Computed(function(use)
		local r = use(ratio)
		if r >= 1 then
			return C.mythic
		end
		if r >= 0.9 then
			return C.mythic
		end
		if r >= 0.7 then
			return C.legendary
		end
		return C.sell
	end)

	local fillTransparency = s:Computed(function(use)
		local r = use(ratio)
		if use(isFull) then
			return 0.28
		end
		return 0.55 + (1 - r) * 0.25
	end)

	local countText = s:Computed(function(use)
		if use(isFull) then
			return "ПОЛНЫЙ"
		end
		return ("%d/%d"):format(use(usedSlots), use(maxSlots))
	end)

	local countColor = s:Computed(function(use)
		return if use(isFull) then C.white else C.textMain
	end)

	local metrics = s:Computed(function(use)
		use(layoutEpoch)
		local _, chipH = ViewportLayout.inventoryChipSize()
		local padX = ViewportLayout.chromePx(8)
		local iconSz = ViewportLayout.chromePx(24)
		local textLeft = ViewportLayout.chromePx(40)
		local textRight = ViewportLayout.chromePx(8)
		-- ВАЖНО: max должен быть >= min, иначе math.clamp бросает ошибку и
		-- TextSize-computed падает → счётчик инвентаря рисуется без текста.
		local textMax = math.max(12, ViewportLayout.chromePx(17))
		local textSize = math.clamp(math.floor(chipH * 0.42 + 0.5), 12, textMax)
		local cornerPx = math.max(6, ViewportLayout.chromePx(12))
		return {
			padX = padX,
			iconSz = iconSz,
			textLeft = textLeft,
			textRight = textRight,
			textSize = textSize,
			cornerPx = cornerPx,
		}
	end)

	return s:New("Frame")({
		Name = "InventoryWidget",
		Size = chipSize,
		Position = s:Computed(function(use)
			use(layoutEpoch)
			local w = use(chipW)
			return UDim2.new(1, -(w + ViewportLayout.sidePad()), 0, ViewportLayout.topHudY())
		end),
		BackgroundColor3 = C.bgChip,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 7,
		[Children] = {
			s:New("UICorner")({
				CornerRadius = s:Computed(function(use)
					return UDim.new(0, use(metrics).cornerPx)
				end),
			}),
			s:New("UIStroke")({
				Color = s:Computed(function(use)
					return if use(isFull) then C.mythic else C.dockBorder
				end),
				Thickness = theme.STROKE.medium,
			}),
			s:New("Frame")({
				Name = "CapacityFill",
				Size = s:Computed(function(use)
					return UDim2.new(use(ratio), 0, 1, 0)
				end),
				BackgroundColor3 = accentColor,
				BackgroundTransparency = fillTransparency,
				BorderSizePixel = 0,
				ZIndex = 1,
				[Children] = {
					s:New("UICorner")({
						CornerRadius = s:Computed(function(use)
							return UDim.new(0, use(metrics).cornerPx)
						end),
					}),
				},
			}),
			s:New("ImageLabel")({
				Name = "Icon",
				Size = s:Computed(function(use)
					local m = use(metrics)
					return UDim2.fromOffset(m.iconSz, m.iconSz)
				end),
				Position = s:Computed(function(use)
					local m = use(metrics)
					return UDim2.new(0, m.padX, 0.5, -math.floor(m.iconSz * 0.5 + 0.5))
				end),
				BackgroundTransparency = 1,
				Image = UiAssets.image("tab_inventory"),
				ImageColor3 = ICON.tint,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 3,
			}),
			s:New("TextLabel")({
				Name = "Count",
				Size = s:Computed(function(use)
					local m = use(metrics)
					return UDim2.new(1, -(m.textLeft + m.textRight), 1, 0)
				end),
				Position = s:Computed(function(use)
					return UDim2.new(0, use(metrics).textLeft, 0, 0)
				end),
				BackgroundTransparency = 1,
				Text = countText,
				TextSize = s:Computed(function(use)
					return use(metrics).textSize
				end),
				Font = theme.FONT.body,
				TextColor3 = countColor,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 3,
				[Children] = {
					s:New("UIStroke")({
						Color = C.outlineDark,
						Thickness = 1,
						Transparency = s:Computed(function(use)
							return if use(isFull) then 0.35 else 0.55
						end),
					}),
				},
			}),
		},
	})
end

return InventoryWidget
