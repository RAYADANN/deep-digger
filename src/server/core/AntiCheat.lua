--!strict
-- AntiCheat.lua — проверка лимитов кликов.
-- Можно перенести в любой проект с кликером.
--
-- Лимиты:
--   - макс 15 кликов/сек
--   - проверка существования блока (на сервере)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)

local AntiCheat = {}
AntiCheat.__index = AntiCheat

export type ClickRecord = {
    timestamps: { number },
    blockCount: number,
}

function AntiCheat.new()
    local self = setmetatable({}, AntiCheat)
    self._log = Logger.new("AntiCheat")
    self._clicks = {} :: { [number]: ClickRecord }  -- [userId] -> ClickRecord
    self._maxCps = Constants.MAX_CLICKS_PER_SECOND  -- 15
    self._log:info("AntiCheat initialized")
    return self
end

--[[
    Проверить и зарегистрировать клик игрока.
    Возвращает true если клик валидный, false если спам.
]]
function AntiCheat:checkClick(player: Player): boolean
    local userId = player.UserId
    local now = os.clock()

    if not self._clicks[userId] then
        self._clicks[userId] = {
            timestamps = {},
            blockCount = 0,
        }
    end

    local record = self._clicks[userId]

    -- Добавляем текущий клик
    table.insert(record.timestamps, now)

    -- Удаляем клики старше 1 секунды
    local cutoff = now - 1
    while #record.timestamps > 0 and record.timestamps[1] < cutoff do
        table.remove(record.timestamps, 1)
    end

    -- Проверяем лимит
    if #record.timestamps > self._maxCps then
        self._log:warn("AntiCheat triggered for", userId, "- clicks:", #record.timestamps)
        return false
    end

    return true
end

--[[
    Сбросить счётчик для игрока (при выходе).
]]
function AntiCheat:reset(player: Player)
    self._clicks[player.UserId] = nil
end

return AntiCheat
