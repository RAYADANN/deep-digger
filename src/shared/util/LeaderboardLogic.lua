--!strict
-- LeaderboardLogic.lua — Phase 10.
--
-- Единственный источник формул лидерборда: score-приведение, форматтеры
-- ранка/значения, throttle-логика для записи в MemoryStore.
--
-- API:
--   LeaderboardLogic.toScore(value)                          -> number
--   LeaderboardLogic.formatRank(rank?)                       -> string  ("#42" | "—")
--   LeaderboardLogic.formatValue(boardId, value)             -> string  ("12.5K" | "127 м")
--   LeaderboardLogic.crownForRank(rank?)                     -> string?  ("👑" для #1)
--   LeaderboardLogic.shouldWrite(boardId, lastWritten, curr) -> boolean
--
-- Принципы:
--   * MemoryStoreSortedMap принимает только integer score → math.floor.
--   * Negative scores не поддерживаются (по сути), но totalCoinsEarned и
--     maxDepthReached неотрицательны — clamp до 0.
--   * Префикс "#" к рангу хардкоден в format: UI должен звать formatRank,
--     не делать tostring(rank).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local LeaderboardLogic = {}

export type BoardId = "coins" | "depth"

local function cfg()
    return Constants.LEADERBOARD or {}
end

-- Привести number → integer score для MemoryStoreSortedMap.
function LeaderboardLogic.toScore(value: number?): number
    local v = value or 0
    if v < 0 then
        v = 0
    end
    -- MemoryStore хранит integer. Используем math.floor; для очень больших
    -- значений (1e15+) теряется точность float64, но в нашем случае топ
    -- по coins ограничен ~1e12 (даже за 100 ребёртов через автосейл).
    return math.floor(v)
end

-- Форматирует rank. nil → "—".
function LeaderboardLogic.formatRank(rank: number?): string
    if not rank or rank <= 0 then
        return "—"
    end
    return ("#%d"):format(math.floor(rank))
end

-- Формат значения для UI. Coins использует short-number (12.5K),
-- depth — целое число + " м".
function LeaderboardLogic.formatValue(boardId: BoardId, value: number): string
    local n = math.floor(value or 0)
    if boardId == "depth" then
        return tostring(n) .. " м"
    end
    -- Coins: short-number с тысячниками.
    if n >= 1e9 then
        return ("%.1fB"):format(n / 1e9)
    elseif n >= 1e6 then
        return ("%.1fM"):format(n / 1e6)
    elseif n >= 1e3 then
        return ("%.1fK"):format(n / 1e3)
    end
    return tostring(n)
end

-- Корона для top-1. UI кладёт её слева от ника.
function LeaderboardLogic.crownForRank(rank: number?): string?
    if rank == 1 then
        return "👑"
    end
    return nil
end

-- Throttle: пишем в MemoryStore только если изменение значимое.
-- writeThresholdCoins = 100 → каждые 100 монет; writeThresholdDepth = 5 → каждые 5 м.
-- Без порога каждая продажа = SetAsync, что выжрет квоту MemoryStore.
function LeaderboardLogic.shouldWrite(boardId: BoardId, lastWritten: number?, current: number): boolean
    local last = lastWritten or 0
    local curr = current or 0
    if curr <= last then
        return false
    end
    local threshold
    if boardId == "depth" then
        threshold = cfg().writeThresholdDepth or 5
    else
        threshold = cfg().writeThresholdCoins or 100
    end
    return (curr - last) >= threshold
end

return LeaderboardLogic
