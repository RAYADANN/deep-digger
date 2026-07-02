--!strict
-- NavBtn для нижнего дока: иконка (30px) сверху + подпись (10px) снизу.
-- Sell-вариант: зелёная кнопка-CTA. Square-вариант (legacy): квадратная кнопка без подписи.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme        = require(script.Parent.Parent.theme)
local UiAssets     = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local UiMotion     = require(script.Parent.Parent.Parent.util.UiMotion)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local OnEvent  = Fusion.OnEvent
local Children = Fusion.Children
local peek     = Fusion.peek
local C        = theme.C
local ICON     = theme.ICON

export type Props = {
	name:        string,
	tabId:       string?,
	label:       string?,
	iconKey:     string,
	accent:      Color3,
	activeTab:   any?,
	panelOpen:   any?,
	showBadge:   any?,
	onActivated: (() -> ())?,
	isSell:      boolean?,
	isShop:      boolean?,
	widthScale:  number?,
}

local DockIcon = {}

function DockIcon.create(s: ScopeFactory.HudScope, props: Props)
	local iconPx = ViewportLayout.dockIconPx()
	local labelPx = ViewportLayout.dockLabelPx()
	local legacyPx = ViewportLayout.px(54)
	local isNav    = props.widthScale ~= nil
	local navW     = props.widthScale or 1
	local btnSize  = if isNav
		then UDim2.new(navW, 0, 1, 0)
		else UDim2.fromOffset(legacyPx, legacyPx)

	local isActive = if props.activeTab and props.panelOpen and props.tabId
		then s:Computed(function(use)
			return use(props.panelOpen) and use(props.activeTab) == props.tabId
		end)
		else s:Value(false)

	local hovering = s:Value(false)
	local pressing = s:Value(false)

	local iconImage = UiAssets.image(props.iconKey :: any)
	local label     = props.label or theme.TAB_LABELS[props.tabId or ""] or ""
	local isSell    = props.isSell == true
	local isShop    = props.isShop == true

	local function onActivated()
		if props.onActivated then
			props.onActivated()
			return
		end
		if not props.activeTab or not props.panelOpen or not props.tabId then return end
		if peek(props.panelOpen) and peek(props.activeTab) == props.tabId then
			props.panelOpen:set(false)
		else
			props.activeTab:set(props.tabId)
			props.panelOpen:set(true)
		end
	end

	local function wireMotion(btn: TextButton)
		UiMotion.bindHoverPress(s, btn, hovering, pressing, { hoverScale = 1.05, pressScale = 0.94 })
		if props.activeTab and props.panelOpen and props.tabId then
			UiMotion.watch(s, function()
				return peek(isActive)
			end, function(active)
				local activeBar = btn:FindFirstChild("ActiveBar") :: Frame?
				local activeBg = btn:FindFirstChild("ActiveBg") :: Frame?
				local icon = btn:FindFirstChild("Icon") :: ImageLabel?
				if activeBar then
					UiMotion.play(activeBar, { BackgroundTransparency = if active then 0 else 1 }, UiMotion.SNAP)
				end
				if activeBg then
					UiMotion.play(activeBg, { BackgroundTransparency = if active then 0.88 else 1 }, UiMotion.SNAP)
				end
				if icon then
					UiMotion.play(icon, {
						ImageTransparency = if active then 0 else ICON.inactiveAlpha,
					}, UiMotion.SNAP)
				end
			end)
		end
	end

	-- ── SELL ─────────────────────────────────────────────────────────────────
	if isSell and isNav then
		local sellBtn = s:New("TextButton")({
			Name            = props.name,
			Size            = btnSize,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text            = "",
			ZIndex          = 2,
			[Children] = {
				s:New("Frame")({
					Name            = "SellFace",
					Size            = UDim2.new(1, -10, 1, -12),
					Position        = UDim2.new(0, 5, 0, 6),
					BackgroundColor3 = C.sell,
					BorderSizePixel = 0,
					ZIndex          = 2,
					[Children] = {
						s:New("UICorner")({ CornerRadius = theme.RADIUS.btn }),
						s:New("UIStroke")({ Color = C.outlineDark, Thickness = 1.5, Transparency = 0.5 }),
						s:New("UIGradient")({
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
							}),
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0.70),
								NumberSequenceKeypoint.new(1, 0.92),
							}),
							Rotation = 90,
						}),
						s:New("ImageLabel")({
							Size            = UDim2.fromOffset(28, 28),
							Position        = UDim2.new(0.5, -14, 0, 7),
							BackgroundTransparency = 1,
							Image           = iconImage,
							ImageColor3     = ICON.tint,
							ScaleType       = Enum.ScaleType.Fit,
							ZIndex          = 3,
						}),
						s:New("TextLabel")({
							Size            = UDim2.new(1, 0, 0, 16),
							Position        = UDim2.new(0, 0, 1, -19),
							BackgroundTransparency = 1,
							Text            = label,
							TextSize        = labelPx,
							Font            = theme.FONT.title,
							TextColor3      = C.white,
							TextXAlignment  = Enum.TextXAlignment.Center,
							ZIndex          = 3,
						}),
					},
				}),
			},
			[OnEvent("MouseEnter")]       = function() hovering:set(true) end,
			[OnEvent("MouseLeave")]       = function() hovering:set(false); pressing:set(false) end,
			[OnEvent("MouseButton1Down")] = function() pressing:set(true) end,
			[OnEvent("MouseButton1Up")]   = function() pressing:set(false) end,
			[OnEvent("Activated")]        = onActivated,
		})
		UiMotion.defer(s, sellBtn, function(btn)
			wireMotion(btn)
			return nil
		end)
		return sellBtn
	end

	-- ── SHOP (центральный hero-CTA) ───────────────────────────────────────────
	if isShop and isNav then
		local shopActiveBg = s:Computed(function(use)
			return if use(isActive) then 0.82 else 1
		end)

		local shopBtn = s:New("TextButton")({
			Name            = props.name,
			Size            = btnSize,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text            = "",
			ZIndex          = 6,
			[Children] = {
				s:New("Frame")({
					Name            = "ShopGlow",
					Size            = UDim2.new(1, 4, 1, 4),
					Position        = UDim2.new(0, -2, 0, -2),
					BackgroundColor3 = props.accent,
					BackgroundTransparency = 0.62,
					BorderSizePixel = 0,
					ZIndex          = 1,
					[Children] = {
						s:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
						s:New("UIStroke")({
							Name = "GlowStroke",
							Color = C.goldHi,
							Thickness = 2,
							Transparency = 0.5,
						}),
					},
				}),
				s:New("Frame")({
					Name            = "ShopFace",
					Size            = UDim2.new(1, -10, 1, -10),
					Position        = UDim2.new(0, 5, 0, 5),
					BackgroundColor3 = props.accent,
					BackgroundTransparency = shopActiveBg,
					BorderSizePixel = 0,
					ZIndex          = 3,
					[Children] = {
						s:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
						s:New("UIStroke")({
							Color = C.gold,
							Thickness = 2,
							Transparency = s:Computed(function(use)
								return if use(isActive) then 0.05 else 0.2
							end),
						}),
						s:New("UIGradient")({
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 230)),
								ColorSequenceKeypoint.new(0.5, props.accent),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 150)),
							}),
							Rotation = 90,
						}),
						s:New("Frame")({
							Name = "ShopContent",
							Size = UDim2.new(1, -6, 1, -6),
							Position = UDim2.new(0, 3, 0, 3),
							BackgroundTransparency = 1,
							ZIndex = 4,
							[Children] = {
								s:New("UIListLayout")({
									FillDirection = Enum.FillDirection.Vertical,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									VerticalAlignment = Enum.VerticalAlignment.Center,
									Padding = UDim.new(0, 2),
									SortOrder = Enum.SortOrder.LayoutOrder,
								}),
								s:New("ImageLabel")({
									LayoutOrder = 1,
									Size = UDim2.fromOffset(iconPx, iconPx),
									BackgroundTransparency = 1,
									Image = iconImage,
									ImageColor3 = ICON.tint,
									ScaleType = Enum.ScaleType.Fit,
								}),
								s:New("TextLabel")({
									LayoutOrder = 2,
									AutomaticSize = Enum.AutomaticSize.XY,
									Size = UDim2.fromOffset(0, 0),
									BackgroundTransparency = 1,
									Text = label,
									TextSize = labelPx,
									Font = theme.FONT.title,
									TextColor3 = C.white,
									TextXAlignment = Enum.TextXAlignment.Center,
									TextYAlignment = Enum.TextYAlignment.Center,
									LineHeight = 1,
									[Children] = {
										s:New("UIStroke")({ Color = C.outlineDark, Thickness = 1, Transparency = 0.35 }),
									},
								}),
							},
						}),
					},
				}),
			},
			[OnEvent("MouseEnter")]       = function() hovering:set(true) end,
			[OnEvent("MouseLeave")]       = function() hovering:set(false); pressing:set(false) end,
			[OnEvent("MouseButton1Down")] = function() pressing:set(true) end,
			[OnEvent("MouseButton1Up")]   = function() pressing:set(false) end,
			[OnEvent("Activated")]        = onActivated,
		})
		UiMotion.defer(s, shopBtn, function(btn)
			UiMotion.bindHoverPress(s, btn, hovering, pressing, { hoverScale = 1.07, pressScale = 0.93 })
			local glow = btn:FindFirstChild("ShopGlow") :: Frame?
			local glowStroke = if glow then glow:FindFirstChild("GlowStroke") :: UIStroke? else nil
			if glowStroke then
				local pulse = UiMotion.pulseStroke(glowStroke, 0.25, 0.7, 1.6)
				return pulse.cancel
			end
			return nil
		end)
		return shopBtn
	end

	-- ── NAV BUTTON ────────────────────────────────────────────────────────────
	if isNav then
		local activeBarAlpha = s:Computed(function(use)
			return if use(isActive) then 0 else 1
		end)
		local activeBgAlpha = s:Computed(function(use)
			return if use(isActive) then 0.88 else 1
		end)
		local iconAlpha = s:Computed(function(use)
			return if use(isActive) then 0 else ICON.inactiveAlpha
		end)
		local labelColor = s:Computed(function(use)
			return if use(isActive) then props.accent else C.textMuted
		end)

		local navBtn = s:New("TextButton")({
			Name            = props.name,
			Size            = btnSize,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text            = "",
			ZIndex          = 2,
			[Children] = {
				-- верхний акцент-бар (активное состояние)
				s:New("Frame")({
					Name            = "ActiveBar",
					Size            = UDim2.new(0.5, 0, 0, 3),
					Position        = UDim2.new(0.25, 0, 0, 0),
					BackgroundColor3 = props.accent,
					BackgroundTransparency = activeBarAlpha,
					BorderSizePixel = 0,
					ZIndex          = 4,
					[Children] = { s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
				}),
				-- подсветка фона при активном состоянии
				s:New("Frame")({
					Name            = "ActiveBg",
					Size            = UDim2.new(0.8, 0, 0.78, 0),
					Position        = UDim2.new(0.1, 0, 0.11, 0),
					BackgroundColor3 = props.accent,
					BackgroundTransparency = activeBgAlpha,
					BorderSizePixel = 0,
					ZIndex          = 1,
					[Children] = { s:New("UICorner")({ CornerRadius = theme.RADIUS.btn }) },
				}),
				s:New("ImageLabel")({
					Name            = "Icon",
					Size            = UDim2.fromOffset(iconPx, iconPx),
					Position        = UDim2.new(0.5, -math.floor(iconPx * 0.5 + 0.5), 0, ViewportLayout.px(9)),
					BackgroundTransparency = 1,
					Image           = iconImage,
					ImageColor3     = ICON.tint,
					ImageTransparency = iconAlpha,
					ScaleType       = Enum.ScaleType.Fit,
					ZIndex          = 3,
				}),
				s:New("TextLabel")({
					Name            = "Label",
					Size            = UDim2.new(1, 0, 0, ViewportLayout.px(15)),
					Position        = UDim2.new(0, 0, 1, -ViewportLayout.px(18)),
					BackgroundTransparency = 1,
					Text            = label,
					TextSize        = labelPx,
					Font            = theme.FONT.body,
					TextColor3      = labelColor,
					TextXAlignment  = Enum.TextXAlignment.Center,
					ZIndex          = 3,
				}),
				if props.showBadge
					then s:New("Frame")({
						Name            = "Badge",
						Size            = UDim2.fromOffset(11, 11),
						Position        = UDim2.new(0.5, 8, 0, 8),
						BackgroundColor3 = C.mythic,
						BorderSizePixel = 0,
						Visible         = props.showBadge,
						ZIndex          = 5,
						[Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
							s:New("UIStroke")({ Color = C.dockBg, Thickness = 1.5 }),
						},
					})
					else nil,
			},
			[OnEvent("MouseEnter")]       = function() hovering:set(true) end,
			[OnEvent("MouseLeave")]       = function() hovering:set(false); pressing:set(false) end,
			[OnEvent("MouseButton1Down")] = function() pressing:set(true) end,
			[OnEvent("MouseButton1Up")]   = function() pressing:set(false) end,
			[OnEvent("Activated")]        = onActivated,
		})
		UiMotion.defer(s, navBtn, function(btn)
			wireMotion(btn)
			return nil
		end)
		return navBtn
	end

	-- ── LEGACY SQUARE (sidebar, без widthScale) ───────────────────────────────
	local legacyBtn = s:New("TextButton")({
		Name            = props.name,
		Size            = btnSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text            = "",
		[Children] = {
			s:New("Frame")({
				Name            = "BtnFace",
				Size            = UDim2.fromScale(1, 1),
				BackgroundColor3 = props.accent,
				BackgroundTransparency = s:Computed(function(use)
					return if use(isActive) then 0 else 0.08
				end),
				BorderSizePixel = 0,
				[Children] = {
					s:New("UICorner")({ CornerRadius = theme.RADIUS.navBtn }),
					s:New("UIStroke")({ Color = C.outlineDark, Thickness = 2, Transparency = 0 }),
					s:New("ImageLabel")({
						Size            = UDim2.fromOffset(40, 40),
						Position        = UDim2.new(0.5, -20, 0.5, -20),
						BackgroundTransparency = 1,
						Image           = iconImage,
						ImageColor3     = ICON.tint,
						ScaleType       = Enum.ScaleType.Fit,
						ZIndex          = 2,
					}),
					if props.showBadge
						then s:New("Frame")({
							Name            = "Badge",
							Size            = UDim2.fromOffset(13, 13),
							Position        = UDim2.new(1, -11, 0, -3),
							BackgroundColor3 = C.mythic,
							BorderSizePixel = 0,
							Visible         = props.showBadge,
							ZIndex          = 4,
							[Children] = {
								s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
								s:New("UIStroke")({ Color = C.outlineDark, Thickness = 2 }),
							},
						})
						else nil,
				},
			}),
		},
		[OnEvent("MouseEnter")]       = function() hovering:set(true) end,
		[OnEvent("MouseLeave")]       = function() hovering:set(false); pressing:set(false) end,
		[OnEvent("MouseButton1Down")] = function() pressing:set(true) end,
		[OnEvent("MouseButton1Up")]   = function() pressing:set(false) end,
		[OnEvent("Activated")]        = onActivated,
	})
	UiMotion.defer(s, legacyBtn, function(btn)
		UiMotion.bindHoverPress(s, btn, hovering, pressing, { hoverScale = 1.04, pressScale = 0.95 })
		return nil
	end)
	return legacyBtn
end

return DockIcon
