--!strict
-- DailyLogic.lua — Phase 10.
--
-- Единственный источник формул daily-reward цикла (по аналогии с
-- RebirthLogic.lua). Любые потребители — сервер (DailyReward,
-- DevCommands), клиент (DailyRewardModal countdown) — обязаны звать
-- функции отсюда. Никаких os.date("!*t").yday в двух местах.
--
-- API:
--   DailyLogic.currentDay(now?)           -> { yday, year }
--   DailyLogic.daysBetween(prev, curr)    -> number  (gap в днях, ≥ 0)
--   DailyLogic.canClaim(dailyState, now?) -> boolean
--   DailyLogic.nextStreak(dailyState, now?) -> number  (1..7 — следующий день
--                                                       при claim'е СЕЙЧАС)
--   DailyLogic.streakToCycleDay(streak)   -> number  (1..7)
--   DailyLogic.timeUntilNextDay(now?)     -> { hours, minutes, seconds, total }
--                                                       время до 00:00 UTC
--
-- Принципы:
--   * UTC, не локальное. os.date("!*t") с восклицательным знаком.
--   * Год учитывается: 31 декабря (yday=365) → 1 января (yday=1) — gap == 1,
--     не -364.
--   * Streak max = Constants.DAILY.cycleDays (7). После Day 7 cycle сбрасывается
--     в 0, следующий claim снова Day 1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local DailyLogic = {}

local function cfg()
    return Constants.DAILY or {}
end

local function cycleDays(): number
    return cfg().cycleDays or 7
end

local function resetThreshold(): number
    return cfg().streakResetAfterMissedDays or 2
end

-- Текущий день UTC. Принимает опциональный `now` (unix-timestamp) для
-- тестов / симуляций DevCommand /setday.
function DailyLogic.currentDay(now: number?): { yday: number, year: number }
    local t = os.date("!*t", now or os.time())
    return { yday = t.yday, year = t.year }
end

--[[
    Возвращает количество прошедших дней между prev (lastClaim) и curr
    (current day). Учитывает переход через границу года: 365/366 + curr.yday.

    prev = { yday=0, year=0 } (свежий профиль) → возвращаем большое число,
    чтобы canClaim был true и было видно, что игрок никогда не claim'ил.

    Гарантирует gap >= 0. Если профиль будущий (прыжок назад в /setday) —
    это валидный кейс, тоже разрешаем (gap = 0, как «уже сегодня claim'ил»).
]]
function DailyLogic.daysBetween(prev: { yday: number, year: number }, curr: { yday: number, year: number }): number
    if not prev or (prev.yday or 0) <= 0 then
        return math.huge  -- никогда не claim'ил
    end
    if curr.year == prev.year then
        return math.max(0, curr.yday - prev.yday)
    end
    if curr.year > prev.year then
        -- Сколько дней было в годах между prev.year и curr.year-1.
        -- Достаточно знать длину prev.year (365 или 366) + одна точка в
        -- curr.year. Для multi-year gap (игрок не заходил 2+ года) считаем
        -- консервативно через високосность.
        local total = 0
        local function daysInYear(y: number): number
            local isLeap = (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
            return isLeap and 366 or 365
        end
        -- От prev.yday до конца prev.year.
        total += daysInYear(prev.year) - prev.yday
        -- Полные годы между.
        for y = prev.year + 1, curr.year - 1 do
            total += daysInYear(y)
        end
        -- В curr.year прошло yday дней.
        total += curr.yday
        return total
    end
    -- curr.year < prev.year — клиент сломан или /setday прыгнул назад.
    -- Возвращаем 0 (= уже claim'ил сегодня), безопасно для UI.
    return 0
end

--[[
    Может ли игрок claim'нуть сегодня?

    true если:
      * никогда не claim'ил (lastClaimYday == 0),
      * прошёл хотя бы 1 день с последнего claim'а.

    false если:
      * gap == 0 (сегодня уже забрал).
]]
function DailyLogic.canClaim(dailyState: any, now: number?): boolean
    if not dailyState then
        return true
    end
    local last = { yday = dailyState.lastClaimYday or 0, year = dailyState.lastClaimYear or 0 }
    local curr = DailyLogic.currentDay(now)
    local gap = DailyLogic.daysBetween(last, curr)
    return gap >= 1
end

--[[
    Возвращает streak, который получит игрок при claim'е СЕЙЧАС:
      * gap >= streakResetAfterMissedDays  → 1 (reset),
      * gap == 1 (вчера claim'ил)          → currentStreak + 1, но <= 7,
                                              иначе цикл начинается заново (1).
      * никогда не claim'ил                → 1.
      * gap == 0 (сегодня уже)             → currentStreak (без изменений).

    Используется DailyReward._handleClaim: считаем новый streak ДО мутации
    профиля, потом записываем.
]]
function DailyLogic.nextStreak(dailyState: any, now: number?): number
    if not dailyState or (dailyState.lastClaimYday or 0) <= 0 then
        return 1
    end
    local last = { yday = dailyState.lastClaimYday or 0, year = dailyState.lastClaimYear or 0 }
    local curr = DailyLogic.currentDay(now)
    local gap = DailyLogic.daysBetween(last, curr)
    local current = dailyState.currentStreak or 0
    if gap >= resetThreshold() then
        return 1
    end
    if gap == 0 then
        return current
    end
    -- gap == 1: продолжаем streak. После Day 7 цикл начинается заново.
    local next = current + 1
    local maxStreak = cycleDays()
    if next > maxStreak then
        return 1
    end
    return next
end

--[[
    Маппинг streak (1..cycleDays) в day-номер цикла (1..7).
    После Day 7 nextStreak уже вернёт 1, так что здесь чистая identity —
    но оставляем функцию, чтобы UI не делал math.clamp вручную.
]]
function DailyLogic.streakToCycleDay(streak: number): number
    local s = math.max(1, math.floor(streak or 1))
    local max = cycleDays()
    if s > max then
        return ((s - 1) % max) + 1
    end
    return s
end

--[[
    Сколько времени до 00:00 UTC следующего дня. UI показывает «Через 23ч 14м».
    Возвращает структуру с total в секундах для удобства tick'a.
]]
function DailyLogic.timeUntilNextDay(now: number?): { hours: number, minutes: number, seconds: number, total: number }
    local t = now or os.time()
    local utc = os.date("!*t", t)
    -- Секунды от полуночи UTC.
    local secondsToday = utc.hour * 3600 + utc.min * 60 + utc.sec
    local total = 86400 - secondsToday
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local seconds = total % 60
    return {
        hours = hours,
        minutes = minutes,
        seconds = seconds,
        total = total,
    }
end

return DailyLogic
