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
    -- Визуальная идентичность (Фаза 14): material/reflectance/glow заполнены
    -- по слоям в OreDatabase, рендер читает их с приоритетом над
    -- ORE_VISUAL_BY_RARITY. atlasIndex/meshId — задел под texture atlas и
    -- hero-меши (post-MVP), пока не заполняются.
    material: Enum.Material?,    -- встроенный материал (Slate, Foil, Glass, Metal...)
    reflectance: number?,        -- блеск 0..1 (Gold, Diamond)
    atlasIndex: number?,         -- индекс ячейки в общем texture atlas
    meshId: string?,             -- rbxassetid://... для hero-ассетов (сундуки)
    glow: boolean?,              -- шиммер-материал (Foil) для мистических руд; Neon с блоков убран (нагрузка/bloom)
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

-- Phase 11 (Pets MVP): запись о владении питомцем.
--   uid   — уникальный идентификатор экземпляра (несколько одинаковых петов
--           различимы), генерируется сервером через petUidCounter.
--   petId — ссылка на PetDatabase.Pet.id (определение, эффект, визуал).
export type PetRecord = {
    uid: string,
    petId: string,
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
    -- Phase 11 (Pets MVP):
    --   pets          — инвентарь питомцев (записи { uid, petId }).
    --   equippedPet   — uid экипированного пета (1 slot на старте; string?).
    --                   PetLogic.getEquippedUids поддерживает и список (для
    --                   будущего gamepass «+2 pet slots» из Фазы 12).
    --   petUidCounter — монотонный счётчик для генерации uid'ов (server-only).
    pets: { PetRecord },
    equippedPet: string?,
    petUidCounter: number,
    -- Phase 12 (Монетизация): кэш владения геймпассами по key
    -- (Constants.GAMEPASSES). Source of truth — UserOwnsGamePassAsync,
    -- MonetizationManager синкает кэш на заходе и на покупке. Девпродукты
    -- (coin packs / egg 10x) сюда НЕ пишутся — они повторяемые.
    gamepasses: { [string]: boolean },
    -- Phase 13 (Ore Discovery Index): журнал находок — ключевая retention-
    -- механика (цель охоты = руда).
    --   discoveredOres       — { [oreId] = true } какие руды найдены (>=1 раз).
    --                          ПЕРЕЖИВАЕТ ребёрт (это коллекция-история, не
    --                          прогрессия) — RebirthManager поле не трогает.
    --   discoveredMilestones — { [layerId] = true } за какие слои выдана
    --                          milestone-награда (защита от двойного грантa).
    discoveredOres: { [string]: boolean },
    discoveredMilestones: { [string]: boolean },
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
