--!strict
-- RebirthManager.lua — Phase 9.
--
-- Серверная часть prestige-петли:
--   1) Net:Handle("Rebirth") — валидирует условия (coins >= cost), сбрасывает
--      прогресс игрока, инкрементирует rebirths, пересчитывает кэш
--      rebirthMultiplier, шлёт тост + клиент-FX через notify.
--   2) onProfileLoaded(player) — пересчитывает rebirthMultiplier из
--      rebirths на случай ручной правки сейва. Идемпотентно — безопасно
--      звать на каждом заходе.
--   3) devRebirth(player, n) — DI для DevCommands /rebirth [N]: даёт
--      N ребёртов без проверки цены (для тестирования R5/R10/R25 порогов).
--
-- Что СБРАСЫВАЕТСЯ при ребёрте (`coins=0, inventory={}, *Level=1, autoSell=
-- false, depth/layer/_stoneLayerNotified`):
--   * coins, inventory, *Level, autoSellUnlocked — это и есть «прогрессия,
--     которой жертвуем ради множителя».
--   * depth/layer/_stoneLayerNotified — игрок начинает с поверхности; флаг
--     «Stone-уведомление видел» обнуляется, чтобы при повторном спуске на
--     50м снова прилетел тост.
--
-- Что СОХРАНЯЕТСЯ (НЕ трогаем):
--   * rebirths/rebirthMultiplier — сам прогресс prestige.
--   * totalCoinsEarned, totalBlocksMined, maxDepthReached, bossesDefeated,
--     shaftsFound, playTime, lastSave — статистика. Это «история», она не
--     должна ресетиться.
--   * tutorialStep / firstSession — опытный игрок не должен снова видеть
--     туториал и получать STARTER_COINS. Это ВАЖНО: tutorialStep остаётся
--     3, иначе после ребёрта на пустой инвентарь Tutorial.start снова
--     включится с «Кликни блок!».
--
-- Не отвечает за ресет визуала Mine — сервер шлёт snapshot через
-- onResetBlocks (DI), чтобы клиент перезалил блоки с нуля. Если DI не
-- передан — клиент просто увидит тот же ландшафт, что и до ребёрта (это
-- допустимо для MVP, шахта общая по визуалу).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local Net = require(modules.Net)
local OreTypes = require(shared.types.OreTypes)
local RebirthLogic = require(shared.util.RebirthLogic)

export type Deps = {
    profileManager: any,
    onProfileChanged: ((player: Player) -> ())?,
    notify: ((player: Player, payload: any) -> ())?,
    -- Опционально: ресет визуального состояния шахты после ребёрта
    -- (вызов sendBlocksSnapshot + MiningEngine:resetPlayer из init.server.lua).
    onResetBlocks: ((player: Player) -> ())?,
}

local RebirthManager = {}
RebirthManager.__index = RebirthManager

-- Цвет для эпичного тоста и FX. RebirthFX.lua использует тот же оттенок
-- (mythicGold) — чтобы серверный notify и клиентский эффект читались как
-- одно событие.
local MYTHIC_GOLD = { r = 255, g = 210, b = 50 }

function RebirthManager.new(deps: Deps)
    local self = setmetatable({}, RebirthManager)
    self._log = Logger.new("RebirthManager")
    self._profileManager = deps.profileManager
    self._onProfileChanged = deps.onProfileChanged
    self._notify = deps.notify
    self._onResetBlocks = deps.onResetBlocks

    Net:Handle("Rebirth", function(player: Player)
        return self:_handleRebirth(player)
    end)

    self._log:info("RebirthManager initialized")
    return self
end

function RebirthManager:_data(player: Player): OreTypes.PlayerData?
    return self._profileManager:getData(player)
end

function RebirthManager:_sync(player: Player)
    if self._onProfileChanged then
        self._onProfileChanged(player)
    end
end

