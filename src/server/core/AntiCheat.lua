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
local OreTypes = require(shared.types.OreTypes)
local UpgradeLogic = require(shared.util.UpgradeLogic)

local AntiCheat = {}
AntiCheat.__index = AntiCheat

export type ClickRecord = {
    timestamps: { number },
    blockCount: number,
}

function AntiCheat.new()
    local self = setmetatable({}, AntiCheat)
    self._log = Logger.new("AntiCheat")
    self._clicks = {} :: { [number]: ClickRecord }
    self._lastSwing = {} :: { [number]: number }
    self._maxCps = Constants.MAX_CLICKS_PER_SECOND
    self._log:info("AntiCheat initialized")
    return self
end

--[[
    Проверить пачку кликов MineBlock (размер + CPS на каждый удар).
]]
function AntiCheat:validateMineBatch(player: Player, clickCount: number): boolean
    if type(clickCount) ~= "number" or clickCount < 1 then
        return false
    end
    if clickCount > Constants.MAX_MINE_BATCH_SIZE then
        self._log:warn("AntiCheat batch too large for", player.UserId, "- count:", clickCount)
        return false
    end
    for _ = 1, clickCount do
        if not self:checkClick(player) then
            return false
        end
    end
    return true
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
--[[
    Проверка кулдауна удара по уровню speed (апгрейд).
]]
function AntiCheat:validateSwing(player: Player, playerData: OreTypes.PlayerData): boolean
    local userId = player.UserId
    local now = os.clock()
    local minInterval = UpgradeLogic.swingDelaySeconds(playerData.speedLevel or 1)

    local last = self._lastSwing[userId]
    if last and (now - last) < minInterval * 0.9 then
        return false
    end

    self._lastSwing[userId] = now
    return true
end

function AntiCheat:reset(player: Player)
    local userId = player.UserId
    self._clicks[userId] = nil
    self._lastSwing[userId] = nil
end

return AntiCheat
