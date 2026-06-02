--!strict
-- Leaderboard.lua — Phase 10.
--
-- Глобальный лидерборд по двум метрикам:
--   * totalCoinsEarned (board "coins")
--   * maxDepthReached  (board "depth")
--
-- Используем MemoryStoreSortedMap (НЕ DataStore, НЕ MemoryStoreQueue):
--   * SortedMap имеет встроенную сортировку — ровно то, что нужно для top-N.
--   * TTL автоматический (expirationSeconds в Constants.LEADERBOARD).
--   * Лимит чтения: 100 elements за GetRangeAsync. Берём 50.
--
-- API:
--   Leaderboard.new(deps)
--   Leaderboard:writeIfChanged(player)
--       — вызывается из EconomyManager.onEconomyChanged hook'а
--         (после продажи и после ребёрта). Throttle через
--         LeaderboardLogic.shouldWrite (delta >= writeThreshold).
--   Leaderboard:fetchTop(boardId): { Entry } | nil
--       — кэшируется на refreshIntervalSeconds. nil → ошибка MemoryStore.
--   Leaderboard:fetchPlayerRank(boardId, userId): number?
--       — линейный поиск в кэше. Если игрока нет в top-N — nil.
--   Net:Function("RequestLeaderboard")
--       — клиент дёргает раз в 30с (server throttle 5с/игрок).
--
-- Граничные кейсы:
--   * MemoryStore failure → fetchTop возвращает nil, UI рисует «загрузка».
--     В фоне retry с exp-backoff (2/4/8с).
--   * Имена игроков НЕ хранятся в map.value: лимит 64KB, UTF-8 issues.
--     Резолвим через Players:GetNameFromUserIdAsync + локальный кэш.
--   * Ключ map'а = "user_<userId>" (string), значение = score (integer).
--   * Sort order = Descending (топ-1 = максимум).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local Net = require(modules.Net)
local LeaderboardLogic = require(shared.util.LeaderboardLogic)

local Leaderboard = {}
Leaderboard.__index = Leaderboard

export type Entry = {
    userId: number,
    name: string,
    value: number,
    rank: number,
}

export type BoardSnapshot = {
    entries: { Entry },
    fetchedAt: number,
    error: string?,
}

export type Deps = {
    profileManager: any,
    onProfileChanged: ((player: Player) -> ())?,
}

-- Кэш имён игроков. GetNameFromUserIdAsync дорогой (rate-limited): ~2 запроса/сек
-- на сервер. После первого resolve'a имя живёт до перезапуска сервера.
local _nameCache: { [number]: string } = {}

-- Per-player throttle на Net:Function("RequestLeaderboard"): 5 секунд.
local _lastRequestAt: { [number]: number } = {}

local function getName(userId: number): string
    local cached = _nameCache[userId]
    if cached then
        return cached
    end
    -- Сначала пробуем найти online-игрока (без сетевого вызова).
    local online = Players:GetPlayerByUserId(userId)
    if online then
        _nameCache[userId] = online.Name
        return online.Name
    end
    local ok, name = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    if ok and typeof(name) == "string" then
        _nameCache[userId] = name
        return name
    end
    return "Player_" .. tostring(userId)
end

local function userKey(userId: number): string
    return "u" .. tostring(userId)
end

local function parseUserId(key: string): number?
    if typeof(key) ~= "string" then
        return nil
    end
    local id = key:match("^u(%d+)$")
    if id then
        return tonumber(id)
    end
    return nil
end

function Leaderboard.new(deps: Deps?)
    local self = setmetatable({}, Leaderboard)
    self._log = Logger.new("Leaderboard")
    self._profileManager = deps and deps.profileManager
    self._onProfileChanged = deps and deps.onProfileChanged

    local cfg = Constants.LEADERBOARD or {}
    -- Pcall на случай: некоторые сервера (особенно Studio в Team Test без
    -- DataModel privileges) могут крашнуть на GetSortedMap. Не валим init.
    local function safeGetMap(name: string)
        local ok, map = pcall(function()
            return MemoryStoreService:GetSortedMap(name)
        end)
        if ok and map then
            return map
        end
        self._log:warn("Failed to acquire MemoryStoreSortedMap:", name)
        return nil
    end
    self._coinsMap = safeGetMap(cfg.COINS_MAP or "Leaderboard_Coins_v1")
    self._depthMap = safeGetMap(cfg.DEPTH_MAP or "Leaderboard_Depth_v1")

    -- Кэш топ-N. nil = ещё не загружали. {} = пустой топ (валидное состояние).
    self._cache = {
        coins = nil :: BoardSnapshot?,
        depth = nil :: BoardSnapshot?,
    } :: any
    self._refreshing = { coins = false, depth = false }
    self._lastError = { coins = nil :: string?, depth = nil :: string? } :: any

    self:_registerNet()
    self:_startRefreshLoop()
    self._log:info("Leaderboard initialized (MemoryStoreSortedMap)")
    return self
