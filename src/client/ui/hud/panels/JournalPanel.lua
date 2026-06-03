--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local DiscoveryLogic = require(ReplicatedStorage:WaitForChild("shared").util.DiscoveryLogic)
local OreEntry = require(script.Parent.Parent.components.OreEntry)

local Children = Fusion.Children
local C = theme.C

local JournalPanel = {}

local function isDiscovered(map: { [string]: boolean }, oreId: string): boolean
    return map[oreId] == true
end

function JournalPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("ScrollingFrame")({
        Name = "Journal",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "journal"
        end),
        [Children] = {
            s:New("UIPadding")({
                PaddingTop = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 8),
            }),
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 10),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            s:New("Frame")({
                Name = "JournalHeader",
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = C.panelHeader,
                BackgroundTransparency = 0.15,
                BorderSizePixel = 0,
                LayoutOrder = 0,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
                    s:New("UIStroke")({ Color = C.gem, Thickness = 1, Transparency = 0.5 }),
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -12, 0, 20),
                        Position = UDim2.new(0, 8, 0, 6),
                        BackgroundTransparency = 1,
                        Text = "📖 Журнал находок",
                        TextSize = 14,
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = C.textMain,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 2,
                    }),
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -12, 0, 16),
                        Position = UDim2.new(0, 8, 0, 24),
                        BackgroundTransparency = 1,
                        Text = s:Computed(function(use)
                            local found = use(state.discoveryFound)
                            local total = use(state.discoveryTotal)
                            return ("Открыто %d / %d руд"):format(found, total)
                        end),
                        TextSize = 12,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = C.gem,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 2,
                    }),
                },
            }),
            s:Computed(function(use)
                local discovered = use(state.discoveredOres) :: { [string]: boolean }
                local milestones = use(state.discoveredMilestones) :: { [string]: boolean }
                local sections = {}
                local layoutOrder = 1

                for _, layer in ipairs(DiscoveryLogic.getLayers()) do
                    local progress = DiscoveryLogic.layerProgress({ discoveredOres = discovered }, layer.layerId)
                    local complete = progress.total > 0 and progress.found >= progress.total
                    local milestoneDone = milestones[layer.layerId] == true

                    sections[#sections + 1] = s:New("Frame")({
                        Name = "Layer_" .. layer.layerId,
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundTransparency = 1,
                        LayoutOrder = layoutOrder,
                        [Children] = {
                            s:New("UIListLayout")({
                                FillDirection = Enum.FillDirection.Vertical,
                                Padding = UDim.new(0, 6),
                            }),
                            s:New("Frame")({
                                Size = UDim2.new(1, 0, 0, 28),
                                BackgroundTransparency = 1,
                                [Children] = {
                                    s:New("TextLabel")({
                                        Size = UDim2.new(0.72, 0, 1, 0),
                                        BackgroundTransparency = 1,
                                        Text = layer.name,
                                        TextSize = 13,
                                        Font = Enum.Font.GothamBold,
                                        TextColor3 = C.textMain,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                        ZIndex = 2,
                                    }),
                                    s:New("TextLabel")({
                                        Size = UDim2.new(0.28, 0, 1, 0),
                                        Position = UDim2.new(0.72, 0, 0, 0),
                                        BackgroundTransparency = 1,
                                        Text = ("%d/%d%s"):format(
                                            progress.found,
                                            progress.total,
                                            if complete and milestoneDone then " ✓" else ""
                                        ),
                                        TextSize = 12,
                                        Font = Enum.Font.Gotham,
                                        TextColor3 = if complete then C.gem else C.textMuted,
                                        TextXAlignment = Enum.TextXAlignment.Right,
                                        ZIndex = 2,
                                    }),
                                },
                            }),
                            s:New("Frame")({
                                Size = UDim2.new(1, 0, 0, 0),
                                AutomaticSize = Enum.AutomaticSize.Y,
                                BackgroundTransparency = 1,
                                [Children] = {
                                    s:New("UIGridLayout")({
                                        CellSize = UDim2.new(0, 52, 0, 62),
                                        CellPadding = UDim2.new(0, 6, 0, 6),
                                        SortOrder = Enum.SortOrder.Name,
                                    }),
                                    (function()
                                        local entries = {}
                                        for _, oreId in ipairs(layer.ores) do
                                            entries[#entries + 1] = OreEntry.create(s, {
                                                oreId = oreId,
                                                discovered = isDiscovered(discovered, oreId),
                                            })
                                        end
                                        return entries
                                    end)(),
                                },
                            }),
                        },
                    })
                    layoutOrder += 1
                end

                return sections
            end),
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local milestones = use(state.discoveredMilestones) :: { [string]: boolean }
                    local count = 0
                    for _ in pairs(milestones) do
                        count += 1
                    end
                    if count == 0 then
                        return "Полностью открой слой — получи бонус 💰"
                    end
                    return ("Награды за слои: %d"):format(count)
                end),
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextColor3 = C.textMuted,
                TextWrapped = true,
                LayoutOrder = 99,
                ZIndex = 2,
            }),
        },
    })
end

return JournalPanel
