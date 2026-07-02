--!strict
-- Плитка питомца в EggShopModal: 3D-превью без вращения.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local PetDatabase = require(ReplicatedStorage:WaitForChild("shared").data.PetDatabase)
local PetLogic = require(ReplicatedStorage:WaitForChild("shared").util.PetLogic)
local PetModelKit = require(ReplicatedStorage:WaitForChild("shared").util.PetModelKit)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local EggShopLayout = require(script.Parent.Parent.Parent.EggShopLayout)

local Children = Fusion.Children
local C = theme.C
local RARITY_COLOR = theme.RARITY_COLOR

export type Props = {
	petId: string,
	layoutOrder: number,
	cellH: number?,
	percent: number?,
}

local EggShopPetTile = {}

local function createPreview(s: ScopeFactory.HudScope, pet: PetDatabase.Pet, tileH: number)
	local preview = s:New("Frame")({
		Name = "Preview",
		Size = UDim2.new(1, -8, 0, math.floor(tileH * 0.52 + 0.5)),
		Position = UDim2.new(0, 4, 0, math.floor(tileH * 0.06 + 0.5)),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})

	local display = PetModelKit.clonePetDisplay(pet.modelName, PetModelKit.displayHeights().card * 0.85)
	if display then
		local mounted = PetModelKit.mountInViewport(preview, display, 3.2)
		table.insert(s, mounted.destroy)
	else
		table.insert(
			s,
			s:New("ImageLabel")({
				Name = "IconFallback",
				Size = UDim2.fromScale(0.72, 0.72),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = UiAssets.tab("pets"),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
				Parent = preview,
			})
		)
	end

	return preview
end

function EggShopPetTile.create(s: ScopeFactory.HudScope, props: Props)
	local pet = PetDatabase.get(props.petId)
	if not pet then
		return s:New("Frame")({
			LayoutOrder = props.layoutOrder,
			BackgroundTransparency = 1,
		})
	end

	local tileH = props.cellH or 78
	-- Десктоп: имя ~1.5×, бонус/процент крупнее (et=1.5). Phone/tablet = 1.0.
	local et = EggShopLayout.textMult()
	local color = RARITY_COLOR[pet.rarity] or C.common
	local pctText = if typeof(props.percent) == "number"
		then (if props.percent >= 10
			then ("%d%%"):format(math.floor(props.percent + 0.5))
			else ("%.1f%%"):format(props.percent))
		else nil

	return s:New("Frame")({
		Name = "Pool_" .. pet.id,
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = C.bg3,
		BorderSizePixel = 0,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			s:New("UIStroke")({ Color = color, Thickness = 1.5, Transparency = 0.25 }),
			s:New("Frame")({
				Size = UDim2.new(1, 0, 0, 3),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = { s:New("UICorner")({ CornerRadius = UDim.new(0, 3) }) },
			}),
			createPreview(s, pet, tileH),
			s:New("TextLabel")({
				Size = UDim2.new(1, -8, 0, math.floor(tileH * 0.22 + 0.5)),
				Position = UDim2.new(0, 4, 0, math.floor(tileH * 0.6 + 0.5)),
				BackgroundTransparency = 1,
				Text = pet.name,
				TextSize = math.clamp(math.floor(tileH * 0.13 * et + 0.5), 12, 33),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textMain,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 2,
				[Children] = {
					s:New("UIStroke")({
						Color = C.outlineDark,
						Thickness = math.clamp(math.floor(tileH * 0.02 + 0.5), 1, 2),
						Transparency = 0.35,
						LineJoinMode = Enum.LineJoinMode.Round,
					}),
				},
			}),
			if pctText
				then s:New("TextLabel")({
					Size = UDim2.new(0, math.floor(tileH * 0.36 + 0.5), 0, math.floor(tileH * 0.16 + 0.5)),
					Position = UDim2.new(1, -math.floor(tileH * 0.05 + 0.5), 0, math.floor(tileH * 0.05 + 0.5)),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = color,
					BackgroundTransparency = 0.12,
					Text = pctText,
					TextSize = math.clamp(math.floor(tileH * 0.088 * et + 0.5), 10, 22),
					Font = Enum.Font.GothamBlack,
					TextColor3 = C.textDark,
					ZIndex = 3,
					[Children] = {
						s:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
					},
				})
				else nil,
			s:New("TextLabel")({
				Size = UDim2.new(1, -8, 0, math.floor(tileH * 0.14 + 0.5)),
				Position = UDim2.new(0, 4, 1, -math.floor(tileH * 0.16 + 0.5)),
				BackgroundTransparency = 1,
				Text = PetLogic.effectShort(pet.effect),
				TextSize = math.clamp(math.floor(tileH * 0.082 * et + 0.5), 9, 23),
				Font = Enum.Font.GothamBold,
				-- Бонус питомца — ключевая, но плохо читаемая строка на тёмной
				-- плитке. Вместо тусклого rarity-цвета — контрастный near-white
				-- + тёмный контур (толщина от tileH → на телефоне тоньше).
				TextColor3 = C.textMain,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 2,
				[Children] = {
					s:New("UIStroke")({
						Color = C.outlineDark,
						Thickness = math.clamp(math.floor(tileH * 0.02 * et + 0.5), 1, 3),
						Transparency = 0.08,
						LineJoinMode = Enum.LineJoinMode.Round,
					}),
				},
			}),
		},
	})
end

return EggShopPetTile
