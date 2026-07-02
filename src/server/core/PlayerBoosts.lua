--!strict
-- PlayerBoosts.lua — Phase 10.
--
-- Чистые функции для работы с playerData.activeBoosts. НЕ singleton —
-- передаётся как dep в SellInventory / DailyReward / DevCommands.
--
-- Структура boost'а:
--   { kind = "coins" | "luck" | "damage" | "speed", multiplier = 2, expiresAt = 1696000000, source = "daily_day_4" }
--
-- API:
--   PlayerBoosts.totalMultiplier(activeBoosts, kind, now?) -> number
--   PlayerBoosts.addBoost(activeBoosts, opts)              -> ActiveBoost
--   PlayerBoosts.cleanup(activeBoosts, now?)               -> boolean (true=что-то удалили)
--   PlayerBoosts.activeFor(activeBoosts, kind, now?)       -> { ActiveBoost }
--
-- Принципы:
--   * Не мутирует список при cleanup'е напрямую — фильтрует in-place чтобы
--     ProfileService увидел изменение и сохранил.
--   * Истёкшие boost'ы НЕ суммируются в totalMultiplier (это и есть
--     причина, по которой важно дёргать cleanup перед totalMultiplier).
--   * Если в activeBoosts несколько активных «coins x2» — мультипликаторы
--     складываются как (1 + Σ(m - 1)), не перемножаются. Это intuitive для
--     игрока («два x2 = x3», а не x4). Pet Sim 99 / Mining Sim 2 используют
--     этот стиль.

local PlayerBoosts = {}

export type ActiveBoost = {
    kind: string,
    multiplier: number,
    expiresAt: number,
    source: string?,
}

export type AddBoostOptions = {
    kind: string,
    multiplier: number,
    durationSec: number,
    source: string?,
}

local function nowOr(now: number?): number
    return now or os.time()
end

--[[
    Удаляет истёкшие boost'ы из списка. Мутирует in-place (table.remove с конца).
    Возвращает true если был удалён хотя бы один — это сигнал для вызывающего
    стрельнуть syncPlayerHud (UI обновит BoostChip).
]]
function PlayerBoosts.cleanup(activeBoosts: { ActiveBoost }?, now: number?): boolean
    if not activeBoosts or #activeBoosts == 0 then
        return false
    end
    local n = nowOr(now)
    local removed = false
    for i = #activeBoosts, 1, -1 do
        local boost = activeBoosts[i]
        if not boost or typeof(boost) ~= "table" or (boost.expiresAt or 0) <= n then
            table.remove(activeBoosts, i)
            removed = true
        end
    end
    return removed
end

--[[
    Все активные boost'ы данного `kind`. cleanup НЕ вызывается — это
    «view» функция, мутации только через cleanup/addBoost.
]]
function PlayerBoosts.activeFor(activeBoosts: { ActiveBoost }?, kind: string, now: number?): { ActiveBoost }
    local result: { ActiveBoost } = {}
    if not activeBoosts then
        return result
    end
    local n = nowOr(now)
    for _, boost in ipairs(activeBoosts) do
        if typeof(boost) == "table"
            and boost.kind == kind
            and (boost.expiresAt or 0) > n
        then
            table.insert(result, boost)
        end
    end
    return result
end

--[[
    Суммарный множитель для kind. Если активных boost'ов нет — возвращает 1.

    Стиль аккумуляции — additive: x2 + x2 = x3 (1 + (2-1) + (2-1)).
    Альтернатива multiplicative (x4) ломает балансировку: легендарные
    события легко комбинируются в нереальные суммы.
]]
function PlayerBoosts.totalMultiplier(activeBoosts: { ActiveBoost }?, kind: string, now: number?): number
    local active = PlayerBoosts.activeFor(activeBoosts, kind, now)
    if #active == 0 then
        return 1
    end
    local bonus = 0
    for _, boost in ipairs(active) do
        local m = boost.multiplier or 1
        if m > 1 then
            bonus += (m - 1)
        end
    end
    return 1 + bonus
end

--[[
    Добавить boost. Если уже активен boost того же kind+source — продлеваем
    (max(existing.expiresAt, new.expiresAt)) вместо плодения дубликатов.
    Это для idempotency: /daily-сценарий не должен наплодить 5 одинаковых
    boost'ов при множественных вызовах за секунду.
]]
function PlayerBoosts.addBoost(activeBoosts: { ActiveBoost }, opts: AddBoostOptions): ActiveBoost
    local n = os.time()
    local expiresAt = n + math.max(1, math.floor(opts.durationSec or 60))
    -- Поиск существующего boost'a с тем же kind+source — продлеваем.
    if opts.source then
        for _, boost in ipairs(activeBoosts) do
            if typeof(boost) == "table"
                and boost.kind == opts.kind
                and boost.source == opts.source
            then
                boost.expiresAt = math.max(boost.expiresAt or 0, expiresAt)
                boost.multiplier = opts.multiplier or boost.multiplier
                return boost
            end
        end
    end
    local boost: ActiveBoost = {
        kind = opts.kind,
        multiplier = opts.multiplier or 2,
        expiresAt = expiresAt,
        source = opts.source,
    }
    table.insert(activeBoosts, boost)
    return boost
end

--[[
    Сериализация boost'а для клиентского HUD-payload'а. Добавляем remaining
    в секундах, чтобы BoostChip не пересчитывал os.time() на клиенте (там
    серверный os.time может разъезжаться).
]]
function PlayerBoosts.toPayload(boost: ActiveBoost, now: number?): { kind: string, multiplier: number, remaining: number, source: string?, expiresAt: number }
    local n = nowOr(now)
    local remaining = math.max(0, (boost.expiresAt or 0) - n)
    return {
        kind = boost.kind,
        multiplier = boost.multiplier or 1,
        remaining = remaining,
        source = boost.source,
        expiresAt = boost.expiresAt or 0,
    }
end

function PlayerBoosts.toPayloadList(activeBoosts: { ActiveBoost }?, now: number?): { any }
    local result: { any } = {}
    if not activeBoosts then
        return result
    end
    local n = nowOr(now)
    for _, boost in ipairs(activeBoosts) do
        if typeof(boost) == "table" and (boost.expiresAt or 0) > n then
            table.insert(result, PlayerBoosts.toPayload(boost, n))
        end
    end
    return result
end

return PlayerBoosts
