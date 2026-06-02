--!strict
-- Haptics.lua — мобильная вибрация по событиям геймплея.
--
-- Все вызовы HapticService обёрнуты в pcall: на десктопе/Mac/некоторых
-- Studio-билдах он любит кидать "GamepadConnected" и подобные исключения.
-- На мобильниках с активным touch — даёт реальную вибрацию через системный API.
--
-- Сила импульса фиксированная per-preset, длительность короткая (50–120 мс) — это
-- ритмично совпадает с длительностью CameraShake и не превращает игру в массажёр.

local HapticService = game:GetService("HapticService")
local UserInputService = game:GetService("UserInputService")

local Haptics = {}

type Preset = { intensity: number, duration: number }

-- В mining-сим игрок кликает 3–4 раза в секунду — hit-вибрация должна быть
-- ОЧЕНЬ лёгкой, иначе телефон превращается в массажёр и аккумулятор сядет
-- за 10 минут. На крите и разрушении — сильнее, событие.
local PRESETS: { [string]: Preset } = {
    hit = { intensity = 0.12, duration = 0.03 },
    crit = { intensity = 0.4, duration = 0.06 },
    ["break"] = { intensity = 0.6, duration = 0.08 },
    legendary_break = { intensity = 1.0, duration = 0.15 },
}

local function isMobile(): boolean
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local _enabled = true

function Haptics.setEnabled(on: boolean)
    _enabled = on
end

function Haptics.pulse(preset: string)
    if not _enabled then
        return
    end
    if not isMobile() then
        return
    end
    local p = PRESETS[preset]
    if not p then
        return
    end

    pcall(function()
        HapticService:SetMotor(
            Enum.UserInputType.Gamepad1,
            Enum.VibrationMotor.Large,
            p.intensity
        )
    end)

    task.delay(p.duration, function()
        pcall(function()
            HapticService:SetMotor(
                Enum.UserInputType.Gamepad1,
                Enum.VibrationMotor.Large,
                0
            )
        end)
    end)
end

return Haptics
