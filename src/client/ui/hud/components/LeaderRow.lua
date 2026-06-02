--!strict
-- LeaderRow.lua — Phase 10.
--
-- Одна строка глобального лидерборда. Используется LeaderboardPanel
-- через UIListLayout. Содержит:
--   * rank "#42" с короной 👑 для top-1,
--   * avatar (Players:GetUserThumbnailAsync, кэш в module-level table),
--   * имя игрока,
--   * formatted value (12.5K / 127 м).
--
-- Highlights:
--   * Если userId == LocalPlayer.UserId — золотой UIStroke + bold имя
--     («это вы»).
--   * Top-1 не рендерится здесь — для него отдельный spotlight (в Panel).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local LeaderboardLogic = require(ReplicatedStorage:WaitForChild("shared").util.LeaderboardLogic)

local Children = Fusion.Children
local C = theme.C

-- Кэш `userId → asset content URL` для avatar'ов. GetUserThumbnailAsync —
-- rate-limited (~50 req/min/server), повторять для каждого refresh'a
-- лидерборда (раз в 30с) — антипаттерн. Запись живёт до перезахода сервера.
local _thumbCache: { [number]: string } = {}
-- Запросы in-flight: если уже идёт fetch — не плодим параллельные task.spawn.
local _thumbFetching: { [number]: boolean } = {}

local function resolveThumbnail(userId: number, onReady: (url: string) -> ())
    local cached = _thumbCache[userId]
    if cached then
        onReady(cached)
        return
    end
    if _thumbFetching[userId] then
        return
    end
    _thumbFetching[userId] = true
    task.spawn(function()
        local ok, content = pcall(function()
            -- HeadShot + 150x150 — баланс качества и скорости.
            local url, _isReady = Players:GetUserThumbnailAsync(
                userId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
            return url
        end)
        _thumbFetching[userId] = nil
        if ok and typeof(content) == "string" then
            _thumbCache[userId] = content
            onReady(content)
        end
    end)
end

export type Entry = {
    userId: number,
    name: string,
    value: number,
    rank: number,
}

export type Props = {
    entry: Entry,
    boardId: string,
    isLocalPlayer: boolean?,
}

local LeaderRow = {}

function LeaderRow.create(s: ScopeFactory.HudScope, props: Props)
    local entry = props.entry
    local isLocal = props.isLocalPlayer or false
    -- Async avatar: показываем skeleton (серый круг) пока грузится.
    local avatarImage = s:Value("")
    resolveThumbnail(entry.userId, function(url)
        -- Защита: scope мог быть уже destroyed (HUD destroyed во время fetch'a).
        local ok = pcall(function()
            avatarImage:set(url)
        end)
        if not ok then return end
    end)

    local crown = LeaderboardLogic.crownForRank(entry.rank)
    local nameText = if crown then crown .. " " .. entry.name else entry.name

    return s:New("Frame")({
        Name = "LeaderRow_" .. tostring(entry.rank),
        Size = UDim2.new(1, -8, 0, 44),
        BackgroundColor3 = if isLocal then C.goldBg else C.btnBg,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
            s:New("UIStroke")({
                Color = if isLocal then C.gold else C.btnBorder,
                Thickness = if isLocal then 1.8 else 1,
                Transparency = 0.4,
            }),
            -- Rank.
            s:New("TextLabel")({
                Size = UDim2.new(0, 44, 1, 0),
                Position = UDim2.new(0, 4, 0, 0),
                BackgroundTransparency = 1,
                Text = LeaderboardLogic.formatRank(entry.rank),
                TextSize = 14,
                Font = Enum.Font.GothamBold,
                TextColor3 = if entry.rank <= 3 then C.gold else C.textMuted,
                TextXAlignment = Enum.TextXAlignment.Center,
            }),
            -- Avatar (32x32 круг).
            s:New("Frame")({
                Size = UDim2.fromOffset(32, 32),
                Position = UDim2.new(0, 52, 0.5, -16),
                BackgroundColor3 = Color3.fromRGB(40, 40, 60),
                BorderSizePixel = 0,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
                    s:New("UIStroke")({
                        Color = if isLocal then C.gold else C.tabBorder,
                        Thickness = 1.2,
                        Transparency = 0.5,
                    }),
                    s:New("ImageLabel")({
                        Size = UDim2.fromScale(1, 1),
                        BackgroundTransparency = 1,
                        Image = avatarImage,
                        ImageTransparency = s:Computed(function(use)
                            -- Fade-in: skeleton-серый круг видно, пока Image=""
                            return if use(avatarImage) == "" then 1 else 0
                        end),
                        [Children] = {
                            s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
                        },
                    }),
                },
            }),
            -- Name.
            s:New("TextLabel")({
                Size = UDim2.new(1, -160, 1, 0),
                Position = UDim2.new(0, 92, 0, 0),
                BackgroundTransparency = 1,
                Text = nameText,
                TextSize = 13,
                Font = if isLocal then Enum.Font.GothamBlack else Enum.Font.GothamBold,
                TextColor3 = if isLocal then C.gold else C.textMain,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),
            -- Value.
            s:New("TextLabel")({
                Size = UDim2.new(0, 100, 1, 0),
                Position = UDim2.new(1, -108, 0, 0),
                BackgroundTransparency = 1,
                Text = LeaderboardLogic.formatValue(props.boardId :: any, entry.value),
                TextSize = 14,
                Font = Enum.Font.GothamBlack,
                TextColor3 = C.gold,
                TextXAlignment = Enum.TextXAlignment.Right,
            }),
        },
    })
end

return LeaderRow
