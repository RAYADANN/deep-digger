--!strict
-- FreezeDiagnostics.lua — диагностика фризов и просадок FPS с атрибуцией причин.
--
-- ЧТО ДЕЛАЕТ:
--   1. Каждый кадр меряет время (Heartbeat dt + RenderStepped dt).
--   2. Раз в кадр забирает счётчики активности из PerfBeacon (сколько партов
--      создано/удалено, break-эффектов, сетевых дельт, raycast'ов и т.д.).
--   3. Когда кадр > порога фриза — НЕМЕДЛЕННО печатает причину: что именно
--      произошло в этом кадре + системные метрики (физика, память, GC).
--   4. Копит статистику (avg/min FPS, p95/p99, гистограмма, worst-кадры) и по
--      запросу (/diagreport) или по таймеру печатает полный отчёт с разбивкой
--      «сколько суммарного лага дала каждая причина».
--
-- ПОЧЕМУ ТАК: MicroProfiler в Studio не читается через MCP, а «worst frame
-- 1300 мс» сам по себе не говорит ПОЧЕМУ. Этот модуль связывает длину кадра
-- с конкретной активностью игры в том же кадре → причина видна сразу.
--
-- ВАЖНО ПРО ФОКУС: RunService.RenderStepped троттлится, когда окно Studio НЕ в
-- фокусе (Heartbeat=60, Render≈15). Модуль это детектит и помечает FPS-цифры
-- как невалидные, но фризы-всплески (Heartbeat dt) остаются валидными.

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")

local shared = game:GetService("ReplicatedStorage"):WaitForChild("shared")
local PerfBeacon = require(shared.util.PerfBeacon)

-- ===== Пороги (мс) =====
local FREEZE_MS = 100        -- кадр длиннее → печать причины немедленно
local HITCH_MS = 50          -- «микрофриз» — копим в гистограмму, без спама
local BUCKETS = { 16, 33, 50, 100, 200, 500, 1000 } -- границы гистограммы (мс)

-- Поля PerfBeacon → человекочитаемые имена + к какой «причине» относятся.
-- weightMs: множитель не нужен — мы и так меряем dt; это просто метки.
local FIELD_LABELS: { [string]: string } = {
    partsCreated = "блоков создано",
    partsDestroyed = "блоков удалено (без анимации)",
    animDestroy = "break-анимаций (chunks+dust+shockwave)",
    fxChunks = "осколков (chunk parts)",
    fxDust = "пыль-эмиттеров",
    fxShockwave = "shockwave-сфер",
    fxCoinPop = "coin-pop'ов",
    fxDmgNumber = "цифр урона",
    deltaCalls = "applyDelta вызовов",
    deltaCreated = "created в дельтах",
    deltaRemoved = "removed в дельтах",
    deltaUpdated = "updated в дельтах",
    snapshotCalls = "snapshot'ов",
    raycasts = "raycast'ов (hover/click)",
    mineInvokes = "MineBlock-вызовов",
    hoverRebuild = "пересборок hover",
    playerPayloadApply = "PlayerStats/Inv-пейлоадов применено",
    hudSetData = "hud:setPlayerData вызовов",
    hudSetDataMs = "hud:setPlayerData (мс, суммарно в кадре)",
    miningHudDelta = "PlayerHudDelta (лёгкая дельта)",
    hudMiningDelta = "hud:applyMiningDelta вызовов",
    hudMiningDeltaMs = "hud:applyMiningDelta (мс, суммарно в кадре)",
}

-- Группировка полей в укрупнённые «причины» для итогового отчёта.
local CAUSE_GROUPS: { [string]: { string } } = {
    BLOCK_CREATE = { "partsCreated" },
    BREAK_FX = { "animDestroy", "fxChunks", "fxDust", "fxShockwave" },
    SERVER_DELTA = { "deltaCreated", "deltaRemoved", "deltaUpdated", "deltaCalls" },
    SNAPSHOT = { "snapshotCalls" },
    INPUT_RAYCAST = { "raycasts", "mineInvokes" },
    UI_FX = { "fxCoinPop", "fxDmgNumber" },
    HUD_FUSION = { "hudSetData", "playerPayloadApply" },
}

local FreezeDiagnostics = {}
FreezeDiagnostics.__index = FreezeDiagnostics

-- Состояние держим в _G, чтобы мониторинг пережил респавн (клиентские скрипты
-- перезагружаются, _G в Luau-VM — нет).
local function getState()
    local g = _G :: any
    if not g.DD_DIAG_STATE then
        g.DD_DIAG_STATE = {
            running = false,
            startClock = 0,
            frameCount = 0,
            renderFrameCount = 0,
            sumDt = 0,
            worstMs = 0,
            dts = {},                 -- все Heartbeat dt (мс) для перцентилей
            hist = {},                -- гистограмма по BUCKETS
            over = { [50] = 0, [100] = 0, [200] = 0, [500] = 0 },
            worstFrames = {},         -- топ-N кадров с атрибуцией
            causeMs = {},             -- cause -> суммарный лаг (мс) кадров, где он доминировал
            totals = {},              -- суммарные счётчики PerfBeacon за сессию
            lastHeap = 0,
            lastMem = 0,
            peakHeapMb = 0,
            renderDt = 0,             -- последний RenderStepped dt (мс)
            focusWarned = false,
        }
    end
    return g.DD_DIAG_STATE
end

local TOP_FRAMES = 15

local function pct(sorted: { number }, p: number): number
    local n = #sorted
    if n == 0 then return 0 end
    local idx = math.clamp(math.ceil(p / 100 * n), 1, n)
    return sorted[idx]
end

-- Определяет доминирующую причину кадра по счётчикам PerfBeacon + системным
-- метрикам. Возвращает (causeTag, описание).
local function attribute(frame): (string, string)
    local c = frame.counts
    -- Порядок проверок = приоритет атрибуции.
    -- HUD/Fusion проверяем ПЕРВЫМ и по ИЗМЕРЕННОМУ времени (hudSetDataMs), а не
    -- по косвенным признакам: hud:setPlayerData дёргается на каждый mine (сервер
    -- шлёт PlayerStats+PlayerInventory) и пересобирает Fusion-граф — это главный
    -- подозреваемый по heap-аллокациям. Если измеренное время доминирует в
    -- кадре — это точно он, без догадок.
    local hudMs = c.hudSetDataMs or 0
    local miningHudMs = c.hudMiningDeltaMs or 0
    if miningHudMs >= frame.ms * 0.5 and miningHudMs > 5 then
        return "HUD_MINING", string.format(
            "hud:applyMiningDelta занял %d мс из %d мс кадра",
            math.floor(miningHudMs), math.floor(frame.ms))
    end
    if hudMs >= frame.ms * 0.5 and hudMs > 30 then
        return "HUD_FUSION", string.format(
            "hud:setPlayerData занял %d мс из %d мс кадра (×%d вызовов)",
            math.floor(hudMs), math.floor(frame.ms), c.hudSetData or 0)
    end
    if (c.snapshotCalls or 0) > 0 then
        return "SNAPSHOT", string.format("snapshot (%d блоков в очередь)", c.partsCreated or 0)
    end
    local created = c.partsCreated or 0
    local breaks = (c.animDestroy or 0)
    local deltaCreated = c.deltaCreated or 0
    local deltaRemoved = c.deltaRemoved or 0

    -- Большая серверная дельта (пробитие полости): много created/removed разом.
    if deltaCreated >= 20 or deltaRemoved >= 10 then
        return "SERVER_DELTA", string.format("дельта-всплеск: +%d / -%d блоков", deltaCreated, deltaRemoved)
    end
    if breaks >= 4 then
        return "BREAK_FX", string.format("%d break-анимаций (chunks/dust/shockwave) в кадре", breaks)
    end
    if created >= 15 then
        return "BLOCK_CREATE", string.format("%d _createPart в кадре", created)
    end
    -- Память/GC: heap скакнул в этом кадре.
    if frame.heapDeltaKb and frame.heapDeltaKb > 4096 then
        -- Если в этом же кадре был HUD-апдейт и почти нет работы с блоками —
        -- это отложенная пересборка Fusion-графа (аллокации после setPlayerData).
        if (c.hudSetData or 0) > 0 and created < 5 and breaks < 2 then
            return "HUD_FUSION", string.format(
                "+%.1f МБ heap + hud:setPlayerData ×%d (отложенная пересборка Fusion)",
                frame.heapDeltaKb / 1024, c.hudSetData or 0)
        end
        return "GC_ALLOC", string.format("+%.1f МБ Lua-heap за кадр (аллокации/GC)", frame.heapDeltaKb / 1024)
    end
    -- Физика: реальный physics FPS просел.
    if frame.physicsFps and frame.physicsFps > 0 and frame.physicsFps < 40 then
        return "PHYSICS", string.format("physics FPS=%d (упавшие осколки/коллизии)", math.floor(frame.physicsFps))
    end
    -- Рендер: RenderStepped >> Heartbeat → GPU/рендер-бутылочное горло.
    if frame.renderMs and frame.renderMs > frame.ms * 1.5 and frame.renderMs > FREEZE_MS then
        return "RENDER_GPU", string.format("render dt=%d мс >> heartbeat=%d мс", math.floor(frame.renderMs), math.floor(frame.ms))
    end
    if breaks > 0 or created > 0 then
        return "MIXED", string.format("смешанное: +%d блоков, %d эффектов", created, breaks)
    end
    return "UNKNOWN", "нет активности игры в кадре (движок/GC/внешнее)"
end

local function describeCounts(counts): string
    local parts = {}
    for field, label in pairs(FIELD_LABELS) do
        local v = counts[field]
        if v and v > 0 then
            table.insert(parts, string.format("%s=%d", label, v))
        end
    end
    if #parts == 0 then return "(пусто)" end
    table.sort(parts)
    return table.concat(parts, ", ")
end

function FreezeDiagnostics.start(opts)
    opts = opts or {}
    local s = getState()

    -- Респавн: клиентские скрипты перезагрузились, старые коннекшены мертвы, но
    -- _G.running ещё true. Не сбрасываем накопленную статистику — просто
    -- переподключаемся, чтобы мониторинг продолжился сквозь смерть/респавн.
    local isReconnect = s.running and (not s._hbConn or not s._hbConn.Connected)
    if s.running and s._hbConn and s._hbConn.Connected then
        print("[Diag] Уже запущено. /diagreport — отчёт, /diagstop — стоп.")
        return
    end

    FREEZE_MS = opts.freezeMs or FREEZE_MS

    if not isReconnect then
        -- Новая сессия — полный сброс.
        s.startClock = os.clock()
        s.frameCount = 0
        s.renderFrameCount = 0
        s.sumDt = 0
        s.worstMs = 0
        s.dts = {}
        s.hist = {}
        s.over = { [50] = 0, [100] = 0, [200] = 0, [500] = 0 }
        s.worstFrames = {}
        s.causeMs = {}
        s.totals = {}
        s.peakHeapMb = 0
        s.focusWarned = false
        PerfBeacon.reset()
    end
    s.running = true
    s.lastHeap = collectgarbage("count")
    s.renderDt = 0
    PerfBeacon.enabled = true

    -- RenderStepped: меряем рендер-кадр отдельно (детект троттлинга/GPU).
    s._renderConn = RunService.RenderStepped:Connect(function(dt)
        s.renderFrameCount += 1
        s.renderDt = dt * 1000
    end)

    -- Heartbeat: основной кадровый замер + атрибуция.
    s._hbConn = RunService.Heartbeat:Connect(function(dt)
        local ms = dt * 1000
        s.frameCount += 1
        s.sumDt += dt

        -- Перцентили: храним dt (с разумным капом, чтобы не течь в долгой сессии).
        if #s.dts < 50000 then
            s.dts[#s.dts + 1] = ms
        end

        -- Гистограмма.
        for _, b in ipairs(BUCKETS) do
            if ms <= b then
                s.hist[b] = (s.hist[b] or 0) + 1
                break
            end
        end
        if ms > BUCKETS[#BUCKETS] then
            s.hist.huge = (s.hist.huge or 0) + 1
        end
        for thr, _ in pairs(s.over) do
            if ms > thr then s.over[thr] += 1 end
        end

        -- Забираем активность кадра.
        local counts = PerfBeacon.drain()
        for k, v in pairs(counts) do
            s.totals[k] = (s.totals[k] or 0) + v
        end

        if ms > s.worstMs then s.worstMs = ms end

        -- Heap-дельта (KB) для атрибуции GC/аллокаций.
        local heap = collectgarbage("count")
        local heapDeltaKb = heap - (s.lastHeap or heap)
        s.lastHeap = heap
        local heapMb = heap / 1024
        if heapMb > s.peakHeapMb then s.peakHeapMb = heapMb end

        -- Системные метрики собираем только для «тяжёлых» кадров (дёшево).
        local frame = {
            ms = ms,
            renderMs = s.renderDt,
            counts = counts,
            heapDeltaKb = heapDeltaKb,
            atSec = os.clock() - s.startClock,
        }

        if ms >= HITCH_MS then
            -- Дорогие метрики — только когда уже есть просадка.
            local ok, pfps = pcall(function() return workspace:GetRealPhysicsFPS() end)
            frame.physicsFps = ok and pfps or nil
        end

        if ms >= FREEZE_MS then
            local cause, desc = attribute(frame)
            frame.cause = cause
            frame.desc = desc
            s.causeMs[cause] = (s.causeMs[cause] or 0) + ms

            -- Топ-N worst кадров.
            table.insert(s.worstFrames, frame)
            table.sort(s.worstFrames, function(a, b) return a.ms > b.ms end)
            while #s.worstFrames > TOP_FRAMES do
                table.remove(s.worstFrames)
            end

            -- Немедленная печать причины.
            print(string.format(
                "[Diag] ФРИЗ %d мс @ %.1fс | ПРИЧИНА: %s — %s | детали: %s",
                math.floor(ms), frame.atSec, cause, desc, describeCounts(counts)
            ))
        end

        -- Детект троттлинга фона (раз за сессию).
        if not s.focusWarned and s.frameCount == 120 then
            local hbFps = s.frameCount / (os.clock() - s.startClock)
            local rsFps = s.renderFrameCount / (os.clock() - s.startClock)
            if hbFps > 40 and rsFps < hbFps * 0.5 then
                s.focusWarned = true
                print(string.format(
                    "[Diag] ВНИМАНИЕ: окно Studio в фоне (Heartbeat≈%d, Render≈%d FPS). "
                    .. "FPS-цифры НЕВАЛИДНЫ — кликни на окно Studio. Фризы-всплески валидны.",
                    math.floor(hbFps), math.floor(rsFps)
                ))
            end
        end
    end)

    if isReconnect then
        print("[Diag] Переподключено после респавна (статистика сохранена).")
    else
        print(string.format(
            "[Diag] Мониторинг запущен (порог фриза=%d мс). Команды: /diagreport, /diagstop, /diagreset.",
            FREEZE_MS
        ))
    end
    if opts.autoReportSec and opts.autoReportSec > 0 then
        task.delay(opts.autoReportSec, function()
            if getState().running then
                FreezeDiagnostics.report()
            end
        end)
    end
end

function FreezeDiagnostics.report()
    local s = getState()
    if s.frameCount == 0 then
        print("[Diag] Нет данных (мониторинг не запущен?).")
        return
    end
    local elapsed = os.clock() - s.startClock
    local hbFps = s.frameCount / elapsed
    local rsFps = s.renderFrameCount / elapsed
    local avgFps = s.sumDt > 0 and (s.frameCount / s.sumDt) or 0

    local sorted = table.clone(s.dts)
    table.sort(sorted)

    print("==================== [Diag] ОТЧЁТ О ПРОИЗВОДИТЕЛЬНОСТИ ====================")
    print(string.format("Длительность: %.1f с | кадров(HB): %d | кадров(Render): %d",
        elapsed, s.frameCount, s.renderFrameCount))
    print(string.format("FPS: Heartbeat≈%d, Render≈%d%s",
        math.floor(hbFps), math.floor(rsFps),
        (rsFps < hbFps * 0.5 and hbFps > 40) and "  ⚠ ОКНО В ФОНЕ — Render троттлится, FPS невалиден" or ""))
    local avgMs = s.frameCount > 0 and (s.sumDt * 1000 / s.frameCount) or 0
    print(string.format("Кадр (мс): avg=%.1f  p50=%.1f  p95=%.1f  p99=%.1f  worst=%d",
        avgMs, pct(sorted, 50), pct(sorted, 95), pct(sorted, 99), math.floor(s.worstMs)))
    print(string.format("Фризы: >50мс=%d  >100мс=%d  >200мс=%d  >500мс=%d",
        s.over[50], s.over[100], s.over[200], s.over[500]))
    print(string.format("Lua-heap: текущий=%.1f МБ, пик=%.1f МБ", collectgarbage("count") / 1024, s.peakHeapMb))

    -- Гистограмма.
    local histParts = {}
    local prev = 0
    for _, b in ipairs(BUCKETS) do
        table.insert(histParts, string.format("≤%dмс:%d", b, s.hist[b] or 0))
        prev = b
    end
    table.insert(histParts, string.format(">%dмс:%d", prev, s.hist.huge or 0))
    print("Гистограмма кадров: " .. table.concat(histParts, "  "))

    -- Разбивка лага по причинам.
    print("---- ВКЛАД ПРИЧИН В ЛАГ (сумма мс фриз-кадров, где причина доминировала) ----")
    local causeList = {}
    for cause, msSum in pairs(s.causeMs) do
        table.insert(causeList, { cause = cause, ms = msSum })
    end
    table.sort(causeList, function(a, b) return a.ms > b.ms end)
    if #causeList == 0 then
        print("  (фризов выше порога не зафиксировано — хорошо!)")
    else
        for _, e in ipairs(causeList) do
            print(string.format("  %-14s %6d мс суммарно", e.cause, math.floor(e.ms)))
        end
    end

    -- Топ worst кадров.
    print("---- ТОП WORST КАДРОВ ----")
    for i, f in ipairs(s.worstFrames) do
        print(string.format("  #%d  %d мс @ %.1fс  [%s] %s",
            i, math.floor(f.ms), f.atSec, f.cause or "?", f.desc or ""))
        print(string.format("        активность: %s", describeCounts(f.counts)))
    end

    -- Суммарные счётчики за сессию.
    print("---- СУММАРНАЯ АКТИВНОСТЬ ЗА СЕССИЮ ----")
    print("  " .. describeCounts(s.totals))
    print("============================================================================")
end

function FreezeDiagnostics.stop()
    local s = getState()
    if not s.running then
        print("[Diag] Мониторинг не запущен.")
        return
    end
    FreezeDiagnostics.report()
    s.running = false
    PerfBeacon.enabled = false
    if s._hbConn then s._hbConn:Disconnect(); s._hbConn = nil end
    if s._renderConn then s._renderConn:Disconnect(); s._renderConn = nil end
    print("[Diag] Мониторинг остановлен.")
end

function FreezeDiagnostics.reset()
    local s = getState()
    local wasRunning = s.running
    if wasRunning then
        if s._hbConn then s._hbConn:Disconnect(); s._hbConn = nil end
        if s._renderConn then s._renderConn:Disconnect(); s._renderConn = nil end
        s.running = false
    end
    (_G :: any).DD_DIAG_STATE = nil
    print("[Diag] Состояние сброшено.")
    if wasRunning then
        FreezeDiagnostics.start()
    end
end

return FreezeDiagnostics
