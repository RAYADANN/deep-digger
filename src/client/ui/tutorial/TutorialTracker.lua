--!strict
-- TutorialTracker.lua — Phase 8 polish.
--
-- Квест-трекер в правой части экрана. Раскладка:
--
--   ┌─────────────────────────────────┐
--   │ 📜 Задание 1 из 3               │
--   │ Добыть руду                     │
--   │ [█████░░░░░] 0 / 1              │
--   └─────────────────────────────────┘
--
-- Появляется при `show(opts)`, обновляется через `update(opts)` или
-- `setProgress(current, goal)`. При `complete()` проигрывает галочку и
-- автоматически прячется. `destroy()` мгновенно убирает.
--
-- API:
--   local handle = TutorialTracker.show({
--       title = "Задание 1 из 3",
--       description = "Добыть руду",
--       goal = 1,                          -- nil = без progress bar
--       icon = "📜",                       -- emoji слева
--   })
--   handle:setProgress(current, goal)
--   handle:update({...})
--   handle:complete()                      -- анимация ✓ + auto-hide
--   handle:destroy()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local TUTORIAL_GUI_NAME = "DeepDigger_Tutorial"
local GOLD = Color3.fromRGB(255, 210, 50)
local GREEN = Color3.fromRGB(100, 220, 100)

local TutorialTracker = {}

export type Options = {
    title: string,
    description: string,
    goal: number?,
    icon: string?,
}

export type Handle = {
    update: (self: Handle, opts: Options) -> (),
    setProgress: (self: Handle, current: number, goal: number?) -> (),
    complete: (self: Handle) -> (),
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
    newGui.DisplayOrder = 80
    newGui.Parent = pg
    return newGui
end

local function buildFrame(): {
    root: Frame,
    icon: TextLabel,
    title: TextLabel,
    description: TextLabel,
    progressBg: Frame,
    progressFill: Frame,
    progressText: TextLabel,
    checkmark: TextLabel,
    stroke: UIStroke,
}
    local root = Instance.new("Frame")
    root.Name = "TutorialTracker"
    root.Size = UDim2.fromOffset(280, 96)
    root.AnchorPoint = Vector2.new(1, 0)
    -- Стартовая позиция: за правым краем, прилетит влево.
    root.Position = UDim2.new(1, 320, 0, 110)
    root.BackgroundColor3 = Color3.fromRGB(14, 14, 28)
    root.BackgroundTransparency = 0.1
    root.BorderSizePixel = 0
    root.ZIndex = 9
    root.Active = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = root

    local stroke = Instance.new("UIStroke")
    stroke.Color = GOLD
    stroke.Thickness = 2
    stroke.Transparency = 0.15
    stroke.Parent = root

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.fromOffset(28, 28)
    icon.Position = UDim2.fromOffset(10, 8)
    icon.BackgroundTransparency = 1
    icon.Font = Enum.Font.GothamBlack
    icon.TextSize = 22
    icon.Text = "📜"
    icon.TextColor3 = GOLD
    icon.ZIndex = 10
    icon.Parent = root

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -50, 0, 22)
    title.Position = UDim2.fromOffset(40, 10)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 13
    title.TextColor3 = GOLD
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = ""
    title.ZIndex = 10
    title.Parent = root

    local description = Instance.new("TextLabel")
    description.Size = UDim2.new(1, -20, 0, 22)
    description.Position = UDim2.fromOffset(10, 34)
    description.BackgroundTransparency = 1
    description.Font = Enum.Font.GothamBold
    description.TextSize = 15
    description.TextColor3 = Color3.fromRGB(240, 235, 220)
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.Text = ""
    description.ZIndex = 10
    description.Parent = root

    -- ===== Progress bar =====
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBg"
    progressBg.Size = UDim2.new(1, -100, 0, 10)
    progressBg.Position = UDim2.fromOffset(10, 68)
    progressBg.BackgroundColor3 = Color3.fromRGB(28, 28, 50)
    progressBg.BorderSizePixel = 0
    progressBg.ZIndex = 10
    progressBg.Visible = false
    progressBg.Parent = root

    local pbgCorner = Instance.new("UICorner")
    pbgCorner.CornerRadius = UDim.new(1, 0)
    pbgCorner.Parent = progressBg

    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.fromScale(0, 1)
    progressFill.BackgroundColor3 = GOLD
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 11
    progressFill.Parent = progressBg

    local pfillCorner = Instance.new("UICorner")
    pfillCorner.CornerRadius = UDim.new(1, 0)
    pfillCorner.Parent = progressFill

    local progressText = Instance.new("TextLabel")
    progressText.Size = UDim2.fromOffset(80, 14)
    progressText.AnchorPoint = Vector2.new(1, 0)
    progressText.Position = UDim2.new(1, -10, 0, 66)
    progressText.BackgroundTransparency = 1
    progressText.Font = Enum.Font.GothamBold
    progressText.TextSize = 12
    progressText.TextColor3 = GOLD
    progressText.TextXAlignment = Enum.TextXAlignment.Right
    progressText.Text = ""
    progressText.ZIndex = 10
    progressText.Visible = false
    progressText.Parent = root

    -- ===== Checkmark (показывается при complete) =====
    local checkmark = Instance.new("TextLabel")
    checkmark.Size = UDim2.fromOffset(40, 40)
    checkmark.AnchorPoint = Vector2.new(1, 0.5)
    checkmark.Position = UDim2.new(1, -10, 0.5, 0)
    checkmark.BackgroundTransparency = 1
    checkmark.Font = Enum.Font.GothamBlack
    checkmark.TextSize = 28
    checkmark.TextColor3 = GREEN
    checkmark.Text = "✓"
    checkmark.ZIndex = 12
    checkmark.Visible = false
    checkmark.Parent = root

    return {
        root = root,
        icon = icon,
        title = title,
        description = description,
        progressBg = progressBg,
        progressFill = progressFill,
        progressText = progressText,
        checkmark = checkmark,
        stroke = stroke,
    }
