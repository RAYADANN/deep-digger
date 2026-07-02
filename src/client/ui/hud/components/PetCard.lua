--!strict
-- Квадратная карточка питомца в сетке PetsPanel.
-- `equippedUids` — Value: обводка и бейдж обновляются без пересборки списка.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local PetDatabase = require(ReplicatedStorage:WaitForChild("shared").data.PetDatabase)
local PetLogic = require(ReplicatedStorage:WaitForChild("shared").util.PetLogic)
local PetModelKit = require(ReplicatedStorage:WaitForChild("shared").util.PetModelKit)
local BuffMeta = require(ReplicatedStorage:WaitForChild("shared").data.BuffMeta)
local BuffIcon = require(script.Parent.BuffIcon)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local UiIcon = require(script.Parent.UiIcon)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local PanelScale = require(script.Parent.Parent.PanelScale)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
local RARITY_COLOR = theme.RARITY_COLOR
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text

-- Дизайн-эталон карточки. Реальные пиксели считаются на лету (sc), а не на
-- этапе require — иначе масштаб «замораживается» до старта ViewportLayout.
local CARD_W_DESIGN = 104
local CARD_H_DESIGN = 128
local PREVIEW_H_DESIGN = 62

export type Props = {
	uid: string,
	petId: string,
	equippedUids: any,
	layoutOrder: number?,
	onToggle: ((uid: string, equipped: boolean) -> ())?,
}

local PetCard = {}

function PetCard.cellSize(): UDim2
	return UDim2.fromOffset(sc(CARD_W_DESIGN), sc(CARD_H_DESIGN))
end

local function isUidEquipped(uid: string, equippedUids: { string }): boolean
	for _, u in ipairs(equippedUids) do
		if u == uid then
			return true
		end
	end
	return false
end

local function createPreview(s: ScopeFactory.HudScope, def: PetDatabase.Pet, previewH: number)
	local preview = s:New("Frame")({
		Name = "Preview",
		Size = UDim2.new(1, -sc(10), 0, previewH),
		Position = UDim2.new(0, sc(5), 0, sc(8)),
		BackgroundColor3 = C.bg4,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 2,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
			s:New("UIStroke")({
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 1,
				Transparency = 0.85,
			}),
		},
	})

	local display = PetModelKit.clonePetDisplay(def.modelName, PetModelKit.displayHeights().card)
	if display then
		local mounted = PetModelKit.mountInViewport(preview, display, 3.6)
		table.insert(s, mounted.destroy)
	else
		table.insert(s, s:New("ImageLabel")({
			Name = "IconFallback",
			Size = UDim2.fromScale(0.65, 0.65),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = UiAssets.tab("pets"),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
			Parent = preview,
		}))
	end

	return preview
end

function PetCard.create(s: ScopeFactory.HudScope, props: Props)
	local def = PetDatabase.get(props.petId)
	if not def then
		return s:New("Frame")({
			Size = PetCard.cellSize(),
			BackgroundTransparency = 1,
			LayoutOrder = props.layoutOrder or 0,
		})
	end

	local rarityColor = RARITY_COLOR[def.rarity] or C.common
	local hovered = s:Value(false)
	local pressing = s:Value(false)
	local buffKind = BuffMeta.kindFromPetEffect(def.effect.kind)
	local previewH = sc(PREVIEW_H_DESIGN)

	local isEquipped = s:Computed(function(use)
		return isUidEquipped(props.uid, use(props.equippedUids) or {})
	end)

	local card = s:New("TextButton")({
		Name = "PetCard_" .. props.uid,
		Size = PetCard.cellSize(),
		LayoutOrder = props.layoutOrder or 0,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		BackgroundColor3 = s:Computed(function(use)
			if use(isEquipped) then
				return use(hovered) and Color3.fromRGB(52, 42, 14) or C.goldBg
			end
			return use(hovered) and C.btnHover or C.btnBg
		end),
		BackgroundTransparency = s:Computed(function(use)
			return if use(isEquipped) then 0.06 else 0
		end),
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(10)) }),
			s:New("UIStroke")({
				Color = s:Computed(function(use)
					return if use(isEquipped) then C.gold else rarityColor
				end),
				Thickness = s:Computed(function(use)
					return if use(isEquipped) then sc(2.5) else sc(1.5)
				end),
				Transparency = s:Computed(function(use)
					return if use(isEquipped) then 0.1 else 0.35
				end),
			}),
			s:New("Frame")({
				Size = UDim2.new(1, 0, 0, sc(3)),
				BackgroundColor3 = s:Computed(function(use)
					return if use(isEquipped) then C.gold else rarityColor
				end),
				BorderSizePixel = 0,
				ZIndex = 3,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(0, sc(3)) }),
				},
			}),
			createPreview(s, def, previewH),
			s:New("TextLabel")({
				Size = UDim2.new(1, -sc(8), 0, sc(14)),
				Position = UDim2.new(0, sc(4), 0, sc(8) + previewH + sc(4)),
				BackgroundTransparency = 1,
				Text = def.name,
				TextSize = text(12),
				Font = Enum.Font.GothamBlack,
				TextColor3 = C.textMain,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 2,
			}),
			s:New("Frame")({
				Size = UDim2.new(1, -sc(8), 0, sc(14)),
				Position = UDim2.new(0, sc(4), 0, sc(8) + previewH + sc(18)),
				BackgroundTransparency = 1,
				ZIndex = 2,
				[Children] = {
					if buffKind
						then BuffIcon.create(s, {
							kind = buffKind,
							size = UDim2.fromOffset(sc(12), sc(12)),
							position = UDim2.new(0.5, -sc(34), 0.5, -sc(6)),
							zIndex = 3,
						})
						else nil,
					s:New("TextLabel")({
						Size = UDim2.new(1, -sc(16), 1, 0),
						Position = UDim2.new(0.5, -sc(8), 0, 0),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Text = PetLogic.effectShort(def.effect),
						TextSize = text(10, 10),
						Font = Enum.Font.Gotham,
						TextColor3 = rarityColor,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 3,
					}),
				},
			}),
			s:New("Frame")({
				Name = "EquippedBadge",
				Size = UDim2.fromOffset(sc(22), sc(22)),
				Position = UDim2.new(1, -sc(6), 0, sc(6)),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = C.gold,
				BorderSizePixel = 0,
				Visible = isEquipped,
				ZIndex = 5,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					s:New("UIStroke")({ Color = C.white, Thickness = sc(1.2), Transparency = 0.35 }),
					UiIcon.create(s, {
						source = "icon_check",
						size = UDim2.fromOffset(sc(12), sc(12)),
						position = UDim2.fromScale(0.5, 0.5),
						anchorPoint = Vector2.new(0.5, 0.5),
						zIndex = 6,
					}),
				},
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, -sc(8), 0, sc(12)),
				Position = UDim2.new(0, sc(4), 1, -sc(14)),
				BackgroundTransparency = 1,
				Text = s:Computed(function(use)
					return if use(isEquipped) then "НАДЕТ" else "надеть"
				end),
				TextSize = text(10, 10),
				Font = Enum.Font.GothamBold,
				TextColor3 = s:Computed(function(use)
					return if use(isEquipped) then C.gold else C.textMuted
				end),
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 2,
			}),
		},
		[OnEvent("Activated")] = function()
			if props.onToggle then
				props.onToggle(props.uid, peek(isEquipped))
			end
		end,
	})

	UiMotion.bindHoverPress(s, card, hovered, pressing, { hoverScale = 1.05, pressScale = 0.96 })

	return card
end

return PetCard
