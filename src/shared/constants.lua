--!strict
-- constants.lua — общие константы

local Constants = {}

export type LayerId = "dirt" | "stone" | "limestone" | "crimson" | "marble" | "obsidian" | "void"

Constants.LAYERS = {
    { id = "dirt" :: LayerId, name = "Dirt Layer", depthStart = 0, depthEnd = 49, bgColor = Color3.fromRGB(92, 58, 30), blockColor = Color3.fromRGB(139, 105, 20) },
    { id = "stone" :: LayerId, name = "Stone Layer", depthStart = 50, depthEnd = 149, bgColor = Color3.fromRGB(74, 74, 74), blockColor = Color3.fromRGB(128, 128, 128) },
    { id = "limestone" :: LayerId, name = "Limestone Layer", depthStart = 150, depthEnd = 299, bgColor = Color3.fromRGB(212, 197, 169), blockColor = Color3.fromRGB(232, 213, 176) },
    { id = "crimson" :: LayerId, name = "Crimson Layer", depthStart = 300, depthEnd = 499, bgColor = Color3.fromRGB(74, 0, 0), blockColor = Color3.fromRGB(139, 0, 0) },
    { id = "marble" :: LayerId, name = "Marble Layer", depthStart = 500, depthEnd = 799, bgColor = Color3.fromRGB(232, 232, 232), blockColor = Color3.fromRGB(242, 242, 242) },
    { id = "obsidian" :: LayerId, name = "Obsidian Layer", depthStart = 800, depthEnd = 1199, bgColor = Color3.fromRGB(13, 0, 26), blockColor = Color3.fromRGB(26, 26, 46) },
    { id = "void" :: LayerId, name = "Void Layer", depthStart = 1200, depthEnd = math.huge, bgColor = Color3.fromRGB(0, 0, 0), blockColor = Color3.fromRGB(13, 0, 26) },
}

Constants.BLOCK_SIZE_STUDS = 4.5
Constants.SURFACE_W = 15
Constants.SURFACE_D = 15
Constants.SURFACE_H = 10
Constants.SHAFT_W = 5
Constants.SHAFT_D = 5
Constants.SHAFT_H = 5

Constants.RARITY_CHANCES = { common = 0.50, uncommon = 0.30, rare = 0.15, epic = 0.04, legendary = 0.009, mythic = 0.001 }
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

return Constants
