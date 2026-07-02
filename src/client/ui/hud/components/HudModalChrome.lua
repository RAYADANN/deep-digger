--!strict
-- Общая оболочка HUD-модалок: градиент, рамка, кнопка закрытия.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local PanelScale = require(script.Parent.Parent.PanelScale)
local UiIcon = require(script.Parent.UiIcon)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local C = theme.C
local sc = PanelScale.gsc

export type ShellProps = {
	accent: Color3,
	gradientTop: Color3,
	size: any,
	position: any,
	onClose: () -> (),
	children: { Instance }?,
	designSize: Vector2?,
	contentScale: any?,
}

local HudModalChrome = {}

local function px(n: number, designMode: boolean): number
	return if designMode then n else sc(n)
end

function HudModalChrome.closeButton(s: ScopeFactory.HudScope, onClose: () -> (), designMode: boolean?)
	local dm = designMode == true
	return s:New("TextButton")({
		Name = "CloseBtn",
		Size = UDim2.fromOffset(px(32, dm), px(32, dm)),
		Position = UDim2.new(1, -px(40, dm), 0, px(10, dm)),
		BackgroundColor3 = C.btnBg,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, px(8, dm)) }),
			s:New("UIStroke")({ Color = C.dockBorder, Thickness = 1, Transparency = 0.45 }),
			UiIcon.create(s, {
				source = "icon_close",
				size = UDim2.fromOffset(px(18, dm), px(18, dm)),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 6,
			}),
		},
		[OnEvent("Activated")] = onClose,
	})
end

function HudModalChrome.accentBar(s: ScopeFactory.HudScope, accent: Color3, designMode: boolean?)
	return s:New("Frame")({
		Name = "AccentBar",
		Size = UDim2.new(1, 0, 0, px(3, designMode == true)),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
end

function HudModalChrome.shell(s: ScopeFactory.HudScope, props: ShellProps)
	local inner = props.children or {}
	local designMode = props.designSize ~= nil and props.contentScale ~= nil
	local shellChildren: { Instance } = {
		s:New("UICorner")({ CornerRadius = UDim.new(0, px(14, designMode)) }),
		s:New("UIStroke")({ Color = props.accent, Thickness = px(2, designMode), Transparency = 0.12 }),
		s:New("UIGradient")({
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, props.gradientTop),
				ColorSequenceKeypoint.new(1, C.panelBg),
			}),
			Rotation = 90,
		}),
		HudModalChrome.accentBar(s, props.accent, designMode),
		HudModalChrome.closeButton(s, props.onClose, designMode),
	}
	if props.designSize and props.contentScale then
		local scaledChildren: { Instance } = {
			s:New("UIScale")({ Scale = props.contentScale }),
		}
		for _, child in ipairs(inner) do
			scaledChildren[#scaledChildren + 1] = child
		end
		shellChildren[#shellChildren + 1] = s:New("Frame")({
			Name = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = false,
			ZIndex = 3,
			[Children] = {
				s:New("Frame")({
					Name = "ScaledRoot",
					Size = UDim2.fromOffset(props.designSize.X, props.designSize.Y),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					[Children] = scaledChildren,
				}),
			},
		})
	else
		for _, child in ipairs(inner) do
			shellChildren[#shellChildren + 1] = child
		end
	end

	return s:New("Frame")({
		Name = "Modal",
		Size = props.size,
		Position = props.position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.panelBg,
		BorderSizePixel = 0,
		Active = true,
		ClipsDescendants = true,
		ZIndex = 2,
		[Children] = shellChildren,
	})
end

return HudModalChrome
