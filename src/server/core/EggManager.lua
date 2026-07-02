--!strict
-- EggManager.lua — Phase 11 (Pets MVP).
--
-- Экономика яиц: определения (из Constants.PETS.eggs), цена, batch-hatch.
-- НЕ хранит состояние игрока — это делает PetManager (playerData.pets).
-- Пул питомцев и weighted roll — PetLogic + EggPoolDatabase (единый источник),
-- здесь только оркестрация count + стоимости.
--
-- MVP: один тип яйца «basic» (Basic Egg). Новые яйца =
-- запись в Constants.PETS.eggs + пул в EggPoolDatabase.
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
    modelName: string?,
    cost: number,
    gemCost: number?,
}

export type Currency = "coins" | "gems"

function EggManager.getEgg(eggId: string): EggDef?
    local eggs = (Constants.PETS or {}).eggs or {}
    return eggs[eggId]
end

-- Цена в монетах за `count` яиц. 0 для неизвестного яйца — вызывающий решит.
function EggManager.totalCost(eggId: string, count: number): number
    local egg = EggManager.getEgg(eggId)
    if not egg then
        return 0
    end
    local n = math.max(0, math.floor(count or 0))
    return (egg.cost or 0) * n
end

-- P1.6: цена за `count` яиц в выбранной валюте. Для gems используется
-- egg.gemCost (nil/0 → яйцо нельзя купить за гемы). Единая точка цены для
-- сервера (валидация) и клиента (кнопки), чтобы числа не разъезжались.
function EggManager.totalPrice(eggId: string, count: number, currency: Currency): number
    local egg = EggManager.getEgg(eggId)
    if not egg then
        return 0
    end
    local n = math.max(0, math.floor(count or 0))
    if currency == "gems" then
        return (egg.gemCost or 0) * n
    end
    return (egg.cost or 0) * n
end

-- Можно ли купить это яйцо за гемы (есть положительный gemCost).
function EggManager.acceptsGems(eggId: string): boolean
    local egg = EggManager.getEgg(eggId)
    return egg ~= nil and typeof(egg.gemCost) == "number" and egg.gemCost > 0
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
        table.insert(result, PetLogic.rollHatch(eggId, rng))
    end
    return result
end

return EggManager
