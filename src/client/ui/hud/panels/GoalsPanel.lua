--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local peek = Fusion.peek
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local PanelScale = require(script.Parent.Parent.PanelScale)
local UiIcon = require(script.Parent.Parent.components.UiIcon)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local C = theme.C
local ICON = theme.ICON
local ACCENT = theme.TAB_ACCENTS.goals
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text
local tsize = PanelScale.tsize

local GoalsPanel = {}

local function formatReward(reward: { coins: number?, gems: number?, aura: string? }?): string
	if not reward then
		return ""
	end
	local parts = {}
	if reward.coins and reward.coins > 0 then
		table.insert(parts, ("+%d монет"):format(reward.coins))
	end
	if reward.gems and reward.gems > 0 then
		table.insert(parts, ("+%d крист."):format(reward.gems))
	end
	if reward.aura then
		table.insert(parts, reward.aura)
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

-- P1.5: получение награды за ежедневное задание.
local function tryClaimDaily(questId: string, isBusy: any)
	if peek(isBusy) then
		return
	end
	isBusy:set(true)
	task.spawn(function()
		local ok, result = pcall(function()
			return Net:Invoke("ClaimDailyQuest", questId)
		end)
		isBusy:set(false)
		if not ok then
			warn("[GoalsPanel] ClaimDailyQuest failed:", result)
		end
	end)
end

local function tryEquipTitle(titleId: string?, isBusy: any)
	if peek(isBusy) then
		return
	end
	isBusy:set(true)
	task.spawn(function()
		local ok, result = pcall(function()
			return Net:Invoke("EquipTitle", titleId)
		end)
		isBusy:set(false)
		if not ok then
			warn("[GoalsPanel] EquipTitle failed:", result)
		end
	end)
end

local function formatResetIn(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = math.floor(s / 3600)
	local m = math.floor((s % 3600) / 60)
	if h > 0 then
		return ("сброс через %dч %dм"):format(h, m)
	end
	return ("сброс через %dм"):format(m)
end

local function progressBar(s: ScopeFactory.HudScope, ratio: number, fillColor: Color3)
	return s:New("Frame")({
		Size = UDim2.new(1, 0, 0, sc(10)),
		BackgroundColor3 = C.panelInner,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = 2,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			s:New("Frame")({
				Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0),
				BackgroundColor3 = fillColor,
				BackgroundTransparency = 0.05,
				BorderSizePixel = 0,
				ZIndex = 3,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				},
			}),
		},
	})
end

local function dailyRow(s: ScopeFactory.HudScope, quest: any, layoutOrder: number, isBusy: any): Instance
	local progress = math.min(quest.progress or 0, quest.target or 0)
	local ratio = if (quest.target or 0) > 0 then progress / quest.target else 0
	local claimed = quest.claimed == true
	local claimable = quest.claimable == true
	local fillColor = if claimed then C.sell elseif claimable then C.gem else ACCENT
	local rewardText = formatReward(quest.reward)
	local btnText = if claimed then "ПОЛУЧЕНО" elseif claimable then "ЗАБРАТЬ" else "В ПРОЦЕССЕ"
	return s:New("Frame")({
		Name = "Daily_" .. tostring(quest.id),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.btnBg,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
			s:New("UIStroke")({
				Color = if claimable then C.gem else C.dockBorder,
				Thickness = sc(1),
				Transparency = 0.5,
			}),
			s:New("UIPadding")({
				PaddingTop = PanelScale.pad(8),
				PaddingBottom = PanelScale.pad(8),
				PaddingLeft = PanelScale.pad(10),
				PaddingRight = PanelScale.pad(10),
			}),
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = PanelScale.pad(5),
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, sc(18)),
				BackgroundTransparency = 1,
				Text = quest.name,
				TextSize = tsize(14),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textMain,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, sc(15)),
				BackgroundTransparency = 1,
				Text = quest.desc,
				TextSize = text(12),
				Font = Enum.Font.Gotham,
				TextColor3 = C.textLabel,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			progressBar(s, ratio, fillColor),
			s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, sc(15)),
				BackgroundTransparency = 1,
				Text = ("%d / %d"):format(progress, quest.target or 0)
					.. (if rewardText ~= "" then "  ·  " .. rewardText else ""),
				TextSize = text(11),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textSub,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("TextButton")({
				Size = UDim2.new(0, sc(132), 0, sc(30)),
				BackgroundColor3 = if claimable then C.gold else C.btnDisabled,
				BackgroundTransparency = if claimable then 0 else 0.25,
				BorderSizePixel = 0,
				Text = btnText,
				TextSize = text(12),
				Font = Enum.Font.GothamBlack,
				TextColor3 = if claimable then Color3.fromRGB(40, 25, 0) else C.textMuted,
				Active = claimable,
				AutoButtonColor = false,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
				},
				[OnEvent("Activated")] = function()
					if claimable then
						tryClaimDaily(quest.id, isBusy)
					end
				end,
			}),
		},
	})
