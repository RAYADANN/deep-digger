--!strict
-- HUD.lua — главный HUD Deep Digger
-- Стиль: землистый / приключенческий (Terraria)
-- Требует: Fusion установленный в Packages

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages.Fusion)

local New = Fusion.New
local Value = Fusion.Value
local Computed = Fusion.Computed
local Spring = Fusion.Spring
local Observer = Fusion.Observer
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Tween = Fusion.Tween

-- ============================================================
-- Цвета в стиле Terraria / землистый
-- ============================================================
local C = {
    panelBg      = Color3.fromRGB(42,  30,  18),
    panelBorder  = Color3.fromRGB(101, 72,  36),
    panelInner   = Color3.fromRGB(58,  42,  24),
    gold         = Color3.fromRGB(255, 210, 50),
    gem          = Color3.fromRGB(100, 200, 255),
    depthText    = Color3.fromRGB(200, 220, 180),
    layerText    = Color3.fromRGB(240, 200, 120),
    textMain     = Color3.fromRGB(255, 245, 210),
    textMuted    = Color3.fromRGB(160, 140, 100),
    common       = Color3.fromRGB(200, 200, 200),
    uncommon     = Color3.fromRGB(100, 220, 100),
    rare         = Color3.fromRGB(80,  150, 255),
    epic         = Color3.fromRGB(190, 80,  230),
    legendary    = Color3.fromRGB(255, 165, 0),
    mythic       = Color3.fromRGB(255, 60,  60),
    upgradeBg    = Color3.fromRGB(35,  25,  15),
    upgradeBtn   = Color3.fromRGB(80,  55,  25),
    upgradeBtnH  = Color3.fromRGB(120, 85,  35),
    barBg        = Color3.fromRGB(25,  18,  10),
    barFill      = Color3.fromRGB(160, 100, 40),
    barGlow      = Color3.fromRGB(220, 160, 60),
}

local ORE_ICONS: { [string]: string } = {
    dirt = "⬛", pebble = "⬜", clay = "🟫", coal = "🪨",
    root = "🌿", fossil = "🦴", stone = "🪨", copper = "🟧",
    iron = "⚙️", silver = "🔘", gold = "🟡", sapphire = "💎",
    ruby = "🔴",
}

local RARITY_COLOR: { [string]: Color3 } = {
    common = C.common, uncommon = C.uncommon, rare = C.rare,
    epic = C.epic, legendary = C.legendary, mythic = C.mythic,
}

local UPGRADE_NAMES: { [string]: string } = {
    pickaxe = "⛏ Кирка", speed = "⚡ Скорость", fortune = "🍀 Удача",
    inventory = "🎒 Рюкзак", crit = "💥 Крит",
    multiSell = "💰 Продажа", autoSell = "🔄 Авто",
}

-- ============================================================
-- Утилиты
-- ============================================================
local function shortNum(n: number): string
    if n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

local function upgradeCost(base: number, exp: number, level: number): number
    return math.floor(base * (exp ^ (level - 1)))
end

-- Определение редкости по oreId
local EPIC = { sapphire=true, ruby=true, emerald=true, diamond=true, shadow_gem=true, galaxy_opal=true }
local RARE = { fossil=true, silver=true, gold=true, topaz=true, moonstone=true, spirit_shard=true, star_fragment=true }
local UNCOMMON = { coal=true, iron=true, malachite=true, blood_opal=true, amethyst=true, nebula_crystal=true }
local LEGENDARY = { fire_opal=true, astralite=true }
local MYTHIC = { void_crystal=true }

local function oreRarity(oreId: string): string
    if MYTHIC[oreId] then return "mythic"
    elseif LEGENDARY[oreId] then return "legendary"
    elseif EPIC[oreId] then return "epic"
    elseif RARE[oreId] then return "rare"
    elseif UNCOMMON[oreId] then return "uncommon"
    else return "common" end
end

