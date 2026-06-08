--!strict
-- constants.lua — общие константы

local Constants = {}

export type LayerId = "dirt" | "stone" | "limestone" | "crimson" | "marble" | "obsidian" | "void"

Constants.LAYERS = {
    { id = "dirt" :: LayerId, name = "Grassland", depthStart = 0, depthEnd = 49, bgColor = Color3.fromRGB(150, 190, 120), blockColor = Color3.fromRGB(96, 158, 64) },
    { id = "stone" :: LayerId, name = "Stone Layer", depthStart = 50, depthEnd = 149, bgColor = Color3.fromRGB(74, 74, 74), blockColor = Color3.fromRGB(128, 128, 128) },
    { id = "limestone" :: LayerId, name = "Limestone Layer", depthStart = 150, depthEnd = 299, bgColor = Color3.fromRGB(212, 197, 169), blockColor = Color3.fromRGB(232, 213, 176) },
    { id = "crimson" :: LayerId, name = "Crimson Layer", depthStart = 300, depthEnd = 499, bgColor = Color3.fromRGB(74, 0, 0), blockColor = Color3.fromRGB(139, 0, 0) },
    { id = "marble" :: LayerId, name = "Marble Layer", depthStart = 500, depthEnd = 799, bgColor = Color3.fromRGB(232, 232, 232), blockColor = Color3.fromRGB(242, 242, 242) },
    { id = "obsidian" :: LayerId, name = "Obsidian Layer", depthStart = 800, depthEnd = 1199, bgColor = Color3.fromRGB(13, 0, 26), blockColor = Color3.fromRGB(26, 26, 46) },
    { id = "void" :: LayerId, name = "Void Layer", depthStart = 1200, depthEnd = math.huge, bgColor = Color3.fromRGB(0, 0, 0), blockColor = Color3.fromRGB(13, 0, 26) },
}

-- Phase 14 (визуальная идентичность): профиль освещения на слой — ощущение
-- «спуска вглубь». Данные (не формулы), читаются client/core/LayerEnvironment,
-- который твинит Lighting.Brightness / ClockTime / FogEnd + Atmosphere.Density.
-- dirt = яркая поверхность (полдень), void = почти полная тьма (полночь).
Constants.LAYER_LIGHTING = {
    dirt      = { brightness = 2.2,  clockTime = 14.0, fogEnd = 900, atmosphereDensity = 0.30, atmosphereHaze = 1.0 },
    stone     = { brightness = 1.7,  clockTime = 10.0, fogEnd = 700, atmosphereDensity = 0.35, atmosphereHaze = 1.4 },
    limestone = { brightness = 1.4,  clockTime = 8.0,  fogEnd = 600, atmosphereDensity = 0.40, atmosphereHaze = 1.8 },
    crimson   = { brightness = 1.0,  clockTime = 5.5,  fogEnd = 480, atmosphereDensity = 0.50, atmosphereHaze = 2.2 },
    marble    = { brightness = 1.5,  clockTime = 7.0,  fogEnd = 650, atmosphereDensity = 0.32, atmosphereHaze = 1.5 },
    obsidian  = { brightness = 0.65, clockTime = 2.0,  fogEnd = 380, atmosphereDensity = 0.55, atmosphereHaze = 2.6 },
    void      = { brightness = 0.35, clockTime = 0.0,  fogEnd = 300, atmosphereDensity = 0.60, atmosphereHaze = 3.0 },
}

-- Шахтёрский фонарик (client/core/Headlamp). PointLight на персонаже —
-- всегда освещает блоки рядом, не убивая атмосферу «спуска во тьму».
-- baseRange/baseBrightness — на поверхности; глубже свет чуть ярче и дальше
-- (depthBonus * нормализованная глубина), чтобы во тьме void было видно.
-- Один источник света — дёшево по перфу (важно после фикса фризов).
Constants.HEADLAMP = {
    enabled = false, -- выкл: свет перенесён на курсор (CURSOR_LIGHT)
    color = Color3.fromRGB(255, 244, 214), -- тёплый белый, как лампа накаливания
    baseRange = 26,
    maxRange = 42,
    baseBrightness = 1.6,
    maxBrightness = 3.0,
    -- глубина (в метрах), на которой фонарик достигает max-значений
    fullPowerDepth = 1200,
    shadows = false, -- тени дороги; держим выкл для производительности
}

-- Свет фонарика на курсоре (client/core/MiningRenderer). Небольшой PointLight
-- следует за лучом мыши в шахте — освещает блок под прицелом, не персонажа.
Constants.CURSOR_LIGHT = {
    brightness = 0.85,
    range = 11,
    color = Color3.fromRGB(255, 248, 230),
    -- если луч не попал в блок — свет вдоль луча на этой дистанции (студы)
    fallbackDistance = 14,
}

