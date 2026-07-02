--!strict

-- Компактная карточка буста (сетка 2 колонки).



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



export type BoostItem = {

	key: string,

	id: number,

	name: string,

	icon: string,

	priceRobux: number,

	wasPriceRobux: number?,

	desc: string,

	kind: "product",

}



export type Props = {

	item: BoostItem,

	accent: Color3,

	accentHi: Color3,

	layoutOrder: number,

}



local CARD_H_DESIGN = 132

local FOOTER_H_DESIGN = 44

local BOTTOM_PAD_DESIGN = 10



local ShopBoostCard = {}



function ShopBoostCard.create(s: ScopeFactory.HudScope, props: Props)

	-- Масштаб на лету (sc), а не на require — иначе размер замораживается.

	local CARD_H = sc(CARD_H_DESIGN)

	local FOOTER_H = sc(FOOTER_H_DESIGN)

	local BOTTOM_PAD = sc(BOTTOM_PAD_DESIGN)

	local item = props.item

	local hovered = s:Value(false)

	local canBuy = item.id ~= 0



	local function onPurchase()

		if not canBuy then

			return

		end

		ShopPurchase.prompt(item)

	end



	local card = s:New("Frame")({

		Name = "Boost_" .. item.key,

		Size = UDim2.new(0.5, -sc(6), 0, CARD_H),

		BackgroundColor3 = s:Computed(function(use)

			return if use(hovered) then C.bg4 else C.btnBg

		end),

		BorderSizePixel = 0,

		LayoutOrder = props.layoutOrder,

		[Children] = {

			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(10)) }),

			s:New("UIStroke")({

				Color = s:Computed(function(use)

					return if use(hovered) then props.accentHi else props.accent

				end),

				Thickness = sc(1.5),

				Transparency = s:Computed(function(use)

					return if use(hovered) then 0.12 else 0.4

				end),

			}),

			s:New("UIPadding")({

				PaddingTop = PanelScale.pad(8),

				PaddingLeft = PanelScale.pad(6),

				PaddingRight = PanelScale.pad(6),

				PaddingBottom = UDim.new(0, BOTTOM_PAD),

			}),

			s:New("Frame")({

				Name = "TopBlock",

				Size = UDim2.new(1, 0, 1, -FOOTER_H),

				BackgroundTransparency = 1,

				ZIndex = 2,

				[Children] = {

					s:New("UIListLayout")({

						FillDirection = Enum.FillDirection.Vertical,

						HorizontalAlignment = Enum.HorizontalAlignment.Center,

						VerticalAlignment = Enum.VerticalAlignment.Top,

						Padding = PanelScale.pad(3),

						SortOrder = Enum.SortOrder.LayoutOrder,

					}),

					s:New("ImageLabel")({

						LayoutOrder = 1,

						Size = UDim2.fromOffset(sc(36), sc(36)),

						BackgroundTransparency = 1,

						Image = UiAssets.resolve(item.icon),

						ScaleType = Enum.ScaleType.Fit,

					}),

					s:New("TextLabel")({

						LayoutOrder = 2,

						Size = UDim2.new(1, 0, 0, sc(16)),

						BackgroundTransparency = 1,

						Text = item.name,

						TextSize = text(13),

						Font = Enum.Font.GothamBlack,

						TextColor3 = C.textMain,

						TextXAlignment = Enum.TextXAlignment.Center,

						TextTruncate = Enum.TextTruncate.AtEnd,

					}),

					s:New("TextLabel")({

						LayoutOrder = 3,

						Size = UDim2.new(1, 0, 0, sc(26)),

						BackgroundTransparency = 1,

						Text = item.desc,

						TextSize = text(10, 11),

						Font = Enum.Font.Gotham,

						TextColor3 = C.textMuted,

						TextXAlignment = Enum.TextXAlignment.Center,

						TextYAlignment = Enum.TextYAlignment.Top,

						TextWrapped = true,

						TextTruncate = Enum.TextTruncate.AtEnd,

					}),

				},

			}),

			s:New("Frame")({

				Name = "PriceFooter",

				Size = UDim2.new(1, 0, 0, FOOTER_H),

				Position = UDim2.new(0, 0, 1, 0),

				AnchorPoint = Vector2.new(0, 1),

				BackgroundTransparency = 1,

				ZIndex = 2,

				[Children] = {

					s:New("UIListLayout")({

						FillDirection = Enum.FillDirection.Vertical,

						HorizontalAlignment = Enum.HorizontalAlignment.Center,

						VerticalAlignment = Enum.VerticalAlignment.Center,

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

			s:New("TextButton")({

				Name = "BuyHit",

				Size = UDim2.fromScale(1, 1),

				BackgroundTransparency = 1,

				Text = "",

				ZIndex = 3,

				[OnEvent("MouseEnter")] = function()

					hovered:set(true)

				end,

				[OnEvent("MouseLeave")] = function()

					hovered:set(false)

				end,

				[OnEvent("Activated")] = onPurchase,

			}),

		},

	})



	UiMotion.defer(s, card, function(frame)

		local hit = frame:FindFirstChild("BuyHit") :: TextButton?

		if hit and canBuy then

			UiInteract.attachScoped(s, hit, { hoverScale = 1.03, pressScale = 0.97 })

		end

		return nil

	end)



	return card

end



return ShopBoostCard

