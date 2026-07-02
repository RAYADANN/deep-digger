--!strict
-- PetsPanel — вкладка «Питомцы»: только экипировка и активные бонусы.
-- Покупка яиц — у машин в Workspace (EggShopModal через EggMachines).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local PanelScale = require(script.Parent.Parent.PanelScale)
local PetCard = require(script.Parent.Parent.components.PetCard)
local BuffEffectChip = require(script.Parent.Parent.components.BuffEffectChip)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local Formatters = require(script.Parent.Parent.formatters)
local SoundManager = require(script.Parent.Parent.Parent.Parent.core.SoundManager)
local Notification = require(script.Parent.Parent.Parent.Notification)
local PetHatchFX = require(script.Parent.Parent.Parent.PetHatchFX)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text

local PetsPanel = {}

-- P1.6 + P2.8: Desert Egg покупается за кристаллы прямо в панели питомцев.
-- Серверный HatchEgg авторитетен (валидация/списание гемов), клиент только
-- шлёт запрос и проигрывает PetHatchFX. eggId жёстко "desert" — единственное
-- gem-яйцо на старте.
local DESERT_EGG_ID = "desert"

local function desertEggDef(): any?
	local eggs = (Constants.PETS or {}).eggs or {}
	return eggs[DESERT_EGG_ID]
end

local function hatchDesertWithGems(count: number, isBusy: any)
	if peek(isBusy) then
		return
	end
	isBusy:set(true)
	SoundManager.play("ui_click")
	task.spawn(function()
		local ok, result = pcall(function()
			return Net:Invoke("HatchEgg", DESERT_EGG_ID, count, "gems")
		end)
		isBusy:set(false)
		if not ok then
			SoundManager.play("buy_fail")
			Notification.show({ text = "Сетевая ошибка", icon = "icon_warning", duration = 2.5 })
			return
		end
		if typeof(result) == "table" and result.success then
			SoundManager.play("sell_success")
			local egg = desertEggDef()
			pcall(function()
				PetHatchFX.play(result.hatched, egg and egg.modelName)
			end)
			return
		end
		if typeof(result) == "table" and result.message then
			SoundManager.play("buy_fail")
			Notification.show({
				text = result.message,
				icon = "icon_gem",
				color = Color3.fromRGB(255, 140, 60),
				duration = 2.5,
			})
		end
	end)
end

local function onTogglePet(uid: string, equipped: boolean)
	task.spawn(function()
		pcall(function()
			if equipped then
				Net:Invoke("UnequipPet", uid)
			else
				Net:Invoke("EquipPet", uid)
			end
		end)
		SoundManager.play("ui_click")
	end)
end

local function boostHeader(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	local chipRow = s:Computed(function(use)
		local fx = use(state.petEffects) or {}
		local children: { Instance } = {
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = PanelScale.pad(6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Wraps = true,
			}),
		}
		if (fx.equippedCount or 0) == 0 then
			children[#children + 1] = s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, sc(28)),
				BackgroundTransparency = 1,
				Text = "Питомец не экипирован — нажми на карточку ниже",
				TextSize = text(12),
				Font = theme.FONT.body,
				TextColor3 = C.textMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				ZIndex = 2,
			})
			return children
		end
		local order = 0
		local function addChip(kind: "damage" | "luck" | "coin" | "multiMine", text: string)
			order += 1
			children[#children + 1] = BuffEffectChip.create(s, {
				kind = kind,
				valueText = text,
				layoutOrder = order,
			})
		end
		if (fx.damage or 1) > 1.001 then
			addChip("damage", ("+%d%% урон"):format(math.floor(((fx.damage or 1) - 1) * 100 + 0.5)))
		end
		if (fx.coin or 0) > 0.001 then
			addChip("coin", ("+%d%% монет"):format(math.floor((fx.coin or 0) * 100 + 0.5)))
		end
		if (fx.luck or 1) > 1.001 then
			addChip("luck", ("+%d%% удача"):format(math.floor(((fx.luck or 1) - 1) * 100 + 0.5)))
		end
		if (fx.multiMine or 0) > 0.001 then
			addChip("multiMine", ("%d%% ×2"):format(math.floor((fx.multiMine or 0) * 100 + 0.5)))
		end
		if order == 0 then
			children[#children + 1] = s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, sc(28)),
				BackgroundTransparency = 1,
				Text = "Питомец экипирован",
				TextSize = text(12),
				Font = theme.FONT.body,
				TextColor3 = C.textSub,
				ZIndex = 2,
			})
		end
		return children
	end)

	return s:New("Frame")({
		Name = "BoostHeader",
		Size = UDim2.new(1, -sc(8), 0, sc(78)),
		BackgroundColor3 = C.btnBg,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
			s:New("UIStroke")({ Color = C.gem, Thickness = sc(1.5), Transparency = 0.4 }),
			s:New("ImageLabel")({
				Size = UDim2.fromOffset(sc(18), sc(18)),
				Position = UDim2.new(0, sc(12), 0, sc(10)),
				BackgroundTransparency = 1,
				Image = UiAssets.tab("pets"),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, -sc(40), 0, sc(18)),
				Position = UDim2.new(0, sc(34), 0, sc(10)),
				BackgroundTransparency = 1,
				Text = "АКТИВНЫЕ БОНУСЫ ПИТОМЦА",
				TextSize = text(12),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textLabel,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("Frame")({
				Name = "ChipRow",
				Size = UDim2.new(1, -sc(24), 0, sc(36)),
				Position = UDim2.new(0, sc(12), 0, sc(34)),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 2,
				[Children] = chipRow,
			}),
		},
	})
