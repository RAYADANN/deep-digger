--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local TabBtn = require(script.Parent.Parent.components.TabBtn)

local Children = Fusion.Children

local TabBar = {}

function TabBar.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("Frame")({
        Size = UDim2.new(0, 200, 0, 72),
        Position = UDim2.new(0, 8, 1, -80),
        BackgroundTransparency = 1,
        [Children] = {
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 6),
                VerticalAlignment = Enum.VerticalAlignment.Center,
            }),
            TabBtn.create(s, {
                icon = "⛏",
                label = "ИНВЕНТ",
                tabId = "inventory",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
            TabBtn.create(s, {
                icon = "⚒",
                label = "АПГРЕЙД",
                tabId = "upgrades",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
            TabBtn.create(s, {
                icon = "📊",
                label = "СТАТЫ",
                tabId = "stats",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
        },
    })
end

return TabBar