Constants.BLOCK_SIZE_STUDS = 4.5
Constants.SURFACE_W = 15
Constants.SURFACE_D = 15
Constants.SURFACE_H = 10
Constants.SHAFT_W = 5
Constants.SHAFT_D = 5
Constants.SHAFT_H = 5

Constants.RARITY_CHANCES = { common = 0.50, uncommon = 0.30, rare = 0.15, epic = 0.04, legendary = 0.009, mythic = 0.001 }
-- Fallback-вес спавна по rarity, если у руды нет явного weight в OreDatabase.
Constants.RARITY_DEFAULT_WEIGHT = {
    common = 100,
    uncommon = 22,
    rare = 5,
    epic = 1.2,
    legendary = 0.3,
    mythic = 0.08,
}
Constants.RARITY_COLORS = {
    common = Color3.fromRGB(180, 180, 180),
    uncommon = Color3.fromRGB(100, 200, 100),
    rare = Color3.fromRGB(60, 140, 255),
    epic = Color3.fromRGB(180, 60, 220),
    legendary = Color3.fromRGB(255, 160, 0),
    mythic = Color3.fromRGB(255, 50, 50),
}
Constants.RARITY_LABELS = {
    common = "Common",
    uncommon = "Uncommon",
    rare = "Rare",
    epic = "Epic",
    legendary = "Legendary",
    mythic = "Mythic",
}
-- Скрытые комнаты (MiningEngine.hitBlock):
--   шанс комнаты = SHAFT_BASE_CHANCE + depth * SHAFT_DEPTH_BONUS
--   на каждом шаге каверны 3x3x3 кубик становится air с вероятностью SHAFT_EXPAND_CHANCE
--   редкость сундука бустится на (1 + math.random(0, SHAFT_RARITY_BOOST_MAX)) ступеней
Constants.SHAFT_BASE_CHANCE = 0.08
Constants.SHAFT_DEPTH_BONUS = 0.0001
Constants.SHAFT_EXPAND_CHANCE = 0.7
Constants.SHAFT_RARITY_BOOST_MAX = 2
Constants.SHAFT_RARE_BOOST = 0.25
Constants.SHAFT_PERMANENT_BONUS = 0.005

Constants.UPGRADES = {
    pickaxe = { baseCost = 50, exponent = 1.5, maxLevel = 100, powerPerLevel = 2 },
    speed = { baseCost = 100, exponent = 1.3, maxLevel = 50, reductionMs = 35 },
    fortune = { baseCost = 500, exponent = 1.6, maxLevel = 30, chancePerLevel = 0.02 },
    inventory = { baseCost = 150, exponent = 1.4, maxLevel = 20, slotsPerLevel = 5 },
    crit = { baseCost = 400, exponent = 1.6, maxLevel = 15, chancePerLevel = 0.03, baseChance = 0.05 },
    multiSell = { baseCost = 800, exponent = 1.8, maxLevel = 10, bonusPerLevel = 0.05 },
    autoSell = { baseCost = 5000, maxLevel = 1 },
}

Constants.STONE_PICKAXE_MIN_LEVEL = 5
Constants.STONE_DAMAGE_PENALTY = 0.5

Constants.BASE_INVENTORY_SLOTS = 10
Constants.BASE_SWING_DELAY_MS = 400
Constants.MIN_SWING_DELAY_SECONDS = 0.05
Constants.MAX_CLICKS_PER_SECOND = 20
Constants.MAX_MINE_BATCH_SIZE = 16
Constants.AUTOSAVE_INTERVAL = 60

-- Phase 8 (Онбординг): стартовый баланс, чтобы новичок сразу мог купить
-- pickaxe lvl 2 (baseCost 50) с запасом и почувствовал прогрессию в первые
-- 30 секунд. Выдаётся серверным TutorialManager один раз через флаг
-- profile.firstSession.
Constants.STARTER_COINS = 100

-- Шаги туториала (server validates monotonic growth in {0,1,2,3}).
Constants.TUTORIAL_STEPS = {
    NOT_STARTED = 0,
    MINED_FIRST_BLOCK = 1,
    SOLD_FIRST_ORE = 2,
    COMPLETED = 3,
}

-- Phase 9 (Rebirth / Prestige): долгосрочная петля.
--   baseCost              — стоимость первого ребёрта.
--   exponent              — множитель цены на каждый следующий ребёрт
--                            (cost = baseCost * exponent^rebirths).
--   multiplierPerRebirth  — прирост к value руд за каждый ребёрт.
--                            Денормализованный кэш живёт в
--                            playerData.rebirthMultiplier и применяется
--                            в SellInventory (payout *= mult).
--   pickaxeMaxBonusAt     — пороги количества ребёртов, на которых
--                            maxLevel у pickaxe увеличивается на +1.
--                            UpgradeLogic.maxLevel сам считает количество
--                            «перейденных» порогов.
-- Формулы — единый источник в shared/util/RebirthLogic.lua.
Constants.REBIRTH = {
    baseCost = 50000,
    exponent = 5,
    multiplierPerRebirth = 0.1,
    pickaxeMaxBonusAt = { 5, 10, 25 },
}

