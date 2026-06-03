--!strict
-- PerfBeacon.lua — сверхлёгкий счётчик активности для атрибуции фризов.
--
-- Идея: системы (рендер, эффекты, сеть) «звонят в колокол» на каждое
-- потенциально дорогое действие — bump("partsCreated"), addTime("deltaMs", ms)
-- и т.п. FreezeDiagnostics раз в кадр забирает накопленное (drain) и
-- сопоставляет с длиной кадра. Так мы узнаём НЕ просто «кадр был 800 мс», а
-- «кадр был 800 мс, и в нём создалось 137 партов + 39 break-эффектов».
--
-- Стоимость: bump = одно сложение в таблице. Когда enabled=false — ранний
-- выход, накладные расходы ~ноль (можно оставлять вызовы в проде).
--
-- ВАЖНО: модуль лежит в ReplicatedStorage.shared → единый синглтон на VM,
-- переживает респавн клиента (LocalScript'ы перезагружаются, ModuleScript нет).

local PerfBeacon = {}

-- Глобальный выключатель. FreezeDiagnostics включает при старте мониторинга.
PerfBeacon.enabled = false

-- Текущее окно накопления (один кадр). drain() обнуляет.
local counts: { [string]: number } = {}

-- Накопить счётчик события (по умолчанию +1).
function PerfBeacon.bump(field: string, n: number?)
    if not PerfBeacon.enabled then return end
    counts[field] = (counts[field] or 0) + (n or 1)
end

-- Накопить время (мс) в поле-аккумуляторе (имя обычно с суффиксом "Ms").
function PerfBeacon.addTime(field: string, ms: number)
    if not PerfBeacon.enabled then return end
    counts[field] = (counts[field] or 0) + ms
end

-- Забрать накопленное и обнулить окно (вызывается раз в кадр диагностикой).
function PerfBeacon.drain(): { [string]: number }
    local out = counts
    counts = {}
    return out
end

-- Посмотреть без обнуления (для отладки).
function PerfBeacon.peek(): { [string]: number }
    return counts
end

-- Полный сброс (на старт новой сессии мониторинга).
function PerfBeacon.reset()
    counts = {}
end

return PerfBeacon
