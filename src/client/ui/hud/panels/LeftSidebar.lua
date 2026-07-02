--!strict
-- Нижний док: вкладки в ряд, магазин — hero по центру.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local DockIcon = require(script.Parent.Parent.components.DockIcon)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local C = theme.C
local ICON = theme.ICON
local ACCENTS = theme.TAB_ACCENTS

local DOCK_TABS = {
	{ tabId = "inventory", iconKey = "tab_inventory", accent = ACCENTS.inventory },
	{ tabId = "journal", iconKey = "tab_journal", accent = ACCENTS.journal },
	{ tabId = "goals", iconKey = "tab_goals", accent = ACCENTS.goals },
	{ tabId = "shop", iconKey = "tab_shop", accent = ACCENTS.shop, isShop = true },
	{ tabId = "pets", iconKey = "tab_pets", accent = ACCENTS.pets },
	{ tabId = "stats", iconKey = "tab_stats", accent = ACCENTS.stats },
	{ tabId = "rebirth", iconKey = "tab_rebirth", accent = ACCENTS.rebirth },
}

local SHOP_INDEX = 4

local function tabWidth(metrics: ViewportLayout.DockMetrics, tab: { isShop: boolean? }): number
	return if tab.isShop then metrics.shopW else metrics.btnW
end

local LeftSidebar = {}

