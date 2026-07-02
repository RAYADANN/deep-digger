--!strict
-- Подпись над зоной хаба (SELL / UPGRADE): компактно, но читаемо издалека.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

export type Props = {
	accent: Color3,
	iconKey: string,
	title: string,
	studsOffset: Vector3?,
	maxDistance: number?,
}

export type Handle = {
	setInZone: (inZone: boolean) -> (),
	destroy: () -> (),
}

local BG = Color3.fromRGB(8, 10, 18)
local TEXT_IDLE = Color3.fromRGB(215, 222, 240)

local PILL_W = 208
local PILL_H = 40

local function pillSize(): (number, number)
	local camera = workspace.CurrentCamera
	local vpX = if camera then camera.ViewportSize.X else 1280
	if vpX < 520 then
		return 156, 30
	elseif vpX < 900 then
		return 180, 34
	end
	return PILL_W, PILL_H
end

local ZoneBillboard = {}

function ZoneBillboard.apply(billboard: BillboardGui, adornee: BasePart, props: Props): Handle
	for _, child in billboard:GetChildren() do
		child:Destroy()
	end

	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = props.maxDistance or 200
	local pillW, pillH = pillSize()
	billboard.Size = UDim2.fromOffset(pillW, pillH)
	billboard.StudsOffset = props.studsOffset or Vector3.new(0, if UserInputService.TouchEnabled then 9.2 else 7.2, 0)
	billboard.ResetOnSpawn = false
	billboard.Enabled = true

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = BG
	pill.BackgroundTransparency = 0.28
	pill.BorderSizePixel = 0
	pill.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = pill

	local stroke = Instance.new("UIStroke")
	stroke.Color = props.accent
	stroke.Thickness = 1.5
	stroke.Transparency = 0.42
	stroke.Parent = pill

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(0, 4, 1, -8)
	accent.Position = UDim2.new(0, 6, 0, 4)
	accent.BackgroundColor3 = props.accent
	accent.BorderSizePixel = 0
	accent.Parent = pill
	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 2)
	accentCorner.Parent = accent

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(22, 22)
	icon.Position = UDim2.new(0, 16, 0.5, -11)
	icon.BackgroundTransparency = 1
	icon.Image = UiAssets.resolve(props.iconKey)
	icon.ImageColor3 = props.accent
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = pill

	local title = Instance.new("TextLabel")
	title.Name = "TitleLabel"
	title.Size = UDim2.new(1, -48, 1, 0)
	title.Position = UDim2.new(0, 44, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = props.title
	title.TextSize = 16
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = TEXT_IDLE
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = pill

	local inZone = false

	local function setInZone(active: boolean)
		if inZone == active then
			return
		end
		inZone = active
		title.TextColor3 = if active then props.accent else TEXT_IDLE
		stroke.Transparency = if active then 0.12 else 0.42
		pill.BackgroundTransparency = if active then 0.18 else 0.28
	end

	return {
		setInZone = setInZone,
		destroy = function() end,
	}
end

return ZoneBillboard
