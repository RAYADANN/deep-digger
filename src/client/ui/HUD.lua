--!strict
-- HUD.lua — современный профессиональный интерфейс (Fusion 0.3).

local modules = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Fusion = require(modules.Fusion)
local scope = Fusion.scoped(Fusion)
local player = game:GetService("Players").LocalPlayer
local OnEvent = Fusion.OnEvent
local Children = Fusion.Children

local HUD = {}
HUD.__index = HUD

-- Палитра (тёмная тема, аккуратные акценты)
local C = {
    panel = Color3.fromRGB(10, 12, 22),
    panelBorder = Color3.fromRGB(35, 40, 65),
    gold = Color3.fromRGB(255, 200, 60),
    cyan = Color3.fromRGB(60, 200, 255),
    green = Color3.fromRGB(55, 220, 100),
    text = Color3.fromRGB(220, 225, 235),
    muted = Color3.fromRGB(100, 110, 130),
    sellGreen = Color3.fromRGB(45, 185, 55),
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

-- Один стат-блок
local function statBlock(icon, valueObj, formatFn, color)
    return scope:New("Frame")({
        Size = UDim2.fromOffset(140, 40),
        BackgroundColor3 = Color3.fromRGB(15, 17, 28),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 1,
        BorderColor3 = C.panelBorder,
        [Children] = {
            scope:New("UICorner")({CornerRadius = UDim.new(0, 8)}),
            scope:New("TextLabel")({
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.fromOffset(22, 40),
                BackgroundTransparency = 1,
                Text = icon, TextSize = 16,
            }),
            scope:New("TextLabel")({
                Position = UDim2.fromOffset(36, 0),
                Size = UDim2.new(1, -42, 1, 0),
                BackgroundTransparency = 1,
                Text = scope:Computed(function(use)
                    return formatFn and formatFn(use(valueObj)) or tostring(use(valueObj))
                end),
                Font = Enum.Font.GothamBold,
                TextSize = 16,
                TextColor3 = color or C.text,
                TextStrokeTransparency = 0.5,
                TextStrokeColor3 = Color3.new(0,0,0),
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
            -- Верхняя панель — тёмное стекло
            scope:New("Frame")({
                Size = UDim2.new(1, 0, 0, 64),
                BackgroundColor3 = C.panel,
                BackgroundTransparency = 0.2,
                BorderSizePixel = 0,
                [Children] = {
                    -- Нижнее свечение
                    scope:New("Frame")({
                        Size = UDim2.new(1, 0, 0, 2),
                        Position = UDim2.new(0, 0, 1, -1),
                        BackgroundColor3 = C.cyan,
                        BackgroundTransparency = 0.6,
                        BorderSizePixel = 0,
                    }),
                    -- Левый блок: лого + глубина
                    scope:New("Frame")({
                        Size = UDim2.new(0.5, -20, 1, 0),
                        Position = UDim2.fromOffset(20, 0),
                        BackgroundTransparency = 1,
                        [Children] = {
                            scope:New("TextLabel")({
                                Position = UDim2.fromOffset(0, 8),
                                Size = UDim2.fromOffset(160, 24),
                                BackgroundTransparency = 1,
                                Text = "⛏ DEEP DIGGER",
                                Font = Enum.Font.GothamBlack,
                                TextSize = 18,
                                TextColor3 = C.text,
                                TextStrokeTransparency = 0.5,
                                TextXAlignment = Enum.TextXAlignment.Left,
                            }),
                            scope:New("Frame")({
                                Position = UDim2.fromOffset(0, 36),
                                Size = UDim2.new(1, 0, 0, 22),
                                BackgroundTransparency = 1,
                                [Children] = {
                                    -- 🪙
                                    scope:New("TextLabel")({
                                        Position = UDim2.fromOffset(0, 0),
                                        Size = UDim2.fromOffset(16, 22),
                                        BackgroundTransparency = 1,
                                        Text = "🪙", TextSize = 14,
                                    }),
                                    scope:New("TextLabel")({
                                        Position = UDim2.fromOffset(18, 0),
                                        Size = UDim2.fromOffset(90, 22),
                                        BackgroundTransparency = 1,
                                        Text = scope:Computed(function(use)
                                            return fmt(use(self._coins))
                                        end),
                                        Font = Enum.Font.GothamBold,
                                        TextSize = 16,
                                        TextColor3 = C.gold,
                                        TextStrokeTransparency = 0.4,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                    }),
                                    -- 📏
                                    scope:New("TextLabel")({
                                        Position = UDim2.fromOffset(110, 0),
                                        Size = UDim2.fromOffset(16, 22),
                                        BackgroundTransparency = 1,
                                        Text = "📏", TextSize = 14,
                                    }),
                                    scope:New("TextLabel")({
                                        Position = UDim2.fromOffset(128, 0),
                                        Size = UDim2.fromOffset(100, 22),
                                        BackgroundTransparency = 1,
                                        Text = scope:Computed(function(use)
                                            return use(self._depth) .. "m"
                                        end),
                                        Font = Enum.Font.GothamBold,
                                        TextSize = 14,
                                        TextColor3 = C.text,
                                        TextStrokeTransparency = 0.4,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                    }),
                                },
                            }),
                        },
                    }),
                    -- Правый блок: статы + SELL
                    scope:New("Frame")({
                        Size = UDim2.new(0.5, -20, 1, 0),
                        Position = UDim2.new(1, -20, 0, 0),
                        BackgroundTransparency = 1,
                        [Children] = {
                            -- Уровни
                            scope:New("Frame")({
                                Size = UDim2.fromOffset(200, 40),
                                Position = UDim2.new(1, -340, 0, 12),
                                BackgroundTransparency = 1,
                                [Children] = {
                                    scope:New("TextLabel")({
                                        Position = UDim2.fromOffset(0, 0),
                                        Size = UDim2.fromOffset(90, 20),
                                        BackgroundTransparency = 1,
                                        Text = scope:Computed(function(use)
                                            return "⛏ Lv." .. use(self._pick)
                                        end),
                                        Font = Enum.Font.GothamBold,
                                        TextSize = 14,
                                        TextColor3 = C.cyan,
                                        TextStrokeTransparency = 0.4,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                    }),
                                    scope:New("TextLabel")({
                                        Position = UDim2.fromOffset(100, 0),
                                        Size = UDim2.fromOffset(100, 20),
                                        BackgroundTransparency = 1,
                                        Text = scope:Computed(function(use)
                                            return "⚡ Lv." .. use(self._speed)
                                        end),
                                        Font = Enum.Font.GothamBold,
                                        TextSize = 14,
                                        TextColor3 = C.green,
                                        TextStrokeTransparency = 0.4,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                    }),
                                },
                            }),
                            -- SELL
                            scope:New("ImageButton")({
                                Size = UDim2.fromOffset(120, 40),
                                Position = UDim2.new(1, -130, 0, 12),
                                BackgroundColor3 = C.sellGreen,
                                BackgroundTransparency = 0.15,
                                BorderSizePixel = 0,
                                [Children] = {
                                    scope:New("UICorner")({CornerRadius = UDim.new(0, 10)}),
                                    scope:New("TextLabel")({
                                        Size = UDim2.fromScale(1, 1),
                                        BackgroundTransparency = 1,
                                        Text = "💰 SELL",
                                        Font = Enum.Font.GothamBold,
                                        TextSize = 15,
                                        TextColor3 = Color3.new(1,1,1),
                                        TextStrokeTransparency = 0.3,
                                    }),
                                },
                                [OnEvent("MouseButton1Click")] = function() print("Sell!") end,
                                [OnEvent("MouseEnter")] = function(s)
                                    s.BackgroundColor3 = Color3.fromRGB(55,210,65)
                                    s:TweenSize(UDim2.fromOffset(124, 42), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.15, true)
                                end,
                                [OnEvent("MouseLeave")] = function(s)
                                    s.BackgroundColor3 = C.sellGreen
                                    s:TweenSize(UDim2.fromOffset(120, 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.15, true)
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
