--!strict
-- Подсветка цели: обводка на HUD-элементе или 3D-пин в мире.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local GOLD = Color3.fromRGB(255, 214, 96)
local GOLD_HI = Color3.fromRGB(255, 244, 210)
local HIGHLIGHT_NAME = "TutorialOverlay"
local LABEL_NAME = "TutorialOverlayLabel"

local TutorialArrow = {}

export type Handle = {
	destroy: (self: Handle) -> (),
}

local function makeHandle(): Handle
	return {
		destroy = function(_self: Handle) end,
	}
end

local function goalImage(): string
	local pin = UiAssets.image("tutorial_goal_pin")
	if pin ~= "" then
		return pin
	end
	return UiAssets.image("icon_tutorial_arrow")
end

local function upgRowAncestor(target: GuiObject): GuiObject?
	local parent = target.Parent
	if parent and parent:IsA("GuiObject") and string.sub(parent.Name, 1, 7) == "UpgRow_" then
		return parent :: GuiObject
	end
	return nil
end

local function clearTutorialChrome(target: GuiObject)
	local existing = target:FindFirstChild(HIGHLIGHT_NAME)
	if existing then
		existing:Destroy()
	end
	local label = target:FindFirstChild(LABEL_NAME)
	if label then
		label:Destroy()
	end
end

function TutorialArrow.clearGuiChrome(target: GuiObject)
	clearTutorialChrome(target)
	local row = upgRowAncestor(target)
	if row then
		clearTutorialChrome(row)
	end
end

function TutorialArrow.sweepHudChrome(hud: Instance)
	for _, desc in hud:GetDescendants() do
		if desc.Name == HIGHLIGHT_NAME or desc.Name == LABEL_NAME then
			desc:Destroy()
		end
	end
end

local function pointAtGui(target: GuiObject, text: string): Handle
	TutorialArrow.clearGuiChrome(target)

	local overlay = Instance.new("Frame")
	overlay.Name = HIGHLIGHT_NAME
	overlay.AnchorPoint = Vector2.new(0.5, 0.5)
	overlay.Position = UDim2.fromScale(0.5, 0.5)
	overlay.Size = UDim2.new(1, 14, 1, 14)
	overlay.BackgroundColor3 = GOLD
	overlay.BackgroundTransparency = 0.88
	overlay.BorderSizePixel = 0
	overlay.Active = false
	overlay.ZIndex = math.max(target.ZIndex + 4, 12)
	overlay.Parent = target

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = overlay

	local stroke = Instance.new("UIStroke")
	stroke.Color = GOLD
	stroke.Thickness = 2.2
	stroke.Transparency = 0.08
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = overlay

	local row = upgRowAncestor(target)
	local buyBtn = if target.Name == "BuyButton" then target else nil

	local labelFrame = Instance.new("Frame")
	labelFrame.Name = LABEL_NAME
	if buyBtn and row then
		labelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		labelFrame.Position = UDim2.new(
			buyBtn.Position.X.Scale,
			buyBtn.Position.X.Offset + math.floor(buyBtn.Size.X.Offset * 0.5),
			buyBtn.Position.Y.Scale,
			buyBtn.Position.Y.Offset + math.floor(buyBtn.Size.Y.Offset * 0.5)
		)
		labelFrame.Parent = row
	elseif buyBtn then
		labelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		labelFrame.Position = UDim2.fromScale(0.5, 0.5)
		labelFrame.Parent = buyBtn
	else
		labelFrame.AnchorPoint = Vector2.new(0.5, 1)
		labelFrame.Position = UDim2.new(0.5, 0, 0, -10)
		labelFrame.Parent = target
	end
	labelFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
	labelFrame.BackgroundTransparency = 0.06
	labelFrame.BorderSizePixel = 0
	labelFrame.Active = false
	labelFrame.AutomaticSize = Enum.AutomaticSize.XY
	labelFrame.Size = UDim2.fromOffset(0, 0)
	local labelHost = labelFrame.Parent :: GuiObject
	labelFrame.ZIndex = math.max(labelHost.ZIndex + 6, 16)

	Instance.new("UICorner", labelFrame).CornerRadius = UDim.new(0, 10)
	local lblStroke = Instance.new("UIStroke")
	lblStroke.Color = GOLD
	lblStroke.Thickness = 1.5
	lblStroke.Transparency = 0.2
	lblStroke.Parent = labelFrame

	local lblPad = Instance.new("UIPadding")
	lblPad.PaddingTop = UDim.new(0, 6)
	lblPad.PaddingBottom = UDim.new(0, 6)
	lblPad.PaddingLeft = UDim.new(0, 10)
	lblPad.PaddingRight = UDim.new(0, 10)
	lblPad.Parent = labelFrame

	local labelText = Instance.new("TextLabel")
	labelText.BackgroundTransparency = 1
	labelText.AutomaticSize = Enum.AutomaticSize.XY
	labelText.Size = UDim2.fromOffset(0, 0)
	labelText.Font = Enum.Font.GothamBold
	labelText.TextSize = 14
	labelText.TextColor3 = GOLD_HI
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.Text = text
	labelText.Parent = labelFrame

	local pulseTween = TweenService:Create(
		stroke,
		TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Thickness = 3.4, Transparency = 0.32 }
	)
	pulseTween:Play()

	local destroyed = false
	local labelRow = if buyBtn and row then row else nil
	return {
		destroy = function(_self: Handle)
			if destroyed then
				return
			end
			destroyed = true
			pulseTween:Cancel()
			if overlay.Parent then
				overlay:Destroy()
			end
			if labelFrame.Parent then
				labelFrame:Destroy()
			end
			if labelRow then
				clearTutorialChrome(labelRow)
			end
		end,
	}
end

local function pointAtPart(target: BasePart, text: string): Handle
	local folder = Instance.new("Folder")
	folder.Name = "TutorialWorldBeacon"
	folder.Parent = target

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TutorialArrow"
	billboard.Size = UDim2.fromOffset(140, 140)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 650
	billboard.Adornee = target
	billboard.Parent = folder

	local pin = Instance.new("ImageLabel")
	pin.Size = UDim2.fromScale(1, 1)
	pin.BackgroundTransparency = 1
	pin.Image = goalImage()
	pin.ScaleType = Enum.ScaleType.Fit
	pin.Parent = billboard

	local labelBg = Instance.new("Frame")
	labelBg.Size = UDim2.new(1, -12, 0, 40)
	labelBg.Position = UDim2.new(0, 6, 1, 4)
	labelBg.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
	labelBg.BackgroundTransparency = 0.08
	labelBg.BorderSizePixel = 0
	labelBg.Parent = billboard
	Instance.new("UICorner", labelBg).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", labelBg)
	stroke.Color = GOLD
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = GOLD_HI
	label.TextWrapped = true
	label.Parent = labelBg

	local bounceTween = TweenService:Create(
		billboard,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffset = Vector3.new(0, 6.2, 0) }
	)
	bounceTween:Play()

	local destroyed = false
	return {
		destroy = function(_self: Handle)
			if destroyed then
				return
			end
			destroyed = true
			bounceTween:Cancel()
			folder:Destroy()
		end,
	}
end

function TutorialArrow.pointAt(target: any, text: string): Handle
	if typeof(target) ~= "Instance" then
		return makeHandle()
	end
	if target:IsA("GuiObject") then
		return pointAtGui(target :: GuiObject, text)
	end
	if target:IsA("BasePart") then
		return pointAtPart(target :: BasePart, text)
	end
	return makeHandle()
end

return TutorialArrow
