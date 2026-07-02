--!strict
-- SoundDatabase.lua — единственный источник правды по звуковым событиям.
--
-- Layer break (break_layer_*) — звук крошения наполнителя/common по слою.
-- Layer music (music_*) — фоновая мелодия слоя (loop, категория "music").
-- Rarity break/hit — для редких руд epic+ (и hit по rarity-тиру).

export type PitchRange = { min: number, max: number }

export type SoundEntry = {
    soundId: string,
    volume: number,
    pitchRange: PitchRange?,
    loop: boolean?,
    playbackSpeed: number?,
}

local OreDatabase = require(script.Parent.OreDatabase)
local _oreDb = OreDatabase.new()

local SoundDatabase = {}

SoundDatabase.CATEGORY = {
    hit_dirt = "sfx",
    hit_stone = "sfx",
    hit_metal = "sfx",
    hit_gem = "sfx",
    break_common = "sfx",
    break_uncommon = "sfx",
    break_rare = "sfx",
    break_epic = "sfx",
    break_legendary = "sfx",
    break_mythic = "sfx",
    break_layer_dirt = "sfx",
    break_layer_stone = "sfx",
    break_layer_limestone = "sfx",
    break_layer_crimson = "sfx",
    break_layer_marble = "sfx",
    break_layer_obsidian = "sfx",
    break_layer_void = "sfx",
    crit = "sfx",
    coin_pickup = "sfx",
    sell_success = "ui",
    sell_fail = "ui",
    buy_upgrade = "ui",
    buy_fail = "ui",
    ui_click = "ui",
    music_dirt = "music",
    music_stone = "music",
    music_limestone = "music",
    music_crimson = "music",
    music_marble = "music",
    music_obsidian = "music",
    music_void = "music",
    layer_enter_dirt = "sfx",
    layer_enter_stone = "sfx",
    layer_enter_limestone = "sfx",
    layer_enter_crimson = "sfx",
    layer_enter_marble = "sfx",
    layer_enter_obsidian = "sfx",
    layer_enter_void = "sfx",
}

-- common/uncommon → звук слоя; rare+ → rarity break.
SoundDatabase.LAYER_BREAK = {
    dirt = "break_layer_dirt",
    stone = "break_layer_stone",
    limestone = "break_layer_limestone",
    crimson = "break_layer_crimson",
    marble = "break_layer_marble",
    obsidian = "break_layer_obsidian",
    void = "break_layer_void",
}

SoundDatabase.RARITY_BREAK = {
    common = "break_common",
    uncommon = "break_uncommon",
    rare = "break_rare",
    epic = "break_epic",
    legendary = "break_legendary",
    mythic = "break_mythic",
}

SoundDatabase.RARITY_HIT = {
    common = "hit_dirt",
    uncommon = "hit_dirt",
    rare = "hit_stone",
    epic = "hit_metal",
    legendary = "hit_gem",
    mythic = "hit_gem",
}

