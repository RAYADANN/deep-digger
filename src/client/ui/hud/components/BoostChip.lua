--!strict
-- BoostChip.lua — Phase 10.
--
-- Маленький фрейм в TopBar справа от ResourceChip'ов. Visible только при
-- activeBoosts > 0. Тикает remaining раз в секунду локально (без
-- ре-фетча с сервера). После истечения boost'a — скрывается.
--
-- API:
--   BoostChip.create(scope, state) → Frame
--
-- Поведение:
--   * Берёт первый активный boost из state.activeBoosts (Phase 10 MVP
--     поддерживает только один boost; UI multi-boost — patch 1.1).
--   * Текст: «⚡ x2 · MM:SS».
--   * UIStroke цикл RGB через TweenService (Pet Sim style).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
local ICON = theme.ICON

local BoostChip = {}

-- Формат «MM:SS». Подсчёт без timestring-локализаций — модно.
local function fmtTime(secs: number): string
    secs = math.max(0, math.floor(secs))
    local m = math.floor(secs / 60)
    local s = secs % 60
    return ("%02d:%02d"):format(m, s)
end

--[[
    Найти первый активный boost из списка. В MVP-scope их обычно один,
    но если их несколько — берём с максимальным remaining (наиболее
    «свежий» boost для отображения).
]]
local function pickPrimaryBoost(list: any): any
    if typeof(list) ~= "table" then return nil end
    local best
    local bestRem = -1
    for _, b in ipairs(list) do
        if typeof(b) == "table" then
            local rem = b.remaining or 0
            if rem > bestRem then
                bestRem = rem
                best = b
            end
        end
    end
    return best
end

function BoostChip.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState, position: UDim2?)
    -- Локальный таймер: server присылает remaining раз в HUD-payload
    -- (часто это > раз в секунду, но не каждую). Между тиками сервера
    -- тикаем локально, переустанавливаемся при новом payload'е.
    local primaryBoost = s:Value(nil :: any)
    local localRemaining = s:Value(0)

    -- Реактим на изменение activeBoosts.
    local activeBoostsView = s:Computed(function(use)
        local list = use(state.activeBoosts)
        return pickPrimaryBoost(list)
    end)

    -- Подписываемся вручную через Heartbeat tick'и + сравнение peek'a.
    local lastSignature: any = nil
    local lastTick = os.clock()
    local heartbeatConn: RBXScriptConnection? = nil

    local function applyBoostFromServer()
        local boost = peek(activeBoostsView)
        primaryBoost:set(boost)
        if boost then
            localRemaining:set(boost.remaining or 0)
        else
            localRemaining:set(0)
        end
    end

    heartbeatConn = RunService.Heartbeat:Connect(function()
        -- Локальный tick раз в секунду.
        local now = os.clock()
        if now - lastTick >= 1 then
            lastTick = now
            local cur = peek(localRemaining) or 0
            if cur > 0 then
                localRemaining:set(math.max(0, cur - 1))
            end
        end
        -- Detect new payload: сравниваем (kind, expiresAt) первого boost'a.
        -- Если изменилось — переустанавливаем localRemaining.
        local current = peek(activeBoostsView)
        local sig
        if current then
            sig = tostring(current.kind) .. ":" .. tostring(current.expiresAt) .. ":" .. tostring(current.multiplier)
        else
            sig = "nil"
        end
        if sig ~= lastSignature then
            lastSignature = sig
            applyBoostFromServer()
        end
    end)

    -- Cleanup heartbeat при destroy scope.
    if typeof(s) == "table" then
        table.insert(s, function()
            if heartbeatConn then
                heartbeatConn:Disconnect()
                heartbeatConn = nil
            end
        end)
    end

    local visible = s:Computed(function(use)
        local b = use(primaryBoost)
        return b ~= nil and (use(localRemaining) or 0) > 0
    end)

    -- Десктоп: масштабируем чип через chromeMult. Phone/tablet = ×1.
    local cm = ViewportLayout.chromeMult()
    local function d(n: number): number
        return math.max(1, math.floor(n * cm + 0.5))
    end

    local chipFrame = s:New("Frame")({
        Name = "BoostChip",
        Size = UDim2.new(0, d(118), 0, d(24)),
        Position = position or UDim2.new(0, 0, 0, ViewportLayout.px(110)),
        BackgroundColor3 = C.gemBg,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Visible = visible,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, d(5)) }),
            s:New("UIStroke")({
                Color = Color3.fromRGB(255, 200, 60),
                Thickness = math.max(1.2, d(1.2)),
                Transparency = 0.3,
            }),
            s:New("ImageLabel")({
                Size = UDim2.fromOffset(d(14), d(14)),
                Position = UDim2.new(0, d(4), 0.5, -d(7)),
                BackgroundTransparency = 1,
                Image = UiAssets.image("upg_speed"),
                ImageColor3 = ICON.tint,
                ScaleType = Enum.ScaleType.Fit,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -d(24), 1, 0),
                Position = UDim2.new(0, d(20), 0, 0),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local b = use(primaryBoost)
                    if not b then return "" end
                    local mult = b.multiplier or 1
                    return ("x%g · %s"):format(mult, fmtTime(use(localRemaining) or 0))
                end),
                TextSize = d(12),
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.fromRGB(255, 215, 90),
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        },
    })

    -- RGB-цикл UIStroke (Pet Sim style). Не блокирует — рекурсивный tween.
    task.spawn(function()
        local stroke
        for _, child in ipairs(chipFrame:GetChildren()) do
            if child:IsA("UIStroke") then
                stroke = child
                break
            end
        end
        if not stroke then return end
        local colors = {
            Color3.fromRGB(255, 200, 60),
            Color3.fromRGB(80, 200, 255),
            Color3.fromRGB(220, 100, 220),
            Color3.fromRGB(120, 255, 120),
        }
        local idx = 1
        while stroke.Parent do
            idx = (idx % #colors) + 1
            local tw = TweenService:Create(stroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Color = colors[idx],
            })
            tw:Play()
            tw.Completed:Wait()
        end
    end)

    return chipFrame
end

return BoostChip
