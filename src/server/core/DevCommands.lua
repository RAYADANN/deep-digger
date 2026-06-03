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
    -- Phase 8: опционально — TutorialManager. Если передан, /reset
    -- сбрасывает шаги туториала и снова выдаёт стартовый бонус,
    -- чтобы можно было пройти онбординг повторно.
    tutorialManager: any?,
    -- Phase 9: опционально — RebirthManager. Если передан, /rebirth [N]
    -- даёт N ребёртов без проверки цены (для тестирования R5/R10/R25
    -- порогов maxLevel pickaxe и масштабирования множителя).
    rebirthManager: any?,
    -- Phase 10: опционально — DailyReward + Leaderboard.
    --   /daily          — open модал немедленно (force notify available).
    --   /setday +N      — сдвиг lastClaimYday на N дней назад (test streak).
    --   /resetdaily     — полный сброс dailyState + activeBoosts.
    --   /boost <min>    — добавить x2 coins-boost на N минут.
    --   /leaderboard refresh — force refresh кэша.
    dailyReward: any?,
    leaderboard: any?,
    -- Phase 11: опционально — PetManager.
    --   /egg [N]   — бесплатно вылупить N петов (без списания монет).
    --   /hatch     — алиас /egg 1.
    --   /pet <id>  — выдать конкретного пета по petId (см. PetDatabase).
    --   /clearpets — удалить всех петов + снять экипировку.
    petManager: any?,
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
    self._tutorialManager = deps.tutorialManager
    self._rebirthManager = deps.rebirthManager
    self._dailyReward = deps.dailyReward
    self._leaderboard = deps.leaderboard
    self._petManager = deps.petManager

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
    -- Phase 8: чтобы можно было повторно протестировать онбординг через
    -- /reset, сбрасываем шаг туториала и снова выдаём стартовый бонус.
    -- Если TutorialManager не подключён — fallback на ручной сброс полей.
    if self._tutorialManager then
        self._tutorialManager:reset(player)
    else
        data.tutorialStep = 0
        data.firstSession = true
    end
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

function DevCommands:_handleRebirth(player: Player, args: { string })
    -- Phase 9: /rebirth [N] даёт N ребёртов через RebirthManager (без
    -- проверки цены). Если RebirthManager не передан в DI — это не баг
    -- DevCommands, а конфиг проекта; молча выходим, чтобы /rebirth не падал.
    if not self._rebirthManager then
        self:_notifyPlayer(player, "RebirthManager не подключён")
        return
    end
    local n: number
    if not args[1] or args[1] == "" then
        n = 1
    else
        local parsed = tonumber(args[1])
        if not parsed or parsed <= 0 then
            self:_notifyPlayer(player, "Использование: /rebirth [N]")
            return
        end
        n = math.floor(math.min(parsed, 1000))
    end
    self._rebirthManager:devRebirth(player, n)
    self:_notifyPlayer(player, ("+%d ребёртов"):format(n))
    self._log:info("DevRebirth:", player.UserId, "+" .. n)
end

--[[
    Phase 10 dev-команды.
]]
function DevCommands:_handleDaily(player: Player)
    if not self._dailyReward then
        self:_notifyPlayer(player, "DailyReward не подключён")
        return
    end
    self._dailyReward:devNotifyAvailable(player)
    self:_notifyPlayer(player, "Open daily modal (если canClaim)")
end

function DevCommands:_handleSetDay(player: Player, args: { string })
    if not self._dailyReward then
        self:_notifyPlayer(player, "DailyReward не подключён")
        return
    end
    local arg = args[1] or "1"
    -- Поддерживаем "+1", "1", "-1" (последнее — на завтра ушёл).
    if arg:sub(1, 1) == "+" then
        arg = arg:sub(2)
    end
    local n = tonumber(arg)
    if not n then
        self:_notifyPlayer(player, "Использование: /setday [+N]")
        return
    end
    -- /setday +N значит «считать что claim был N дней назад» — после команды
    -- canClaim снова true (если N >= 1).
    self._dailyReward:devShiftLastClaim(player, math.floor(n))
    self:_notifyPlayer(player, ("setday -%d дн."):format(math.floor(n)))
end

function DevCommands:_handleResetDaily(player: Player)
    if not self._dailyReward then
        self:_notifyPlayer(player, "DailyReward не подключён")
        return
    end
    self._dailyReward:reset(player)
    self:_notifyPlayer(player, "Daily reset")
end

