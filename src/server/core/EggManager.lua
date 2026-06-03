--!strict
-- EggManager.lua — Phase 11 (Pets MVP).
--
-- Экономика яиц: определения (из Constants.PETS.eggs), цена, batch-hatch.
-- НЕ хранит состояние игрока — это делает PetManager (playerData.pets).
-- Формула weighted random roll живёт в PetLogic.rollHatch (единый источник),
-- здесь только оркестрация count + стоимости.
--
-- MVP: один тип яйца «basic» (Basic Egg). Добавление Gold Egg в патче 1.1 =
-- новая запись в Constants.PETS.eggs + (опц.) свои веса rarity.
--
-- Plain-модуль (без .new / DI): функции чистые, читают только Constants +
-- PetLogic. PetManager require'ит его напрямую.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local Constants = require(shared.constants)
local PetLogic = require(shared.util.PetLogic)

local EggManager = {}

export type EggDef = {
    id: string,
    name: string,
    icon: string,
    cost: number,
}

function EggManager.getEgg(eggId: string): EggDef?
    local eggs = (Constants.PETS or {}).eggs or {}
    return eggs[eggId]
end

-- Цена за `count` яиц данного типа. Возвращает 0 для неизвестного яйца —
-- вызывающий (PetManager) сам решит, что делать (вернёт ошибку).
function EggManager.totalCost(eggId: string, count: number): number
    local egg = EggManager.getEgg(eggId)
    if not egg then
        return 0
    end
    local n = math.max(0, math.floor(count or 0))
    return (egg.cost or 0) * n
end

-- Клампит запрошенное число яиц в [1, hatchBatchMax] — серверный античит на
-- «open 10x» (клиент не может запросить 1000 яиц одним вызовом).
function EggManager.clampCount(count: number?): number
    local maxN = math.max(1, math.floor((Constants.PETS or {}).hatchBatchMax or 10))
    local n = math.floor(count or 1)
    return math.clamp(n, 1, maxN)
end

--[[
    Прокатить `count` хэтчей. Возвращает список petId (по одному на яйцо).
    `rng` опционален — прокидывается в PetLogic.rollHatch для детерминированных
    тестов. Здесь НЕТ списания монет и записи в профиль — это PetManager.
]]
function EggManager.hatch(eggId: string, count: number, rng: (() -> number)?): { string }
    local egg = EggManager.getEgg(eggId)
    local result: { string } = {}
    if not egg then
        return result
    end
    local n = EggManager.clampCount(count)
    for _ = 1, n do
        table.insert(result, PetLogic.rollHatch(rng))
    end
    return result
end

return EggManager
