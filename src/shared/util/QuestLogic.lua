--!strict
-- QuestLogic.lua — цепочка квестов (единый источник формул).
--
-- Прогресс выводится из существующих счётчиков playerData — отдельный
-- per-event трекинг не нужен. Квесты идут последовательно: activeQuest =
-- первый, чей id ещё не в claimedQuests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local DiscoveryLogic = require(shared.util.DiscoveryLogic)

export type QuestMetric = "blocksMined" | "coinsEarned" | "depth" | "oresDiscovered" | "rebirths" | "shaftRooms"

export type QuestDef = {
    id: string,
    name: string,
    desc: string,
    metric: QuestMetric,
    target: number,
    reward: { coins: number?, gems: number? },
}

local QuestLogic = {}

local QUESTS: { QuestDef } = {
    {
        id = "q_mine_10",
        name = "Первые шаги",
        desc = "Добыть 10 блоков",
        metric = "blocksMined",
        target = 10,
        reward = { coins = 50 },
    },
    {
        id = "q_mine_100",
        name = "Привычка копать",
        desc = "Добыть 100 блоков",
        metric = "blocksMined",
        target = 100,
        reward = { coins = 200 },
    },
    {
        id = "q_depth_50",
        name = "Каменный слой",
        desc = "Достичь глубины 50 м",
        metric = "depth",
        target = 50,
        reward = { coins = 300 },
    },
    {
        id = "q_ores_5",
        name = "Коллекционер",
        desc = "Открыть 5 разных руд",
        metric = "oresDiscovered",
        target = 5,
        reward = { coins = 400, gems = 5 },
    },
    {
        id = "q_coins_10k",
        name = "Первый капитал",
        desc = "Заработать 10 000 монет всего",
        metric = "coinsEarned",
        target = 10000,
        reward = { coins = 500 },
    },
    {
        id = "q_mine_1000",
        name = "Опытный шахтёр",
        desc = "Добыть 1 000 блоков",
        metric = "blocksMined",
        target = 1000,
        reward = { coins = 1500, gems = 10 },
    },
    {
        id = "q_depth_150",
        name = "Известняк",
        desc = "Достичь глубины 150 м",
        metric = "depth",
        target = 150,
        reward = { coins = 2000 },
    },
    {
        id = "q_ores_15",
        name = "Охотник за рудами",
        desc = "Открыть 15 разных руд",
        metric = "oresDiscovered",
        target = 15,
        reward = { coins = 3000, gems = 25 },
    },
    {
        id = "q_depth_1200",
        name = "Бездна",
        desc = "Достичь глубины 1 200 м (Void Layer)",
        metric = "depth",
        target = 1200,
        reward = { coins = 10000, gems = 100 },
    },
    {
        id = "q_rebirth_1",
        name = "Новое начало",
        desc = "Совершить 1 ребёрт",
        metric = "rebirths",
        target = 1,
        reward = { coins = 5000, gems = 50 },
    },
}

function QuestLogic.getAll(): { QuestDef }
    return QUESTS
end

function QuestLogic.getById(questId: string): QuestDef?
    for _, q in ipairs(QUESTS) do
        if q.id == questId then
            return q
        end
    end
    return nil
end

function QuestLogic.isClaimed(data: any, questId: string): boolean
    if not data or typeof(data.claimedQuests) ~= "table" then
        return false
    end
    return data.claimedQuests[questId] == true
end

function QuestLogic.progressValue(data: any, metric: QuestMetric): number
    if not data then
        return 0
    end
    if metric == "blocksMined" then
        return data.totalBlocksMined or 0
    elseif metric == "coinsEarned" then
        return data.totalCoinsEarned or 0
    elseif metric == "depth" then
        return data.maxDepthReached or 0
    elseif metric == "oresDiscovered" then
        return DiscoveryLogic.totalProgress(data).found
    elseif metric == "rebirths" then
        return data.rebirths or 0
    elseif metric == "shaftRooms" then
        return data.shaftRoomCount or 0
    end
    return 0
end

function QuestLogic.isComplete(data: any, quest: QuestDef): boolean
    return QuestLogic.progressValue(data, quest.metric) >= quest.target
end

function QuestLogic.activeQuest(data: any): QuestDef?
    for _, quest in ipairs(QUESTS) do
        if not QuestLogic.isClaimed(data, quest.id) then
            return quest
        end
    end
    return nil
end

export type ActiveQuestPayload = {
    id: string,
    name: string,
    desc: string,
    metric: QuestMetric,
    target: number,
    progress: number,
    claimable: boolean,
    reward: { coins: number?, gems: number? },
}

function QuestLogic.buildActivePayload(data: any): ActiveQuestPayload?
    local quest = QuestLogic.activeQuest(data)
    if not quest then
        return nil
    end
    local progress = QuestLogic.progressValue(data, quest.metric)
    return {
        id = quest.id,
        name = quest.name,
        desc = quest.desc,
        metric = quest.metric,
        target = quest.target,
        progress = progress,
        claimable = progress >= quest.target,
        reward = quest.reward,
    }
end

function QuestLogic.claimedCount(data: any): number
    local n = 0
    if typeof(data.claimedQuests) == "table" then
        for _, v in pairs(data.claimedQuests) do
            if v == true then
                n += 1
            end
        end
    end
    return n
end

function QuestLogic.totalCount(): number
    return #QUESTS
end

return QuestLogic
