--!strict
-- TutorialArrow.lua — Phase 8.
--
-- Подсветка / стрелка на нужный элемент. Универсальный helper для
-- туториала и любых будущих подсказок (например, ребёрт-prompt).
--
-- API:
--   local handle = TutorialArrow.pointAt(target, text)
--   handle:destroy()
--
--   target = GuiObject     → пульсирующий золотой UIStroke + label сбоку.
--   target = BasePart      → BillboardGui ⬇ с bounce-tween над блоком.
--   target = nil           → возвращается no-op handle (ничего не рисуем).
--
-- Конвенции:
--   * Всё живёт в одном ScreenGui `DeepDigger_Tutorial`, чтобы не плодить
--     гуи и не конфликтовать с HUD.
--   * `Active = false` на оверлеях → клик через стрелку доходит до цели.
--   * Pulse / bounce — `RepeatCount = -1, Reverses = true`. Закрытие
--     handle:destroy() гарантирует, что Tween остановлен, Instance удалены,
--     RunService-конекшнов после нас не остаётся.
--   * Для GuiObject стрелка живёт «прилипшей» к target через RenderStepped:
--     цель может двигаться (например, MainPanel то open/close), оверлей
--     должен ехать за ней.
--   * Для BasePart мы не следим за движением (блоки в нашем рендере
--     анкорные, не двигаются). Это упрощает реализацию.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local TUTORIAL_GUI_NAME = "DeepDigger_Tutorial"
local GOLD = Color3.fromRGB(255, 210, 50)
local GOLD_DARK = Color3.fromRGB(180, 130, 20)
local PULSE_THIN = 1.5
local PULSE_THICK = 3.5
local PULSE_DURATION = 0.55

local TutorialArrow = {}

export type Handle = {
    destroy: (self: Handle) -> (),
}

local function ensureGui(): ScreenGui
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = pg:FindFirstChild(TUTORIAL_GUI_NAME)
    if gui then
        return gui :: ScreenGui
    end
    local newGui = Instance.new("ScreenGui")
    newGui.Name = TUTORIAL_GUI_NAME
    newGui.ResetOnSpawn = false
    newGui.IgnoreGuiInset = true
    newGui.DisplayOrder = 80 -- ниже Tooltip (90) и Notifications (100), выше HUD (20)
    newGui.Parent = pg
    return newGui
end

local function makeHandle(): Handle
    return {
        destroy = function(_self: Handle) end,
    }
end

