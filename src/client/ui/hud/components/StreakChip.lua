--!strict
-- StreakChip.lua — Phase 10.
--
-- Маленький чип «🔥 N дней» в TopBar справа. Visible только при streak >= 2
-- (чтобы новичок не видел «🔥 0»). Опциональный (не критическая часть HUD).
--
-- Совместим с TopBar: принимает position UDim2 (TopBar решает где разместить).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)

local Children = Fusion.Children
local C = theme.C

local StreakChip = {}

function StreakChip.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState, position: UDim2?)
    return s:New("Frame")({
        Name = "StreakChip",
        Size = UDim2.new(0, 80, 0, 22),
        Position = position or UDim2.new(0, 0, 0, 110),
        BackgroundColor3 = Color3.fromRGB(50, 25, 10),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Visible = s:Computed(function(use)
            return (use(state.dailyStreak) or 0) >= 2
        end),
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
            s:New("UIStroke")({
                Color = Color3.fromRGB(255, 140, 60),
                Thickness = 1,
                Transparency = 0.5,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -8, 1, 0),
                Position = UDim2.new(0, 4, 0, 0),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    return ("🔥 %d дн."):format(math.floor(use(state.dailyStreak) or 0))
                end),
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.fromRGB(255, 180, 90),
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        },
    })
end

return StreakChip
