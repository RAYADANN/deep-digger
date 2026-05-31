--!strict
-- Временный клиентский каталог руд (Фаза 6 → OreDatabase в shared).

local OreCatalog = {}

local RARITY: { [string]: string } = {
    dirt = "common", pebble = "common", clay = "common", root = "common", coal = "uncommon",
    stone = "common", copper = "common", iron = "uncommon", fossil = "rare", silver = "uncommon",
    gold = "uncommon", sapphire = "rare", ruby = "rare", limestone = "common", marble_chip = "common",
    malachite = "uncommon", topaz = "rare", emerald = "epic", crimson_rock = "common", redstone = "common",
    blood_opal = "uncommon", oil_deposit = "uncommon", diamond = "epic", fire_opal = "legendary",
    marble = "common", white_quartz = "common", calcite = "uncommon", moonstone = "rare", astralite = "legendary",
    obsidian = "common", dark_quartz = "common", amethyst = "uncommon", spirit_shard = "rare",
    shadow_gem = "epic", void_stone = "common", nebula_crystal = "uncommon", star_fragment = "rare",
    galaxy_opal = "epic", void_crystal = "mythic",
}

local ICON: { [string]: string } = {
    dirt = "🟫", pebble = "⬜", clay = "🟤", coal = "⬛", root = "🌿", fossil = "🦴", stone = "🪨",
    copper = "🟧", iron = "⚙", silver = "⬡", gold = "★", sapphire = "◆", ruby = "♦", limestone = "□",
    marble_chip = "◇", malachite = "◈", topaz = "◉", emerald = "◆", crimson_rock = "▪", redstone = "●",
    blood_opal = "◎", oil_deposit = "▼", diamond = "◆", fire_opal = "◈", marble = "□", white_quartz = "◇",
    calcite = "○", moonstone = "◉", astralite = "✦", obsidian = "■", dark_quartz = "◆", amethyst = "◈",
    spirit_shard = "✦", shadow_gem = "◆", void_stone = "▪", nebula_crystal = "✦", star_fragment = "★",
    galaxy_opal = "◎", void_crystal = "✦",
}

function OreCatalog.getRarity(oreId: string): string
    return RARITY[oreId] or "common"
end

function OreCatalog.getIcon(oreId: string): string
    return ICON[oreId] or "?"
end

return OreCatalog
