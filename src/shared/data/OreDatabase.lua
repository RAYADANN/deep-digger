--!strict
-- OreDatabase.lua — единственный источник правды по рудам.
-- Лежит в shared/, чтобы и сервер (валидация, спавн) и клиент (рендер, HUD)
-- читали одни и те же данные через ReplicatedStorage без сетевых запросов.
--
-- Поля:
--   id, name, layer, rarity, hp, value, xp, color, icon  — обязательные.
--   dropsOil, isGeode                                   — старые опц. флаги.
--   material, reflectance, glow                         — визуал по слою
--   (Фаза 14: материалы; atlasIndex/meshId — задел под texture atlas).
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
    -- Phase 14 (визуальная идентичность): поля material / reflectance / glow
    -- заполнены по дизайн-гайду слоёв. MiningRenderer:_createPart читает их с
    -- приоритетом OreDef → fallback на ORE_VISUAL_BY_RARITY. Принцип «спуска
    -- вглубь»: грязь/камень — матовые (Ground/Slate), металлы — Foil/Metal с
    -- блеском, самоцветы — Glass + reflectance, мистические руды — шиммер Foil
    -- (glow). Neon с блоков убран (лишняя нагрузка/bloom).
    return {
        dirt = {
            { id = "dirt", name = "Dirt", layer = "dirt", rarity = "common", hp = 1, value = 1, xp = 1, color = Color3.fromRGB(139, 105, 20), icon = "🟫", material = Enum.Material.Ground },
            { id = "pebble", name = "Pebble", layer = "dirt", rarity = "common", hp = 2, value = 2, xp = 1, color = Color3.fromRGB(160, 160, 160), icon = "⬜", material = Enum.Material.Rock },
            { id = "clay", name = "Clay", layer = "dirt", rarity = "common", hp = 3, value = 3, xp = 2, color = Color3.fromRGB(196, 168, 130), icon = "🟤", material = Enum.Material.Mud },
            { id = "coal", name = "Coal", layer = "dirt", rarity = "uncommon", hp = 5, value = 5, xp = 2, color = Color3.fromRGB(28, 28, 28), icon = "⬛", material = Enum.Material.Slate },
            { id = "root", name = "Root", layer = "dirt", rarity = "common", hp = 4, value = 4, xp = 1, color = Color3.fromRGB(92, 58, 30), icon = "🌿", material = Enum.Material.Wood },
            { id = "fossil", name = "Fossil", layer = "dirt", rarity = "rare", hp = 10, value = 15, xp = 5, color = Color3.fromRGB(232, 213, 176), icon = "🦴", material = Enum.Material.Sandstone, reflectance = 0.05 },
            -- Тест Фазы 6: появится на поверхности (rarity=mythic, шанс 0.1%).
            -- Проверяет, что добавление новой руды НЕ требует правок клиента.
            -- Намеренно БЕЗ material/glow — проверяет fallback на ORE_VISUAL_BY_RARITY.
            { id = "test_glow", name = "Test Glow", layer = "dirt", rarity = "mythic", hp = 1, value = 1000, xp = 1, color = Color3.fromRGB(255, 0, 255), icon = "🟪" },
        },
        stone = {
            { id = "stone", name = "Stone", layer = "stone", rarity = "common", hp = 8, value = 6, xp = 3, color = Color3.fromRGB(128, 128, 128), icon = "🪨", material = Enum.Material.Slate },
            { id = "copper", name = "Copper", layer = "stone", rarity = "common", hp = 10, value = 8, xp = 3, color = Color3.fromRGB(184, 115, 51), icon = "🟧", material = Enum.Material.Metal },
            { id = "iron", name = "Iron", layer = "stone", rarity = "common", hp = 15, value = 15, xp = 5, color = Color3.fromRGB(193, 154, 107), icon = "⚙", material = Enum.Material.Metal },
            { id = "silver", name = "Silver", layer = "stone", rarity = "uncommon", hp = 20, value = 25, xp = 7, color = Color3.fromRGB(192, 192, 192), icon = "⬡", material = Enum.Material.Foil },
            { id = "gold", name = "Gold", layer = "stone", rarity = "uncommon", hp = 30, value = 40, xp = 10, color = Color3.fromRGB(255, 215, 0), icon = "★", material = Enum.Material.Foil },
            { id = "sapphire", name = "Sapphire", layer = "stone", rarity = "rare", hp = 50, value = 80, xp = 15, color = Color3.fromRGB(15, 82, 186), icon = "◆", material = Enum.Material.Glass, reflectance = 0.25 },
            { id = "ruby", name = "Ruby", layer = "stone", rarity = "rare", hp = 75, value = 120, xp = 20, color = Color3.fromRGB(224, 17, 95), icon = "♦", material = Enum.Material.Glass, reflectance = 0.25 },
        },
        limestone = {
            { id = "limestone", name = "Limestone", layer = "limestone", rarity = "common", hp = 20, value = 18, xp = 6, color = Color3.fromRGB(232, 213, 176), icon = "□", material = Enum.Material.Sandstone },
            { id = "marble_chip", name = "Marble Chip", layer = "limestone", rarity = "common", hp = 35, value = 30, xp = 8, color = Color3.fromRGB(245, 245, 220), icon = "◇", material = Enum.Material.Marble },
            { id = "malachite", name = "Malachite", layer = "limestone", rarity = "uncommon", hp = 60, value = 55, xp = 12, color = Color3.fromRGB(11, 218, 81), icon = "◈", material = Enum.Material.Marble },
            { id = "topaz", name = "Topaz", layer = "limestone", rarity = "rare", hp = 80, value = 100, xp = 18, color = Color3.fromRGB(255, 200, 124), icon = "◉", material = Enum.Material.Glass, reflectance = 0.2 },
            { id = "emerald", name = "Emerald", layer = "limestone", rarity = "epic", hp = 100, value = 150, xp = 25, color = Color3.fromRGB(80, 200, 120), icon = "◆", material = Enum.Material.Glass, reflectance = 0.3 },
        },
        crimson = {
            { id = "crimson_rock", name = "Crimson Rock", layer = "crimson", rarity = "common", hp = 50, value = 40, xp = 12, color = Color3.fromRGB(139, 0, 0), icon = "▪", material = Enum.Material.Basalt },
            { id = "redstone", name = "Redstone", layer = "crimson", rarity = "common", hp = 80, value = 65, xp = 18, color = Color3.fromRGB(204, 51, 51), icon = "●", material = Enum.Material.Slate },
            { id = "blood_opal", name = "Blood Opal", layer = "crimson", rarity = "uncommon", hp = 150, value = 180, xp = 30, color = Color3.fromRGB(227, 66, 52), icon = "◎", material = Enum.Material.Marble },
            { id = "oil_deposit", name = "Oil Deposit", layer = "crimson", rarity = "uncommon", hp = 120, value = 0, xp = 20, color = Color3.fromRGB(59, 59, 59), icon = "▼", dropsOil = true, material = Enum.Material.Slate },
            { id = "diamond", name = "Diamond", layer = "crimson", rarity = "epic", hp = 200, value = 400, xp = 50, color = Color3.fromRGB(185, 242, 255), icon = "◆", material = Enum.Material.Glass, reflectance = 0.4 },
            { id = "fire_opal", name = "Fire Opal", layer = "crimson", rarity = "legendary", hp = 250, value = 600, xp = 75, color = Color3.fromRGB(255, 94, 0), icon = "◈", material = Enum.Material.Glass, reflectance = 0.35 },
        },
        marble = {
            { id = "marble", name = "Marble", layer = "marble", rarity = "common", hp = 80, value = 70, xp = 20, color = Color3.fromRGB(242, 242, 242), icon = "□", material = Enum.Material.Marble },
            { id = "white_quartz", name = "White Quartz", layer = "marble", rarity = "common", hp = 120, value = 110, xp = 28, color = Color3.fromRGB(248, 248, 255), icon = "◇", material = Enum.Material.Marble },
            { id = "calcite", name = "Calcite", layer = "marble", rarity = "uncommon", hp = 180, value = 200, xp = 40, color = Color3.fromRGB(232, 232, 232), icon = "○", material = Enum.Material.Marble },
            { id = "moonstone", name = "Moonstone", layer = "marble", rarity = "rare", hp = 280, value = 500, xp = 70, color = Color3.fromRGB(58, 216, 255), icon = "◉", material = Enum.Material.Glass, reflectance = 0.3 },
            { id = "astralite", name = "Astralite", layer = "marble", rarity = "legendary", hp = 400, value = 1200, xp = 120, color = Color3.fromRGB(177, 156, 217), icon = "✦", glow = true },
        },
        obsidian = {
            { id = "obsidian", name = "Obsidian", layer = "obsidian", rarity = "common", hp = 150, value = 150, xp = 35, color = Color3.fromRGB(26, 26, 46), icon = "■", material = Enum.Material.Slate },
            { id = "dark_quartz", name = "Dark Quartz", layer = "obsidian", rarity = "common", hp = 250, value = 300, xp = 55, color = Color3.fromRGB(45, 27, 78), icon = "◆", material = Enum.Material.Slate },
            { id = "amethyst", name = "Amethyst", layer = "obsidian", rarity = "uncommon", hp = 400, value = 600, xp = 85, color = Color3.fromRGB(153, 102, 204), icon = "◈", material = Enum.Material.Marble },
            { id = "spirit_shard", name = "Spirit Shard", layer = "obsidian", rarity = "rare", hp = 600, value = 1200, xp = 150, color = Color3.fromRGB(224, 176, 255), icon = "✦", glow = true },
            { id = "shadow_gem", name = "Shadow Gem", layer = "obsidian", rarity = "epic", hp = 900, value = 2500, xp = 250, color = Color3.fromRGB(47, 0, 79), icon = "◆", material = Enum.Material.Glass, reflectance = 0.3 },
        },
        void = {
            { id = "void_stone", name = "Void Stone", layer = "void", rarity = "common", hp = 300, value = 500, xp = 60, color = Color3.fromRGB(13, 0, 26), icon = "▪", material = Enum.Material.Basalt },
            { id = "nebula_crystal", name = "Nebula Crystal", layer = "void", rarity = "uncommon", hp = 500, value = 1000, xp = 100, color = Color3.fromRGB(75, 0, 130), icon = "✦", glow = true },
            { id = "star_fragment", name = "Star Fragment", layer = "void", rarity = "rare", hp = 800, value = 2500, xp = 200, color = Color3.fromRGB(255, 255, 153), icon = "★", glow = true },
            { id = "galaxy_opal", name = "Galaxy Opal", layer = "void", rarity = "epic", hp = 1500, value = 6000, xp = 400, color = Color3.fromRGB(0, 0, 128), icon = "◎", material = Enum.Material.Glass, reflectance = 0.4 },
            { id = "void_crystal", name = "Void Crystal", layer = "void", rarity = "mythic", hp = 2500, value = 10000, xp = 500, color = Color3.fromRGB(0, 0, 0), icon = "✦", glow = true },
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