end

local function applyOptions(state: any, opts: Options)
    local parts = state.parts
    parts.title.Text = opts.title or ""
    parts.description.Text = opts.description or ""
    parts.icon.Text = opts.icon or "📜"

    if opts.goal and opts.goal > 0 then
        state.goal = opts.goal
        state.current = math.min(state.current or 0, opts.goal)
        parts.progressBg.Visible = true
        parts.progressText.Visible = true
        parts.progressFill.Size = UDim2.fromScale(state.current / opts.goal, 1)
        parts.progressText.Text = string.format("%d / %d", state.current, opts.goal)
    else
        state.goal = nil
        parts.progressBg.Visible = false
        parts.progressText.Visible = false
    end
end

function TutorialTracker.show(opts: Options): Handle
    local gui = ensureGui()
    local parts = buildFrame()
    parts.root.Parent = gui

    local state: any = {
        parts = parts,
        destroyed = false,
        completed = false,
        current = 0,
        goal = nil,
    }

    -- Slide-in справа.
    parts.root.Position = UDim2.new(1, 320, 0, 110)
    TweenService:Create(
        parts.root,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(1, -20, 0, 110) }
    ):Play()

    applyOptions(state, opts)

    local handle: Handle = {} :: any

    function handle:update(newOpts: Options)
        if state.destroyed then return end
        applyOptions(state, newOpts)
    end

    function handle:setProgress(current: number, goal: number?)
        if state.destroyed or state.completed then return end
        if goal then state.goal = goal end
        state.current = math.max(0, math.min(current, state.goal or current))
        local g = state.goal
        if g and g > 0 then
            parts.progressBg.Visible = true
            parts.progressText.Visible = true
            local tween = TweenService:Create(
                parts.progressFill,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.fromScale(state.current / g, 1) }
            )
            tween:Play()
            parts.progressText.Text = string.format("%d / %d", state.current, g)
        end
    end

    function handle:complete()
        if state.destroyed or state.completed then return end
        state.completed = true
        -- Заполняем progress bar до конца.
        if state.goal and state.goal > 0 then
            TweenService:Create(
                parts.progressFill,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN }
            ):Play()
            parts.progressText.Text = string.format("%d / %d", state.goal, state.goal)
            parts.progressText.TextColor3 = GREEN
        end
        -- Меняем цвет рамки и иконки на зелёный.
        TweenService:Create(parts.stroke, TweenInfo.new(0.2), { Color = GREEN }):Play()
        parts.title.TextColor3 = GREEN
        parts.icon.TextColor3 = GREEN
        -- Показываем checkmark.
        parts.checkmark.Visible = true
        parts.checkmark.TextTransparency = 1
        parts.checkmark.Size = UDim2.fromOffset(20, 20)
        local checkTween = TweenService:Create(
            parts.checkmark,
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Size = UDim2.fromOffset(40, 40), TextTransparency = 0 }
        )
        checkTween:Play()
        -- Через 1.4 сек прячем трекер.
        task.delay(1.4, function()
            if not state.destroyed then
                handle:destroy()
            end
        end)
    end

    function handle:destroy()
        if state.destroyed then return end
        state.destroyed = true
        local root = parts.root
        local slideOut = TweenService:Create(
            root,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(1, 320, 0, 110), BackgroundTransparency = 1 }
        )
        slideOut:Play()
        slideOut.Completed:Connect(function()
            if root.Parent then
                root:Destroy()
            end
        end)
    end

    return handle
end

return TutorialTracker
