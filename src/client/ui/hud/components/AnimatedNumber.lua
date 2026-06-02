--!strict
-- AnimatedNumber.lua — Phase 8.
--
-- Плавный count-up для Fusion.Value<number> в HUD:
--   `AnimatedNumber.tween(state, target, duration?)`
--
-- Зачем не TweenService на самой Value: Fusion.Value не Instance, ему
-- нельзя задать TweenInfo. Делаем сами через RunService.Heartbeat —
-- интерполируем от текущего `peek(state)` к `target` с Quad/Out, дёргаем
-- `state:set()` каждый кадр.
--
-- Что НЕ tween-ить:
--   - depth, levels, inventoryCount — это «дискретные» значения, плавная
--     анимация делает их неинформативными.
--   - Числа, которые меняются десятки раз в секунду — заведут анимацию в
--     дрожь. Здесь `cancel previous` спасает: новый tween стартует с того,
--     где остановился предыдущий.
--
-- API:
--   AnimatedNumber.tween(state, 1234)        — 0.3с по умолчанию
--   AnimatedNumber.tween(state, 1234, 0.6)   — кастомная длительность
--   AnimatedNumber.cancel(state)             — остановить tween
--   AnimatedNumber.snap(state, value)        — поставить значение без tween

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local peek = Fusion.peek

local DEFAULT_DURATION = 0.3
local EPSILON = 0.01

-- Активные tween-сессии, ключ — Fusion.Value, чтобы повторный tween по тому
-- же state отменял предыдущий. Слабая мапа: если state будет уничтожен,
-- запись соберёт GC.
local active: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any

local AnimatedNumber = {}

-- Quad/Out: f(t) = 1 - (1 - t)^2. Чистая, не зависит от TweenService.
local function easeOutQuad(t: number): number
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    local inv = 1 - t
    return 1 - inv * inv
end

function AnimatedNumber.cancel(state: any)
    local session = active[state]
    if not session then
        return
    end
    active[state] = nil
    if session.conn then
        session.conn:Disconnect()
        session.conn = nil
    end
end

function AnimatedNumber.snap(state: any, value: number)
    AnimatedNumber.cancel(state)
    state:set(value)
end

function AnimatedNumber.tween(state: any, target: number, duration: number?)
    if typeof(target) ~= "number" then
        return
    end
    local current = peek(state)
    if typeof(current) ~= "number" then
        current = 0
    end
    -- Уже на цели — отменяем активный tween и просто фиксируем.
    if math.abs(current - target) < EPSILON then
        AnimatedNumber.cancel(state)
        state:set(target)
        return
    end

    local dur = duration or DEFAULT_DURATION
    if dur <= 0 then
        AnimatedNumber.snap(state, target)
        return
    end

    -- Отменяем предыдущий tween, но СТАРТУЕМ с того значения, где он
    -- остановился (которое уже в peek(state)). Это убирает «скачок назад»,
    -- если несколько payload'ов прилетели подряд.
    AnimatedNumber.cancel(state)

    local startValue = current
    local startTime = os.clock()
    local session: any = { conn = nil }
    active[state] = session

    session.conn = RunService.Heartbeat:Connect(function()
        -- Если кто-то снаружи пересоздал session (повторный tween) — выходим.
        if active[state] ~= session then
            if session.conn then session.conn:Disconnect() end
            return
        end
        local elapsed = os.clock() - startTime
        local progress = math.clamp(elapsed / dur, 0, 1)
        local eased = easeOutQuad(progress)
        local value = startValue + (target - startValue) * eased
        if progress >= 1 then
            state:set(target)
            if session.conn then
                session.conn:Disconnect()
                session.conn = nil
            end
            if active[state] == session then
                active[state] = nil
            end
        else
            state:set(value)
        end
    end)
end

return AnimatedNumber