-- Phase 10 (Daily Reward + Leaderboard): retention-петля.
--
-- DAILY:
--   cycleDays                   — длина цикла (7 в стандартных Roblox-симах).
--   grantBoostAtDay7            — Day 7 выдаёт coins + x2 boost; флаг для
--                                  будущего A/B-теста.
--   streakResetAfterMissedDays  — если игрок пропустил N+ дней подряд, streak
--                                  обнуляется в 1 (= Day 1).
--   rolloverCheckInterval       — сколько секунд между проверками «у кого
--                                  наступил новый день» в серверном task.spawn.
--                                  60с — компромисс: точность тикает чаще,
--                                  чем игрок успевает кликнуть, но не сжигает
--                                  CPU при 50 одновременных игроках.
-- Формулы дней — shared/util/DailyLogic.lua. Сетка наград — DailyRewardDatabase.lua.
Constants.DAILY = {
    cycleDays = 7,
    grantBoostAtDay7 = true,
    streakResetAfterMissedDays = 2,
    rolloverCheckInterval = 60,
}

-- LEADERBOARD:
--   COINS_MAP / DEPTH_MAP        — ключи MemoryStoreSortedMap. Версионируем
--                                   суффиксом _v1 чтобы при изменении схемы
--                                   можно было ввести _v2 без удаления данных.
--   topSize                      — длина leaderboard'a, который кэшируется
--                                   на сервере и рассылается клиенту.
--   refreshIntervalSeconds       — сервер тянет свежий top из MemoryStore
--                                   раз в N секунд. 30с — это compromise:
--                                   игрок видит «обновление через 28с» в UI,
--                                   а нагрузка на MemoryStore — раз в 30с/сервер,
--                                   не на каждого игрока.
--   expirationSeconds            — TTL для записей в MemoryStore. 30 дней —
--                                   неактивные игроки выпадают из топа.
--   writeThresholdCoins / Depth  — минимальный шаг изменения метрики, чтобы
--                                   записать в MemoryStore. Без порога каждая
--                                   продажа дёргала бы SetAsync — это съело бы
--                                   квоту MemoryStore на сервере. 100 монет /
--                                   5 м глубины — игрок не замечает «лага»,
--                                   но кол-во записей падает на порядок.
Constants.LEADERBOARD = {
    COINS_MAP = "Leaderboard_Coins_v1",
    DEPTH_MAP = "Leaderboard_Depth_v1",
    topSize = 50,
    refreshIntervalSeconds = 30,
    expirationSeconds = 60 * 60 * 24 * 30,
    writeThresholdCoins = 100,
    writeThresholdDepth = 5,
}

-- Phase 11 (Pets MVP): жанро-определяющая механика.
--
-- PETS:
--   maxEquipped       — сколько петов можно держать экипированными
--                        одновременно. 1 на старте MVP; gamepass из Фазы 12
--                        («+2 pet slots») поднимет до 3 — поэтому читаем это
--                        число везде через PetLogic, а не хардкодим 1.
--   hatchBatchMax     — макс. яиц за один Net:Handle("HatchEgg", count)
--                        («open 10x»). Античит на сервере клампит count.
--   multiMineMaxChance — потолок суммарного шанса multiMine, чтобы стек из
--                        нескольких multiMine-петов (после gamepass slots)
--                        не давал гарантированный второй блок каждый удар.
--   luckMaxMultiplier  — потолок множителя шанса скрытых комнат (luckBoost),
--                        чтобы не сломать экономику комнат на стеках.
--   eggs              — определения яиц. На MVP один тип «basic».
--                        cost — цена в монетах за ОДНО яйцо.
-- Формулы (weighted roll, аккумуляция эффектов) — в shared/util/PetLogic.lua.
-- Сами питомцы и их эффекты — в shared/data/PetDatabase.lua.
Constants.PETS = {
    maxEquipped = 1,
    hatchBatchMax = 10,
    multiMineMaxChance = 0.9,
    luckMaxMultiplier = 3.0,
    eggs = {
        basic = {
            id = "basic",
            name = "Basic Egg",
            icon = "🥚",
            cost = 1000,
        },
    },
    -- Веса rarity для weighted random hatch из Basic Egg. Сумма не обязана
    -- быть 1 — PetLogic нормализует. Common доминирует, mythic — джекпот.
    -- Внутри выпавшей rarity пет выбирается равновероятно из пула этой
    -- редкости в PetDatabase.
    basicEggWeights = {
        common = 0.55,
        uncommon = 0.27,
        rare = 0.13,
        epic = 0.04,
        legendary = 0.009,
        mythic = 0.001,
    },
}

