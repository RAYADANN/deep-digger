--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local InvSlot = require(script.Parent.Parent.components.InvSlot)
local PanelScale = require(script.Parent.Parent.PanelScale)

local Children = Fusion.Children
local C = theme.C
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc

local InventoryPanel = {}

function InventoryPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("ScrollingFrame")({
        Name = "Inventory",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = PanelScale.scrollBar(),
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "inventory"
        end),
        [Children] = {
            s:New("UIGridLayout")({
                CellSize = UDim2.fromOffset(sc(58), sc(68)),
                CellPadding = UDim2.fromOffset(sc(8), sc(8)),
                SortOrder = Enum.SortOrder.Name,
            }),
            s:New("UIPadding")({
                PaddingLeft = PanelScale.pad(4),
                PaddingTop = PanelScale.pad(4),
            }),
            s:Computed(function(use)
                if not use(state.panelOpen) or use(state.activeTab) ~= "inventory" then
                    return {}
                end
                HudStateModule.flushPendingInventory(state)
                local slots = {}
                for _, item in ipairs(use(state.inventory)) do
                    slots[#slots + 1] = InvSlot.create(s, { oreId = item.oreId, count = item.count })
                end
                return slots
            end),
        },
    })
end

return InventoryPanel
