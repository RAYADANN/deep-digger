--!strict
-- Модал покупки яйца у машины в Workspace.Eggs: шансы, пул питомцев, hatch 1×/10×.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local PetLogic = require(ReplicatedStorage:WaitForChild("shared").util.PetLogic)

local theme = require(script.Parent.hud.theme)
local Formatters = require(script.Parent.hud.formatters)
local UiIcon = require(script.Parent.hud.components.UiIcon)
local EggShopPetTile = require(script.Parent.hud.components.EggShopPetTile)
local EggShopEggPreview = require(script.Parent.hud.components.EggShopEggPreview)
local EggHatchFooter = require(script.Parent.hud.components.EggHatchFooter)
local EggShopLayout = require(script.Parent.EggShopLayout)
local Notification = require(script.Parent.Notification)
local SoundManager = require(script.Parent.Parent.core.SoundManager)
local PetHatchFX = require(script.Parent.PetHatchFX)
local ScopeFactory = require(script.Parent.hud.ScopeFactory)
local UiMotion = require(script.Parent.util.UiMotion)
local ViewportLayout = require(script.Parent.util.ViewportLayout)
local UiScreen = require(script.Parent.util.UiScreen)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek

local C = theme.C
local RARITY_COLOR = theme.RARITY_COLOR
local RARITY_ORDER = theme.RARITY_ORDER

local GUI_NAME = "DeepDigger_EggShopModal"
local HATCH_MAX = (Constants.PETS or {}).hatchBatchMax or 10

type EggModalLayout = EggShopLayout.Layout

local function countPoolPets(eggId: string): number
	return #PetLogic.getHatchOdds(eggId)
end

local EggShopModal = {}

export type EggDef = {
	id: string,
	name: string,
	icon: string?,
	modelName: string?,
	cost: number,
	accent: Color3?,
}

export type Options = {
	eggId: string,
	eggDef: EggDef,
	getCoins: () -> number,
	onClose: (() -> ())?,
}

export type Handle = { close: (self: Handle) -> () }

local _active: Handle? = nil
local _activeScope: any = nil
local _openEggId: string? = nil
local _rootScope = ScopeFactory.new()

local function ensureGui(): ScreenGui?
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	return UiScreen.ensure(pg, GUI_NAME, "modal")
end

local function formatPercent(value: number): string
	if value >= 10 then
		return ("%d%%"):format(math.floor(value + 0.5))
	end
	if value >= 1 then
		return ("%.1f%%"):format(value)
	end
	return ("%.2f%%"):format(value)
end

local function doHatch(eggDef: EggDef, count: number, isBusy: any, getCoins: () -> number)
	if peek(isBusy) then
		return
	end
	local n = math.clamp(math.floor(count), 1, HATCH_MAX)
	local cost = (eggDef.cost or 0) * n
	local coins = getCoins()
	if coins < cost then
		SoundManager.play("buy_fail")
		Notification.show({
			text = ("Не хватает %s монет"):format(Formatters.shortNumber(cost - coins)),
			icon = "icon_egg",
			color = Color3.fromRGB(255, 140, 60),
			duration = 2.5,
		})
		return
	end

	isBusy:set(true)
	task.spawn(function()
		local ok, result = pcall(function()
			return Net:Invoke("HatchEgg", eggDef.id, n)
		end)
		isBusy:set(false)
		if not ok then
			SoundManager.play("buy_fail")
			Notification.show({ text = "Сетевая ошибка", icon = "icon_warning", duration = 2.5 })
			return
		end
		if typeof(result) == "table" and result.success then
			SoundManager.play("sell_success")
			pcall(function()
				PetHatchFX.play(result.hatched, eggDef.modelName)
			end)
			return
		end
		if typeof(result) == "table" and result.message then
			SoundManager.play("buy_fail")
			Notification.show({
				text = result.message,
				icon = "icon_egg",
				color = Color3.fromRGB(255, 140, 60),
				duration = 2.5,
			})
		end
	end)
end

