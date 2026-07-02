--!strict
-- DailyCard.lua — Phase 10.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local DailyRewardDatabase = require(ReplicatedStorage:WaitForChild("shared").data.DailyRewardDatabase)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local Children = Fusion.Children
local C = theme.C
local ICON = theme.ICON

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
        return s:New("Frame")({
            Size = UDim2.fromOffset(100, 140),
            BackgroundTransparency = 1,
        })
    end
    local stateName = props.state
    local rarityColor = RARITY_COLOR[reward.rarity] or C.common
    local iconKey = DailyRewardDatabase.iconFor(reward)
    local rewardImage = UiAssets.resolve(iconKey)

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
        BackgroundTransparency = if stateName == "future" then 0.35 else 0,
        BorderSizePixel = 0,
        LayoutOrder = props.layoutOrder or props.cycleDay,
        ZIndex = 4,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
            stroke,
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, 18),
                Position = UDim2.new(0, 0, 0, 6),
                BackgroundTransparency = 1,
                Text = ("День %d"):format(props.cycleDay),
                TextSize = 14,
                Font = Enum.Font.GothamBold,
                TextColor3 = if stateName == "current" then C.gold else C.textLabel,
                ZIndex = 2,
            }),
            if stateName == "past"
                then s:New("ImageLabel")({
                    Size = UDim2.fromOffset(32, 32),
                    Position = UDim2.new(0.5, -16, 0.5, -28),
                    BackgroundTransparency = 1,
                    Image = UiAssets.image("icon_check"),
                    ImageColor3 = ICON.tint,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 3,
                })
                else s:New("ImageLabel")({
                    Size = UDim2.fromOffset(40, 40),
                    Position = UDim2.new(0.5, -20, 0.5, -28),
                    BackgroundTransparency = 1,
                    Image = rewardImage,
                    ImageColor3 = ICON.tint,
                    ImageTransparency = if stateName == "future" then ICON.mutedAlpha else 0,
                    ScaleType = Enum.ScaleType.Fit,
                    ZIndex = 2,
                }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -8, 0, 36),
                Position = UDim2.new(0, 4, 1, -44),
                BackgroundTransparency = 1,
                Text = reward.label,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextColor3 = if stateName == "future" then C.textMuted else C.textMain,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 2,
            }),
        },
    })
end

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
