--!strict
-- Полноэкранный hatch: 3D-яйцо (ViewportFrame) + reveal-карточки с 3D-питомцами.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetLogic = require(ReplicatedStorage:WaitForChild("shared").util.PetLogic)
local PetDatabase = require(ReplicatedStorage:WaitForChild("shared").data.PetDatabase)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local PetModelKit = require(ReplicatedStorage:WaitForChild("shared").util.PetModelKit)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local UiScreen = require(script.Parent.util.UiScreen)

local PetHatchFX = {}

local FX_GUI_NAME = "DeepDigger_PetHatchFX"

-- Масштаб всего hatch-UI (карточки, заголовок). Яйцо — отдельно ×2.
local UI_SCALE = 1.42
local EGG_SIZE_MULT = 2

local function sc(n: number): number
	return math.floor(n * UI_SCALE + 0.5)
end

-- Фаза встряхивания / раскрытия яйца (+~0.5 с к прежней).
local SHAKE_COUNT = 7
local SHAKE_TWEEN = 0.13
local SHAKE_WAIT = 0.14
local PRE_CRACK_WAIT = 0.15
local CRACK_DURATION = 0.3

local RARITY_COLOR: { [string]: Color3 } = {
	common = Color3.fromRGB(200, 200, 200),
	uncommon = Color3.fromRGB(120, 230, 120),
	rare = Color3.fromRGB(80, 160, 255),
	epic = Color3.fromRGB(200, 80, 240),
	legendary = Color3.fromRGB(255, 180, 30),
	mythic = Color3.fromRGB(255, 70, 70),
}

local RARITY_WEIGHT = {
	common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6,
}

local _activeGui: ScreenGui? = nil

local function defaultEggModelName(): string
	local egg = (Constants.PETS or {}).eggs and Constants.PETS.eggs.basic
	return (egg and egg.modelName) or "Basic"
end

local function getPlayerGui(): Instance?
	local player = Players.LocalPlayer
	return player and player:FindFirstChildOfClass("PlayerGui")
end

local function bestRarity(hatched: { any }): string
	local best = "common"
	local bestW = 0
	for _, p in ipairs(hatched) do
		local r = p.rarity or "common"
		local w = RARITY_WEIGHT[r] or 1
		if w > bestW then
			bestW = w
			best = r
		end
	end
	return best
end

local function shockwave(parent: Instance, color: Color3, delay: number, ringSize: number)
	task.delay(delay, function()
		if not parent.Parent then
			return
		end
		local ring = Instance.new("Frame")
		ring.Size = UDim2.fromOffset(sc(20), sc(20))
		ring.Position = UDim2.fromScale(0.5, 0.42)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.BackgroundTransparency = 1
		ring.BorderSizePixel = 0
		ring.ZIndex = 6
		ring.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = ring
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = sc(4)
		stroke.Transparency = 0.05
		stroke.Parent = ring
		local dur = 0.55
		TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(ringSize, ringSize),
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Thickness = 1,
		}):Play()
		Debris:AddItem(ring, dur + 0.15)
	end)
end

