--!strict
-- QuestManager.lua — серверная часть цепочки квестов.
--
-- DI через Deps (как DiscoveryManager). Прогресс выводится из счётчиков
-- профиля; награда выдаётся по клику «Забрать» (ClaimQuest).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")

local Logger = require(shared.util.Logger)
local QuestLogic = require(shared.util.QuestLogic)

export type Deps = {
    profileManager: any,
    onProfileChanged: ((player: Player) -> ())?,
    notify: ((player: Player, payload: any) -> ())?,
    notifyOnce: ((player: Player, key: string, payload: any) -> ())?,
}

local QuestManager = {}
QuestManager.__index = QuestManager

local GOLD = { r = 255, g = 210, b = 50 }

local function ensureFields(data: any)
    if typeof(data.claimedQuests) ~= "table" then
        data.claimedQuests = {}
    end
end

function QuestManager.new(deps: Deps)
    local self = setmetatable({}, QuestManager)
    self._log = Logger.new("QuestManager")
    self._profileManager = deps.profileManager
    self._onProfileChanged = deps.onProfileChanged
    self._notify = deps.notify
    self._notifyOnce = deps.notifyOnce
    -- userId -> questId, для которого уже показали «готово к получению»
    self._readyNotified = {}
    return self
end

function QuestManager:_data(player: Player)
    return self._profileManager:getData(player)
end

function QuestManager:_sync(player: Player)
    if self._onProfileChanged then
        self._onProfileChanged(player)
    end
end

function QuestManager:onProfileLoaded(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    ensureFields(data)
    self._readyNotified[player.UserId] = nil
end

function QuestManager:onPlayerLeaving(player: Player)
    self._readyNotified[player.UserId] = nil
end

--[[
    Проверить активный квест. Если выполнен — тост «забери награду» (один раз
    на квест, пока не claim). Возвращает true если состояние изменилось.
]]
function QuestManager:evaluate(player: Player): boolean
    local data = self:_data(player)
    if not data then
        return false
    end
    ensureFields(data)
    local active = QuestLogic.activeQuest(data)
    if not active then
        return false
    end
    if not QuestLogic.isComplete(data, active) then
        return false
    end
    local uid = player.UserId
    if self._readyNotified[uid] == active.id then
        return false
    end
    self._readyNotified[uid] = active.id
    if self._notifyOnce then
        self._notifyOnce(player, "quest_ready_" .. active.id, {
            text = ("🎯 Цель выполнена: %s — забери награду!"):format(active.name),
            icon = "🎯",
            color = GOLD,
            duration = 4,
            kind = "quest_ready",
            questId = active.id,
        })
    elseif self._notify then
        self._notify(player, {
            text = ("🎯 Цель выполнена: %s — забери награду!"):format(active.name),
            icon = "🎯",
            color = GOLD,
            duration = 4,
            kind = "quest_ready",
            questId = active.id,
        })
    end
    return true
end

export type ClaimResult = {
    success: boolean,
    error: string?,
    questId: string?,
    coinsAwarded: number?,
    gemsAwarded: number?,
}

function QuestManager:claim(player: Player, questId: string): ClaimResult
    local data = self:_data(player)
    if not data then
        return { success = false, error = "No profile" }
    end
    ensureFields(data)

    local active = QuestLogic.activeQuest(data)
    if not active or active.id ~= questId then
        return { success = false, error = "Not active quest" }
    end
    if not QuestLogic.isComplete(data, active) then
        return { success = false, error = "Not complete" }
    end
    if QuestLogic.isClaimed(data, questId) then
        return { success = false, error = "Already claimed" }
    end

    local reward = active.reward
    local coinsAwarded = 0
    local gemsAwarded = 0
    if reward.coins and reward.coins > 0 then
        coinsAwarded = reward.coins
        data.coins = (data.coins or 0) + coinsAwarded
        data.totalCoinsEarned = (data.totalCoinsEarned or 0) + coinsAwarded
    end
    if reward.gems and reward.gems > 0 then
        gemsAwarded = reward.gems
        data.gems = (data.gems or 0) + gemsAwarded
    end

    data.claimedQuests[questId] = true
    self._readyNotified[player.UserId] = nil

    if self._notify then
        local parts = {}
        if coinsAwarded > 0 then
            table.insert(parts, ("+%d 💰"):format(coinsAwarded))
        end
        if gemsAwarded > 0 then
            table.insert(parts, ("+%d 💎"):format(gemsAwarded))
        end
        self._notify(player, {
            text = ("🎯 Квест «%s» — награда %s"):format(active.name, table.concat(parts, " ")),
            icon = "🎯",
            color = GOLD,
            duration = 4,
            kind = "quest_claimed",
            questId = questId,
        })
    end

    self._log:info("Quest claimed:", player.UserId, questId, coinsAwarded, gemsAwarded)
    self:_sync(player)
    return {
        success = true,
        questId = questId,
        coinsAwarded = coinsAwarded,
        gemsAwarded = gemsAwarded,
    }
end

function QuestManager:devResetQuests(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    data.claimedQuests = {}
    self._readyNotified[player.UserId] = nil
    self:_sync(player)
end

function QuestManager:devCompleteActive(player: Player): boolean
    local data = self:_data(player)
    if not data then
        return false
    end
    local active = QuestLogic.activeQuest(data)
    if not active then
        return false
    end
    -- Подгоняем счётчик под target (dev-only).
    if active.metric == "blocksMined" then
        data.totalBlocksMined = math.max(data.totalBlocksMined or 0, active.target)
    elseif active.metric == "coinsEarned" then
        data.totalCoinsEarned = math.max(data.totalCoinsEarned or 0, active.target)
    elseif active.metric == "depth" then
        data.maxDepthReached = math.max(data.maxDepthReached or 0, active.target)
    elseif active.metric == "rebirths" then
        data.rebirths = math.max(data.rebirths or 0, active.target)
        data.rebirthMultiplier = 1 + (data.rebirths or 0) * 0.1
    end
    self:_sync(player)
    return true
end

return QuestManager
