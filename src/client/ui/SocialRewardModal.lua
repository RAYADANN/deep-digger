--!strict

-- Модал бесплатной соц-награды (группа + избранное).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek

local HudStateModule = require(script.Parent.hud.HudState)
local theme = require(script.Parent.hud.theme)
local UiIcon = require(script.Parent.hud.components.UiIcon)
local HudModalChrome = require(script.Parent.hud.components.HudModalChrome)
local RewardPreviewRow = require(script.Parent.hud.components.RewardPreviewRow)
local SocialRewardActions = require(script.Parent.hud.util.SocialRewardActions)
local ViewportLayout = require(script.Parent.util.ViewportLayout)
local PanelScale = require(script.Parent.hud.PanelScale)
local UiScreen = require(script.Parent.util.UiScreen)
local SoundManager = require(script.Parent.Parent.core.SoundManager)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local C = theme.C
local ACCENT = theme.TAB_ACCENTS.shop
local PAD = 18
local ROW_GAP = 10

local MODAL_GUI_NAME = "DeepDigger_SocialRewardModal"
local FADE_IN = 0.18
local FADE_OUT = 0.15
local DESIGN_W = 440
local DESIGN_H = 400

local L = {
	TITLE = 1,
	SUBTITLE = 2,
	REWARDS = 3,
	STATUS = 4,
	DESC = 5,
	PAD_BEFORE_BTNS = 6,
	BTN_GROUP = 7,
	BTN_FAV = 8,
	PAD_BEFORE_CLAIM = 9,
	BTN_CLAIM = 10,
}

local SocialRewardModal = {}

export type Options = {
	scope: any,
	state: HudStateModule.HudState,
	onClose: (() -> ())?,
}

export type Handle = { close: (self: Handle) -> () }

local _activeHandle: Handle? = nil

local function ensureGui(): ScreenGui?
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	return UiScreen.ensure(pg, MODAL_GUI_NAME, "modal")
end

local function actionButton(s: any, label: string, layoutOrder: number, fitScale: any, onActivated: () -> ())
	return s:New("TextButton")({
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, s:Computed(function(use)
			return PanelScale.modalGsc(42, use(fitScale))
		end)),
		BackgroundColor3 = C.panelInner,
		BorderSizePixel = 0,
		Text = label,
		TextSize = s:Computed(function(use)
			return PanelScale.modalText(12, use(fitScale))
		end),
		Font = Enum.Font.GothamBold,
		TextColor3 = C.textMain,
		AutoButtonColor = false,
		ZIndex = 4,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
			s:New("UIStroke")({ Color = ACCENT, Thickness = 1, Transparency = 0.65 }),
		},
		[OnEvent("Activated")] = onActivated,
	})
end

local function modalBody(
	s: any,
	state: HudStateModule.HudState,
	rewards: RewardPreviewRow.RewardTable,
	isBusy: any,
	fitScale: any,
	onClaimSuccess: () -> ()
)
	return s:New("Frame")({
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
		[Children] = {
			s:New("UIPadding")({
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, PAD),
				PaddingRight = UDim.new(0, PAD),
			}),
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, ROW_GAP),
			}),
			UiIcon.titleRow(s, {
				source = "icon_social_reward",
				text = "Бесплатная награда",
				textSize = s:Computed(function(use)
					return PanelScale.modalTsize(20, use(fitScale))
				end),
				font = Enum.Font.GothamBlack,
				textColor = C.gold,
				size = UDim2.new(1, -54, 0, s:Computed(function(use)
					return PanelScale.modalGsc(32, use(fitScale))
				end)),
				iconSize = s:Computed(function(use)
					return PanelScale.modalGsc(26, use(fitScale))
				end),
				zIndex = 4,
				layoutOrder = L.TITLE,
			}),
			s:New("TextLabel")({
				LayoutOrder = L.SUBTITLE,
				Size = UDim2.new(1, 0, 0, s:Computed(function(use)
					return PanelScale.modalGsc(18, use(fitScale))
				end)),
				BackgroundTransparency = 1,
				Text = "Награда за поддержку",
				TextSize = s:Computed(function(use)
					return PanelScale.modalText(12, use(fitScale))
				end),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textLabel,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 4,
			}),
			RewardPreviewRow.create(s, {
				rewards = rewards,
				layoutOrder = L.REWARDS,
				fitScale = fitScale,
			}),
			s:New("TextLabel")({
				LayoutOrder = L.STATUS,
				Size = UDim2.new(1, 0, 0, s:Computed(function(use)
					return PanelScale.modalGsc(18, use(fitScale))
				end)),
				BackgroundTransparency = 1,
				Text = s:Computed(function(use)
					local social = use(state.socialReward) or {}
					return ("Группа %s   ·   Избранное %s"):format(
						SocialRewardActions.statusMark(social.inGroup == true),
						SocialRewardActions.statusMark(social.favoriteConfirmed == true)
					)
				end),
				TextSize = s:Computed(function(use)
					return PanelScale.modalText(12, use(fitScale))
				end),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textMain,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 4,
			}),
			s:New("TextLabel")({
				LayoutOrder = L.DESC,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = "Вступи в группу и добавь игру в избранное — затем забери подарок один раз.",
				TextSize = s:Computed(function(use)
					return PanelScale.modalText(12, use(fitScale))
				end),
				Font = Enum.Font.Gotham,
				TextColor3 = C.textSub,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 4,
			}),
			s:New("Frame")({
				LayoutOrder = L.PAD_BEFORE_BTNS,
				Size = UDim2.new(1, 0, 0, 4),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}),
			actionButton(s, "ВСТУПИТЬ В ГРУППУ", L.BTN_GROUP, fitScale, function()
				SoundManager.play("ui_click")
				SocialRewardActions.promptGroup(isBusy)
			end),
			actionButton(s, "ДОБАВИТЬ В ИЗБРАННОЕ", L.BTN_FAV, fitScale, function()
				SoundManager.play("ui_click")
				SocialRewardActions.promptFavorite(isBusy)
			end),
			s:New("Frame")({
				LayoutOrder = L.PAD_BEFORE_CLAIM,
				Size = UDim2.new(1, 0, 0, 4),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}),
			s:New("TextButton")({
				LayoutOrder = L.BTN_CLAIM,
				Size = UDim2.new(1, 0, 0, s:Computed(function(use)
					return PanelScale.modalGsc(46, use(fitScale))
				end)),
				BackgroundColor3 = s:Computed(function(use)
					local social = use(state.socialReward) or {}
					return if social.canClaim then C.gold else C.btnDisabled
				end),
				BackgroundTransparency = s:Computed(function(use)
					local social = use(state.socialReward) or {}
					return if social.canClaim then 0 else 0.25
				end),
				BorderSizePixel = 0,
				Text = "ЗАБРАТЬ НАГРАДУ",
				TextSize = s:Computed(function(use)
					return PanelScale.modalTsize(14, use(fitScale))
				end),
				Font = Enum.Font.GothamBlack,
				TextColor3 = Color3.fromRGB(40, 25, 0),
				AutoButtonColor = false,
				ZIndex = 4,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
					s:New("UIStroke")({ Color = C.goldHi, Thickness = 1, Transparency = 0.35 }),
				},
				[OnEvent("Activated")] = function()
					SoundManager.play("ui_click")
					SocialRewardActions.tryClaim(isBusy, function(success)
						if success then
							onClaimSuccess()
						end
					end)
				end,
			}),
		},
	})