local function revealCard(
	parent: Instance,
	def: PetDatabase.Pet,
	layoutOrder: number,
	big: boolean,
	popDelay: number
): { destroy: () -> () }
	local color = RARITY_COLOR[def.rarity] or RARITY_COLOR.common
	local w = if big then sc(200) else sc(96)
	local h = if big then sc(240) else sc(116)

	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(0, 0)
	card.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.ZIndex = 7
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, sc(10))
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = if big then sc(3) else sc(2)
	stroke.Transparency = 0.1
	stroke.Parent = card

	local previewHost = Instance.new("Frame")
	previewHost.Size = UDim2.new(1, -sc(8), 0, if big then sc(120) else sc(56))
	previewHost.Position = UDim2.new(0, sc(4), 0, if big then sc(10) else sc(6))
	previewHost.BackgroundTransparency = 1
	previewHost.ZIndex = 8
	previewHost.Parent = card

	local viewportCleanup: (() -> ())? = nil
	if big then
		local display = PetModelKit.clonePetDisplay(def.modelName, PetModelKit.displayHeights().card)
		if display then
			local mounted = PetModelKit.mountInViewport(previewHost, display, 5.5)
			viewportCleanup = mounted.destroy
		end
	end
	if not viewportCleanup then
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(1, 1)
		icon.BackgroundTransparency = 1
		icon.Text = def.icon
		icon.TextScaled = true
		icon.Font = Enum.Font.GothamBold
		icon.TextColor3 = color
		icon.ZIndex = 8
		icon.Parent = previewHost
	end

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -sc(8), 0, if big then sc(28) else sc(16))
	name.Position = UDim2.new(0, sc(4), 0, if big then sc(142) else sc(66))
	name.BackgroundTransparency = 1
	name.Text = def.name
	name.TextScaled = big
	name.TextSize = sc(12)
	name.Font = Enum.Font.GothamBlack
	name.TextColor3 = Color3.fromRGB(240, 235, 220)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 8
	name.Parent = card

	local effect = Instance.new("TextLabel")
	effect.Size = UDim2.new(1, -sc(8), 0, if big then sc(24) else sc(16))
	effect.Position = UDim2.new(0, sc(4), 0, if big then sc(176) else sc(84))
	effect.BackgroundTransparency = 1
	effect.Text = PetLogic.effectShort(def.effect)
	effect.TextSize = if big then sc(14) else sc(10)
	effect.Font = Enum.Font.GothamBold
	effect.TextColor3 = color
	effect.ZIndex = 8
	effect.Parent = card

	task.delay(popDelay, function()
		if not card.Parent then
			return
		end
		TweenService:Create(card, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(w, h),
		}):Play()
	end)

	return {
		destroy = function()
			if viewportCleanup then
				viewportCleanup()
			end
		end,
	}
end

local function dismiss(gui: ScreenGui, cleanups: { () -> () }?)
	if _activeGui == gui then
		_activeGui = nil
	end
	if cleanups then
		for _, fn in ipairs(cleanups) do
			pcall(fn)
		end
	end
	if not gui.Parent then
		return
	end
	local backdrop = gui:FindFirstChild("Backdrop")
	if backdrop and backdrop:IsA("Frame") then
		TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
	end
	task.delay(0.22, function()
		if gui then
			gui:Destroy()
		end
	end)
end

