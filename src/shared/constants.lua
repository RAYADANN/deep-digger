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
    dirt      = { brightness = 2.2,  clockTime = 14.0, fogStart = 120, fogEnd = 900, atmosphereDensity = 0.30, atmosphereHaze = 1.0 },
    stone     = { brightness = 1.7,  clockTime = 10.0, fogStart = 100, fogEnd = 700, atmosphereDensity = 0.35, atmosphereHaze = 1.4 },
    limestone = { brightness = 1.4,  clockTime = 8.0,  fogStart = 80,  fogEnd = 600, atmosphereDensity = 0.40, atmosphereHaze = 1.8 },
    crimson   = { brightness = 0.85, clockTime = 5.5,  fogStart = 40,  fogEnd = 380, atmosphereDensity = 0.62, atmosphereHaze = 3.0 },
    marble    = { brightness = 1.5,  clockTime = 7.0,  fogStart = 90,  fogEnd = 650, atmosphereDensity = 0.38, atmosphereHaze = 1.8 },
    obsidian  = { brightness = 0.55, clockTime = 2.0,  fogStart = 25,  fogEnd = 300, atmosphereDensity = 0.68, atmosphereHaze = 3.2 },
    void      = { brightness = 0.28, clockTime = 0.0,  fogStart = 15,  fogEnd = 220, atmosphereDensity = 0.78, atmosphereHaze = 3.8 },
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
    brightness = 0.45,
    range = 9,
    color = Color3.fromRGB(255, 248, 230),
    -- если луч не попал в блок — свет вдоль луча на этой дистанции (студы)
    fallbackDistance = 14,
}

Constants.BLOCK_SIZE_STUDS = 4.5
-- Макс. дистанция копания от персонажа (в блоках сетки).
Constants.MAX_MINE_REACH_BLOCKS = 6

-- P0.3 (server-authoritative depth): клиент шлёт depth через "UpdateDepth",
-- но это client-trusted (спуф maxDepthReached / лидерборда / квестов). Сервер
-- пересчитывает «правдоподобную» глубину из Y персонажа (LayerUtil.depthFromY,
-- та же формула что у клиента) и клампит заявленную глубину к serverDepth +
-- slackBlocks. slackBlocks покрывает джиттер репликации и то, что игрок копает
-- на пару блоков ниже корня. Спуф «я на 9999м» обрезается до реальной глубины.
Constants.DEPTH_VALIDATION = {
    slackBlocks = 6,
}

-- P2.9 (Ore Mutation / Variant): «трейлерный» момент. С маленьким шансом
-- свежесгенерированный блок руды становится мутировавшим вариантом — светится
-- в стене своим оттенком, а при добыче даёт бонусные монеты = (valueMult-1) *
-- базовая ценность руды + нотификацию. Полностью data-driven; логика ролла и
-- lookup'ы — shared/util/MutationLogic.lua (единый источник клиент+сервер).
--   rollChance — шанс что блок руды мутирует (на каждый сгенерированный блок).
--   variants   — варианты с весами (внутри ролла), множителем ценности и
--                визуальным оттенком (Neon-tint у блока в стене).
Constants.MUTATIONS = {
    rollChance = 0.004,
    variants = {
        { id = "shiny", name = "Блестящая", valueMult = 5, weight = 100, tint = Color3.fromRGB(150, 235, 255) },
        { id = "golden", name = "Золотая", valueMult = 15, weight = 32, tint = Color3.fromRGB(255, 205, 55) },
        { id = "rainbow", name = "Радужная", valueMult = 50, weight = 5, tint = Color3.fromRGB(255, 110, 225) },
    },
}
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
    -- P1.7 (fix speed): раньше reductionMs = 35 (линейно) упирался в пол
    -- MIN_SWING_DELAY_SECONDS уже к ~ур.11 — уровни 12-50 стоили дороже за ноль
    -- эффекта. Теперь reductionPct — мультипликативное (diminishing) снижение:
    -- delay = BASE * (1 - reductionPct)^(lvl-1). При 0.04 на ур.50 задержка
    -- ~0.054с (близко к полу, но НЕ упирается раньше) — все 50 уровней дают
    -- ощутимый прирост, кривая остаётся плавной.
    speed = { baseCost = 100, exponent = 1.3, maxLevel = 50, reductionPct = 0.04 },
    fortune = { baseCost = 500, exponent = 1.6, maxLevel = 30, chancePerLevel = 0.02 },
    inventory = { baseCost = 150, exponent = 1.4, maxLevel = 20, slotsPerLevel = 5 },
    crit = { baseCost = 400, exponent = 1.6, maxLevel = 15, chancePerLevel = 0.03, baseChance = 0.05 },
    multiSell = { baseCost = 800, exponent = 1.8, maxLevel = 10, bonusPerLevel = 0.05 },
    autoSell = { baseCost = 5000, maxLevel = 1 },
}

