--!strict
-- LeaderboardPanel.lua — Phase 10.
--
-- Контент 5-го таба HUD. Глобальный лидерборд:
--   * Toggle «💰 Монеты» / «⬇ Глубина» сверху.
--   * Spotlight-карточка top-1 с короной 👑 и золотой обводкой.
--   * ScrollingFrame с top-2..top-50.
--   * Footer «Вы: #1247» если игрок не в top-50.
--   * Countdown «Обновится через Ns» справа сверху.
--   * Loading state: skeleton-плейсхолдеры.
--   * Error: «Сервис недоступен. Обновляем...»
--
-- Net:Function("RequestLeaderboard") дёргается раз в 30с пока панель видна.
-- При закрытии (activeTab != "leaderboard" или panelOpen == false) — стопаем.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local LeaderboardLogic = require(ReplicatedStorage:WaitForChild("shared").util.LeaderboardLogic)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local LeaderRow = require(script.Parent.Parent.components.LeaderRow)
local UiIcon = require(script.Parent.Parent.components.UiIcon)
local PanelScale = require(script.Parent.Parent.PanelScale)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text
local tsize = PanelScale.tsize

local LeaderboardPanel = {}

local LOCAL_USER_ID = Players.LocalPlayer.UserId
local REFRESH_INTERVAL = (Constants.LEADERBOARD or {}).refreshIntervalSeconds or 30

local function skeletonRow(s: ScopeFactory.HudScope, index: number)
    return s:New("Frame")({
        Name = "Skeleton_" .. index,
        Size = UDim2.new(1, -sc(8), 0, sc(44)),
        BackgroundColor3 = C.btnBg,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, sc(6)) }),
            -- Серый skeleton-круг под аватар.
            s:New("Frame")({
                Size = UDim2.fromOffset(sc(32), sc(32)),
                Position = UDim2.new(0, sc(52), 0.5, -sc(16)),
                BackgroundColor3 = Color3.fromRGB(60, 60, 90),
                BackgroundTransparency = 0.3,
                BorderSizePixel = 0,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
                },
            }),
            s:New("Frame")({
                Size = UDim2.new(0.5, 0, 0, sc(12)),
                Position = UDim2.new(0, sc(96), 0.5, -sc(6)),
                BackgroundColor3 = Color3.fromRGB(70, 70, 100),
                BackgroundTransparency = 0.4,
                BorderSizePixel = 0,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, sc(4)) }),
                },
            }),
        },
    })
end

--[[
    Spotlight для top-1. Большая карточка с короной, золотым stroke,
    pulse-анимация через s:Computed (Fusion не имеет тwen'a для UIStroke;
    делаем визуально статично, но с яркими цветами).
]]
local function spotlightCard(s: ScopeFactory.HudScope, entryValue: any, boardId: any)
    -- entryValue — Value<Entry?>
    return s:New("Frame")({
        Name = "Spotlight",
        -- Под хедером (header h=sc(32) + зазор sc(4)). Без явной позиции карточка
        -- ложилась в (0,0) и перекрывала хедер.
        Size = UDim2.new(1, -sc(8), 0, sc(72)),
        Position = UDim2.new(0, 0, 0, sc(36)),
        BackgroundColor3 = C.goldBg,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Visible = s:Computed(function(use)
            return use(entryValue) ~= nil
        end),
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, sc(10)) }),
            s:New("UIStroke")({ Color = C.gold, Thickness = sc(theme.STROKE.thick), Transparency = 0.1 }),
            -- Корона над всем рядом.
            UiIcon.titleRow(s, {
                source = "icon_crown",
                text = "#1 ВО ВСЁМ МИРЕ",
                textSize = sc(12),
                font = Enum.Font.GothamBlack,
                textColor = C.gold,
                size = UDim2.new(1, -sc(16), 0, sc(18)),
                position = UDim2.new(0, sc(8), 0, sc(6)),
                iconSize = sc(16),
            }),
            -- Имя + value.
            s:New("TextLabel")({
                Size = UDim2.new(1, -sc(16), 0, sc(22)),
                Position = UDim2.new(0, sc(8), 0, sc(26)),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local e = use(entryValue)
                    if not e then return "—" end
                    return e.name
                end),
                TextSize = tsize(18),
                Font = Enum.Font.GothamBlack,
                TextColor3 = C.textMain,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -sc(16), 0, sc(22)),
                Position = UDim2.new(0, sc(8), 0, sc(48)),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local e = use(entryValue)
                    if not e then return "" end
                    local id = use(boardId)
                    return LeaderboardLogic.formatValue(id, e.value)
                end),
                TextSize = tsize(16),
                Font = Enum.Font.GothamBold,
                TextColor3 = C.gold,
                TextXAlignment = Enum.TextXAlignment.Right,
            }),
        },
    })
