--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local peek = Fusion.peek
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local C = theme.C

local GoalsPanel = {}

local function formatReward(reward: { coins: number?, gems: number?, aura: string? }?): string
    if not reward then
        return ""
    end
    local parts = {}
    if reward.coins and reward.coins > 0 then
        table.insert(parts, ("+%d 💰"):format(reward.coins))
    end
    if reward.gems and reward.gems > 0 then
        table.insert(parts, ("+%d 💎"):format(reward.gems))
    end
    if reward.aura then
        table.insert(parts, "✨ " .. reward.aura)
    end
    return table.concat(parts, "  ")
end

local function tryClaimQuest(questId: string, isBusy: any)
    if peek(isBusy) then
        return
    end
    isBusy:set(true)
    task.spawn(function()
        local ok, result = pcall(function()
            return Net:Invoke("ClaimQuest", questId)
        end)
        isBusy:set(false)
        if not ok then
            warn("[GoalsPanel] ClaimQuest failed:", result)
        end
    end)
end

function GoalsPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    local isBusy = s:Value(false)

    return s:New("ScrollingFrame")({
        Name = "Goals",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "goals"
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
            -- Активный квест
            s:New("Frame")({
                Name = "QuestHeader",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = C.panelHeader,
                BackgroundTransparency = 0.15,
                BorderSizePixel = 0,
                LayoutOrder = 0,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
                    s:New("UIStroke")({ Color = C.gem, Thickness = 1, Transparency = 0.5 }),
                    s:New("UIPadding")({
                        PaddingTop = UDim.new(0, 8),
                        PaddingBottom = UDim.new(0, 8),
                        PaddingLeft = UDim.new(0, 10),
                        PaddingRight = UDim.new(0, 10),
                    }),
                    s:New("UIListLayout")({
                        FillDirection = Enum.FillDirection.Vertical,
                        Padding = UDim.new(0, 6),
                    }),
                    s:New("TextLabel")({
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        Text = s:Computed(function(use)
                            local claimed = use(state.questClaimedCount)
                            local total = use(state.questTotalCount)
                            return ("🎯 Текущая цель  (%d / %d)"):format(claimed, total)
                        end),
                        TextSize = 13,
                        Font = Enum.Font.GothamBlack,
                        TextColor3 = C.textMain,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }),
                    s:Computed(function(use)
                        local quest = use(state.questActive)
                        if not quest then
                            return s:New("TextLabel")({
                                Size = UDim2.new(1, 0, 0, 40),
                                BackgroundTransparency = 1,
                                Text = "✅ Все цели выполнены!",
                                TextSize = 14,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = C.gem,
                                TextXAlignment = Enum.TextXAlignment.Left,
                            })
                        end

                        local progress = math.min(quest.progress, quest.target)
                        local ratio = if quest.target > 0 then progress / quest.target else 0

                        return s:New("Frame")({
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            BackgroundTransparency = 1,
                            [Children] = {
                                s:New("UIListLayout")({
                                    FillDirection = Enum.FillDirection.Vertical,
                                    Padding = UDim.new(0, 6),
                                }),
                                s:New("TextLabel")({
                                    Size = UDim2.new(1, 0, 0, 18),
                                    BackgroundTransparency = 1,
                                    Text = quest.name,
                                    TextSize = 14,
                                    Font = Enum.Font.GothamBold,
                                    TextColor3 = C.textMain,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                }),
                                s:New("TextLabel")({
                                    Size = UDim2.new(1, 0, 0, 16),
                                    BackgroundTransparency = 1,
                                    Text = quest.desc,
                                    TextSize = 12,
                                    Font = Enum.Font.Gotham,
                                    TextColor3 = C.textMuted,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                }),
                                s:New("Frame")({
                                    Size = UDim2.new(1, 0, 0, 14),
                                    BackgroundColor3 = C.closeBg,
                                    BackgroundTransparency = 0.3,
                                    BorderSizePixel = 0,
                                    [Children] = {
                                        s:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
                                        s:New("Frame")({
                                            Size = UDim2.new(ratio, 0, 1, 0),
                                            BackgroundColor3 = if quest.claimable then C.gem else C.gold,
                                            BackgroundTransparency = 0.1,
                                            BorderSizePixel = 0,
                                            [Children] = {
                                                s:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
                                            },
                                        }),
                                    },
                                }),
                                s:New("TextLabel")({
                                    Size = UDim2.new(1, 0, 0, 16),
                                    BackgroundTransparency = 1,
                                    Text = ("%d / %d  ·  %s"):format(progress, quest.target, formatReward(quest.reward)),
                                    TextSize = 11,
                                    Font = Enum.Font.GothamBold,
                                    TextColor3 = C.textMuted,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                }),
                                s:New("TextButton")({
                                    Size = UDim2.new(0, 140, 0, 32),
                                    BackgroundColor3 = if quest.claimable then C.gem else C.closeBg,
                                    BackgroundTransparency = if quest.claimable then 0.1 else 0.4,
                                    BorderSizePixel = 0,
                                    Text = if quest.claimable then "ЗАБРАТЬ" else "В ПРОЦЕССЕ",
                                    TextSize = 13,
                                    Font = Enum.Font.GothamBlack,
                                    TextColor3 = C.white,
                                    Active = quest.claimable,
                                    AutoButtonColor = quest.claimable,
                                    [Children] = {
                                        s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
                                    },
                                    [OnEvent("Activated")] = function()
                                        if quest.claimable then
                                            tryClaimQuest(quest.id, isBusy)
                                        end
                                    end,
                                }),
                            },
                        })
                    end),
                },
            }),
            -- Достижения
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundTransparency = 1,
                Text = "🏅 Достижения",
                TextSize = 13,
                Font = Enum.Font.GothamBlack,
                TextColor3 = C.textMain,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
            }),
            s:Computed(function(use)
                local list = use(state.achievements) :: { any }
                local rows = {}
                for i, ach in ipairs(list) do
                    local unlocked = ach.unlocked == true
                    rows[#rows + 1] = s:New("Frame")({
                        Name = "Ach_" .. ach.id,
                        Size = UDim2.new(1, 0, 0, 52),
                        BackgroundColor3 = if unlocked then C.panelHeader else C.closeBg,
                        BackgroundTransparency = if unlocked then 0.2 else 0.5,
                        BorderSizePixel = 0,
                        LayoutOrder = i + 1,
                        [Children] = {
                            s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
                            s:New("TextLabel")({
                                Size = UDim2.new(0, 36, 1, 0),
                                Position = UDim2.new(0, 6, 0, 0),
                                BackgroundTransparency = 1,
                                Text = ach.icon or "🏅",
                                TextSize = 22,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = if unlocked then C.gem else C.textMuted,
                            }),
                            s:New("TextLabel")({
                                Size = UDim2.new(1, -100, 0, 18),
                                Position = UDim2.new(0, 44, 0, 8),
                                BackgroundTransparency = 1,
                                Text = ach.name,
                                TextSize = 13,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = if unlocked then C.textMain else C.textMuted,
                                TextXAlignment = Enum.TextXAlignment.Left,
                            }),
                            s:New("TextLabel")({
                                Size = UDim2.new(1, -100, 0, 14),
                                Position = UDim2.new(0, 44, 0, 28),
                                BackgroundTransparency = 1,
                                Text = ach.description,
                                TextSize = 11,
                                Font = Enum.Font.Gotham,
                                TextColor3 = C.textMuted,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextTruncate = Enum.TextTruncate.AtEnd,
                            }),
                            s:New("TextLabel")({
                                Size = UDim2.new(0, 80, 1, 0),
                                Position = UDim2.new(1, -86, 0, 0),
                                BackgroundTransparency = 1,
                                Text = if unlocked then "✓" else formatReward(ach.reward),
                                TextSize = if unlocked then 18 else 10,
                                Font = Enum.Font.GothamBold,
                                TextColor3 = if unlocked then C.gem else C.gold,
                                TextXAlignment = Enum.TextXAlignment.Right,
                            }),
                        },
                    })
                end
                return rows
            end),
        },
    })
end

return GoalsPanel