-- Phase 12 (Монетизация): revenue stream после запуска.
--
-- GAMEPASSES — одноразовые покупки (Robux), проверяются через
--   MarketplaceService:UserOwnsGamePassAsync (source of truth) и кэшируются
--   в playerData.gamepasses[key]. Эффекты применяет MonetizationManager,
--   формулы (coinBoost / petSlotBonus) — единый источник в
--   shared/util/MonetizationLogic.lua.
--
--   key        — внутренний ключ (НЕ id). Используется в playerData.gamepasses,
--                DevCommands /grantpass <key>, ShopPanel.
--   id         — реальный Gamepass ID из Creator Hub. 0 = ПЛЕЙСХОЛДЕР, заменить
--                после создания пасса (в Studio реальные покупки невозможны —
--                эмуляция через /grantpass).
--   priceRobux — справочная цена для UI (фактическую берёт Roblox из Hub).
--   coinBoost  — VIP: аддитивный бонус к продаже (+0.10 = +10%), ложится в ту
--                же boost-стадию SellInventory, что daily/pet coinBoost.
--   slotBonus  — petSlots: +N к Constants.PETS.maxEquipped (через PetLogic).
Constants.GAMEPASSES = {
    vip = {
        key = "vip",
        id = 0,
        name = "VIP",
        icon = "👑",
        priceRobux = 399,
        desc = "+10% монет, титул VIP и золотой ник",
        coinBoost = 0.10,
        title = "VIP",
        nameColor = Color3.fromRGB(255, 210, 50),
    },
    autoSell = {
        key = "autoSell",
        id = 0,
        name = "Auto-Sell",
        icon = "♻",
        priceRobux = 599,
        desc = "Авто-продажа навсегда — инвентарь не переполнится",
    },
    petSlots = {
        key = "petSlots",
        id = 0,
        name = "+2 слота питомцев",
        icon = "🐾",
        priceRobux = 799,
        desc = "Экипируй до 3 питомцев одновременно",
        slotBonus = 2,
    },
}

-- DEVPRODUCTS — повторяемые покупки (Robux), обрабатываются через
--   MarketplaceService.ProcessReceipt в MonetizationManager. Защита от
--   двойного начисления — DataStore purchase history по PurchaseId.
--
--   key    — внутренний ключ (DevCommands /grantproduct <key> [N], ShopPanel).
--   id     — реальный DeveloperProduct ID из Creator Hub. 0 = ПЛЕЙСХОЛДЕР.
--   kind   — "coins" | "eggs" — что выдаём.
--   amount — сколько (монет / яиц).
Constants.DEVPRODUCTS = {
    coinsSmall = {
        key = "coinsSmall",
        id = 0,
        name = "Small Coin Pack",
        icon = "💰",
        priceRobux = 99,
        kind = "coins",
        amount = 10000,
        desc = "+10 000 монет",
    },
    coinsMedium = {
        key = "coinsMedium",
        id = 0,
        name = "Medium Coin Pack",
        icon = "💰",
        priceRobux = 399,
        kind = "coins",
        amount = 100000,
        desc = "+100 000 монет",
    },
    egg10 = {
        key = "egg10",
        id = 0,
        name = "Egg 10x",
        icon = "🥚",
        priceRobux = 199,
        kind = "eggs",
        amount = 10,
        desc = "10 яиц сразу",
    },
}

-- Phase 13 (Ore Discovery Index): ключевая retention-механика. Цель охоты —
-- сама руда (как в оригинале), а не петы. Журнал находок («Открыто N/M»)
-- превращает копание в коллекционирование кор-ресурса.
--
-- DISCOVERY:
--   layerMilestoneCoins — разовая награда за ПОЛНОСТЬЮ открытый слой (все
--     руды слоя найдены хотя бы раз). Масштабируется с глубиной — нижние
--     слои гейтятся ребёртами, поэтому награда растёт на порядки. Защита от
--     двойной выдачи — playerData.discoveredMilestones[layerId].
-- Формулы (прогресс, каталог по слоям, проверка полноты) — единый источник в
-- shared/util/DiscoveryLogic.lua. Сами руды — shared/data/OreDatabase.lua.
Constants.DISCOVERY = {
    layerMilestoneCoins = {
        dirt = 2500,
        stone = 15000,
        limestone = 75000,
        crimson = 300000,
        marble = 1000000,
        obsidian = 5000000,
        void = 25000000,
    },
}

return Constants
