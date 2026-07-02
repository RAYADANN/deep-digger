--!strict
-- LayerAmbience — ambient-звук, туман и частицы воздуха при смене слоя.
-- Данные: LayerProfile.IDENTITY. Параллелен LayerEnvironment (свет/Atmosphere).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")

local LayerProfile = require(shared.data.LayerProfile)
local Logger = require(shared.util.Logger)
local SoundManager = require(script.Parent.SoundManager)

export type ParticleCfg = {
    color: Color3,
    rate: number,
    speedMin: number,
    speedMax: number,
    size: number,
    lightEmission: number,
}

export type FogCfg = {
    color: Color3,
    rate: number,
    size: number,
    lightEmission: number,
}

export type LayerAmbience = {
    _log: any,
    _currentLayerId: string,
    _particleHost: BasePart?,
    _sparkleEmitter: ParticleEmitter?,
    _fogEmitter: ParticleEmitter?,
    apply: (self: LayerAmbience, layerId: string, character: Model?, playEnter: boolean?) -> (),
    reset: (self: LayerAmbience) -> (),
    destroy: (self: LayerAmbience) -> (),
}

local LayerAmbience = {}
LayerAmbience.__index = LayerAmbience

local HOST_NAME = "DeepDigger_LayerParticles"

function LayerAmbience.new(): LayerAmbience
    local self = setmetatable({}, LayerAmbience) :: LayerAmbience
    self._log = Logger.new("LayerAmbience")
    self._currentLayerId = ""
    self._particleHost = nil
    self._sparkleEmitter = nil
    self._fogEmitter = nil
    return self
end

function LayerAmbience:_clearParticles()
    if self._particleHost then
        self._particleHost:Destroy()
        self._particleHost = nil
        self._sparkleEmitter = nil
        self._fogEmitter = nil
    end
end

function LayerAmbience:_ensureParticleHost(character: Model): BasePart?
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return nil end

    if self._particleHost and self._particleHost.Parent then
        return self._particleHost
    end

    local host = Instance.new("Part")
    host.Name = HOST_NAME
    host.Size = Vector3.new(14, 10, 14)
    host.Transparency = 1
    host.Anchored = false
    host.CanCollide = false
    host.CanTouch = false
    host.CanQuery = false
    host.CastShadow = false
    host.Massless = true
    host.CFrame = root.CFrame
    host.Parent = character

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = host
    weld.Parent = host

    self._particleHost = host
    return host
end

function LayerAmbience:_makeSparkleEmitter(host: BasePart, cfg: ParticleCfg): ParticleEmitter
    local e = Instance.new("ParticleEmitter")
    e.Name = "LayerSparkles"
    e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    e.Color = ColorSequence.new(cfg.color)
    e.LightEmission = cfg.lightEmission
    e.LightInfluence = 0.35
    e.Rate = cfg.rate
    e.Lifetime = NumberRange.new(2.5, 4.5)
    e.Speed = NumberRange.new(cfg.speedMin, cfg.speedMax)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, cfg.size),
        NumberSequenceKeypoint.new(1, 0),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.VelocityInheritance = 0.2
    e.Acceleration = Vector3.new(0, 0.3, 0)
    e.Parent = host
    return e
end

function LayerAmbience:_makeFogEmitter(host: BasePart, cfg: FogCfg): ParticleEmitter
    local e = Instance.new("ParticleEmitter")
    e.Name = "LayerFog"
    e.Texture = "rbxasset://textures/particles/smoke_main.dds"
    e.Color = ColorSequence.new(cfg.color)
    e.LightEmission = cfg.lightEmission
    e.LightInfluence = 0.2
    e.Rate = cfg.rate
    e.Lifetime = NumberRange.new(4, 7)
    e.Speed = NumberRange.new(0.2, 0.8)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-15, 15)
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, cfg.size * 0.6),
        NumberSequenceKeypoint.new(0.5, cfg.size),
        NumberSequenceKeypoint.new(1, cfg.size * 1.2),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.55),
        NumberSequenceKeypoint.new(0.5, 0.7),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.VelocityInheritance = 0.05
    e.Acceleration = Vector3.new(0, 0.15, 0)
    e.Drag = 1.5
    e.Parent = host
    return e
end

function LayerAmbience:_applyParticles(character: Model?, sparkleCfg: ParticleCfg?, fogCfg: FogCfg?)
    self:_clearParticles()
    if not character or (not sparkleCfg and not fogCfg) then return end
    local host = self:_ensureParticleHost(character)
    if not host then return end

    if sparkleCfg then
        self._sparkleEmitter = self:_makeSparkleEmitter(host, sparkleCfg)
    end
    if fogCfg then
        self._fogEmitter = self:_makeFogEmitter(host, fogCfg)
    end
end

function LayerAmbience:apply(layerId: string, character: Model?, playEnter: boolean?)
    if layerId == self._currentLayerId then
        return
    end
    self._currentLayerId = layerId

    local profile = LayerProfile.IDENTITY[layerId]
    if not profile then
        SoundManager.stopLoop(0.5)
        self:_clearParticles()
        return
    end

    self._log:info("Layer ambience:", layerId)

    local music = profile.music
    if music then
        SoundManager.playLoop(music.eventId, music.volume)
    else
        SoundManager.stopLoop(0.5)
    end

    if playEnter == true and profile.enter then
        SoundManager.play(profile.enter)
    end

    self:_applyParticles(character, profile.particles, profile.fog)
end

function LayerAmbience:reset()
    self._currentLayerId = ""
    SoundManager.stopLoop(0.3)
    self:_clearParticles()
end

function LayerAmbience:destroy()
    SoundManager.stopLoop(0.3)
    self:_clearParticles()
    self._currentLayerId = ""
end

return LayerAmbience
