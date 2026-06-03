--!strict
-- ShopCard.lua — Phase 12 (Монетизация).
--
-- Карточка товара в ShopPanel (геймпасс или девпродукт). ZIndex 2+ на тексте
-- (грабли Фазы 10). Кнопка PURCHASE:
--   * gamepass → MarketplaceService:PromptGamePassPurchase (id != 0).
--   * product  → MarketplaceService:PromptProductPurchase (id != 0).
--   * id == 0  → плейсхолдер (ещё не создан в Creator Hub) — disabled +
--     подсказка «настрой ID в Hub / используй /grantpass в Studio».

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local Notification = require(script.Parent.Parent.Parent.Notification)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local C = theme.C

export type ShopItemDef = {
    key: string,
    id: number,
    name: string,
    icon: string,
    priceRobux: number,
    desc: string,
    kind: "gamepass" | "product",
}

export type Props = {
    item: ShopItemDef,
    owned: boolean,
    layoutOrder: number,
}

local ShopCard = {}

function ShopCard.create(s: ScopeFactory.HudScope, props: Props)
    local item = props.item
    local hovered = s:Value(false)
    local hasRealId = item.id ~= 0
    local canBuy = not props.owned and hasRealId

    local function onPurchase()
        if props.owned then
            return
        end
        if not hasRealId then
            Notification.show({
                text = "ID не настроен в Creator Hub. В Studio: /grantpass или /grantproduct",
                icon = "🛠",
                color = Color3.fromRGB(120, 200, 255),
                duration = 3,
            })
            return
        end
        pcall(function()
            if item.kind == "gamepass" then
                MarketplaceService:PromptGamePassPurchase(game.Players.LocalPlayer, item.id)
            else
                MarketplaceService:PromptProductPurchase(game.Players.LocalPlayer, item.id)
            end
        end)
    end

    return s:New("Frame")({
        Name = "ShopCard_" .. item.key,
        Size = UDim2.new(1, -8, 0, 88),
        BackgroundColor3 = C.btnBg,
        BorderSizePixel = 0,
        LayoutOrder = props.layoutOrder,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
            s:New("UIStroke")({
                Color = if props.owned then C.uncommon else C.gold,
                Thickness = if props.owned then 1.5 else 2,
                Transparency = if props.owned then 0.5 else 0.25,
            }),
            -- Иконка.
            s:New("TextLabel")({
                Size = UDim2.new(0, 48, 0, 48),
                Position = UDim2.new(0, 10, 0.5, -24),
                BackgroundTransparency = 1,
                Text = item.icon,
                TextSize = 32,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.textMain,
                ZIndex = 2,
            }),
            -- Название.
            s:New("TextLabel")({
                Size = UDim2.new(1, -180, 0, 20),
                Position = UDim2.new(0, 64, 0, 12),
                BackgroundTransparency = 1,
                Text = item.name,
                TextSize = 15,
                Font = Enum.Font.GothamBlack,
                TextColor3 = C.textMain,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 2,
            }),
            -- Описание.
            s:New("TextLabel")({
                Size = UDim2.new(1, -180, 0, 36),
                Position = UDim2.new(0, 64, 0, 32),
                BackgroundTransparency = 1,
                Text = item.desc,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextColor3 = C.textLabel,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                ZIndex = 2,
            }),
            -- Цена / статус.
            s:New("TextLabel")({
                Size = UDim2.new(0, 110, 0, 16),
                Position = UDim2.new(1, -118, 0, 14),
                BackgroundTransparency = 1,
                Text = if props.owned
                    then "✓ КУПЛЕНО"
                    else ("R$ %d"):format(item.priceRobux),
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextColor3 = if props.owned then C.uncommon else C.gold,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 2,
            }),
            -- Кнопка PURCHASE.
            s:New("TextButton")({
                Size = UDim2.new(0, 100, 0, 32),
                Position = UDim2.new(1, -110, 1, -40),
                AutoButtonColor = false,
                BackgroundColor3 = s:Computed(function(use)
                    if props.owned or not hasRealId then
                        return C.btnDisabled
                    end
                    return use(hovered) and Color3.fromRGB(220, 180, 30) or C.gold
                end),
                BorderSizePixel = 0,
                Text = if props.owned then "OWNED" elseif hasRealId then "КУПИТЬ" else "SOON",
                TextSize = 13,
                Font = Enum.Font.GothamBlack,
                TextColor3 = s:Computed(function(use)
                    return if canBuy then Color3.fromRGB(40, 25, 0) else C.textMuted
                end),
                Active = canBuy,
                ZIndex = 3,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
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
        },
    })
end

return ShopCard