SoundDatabase.EVENTS = {
    -- ===== Hits (по rarity-тиру) =====
    hit_dirt = {
        soundId = "rbxasset://sounds/clickfast.mp3",
        volume = 0.55,
        pitchRange = { min = 0.75, max = 0.95 },
    },
    hit_stone = {
        soundId = "rbxasset://sounds/button.mp3",
        volume = 0.6,
        pitchRange = { min = 0.7, max = 0.9 },
    },
    hit_metal = {
        soundId = "rbxasset://sounds/collide.mp3",
        volume = 0.55,
        pitchRange = { min = 0.92, max = 1.08 },
    },
    hit_gem = {
        soundId = "rbxasset://sounds/electronicpingshort.mp3",
        volume = 0.55,
        pitchRange = { min = 1.15, max = 1.35 },
    },

    -- ===== Layer breaks (наполнитель / common / uncommon) =====
    break_layer_dirt = {
        soundId = "rbxasset://sounds/clickfast.mp3",
        volume = 0.52,
        pitchRange = { min = 0.68, max = 0.88 },
    },
    break_layer_stone = {
        soundId = "rbxasset://sounds/collide.mp3",
        volume = 0.58,
        pitchRange = { min = 0.72, max = 0.92 },
    },
    break_layer_limestone = {
        soundId = "rbxasset://sounds/button.mp3",
        volume = 0.54,
        pitchRange = { min = 0.62, max = 0.82 },
    },
    break_layer_crimson = {
        soundId = "rbxasset://sounds/bass.mp3",
        volume = 0.56,
        pitchRange = { min = 0.42, max = 0.58 },
    },
    break_layer_marble = {
        soundId = "rbxasset://sounds/impact_water.mp3",
        volume = 0.50,
        pitchRange = { min = 0.85, max = 1.05 },
    },
    break_layer_obsidian = {
        soundId = "rbxasset://sounds/impact_explosion_01.mp3",
        volume = 0.54,
        pitchRange = { min = 0.68, max = 0.88 },
    },
    break_layer_void = {
        soundId = "rbxasset://sounds/impact_explosion_03.mp3",
        volume = 0.58,
        pitchRange = { min = 0.38, max = 0.52 },
    },

    -- ===== Breaks (rare+ по rarity) =====
    break_common = {
        soundId = "rbxasset://sounds/collide.mp3",
        volume = 0.55,
        pitchRange = { min = 0.85, max = 1.0 },
    },
    break_uncommon = {
        soundId = "rbxasset://sounds/collide.mp3",
        volume = 0.6,
        pitchRange = { min = 0.95, max = 1.12 },
    },
    break_rare = {
        soundId = "rbxasset://sounds/impact_explosion_01.mp3",
        volume = 0.6,
        pitchRange = { min = 1.05, max = 1.2 },
    },
    break_epic = {
        soundId = "rbxasset://sounds/impact_explosion_02.mp3",
        volume = 0.65,
        pitchRange = { min = 0.95, max = 1.1 },
    },
    break_legendary = {
        soundId = "rbxasset://sounds/impact_explosion_03.mp3",
        volume = 0.7,
        pitchRange = { min = 0.85, max = 1.0 },
    },
    break_mythic = {
        soundId = "rbxassetid://9112854440",
        volume = 1.0,
        pitchRange = { min = 0.82, max = 0.92 },
    },

    crit = {
        soundId = "rbxasset://sounds/electronicpingshort.mp3",
        volume = 0.8,
        pitchRange = { min = 1.25, max = 1.4 },
    },
    coin_pickup = {
        soundId = "rbxasset://sounds/electronicpingshort.mp3",
        volume = 0.5,
        pitchRange = { min = 1.4, max = 1.6 },
    },

    sell_success = {
        soundId = "rbxasset://sounds/electronicpingshort.mp3",
        volume = 0.7,
        pitchRange = { min = 1.0, max = 1.1 },
    },
    sell_fail = {
        soundId = "rbxassetid://550209561",
        volume = 0.5,
        pitchRange = { min = 0.95, max = 1.0 },
    },
    buy_upgrade = {
        soundId = "rbxasset://sounds/button.mp3",
        volume = 0.7,
        pitchRange = { min = 1.1, max = 1.25 },
    },
    buy_fail = {
        soundId = "rbxassetid://550209561",
        volume = 0.5,
        pitchRange = { min = 0.95, max = 1.0 },
    },
    ui_click = {
        soundId = "rbxasset://sounds/clickfast.mp3",
        volume = 0.4,
        pitchRange = { min = 1.0, max = 1.15 },
    },

    -- ===== Layer music (loop, Creator Store Audio — заменить на кастом при полишинге) =====
    music_dirt = {
        soundId = "rbxassetid://1848354536",
        volume = 0.12,
        loop = true,
        playbackSpeed = 1.0,
    },
    music_stone = {
        soundId = "rbxassetid://9043887091",
        volume = 0.10,
        loop = true,
        playbackSpeed = 0.95,
    },
    music_limestone = {
        soundId = "rbxassetid://9112854440",
        volume = 0.09,
        loop = true,
        playbackSpeed = 0.92,
    },
    music_crimson = {
        soundId = "rbxassetid://1837879082",
        volume = 0.13,
        loop = true,
        playbackSpeed = 0.85,
    },
    music_marble = {
        soundId = "rbxassetid://1848354536",
        volume = 0.08,
        loop = true,
        playbackSpeed = 1.18,
    },
    music_obsidian = {
        soundId = "rbxassetid://1837879082",
        volume = 0.11,
        loop = true,
        playbackSpeed = 0.68,
    },
    music_void = {
        soundId = "rbxassetid://9043887091",
        volume = 0.09,
        loop = true,
        playbackSpeed = 0.55,
    },

    layer_enter_dirt = {
        soundId = "rbxasset://sounds/impact_water.mp3",
        volume = 0.30,
        pitchRange = { min = 0.9, max = 1.05 },
    },
    layer_enter_stone = {
        soundId = "rbxasset://sounds/impact_water.mp3",
        volume = 0.28,
        pitchRange = { min = 0.8, max = 0.95 },
    },
    layer_enter_limestone = {
        soundId = "rbxasset://sounds/impact_water.mp3",
        volume = 0.20,
        pitchRange = { min = 0.85, max = 1.0 },
    },
    layer_enter_crimson = {
        soundId = "rbxasset://sounds/bass.mp3",
        volume = 0.32,
        pitchRange = { min = 0.5, max = 0.65 },
    },
    layer_enter_marble = {
        soundId = "rbxasset://sounds/electronicpingshort.mp3",
        volume = 0.25,
        pitchRange = { min = 0.9, max = 1.1 },
    },
    layer_enter_obsidian = {
        soundId = "rbxasset://sounds/electronicpingshort.mp3",
        volume = 0.30,
        pitchRange = { min = 0.55, max = 0.7 },
    },
    layer_enter_void = {
        soundId = "rbxasset://sounds/impact_explosion_03.mp3",
        volume = 0.22,
        pitchRange = { min = 0.45, max = 0.6 },
    },
}

function SoundDatabase.get(eventId: string): SoundEntry?
    return SoundDatabase.EVENTS[eventId]
end

function SoundDatabase.getCategory(eventId: string): string
    return SoundDatabase.CATEGORY[eventId] or "sfx"
end

function SoundDatabase.hitEventForRarity(rarity: string): string
    return SoundDatabase.RARITY_HIT[rarity] or "hit_dirt"
end

function SoundDatabase.breakEventForRarity(rarity: string): string
    return SoundDatabase.RARITY_BREAK[rarity] or "break_common"
end

function SoundDatabase.breakEventForLayer(layerId: string): string
    return SoundDatabase.LAYER_BREAK[layerId] or "break_layer_dirt"
end

function SoundDatabase.breakEventForOre(oreId: string, rarity: string): string
    if rarity ~= "common" and rarity ~= "uncommon" then
        return SoundDatabase.breakEventForRarity(rarity)
    end
    local def = _oreDb:getOre(oreId)
    local layerId = def and def.layer or "dirt"
    return SoundDatabase.breakEventForLayer(layerId)
end

return SoundDatabase
