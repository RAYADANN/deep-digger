--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local shared = ReplicatedStorage:WaitForChild("shared")
local OreLookup = require(script.Parent.Parent.Parent.Parent.core.OreLookup)
local OreAssets = require(shared.data.OreAssets)
local OreIcon = require(script.Parent.OreIcon)
local PanelScale = require(script.Parent.Parent.PanelScale)

local Children = Fusion.Children
local C = theme.C
local RARITY_COLOR = theme.RARITY_COLOR
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text

export type Props = {
    oreId: string,
    discovered: boolean,
}

local OreEntry = {}

function OreEntry.create(s: ScopeFactory.HudScope, props: Props)
    local rarity = OreLookup.getRarity(props.oreId)
    local rarityColor = RARITY_COLOR[rarity] or C.common
    local name = OreLookup.getName(props.oreId) or props.oreId
    local hasImage = OreAssets.hasImage(props.oreId)

    return s:New("Frame")({
        Name = "Ore_" .. props.oreId,
        Size = UDim2.fromOffset(sc(52), sc(62)),
        BackgroundColor3 = s:Computed(function(use)
            return if props.discovered then C.btnBg else C.panelHeader
        end),
        BackgroundTransparency = s:Computed(function(use)
            return if props.discovered then 0 else 0.35
        end),
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, sc(6)) }),
            s:New("UIStroke")({
                Color = rarityColor,
                Thickness = if props.discovered and (rarity == "mythic" or rarity == "legendary") then sc(2.5)
                    elseif props.discovered and (rarity == "epic" or rarity == "rare") then sc(2)
                    else sc(1.5),
                Transparency = if props.discovered then 0.15 else 0.65,
            }),
            s:New("Frame")({
                Size = UDim2.new(1, 0, 0, sc(3)),
                BackgroundColor3 = rarityColor,
                BackgroundTransparency = s:Computed(function()
                    return if props.discovered then 0 else 0.7
                end),
                BorderSizePixel = 0,
                [Children] = { s:New("UICorner")({ CornerRadius = UDim.new(0, sc(3)) }) },
            }),
            if props.discovered and hasImage
                then OreIcon.create(s, {
                    oreId = props.oreId,
                    size = UDim2.new(1, -sc(6), 0, sc(30)),
                    position = UDim2.new(0, sc(3), 0, sc(6)),
                    textColor3 = s:Computed(function()
                        return rarityColor
                    end),
                    zIndex = 2,
                })
                else s:New("TextLabel")({
                    Size = UDim2.new(1, 0, 0, sc(30)),
                    Position = UDim2.new(0, 0, 0, sc(6)),
                    BackgroundTransparency = 1,
                    Text = if props.discovered then OreLookup.getIcon(props.oreId) else "?",
                    TextScaled = true,
                    Font = Enum.Font.GothamBold,
                    TextColor3 = s:Computed(function()
                        return if props.discovered then rarityColor else C.textMuted
                    end),
                    ZIndex = 2,
                }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -sc(4), 0, sc(22)),
                Position = UDim2.new(0, sc(2), 0, sc(36)),
                BackgroundTransparency = 1,
                Text = if props.discovered then name else "???",
                TextSize = text(10, 10),
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
