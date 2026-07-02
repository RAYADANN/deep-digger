--!strict
-- MutationLogic.lua — P2.9 (Ore Mutation / Variant).
--
-- Единственный источник формул системы мутаций руды (по аналогии с
-- RebirthLogic / PetLogic). Сервер катит ролл (MiningEngine) и считает бонус
-- (init.server), клиент берёт оттенок/название для тинта блока и FX. Дубликаты
-- таблицы шансов / множителей запрещены — только вызовы отсюда.
--
-- Данные — Constants.MUTATIONS (rollChance + variants). Variant:
--   { id, name, valueMult, weight, tint }.
--
-- API:
--   MutationLogic.roll(rng?)          -> string?  (id мутации или nil)
--   MutationLogic.get(id)             -> variant? (определение варианта)
--   MutationLogic.valueMultiplier(id) -> number   (множитель ценности, 1 если нет)
--   MutationLogic.tint(id)            -> Color3?
--   MutationLogic.label(id)           -> string?

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local MutationLogic = {}

local function cfg()
    return Constants.MUTATIONS or {}
end

function MutationLogic.get(id: string?): any?
    if typeof(id) ~= "string" then
        return nil
    end
    for _, variant in ipairs(cfg().variants or {}) do
        if variant.id == id then
            return variant
        end
    end
    return nil
end

function MutationLogic.valueMultiplier(id: string?): number
    local variant = MutationLogic.get(id)
    return variant and variant.valueMult or 1
end

function MutationLogic.tint(id: string?): Color3?
    local variant = MutationLogic.get(id)
    return variant and variant.tint or nil
end

function MutationLogic.label(id: string?): string?
    local variant = MutationLogic.get(id)
    return variant and variant.name or nil
end

-- Серверный ролл мутации для нового блока руды. Возвращает id варианта или
-- nil (обычный блок). `rng` опционален — прокидывается в тестах для
-- детерминизма. Сначала проверяется общий rollChance, затем взвешенный выбор
-- варианта по weight.
function MutationLogic.roll(rng: (() -> number)?): string?
    local c = cfg()
    local chance = c.rollChance or 0
    if chance <= 0 then
        return nil
    end
    local rand = rng or math.random
    if rand() >= chance then
        return nil
    end
    local variants = c.variants or {}
    local total = 0
    for _, variant in ipairs(variants) do
        total += (variant.weight or 0)
    end
    if total <= 0 then
        return nil
    end
    local r = rand() * total
    local acc = 0
    for _, variant in ipairs(variants) do
        acc += (variant.weight or 0)
        if r <= acc then
            return variant.id
        end
    end
    local last = variants[#variants]
    return last and last.id or nil
end

return MutationLogic
