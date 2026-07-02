--!strict
-- Футер EggShopModal: 4 отдельные кнопки в сетке 2×2, каждая со своей анимацией.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local UiIcon = require(script.Parent.UiIcon)
local EggMonetization = require(ReplicatedStorage:WaitForChild("shared").util.EggMonetization)
local MonetizationLogic = require(ReplicatedStorage:WaitForChild("shared").util.MonetizationLogic)
local ShopPurchase = require(script.Parent.ShopPurchase)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek

local C = theme.C

local BTN_H = 52
local GRID_GAP = 10

local BTN_BG = Color3.fromRGB(96, 72, 28)
local BTN_BG_HOVER = Color3.fromRGB(128, 96, 36)
local BTN_BG_PRESS = Color3.fromRGB(72, 54, 20)
local BTN_STROKE = Color3.fromRGB(255, 210, 72)
local BTN_STROKE_ROBUX = Color3.fromRGB(88, 220, 140)
local BTN_TEXT = Color3.fromRGB(255, 246, 220)

export type Props = {
	eggId: string,
	eggCost: number,
	hatchMax: number,
	getCoins: () -> number,
	isBusy: any,
	onCoinHatch: (count: number) -> (),
	footerH: number?,
	sidePad: number?,
	footerPad: number?,
}

local function labelStroke(s: any)
	return s:New("UIStroke")({
		Color = C.outlineDark,
		Thickness = 2,
		Transparency = 0.28,
	})
end

local EggHatchFooter = {}

