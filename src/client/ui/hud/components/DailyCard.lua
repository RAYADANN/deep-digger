--!strict
-- DailyCard.lua — Phase 10.
--
-- Одна карточка дневной награды в DailyRewardModal. Состав:
--   * Шапка: «День N» + ✓ если прошлый, glow-pulse если текущий, серое если будущий.
--   * Иконка типа награды (💰 / ⚡).
--   * Лейбл «+500 монет».
--   * Цветная UIStroke по rarity (common серый / mythic золотой).
--
-- Состояния (state-машина):
--   "past"    — claim'нул в одном из прошлых дней. Show ✓, темнее.
--   "current" — claim сегодня (selected при открытии модала, pulse-glow).
--   "future"  — будущий день. Greyed, без интерактивности.
--
-- Размер фиксированный 100×140 для desktop, рассчитан под grid 4 на ряд +
-- gap 10 — 4*100 + 3*10 = 430 px. Mobile UIListLayout сам разложит вертикально.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local DailyRewardDatabase = require(ReplicatedStorage:WaitForChild("shared").data.DailyRewardDatabase)

local Children = Fusion.Children
local C = theme.C

-- RARITY → border-color. Соответствует Constants.RARITY_COLORS, но дублируем
-- здесь со стрижкой под тему HUD (theme.RARITY_COLOR).
local RARITY_COLOR = theme.RARITY_COLOR

export type CardState = "past" | "current" | "future"

export type Props = {
    cycleDay: number,
    state: CardState,
    layoutOrder: number?,
}

local DailyCard = {}

function DailyCard.create(s: ScopeFactory.HudScope, props: Props)
    local reward = DailyRewardDatabase.get(props.cycleDay)
    if not reward then
        -- Защита от мисконфига — рендерим пустую заглушку.
        return s:New("Frame")({
            Size = UDim2.fromOffset(100, 140),
            BackgroundTransparency = 1,
        })
    end
    local stateName = props.state
    local rarityColor = RARITY_COLOR[reward.rarity] or C.common
    local icon = DailyRewardDatabase.iconFor(reward)

    -- Pulse-glow: для current-карточки тwen stroke.Transparency 0.1↔0.5
    -- через TweenService. Не yield'ит — Tween бесконечно, очищается при
    -- разрушении ScreenGui.
    local stroke = s:New("UIStroke")({
        Color = rarityColor,
        Thickness = if stateName == "current" then 3 else 1.5,
        Transparency = if stateName == "future" then 0.7 else 0.1,
    })

    local cardBg
    if stateName == "future" then
        cardBg = Color3.fromRGB(28, 28, 38)
    elseif stateName == "past" then
        cardBg = Color3.fromRGB(40, 40, 55)
    else
        cardBg = C.btnBg
    end

    return s:New("Frame")({
        Name = "DailyCard_" .. tostring(props.cycleDay),
        Size = UDim2.fromOffset(100, 140),
        BackgroundColor3 = cardBg,
        BackgroundTransparency = if stateName == "future" then 0.3 else 0.1,
        BorderSizePixel = 0,
        LayoutOrder = props.layoutOrder or props.cycleDay,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
            stroke,
            -- Шапка «День N»
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, 18),
                Position = UDim2.new(0, 0, 0, 6),
                BackgroundTransparency = 1,
                Text = ("День %d"):format(props.cycleDay),
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextColor3 = if stateName == "current" then C.gold else C.textLabel,
            }),
            -- ✓ для past дней (поверх иконки)
            s:New("TextLabel")({
                Size = UDim2.fromOffset(28, 28),
                Position = UDim2.new(0.5, -14, 0.5, -28),
                BackgroundTransparency = 1,
                Text = if stateName == "past" then "✓" else "",
                TextSize = 36,
                Font = Enum.Font.GothamBlack,
                TextColor3 = Color3.fromRGB(140, 255, 140),
                Visible = stateName == "past",
            }),
            -- Иконка типа награды
            s:New("TextLabel")({
                Size = UDim2.fromOffset(40, 40),
                Position = UDim2.new(0.5, -20, 0.5, -28),
                BackgroundTransparency = 1,
                Text = icon,
                TextScaled = true,
                Font = Enum.Font.GothamBold,
                TextColor3 = if stateName == "future" then C.textMuted else C.gold,
                Visible = stateName ~= "past",
            }),
            -- Текст награды
            s:New("TextLabel")({
                Size = UDim2.new(1, -8, 0, 36),
                Position = UDim2.new(0, 4, 1, -44),
                BackgroundTransparency = 1,
                Text = reward.label,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextColor3 = if stateName == "future" then C.textMuted else C.textMain,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
            }),
        },
    })
end

--[[
    Запускает pulse-glow tween на UIStroke. Возвращает функцию stop().
    Используется только для current-карточки (одна на модал).
]]
function DailyCard.startPulse(stroke: UIStroke): () -> ()
    if not stroke or not stroke:IsA("UIStroke") then
        return function() end
    end
    local running = true
    task.spawn(function()
        local goingUp = false
        while running and stroke.Parent do
            local target = goingUp and 0.1 or 0.5
            local tween = TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Transparency = target,
            })
            tween:Play()
            tween.Completed:Wait()
            goingUp = not goingUp
        end
    end)
    return function()
        running = false
    end
end

return DailyCard
