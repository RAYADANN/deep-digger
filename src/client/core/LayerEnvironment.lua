--!strict
-- Плавная смена освещения по текущему слою (Constants.LAYERS.bgColor).

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LayerUtil = require(ReplicatedStorage:WaitForChild("shared").util.LayerUtil)
local Logger = require(ReplicatedStorage:WaitForChild("shared").util.Logger)

local TWEEN_DURATION = 1.2

local LayerEnvironment = {}
LayerEnvironment.__index = LayerEnvironment

function LayerEnvironment.new()
    local self = setmetatable({}, LayerEnvironment)
    self._log = Logger.new("LayerEnvironment")
    self._currentLayerId = ""
    self._activeTween = nil :: Tween?
    return self
end

local function dim(color: Color3, factor: number): Color3
    return Color3.new(color.R * factor, color.G * factor, color.B * factor)
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
    self._log:info("Layer environment:", layer.name)

    self._activeTween = TweenService:Create(
        Lighting,
        TweenInfo.new(TWEEN_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Ambient = dim(bg, 0.55),
            OutdoorAmbient = dim(bg, 0.35),
            FogColor = dim(bg, 0.25),
            FogEnd = 600,
        }
    )
    self._activeTween:Play()
end

function LayerEnvironment:reset()
    self._currentLayerId = ""
    if self._activeTween then
        self._activeTween:Cancel()
        self._activeTween = nil
    end
    local dirt = LayerUtil.getLayer("dirt")
    if dirt then
        self:apply("dirt")
    end
end

return LayerEnvironment
