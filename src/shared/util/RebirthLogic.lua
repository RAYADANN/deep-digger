--!strict
-- RebirthLogic.lua — Phase 9.
--
-- Единственный источник формул prestige-системы (по аналогии с
-- UpgradeLogic.lua). Любой потребитель — сервер (RebirthManager,
-- SellInventory, BuyUpgrade), клиент (RebirthPanel, StatsPanel, UpgRow
-- tooltip) — обязан звать функции отсюда. Дубликаты math.floor(baseCost *
-- exponent^rebirths) в нескольких местах = баг при первой смене баланса.
--
-- API:
--   RebirthLogic.cost(rebirths)                  -> number  (стоимость
--                                                            СЛЕДУЮЩЕГО
--                                                            ребёрта)
--   RebirthLogic.valueMultiplier(rebirths)       -> number  (1 + r * 0.1)
--   RebirthLogic.pickaxeMaxLevelBonus(rebirths)  -> number  (сколько
--                                                            порогов R5/R10/
--                                                            R25 уже пройдено)
--   RebirthLogic.describeReward(currentRebirths) -> string  ("x1.3 → x1.4")
--   RebirthLogic.nextPickaxeBonusThreshold(r)    -> number? (ближайший
--                                                             ещё не открытый
--                                                             порог; nil если
--                                                             все пройдены)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local RebirthLogic = {}

local function cfg()
    return Constants.REBIRTH or {}
end

-- Стоимость ОЧЕРЕДНОГО ребёрта при текущем количестве `rebirths`.
-- Первый ребёрт (rebirths == 0) стоит baseCost, второй — baseCost*exponent,
-- и т.д. math.floor — чтобы серверная валидация и клиентский UI совпадали
-- бит-в-бит (числа с плавающей точкой могут разойтись на 1 монету).
function RebirthLogic.cost(rebirths: number): number
    local c = cfg()
    local base = c.baseCost or 50000
    local exp = c.exponent or 5
    local r = math.max(0, math.floor(rebirths or 0))
    return math.floor(base * (exp ^ r))
end

-- Множитель к value руд после `rebirths` ребёртов. Используется в
-- SellInventory и денормализуется в playerData.rebirthMultiplier.
-- P1.4: мультипликативная награда — multiplierBase ^ rebirths (компаундится).
-- Fallback на старую линейную формулу (1 + r*per), если multiplierBase нет.
function RebirthLogic.valueMultiplier(rebirths: number): number
    local c = cfg()
    local r = math.max(0, math.floor(rebirths or 0))
    if c.multiplierBase then
        return c.multiplierBase ^ r
    end
    local per = c.multiplierPerRebirth or 0.1
    return 1 + r * per
end

-- P1.4: бонусные слоты пета за пройденные пороги REBIRTH.petSlotBonusAt.
-- Складывается с базой Constants.PETS.maxEquipped и gamepass-бонусом
-- внутри PetLogic.maxEquipped (единственный потребитель).
function RebirthLogic.petSlotBonus(rebirths: number): number
    local c = cfg()
    local thresholds = c.petSlotBonusAt or {}
    local r = math.max(0, math.floor(rebirths or 0))
    local count = 0
    for _, threshold in ipairs(thresholds) do
        if r >= threshold then
            count += 1
        end
    end
    return count
end

-- P1.4: бонусные слоты рюкзака за ребёрты (линейно по
-- REBIRTH.inventorySlotsPerRebirth). Складывается в UpgradeLogic.inventoryCapacity.
function RebirthLogic.inventorySlotBonus(rebirths: number): number
    local c = cfg()
    local per = math.max(0, math.floor(c.inventorySlotsPerRebirth or 0))
    local r = math.max(0, math.floor(rebirths or 0))
    return r * per
end

-- Сколько +1 к maxLevel pickaxe уже разблокировано. Порог считается
-- «пройденным», когда `rebirths >= threshold` — то есть на R5
-- pickaxeMaxBonusAt = {5,10,25} вернёт 1, на R10 → 2, на R25 → 3.
function RebirthLogic.pickaxeMaxLevelBonus(rebirths: number): number
    local c = cfg()
    local thresholds = c.pickaxeMaxBonusAt or {}
    local r = math.max(0, math.floor(rebirths or 0))
    local count = 0
    for _, threshold in ipairs(thresholds) do
        if r >= threshold then
            count += 1
        end
    end
    return count
end

-- Следующий ещё не пройденный порог из pickaxeMaxBonusAt, либо nil если
-- все пороги пройдены. RebirthPanel использует это для тизера типа
-- «Следующий бонус: +1 maxLevel кирки на R10».
function RebirthLogic.nextPickaxeBonusThreshold(rebirths: number): number?
    local c = cfg()
    local thresholds = c.pickaxeMaxBonusAt or {}
    local r = math.max(0, math.floor(rebirths or 0))
    for _, threshold in ipairs(thresholds) do
        if r < threshold then
            return threshold
        end
    end
    return nil
end

-- Текстовое описание множителя для UI. P1.4: множитель теперь компаундится
-- (×1.6/ребёрт) и быстро уходит в десятки/сотни — формат адаптивный:
-- <10 → одна цифра после точки (x1.6), 10..999 → целое (x110), иначе
-- компактно (x1.2k). Экспортируем — RebirthPanel/RebirthConfirmModal зовут
-- отсюда, без дублей формата.
function RebirthLogic.formatMultiplier(value: number): string
    if value < 10 then
        return ("x%.1f"):format(value)
    elseif value < 1000 then
        return ("x%d"):format(math.floor(value + 0.5))
    elseif value < 1000000 then
        return ("x%.1fk"):format(value / 1000)
    end
    return ("x%.1fM"):format(value / 1000000)
end

function RebirthLogic.describeReward(currentRebirths: number): string
    local now = RebirthLogic.valueMultiplier(currentRebirths)
    local nextR = RebirthLogic.valueMultiplier(currentRebirths + 1)
    return ("К ценам руд: %s → %s"):format(
        RebirthLogic.formatMultiplier(now),
        RebirthLogic.formatMultiplier(nextR)
    )
end

return RebirthLogic
