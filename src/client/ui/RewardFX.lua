--!strict
-- RewardFX.lua — Phase 10.
--
-- Visual FX для daily-claim (отличается от RebirthFX тем, что это
-- screen-overlay coin/gem rain, а не world-space chunks вокруг игрока).
-- DailyRewardModal вызывает RewardFX.burst(rarity) после клика [ЗАБРАТЬ].
--
-- Состав:
--   * 60-100 spriteов 💰 падают сверху с rotation + gravity, fade у дна.
--   * 3 shockwave-кольца цвета rarity дня в центре экрана.
--   * Total duration ~1.5с.
--
-- Принципы Phase 7 (mining-style) НЕ нарушаем:
--   * Это retention-фича (daily), не геймплейный momentary feedback.
--   * Полноэкранный effect допустим (модал ВСЁ РАВНО полноэкранный).
--   * pcall-обёртка вокруг всего: если ScreenGui не создался — claim всё
--     равно состоится, сервер уже выдал монеты.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local UiScreen = require(script.Parent.util.UiScreen)

local RewardFX = {}

local FX_GUI_NAME = "DeepDigger_RewardFX"

-- Палитра по rarity (соответствует Constants.RARITY_COLORS, но дублируем
-- инлайн, чтобы не require'ить heavy-модуль).
local RARITY_COLOR: { [string]: Color3 } = {
    common = Color3.fromRGB(220, 220, 220),
    uncommon = Color3.fromRGB(120, 230, 120),
    rare = Color3.fromRGB(80, 160, 255),
    epic = Color3.fromRGB(200, 80, 240),
    legendary = Color3.fromRGB(255, 180, 30),
    mythic = Color3.fromRGB(255, 215, 90),
}

local function ensureGui(): ScreenGui?
    local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    return UiScreen.ensure(pg, FX_GUI_NAME, "fx")
end

local function spawnCoin(parent: ScreenGui, viewportX: number, viewportY: number)
    local size = 28 + math.random() * 12
    local startX = math.random() * viewportX
    local startY = -size - math.random() * 80

    local label = Instance.new("ImageLabel")
    label.Size = UDim2.fromOffset(size, size)
    label.Position = UDim2.fromOffset(startX, startY)
    label.BackgroundTransparency = 1
    label.Image = UiAssets.coin()
    label.ScaleType = Enum.ScaleType.Fit
    label.ImageTransparency = 0
    label.Rotation = math.random() * 360
    label.Parent = parent

    -- Tween: падение к низу + спин. Длительность зависит от стартовой
    -- высоты, но усредняем ~1.2-1.6с.
    local fallTime = 1.2 + math.random() * 0.5
    local endY = viewportY + size + 20
    local rotation = label.Rotation + (math.random() - 0.5) * 720
    local tween = TweenService:Create(label, TweenInfo.new(fallTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
        Position = UDim2.fromOffset(startX + (math.random() - 0.5) * 80, endY),
        Rotation = rotation,
        ImageTransparency = 0.8,
    })
    tween:Play()
    Debris:AddItem(label, fallTime + 0.2)
end

local function spawnShockwave(parent: ScreenGui, color: Color3, delay: number, finalScale: number)
    task.delay(delay, function()
        if not parent.Parent then return end
        local ring = Instance.new("Frame")
        ring.Size = UDim2.fromOffset(20, 20)
        ring.Position = UDim2.fromScale(0.5, 0.5)
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.BackgroundTransparency = 1
        ring.BorderSizePixel = 0
        ring.Parent = parent

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = ring

        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = 4
        stroke.Transparency = 0.1
        stroke.Parent = ring

        local dur = 0.6
        TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(finalScale, finalScale),
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
            Thickness = 1,
        }):Play()
        Debris:AddItem(ring, dur + 0.2)
    end)
end

--[[
    Главный API. Запускает coin-rain + 3 shockwave цвета rarity.
    `rarity` — строка "common".."mythic", дефолт "common".
    Безопасен: если GUI не получилось создать — no-op.
]]
function RewardFX.burst(rarity: string?)
    local ok, err = pcall(function()
        local gui = ensureGui()
        if not gui then return end
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1024, 768)
        local color = RARITY_COLOR[rarity or "common"] or RARITY_COLOR.common

        -- Кол-во монет по rarity: чем эпичнее день, тем больше золота.
        local coinCount = 60
        if rarity == "epic" then coinCount = 80
        elseif rarity == "legendary" then coinCount = 95
        elseif rarity == "mythic" then coinCount = 120
        end

        -- Распределяем спавн по 0..0.4с, чтобы поток был «волной», не одним кадром.
        for i = 1, coinCount do
            task.delay(math.random() * 0.4, function()
                if gui.Parent then
                    spawnCoin(gui, viewport.X, viewport.Y)
                end
            end)
        end

        -- 3 shockwave кольца: финальный размер зависит от viewport
        -- (хотим, чтобы кольцо вышло за края экрана).
        local maxScale = math.max(viewport.X, viewport.Y) * 1.2
        spawnShockwave(gui, color, 0, maxScale * 0.5)
        spawnShockwave(gui, color, 0.18, maxScale * 0.8)
        spawnShockwave(gui, color, 0.4, maxScale * 1.0)
    end)
    if not ok then
        warn("[RewardFX] burst failed:", err)
    end
end

return RewardFX
