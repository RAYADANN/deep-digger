--!strict
-- Tooltip.lua — Phase 8.
--
-- Универсальный hover-tooltip для любого GuiObject. Привязка идёт через
-- ScopeFactory.HudScope: при разрушении HUD (Fusion.doCleanup) все
-- connection'ы и сам tooltip-фрейм очищаются автоматически.
--
-- API:
--   Tooltip.attach(scope, target, getText)
--
--     scope     — HudScope (`scope:innerScope()` будет переиспользован
--                 для регистрации cleanup'ов).
--     target    — GuiObject, по которому отслеживаем MouseEnter/MouseLeave.
--     getText() — функция, возвращающая строку (`getText()` вызывается
--                 на каждом MouseEnter, чтобы tooltip всегда показывал
--                 актуальное состояние — например, «Сейчас N → Далее N+1»).
--
-- Особенности:
--   * Frame создаётся в одном `DeepDigger_Tutorial` ScreenGui (общий с
--     туториалом), чтобы не плодить HUD-Gui.
--   * `Active = false` на оверлее — клик через tooltip доходит до target.
--   * Edge-clamp: если tooltip уезжает за экран — двигаем влево / вверх.
--   * Fade-in 0.1с / fade-out 0.1с через TweenService.
--   * Повторный MouseEnter до того как fade-out закончился — отменяем
--     уничтожение и снова показываем (типично при шаткой мыши на грани).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local TOOLTIP_GUI_NAME = "DeepDigger_Tutorial"
local FADE_IN = 0.1
local FADE_OUT = 0.1
local TOOLTIP_BG = Color3.fromRGB(15, 15, 28)
local TOOLTIP_STROKE = Color3.fromRGB(120, 200, 255)
local TOOLTIP_TEXT = Color3.fromRGB(240, 235, 220)
local TOOLTIP_MIN_W = 200
local TOOLTIP_MAX_W = 320
local TOOLTIP_PADDING = 8
local OFFSET_GAP = 6

local Tooltip = {}

local function ensureGui(): ScreenGui
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = pg:FindFirstChild(TOOLTIP_GUI_NAME)
    if gui then
        return gui :: ScreenGui
    end
    local newGui = Instance.new("ScreenGui")
    newGui.Name = TOOLTIP_GUI_NAME
    newGui.ResetOnSpawn = false
    newGui.IgnoreGuiInset = true
    newGui.DisplayOrder = 90 -- выше HUD (20), ниже Notifications (100)
    newGui.Parent = pg
    return newGui
end

local function buildFrame(): (Frame, TextLabel, UIStroke)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(TOOLTIP_MIN_W, 60)
    frame.BackgroundColor3 = TOOLTIP_BG
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Active = false
    frame.AutoLocalize = false
    frame.ZIndex = 10

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = TOOLTIP_STROKE
    stroke.Thickness = 1.5
    stroke.Transparency = 1
    stroke.Parent = frame

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, TOOLTIP_PADDING)
    padding.PaddingBottom = UDim.new(0, TOOLTIP_PADDING)
    padding.PaddingLeft = UDim.new(0, TOOLTIP_PADDING)
    padding.PaddingRight = UDim.new(0, TOOLTIP_PADDING)
    padding.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = TOOLTIP_TEXT
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.TextTransparency = 1
    label.RichText = true
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.Parent = frame

    return frame, label, stroke
end

local function positionFrame(frame: Frame, target: GuiObject)
    local camera = workspace.CurrentCamera
    local viewport = if camera then camera.ViewportSize else Vector2.new(1024, 768)
    local tPos = target.AbsolutePosition
    local tSize = target.AbsoluteSize
    local fSize = frame.AbsoluteSize
    if fSize.X < 10 then
        fSize = Vector2.new(TOOLTIP_MIN_W, 60)
    end

    -- Дефолт — справа от target. Если не помещается — слева. Если и слева не
    -- помещается — снизу под target.
    local x = tPos.X + tSize.X + OFFSET_GAP
    local y = tPos.Y
    if x + fSize.X > viewport.X - 4 then
        x = tPos.X - fSize.X - OFFSET_GAP
        if x < 4 then
            x = math.clamp(tPos.X, 4, viewport.X - fSize.X - 4)
            y = tPos.Y + tSize.Y + OFFSET_GAP
        end
    end
    y = math.clamp(y, 4, math.max(4, viewport.Y - fSize.Y - 4))

    frame.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