end

function GoalsPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	local isBusy = s:Value(false)

	return s:New("ScrollingFrame")({
		Name = "Goals",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = PanelScale.scrollBar(),
		ScrollBarImageColor3 = C.panelBorder,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = s:Computed(function(use)
			return use(state.activeTab) == "goals"
		end),
		[Children] = {
			s:New("UIPadding")({
				PaddingTop = PanelScale.pad(4),
				PaddingLeft = PanelScale.pad(4),
				PaddingRight = PanelScale.pad(4),
				PaddingBottom = PanelScale.pad(8),
			}),
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = PanelScale.pad(8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			-- Активный квест
			s:New("Frame")({
				Name = "QuestCard",
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = C.btnBg,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				LayoutOrder = 0,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
					s:New("UIStroke")({
						Color = s:Computed(function(use)
							local q = use(state.questActive)
							return if q and q.claimable then C.gem else C.dockBorder
						end),
						Thickness = sc(1),
						Transparency = 0.45,
					}),
					s:New("Frame")({
						Name = "QuestBody",
						Size = UDim2.new(1, -sc(12), 0, 0),
						Position = UDim2.new(0, sc(6), 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						[Children] = {
							s:New("UIPadding")({
								PaddingTop = PanelScale.pad(0),
								PaddingBottom = PanelScale.pad(10),
								PaddingLeft = PanelScale.pad(8),
								PaddingRight = PanelScale.pad(10),
							}),
							s:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Vertical,
								Padding = PanelScale.pad(8),
							}),
							s:New("TextLabel")({
								Size = UDim2.new(1, 0, 0, sc(14)),
								BackgroundTransparency = 1,
								Text = s:Computed(function(use)
									local claimed = use(state.questClaimedCount)
									local total = use(state.questTotalCount)
									return ("Квесты: %d / %d"):format(claimed, total)
								end),
								TextSize = text(12),
								Font = Enum.Font.GothamBold,
								TextColor3 = C.textLabel,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 2,
							}),
							s:Computed(function(use)
								local quest = use(state.questActive)
								if not quest then
									return s:New("Frame")({
										Size = UDim2.new(1, 0, 0, sc(36)),
										BackgroundTransparency = 1,
										[Children] = {
											UiIcon.create(s, {
												source = "icon_check",
												size = UDim2.fromOffset(sc(22), sc(22)),
												position = UDim2.new(0, 0, 0.5, -sc(11)),
												zIndex = 3,
											}),
											s:New("TextLabel")({
												Size = UDim2.new(1, -sc(30), 1, 0),
												Position = UDim2.new(0, sc(30), 0, 0),
												BackgroundTransparency = 1,
												Text = "Все квесты выполнены",
												TextSize = tsize(15),
												Font = Enum.Font.GothamBold,
												TextColor3 = C.textMain,
												TextXAlignment = Enum.TextXAlignment.Left,
												TextYAlignment = Enum.TextYAlignment.Center,
												ZIndex = 2,
											}),
										},
									})
								end

								local progress = math.min(quest.progress, quest.target)
								local ratio = if quest.target > 0 then progress / quest.target else 0
								local fillColor = if quest.claimable then C.gem else ACCENT
								local rewardText = formatReward(quest.reward)

								return s:New("Frame")({
									Size = UDim2.new(1, 0, 0, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									BackgroundTransparency = 1,
									[Children] = {
										s:New("UIListLayout")({
											FillDirection = Enum.FillDirection.Vertical,
											Padding = PanelScale.pad(6),
										}),
										s:New("TextLabel")({
											Size = UDim2.new(1, 0, 0, sc(20)),
											BackgroundTransparency = 1,
											Text = quest.name,
											TextSize = tsize(15),
											Font = Enum.Font.GothamBlack,
											TextColor3 = C.textMain,
											TextXAlignment = Enum.TextXAlignment.Left,
											ZIndex = 2,
										}),
										s:New("TextLabel")({
											Size = UDim2.new(1, 0, 0, 0),
											AutomaticSize = Enum.AutomaticSize.Y,
											BackgroundTransparency = 1,
											Text = quest.desc,
											TextSize = text(13),
											Font = Enum.Font.Gotham,
											TextColor3 = C.textLabel,
											TextWrapped = true,
											TextXAlignment = Enum.TextXAlignment.Left,
											ZIndex = 2,
										}),
										progressBar(s, ratio, fillColor),
										s:New("TextLabel")({
											Size = UDim2.new(1, 0, 0, sc(16)),
											BackgroundTransparency = 1,
											Text = ("%d / %d"):format(progress, quest.target)
												.. (if rewardText ~= "" then "  ·  " .. rewardText else ""),
											TextSize = text(12),
											Font = Enum.Font.GothamBold,
											TextColor3 = C.textSub,
											TextXAlignment = Enum.TextXAlignment.Left,
											ZIndex = 2,
										}),
										s:New("TextButton")({
											Size = UDim2.new(0, sc(148), 0, sc(34)),
											BackgroundColor3 = if quest.claimable then C.gold else C.btnDisabled,
											BackgroundTransparency = if quest.claimable then 0 else 0.25,
											BorderSizePixel = 0,
											Text = if quest.claimable then "ЗАБРАТЬ НАГРАДУ" else "В ПРОЦЕССЕ",
											TextSize = text(13),
											Font = Enum.Font.GothamBlack,
											TextColor3 = if quest.claimable
												then Color3.fromRGB(40, 25, 0)
												else C.textMuted,
											Active = quest.claimable,
											AutoButtonColor = false,
											ZIndex = 2,
											[Children] = {
												s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
												s:New("UIStroke")({
													Color = if quest.claimable
														then Color3.fromRGB(255, 230, 140)
														else C.dockBorder,
													Thickness = sc(1),
													Transparency = 0.5,
												}),
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
				},
			}),
			-- P1.5: блок повторяемых ежедневок (заголовок + строки + таймер сброса).
			s:New("Frame")({
				Name = "DailyQuests",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Vertical,
						Padding = PanelScale.pad(6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					s:New("TextLabel")({
						LayoutOrder = 0,
						Size = UDim2.new(1, 0, 0, sc(18)),
						BackgroundTransparency = 1,
						Text = s:Computed(function(use)
							local dq = use(state.dailyQuests) or {}
							return ("ЕЖЕДНЕВНЫЕ ЗАДАНИЯ  ·  %s"):format(formatResetIn(dq.secondsUntilReset or 0))
						end),
						TextSize = text(11),
						Font = theme.FONT.title,
						TextColor3 = C.textSub,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 2,
					}),
					s:Computed(function(use)
						local dq = use(state.dailyQuests) or {}
						local rows = {}
						for i, quest in ipairs(dq.quests or {}) do
							rows[#rows + 1] = dailyRow(s, quest, i, isBusy)
						end
						return rows
					end),
				},
			}),
			s:New("TextLabel")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, sc(18)),
				BackgroundTransparency = 1,
				Text = "ДОСТИЖЕНИЯ",
				TextSize = text(11),
				Font = theme.FONT.title,
				TextColor3 = C.textSub,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("TextLabel")({
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = "Выбери титул — он отображается под ником над головой.",
				TextSize = text(11),
				Font = Enum.Font.Gotham,
				TextColor3 = C.textLabel,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("Frame")({
				Name = "TitleAuto",
				Size = UDim2.new(1, 0, 0, sc(48)),
				BackgroundColor3 = s:Computed(function(use)
					return if use(state.equippedTitleId) == nil then C.bg4 else C.btnBg
				end),
				BackgroundTransparency = s:Computed(function(use)
					return if use(state.equippedTitleId) == nil then 0.1 else 0
				end),
				BorderSizePixel = 0,
				LayoutOrder = 5,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
					s:New("UIStroke")({
						Color = s:Computed(function(use)
							return if use(state.equippedTitleId) == nil then ACCENT else C.dockBorder
						end),
						Thickness = sc(1),
						Transparency = s:Computed(function(use)
							return if use(state.equippedTitleId) == nil then 0.55 else 0.45
						end),
					}),
					s:New("TextLabel")({
						Size = UDim2.new(1, -sc(108), 1, 0),
						Position = UDim2.new(0, sc(12), 0, 0),
						BackgroundTransparency = 1,
						Text = "Авто (по ребёртам)",
						TextSize = tsize(14),
						Font = Enum.Font.GothamBold,
						TextColor3 = s:Computed(function(use)
							return if use(state.equippedTitleId) == nil then C.textMain else C.textLabel
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Center,
						ZIndex = 2,
					}),
					s:New("ImageLabel")({
						Size = UDim2.fromOffset(sc(22), sc(22)),
						Position = UDim2.new(1, -sc(36), 0.5, -sc(11)),
						BackgroundTransparency = 1,
						Image = UiAssets.image("icon_check"),
						ImageColor3 = ICON.tint,
						ScaleType = Enum.ScaleType.Fit,
						Visible = s:Computed(function(use)
							return use(state.equippedTitleId) == nil
						end),
						ZIndex = 3,
					}),
					s:New("TextButton")({
						Size = UDim2.new(0, sc(88), 0, sc(30)),
						Position = UDim2.new(1, -sc(94), 0.5, -sc(15)),
						BackgroundColor3 = C.btnBg,
						BorderSizePixel = 0,
						Text = "ВЫБРАТЬ",
						TextSize = text(11),
						Font = Enum.Font.GothamBold,
						TextColor3 = C.textMain,
						AutoButtonColor = false,
						Visible = s:Computed(function(use)
							return use(state.equippedTitleId) ~= nil
						end),
						ZIndex = 2,
						[Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(0, sc(6)) }),
							s:New("UIStroke")({ Color = C.dockBorder, Thickness = sc(1), Transparency = 0.45 }),
						},
						[OnEvent("Activated")] = function()
							tryEquipTitle(nil, isBusy)
						end,
					}),
				},
			}),
			s:Computed(function(use)
				local list = use(state.achievements) :: { any }
				local equippedId = use(state.equippedTitleId)
				local rows = {}
				for i, ach in ipairs(list) do
					local unlocked = ach.unlocked == true
					local isEquipped = unlocked and equippedId == ach.id
					local iconId = UiAssets.resolve(ach.icon)
					if iconId == "" then
						iconId = UiAssets.achievement(ach.id)
					end

					rows[#rows + 1] = s:New("Frame")({
						Name = "Ach_" .. ach.id,
						Size = UDim2.new(1, 0, 0, sc(56)),
						BackgroundColor3 = if unlocked then C.bg4 else C.btnBg,
						BackgroundTransparency = if unlocked then 0.1 else 0,
						BorderSizePixel = 0,
						LayoutOrder = i + 5,
						[Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
							s:New("UIStroke")({
								Color = if unlocked then ACCENT else C.dockBorder,
								Thickness = sc(1),
								Transparency = if unlocked then 0.55 else 0.45,
							}),
							s:New("ImageLabel")({
								Size = UDim2.fromOffset(sc(30), sc(30)),
								Position = UDim2.new(0, sc(10), 0.5, -sc(15)),
								BackgroundTransparency = 1,
								Image = iconId,
								ImageColor3 = ICON.tint,
								ImageTransparency = if unlocked then 0 else ICON.mutedAlpha,
								ScaleType = Enum.ScaleType.Fit,
								ZIndex = 2,
							}),
							s:New("TextLabel")({
								Size = UDim2.new(1, -sc(108), 0, sc(18)),
								Position = UDim2.new(0, sc(48), 0, sc(10)),
								BackgroundTransparency = 1,
								Text = ach.name,
								TextSize = tsize(14),
								Font = Enum.Font.GothamBold,
								TextColor3 = if unlocked then C.textMain else C.textLabel,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 2,
							}),
							s:New("TextLabel")({
								Size = UDim2.new(1, -sc(108), 0, sc(16)),
								Position = UDim2.new(0, sc(48), 0, sc(30)),
								BackgroundTransparency = 1,
								Text = ach.description,
								TextSize = text(12),
								Font = Enum.Font.Gotham,
								TextColor3 = C.textLabel,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 2,
							}),
							if isEquipped
								then s:New("TextLabel")({
									Size = UDim2.new(0, sc(88), 1, 0),
									Position = UDim2.new(1, -sc(94), 0, 0),
									BackgroundTransparency = 1,
									Text = "ТИТУЛ",
									TextSize = text(11),
									Font = Enum.Font.GothamBlack,
									TextColor3 = ACCENT,
									TextXAlignment = Enum.TextXAlignment.Right,
									TextYAlignment = Enum.TextYAlignment.Center,
									ZIndex = 3,
								})
								elseif unlocked
								then s:New("TextButton")({
									Size = UDim2.new(0, sc(88), 0, sc(30)),
									Position = UDim2.new(1, -sc(94), 0.5, -sc(15)),
									BackgroundColor3 = C.btnBg,
									BorderSizePixel = 0,
									Text = "НАДЕТЬ",
									TextSize = text(11),
									Font = Enum.Font.GothamBold,
									TextColor3 = C.textMain,
									AutoButtonColor = false,
									ZIndex = 2,
									[Children] = {
										s:New("UICorner")({ CornerRadius = UDim.new(0, sc(6)) }),
										s:New("UIStroke")({ Color = ACCENT, Thickness = sc(1), Transparency = 0.45 }),
									},
									[OnEvent("Activated")] = function()
										tryEquipTitle(ach.id, isBusy)
									end,
								})
								else s:New("TextLabel")({
									Size = UDim2.new(0, sc(88), 1, 0),
									Position = UDim2.new(1, -sc(94), 0, 0),
									BackgroundTransparency = 1,
									Text = formatReward(ach.reward),
									TextSize = text(11),
									Font = Enum.Font.GothamBold,
									TextColor3 = C.gold,
									TextXAlignment = Enum.TextXAlignment.Right,
									TextYAlignment = Enum.TextYAlignment.Center,
									ZIndex = 2,
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
