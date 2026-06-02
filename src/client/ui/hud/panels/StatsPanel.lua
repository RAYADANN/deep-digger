--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local StatRow = require(script.Parent.Parent.components.StatRow)
local LeaderboardLogic = require(ReplicatedStorage:WaitForChild("shared").util.LeaderboardLogic)

local Children = Fusion.Children
local C = theme.C

local StatsPanel = {}

function StatsPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("ScrollingFrame")({
        Name = "Stats",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "stats"
        end),
        [Children] = {
            s:New("UIPadding")({
                PaddingTop = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
            }),
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 8),
            }),
            StatRow.create(s, {
                label = "⬇ Макс. глубина",
                valueText = s:Computed(function(use)
                    return math.floor(use(state.statMaxDepth)) .. " м"
                end),
                valueColor = C.depthFill,
            }),
            StatRow.create(s, {
                label = "⛏ Блоков сломано",
                valueText = s:Computed(function(use)
                    return Formatters.shortNumber(use(state.statBlocksMined))
                end),
            }),
            StatRow.create(s, {
                label = "💰 Монет заработано",
                valueText = s:Computed(function(use)
                    -- Phase 8: count-up через statTotalCoinsDisplay.
                    return Formatters.shortNumber(use(state.statTotalCoinsDisplay))
                end),
            }),
            StatRow.create(s, {
                label = "🏆 Боссов убито",
                valueText = s:Computed(function(use)
                    return tostring(use(state.statBossesDefeated))
                end),
                valueColor = C.mythic,
            }),
            -- Phase 9: prestige-блок. Множитель — дискретный (меняется на
            -- 0.1 за каждый ребёрт), tween не нужен — иначе игрок не
            -- поверит, что цифра «защёлкнулась».
            StatRow.create(s, {
                label = "💠 Ребёрты",
                valueText = s:Computed(function(use)
                    return tostring(math.floor(use(state.rebirths) or 0))
                end),
                valueColor = C.gold,
            }),
            StatRow.create(s, {
                label = "✨ Множитель к ценам руд",
                valueText = s:Computed(function(use)
                    return ("x%.1f"):format(use(state.rebirthMultiplier) or 1)
                end),
                valueColor = C.gold,
            }),
            -- Phase 10: daily streak + leaderboard ранки.
            StatRow.create(s, {
                label = "🔥 Стрик дней",
                valueText = s:Computed(function(use)
                    local streak = math.floor(use(state.dailyStreak) or 0)
                    local total = math.floor(use(state.dailyTotalClaimed) or 0)
                    return ("%d (всего %d)"):format(streak, total)
                end),
                valueColor = Color3.fromRGB(255, 180, 90),
            }),
            StatRow.create(s, {
                label = "🏆 Ранг (монеты)",
                valueText = s:Computed(function(use)
                    local placement = use(state.leaderboardPlacement) or {}
                    return LeaderboardLogic.formatRank(placement.coinsRank)
                end),
                valueColor = C.gold,
            }),
            StatRow.create(s, {
                label = "🏆 Ранг (глубина)",
                valueText = s:Computed(function(use)
                    local placement = use(state.leaderboardPlacement) or {}
                    return LeaderboardLogic.formatRank(placement.depthRank)
                end),
                valueColor = C.gold,
            }),
        },
    })
end

return StatsPanel
