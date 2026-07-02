--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local PanelScale = require(script.Parent.Parent.PanelScale)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)
local UiInteract = require(script.Parent.Parent.Parent.util.UiInteract)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)
local InventoryPanel = require(script.Parent.InventoryPanel)
local UpgradesPanel = require(script.Parent.UpgradesPanel)
local StatsPanel = require(script.Parent.StatsPanel)
local RebirthPanel = require(script.Parent.RebirthPanel)
local LeaderboardPanel = require(script.Parent.LeaderboardPanel)
local PetsPanel = require(script.Parent.PetsPanel)
local ShopPanel = require(script.Parent.ShopPanel)
local JournalPanel = require(script.Parent.JournalPanel)
local GoalsPanel = require(script.Parent.GoalsPanel)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C

local sc = PanelScale.sc
local tsize = PanelScale.tsize
local MODAL_W = PanelScale.MODAL_W
local MODAL_H = PanelScale.MODAL_H
local HEADER_H = PanelScale.HEADER_H

local MainPanel = {}

local TITLE_MAP: { [string]: string } = {
	inventory = "ИНВЕНТАРЬ",
	upgrades = "УЛУЧШЕНИЯ",
	rebirth = "РЕБЁРТ",
	leaderboard = "ЛИДЕРБОРД",
	pets = "ПИТОМЦЫ",
	shop = "МАГАЗИН",
	journal = "ЖУРНАЛ НАХОДОК",
	goals = "ЦЕЛИ",
	stats = "СТАТИСТИКА",
}

local function titleForTab(tab: string): string
	return TITLE_MAP[tab] or "СТАТИСТИКА"
end

function MainPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local modalSize = s:Computed(function(use)
		use(layoutEpoch)
		local w, h = ViewportLayout.modalPixels(MODAL_W, MODAL_H)
		return UDim2.fromOffset(w, h)
	end)

	local modalPosition = s:Computed(function(use)
		use(layoutEpoch)
		local _, h = ViewportLayout.modalPixels(MODAL_W, MODAL_H)
		return UDim2.new(0.5, 0, 0, ViewportLayout.modalCenterY(h))
	end)

	local headerH = s:Computed(function(use)
		use(layoutEpoch)
		return ViewportLayout.modalHeaderPixels(HEADER_H)
	end)

	local root = s:New("Frame")({
		Name = "MainPanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = s:Computed(function(use)
			return use(state.panelOpen)
		end),
		ZIndex = 10,
		[Children] = {
			s:New("TextButton")({
				Name = "Dismiss",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 1,
				[OnEvent("Activated")] = function()
					state.panelOpen:set(false)
				end,
			}),
			s:New("Frame")({
				Name = "Modal",
				Size = modalSize,
				Position = modalPosition,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = C.panelBg,
				BorderSizePixel = 0,
				ZIndex = 2,
				Active = true,
				ClipsDescendants = true,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(0, sc(12)) }),
					s:New("UIStroke")({ Color = C.panelBorder, Thickness = sc(theme.STROKE.medium) }),
					s:New("Frame")({
						Name = "Header",
						Size = s:Computed(function(use)
							return UDim2.new(1, 0, 0, use(headerH))
						end),
						BackgroundColor3 = s:Computed(function(use)
							return theme.TAB_ACCENTS[use(state.activeTab)] or C.primary
						end),
						BorderSizePixel = 0,
						ZIndex = 2,
						[Children] = {
							s:New("UIGradient")({
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 200)),
								}),
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0.72),
									NumberSequenceKeypoint.new(1, 0.88),
								}),
								Rotation = 90,
							}),
							s:New("TextLabel")({
								Size = UDim2.new(1, -sc(58), 1, 0),
								Position = UDim2.new(0, sc(18), 0, 0),
								BackgroundTransparency = 1,
								Text = s:Computed(function(use)
									return titleForTab(use(state.activeTab))
								end),
								TextSize = tsize(22),
								Font = theme.FONT.title,
								TextColor3 = C.white,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 3,
								[Children] = {
									s:New("UIStroke")({ Color = C.outlineDark, Thickness = 1, Transparency = 0.4 }),
								},
							}),
							s:New("TextButton")({
								Size = UDim2.fromOffset(sc(34), sc(34)),
								Position = UDim2.new(1, -sc(44), 0.5, -sc(17)),
								BackgroundColor3 = C.closeBg,
								BackgroundTransparency = 0.15,
								BorderSizePixel = 0,
								Text = "",
								ZIndex = 3,
								[Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
									s:New("ImageLabel")({
										Size = UDim2.fromOffset(sc(16), sc(16)),
										Position = UDim2.fromScale(0.5, 0.5),
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Image = UiAssets.image("icon_close"),
										ScaleType = Enum.ScaleType.Fit,
										ZIndex = 4,
									}),
								},
								[OnEvent("Activated")] = function()
									state.panelOpen:set(false)
								end,
							}),
						},
					}),
					s:New("Frame")({
						Name = "Content",
						Size = s:Computed(function(use)
							local h = use(headerH)
							return UDim2.new(1, -sc(12), 1, -(h + sc(10)))
						end),
						Position = s:Computed(function(use)
							local h = use(headerH)
							return UDim2.new(0, sc(6), 0, h + sc(4))
						end),
						BackgroundColor3 = C.panelBody,
						BackgroundTransparency = 0,
						BorderSizePixel = 0,
						ClipsDescendants = true,
						ZIndex = 2,
						[Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(0, sc(10)) }),
							InventoryPanel.create(s, state),
							UpgradesPanel.create(s, state),
							StatsPanel.create(s, state),
							RebirthPanel.create(s, state),
							LeaderboardPanel.create(s, state),
							PetsPanel.create(s, state),
							ShopPanel.create(s, state),
							JournalPanel.create(s, state),
							GoalsPanel.create(s, state),
						},
					}),
				},
			}),
		},
	})

	UiMotion.defer(s, root, function(frame)
		local modal = frame:FindFirstChild("Modal") :: Frame?
		local header = if modal then modal:FindFirstChild("Header") :: Frame? else nil
		local close = if header then header:FindFirstChildWhichIsA("TextButton") :: TextButton? else nil
		if close then
			UiInteract.attachScoped(s, close, { hoverScale = 1.08, pressScale = 0.92 })
		end
		return nil
	end)

	return root
end

return MainPanel
