--!strict
-- Палитра HUD (переносится в другие Roblox UI без изменений).

local C = {
    panelBg = Color3.fromRGB(18, 18, 28),
    panelBorder = Color3.fromRGB(60, 60, 90),
    panelInner = Color3.fromRGB(25, 25, 40),
    panelHeader = Color3.fromRGB(30, 30, 50),
    depthFill = Color3.fromRGB(60, 140, 220),
    depthBg = Color3.fromRGB(15, 30, 60),
    gold = Color3.fromRGB(255, 210, 50),
    goldBg = Color3.fromRGB(50, 40, 10),
    gem = Color3.fromRGB(80, 200, 255),
    gemBg = Color3.fromRGB(10, 35, 55),
    textMain = Color3.fromRGB(240, 235, 220),
    textMuted = Color3.fromRGB(130, 125, 145),
    textLabel = Color3.fromRGB(160, 155, 180),
    white = Color3.fromRGB(255, 255, 255),
    common = Color3.fromRGB(180, 180, 180),
    uncommon = Color3.fromRGB(80, 210, 80),
    rare = Color3.fromRGB(60, 140, 255),
    epic = Color3.fromRGB(180, 60, 220),
    legendary = Color3.fromRGB(255, 160, 0),
    mythic = Color3.fromRGB(255, 50, 50),
    btnBg = Color3.fromRGB(35, 35, 55),
    btnBorder = Color3.fromRGB(70, 70, 105),
    btnHover = Color3.fromRGB(50, 50, 75),
    btnDisabled = Color3.fromRGB(25, 25, 38),
    tabActive = Color3.fromRGB(55, 55, 85),
    tabInactive = Color3.fromRGB(28, 28, 45),
    tabBorder = Color3.fromRGB(80, 80, 120),
    sellBg = Color3.fromRGB(40, 100, 40),
    sellText = Color3.fromRGB(150, 255, 120),
    sellStroke = Color3.fromRGB(80, 180, 80),
    closeBg = Color3.fromRGB(120, 30, 30),
    closeStroke = Color3.fromRGB(200, 60, 60),
}

local RARITY_COLOR = {
    common = C.common,
    uncommon = C.uncommon,
    rare = C.rare,
    epic = C.epic,
    legendary = C.legendary,
    mythic = C.mythic,
}

local LAYER_COLORS = {
    dirt = Color3.fromRGB(180, 130, 70),
    stone = Color3.fromRGB(160, 160, 175),
    limestone = Color3.fromRGB(220, 200, 160),
    crimson = Color3.fromRGB(220, 60, 60),
    marble = Color3.fromRGB(210, 210, 230),
    obsidian = Color3.fromRGB(140, 80, 220),
    void = Color3.fromRGB(80, 40, 160),
}

local UPGRADE_COLORS = {
    pickaxe = Color3.fromRGB(220, 80, 80),
    speed = Color3.fromRGB(80, 200, 80),
    fortune = Color3.fromRGB(80, 160, 255),
    inventory = Color3.fromRGB(180, 80, 220),
    crit = Color3.fromRGB(255, 160, 0),
    multiSell = Color3.fromRGB(255, 210, 50),
    autoSell = Color3.fromRGB(80, 220, 200),
}

local RARITY_ORDER = { mythic = 1, legendary = 2, epic = 3, rare = 4, uncommon = 5, common = 6 }

return {
    C = C,
    RARITY_COLOR = RARITY_COLOR,
    LAYER_COLORS = LAYER_COLORS,
    UPGRADE_COLORS = UPGRADE_COLORS,
    RARITY_ORDER = RARITY_ORDER,
}
