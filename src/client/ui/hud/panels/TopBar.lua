--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local DepthBar = require(script.Parent.Parent.components.DepthBar)
local ResourceChip = require(script.Parent.Parent.components.ResourceChip)
local SellButton = require(script.Parent.Parent.components.SellButton)

local Children = Fusion.Children
local C = theme.C

local TopBar = {}

function TopBar.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    local layerColor = s:Computed(function(use)
        return theme.LAYER_COLORS[use(state.layerId)] or C.depthFill
    end)

    return s:New("Frame")({
        Size = UDim2.new(0, 240, 0, 118),
        Position = UDim2.new(0, 8, 0, 36),
        BackgroundTransparency = 1,
        [Children] = {
            DepthBar.create(s, state),
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, 18),
                Position = UDim2.new(0, 0, 0, 28),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    return "▼ " .. use(state.layerName)
                end),
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextColor3 = layerColor,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            ResourceChip.create(s, {
                position = UDim2.new(0, 0, 0, 50),
                bgColor = C.goldBg,
                strokeColor = C.gold,
                prefix = "💰 ",
                textColor = C.gold,
                amount = state.coins,
            }),
            ResourceChip.create(s, {
                position = UDim2.new(0, 122, 0, 50),
                bgColor = C.gemBg,
                strokeColor = C.gem,
                prefix = "💎 ",
                textColor = C.gem,
                amount = state.gems,
            }),
            SellButton.create(s),
        },
    })
end

return TopBar
