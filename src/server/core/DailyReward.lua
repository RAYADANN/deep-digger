--!strict
-- DailyReward.lua — Phase 10.
--
-- Серверная часть daily-reward retention-петли:
--   1) Net:Handle("ClaimDaily") — валидирует canClaim, вычисляет streak,
--      выдаёт награду из DailyRewardDatabase (coins / boost / coins+bonus),
--      шлёт notify "Награда забрана!" с kind="daily_reward" для клиентского FX.
--   2) onProfileLoaded — если canClaim → notify "Награда доступна!"
--      (kind="daily_available"). НЕ авто-claim'им: satisfaction даёт игроку
--      сам click [ЗАБРАТЬ].
--   3) Серверный task.spawn раз в rolloverCheckInterval (60с) детектит
--      «новый день наступил во время сессии» (игрок зашёл в 23:55, в 00:01
--      получает тост без перезахода).
--   4) DevHooks: devGrantDay / devSetLastClaim / reset для DevCommands.
--
-- Структура совпадает с RebirthManager.lua (Phase 9):
--   * DI через Deps,
--   * Net:Handle регистрируется в new(),
--   * onProfileLoaded идемпотентен.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local Net = require(modules.Net)
local DailyLogic = require(shared.util.DailyLogic)
local DailyRewardDatabase = require(shared.data.DailyRewardDatabase)
local PlayerBoosts = require(script.Parent.PlayerBoosts)

export type Deps = {
    profileManager: any,
    onProfileChanged: ((player: Player) -> ())?,
    notify: ((player: Player, payload: any) -> ())?,
}

local DailyReward = {}
DailyReward.__index = DailyReward

-- Цвет для тостов «daily». Тёплый золотой — это retention-фича, должна
-- быть «приятной», не как ошибка.
local GOLD = { r = 255, g = 210, b = 50 }

local function rarityColor(rarity: string): { r: number, g: number, b: number }
    local map = Constants.RARITY_COLORS or {}
    local c = map[rarity] or Color3.fromRGB(255, 210, 50)
    return { r = math.floor(c.R * 255), g = math.floor(c.G * 255), b = math.floor(c.B * 255) }
end

function DailyReward.new(deps: Deps)
    local self = setmetatable({}, DailyReward)
    self._log = Logger.new("DailyReward")
    self._profileManager = deps.profileManager
    self._onProfileChanged = deps.onProfileChanged
    self._notify = deps.notify
    -- Trackает, каким игрокам уже шлёт тост «новая награда доступна» в
    -- текущей сессии — чтобы не спамить каждые 60с в rollover-петле.
    self._availabilityNotified = {} :: { [number]: number? } -- [userId] = ydayWhenNotified

    Net:Handle("ClaimDaily", function(player: Player)
        return self:_handleClaim(player)
    end)

    -- Cleanup per-session throttle при выходе игрока (без этого map растёт
    -- по userId за всё uptime сервера).
    Players.PlayerRemoving:Connect(function(player: Player)
        self._availabilityNotified[player.UserId] = nil
    end)

    self:_startRolloverWatcher()
    self._log:info("DailyReward initialized")
    return self
end

function DailyReward:_data(player: Player)
    return self._profileManager:getData(player)
end

function DailyReward:_sync(player: Player)
    if self._onProfileChanged then
        self._onProfileChanged(player)
    end
end

local function ensureDailyState(data: any)
    if not data.dailyState or typeof(data.dailyState) ~= "table" then
        data.dailyState = {
            lastClaimYday = 0,
            lastClaimYear = 0,
            currentStreak = 0,
            totalDaysClaimed = 0,
        }
    end
    return data.dailyState
end

local function ensureActiveBoosts(data: any)
    if not data.activeBoosts or typeof(data.activeBoosts) ~= "table" then
        data.activeBoosts = {}
    end
    return data.activeBoosts
end

