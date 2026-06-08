--!strict
-- ProfileManager.lua — универсальный менеджер профилей для Roblox.
-- 
-- Можно перенести в любой проект:
--   1. Заменить TEMPLATE на свою структуру данных
--   2. Всё остальное — готовый DataStore менеджмент
--
-- Использует ProfileService (loleris) под капотом.
-- Автосохранение, кэширование, lock при загрузке.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)

local ProfileService = require(modules.ProfileService)

local ProfileManager = {}
ProfileManager.__index = ProfileManager

-- Типы
export type PlayerProfile = {
    data: PlayerData,
    meta: {
        userId: number,
        loadTime: number,
        lastSave: number,
    },
    release: () -> (),
    save: () -> (),
    listenToRelease: (callback: (savedData: PlayerData?) -> ()) -> (),
}

-- Структура данных игрока по умолчанию.
-- ProfileService мерджит новые поля в старые профили автоматически: при
-- добавлении полей (tutorialStep, firstSession в Phase 8) старые сейвы
-- получают дефолты. Миграцию «опытный игрок не должен видеть туториал»
-- делает TutorialManager на основе totalBlocksMined / totalCoinsEarned.
local DEFAULT_DATA = {
    depth = 0,
    layer = "dirt",
    coins = 0,
    gems = 0,
    pickaxeLevel = 1,
    speedLevel = 1,
    fortuneLevel = 1,
    inventoryLevel = 1,
    critLevel = 1,
    multiSellLevel = 1,
    autoSellUnlocked = false,
    inventory = {},
    totalBlocksMined = 0,
    totalCoinsEarned = 0,
    bossesDefeated = 0,
    maxDepthReached = 0,
    shaftsFound = {},
    -- Счётчик найденных скрытых комнат (для достижения shaft_finder).
    shaftRoomCount = 0,
    playTime = 0,
    lastSave = 0,
    -- Phase 8: онбординг.
    -- tutorialStep: 0 = не начат, 1 = после первого клика, 2 = после первой
    -- продажи, 3 = completed (не показывать туториал).
    -- firstSession: true до первой выдачи STARTER_COINS, потом false навсегда —
    -- защита от двойного начисления стартового бонуса.
    tutorialStep = 0,
    firstSession = true,
    -- Phase 9 (rebirth / prestige).
    -- rebirths: количество совершённых ребёртов (увеличивается на 1 в
    --   RebirthManager после успешного сброса прогресса).
    -- rebirthMultiplier: денормализованный кэш = 1 + rebirths * 0.1.
    --   Лежит в профиле, чтобы SellInventory не считал формулу на каждой
    --   продаже. Пересчитывается в RebirthManager:onProfileLoaded (на
    --   случай ручной правки сейва или несоответствия).
    rebirths = 0,
    rebirthMultiplier = 1.0,
    -- Phase 10 (Daily reward + Leaderboard).
    -- dailyState: трекинг ежедневной награды.
    --   lastClaimYday/lastClaimYear: 0/0 у новичка — DailyLogic.canClaim
    --     вернёт true сразу при заходе, модал откроется автоматически.
    --   currentStreak: 0..7. После Day 7 → обнуляется в 0, следующий claim
    --     становится Day 1 (DailyLogic.streakToCycleDay).
    --   totalDaysClaimed: pure-статистика.
    dailyState = {
        lastClaimYday = 0,
        lastClaimYear = 0,
        currentStreak = 0,
        totalDaysClaimed = 0,
    },
    -- activeBoosts: temporary multipliers (выдаются Day 4/6/7 + dev /boost).
    --   Истёкшие boost'ы чистятся PlayerBoosts.cleanup на onProfileLoaded и
    --   на каждой продаже в SellInventory. expiresAt — os.time() unix.
    activeBoosts = {},
    -- leaderboardPlacement: кэш ранга игрока (обновляется LeaderboardManager).
    --   coinsRank/depthRank: nil если игрок не в top-50.
    --   coinsValue/depthValue: последнее значение, записанное в MemoryStore.
    --     Используется для throttling: пишем только если delta >= writeThreshold.
    leaderboardPlacement = {
        coinsRank = nil,
        depthRank = nil,
        coinsValue = 0,
        depthValue = 0,
    },
    -- Phase 11 (Pets MVP).
    --   pets: список { uid, petId }. Пустой у новичка.
    --   equippedPet: uid экипированного пета (nil = ничего не экипировано).
    --     ProfileService не хранит nil в таблице, поэтому поле может
    --     отсутствовать в старых сейвах — PetManager:onProfileLoaded
    --     гарантирует его наличие. Template-мердж добавит pets={} и
    --     petUidCounter=0 старым профилям без отдельной миграции.
    --   petUidCounter: монотонный счётчик для uid'ов новых петов.
    pets = {},
    equippedPet = nil,
    petUidCounter = 0,
    -- Phase 12 (Монетизация).
    --   gamepasses: кэш владения по key (vip / autoSell / petSlots). Source of
    --     truth — MarketplaceService:UserOwnsGamePassAsync; MonetizationManager
    --     синкает на onProfileLoaded и на PromptGamePassPurchaseFinished.
    --     Template-мердж добавит {} старым профилям без миграции.
    gamepasses = {},
    -- Phase 13 (Ore Discovery Index — журнал находок).
    --   discoveredOres: { [oreId] = true } — найденные руды. Переживает ребёрт
    --     (коллекция-история). Template-мердж добавит {} старым профилям;
    --     DiscoveryManager:onProfileLoaded бэкфилит руды из текущего инвентаря.
    --   discoveredMilestones: { [layerId] = true } — выданные награды за слой.
    discoveredOres = {},
    discoveredMilestones = {},
    -- Цели / квесты: claimedQuests[id]=true после получения награды.
    claimedQuests = {},
    -- Достижения: unlockedAchievements[id]=true.
    unlockedAchievements = {},
}

