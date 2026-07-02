--!strict

-- Hero-карточка набора: лента скидки, перки, зачёркнутая цена, иконка Robux.



local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)



local ScopeFactory = require(script.Parent.Parent.ScopeFactory)

local theme = require(script.Parent.Parent.theme)

local PanelScale = require(script.Parent.Parent.PanelScale)

local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local UiInteract = require(script.Parent.Parent.Parent.util.UiInteract)

local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)

local RobuxPrice = require(script.Parent.RobuxPrice)

local ShopPurchase = require(script.Parent.ShopPurchase)



local OnEvent = Fusion.OnEvent

local Children = Fusion.Children

local C = theme.C

-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text
local tsize = PanelScale.tsize



export type FeaturedItem = {

	key: string,

	id: number,

	name: string,

	icon: string,

	priceRobux: number,

	wasPriceRobux: number?,

	desc: string,

	badge: string?,

	perks: { string }?,

	kind: "product",

}



export type Props = {

	item: FeaturedItem,

	owned: boolean,

	accent: Color3,

	accentHi: Color3,

	layoutOrder: number,

}



local CARD_H_DESIGN = 162

local ART_SIZE_DESIGN = 104

local ART_IMG_DESIGN = 92

local RIGHT_W_DESIGN = 136



local ShopFeaturedCard = {}