-- ============================================================
-- Слот инвентаря
-- ============================================================
local function InventorySlot(oreId: string, count: number): Frame
    local rarity = oreRarity(oreId)
    local rarColor = RARITY_COLOR[rarity] or C.common
    local icon = ORE_ICONS[oreId] or "❓"
    local isHovered = Value(false)

    return New "Frame" {
        Size = UDim2.new(0, 52, 0, 52),
        BackgroundColor3 = Computed(function()
            return if isHovered:get() then C.upgradeBtnH else C.upgradeBg
        end),
        BorderSizePixel = 0,
        [Children] = {
            New "UICorner" { CornerRadius = UDim.new(0, 6) },
            New "UIStroke" { Color = rarColor, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            New "TextLabel" {
                Size = UDim2.new(1, 0, 0.65, 0), Position = UDim2.new(0, 0, 0, 4),
                BackgroundTransparency = 1, Text = icon, TextScaled = true,
                Font = Enum.Font.GothamBold, TextColor3 = C.textMain,
            },
            New "TextLabel" {
                Size = UDim2.new(1, -4, 0.3, 0), Position = UDim2.new(0, 0, 0.68, 0),
                BackgroundTransparency = 1, Text = shortNum(count), TextSize = 11,
                Font = Enum.Font.GothamBold, TextColor3 = rarColor,
                TextXAlignment = Enum.TextXAlignment.Center,
            },
            New "TextButton" {
                Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 5,
                [OnEvent "MouseEnter"] = function() isHovered:set(true) end,
                [OnEvent "MouseLeave"] = function() isHovered:set(false) end,
            },
        },
    }
end

-- ============================================================
-- Кнопка апгрейда
-- ============================================================
local function UpgradeButton(props: {
    upgradeId: string, level: number, maxLevel: number,
    cost: number, coins: number, onBuy: () -> (),
}): Frame
    local canAfford = props.coins >= props.cost
    local isMax = props.level >= props.maxLevel

    return New "Frame" {
        Size = UDim2.new(0, 110, 0, 56),
        BackgroundColor3 = C.upgradeBg, BorderSizePixel = 0,
        [Children] = {
            New "UICorner" { CornerRadius = UDim.new(0, 6) },
            New "UIStroke" { Color = if isMax then C.textMuted elseif canAfford then C.panelBorder else Color3.fromRGB(60,40,20), Thickness = 1.5 },
            New "TextLabel" {
                Size = UDim2.new(1, -8, 0, 18), Position = UDim2.new(0, 4, 0, 4),
                BackgroundTransparency = 1, Text = UPGRADE_NAMES[props.upgradeId] or props.upgradeId,
                TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.layerText,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            },
            New "TextLabel" {
                Size = UDim2.new(0.5, -4, 0, 14), Position = UDim2.new(0, 4, 0, 22),
                BackgroundTransparency = 1,
                Text = if isMax then "МАКС" else ("Lv. " .. props.level),
                TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = if isMax then C.gold else C.textMuted,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
            New "TextLabel" {
                Size = UDim2.new(1, -8, 0, 14), Position = UDim2.new(0, 4, 0, 37),
                BackgroundTransparency = 1,
                Text = if isMax then "" else ("💰 " .. shortNum(props.cost)),
                TextSize = 11, Font = Enum.Font.GothamBold,
                TextColor3 = if isMax then C.textMuted elseif canAfford then C.gold else C.textMuted,
                TextXAlignment = Enum.TextXAlignment.Left,
            },
            New "TextButton" {
                Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 5,
                [OnEvent "MouseEnter"] = function() end,
                [OnEvent "MouseLeave"] = function() end,
                [OnEvent "Activated"] = function() if not isMax and canAfford then props.onBuy() end end,
            },
        },
    }
end

-- ============================================================
-- HUD
-- ============================================================
local HUD = {}
HUD.__index = HUD

function HUD.new(player: Player)
    local self = setmetatable({}, HUD)
    self._coins = Value(0)
    self._gems = Value(0)
    self._depth = Value(0)
    self._layer = Value("Dirt Layer")
    self._maxDepth = Value(1500)
    self._inventory = Value({} :: { { oreId: string, count: number } })
    self._upgrades = Value({} :: { [string]: { level: number, maxLevel: number } })

    self._gui = New "ScreenGui" {
        Name = "DeepDiggerHUD",
        ResetOnSpawn = false, DisplayOrder = 10,
        Parent = player.PlayerGui,
        [Children] = {
            self:_buildTopBar(),
            self:_buildBottomBar(),
        },
    }
    return self
end

function HUD:_buildTopBar(): Frame
    local depthPct = Computed(function()
        return math.clamp(self._depth:get() / math.max(self._maxDepth:get(), 1), 0, 1)
    end)

    return New "Frame" {
        Name = "TopBar",
        Size = UDim2.new(0, 420, 0, 54),
        Position = UDim2.new(0.5, 0, 0, 10),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = C.panelBg, BorderSizePixel = 0,
        [Children] = {
            New "UICorner" { CornerRadius = UDim.new(0, 8) },
            New "UIStroke" { Color = C.panelBorder, Thickness = 2 },
            -- Монеты
            New "Frame" {
                Size = UDim2.new(0, 110, 1, -8), Position = UDim2.new(0, 8, 0, 4),
                BackgroundTransparency = 1,
                [Children] = {
                    New "TextLabel" {
                        Size = UDim2.new(1, 0, 0.45, 0), BackgroundTransparency = 1,
                        Text = "💰 МОНЕТЫ", TextSize = 10, Font = Enum.Font.GothamBold,
                        TextColor3 = C.textMuted, TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    New "TextLabel" {
                        Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.new(0, 0, 0.45, 0),
                        BackgroundTransparency = 1,
                        Text = Computed(function() return shortNum(self._coins:get()) end),
                        TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = C.gold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                },
            },
            New "Frame" { Size = UDim2.new(0, 1, 0.7, 0), Position = UDim2.new(0, 122, 0.15, 0),
                BackgroundColor3 = C.panelBorder, BorderSizePixel = 0 },
            -- Гемы
            New "Frame" {
                Size = UDim2.new(0, 90, 1, -8), Position = UDim2.new(0, 130, 0, 4),
                BackgroundTransparency = 1,
                [Children] = {
                    New "TextLabel" {
                        Size = UDim2.new(1, 0, 0.45, 0), BackgroundTransparency = 1,
                        Text = "💎 ГЕМЫ", TextSize = 10, Font = Enum.Font.GothamBold,
                        TextColor3 = C.textMuted, TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    New "TextLabel" {
                        Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.new(0, 0, 0.45, 0),
                        BackgroundTransparency = 1,
                        Text = Computed(function() return shortNum(self._gems:get()) end),
                        TextSize = 20, Font = Enum.Font.GothamBlack, TextColor3 = C.gem,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                },
            },
            New "Frame" { Size = UDim2.new(0, 1, 0.7, 0), Position = UDim2.new(0, 225, 0.15, 0),
                BackgroundColor3 = C.panelBorder, BorderSizePixel = 0 },
            -- Глубина
            New "Frame" {
                Size = UDim2.new(0, 180, 1, -8), Position = UDim2.new(0, 232, 0, 4),
                BackgroundTransparency = 1,
                [Children] = {
                    New "TextLabel" {
                        Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
                        Text = Computed(function() return self._layer:get() end),
                        TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.layerText,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    New "TextLabel" {
                        Size = UDim2.new(0.6, 0, 0, 20), Position = UDim2.new(0, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = Computed(function() return "⬇ " .. math.floor(self._depth:get()) .. "м" end),
                        TextSize = 18, Font = Enum.Font.GothamBlack, TextColor3 = C.depthText,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    },
                    New "Frame" {
                        Size = UDim2.new(1, 0, 0, 5), Position = UDim2.new(0, 0, 1, -5),
                        BackgroundColor3 = C.barBg, BorderSizePixel = 0, ClipsDescendants = true,
                        [Children] = {
                            New "UICorner" { CornerRadius = UDim.new(1, 0) },
                            New "Frame" {
                                Size = Computed(function() return UDim2.new(depthPct:get(), 0, 1, 0) end),
                                BackgroundColor3 = C.barFill, BorderSizePixel = 0,
                                [Children] = {
                                    New "UICorner" { CornerRadius = UDim.new(1, 0) },
                                    New "UIGradient" {
                                        Color = ColorSequence.new({
                                            ColorSequenceKeypoint.new(0, C.barFill),
                                            ColorSequenceKeypoint.new(1, C.barGlow),
                                        }),
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

function HUD:_buildBottomBar(): Frame
    local tabActive = Value("inventory")

    return New "Frame" {
        Name = "BottomBar",
        Size = UDim2.new(0, 560, 0, 130),
        Position = UDim2.new(0.5, 0, 1, -10),
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = C.panelBg, BorderSizePixel = 0,
        [Children] = {
            New "UICorner" { CornerRadius = UDim.new(0, 8) },
            New "UIStroke" { Color = C.panelBorder, Thickness = 2 },
            -- Табы
            New "Frame" {
                Size = UDim2.new(1, -8, 0, 30), Position = UDim2.new(0, 4, 0, 4),
                BackgroundTransparency = 1,
                [Children] = {
                    New "UIListLayout" { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) },
                    New "TextButton" {
                        Size = UDim2.new(0, 110, 0, 28),
                        BackgroundColor3 = Computed(function()
                            return if tabActive:get() == "inventory" then C.panelBorder else C.panelBg
                        end),
                        BorderSizePixel = 0, Text = "🎒 Инвентарь", TextSize = 12,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = Computed(function()
                            return if tabActive:get() == "inventory" then C.gold else C.textMuted
                        end),
                        [Children] = { New "UICorner" { CornerRadius = UDim.new(0, 4) } },
                        [OnEvent "Activated"] = function() tabActive:set("inventory") end,
                    },
                    New "TextButton" {
                        Size = UDim2.new(0, 110, 0, 28),
                        BackgroundColor3 = Computed(function()
                            return if tabActive:get() == "upgrades" then C.panelBorder else C.panelBg
                        end),
                        BorderSizePixel = 0, Text = "⚒ Апгрейды", TextSize = 12,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = Computed(function()
                            return if tabActive:get() == "upgrades" then C.gold else C.textMuted
                        end),
                        [Children] = { New "UICorner" { CornerRadius = UDim.new(0, 4) } },
                        [OnEvent "Activated"] = function() tabActive:set("upgrades") end,
                    },
                },
            },
            -- Контент: инвентарь
            New "ScrollingFrame" {
                Name = "InventoryContent",
                Size = UDim2.new(1, -8, 0, 82), Position = UDim2.new(0, 4, 0, 38),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                ScrollBarThickness = 4, ScrollBarImageColor3 = C.panelBorder,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.X,
                Visible = Computed(function() return tabActive:get() == "inventory" end),
                [Children] = {
                    New "UIListLayout" { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center },
                    New "UIPadding" { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) },
                    Computed(function()
                        local slots = {}
                        for _, item in ipairs(self._inventory:get()) do
                            table.insert(slots, InventorySlot(item.oreId, item.count))
                        end
                        return slots
                    end),
                },
            },
            -- Контент: апгрейды
            New "ScrollingFrame" {
                Name = "UpgradesContent",
                Size = UDim2.new(1, -8, 0, 82), Position = UDim2.new(0, 4, 0, 38),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                ScrollBarThickness = 4, ScrollBarImageColor3 = C.panelBorder,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.X,
                Visible = Computed(function() return tabActive:get() == "upgrades" end),
                [Children] = {
                    New "UIListLayout" { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center },
                    New "UIPadding" { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) },
                    Computed(function()
                        local btns = {}
                        local upgrades = self._upgrades:get()
                        local coins = self._coins:get()
                        for upgradeId, data in pairs(upgrades) do
                            local Constants = require(ReplicatedStorage.shared.constants)
                            local cfg = Constants.UPGRADES[upgradeId]
                            if cfg then
                                local cost = upgradeCost(cfg.baseCost, cfg.exponent or 1.5, data.level)
                                table.insert(btns, UpgradeButton({
                                    upgradeId = upgradeId,
                                    level = data.level,
                                    maxLevel = cfg.maxLevel,
                                    cost = cost,
                                    coins = coins,
                                    onBuy = function()
                                        local Net = require(Packages.Net)
                                        Net:Invoke("BuyUpgrade", upgradeId)
                                    end,
                                }))
                            end
                        end
                        return btns
                    end),
                },
            },
        },
    }
end

-- ============================================================
-- Публичное API
-- ============================================================
function HUD:setCoins(amount) self._coins:set(amount) end
function HUD:setGems(amount) self._gems:set(amount) end
function HUD:setDepth(depth, layerName)
    self._depth:set(depth)
    self._layer:set(layerName or "Dirt Layer")
end

function HUD:setInventory(inventory)
    local rarityOrder = { mythic=1, legendary=2, epic=3, rare=4, uncommon=5, common=6 }
    table.sort(inventory, function(a, b)
        return (rarityOrder[oreRarity(a.oreId)] or 6) < (rarityOrder[oreRarity(b.oreId)] or 6)
    end)
    self._inventory:set(inventory)
end

function HUD:setUpgrades(playerData)
    local result = {}
    local ids = { "pickaxe", "speed", "fortune", "inventory", "crit", "multiSell" }
    for _, id in ipairs(ids) do
        result[id] = { level = playerData[id .. "Level"] or 1, maxLevel = 100 }
    end
    if playerData.autoSellUnlocked then
        result["autoSell"] = { level = 1, maxLevel = 1 }
    end
    self._upgrades:set(result)
end

function HUD:destroy()
    if self._gui then self._gui:Destroy() end
end

return HUD
