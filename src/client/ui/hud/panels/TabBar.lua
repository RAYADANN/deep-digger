--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local TabBtn = require(script.Parent.Parent.components.TabBtn)

local Children = Fusion.Children

local TabBar = {}

function TabBar.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    -- Phase 13: 8-й таб 📖 ЖУРНАЛ (retention — коллекция руд).
    -- Phase 16: 9-й таб 🎯 ЦЕЛИ (квесты + достижения).
    -- 9 * 58 + 8 * 6 = 570.
    return s:New("Frame")({
        Size = UDim2.new(0, 570, 0, 72),
        Position = UDim2.new(0, 8, 1, -80),
        BackgroundTransparency = 1,
        [Children] = {
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 6),
                VerticalAlignment = Enum.VerticalAlignment.Center,
            }),
            TabBtn.create(s, {
                icon = "tab_inventory",
                label = "ИНВЕНТ",
                tabId = "inventory",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
            TabBtn.create(s, {
                icon = "tab_upgrades",
                label = "АПГРЕЙД",
                tabId = "upgrades",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
            TabBtn.create(s, {
                icon = "tab_stats",
                label = "СТАТЫ",
                tabId = "stats",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
            -- Phase 9: prestige-таб. Имя кнопки `Tab_rebirth` следует
            -- конвенции Phase 8 — на случай если Tutorial.lua вырастит
            -- 4-й шаг «попробуй ребёрт» в будущем.
            TabBtn.create(s, {
                icon = "tab_rebirth",
                label = "РЕБЁРТ",
                tabId = "rebirth",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
            -- Phase 10: глобальный лидерборд. 5-й таб — конечная точка
            -- TabBar в MVP-scope. Tab_leaderboard используется
            -- LeaderboardPanel.create как activeTab filter.
            TabBtn.create(s, {
                icon = "tab_leaderboard",
                label = "ЛИДЕРЫ",
                tabId = "leaderboard",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
            -- Phase 11: pets. 6-й таб — жанро-определяющая механика.
            -- Tab_pets используется PetsPanel.create как activeTab filter.
            TabBtn.create(s, {
                icon = "tab_pets",
                label = "ПИТОМЦЫ",
                tabId = "pets",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
            -- Phase 12: монетизация. Tab_shop — ShopPanel filter.
            TabBtn.create(s, {
                icon = "tab_shop",
                label = "МАГАЗИН",
                tabId = "shop",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
            TabBtn.create(s, {
                icon = "tab_journal",
                label = "ЖУРНАЛ",
                tabId = "journal",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
            TabBtn.create(s, {
                icon = "tab_goals",
                label = "ЦЕЛИ",
                tabId = "goals",
                activeTab = state.activeTab,
                panelOpen = state.panelOpen,
            }),
        },
    })
end

return TabBar