function ShopFeaturedCard.create(s: ScopeFactory.HudScope, props: Props)

	-- Масштаб на лету (sc), а не на require — иначе размер замораживается.

	local CARD_H = sc(CARD_H_DESIGN)

	local ART_SIZE = sc(ART_SIZE_DESIGN)

	local ART_IMG = sc(ART_IMG_DESIGN)

	local RIGHT_W = sc(RIGHT_W_DESIGN)

	local item = props.item

	local hovered = s:Value(false)

	local canBuy = not props.owned and item.id ~= 0

	local perks = item.perks or {}



	local function onPurchase()

		if not canBuy then

			return

		end

		ShopPurchase.prompt(item)

	end



	local card = s:New("Frame")({

		Name = "Featured_" .. item.key,

		Size = UDim2.new(1, -sc(8), 0, CARD_H),

		BackgroundColor3 = s:Computed(function(use)

			return if use(hovered) then C.bg4 else C.btnBg

		end),

		BorderSizePixel = 0,

		LayoutOrder = props.layoutOrder,

		[Children] = {

			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(12)) }),

			s:New("UIStroke")({

				Color = s:Computed(function(use)

					if props.owned then

						return C.uncommon

					end

					return if use(hovered) then props.accentHi else props.accent

				end),

				Thickness = sc(2),

				Transparency = s:Computed(function(use)

					return if use(hovered) then 0.08 else 0.28

				end),

			}),

			s:New("UIGradient")({

				Color = ColorSequence.new({

					ColorSequenceKeypoint.new(0, props.accent),

					ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 30, 48)),

				}),

				Transparency = NumberSequence.new({

					NumberSequenceKeypoint.new(0, 0.72),

					NumberSequenceKeypoint.new(1, 0.9),

				}),

				Rotation = 125,

			}),

			if item.badge and not props.owned

				then s:New("Frame")({

					Name = "Badge",

					Size = UDim2.fromOffset(sc(72), sc(22)),

					Position = UDim2.new(0, sc(10), 0, sc(8)),

					BackgroundColor3 = Color3.fromRGB(255, 70, 90),

					BorderSizePixel = 0,

					ZIndex = 4,

					[Children] = {

						s:New("UICorner")({ CornerRadius = UDim.new(0, sc(6)) }),

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

				Name = "PackArt",

				Size = UDim2.fromOffset(ART_SIZE, ART_SIZE),

				Position = UDim2.new(0, sc(10), 0.5, -ART_SIZE / 2),

				BackgroundColor3 = props.accent,

				BackgroundTransparency = 0.55,

				BorderSizePixel = 0,

				ZIndex = 2,

				[Children] = {

					s:New("UICorner")({ CornerRadius = UDim.new(0, sc(14)) }),

					s:New("UIStroke")({

						Color = props.accentHi,

						Thickness = sc(2),

						Transparency = 0.2,

					}),

					s:New("UIGradient")({

						Color = ColorSequence.new({

							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),

							ColorSequenceKeypoint.new(1, props.accent),

						}),

						Transparency = NumberSequence.new({

							NumberSequenceKeypoint.new(0, 0.82),

							NumberSequenceKeypoint.new(1, 0.92),

						}),

						Rotation = 120,

					}),

					s:New("ImageLabel")({

						Size = UDim2.fromOffset(ART_IMG, ART_IMG),

						Position = UDim2.new(0.5, -ART_IMG / 2, 0.5, -ART_IMG / 2),

						BackgroundTransparency = 1,

						Image = UiAssets.resolve(item.icon),

						ScaleType = Enum.ScaleType.Fit,

						ZIndex = 3,

					}),

				},

			}),

			s:New("Frame")({

				Name = "Body",

				Size = UDim2.new(1, -(ART_SIZE + RIGHT_W + sc(26)), 1, -sc(16)),

				Position = UDim2.new(0, ART_SIZE + sc(12), 0, sc(8)),

				BackgroundTransparency = 1,

				ZIndex = 2,

				[Children] = {

					s:New("UIListLayout")({

						FillDirection = Enum.FillDirection.Vertical,

						Padding = PanelScale.pad(3),

						SortOrder = Enum.SortOrder.LayoutOrder,

						VerticalAlignment = Enum.VerticalAlignment.Center,

					}),

					s:New("TextLabel")({

						LayoutOrder = 1,

						Size = UDim2.new(1, 0, 0, sc(20)),

						BackgroundTransparency = 1,

						Text = item.name,

						TextSize = tsize(16),

						Font = Enum.Font.GothamBlack,

						TextColor3 = C.textMain,

						TextXAlignment = Enum.TextXAlignment.Left,

						TextYAlignment = Enum.TextYAlignment.Center,

					}),

					s:New("TextLabel")({

						LayoutOrder = 2,

						Size = UDim2.new(1, 0, 0, 0),

						AutomaticSize = Enum.AutomaticSize.Y,

						BackgroundTransparency = 1,

						Text = item.desc,

						TextSize = text(11),

						Font = Enum.Font.Gotham,

						TextColor3 = C.textLabel,

						TextXAlignment = Enum.TextXAlignment.Left,

						TextYAlignment = Enum.TextYAlignment.Top,

						TextWrapped = true,

						TextTruncate = Enum.TextTruncate.AtEnd,

					}),

					s:New("Frame")({

						LayoutOrder = 3,

						Size = UDim2.new(1, 0, 0, 0),

						AutomaticSize = Enum.AutomaticSize.Y,

						BackgroundTransparency = 1,

						[Children] = {

							s:New("UIListLayout")({

								FillDirection = Enum.FillDirection.Vertical,

								Padding = PanelScale.pad(1),

							}),

							s:Computed(function()

								local rows = {}

								for i, perk in ipairs(perks) do

									rows[#rows + 1] = s:New("TextLabel")({

										LayoutOrder = i,

										Size = UDim2.new(1, 0, 0, sc(14)),

										BackgroundTransparency = 1,

										Text = "• " .. perk,

										TextSize = text(11),

										Font = Enum.Font.GothamBold,

										TextColor3 = props.accentHi,

										TextXAlignment = Enum.TextXAlignment.Left,

									})

								end

								return rows

							end),

						},

					}),

				},

			}),

			if props.owned

				then s:New("Frame")({

					Name = "OwnedChip",

					Size = UDim2.fromOffset(RIGHT_W, sc(34)),

					Position = UDim2.new(1, -sc(10), 0.5, 0),

					AnchorPoint = Vector2.new(1, 0.5),

					BackgroundColor3 = Color3.fromRGB(18, 48, 32),

					BorderSizePixel = 0,

					ZIndex = 3,

					[Children] = {

						s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),

						s:New("TextLabel")({

							Size = UDim2.fromScale(1, 1),

							BackgroundTransparency = 1,

							Text = "ПОЛУЧЕНО",

							TextSize = text(12),

							Font = Enum.Font.GothamBlack,

							TextColor3 = C.uncommon,

							TextXAlignment = Enum.TextXAlignment.Center,

						}),

					},

				})

				else s:New("TextButton")({

					Name = "BuyButton",

					Size = UDim2.fromOffset(RIGHT_W, sc(88)),

					Position = UDim2.new(1, -sc(10), 0.5, 0),

					AnchorPoint = Vector2.new(1, 0.5),

					AutoButtonColor = false,

					BackgroundColor3 = s:Computed(function(use)

						return if use(hovered) then props.accentHi else props.accent

					end),

					BorderSizePixel = 0,

					Text = "",

					Active = canBuy,

					ZIndex = 5,

					[Children] = {

						s:New("UICorner")({ CornerRadius = UDim.new(0, sc(10)) }),

						s:New("UIStroke")({ Color = C.white, Thickness = sc(1.5), Transparency = 0.5 }),

						s:New("UIListLayout")({

							FillDirection = Enum.FillDirection.Vertical,

							HorizontalAlignment = Enum.HorizontalAlignment.Center,

							VerticalAlignment = Enum.VerticalAlignment.Center,

							Padding = PanelScale.pad(4),

						}),

						s:New("TextLabel")({

							LayoutOrder = 1,

							Size = UDim2.new(1, 0, 0, sc(18)),

							BackgroundTransparency = 1,

							Text = if item.id ~= 0 then "КУПИТЬ" else "СКОРО",

							TextSize = tsize(13),

							Font = Enum.Font.GothamBlack,

							TextColor3 = C.white,

							TextXAlignment = Enum.TextXAlignment.Center,

							[Children] = {

								s:New("UIStroke")({

									Color = Color3.fromRGB(20, 24, 40),

									Thickness = sc(1.5),

									Transparency = 0.2,

								}),

							},

						}),

						RobuxPrice.create(s, {

							price = item.priceRobux,

							wasPrice = item.wasPriceRobux,

							textSize = PanelScale.priceText(14),

							iconSize = PanelScale.tsize(22),

							textColor = C.white,

							wasColor = Color3.fromRGB(220, 225, 240),

							strokeColor = Color3.fromRGB(20, 24, 40),

							stacked = true,

							horizontalAlignment = Enum.HorizontalAlignment.Center,

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

				}),

			s:New("TextButton")({

				Name = "HoverCatcher",

				Size = UDim2.new(1, -(RIGHT_W + sc(10)), 1, 0),

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

		local buy = frame:FindFirstChild("BuyButton") :: TextButton?

		if buy and canBuy then

			UiInteract.attachScoped(s, buy, { hoverScale = 1.04, pressScale = 0.95 })

		end

		return nil

	end)



	return card

end



return ShopFeaturedCard

