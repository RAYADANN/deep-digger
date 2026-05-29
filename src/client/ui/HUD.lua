--!strict
-- HUD.lua — UI в стиле Infinite Mining Incremental (топ-игр Roblox)

local modules = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Fusion = require(modules.Fusion)
local scope = Fusion.scoped(Fusion)
local player = game:GetService("Players").LocalPlayer
local OnEvent = Fusion.OnEvent
local Children = Fusion.Children

local HUD = {}
HUD.__index = HUD

-- Палитра как в топ Roblox mining играх
local C = {
    panel = Color3.fromRGB(18, 20, 35),
    panelBorder = Color3.fromRGB(40, 45, 70),
    card = Color3.fromRGB(25, 28, 45),
    gold = Color3.fromRGB(255, 195, 40),
    cyan = Color3.fromRGB(50, 210, 255),
    green = Color3.fromRGB(50, 220, 80),
    red = Color3.fromRGB(230, 60, 60),
    purple = Color3.fromRGB(160, 80, 255),
    text = Color3.fromRGB(220, 225, 235),
    muted = Color3.fromRGB(100, 110, 135),
    btnSell = Color3.fromRGB(45, 190, 55),
    white = Color3.new(1, 1, 1),
}

local function fmt(n)
    if n >= 1e6 then return ("%.2fM"):format(n/1e6)
    elseif n >= 1e3 then return ("%.1fK"):format(n/1e3)
    else return tostring(math.floor(n)) end
end

function HUD.new()
    local self = setmetatable({}, HUD)
    self._coins = scope:Value(0)
    self._depth = scope:Value(0)
    self._pick = scope:Value(1)
    self._speed = scope:Value(1)
    self._gui = nil; self._created = false
    return self
end

-- Утилита: текст с тенью
local function txt(overrides)
    local props = {
        Font = Enum.Font.GothamBold,
        TextColor3 = C.text,
        TextStrokeTransparency = 0.4,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
    }
    for k, v in pairs(overrides) do props[k] = v end
    return scope:New("TextLabel")(props)
end

