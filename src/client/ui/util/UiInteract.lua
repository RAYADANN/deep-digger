--!strict
-- Hover / press для GuiButton. Desktop hover; mobile — только press.

local UserInputService = game:GetService("UserInputService")

local UiMotion = require(script.Parent.UiMotion)

export type Options = {
	hoverScale: number?,
	pressScale: number?,
	disabled: (() -> boolean)?,
}

export type Handle = { destroy: () -> () }

local UiInteract = {}

function UiInteract.attachScoped(scope: any, button: GuiButton, opts: Options?): Handle
	local handle = UiInteract.attach(button, opts)
	if typeof(scope) == "table" then
		table.insert(scope, function()
			handle.destroy()
		end)
	end
	return handle
end

function UiInteract.attach(button: GuiButton, opts: Options?): Handle
	local hoverScale = if opts and opts.hoverScale then opts.hoverScale else 1.06
	local pressScale = if opts and opts.pressScale then opts.pressScale else 0.94
	local isDisabled = if opts and opts.disabled then opts.disabled else function()
		return false
	end

	local scale = UiMotion.ensureScale(button)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	local connections: { RBXScriptConnection } = {}
	local hovering = false
	local pressing = false
	local baseStrokeT = if stroke then stroke.Transparency else nil

	local function applyScale(target: number)
		if isDisabled() then
			return
		end
		UiMotion.setScale(button, target, if pressing then UiMotion.PRESS else UiMotion.HOVER)
		if stroke and baseStrokeT then
			local strokeGoal = if hovering and not pressing then math.max(0, baseStrokeT - 0.25) else baseStrokeT
			UiMotion.play(stroke, { Transparency = strokeGoal }, UiMotion.HOVER)
		end
	end

	local function refresh()
		if isDisabled() then
			scale.Scale = 1
			return
		end
		if pressing then
			applyScale(pressScale)
		elseif hovering and UserInputService.MouseEnabled then
			applyScale(hoverScale)
		else
			applyScale(1)
		end
	end

	table.insert(connections, button.MouseEnter:Connect(function()
		hovering = true
		refresh()
	end))
	table.insert(connections, button.MouseLeave:Connect(function()
		hovering = false
		pressing = false
		refresh()
	end))
	table.insert(connections, button.MouseButton1Down:Connect(function()
		pressing = true
		refresh()
	end))
	table.insert(connections, button.MouseButton1Up:Connect(function()
		pressing = false
		refresh()
	end))

	return {
		destroy = function()
			for _, conn in connections do
				conn:Disconnect()
			end
			table.clear(connections)
		end,
	}
end

return UiInteract
