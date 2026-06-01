--!strict
-- OreTypes.lua — типы руд и структур данных.
-- Универсальный: можно перенести в любой проект с рудной системой.

export type Rarity = "common" | "uncommon" | "rare" | "epic" | "legendary" | "mythic"

export type OreDef = {
    id: string,
    name: string,
    layer: string,
    rarity: Rarity,
    hp: number,
    value: number,
    xp: number,
    color: Color3,
    icon: string,      -- rbxassetid://...
    dropsOil: boolean?,
    isGeode: boolean?,
}

export type OreInstance = {
    id: string,         -- уникальный ID блока на карте (напр. "grid_3_7")
    oreId: string,      -- ссылка на OreDef.id
    hp: number,         -- текущее HP
    maxHp: number,      -- максимальное HP
    depth: number,      -- на какой глубине находится
    isShaft: boolean,   -- внутри шахты?
}

export type PlayerData = {
    depth: number,
    layer: string,
    coins: number,
    gems: number,
    pickaxeLevel: number,
    speedLevel: number,
    fortuneLevel: number,
    inventoryLevel: number,
    critLevel: number,
    multiSellLevel: number,
    autoSellUnlocked: boolean,
    inventory: { [string]: number },  -- [oreId] = количество
    totalBlocksMined: number,
    totalCoinsEarned: number,
    bossesDefeated: number,
    maxDepthReached: number,
    shaftsFound: { string },
    playTime: number,
    lastSave: number,
}

export type UpgradeDef = {
    id: string,
    name: string,
    baseCost: number,
    exponent: number,
    maxLevel: number,
    description: string,
    effectPerLevel: string,
}

return {}
