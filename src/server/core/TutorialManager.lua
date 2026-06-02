--!strict
-- TutorialManager.lua — Phase 8.
--
-- Серверная часть онбординга:
--   1) Миграция «опытных» профилей (totalBlocksMined > 0 или
--      totalCoinsEarned > 0) — выставляем tutorialStep = 3,
--      чтобы старые игроки не получили туториал на ровном месте.
--   2) First-time bonus: при `profileData.firstSession == true` начисляем
--      `Constants.STARTER_COINS` (только если у игрока меньше) и
--      разово показываем тост. firstSession сразу выставляется в false,
--      даже если бонус не понадобился (защита от двойного начисления).
--   3) Net:Handle("UpdateTutorialStep") — клиент шлёт текущий шаг по мере
--      прогресса. Сервер валидирует:
--        - тип number,
--        - диапазон 0..3,
--        - монотонный рост (нельзя «откатить» туториал).
--      Клиент — недоверенный источник.
--
-- Не отвечает за рассылку HUD-пейлоадов — сразу зовёт `onProfileChanged`
-- (DI из init.server.lua), который сам решает, как ресинкать клиент.
-- Это позволяет переиспользовать модуль в любом проекте.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local Net = require(modules.Net)
local OreTypes = require(shared.types.OreTypes)

local TUTORIAL_MIN = Constants.TUTORIAL_STEPS.NOT_STARTED
local TUTORIAL_MAX = Constants.TUTORIAL_STEPS.COMPLETED

export type Deps = {
    profileManager: any,
    onProfileChanged: ((player: Player) -> ())?,
    notify: ((player: Player, payload: any) -> ())?,
}

local TutorialManager = {}
TutorialManager.__index = TutorialManager

local function isExperienced(data: OreTypes.PlayerData): boolean
    if (data.totalBlocksMined or 0) > 0 then
        return true
    end
    if (data.totalCoinsEarned or 0) > 0 then
        return true
    end
    -- Любой апгрейд выше базового тоже выдаёт «не новичка» — на случай если
    -- сейв был ручной (devcommand /maxlvl) до того как поле totalBlocksMined
    -- начали трекать.
    if (data.pickaxeLevel or 1) > 1 or (data.autoSellUnlocked == true) then
        return true
    end
    return false
end

function TutorialManager.new(deps: Deps)
    local self = setmetatable({}, TutorialManager)
    self._log = Logger.new("TutorialManager")
    self._profileManager = deps.profileManager
    self._onProfileChanged = deps.onProfileChanged
    self._notify = deps.notify

    Net:Handle("UpdateTutorialStep", function(player: Player, step: any)
        return self:_handleStep(player, step)
    end)

    self._log:info("TutorialManager initialized")
    return self
end

function TutorialManager:_data(player: Player): OreTypes.PlayerData?
    return self._profileManager:getData(player)
end

function TutorialManager:_sync(player: Player)
    if self._onProfileChanged then
        self._onProfileChanged(player)
    end
end

--[[
    Выдаёт стартовый бонус, если `firstSession == true`, и сбрасывает флаг.
    НЕ запускает миграцию (это уже только для первой загрузки).
    Используется и из `onProfileLoaded`, и из `:reset` — для DevCommands.
]]
function TutorialManager:applyFirstTimeBonus(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    if not data.firstSession then
        return
    end
    -- Сначала firstSession = false (защита от повторного начисления, если
    -- что-то упадёт между шагами), потом уже меняем монеты и шлём notify.
    data.firstSession = false
    local need = Constants.STARTER_COINS or 0
    if need > 0 and (data.coins or 0) < need then
        data.coins = need
    end
    if self._notify then
        self._notify(player, {
            text = "+" .. tostring(need) .. " монет на старт! Купи свою первую кирку 🪨",
            icon = "💰",
            color = { r = 255, g = 210, b = 50 },
            duration = 4.5,
        })
    end
    self:_sync(player)
    self._log:info("First-time bonus applied for", player.UserId, "starter coins:", need)
end

--[[
    Вызывается из init.server.lua после ProfileManager:loadProfile.
    Делает миграцию «опытных» профилей (tutorialStep = 3, никакого туториала)
    и одноразовый стартовый бонус. ВАЖНО: миграция здесь — путь
    «первая загрузка профиля», а НЕ путь «DevCommand /reset». Это разные
    интенты:
      * первая загрузка → опытный игрок не хочет видеть туториал заново;
      * /reset в Studio → разработчик ХОЧЕТ видеть туториал, даже если на
        профиле висит pickaxeLevel=20 от прошлых тестов.
    Поэтому миграция ТОЛЬКО тут, а в :reset() её нет.
]]
function TutorialManager:onProfileLoaded(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end

    if (data.tutorialStep or 0) < TUTORIAL_MAX and isExperienced(data) then
        self._log:info("Migrating experienced profile to tutorialStep=3 for", player.UserId)
        data.tutorialStep = TUTORIAL_MAX
        data.firstSession = false
    end

    self:applyFirstTimeBonus(player)
end

function TutorialManager:_handleStep(player: Player, step: any)
    if typeof(step) ~= "number" then
        return { success = false, error = "invalid_request" }
    end
    step = math.floor(step)
    if step < TUTORIAL_MIN or step > TUTORIAL_MAX then
        return { success = false, error = "out_of_range" }
    end

    local data = self:_data(player)
    if not data then
        return { success = false, error = "no_profile" }
    end

    local current = data.tutorialStep or 0
    -- Монотонный рост: клиенту нельзя «откатить» прогресс. Повтор того же
    -- шага возвращаем как success (идемпотентность), но в HUD не ресинкаем.
    if step <= current then
        return { success = true, step = current }
    end

    data.tutorialStep = step
    self._log:debug("Tutorial step:", player.UserId, current, "->", step)
    self:_sync(player)
    return { success = true, step = step }
end

--[[
    DI-хук для DevCommands /reset.
    Принудительно сбрасывает шаги (firstSession = true, tutorialStep = 0),
    выдаёт стартовый бонус и ресинкает HUD. Миграцию isExperienced СПЕЦИАЛЬНО
    не вызываем — `/reset` это запрос «хочу пройти туториал ещё раз», даже
    если профиль уже опытный (pickaxeLevel > 1 от прошлых /maxlvl и т.п.).
    Миграция работает только на первой загрузке профиля (`onProfileLoaded`).
]]
function TutorialManager:reset(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    data.tutorialStep = 0
    data.firstSession = true
    self:applyFirstTimeBonus(player)
end

return TutorialManager