-- Блок-карточка для статов
local function statCard(icon, valueObj, suffix, iconColor, valColor)
    return scope:New("Frame")({
        Size = UDim2.fromOffset(145, 42),
        BackgroundColor3 = C.card,
        BorderSizePixel = 1,
        BorderColor3 = C.panelBorder,
        [Children] = {
            scope:New("UICorner")({CornerRadius = UDim.new(0, 10)}),
            -- Иконка слева
            txt({Text = icon, Size = UDim2.fromOffset(26, 42), TextSize = 16, Position = UDim2.fromOffset(8, 0)}),
            -- Значение справа
            txt({
                Position = UDim2.fromOffset(38, 0),
                Size = UDim2.new(1, -44, 1, 0),
                Text = scope:Computed(function(use)
                    local v = use(valueObj)
                    return fmt(v) .. (suffix or "")
                end),
                TextSize = 18,
                TextColor3 = valColor or C.white,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        },
    })
end

-- Уровень (иконка + Lv.X)
local function levelCard(icon, valueObj, color)
    return scope:New("Frame")({
        Size = UDim2.fromOffset(110, 34),
        BackgroundColor3 = C.card,
        BorderSizePixel = 1,
        BorderColor3 = C.panelBorder,
        [Children] = {
            scope:New("UICorner")({CornerRadius = UDim.new(0, 8)}),
            txt({Text = icon, Size = UDim2.fromOffset(22, 34), TextSize = 14, Position = UDim2.fromOffset(6, 0)}),
            txt({
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -34, 1, 0),
                Text = scope:Computed(function(use) return "Lv." .. use(valueObj) end),
                TextSize = 14, TextColor3 = color or C.white,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        },
    })
end

function HUD:create()
    if self._created then return end
    self._created = true

    self._gui = scope:New("ScreenGui")({
        Name = "DeepDigger_HUD",
        Parent = player:WaitForChild("PlayerGui"),
        ResetOnSpawn = false,
        [Children] = {
            -- === ВЕРХНЯЯ ПАНЕЛЬ ===
            scope:New("Frame")({
                Size = UDim2.new(1, 0, 0, 60),
                BackgroundColor3 = C.panel,
                BackgroundTransparency = 0.1,
                BorderSizePixel = 0,
                [Children] = {
                    -- Нижняя линия-акцент
                    scope:New("Frame")({
                        Size = UDim2.new(1, 0, 0, 1),
                        Position = UDim2.new(0, 0, 1, 0),
                        BackgroundColor3 = C.cyan,
                        BackgroundTransparency = 0.7,
                        BorderSizePixel = 0,
                    }),
                    -- Левая часть: лого + монеты + глубина
                    scope:New("Frame")({
                        Size = UDim2.fromOffset(420, 60),
                        BackgroundTransparency = 1,
                        [Children] = {
                            -- Логотип
                            txt({
                                Position = UDim2.fromOffset(16, 6),
                                Size = UDim2.fromOffset(140, 22),
                                Text = "⛏️ DEEP DIGGER",
                                TextSize = 16,
                                TextColor3 = C.white,
                                TextXAlignment = Enum.TextXAlignment.Left,
                            }),
                            -- Строка со статами
                            scope:New("Frame")({
                                Position = UDim2.fromOffset(16, 30),
                                Size = UDim2.fromOffset(400, 26),
                                BackgroundTransparency = 1,
                                [Children] = {
                                    -- 🪙
                                    txt({
                                        Size = UDim2.fromOffset(18, 26), TextSize = 14,
                                        Text = "🪙",
                                    }),
                                    txt({
                                        Position = UDim2.fromOffset(20, 0),
                                        Size = UDim2.fromOffset(90, 26),
                                        Text = scope:Computed(function(use)
                                            return fmt(use(self._coins))
                                        end),
                                        TextSize = 16, TextColor3 = C.gold,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                    }),
                                    -- 📏 разделитель
                                    txt({
                                        Position = UDim2.fromOffset(115, 0),
                                        Size = UDim2.fromOffset(14, 26),
                                        Text = "|", TextSize = 14, TextColor3 = C.muted,
                                    }),
                                    -- 📏
                                    txt({
                                        Position = UDim2.fromOffset(130, 0),
                                        Size = UDim2.fromOffset(18, 26), TextSize = 14,
                                        Text = "📏",
                                    }),
                                    txt({
                                        Position = UDim2.fromOffset(150, 0),
                                        Size = UDim2.fromOffset(100, 26),
                                        Text = scope:Computed(function(use)
                                            return use(self._depth) .. "m"
                                        end),
                                        TextSize = 16, TextColor3 = C.text,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                    }),
                                },
                            }),
                        },
                    }),
                    -- Правая часть: уровни + кнопка SELL
                    scope:New("Frame")({
                        Size = UDim2.new(0.5, -20, 1, 0),
                        Position = UDim2.new(1, -20, 0, 0),
                        BackgroundTransparency = 1,
                        [Children] = {
                            -- уровни
                            scope:New("Frame")({
                                Position = UDim2.new(1, -280, 0, 0),
                                Size = UDim2.fromOffset(240, 60),
                                BackgroundTransparency = 1,
                                [Children] = {
                                    levelCard("⛏", self._pick, C.cyan),
                                    scope:New("Frame")({
                                        Position = UDim2.fromOffset(0, 28),
                                        BackgroundTransparency = 1,
                                        Size = UDim2.fromOffset(110, 34),
                                        [Children] = {
                                            levelCard("⚡", self._speed, C.green),
                                        },
                                    }),
                                },
                            }),
                            -- SELL
                            scope:New("ImageButton")({
                                Size = UDim2.fromOffset(125, 40),
                                Position = UDim2.new(1, -135, 0, 10),
                                BackgroundColor3 = C.btnSell,
                                BackgroundTransparency = 0.1,
                                BorderSizePixel = 0,
                                [Children] = {
                                    scope:New("UICorner")({CornerRadius = UDim.new(0, 10)}),
                                    txt({
                                        Text = "💰 SELL", TextSize = 16, TextColor3 = C.white,
                                        Font = Enum.Font.GothamBlack,
                                    }),
                                },
                                [OnEvent("MouseButton1Click")] = function() print("Sell!") end,
                                [OnEvent("MouseEnter")] = function(s)
                                    s.BackgroundColor3 = Color3.fromRGB(55,210,65)
                                    s:TweenSize(UDim2.fromOffset(129, 42), nil, nil, 0.12, true)
                                end,
                                [OnEvent("MouseLeave")] = function(s)
                                    s.BackgroundColor3 = C.btnSell
                                    s:TweenSize(UDim2.fromOffset(125, 40), nil, nil, 0.12, true)
                                end,
                            }),
                        },
                    }),
                },
            }),
        },
    })
end

function HUD:update(data)
    if not self._created then self:create() end
    if data.coins then self._coins:set(data.coins) end
    if data.depth then self._depth:set(data.depth) end
    if data.pickaxeLevel then self._pick:set(data.pickaxeLevel) end
    if data.speedLevel then self._speed:set(data.speedLevel) end
end

function HUD:destroy()
    if self._gui then self._gui:Destroy(); self._gui = nil end
    self._created = false
end

return HUD
