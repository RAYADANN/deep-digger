--!strict
-- Leaderboard.lua — ЗАГЛУШКА
-- Глобальный лидерборд (MemoryStore)
-- MVP: не используется, заглушка чтобы не падало

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")

local Logger = require(shared.util.Logger)

local Leaderboard = {}
Leaderboard.__index = Leaderboard

function Leaderboard.new()
    local self = setmetatable({}, Leaderboard)
    self._log = Logger.new("Leaderboard")
    self._log:info("Leaderboard initialized (MVP stub)")
    return self
end

return Leaderboard
