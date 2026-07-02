--!strict
-- PetLogic.lua — Phase 11 (Pets MVP).
--
-- Единственный источник формул пет-системы (по аналогии с RebirthLogic /
-- DailyLogic / PlayerBoosts). Любой потребитель — сервер (PetManager,
-- EggManager, MiningEngine, SellInventory), клиент (PetsPanel, PetCard) —
-- обязан звать функции отсюда. Дубликаты «1 + Σ damageBoost» в нескольких
-- местах = рассинхрон сервер/клиент при первой смене баланса.
--
-- Аккумуляция эффектов — additive, как PlayerBoosts.totalMultiplier:
--   два пета по +20% damage → +40% (x1.4), а не x1.44. Intuitive для игрока
--   и согласовано с daily-boost стеком из Фазы 10.
--
-- Структуры в playerData (см. OreTypes.PlayerData):
--   pets         — { { uid: string, petId: string }, ... } (инвентарь петов).
--   equippedPet  — uid экипированного пета (string?) ИЛИ список uid'ов
--                  (для будущего multi-slot после gamepass). Обе формы
--                  поддерживаются getEquippedUids.
--   petUidCounter — монотонный счётчик для генерации uid'ов (server-only).
--
-- API:
--   PetLogic.maxEquipped()                       -> number
--   PetLogic.getEggPool(eggId)                   -> { petId, weight }[]
--   PetLogic.getHatchOdds(eggId)                 -> { petId, rarity, percent, weight }[]
--   PetLogic.rollHatch(eggId?, rng?)             -> petId (weighted random из пула яйца)
--   PetLogic.getEquippedUids(data)               -> { string }
--   PetLogic.getEquippedPets(data)               -> { Pet }  (def'ы из PetDatabase)
--   PetLogic.damageMultiplier(data)              -> number  (1 + Σ damageBoost)
--   PetLogic.luckMultiplier(data)                -> number  (clamp 1 + Σ luckBoost)
--   PetLogic.coinBoostSum(data)                  -> number  (Σ coinBoost, аддитив)
--   PetLogic.multiMineChance(data)               -> number  (clamp Σ multiMine)
--   PetLogic.summary(data)                       -> { damage, luck, coin, multiMine, equippedCount }
--   PetLogic.describeEffect(pet)                 -> string  ("+15% урона")
--   PetLogic.effectShort(effect)                 -> string

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local Constants = require(shared.constants)
local PetDatabase = require(shared.data.PetDatabase)
local EggPoolDatabase = require(shared.data.EggPoolDatabase)
-- Phase 12: gamepass «+2 pet slots» расширяет maxEquipped. MonetizationLogic
-- читает только Constants + playerData.gamepasses → циклической зависимости с
-- PetLogic нет (MonetizationLogic про петов не знает).
local MonetizationLogic = require(shared.util.MonetizationLogic)
-- P1.4: ребёрт открывает доп. слоты петов (RebirthLogic.petSlotBonus).
-- RebirthLogic зависит только от Constants → цикла с PetLogic нет.
local RebirthLogic = require(shared.util.RebirthLogic)

local PetLogic = {}

type Pet = PetDatabase.Pet
type PetEffect = PetDatabase.PetEffect

local function cfg()
    return Constants.PETS or {}
end

--[[
    Сколько питомцев можно держать экипированными. База — Constants.PETS.maxEquipped
    (1 на старте). Если передан `data` и игрок владеет геймпассом «+2 pet slots»
    (Phase 12), потолок поднимается на slotBonus. Вызывать с data везде, где есть
    профиль — иначе слоты пасса не учтутся.
]]
function PetLogic.maxEquipped(data: any?): number
    local base = math.max(1, math.floor(cfg().maxEquipped or 1))
    if data then
        base += MonetizationLogic.petSlotBonus(data)
        base += RebirthLogic.petSlotBonus(data.rebirths or 0)
    end
    return base
end

local RARITY_SORT_ORDER = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6 }

export type EggPoolEntry = EggPoolDatabase.PoolEntry

export type HatchOddEntry = {
    petId: string,
    rarity: string,
    name: string,
    percent: number,
    weight: number,
}

--[[
    Пул питомцев конкретного яйца. Неизвестный eggId → basic.
]]
function PetLogic.getEggPool(eggId: string): { EggPoolEntry }
    return EggPoolDatabase.getPool(eggId)
end

--[[
    Нормализованные шансы выпадения каждого питомца в яйце (клиент + сервер).
    percent — доля 0..100, округление на стороне UI.
]]
function PetLogic.getHatchOdds(eggId: string): { HatchOddEntry }
    local pool = PetLogic.getEggPool(eggId)
    local total = 0
    for _, entry in ipairs(pool) do
        total += math.max(0, entry.weight)
    end

    local result: { HatchOddEntry } = {}
    for _, entry in ipairs(pool) do
        local w = math.max(0, entry.weight)
        if w > 0 then
            local def = PetDatabase.get(entry.petId)
            if def then
                table.insert(result, {
                    petId = entry.petId,
                    rarity = def.rarity,
                    name = def.name,
                    percent = if total > 0 then (w / total) * 100 else 0,
                    weight = w,
                })
            end
        end
    end

    table.sort(result, function(a, b)
        local ra = RARITY_SORT_ORDER[a.rarity] or 99
        local rb = RARITY_SORT_ORDER[b.rarity] or 99
        if ra ~= rb then
            return ra < rb
        end
        if a.percent ~= b.percent then
            return a.percent > b.percent
        end
        return a.petId < b.petId
    end)

    return result
end

