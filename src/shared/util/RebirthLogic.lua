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
function RebirthLogic.valueMultiplier(rebirths: number): number
    local c = cfg()
    local per = c.multiplierPerRebirth or 0.1
    local r = math.max(0, math.floor(rebirths or 0))
    return 1 + r * per
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

-- Текстовое описание прироста множителя «до → после» для UI подтверждения.
local function formatMultiplier(value: number): string
    -- 1, 1.1, 1.2 ... — одна цифра после точки достаточно (multiplier
    -- меняется кратно 0.1 при дефолтном multiplierPerRebirth).
    return ("x%.1f"):format(value)
end

function RebirthLogic.describeReward(currentRebirths: number): string
    local now = RebirthLogic.valueMultiplier(currentRebirths)
    local nextR = RebirthLogic.valueMultiplier(currentRebirths + 1)
    return ("К ценам руд: %s → %s"):format(formatMultiplier(now), formatMultiplier(nextR))
end

return RebirthLogic
