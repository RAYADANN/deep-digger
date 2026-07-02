--!strict
-- Текущая цель: справа по центру (desktop/tablet), под ribbon на телефоне.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
local ICON = theme.ICON
local ACCENT = theme.TAB_ACCENTS.goals

local PAD_R = 10

local function ts(n: number): number
	return math.floor(n * ViewportLayout.textMult() + 0.5)
end

local QuestTracker = {}

function QuestTracker.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local hovering = s:Value(false)
	local pressing = s:Value(false)

	local showBadge = s:Computed(function(use)
		local q = use(state.questActive)
		return q ~= nil and q.claimable == true
	end)

	local strokeColor = s:Computed(function(use)
		if use(showBadge) then
			return C.gem
		end
		return C.dockBorder
	end)

	local function openGoals()
		state.activeTab:set("goals")
		state.panelOpen:set(true)
	end

	local trackerWidth = s:Computed(function(use)
		use(layoutEpoch)
		if ViewportLayout.isPhone() then
			return ViewportLayout.availableWidth()
		end
		return ViewportLayout.questTrackerWidth()
	end)

	local tracker = s:New("Frame")({
		Name = "QuestTrackerHost",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = s:Computed(function(use)
			if use(state.panelOpen) then
				return false
			end
			use(layoutEpoch)
			if ViewportLayout.isPhone() then
				return false
			end
			return ViewportLayout.getSize().Y >= 380
		end),
		ZIndex = 6,
		[Children] = {
			s:New("Frame")({
				Name = "QuestTracker",
				Size = s:Computed(function(use)
					local w = use(trackerWidth)
					return UDim2.fromOffset(w, 0)
				end),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = s:Computed(function(use)
					use(layoutEpoch)
					if ViewportLayout.isPhone() then
						return UDim2.new(0.5, 0, 0, ViewportLayout.topChromeHeight() + 4)
					end
					return UDim2.new(1, -PAD_R, 0.5, 0)
				end),
				AnchorPoint = s:Computed(function(use)
					use(layoutEpoch)
					if ViewportLayout.isPhone() then
						return Vector2.new(0.5, 0)
					end
					return Vector2.new(1, 0.5)
				end),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("TextButton")({
						Name = "Face",
						Size = UDim2.new(1, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = C.dockBg,
						BackgroundTransparency = 0.08,
						BorderSizePixel = 0,
						Text = "",
						AutoButtonColor = false,
						[OnEvent("MouseEnter")] = function()
							hovering:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							hovering:set(false)
							pressing:set(false)
						end,
						[OnEvent("MouseButton1Down")] = function()
							pressing:set(true)
						end,
						[OnEvent("MouseButton1Up")] = function()
							pressing:set(false)
						end,
						[OnEvent("Activated")] = openGoals,
						[Children] = {
							s:New("UICorner")({ CornerRadius = theme.RADIUS.chip }),
							s:New("UIStroke")({
								Color = strokeColor,
								Thickness = 1.5,
								Transparency = s:Computed(function(use)
									return if use(showBadge) then 0.15 else 0.4
								end),
							}),
							s:New("UIGradient")({
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 48, 72)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 17, 30)),
								}),
								Rotation = 90,
								Transparency = NumberSequence.new(0.35),
							}),
							s:New("Frame")({
								Name = "AccentBar",
								Size = UDim2.new(0, 3, 1, -16),
								Position = UDim2.new(0, 8, 0, 8),
								BackgroundColor3 = s:Computed(function(use)
									return if use(showBadge) then C.gem else ACCENT
								end),
								BorderSizePixel = 0,
								ZIndex = 2,
								[Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
								},
							}),
							s:New("ImageLabel")({
								Name = "Icon",
								Size = UDim2.fromOffset(22, 22),
								Position = UDim2.new(0, 16, 0, 10),
								BackgroundTransparency = 1,
								Image = UiAssets.tab("goals"),
								ImageColor3 = ICON.tint,
								ScaleType = Enum.ScaleType.Fit,
								ZIndex = 2,
							}),
							s:New("Frame")({
								Name = "Badge",
								Size = UDim2.fromOffset(12, 12),
								Position = UDim2.new(1, -14, 0, 8),
								BackgroundColor3 = C.mythic,
								BorderSizePixel = 0,
								Visible = showBadge,
								ZIndex = 4,
								[Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
									s:New("UIStroke")({ Color = C.dockBg, Thickness = 1.5 }),
								},
							}),
							s:New("Frame")({
								Name = "Body",
								Size = UDim2.new(1, -20, 0, 0),
								Position = UDim2.new(0, 10, 0, 8),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								ZIndex = 2,
								[Children] = {
									s:New("UIPadding")({
										PaddingTop = UDim.new(0, 0),
										PaddingBottom = UDim.new(0, 10),
										PaddingLeft = UDim.new(0, 34),
										PaddingRight = UDim.new(0, 10),
									}),
									s:New("UIListLayout")({
										FillDirection = Enum.FillDirection.Vertical,
										Padding = UDim.new(0, 5),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									s:New("TextLabel")({
										LayoutOrder = 0,
										Size = UDim2.new(1, 0, 0, 14),
										BackgroundTransparency = 1,
										Text = "ТЕКУЩАЯ ЦЕЛЬ",
										TextSize = ts(11),
										Font = theme.FONT.title,
										TextColor3 = ACCENT,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
									s:Computed(function(use)
										local quest = use(state.questActive)
										if not quest then
											return s:New("TextLabel")({
												LayoutOrder = 1,
												Size = UDim2.new(1, 0, 0, 32),
												BackgroundTransparency = 1,
												Text = "Все цели выполнены",
												TextSize = ts(13),
												Font = Enum.Font.GothamBold,
												TextColor3 = C.gem,
												TextWrapped = true,
												TextXAlignment = Enum.TextXAlignment.Left,
											})
										end

										local progress = math.min(quest.progress, quest.target)
										local ratio = if quest.target > 0 then progress / quest.target else 0
										local barColor = if quest.claimable then C.gem else ACCENT

										return s:New("Frame")({
											LayoutOrder = 1,
											Size = UDim2.new(1, 0, 0, 0),
											AutomaticSize = Enum.AutomaticSize.Y,
											BackgroundTransparency = 1,
											[Children] = {
												s:New("UIListLayout")({
													FillDirection = Enum.FillDirection.Vertical,
													Padding = UDim.new(0, 4),
												}),
												s:New("TextLabel")({
													Size = UDim2.new(1, 0, 0, 16),
													BackgroundTransparency = 1,
													Text = quest.name,
													TextSize = ts(13),
													Font = Enum.Font.GothamBlack,
													TextColor3 = C.textMain,
													TextTruncate = Enum.TextTruncate.AtEnd,
													TextXAlignment = Enum.TextXAlignment.Left,
												}),
												s:New("TextLabel")({
													Size = UDim2.new(1, 0, 0, 14),
													BackgroundTransparency = 1,
													Text = if quest.claimable
														then "Награда готова — открой и забери"
														else quest.desc,
													TextSize = ts(12),
													Font = Enum.Font.Gotham,
													TextColor3 = if quest.claimable then C.gem else C.textMuted,
													TextWrapped = true,
													TextXAlignment = Enum.TextXAlignment.Left,
												}),
												s:New("Frame")({
													Size = UDim2.new(1, 0, 0, 8),
													BackgroundColor3 = C.closeBg,
													BackgroundTransparency = 0.55,
													BorderSizePixel = 0,
													[Children] = {
														s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
														s:New("Frame")({
															Size = UDim2.new(ratio, 0, 1, 0),
															BackgroundColor3 = barColor,
															BackgroundTransparency = 0.05,
															BorderSizePixel = 0,
															[Children] = {
																s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
															},
														}),
													},
												}),
												s:New("TextLabel")({
													Size = UDim2.new(1, 0, 0, 14),
													BackgroundTransparency = 1,
													Text = ("%d / %d"):format(progress, quest.target),
													TextSize = ts(12),
													Font = Enum.Font.GothamBold,
													TextColor3 = C.textSub,
													TextXAlignment = Enum.TextXAlignment.Left,
												}),
											},
										})
									end),
								},
							}),
						},
					}),
				},
			}),
		},
	})

	UiMotion.defer(s, tracker, function(root)
		local face = root:FindFirstChild("QuestTracker", true) :: Frame?
		face = if face then face:FindFirstChild("Face") :: TextButton? else nil
		if face then
			UiMotion.bindHoverPress(s, face, hovering, pressing, { hoverScale = 1.03, pressScale = 0.96 })
			local badge = face:FindFirstChild("Badge") :: Frame?
			if badge then
				UiMotion.watch(s, function()
					return peek(showBadge)
				end, function(visible, wasVisible)
					if visible and not wasVisible then
						UiMotion.pop(badge, 1.2)
					end
				end)
			end
		end
		return nil
	end)

	return tracker
end

return QuestTracker
