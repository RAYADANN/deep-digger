--!strict
-- SoundDatabase.lua — единственный источник правды по звуковым событиям.
--
-- По аналогии с OreDatabase лежит в shared/data: сейчас читает только клиент
-- (server в Фазе 7 звуки не играет), но если в Фазе 9 (Rebirth) или 11 (Pets)
-- появится событийный звук, рассинхронизироваться будет негде — один файл.
--
-- Один Sound-инстанс per eventId, переиспользуется через :Play(). Для разнообразия
-- — random pitch ±0.1 при play (диапазон в `pitchRange`). Никаких ассет-фабрик
-- на каждый клик.
--
-- ВАЖНО: звуки берём из ВСТРОЕННЫХ движковых ассетов `rbxasset://sounds/*.mp3`.
-- Они поставляются с клиентом Roblox (см. content/sounds/), грузятся мгновенно
-- и НЕ проходят audio-модерацию — поэтому никогда не дают «Asset type does not
-- match requested type» (в отличие от library-ID, которые Roblox в 2024+ массово
-- порезал). Это рабочие placeholder'ы под mining-жанр; на полишинге (Фаза 13)
-- можно подменить на кастомные library-ассеты через Toolbox → Creator Store →
-- Audio. Менять только здесь — больше нигде эти строки не встречаются.

export type PitchRange = { min: number, max: number }

export type SoundEntry = {
    soundId: string,
    volume: number,
    pitchRange: PitchRange?,
}

local SoundDatabase = {}

-- Категория (sfx/ui) — для setVolume по группам.
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
    crit = "sfx",
    coin_pickup = "sfx",
    sell_success = "ui",
    sell_fail = "ui",
    buy_upgrade = "ui",
    buy_fail = "ui",
    ui_click = "ui",
}

-- Маппинг rarity → break-событие. Используется SoundManager.playForOre("break", oreId).
SoundDatabase.RARITY_BREAK = {
    common = "break_common",
    uncommon = "break_uncommon",
    rare = "break_rare",
    epic = "break_epic",
    legendary = "break_legendary",
    mythic = "break_mythic",
}

-- Маппинг rarity → hit-событие (4 тира, как в плане):
--   common/uncommon → dirt (мягкий)
--   rare            → stone
--   epic            → metal
--   legendary+      → gem (звон)
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
        soundId = "rbxasset://sounds/clickfast.mp3", -- лёгкий tap по земле
        volume = 0.55,
        pitchRange = { min = 0.75, max = 0.95 },
    },
    hit_stone = {
        soundId = "rbxasset://sounds/button.mp3", -- удар по камню
        volume = 0.6,
        pitchRange = { min = 0.7, max = 0.9 },
    },
    hit_metal = {
        soundId = "rbxasset://sounds/collide.mp3", -- металлический clack
        volume = 0.55,
        pitchRange = { min = 0.92, max = 1.08 },
    },
    hit_gem = {
        soundId = "rbxasset://sounds/electronicpingshort.mp3", -- звон по кристаллу
        volume = 0.55,
        pitchRange = { min = 1.15, max = 1.35 },
    },

    -- ===== Breaks (по rarity) =====
    break_common = {
        soundId = "rbxasset://sounds/collide.mp3", -- лёгкое крошение
        volume = 0.55,
        pitchRange = { min = 0.85, max = 1.0 },
    },
    break_uncommon = {
        soundId = "rbxasset://sounds/collide.mp3", -- shares common; pitch чуть выше
        volume = 0.6,
        pitchRange = { min = 0.95, max = 1.12 },
    },
    break_rare = {
        soundId = "rbxasset://sounds/impact_explosion_01.mp3", -- разлёт осколков
        volume = 0.6,
        pitchRange = { min = 1.05, max = 1.2 },
    },
    break_epic = {
        soundId = "rbxasset://sounds/impact_explosion_02.mp3", -- большой break
        volume = 0.65,
        pitchRange = { min = 0.95, max = 1.1 },
    },
    break_legendary = {
        soundId = "rbxasset://sounds/impact_explosion_03.mp3", -- эпичный boom
        volume = 0.7,
        pitchRange = { min = 0.85, max = 1.0 },
    },
    break_mythic = {
        soundId = "rbxassetid://9112854440", -- TODO playtest: мистический взрыв (рабочий library-ID)
        volume = 1.0,
        pitchRange = { min = 0.82, max = 0.92 },
    },

    -- ===== Spec events =====
    crit = {
        soundId = "rbxasset://sounds/electronicpingshort.mp3", -- золотой chime
        volume = 0.8,
        pitchRange = { min = 1.25, max = 1.4 },
    },
    coin_pickup = {
        soundId = "rbxasset://sounds/electronicpingshort.mp3", -- монетка
        volume = 0.5,
        pitchRange = { min = 1.4, max = 1.6 },
    },

    -- ===== UI =====
    sell_success = {
        soundId = "rbxasset://sounds/electronicpingshort.mp3", -- касса/успех
        volume = 0.7,
        pitchRange = { min = 1.0, max = 1.1 },
    },
    sell_fail = {
        soundId = "rbxassetid://550209561", -- TODO playtest: мягкая ошибка (рабочий library-ID)
        volume = 0.5,
        pitchRange = { min = 0.95, max = 1.0 },
    },
    buy_upgrade = {
        soundId = "rbxasset://sounds/button.mp3", -- апгрейд up
        volume = 0.7,
        pitchRange = { min = 1.1, max = 1.25 },
    },
    buy_fail = {
        soundId = "rbxassetid://550209561", -- рабочий library-ID, шарится с sell_fail
        volume = 0.5,
        pitchRange = { min = 0.95, max = 1.0 },
    },
    ui_click = {
        soundId = "rbxasset://sounds/clickfast.mp3", -- лёгкий click
        volume = 0.4,
        pitchRange = { min = 1.0, max = 1.15 },
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

return SoundDatabase
