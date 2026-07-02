--!strict
-- Контент таба «Магазин»: секции, hero-наборы, бусты, пассы.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local ShopCatalog = require(ReplicatedStorage:WaitForChild("shared").data.ShopCatalog)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local ShopCard = require(script.Parent.Parent.components.ShopCard)
local ShopFeaturedCard = require(script.Parent.Parent.components.ShopFeaturedCard)
local ShopBoostCard = require(script.Parent.Parent.components.ShopBoostCard)
local PanelScale = require(script.Parent.Parent.PanelScale)

local Children = Fusion.Children
local C = theme.C
local ACCENTS = theme.TAB_ACCENTS
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text
local tsize = PanelScale.tsize

local ShopPanel = {}

local ACCENT_BY_KEY = {
	shop = ACCENTS.shop,
	gold = C.gold,
	luck = Color3.fromRGB(70, 220, 130),
	damage = Color3.fromRGB(255, 110, 90),
}

local ACCENT_HI_BY_KEY = {
	shop = Color3.fromRGB(255, 175, 215),
	gold = C.goldHi,
	luck = Color3.fromRGB(120, 255, 170),
	damage = Color3.fromRGB(255, 150, 120),
}

local function accentPair(accentKey: string): (Color3, Color3)
	return ACCENT_BY_KEY[accentKey] or ACCENTS.shop, ACCENT_HI_BY_KEY[accentKey] or C.goldHi
end

local function productToItem(def: any): ShopCard.ShopItemDef
	return {
		key = def.key,
		id = def.id or 0,
		name = def.name or def.key,
		icon = def.icon or "coin",
		priceRobux = def.priceRobux or 0,
		wasPriceRobux = def.wasPriceRobux,
		badge = def.badge,
		desc = def.desc or "",
		kind = "product",
	}
end

local function productToFeatured(def: any): ShopFeaturedCard.FeaturedItem
	return {
		key = def.key,
		id = def.id or 0,
		name = def.name or def.key,
		icon = def.icon or "icon_gift",
		priceRobux = def.priceRobux or 0,
		wasPriceRobux = def.wasPriceRobux,
		badge = def.badge,
		desc = def.desc or "",
		perks = def.perks,
		kind = "product",
	}
end

local function gamepassToItem(def: any): ShopCard.ShopItemDef
	return {
		key = def.key,
		id = def.id or 0,
		name = def.name or def.key,
		icon = def.icon or "icon_crown",
		priceRobux = def.priceRobux or 0,
		badge = def.badge,
		desc = def.desc or "",
		kind = "gamepass",
	}
end

local function sectionHeader(
	s: ScopeFactory.HudScope,
	title: string,
	subtitle: string?,
	iconKey: string,
	accent: Color3,
	layoutOrder: number
)
	return s:New("Frame")({
		Name = "SectionHeader",
		Size = UDim2.new(1, -sc(8), 0, if subtitle then sc(38) else sc(30)),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		[Children] = {
			s:New("Frame")({
				Size = UDim2.fromOffset(sc(3), sc(18)),
				Position = UDim2.new(0, 0, 0, if subtitle then sc(4) else sc(6)),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				},
			}),
			s:New("ImageLabel")({
				Size = UDim2.fromOffset(sc(18), sc(18)),
				Position = UDim2.new(0, sc(10), 0, if subtitle then sc(4) else sc(6)),
				BackgroundTransparency = 1,
				Image = UiAssets.image(iconKey :: any),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, -sc(34), 0, sc(18)),
				Position = UDim2.new(0, sc(32), 0, if subtitle then sc(2) else sc(6)),
				BackgroundTransparency = 1,
				Text = title,
				TextSize = text(13),
				Font = Enum.Font.GothamBlack,
				TextColor3 = C.textMain,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			if subtitle
				then s:New("TextLabel")({
					Size = UDim2.new(1, -sc(34), 0, sc(14)),
					Position = UDim2.new(0, sc(32), 0, sc(20)),
					BackgroundTransparency = 1,
					Text = subtitle,
					TextSize = text(11),
					Font = Enum.Font.Gotham,
					TextColor3 = C.textMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 2,
				})
				else nil,
		},
	})
end