--[[
    Выдать награду: мутирует playerData. Возвращает payload для UI
    (что именно выдали, чтобы клиент знал что анимировать).
]]
function DailyReward:_grantReward(player: Player, data: any, reward: DailyRewardDatabase.DailyReward): any
    local granted = {
        type = reward.type,
        amount = reward.amount,
        duration = reward.duration,
        rarity = reward.rarity,
        label = reward.label,
        coinsAwarded = 0,
        boostsAdded = {},
    }

    local activeBoosts = ensureActiveBoosts(data)

    if reward.type == "coins" then
        local amt = math.max(0, math.floor(reward.amount or 0))
        data.coins = (data.coins or 0) + amt
        data.totalCoinsEarned = (data.totalCoinsEarned or 0) + amt
        granted.coinsAwarded = amt
    elseif reward.type == "boost" then
        local boost = PlayerBoosts.addBoost(activeBoosts, {
            kind = "coins",
            multiplier = reward.amount or 2,
            durationSec = reward.duration or 600,
            source = "daily_day_" .. tostring(data.dailyState.currentStreak or 0),
        })
        table.insert(granted.boostsAdded, PlayerBoosts.toPayload(boost))
    end

    -- Day 7 эпик-награда: coins + bonusBoost.
    if reward.bonusBoost then
        local boost = PlayerBoosts.addBoost(activeBoosts, {
            kind = "coins",
            multiplier = reward.bonusBoost.multiplier or 2,
            durationSec = reward.bonusBoost.duration or 1800,
            source = "daily_day_7_bonus",
        })
        table.insert(granted.boostsAdded, PlayerBoosts.toPayload(boost))
    end

    return granted
end

function DailyReward:_notifyClaim(player: Player, reward: DailyRewardDatabase.DailyReward, cycleDay: number)
    if not self._notify then
        return
    end
    self._notify(player, {
        text = ("🎁 День %d: %s"):format(cycleDay, reward.label or "Награда забрана"),
        icon = DailyRewardDatabase.iconFor(reward),
        color = rarityColor(reward.rarity or "common"),
        duration = 4,
        -- Клиентский init.client.lua перехватывает kind="daily_reward" и
        -- запускает RewardFX.burst(rarity).
        kind = "daily_reward",
        rarity = reward.rarity,
    })
end

function DailyReward:_notifyAvailable(player: Player, force: boolean?)
    if not self._notify then
        return
    end
    local data = self:_data(player)
    if not data then
        return
    end
    if not DailyLogic.canClaim(data.dailyState) then
        return
    end
    -- Throttle: один раз за день. Без проверки rollover-watcher шлёт тост
    -- каждые 60с.
    local curr = DailyLogic.currentDay()
    if not force then
        local notifiedYday = self._availabilityNotified[player.UserId]
        if notifiedYday == curr.yday then
            return
        end
    end
    self._availabilityNotified[player.UserId] = curr.yday

    self._notify(player, {
        text = "🎁 Награда за день доступна!",
        icon = "🎁",
        color = GOLD,
        duration = 4.5,
        kind = "daily_available",
    })
end