end

function Leaderboard:_mapFor(boardId: string)
    if boardId == "depth" then
        return self._depthMap
    end
    return self._coinsMap
end

--[[
    Сырое чтение top-N из MemoryStore. Блокирующее. НЕ кэширует — это
    низкоуровневый helper для _refresh / fetchTop. Возвращает {entries, error}.
]]
function Leaderboard:_readTop(boardId: string): BoardSnapshot
    local map = self:_mapFor(boardId)
    if not map then
        return { entries = {}, fetchedAt = os.time(), error = "memorystore_unavailable" }
    end
    local cfg = Constants.LEADERBOARD or {}
    local topSize = math.min(100, cfg.topSize or 50)

    local ok, result = pcall(function()
        -- GetRangeAsync(direction, count, exclusiveLowerBound?)
        return map:GetRangeAsync(Enum.SortDirection.Descending, topSize)
    end)
    if not ok then
        self._log:warn("GetRangeAsync failed for", boardId, ":", result)
        return { entries = {}, fetchedAt = os.time(), error = tostring(result) }
    end

    local entries: { Entry } = {}
    if typeof(result) == "table" then
        for i, item in ipairs(result) do
            local key = item.key
            local value = item.value
            local userId = parseUserId(key)
            if userId and typeof(value) == "number" then
                table.insert(entries, {
                    userId = userId,
                    name = getName(userId),
                    value = math.floor(value),
                    rank = i,
                })
            end
        end
    end
    return { entries = entries, fetchedAt = os.time(), error = nil }
end

--[[
    Async refresh кэша. Не yield'ит вызывающего: ставит флаг _refreshing и
    запускается в отдельном task.spawn. Если уже идёт refresh — no-op.
]]
function Leaderboard:_refresh(boardId: string)
    if self._refreshing[boardId] then
        return
    end
    self._refreshing[boardId] = true
    task.spawn(function()
        local snapshot = self:_readTop(boardId)
        self._cache[boardId] = snapshot
        if snapshot.error then
            self._lastError[boardId] = snapshot.error
        else
            self._lastError[boardId] = nil
        end
        self._refreshing[boardId] = false
        -- Обновляем ранг для online-игроков (для leaderboardPlacement в HUD-payload).
        self:_updateOnlineRanks(boardId, snapshot)
    end)
end

function Leaderboard:_updateOnlineRanks(boardId: string, snapshot: BoardSnapshot)
    if not self._profileManager then
        return
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local data = self._profileManager:getData(player)
        if data then
            local placement = data.leaderboardPlacement
            if not placement then
                data.leaderboardPlacement = {
                    coinsRank = nil, depthRank = nil,
                    coinsValue = 0, depthValue = 0,
                }
                placement = data.leaderboardPlacement
            end
            local foundRank
            for _, entry in ipairs(snapshot.entries) do
                if entry.userId == player.UserId then
                    foundRank = entry.rank
                    break
                end
            end
            if boardId == "coins" then
                placement.coinsRank = foundRank
            elseif boardId == "depth" then
                placement.depthRank = foundRank
            end
        end
        if self._onProfileChanged then
            self._onProfileChanged(player)
        end
    end
end

function Leaderboard:_startRefreshLoop()
    local interval = (Constants.LEADERBOARD or {}).refreshIntervalSeconds or 30
    -- Стартуем оба board'a через короткую паузу — даём профилям успеть
    -- загрузиться у первых игроков.
    task.spawn(function()
        task.wait(3)
        while true do
            self:_refresh("coins")
            self:_refresh("depth")
            task.wait(interval)
        end
    end)
end

