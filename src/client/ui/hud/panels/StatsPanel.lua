--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local StatRow = require(script.Parent.Parent.components.StatRow)

local Children = Fusion.Children
local C = theme.C

local StatsPanel = {}

function StatsPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("ScrollingFrame")({
        Name = "Stats",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "stats"
        end),
        [Children] = {
            s:New("UIPadding")({
                PaddingTop = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
            }),
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 8),
            }),
            StatRow.create(s, {
                label = "⬇ Макс. глубина",
                valueText = s:Computed(function(use)
                    return math.floor(use(state.statMaxDepth)) .. " м"
                end),
                valueColor = C.depthFill,
            }),
            StatRow.create(s, {
                label = "⛏ Блоков сломано",
                valueText = s:Computed(function(use)
                    return Formatters.shortNumber(use(state.statBlocksMined))
                end),
            }),
            StatRow.create(s, {
                label = "💰 Монет заработано",
                valueText = s:Computed(function(use)
                    return Formatters.shortNumber(use(state.statTotalCoins))
                end),
            }),
            StatRow.create(s, {
                label = "🏆 Боссов убито",
                valueText = s:Computed(function(use)
                    return tostring(use(state.statBossesDefeated))
                end),
                valueColor = C.mythic,
            }),
        },
    })
end

return StatsPanel
