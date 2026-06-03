--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local OreLookup = require(script.Parent.Parent.Parent.Parent.core.OreLookup)

local Children = Fusion.Children
local C = theme.C
local RARITY_COLOR = theme.RARITY_COLOR

export type Props = {
    oreId: string,
    discovered: boolean,
}

local OreEntry = {}

function OreEntry.create(s: ScopeFactory.HudScope, props: Props)
    local rarity = OreLookup.getRarity(props.oreId)
    local rarityColor = RARITY_COLOR[rarity] or C.common
    local icon = OreLookup.getIcon(props.oreId)
    local name = OreLookup.getName(props.oreId) or props.oreId

    return s:New("Frame")({
        Name = "Ore_" .. props.oreId,
        Size = UDim2.new(0, 52, 0, 62),
        BackgroundColor3 = s:Computed(function(use)
            return if props.discovered then C.btnBg else C.panelHeader
        end),
        BackgroundTransparency = s:Computed(function(use)
            return if props.discovered then 0 else 0.35
        end),
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
            s:New("UIStroke")({
                Color = rarityColor,
                Thickness = if props.discovered and (rarity == "mythic" or rarity == "legendary") then 2.5
                    elseif props.discovered and (rarity == "epic" or rarity == "rare") then 2
                    else 1.5,
                Transparency = if props.discovered then 0.15 else 0.65,
            }),
            s:New("Frame")({
                Size = UDim2.new(1, 0, 0, 3),
                BackgroundColor3 = rarityColor,
                BackgroundTransparency = s:Computed(function()
                    return if props.discovered then 0 else 0.7
                end),
                BorderSizePixel = 0,
                [Children] = { s:New("UICorner")({ CornerRadius = UDim.new(0, 3) }) },
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, 30),
                Position = UDim2.new(0, 0, 0, 6),
                BackgroundTransparency = 1,
                Text = if props.discovered then icon else "?",
                TextScaled = true,
                Font = Enum.Font.GothamBold,
                TextColor3 = s:Computed(function()
                    return if props.discovered then rarityColor else C.textMuted
                end),
                ZIndex = 2,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -4, 0, 22),
                Position = UDim2.new(0, 2, 0, 36),
                BackgroundTransparency = 1,
                Text = if props.discovered then name else "???",
                TextSize = 8,
                Font = Enum.Font.Gotham,
                TextColor3 = s:Computed(function()
                    return if props.discovered then C.textMain else C.textMuted
                end),
                TextXAlignment = Enum.TextXAlignment.Center,
                TextWrapped = true,
                ZIndex = 2,
            }),
        },
    })
end

return OreEntry