Constants.STONE_PICKAXE_MIN_LEVEL = 5
Constants.STONE_DAMAGE_PENALTY = 0.5

-- P0.2 (early-loop juice): стартовая ёмкость рюкзака. С inventoryLevel = 1
-- (старт) ёмкость = BASE + 1 * slotsPerLevel = 25 + 5 = 30 — игрок продаёт
-- реже (раз в ~30 блоков, а не каждые 6 секунд) и видит крупнее число продажи.
Constants.BASE_INVENTORY_SLOTS = 25
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

-- Phase 9 / P1.4 (Rebirth / Prestige rework): долгосрочная петля.
--   baseCost              — стоимость первого ребёрта.
--   exponent              — множитель цены на каждый следующий ребёрт
--                            (cost = baseCost * exponent^rebirths).
--   multiplierBase        — P1.4: МУЛЬТИПЛИКАТИВНАЯ награда. Множитель к value
--                            руд = multiplierBase ^ rebirths (компаундится):
--                            R1 ×1.6, R3 ×4.1, R5 ×10.5, R10 ×110. Раньше было
--                            линейно (1 + r*0.1) → prestige умирал к R3-R5.
--   multiplierPerRebirth  — legacy fallback (используется только если
--                            multiplierBase не задан).
--   pickaxeMaxBonusAt     — пороги ребёртов, на которых maxLevel pickaxe +1.
--   petSlotBonusAt        — P1.4: пороги, на которых открывается +1 слот пета
--                            (через PetLogic.maxEquipped). Долгосрочный анлок.
--   inventorySlotsPerRebirth — P1.4: +N слотов рюкзака за каждый ребёрт
--                            (через UpgradeLogic.inventoryCapacity).
-- Кривая: цена растёт ×3.5/ребёрт, доход ×1.6/ребёрт + анлоки — prestige
-- остаётся выгодным в долгую (множитель компаундится, гриндить быстрее).
-- Формулы — единый источник в shared/util/RebirthLogic.lua.
Constants.REBIRTH = {
    baseCost = 25000,
    exponent = 3.5,
    multiplierBase = 1.6,
    multiplierPerRebirth = 0.1,
    pickaxeMaxBonusAt = { 5, 10, 25 },
    petSlotBonusAt = { 3, 8, 15 },
    inventorySlotsPerRebirth = 5,
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
--   eggs              — определения яиц (цена, иконка, модель).
--                        Пул питомцев каждого яйца — shared/data/EggPoolDatabase.lua.
--                        cost — цена в монетах за ОДНО яйцо.
-- Формулы (weighted roll, аккумуляция эффектов) — в shared/util/PetLogic.lua.
-- Сами питомцы и их эффекты — в shared/data/PetDatabase.lua (30 playable).
Constants.PETS = {
    maxEquipped = 1,
    hatchBatchMax = 10,
    multiMineMaxChance = 0.9,
    luckMaxMultiplier = 3.0,
    eggs = {
        basic = {
            id = "basic",
            name = "Basic Egg",
            icon = "icon_egg",
            modelName = "Basic",
            cost = 1000,
            accent = Color3.fromRGB(120, 220, 100),
        },
        desert = {
            id = "desert",
            name = "Desert Egg",
            icon = "icon_egg",
            modelName = "Desert",
            cost = 7500,
            -- P1.6 (gem sink) + P2.8 (2-е яйцо): Desert Egg покупается за
            -- КРИСТАЛЛЫ (из квестов/достижений). gemCost — цена за 1 яйцо.
            -- Свой пул питомцев — EggPoolDatabase.desert.
            gemCost = 100,
            accent = Color3.fromRGB(255, 180, 70),
        },
        candy = {
            id = "candy",
            name = "Candy Egg",
            icon = "icon_egg",
            modelName = "Candy",
            cost = 35000,
            accent = Color3.fromRGB(255, 120, 200),
        },
        ocean = {
            id = "ocean",
            name = "Ocean Egg",
            icon = "icon_egg",
            modelName = "Ocean",
            cost = 150000,
            accent = Color3.fromRGB(70, 170, 255),
        },
        lava = {
            id = "lava",
            name = "Lava Egg",
            icon = "icon_egg",
            modelName = "Lava",
            cost = 750000,
            accent = Color3.fromRGB(255, 90, 45),
        },
        explosive_hydro = {
            id = "explosive_hydro",
            name = "Explosive Hydro Egg",
            icon = "icon_egg",
            modelName = "Explosive Hydro",
            cost = 3000000,
            accent = Color3.fromRGB(60, 240, 255),
        },
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
        id = 0, -- TODO: paste Creator Hub ID
        name = "VIP",
        icon = "icon_crown",
        priceRobux = 399,
        desc = "+10% монет, титул VIP и золотой ник",
        coinBoost = 0.10,
        title = "VIP",
        nameColor = Color3.fromRGB(255, 210, 50),
    },
    autoSell = {
        key = "autoSell",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Auto-Sell",
        icon = "upg_autosell",
        priceRobux = 599,
        badge = "ПОПУЛЯРНО",
        desc = "Авто-продажа навсегда — инвентарь не переполнится",
    },
    petSlots = {
        key = "petSlots",
        id = 0, -- TODO: paste Creator Hub ID
        name = "+2 слота питомцев",
        icon = "tab_pets",
        priceRobux = 799,
        desc = "Экипируй до 3 питомцев одновременно",
        slotBonus = 2,
    },
}

-- DEVPRODUCTS — повторяемые покупки (Robux), обрабатываются через
--   MarketplaceService.ProcessReceipt в MonetizationManager. Защита от
--   двойного начисления — DataStore purchase history по PurchaseId.
--
--   key           — внутренний ключ (DevCommands /grantproduct <key> [N], ShopPanel).
--   id            — реальный DeveloperProduct ID из Creator Hub. 0 = ПЛЕЙСХОЛДЕР.
--   kind          — "coins" | "eggs" | "egg_hatch" | "boost" | "bundle".
--   amount        — для coins/eggs.
--   wasPriceRobux — зачёркнутая «старая» цена в UI (скидка).
--   badge         — лента на карточке («СТАРТ», «-50%», «ХИТ»).
--   oneTime       — true → shopPurchases[key], повторная покупка не выдаёт награду.
--   perks         — список строк для hero-карточек наборов.
--   rewards       — для kind=bundle: { { kind, amount? }, { kind=boost, boostKind, multiplier, durationSec } }.
--   boostKind / multiplier / durationSec — для kind=boost.
Constants.DEVPRODUCTS = {
    starterPack = {
        key = "starterPack",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Стартовый набор",
        icon = "pack_starter",
        priceRobux = 99,
        wasPriceRobux = 499,
        badge = "СТАРТ",
        oneTime = true,
        kind = "bundle",
        desc = "Идеальный старт — монеты, буст и питомцы",
        perks = { "25 000 монет", "x2 монеты · 30 мин", "3 яйца" },
        rewards = {
            { kind = "coins", amount = 25000 },
            { kind = "boost", boostKind = "coins", multiplier = 2, durationSec = 1800 },
            { kind = "eggs", amount = 3 },
        },
    },
    bundleMiner = {
        key = "bundleMiner",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Набор шахтёра",
        icon = "pack_miner",
        priceRobux = 349,
        wasPriceRobux = 699,
        badge = "-50%",
        kind = "bundle",
        desc = "Монеты, удача и яйца в одном пакете",
        perks = { "50 000 монет", "x2 удача · 15 мин", "5 яиц" },
        rewards = {
            { kind = "coins", amount = 50000 },
            { kind = "boost", boostKind = "luck", multiplier = 2, durationSec = 900 },
            { kind = "eggs", amount = 5 },
        },
    },
    bundleMega = {
        key = "bundleMega",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Мега набор",
        icon = "pack_mega",
        priceRobux = 799,
        wasPriceRobux = 1599,
        badge = "ХИТ",
        kind = "bundle",
        desc = "Максимум прогресса за одну покупку",
        perks = { "250 000 монет", "x2 монеты · 1 ч", "x2 сила · 30 мин", "15 яиц" },
        rewards = {
            { kind = "coins", amount = 250000 },
            { kind = "boost", boostKind = "coins", multiplier = 2, durationSec = 3600 },
            { kind = "boost", boostKind = "damage", multiplier = 2, durationSec = 1800 },
            { kind = "eggs", amount = 15 },
        },
    },
    boostLuck15 = {
        key = "boostLuck15",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Удача x2",
        icon = "buff_luck",
        priceRobux = 49,
        kind = "boost",
        boostKind = "luck",
        multiplier = 2,
        durationSec = 900,
		desc = "15 мин · больше редкой руды и комнат",
    },
    boostLuck60 = {
        key = "boostLuck60",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Удача x2",
        icon = "buff_luck",
        priceRobux = 149,
        wasPriceRobux = 196,
        kind = "boost",
        boostKind = "luck",
        multiplier = 2,
        durationSec = 3600,
        desc = "1 час · максимум редких находок",
    },
    boostCoins15 = {
        key = "boostCoins15",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Монеты x2",
        icon = "buff_coin",
        priceRobux = 49,
        kind = "boost",
        boostKind = "coins",
        multiplier = 2,
        durationSec = 900,
        desc = "15 мин · удвоенная продажа",
    },
    boostCoins60 = {
        key = "boostCoins60",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Монеты x2",
        icon = "buff_coin",
        priceRobux = 149,
        wasPriceRobux = 196,
        kind = "boost",
        boostKind = "coins",
        multiplier = 2,
        durationSec = 3600,
        desc = "1 час · фарм без остановки",
    },
    boostDamage15 = {
        key = "boostDamage15",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Сила x2",
        icon = "buff_damage",
        priceRobux = 59,
        kind = "boost",
        boostKind = "damage",
        multiplier = 2,
        durationSec = 900,
        desc = "15 мин · вдвое больше урона",
    },
    boostSpeed15 = {
        key = "boostSpeed15",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Скорость x2",
        icon = "upg_speed",
        priceRobux = 59,
        kind = "boost",
        boostKind = "speed",
        multiplier = 2,
        durationSec = 900,
        desc = "15 мин · копай в два раза быстрее",
    },
    coinsSmall = {
        key = "coinsSmall",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Малый пакет",
        icon = "coin",
        priceRobux = 99,
        wasPriceRobux = 149,
        kind = "coins",
        amount = 10000,
        desc = "+10 000 монет",
    },
    coinsMedium = {
        key = "coinsMedium",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Средний пакет",
        icon = "coin",
        priceRobux = 399,
        wasPriceRobux = 599,
        kind = "coins",
        amount = 100000,
        desc = "+100 000 монет",
    },
    coinsLarge = {
        key = "coinsLarge",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Большой пакет",
        icon = "coin",
        priceRobux = 899,
        wasPriceRobux = 1499,
        badge = "-40%",
        kind = "coins",
        amount = 500000,
        desc = "+500 000 монет",
    },
    coinsMega = {
        key = "coinsMega",
        id = 0, -- TODO: paste Creator Hub ID
        name = "Мега пакет",
        icon = "coin",
        priceRobux = 2499,
        wasPriceRobux = 4999,
        badge = "ХИТ",
        kind = "coins",
        amount = 2000000,
        desc = "+2 000 000 монет",
    },
    egg5 = {
        key = "egg5",
        id = 0, -- TODO: paste Creator Hub ID
        name = "5 яиц",
        icon = "icon_egg",
        priceRobux = 99,
        kind = "eggs",
        amount = 5,
        desc = "5 вылуплений подряд",
    },
    egg10 = {
        key = "egg10",
        id = 0, -- TODO: paste Creator Hub ID
        name = "10 яиц",
        icon = "icon_egg",
        priceRobux = 199,
        wasPriceRobux = 249,
        kind = "eggs",
        amount = 10,
        desc = "10 яиц сразу",
    },
    egg25 = {
        key = "egg25",
        id = 0, -- TODO: paste Creator Hub ID
        name = "25 яиц",
        icon = "icon_egg",
        priceRobux = 399,
        wasPriceRobux = 598,
        badge = "-33%",
        kind = "eggs",
        amount = 25,
        desc = "25 яиц — шанс на легенду",
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

-- Соц-награда: вступление в группу + добавление игры в избранное.
-- groupId / universeId — заменить после публикации (Creator Hub).
-- Избранное сервером не проверяется (Roblox API); клиент подтверждает
-- через ConfirmSocialFavorite после PromptSetFavorite.
Constants.SOCIAL_REWARD = {
    groupId = 0, -- TODO: paste Creator Hub group ID
    universeId = 0, -- TODO: paste universe ID (не placeId!)
    rewards = {
        coins = 7500,
        gems = 15,
        boost = { kind = "coins", multiplier = 2, durationSec = 900 },
    },
}

-- Обратная совместимость: профиль слоёв живёт в data/LayerProfile.lua.
local LayerProfile = require(script.Parent.data.LayerProfile)
Constants.LAYER_PROFILE = LayerProfile.IDENTITY
Constants.LAYER_BLOCK_GLOW = LayerProfile.BLOCK_GLOW

return Constants
