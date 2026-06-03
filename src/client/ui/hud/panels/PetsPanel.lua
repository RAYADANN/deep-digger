--!strict
-- PetsPanel.lua — Phase 11 (Pets MVP).
--
-- Контент 6-го таба HUD (🐾 ПИТОМЦЫ). Состав:
--   * Header: индикатор активных бустов от экипированных петов (PetLogic.summary).
--   * Hatch-секция: Basic Egg + кнопки «Открыть 1×» / «Открыть 10×».
--   * Грид owned-петов (PetCard) с equip/unequip по клику.
--
-- КРИТИЧНО (грабли Фазы 10): грид петов собирается через s:Computed ВНУТРИ
-- дерева (в [Children] контейнера-грида), а НЕ инстансами в цикле до s:New —
-- иначе в Fusion 0.3 карточки не парентятся. Паттерн идентичен InventoryPanel /
-- LeaderboardPanel.
--
-- Hatch: Net:Invoke("HatchEgg", count) в task.spawn (не yield'им в обработчике
-- клика). На success → PetHatchFX.play(hatched) + sell-звук. Тосты ошибок —
-- через Notification.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local PetCard = require(script.Parent.Parent.components.PetCard)
-- ui/hud/panels → ui/hud → ui → core / ui-modules.
local SoundManager = require(script.Parent.Parent.Parent.Parent.core.SoundManager)
local Notification = require(script.Parent.Parent.Parent.Notification)
local PetHatchFX = require(script.Parent.Parent.Parent.PetHatchFX)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C

local PetsPanel = {}

local function isEquippedUid(uid: string, equippedUids: { string }): boolean
    for _, u in ipairs(equippedUids) do
        if u == uid then
            return true
        end
    end
    return false
end

local EGG = (Constants.PETS or {}).eggs and Constants.PETS.eggs.basic or { name = "Basic Egg", icon = "🥚", cost = 1000 }
local HATCH_MAX = (Constants.PETS or {}).hatchBatchMax or 10

--[[
    Выполнить hatch count яиц. Net:Invoke в task.spawn — не yield'им в клике.
]]
local function doHatch(state: HudStateModule.HudState, count: number, isBusy: any)
    if peek(isBusy) then
        return
    end
    local n = math.clamp(math.floor(count), 1, HATCH_MAX)
    local cost = (EGG.cost or 0) * n
    local coins = peek(state.coins) or 0
    if coins < cost then
        SoundManager.play("buy_fail")
        Notification.show({
            text = ("Не хватает %d монет на %d 🥚"):format(cost - coins, n),
            icon = "🥚",
            color = Color3.fromRGB(255, 140, 60),
            duration = 2.5,
        })
        return
    end

    isBusy:set(true)
    task.spawn(function()
        local ok, result = pcall(function()
            return Net:Invoke("HatchEgg", n)
        end)
        isBusy:set(false)
        if not ok then
            SoundManager.play("buy_fail")
            Notification.show({
                text = "Сетевая ошибка открытия яйца",
                icon = "⚠",
                color = Color3.fromRGB(255, 140, 60),
                duration = 2.5,
            })
            return
        end
        if typeof(result) == "table" and result.success then
            SoundManager.play("sell_success")
            -- FX-ревил: PetHatchFX сам разрулит 1× и 10×. Падение FX не
            -- срывает hatch — пет уже в профиле (сервер прислал PlayerStats).
            pcall(function()
                PetHatchFX.play(result.hatched)
            end)
            return
        end
        if typeof(result) == "table" and result.message then
            SoundManager.play("buy_fail")
            Notification.show({
                text = result.message,
                icon = "🥚",
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

-- Header: индикатор бустов от экипированных петов.
local function boostHeader(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("Frame")({
        Name = "BoostHeader",
        Size = UDim2.new(1, -8, 0, 64),
        BackgroundColor3 = C.btnBg,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
            s:New("UIStroke")({ Color = C.gem, Thickness = 1.5, Transparency = 0.4 }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -16, 0, 18),
                Position = UDim2.new(0, 12, 0, 8),
                BackgroundTransparency = 1,
                Text = "🐾 АКТИВНЫЕ БОНУСЫ ПИТОМЦА",
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.textLabel,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -16, 0, 28),
                Position = UDim2.new(0, 12, 0, 28),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local fx = use(state.petEffects) or {}
                    if (fx.equippedCount or 0) == 0 then
                        return "Питомец не экипирован — нажми на карточку ниже"
                    end
                    local parts = {}
                    if (fx.damage or 1) > 1 then
                        table.insert(parts, ("⚔ +%d%% урон"):format(math.floor(((fx.damage or 1) - 1) * 100 + 0.5)))
                    end
                    if (fx.coin or 0) > 0 then
                        table.insert(parts, ("💰 +%d%% монет"):format(math.floor((fx.coin or 0) * 100 + 0.5)))
                    end
                    if (fx.luck or 1) > 1 then
                        table.insert(parts, ("✨ +%d%% удача"):format(math.floor(((fx.luck or 1) - 1) * 100 + 0.5)))
                    end
                    if (fx.multiMine or 0) > 0 then
                        table.insert(parts, ("⛏ %d%% ×2 блока"):format(math.floor((fx.multiMine or 0) * 100 + 0.5)))
                    end
                    if #parts == 0 then
                        return "Питомец экипирован"
                    end
                    return table.concat(parts, "   ")
                end),
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.gold,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                ZIndex = 2,
            }),
        },
    })