end

local function gemHatchButton(
	s: ScopeFactory.HudScope,
	state: HudStateModule.HudState,
	count: number,
	cost: number,
	layoutOrder: number,
	isBusy: any
)
	local hovering = s:Value(false)
	local canAfford = s:Computed(function(use)
		return (use(state.gems) or 0) >= cost and not use(isBusy)
	end)
	return s:New("TextButton")({
		Name = "GemHatch_" .. count,
		Size = UDim2.new(0.5, -sc(5), 1, 0),
		LayoutOrder = layoutOrder,
		AutoButtonColor = false,
		BackgroundColor3 = s:Computed(function(use)
			if not use(canAfford) then
				return C.btnDisabled
			end
			return if use(hovering) then C.bg3 else C.btnBg
		end),
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 2,
		[OnEvent("MouseEnter")] = function()
			hovering:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovering:set(false)
		end,
		[OnEvent("Activated")] = function()
			if peek(canAfford) then
				hatchDesertWithGems(count, isBusy)
			else
				SoundManager.play("buy_fail")
			end
		end,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
			s:New("UIStroke")({ Color = C.gem, Thickness = sc(1.25), Transparency = 0.35 }),
			s:New("TextLabel")({
				Size = UDim2.new(1, -sc(10), 0, sc(16)),
				Position = UDim2.new(0, sc(5), 0, sc(6)),
				BackgroundTransparency = 1,
				Text = ("Открыть %d×"):format(count),
				TextSize = text(13),
				Font = Enum.Font.GothamBlack,
				TextColor3 = s:Computed(function(use)
					return if use(canAfford) then C.textMain else C.textMuted
				end),
				ZIndex = 3,
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, -sc(10), 0, sc(16)),
				Position = UDim2.new(0, sc(5), 0, sc(24)),
				BackgroundTransparency = 1,
				Text = ("%s 💎"):format(Formatters.shortNumber(cost)),
				TextSize = text(13),
				Font = Enum.Font.GothamBold,
				TextColor3 = s:Computed(function(use)
					return if use(canAfford) then C.gem else C.textMuted
				end),
				ZIndex = 3,
			}),
		},
	})
end

local function desertEggSection(s: ScopeFactory.HudScope, state: HudStateModule.HudState, isBusy: any): Instance?
	local egg = desertEggDef()
	local gemCost = egg and tonumber(egg.gemCost) or 0
	if not egg or gemCost <= 0 then
		return nil
	end
	local maxN = math.max(1, math.floor((Constants.PETS or {}).hatchBatchMax or 10))
	return s:New("Frame")({
		Name = "DesertEggShop",
		Size = UDim2.new(1, -sc(8), 0, sc(132)),
		BackgroundColor3 = C.btnBg,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
			s:New("UIStroke")({ Color = C.gem, Thickness = sc(1.5), Transparency = 0.4 }),
			s:New("UIPadding")({
				PaddingTop = PanelScale.pad(10),
				PaddingLeft = PanelScale.pad(12),
				PaddingRight = PanelScale.pad(12),
				PaddingBottom = PanelScale.pad(10),
			}),
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = PanelScale.pad(6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, sc(18)),
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				Text = (egg.name or "Desert Egg") .. " — за кристаллы",
				TextSize = text(13),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textLabel,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("TextLabel")({
				Size = UDim2.new(1, 0, 0, sc(16)),
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				Text = s:Computed(function(use)
					return ("Лучше шансы на редких. У тебя: %s 💎"):format(Formatters.shortNumber(use(state.gems) or 0))
				end),
				TextSize = text(12),
				Font = theme.FONT.body,
				TextColor3 = C.textSub,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("Frame")({
				Name = "Buttons",
				Size = UDim2.new(1, 0, 0, sc(48)),
				LayoutOrder = 3,
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, sc(10)),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					gemHatchButton(s, state, 1, gemCost, 1, isBusy),
					gemHatchButton(s, state, maxN, gemCost * maxN, 2, isBusy),
				},
			}),
		},
	})
