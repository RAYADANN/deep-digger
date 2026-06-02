--!strict
-- CameraShake.lua — лёгкий screen-shake поверх любой камеры.
--
-- Принцип: на RenderStepped считаем суммарный offset от всех активных шейков,
-- применяем его как CFrame.new(offset) * camera.CFrame **после** того, как Roblox
-- сам обновил камеру в этом кадре. В конце следующего кадра откатываем
-- предыдущий offset через сохранённый "applied" CFrame — так пользовательский
-- CameraScript / CameraType.Custom продолжают работать без накопления дрейфа.
--
-- Несколько шейков складываются (intensity суммируется, затухает по своему таймеру).
-- Пресеты в Constants ниже — единственный источник «силы» эффекта в игре.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraShake = {}

type Shake = {
    intensity: number,
    startedAt: number,
    duration: number,
}

-- Mining-сим: камеру трясём ТОЛЬКО на разрушении блока, и только начиная с
-- rare. Hit / crit пресеты оставлены в API для будущего (например, бой с
-- боссом в патче 1.1) — но MiningRenderer их не дёргает.
--
-- Числа подобраны так, чтобы:
--   * rare_break — еле заметное "удар тяжёлого блока",
--   * break (epic) — ощутимый, но не мешающий следующему клику,
--   * legendary_break — событие, читается даже периферийным зрением.
local PRESETS: { [string]: { intensity: number, duration: number } } = {
    hit = { intensity = 0.04, duration = 0.04 },
    crit = { intensity = 0.1, duration = 0.08 },
    rare_break = { intensity = 0.05, duration = 0.08 },
    ["break"] = { intensity = 0.09, duration = 0.12 },
    legendary_break = { intensity = 0.22, duration = 0.25 },
}

local _started = false
local _camera: Camera? = nil
local _conn: RBXScriptConnection? = nil
local _active: { Shake } = {}
local _lastOffset = Vector3.zero

local function currentCamera(): Camera?
    return _camera or Workspace.CurrentCamera
end

-- Активные шейки фильтруются прямо на месте: завершённые удаляются, активные
-- складываются с экспоненциальным затуханием. Random offset берётся раз за кадр,
-- умножается на суммарную intensity.
local function step()
    local cam = currentCamera()
    if not cam then
        _lastOffset = Vector3.zero
        return
    end

    -- 1) Снимаем предыдущий offset, чтобы не накапливался.
    if _lastOffset.Magnitude > 0 then
        cam.CFrame = cam.CFrame * CFrame.new(-_lastOffset)
        _lastOffset = Vector3.zero
    end

    if #_active == 0 then
        return
    end

    local now = os.clock()
    local total = 0
    local i = 1
    while i <= #_active do
        local s = _active[i]
        local elapsed = now - s.startedAt
        if elapsed >= s.duration then
            table.remove(_active, i)
        else
            local remaining = 1 - (elapsed / s.duration)
            total += s.intensity * remaining
            i += 1
        end
    end

    if total <= 0 then
        return
    end

    local offset = Vector3.new(
        (math.random() * 2 - 1) * total,
        (math.random() * 2 - 1) * total,
        (math.random() * 2 - 1) * total * 0.5
    )

    cam.CFrame = cam.CFrame * CFrame.new(offset)
    _lastOffset = offset
end

function CameraShake.start(camera: Camera?)
    _camera = camera
    if _started then
        return
    end
    _started = true
    _conn = RunService.RenderStepped:Connect(step)
end

function CameraShake.stop()
    if _conn then
        _conn:Disconnect()
        _conn = nil
    end
    _started = false
    _active = {}
    -- Откат последнего offset, чтобы камера осталась на правильной позиции.
    local cam = currentCamera()
    if cam and _lastOffset.Magnitude > 0 then
        cam.CFrame = cam.CFrame * CFrame.new(-_lastOffset)
    end
    _lastOffset = Vector3.zero
end

function CameraShake.shake(intensity: number, duration: number)
    if intensity <= 0 or duration <= 0 then
        return
    end
    table.insert(_active, {
        intensity = intensity,
        startedAt = os.clock(),
        duration = duration,
    })
end

function CameraShake.shakePreset(preset: string)
    local p = PRESETS[preset]
    if not p then
        return
    end
    CameraShake.shake(p.intensity, p.duration)
end

return CameraShake
