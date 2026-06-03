--!strict
-- PetDatabase.lua — Phase 11 (Pets MVP).
--
-- Единственный источник правды по питомцам. Лежит в shared/data (как
-- OreDatabase / DailyRewardDatabase): читают и сервер (PetManager / EggManager
-- при hatch + расчёт эффектов через PetLogic), и клиент (PetsPanel / PetCard /
-- PetVisual для отрисовки).
--
-- Поля Pet:
--   id      — стабильный строковый ключ (хранится в playerData.pets[i].petId).
--   name    — отображаемое имя (русский, игра локализована на ru).
--   rarity  — common..mythic. Маппится в Constants.RARITY_COLORS / theme.
--   icon    — emoji сейчас, rbxassetid://... после визуального паса (Фаза 13).
--   color   — базовый цвет для PetVisual-модели и карточки (fallback к rarity).
--   effect  — { kind, value }:
--      kind = "damageBoost" — value = доля прироста урона (0.15 = +15%).
--      kind = "luckBoost"   — value = доля прироста шанса скрытых комнат.
--      kind = "coinBoost"   — value = доля прироста монет при продаже.
--      kind = "multiMine"   — value = шанс сломать дополнительный блок (0..1).
--
-- Балансные числа жить ТОЛЬКО здесь и в Constants.PETS. PetLogic.lua формулы
-- не дублирует — он только аккумулирует эффекты экипированных петов.
--
-- MVP-набор: 10 питомцев, покрывают все 4 типа эффектов и rarity-ramp
-- common → mythic. Внутри одной rarity сила эффекта одинакова по типу, но
-- сильнее на верхних редкостях (см. value).

export type PetEffectKind = "damageBoost" | "luckBoost" | "coinBoost" | "multiMine"
export type PetRarity = "common" | "uncommon" | "rare" | "epic" | "legendary" | "mythic"

export type PetEffect = {
    kind: PetEffectKind,
    value: number,
}

export type Pet = {
    id: string,
    name: string,
    rarity: PetRarity,
    icon: string,
    color: Color3,
    effect: PetEffect,
}

local PETS: { Pet } = {
    -- common
    {
        id = "pebble_pup", name = "Камешек", rarity = "common",
        icon = "🐶", color = Color3.fromRGB(170, 160, 150),
        effect = { kind = "damageBoost", value = 0.10 },
    },
    {
        id = "coin_chick", name = "Монетка", rarity = "common",
        icon = "🐤", color = Color3.fromRGB(200, 190, 120),
        effect = { kind = "coinBoost", value = 0.10 },
    },
    -- uncommon
    {
        id = "mole_digger", name = "Кротёныш", rarity = "uncommon",
        icon = "🦔", color = Color3.fromRGB(120, 200, 120),
        effect = { kind = "damageBoost", value = 0.20 },
    },
    {
        id = "lucky_cat", name = "Удачливый кот", rarity = "uncommon",
        icon = "🐱", color = Color3.fromRGB(120, 210, 140),
        effect = { kind = "luckBoost", value = 0.20 },
    },
    -- rare
    {
        id = "gem_fox", name = "Самоцветный лис", rarity = "rare",
        icon = "🦊", color = Color3.fromRGB(60, 140, 255),
        effect = { kind = "coinBoost", value = 0.25 },
    },
    {
        id = "drill_bot", name = "Бур-бот", rarity = "rare",
        icon = "🤖", color = Color3.fromRGB(80, 150, 255),
        effect = { kind = "multiMine", value = 0.15 },
    },
    -- epic
    {
        id = "crystal_owl", name = "Кристальная сова", rarity = "epic",
        icon = "🦉", color = Color3.fromRGB(180, 60, 220),
        effect = { kind = "damageBoost", value = 0.40 },
    },
    {
        id = "midas_hound", name = "Золотой гончий", rarity = "epic",
        icon = "🐕", color = Color3.fromRGB(200, 80, 230),
        effect = { kind = "coinBoost", value = 0.40 },
    },
    -- legendary
    {
        id = "phoenix_drake", name = "Огненный дракончик", rarity = "legendary",
        icon = "🐉", color = Color3.fromRGB(255, 160, 0),
        effect = { kind = "multiMine", value = 0.30 },
    },
    -- mythic
    {
        id = "void_titan", name = "Титан Бездны", rarity = "mythic",
        icon = "👾", color = Color3.fromRGB(255, 60, 60),
        effect = { kind = "damageBoost", value = 1.00 },
    },
}

-- O(1) лукап по id (строим один раз при require).
local byId: { [string]: Pet } = {}
for _, pet in ipairs(PETS) do
    byId[pet.id] = pet
end

-- Пулы по rarity для weighted hatch (PetLogic берёт случайного из пула
-- выпавшей редкости).
local byRarity: { [string]: { Pet } } = {}
for _, pet in ipairs(PETS) do
    local bucket = byRarity[pet.rarity]
    if not bucket then
        bucket = {}
        byRarity[pet.rarity] = bucket
    end
    table.insert(bucket, pet)
end

local module = {}

function module.get(petId: string): Pet?
    return byId[petId]
end

function module.getAll(): { Pet }
    return PETS
end

function module.getByRarity(rarity: string): { Pet }
    return byRarity[rarity] or {}
end

return module
