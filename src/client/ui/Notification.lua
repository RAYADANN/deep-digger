--!strict
-- Переносимый модуль плавающих уведомлений (тосты).
-- Не зависит от конкретной игры.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

export type NotifyOptions = {
    text: string,
    color: Color3?,
    duration: number?,
    icon: string?,
}

local DEFAULT_COLOR = Color3.fromRGB(180, 130, 255)
local DEFAULT_DURATION = 2.5

local Notification = {}

local stack: { Frame } = {}

local function ensureGui(): ScreenGui
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = pg:FindFirstChild("DeepDiggerNotifications")
    if gui then
        return gui :: ScreenGui
    end

    local newGui = Instance.new("ScreenGui")
    newGui.Name = "DeepDiggerNotifications"
    newGui.ResetOnSpawn = false
    newGui.IgnoreGuiInset = true
    newGui.DisplayOrder = 100
    newGui.Parent = pg
    return newGui
end

local function relayout()
    for index, frame in ipairs(stack) do
        local targetY = 60 + (index - 1) * 80
        TweenService:Create(
            frame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad),
            { Position = UDim2.new(0.5, -180, 0, targetY) }
        ):Play()
    end
end

function Notification.show(options: NotifyOptions)
    local gui = ensureGui()
    local color = options.color or DEFAULT_COLOR
    local duration = options.duration or DEFAULT_DURATION
    local prefix = if options.icon then options.icon .. "  " else ""

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(360, 70)
    frame.Position = UDim2.new(0.5, -180, 0, -80)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 30)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 2
    stroke.Transparency = 0.2
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = prefix .. options.text
    label.Font = Enum.Font.GothamBold
    label.TextSize = 20
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextWrapped = true
    label.Parent = frame

    table.insert(stack, frame)
    relayout()

    task.delay(duration, function()
        local index = table.find(stack, frame)
        if index then
            table.remove(stack, index)
        end
        local out = TweenService:Create(
            frame,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad),
            { Position = UDim2.new(0.5, -180, 0, -90) }
        )
        out:Play()
        out.Completed:Connect(function()
            frame:Destroy()
        end)
        relayout()
    end)
end

return Notification
