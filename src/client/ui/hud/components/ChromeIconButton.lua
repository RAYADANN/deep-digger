--!strict
-- Квадратная HUD-кнопка с иконкой для верхнего хрома.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
local ICON = theme.ICON

export type Props = {
	name: string,
	iconKey: string,
	accent: Color3,
	size: any?,
	position: any?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	visible: any?,
	showPulse: any?,
	showBadge: any?,
	tooltip: string?,
	onActivated: () -> (),
	zIndex: number?,
}

local ChromeIconButton = {}

function ChromeIconButton.create(s: ScopeFactory.HudScope, props: Props)
	local hovering = s:Value(false)
	local pressing = s:Value(false)
	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local defaultSize = s:Computed(function(use)
		use(layoutEpoch)
		local px = ViewportLayout.chromePx(40)
		return UDim2.fromOffset(px, px)
	end)

	local iconPx = s:Computed(function(use)
		use(layoutEpoch)
		return math.max(18, ViewportLayout.chromePx(26))
	end)

	local cornerPx = s:Computed(function(use)
		use(layoutEpoch)
		return math.max(8, ViewportLayout.chromePx(12))
	end)

	local iconImage = UiAssets.image(props.iconKey :: any)

	local root = s:New("TextButton")({
		Name = props.name,
		Size = props.size or defaultSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Visible = props.visible,
		ZIndex = props.zIndex or 8,
		[Children] = {
			s:New("Frame")({
				Name = "Glow",
				Size = UDim2.new(1, 4, 1, 4),
				Position = UDim2.new(0, -2, 0, -2),
				BackgroundColor3 = props.accent,
				BackgroundTransparency = s:Computed(function(use)
					if props.showPulse and use(props.showPulse) then
						return 0.58
					end
					return 1
				end),
				BorderSizePixel = 0,
				ZIndex = 1,
				[Children] = {
					s:New("UICorner")({
						CornerRadius = s:Computed(function(use)
							return UDim.new(0, use(cornerPx) + 2)
						end),
					}),
					s:New("UIStroke")({
						Name = "GlowStroke",
						Color = C.goldHi,
						Thickness = 2,
						Transparency = s:Computed(function(use)
							if props.showPulse and use(props.showPulse) then
								return 0.55
							end
							return 1
						end),
					}),
				},
			}),
			s:New("Frame")({
				Name = "Face",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = C.bgChip,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({
						CornerRadius = s:Computed(function(use)
							return UDim.new(0, use(cornerPx))
						end),
					}),
					s:New("UIStroke")({
						Color = s:Computed(function(use)
							if props.showPulse and use(props.showPulse) then
								return props.accent
							end
							return C.dockBorder
						end),
						Thickness = theme.STROKE.medium,
						Transparency = s:Computed(function(use)
							if props.showPulse and use(props.showPulse) then
								return 0.15
							end
							return 0.35
						end),
					}),
					s:New("ImageLabel")({
						Name = "Icon",
						Size = s:Computed(function(use)
							local px = use(iconPx)
							return UDim2.fromOffset(px, px)
						end),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = iconImage,
						ImageColor3 = ICON.tint,
						ScaleType = Enum.ScaleType.Fit,
						ZIndex = 3,
					}),
					if props.showBadge
						then s:New("Frame")({
							Name = "Badge",
							Size = UDim2.fromOffset(10, 10),
							Position = UDim2.new(1, -4, 0, -2),
							AnchorPoint = Vector2.new(1, 0),
							BackgroundColor3 = C.mythic,
							BorderSizePixel = 0,
							Visible = props.showBadge,
							ZIndex = 4,
							[Children] = {
								s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
								s:New("UIStroke")({ Color = C.dockBg, Thickness = 1.5 }),
							},
						})
						else nil,
				},
			}),
		},
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
		[OnEvent("Activated")] = props.onActivated,
	})

	UiMotion.defer(s, root, function(btn)
		UiMotion.bindHoverPress(s, btn, hovering, pressing, { hoverScale = 1.06, pressScale = 0.92 })
		if not props.showPulse then
			return nil
		end
		local glow = btn:FindFirstChild("Glow") :: Frame?
		local glowStroke = if glow then glow:FindFirstChild("GlowStroke") :: UIStroke? else nil
		local activePulse: (() -> ())? = nil
		UiMotion.watch(s, function()
			return props.showPulse and peek(props.showPulse) == true
		end, function(active)
			if activePulse then
				activePulse()
				activePulse = nil
			end
			if active and glowStroke then
				local pulse = UiMotion.pulseStroke(glowStroke, 0.25, 0.7, 1.6)
				activePulse = pulse.cancel
			elseif glow then
				glow.BackgroundTransparency = 1
			end
		end)
		return function()
			if activePulse then
				activePulse()
			end
		end
	end)

	return root
end

return ChromeIconButton
