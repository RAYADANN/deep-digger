--!strict
-- Стандартная карточка товара: gamepass, монеты, яйца.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local UiInteract = require(script.Parent.Parent.Parent.util.UiInteract)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)
local RobuxPrice = require(script.Parent.RobuxPrice)
local ShopPurchase = require(script.Parent.ShopPurchase)
local PanelScale = require(script.Parent.Parent.PanelScale)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local C = theme.C
local ACCENTS = theme.TAB_ACCENTS
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text

export type ShopItemDef = {
	key: string,
	id: number,
	name: string,
	icon: string,
	priceRobux: number,
	wasPriceRobux: number?,
	badge: string?,
	desc: string,
	kind: "gamepass" | "product",
}

export type Props = {
	item: ShopItemDef,
	owned: boolean,
	layoutOrder: number,
}

local CARD_H_DESIGN = 94
local RIGHT_W_DESIGN = 116

local ShopCard = {}

function ShopCard.create(s: ScopeFactory.HudScope, props: Props)
	-- Считаем масштаб на лету (sc), а не на require — иначе размер замораживается.
	local CARD_H = sc(CARD_H_DESIGN)
	local RIGHT_W = sc(RIGHT_W_DESIGN)
	local item = props.item
	local hovered = s:Value(false)
	local hasRealId = item.id ~= 0
	local canBuy = not props.owned and hasRealId
	local accent = if item.kind == "gamepass" then ACCENTS.shop else C.gold
	local accentHi = if item.kind == "gamepass"
		then Color3.fromRGB(255, 175, 215)
		else C.goldHi
	local cardH = if item.wasPriceRobux then sc(108) else CARD_H

	local function onPurchase()
		if props.owned or not canBuy then
			return
		end
		ShopPurchase.prompt(item)
	end

	local card = s:New("Frame")({
		Name = "ShopCard_" .. item.key,
		Size = UDim2.new(1, -sc(8), 0, cardH),
		BackgroundColor3 = s:Computed(function(use)
			return if use(hovered) then C.bg4 else C.btnBg
		end),
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(10)) }),
			s:New("UIStroke")({
				Color = s:Computed(function(use)
					if props.owned then
						return C.uncommon
					end
					return if use(hovered) then accentHi else accent
				end),
				Thickness = if props.owned then sc(1.5) else sc(2),
				Transparency = s:Computed(function(use)
					if props.owned then
						return 0.45
					end
					return if use(hovered) then 0.1 else 0.35
				end),
			}),
			s:New("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, accent),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.94),
					NumberSequenceKeypoint.new(1, 0.88),
				}),
				Rotation = 135,
			}),
			if item.badge and not props.owned
				then s:New("Frame")({
					Name = "Badge",
					Size = UDim2.fromOffset(sc(88), sc(20)),
					Position = UDim2.new(0, sc(10), 0, sc(8)),
					BackgroundColor3 = Color3.fromRGB(255, 90, 110),
					BorderSizePixel = 0,
					ZIndex = 4,
					[Children] = {
						s:New("UICorner")({ CornerRadius = UDim.new(0, sc(5)) }),
						s:New("TextLabel")({
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = item.badge,
							TextSize = text(11),
							Font = Enum.Font.GothamBlack,
							TextColor3 = C.white,
							TextXAlignment = Enum.TextXAlignment.Center,
						}),
					},
				})
				else nil,
			s:New("Frame")({
				Name = "AccentBar",
				Size = UDim2.new(0, sc(4), 1, -sc(14)),
				Position = UDim2.new(0, sc(8), 0, sc(7)),
				BackgroundColor3 = if props.owned then C.uncommon else accent,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				},
			}),
			s:New("Frame")({
				Name = "IconCircle",
				Size = UDim2.fromOffset(sc(52), sc(52)),
				Position = UDim2.new(0, sc(20), 0.5, -sc(26)),
				BackgroundColor3 = accent,
				BackgroundTransparency = 0.82,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					s:New("UIStroke")({
						Color = accentHi,
						Thickness = sc(1.5),
						Transparency = 0.35,
					}),
					s:New("ImageLabel")({
						Size = UDim2.fromOffset(sc(42), sc(42)),
						Position = UDim2.new(0.5, -sc(21), 0.5, -sc(21)),
						BackgroundTransparency = 1,
						Image = UiAssets.resolve(item.icon),
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = 3,
					}),
				},
			}),
			s:New("Frame")({
				Name = "Body",
				Size = UDim2.new(1, -(sc(82) + RIGHT_W + sc(16)), 1, -sc(16)),
				Position = UDim2.new(0, sc(82), 0, sc(8)),
				BackgroundTransparency = 1,
				ZIndex = 2,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = PanelScale.pad(4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					s:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, sc(18)),
						BackgroundTransparency = 1,
						Text = item.name,
						TextSize = text(15),
						Font = Enum.Font.GothamBlack,
						TextColor3 = C.textMain,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),
					s:New("TextLabel")({
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						Text = item.desc,
						TextSize = text(13),
						Font = Enum.Font.Gotham,
						TextColor3 = C.textLabel,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextWrapped = true,
					}),
				},
			}),
			s:New("Frame")({
				Name = "RightCol",
				Size = UDim2.fromOffset(RIGHT_W, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.new(1, -sc(10), 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				ZIndex = 3,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = PanelScale.pad(6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					if props.owned
						then s:New("Frame")({
							Name = "OwnedChip",
							LayoutOrder = 1,
							Size = UDim2.fromOffset(RIGHT_W, sc(34)),
							BackgroundColor3 = Color3.fromRGB(18, 48, 32),
							BackgroundTransparency = 0.15,
							BorderSizePixel = 0,
							[Children] = {
								s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
								s:New("UIStroke")({ Color = C.uncommon, Thickness = sc(1.5), Transparency = 0.35 }),
								s:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Horizontal,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									Padding = PanelScale.pad(4),
								}),
								s:New("ImageLabel")({
									LayoutOrder = 1,
									Size = UDim2.fromOffset(sc(14), sc(14)),
									BackgroundTransparency = 1,
									Image = UiAssets.image("icon_check"),
									ScaleType = Enum.ScaleType.Fit,
								}),
								s:New("TextLabel")({
									LayoutOrder = 2,
									AutomaticSize = Enum.AutomaticSize.XY,
									BackgroundTransparency = 1,
									Text = "КУПЛЕНО",
									TextSize = text(12),
									Font = Enum.Font.GothamBlack,
									TextColor3 = C.uncommon,
								}),
							},
						})
						else s:New("Frame")({
							Name = "PriceChip",
							LayoutOrder = 1,
							AutomaticSize = Enum.AutomaticSize.XY,
							BackgroundColor3 = C.goldBg,
							BackgroundTransparency = 0.1,
							BorderSizePixel = 0,
							[Children] = {
								s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
								s:New("UIStroke")({ Color = C.gold, Thickness = sc(1.5), Transparency = 0.4 }),
								s:New("UIPadding")({
									PaddingTop = PanelScale.pad(4),
									PaddingBottom = PanelScale.pad(4),
									PaddingLeft = PanelScale.pad(8),
									PaddingRight = PanelScale.pad(8),
								}),
								RobuxPrice.create(s, {
									price = item.priceRobux,
									wasPrice = item.wasPriceRobux,
									textSize = PanelScale.priceText(13),
									iconSize = PanelScale.tsize(18),
									strokeColor = C.outlineDark,
									stacked = item.wasPriceRobux ~= nil,
									horizontalAlignment = Enum.HorizontalAlignment.Center,
								}),
							},
						}),
					if not props.owned
						then s:New("TextButton")({
							Name = "BuyButton",
							LayoutOrder = 2,
							Size = UDim2.fromOffset(RIGHT_W, sc(34)),
							AutoButtonColor = false,
							BackgroundColor3 = s:Computed(function(use)
								if not hasRealId then
									return C.btnDisabled
								end
								return if use(hovered) then accentHi else accent
							end),
							BorderSizePixel = 0,
							Text = if hasRealId then "КУПИТЬ" else "СКОРО",
							TextSize = text(13),
							Font = Enum.Font.GothamBlack,
							TextColor3 = s:Computed(function()
								return if canBuy then C.white else C.textMuted
							end),
							TextXAlignment = Enum.TextXAlignment.Center,
							Active = canBuy,
							ZIndex = 4,
							[Children] = {
								s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
								s:New("UIStroke")({
									Color = C.white,
									Thickness = sc(1.5),
									Transparency = if canBuy then 0.55 else 0.8,
								}),
							},
							[OnEvent("MouseEnter")] = function()
								if canBuy then
									hovered:set(true)
								end
							end,
							[OnEvent("MouseLeave")] = function()
								hovered:set(false)
							end,
							[OnEvent("Activated")] = onPurchase,
						})
						else nil,
				},
			}),
			s:New("TextButton")({
				Name = "HoverCatcher",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 1,
				[OnEvent("MouseEnter")] = function()
					hovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					hovered:set(false)
				end,
			}),
		},
	})

	UiMotion.defer(s, card, function(frame)
		local rightCol = frame:FindFirstChild("RightCol")
		local buy = if rightCol then rightCol:FindFirstChild("BuyButton") :: TextButton? else nil
		if buy and canBuy then
			UiInteract.attachScoped(s, buy, { hoverScale = 1.05, pressScale = 0.94 })
		end
		return nil
	end)

	return card
end

return ShopCard