local function buildOddsRows(s: any, eggId: string, scale: number)
	local et = EggShopLayout.textMult()
	local function d(n: number): number
		return math.max(1, math.floor(n * scale + 0.5))
	end
	local function dt(n: number): number
		return math.max(1, math.floor(n * scale * et + 0.5))
	end
	local rowH = dt(24)
	local nameSize = math.clamp(dt(13), 11, 23)
	local pctSize = math.clamp(dt(13), 11, 24)
	local rows: { Instance } = {
		s:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, d(4)),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local order = 0
	for _, entry in ipairs(PetLogic.getHatchOdds(eggId)) do
		order += 1
		local color = RARITY_COLOR[entry.rarity] or C.common
		local pct = formatPercent(entry.percent)
		rows[#rows + 1] = s:New("Frame")({
			Name = "Odd_" .. entry.petId,
			Size = UDim2.new(1, 0, 0, rowH),
			BackgroundColor3 = C.bg3,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			LayoutOrder = order,
			[Children] = {
				s:New("UICorner")({ CornerRadius = theme.RADIUS.icon }),
				s:New("Frame")({
					Size = UDim2.new(0, d(4), 1, -d(8)),
					Position = UDim2.new(0, d(5), 0, d(4)),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					ZIndex = 2,
					[Children] = { s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
				}),
				s:New("TextLabel")({
					Size = UDim2.new(1, -d(72), 1, 0),
					Position = UDim2.new(0, d(14), 0, 0),
					BackgroundTransparency = 1,
					Text = entry.name,
					TextSize = nameSize,
					Font = theme.FONT.body,
					TextColor3 = C.textMain,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 2,
				}),
				s:New("TextLabel")({
					Size = UDim2.new(0, d(54), 1, 0),
					Position = UDim2.new(1, -d(58), 0, 0),
					BackgroundTransparency = 1,
					Text = pct,
					TextSize = pctSize,
					Font = Enum.Font.GothamBlack,
					TextColor3 = color,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 2,
				}),
			},
		})
	end
	if order == 0 then
		rows[#rows + 1] = s:New("TextLabel")({
			Size = UDim2.new(1, 0, 0, rowH),
			BackgroundTransparency = 1,
			Text = "Шансы не настроены",
			TextSize = nameSize,
			Font = theme.FONT.body,
			TextColor3 = C.textMuted,
		})
	end
	return rows
end

