--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
-- script.Parent.Parent.Parent.Parent = client (StarterGui.client → PlayerScripts.client)
local OreLookup = require(script.Parent.Parent.Parent.Parent.core.OreLookup)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local C = theme.C
local RARITY_COLOR = theme.RARITY_COLOR

export type Props = {
    oreId: string,
    count: number,
}

local InvSlot = {}

function InvSlot.create(s: ScopeFactory.HudScope, props: Props)
    local rarity = OreLookup.getRarity(props.oreId)
    local rarityColor = RARITY_COLOR[rarity] or C.common
    local icon = OreLookup.getIcon(props.oreId)
    local hovered = s:Value(false)

    return s:New("Frame")({
        Size = UDim2.new(0, 58, 0, 68),
        BackgroundColor3 = s:Computed(function(use)
            return use(hovered) and C.btnHover or C.btnBg
        end),
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
            s:New("UIStroke")({ Color = rarityColor, Thickness = 1.5, Transparency = 0.2 }),
            s:New("Frame")({
                Size = UDim2.new(1, 0, 0, 3),
                BackgroundColor3 = rarityColor,
                BorderSizePixel = 0,
                [Children] = { s:New("UICorner")({ CornerRadius = UDim.new(0, 3) }) },
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, 36),
                Position = UDim2.new(0, 0, 0, 8),
                BackgroundTransparency = 1,
                Text = icon,
                TextScaled = true,
                Font = Enum.Font.GothamBold,
                TextColor3 = rarityColor,
                ZIndex = 2,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -4, 0, 14),
                Position = UDim2.new(0, 2, 0, 44),
                BackgroundTransparency = 1,
                Text = props.oreId:gsub("_", " "):sub(1, 10),
                TextSize = 9,
                Font = Enum.Font.Gotham,
                TextColor3 = C.textMuted,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 2,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -4, 0, 14),
                Position = UDim2.new(0, 2, 0, 54),
                BackgroundTransparency = 1,
                Text = "x" .. Formatters.shortNumber(props.count),
                TextSize = 11,
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
                end,
            }),
        },
    })
end

return InvSlot
