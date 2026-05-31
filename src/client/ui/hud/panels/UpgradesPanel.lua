--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)
local peek = Fusion.peek
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local UpgradeMeta = require(script.Parent.Parent.UpgradeMeta)
local UpgRow = require(script.Parent.Parent.components.UpgRow)

local Children = Fusion.Children
local C = theme.C

local UpgradesPanel = {}

function UpgradesPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("ScrollingFrame")({
        Name = "Upgrades",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "upgrades"
        end),
        [Children] = {
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            s:New("UIPadding")({
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4),
            }),
            s:Computed(function(use)
                local rows = {}
                local upgrades = use(state.upgrades)
                local coins = use(state.coins)
                for _, id in ipairs(UpgradeMeta.ORDER) do
                    local row = upgrades[id]
                    if not row then
                        continue
                    end
                    local cfg = Constants.UPGRADES[id]
                    if not cfg then
                        continue
                    end
                    local displayLevel = math.max(row.level, 1)
                    local cost = Formatters.upgradeCost(id, displayLevel)
                    local isMax = if id == "autoSell"
                        then row.level >= 1
                        else row.level >= cfg.maxLevel
                    rows[#rows + 1] = UpgRow.create(s, {
                        upgradeId = id,
                        level = row.level,
                        maxLevel = cfg.maxLevel,
                        cost = cost,
                        canAfford = not isMax and coins >= cost,
                        canAffordNow = function()
                            return not isMax and peek(state.coins) >= cost
                        end,
                        onBuy = function()
                            return Net:Invoke("BuyUpgrade", id)
                        end,
                    })
                end
                return rows
            end),
        },
    })
end

return UpgradesPanel
