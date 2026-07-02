--!strict

-- Модал ввода и активации промокода.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek

local theme = require(script.Parent.hud.theme)
local UiIcon = require(script.Parent.hud.components.UiIcon)
local HudModalChrome = require(script.Parent.hud.components.HudModalChrome)
local RewardPreviewRow = require(script.Parent.hud.components.RewardPreviewRow)
local PromoCodeActions = require(script.Parent.hud.util.PromoCodeActions)
local ViewportLayout = require(script.Parent.util.ViewportLayout)
local PanelScale = require(script.Parent.hud.PanelScale)
local UiScreen = require(script.Parent.util.UiScreen)
local SoundManager = require(script.Parent.Parent.core.SoundManager)
local PromoCodes = require(ReplicatedStorage:WaitForChild("shared").data.PromoCodes)

local C = theme.C
local ACCENT = theme.TAB_ACCENTS.goals
local PAD = 18
local ROW_GAP = 10

local MODAL_GUI_NAME = "DeepDigger_PromoCodeModal"
local FADE_IN = 0.18
local FADE_OUT = 0.15
local DESIGN_W = 420
local DESIGN_H = 280

local L = {
	TITLE = 1,
	DESC = 2,
	REWARDS = 3,
	INPUT = 4,
	BTN = 5,
}

local PromoCodeModal = {}

export type Options = {
	scope: any,
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

local function sampleReward(): RewardPreviewRow.RewardTable
	local all = PromoCodes.getAll()
	local def = all[1]
	if def then
		return def.reward
	end
	return { coins = 5000, gems = 10 }
end

function PromoCodeModal.show(opts: Options): Handle?
	if _activeHandle then
		return _activeHandle
	end

	local parentScope = opts.scope
	local s = parentScope:innerScope()
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
	local codeDraft = ""
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
				gradientTop = Color3.fromRGB(48, 22, 38),
				size = modalSize,
				position = modalPos,
				onClose = doClose,
				designSize = Vector2.new(DESIGN_W, DESIGN_H),
				contentScale = fitScale,
				children = {
					s:New("Frame")({
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
								source = "icon_promo_code",
								text = "Промокод",
								textSize = s:Computed(function(use)
									return PanelScale.modalTsize(20, use(fitScale))
								end),
								font = Enum.Font.GothamBlack,
								textColor = ACCENT,
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
								LayoutOrder = L.DESC,
								Size = UDim2.new(1, 0, 0, 0),
								AutomaticSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								Text = "Введите код из соцсетей или стрима — награда начислится сразу.",
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
							RewardPreviewRow.create(s, {
								rewards = sampleReward(),
								layoutOrder = L.REWARDS,
								fitScale = fitScale,
							}),
							s:New("TextBox")({
								LayoutOrder = L.INPUT,
								Name = "CodeInput",
								Size = UDim2.new(1, 0, 0, s:Computed(function(use)
									return PanelScale.modalGsc(44, use(fitScale))
								end)),
								BackgroundColor3 = C.panelInner,
								BorderSizePixel = 0,
								ClearTextOnFocus = false,
								Font = Enum.Font.GothamBold,
								PlaceholderText = "Введите код…",
								PlaceholderColor3 = C.textMuted,
								Text = "",
								TextColor3 = C.textMain,
								TextSize = s:Computed(function(use)
									return PanelScale.modalTsize(15, use(fitScale))
								end),
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 4,
								[Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
									s:New("UIPadding")({
										PaddingLeft = UDim.new(0, 12),
										PaddingRight = UDim.new(0, 12),
									}),
									s:New("UIStroke")({ Color = ACCENT, Thickness = 1, Transparency = 0.55 }),
								},
								[OnEvent("Changed")] = function(rbx: TextBox)
									codeDraft = rbx.Text
								end,
							}),
							s:New("TextButton")({
								LayoutOrder = L.BTN,
								Size = UDim2.new(1, 0, 0, s:Computed(function(use)
									return PanelScale.modalGsc(46, use(fitScale))
								end)),
								BackgroundColor3 = s:Computed(function(use)
									return if use(isBusy) then C.btnDisabled else ACCENT
								end),
								BorderSizePixel = 0,
								Text = "АКТИВИРОВАТЬ",
								TextSize = s:Computed(function(use)
									return PanelScale.modalTsize(14, use(fitScale))
								end),
								Font = Enum.Font.GothamBlack,
								TextColor3 = Color3.fromRGB(30, 20, 50),
								AutoButtonColor = false,
								ZIndex = 4,
								[Children] = {
									s:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
									s:New("UIStroke")({ Color = C.white, Thickness = 1, Transparency = 0.75 }),
								},
								[OnEvent("Activated")] = function()
									SoundManager.play("ui_click")
									PromoCodeActions.tryRedeem(codeDraft, isBusy)
								end,
							}),
						},
					}),
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

return PromoCodeModal
