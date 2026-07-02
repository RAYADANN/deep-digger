--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)
local peek = Fusion.peek
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local UpgradeMeta = require(script.Parent.Parent.UpgradeMeta)
local UpgRow = require(script.Parent.Parent.components.UpgRow)
local theme = require(script.Parent.Parent.theme)
local PanelScale = require(script.Parent.Parent.PanelScale)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local Children = Fusion.Children
local C = theme.C

local LIST_GAP = 8
-- Читаемая дизайн-высота строки. Раньше высота ужималась под контент модалки
-- (floor sc(44)), из-за чего на телефоне 7 строк не влезали в ~236px и нижние
-- ("Продажа"/"Авто-продажа") клиппились. Теперь строки живут в ScrollingFrame,
-- поэтому держим фиксированную читаемую высоту и просто скроллим.
local ROW_DESIGN_H = 62

local UpgradesPanel = {}

function UpgradesPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    local layoutEpoch = s:Value(0)
    ViewportLayout.subscribe(function()
        layoutEpoch:set(peek(layoutEpoch) + 1)
    end, s)

    -- Высота строки реактивна к ресайзу вьюпорта (sc() зависит от uiScale),
    -- но НЕ подгоняется под высоту модалки — теперь помещаемость решает скролл.
    local rowHeight = s:Computed(function(use)
        use(layoutEpoch)
        -- gsc: на десктопе высота строки ×2 синхронно с ×2 текстом UpgRow.
        return PanelScale.gsc(ROW_DESIGN_H)
    end)

    return s:New("ScrollingFrame")({
        Name = "Upgrades",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = PanelScale.scrollBar(),
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "upgrades"
        end),
        [Children] = {
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Vertical,
                Padding = PanelScale.pad(LIST_GAP),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            s:New("UIPadding")({
                PaddingLeft = PanelScale.pad(6),
                PaddingRight = PanelScale.pad(6),
                PaddingTop = PanelScale.pad(6),
                PaddingBottom = PanelScale.pad(6),
            }),
            -- Строки строим один раз (на открытие таба / ресайз), а НЕ на каждую
            -- покупку: уровень/стоимость/MAX обновляются реактивно внутри UpgRow.
            -- Раньше зависимость от `state.upgrades` пересобирала все ~7 строк на
            -- каждый апгрейд → destroy+recreate инстансов = мерцание текста.
            s:Computed(function(use)
                if use(state.activeTab) ~= "upgrades" then
                    return {}
                end
                local rh = use(rowHeight)
                local rows = {}
                for _, id in ipairs(UpgradeMeta.ORDER) do
                    local cfg = Constants.UPGRADES[id]
                    if not cfg then
                        continue
                    end
                    rows[#rows + 1] = UpgRow.create(s, {
                        upgradeId = id,
                        rowHeight = rh,
                        coinsValue = state.coins,
                        upgradesValue = state.upgrades,
                        rebirthsValue = state.rebirths,
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