local function shopBanner(s: ScopeFactory.HudScope)
	return s:New("Frame")({
		Name = "ShopBanner",
		Size = UDim2.new(1, -sc(8), 0, sc(76)),
		BackgroundColor3 = C.panelInner,
		BorderSizePixel = 0,
		LayoutOrder = 0,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(12)) }),
			s:New("UIStroke")({
				Color = ACCENTS.shop,
				Thickness = sc(2),
				Transparency = 0.25,
			}),
			s:New("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 190)),
					ColorSequenceKeypoint.new(0.55, Color3.fromRGB(120, 90, 200)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 48, 88)),
				}),
				Rotation = 18,
			}),
			s:New("Frame")({
				Size = UDim2.fromOffset(sc(52), sc(52)),
				Position = UDim2.new(0, sc(12), 0.5, -sc(26)),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.88,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					s:New("ImageLabel")({
						Size = UDim2.fromOffset(sc(30), sc(30)),
						Position = UDim2.new(0.5, -sc(15), 0.5, -sc(15)),
						BackgroundTransparency = 1,
						Image = UiAssets.tab("shop"),
						ScaleType = Enum.ScaleType.Fit,
					}),
				},
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, -sc(80), 0, sc(22)),
				Position = UDim2.new(0, sc(74), 0, sc(16)),
				BackgroundTransparency = 1,
				Text = "Премиум магазин",
				TextSize = tsize(17),
				Font = Enum.Font.GothamBlack,
				TextColor3 = C.white,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
				[Children] = {
					s:New("UIStroke")({ Color = C.outlineDark, Thickness = sc(1), Transparency = 0.5 }),
				},
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, -sc(80), 0, sc(28)),
				Position = UDim2.new(0, sc(74), 0, sc(38)),
				BackgroundTransparency = 1,
				Text = "Наборы, бусты и пассы — ускорь прогресс",
				TextSize = text(12),
				Font = Enum.Font.Gotham,
				TextColor3 = Color3.fromRGB(230, 220, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				ZIndex = 2,
			}),
		},
	})
end

local function buildProductCards(
	s: ScopeFactory.HudScope,
	keys: { string },
	layoutOrderStart: number
): { Instance }
	local cards: { Instance } = {}
	for i, key in ipairs(keys) do
		local def = ShopCatalog.productDef(key)
		if def then
			cards[#cards + 1] = ShopCard.create(s, {
				item = productToItem(def),
				owned = false,
				layoutOrder = layoutOrderStart + i,
			})
		end
	end
	return cards
end

local function buildBoostCards(
	s: ScopeFactory.HudScope,
	keys: { string },
	accent: Color3,
	accentHi: Color3,
	layoutOrderStart: number
): { Instance }
	local cards: { Instance } = {}
	for i, key in ipairs(keys) do
		local def = ShopCatalog.productDef(key)
		if def then
			cards[#cards + 1] = ShopBoostCard.create(s, {
				item = productToItem(def) :: any,
				accent = accent,
				accentHi = accentHi,
				layoutOrder = layoutOrderStart + i,
			})
		end
	end
	return cards
end

local function buildFeaturedCards(
	s: ScopeFactory.HudScope,
	keys: { string },
	accent: Color3,
	accentHi: Color3,
	purchases: { [string]: boolean }?
): { Instance }
	local cards: { Instance } = {}
	for i, key in ipairs(keys) do
		local def = ShopCatalog.productDef(key)
		if def then
			local owned = def.oneTime == true and purchases ~= nil and purchases[key] == true
			cards[#cards + 1] = ShopFeaturedCard.create(s, {
				item = productToFeatured(def),
				owned = owned,
				accent = accent,
				accentHi = accentHi,
				layoutOrder = i,
			})
		end
	end
	return cards
end

local function withLayout(layout: Instance, items: { Instance }): { Instance }
	local out: { Instance } = { layout }
	for _, item in ipairs(items) do
		table.insert(out, item)
	end
	return out
end

