--!strict
-- AchievementManager.lua — отслеживание достижений игрока.
--
-- Разблокировки персистятся в playerData.unlockedAchievements.
-- Подписывается на события через check() после значимых действий.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")
local Signal = require(shared.util.Signal)
local Logger = require(shared.util.Logger)
local DiscoveryLogic = require(shared.util.DiscoveryLogic)
local Net = require(modules.Net)

local AchievementManager = {}
AchievementManager.__index = AchievementManager

export type Achievement = {
    id: string,
    name: string,
    description: string,
    icon: string,
    reward: { coins: number?, gems: number?, aura: string? },
    check: (playerData: any) -> boolean,
    hidden: boolean?, -- future content — не показывать в UI
}

export type Deps = {
    profileManager: any,
    onProfileChanged: ((player: Player) -> ())?,
    notify: ((player: Player, payload: any) -> ())?,
}

function AchievementManager.new(deps: Deps?)
    local self = setmetatable({}, AchievementManager)
    self._log = Logger.new("Achievements")
    self.onAchievementUnlocked = Signal.new()
    self._profileManager = deps and deps.profileManager
    self._onProfileChanged = deps and deps.onProfileChanged
    self._notify = deps and deps.notify
    self._achievements = self:_buildList()

    Net:Handle("EquipTitle", function(player: Player, titleId: string?)
        return self:_handleEquipTitle(player, titleId)
    end)

    self._log:info("AchievementManager initialized")
    return self
end

function AchievementManager:_buildList(): { Achievement }
    return {
        {
            id = "first_ore",
            name = "First Dig",
            description = "Mine your first ore",
            icon = "upg_pickaxe",
            reward = { coins = 100 },
            check = function(data) return (data.totalBlocksMined or 0) >= 1 end,
        },
        {
            id = "deep_100",
            name = "Getting Deeper",
            description = "Reach 100 meters depth",
            icon = "depth",
            reward = { coins = 500 },
            check = function(data) return (data.maxDepthReached or 0) >= 100 end,
        },
        {
            id = "deep_500",
            name = "Deep Diver",
            description = "Reach 500 meters depth",
            icon = "depth",
            reward = { coins = 2500, gems = 50 },
            check = function(data) return (data.maxDepthReached or 0) >= 500 end,
        },
        {
            id = "collector_10",
            name = "Collector",
            description = "Discover 10 unique ore types",
            icon = "tab_inventory",
            reward = { coins = 1000 },
            check = function(data)
                return DiscoveryLogic.totalProgress(data).found >= 10
            end,
        },
        {
            id = "boss_slayer",
            name = "Boss Slayer",
            description = "Defeat your first boss",
            icon = "icon_boss",
            reward = { coins = 5000, gems = 100 },
            check = function(data) return (data.bossesDefeated or 0) >= 1 end,
            hidden = true,
        },
        {
            id = "millionaire",
            name = "Millionaire",
            description = "Earn 1,000,000 coins total",
            icon = "coin",
            reward = { aura = "rainbow" },
            check = function(data) return (data.totalCoinsEarned or 0) >= 1000000 end,
        },
        {
            id = "shaft_finder",
            name = "Shaft Explorer",
            description = "Find 10 hidden rooms",
            icon = "icon_sparkle",
            reward = { gems = 200 },
            check = function(data) return (data.shaftRoomCount or 0) >= 10 end,
        },
    }
end

function AchievementManager:getAll(): { Achievement }
    return self._achievements
end

function AchievementManager:getVisible(): { Achievement }
    local out = {}
    for _, a in ipairs(self._achievements) do
        if not a.hidden then
            table.insert(out, a)
        end
    end
    return out
end

function AchievementManager:getById(id: string): Achievement?
    for _, a in ipairs(self._achievements) do
        if a.id == id then
            return a
        end
    end
    return nil
end

local function ensureFields(data: any)
    if typeof(data.unlockedAchievements) ~= "table" then
        data.unlockedAchievements = {}
    end
    if data.equippedTitleId ~= nil and typeof(data.equippedTitleId) ~= "string" then
        data.equippedTitleId = nil
    end
end

function AchievementManager:isUnlocked(data: any, achievementId: string): boolean
    if not data or typeof(data.unlockedAchievements) ~= "table" then
        return false
    end
    return data.unlockedAchievements[achievementId] == true
end

function AchievementManager:loadUnlocked(player: Player)
    local data = if self._profileManager then self._profileManager:getData(player) else nil
    if data then
        ensureFields(data)
        self:_sanitizeEquippedTitle(data)
    end
end

function AchievementManager:_sanitizeEquippedTitle(data: any)
    local eq = data.equippedTitleId
    if typeof(eq) ~= "string" or eq == "" then
        data.equippedTitleId = nil
        return
    end
    if not self:isUnlocked(data, eq) or not self:getById(eq) then
        data.equippedTitleId = nil
    end
end

function AchievementManager:_handleEquipTitle(player: Player, titleId: string?)
    local data = if self._profileManager then self._profileManager:getData(player) else nil
    if not data then
        return { success = false, error = "no_profile" }
    end
    ensureFields(data)

    if titleId == nil or titleId == "" then
        data.equippedTitleId = nil
        if self._onProfileChanged then
            self._onProfileChanged(player)
        end
        return { success = true, equippedTitleId = nil }
    end
    if typeof(titleId) ~= "string" then
        return { success = false, error = "bad_title", message = "Неверный титул" }
    end
    if not self:isUnlocked(data, titleId) then
        return { success = false, error = "locked", message = "Достижение ещё не открыто" }
    end
    if not self:getById(titleId) then
        return { success = false, error = "unknown", message = "Титул не найден" }
    end

    data.equippedTitleId = titleId
    if self._onProfileChanged then
        self._onProfileChanged(player)
    end
    return { success = true, equippedTitleId = titleId }
end

function AchievementManager:check(player: Player, playerData: any): boolean
    ensureFields(playerData)
    local changed = false

    for _, achievement in ipairs(self._achievements) do
        if not self:isUnlocked(playerData, achievement.id) then
            if achievement.check(playerData) then
                playerData.unlockedAchievements[achievement.id] = true
                changed = true
                self.onAchievementUnlocked:fire(player, achievement.id)

                local reward = achievement.reward
                if reward.coins and reward.coins > 0 then
                    playerData.coins = (playerData.coins or 0) + reward.coins
                    playerData.totalCoinsEarned = (playerData.totalCoinsEarned or 0) + reward.coins
                end
                if reward.gems and reward.gems > 0 then
                    playerData.gems = (playerData.gems or 0) + reward.gems
                end

                if self._notify then
                    self._notify(player, {
                        text = ("Достижение: %s!"):format(achievement.name),
                        icon = achievement.icon,
                        color = { r = 255, g = 210, b = 50 },
                        duration = 4,
                        kind = "achievement_unlocked",
                        achievementId = achievement.id,
                    })
                end

                self._log:info("Achievement unlocked:", achievement.name, "- Player:", player.UserId)
            end
        end
    end

    return changed
end

export type AchievementPayload = {
    id: string,
    name: string,
    description: string,
    icon: string,
    unlocked: boolean,
    reward: { coins: number?, gems: number?, aura: string? },
}

function AchievementManager:buildPayload(playerData: any): { AchievementPayload }
    ensureFields(playerData)
    local out: { AchievementPayload } = {}
    for _, a in ipairs(self:getVisible()) do
        table.insert(out, {
            id = a.id,
            name = a.name,
            description = a.description,
            icon = a.icon,
            unlocked = self:isUnlocked(playerData, a.id),
            reward = a.reward,
        })
    end
    return out
end

return AchievementManager
