--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local DockIcon = require(script.Parent.Parent.components.DockIcon)

local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
local ACCENTS = theme.TAB_ACCENTS

local PRIMARY_TABS = {
	{ label = "РЮКЗАК", tabId = "inventory", iconKey = "tab_inventory" },
	{ label = "КИРКА", tabId = "upgrades", iconKey = "tab_upgrades" },
	{ label = "ЖУРНАЛ", tabId = "journal", iconKey = "tab_journal" },
}

local MORE_TABS = {
	{ label = "СТАТЫ", tabId = "stats", iconKey = "tab_stats" },
	{ label = "РЕБЁРТ", tabId = "rebirth", iconKey = "tab_rebirth" },
	{ label = "ТОП", tabId = "leaderboard", iconKey = "tab_leaderboard" },
	{ label = "МАГАЗ", tabId = "shop", iconKey = "tab_shop" },
}

local BottomDock = {}

function BottomDock.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	local moreOpen = s:Value(false)

	local function openTab(tabId: string)
		state.activeTab:set(tabId)
		state.panelOpen:set(true)
		moreOpen:set(false)
	end

	local dockWidth = 58 * 5 + 10 * 4 + 24

	return s:New("Frame")({
		Name = "BottomDock",
		Size = UDim2.fromOffset(dockWidth, 92),
		Position = UDim2.new(0.5, -dockWidth / 2, 1, -104),
		BackgroundColor3 = C.dockBg,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		[Children] = {
			s:New("UICorner")({ CornerRadius = theme.RADIUS.dock }),
			s:New("UIStroke")({ Color = C.dockStroke, Thickness = 1.5, Transparency = 0.35 }),
			s:New("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 60, 90)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 24, 36)),
				}),
				Rotation = 90,
				Transparency = NumberSequence.new(0.55),
			}),
			s:New("Frame")({
				Name = "DockRow",
				Size = UDim2.new(1, -20, 1, -12),
				Position = UDim2.new(0, 10, 0, 6),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 10),
						VerticalAlignment = Enum.VerticalAlignment.Center,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
					}),
					(function()
						local buttons = {}
						for _, tab in PRIMARY_TABS do
							buttons[#buttons + 1] = DockIcon.create(s, {
								name = "Tab_" .. tab.tabId,
								tabId = tab.tabId,
								label = tab.label,
								iconKey = tab.iconKey,
								accent = ACCENTS[tab.tabId] or C.accentCyan,
								activeTab = state.activeTab,
								panelOpen = state.panelOpen,
								showBadge = nil,
							})
						end
						buttons[#buttons + 1] = DockIcon.create(s, {
							name = "Tab_more",
							label = "ЕЩЁ",
							iconKey = "tab_more",
							accent = ACCENTS.more,
							onActivated = function()
								moreOpen:set(not peek(moreOpen))
							end,
						})
						return buttons
					end)(),
				},
			}),
			s:New("Frame")({
				Name = "MoreMenu",
				Size = UDim2.fromOffset(280, 84),
				Position = UDim2.new(1, -64, 0, -92),
				BackgroundColor3 = C.panelGlass,
				BackgroundTransparency = 0.12,
				BorderSizePixel = 0,
				Visible = moreOpen,
				ZIndex = 6,
				[Children] = {
					s:New("UICorner")({ CornerRadius = theme.RADIUS.panel }),
					s:New("UIStroke")({ Color = C.panelBorder, Thickness = 1.5, Transparency = 0.5 }),
					s:New("UIPadding")({ PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8) }),
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 4),
					}),
					(function()
						local items = {}
						for _, tab in MORE_TABS do
							items[#items + 1] = DockIcon.create(s, {
								name = "Tab_" .. tab.tabId,
								label = tab.label,
								iconKey = tab.iconKey,
								accent = ACCENTS[tab.tabId] or C.accentCyan,
								onActivated = function()
									openTab(tab.tabId)
								end,
							})
						end
						return items
					end)(),
				},
			}),
		},
	})
end

return BottomDock
