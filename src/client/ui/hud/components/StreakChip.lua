--!strict
-- StreakChip.lua — Phase 10.
--
-- Маленький чип «N дней» со streak-иконкой в TopBar справа.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local Children = Fusion.Children
local C = theme.C
local ICON = theme.ICON

local StreakChip = {}

-- Дизайн-эталон чипа; всё внутри — scale-based, тянется от высоты строки.
local DESIGN_W = 80
local DESIGN_H = 22

-- `heightVal` — Fusion-значение высоты статус-строки (см. CurrencyRibbon).
function StreakChip.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState, heightVal: any?)
    local H = heightVal
    if not H then
        H = s:Value(DESIGN_H)
    end

    return s:New("Frame")({
        Name = "StreakChip",
        Size = s:Computed(function(use)
            local h = use(H)
            return UDim2.fromOffset(math.floor(DESIGN_W * h / DESIGN_H + 0.5), h)
        end),
        BackgroundColor3 = Color3.fromRGB(50, 25, 10),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Visible = s:Computed(function(use)
            return (use(state.dailyStreak) or 0) >= 2
        end),
        [Children] = {
            s:New("UICorner")({ CornerRadius = theme.RADIUS.chip }),
            s:New("UIStroke")({
                Color = Color3.fromRGB(255, 140, 60),
                Thickness = theme.STROKE.medium,
                Transparency = 0.5,
            }),
            s:New("ImageLabel")({
                Size = UDim2.fromScale(14 / DESIGN_W, 14 / DESIGN_H),
                Position = UDim2.fromScale(4 / DESIGN_W, 0.5),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Image = UiAssets.image("icon_streak"),
                ImageColor3 = ICON.tint,
                ScaleType = Enum.ScaleType.Fit,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1 - 22 / DESIGN_W, 0, 1, 0),
                Position = UDim2.fromScale(20 / DESIGN_W, 0),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    return ("%d дн."):format(math.floor(use(state.dailyStreak) or 0))
                end),
                TextSize = s:Computed(function(use)
                    return math.max(8, math.floor(12 * use(H) / DESIGN_H + 0.5))
                end),
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.fromRGB(255, 180, 90),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),
        },
    })
end

return StreakChip
