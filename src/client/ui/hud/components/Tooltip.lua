--!strict
-- Hover-tooltip для HUD. Отдельный ScreenGui поверх модалок.

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local theme = require(script.Parent.Parent.theme)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)
local UiScreen = require(script.Parent.Parent.Parent.util.UiScreen)

local C = theme.C

local TOOLTIP_GUI_NAME = "DeepDigger_Tooltip"
local FADE_IN = 0.1
local FADE_OUT = 0.1

local BASE_TEXT_SIZE = 16
local MIN_TEXT_SIZE = 13
local BASE_PADDING = 12
local BASE_MIN_W = 260
local BASE_MAX_W = 400
local BASE_CORNER = 10
local BASE_OFFSET = 10
local BASE_STROKE = 1.5
local LINE_HEIGHT = 1.14

export type AttachOptions = {
	scale: number?,
}

local Tooltip = {}

local function scaled(base: number, scale: number): number
	return math.floor(base * scale + 0.5)
end

local function tooltipTextSize(scale: number): number
	return math.max(MIN_TEXT_SIZE, scaled(BASE_TEXT_SIZE, scale))
end

local function ensureGui(): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UiScreen.ensure(pg, TOOLTIP_GUI_NAME, "tooltip")
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	return gui
end

local function stripRichText(text: string): string
	return (text:gsub("<[^>]+>", ""))
end

local function estimateWidth(text: string, scale: number): number
	local plain = stripRichText(text)
	local textSize = tooltipTextSize(scale)
	local maxW = scaled(BASE_MAX_W, scale)
	local minW = scaled(BASE_MIN_W, scale)
	local padding = scaled(BASE_PADDING, scale)
	local size = TextService:GetTextSize(
		plain,
		textSize,
		Enum.Font.Gotham,
		Vector2.new(maxW - padding * 2, math.huge)
	)
	return math.clamp(size.X + padding * 2, minW, maxW)
end

local function buildFrame(scale: number): (Frame, TextLabel, UIStroke)
	local padding = scaled(BASE_PADDING, scale)
	local maxW = scaled(BASE_MAX_W, scale)
	local minW = scaled(BASE_MIN_W, scale)
	local textSize = tooltipTextSize(scale)

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(maxW, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = C.panelInner
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.AutoLocalize = false
	frame.ClipsDescendants = false
	frame.ZIndex = 100

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, scaled(BASE_CORNER, scale))
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = C.primary
	stroke.Thickness = scaled(BASE_STROKE, scale)
	stroke.Transparency = 1
	stroke.Parent = frame

	local paddingInst = Instance.new("UIPadding")
	paddingInst.PaddingTop = UDim.new(0, padding)
	paddingInst.PaddingBottom = UDim.new(0, padding)
	paddingInst.PaddingLeft = UDim.new(0, padding)
	paddingInst.PaddingRight = UDim.new(0, padding)
	paddingInst.Parent = frame

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(minW, 0)
	sizeConstraint.MaxSize = Vector2.new(maxW, 10000)
	sizeConstraint.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = textSize
	label.LineHeight = LINE_HEIGHT
	label.TextColor3 = C.textMain
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextTransparency = 1
	label.RichText = true
	label.ZIndex = 101
	label.Parent = frame

	return frame, label, stroke
end

local function positionFrame(frame: Frame, target: GuiObject, scale: number)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1024, 768)
	local tPos = target.AbsolutePosition
	local tSize = target.AbsoluteSize
	local fSize = frame.AbsoluteSize
	local offset = scaled(BASE_OFFSET, scale)
	local edge = scaled(8, scale)
	local fallbackW = scaled(BASE_MAX_W, scale)
	local fallbackH = scaled(80, scale)
	if fSize.X < 10 or fSize.Y < 10 then
		fSize = Vector2.new(fallbackW, fallbackH)
	end

	local x = tPos.X + tSize.X + offset
	local y = tPos.Y
	if x + fSize.X > viewport.X - edge then
		x = tPos.X - fSize.X - offset
		if x < edge then
			x = math.clamp(tPos.X, edge, viewport.X - fSize.X - edge)
			y = tPos.Y + tSize.Y + offset
		end
	end
	y = math.clamp(y, edge, math.max(edge, viewport.Y - fSize.Y - edge))

	frame.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
end

function Tooltip.attach(scope: any, target: GuiObject, getText: () -> string, options: AttachOptions?)
	local scale = if options and options.scale then options.scale else 1
	local state = {
		frame = nil :: Frame?,
		label = nil :: TextLabel?,
		stroke = nil :: UIStroke?,
		fadeOutTask = nil :: thread?,
		destroyed = false,
	}

	local function destroyFrame()
		if state.frame then
			state.frame:Destroy()
		end
		state.frame, state.label, state.stroke = nil, nil, nil
	end

	local function show()
		if state.destroyed then
			return
		end
		if state.fadeOutTask then
			task.cancel(state.fadeOutTask)
			state.fadeOutTask = nil
		end
		if not state.frame then
			local gui = ensureGui()
			local f, l, st = buildFrame(scale)
			state.frame, state.label, state.stroke = f, l, st
			f.Parent = gui
		end
		local frame = state.frame :: Frame
		local label = state.label :: TextLabel
		local stroke = state.stroke :: UIStroke

		local ok, text = pcall(getText)
		if not ok or typeof(text) ~= "string" then
			text = ""
		end
		label.Text = text
		frame.Size = UDim2.fromOffset(estimateWidth(text, scale), 0)

		task.defer(function()
			if state.frame == frame then
				positionFrame(frame, target, scale)
			end
		end)

		TweenService:Create(frame, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.04,
		}):Play()
		TweenService:Create(label, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 0,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(FADE_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 0.12,
		}):Play()
		UiMotion.setScale(frame, 0.94, nil)
		UiMotion.setScale(frame, 1, UiMotion.POP)
	end

	local function hide()
		if state.fadeOutTask then
			task.cancel(state.fadeOutTask)
		end
		local frame = state.frame
		local label = state.label
		local stroke = state.stroke
		if not frame or not label or not stroke then
			return
		end
		TweenService:Create(frame, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(label, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(FADE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		}):Play()

		state.fadeOutTask = task.delay(FADE_OUT + 0.02, function()
			state.fadeOutTask = nil
			if state.destroyed then
				return
			end
			destroyFrame()
		end)
	end

	local enterConn = target.MouseEnter:Connect(show)
	local leaveConn = target.MouseLeave:Connect(hide)

	local function disposeAll()
		if state.destroyed then
			return
		end
		state.destroyed = true
		enterConn:Disconnect()
		leaveConn:Disconnect()
		if state.fadeOutTask then
			task.cancel(state.fadeOutTask)
			state.fadeOutTask = nil
		end
		destroyFrame()
	end

	local ancestryConn: RBXScriptConnection
	ancestryConn = target.AncestryChanged:Connect(function()
		if not target.Parent then
			hide()
			disposeAll()
			ancestryConn:Disconnect()
		end
	end)

	if typeof(scope) == "table" then
		table.insert(scope, function()
			ancestryConn:Disconnect()
			disposeAll()
		end)
	end
end

return Tooltip