function LeftSidebar.create(
	s: ScopeFactory.HudScope,
	state: HudStateModule.HudState,
	homeActivated: () -> ()
)
	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local homeVisible = s:Computed(function(use)
		return math.floor(use(state.depth) or 0) > 0
	end)

	local dockLayout = s:Computed(function(use)
		use(layoutEpoch)
		local metrics = ViewportLayout.dockMetrics()
		local designW = ViewportLayout.dockWidthForTabs(metrics, DOCK_TABS, SHOP_INDEX)
		local dockW, dockH = ViewportLayout.dockPixelSize(designW, metrics.dockH)
		local fit = dockW / designW
		local btnY = math.floor((dockH - metrics.btnH * fit) * 0.5 + 0.5)
		return {
			metrics = metrics,
			dockW = dockW,
			dockH = dockH,
			fit = fit,
			btnY = btnY,
			shopCenterX = math.floor(
				(ViewportLayout.slotX(metrics, DOCK_TABS, SHOP_INDEX, SHOP_INDEX) + metrics.shopW * 0.5) * fit + 0.5
			),
		}
	end)

	local dockChildren: { Instance } = {}

	for i, tab in ipairs(DOCK_TABS) do
		local isShopTab = tab.isShop == true

		local btn = DockIcon.create(s, {
			name = "Tab_" .. tab.tabId,
			tabId = tab.tabId,
			iconKey = tab.iconKey,
			accent = tab.accent,
			widthScale = 1,
			activeTab = state.activeTab,
			panelOpen = state.panelOpen,
			isShop = isShopTab,
		})

		dockChildren[#dockChildren + 1] = s:New("Frame")({
			Name = "Slot" .. i,
			Size = s:Computed(function(use)
				local layout = use(dockLayout)
				local slotW = tabWidth(layout.metrics, tab) * layout.fit
				return UDim2.fromOffset(math.floor(slotW + 0.5), math.floor(layout.metrics.btnH * layout.fit + 0.5))
			end),
			Position = s:Computed(function(use)
				local layout = use(dockLayout)
				local x = ViewportLayout.slotX(layout.metrics, DOCK_TABS, SHOP_INDEX, i) * layout.fit
				return UDim2.fromOffset(math.floor(x + 0.5), layout.btnY)
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = if isShopTab then 4 else 2,
			[Children] = { btn },
		})
	end

	local homeHover = s:Value(false)
	local homePress = s:Value(false)

	local homeStack = s:New("Frame")({
		Name = "HomeStack",
		Size = s:Computed(function(use)
			local layout = use(dockLayout)
			local homeW = math.floor(132 * layout.fit + 0.5)
			local homeH = math.floor(38 * layout.fit + 0.5)
			local pad = math.floor(12 * layout.fit + 0.5)
			return UDim2.fromOffset(homeW + pad, homeH + pad)
		end),
		Position = s:Computed(function(use)
			local layout = use(dockLayout)
			local homeH = math.floor(38 * layout.fit + 0.5)
			return UDim2.fromOffset(layout.shopCenterX, -(homeH + math.floor(10 * layout.fit + 0.5)))
		end),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Visible = homeVisible,
		ZIndex = 9,
		[Children] = {
			s:New("Frame")({
				Name = "HomeGlow",
				Size = s:Computed(function(use)
					local layout = use(dockLayout)
					local homeW = math.floor(132 * layout.fit + 0.5)
					local homeH = math.floor(38 * layout.fit + 0.5)
					return UDim2.fromOffset(homeW + math.floor(6 * layout.fit + 0.5), homeH + math.floor(4 * layout.fit + 0.5))
				end),
				Position = UDim2.new(0.5, 0, 1, 0),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = C.primary,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				ZIndex = 1,
				[Children] = {
					s:New("UICorner")({ CornerRadius = theme.RADIUS.chip }),
					s:New("UIStroke")({
						Name = "GlowStroke",
						Color = ACCENTS.home,
						Thickness = theme.STROKE.medium,
						Transparency = 0.35,
					}),
				},
			}),
			s:New("TextButton")({
				Name = "HomePill",
				Size = s:Computed(function(use)
					local layout = use(dockLayout)
					return UDim2.fromOffset(
						math.floor(132 * layout.fit + 0.5),
						math.floor(38 * layout.fit + 0.5)
					)
				end),
				Position = UDim2.new(0.5, 0, 1, 0),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = ACCENTS.home,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Text = "",
				ZIndex = 2,
				[OnEvent("MouseEnter")] = function()
					homeHover:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					homeHover:set(false)
					homePress:set(false)
				end,
				[OnEvent("MouseButton1Down")] = function()
					homePress:set(true)
				end,
				[OnEvent("MouseButton1Up")] = function()
					homePress:set(false)
				end,
				[OnEvent("Activated")] = homeActivated,
				[Children] = {
					s:New("UICorner")({ CornerRadius = theme.RADIUS.btn }),
					s:New("UIStroke")({
						Color = C.btnBorder,
						Thickness = theme.STROKE.thick,
						Transparency = 0.1,
					}),
					s:New("UIGradient")({
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(148, 228, 255)),
							ColorSequenceKeypoint.new(1, ACCENTS.home),
						}),
						Rotation = 90,
					}),
					s:New("TextLabel")({
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "🏠 Домой",
						TextSize = s:Computed(function(use)
							local layout = use(dockLayout)
							return math.max(11, math.floor(13 * layout.fit + 0.5))
						end),
						Font = theme.FONT.title,
						TextColor3 = C.white,
						ZIndex = 3,
					}),
				},
			}),
		},
	})

	local dockInner: { Instance } = {
		s:New("UICorner")({ CornerRadius = theme.RADIUS.chip }),
		s:New("UIStroke")({ Color = C.dockBorder, Thickness = theme.STROKE.medium }),
		s:New("UIGradient")({
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 34, 56)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(14, 17, 30)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 10, 20)),
			}),
			Rotation = 90,
		}),
	}
	for _, child in dockChildren do
		dockInner[#dockInner + 1] = child
	end
	dockInner[#dockInner + 1] = homeStack

	local dockBottom = s:Value(ViewportLayout.dockBottomMargin())
	ViewportLayout.subscribe(function()
		dockBottom:set(ViewportLayout.dockBottomMargin())
	end, s)

	local dock = s:New("Frame")({
		Name = "LeftSidebar",
		Size = s:Computed(function(use)
			local layout = use(dockLayout)
			return UDim2.fromOffset(layout.dockW, layout.dockH)
		end),
		Position = s:Computed(function(use)
			return UDim2.new(0.5, 0, 1, -use(dockBottom))
		end),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = C.dockBg,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 8,
		ClipsDescendants = false,
		[Children] = dockInner,
	})

	UiMotion.defer(s, homeStack, function(stack)
		local pill = stack:FindFirstChild("HomePill") :: TextButton?
		if pill then
			UiMotion.bindHoverPress(s, pill, homeHover, homePress, { hoverScale = 1.06, pressScale = 0.94 })
		end
		local glow = stack:FindFirstChild("HomeGlow") :: Frame?
		local glowStroke = if glow then glow:FindFirstChild("GlowStroke") :: UIStroke? else nil
		if glowStroke then
			task.spawn(function()
				while glow and glow.Parent and peek(homeVisible) do
					TweenService:Create(
						glow,
						TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
						{ BackgroundTransparency = 0.68 }
					):Play()
					if glowStroke.Parent then
						TweenService:Create(
							glowStroke,
							TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
							{ Transparency = 0.55 }
						):Play()
					end
					task.wait(0.95)
					if not glow or not glow.Parent or not peek(homeVisible) then
						break
					end
					TweenService:Create(
						glow,
						TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
						{ BackgroundTransparency = 0.42 }
					):Play()
					if glowStroke.Parent then
						TweenService:Create(
							glowStroke,
							TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
							{ Transparency = 0.2 }
						):Play()
					end
					task.wait(0.95)
				end
			end)
		end
		return nil
	end)

	return dock
end

return LeftSidebar
