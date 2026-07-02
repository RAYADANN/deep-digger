--!strict
-- Иконка Robux + цена. Режим stack — вертикально (для узких кнопок).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local Children = Fusion.Children
local C = theme.C

export type Props = {
	price: number,
	wasPrice: number?,
	textSize: number?,
	iconSize: number?,
	textColor: Color3?,
	wasColor: Color3?,
	strokeColor: Color3?,
	layoutOrder: number?,
	horizontalAlignment: Enum.HorizontalAlignment?,
	stacked: boolean?,
}

local RobuxPrice = {}

local function priceTextLabel(
	s: ScopeFactory.HudScope,
	text: string,
	textSize: number,
	textColor: Color3,
	strokeColor: Color3,
	strikethrough: boolean
)
	return s:New("TextLabel")({
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Text = if strikethrough then string.format("<s>%s</s>", text) else text,
		RichText = strikethrough,
		TextSize = textSize,
		Font = if strikethrough then Enum.Font.GothamBold else Enum.Font.GothamBlack,
		TextColor3 = textColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		[Children] = {
			s:New("UIStroke")({
				Color = strokeColor,
				Thickness = 1.5,
				Transparency = 0.15,
			}),
		},
	})
end

local function robuxIcon(s: ScopeFactory.HudScope, iconSize: number, transparency: number)
	return s:New("ImageLabel")({
		Size = UDim2.fromOffset(iconSize, iconSize),
		BackgroundTransparency = 1,
		Image = UiAssets.robux(),
		ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Fit,
	})
end

local function priceRow(
	s: ScopeFactory.HudScope,
	iconSize: number,
	textSize: number,
	text: string,
	textColor: Color3,
	strokeColor: Color3,
	iconTransparency: number,
	layoutOrder: number,
	strikethrough: boolean
)
	return s:New("Frame")({
		Name = if strikethrough then "WasRow" else "CurrentRow",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		[Children] = {
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 4),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			robuxIcon(s, iconSize, iconTransparency),
			priceTextLabel(s, text, textSize, textColor, strokeColor, strikethrough),
		},
	})
end

function RobuxPrice.create(s: ScopeFactory.HudScope, props: Props)
	local textSize = props.textSize or 14
	local iconSize = props.iconSize or 20
	local textColor = props.textColor or C.goldHi
	local wasColor = props.wasColor or Color3.fromRGB(190, 195, 210)
	local strokeColor = props.strokeColor or C.outlineDark
	local align = props.horizontalAlignment or Enum.HorizontalAlignment.Center
	local hasWas = props.wasPrice ~= nil and (props.wasPrice :: number) > props.price
	local stacked = props.stacked == true or (props.stacked == nil and hasWas)

	if stacked and hasWas then
		return s:New("Frame")({
			Name = "RobuxPrice",
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			LayoutOrder = props.layoutOrder,
			[Children] = {
				s:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 2),
					HorizontalAlignment = align,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				priceRow(
					s,
					iconSize - 2,
					textSize - 1,
					tostring(props.wasPrice),
					wasColor,
					strokeColor,
					0.25,
					1,
					true
				),
				priceRow(
					s,
					iconSize,
					textSize + 1,
					tostring(props.price),
					textColor,
					strokeColor,
					0,
					2,
					false
				),
			},
		})
	end

	local children: { Instance } = {
		s:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = align,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if hasWas then
		children[#children + 1] = priceRow(
			s,
			iconSize - 2,
			textSize - 1,
			tostring(props.wasPrice),
			wasColor,
			strokeColor,
			0.25,
			1,
			true
		)
	end
	children[#children + 1] = priceRow(
		s,
		iconSize,
		textSize + 1,
		tostring(props.price),
		textColor,
		strokeColor,
		0,
		2,
		false
	)

	return s:New("Frame")({
		Name = "RobuxPrice",
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		[Children] = children,
	})
end

return RobuxPrice
