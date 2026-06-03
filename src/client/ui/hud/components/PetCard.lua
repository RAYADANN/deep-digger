--!strict
-- PetCard.lua — Phase 11 (Pets MVP).
--
-- Карточка одного питомца в PetsPanel. Состав:
--   * rarity-цветной UIStroke (common серый … mythic красный) + полоска сверху.
--   * Иконка пета (emoji), имя, короткое описание эффекта (PetLogic.effectShort).
--   * Бейдж «✓» если пет экипирован (золотая обводка).
--   * Клик по карточке → equip (или unequip если уже экипирован) через props.onToggle.
--
-- КРИТИЧНО (грабли Фазы 10): все текстовые лейблы внутри карточки имеют
-- ZIndex >= 2, чтобы не утонуть под фоном/UIStroke в Fusion 0.3 (баг daily-карт).
--
-- Карточка создаётся внутри s:Computed списка PetsPanel — `equipped` статичен
-- на момент рендера (Computed пересобирает список при смене state.equippedPet).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local PetDatabase = require(ReplicatedStorage:WaitForChild("shared").data.PetDatabase)
local PetLogic = require(ReplicatedStorage:WaitForChild("shared").util.PetLogic)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local C = theme.C
local RARITY_COLOR = theme.RARITY_COLOR

export type Props = {
    uid: string,
    petId: string,
    equipped: boolean,
    layoutOrder: number?,
    onToggle: ((uid: string, equipped: boolean) -> ())?,
}

local PetCard = {}

function PetCard.create(s: ScopeFactory.HudScope, props: Props)
    local def = PetDatabase.get(props.petId)
    if not def then
        return s:New("Frame")({
            Size = UDim2.fromOffset(92, 108),
            BackgroundTransparency = 1,
            LayoutOrder = props.layoutOrder or 0,
        })
    end

    local rarityColor = RARITY_COLOR[def.rarity] or C.common
    local hovered = s:Value(false)
    local equipped = props.equipped

    return s:New("Frame")({
        Name = "PetCard_" .. props.uid,
        Size = UDim2.fromOffset(92, 108),
        LayoutOrder = props.layoutOrder or 0,
        BackgroundColor3 = s:Computed(function(use)
            return use(hovered) and C.btnHover or C.btnBg
        end),
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
            -- Экипированный пет — золотая обводка, остальные — rarity-цвет.
            s:New("UIStroke")({
                Color = if equipped then C.gold else rarityColor,
                Thickness = if equipped then 2.5 else 1.5,
                Transparency = 0.15,
            }),
            -- Rarity-полоска сверху.
            s:New("Frame")({
                Size = UDim2.new(1, 0, 0, 3),
                BackgroundColor3 = rarityColor,
                BorderSizePixel = 0,
                ZIndex = 2,
                [Children] = { s:New("UICorner")({ CornerRadius = UDim.new(0, 3) }) },
            }),
            -- Иконка пета.
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, 38),
                Position = UDim2.new(0, 0, 0, 8),
                BackgroundTransparency = 1,
                Text = def.icon,
                TextScaled = true,
                Font = Enum.Font.GothamBold,
                TextColor3 = rarityColor,
                ZIndex = 2,
            }),
            -- Имя пета.
            s:New("TextLabel")({
                Size = UDim2.new(1, -6, 0, 14),
                Position = UDim2.new(0, 3, 0, 48),
                BackgroundTransparency = 1,
                Text = def.name,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.textMain,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 2,
            }),
            -- Эффект.
            s:New("TextLabel")({
                Size = UDim2.new(1, -6, 0, 14),
                Position = UDim2.new(0, 3, 0, 64),
                BackgroundTransparency = 1,
                Text = PetLogic.effectShort(def.effect),
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextColor3 = rarityColor,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 2,
            }),
            -- Статус-строка: «✓ ЭКИПИРОВАН» / «Экипировать».
            s:New("TextLabel")({
                Size = UDim2.new(1, -6, 0, 16),
                Position = UDim2.new(0, 3, 1, -20),
                BackgroundTransparency = 1,
                Text = if equipped then "✓ НАДЕТ" else "надеть",
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                TextColor3 = if equipped then C.gold else C.textMuted,
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = 2,
            }),
            -- Клик-оверлей (ZIndex выше всего, прозрачный).
            s:New("TextButton")({
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 5,
                [OnEvent("MouseEnter")] = function()
                    hovered:set(true)
                end,
                [OnEvent("MouseLeave")] = function()
                    hovered:set(false)
                end,
                [OnEvent("Activated")] = function()
                    if props.onToggle then
                        props.onToggle(props.uid, equipped)
                    end
                end,
            }),
        },
    })
end

return PetCard