function DailyReward:_handleClaim(player: Player)
    local data = self:_data(player)
    if not data then
        return { success = false, error = "no_profile", message = "Профиль не загружен" }
    end
    local dailyState = ensureDailyState(data)
    if not DailyLogic.canClaim(dailyState) then
        local until_ = DailyLogic.timeUntilNextDay()
        return {
            success = false,
            error = "already_claimed",
            message = ("Уже забрано. Через %dч %02dм"):format(until_.hours, until_.minutes),
            nextClaimSeconds = until_.total,
        }
    end

    -- Шаг 1: вычислить новый streak ДО мутации.
    local newStreak = DailyLogic.nextStreak(dailyState)
    local cycleDay = DailyLogic.streakToCycleDay(newStreak)
    local reward = DailyRewardDatabase.get(cycleDay)
    if not reward then
        self._log:warn("No reward defined for cycleDay", cycleDay, "— treating as no-op")
        return { success = false, error = "no_reward_defined", message = "Награда не задана" }
    end

    -- Шаг 2: записать новый dailyState.
    dailyState.currentStreak = newStreak
    local curr = DailyLogic.currentDay()
    dailyState.lastClaimYday = curr.yday
    dailyState.lastClaimYear = curr.year
    dailyState.totalDaysClaimed = (dailyState.totalDaysClaimed or 0) + 1

    -- Шаг 3: выдать награду (мутирует coins / activeBoosts).
    local granted = self:_grantReward(player, data, reward)

    -- Шаг 4: notify + sync.
    self:_notifyClaim(player, reward, cycleDay)
    -- Сразу же помечаем как «уведомлено сегодня» — иначе rollover-watcher
    -- через 60с может прислать «новая награда!» (если игрок успел перепрыгнуть
    -- через ровную полночь UTC между _handleClaim и watcher tick'ом).
    self._availabilityNotified[player.UserId] = curr.yday

    self:_sync(player)

    self._log:info(
        "Daily claimed by", player.UserId,
        "- cycleDay:", cycleDay,
        "- streak:", newStreak,
        "- type:", reward.type
    )

    return {
        success = true,
        cycleDay = cycleDay,
        streak = newStreak,
        totalDaysClaimed = dailyState.totalDaysClaimed,
        granted = granted,
    }
end

--[[
    Вызывается из init.server.lua после ProfileManager:loadProfile.
    Если можно claim — шлём notify «доступна». Авто-claim'ить НЕ нужно:
    игроку нужно увидеть satisfaction от модала.

    Также чистит истёкшие boost'ы (cleanup).
]]
function DailyReward:onProfileLoaded(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    ensureDailyState(data)
    local activeBoosts = ensureActiveBoosts(data)
    PlayerBoosts.cleanup(activeBoosts)
    -- Сброс per-session throttle. Это гарантирует что после rejoin'a тост
    -- «награда доступна» прилетит снова.
    self._availabilityNotified[player.UserId] = nil
    if DailyLogic.canClaim(data.dailyState) then
        self:_notifyAvailable(player, true)
    end
end

--[[
    Серверный watcher: раз в Constants.DAILY.rolloverCheckInterval (60с)
    проходит по всем активным профилям и шлёт notify тем, у кого только
    что наступил новый день.

    Игрок зашёл в 23:55 UTC → в 00:01 получает тост, не перезаходит.
]]
function DailyReward:_startRolloverWatcher()
    local interval = (Constants.DAILY or {}).rolloverCheckInterval or 60
    task.spawn(function()
        while true do
            task.wait(interval)
            for _, player in ipairs(Players:GetPlayers()) do
                local data = self._profileManager:getData(player)
                if data then
                    -- Также чистим истёкшие boost'ы каждые 60с —
                    -- BoostChip на клиенте получит свежий список без
                    -- ручного refresh'a (sync дёргается при cleanup).
                    local activeBoosts = ensureActiveBoosts(data)
                    local cleaned = PlayerBoosts.cleanup(activeBoosts)
                    if cleaned then
                        self:_sync(player)
                    end
                    if DailyLogic.canClaim(data.dailyState) then
                        self:_notifyAvailable(player)
                    end
                end
            end
        end
    end)
end

--[[
    DevHook: имитировать claim прошлого дня (для тестирования стрика).
    /setday +N → сдвигает lastClaimYday на N дней назад.
]]
function DailyReward:devShiftLastClaim(player: Player, daysAgo: number)
    local data = self:_data(player)
    if not data then
        return
    end
    local state = ensureDailyState(data)
    -- Сдвигаем yday назад на daysAgo. Если уходим за начало года —
    -- decrement year и подгоняем yday.
    local curr = DailyLogic.currentDay()
    local newYday = curr.yday - daysAgo
    local newYear = curr.year
    while newYday < 1 do
        newYear -= 1
        -- Округлим длину прошлого года до 365 (для simplicity dev-команды).
        newYday = newYday + 365
    end
    state.lastClaimYday = newYday
    state.lastClaimYear = newYear
    -- Сбрасываем throttle и шлём свежий «доступна» тост, если canClaim.
    self._availabilityNotified[player.UserId] = nil
    self:_sync(player)
    if DailyLogic.canClaim(state) then
        self:_notifyAvailable(player, true)
    end
end

--[[
    DevHook: открыть модал сейчас (force notify).
]]
function DailyReward:devNotifyAvailable(player: Player)
    self:_notifyAvailable(player, true)
end

--[[
    DevHook: полный reset. Используется /resetdaily.
]]
function DailyReward:reset(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    data.dailyState = {
        lastClaimYday = 0,
        lastClaimYear = 0,
        currentStreak = 0,
        totalDaysClaimed = 0,
    }
    data.activeBoosts = {}
    self._availabilityNotified[player.UserId] = nil
    self:_sync(player)
    self:_notifyAvailable(player, true)
end

--[[
    DevHook: добавить boost вручную через /boost <minutes>.
]]
function DailyReward:devAddBoost(player: Player, minutes: number, multiplier: number?)
    local data = self:_data(player)
    if not data then
        return
    end
    local activeBoosts = ensureActiveBoosts(data)
    PlayerBoosts.addBoost(activeBoosts, {
        kind = "coins",
        multiplier = multiplier or 2,
        durationSec = math.max(1, math.floor(minutes * 60)),
        source = "devcmd",
    })
    self:_sync(player)
end

return DailyReward
