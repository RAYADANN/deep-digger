--!strict
-- DailyQuestLogic.lua — P1.5 (повторяемые ежедневные задания).
--
-- В отличие от QuestLogic (последовательная цепочка одноразовых квестов),
-- ежедневки сбрасываются каждый UTC-день и дают повторяемую петлю + гемы
-- (синергия с gem-сливом Desert Egg, P1.6).
--
-- Прогресс считается как ДЕЛЬТА кумулятивных счётчиков от дневного baseline:
--   progress = max(0, current[metric] - baseline[metric]).
-- baseline снимается при первом заходе в новый день. Метрики выбраны только
-- монотонно растущие при игре (blocksMined / coinsEarned / shaftRooms), чтобы
-- ежедневка всегда была выполнима — depth/oresDiscovered у ветеранов упёрты в
-- потолок и не годятся для дельты.
--
-- Состояние в playerData.dailyQuests:
--   { yday, year, baseline = { [metric]: number }, claimed = { [id]: true } }
--
-- API:
--   DailyQuestLogic.getAll()            -> { Def }
--   DailyQuestLogic.ensureReset(data)   -> boolean (true если день сменился)
--   DailyQuestLogic.progress(data, def) -> number
--   DailyQuestLogic.isComplete(data, def) -> boolean
--   DailyQuestLogic.isClaimed(data, id) -> boolean
--   DailyQuestLogic.getById(id)         -> Def?
--   DailyQuestLogic.buildPayload(data)  -> { Entry } + secondsUntilReset
--   DailyQuestLogic.secondsUntilReset() -> number

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local DiscoveryLogic = require(shared.util.DiscoveryLogic)

export type DailyMetric = "blocksMined" | "coinsEarned" | "shaftRooms"

export type DailyQuestDef = {
    id: string,
    name: string,
    desc: string,
    metric: DailyMetric,
    target: number,
    reward: { coins: number?, gems: number? },
}

local DailyQuestLogic = {}

local DAILY_QUESTS: { DailyQuestDef } = {
    {
        id = "dq_mine",
        name = "Дневная норма",
        desc = "Добыть 300 блоков сегодня",
        metric = "blocksMined",
        target = 300,
        reward = { coins = 2500, gems = 10 },
    },
    {
        id = "dq_coins",
        name = "Дневной доход",
        desc = "Заработать 8 000 монет сегодня",
        metric = "coinsEarned",
        target = 8000,
        reward = { coins = 3000, gems = 10 },
    },
    {
        id = "dq_rooms",
        name = "Исследователь",
        desc = "Найти 2 скрытые комнаты сегодня",
        metric = "shaftRooms",
        target = 2,
        reward = { coins = 2000, gems = 15 },
    },
}

local METRICS_USED = { "blocksMined", "coinsEarned", "shaftRooms" }

function DailyQuestLogic.getAll(): { DailyQuestDef }
    return DAILY_QUESTS
end

function DailyQuestLogic.getById(id: string): DailyQuestDef?
    for _, def in ipairs(DAILY_QUESTS) do
        if def.id == id then
            return def
        end
    end
    return nil
end

local function cumulativeValue(data: any, metric: string): number
    if metric == "blocksMined" then
        return data.totalBlocksMined or 0
    elseif metric == "coinsEarned" then
        return data.totalCoinsEarned or 0
    elseif metric == "shaftRooms" then
        return data.shaftRoomCount or 0
    elseif metric == "oresDiscovered" then
        return DiscoveryLogic.totalProgress(data).found
    end
    return 0
end

local function snapshot(data: any): { [string]: number }
    local base = {}
    for _, metric in ipairs(METRICS_USED) do
        base[metric] = cumulativeValue(data, metric)
    end
    return base
end

-- UTC «день года» + год — единый сброс для всех игроков (как DailyReward).
local function todayKey(): (number, number)
    local t = os.date("!*t")
    return t.yday, t.year
end

function DailyQuestLogic.secondsUntilReset(): number
    local t = os.date("!*t")
    local secsToday = t.hour * 3600 + t.min * 60 + t.sec
    return math.max(0, 86400 - secsToday)
end

-- Гарантирует актуальность data.dailyQuests для текущего дня. Возвращает true,
-- если день сменился (baseline переснят, claimed очищен). Идемпотентно.
function DailyQuestLogic.ensureReset(data: any): boolean
    if typeof(data.dailyQuests) ~= "table" then
        data.dailyQuests = { yday = 0, year = 0, baseline = {}, claimed = {} }
    end
    local dq = data.dailyQuests
    local yday, year = todayKey()
    if dq.yday ~= yday or dq.year ~= year then
        dq.yday = yday
        dq.year = year
        dq.baseline = snapshot(data)
        dq.claimed = {}
        return true
    end
    if typeof(dq.baseline) ~= "table" then
        dq.baseline = snapshot(data)
    end
    if typeof(dq.claimed) ~= "table" then
        dq.claimed = {}
    end
    return false
end

function DailyQuestLogic.progress(data: any, def: DailyQuestDef): number
    local dq = data.dailyQuests or {}
    local base = (dq.baseline or {})[def.metric]
    local current = cumulativeValue(data, def.metric)
    if typeof(base) ~= "number" then
        base = current
    end
    return math.max(0, current - base)
end

function DailyQuestLogic.isComplete(data: any, def: DailyQuestDef): boolean
    return DailyQuestLogic.progress(data, def) >= def.target
end

function DailyQuestLogic.isClaimed(data: any, id: string): boolean
    local dq = data.dailyQuests or {}
    return typeof(dq.claimed) == "table" and dq.claimed[id] == true
end

export type DailyQuestEntry = {
    id: string,
    name: string,
    desc: string,
    metric: DailyMetric,
    target: number,
    progress: number,
    claimable: boolean,
    claimed: boolean,
    reward: { coins: number?, gems: number? },
}

export type DailyQuestPayload = {
    quests: { DailyQuestEntry },
    secondsUntilReset: number,
}

function DailyQuestLogic.buildPayload(data: any): DailyQuestPayload
    local quests: { DailyQuestEntry } = {}
    for _, def in ipairs(DAILY_QUESTS) do
        local progress = DailyQuestLogic.progress(data, def)
        local claimed = DailyQuestLogic.isClaimed(data, def.id)
        table.insert(quests, {
            id = def.id,
            name = def.name,
            desc = def.desc,
            metric = def.metric,
            target = def.target,
            progress = progress,
            claimable = (not claimed) and progress >= def.target,
            claimed = claimed,
            reward = def.reward,
        })
    end
    return {
        quests = quests,
        secondsUntilReset = DailyQuestLogic.secondsUntilReset(),
    }
end

return DailyQuestLogic
