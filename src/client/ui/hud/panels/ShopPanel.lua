--!strict
-- ShopPanel.lua — Phase 12 (Монетизация).
--
-- Контент 7-го таба HUD (🛒 МАГАЗИН). Секции:
--   * Game Passes — VIP, Auto-Sell, +2 pet slots.
--   * Dev Products — coin packs, Egg 10x.
--
-- Список карточек через s:Computed ВНУТРИ [Children] (паттерн PetsPanel /
-- LeaderboardPanel — иначе Fusion 0.3 не парентит карточки).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local ShopCard = require(script.Parent.Parent.components.ShopCard)

local Children = Fusion.Children
local C = theme.C

local ShopPanel = {}

local function buildGamepassItems(): { ShopCard.ShopItemDef }
    local items: { ShopCard.ShopItemDef } = {}
    local order = { "vip", "autoSell", "petSlots" }
    for _, key in ipairs(order) do
        local def = (Constants.GAMEPASSES or {})[key]
        if def then
            table.insert(items, {
                key = key,
                id = def.id or 0,
                name = def.name or key,
                icon = def.icon or "✨",
                priceRobux = def.priceRobux or 0,
                desc = def.desc or "",
                kind = "gamepass",
            })
        end
    end
    return items
end

local function buildProductItems(): { ShopCard.ShopItemDef }
    local items: { ShopCard.ShopItemDef } = {}
    local order = { "coinsSmall", "coinsMedium", "egg10" }
    for _, key in ipairs(order) do
        local def = (Constants.DEVPRODUCTS or {})[key]
        if def then
            table.insert(items, {
                key = key,
                id = def.id or 0,
                name = def.name or key,
                icon = def.icon or "💰",
                priceRobux = def.priceRobux or 0,
                desc = def.desc or "",
                kind = "product",
            })
        end
    end
    return items
end

local GAMEPASS_ITEMS = buildGamepassItems()
local PRODUCT_ITEMS = buildProductItems()

local function sectionHeader(s: ScopeFactory.HudScope, text: string, layoutOrder: number)
    return s:New("TextLabel")({
        Name = "SectionHeader",
        Size = UDim2.new(1, -8, 0, 22),
        LayoutOrder = layoutOrder,
        BackgroundTransparency = 1,
        Text = text,
        TextSize = 13,
        Font = Enum.Font.GothamBlack,
        TextColor3 = C.gold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    })
end

function ShopPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("ScrollingFrame")({
        Name = "Shop",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "shop"
        end),
        [Children] = {
            s:New("UIPadding")({
                PaddingTop = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 8),
            }),
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            sectionHeader(s, "🎫 GAME PASSES", 1),
            s:New("Frame")({
                Name = "GamepassList",
                Size = UDim2.new(1, -8, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = 2,
                [Children] = {
                    s:New("UIListLayout")({
                        FillDirection = Enum.FillDirection.Vertical,
                        Padding = UDim.new(0, 8),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    s:Computed(function(use)
                        local gp = use(state.gamepasses) or {}
                        local cards = {}
                        for i, item in ipairs(GAMEPASS_ITEMS) do
                            cards[#cards + 1] = ShopCard.create(s, {
                                item = item,
                                owned = gp[item.key] == true,
                                layoutOrder = i,
                            })
                        end
                        return cards
                    end),
                },
            }),
            sectionHeader(s, "💎 DEV PRODUCTS", 10),
            s:New("Frame")({
                Name = "ProductList",
                Size = UDim2.new(1, -8, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = 11,
                [Children] = {
                    s:New("UIListLayout")({
                        FillDirection = Enum.FillDirection.Vertical,
                        Padding = UDim.new(0, 8),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    s:Computed(function(use)
                        local cards = {}
                        for i, item in ipairs(PRODUCT_ITEMS) do
                            cards[#cards + 1] = ShopCard.create(s, {
                                item = item,
                                owned = false,
                                layoutOrder = i,
                            })
                        end
                        return cards
                    end),
                },
            }),
            s:New("TextLabel")({
                Name = "StudioHint",
                Size = UDim2.new(1, -8, 0, 36),
                LayoutOrder = 20,
                BackgroundTransparency = 1,
                Text = "В Studio: /grantpass <key> · /grantproduct <key>",
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextColor3 = C.textMuted,
                TextWrapped = true,
                ZIndex = 2,
            }),
        },
    })
end

return ShopPanel
