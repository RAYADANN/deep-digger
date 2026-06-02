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
-- ВАЖНО: все ID — из Roblox audio library (free), официальные звуки Roblox.
-- При первом плейтесте часть может звучать неудачно — заменяй прямо здесь,
-- больше нигде эти числа не встречаются. TODO-метки помечают звуки, которые
-- стоит подобрать аккуратнее под жанр mining.

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
        soundId = "rbxassetid://5810753638", -- TODO playtest: мягкий thud по земле
        volume = 0.55,
        pitchRange = { min = 0.9, max = 1.1 },
    },
    hit_stone = {
        soundId = "rbxassetid://9114958063", -- TODO playtest: удар по камню
        volume = 0.6,
        pitchRange = { min = 0.9, max = 1.1 },
    },
    hit_metal = {
        soundId = "rbxassetid://6987830013", -- TODO playtest: металлический clang
        volume = 0.55,
        pitchRange = { min = 0.92, max = 1.08 },
    },
    hit_gem = {
        soundId = "rbxassetid://7340791418", -- TODO playtest: звон по кристаллу
        volume = 0.55,
        pitchRange = { min = 0.95, max = 1.1 },
    },

    -- ===== Breaks (по rarity) =====
    break_common = {
        soundId = "rbxassetid://3168521635", -- TODO playtest: лёгкое крошение
        volume = 0.55,
        pitchRange = { min = 0.92, max = 1.08 },
    },
    break_uncommon = {
        soundId = "rbxassetid://3168521635", -- shares common; pitch чуть выше
        volume = 0.6,
        pitchRange = { min = 1.0, max = 1.12 },
    },
    break_rare = {
        soundId = "rbxassetid://7340791418", -- TODO playtest: разлёт осколков
        volume = 0.65,
        pitchRange = { min = 0.95, max = 1.05 },
    },
    break_epic = {
        soundId = "rbxassetid://2920779349", -- TODO playtest: большой break с sparkle
        volume = 0.75,
        pitchRange = { min = 0.92, max = 1.0 },
    },
    break_legendary = {
        soundId = "rbxassetid://5174488001", -- TODO playtest: эпичный boom
        volume = 0.85,
        pitchRange = { min = 0.88, max = 0.98 },
    },
    break_mythic = {
        soundId = "rbxassetid://9112854440", -- TODO playtest: мистический взрыв
        volume = 1.0,
        pitchRange = { min = 0.82, max = 0.92 },
    },

    -- ===== Spec events =====
    crit = {
        soundId = "rbxassetid://9112999517", -- TODO playtest: золотой chime
        volume = 0.8,
        pitchRange = { min = 0.98, max = 1.05 },
    },
    coin_pickup = {
        soundId = "rbxassetid://4612379032", -- TODO playtest: монетка
        volume = 0.6,
        pitchRange = { min = 0.95, max = 1.1 },
    },

    -- ===== UI =====
    sell_success = {
        soundId = "rbxassetid://5097964656", -- TODO playtest: cash register
        volume = 0.7,
        pitchRange = { min = 1.0, max = 1.05 },
    },
    sell_fail = {
        soundId = "rbxassetid://550209561", -- TODO playtest: мягкая ошибка
        volume = 0.5,
        pitchRange = { min = 0.95, max = 1.0 },
    },
    buy_upgrade = {
        soundId = "rbxassetid://9114157950", -- TODO playtest: апгрейд up
        volume = 0.7,
        pitchRange = { min = 1.0, max = 1.08 },
    },
    buy_fail = {
        soundId = "rbxassetid://550209561",
        volume = 0.5,
        pitchRange = { min = 0.95, max = 1.0 },
    },
    ui_click = {
        soundId = "rbxassetid://9119714799", -- TODO playtest: лёгкий click
        volume = 0.4,
        pitchRange = { min = 0.95, max = 1.05 },
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
