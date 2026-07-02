--!strict
-- OreDatabase.lua — единственный источник правды по рудам.
-- Лежит в shared/, чтобы и сервер (валидация, спавн) и клиент (рендер, HUD)
-- читали одни и те же данные через ReplicatedStorage без сетевых запросов.
--
-- Поля:
--   id, name, layer, rarity, hp, value, xp, color, icon  — обязательные.
--   weight                                              — относительный вес спавна
--     внутри слоя (Minecraft-style: наполнитель доминирует).
--   dropsOil, isGeode                                   — старые опц. флаги.
--   protrusion = "crystal"                              — low-poly кластер
--     кристаллов поверх блока (самоцветы/мистические руды); строит рендер.
--   material/reflectance/glow                           — больше не задаём
--     (low-poly пас сделал блоки плоскими; meshId — задел под Blender-меши).
--
-- Добавление новой руды = одна правка ЭТОГО файла. Клиент сам подтянет
-- цвет, редкость, иконку через client/core/OreLookup.

local OreDatabase = {}
OreDatabase.__index = OreDatabase

function OreDatabase.new()
    local self = setmetatable({}, OreDatabase)
    self._data = self:_buildDatabase()
    return self
end

function OreDatabase:_buildDatabase()
    -- Low-poly пас: блоки рендерятся плоским материалом (SmoothPlastic) + лёгкий
    -- цветовой джиттер на блок, чтобы стена не выглядела монолитом — это в
    -- MiningRenderer. Шумные материалы (Ground/Slate/Metal/Foil) убраны: они
    -- конфликтовали с low-poly картой. Поэтому здесь material/reflectance/glow
    -- больше НЕ задаются — рендер сам делает всё плоским.
    --
    -- protrusion = "crystal" → у кристаллических руд (самоцветы/мистические)
    -- рендер строит low-poly кластер шардов цвета руды поверх куба. Это «герой»-
    -- момент редкой находки. Не-кристаллические редкие руды (fossil, oil) —
    -- остаются плоскими. Позже шарды заменяются Blender-мешами через meshId.
    --
    -- Первый слой «dirt» (ID не меняем — завязан в прогрессии) теперь визуально
    -- ТРАВА: наполнитель зелёный, под ним земля/камешки/корни.
    --
    -- weight: относительный вес спавна внутри слоя. Наполнитель ~900,
    -- uncommon изредка, rare+ очень редко (как в Minecraft).
    return {
        dirt = {
            -- P0.2 (early-loop juice): dirt-слой — первые 30-60 секунд игры.
            -- Значения подняты ~×3, чтобы первый «ПРОДАТЬ» давал ощутимое число,
            -- а не 15 монет. Grass hp = 2 (было 1): первый апгрейд кирки
            -- (power 1 → 3) сразу делает наполнитель one-shot — видимый прирост
            -- скорости/дохода. Stone+ слои НЕ тронуты (кривая глубины цела).
            { id = "dirt", name = "Grass", layer = "dirt", rarity = "common", weight = 900, hp = 2, value = 3, xp = 1, color = Color3.fromRGB(96, 158, 64), icon = "🟩" },
            { id = "pebble", name = "Pebble", layer = "dirt", rarity = "uncommon", weight = 90, hp = 2, value = 6, xp = 1, color = Color3.fromRGB(138, 146, 150), icon = "⬜" },
            { id = "clay", name = "Clay", layer = "dirt", rarity = "uncommon", weight = 70, hp = 3, value = 9, xp = 2, color = Color3.fromRGB(170, 134, 98), icon = "🟫" },
            { id = "coal", name = "Coal", layer = "dirt", rarity = "uncommon", weight = 30, hp = 5, value = 15, xp = 2, color = Color3.fromRGB(46, 48, 58), icon = "⬛" },
            { id = "root", name = "Root", layer = "dirt", rarity = "uncommon", weight = 60, hp = 4, value = 12, xp = 1, color = Color3.fromRGB(112, 76, 44), icon = "🌿" },
            { id = "fossil", name = "Fossil", layer = "dirt", rarity = "rare", weight = 6, hp = 10, value = 45, xp = 5, color = Color3.fromRGB(232, 222, 182), icon = "🦴" },
            { id = "amber", name = "Amber", layer = "dirt", rarity = "epic", weight = 3, hp = 14, value = 100, xp = 8, color = Color3.fromRGB(230, 158, 40), icon = "🟠", protrusion = "crystal" },
            { id = "ancient_relic", name = "Ancient Relic", layer = "dirt", rarity = "legendary", weight = 1, hp = 22, value = 260, xp = 15, color = Color3.fromRGB(184, 142, 92), icon = "🏺" },
            { id = "dino_egg", name = "Dino Egg", layer = "dirt", rarity = "mythic", weight = 1, hp = 40, value = 750, xp = 30, color = Color3.fromRGB(236, 224, 196), icon = "🥚" },
            -- Тест Фазы 6: weight=0 — не спавнится в продакшене.
            { id = "test_glow", name = "Test Glow", layer = "dirt", rarity = "mythic", weight = 0, hp = 1, value = 1000, xp = 1, color = Color3.fromRGB(255, 0, 255), icon = "🟪" },
        },
        stone = {
            { id = "stone", name = "Stone", layer = "stone", rarity = "common", weight = 900, hp = 8, value = 6, xp = 3, color = Color3.fromRGB(128, 128, 132), icon = "🪨" },
            { id = "copper", name = "Copper", layer = "stone", rarity = "uncommon", weight = 110, hp = 10, value = 8, xp = 3, color = Color3.fromRGB(188, 116, 56), icon = "🟧" },
            { id = "iron", name = "Iron", layer = "stone", rarity = "uncommon", weight = 70, hp = 15, value = 15, xp = 5, color = Color3.fromRGB(156, 150, 144), icon = "⚙" },
            { id = "silver", name = "Silver", layer = "stone", rarity = "uncommon", weight = 22, hp = 20, value = 25, xp = 7, color = Color3.fromRGB(206, 212, 224), icon = "⬡" },
            { id = "gold", name = "Gold", layer = "stone", rarity = "uncommon", weight = 14, hp = 30, value = 40, xp = 10, color = Color3.fromRGB(255, 208, 64), icon = "★" },
            { id = "sapphire", name = "Sapphire", layer = "stone", rarity = "rare", weight = 5, hp = 50, value = 80, xp = 15, color = Color3.fromRGB(64, 128, 255), icon = "◆", protrusion = "crystal" },
            { id = "ruby", name = "Ruby", layer = "stone", rarity = "rare", weight = 3, hp = 75, value = 120, xp = 20, color = Color3.fromRGB(235, 44, 76), icon = "♦", protrusion = "crystal" },
            { id = "aquamarine", name = "Aquamarine", layer = "stone", rarity = "epic", weight = 3, hp = 90, value = 220, xp = 30, color = Color3.fromRGB(120, 220, 235), icon = "💠", protrusion = "crystal" },
            { id = "black_opal", name = "Black Opal", layer = "stone", rarity = "legendary", weight = 1, hp = 130, value = 500, xp = 55, color = Color3.fromRGB(64, 58, 86), icon = "🔮", protrusion = "crystal" },
            { id = "star_sapphire", name = "Star Sapphire", layer = "stone", rarity = "mythic", weight = 1, hp = 200, value = 1000, xp = 90, color = Color3.fromRGB(70, 112, 235), icon = "✦", protrusion = "crystal" },
        },
        limestone = {
            { id = "limestone", name = "Limestone", layer = "limestone", rarity = "common", weight = 900, hp = 20, value = 18, xp = 6, color = Color3.fromRGB(224, 212, 182), icon = "□" },
            { id = "marble_chip", name = "Marble Chip", layer = "limestone", rarity = "uncommon", weight = 120, hp = 35, value = 30, xp = 8, color = Color3.fromRGB(232, 234, 230), icon = "◇" },
            { id = "malachite", name = "Malachite", layer = "limestone", rarity = "uncommon", weight = 26, hp = 60, value = 55, xp = 12, color = Color3.fromRGB(24, 196, 104), icon = "◈" },
            { id = "topaz", name = "Topaz", layer = "limestone", rarity = "rare", weight = 6, hp = 80, value = 100, xp = 18, color = Color3.fromRGB(255, 206, 96), icon = "◉", protrusion = "crystal" },
            { id = "emerald", name = "Emerald", layer = "limestone", rarity = "epic", weight = 2, hp = 100, value = 150, xp = 25, color = Color3.fromRGB(40, 224, 120), icon = "◆", protrusion = "crystal" },
            { id = "jade_idol", name = "Jade Idol", layer = "limestone", rarity = "legendary", weight = 1, hp = 180, value = 700, xp = 60, color = Color3.fromRGB(40, 190, 140), icon = "🗿" },
            { id = "prismarine_core", name = "Prismarine Core", layer = "limestone", rarity = "mythic", weight = 1, hp = 280, value = 1600, xp = 110, color = Color3.fromRGB(90, 210, 200), icon = "🔷", protrusion = "crystal" },
        },
        crimson = {
            { id = "crimson_rock", name = "Crimson Rock", layer = "crimson", rarity = "common", weight = 900, hp = 50, value = 40, xp = 12, color = Color3.fromRGB(142, 52, 52), icon = "▪" },
            { id = "redstone", name = "Redstone", layer = "crimson", rarity = "uncommon", weight = 130, hp = 80, value = 65, xp = 18, color = Color3.fromRGB(212, 62, 52), icon = "●" },
            { id = "blood_opal", name = "Blood Opal", layer = "crimson", rarity = "uncommon", weight = 24, hp = 150, value = 180, xp = 30, color = Color3.fromRGB(226, 56, 104), icon = "◎" },
            { id = "oil_deposit", name = "Oil Deposit", layer = "crimson", rarity = "uncommon", weight = 20, hp = 120, value = 0, xp = 20, color = Color3.fromRGB(40, 50, 56), icon = "▼", dropsOil = true },
            { id = "cinnabar", name = "Cinnabar", layer = "crimson", rarity = "rare", weight = 5, hp = 170, value = 250, xp = 35, color = Color3.fromRGB(220, 60, 50), icon = "🔺", protrusion = "crystal" },
            { id = "diamond", name = "Diamond", layer = "crimson", rarity = "epic", weight = 3, hp = 200, value = 400, xp = 50, color = Color3.fromRGB(158, 238, 255), icon = "◆", protrusion = "crystal" },
            { id = "fire_opal", name = "Fire Opal", layer = "crimson", rarity = "legendary", weight = 1, hp = 250, value = 600, xp = 75, color = Color3.fromRGB(255, 120, 30), icon = "◈", protrusion = "crystal" },
            { id = "phoenix_heart", name = "Phoenix Heart", layer = "crimson", rarity = "mythic", weight = 1, hp = 400, value = 3000, xp = 160, color = Color3.fromRGB(255, 90, 30), icon = "🔥", protrusion = "crystal" },
        },
        marble = {
            { id = "marble", name = "Marble", layer = "marble", rarity = "common", weight = 900, hp = 80, value = 70, xp = 20, color = Color3.fromRGB(236, 236, 238), icon = "□" },
            { id = "white_quartz", name = "White Quartz", layer = "marble", rarity = "uncommon", weight = 120, hp = 120, value = 110, xp = 28, color = Color3.fromRGB(234, 240, 250), icon = "◇" },
            { id = "calcite", name = "Calcite", layer = "marble", rarity = "uncommon", weight = 24, hp = 180, value = 200, xp = 40, color = Color3.fromRGB(242, 232, 214), icon = "○" },
            { id = "moonstone", name = "Moonstone", layer = "marble", rarity = "rare", weight = 5, hp = 280, value = 500, xp = 70, color = Color3.fromRGB(140, 224, 255), icon = "◉", protrusion = "crystal" },
            { id = "selenite", name = "Selenite", layer = "marble", rarity = "epic", weight = 2, hp = 340, value = 800, xp = 95, color = Color3.fromRGB(235, 240, 250), icon = "🌙", protrusion = "crystal" },
            { id = "astralite", name = "Astralite", layer = "marble", rarity = "legendary", weight = 1, hp = 400, value = 1200, xp = 120, color = Color3.fromRGB(200, 172, 255), icon = "✦", protrusion = "crystal" },
            { id = "seraph_tear", name = "Seraph Tear", layer = "marble", rarity = "mythic", weight = 1, hp = 600, value = 3500, xp = 200, color = Color3.fromRGB(250, 250, 235), icon = "💧", protrusion = "crystal" },
        },
        obsidian = {
            { id = "obsidian", name = "Obsidian", layer = "obsidian", rarity = "common", weight = 900, hp = 150, value = 150, xp = 35, color = Color3.fromRGB(38, 36, 54), icon = "■" },
            { id = "dark_quartz", name = "Dark Quartz", layer = "obsidian", rarity = "uncommon", weight = 120, hp = 250, value = 300, xp = 55, color = Color3.fromRGB(104, 76, 150), icon = "◆" },
            { id = "amethyst", name = "Amethyst", layer = "obsidian", rarity = "uncommon", weight = 24, hp = 400, value = 600, xp = 85, color = Color3.fromRGB(172, 118, 224), icon = "◈", protrusion = "crystal" },
            { id = "spirit_shard", name = "Spirit Shard", layer = "obsidian", rarity = "rare", weight = 5, hp = 600, value = 1200, xp = 150, color = Color3.fromRGB(228, 184, 255), icon = "✦", protrusion = "crystal" },
            { id = "shadow_gem", name = "Shadow Gem", layer = "obsidian", rarity = "epic", weight = 2, hp = 900, value = 2500, xp = 250, color = Color3.fromRGB(152, 52, 212), icon = "◆", protrusion = "crystal" },
            { id = "soul_crystal", name = "Soul Crystal", layer = "obsidian", rarity = "legendary", weight = 1, hp = 1200, value = 4000, xp = 350, color = Color3.fromRGB(190, 120, 255), icon = "👻", protrusion = "crystal" },
            { id = "eclipse_stone", name = "Eclipse Stone", layer = "obsidian", rarity = "mythic", weight = 1, hp = 1700, value = 7000, xp = 500, color = Color3.fromRGB(96, 44, 148), icon = "🌑", protrusion = "crystal" },
        },
        void = {
            { id = "void_stone", name = "Void Stone", layer = "void", rarity = "common", weight = 900, hp = 300, value = 500, xp = 60, color = Color3.fromRGB(36, 26, 56), icon = "▪" },
            { id = "nebula_crystal", name = "Nebula Crystal", layer = "void", rarity = "uncommon", weight = 90, hp = 500, value = 1000, xp = 100, color = Color3.fromRGB(134, 62, 198), icon = "✦", protrusion = "crystal" },
            { id = "star_fragment", name = "Star Fragment", layer = "void", rarity = "rare", weight = 14, hp = 800, value = 2500, xp = 200, color = Color3.fromRGB(255, 242, 168), icon = "★", protrusion = "crystal" },
            { id = "galaxy_opal", name = "Galaxy Opal", layer = "void", rarity = "epic", weight = 4, hp = 1500, value = 6000, xp = 400, color = Color3.fromRGB(74, 84, 228), icon = "◎", protrusion = "crystal" },
            { id = "singularity_shard", name = "Singularity Shard", layer = "void", rarity = "legendary", weight = 1, hp = 1800, value = 8000, xp = 450, color = Color3.fromRGB(50, 60, 160), icon = "🕳", protrusion = "crystal" },
            { id = "void_crystal", name = "Void Crystal", layer = "void", rarity = "mythic", weight = 1, hp = 2500, value = 10000, xp = 500, color = Color3.fromRGB(198, 96, 255), icon = "✦", protrusion = "crystal" },
        },
    }
end

function OreDatabase:getAll(): { [string]: { any } }
    return self._data
end

function OreDatabase:getByLayer(layerId: string): { any }
    return self._data[layerId] or {}
end

function OreDatabase:getOre(oreId: string): any?
    for _, pool in pairs(self._data) do
        for _, ore in ipairs(pool) do
            if ore.id == oreId then
                return ore
            end
        end
    end
    return nil
end

return OreDatabase
