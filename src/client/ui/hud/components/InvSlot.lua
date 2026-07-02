--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local OreLookup = require(script.Parent.Parent.Parent.Parent.core.OreLookup)
local OreIcon = require(script.Parent.OreIcon)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)
local PanelScale = require(script.Parent.Parent.PanelScale)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local C = theme.C
local RARITY_COLOR = theme.RARITY_COLOR
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text

export type Props = {
    oreId: string,
    count: number,
}

local InvSlot = {}

function InvSlot.create(s: ScopeFactory.HudScope, props: Props)
    local rarity = OreLookup.getRarity(props.oreId)
    local rarityColor = RARITY_COLOR[rarity] or C.common
    local hovered = s:Value(false)
    local pressing = s:Value(false)

    local slot = s:New("Frame")({
        Size = UDim2.fromOffset(sc(58), sc(68)),
        BackgroundColor3 = s:Computed(function(use)
            return use(hovered) and C.btnHover or C.btnBg
        end),
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, sc(6)) }),
            s:New("UIStroke")({ Color = rarityColor, Thickness = sc(1.5), Transparency = 0.2 }),
            s:New("Frame")({
                Size = UDim2.new(1, 0, 0, sc(3)),
                BackgroundColor3 = rarityColor,
                BorderSizePixel = 0,
                [Children] = { s:New("UICorner")({ CornerRadius = UDim.new(0, sc(3)) }) },
            }),
            OreIcon.create(s, {
                oreId = props.oreId,
                size = UDim2.new(1, -sc(8), 0, sc(36)),
                position = UDim2.new(0, sc(4), 0, sc(8)),
                textColor3 = rarityColor,
                zIndex = 2,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -sc(4), 0, sc(14)),
                Position = UDim2.new(0, sc(2), 0, sc(44)),
                BackgroundTransparency = 1,
                Text = (OreLookup.getName(props.oreId) or props.oreId):sub(1, 10),
                TextSize = text(10, 10),
                Font = Enum.Font.Gotham,
                TextColor3 = C.textMuted,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 2,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -sc(4), 0, sc(14)),
                Position = UDim2.new(0, sc(2), 0, sc(54)),
                BackgroundTransparency = 1,
                Text = "x" .. Formatters.shortNumber(props.count),
                TextSize = text(11, 11),
                Font = Enum.Font.GothamBold,
                TextColor3 = rarityColor,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 2,
            }),
            s:New("TextButton")({
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 5,
                [OnEvent("MouseEnter")] = function()
                    hovered:set(true)
                end,
                [OnEvent("MouseLeave")] = function()
                    hovered:set(false)
                    pressing:set(false)
                end,
                [OnEvent("MouseButton1Down")] = function()
                    pressing:set(true)
                end,
                [OnEvent("MouseButton1Up")] = function()
                    pressing:set(false)
                end,
            }),
        },
    })

    UiMotion.bindHoverPress(s, slot, hovered, pressing, { hoverScale = 1.06, pressScale = 0.97 })

    return slot
end

return InvSlot
