--!strict
-- TutorialDialog.lua — Phase 8 polish.
--
-- Боттом-центр диалоговое окно «наставника». Раскладка:
--
--   ┌──────────────────────────────────────────────┐
--   │ ╭───╮  Шахтёр Бородач                        │
--   │ │⛏️ │  Видишь блок? Кликни по нему!          │
--   │ ╰───╯                                        │
--   │                            [ Понятно ✓ ] [✕] │
--   └──────────────────────────────────────────────┘
--
-- API:
--   local handle = TutorialDialog.show({
--       speaker = "⛏️",
--       name = "Шахтёр Бородач",
--       text = "Привет!",
--       kind = "intro" | "task" | "success" | "finale",
--       onAdvance = function() end,    -- клик [Понятно ✓]
--       onSkip = function() end,       -- клик [✕]
--       hideAdvanceButton = false,     -- спрятать [Понятно ✓]
--   })
--   handle:update(opts)
--   handle:destroy()
--
-- Эффекты:
--   * Slide-in снизу + fade-in (TweenService, 0.25с Quad/Out).
--   * Typewriter: текст печатается посимвольно (~40 chars/sec). Клик
--     где угодно на диалоге → мгновенно дописать весь текст (skip typing).
--   * Цвет рамки зависит от `kind`: intro=gold, task=blue, success=green,
--     finale=mythic.
--   * `Active = false` снаружи диалога — модал НЕ блокирует геймплей,
--     игрок может одновременно кликать по блокам.
--   * При destroy → slide-out + fade-out + Destroy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local ViewportLayout = require(script.Parent.Parent.util.ViewportLayout)
local UiScreen = require(script.Parent.Parent.util.UiScreen)

local px = ViewportLayout.px

local TUTORIAL_GUI_NAME = "DeepDigger_Tutorial"
local TYPE_SPEED_CHARS_PER_SEC = 42

local KIND_COLORS = {
    intro = Color3.fromRGB(255, 210, 50),     -- gold
    task = Color3.fromRGB(80, 200, 255),      -- cyan
    success = Color3.fromRGB(100, 220, 100),  -- green
    finale = Color3.fromRGB(220, 120, 255),   -- mythic
}
local DEFAULT_COLOR = KIND_COLORS.intro
local DIALOG_H = 118

local function dialogHeight(): number
    return ViewportLayout.px(DIALOG_H)
end

local function dialogWidth(): number
    local maxW = math.floor(ViewportLayout.playableWidth() * 0.92 + 0.5)
    return math.clamp(maxW, ViewportLayout.px(260), ViewportLayout.px(560))
end

local function dialogRestY(): number
    return -ViewportLayout.bottomChromeInset() - 8
end

local TutorialDialog = {}

export type Options = {
    speaker: string,
    name: string,
    text: string,
    kind: string?,
    onAdvance: (() -> ())?,
    onSkip: (() -> ())?,
    hideAdvanceButton: boolean?,
}

export type Handle = {
    update: (self: Handle, opts: Options) -> (),
    destroy: (self: Handle) -> (),
}

local function ensureGui(): ScreenGui
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    return UiScreen.ensure(pg, TUTORIAL_GUI_NAME, "tutorial")
end

local function colorFor(kind: string?): Color3
    if kind and KIND_COLORS[kind] then
        return KIND_COLORS[kind]
    end
    return DEFAULT_COLOR
end

