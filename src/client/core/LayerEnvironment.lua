--!strict
-- Плавная смена освещения по текущему слою — ощущение «спуска вглубь».
-- Phase 4: твин Ambient/OutdoorAmbient/FogColor по Constants.LAYERS.bgColor.
-- Phase 14: + Brightness / ClockTime / FogEnd и Atmosphere.Density по
-- Constants.LAYER_LIGHTING (dirt = яркий полдень → void = почти тьма).
-- Без fullscreen post-processing (нет ColorCorrection/Bloom) — в духе Phase 7
-- весь визуал локален в окружении, не в «глазах» игрока.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("shared")
local Constants = require(shared.constants)
local LayerProfile = require(shared.data.LayerProfile)
local LayerUtil = require(shared.util.LayerUtil)
local Logger = require(shared.util.Logger)

local TWEEN_DURATION = 1.2
local ATMOSPHERE_NAME = "DeepDigger_LayerAtmosphere"

local LayerEnvironment = {}
LayerEnvironment.__index = LayerEnvironment

function LayerEnvironment.new()
    local self = setmetatable({}, LayerEnvironment)
    self._log = Logger.new("LayerEnvironment")
    self._currentLayerId = ""
    self._activeTween = nil :: Tween?
    self._atmosphereTween = nil :: Tween?
    self._atmosphere = nil :: Atmosphere?
    return self
end

local function dim(color: Color3, factor: number): Color3
    return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

-- Ленивое создание единственного Atmosphere-инстанса. Atmosphere — это
-- environment-объект (не post-processing эффект), даёт глубинный туман-дымку,
-- который сгущается с глубиной. Создаём при первом apply, переиспользуем.
function LayerEnvironment:_ensureAtmosphere(): Atmosphere?
    if self._atmosphere and self._atmosphere.Parent then
        return self._atmosphere
    end
    local existing = Lighting:FindFirstChild(ATMOSPHERE_NAME)
    if existing and existing:IsA("Atmosphere") then
        self._atmosphere = existing
        return existing
    end
    local atmo = Instance.new("Atmosphere")
    atmo.Name = ATMOSPHERE_NAME
    atmo.Density = 0.3
    atmo.Offset = 0.25
    atmo.Glare = 0
    atmo.Haze = 1
    atmo.Parent = Lighting
    self._atmosphere = atmo
    return atmo
end

function LayerEnvironment:apply(layerId: string)
    if layerId == self._currentLayerId then
        return
    end
    self._currentLayerId = layerId

    local layer = LayerUtil.getLayer(layerId)
    if not layer then
        return
    end

    if self._activeTween then
        self._activeTween:Cancel()
        self._activeTween = nil
    end

    local bg = layer.bgColor
    local light = Constants.LAYER_LIGHTING[layerId] or Constants.LAYER_LIGHTING.dirt
    self._log:info("Layer environment:", layer.name)

    self._activeTween = TweenService:Create(
        Lighting,
        TweenInfo.new(TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Ambient = dim(bg, 0.55),
            OutdoorAmbient = dim(bg, 0.35),
            FogColor = dim(bg, 0.25),
            FogStart = light.fogStart or 0,
            FogEnd = light.fogEnd,
            Brightness = light.brightness,
            ClockTime = light.clockTime,
        }
    )
    self._activeTween:Play()

    -- Atmosphere: дымка цвета слоя, плотность растёт с глубиной. Color/Decay
    -- подкрашивают дальний туман под слой, Density/Haze — «густоту воздуха».
    local atmo = self:_ensureAtmosphere()
    if atmo then
        if self._atmosphereTween then
            self._atmosphereTween:Cancel()
            self._atmosphereTween = nil
        end
        local profile = LayerProfile.IDENTITY[layerId]
        local glare = if profile and profile.atmosphereGlare then profile.atmosphereGlare else 0
        self._atmosphereTween = TweenService:Create(
            atmo,
            TweenInfo.new(TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Density = light.atmosphereDensity,
                Haze = light.atmosphereHaze,
                Color = dim(bg, 0.6),
                Decay = dim(bg, 0.4),
                Glare = glare,
            }
        )
        self._atmosphereTween:Play()
    end
end

function LayerEnvironment:reset()
    self._currentLayerId = ""
    if self._activeTween then
        self._activeTween:Cancel()
        self._activeTween = nil
    end
    if self._atmosphereTween then
        self._atmosphereTween:Cancel()
        self._atmosphereTween = nil
    end
    local dirt = LayerUtil.getLayer("dirt")
    if dirt then
        self:apply("dirt")
    end
end

return LayerEnvironment