-- Создать ProfileStore
local ProfileStore = ProfileService.GetProfileStore("PlayerData_v1", DEFAULT_DATA)

function ProfileManager.new()
    local self = setmetatable({}, ProfileManager)
    self._log = Logger.new("ProfileManager")
    self._profiles = {}        -- [userId] -> PlayerProfile
    self._playerToProfile = {}  -- [Player] -> PlayerProfile
    self._log:info("ProfileManager initialized")
    return self
end

--[[
    Загрузить профиль игрока.
    Вызывается при PlayerAdded.
]]
function ProfileManager:loadProfile(player: Player)
    local userId = player.UserId
    self._log:info("Loading profile for", userId)

    local ok, profile = pcall(function()
        return ProfileStore:LoadProfileAsync("player_" .. userId)
    end)

    if not ok or not profile then
        self._log:error("Failed to load profile for", userId)
        player:Kick("Failed to load profile. Please rejoin.")
        return nil
    end

    -- Авто-релиз при выходе
    profile:ListenToRelease(function()
        self._profiles[userId] = nil
        self._playerToProfile[player] = nil
        self._log:info("Profile released for", userId)
    end)

    -- Инициализация
    profile.Data.lastSave = os.time()

    self._profiles[userId] = profile
    self._playerToProfile[player] = profile

    self._log:info("Profile loaded for", userId, "- Coins:", profile.Data.coins)
    return profile
end

--[[
    Получить данные профиля игрока.
]]
function ProfileManager:getData(player: Player): PlayerData?
    local profile = self._playerToProfile[player]
    if profile then
        return profile.Data
    end
    return nil
end

--[[
    Получить объект профиля (для ручного сохранения).
]]
function ProfileManager:getProfile(player: Player): PlayerProfile?
    return self._playerToProfile[player]
end

--[[
    Сохранить профиль.
    Автосохранение вызывается по таймеру.
]]
function ProfileManager:saveProfile(player: Player)
    local profile = self._playerToProfile[player]
    if not profile then
        return
    end

    profile.Data.lastSave = os.time()
    local ok, err = pcall(function()
        profile:Save()
    end)

    if ok then
        self._log:debug("Saved profile for", player.UserId)
    else
        self._log:warn("Save failed for", player.UserId, "-", err)
    end
end

--[[
    Сохранить все профили (вызывается при shutdown).
]]
function ProfileManager:saveAll()
    self._log:info("Saving all profiles...")
    for _, profile in pairs(self._profiles) do
        local ok, err = pcall(function()
            profile:Save()
        end)
        if not ok then
            self._log:warn("Save failed:", err)
        end
    end
end

return ProfileManager
