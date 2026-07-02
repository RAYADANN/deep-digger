--!strict
-- Переносимый модуль плавающих уведомлений (тосты).
-- Не зависит от конкретной игры.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local ViewportLayout = require(script.Parent.util.ViewportLayout)
local UiScreen = require(script.Parent.util.UiScreen)

export type NotifyOptions = {
    text: string,
    color: Color3?,
    duration: number?,
    icon: string?,
    oreId: string?,
}

local DEFAULT_COLOR = Color3.fromRGB(180, 130, 255)
local DEFAULT_DURATION = 2.5
local ICON_SIZE = 36

local Notification = {}

local stack: { Frame } = {}

local function ensureGui(): ScreenGui
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    return UiScreen.ensure(pg, "DeepDiggerNotifications", "toast")
end

local function resolveIconImage(options: NotifyOptions): string
    if options.oreId and options.oreId ~= "" then
        local ok, oreImage = pcall(function()
            local OreLookup = require(script.Parent.Parent.core.OreLookup)
            return OreLookup.getImage(options.oreId)
        end)
        if ok and typeof(oreImage) == "string" and oreImage ~= "" then
            return oreImage
        end
    end
    return UiAssets.resolve(options.icon)
end

local function relayout()
    local topBase = ViewportLayout.notificationStackTop()
    local rowStep = ViewportLayout.notificationRowStep()
    local toastW, _ = ViewportLayout.notificationSize()
    local halfW = math.floor(toastW * 0.5 + 0.5)
    for index, frame in ipairs(stack) do
        local targetY = topBase + (index - 1) * rowStep
        TweenService:Create(
            frame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad),
            { Position = UDim2.new(0.5, -halfW, 0, targetY) }
        ):Play()
    end
end

-- Пересчёт размеров уже показанных тостов при изменении вьюпорта (поворот/ресайз).
local function resizeStack()
    local toastW, toastH = ViewportLayout.notificationSize()
    local iconSize = ViewportLayout.px(ICON_SIZE)
    local textSize = ViewportLayout.textPx(18)
    for _, frame in ipairs(stack) do
        frame.Size = UDim2.fromOffset(toastW, toastH)
        local icon = frame:FindFirstChild("Icon")
        local hasIcon = icon ~= nil
        if icon and icon:IsA("ImageLabel") then
            icon.Size = UDim2.fromOffset(iconSize, iconSize)
            icon.Position = UDim2.new(0, ViewportLayout.px(12), 0.5, -iconSize / 2)
        end
        local label = frame:FindFirstChildWhichIsA("TextLabel")
        if label then
            label.Size = UDim2.new(1, hasIcon and -(iconSize + ViewportLayout.px(24)) or -ViewportLayout.px(16), 1, -ViewportLayout.px(8))
            label.Position = UDim2.new(0, hasIcon and (iconSize + ViewportLayout.px(20)) or ViewportLayout.px(8), 0, ViewportLayout.px(4))
            label.TextSize = textSize
        end
    end
    relayout()
end

local _subscribed = false
local function ensureSubscribed()
    if _subscribed then
        return
    end
    _subscribed = true
    ViewportLayout.subscribe(resizeStack)
end

function Notification.show(options: NotifyOptions)
    local gui = ensureGui()
    ensureSubscribed()
    local color = options.color or DEFAULT_COLOR
    local duration = options.duration or DEFAULT_DURATION
    local iconImage = resolveIconImage(options)
    local hasIcon = iconImage ~= ""

    local toastW, toastH = ViewportLayout.notificationSize()
    local iconSize = ViewportLayout.px(ICON_SIZE)
    local textSize = ViewportLayout.textPx(18)
    local halfW = math.floor(toastW * 0.5 + 0.5)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(toastW, toastH)
    frame.Position = UDim2.new(0.5, -halfW, 0, -toastH)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 30)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, ViewportLayout.px(12))
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = math.max(1, ViewportLayout.px(2))
    stroke.Transparency = 0.2
    stroke.Parent = frame

    if hasIcon then
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.fromOffset(iconSize, iconSize)
        icon.Position = UDim2.new(0, ViewportLayout.px(12), 0.5, -iconSize / 2)
        icon.BackgroundTransparency = 1
        icon.Image = iconImage
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = frame
    end

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, hasIcon and -(iconSize + ViewportLayout.px(24)) or -ViewportLayout.px(16), 1, -ViewportLayout.px(8))
    label.Position = UDim2.new(0, hasIcon and (iconSize + ViewportLayout.px(20)) or ViewportLayout.px(8), 0, ViewportLayout.px(4))
    label.BackgroundTransparency = 1
    label.Text = options.text
    label.Font = Enum.Font.GothamBold
    label.TextSize = textSize
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Parent = frame

    table.insert(stack, frame)
    relayout()

    task.delay(duration, function()
        local index = table.find(stack, frame)
        if index then
            table.remove(stack, index)
        end
        local curW, curH = ViewportLayout.notificationSize()
        local out = TweenService:Create(
            frame,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad),
            { Position = UDim2.new(0.5, -math.floor(curW * 0.5 + 0.5), 0, -curH) }
        )
        out:Play()
        out.Completed:Connect(function()
            frame:Destroy()
        end)
        relayout()
    end)
end

return Notification