--[[
    Применить эффекты ребёрта к profileData. ВАЖНО: метод НЕ проверяет
    цену — это делает _handleRebirth. devRebirth / _handleRebirth — оба
    зовут эту функцию для единого reset-кода.
]]
function RebirthManager:_applyRebirth(player: Player, data: OreTypes.PlayerData)
    local newRebirths = (data.rebirths or 0) + 1

    -- Reset прогрессии. *Level = 1, не 0 — это согласовано с
    -- DEFAULT_DATA в ProfileManager (старт всегда с lvl 1).
    data.coins = 0
    data.inventory = {}
    data.pickaxeLevel = 1
    data.speedLevel = 1
    data.fortuneLevel = 1
    data.inventoryLevel = 1
    data.critLevel = 1
    data.multiSellLevel = 1
    data.autoSellUnlocked = false
    -- Локальное состояние сессии: глубина и тост Stone обнуляем, чтобы
    -- повторный спуск на 50м снова показал тост слоя.
    data.depth = 0
    data.layer = "dirt"
    ;(data :: any)._stoneLayerNotified = false

    -- Инкремент prestige + денормализация кэша.
    data.rebirths = newRebirths
    data.rebirthMultiplier = RebirthLogic.valueMultiplier(newRebirths)

    -- tutorialStep / firstSession НЕ трогаем — см. шапку.

    self._log:info(
        "Rebirth applied for", player.UserId,
        "- rebirths:", newRebirths,
        "- multiplier:", data.rebirthMultiplier
    )
end

function RebirthManager:_notifyRebirth(player: Player, data: OreTypes.PlayerData)
    if not self._notify then
        return
    end
    self._notify(player, {
        text = ("REBIRTH! Ребёрт #%d, теперь x%.1f к ценам руд"):format(
            data.rebirths or 0,
            data.rebirthMultiplier or 1
        ),
        icon = "💠",
        color = MYTHIC_GOLD,
        duration = 5,
        -- `kind` сигнализирует клиенту запустить RebirthFX. Notification.show
        -- проигнорирует поле (читает только text/color/icon/duration), а
        -- init.client.lua перехватит и зовёт RebirthFX.burst().
        kind = "rebirth",
    })
end

function RebirthManager:_handleRebirth(player: Player)
    local data = self:_data(player)
    if not data then
        return { success = false, error = "no_profile", message = "Профиль не загружен" }
    end

    local cost = RebirthLogic.cost(data.rebirths or 0)
    local coins = data.coins or 0
    if coins < cost then
        return {
            success = false,
            error = "not_enough_coins",
            message = ("Не хватает %d монет для ребёрта"):format(cost - coins),
            requiredCoins = cost,
        }
    end

    self:_applyRebirth(player, data)
    self:_notifyRebirth(player, data)

    if self._onResetBlocks then
        -- Опционально: сброс визуала шахты (см. init.server.lua).
        -- Не обязательно для функциональности ребёрта.
        local ok, err = pcall(self._onResetBlocks, player)
        if not ok then
            self._log:warn("onResetBlocks failed:", err)
        end
    end

    self:_sync(player)

    return {
        success = true,
        rebirths = data.rebirths,
        rebirthMultiplier = data.rebirthMultiplier,
        coinsSpent = cost,
        message = ("REBIRTH! x%.1f"):format(data.rebirthMultiplier or 1),
    }
end

--[[
    Вызывается из init.server.lua после ProfileManager:loadProfile.
    Идемпотентен: пересчитывает rebirthMultiplier из rebirths, чтобы кэш
    не разъезжался с формулой при ручных правках сейва или изменении
    multiplierPerRebirth в Constants между релизами.

    НЕ сбрасывает прогресс. НЕ начисляет ребёрты автоматически.
]]
function RebirthManager:onProfileLoaded(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    local r = math.max(0, math.floor(data.rebirths or 0))
    data.rebirths = r
    data.rebirthMultiplier = RebirthLogic.valueMultiplier(r)
end

--[[
    DI-хук для DevCommands /rebirth [N]: даёт N ребёртов без проверки
    цены. Используется только в Studio. Идёт через _applyRebirth, чтобы
    логика сброса и инкремента жила в одном месте.
]]
function RebirthManager:devRebirth(player: Player, count: number?)
    local n = math.max(1, math.floor(count or 1))
    local data = self:_data(player)
    if not data then
        return
    end
    for _ = 1, n do
        self:_applyRebirth(player, data)
    end
    self:_notifyRebirth(player, data)
    self:_sync(player)
end

return RebirthManager
