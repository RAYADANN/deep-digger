--!strict
-- Пресеты твинов и хелперы анимации для HUD.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local peek = Fusion.peek

export type PulseHandle = { cancel: () -> () }
export type CleanupFn = () -> ()

local UiMotion = {}

UiMotion.HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
UiMotion.PRESS = TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
UiMotion.MODAL_IN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
UiMotion.MODAL_OUT = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
UiMotion.FADE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
UiMotion.POP = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
UiMotion.SLIDE = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
UiMotion.SNAP = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function UiMotion.play(instance: Instance, props: { [string]: any }, info: TweenInfo): Tween
	local tween = TweenService:Create(instance, info, props)
	tween:Play()
	return tween
end

function UiMotion.ensureScale(gui: GuiObject): UIScale
	local existing = gui:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "UiScale"
	scale.Scale = 1
	scale.Parent = gui
	return scale
end

function UiMotion.setScale(gui: GuiObject, target: number, info: TweenInfo?)
	local scale = UiMotion.ensureScale(gui)
	if info then
		UiMotion.play(scale, { Scale = target }, info)
	else
		scale.Scale = target
	end
end

function UiMotion.pop(gui: GuiObject, peak: number?)
	local scale = UiMotion.ensureScale(gui)
	local peakScale = peak or 1.14
	scale.Scale = 1
	UiMotion.play(scale, { Scale = peakScale }, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	task.delay(0.12, function()
		if scale.Parent then
			UiMotion.play(scale, { Scale = 1 }, UiMotion.POP)
		end
	end)
end

function UiMotion.defer(scope: any, instance: Instance, callback: (Instance) -> CleanupFn?)
	task.defer(function()
		if not instance.Parent then
			return
		end
		local cleanup = callback(instance)
		if cleanup and typeof(scope) == "table" then
			table.insert(scope, cleanup)
		end
	end)
end

function UiMotion.watch(scope: any, getValue: () -> any, onChange: (new: any, old: any) -> ())
	local last = getValue()
	local conn = RunService.Heartbeat:Connect(function()
		local cur = getValue()
		if cur ~= last then
			local prev = last
			last = cur
			onChange(cur, prev)
		end
	end)
	if typeof(scope) == "table" then
		table.insert(scope, function()
			conn:Disconnect()
		end)
	end
end

function UiMotion.watchNumber(
	scope: any,
	getValue: () -> number,
	onChange: (new: number, old: number, delta: number) -> ()
)
	local last = getValue()
	local conn = RunService.Heartbeat:Connect(function()
		local cur = getValue()
		if math.abs(cur - last) > 0.01 then
			local prev = last
			last = cur
			onChange(cur, prev, cur - prev)
		end
	end)
	if typeof(scope) == "table" then
		table.insert(scope, function()
			conn:Disconnect()
		end)
	end
end

function UiMotion.pulseStroke(stroke: UIStroke, minT: number, maxT: number, period: number): PulseHandle
	local running = true

	task.spawn(function()
		local forward = true
		while running and stroke.Parent do
			local goal = if forward then minT else maxT
			local tween = TweenService:Create(
				stroke,
				TweenInfo.new(period * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Transparency = goal }
			)
			tween:Play()
			tween.Completed:Wait()
			forward = not forward
		end
	end)

	return {
		cancel = function()
			running = false
		end,
	}
end

function UiMotion.pulseScale(scope: any, gui: GuiObject, minS: number, maxS: number, period: number): PulseHandle
	local scale = UiMotion.ensureScale(gui)
	local running = true

	task.spawn(function()
		local forward = true
		while running and scale.Parent do
			local goal = if forward then maxS else minS
			local tween = TweenService:Create(
				scale,
				TweenInfo.new(period * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Scale = goal }
			)
			tween:Play()
			tween.Completed:Wait()
			forward = not forward
		end
	end)

	local handle: PulseHandle = {
		cancel = function()
			running = false
			if scale.Parent then
				scale.Scale = 1
			end
		end,
	}
	if typeof(scope) == "table" then
		table.insert(scope, handle.cancel)
	end
	return handle
end

function UiMotion.bindHoverPress(
	scope: any,
	gui: GuiObject,
	hovering: any,
	pressing: any,
	opts: { hoverScale: number?, pressScale: number? }?
)
	local hoverScale = if opts and opts.hoverScale then opts.hoverScale else 1.06
	local pressScale = if opts and opts.pressScale then opts.pressScale else 0.94

	local function refresh()
		local target = 1
		if peek(pressing) then
			target = pressScale
		elseif peek(hovering) and UserInputService.MouseEnabled then
			target = hoverScale
		end
		UiMotion.setScale(gui, target, UiMotion.HOVER)
	end

	UiMotion.defer(scope, gui, function()
		refresh()
		return nil
	end)

	UiMotion.watch(scope, function()
		return peek(hovering)
	end, refresh)
	UiMotion.watch(scope, function()
		return peek(pressing)
	end, refresh)
end

function UiMotion.slideY(gui: GuiObject, fromY: number, toY: number, info: TweenInfo?)
	gui.Position = UDim2.new(gui.Position.X.Scale, gui.Position.X.Offset, gui.Position.Y.Scale, fromY)
	UiMotion.play(gui, { Position = UDim2.new(gui.Position.X.Scale, gui.Position.X.Offset, gui.Position.Y.Scale, toY) }, info or UiMotion.SLIDE)
end

function UiMotion.fadeIn(gui: GuiObject, props: { bg: number?, stroke: UIStroke?, strokeT: number? })
	if gui:IsA("GuiObject") then
		UiMotion.play(gui, { BackgroundTransparency = props.bg or 0 }, UiMotion.FADE)
	end
	if props.stroke then
		UiMotion.play(props.stroke, { Transparency = props.strokeT or 0.2 }, UiMotion.FADE)
	end
end

function UiMotion.modalEnter(backdrop: Frame, panel: GuiObject)
	backdrop.BackgroundTransparency = 1
	panel.Visible = true
	UiMotion.setScale(panel, 0.88, nil)
	UiMotion.play(backdrop, { BackgroundTransparency = 0.45 }, UiMotion.FADE)
	UiMotion.setScale(panel, 1, UiMotion.MODAL_IN)
end

function UiMotion.modalExit(backdrop: Frame, panel: GuiObject, onDone: (() -> ())?)
	UiMotion.play(backdrop, { BackgroundTransparency = 1 }, UiMotion.MODAL_OUT)
	UiMotion.setScale(panel, 0.92, UiMotion.MODAL_OUT)
	task.delay(UiMotion.MODAL_OUT.Time, function()
		panel.Visible = false
		if onDone then
			onDone()
		end
	end)
end

return UiMotion
