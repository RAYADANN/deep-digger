--!strict
-- RebirthConfirmModal.lua — Phase 9.
--
-- Модальное окно подтверждения ребёрта. Ребёрт необратим — misclick стоит
-- ~30 минут прогресса, поэтому модал обязателен.
--
-- Anti-misclick:
--   * После открытия кнопка [РЕБЁРТ] disabled 0.3с (визуальный pulse),
--     затем активируется. Игрок не может «слепо» прокликать.
--   * ESC и клик по фону / кнопке [ОТМЕНА] закрывают модал без действия.
--
-- API:
--   RebirthConfirmModal.show(opts)
--     opts.scope    — родительский HudScope (для cleanup при destroy HUD).
--     opts.title    — заголовок («Ребёрт #1»).
--     opts.body     — основной текст (RichText), «Что сохранится / сбросится».
--     opts.confirm  — callback на подтверждение.
--     opts.onClose  — опциональный callback при закрытии (cancel или confirm).
--
-- Возвращает handle с методом :close() для программного закрытия.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children

local theme = require(script.Parent.Parent.theme)
local C = theme.C

local MODAL_GUI_NAME = "DeepDigger_RebirthModal"
local ANTI_MISCLICK_DELAY = 0.3
local FADE_IN = 0.18

local RebirthConfirmModal = {}

export type Options = {
    scope: any,
    title: string,
    body: string,
    confirmText: string?,
    cancelText: string?,
    confirm: () -> (),
    onClose: (() -> ())?,
}

export type Handle = {
    close: (self: Handle) -> (),
}

local function ensureGui(): ScreenGui
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local gui = pg:FindFirstChild(MODAL_GUI_NAME)
    if gui then
        return gui :: ScreenGui
    end
    local newGui = Instance.new("ScreenGui")
    newGui.Name = MODAL_GUI_NAME
    newGui.ResetOnSpawn = false
    newGui.IgnoreGuiInset = true
    -- DisplayOrder выше HUD (20) и tooltip (90), ниже Notifications (100) —
    -- модал должен быть поверх HUD, но тосты «REBIRTH!» — поверх модала.
    newGui.DisplayOrder = 95
    newGui.Parent = pg
    return newGui
end

function RebirthConfirmModal.show(opts: Options): Handle
    local s = opts.scope
    local gui = ensureGui()

    -- Только один модал одновременно: если уже открыт — закрываем старый.
    for _, child in ipairs(gui:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    local enabled = s:Value(false)
    local hoveredConfirm = s:Value(false)
    local hoveredCancel = s:Value(false)

    local handle: any = { _closed = false }
    local escConn: RBXScriptConnection? = nil

    local backdrop: Frame

    local function doClose()
        if handle._closed then
            return
        end
        handle._closed = true
        if escConn then
            escConn:Disconnect()
            escConn = nil
        end
        if backdrop then
            -- Fade-out, потом destroy.
            TweenService:Create(backdrop, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 1,
            }):Play()
            task.delay(0.15, function()
                if backdrop and backdrop.Parent then
                    backdrop:Destroy()
                end
            end)
        end
        if opts.onClose then
            opts.onClose()
        end
    end

    handle.close = function()
        doClose()
    end

    local confirmText = opts.confirmText or "РЕБЁРТ"
    local cancelText = opts.cancelText or "ОТМЕНА"

    backdrop = s:New("Frame")({
        Name = "Backdrop",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Parent = gui,
        Active = true,
        ZIndex = 1,
        [Children] = {
            s:New("TextButton")({
                -- Прозрачная overlay-кнопка — клик по «темноте» закрывает.
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                [OnEvent("Activated")] = doClose,
            }),
            s:New("Frame")({
                Name = "Modal",
                Size = UDim2.fromOffset(420, 280),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = C.panelBg,
                BorderSizePixel = 0,
                ZIndex = 2,
                -- Active=true — клик по «голому» телу модала (между кнопками)
                -- НЕ проваливается на backdrop-TextButton (который закрывает
                -- модал). Без этого игрок промахом мимо кнопки закрыл бы
                -- модал, обходя anti-misclick задержку.
                Active = true,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
                    s:New("UIStroke")({ Color = C.gold, Thickness = 2, Transparency = 0.1 }),
                    -- Header (заголовок) с золотым акцентом.
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -32, 0, 36),
                        Position = UDim2.new(0, 16, 0, 12),
                        BackgroundTransparency = 1,
                        Text = "💠 " .. opts.title,
                        TextSize = 22,
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = C.gold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }),
                    -- Body (RichText) — «Что сохранится / сбросится / следующий бонус».
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -32, 1, -140),
                        Position = UDim2.new(0, 16, 0, 56),
                        BackgroundTransparency = 1,
                        Text = opts.body,
                        TextSize = 14,
                        Font = Enum.Font.Gotham,
                        TextColor3 = C.textMain,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Top,
                        TextWrapped = true,
                        RichText = true,
                    }),
                    -- Cancel button.
                    s:New("TextButton")({
                        Name = "CancelButton",
                        Size = UDim2.new(0, 130, 0, 44),
                        Position = UDim2.new(0, 16, 1, -60),
                        BackgroundColor3 = s:Computed(function(use)
                            return use(hoveredCancel) and C.btnHover or C.btnBg
                        end),
                        BorderSizePixel = 0,
                        Text = cancelText,
                        TextSize = 15,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = C.textMain,
                        AutoButtonColor = false,
                        [Children] = {
                            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
                            s:New("UIStroke")({ Color = C.btnBorder, Thickness = 1.5, Transparency = 0.4 }),
                        },
                        [OnEvent("MouseEnter")] = function() hoveredCancel:set(true) end,
                        [OnEvent("MouseLeave")] = function() hoveredCancel:set(false) end,
                        [OnEvent("Activated")] = doClose,
                    }),
                    -- Confirm button — disabled первые 0.3с (anti-misclick).
                    s:New("TextButton")({
                        Name = "ConfirmButton",
                        Size = UDim2.new(0, 240, 0, 44),
                        Position = UDim2.new(1, -256, 1, -60),
                        BackgroundColor3 = s:Computed(function(use)
                            if not use(enabled) then
                                return C.btnDisabled
                            end
                            return use(hoveredConfirm) and Color3.fromRGB(220, 180, 30) or C.gold
                        end),
                        BorderSizePixel = 0,
                        Text = s:Computed(function(use)
                            if not use(enabled) then
                                return "..."
                            end
                            return confirmText
                        end),
                        TextSize = 16,
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
                        [OnEvent("MouseEnter")] = function() hoveredConfirm:set(true) end,
                        [OnEvent("MouseLeave")] = function() hoveredConfirm:set(false) end,
                        [OnEvent("Activated")] = function()
                            if handle._closed then
                                return
                            end
                            if not Fusion.peek(enabled) then
                                -- Игрок прокликал anti-misclick — игнор.
                                return
                            end
                            doClose()
                            local ok, err = pcall(opts.confirm)
                            if not ok then
                                warn("[RebirthConfirmModal] confirm failed:", err)
                            end
                        end,
                    }),
                },
            }),
        },
    })

    -- Fade-in backdrop'a.
    backdrop.BackgroundTransparency = 1
    TweenService:Create(backdrop, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 0.45,
    }):Play()

    -- Anti-misclick: 0.3с задержка перед активацией [РЕБЁРТ]. Это и время на
    -- прочтение тела модала.
    task.delay(ANTI_MISCLICK_DELAY, function()
        if not handle._closed then
            enabled:set(true)
        end
    end)

    -- ESC закрывает модал.
    escConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            doClose()
        end
    end)

    return handle :: Handle
end

return RebirthConfirmModal