local function buildFrame(): {
    root: Frame,
    avatar: ImageLabel,
    avatarRing: UIStroke,
    nameLabel: TextLabel,
    textLabel: TextLabel,
    advanceBtn: TextButton,
    skipBtn: TextButton,
    stroke: UIStroke,
    contentClick: TextButton,
}
    local root = Instance.new("Frame")
    root.Name = "TutorialDialog"
    root.Size = UDim2.fromOffset(dialogWidth(), dialogHeight())
    root.AnchorPoint = Vector2.new(0.5, 1)
    root.Position = UDim2.new(0.5, 0, 1, 200)
    root.BackgroundColor3 = Color3.fromRGB(14, 14, 28)
    root.BackgroundTransparency = 0.08
    root.BorderSizePixel = 0
    root.ZIndex = 10
    root.Active = false

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, px(14))
    corner.Parent = root

    local stroke = Instance.new("UIStroke")
    stroke.Color = DEFAULT_COLOR
    stroke.Thickness = math.max(1, px(2.5))
    stroke.Transparency = 0.1
    stroke.Parent = root

    -- Невидимая кнопка-перехватчик на всё окно — клик мгновенно
    -- дописывает typewriter. ZIndex выше label, но ниже advance/skip.
    local contentClick = Instance.new("TextButton")
    contentClick.Name = "ContentClick"
    contentClick.Size = UDim2.fromScale(1, 1)
    contentClick.BackgroundTransparency = 1
    contentClick.Text = ""
    contentClick.AutoButtonColor = false
    contentClick.ZIndex = 11
    contentClick.Parent = root

    -- ===== Avatar (левая колонка) =====
    local avatarFrame = Instance.new("Frame")
    avatarFrame.Size = UDim2.fromOffset(px(86), px(86))
    avatarFrame.Position = UDim2.fromOffset(px(14), px(14))
    avatarFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 50)
    avatarFrame.BorderSizePixel = 0
    avatarFrame.ZIndex = 12
    avatarFrame.Active = false
    avatarFrame.Parent = root

    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(1, 0)
    avatarCorner.Parent = avatarFrame

    local avatarRing = Instance.new("UIStroke")
    avatarRing.Color = DEFAULT_COLOR
    avatarRing.Thickness = math.max(1, px(3))
    avatarRing.Transparency = 0
    avatarRing.Parent = avatarFrame

    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.fromScale(1, 1)
    avatar.BackgroundTransparency = 1
    avatar.Image = UiAssets.image("upg_pickaxe")
    avatar.ScaleType = Enum.ScaleType.Fit
    avatar.ZIndex = 13
    avatar.Parent = avatarFrame

    -- ===== Текстовая колонка =====
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -px(130), 0, px(22))
    nameLabel.Position = UDim2.fromOffset(px(112), px(16))
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextSize = ViewportLayout.textPx(16)
    nameLabel.TextColor3 = DEFAULT_COLOR
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = ""
    nameLabel.ZIndex = 12
    nameLabel.Parent = root

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -px(130), 0, px(70))
    textLabel.Position = UDim2.fromOffset(px(112), px(42))
    textLabel.BackgroundTransparency = 1
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = ViewportLayout.textPx(15)
    textLabel.TextColor3 = Color3.fromRGB(232, 230, 220)
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Top
    textLabel.TextWrapped = true
    textLabel.RichText = true
    textLabel.Text = ""
    textLabel.ZIndex = 12
    textLabel.Parent = root

    -- ===== Кнопки =====
    local advanceBtn = Instance.new("TextButton")
    advanceBtn.Size = UDim2.fromOffset(px(140), px(30))
    advanceBtn.AnchorPoint = Vector2.new(1, 1)
    advanceBtn.Position = UDim2.new(1, -px(54), 1, -px(12))
    advanceBtn.BackgroundColor3 = DEFAULT_COLOR
    advanceBtn.BorderSizePixel = 0
    advanceBtn.Text = "Понятно"
    advanceBtn.Font = Enum.Font.GothamBold
    advanceBtn.TextSize = ViewportLayout.textPx(14)
    advanceBtn.TextColor3 = Color3.fromRGB(20, 20, 36)
    advanceBtn.AutoButtonColor = true
    advanceBtn.ZIndex = 14
    advanceBtn.Active = true
    advanceBtn.Parent = root

    local advBtnCorner = Instance.new("UICorner")
    advBtnCorner.CornerRadius = UDim.new(0, px(8))
    advBtnCorner.Parent = advanceBtn

    local skipBtn = Instance.new("TextButton")
    skipBtn.Size = UDim2.fromOffset(px(34), px(30))
    skipBtn.AnchorPoint = Vector2.new(1, 1)
    skipBtn.Position = UDim2.new(1, -px(12), 1, -px(12))
    skipBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    skipBtn.BackgroundTransparency = 0.2
    skipBtn.BorderSizePixel = 0
    skipBtn.Text = "X"
    skipBtn.Font = Enum.Font.GothamBold
    skipBtn.TextSize = ViewportLayout.textPx(16)
    skipBtn.TextColor3 = Color3.fromRGB(220, 180, 180)
    skipBtn.AutoButtonColor = true
    skipBtn.ZIndex = 14
    skipBtn.Active = true
    skipBtn.Parent = root

    local skipBtnCorner = Instance.new("UICorner")
    skipBtnCorner.CornerRadius = UDim.new(0, px(8))
    skipBtnCorner.Parent = skipBtn

    local skipBtnStroke = Instance.new("UIStroke")
    skipBtnStroke.Color = Color3.fromRGB(180, 80, 80)
    skipBtnStroke.Thickness = 1
    skipBtnStroke.Transparency = 0.3
    skipBtnStroke.Parent = skipBtn

    return {
        root = root,
        avatar = avatar,
        avatarRing = avatarRing,
        nameLabel = nameLabel,
        textLabel = textLabel,
        advanceBtn = advanceBtn,
        skipBtn = skipBtn,
        stroke = stroke,
        contentClick = contentClick,
    }
