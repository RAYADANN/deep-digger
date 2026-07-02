--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local StatRow = require(script.Parent.Parent.components.StatRow)
local PanelScale = require(script.Parent.Parent.PanelScale)
local LeaderboardLogic = require(ReplicatedStorage:WaitForChild("shared").util.LeaderboardLogic)
local RebirthLogic = require(ReplicatedStorage:WaitForChild("shared").util.RebirthLogic)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local Notification = require(script.Parent.Parent.Parent.Notification)
local SoundManager = require(script.Parent.Parent.Parent.Parent.core.SoundManager)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text

local StatsPanel = {}

-- P2.10: телепорт к началу уже открытого слоя (server-authoritative).
local function tryWarp(layerId: string, isBusy: any)
    if peek(isBusy) then
        return
    end
    isBusy:set(true)
    SoundManager.play("ui_click")
    task.spawn(function()
        local ok, result = pcall(function()
            return Net:Invoke("TeleportLayer", layerId)
        end)
        isBusy:set(false)
        if ok and typeof(result) == "table" and result.success then
            SoundManager.play("sell_success")
            return
        end
        SoundManager.play("buy_fail")
        local msg = if typeof(result) == "table" and result.message then result.message else "Не удалось переместиться"
        Notification.show({ text = msg, icon = "depth", color = Color3.fromRGB(255, 140, 60), duration = 2.5 })
    end)
end

local function warpButton(s: ScopeFactory.HudScope, state: HudStateModule.HudState, layer: any, order: number, isBusy: any): Instance
    local unlocked = s:Computed(function(use)
        return (use(state.statMaxDepth) or 0) >= (layer.depthStart or 0)
    end)
    local hovering = s:Value(false)
    return s:New("TextButton")({
        Name = "Warp_" .. tostring(layer.id),
        Size = UDim2.new(1, 0, 0, sc(34)),
        LayoutOrder = order,
        AutoButtonColor = false,
        BackgroundColor3 = s:Computed(function(use)
            if not use(unlocked) then
                return C.btnDisabled
            end
            return if use(hovering) then C.bg3 else C.btnBg
        end),
        BackgroundTransparency = s:Computed(function(use)
            return if use(unlocked) then 0 else 0.3
        end),
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 2,
        [OnEvent("MouseEnter")] = function()
            hovering:set(true)
        end,
        [OnEvent("MouseLeave")] = function()
            hovering:set(false)
        end,
        [OnEvent("Activated")] = function()
            if peek(unlocked) then
                tryWarp(layer.id, isBusy)
            else
                SoundManager.play("buy_fail")
            end
        end,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
            s:New("UIStroke")({
                Color = s:Computed(function(use)
                    return if use(unlocked) then C.depthFill else C.dockBorder
                end),
                Thickness = sc(1),
                Transparency = 0.45,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -sc(20), 1, 0),
                Position = UDim2.new(0, sc(10), 0, 0),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local name = layer.name or layer.id
                    if use(unlocked) then
                        return ("%s  ·  %d м"):format(name, layer.depthStart or 0)
                    end
                    return ("%s  ·  %d м (закрыто)"):format(name, layer.depthStart or 0)
                end),
                TextSize = text(13),
                Font = Enum.Font.GothamBold,
                TextColor3 = s:Computed(function(use)
                    return if use(unlocked) then C.textMain else C.textMuted
                end),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 3,
            }),
        },
    })
end

function StatsPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    local warpBusy = s:Value(false)
    return s:New("ScrollingFrame")({
        Name = "Stats",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = PanelScale.scrollBar(),
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "stats"
        end),
        [Children] = {
            s:New("UIPadding")({
                PaddingTop = PanelScale.pad(4),
                PaddingLeft = PanelScale.pad(4),
                PaddingRight = PanelScale.pad(4),
            }),
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Vertical,
                Padding = PanelScale.pad(8),
            }),
            StatRow.create(s, {
                iconSource = "depth",
                label = "Макс. глубина",
                valueText = s:Computed(function(use)
                    return math.floor(use(state.statMaxDepth)) .. " м"
                end),
                valueColor = C.depthFill,
            }),
            StatRow.create(s, {
                iconSource = "upg_pickaxe",
                label = "Блоков сломано",
                valueText = s:Computed(function(use)
                    return Formatters.shortNumber(use(state.statBlocksMined))
                end),
            }),
            StatRow.create(s, {
                iconSource = "coin",
                label = "Монет заработано",
                valueText = s:Computed(function(use)
                    return Formatters.shortNumber(use(state.statTotalCoinsDisplay))
                end),
            }),
            StatRow.create(s, {
                iconSource = "icon_boss",
                label = "Боссов убито",
                valueText = s:Computed(function(use)
                    return tostring(use(state.statBossesDefeated))
                end),
                valueColor = C.mythic,
            }),
            StatRow.create(s, {
                iconSource = "tab_rebirth",
                label = "Ребёрты",
                valueText = s:Computed(function(use)
                    return tostring(math.floor(use(state.rebirths) or 0))
                end),
                valueColor = C.gold,
            }),
            StatRow.create(s, {
                iconSource = "icon_sparkle",
                label = "Множитель к ценам руд",
                valueText = s:Computed(function(use)
                    return RebirthLogic.formatMultiplier(use(state.rebirthMultiplier) or 1)
                end),
                valueColor = C.gold,
            }),
            StatRow.create(s, {
                iconSource = "icon_streak",
                label = "Стрик дней",
                valueText = s:Computed(function(use)
                    local streak = math.floor(use(state.dailyStreak) or 0)
                    local total = math.floor(use(state.dailyTotalClaimed) or 0)
                    return ("%d (всего %d)"):format(streak, total)
                end),
                valueColor = Color3.fromRGB(255, 180, 90),
            }),
            StatRow.create(s, {
                iconSource = "coin",
                label = "Ранг (монеты)",
                valueText = s:Computed(function(use)
                    local placement = use(state.leaderboardPlacement) or {}
                    return LeaderboardLogic.formatRank(placement.coinsRank)
                end),
                valueColor = C.gold,
            }),
            StatRow.create(s, {
                iconSource = "depth",
                label = "Ранг (глубина)",
                valueText = s:Computed(function(use)
                    local placement = use(state.leaderboardPlacement) or {}
                    return LeaderboardLogic.formatRank(placement.depthRank)
                end),
                valueColor = C.gold,
            }),
            -- P2.10: быстрый спуск к открытым слоям.
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, sc(18)),
                BackgroundTransparency = 1,
                Text = "БЫСТРЫЙ СПУСК",
                TextSize = text(11),
                Font = theme.FONT.title,
                TextColor3 = C.textSub,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }),
            s:New("Frame")({
                Name = "WarpList",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                [Children] = {
                    s:New("UIListLayout")({
                        FillDirection = Enum.FillDirection.Vertical,
                        Padding = PanelScale.pad(6),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    s:Computed(function(_use)
                        local rows = {}
                        for i, layer in ipairs(Constants.LAYERS or {}) do
                            rows[#rows + 1] = warpButton(s, state, layer, i, warpBusy)
                        end
                        return rows
                    end),
                },
            }),
        },
    })
end

return StatsPanel
