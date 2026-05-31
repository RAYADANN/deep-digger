--!strict
-- Dev-команды через чат. Активны только в Roblox Studio.
-- Можно вырезать целиком: модуль не зависит от игрового кода кроме DI.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Logger = require(game:GetService("ReplicatedStorage")
    :WaitForChild("shared").util.Logger)

export type Deps = {
    profileManager: any,
    onEconomyChanged: ((player: Player) -> ())?,
    notify: ((player: Player, payload: any) -> ())?,
}

local DevCommands = {}
DevCommands.__index = DevCommands

local function isStudio(): boolean
    return RunService:IsStudio()
end

local function parseAmount(arg: string?): number?
    if not arg or arg == "" then
        return 1000
    end
    local n = tonumber(arg)
    if not n or n <= 0 then
        return nil
    end
    return math.floor(math.min(n, 1e12))
end

function DevCommands.new(deps: Deps)
    local self = setmetatable({}, DevCommands)
    self._log = Logger.new("DevCommands")
    self._profileManager = deps.profileManager
    self._onEconomyChanged = deps.onEconomyChanged
    self._notify = deps.notify

    if not isStudio() then
        self._log:info("DevCommands disabled (not Studio)")
        return self
    end

    self._log:info("DevCommands enabled (Studio)")
    Players.PlayerAdded:Connect(function(player)
        self:_bind(player)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        self:_bind(player)
    end
    return self
end

function DevCommands:_notifyPlayer(player: Player, text: string)
    if not self._notify then
        return
    end
    self._notify(player, {
        text = text,
        icon = "🛠",
        color = { r = 120, g = 200, b = 255 },
        duration = 2,
    })
end

function DevCommands:_sync(player: Player)
    if self._onEconomyChanged then
        self._onEconomyChanged(player)
    end
end

function DevCommands:_data(player: Player)
    return self._profileManager:getData(player)
end

function DevCommands:_handleCoins(player: Player, args: { string })
    local amount = parseAmount(args[1])
    if not amount then
        self:_notifyPlayer(player, "Неверная сумма")
        return
    end
    local data = self:_data(player)
    if not data then
        return
    end
    data.coins = (data.coins or 0) + amount
    self:_sync(player)
    self:_notifyPlayer(player, ("+%d монет"):format(amount))
    self._log:info("DevCoins:", player.UserId, "+" .. amount)
end

function DevCommands:_handleReset(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    data.coins = 0
    data.inventory = {}
    data.totalBlocksMined = 0
    data.totalCoinsEarned = 0
    self:_sync(player)
    self:_notifyPlayer(player, "Сброс монет/инвентаря")
end

function DevCommands:_handleMaxUpgrade(player: Player, args: { string })
    local id = args[1]
    if not id then
        self:_notifyPlayer(player, "Использование: /maxlvl <id>")
        return
    end
    local data = self:_data(player)
    if not data then
        return
    end
    local Constants = require(game:GetService("ReplicatedStorage")
        :WaitForChild("shared").constants)
    local cfg = Constants.UPGRADES[id]
    if not cfg then
        self:_notifyPlayer(player, "Неизвестный апгрейд: " .. id)
        return
    end
    if id == "autoSell" then
        data.autoSellUnlocked = true
    else
        (data :: any)[id .. "Level"] = cfg.maxLevel
    end
    self:_sync(player)
    self:_notifyPlayer(player, "Макс. уровень: " .. id)
end

function DevCommands:_handleHelp(player: Player)
    self:_notifyPlayer(player, "/coins [N], /reset, /maxlvl <id>")
end

function DevCommands:_bind(player: Player)
    player.Chatted:Connect(function(msg)
        if msg:sub(1, 1) ~= "/" then
            return
        end
        local parts = string.split(msg, " ")
        local cmd = parts[1]:lower()
        local args = { table.unpack(parts, 2) }

        if cmd == "/coins" then
            self:_handleCoins(player, args)
        elseif cmd == "/reset" then
            self:_handleReset(player)
        elseif cmd == "/maxlvl" then
            self:_handleMaxUpgrade(player, args)
        elseif cmd == "/devhelp" then
            self:_handleHelp(player)
        end
    end)
end

return DevCommands
