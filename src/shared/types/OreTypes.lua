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
    icon: string,      -- emoji сейчас, rbxassetid://... после визуального паса
    dropsOil: boolean?,
    isGeode: boolean?,
    -- Задел под Фазу 13 (визуальная идентичность): материалы, texture atlas,
    -- hero meshes. Сейчас не заполняются — рендер использует defaults
    -- (SmoothPlastic + ore.color). Добавление поля в записи OreDatabase
    -- автоматически активирует визуал без рефакторинга MiningRenderer.
    material: Enum.Material?,    -- встроенный материал (Slate, Foil, Glass, Neon...)
    reflectance: number?,        -- блеск 0..1 (Gold, Diamond)
    atlasIndex: number?,         -- индекс ячейки в общем texture atlas
    meshId: string?,             -- rbxassetid://... для hero-ассетов (сундуки)
    glow: boolean?,              -- использовать Material.Neon для мистических руд
}

export type OreInstance = {
    id: string,         -- уникальный ID блока на карте (напр. "grid_3_7")
    oreId: string,      -- ссылка на OreDef.id
    hp: number,         -- текущее HP
    maxHp: number,      -- максимальное HP
    depth: number,      -- на какой глубине находится
    isShaft: boolean,   -- внутри шахты?
}

-- Phase 10 (Daily Reward + Leaderboard): persistent state retention.
export type DailyState = {
    -- yday (1..366) и год последнего claim'а — используется DailyLogic.daysBetween
    -- чтобы корректно посчитать gap через границу года.
    lastClaimYday: number,
    lastClaimYear: number,
    -- 1..7 — позиция в недельном цикле. После Day 7 сбрасывается в 0;
    -- следующий claim снова Day 1. NextStreak = 1 + (currentStreak % 7).
    currentStreak: number,
    -- Pure-статистика, не сбрасывается при пропуске. Phase 11 может выдавать
    -- pet-яйцо за каждые 30 дней claim'ов.
    totalDaysClaimed: number,
}

export type ActiveBoost = {
    -- "coins" | "luck" | "damage" — в Phase 10 только "coins".
    kind: string,
    multiplier: number,
    -- Unix-timestamp окончания. PlayerBoosts.cleanup чистит истёкшие.
    expiresAt: number,
    -- Источник: "daily_day_4" / "daily_day_6" / "daily_day_7_bonus" / "devcmd"
    -- — для аналитики и UI tooltip («откуда взялся buff»).
    source: string?,
}

export type LeaderboardPlacement = {
    -- nil если игрок ещё не в top-N. UI показывает «—» в этом случае.
    coinsRank: number?,
    depthRank: number?,
    -- Последний записанный score (для оптимизации шага записи: пишем только
    -- если новое значение >= previousWritten + Constants.LEADERBOARD.writeThresholdCoins).
    coinsValue: number,
    depthValue: number,
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
    -- Phase 8 (онбординг): 0..3 — текущий шаг туториала (0 = не начат,
    -- 3 = завершён); firstSession = true до выдачи стартового бонуса.
    tutorialStep: number,
    firstSession: boolean,
    -- Phase 9 (rebirth / prestige): количество совершённых ребёртов и
    -- денормализованный множитель к value руд (rebirthMultiplier =
    -- 1 + rebirths * Constants.REBIRTH.multiplierPerRebirth).
    rebirths: number,
    rebirthMultiplier: number,
    -- Phase 10: retention-петля.
    --   dailyState           — текущий день/стрик в DailyReward.
    --   activeBoosts         — список временных мультипликаторов (x2 coins на 30 мин).
    --                          Хранятся в профиле, чтобы пережить respawn/rejoin.
    --   leaderboardPlacement — кэш ранга для UI; обновляется LeaderboardManager
    --                          раз в refreshIntervalSeconds.
    dailyState: DailyState,
    activeBoosts: { ActiveBoost },
    leaderboardPlacement: LeaderboardPlacement,
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
