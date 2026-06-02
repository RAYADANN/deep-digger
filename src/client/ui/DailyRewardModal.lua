--!strict
-- DailyRewardModal.lua — Phase 10.
--
-- Полноэкранный модал «🎁 Награда за день» с сеткой 7 карточек.
-- Открывается при заходе если dailyState.canClaim == true (через Phase 10
-- логику в init.client.lua: либо первый PlayerStats payload, либо Notify
-- kind="daily_available").
--
-- Структура:
--   * Backdrop (полупрозрачный) + кнопка-overlay для закрытия по клику.
--   * Modal-frame: header «🎁 День N» + grid карточек (4×2 desktop / 2×4 mobile).
--   * Footer: [ЗАБРАТЬ] (золотая) и [ПОЗЖЕ] (серая).
--   * Anti-misclick: 0.4с задержка перед активацией [ЗАБРАТЬ] (по примеру
--     Phase 9 RebirthConfirmModal с 0.3с).
--   * ESC закрывает (без claim).
--
-- На claim:
--   * Net:Invoke("ClaimDaily") без аргументов (сервер сам считает день).
--   * Tween selected-карточки → центр (1.4x scale).
--   * RewardFX.burst(rarity дня).
--   * Через 0.8с fade-out модала.
--
-- API:
--   DailyRewardModal.show({ scope, state }) → Handle :close()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)
-- Constants / DailyLogic / DailyRewardDatabase не нужны клиенту напрямую:
-- сервер вычисляет nextDay / rarity и шлёт через PlayerStats + Notify.

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek

local DailyCard = require(script.Parent.hud.components.DailyCard)
local theme = require(script.Parent.hud.theme)
local Notification = require(script.Parent.Notification)
local SoundManager = require(script.Parent.Parent.core.SoundManager)
-- RewardFX дёргается через Net:Connect("Notify") в init.client.lua с
-- kind="daily_reward" (server-side authority по rarity дня).

local C = theme.C

local MODAL_GUI_NAME = "DeepDigger_DailyModal"
local ANTI_MISCLICK_DELAY = 0.4
local FADE_IN = 0.18
local FADE_OUT = 0.18
local MOBILE_VIEWPORT_X = 800

local DailyRewardModal = {}

export type Options = {
    scope: any,
    -- Текущий streak (0..7). Если 0 — игрок никогда не клеймил, рисуем
    -- День 1 как current. Если N — следующий claim даст streak N+1.
    streak: number,
    -- Какой день СЛЕДУЮЩЕГО claim'а (1..7) — DailyLogic.streakToCycleDay уже посчитан.
    nextDay: number,
    onClose: (() -> ())?,
}

export type Handle = {
    close: (self: Handle) -> (),
}

local _activeHandle: any = nil