end

function PetsPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	local isBusy = s:Value(false)
	return s:New("ScrollingFrame")({
		Name = "Pets",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = PanelScale.scrollBar(),
		ScrollBarImageColor3 = C.panelBorder,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = s:Computed(function(use)
			return use(state.activeTab) == "pets"
		end),
		[Children] = {
			s:New("UIPadding")({
				PaddingTop = PanelScale.pad(4),
				PaddingLeft = PanelScale.pad(4),
				PaddingRight = PanelScale.pad(4),
				PaddingBottom = PanelScale.pad(8),
			}),
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = PanelScale.pad(10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			boostHeader(s, state),
			s:New("TextLabel")({
				Name = "EquipHint",
				Size = UDim2.new(1, -sc(8), 0, sc(36)),
				LayoutOrder = 2,
				BackgroundColor3 = C.bg3,
				BackgroundTransparency = 0.2,
				Text = "  Нажми на питомца, чтобы надеть или снять. Базовые яйца — у машин, Desert Egg — за кристаллы ниже.",
				TextSize = text(12),
				Font = theme.FONT.body,
				TextColor3 = C.textSub,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
				},
			}),
			desertEggSection(s, state, isBusy),
			s:New("TextLabel")({
				Name = "PetsCountLabel",
				Size = UDim2.new(1, -sc(8), 0, sc(20)),
				LayoutOrder = 4,
				BackgroundTransparency = 1,
				Text = s:Computed(function(use)
					local pets = use(state.pets) or {}
					local eq = #(use(state.equippedUids) or {})
					local maxN = use(state.petMaxEquipped) or 1
					return ("Мои питомцы: %d  ·  слотов %d/%d"):format(#pets, eq, maxN)
				end),
				TextSize = text(13),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textLabel,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("Frame")({
				Name = "PetsList",
				Size = UDim2.new(1, -sc(8), 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = C.panelInner,
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
				LayoutOrder = 5,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(0, sc(10)) }),
					s:New("UIStroke")({
						Color = C.dockBorder,
						Thickness = sc(1),
						Transparency = 0.45,
					}),
					s:New("UIPadding")({
						PaddingTop = PanelScale.pad(6),
						PaddingBottom = PanelScale.pad(6),
						PaddingLeft = PanelScale.pad(6),
						PaddingRight = PanelScale.pad(6),
					}),
					s:New("UIGridLayout")({
						CellSize = PetCard.cellSize(),
						CellPadding = UDim2.fromOffset(sc(8), sc(8)),
						SortOrder = Enum.SortOrder.LayoutOrder,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
					}),
					s:Computed(function(use)
						local pets = use(state.pets) or {}
						local cards = {}
						for i, rec in ipairs(pets) do
							cards[#cards + 1] = PetCard.create(s, {
								uid = rec.uid,
								petId = rec.petId,
								equippedUids = state.equippedUids,
								layoutOrder = i,
								onToggle = onTogglePet,
							})
						end
						return cards
					end),
				},
			}),
			s:New("TextLabel")({
				Name = "EmptyState",
				Size = UDim2.new(1, -sc(8), 0, sc(48)),
				LayoutOrder = 6,
				BackgroundTransparency = 1,
				Text = "Пока нет питомцев. Подойди к яйцу на базе и открой его!",
				TextSize = text(13),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textMuted,
				TextWrapped = true,
				Visible = s:Computed(function(use)
					return #(use(state.pets) or {}) == 0
				end),
				ZIndex = 2,
			}),
		},
	})
end

return PetsPanel
