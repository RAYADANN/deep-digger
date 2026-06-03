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
--   PetLogic.rollHatch(rng?)                      -> petId (weighted random)
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

local PetLogic = {}

type Pet = PetDatabase.Pet
type PetEffect = PetDatabase.PetEffect

local function cfg()
    return Constants.PETS or {}
end

function PetLogic.maxEquipped(): number
    return math.max(1, math.floor(cfg().maxEquipped or 1))
end

--[[
    Weighted random hatch из Basic Egg. Сначала по весам rarity
    (Constants.PETS.basicEggWeights), потом равновероятно внутри пула этой
    rarity (PetDatabase.getByRarity). Если пул пуст — спускаемся к common.
    `rng` опционален (для детерминированных тестов) — функция, возвращающая
    [0,1). По умолчанию math.random.
    Возвращает petId.
]]
function PetLogic.rollHatch(rng: (() -> number)?): string
    local random = rng or math.random
    local weights = cfg().basicEggWeights or {}
    -- Порядок rarity от редкого к частому для устойчивого обхода.
    local order = { "mythic", "legendary", "epic", "rare", "uncommon", "common" }

    local total = 0
    for _, rarity in ipairs(order) do
        total += math.max(0, weights[rarity] or 0)
    end
    if total <= 0 then
        -- Деградация: равные шансы по присутствующим rarity.
        total = #order
    end

    local r = random() * total
    local acc = 0
    local chosenRarity = "common"
    for _, rarity in ipairs(order) do
        acc += math.max(0, weights[rarity] or 0)
        if r <= acc then
            chosenRarity = rarity
            break
        end
    end

    -- Выбираем пета из пула выпавшей rarity; если пуст — спускаемся ниже.
    local fallback = { "epic", "rare", "uncommon", "common" }
    local pool = PetDatabase.getByRarity(chosenRarity)
    if #pool == 0 then
        for _, rarity in ipairs(fallback) do
            pool = PetDatabase.getByRarity(rarity)
            if #pool > 0 then
                break
            end
        end
    end
    if #pool == 0 then
        -- Совсем пусто (мисконфиг БД) — берём первого попавшегося.
        local all = PetDatabase.getAll()
        if #all > 0 then
            return all[1].id
        end
        return "pebble_pup"
    end
    local idx = math.floor(random() * #pool) + 1
    idx = math.clamp(idx, 1, #pool)
    return pool[idx].id
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
    local maxN = PetLogic.maxEquipped()
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
