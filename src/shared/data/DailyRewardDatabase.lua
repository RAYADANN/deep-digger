--!strict
-- DailyRewardDatabase.lua — Phase 10.
--
-- Сетка наград на 7 дней daily-reward цикла.
-- По аналогии с OreDatabase / SoundDatabase лежит в shared/data: используется
-- и сервером (DailyReward.lua при выдаче), и клиентом (DailyRewardModal /
-- DailyCard для отрисовки сетки наперёд).
--
-- Поля:
--   type        — "coins" (выдать N монет) | "boost" (выдать temporary multiplier).
--   amount      — для coins это число монет; для boost — множитель (например 2.0).
--   duration    — для boost: сколько секунд действует.
--   rarity      — визуальная редкость карточки. Маппится в RARITY_COLORS на клиенте.
--   label       — подпись для UI (русский, потому что игра локализована на ru).
--   bonusBoost  — на Day 7 эпик-награда: coins + дополнительный boost.
--
-- Балансные числа жить ТОЛЬКО здесь и в Constants.DAILY. DailyLogic.lua
-- формулы НЕ дублирует — он отвечает только за day math (yday, streak, gap).
--
-- Если меняешь сетку — синхронизируй с MVP.md «Фаза 10», иначе текст в
-- доках разойдётся с реальным геймплеем.

export type RewardKind = "coins" | "boost"
export type RewardRarity = "common" | "uncommon" | "rare" | "epic" | "legendary" | "mythic"

export type BoostBonus = {
    multiplier: number,
    duration: number,
}

export type DailyReward = {
    type: RewardKind,
    amount: number,
    duration: number?,
    rarity: RewardRarity,
    label: string,
    -- Day 7: дополнительно к coins выдаём boost. На остальных днях nil.
    bonusBoost: BoostBonus?,
}

local DailyRewardDatabase: { [number]: DailyReward } = {
    [1] = { type = "coins", amount = 500,   rarity = "common",    label = "+500 монет" },
    [2] = { type = "coins", amount = 1000,  rarity = "common",    label = "+1,000 монет" },
    [3] = { type = "coins", amount = 2500,  rarity = "uncommon",  label = "+2,500 монет" },
    [4] = { type = "boost", amount = 2.0, duration = 600,         rarity = "rare",      label = "x2 на 10 мин" },
    [5] = { type = "coins", amount = 10000, rarity = "epic",      label = "+10,000 монет" },
    [6] = { type = "boost", amount = 2.0, duration = 1800,        rarity = "legendary", label = "x2 на 30 мин" },
    [7] = {
        type = "coins",
        amount = 50000,
        rarity = "mythic",
        bonusBoost = { multiplier = 2, duration = 1800 },
        label = "+50,000 монет + x2/30мин",
    },
}

local module = {}

function module.get(cycleDay: number): DailyReward?
    return DailyRewardDatabase[cycleDay]
end

function module.getAll(): { [number]: DailyReward }
    return DailyRewardDatabase
end

-- Иконка для UI по типу/rarity (DailyCard читает это). Можно вынести в
-- отдельный модуль когда добавим pets/eggs, сейчас inline.
function module.iconFor(reward: DailyReward): string
    if reward.type == "coins" then
        return "coin"
    elseif reward.type == "boost" then
        return "upg_speed"
    end
    return "icon_gift"
end

return module
