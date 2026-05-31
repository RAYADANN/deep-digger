--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local InvSlot = require(script.Parent.Parent.components.InvSlot)

local Children = Fusion.Children
local C = theme.C

local InventoryPanel = {}

function InventoryPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("ScrollingFrame")({
        Name = "Inventory",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "inventory"
        end),
        [Children] = {
            s:New("UIGridLayout")({
                CellSize = UDim2.new(0, 58, 0, 68),
                CellPadding = UDim2.new(0, 8, 0, 8),
                SortOrder = Enum.SortOrder.Name,
            }),
            s:New("UIPadding")({ PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }),
            s:Computed(function(use)
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