end

local function toggleButton(s: ScopeFactory.HudScope, label: string, iconKey: string, id: string, currentBoardId: any)
    return s:New("TextButton")({
        Size = UDim2.new(0.5, -sc(4), 1, 0),
        BackgroundColor3 = s:Computed(function(use)
            return use(currentBoardId) == id and C.gem or C.btnBg
        end),
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, sc(6)) }),
            s:New("UIStroke")({
                Color = s:Computed(function(use)
                    return use(currentBoardId) == id and C.gem or C.btnBorder
                end),
                Thickness = sc(theme.STROKE.thin),
                Transparency = 0.4,
            }),
            s:New("ImageLabel")({
                Size = UDim2.fromOffset(sc(16), sc(16)),
                Position = UDim2.new(0.5, -sc(36), 0.5, -sc(8)),
                BackgroundTransparency = 1,
                Image = UiAssets.image(iconKey :: any),
                ScaleType = Enum.ScaleType.Fit,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -sc(40), 1, 0),
                Position = UDim2.new(0, sc(28), 0, 0),
                BackgroundTransparency = 1,
                Text = label,
                TextSize = text(13),
                Font = Enum.Font.GothamBold,
                TextColor3 = s:Computed(function(use)
                    return use(currentBoardId) == id and C.textMain or C.textLabel
                end),
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        },
        [OnEvent("Activated")] = function()
            currentBoardId:set(id)
        end,
    })
end

function LeaderboardPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    -- Локальный стейт: какой board выбран ("coins"|"depth").
    local boardId = s:Value("coins")
    -- Текущий snapshot обоих board'ов. nil → loading.
    local coinsSnapshot = s:Value(nil :: any)
    local depthSnapshot = s:Value(nil :: any)
    local errorText = s:Value(nil :: string?)
    local secondsUntilRefresh = s:Value(REFRESH_INTERVAL)
    local isFetching = s:Value(false)

    local function activeSnapshot()
        local id = peek(boardId)
        if id == "depth" then
            return peek(depthSnapshot)
        end
        return peek(coinsSnapshot)
    end

    -- Async-вызов Net. Любой failure — error-state.
    local function fetchLeaderboard()
        if peek(isFetching) then
            return
        end
        isFetching:set(true)
        task.spawn(function()
            local ok, result = pcall(function()
                return Net:Invoke("RequestLeaderboard")
            end)
            isFetching:set(false)
            if not ok or typeof(result) ~= "table" then
                errorText:set("Сервис недоступен. Обновляем...")
                return
            end
            errorText:set(nil)
            local function snap(board: any)
                if typeof(board) ~= "table" then
                    return { entries = {}, myRank = nil, loading = true, error = nil }
                end
                return board
            end
            coinsSnapshot:set(snap(result.coins))
            depthSnapshot:set(snap(result.depth))
            secondsUntilRefresh:set(REFRESH_INTERVAL)
        end)
    end

    -- Tick-loop: countdown + auto-refresh раз в REFRESH_INTERVAL пока вкладка
    -- активна. Heartbeat создаётся сразу — он лёгкий (1 проверка/сек) и
    -- автоматически gateит работу через panelOpen + activeTab.
    local lastTick = os.clock()
    local hasFetchedOnce = false
    local heartbeatConn: RBXScriptConnection? = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        local dt = now - lastTick
        if dt < 1 then return end
        lastTick = now
        local panelOpen = peek(state.panelOpen)
        local active = peek(state.activeTab)
        if not panelOpen or active ~= "leaderboard" then
            return
        end
        -- Первый показ вкладки — запускаем загрузку сразу.
        if not hasFetchedOnce then
            hasFetchedOnce = true
            fetchLeaderboard()
            return
        end
        local remaining = (peek(secondsUntilRefresh) or REFRESH_INTERVAL) - 1
        if remaining <= 0 then
            secondsUntilRefresh:set(REFRESH_INTERVAL)
            fetchLeaderboard()
        else
            secondsUntilRefresh:set(remaining)
        end
    end)

    local visible = s:Computed(function(use)
        return use(state.activeTab) == "leaderboard"
    end)

    -- Toggle между board'ами триггерит мгновенное переключение (данные уже
    -- лежат в обоих snapshot'ах).

    -- Список строк top-2..top-50. Computed от boardId + snapshot'a.
    -- Spotlight отрисовываем для top-1, остальные через UIListLayout.
    local function rowsFromSnapshot(use: any)
        local snapshot
        if use(boardId) == "depth" then
            snapshot = use(depthSnapshot)
        else
            snapshot = use(coinsSnapshot)
        end
        if not snapshot or typeof(snapshot.entries) ~= "table" then
            return {}
        end
        return snapshot.entries
    end

    local topOneEntry = s:Computed(function(use)
        local entries = rowsFromSnapshot(use)
        return entries[1]
    end)

    local restEntries = s:Computed(function(use)
        local entries = rowsFromSnapshot(use)
        local out = {}
        for i = 2, #entries do
            table.insert(out, entries[i])
        end
        return out
    end)

    local myRankValue = s:Computed(function(use)
        local snapshot
        if use(boardId) == "depth" then
            snapshot = use(depthSnapshot)
        else
            snapshot = use(coinsSnapshot)
        end
        if not snapshot then return nil end
        return snapshot.myRank
    end)

    local isLoading = s:Computed(function(use)
        local snapshot
        if use(boardId) == "depth" then
            snapshot = use(depthSnapshot)
        else
            snapshot = use(coinsSnapshot)
        end
        return snapshot == nil
    end)

    -- Регистрируем cleanup ДО построения Frame'а — scope-таблица уже
    -- готова. heartbeatConn disconnect'ится при разрушении HUD scope.
    if typeof(s) == "table" then
        table.insert(s, function()
            if heartbeatConn then
                heartbeatConn:Disconnect()
                heartbeatConn = nil
            end
        end)
    end

    return s:New("Frame")({
        Name = "Leaderboard",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = visible,
        [Children] = {
            s:New("UIPadding")({
                PaddingTop = PanelScale.pad(4),
                PaddingLeft = PanelScale.pad(4),
                PaddingRight = PanelScale.pad(4),
                PaddingBottom = PanelScale.pad(8),
            }),
            -- Header: toggle + countdown.
            s:New("Frame")({
                Name = "Header",
                Size = UDim2.new(1, -sc(8), 0, sc(32)),
                BackgroundTransparency = 1,
                [Children] = {
                    s:New("Frame")({
                        -- Toggle group.
                        Size = UDim2.new(0, sc(220), 1, 0),
                        Position = UDim2.new(0, 0, 0, 0),
                        BackgroundTransparency = 1,
                        [Children] = {
                            s:New("UIListLayout")({
                                FillDirection = Enum.FillDirection.Horizontal,
                                Padding = PanelScale.pad(8),
                                SortOrder = Enum.SortOrder.LayoutOrder,
                            }),
                            toggleButton(s, "Монеты", "coin", "coins", boardId),
                            toggleButton(s, "Глубина", "depth", "depth", boardId),
                        },
                    }),
                    -- Countdown.
                    s:New("TextLabel")({
                        Size = UDim2.new(0, sc(200), 1, 0),
                        Position = UDim2.new(1, -sc(200), 0, 0),
                        BackgroundTransparency = 1,
                        Text = s:Computed(function(use)
                            local err = use(errorText)
                            if err then return err end
                            local s2 = math.max(0, math.floor(use(secondsUntilRefresh) or 0))
                            return ("Обновится через %dс"):format(s2)
                        end),
                        TextSize = text(11),
                        Font = Enum.Font.Gotham,
                        TextColor3 = s:Computed(function(use)
                            return if use(errorText) then C.mythic else C.textMuted
                        end),
                        TextXAlignment = Enum.TextXAlignment.Right,
                    }),
                },
            }),
            -- Spotlight top-1.
            spotlightCard(s, topOneEntry, boardId),
            -- ScrollingFrame с остальными.
            s:New("ScrollingFrame")({
                Name = "Rows",
                Size = UDim2.new(1, -sc(8), 1, -sc(150)),
                Position = UDim2.new(0, 0, 0, sc(120)),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = PanelScale.scrollBar(),
                ScrollBarImageColor3 = C.panelBorder,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                [Children] = {
                    s:New("UIListLayout")({
                        FillDirection = Enum.FillDirection.Vertical,
                        Padding = PanelScale.pad(4),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    -- Dynamic rows. По паттерну InventoryPanel.lua — Computed
                    -- возвращает таблицу детей; Fusion пересоздаёт её при
                    -- изменении restEntries (snapshot обновился) или boardId
                    -- (переключение Монеты ↔ Глубина).
                    s:Computed(function(use)
                        local rows = {}
                        local id = use(boardId)
                        local entries = use(restEntries)
                        for _, entry in ipairs(entries) do
                            rows[#rows + 1] = LeaderRow.create(s, {
                                entry = entry,
                                boardId = id,
                                isLocalPlayer = entry.userId == LOCAL_USER_ID,
                            })
                        end
                        return rows
                    end),
                    -- Loading skeleton — рендерим если isLoading и нет ни одной строки.
                    s:New("Frame")({
                        Size = UDim2.new(1, -sc(8), 0, sc(200)),
                        BackgroundTransparency = 1,
                        Visible = s:Computed(function(use)
                            return use(isLoading)
                        end),
                        [Children] = {
                            s:New("UIListLayout")({
                                FillDirection = Enum.FillDirection.Vertical,
                                Padding = PanelScale.pad(4),
                            }),
                            skeletonRow(s, 1),
                            skeletonRow(s, 2),
                            skeletonRow(s, 3),
                            skeletonRow(s, 4),
                            skeletonRow(s, 5),
                        },
                    }),
                    -- Empty state.
                    s:New("Frame")({
                        Size = UDim2.new(1, -sc(8), 0, sc(60)),
                        BackgroundTransparency = 1,
                        Visible = s:Computed(function(use)
                            if use(isLoading) then return false end
                            local entries = rowsFromSnapshot(use)
                            return #entries == 0
                        end),
                        [Children] = {
                            UiIcon.titleRow(s, {
                                source = "tab_leaderboard",
                                text = "Будь первым в лидерборде!",
                                textSize = sc(14),
                                font = Enum.Font.GothamBold,
                                textColor = C.textLabel,
                                size = UDim2.new(1, 0, 1, 0),
                                iconSize = sc(18),
                            }),
                        },
                    }),
                },
            }),
            -- Footer: «Вы: #N» если игрок не в top-50.
            s:New("Frame")({
                Name = "MyRank",
                Size = UDim2.new(1, -sc(8), 0, sc(26)),
                Position = UDim2.new(0, 0, 1, -sc(30)),
                BackgroundColor3 = C.btnBg,
                BackgroundTransparency = 0.2,
                BorderSizePixel = 0,
                Visible = s:Computed(function(use)
                    -- Показываем только если myRank известен и больше topSize
                    -- (или если не нашли в snapshot — но при этом snapshot загружен).
                    local r = use(myRankValue)
                    if use(isLoading) then return false end
                    return r ~= nil
                end),
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, sc(6)) }),
                    s:New("UIStroke")({ Color = C.gold, Thickness = sc(theme.STROKE.thin), Transparency = 0.4 }),
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -sc(16), 1, 0),
                        Position = UDim2.new(0, sc(8), 0, 0),
                        BackgroundTransparency = 1,
                        Text = s:Computed(function(use)
                            local r = use(myRankValue)
                            if not r then return "Вы: вне топа" end
                            return ("Вы: %s"):format(LeaderboardLogic.formatRank(r))
                        end),
                        TextSize = text(13),
                        Font = Enum.Font.GothamBold,
                        TextColor3 = C.gold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }),
                },
            }),
        },
    })
end

return LeaderboardPanel
