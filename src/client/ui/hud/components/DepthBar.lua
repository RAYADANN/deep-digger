--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local HudStateModule = require(script.Parent.Parent.HudState)

local Children = Fusion.Children
local C = theme.C

local DepthBar = {}

function DepthBar.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    local fillRatio = s:Computed(function(use)
        local depth = use(state.depth)
        for _, layer in ipairs(Constants.LAYERS) do
            if layer.id == use(state.layerId) then
                local range = layer.depthEnd - layer.depthStart
                if range <= 0 or layer.depthEnd == math.huge then
                    return 0.5
                end
                return math.clamp((depth - layer.depthStart) / range, 0, 1)
            end
        end
        return 0
    end)

    local layerColor = s:Computed(function(use)
        return theme.LAYER_COLORS[use(state.layerId)] or C.depthFill
    end)

    return s:New("Frame")({
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = C.depthBg,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
            s:New("UIStroke")({ Color = C.panelBorder, Thickness = 1, Transparency = 0.4 }),
            s:New("Frame")({
                Size = s:Computed(function(use)
                    return UDim2.new(use(fillRatio), 0, 1, 0)
                end),
                BackgroundColor3 = layerColor,
                BackgroundTransparency = 0.2,
                BorderSizePixel = 0,
                [Children] = { s:New("UICorner")({ CornerRadius = UDim.new(0, 5) }) },
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.4, 0, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = "ГЛУБИНА",
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.white,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 3,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.6, -8, 1, 0),
                Position = UDim2.new(0.4, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    return math.floor(use(state.depth)) .. "м"
                end),
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.white,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 3,
            }),
        },
    })
end

return DepthBar