end

-- Hatch-секция: яйцо + кнопки 1× / 10×.
local function hatchSection(s: ScopeFactory.HudScope, state: HudStateModule.HudState, isBusy: any)
    local function hatchButton(label: string, count: number, layoutOrder: number)
        local hovered = s:Value(false)
        local cost = (EGG.cost or 0) * count
        local canAfford = s:Computed(function(use)
            return (use(state.coins) or 0) >= cost
        end)
        return s:New("TextButton")({
            Name = "HatchButton_" .. count,
            Size = UDim2.new(0.5, -6, 1, 0),
            LayoutOrder = layoutOrder,
            AutoButtonColor = false,
            BackgroundColor3 = s:Computed(function(use)
                if use(isBusy) or not use(canAfford) then
                    return C.btnDisabled
                end
                return use(hovered) and Color3.fromRGB(220, 180, 30) or C.gold
            end),
            BorderSizePixel = 0,
            Text = ("%s  (%s 💰)"):format(label, Formatters.shortNumber(cost)),
            TextSize = 15,
            Font = Enum.Font.GothamBlack,
            TextColor3 = s:Computed(function(use)
                return if use(canAfford) and not use(isBusy)
                    then Color3.fromRGB(40, 25, 0)
                    else C.textMuted
            end),
            [Children] = {
                s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
                s:New("UIStroke")({
                    Color = s:Computed(function(use)
                        return use(canAfford) and Color3.fromRGB(255, 240, 150) or C.btnBorder
                    end),
                    Thickness = 2,
                    Transparency = 0.2,
                }),
            },
            [OnEvent("MouseEnter")] = function() hovered:set(true) end,
            [OnEvent("MouseLeave")] = function() hovered:set(false) end,
            [OnEvent("Activated")] = function()
                doHatch(state, count, isBusy)
            end,
        })
    end

    return s:New("Frame")({
        Name = "HatchSection",
        Size = UDim2.new(1, -8, 0, 92),
        BackgroundColor3 = C.btnBg,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
            s:New("UIStroke")({ Color = C.gold, Thickness = 1.5, Transparency = 0.4 }),
            -- Заголовок яйца.
            s:New("TextLabel")({
                Size = UDim2.new(1, -16, 0, 24),
                Position = UDim2.new(0, 12, 0, 8),
                BackgroundTransparency = 1,
                Text = ("%s %s — %s 💰 за яйцо"):format(EGG.icon or "🥚", EGG.name or "Basic Egg", Formatters.shortNumber(EGG.cost or 0)),
                TextSize = 14,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.textMain,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }),
            -- Контейнер кнопок.
            s:New("Frame")({
                Size = UDim2.new(1, -24, 0, 44),
                Position = UDim2.new(0, 12, 0, 38),
                BackgroundTransparency = 1,
                [Children] = {
                    s:New("UIListLayout")({
                        FillDirection = Enum.FillDirection.Horizontal,
                        Padding = UDim.new(0, 12),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    hatchButton("Открыть 1×", 1, 1),
                    hatchButton("Открыть " .. HATCH_MAX .. "×", HATCH_MAX, 2),
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
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "pets"
        end),
        [Children] = {
            s:New("UIPadding")({
                PaddingTop = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 8),
            }),
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 10),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            boostHeader(s, state),
            hatchSection(s, state, isBusy),
            -- Заголовок «Мои питомцы: N».
            s:New("TextLabel")({
                Name = "PetsCountLabel",
                Size = UDim2.new(1, -8, 0, 20),
                LayoutOrder = 3,
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local pets = use(state.pets) or {}
                    local eq = #(use(state.equippedUids) or {})
                    local maxN = use(state.petMaxEquipped) or 1
                    return ("Мои питомцы: %d  ·  слотов %d/%d"):format(#pets, eq, maxN)
                end),
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.textLabel,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
            }),
            -- Грид петов. Computed ВНУТРИ [Children] (Phase 10 grab #2).
            s:New("Frame")({
                Name = "PetsGrid",
                Size = UDim2.new(1, -8, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = 4,
                [Children] = {
                    s:New("UIGridLayout")({
                        CellSize = UDim2.new(0, 92, 0, 108),
                        CellPadding = UDim2.new(0, 8, 0, 8),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    s:Computed(function(use)
                        local cards = {}
                        local pets = use(state.pets) or {}
                        local equippedUids = use(state.equippedUids) or {}
                        for i, rec in ipairs(pets) do
                            cards[#cards + 1] = PetCard.create(s, {
                                uid = rec.uid,
                                petId = rec.petId,
                                equipped = isEquippedUid(rec.uid, equippedUids),
                                layoutOrder = i,
                                onToggle = onTogglePet,
                            })
                        end
                        return cards
                    end),
                },
            }),
            -- Empty-state.
            s:New("TextLabel")({
                Name = "EmptyState",
                Size = UDim2.new(1, -8, 0, 40),
                LayoutOrder = 5,
                BackgroundTransparency = 1,
                Text = "🥚 Открой яйцо, чтобы получить первого питомца!",
                TextSize = 13,
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
