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
local UiIcon = require(script.Parent.hud.components.UiIcon)
local theme = require(script.Parent.hud.theme)
local Notification = require(script.Parent.Notification)
local SoundManager = require(script.Parent.Parent.core.SoundManager)
local ViewportLayout = require(script.Parent.util.ViewportLayout)
local UiScreen = require(script.Parent.util.UiScreen)
-- RewardFX дёргается через Net:Connect("Notify") в init.client.lua с
-- kind="daily_reward" (server-side authority по rarity дня).

local C = theme.C

local MODAL_GUI_NAME = "DeepDigger_DailyModal"
local ANTI_MISCLICK_DELAY = 0.4
local FADE_IN = 0.18
local FADE_OUT = 0.18

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
    return UiScreen.ensure(pg, MODAL_GUI_NAME, "modal")
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
    local mobile = ViewportLayout.isNarrow()
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

    -- Контент свёрстан в дизайн-пикселях (modalW × modalH) и целиком
    -- ужимается через UIScale, поэтому никогда не обрезается на телефоне.
    local layoutEpoch = s:Value(0)
    ViewportLayout.subscribe(function()
        layoutEpoch:set(peek(layoutEpoch) + 1)
    end, s)
    local fitScale = s:Computed(function(use)
        use(layoutEpoch)
        -- Десктоп: разрешаем окну (и всему тексту внутри UIScale) вырасти до 1.7×
        -- дизайна — так подписи реально крупные. Потолок применяется только на
        -- desktop; на phone/tablet fit-коэффициент < 1, поэтому maxScale не влияет.
        local deskMax = if ViewportLayout.tier() == "desktop" then 1.7 else 1.0
        return ViewportLayout.fitModalScale(modalW, modalH, deskMax)
    end)
    local modalSize = s:Computed(function(use)
        local k = use(fitScale)
        return UDim2.fromOffset(math.floor(modalW * k + 0.5), math.floor(modalH * k + 0.5))
    end)
    local modalPos = s:Computed(function(use)
        local k = use(fitScale)
        return UDim2.new(0.5, 0, 0, ViewportLayout.modalCenterY(math.floor(modalH * k + 0.5)))
    end)

    -- Карточки собираем через s:Computed ВНУТРИ Grid (как InvSlot в
    -- InventoryPanel). Прежний вариант — create() в цикле до backdrop —
    -- в Fusion 0.3 инстансы не попадали в дерево и сетка была пустой.
    local function buildGridCards()
        local cards: { any } = {}
        for day = 1, 7 do
            table.insert(cards, DailyCard.create(s, {
                cycleDay = day,
                state = stateForDay(day),
                layoutOrder = day,
            }))
        end
        return cards
    end

    backdrop = s:New("Frame")({
        Name = "Backdrop",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
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
                Size = modalSize,
                Position = modalPos,
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = C.panelBg,
                BorderSizePixel = 0,
                Active = true,
                ClipsDescendants = true,
                ZIndex = 2,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 14) }),
                    s:New("UIStroke")({ Color = C.gold, Thickness = 2, Transparency = 0.1 }),
                    s:New("Frame")({
                    Name = "Content",
                    Size = UDim2.fromOffset(modalW, modalH),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ZIndex = 2,
                    [Children] = {
                    s:New("UIScale")({ Scale = fitScale }),
                    -- Header
                    UiIcon.titleRow(s, {
                        source = "icon_gift",
                        text = "Награда за день",
                        textSize = 22,
                        font = Enum.Font.GothamBlack,
                        textColor = C.gold,
                        size = UDim2.new(1, -padding * 2, 0, 28),
                        position = UDim2.new(0, padding, 0, padding),
                        iconSize = 24,
                        zIndex = 5,
                    }),
                    s:New("Frame")({
                        Size = UDim2.new(1, -padding * 2, 0, 18),
                        Position = UDim2.new(0, padding, 0, padding + 32),
                        BackgroundTransparency = 1,
                        ZIndex = 5,
                        [Children] = {
                            UiIcon.create(s, {
                                source = "icon_streak",
                                size = UDim2.fromOffset(16, 16),
                                position = UDim2.new(0, 0, 0.5, -8),
                                zIndex = 5,
                            }),
                            s:New("TextLabel")({
                                Size = UDim2.new(1, -22, 1, 0),
                                Position = UDim2.new(0, 22, 0, 0),
                                BackgroundTransparency = 1,
                                Text = ("Стрик: %d дн.  ·  День %d из 7"):format(opts.streak or 0, nextDay),
                                TextSize = 13,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = C.textLabel,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                ZIndex = 5,
                            }),
                        },
                    }),
                    -- Grid с карточками
                    s:New("Frame")({
                        Name = "Grid",
                        Size = UDim2.fromOffset(gridW, gridH),
                        Position = UDim2.new(0.5, -gridW / 2, 0, padding + headerH),
                        BackgroundTransparency = 1,
                        ZIndex = 2,
                        [Children] = {
                            s:New("UIGridLayout")({
                                CellSize = UDim2.fromOffset(cardW, cardH),
                                CellPadding = UDim2.fromOffset(gap, gap),
                                FillDirection = Enum.FillDirection.Horizontal,
                                StartCorner = Enum.StartCorner.TopLeft,
                                FillDirectionMaxCells = cols,
                                SortOrder = Enum.SortOrder.LayoutOrder,
                            }),
                            s:Computed(buildGridCards),
                        },
                    }),
                    -- Footer: [ПОЗЖЕ] + [ЗАБРАТЬ]
                    s:New("TextButton")({
                        Name = "LaterButton",
                        Size = UDim2.new(0, 120, 0, 44),
                        Position = UDim2.new(0, padding, 1, -padding - 44),
                        ZIndex = 5,
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
                        ZIndex = 5,
                        BackgroundColor3 = s:Computed(function(use)
                            if not use(enabled) then return C.btnDisabled end
                            return use(hoveredClaim) and Color3.fromRGB(220, 180, 30) or C.gold
                        end),
                        BorderSizePixel = 0,
                        Text = s:Computed(function(use)
                            if not use(enabled) then return "..." end
                            return "ЗАБРАТЬ"
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
                            UiIcon.create(s, {
                                source = "icon_gift",
                                size = UDim2.fromOffset(18, 18),
                                position = UDim2.new(0, 14, 0.5, -9),
                                zIndex = 6,
                                visible = enabled,
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
                                        icon = "icon_warning",
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
            }),
        },
    })

    backdrop.BackgroundTransparency = 1

    -- Pulse на текущей карточке
    -- смонтировал дерево (нельзя GetDescendants на «сыром» s:New).
    task.defer(function()
        if handle._closed or not backdrop.Parent then
            return
        end
        local modal = backdrop:FindFirstChild("Modal")
        local grid = modal and modal:FindFirstChild("Grid", true)
        local card = grid and grid:FindFirstChild("DailyCard_" .. tostring(nextDay))
        if card then
            local stroke = card:FindFirstChildOfClass("UIStroke")
            if stroke and stroke:IsA("UIStroke") then
                stopPulse = DailyCard.startPulse(stroke)
            end
        end
    end)

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
