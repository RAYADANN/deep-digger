--!strict
-- HUD.lua — профессиональный интерфейс через Fusion 0.3.

local modules = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Fusion = require(modules.Fusion)
local scope = Fusion.scoped(Fusion)
local player = game:GetService("Players").LocalPlayer
local OnEvent = Fusion.OnEvent
local Children = Fusion.Children

local COLORS = {
    bg = Color3.fromRGB(8, 8, 25), accent = Color3.fromRGB(60, 140, 255),
    gold = Color3.fromRGB(255, 200, 50), green = Color3.fromRGB(55, 220, 55),
    text = Color3.fromRGB(240, 240, 245), border = Color3.fromRGB(40, 40, 70),
}

local HUD = {}
HUD.__index = HUD

local function fmt(n)
    if n >= 1e6 then return string.format("%.2fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(n) end
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

-- Вспомогательная функция: иконка + реактивный текст
local function statLine(icon, valueObj, suffix, color)
    return scope:New("Frame")({
        Size = UDim2.fromOffset(130, 36),
        BackgroundTransparency = 1,
        [Children] = {
            scope:New("TextLabel")({
                Size = UDim2.fromOffset(24, 36), BackgroundTransparency = 1,
                Text = icon, TextSize = 18,
            }),
            scope:New("TextLabel")({
                Position = UDim2.fromOffset(24, 0),
                Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1,
                Text = scope:Computed(function(use)
                    return fmt(use(valueObj)) .. (suffix or "")
                end),
                Font = Enum.Font.GothamBold, TextSize = 18,
                TextColor3 = color or COLORS.text,
                TextStrokeTransparency = 0.3, TextStrokeColor3 = Color3.new(0,0,0),
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        },
    })
end

local function statLevel(icon, valueObj, color)
    return scope:New("Frame")({
        Size = UDim2.fromOffset(110, 36),
        BackgroundTransparency = 1,
        [Children] = {
            scope:New("TextLabel")({
                Size = UDim2.fromOffset(24, 36), BackgroundTransparency = 1,
                Text = icon, TextSize = 18,
            }),
            scope:New("TextLabel")({
                Position = UDim2.fromOffset(24, 0),
                Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1,
                Text = scope:Computed(function(use)
                    return "Lv." .. use(valueObj)
                end),
                Font = Enum.Font.GothamBold, TextSize = 18,
                TextColor3 = color or COLORS.text,
                TextStrokeTransparency = 0.3, TextStrokeColor3 = Color3.new(0,0,0),
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
            scope:New("Frame")({
                Size = UDim2.new(1, 0, 0, 56),
                BackgroundColor3 = COLORS.bg, BackgroundTransparency = 0.15,
                BorderSizePixel = 0,
                [Children] = {
                    -- Нижняя граница
                    scope:New("Frame")({
                        Size = UDim2.new(1, 0, 0, 2),
                        Position = UDim2.new(0, 0, 1, -2),
                        BackgroundColor3 = COLORS.accent, BackgroundTransparency = 0.5,
                        BorderSizePixel = 0,
                    }),
                    -- Статы
                    scope:New("Frame")({
                        Size = UDim2.new(1, -40, 1, 0),
                        Position = UDim2.fromOffset(20, 0),
                        BackgroundTransparency = 1,
                        [Children] = {
                            statLine("🪙", self._coins, "", COLORS.gold),
                            statLine("📏", self._depth, "m", COLORS.text),
                            scope:New("Frame")({
                                Size = UDim2.fromOffset(1, 24),
                                BackgroundColor3 = COLORS.border, BorderSizePixel = 0,
                            }),
                            statLevel("⛏", self._pick, COLORS.accent),
                            statLevel("⚡", self._speed, COLORS.green),
                        },
                    }),
                    -- Кнопка SELL
                    scope:New("ImageButton")({
                        Size = UDim2.fromOffset(130, 38),
                        Position = UDim2.new(1, -150, 0, 9),
                        BackgroundColor3 = Color3.fromRGB(45, 170, 45),
                        BackgroundTransparency = 0.1, BorderSizePixel = 0,
                        [Children] = {
                            scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
                            scope:New("TextLabel")({
                                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                                Text = "💰 SELL ALL", Font = Enum.Font.GothamBold,
                                TextSize = 16, TextColor3 = Color3.new(1,1,1),
                                TextStrokeTransparency = 0.3,
                            }),
                        },
                        [OnEvent("MouseButton1Click")] = function() print("Sell!") end,
                        [OnEvent("MouseEnter")] = function(s) s.BackgroundColor3 = Color3.fromRGB(55,200,55) end,
                        [OnEvent("MouseLeave")] = function(s) s.BackgroundColor3 = Color3.fromRGB(45,170,45) end,
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
