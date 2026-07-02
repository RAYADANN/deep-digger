--!strict
-- LayerProfile.lua — идентичность слоёв (свечение руд, ambient, туман, пыль).
-- Отдельный модуль, чтобы Rojo гарантированно подхватывал новый файл.

export type BlockGlowLayer = {
    nonFillerOnly: boolean,
    range: number,
    rarityBrightness: { [string]: number },
    pulseRarities: { [string]: boolean }?,
}

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

export type LayerIdentity = {
    music: { eventId: string, volume: number }?,
    enter: string?,
    particles: ParticleCfg?,
    fog: FogCfg?,
    breakDust: { scaleMul: number, countMul: number, lightEmission: number, tint: Color3 }?,
    fillerReflectance: number?,
    atmosphereGlare: number?,
}

local LayerProfile = {}

LayerProfile.BLOCK_GLOW = {
    crimson = {
        nonFillerOnly = true,
        range = 5.5,
        rarityBrightness = {
            uncommon = 0.24, rare = 0.34, epic = 0.50, legendary = 0.65, mythic = 0.85,
        },
        pulseRarities = { legendary = true, mythic = true },
    },
    obsidian = {
        nonFillerOnly = true,
        range = 6,
        rarityBrightness = {
            uncommon = 0.28, rare = 0.40, epic = 0.58, legendary = 0.72, mythic = 0.90,
        },
        pulseRarities = { epic = true, legendary = true, mythic = true },
    },
    void = {
        nonFillerOnly = true,
        range = 7,
        rarityBrightness = {
            uncommon = 0.30, rare = 0.42, epic = 0.60, legendary = 0.78, mythic = 1.0,
        },
        pulseRarities = { legendary = true, mythic = true },
    },
}

LayerProfile.IDENTITY = {
    dirt = {
        music = { eventId = "music_dirt", volume = 0.12 },
        enter = "layer_enter_dirt",
        particles = { color = Color3.fromRGB(150, 210, 100), rate = 6, speedMin = 0.5, speedMax = 1.5, size = 0.55, lightEmission = 0.15 },
        fog = { color = Color3.fromRGB(140, 190, 110), rate = 18, size = 6, lightEmission = 0.08 },
        breakDust = { scaleMul = 0.9, countMul = 1.0, lightEmission = 0, tint = Color3.fromRGB(140, 180, 100) },
        fillerReflectance = 0,
        atmosphereGlare = 0,
    },
    stone = {
        music = { eventId = "music_stone", volume = 0.10 },
        enter = "layer_enter_stone",
        particles = { color = Color3.fromRGB(140, 145, 155), rate = 5, speedMin = 0.3, speedMax = 1.0, size = 0.5, lightEmission = 0.05 },
        fog = { color = Color3.fromRGB(100, 105, 115), rate = 10, size = 4, lightEmission = 0 },
        breakDust = { scaleMul = 1.0, countMul = 1.1, lightEmission = 0, tint = Color3.fromRGB(120, 120, 130) },
        fillerReflectance = 0,
        atmosphereGlare = 0,
    },
    limestone = {
        music = { eventId = "music_limestone", volume = 0.09 },
        enter = "layer_enter_limestone",
        particles = { color = Color3.fromRGB(230, 220, 200), rate = 5, speedMin = 0.2, speedMax = 0.8, size = 0.55, lightEmission = 0.1 },
        fog = { color = Color3.fromRGB(210, 200, 180), rate = 12, size = 4.5, lightEmission = 0.08 },
        breakDust = { scaleMul = 1.1, countMul = 1.2, lightEmission = 0.05, tint = Color3.fromRGB(210, 200, 180) },
        fillerReflectance = 0,
        atmosphereGlare = 0,
    },
    crimson = {
        music = { eventId = "music_crimson", volume = 0.13 },
        enter = "layer_enter_crimson",
        particles = { color = Color3.fromRGB(220, 50, 35), rate = 8, speedMin = 0.4, speedMax = 1.2, size = 0.6, lightEmission = 0.35 },
        fog = { color = Color3.fromRGB(120, 20, 15), rate = 24, size = 8, lightEmission = 0.25 },
        breakDust = { scaleMul = 1.0, countMul = 1.0, lightEmission = 0.15, tint = Color3.fromRGB(160, 50, 40) },
        fillerReflectance = 0,
        atmosphereGlare = 0.08,
    },
    marble = {
        music = { eventId = "music_marble", volume = 0.08 },
        enter = "layer_enter_marble",
        particles = { color = Color3.fromRGB(245, 245, 255), rate = 6, speedMin = 0.2, speedMax = 0.7, size = 0.65, lightEmission = 0.25 },
        fog = { color = Color3.fromRGB(230, 230, 240), rate = 6, size = 3, lightEmission = 0.15 },
        breakDust = { scaleMul = 1.05, countMul = 1.0, lightEmission = 0.08, tint = Color3.fromRGB(230, 230, 235) },
        fillerReflectance = 0.12,
        atmosphereGlare = 0.4,
    },
    obsidian = {
        music = { eventId = "music_obsidian", volume = 0.11 },
        enter = "layer_enter_obsidian",
        particles = { color = Color3.fromRGB(150, 70, 220), rate = 7, speedMin = 0.3, speedMax = 1.0, size = 0.55, lightEmission = 0.4 },
        fog = { color = Color3.fromRGB(40, 15, 70), rate = 26, size = 9, lightEmission = 0.2 },
        breakDust = { scaleMul = 1.0, countMul = 1.0, lightEmission = 0.2, tint = Color3.fromRGB(100, 50, 150) },
        fillerReflectance = 0,
        atmosphereGlare = 0,
    },
    void = {
        music = { eventId = "music_void", volume = 0.09 },
        enter = "layer_enter_void",
        particles = { color = Color3.fromRGB(210, 190, 255), rate = 10, speedMin = 0.5, speedMax = 1.8, size = 0.5, lightEmission = 0.55 },
        fog = { color = Color3.fromRGB(60, 30, 100), rate = 30, size = 10, lightEmission = 0.3 },
        breakDust = { scaleMul = 1.15, countMul = 1.1, lightEmission = 0.35, tint = Color3.fromRGB(180, 140, 255) },
        fillerReflectance = 0,
        atmosphereGlare = 0.12,
    },
}

return LayerProfile