function DevCommands:_handleBoost(player: Player, args: { string })
    if not self._dailyReward then
        self:_notifyPlayer(player, "DailyReward не подключён")
        return
    end
    local minutes = tonumber(args[1]) or 5
    if minutes <= 0 then
        self:_notifyPlayer(player, "Использование: /boost <минут>")
        return
    end
    local mult = tonumber(args[2]) or 2
    self._dailyReward:devAddBoost(player, minutes, mult)
    self:_notifyPlayer(player, ("+x%g boost · %d мин"):format(mult, minutes))
end

function DevCommands:_handleLeaderboardCmd(player: Player, args: { string })
    if not self._leaderboard then
        self:_notifyPlayer(player, "Leaderboard не подключён")
        return
    end
    local sub = args[1] or "refresh"
    if sub == "refresh" then
        -- Принудительно дёрнем оба board'a (приватный метод, но dev-only).
        pcall(function()
            self._leaderboard:_refresh("coins")
            self._leaderboard:_refresh("depth")
        end)
        self:_notifyPlayer(player, "Лидерборд обновляется...")
    else
        self:_notifyPlayer(player, "Использование: /leaderboard refresh")
    end
end

--[[
    Phase 11 dev-команды (питомцы).
]]
function DevCommands:_handleEgg(player: Player, args: { string })
    if not self._petManager then
        self:_notifyPlayer(player, "PetManager не подключён")
        return
    end
    local n = tonumber(args[1]) or 1
    n = math.max(1, math.floor(n))
    local hatched = self._petManager:devHatch(player, n)
    local count = if hatched then #hatched else 0
    self:_notifyPlayer(player, ("Вылупилось питомцев: %d"):format(count))
    self._log:info("DevEgg:", player.UserId, "+" .. count)
end

function DevCommands:_handlePet(player: Player, args: { string })
    if not self._petManager then
        self:_notifyPlayer(player, "PetManager не подключён")
        return
    end
    local petId = args[1]
    if not petId or petId == "" then
        self:_notifyPlayer(player, "Использование: /pet <id>")
        return
    end
    local rec = self._petManager:devGivePet(player, petId)
    if not rec then
        self:_notifyPlayer(player, "Неизвестный питомец: " .. petId)
        return
    end
    self:_notifyPlayer(player, "Выдан питомец: " .. (rec.name or petId))
end

function DevCommands:_handleClearPets(player: Player)
    if not self._petManager then
        self:_notifyPlayer(player, "PetManager не подключён")
        return
    end
    self._petManager:devClearPets(player)
    self:_notifyPlayer(player, "Питомцы очищены")
end

function DevCommands:_handleSkipTutorial(player: Player)
    -- Принудительно завершает туториал на сервере (tutorialStep = 3).
    -- Удобно для тестов, когда нужно проверить не-онбординг-фичу, но
    -- профиль свежий и автоматический туториал лезет.
    local data = self:_data(player)
    if not data then
        return
    end
    data.tutorialStep = 3
    data.firstSession = false
    self:_sync(player)
    self:_notifyPlayer(player, "Туториал пропущен")
end

function DevCommands:_handleHelp(player: Player)
    self:_notifyPlayer(player,
        "/coins [N], /reset, /maxlvl <id>, /skiptut, /rebirth [N], /daily, /setday +N, /resetdaily, /boost <мин>, /leaderboard refresh, /egg [N], /hatch, /pet <id>, /clearpets"
    )
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
        elseif cmd == "/skiptut" then
            self:_handleSkipTutorial(player)
        elseif cmd == "/rebirth" then
            self:_handleRebirth(player, args)
        elseif cmd == "/daily" then
            self:_handleDaily(player)
        elseif cmd == "/setday" then
            self:_handleSetDay(player, args)
        elseif cmd == "/resetdaily" then
            self:_handleResetDaily(player)
        elseif cmd == "/boost" then
            self:_handleBoost(player, args)
        elseif cmd == "/leaderboard" then
            self:_handleLeaderboardCmd(player, args)
        elseif cmd == "/egg" then
            self:_handleEgg(player, args)
        elseif cmd == "/hatch" then
            self:_handleEgg(player, { "1" })
        elseif cmd == "/pet" then
            self:_handlePet(player, args)
        elseif cmd == "/clearpets" then
            self:_handleClearPets(player)
        elseif cmd == "/devhelp" then
            self:_handleHelp(player)
        end
    end)
end

return DevCommands
