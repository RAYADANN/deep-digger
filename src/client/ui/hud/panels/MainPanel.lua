--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local InventoryPanel = require(script.Parent.InventoryPanel)
local UpgradesPanel = require(script.Parent.UpgradesPanel)
local StatsPanel = require(script.Parent.StatsPanel)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local C = theme.C

local MainPanel = {}

function MainPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("Frame")({
        Name = "MainPanel",
        Size = UDim2.new(0, 540, 0, 340),
        Position = UDim2.new(0, 8, 1, -428),
        Visible = s:Computed(function(use)
            return use(state.panelOpen)
        end),
        BackgroundColor3 = C.panelBg,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
            s:New("UIStroke")({ Color = C.panelBorder, Thickness = 1.5, Transparency = 0.2 }),
            s:New("Frame")({
                Size = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = C.panelHeader,
                BackgroundTransparency = 0.1,
                BorderSizePixel = 0,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
                    s:New("TextLabel")({
                        Size = UDim2.new(0, 30, 1, 0),
                        Position = UDim2.new(0, 8, 0, 0),
                        BackgroundTransparency = 1,
                        Text = "✦",
                        TextSize = 18,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = C.gem,
                    }),
                    s:New("TextLabel")({
                        Size = UDim2.new(0.7, 0, 1, 0),
                        Position = UDim2.new(0, 40, 0, 0),
                        BackgroundTransparency = 1,
                        Text = s:Computed(function(use)
                            local tab = use(state.activeTab)
                            if tab == "inventory" then
                                return "ИНВЕНТАРЬ"
                            elseif tab == "upgrades" then
                                return "УЛУЧШЕНИЯ"
                            end
                            return "СТАТИСТИКА"
                        end),
                        TextSize = 16,
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = C.textMain,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }),
                    s:New("TextButton")({
                        Size = UDim2.new(0, 32, 0, 32),
                        Position = UDim2.new(1, -38, 0.5, -16),
                        BackgroundColor3 = C.closeBg,
                        BackgroundTransparency = 0.2,
                        BorderSizePixel = 0,
                        Text = "✕",
                        TextSize = 14,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = C.white,
                        [Children] = {
                            s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
                            s:New("UIStroke")({ Color = C.closeStroke, Thickness = 1.5, Transparency = 0.3 }),
                        },
                        [OnEvent("Activated")] = function()
                            state.panelOpen:set(false)
                        end,
                    }),
                },
            }),
            s:New("Frame")({
                Name = "Content",
                Size = UDim2.new(1, -8, 1, -46),
                Position = UDim2.new(0, 4, 0, 42),
                BackgroundTransparency = 1,
                [Children] = {
                    InventoryPanel.create(s, state),
                    UpgradesPanel.create(s, state),
                    StatsPanel.create(s, state),
                },
            }),
        },
    })
end

return MainPanel
