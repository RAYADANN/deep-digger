--!strict
-- HUD.lua — профессиональный интерфейс через Fusion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local modules = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(modules.Fusion)
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local New = Fusion.New
local Value = Fusion.Value
local Computed = Fusion.Computed
local Tween = Fusion.Tween
local Hydrate = Fusion.Hydrate
local OnEvent = Fusion.OnEvent
local Children = Fusion.Children

local HUD = {}
HUD.__index = HUD

-- Цвета темы
local COLORS = {
    bg = Color3.fromRGB(8, 8, 25),
    accent = Color3.fromRGB(60, 140, 255),
    gold = Color3.fromRGB(255, 200, 50),
    green = Color3.fromRGB(55, 220, 55),
    red = Color3.fromRGB(230, 50, 50),
    text = Color3.fromRGB(240, 240, 245),
    muted = Color3.fromRGB(120, 120, 140),
    border = Color3.fromRGB(40, 40, 70),
}

function HUD.new()
    local self = setmetatable({}, HUD)
    -- Реактивное состояние
    self._coins = Value(0)
    self._depth = Value(0)
    self._pickLv = Value(1)
    self._speedLv = Value(1)
    self._gui = nil
    self._created = false
    return self
end

-- Формат чисел
local function fmt(n)
    if n >= 1e6 then return string.format("%.2fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(n) end
end

-- Создать иконку + текст
local function statBlock(icon: string, valueObj, color: Color3?)
    return New("Frame")({
        Size = UDim2.fromOffset(150, 36),
        BackgroundTransparency = 1,
        [Children] = {
            -- Иконка
            New("TextLabel")({
                Size = UDim2.fromOffset(30, 36),
                BackgroundTransparency = 1,
                Text = icon,
                TextSize = 20,
            }),
            -- Значение (реактивное)
            New("TextLabel")({
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -30, 1, 0),
                BackgroundTransparency = 1,
                Text = Computed(function()
                    local v = valueObj:get()
                    return tostring(v)
                end),
                Font = Enum.Font.GothamBold,
                TextSize = 18,
                TextColor3 = color or COLORS.text,
                TextStrokeTransparency = 0.3,
                TextStrokeColor3 = Color3.new(0, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        },
    })
end

-- Числовой блок (монеты/глубина) с анимацией
local function numberBlock(icon: string, valueObj, suffix: string?, color: Color3?)
    return New("Frame")({
        Size = UDim2.fromOffset(150, 36),
        BackgroundTransparency = 1,
        [Children] = {
            New("TextLabel")({
                Size = UDim2.fromOffset(30, 36), BackgroundTransparency = 1,
                Text = icon, TextSize = 20,
            }),
            New("TextLabel")({
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -30, 1, 0), BackgroundTransparency = 1,
                Text = Computed(function()
                    local v = valueObj:get()
                    return fmt(v) .. (suffix or "")
                end),
                Font = Enum.Font.GothamBold, TextSize = 18,
                TextColor3 = color or COLORS.text,
                TextStrokeTransparency = 0.3, TextStrokeColor3 = Color3.new(0, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        },
    })
end

function HUD:create()
    if self._created then return end
    self._created = true

    self._gui = New("ScreenGui")({
        Name = "DeepDigger_HUD",
        Parent = player:WaitForChild("PlayerGui"),
        ResetOnSpawn = false,
        [Children] = {
            -- Верхняя панель (полупрозрачная, с градиентом)
            New("Frame")({
                Size = UDim2.new(1, 0, 0, 56),
                BackgroundColor3 = COLORS.bg,
                BackgroundTransparency = 0.15,
                BorderSizePixel = 0,
                -- Нижняя граница
                [Children] = {
                    New("Frame")({
                        Size = UDim2.new(1, 0, 0, 2),
                        Position = UDim2.new(0, 0, 1, -2),
                        BackgroundColor3 = COLORS.accent,
                        BackgroundTransparency = 0.5,
                        BorderSizePixel = 0,
                    }),
                    -- Статы
                    New("Frame")({
                        Size = UDim2.new(1, -40, 1, 0),
                        Position = UDim2.fromOffset(20, 0),
                        BackgroundTransparency = 1,
                        [Children] = {
                            New("UIListLayout")({
                                FillDirection = Enum.FillDirection.Horizontal,
                                HorizontalAlignment = Enum.HorizontalAlignment.Left,
                                VerticalAlignment = Enum.VerticalAlignment.Center,
                                Padding = UDim.new(0, 25),
                            }),
                            numberBlock("🪙", self._coins, "", COLORS.gold),
                            numberBlock("📏", self._depth, "m", COLORS.text),
                            -- Разделитель
                            New("Frame")({
                                Size = UDim2.fromOffset(1, 24),
                                BackgroundColor3 = COLORS.border,
                                BorderSizePixel = 0,
                            }),
                            statBlock("⛏ Lv.", self._pickLv, COLORS.accent),
                            statBlock("⚡ Lv.", self._speedLv, COLORS.green),
                        },
                    }),
                    -- Кнопка SELL
                    New("ImageButton")({
                        Name = "SellBtn",
                        Size = UDim2.fromOffset(130, 38),
                        Position = UDim2.new(1, -150, 0, 9),
                        BackgroundColor3 = Color3.fromRGB(45, 170, 45),
                        BackgroundTransparency = 0.1,
                        BorderSizePixel = 0,
                        [Children] = {
                            New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
                            New("TextLabel")({
                                Size = UDim2.fromScale(1, 1),
                                BackgroundTransparency = 1,
                                Text = "💰 SELL ALL",
                                Font = Enum.Font.GothamBold,
                                TextSize = 16,
                                TextColor3 = Color3.new(1, 1, 1),
                                TextStrokeTransparency = 0.3,
                            }),
                        },
                        [OnEvent("MouseButton1Click")] = function()
                            print("Sell clicked!")
                        end,
                        [OnEvent("MouseEnter")] = function(self)
                            self.BackgroundColor3 = Color3.fromRGB(55, 200, 55)
                        end,
                        [OnEvent("MouseLeave")] = function(self)
                            self.BackgroundColor3 = Color3.fromRGB(45, 170, 45)
                        end,
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
    if data.pickaxeLevel then self._pickLv:set(data.pickaxeLevel) end
    if data.speedLevel then self._speedLv:set(data.speedLevel) end
end

function HUD:destroy()
    if self._gui then self._gui:Destroy(); self._gui = nil end
    self._created = false
end

return HUD