--[[
    Public API: вернуть текущий top из кэша.
    Если кэш ещё не прогрелся (первый запрос) — kicks refresh + возвращает nil.
    Клиент по nil рисует skeleton'ы.
]]
function Leaderboard:fetchTop(boardId: string): BoardSnapshot?
    local snapshot = self._cache[boardId]
    if not snapshot then
        self:_refresh(boardId)
        return nil
    end
    return snapshot
end

function Leaderboard:fetchPlayerRank(boardId: string, userId: number): number?
    local snapshot = self._cache[boardId]
    if not snapshot then
        return nil
    end
    for _, entry in ipairs(snapshot.entries) do
        if entry.userId == userId then
            return entry.rank
        end
    end
    return nil
end

--[[
    Записать score в MemoryStore. Проверка throttle через LeaderboardLogic.shouldWrite.
    Также читает placement.coinsRank/depthRank для UI.
]]
function Leaderboard:writeIfChanged(player: Player)
    if not self._profileManager then
        return
    end
    local data = self._profileManager:getData(player)
    if not data then
        return
    end
    if not data.leaderboardPlacement then
        data.leaderboardPlacement = {
            coinsRank = nil, depthRank = nil,
            coinsValue = 0, depthValue = 0,
        }
    end
    local placement = data.leaderboardPlacement
    local cfg = Constants.LEADERBOARD or {}
    local ttl = cfg.expirationSeconds or (60 * 60 * 24 * 30)

    local function writeOne(boardId: string, currentValue: number, lastWritten: number, map: any, valueField: string)
        if not map then
            return
        end
        if not LeaderboardLogic.shouldWrite(boardId, lastWritten, currentValue) then
            return
        end
        local score = LeaderboardLogic.toScore(currentValue)
        local userId = player.UserId
        local ok, err = pcall(function()
            -- SetAsync(key, value, expiration)
            map:SetAsync(userKey(userId), score, ttl)
        end)
        if ok then
            -- Обновляем кэш последнего записанного значения.
            placement[valueField] = currentValue
        else
            self._log:warn("MemoryStore SetAsync failed for", boardId, "user:", userId, "err:", err)
        end
    end

    writeOne("coins", data.totalCoinsEarned or 0, placement.coinsValue or 0, self._coinsMap, "coinsValue")
    writeOne("depth", data.maxDepthReached or 0, placement.depthValue or 0, self._depthMap, "depthValue")
end

function Leaderboard:_registerNet()
    local THROTTLE = 5
    Net:Handle("RequestLeaderboard", function(player: Player)
        local now = os.clock()
        local last = _lastRequestAt[player.UserId] or 0
        if now - last < THROTTLE then
            -- Просто отдаём текущий кэш (без forced refresh'а).
        else
            _lastRequestAt[player.UserId] = now
        end

        local coins = self._cache.coins
        local depth = self._cache.depth
        if not coins then
            self:_refresh("coins")
        end
        if not depth then
            self:_refresh("depth")
        end

        local function packSnapshot(snapshot: BoardSnapshot?, boardId: string)
            if not snapshot then
                return {
                    entries = {},
                    myRank = nil,
                    loading = true,
                    error = nil,
                }
            end
            local myRank = nil
            for _, entry in ipairs(snapshot.entries) do
                if entry.userId == player.UserId then
                    myRank = entry.rank
                    break
                end
            end
            return {
                entries = snapshot.entries,
                myRank = myRank,
                loading = false,
                error = snapshot.error,
            }
        end

        local refreshInterval = (Constants.LEADERBOARD or {}).refreshIntervalSeconds or 30
        local fetchedAt = (coins and coins.fetchedAt) or (depth and depth.fetchedAt) or os.time()
        return {
            coins = packSnapshot(coins, "coins"),
            depth = packSnapshot(depth, "depth"),
            nextRefreshAt = fetchedAt + refreshInterval,
            serverTime = os.time(),
        }
    end)
end

--[[
    Cleanup при выходе игрока: освобождаем per-player throttle-запись и
    делаем последний writeIfChanged, чтобы прогресс попал в leaderboard
    даже без активной продажи / ребёрта.
]]
function Leaderboard:onPlayerLeaving(player: Player)
    _lastRequestAt[player.UserId] = nil
    -- Финальная запись (не вынудительная — через shouldWrite, т.е. только
    -- если игрок прокачался с последней записи). MemoryStore SetAsync
    -- может yield'ить — оборачиваем pcall чтобы не валить leave handler.
    pcall(function()
        self:writeIfChanged(player)
    end)
end

return Leaderboard
