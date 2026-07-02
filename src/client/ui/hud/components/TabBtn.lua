--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
local ICON = theme.ICON

export type Props = {
	icon: string,
	label: string,
	tabId: string,
	activeTab: any,
	panelOpen: any,
	showBadge: any?,
}

local TabBtn = {}

function TabBtn.create(s: ScopeFactory.HudScope, props: Props)
	local isActive = s:Computed(function(use)
		return use(props.panelOpen) and use(props.activeTab) == props.tabId
	end)
	local hovering = s:Value(false)
	local pressing = s:Value(false)
	local uiScale = s:Computed(function(use)
		if use(pressing) then
			return 0.94
		end
		if use(hovering) and UserInputService.MouseEnabled then
			return 1.06
		end
		return 1
	end)
	local iconImage = UiAssets.resolve(props.icon)

	return s:New("TextButton")({
		Name = "Tab_" .. props.tabId,
		Size = UDim2.fromOffset(64, 68),
		BackgroundColor3 = s:Computed(function(use)
			return use(isActive) and C.tabActive or C.tabInactive
		end),
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Text = "",
		[Children] = {
			s:New("UIScale")({
				Scale = uiScale,
			}),
			s:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
			s:New("UIStroke")({
				Color = s:Computed(function(use)
					return use(isActive) and C.gold or C.tabBorder
				end),
				Thickness = s:Computed(function(use)
					return if use(isActive) then 2 else 1.5
				end),
				Transparency = 0.25,
			}),
			s:New("UIGradient")({
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 170)),
				}),
				Rotation = 90,
			}),
			s:New("ImageLabel")({
				Size = UDim2.fromOffset(30, 30),
				Position = UDim2.new(0.5, -15, 0, 8),
				BackgroundTransparency = 1,
				Image = iconImage,
				ImageColor3 = ICON.tint,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, -4, 0, 14),
				Position = UDim2.new(0, 2, 0, 44),
				BackgroundTransparency = 1,
				Text = props.label,
				TextSize = 9,
				Font = theme.FONT.body,
				TextColor3 = s:Computed(function(use)
					return use(isActive) and C.goldHi or C.textMuted
				end),
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 2,
			}),
			if props.showBadge
				then s:New("Frame")({
					Name = "Badge",
					Size = UDim2.fromOffset(10, 10),
					Position = UDim2.new(1, -12, 0, 6),
					BackgroundColor3 = C.mythic,
					BorderSizePixel = 0,
					Visible = props.showBadge,
					ZIndex = 4,
					[Children] = {
						s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					},
				})
				else nil,
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
		[OnEvent("Activated")] = function()
			if peek(props.panelOpen) and peek(props.activeTab) == props.tabId then
				props.panelOpen:set(false)
			else
				props.activeTab:set(props.tabId)
				props.panelOpen:set(true)
			end
		end,
	})
end

return TabBtn