local function ensureGui(): ScreenGui?
    local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    local existing = pg:FindFirstChild(MODAL_GUI_NAME)
    if existing and existing:IsA("ScreenGui") then
        return existing
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = MODAL_GUI_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    -- DisplayOrder = 95 как RebirthConfirmModal (поверх HUD/таб'a, ниже notifications).
    gui.DisplayOrder = 95
    gui.Parent = pg
    return gui
end

local function isMobile(): boolean
    local camera = workspace.CurrentCamera
    if not camera then return false end
    return camera.ViewportSize.X < MOBILE_VIEWPORT_X
end

function DailyRewardModal.show(opts: Options): Handle?
    -- Защита: только один модал одновременно.
    if _activeHandle then
        return _activeHandle
    end
    -- Phase 10: каждое открытие — свой innerScope. doCleanup на close()
    -- предотвращает накопление Fusion Value/Computed между показами модала.
    local parentScope = opts.scope
    local s = parentScope:innerScope()
    local gui = ensureGui()
    if not gui then return nil end
    -- Чистим возможные остатки от прошлой сессии.
    for _, child in ipairs(gui:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local handle: any = { _closed = false }
    _activeHandle = handle
    local enabled = s:Value(false)
    local hoveredClaim = s:Value(false)
    local hoveredLater = s:Value(false)

    local escConn: RBXScriptConnection? = nil
    local backdrop: Frame
    local currentCardStroke: UIStroke? = nil
    local stopPulse: (() -> ())? = nil

    local function doClose()
        if handle._closed then return end
        handle._closed = true
        _activeHandle = nil
        if escConn then escConn:Disconnect(); escConn = nil end
        if stopPulse then pcall(stopPulse); stopPulse = nil end
        if backdrop then
            TweenService:Create(backdrop, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 1,
            }):Play()
            task.delay(FADE_OUT + 0.05, function()
                if backdrop and backdrop.Parent then
                    backdrop:Destroy()
                end
                -- doCleanup освобождает Fusion-аллокации scope'a. Ставим
                -- после destroy frame'a чтобы Computed-биндинги отвалились
                -- штатно (без error на nil instance).
                pcall(function()
                    Fusion.doCleanup(s)
                end)
            end)
        end
        if opts.onClose then
            pcall(opts.onClose)
        end
    end

    handle.close = function() doClose() end

    -- Расчёт состояний карточек 1..7.
    --   Day N < nextDay → past (✓).
    --   Day == nextDay → current (pulse).
    --   Day > nextDay → future.
    local nextDay = math.clamp(math.floor(opts.nextDay or 1), 1, 7)
    local function stateForDay(day: number): "past" | "current" | "future"
        if day < nextDay then return "past" end
        if day == nextDay then return "current" end
        return "future"
    end

    -- Grid: ВЫНЕСЕНО в локальную функцию, чтобы переключиться desktop ↔ mobile
    -- по viewport.
    local mobile = isMobile()
    local cols = mobile and 2 or 4
    local cardW = 100
    local cardH = 140
    local gap = 10
    local gridW = cols * cardW + (cols - 1) * gap
    local rows = math.ceil(7 / cols)
    local gridH = rows * cardH + (rows - 1) * gap

    -- Modal-фрейм: header + grid + footer.
    local headerH = 64
    local footerH = 64
    local padding = 20
    local modalW = gridW + padding * 2
    local modalH = headerH + gridH + footerH + padding * 2 + 12

    local cardElements: { any } = {}
    for day = 1, 7 do
        local state = stateForDay(day)
        local card = DailyCard.create(s, { cycleDay = day, state = state, layoutOrder = day })
        if state == "current" then
            -- Найти UIStroke внутри карточки для pulse'a. DailyCard кладёт
            -- его прямо как child — берём первого UIStroke.
            local foundStroke
            for _, ch in ipairs(card:GetDescendants()) do
                if ch:IsA("UIStroke") then
                    foundStroke = ch
                    break
                end
            end
            currentCardStroke = foundStroke
            if foundStroke then
                stopPulse = DailyCard.startPulse(foundStroke)
            end
        end
        table.insert(cardElements, card)
    end

    -- Собираем children grid'а: UIGridLayout первый + 7 cards.
    local gridChildren: { any } = {
        s:New("UIGridLayout")({
            CellSize = UDim2.fromOffset(cardW, cardH),
            CellPadding = UDim2.fromOffset(gap, gap),
            StartCorner = Enum.StartCorner.TopLeft,
            FillDirectionMaxCells = cols,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }
    for _, card in ipairs(cardElements) do
        table.insert(gridChildren, card)
    end

    backdrop = s:New("Frame")({
        Name = "Backdrop",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Parent = gui,
        Active = true,
        ZIndex = 1,
        [Children] = {
            s:New("TextButton")({
                -- Backdrop клик закрывает (как RebirthConfirmModal).
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                [OnEvent("Activated")] = doClose,
            }),
            s:New("Frame")({
                Name = "Modal",
                Size = UDim2.fromOffset(modalW, modalH),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = C.panelBg,
                BorderSizePixel = 0,
                Active = true,
                ZIndex = 2,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 14) }),
                    s:New("UIStroke")({ Color = C.gold, Thickness = 2, Transparency = 0.1 }),
                    -- Header
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -padding * 2, 0, 28),
                        Position = UDim2.new(0, padding, 0, padding),
                        BackgroundTransparency = 1,
                        Text = "🎁 Награда за день",
                        TextSize = 22,
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = C.gold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }),
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -padding * 2, 0, 18),
                        Position = UDim2.new(0, padding, 0, padding + 32),
                        BackgroundTransparency = 1,
                        Text = ("🔥 Стрик: %d дн.  ·  День %d из 7"):format(opts.streak or 0, nextDay),
                        TextSize = 13,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = C.textLabel,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }),
                    -- Grid с карточками
                    s:New("Frame")({
                        Name = "Grid",
                        Size = UDim2.fromOffset(gridW, gridH),
                        Position = UDim2.new(0.5, -gridW / 2, 0, padding + headerH),
                        BackgroundTransparency = 1,
                        [Children] = gridChildren,
                    }),
                    -- Footer: [ПОЗЖЕ] + [ЗАБРАТЬ]
                    s:New("TextButton")({
                        Name = "LaterButton",
                        Size = UDim2.new(0, 120, 0, 44),
                        Position = UDim2.new(0, padding, 1, -padding - 44),
                        BackgroundColor3 = s:Computed(function(use)
                            return use(hoveredLater) and C.btnHover or C.btnBg
                        end),
                        BorderSizePixel = 0,
                        Text = "ПОЗЖЕ",
                        TextSize = 14,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = C.textMain,
                        AutoButtonColor = false,
                        [Children] = {
                            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
                            s:New("UIStroke")({ Color = C.btnBorder, Thickness = 1.5, Transparency = 0.4 }),
                        },
                        [OnEvent("MouseEnter")] = function() hoveredLater:set(true) end,
                        [OnEvent("MouseLeave")] = function() hoveredLater:set(false) end,
                        [OnEvent("Activated")] = doClose,
                    }),
                    s:New("TextButton")({
                        Name = "ClaimButton",
                        Size = UDim2.new(0, 240, 0, 44),
                        Position = UDim2.new(1, -padding - 240, 1, -padding - 44),
                        BackgroundColor3 = s:Computed(function(use)
                            if not use(enabled) then return C.btnDisabled end
                            return use(hoveredClaim) and Color3.fromRGB(220, 180, 30) or C.gold
                        end),
                        BorderSizePixel = 0,
                        Text = s:Computed(function(use)
                            if not use(enabled) then return "..." end
                            return "🎁 ЗАБРАТЬ"
                        end),
                        TextSize = 17,
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = s:Computed(function(use)
                            return if use(enabled) then Color3.fromRGB(40, 25, 0) else C.textMuted
                        end),
                        AutoButtonColor = false,
                        [Children] = {
                            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
                            s:New("UIStroke")({
                                Color = s:Computed(function(use)
                                    return use(enabled) and Color3.fromRGB(255, 240, 150) or C.btnBorder
                                end),
                                Thickness = 2,
                                Transparency = 0.2,
                            }),
                        },
                        [OnEvent("MouseEnter")] = function() hoveredClaim:set(true) end,
                        [OnEvent("MouseLeave")] = function() hoveredClaim:set(false) end,
                        [OnEvent("Activated")] = function()
                            if handle._closed then return end
                            if not peek(enabled) then return end
                            -- Disable повторных нажатий пока идёт claim.
                            enabled:set(false)

                            task.spawn(function()
                                local ok, result = pcall(function()
                                    return Net:Invoke("ClaimDaily")
                                end)
                                if not ok or typeof(result) ~= "table" or not result.success then
                                    -- Сетевая ошибка или сервер отказал.
                                    local msg = (result and result.message) or "Не удалось забрать награду"
                                    SoundManager.play("buy_fail")
                                    Notification.show({
                                        text = msg,
                                        icon = "⚠",
                                        color = Color3.fromRGB(255, 140, 60),
                                        duration = 3,
                                    })
                                    doClose()
                                    return
                                end
                                -- Success: SoundManager.play — переиспользуем
                                -- sell_success как daily_claim placeholder
                                -- (отдельный sound TODO playtest).
                                --
                                -- RewardFX.burst НЕ дёргаем здесь — сервер
                                -- шлёт Notify kind="daily_reward" с rarity,
                                -- и client-side handler в init.client.lua
                                -- запускает FX ровно один раз. Так избегаем
                                -- двойного coin-rain'a.
                                SoundManager.play("sell_success")
                                -- Закрываем через 0.8с — даём времени
                                -- coin-rain'у проиграться частично, но
                                -- модал не торчит весь FX.
                                task.delay(0.8, function()
                                    doClose()
                                end)
                            end)
                        end,
                    }),
                },
            }),
        },
    })

    -- Fade-in backdrop'a.
    backdrop.BackgroundTransparency = 1
    TweenService:Create(backdrop, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 0.4,
    }):Play()

    -- Anti-misclick: 0.4с задержка перед [ЗАБРАТЬ].
    task.delay(ANTI_MISCLICK_DELAY, function()
        if not handle._closed then
            enabled:set(true)
        end
    end)

    -- ESC.
    escConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            doClose()
        end
    end)

    return handle :: Handle
end

--[[
    Удобный helper: показывает модал если canClaim true.
    Используется из init.client.lua при получении PlayerStats и Notify.
]]
function DailyRewardModal.showIfClaimable(scope: any, dailyState: any)
    if not dailyState or not dailyState.canClaim then
        return nil
    end
    return DailyRewardModal.show({
        scope = scope,
        streak = dailyState.currentStreak or 0,
        nextDay = dailyState.nextDay or 1,
    })
end

function DailyRewardModal.isOpen(): boolean
    return _activeHandle ~= nil and not _activeHandle._closed
end

return DailyRewardModal