end

local function startTypewriter(state: any, fullText: string)
    -- Останавливаем предыдущий typewriter, если был.
    if state.typeConn then
        state.typeConn:Disconnect()
        state.typeConn = nil
    end
    state.fullText = fullText
    state.typedChars = 0
    state.textLabel.Text = ""
    state.startTime = os.clock()
    state.typeConn = RunService.Heartbeat:Connect(function()
        if not state.fullText then
            if state.typeConn then state.typeConn:Disconnect() end
            return
        end
        local elapsed = os.clock() - state.startTime
        local total = #state.fullText
        local target = math.min(total, math.floor(elapsed * TYPE_SPEED_CHARS_PER_SEC))
        if target > state.typedChars then
            state.typedChars = target
            -- string.sub корректно режет UTF-8 только если использовать utf8.offset.
            -- Эмодзи в русском тексте могут поломаться при усечении посреди байта.
            local cut = utf8.offset(state.fullText, target + 1)
            if cut then
                state.textLabel.Text = string.sub(state.fullText, 1, cut - 1)
            else
                state.textLabel.Text = state.fullText
                state.typedChars = total
            end
        end
        if state.typedChars >= total then
            if state.typeConn then state.typeConn:Disconnect() end
            state.typeConn = nil
            state.textLabel.Text = state.fullText
        end
    end)
end

local function finishTypewriter(state: any)
    if state.typeConn then
        state.typeConn:Disconnect()
        state.typeConn = nil
    end
    if state.fullText then
        state.textLabel.Text = state.fullText
        state.typedChars = #state.fullText
    end
end

local function applyColor(parts: any, color: Color3)
    parts.stroke.Color = color
    parts.avatarRing.Color = color
    parts.nameLabel.TextColor3 = color
    parts.advanceBtn.BackgroundColor3 = color
end

local function applyOptions(state: any, opts: Options)
    local parts = state.parts
    parts.avatar.Image = UiAssets.resolve(opts.speaker) ~= "" and UiAssets.resolve(opts.speaker) or UiAssets.image("upg_pickaxe")
    parts.nameLabel.Text = opts.name or ""

    local color = colorFor(opts.kind)
    applyColor(parts, color)

    local newText = opts.text or ""
    -- Если текст тот же — не перезапускаем typewriter.
    if newText ~= state.fullText then
        startTypewriter(state, newText)
    end

    if opts.hideAdvanceButton then
        parts.advanceBtn.Visible = false
    else
        parts.advanceBtn.Visible = true
    end

    state.onAdvance = opts.onAdvance
    state.onSkip = opts.onSkip
end

function TutorialDialog.show(opts: Options): Handle
    local gui = ensureGui()
    local parts = buildFrame()
    parts.root.Parent = gui

    local state: any = {
        parts = parts,
        destroyed = false,
        typeConn = nil,
        fullText = nil,
        typedChars = 0,
        startTime = 0,
        onAdvance = opts.onAdvance,
        onSkip = opts.onSkip,
        textLabel = parts.textLabel,
        connections = {},
    }

    -- Slide-in.
    parts.root.Size = UDim2.fromOffset(dialogWidth(), dialogHeight())
    parts.root.Position = UDim2.new(0.5, 0, 1, 200)
    TweenService:Create(
        parts.root,
        TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 1, dialogRestY()) }
    ):Play()

    applyOptions(state, opts)

    table.insert(state.connections, parts.contentClick.Activated:Connect(function()
        -- Skip typing — мгновенно дописать.
        if state.typeConn then
            finishTypewriter(state)
        end
    end))

    table.insert(state.connections, parts.advanceBtn.Activated:Connect(function()
        if state.destroyed then return end
        if state.typeConn then
            finishTypewriter(state)
            return
        end
        if state.onAdvance then
            state.onAdvance()
        end
    end))

    table.insert(state.connections, parts.skipBtn.Activated:Connect(function()
        if state.destroyed then return end
        if state.onSkip then
            state.onSkip()
        end
    end))

    local handle: Handle = {} :: any
    function handle:update(newOpts: Options)
        if state.destroyed then return end
        applyOptions(state, newOpts)
    end
    function handle:destroy()
        if state.destroyed then return end
        state.destroyed = true
        if state.typeConn then
            state.typeConn:Disconnect()
            state.typeConn = nil
        end
        for _, c in ipairs(state.connections) do
            c:Disconnect()
        end
        local root = parts.root
        local slideOut = TweenService:Create(
            root,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(0.5, 0, 1, 200), BackgroundTransparency = 1 }
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

return TutorialDialog
