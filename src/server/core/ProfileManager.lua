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

-- Структура данных игрока по умолчанию
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
    shaftsFound = {},
    playTime = 0,
    lastSave = 0,
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
