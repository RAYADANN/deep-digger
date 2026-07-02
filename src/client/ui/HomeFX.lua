--!strict
-- HomeFX — мультяшный «iris wipe».
--
-- ЗАКРЫТИЕ (0.32s):
--   Полноэкранный чёрный оверлей + чёрный круг вырастают одновременно.
--   Круг всегда меньше экрана → видно, что это круг, а не квадрат.
--
-- ПИК — полный чёрный → onPeak() → телепорт.
--
-- ОТКРЫТИЕ (0.42s):
--   Оверлей исчезает, светлый круг расширяется из центра и тоже исчезает —
--   визуальный эффект «портал открывается», как в мультиках.
--
-- Безопасен: повторный вызов во время анимации — no-op.

local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")

local UiScreen = require(script.Parent.util.UiScreen)

local HomeFX = {}
local _active = false

function HomeFX.play(onPeak: () -> ())
	if _active then return end
	_active = true

	local player = Players.LocalPlayer

	-- Диаметр iris-круга = короткая сторона экрана + 40px.
	-- Гарантированно помещается в экран → углы скругления всегда видны → круг, не квадрат.
	local cam        = workspace.CurrentCamera
	local vp         = if cam then cam.ViewportSize else Vector2.new(1920, 1080)
	local irisSize   = math.min(vp.X, vp.Y) + 40   -- e.g. 1120px на 1080p

	local gui = Instance.new("ScreenGui")
	gui.Name = "HomeFX"
	UiScreen.apply(gui, "fx")
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player.PlayerGui

	-- ── Полноэкранный оверлей (покрывает углы за кругом) ─────────────────────
	local overlay = Instance.new("Frame")
	overlay.Size                   = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3       = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel        = 0
	overlay.ZIndex                 = 1
	overlay.Parent                 = gui

	-- ── Закрывающий круг (чёрный, растёт из 0) ───────────────────────────────
	local closeCircle = Instance.new("Frame")
	closeCircle.Size                   = UDim2.fromOffset(0, 0)
	closeCircle.Position               = UDim2.fromScale(0.5, 0.5)
	closeCircle.AnchorPoint            = Vector2.new(0.5, 0.5)
	closeCircle.BackgroundColor3       = Color3.new(0, 0, 0)
	closeCircle.BackgroundTransparency = 0
	closeCircle.BorderSizePixel        = 0
	closeCircle.ZIndex                 = 2
	closeCircle.Parent                 = gui
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0.5, 0)
	cc.Parent       = closeCircle

	-- ── Открывающий круг (светлый, расширяется после пика) ───────────────────
	local openCircle = Instance.new("Frame")
	openCircle.Size                   = UDim2.fromOffset(0, 0)
	openCircle.Position               = UDim2.fromScale(0.5, 0.5)
	openCircle.AnchorPoint            = Vector2.new(0.5, 0.5)
	openCircle.BackgroundColor3       = Color3.fromRGB(200, 225, 255)
	openCircle.BackgroundTransparency = 0.15
	openCircle.BorderSizePixel        = 0
	openCircle.ZIndex                 = 3
	openCircle.Parent                 = gui
	local oc = Instance.new("UICorner")
	oc.CornerRadius = UDim.new(0.5, 0)
	oc.Parent       = openCircle

	task.spawn(function()
		-- ── Фаза 1: ЗАКРЫТИЕ (0.32s) ──────────────────────────────────────
		-- Чёрный круг вырастает до irisSize; оверлей покрывает углы.
		local closeInfo = TweenInfo.new(0.32, Enum.EasingStyle.Circular, Enum.EasingDirection.In)
		local t1 = TweenService:Create(overlay,     closeInfo, { BackgroundTransparency = 0 })
		local t2 = TweenService:Create(closeCircle, closeInfo, {
			Size = UDim2.fromOffset(irisSize, irisSize),
		})
		t1:Play()
		t2:Play()
		t1.Completed:Wait()

		-- ── Пик ───────────────────────────────────────────────────────────
		task.wait(0.04)
		onPeak()   -- ← телепорт
		task.wait(0.04)

		-- ── Фаза 2: ОТКРЫТИЕ (0.42s) ──────────────────────────────────────
		-- Закрывающий круг убираем (оверлей его закрывает).
		closeCircle.Visible = false

		-- Светлый круг расширяется из центра и исчезает.
		-- Оверлей одновременно исчезает → мир «просвечивает» вокруг портала.
		local openInfo = TweenInfo.new(0.42, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
		local t3 = TweenService:Create(overlay,    openInfo, { BackgroundTransparency = 1 })
		local t4 = TweenService:Create(openCircle, openInfo, {
			Size                   = UDim2.fromOffset(irisSize * 1.3, irisSize * 1.3),
			BackgroundTransparency = 1,
		})
		t3:Play()
		t4:Play()
		t3.Completed:Wait()

		gui:Destroy()
		_active = false
	end)
end

return HomeFX