function PetHatchFX.play(hatched: { any }?, eggModelName: string?)
	local ok, err = pcall(function()
		if typeof(hatched) ~= "table" or #hatched == 0 then
			return
		end
		local pg = getPlayerGui()
		if not pg then
			return
		end

		if _activeGui and _activeGui.Parent then
			_activeGui:Destroy()
		end

		local cleanups: { () -> () } = {}
		local gui = Instance.new("ScreenGui")
		gui.Name = FX_GUI_NAME
		UiScreen.apply(gui, "fx")
		gui.Parent = pg
		_activeGui = gui

		local backdrop = Instance.new("Frame")
		backdrop.Name = "Backdrop"
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		backdrop.BackgroundTransparency = 1
		backdrop.BorderSizePixel = 0
		backdrop.ZIndex = 1
		backdrop.Parent = gui
		TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()

		local skipBtn = Instance.new("TextButton")
		skipBtn.Size = UDim2.fromScale(1, 1)
		skipBtn.BackgroundTransparency = 1
		skipBtn.Text = ""
		skipBtn.ZIndex = 2
		skipBtn.Parent = backdrop
		skipBtn.Activated:Connect(function()
			dismiss(gui, cleanups)
		end)

		local color = RARITY_COLOR[bestRarity(hatched)] or RARITY_COLOR.common
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1024, 768)
		local maxScale = math.max(viewport.X, viewport.Y)
		local shockA = math.min(sc(300), maxScale * 0.34)
		local shockB = math.min(sc(400), maxScale * 0.44)

		local eggHost = Instance.new("Frame")
		eggHost.Size = UDim2.fromOffset(sc(180) * EGG_SIZE_MULT, sc(180) * EGG_SIZE_MULT)
		eggHost.Position = UDim2.fromScale(0.5, 0.42)
		eggHost.AnchorPoint = Vector2.new(0.5, 0.5)
		eggHost.BackgroundTransparency = 1
		eggHost.ZIndex = 5
		eggHost.Parent = backdrop

		local eggModelNameResolved = eggModelName or defaultEggModelName()
		local eggFallback = Instance.new("ImageLabel")
		eggFallback.Size = UDim2.fromScale(1, 1)
		eggFallback.BackgroundTransparency = 1
		eggFallback.Image = UiAssets.image("icon_egg")
		eggFallback.ScaleType = Enum.ScaleType.Fit
		eggFallback.ZIndex = 5
		eggFallback.Parent = eggHost

		task.defer(function()
			if not eggHost.Parent then
				return
			end
			local eggDisplay = PetModelKit.cloneEggDisplay(eggModelNameResolved)
			if not eggDisplay then
				return
			end
			eggFallback:Destroy()
			local eggMounted = PetModelKit.mountInViewport(eggHost, eggDisplay, 4.8 * 0.92)
			table.insert(cleanups, eggMounted.destroy)
		end)

		task.spawn(function()
			for i = 1, SHAKE_COUNT do
				local ang = (i % 2 == 0) and 14 or -14
				TweenService:Create(eggHost, TweenInfo.new(SHAKE_TWEEN, Enum.EasingStyle.Sine), { Rotation = ang }):Play()
				task.wait(SHAKE_WAIT)
			end
			TweenService:Create(eggHost, TweenInfo.new(0.1), { Rotation = 0 }):Play()
			task.wait(PRE_CRACK_WAIT)
			TweenService:Create(eggHost, TweenInfo.new(CRACK_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.fromOffset(sc(40) * EGG_SIZE_MULT, sc(40) * EGG_SIZE_MULT),
			}):Play()
			shockwave(backdrop, color, 0, shockA)
			shockwave(backdrop, color, 0.14, shockB)

			local title = Instance.new("TextLabel")
			title.Size = UDim2.fromOffset(sc(360), sc(30))
			title.Position = UDim2.fromScale(0.5, 0.16)
			title.AnchorPoint = Vector2.new(0.5, 0.5)
			title.BackgroundTransparency = 1
			title.Text = if #hatched > 1
				then ("Вылупилось питомцев: %d"):format(#hatched)
				else "Новый питомец!"
			title.TextSize = sc(22)
			title.Font = Enum.Font.GothamBlack
			title.TextColor3 = color
			title.ZIndex = 7
			title.Parent = backdrop

			local container = Instance.new("Frame")
			container.AnchorPoint = Vector2.new(0.5, 0.5)
			container.Position = UDim2.fromScale(0.5, 0.5)
			container.BackgroundTransparency = 1
			container.ZIndex = 7
			container.Parent = backdrop

			local big = #hatched == 1
			local cellW = sc(96)
			local cellH = sc(116)
			local cellPad = sc(8)
			local contentW, contentH
			if big then
				contentW, contentH = sc(200), sc(240)
				container.Size = UDim2.fromOffset(contentW, contentH)
				local layout = Instance.new("UIListLayout")
				layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				layout.VerticalAlignment = Enum.VerticalAlignment.Center
				layout.Parent = container
			else
				contentW = 5 * cellW + 4 * cellPad
				contentH = 2 * cellH + cellPad
				container.Size = UDim2.fromOffset(contentW, contentH)
				local grid = Instance.new("UIGridLayout")
				grid.CellSize = UDim2.fromOffset(cellW, cellH)
				grid.CellPadding = UDim2.new(0, cellPad, 0, cellPad)
				grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
				grid.VerticalAlignment = Enum.VerticalAlignment.Center
				grid.Parent = container
			end

			-- Грид рассчитан в фикс-пикселях (до 5 колонок). На узких экранах
			-- ужимаем весь блок целиком, чтобы карточки не уезжали за край.
			local fitScale = math.min(1, (viewport.X * 0.92) / contentW, (viewport.Y * 0.82) / contentH)
			if fitScale < 1 then
				local fit = Instance.new("UIScale")
				fit.Scale = fitScale
				fit.Parent = container
			end

			for i, p in ipairs(hatched) do
				task.delay(0.04 * i, function()
					if not container.Parent then
						return
					end
					local def = PetDatabase.get(p.petId)
					if def then
						local handle = revealCard(container, def, i, big, 0.02 * i)
						table.insert(cleanups, handle.destroy)
					end
				end)
			end

			task.delay(3.35, function()
				dismiss(gui, cleanups)
			end)
		end)
	end)
	if not ok then
		warn("[PetHatchFX] play failed:", err)
	end
end

return PetHatchFX