function EggHatchFooter.create(s: ScopeFactory.HudScope, props: Props)
	local hoverCoin1, pressCoin1 = s:Value(false), s:Value(false)
	local hoverCoin10, pressCoin10 = s:Value(false), s:Value(false)
	local hoverRobux1, pressRobux1 = s:Value(false), s:Value(false)
	local hoverRobux10, pressRobux10 = s:Value(false), s:Value(false)

	local footerH = props.footerH or (BTN_H * 2 + GRID_GAP)
	local sidePad = props.sidePad or 16
	local footerPad = props.footerPad or 16

	-- Высота кнопок и зазор тянутся от фактической высоты футера, чтобы сетка
	-- 2×2 всегда помещалась (footerH масштабируется на телефоне).
	local designTotal = BTN_H * 2 + GRID_GAP
	local gridGap = math.max(2, math.floor(footerH * GRID_GAP / designTotal + 0.5))
	local btnH = math.max(1, math.floor((footerH - gridGap) / 2 + 0.5))

	-- Внутренняя вёрстка кнопки (заголовок + строка цены) свёрстана в дизайн-
	-- пикселях под BTN_H=52. На телефоне btnH ужимается до ~32 → без масштаба
	-- строка цены (y=28..48) вылезала ЗА пределы кнопки и окна. Тянем всё от btnH.
	local bScale = math.clamp(btnH / BTN_H, 0.5, 1.2)
	local function bs(n: number): number
		return math.max(1, math.floor(n * bScale + 0.5))
	end
	local function btext(n: number, minN: number): number
		return math.max(minN, math.floor(n * bScale + 0.5))
	end

	local function purchaseButton(
		name: string,
		layoutOrder: number,
		enabled: any,
		strokeColor: Color3,
		hovering: any,
		pressing: any,
		title: string,
		priceRow: Instance,
		onActivated: () -> ()
	)
		local strokeT = s:Computed(function(use)
			if not use(enabled) then
				return 0.55
			end
			if use(hovering) then
				return 0
			end
			return 0.1
		end)

		local face = s:New("TextButton")({
			Name = "Face",
			Size = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundTransparency = 0,
			BackgroundColor3 = s:Computed(function(use)
				if not use(enabled) then
					return C.btnDisabled
				end
				if use(pressing) then
					return BTN_BG_PRESS
				end
				if use(hovering) then
					return BTN_BG_HOVER
				end
				return BTN_BG
			end),
			BorderSizePixel = 0,
			Text = "",
			ZIndex = 4,
			[Children] = {
				s:New("UICorner")({ CornerRadius = UDim.new(0, bs(12)) }),
				s:New("UIStroke")({
					Name = "AccentStroke",
					Color = strokeColor,
					Thickness = math.max(1.5, bs(2.5)),
					Transparency = strokeT,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				s:New("UIGradient")({
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 110, 60)),
					}),
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0.72),
						NumberSequenceKeypoint.new(0.4, 0.88),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
				s:New("TextLabel")({
					Size = UDim2.new(1, -bs(12), 0, bs(18)),
					Position = UDim2.new(0, bs(6), 0, bs(5)),
					BackgroundTransparency = 1,
					Text = title,
					TextSize = btext(14, 10),
					Font = Enum.Font.GothamBlack,
					TextColor3 = s:Computed(function(use)
						return if use(enabled) then BTN_TEXT else C.textMuted
					end),
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 5,
					[Children] = { labelStroke(s) },
				}),
				priceRow,
			},
			[OnEvent("MouseEnter")] = function()
				hovering:set(true)
			end,
			[OnEvent("MouseLeave")] = function()
				hovering:set(false)
				pressing:set(false)
			end,
			[OnEvent("MouseButton1Down")] = function()
				pressing:set(true)
			end,
			[OnEvent("MouseButton1Up")] = function()
				pressing:set(false)
			end,
			[OnEvent("Activated")] = onActivated,
		})

		local slot = s:New("Frame")({
			Name = name,
			BackgroundTransparency = 1,
			LayoutOrder = layoutOrder,
			ClipsDescendants = false,
			ZIndex = 3,
			[Children] = { face },
		})

		UiMotion.defer(s, slot, function(slotFrame)
			local btn = slotFrame:FindFirstChild("Face")
			if btn and btn:IsA("TextButton") then
				UiMotion.bindHoverPress(s, btn, hovering, pressing, {
					hoverScale = 1.06,
					pressScale = 0.94,
				})
			end
			return nil
		end)

		return slot
	end

	local function coinPriceRow(cost: number, canAfford: any)
		return s:New("Frame")({
			Size = UDim2.new(1, -bs(12), 0, bs(20)),
			Position = UDim2.new(0, bs(6), 0, bs(28)),
			BackgroundTransparency = 1,
			ZIndex = 5,
			[Children] = {
				s:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, bs(4)),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				UiIcon.create(s, {
					source = "coin",
					size = UDim2.fromOffset(bs(18), bs(18)),
					visible = canAfford,
					zIndex = 5,
				}),
				s:New("TextLabel")({
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Text = Formatters.shortNumber(cost),
					TextSize = btext(15, 10),
					Font = Enum.Font.GothamBlack,
					TextColor3 = s:Computed(function(use)
						return if use(canAfford) then BTN_TEXT else C.textMuted
					end),
					ZIndex = 5,
					[Children] = { labelStroke(s) },
				}),
			},
		})
	end

	local function robuxPriceRow(price: number, enabled: any, rbxImage: string)
		return s:New("Frame")({
			Size = UDim2.new(1, -bs(12), 0, bs(20)),
			Position = UDim2.new(0, bs(6), 0, bs(28)),
			BackgroundTransparency = 1,
			ZIndex = 5,
			[Children] = {
				s:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, bs(5)),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				s:New("ImageLabel")({
					Size = UDim2.fromOffset(bs(18), bs(18)),
					BackgroundTransparency = 1,
					Image = rbxImage,
					ScaleType = Enum.ScaleType.Fit,
					Visible = enabled,
					ZIndex = 5,
				}),
				s:New("TextLabel")({
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					Text = tostring(price),
					TextSize = btext(15, 10),
					Font = Enum.Font.GothamBlack,
					TextColor3 = s:Computed(function(use)
						return if use(enabled) then BTN_TEXT else C.textMuted
					end),
					ZIndex = 5,
					[Children] = { labelStroke(s) },
				}),
			},
		})
	end

	local function coinSlot(count: number, layoutOrder: number, hovering: any, pressing: any)
		local cost = props.eggCost * count
		local canAfford = s:Computed(function(use)
			return props.getCoins() >= cost and not use(props.isBusy)
		end)
		local title = if count == 1 then "Открыть 1×" else ("Открыть " .. count .. "×")
		return purchaseButton(
			"CoinSlot_" .. count,
			layoutOrder,
			canAfford,
			BTN_STROKE,
			hovering,
			pressing,
			title,
			coinPriceRow(cost, canAfford),
			function()
				if peek(canAfford) then
					props.onCoinHatch(count)
				end
			end
		)
	end

	local function robuxSlot(count: number, layoutOrder: number, hovering: any, pressing: any)
		local price = EggMonetization.robuxPrice(props.eggId, count)
		local productKey = EggMonetization.productKey(props.eggId, count)
		local product = MonetizationLogic.productByKey(productKey)
		local enabled = s:Computed(function(use)
			return not use(props.isBusy) and price > 0 and product ~= nil
		end)
		local title = if count == 1 then "1× за Robux" else (count .. "× за Robux")
		return purchaseButton(
			"RobuxSlot_" .. count,
			layoutOrder,
			enabled,
			BTN_STROKE_ROBUX,
			hovering,
			pressing,
			title,
			robuxPriceRow(price, enabled, UiAssets.robux()),
			function()
				if not peek(enabled) or not product then
					return
				end
				ShopPurchase.prompt({
					id = product.id,
					name = product.name,
					kind = "product",
				})
			end
		)
	end

	return s:New("Frame")({
		Name = "Footer",
		Size = UDim2.new(1, -sidePad * 2, 0, footerH),
		Position = UDim2.new(0, sidePad, 1, -(footerH + footerPad)),
		BackgroundTransparency = 1,
		ZIndex = 3,
		[Children] = {
			s:New("UIGridLayout")({
				-- ВАЖНО: ширина ячейки 0.5W - gridGap (не -gridGap/2). При -gridGap/2
				-- сумма двух ячеек + зазор == ширине футера ровно, и из-за округления
				-- грид переносил вторую кнопку на новую строку → 4 кнопки в столбик
				-- вылезали за модал. Небольшой запас гарантирует сетку 2×2.
				CellSize = UDim2.new(0.5, -gridGap, 0, btnH),
				CellPadding = UDim2.new(0, gridGap, 0, gridGap),
				FillDirectionMaxCells = 2,
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			coinSlot(1, 1, hoverCoin1, pressCoin1),
			coinSlot(props.hatchMax, 2, hoverCoin10, pressCoin10),
			robuxSlot(1, 3, hoverRobux1, pressRobux1),
			robuxSlot(props.hatchMax, 4, hoverRobux10, pressRobux10),
		},
	})
end

return EggHatchFooter
