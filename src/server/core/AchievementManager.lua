--!strict
-- AchievementManager.lua — отслеживание достижений игрока.
-- 
-- Универсальный: можно перенести в любой проект.
-- Подписывается на события из MiningEngine, EconomyManager и т.д.
-- При выполнении условия — разблокирует ачивку и вызывает колбэк.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local Signal = require(shared.util.Signal)
local Logger = require(shared.util.Logger)

local AchievementManager = {}
AchievementManager.__index = AchievementManager

-- Типы
export type Achievement = {
    id: string,
    name: string,
    description: string,
    icon: string,
    reward: { coins?: number, gems?: number, aura?: string },
    check: (playerData: any) -> boolean,
}

function AchievementManager.new()
    local self = setmetatable({}, AchievementManager)
    self._log = Logger.new("Achievements")
    self.onAchievementUnlocked = Signal.new()  -- (player, achievementId) -> ()

    self._achievements = self:_buildList()
    self._unlocked = {}  -- [userId] = { [achievementId] = true }

    self._log:info("AchievementManager initialized")
    return self
end

function AchievementManager:_buildList(): { Achievement }
    return {
        {
            id = "first_ore",
            name = "First Dig",
            description = "Mine your first ore",
            icon = "",
            reward = { coins = 100 },
            check = function(data) return data.totalBlocksMined >= 1 end,
        },
        {
            id = "deep_100",
            name = "Getting Deeper",
            description = "Reach 100 meters depth",
            icon = "",
            reward = { coins = 500 },
            check = function(data) return data.depth >= 100 end,
        },
        {
            id = "deep_500",
            name = "Deep Diver",
            description = "Reach 500 meters depth",
            icon = "",
            reward = { coins = 2500, gems = 50 },
            check = function(data) return data.depth >= 500 end,
        },
        {
            id = "collector_10",
            name = "Collector",
            description = "Mine 10 unique ore types",
            icon = "",
            reward = { coins = 1000 },
            check = function(data) return false end,  -- будет реализовано позже
        },
        {
            id = "boss_slayer",
            name = "Boss Slayer",
            description = "Defeat your first boss",
            icon = "",
            reward = { coins = 5000, gems = 100 },
            check = function(data) return data.bossesDefeated >= 1 end,
        },
        {
            id = "millionaire",
            name = "Millionaire",
            description = "Earn 1,000,000 coins total",
            icon = "",
            reward = { aura = "rainbow" },
            check = function(data) return data.totalCoinsEarned >= 1000000 end,
        },
        {
            id = "shaft_finder",
            name = "Shaft Explorer",
            description = "Find 10 mine shafts",
            icon = "",
            reward = { gems = 200 },
            check = function(data) return false end,  -- будет реализовано позже
        },
    }
end

--[[
    Проверить все ачивки для игрока.
    Вызывается после любого значимого события.
]]
function AchievementManager:check(player: Player, playerData: any)
    local userId = player.UserId
    if not self._unlocked[userId] then
        self._unlocked[userId] = {}
    end
    local playerUnlocked = self._unlocked[userId]

    for _, achievement in ipairs(self._achievements) do
        if not playerUnlocked[achievement.id] then
            if achievement.check(playerData) then
                playerUnlocked[achievement.id] = true
                self.onAchievementUnlocked:fire(player, achievement.id)

                -- Награда
                local reward = achievement.reward
                if reward.coins then
                    playerData.coins = (playerData.coins or 0) + reward.coins
                end
                if reward.gems then
                    playerData.gems = (playerData.gems or 0) + reward.gems
                end

                self._log:info("Achievement unlocked:", achievement.name, "- Player:", userId)
            end
        end
    end
end

--[[
    Загрузить разблокированные ачивки из профиля игрока.
]]
function AchievementManager:loadUnlocked(player: Player, achievementIds: { string })
    local userId = player.UserId
    self._unlocked[userId] = {}
    for _, id in ipairs(achievementIds or {}) do
        self._unlocked[userId][id] = true
    end
end

return AchievementManager