end

function Tooltip.attach(scope: any, target: GuiObject, getText: () -> string)
    local state = {
        frame = nil :: Frame?,
        label = nil :: TextLabel?,
        stroke = nil :: UIStroke?,
        fadeOutTask = nil :: thread?,
        destroyed = false,
    }

    local function destroyFrame()
        if state.frame then
            state.frame:Destroy()
        end
        state.frame, state.label, state.stroke = nil, nil, nil
    end

    local function show()
        if state.destroyed then
            return
        end
        if state.fadeOutTask then
            task.cancel(state.fadeOutTask)
            state.fadeOutTask = nil
        end
        if not state.frame then
            local gui = ensureGui()
            local f, l, st = buildFrame()
            state.frame, state.label, state.stroke = f, l, st
            f.Parent = gui
        end
        local frame = state.frame :: Frame
        local label = state.label :: TextLabel
        local stroke = state.stroke :: UIStroke

        local ok, text = pcall(getText)
        if not ok or typeof(text) ~= "string" then
            text = ""
        end
        label.Text = text

        -- Считаем ширину по тексту: чем длиннее — тем шире, но не больше MAX.
        local approxLines = math.max(1, math.ceil(#text / 32))
        local width = math.clamp(8 * 13, TOOLTIP_MIN_W, TOOLTIP_MAX_W)
        if #text > 40 then
            width = TOOLTIP_MAX_W
        end
        frame.Size = UDim2.fromOffset(width, 24 + approxLines * 16)

        -- Один кадр на расчёт AbsoluteSize после автосайза.
        task.defer(function()
            if state.frame and state.frame == frame then
                positionFrame(frame, target)
            end
        end)

        TweenService:Create(frame, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.1,
        }):Play()
        TweenService:Create(label, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextTransparency = 0,
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 0.2,
        }):Play()
    end

    local function hide()
        if state.fadeOutTask then
            task.cancel(state.fadeOutTask)
        end
        local frame = state.frame
        local label = state.label
        local stroke = state.stroke
        if not frame or not label or not stroke then
            return
        end
        TweenService:Create(frame, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 1,
        }):Play()
        TweenService:Create(label, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextTransparency = 1,
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
        }):Play()

        state.fadeOutTask = task.delay(FADE_OUT + 0.02, function()
            state.fadeOutTask = nil
            if state.destroyed then return end
            destroyFrame()
        end)
    end

    local enterConn = target.MouseEnter:Connect(show)
    local leaveConn = target.MouseLeave:Connect(hide)

    local function disposeAll()
        if state.destroyed then return end
        state.destroyed = true
        if enterConn then enterConn:Disconnect() end
        if leaveConn then leaveConn:Disconnect() end
        if state.fadeOutTask then
            task.cancel(state.fadeOutTask)
            state.fadeOutTask = nil
        end
        destroyFrame()
    end

    -- target может быть destroyed раньше scope'a (UpgradesPanel.Computed
    -- пересоздаёт UpgRow'ы при изменении coins/upgrades). Если не освободить
    -- connection'ы здесь — каждый ре-рендер добавит мёртвые записи в scope,
    -- и они проживут до Fusion.doCleanup(scope) на разрушении HUD.
    local ancestryConn: RBXScriptConnection
    ancestryConn = target.AncestryChanged:Connect(function()
        if not target.Parent then
            -- Сначала прячем плавно (если был показан), потом дисконнектим.
            hide()
            disposeAll()
            if ancestryConn then
                ancestryConn:Disconnect()
            end
        end
    end)

    -- Регистрируем cleanup и в scope (на случай Fusion.doCleanup без
    -- предварительного destroy target'a — например HUD сразу уничтожается).
    if typeof(scope) == "table" then
        table.insert(scope, function()
            if ancestryConn then ancestryConn:Disconnect() end
            disposeAll()
        end)
    end
end

return Tooltip
