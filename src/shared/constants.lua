--!strict
-- constants.lua — общие константы

local Constants = {}

export type LayerId = "dirt" | "stone" | "limestone" | "crimson" | "marble" | "obsidian" | "void"

Constants.LAYERS = {
    { id = "dirt" :: LayerId, name = "Dirt Layer", depthStart = 0, depthEnd = 49, bgColor = Color3.fromRGB(92, 58, 30), blockColor = Color3.fromRGB(139, 105, 20) },
    { id = "stone" :: LayerId, name = "Stone Layer", depthStart = 50, depthEnd = 149, bgColor = Color3.fromRGB(74, 74, 74), blockColor = Color3.fromRGB(128, 128, 128) },
    { id = "limestone" :: LayerId, name = "Limestone Layer", depthStart = 150, depthEnd = 299, bgColor = Color3.fromRGB(212, 197, 169), blockColor = Color3.fromRGB(232, 213, 176) },
    { id = "crimson" :: LayerId, name = "Crimson Layer", depthStart = 300, depthEnd = 499, bgColor = Color3.fromRGB(74, 0, 0), blockColor = Color3.fromRGB(139, 0, 0) },
    { id = "marble" :: LayerId, name = "Marble Layer", depthStart = 500, depthEnd = 799, bgColor = Color3.fromRGB(232, 232, 232), blockColor = Color3.fromRGB(242, 242, 242) },
    { id = "obsidian" :: LayerId, name = "Obsidian Layer", depthStart = 800, depthEnd = 1199, bgColor = Color3.fromRGB(13, 0, 26), blockColor = Color3.fromRGB(26, 26, 46) },
    { id = "void" :: LayerId, name = "Void Layer", depthStart = 1200, depthEnd = math.huge, bgColor = Color3.fromRGB(0, 0, 0), blockColor = Color3.fromRGB(13, 0, 26) },
}

Constants.BLOCK_SIZE_STUDS = 4.5
Constants.SURFACE_W = 15
Constants.SURFACE_D = 15
Constants.SURFACE_H = 10
Constants.SHAFT_W = 5
Constants.SHAFT_D = 5
Constants.SHAFT_H = 5

Constants.RARITY_CHANCES = { common = 0.50, uncommon = 0.30, rare = 0.15, epic = 0.04, legendary = 0.009, mythic = 0.001 }
Constants.SHAFT_BASE_CHANCE = 0.06
Constants.SHAFT_DEPTH_BONUS = 0.0001
Constants.SHAFT_RARE_BOOST = 0.25
Constants.SHAFT_PERMANENT_BONUS = 0.005

Constants.UPGRADES = {
    pickaxe = { baseCost = 50, exponent = 1.5, maxLevel = 100, powerPerLevel = 2 },
    speed = { baseCost = 100, exponent = 1.3, maxLevel = 50, reductionMs = 20 },
    fortune = { baseCost = 500, exponent = 1.6, maxLevel = 30, chancePerLevel = 0.02 },
    inventory = { baseCost = 150, exponent = 1.4, maxLevel = 20, slotsPerLevel = 5 },
    crit = { baseCost = 400, exponent = 1.6, maxLevel = 15, chancePerLevel = 0.01 },
    multiSell = { baseCost = 800, exponent = 1.8, maxLevel = 10, bonusPerLevel = 0.05 },
    autoSell = { baseCost = 5000, maxLevel = 1 },
}

Constants.BASE_INVENTORY_SLOTS = 10
Constants.BASE_SWING_DELAY_MS = 1000
Constants.MAX_CLICKS_PER_SECOND = 15
Constants.AUTOSAVE_INTERVAL = 60

return Constants
