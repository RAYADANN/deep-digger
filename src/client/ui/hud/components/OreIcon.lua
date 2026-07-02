--!strict
-- Иконка руды: rbxassetid → baked pixels → emoji.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local OreLookup = require(script.Parent.Parent.Parent.Parent.core.OreLookup)
local OreAssets = require(ReplicatedStorage:WaitForChild("shared").data.OreAssets)

local Children = Fusion.Children

export type Props = {
	oreId: string,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	textColor3: any?,
	zIndex: number?,
}

local OreIcon = {}

function OreIcon.create(s: ScopeFactory.HudScope, props: Props)
	local size = props.size or UDim2.new(1, 0, 0, 36)
	local position = props.position or UDim2.new(0, 0, 0, 8)
	local zIndex = props.zIndex or 2

	local rbxImage = OreLookup.getImage(props.oreId)
	local iconContent = if rbxImage == "" then OreAssets.iconContent(props.oreId) else nil

	local iconChild: Instance
	if rbxImage ~= "" then
		iconChild = s:New("ImageLabel")({
			Name = "RbxImage",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = rbxImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 1,
		})
	elseif iconContent then
		iconChild = s:New("ImageLabel")({
			Name = "PixelImage",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ImageContent = iconContent,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 1,
		})
	else
		iconChild = s:New("TextLabel")({
			Name = "EmojiFallback",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = OreLookup.getIcon(props.oreId),
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			TextColor3 = props.textColor3 or OreLookup.getRarityColor(props.oreId),
			ZIndex = 1,
		})
	end

	return s:New("Frame")({
		Name = "OreIcon",
		Size = size,
		Position = position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		ZIndex = zIndex,
		[Children] = { iconChild },
	})
end

return OreIcon