local function buildSectionContent(
	s: ScopeFactory.HudScope,
	state: HudStateModule.HudState,
	section: ShopCatalog.SectionDef,
	layoutOrder: number
)
	local accent, accentHi = accentPair(section.accentKey)
	local headerOrder = layoutOrder
	local listOrder = layoutOrder + 1

	if section.id == "gamepasses" then
		return {
			sectionHeader(s, section.title, section.subtitle, section.iconKey, accent, headerOrder),
			s:New("Frame")({
				Name = "GamepassList",
				Size = UDim2.new(1, -sc(8), 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = listOrder,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = PanelScale.pad(8),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					s:Computed(function(use)
						local gp = use(state.gamepasses) or {}
						local cards = {}
						for i, key in ipairs(ShopCatalog.gamepassKeys()) do
							local def = ShopCatalog.gamepassDef(key)
							if def then
								cards[#cards + 1] = ShopCard.create(s, {
									item = gamepassToItem(def),
									owned = gp[key] == true,
									layoutOrder = i,
								})
							end
						end
						return cards
					end),
				},
			}),
		}
	end

	if section.layout == "hero" then
		local keys = ShopCatalog.productKeys(section.id)
		if section.id == "starter" then
			return {
				s:Computed(function(use)
					local purchases = use(state.shopPurchases) or {}
					if purchases.starterPack == true then
						return {}
					end
					return {
						sectionHeader(s, section.title, section.subtitle, section.iconKey, accent, headerOrder),
						s:New("Frame")({
							Name = "HeroList_starter",
							Size = UDim2.new(1, -sc(8), 0, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							BackgroundTransparency = 1,
							LayoutOrder = listOrder,
							[Children] = withLayout(
								s:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Vertical,
									Padding = PanelScale.pad(10),
									SortOrder = Enum.SortOrder.LayoutOrder,
								}),
								buildFeaturedCards(s, keys, accent, accentHi, purchases)
							),
						}),
					}
				end),
			}
		end
		return {
			sectionHeader(s, section.title, section.subtitle, section.iconKey, accent, headerOrder),
			s:New("Frame")({
				Name = "HeroList_" .. section.id,
				Size = UDim2.new(1, -sc(8), 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = listOrder,
				[Children] = withLayout(
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = PanelScale.pad(10),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					buildFeaturedCards(s, keys, accent, accentHi, nil)
				),
			}),
		}
	end

	if section.layout == "grid" then
		local keys = ShopCatalog.productKeys(section.id)
		return {
			sectionHeader(s, section.title, section.subtitle, section.iconKey, accent, headerOrder),
			s:New("Frame")({
				Name = "BoostGrid",
				Size = UDim2.new(1, -sc(8), 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = listOrder,
				[Children] = withLayout(
					s:New("UIGridLayout")({
						CellSize = UDim2.new(0.5, -sc(6), 0, sc(132)),
						CellPadding = UDim2.new(0, sc(8), 0, sc(10)),
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
					buildBoostCards(s, keys, accent, accentHi, 0)
				),
			}),
		}
	end

	-- list layout (coins, eggs)
	local keys = ShopCatalog.productKeys(section.id)
	return {
		sectionHeader(s, section.title, section.subtitle, section.iconKey, accent, headerOrder),
		s:New("Frame")({
			Name = "List_" .. section.id,
			Size = UDim2.new(1, -sc(8), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = listOrder,
			[Children] = withLayout(
				s:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					Padding = PanelScale.pad(8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				buildProductCards(s, keys, 0)
			),
		}),
	}
end

function ShopPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	local children: { Instance } = {
		s:New("UIPadding")({
			PaddingTop = PanelScale.pad(4),
			PaddingLeft = PanelScale.pad(4),
			PaddingRight = PanelScale.pad(4),
			PaddingBottom = PanelScale.pad(8),
		}),
		s:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = PanelScale.pad(10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		shopBanner(s),
	}

	local order = 1
	for _, section in ipairs(ShopCatalog.sections()) do
		local sectionBlocks = buildSectionContent(s, state, section, order)
		for _, block in ipairs(sectionBlocks) do
			children[#children + 1] = block
		end
		order += 2
	end

	if RunService:IsStudio() then
		children[#children + 1] = s:New("TextLabel")({
			Name = "StudioHint",
			Size = UDim2.new(1, -sc(8), 0, sc(32)),
			LayoutOrder = 100,
			BackgroundTransparency = 1,
			Text = "Studio: /grantproduct starterPack · /grantpass vip",
			TextSize = text(11),
			Font = Enum.Font.Gotham,
			TextColor3 = C.textMuted,
			TextWrapped = true,
			ZIndex = 2,
		})
	end

	return s:New("ScrollingFrame")({
		Name = "Shop",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = PanelScale.scrollBar(),
		ScrollBarImageColor3 = C.panelBorder,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = s:Computed(function(use)
			return use(state.activeTab) == "shop"
		end),
		[Children] = children,
	})
end

return ShopPanel