end

function SocialRewardModal.show(opts: Options): Handle?
	if _activeHandle then
		return _activeHandle
	end

	local parentScope = opts.scope
	local s = parentScope:innerScope()
	local state = opts.state
	local gui = ensureGui()
	if not gui then
		return nil
	end

	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local isBusy = s:Value(false)
	local handle: any = { _closed = false }
	_activeHandle = handle
	local escConn: RBXScriptConnection? = nil
	local backdrop: Frame

	local function doClose()
		if handle._closed then
			return
		end
		handle._closed = true
		_activeHandle = nil
		if escConn then
			escConn:Disconnect()
			escConn = nil
		end
		if backdrop then
			TweenService:Create(backdrop, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad), {
				BackgroundTransparency = 1,
			}):Play()
			task.delay(FADE_OUT + 0.05, function()
				if backdrop and backdrop.Parent then
					backdrop:Destroy()
				end
				pcall(function()
					Fusion.doCleanup(s)
				end)
			end)
		end
		if opts.onClose then
			pcall(opts.onClose)
		end
	end

	handle.close = function()
		doClose()
	end

	local layoutEpoch = s:Value(0)
	ViewportLayout.subscribe(function()
		layoutEpoch:set(peek(layoutEpoch) + 1)
	end, s)

	local fitScale = s:Computed(function(use)
		use(layoutEpoch)
		local deskMax = if ViewportLayout.tier() == "desktop" then 1.7 else 1.0
		return ViewportLayout.fitModalScale(DESIGN_W, DESIGN_H, deskMax)
	end)

	local modalSize = s:Computed(function(use)
		use(layoutEpoch)
		local k = use(fitScale)
		return UDim2.fromOffset(math.floor(DESIGN_W * k + 0.5), math.floor(DESIGN_H * k + 0.5))
	end)

	local modalPos = s:Computed(function(use)
		use(layoutEpoch)
		local k = use(fitScale)
		return UDim2.new(0.5, 0, 0, ViewportLayout.modalCenterY(math.floor(DESIGN_H * k + 0.5)))
	end)

	local backdropSize = s:Computed(function(use)
		use(layoutEpoch)
		return UiScreen.backdropSize()
	end)

	local backdropPos = s:Computed(function(use)
		use(layoutEpoch)
		return UiScreen.backdropPosition()
	end)

	local rewards = ((Constants.SOCIAL_REWARD or {}).rewards or {}) :: RewardPreviewRow.RewardTable

	backdrop = s:New("Frame")({
		Name = "Backdrop",
		Size = backdropSize,
		Position = backdropPos,
		BackgroundColor3 = C.backdrop,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
		Active = true,
		ZIndex = 1,
		[Children] = {
			s:New("TextButton")({
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				[OnEvent("Activated")] = doClose,
			}),
			HudModalChrome.shell(s, {
				accent = ACCENT,
				gradientTop = Color3.fromRGB(36, 28, 58),
				size = modalSize,
				position = modalPos,
				onClose = doClose,
				designSize = Vector2.new(DESIGN_W, DESIGN_H),
				contentScale = fitScale,
				children = {
					modalBody(s, state, rewards, isBusy, fitScale, doClose),
				},
			}),
		},
	})

	TweenService:Create(backdrop, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 0.45,
	}):Play()

	escConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			doClose()
		end
	end)

	return handle
end

return SocialRewardModal