local function buildPetPool(s: any, eggId: string, layout: EggModalLayout)
	local petCount = countPoolPets(eggId)
	local cellW, cellH = EggShopLayout.poolGrid(
		petCount,
		layout.poolW,
		layout.poolH,
		layout.poolPad,
		layout.gridGap,
		layout.scale
	)
	local children: { Instance } = {
		s:New("UIGridLayout")({
			CellSize = UDim2.fromOffset(cellW, cellH),
			CellPadding = UDim2.new(0, layout.gridGap, 0, layout.gridGap),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local order = 0
	for _, entry in ipairs(PetLogic.getHatchOdds(eggId)) do
		order += 1
		children[#children + 1] = EggShopPetTile.create(s, {
			petId = entry.petId,
			layoutOrder = (RARITY_ORDER[entry.rarity] or 99) * 100 + order,
			cellH = cellH,
			percent = entry.percent,
		})
	end
	return children
end

function EggShopModal.isOpenForEgg(eggId: string): boolean
	if _openEggId ~= eggId or not _active then
		return false
	end
	local handle = _active :: any
	return handle._closed ~= true
end

function EggShopModal.close()
	if _active then
		_active:close()
	end
end

local function forceClose()
	if not _active then
		return
	end
	local handle = _active
	_active = nil
	_openEggId = nil
	handle._closed = true
	local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = pg and pg:FindFirstChild(GUI_NAME)
	if gui then
		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	if _activeScope then
		pcall(function()
			Fusion.doCleanup(_activeScope)
		end)
		_activeScope = nil
	end
end

function EggShopModal.show(opts: Options): Handle?
	if EggShopModal.isOpenForEgg(opts.eggId) then
		return _active
	end
	forceClose()
	local gui = ensureGui()
	if not gui then
		return nil
	end

	local s = _rootScope:innerScope()
	_activeScope = s
	_openEggId = opts.eggId
	local eggDef = opts.eggDef
	local accent = eggDef.accent or C.gem
	local isBusy = s:Value(false)
	local handle: any = { _closed = false }
	_active = handle

	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local escConn: RBXScriptConnection? = nil

	local function doClose()
		if handle._closed then
			return
		end
		handle._closed = true
		_active = nil
		_activeScope = nil
		_openEggId = nil
		if escConn then
			escConn:Disconnect()
			escConn = nil
		end
		local root = gui:FindFirstChild("Root")
		if root and root:IsA("Frame") then
			TweenService:Create(root, UiMotion.MODAL_OUT, {
				BackgroundTransparency = 1,
			}):Play()
			local modal = root:FindFirstChild("Modal")
			if modal and modal:IsA("GuiObject") then
				TweenService:Create(modal, UiMotion.MODAL_OUT, {
					BackgroundTransparency = 1,
				}):Play()
			end
			task.delay(0.18, function()
				if root.Parent then
					root:Destroy()
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
	handle.close = doClose

	-- modalPixels уже ограничивает высоту playableHeight (вьюпорт минус верхний
	-- системный вырез), а modalCenterY центрирует окно внутри safe-полосы и
	-- клампит края — поэтому нижний ряд футера (2×2 hatch) всегда на экране.
	-- Локальный клэмп высоты больше не нужен: логика централизована в ViewportLayout.
	local eggW, eggH = ViewportLayout.modalPixels(EggShopLayout.MODAL_W, EggShopLayout.MODAL_H)
	local modalCenterY = ViewportLayout.modalCenterY(eggH)
	local layout = EggShopLayout.compute(eggW, eggH)
	local et = EggShopLayout.textMult()
	local function d(n: number): number
		return math.max(1, math.floor(n * layout.scale + 0.5))
	end
	-- dt: размер текста тела модалки (десктоп ×1.5); коробки под него растут в
	-- EggShopLayout через dt(), поэтому крупный шрифт не обрезается.
	local function dt(n: number): number
		return math.max(1, math.floor(n * layout.scale * et + 0.5))
	end
	local headerIconPx = d(22)
	local closePx = d(30)

	local eggViewportHost = EggShopEggPreview.create(s, {
		modelName = eggDef.modelName,
		accent = accent,
		icon = eggDef.icon,
		size = layout.previewSize,
		position = UDim2.fromOffset(layout.previewX, layout.previewY),
	})

	local root = s:New("Frame")({
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
		[Children] = {
			s:New("TextButton")({
				Name = "Backdrop",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 1,
				[OnEvent("Activated")] = function()
					SoundManager.play("ui_click")
					doClose()
				end,
			}),
			s:New("Frame")({
				Name = "Modal",
				Size = UDim2.fromOffset(eggW, eggH),
				Position = UDim2.new(0.5, 0, 0, modalCenterY),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = C.panelBg,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = theme.RADIUS.panel }),
					s:New("UIStroke")({ Color = accent, Thickness = 2, Transparency = 0.25 }),
					s:New("Frame")({
						Name = "Header",
						Size = UDim2.new(1, 0, 0, layout.headerH),
						BackgroundColor3 = accent,
						BackgroundTransparency = 0.82,
						BorderSizePixel = 0,
						ZIndex = 3,
						[Children] = {
							s:New("UICorner")({ CornerRadius = theme.RADIUS.panel }),
							UiIcon.create(s, {
								source = eggDef.icon or "icon_egg",
								size = UDim2.fromOffset(headerIconPx, headerIconPx),
								position = UDim2.new(0, layout.sidePad, 0.5, -math.floor(headerIconPx / 2)),
								zIndex = 4,
							}),
							s:New("TextLabel")({
								Size = UDim2.new(1, -(layout.sidePad * 2 + headerIconPx + closePx + d(20)), 1, 0),
								Position = UDim2.new(0, layout.sidePad + headerIconPx + d(8), 0, 0),
								BackgroundTransparency = 1,
								Text = (eggDef.name or "Яйцо"):upper(),
								TextSize = math.clamp(dt(16), 13, 29),
								Font = Enum.Font.GothamBlack,
								TextColor3 = C.textMain,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								ZIndex = 4,
							}),
							s:New("TextButton")({
								Name = "Close",
								Size = UDim2.fromOffset(closePx, closePx),
								Position = UDim2.new(1, -(layout.sidePad + closePx), 0.5, -math.floor(closePx / 2)),
								BackgroundColor3 = C.closeBg,
								BackgroundTransparency = 0.15,
								BorderSizePixel = 0,
								Text = "",
								ZIndex = 5,
								[Children] = {
									s:New("UICorner")({ CornerRadius = theme.RADIUS.icon }),
									UiIcon.create(s, {
										source = "icon_close",
										size = UDim2.fromOffset(math.floor(closePx * 0.44), math.floor(closePx * 0.44)),
										position = UDim2.new(0.5, -math.floor(closePx * 0.22), 0.5, -math.floor(closePx * 0.22)),
										zIndex = 6,
									}),
								},
								[OnEvent("Activated")] = function()
									SoundManager.play("ui_click")
									doClose()
								end,
							}),
						},
					}),
					eggViewportHost,
					s:New("Frame")({
						Name = "RightPanel",
						Size = UDim2.new(0, layout.rightW, 0, layout.rightH),
						Position = UDim2.fromOffset(layout.rightX, layout.rightY),
						BackgroundTransparency = 1,
						ZIndex = 3,
						[Children] = {
							s:New("TextLabel")({
								Size = UDim2.new(1, 0, 0, layout.costLabelH),
								BackgroundTransparency = 1,
								Text = "СТОИМОСТЬ",
								TextSize = math.clamp(dt(12), 10, 20),
								Font = theme.FONT.label,
								TextColor3 = C.textSub,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 3,
							}),
							s:New("Frame")({
								Size = UDim2.new(1, 0, 0, layout.costBoxH),
								Position = UDim2.new(0, 0, 0, layout.costLabelH),
								BackgroundColor3 = C.goldBg,
								BorderSizePixel = 0,
								ZIndex = 3,
								[Children] = {
									s:New("UICorner")({ CornerRadius = theme.RADIUS.icon }),
									s:New("UIStroke")({ Color = C.gold, Thickness = 1.5, Transparency = 0.4 }),
									UiIcon.create(s, {
										source = "coin",
										size = UDim2.fromOffset(d(18), d(18)),
										position = UDim2.new(0, d(10), 0.5, -d(9)),
										zIndex = 4,
									}),
									s:New("TextLabel")({
										Size = UDim2.new(1, -(d(20) + d(18)), 1, 0),
										Position = UDim2.new(0, d(14) + d(18), 0, 0),
										BackgroundTransparency = 1,
										Text = Formatters.shortNumber(eggDef.cost or 0),
										TextSize = math.clamp(dt(15), 12, 27),
										Font = Enum.Font.GothamBlack,
										TextColor3 = C.gold,
										TextXAlignment = Enum.TextXAlignment.Left,
										ZIndex = 4,
									}),
								},
							}),
							s:New("TextLabel")({
								Size = UDim2.new(1, 0, 0, layout.oddsLabelH),
								Position = UDim2.new(0, 0, 0, layout.costLabelH + layout.costBoxH + d(6)),
								BackgroundTransparency = 1,
								Text = "ШАНСЫ ВЫПАДЕНИЯ",
								TextSize = math.clamp(dt(12), 10, 20),
								Font = theme.FONT.label,
								TextColor3 = C.textSub,
								TextXAlignment = Enum.TextXAlignment.Left,
								ZIndex = 3,
							}),
							s:New("ScrollingFrame")({
								Name = "OddsList",
								Size = UDim2.new(1, 0, 0, layout.oddsListH),
								Position = UDim2.new(0, 0, 0, layout.oddsListY),
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								ScrollBarThickness = math.max(3, d(3)),
								ScrollBarImageColor3 = accent,
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								CanvasSize = UDim2.new(),
								ZIndex = 3,
								[Children] = buildOddsRows(s, opts.eggId, layout.scale),
							}),
						},
					}),
					s:New("TextLabel")({
						Size = UDim2.new(1, -layout.sidePad * 2, 0, layout.poolLabelH),
						Position = UDim2.new(0, layout.sidePad, 0, layout.poolLabelY),
						BackgroundTransparency = 1,
						Text = "ВОЗМОЖНЫЕ ПИТОМЦЫ",
						TextSize = math.clamp(dt(12), 10, 21),
						Font = theme.FONT.label,
						TextColor3 = C.textSub,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 3,
					}),
					s:New("ScrollingFrame")({
						Name = "PetPool",
						Size = UDim2.new(1, -layout.sidePad * 2, 0, layout.poolH),
						Position = UDim2.new(0, layout.sidePad, 0, layout.poolY),
						BackgroundColor3 = C.bg2,
						BackgroundTransparency = 0.35,
						BorderSizePixel = 0,
						ScrollBarThickness = math.max(3, d(4)),
						ScrollBarImageColor3 = accent,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(),
						ZIndex = 3,
						[Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(0, d(10)) }),
							s:New("UIPadding")({
								PaddingTop = UDim.new(0, layout.poolPad),
								PaddingLeft = UDim.new(0, layout.poolPad),
								PaddingRight = UDim.new(0, layout.poolPad),
								PaddingBottom = UDim.new(0, layout.poolPad),
							}),
							buildPetPool(s, opts.eggId, layout),
						},
					}),
					EggHatchFooter.create(s, {
						eggId = opts.eggId,
						eggCost = eggDef.cost or 0,
						hatchMax = HATCH_MAX,
						getCoins = opts.getCoins,
						isBusy = isBusy,
						footerH = layout.footerH,
						sidePad = layout.sidePad,
						footerPad = layout.footerPad,
						onCoinHatch = function(count: number)
							SoundManager.play("ui_click")
							doHatch(eggDef, count, isBusy, opts.getCoins)
						end,
					}),
				},
			}),
		},
	})

	local backdrop = root:FindFirstChild("Backdrop")
	if backdrop and backdrop:IsA("GuiObject") then
		backdrop.BackgroundTransparency = 1
	end
	local modal = root:FindFirstChild("Modal")
	if modal and modal:IsA("GuiObject") then
		modal.BackgroundTransparency = 0
	end

	escConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or handle._closed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			doClose()
		end
	end)

	return handle
end

return EggShopModal