--[[
    Weighted random hatch из пула яйца eggId.
    `rng` опционален (для детерминированных тестов) — функция [0,1).
]]
function PetLogic.rollHatch(eggId: string?, rng: (() -> number)?): string
    local random = rng or math.random
    local pool = PetLogic.getEggPool(eggId or "basic")

    local total = 0
    for _, entry in ipairs(pool) do
        total += math.max(0, entry.weight)
    end
    if total <= 0 then
        return "pebble_pup"
    end

    local r = random() * total
    local acc = 0
    for _, entry in ipairs(pool) do
        local w = math.max(0, entry.weight)
        if w > 0 then
            acc += w
            if r <= acc then
                return entry.petId
            end
        end
    end

    return pool[#pool].petId
end

--[[
    Нормализует equippedPet к списку uid'ов. Поддерживает обе формы:
      * string  — один uid (MVP, 1 slot).
      * table   — массив uid'ов (forward-compat для gamepass +slots).
      * nil     — пусто.
    Дополнительно клампит длину до maxEquipped (защита от рассинхрона).
]]
function PetLogic.getEquippedUids(data: any): { string }
    local result: { string } = {}
    if not data then
        return result
    end
    local eq = data.equippedPet
    if typeof(eq) == "string" and eq ~= "" then
        table.insert(result, eq)
    elseif typeof(eq) == "table" then
        for _, uid in ipairs(eq) do
            if typeof(uid) == "string" and uid ~= "" then
                table.insert(result, uid)
            end
        end
    end
    local maxN = PetLogic.maxEquipped(data)
    while #result > maxN do
        table.remove(result)
    end
    return result
end

-- Резолвит uid → запись пета в playerData.pets.
local function findRecord(data: any, uid: string): any?
    if not data or typeof(data.pets) ~= "table" then
        return nil
    end
    for _, rec in ipairs(data.pets) do
        if typeof(rec) == "table" and rec.uid == uid then
            return rec
        end
    end
    return nil
end

--[[
    Список Pet-определений (из PetDatabase) для экипированных петов.
    Битые uid'ы / неизвестные petId молча пропускаются.
]]
function PetLogic.getEquippedPets(data: any): { Pet }
    local pets: { Pet } = {}
    for _, uid in ipairs(PetLogic.getEquippedUids(data)) do
        local rec = findRecord(data, uid)
        if rec then
            local def = PetDatabase.get(rec.petId)
            if def then
                table.insert(pets, def)
            end
        end
    end
    return pets
end

-- Внутренний аккумулятор: сумма value по конкретному kind эффекта среди
-- экипированных петов.
local function sumEffect(data: any, kind: string): number
    local sum = 0
    for _, pet in ipairs(PetLogic.getEquippedPets(data)) do
        local eff = pet.effect
        if eff and eff.kind == kind and typeof(eff.value) == "number" then
            sum += eff.value
        end
    end
    return sum
end

-- 1 + Σ damageBoost. Применяется в MiningEngine:hitBlock к урону.
function PetLogic.damageMultiplier(data: any): number
    return 1 + sumEffect(data, "damageBoost")
end

-- 1 + Σ luckBoost, клампится сверху luckMaxMultiplier (стек питомцев не
-- должен гарантировать комнату каждый удар).
function PetLogic.luckMultiplier(data: any): number
    local mult = 1 + sumEffect(data, "luckBoost")
    local maxMult = cfg().luckMaxMultiplier or 3.0
    return math.clamp(mult, 1, maxMult)
end

-- Σ coinBoost (аддитивный бонус, НЕ +1). Складывается в boost-стадию
-- SellInventory вместе с daily-boost'ами: coinMult = boostMult + coinBoostSum.
function PetLogic.coinBoostSum(data: any): number
    return sumEffect(data, "coinBoost")
end

-- Шанс сломать дополнительный блок. Клампится multiMineMaxChance.
function PetLogic.multiMineChance(data: any): number
    local chance = sumEffect(data, "multiMine")
    local maxChance = cfg().multiMineMaxChance or 0.9
    return math.clamp(chance, 0, maxChance)
end

--[[
    Сводка эффектов для HUD-payload (PetsPanel рисует индикатор бустов).
    Возвращает уже «человеческие» числа: damage/luck — множители (1.4),
    coin — аддитивный бонус (0.25 = +25%), multiMine — шанс (0..1).
]]
function PetLogic.summary(data: any): { damage: number, luck: number, coin: number, multiMine: number, equippedCount: number }
    return {
        damage = PetLogic.damageMultiplier(data),
        luck = PetLogic.luckMultiplier(data),
        coin = PetLogic.coinBoostSum(data),
        multiMine = PetLogic.multiMineChance(data),
        equippedCount = #PetLogic.getEquippedUids(data),
    }
end

local function formatPercent(value: number): string
    return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

-- Короткое описание эффекта для карточки/тултипа.
function PetLogic.effectShort(effect: PetEffect?): string
    if not effect then
        return "—"
    end
    local v = effect.value or 0
    if effect.kind == "damageBoost" then
        return ("+%s урона"):format(formatPercent(v))
    elseif effect.kind == "luckBoost" then
        return ("+%s удачи"):format(formatPercent(v))
    elseif effect.kind == "coinBoost" then
        return ("+%s монет"):format(formatPercent(v))
    elseif effect.kind == "multiMine" then
        return ("%s ×2 блока"):format(formatPercent(v))
    end
    return "—"
end

function PetLogic.describeEffect(pet: Pet?): string
    if not pet then
        return "—"
    end
    return PetLogic.effectShort(pet.effect)
end

return PetLogic