local function pointAtGui(target: GuiObject, text: string): Handle
    local gui = ensureGui()

    local overlay = Instance.new("Frame")
    overlay.Name = "TutorialOverlay"
    overlay.BackgroundColor3 = GOLD
    overlay.BackgroundTransparency = 0.85
    overlay.BorderSizePixel = 0
    overlay.Active = false
    overlay.ZIndex = 5
    overlay.Size = UDim2.fromOffset(target.AbsoluteSize.X + 8, target.AbsoluteSize.Y + 8)
    overlay.Position = UDim2.fromOffset(target.AbsolutePosition.X - 4, target.AbsolutePosition.Y - 4)
    overlay.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = overlay

    local stroke = Instance.new("UIStroke")
    stroke.Color = GOLD
    stroke.Thickness = PULSE_THIN
    stroke.Transparency = 0
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = overlay

    -- Подсказывающий label рядом с подсветкой.
    local labelFrame = Instance.new("Frame")
    labelFrame.Name = "Label"
    labelFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
    labelFrame.BackgroundTransparency = 0.05
    labelFrame.BorderSizePixel = 0
    labelFrame.Active = false
    labelFrame.ZIndex = 6
    labelFrame.AutomaticSize = Enum.AutomaticSize.XY
    labelFrame.Size = UDim2.fromOffset(0, 0)
    labelFrame.Parent = gui

    Instance.new("UICorner", labelFrame).CornerRadius = UDim.new(0, 8)
    local lblStroke = Instance.new("UIStroke")
    lblStroke.Color = GOLD
    lblStroke.Thickness = 2
    lblStroke.Transparency = 0.1
    lblStroke.Parent = labelFrame

    local lblPad = Instance.new("UIPadding")
    lblPad.PaddingTop = UDim.new(0, 8)
    lblPad.PaddingBottom = UDim.new(0, 8)
    lblPad.PaddingLeft = UDim.new(0, 12)
    lblPad.PaddingRight = UDim.new(0, 12)
    lblPad.Parent = labelFrame

    local labelText = Instance.new("TextLabel")
    labelText.BackgroundTransparency = 1
    labelText.AutomaticSize = Enum.AutomaticSize.XY
    labelText.Size = UDim2.fromOffset(0, 0)
    labelText.Font = Enum.Font.GothamBold
    labelText.TextSize = 16
    labelText.TextColor3 = Color3.fromRGB(255, 240, 200)
    labelText.TextXAlignment = Enum.TextXAlignment.Left
    labelText.RichText = true
    labelText.Text = "▶  " .. text
    labelText.Parent = labelFrame

    -- Pulse stroke thickness через TweenService — Reverses = true даёт
    -- симметричный «дышащий» эффект.
    local pulseTween = TweenService:Create(
        stroke,
        TweenInfo.new(PULSE_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Thickness = PULSE_THICK }
    )
    pulseTween:Play()

    -- Следим за позицией / размером target: HUD может скрываться
    -- (panelOpen=false → target вне экрана) или анимировать размер.
    local renderConn: RBXScriptConnection
    renderConn = RunService.RenderStepped:Connect(function()
        if not target.Parent then
            overlay.Visible = false
            labelFrame.Visible = false
            return
        end
        local size = target.AbsoluteSize
        local pos = target.AbsolutePosition
        if size.X <= 0 or size.Y <= 0 then
            overlay.Visible = false
            labelFrame.Visible = false
            return
        end
        overlay.Visible = true
        labelFrame.Visible = true
        overlay.Size = UDim2.fromOffset(size.X + 8, size.Y + 8)
        overlay.Position = UDim2.fromOffset(pos.X - 4, pos.Y - 4)

        -- Размещаем label: справа от элемента, если хватает места,
        -- иначе снизу под подсветкой.
        local camera = workspace.CurrentCamera
        local viewport = if camera then camera.ViewportSize else Vector2.new(1024, 768)
        local lblSize = labelFrame.AbsoluteSize
        if lblSize.X < 10 then
            lblSize = Vector2.new(160, 36)
        end
        local lx = pos.X + size.X + 12
        local ly = pos.Y + size.Y / 2 - lblSize.Y / 2
        if lx + lblSize.X > viewport.X - 8 then
            lx = pos.X + size.X / 2 - lblSize.X / 2
            ly = pos.Y - lblSize.Y - 12
            if ly < 8 then
                ly = pos.Y + size.Y + 12
            end
        end
        lx = math.clamp(lx, 8, viewport.X - lblSize.X - 8)
        ly = math.clamp(ly, 8, viewport.Y - lblSize.Y - 8)
        labelFrame.Position = UDim2.fromOffset(math.floor(lx), math.floor(ly))
    end)

    local destroyed = false
    return {
        destroy = function(_self: Handle)
            if destroyed then return end
            destroyed = true
            if renderConn then renderConn:Disconnect() end
            pulseTween:Cancel()
            overlay:Destroy()
            labelFrame:Destroy()
        end,
    }
end

local function pointAtPart(target: BasePart, text: string): Handle
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "TutorialArrow"
    billboard.Size = UDim2.fromOffset(220, 140)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 500
    billboard.Adornee = target
    billboard.Parent = target

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(1, 0, 0, 70)
    arrow.Position = UDim2.fromOffset(0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "⬇"
    arrow.Font = Enum.Font.GothamBlack
    arrow.TextSize = 56
    arrow.TextColor3 = GOLD
    arrow.TextStrokeColor3 = GOLD_DARK
    arrow.TextStrokeTransparency = 0
    arrow.Parent = billboard

    local labelBg = Instance.new("Frame")
    labelBg.Size = UDim2.new(1, -20, 0, 50)
    labelBg.Position = UDim2.new(0, 10, 0, 76)
    labelBg.BackgroundColor3 = Color3.fromRGB(15, 15, 28)
    labelBg.BackgroundTransparency = 0.05
    labelBg.BorderSizePixel = 0
    labelBg.Parent = billboard
    Instance.new("UICorner", labelBg).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", labelBg)
    stroke.Color = GOLD
    stroke.Thickness = 2

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamBold
    label.TextSize = 18
    label.TextColor3 = Color3.fromRGB(255, 240, 200)
    label.TextWrapped = true
    label.Parent = labelBg

    -- Bounce-tween по StudsOffset.Y — эмулирует подскакивающую стрелку.
    local baseOffset = billboard.StudsOffset
    local bounceTween = TweenService:Create(
        billboard,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
        { StudsOffset = baseOffset + Vector3.new(0, 0.6, 0) }
    )
    bounceTween:Play()

    local destroyed = false
    return {
        destroy = function(_self: Handle)
            if destroyed then return end
            destroyed = true
            bounceTween:Cancel()
            billboard:Destroy()
        end,
    }
end

function TutorialArrow.pointAt(target: any, text: string): Handle
    if typeof(target) ~= "Instance" then
        return makeHandle()
    end
    if target:IsA("GuiObject") then
        return pointAtGui(target :: GuiObject, text)
    end
    if target:IsA("BasePart") then
        return pointAtPart(target :: BasePart, text)
    end
    return makeHandle()
end

return TutorialArrow
