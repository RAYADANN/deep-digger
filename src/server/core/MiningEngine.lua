--!strict
-- MiningEngine.lua — бесконечная 3D шахта через Neighbor Reveal.
-- Блоки генерируются только когда нужны (при ломке соседнего).
-- Никаких чанков — никаких дыр.
--
-- hitBlock возвращает result.blockDelta = { created, updated, removed },
-- чтобы сервер не шёл всю карту блоков по сети каждый удар.

local shared = game:GetService("ReplicatedStorage"):WaitForChild("shared")
local Signal = require(shared.util.Signal)
local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local OreTypes = require(shared.types.OreTypes)
local UpgradeLogic = require(shared.util.UpgradeLogic)
-- Phase 11: эффекты петов (damageBoost / luckBoost / multiMine). Формулы —
-- единый источник в PetLogic, здесь только применение к урону/шансам.
local PetLogic = require(shared.util.PetLogic)

local MiningEngine = {}
MiningEngine.__index = MiningEngine

type OreDef = OreTypes.OreDef
type PlayerData = OreTypes.PlayerData

export type BlockSnap = { oreId: string, hp: number, maxHp: number }
export type BlockDelta = {
    created: { { key: string, oreId: string, hp: number, maxHp: number } },
    updated: { { key: string, hp: number } },
    removed: { string },
}

local NEIGHBORS = {
    {1,0,0}, {-1,0,0},
    {0,1,0}, {0,-1,0},
    {0,0,1}, {0,0,-1},
}

local SW = Constants.SURFACE_W
local SD = Constants.SURFACE_D
local SH = Constants.SURFACE_H

local function key(x, z, y) return string.format("%d_%d_%d", x, z, y) end

--[[
    Снимок блока по ключу. Если блока не было — записываем false-маркер.
    Вызывается ДО любой мутации, чтобы потом собрать дельту.
]]
local function trackKey(snapshot: { [string]: any }, blocks: { [string]: any }, k: string)
    if snapshot[k] ~= nil then return end
    local existing = blocks[k]
    if existing then
        snapshot[k] = { oreId = existing.oreId, hp = existing.hp, maxHp = existing.maxHp } :: BlockSnap
    else
        snapshot[k] = false
    end
end

local function emptyDelta(): BlockDelta
    return { created = {}, updated = {}, removed = {} }
end

local function buildDelta(snapshot: { [string]: any }, blocks: { [string]: any }): BlockDelta
    local delta = emptyDelta()
    for k, orig in pairs(snapshot) do
        local cur = blocks[k]
        if orig == false then
            if cur ~= nil then
                table.insert(delta.created, { key = k, oreId = cur.oreId, hp = cur.hp, maxHp = cur.maxHp })
            end
        else
            if cur == nil then
                table.insert(delta.removed, k)
            elseif cur.oreId ~= orig.oreId or cur.maxHp ~= orig.maxHp then
                -- сундук заменил обычный блок на той же клетке: client должен пересоздать part
                table.insert(delta.removed, k)
                table.insert(delta.created, { key = k, oreId = cur.oreId, hp = cur.hp, maxHp = cur.maxHp })
            elseif cur.hp ~= orig.hp then
                table.insert(delta.updated, { key = k, hp = cur.hp })
            end
        end
    end
    return delta
end

function MiningEngine.new(db)
    local self = setmetatable({}, MiningEngine)
    self._db = db; self._log = Logger.new("MiningEngine")
    self._blocks = {}; self._air = {}
    self.onOreMined = Signal.new()
    self._log:info("MiningEngine initialized (Neighbor Reveal)")
    return self
end

function MiningEngine:_layer(y)
    for _, l in ipairs(Constants.LAYERS) do if y >= l.depthStart and y <= l.depthEnd then return l.id end end
    return "void"
end

function MiningEngine:_oreWeight(ore: OreDef): number
    local w = ore.weight
    if w ~= nil then
        return w
    end
    local fallback = Constants.RARITY_DEFAULT_WEIGHT[ore.rarity]
    return fallback or 1
end

--[[
    Взвешенный ролл по пулу слоя. Наполнитель (weight ~900) доминирует,
    uncommon/rare/epic — изредка и очень редко (Minecraft-style).
]]
function MiningEngine:_roll(layerId)
    local pool = self._db[layerId] or self._db["dirt"]
    local total = 0
    for _, ore in ipairs(pool) do
        local w = self:_oreWeight(ore)
        if w > 0 then
            total += w
        end
    end
    if total <= 0 then
        return pool[1]
    end
    local r = math.random() * total
    local acc = 0
    for _, ore in ipairs(pool) do
        local w = self:_oreWeight(ore)
        if w > 0 then
            acc += w
            if r <= acc then
                return ore
            end
        end
    end
    return pool[1]
end

function MiningEngine:_createBlock(x, z, y)
    local ore = self:_roll(self:_layer(y))
    return { oreId = ore.id, hp = ore.hp, maxHp = ore.hp, depth = y }
end

function MiningEngine:_ensure(userId, x, z, y)
    if y < 0 then return end
    local k = key(x, z, y)
    local air, blocks = self._air[userId], self._blocks[userId]
    if air and air[k] then return end
    if blocks and blocks[k] then return end
    blocks[k] = self:_createBlock(x, z, y)
end

--[[
    Открывает 6 соседей вокруг (x,z,y). Если передан snapshot —
    фиксирует исходное состояние каждой клетки ДО создания нового блока.
]]
function MiningEngine:_revealNeighbors(userId, x, z, y, snapshot)
    local blocks, air = self._blocks[userId], self._air[userId]
    for _, d in ipairs(NEIGHBORS) do
        local nx, nz, ny = x + d[1], z + d[3], y + d[2]
        if ny >= 0 then
            local k = key(nx, nz, ny)
            if not (air and air[k]) and not (blocks and blocks[k]) then
                if snapshot then trackKey(snapshot, blocks, k) end
                blocks[k] = self:_createBlock(nx, nz, ny)
            end
        end
    end
end

function MiningEngine:_genSurface(userId)
    local hw, hd = math.floor(SW / 2), math.floor(SD / 2)
    for y = 0, SH - 1 do
        for z = -hd, hd do
            for x = -hw, hw do
                self:_ensure(userId, x, z, y)
            end
        end
    end
    self._log:info("Surface generated for", userId)
end

--[[
    Блок считается «открытым» если:
      - имеет хотя бы одного air-соседа, либо
      - находится в поверхностном кубе (y < SURFACE_H) — туда игрок может
        кликнуть напрямую, даже если внутренние блоки не имеют air-соседей.
]]
function MiningEngine:_isExposed(userId, x, z, y): boolean
    if y < SH then return true end
    local air = self._air[userId]
    if not air then return false end
    for _, d in ipairs(NEIGHBORS) do
        local nk = key(x + d[1], z + d[3], y + d[2])
        if air[nk] then return true end
    end
    return false
end

--[[
    Инициализация + генерация поверхности при первом вызове.
    Возвращает массив всех блоков (полный snapshot для клиента).
]]
function MiningEngine:getVisibleBlocks(player, playerData)
    local uid = player.UserId
    if not self._blocks[uid] then self._blocks[uid] = {}; self._air[uid] = {} end
    if not next(self._blocks[uid]) then self:_genSurface(uid) end
    local result = {}
    for k, block in pairs(self._blocks[uid]) do
        table.insert(result, { key = k, oreId = block.oreId, hp = block.hp, maxHp = block.maxHp })
    end
    return result
end

--[[
    Ударить блок. Сломал → генерируем соседей = никаких дыр.
    Возвращает обычный result + result.blockDelta — компактный список
    изменений (created / updated / removed) для отправки клиенту.
]]
function MiningEngine:hitBlock(player, playerData, x, z, y, isCrit: boolean?)
    local uid = player.UserId
    if not self._blocks[uid] then self._blocks[uid] = {}; self._air[uid] = {} end
    local blocks, air = self._blocks[uid], self._air[uid]
    local k = key(x, z, y)
    local block = blocks[k]
    if not block then return { success = false, error = "Block not found" } end

    if not self:_isExposed(uid, x, z, y) then
        return { success = false, error = "Block not exposed" }
    end

    if isCrit == nil then
        isCrit = math.random() < UpgradeLogic.critChance(playerData.critLevel or 1)
    end

    local power = UpgradeLogic.pickaxePower(playerData.pickaxeLevel or 1)
    local dmg = if isCrit then power * 3 else power
    -- Phase 11: damageBoost экипированных петов (1 + Σ damageBoost).
    -- Применяется ПОСЛЕ крита — пет усиливает и обычный, и крит-удар.
    dmg *= PetLogic.damageMultiplier(playerData)

    local blockLayer = self:_layer(block.depth)
    local weakPickaxe = false
    if blockLayer == "stone" and (playerData.pickaxeLevel or 1) < Constants.STONE_PICKAXE_MIN_LEVEL then
        dmg *= Constants.STONE_DAMAGE_PENALTY
        weakPickaxe = true
    end

    local snapshot: { [string]: any } = {}
    trackKey(snapshot, blocks, k)
    block.hp -= dmg
    if block.hp > 0 then
        return {
            success = true, mined = false, damage = dmg, crit = isCrit,
            remainingHp = block.hp, weakPickaxe = weakPickaxe,
            blockDelta = buildDelta(snapshot, blocks),
        }
    end

    local pool = self._db[self:_layer(block.depth)] or {}
    local oreDef = nil
    for _, o in ipairs(pool) do if o.id == block.oreId then oreDef = o; break end end
    blocks[k] = nil; air[k] = true

    self:_revealNeighbors(uid, x, z, y, snapshot)

    if oreDef then
        playerData.layer = self:_layer(block.depth)
    end
    self.onOreMined:fire(player, oreDef, block.depth)

    local roomRarity = nil
    local roomGenerated = false
    -- Phase 11: luckBoost петов умножает шанс скрытой комнаты.
    local roomChance = (Constants.SHAFT_BASE_CHANCE + block.depth * Constants.SHAFT_DEPTH_BONUS)
        * PetLogic.luckMultiplier(playerData)
    if oreDef and math.random() <= roomChance then
        roomGenerated = true
        local steps = 4 + math.random(0, 6)
        local cx, cz, cy = x, z, y
        local minY = math.max(0, y - 1)
        for _ = 1, steps do
            local d = NEIGHBORS[math.random(1, #NEIGHBORS)]
            local nx, nz, ny = cx + d[1], cz + d[3], math.max(minY, cy + d[2])
            for dx = -1, 1 do for dz = -1, 1 do for dy = -1, 1 do
                local rny = ny + dy
                if rny >= minY and math.random() < Constants.SHAFT_EXPAND_CHANCE then
                    local rk = key(nx+dx, nz+dz, rny)
                    if blocks[rk] and not air[rk] then
                        trackKey(snapshot, blocks, rk)
                        blocks[rk] = nil; air[rk] = true
                        self:_revealNeighbors(uid, nx+dx, nz+dz, rny, snapshot)
                    end
                end
            end end end
            cx, cz, cy = nx, nz, ny
        end
        local ek = key(cx, cz, cy)
        if not air[ek] then
            local ro = self:_roll(self:_layer(block.depth))
            local rarities = {"common","uncommon","rare","epic","legendary","mythic"}
            local ri = 1; for i, r in ipairs(rarities) do if r == ro.rarity then ri = i; break end end
            local nri = math.min(#rarities, ri + 1 + math.random(0, Constants.SHAFT_RARITY_BOOST_MAX))
            for _, o in ipairs(pool) do if o.rarity == rarities[nri] then ro = o; break end end
            local chestHp = ro.hp * (3 + math.random(0, 3))
            trackKey(snapshot, blocks, ek)
            blocks[ek] = { oreId = ro.id, hp = chestHp, maxHp = chestHp, depth = block.depth }
            roomRarity = ro.rarity
        end
    end

    -- Phase 11 (multiMine): шанс сломать ещё один соседний блок. Один
    -- дополнительный блок за удар (chance клампится <= 1 в PetLogic).
    local bonusOreDefs = nil
    local multiMineChance = PetLogic.multiMineChance(playerData)
    if multiMineChance > 0 and math.random() < multiMineChance then
        local bonusDef = self:_multiMineBreak(uid, x, z, y, snapshot)
        if bonusDef then
            bonusOreDefs = { bonusDef }
        end
    end

    return {
        success = true, mined = true, oreDef = oreDef, damage = dmg, crit = isCrit,
        roomGenerated = roomGenerated, roomRarity = roomRarity, weakPickaxe = weakPickaxe,
        bonusOreDefs = bonusOreDefs,
        blockDelta = buildDelta(snapshot, blocks),
    }
end

--[[
    Phase 11 (multiMine): мгновенно ломает один соседний открытый блок вокруг
    (x,z,y) и возвращает его OreDef (или nil). Снимок передаётся снаружи, чтобы
    изменения попали в общую дельту удара. Снос мгновенный (не по HP) — это
    «бонусный» блок от пета, не повторный удар.
]]
function MiningEngine:_multiMineBreak(uid, x, z, y, snapshot)
    local blocks, air = self._blocks[uid], self._air[uid]
    for _, d in ipairs(NEIGHBORS) do
        local nx, nz, ny = x + d[1], z + d[3], y + d[2]
        if ny >= 0 then
            local nk = key(nx, nz, ny)
            local nb = blocks[nk]
            if nb and self:_isExposed(uid, nx, nz, ny) then
                local pool = self._db[self:_layer(nb.depth)] or {}
                local oreDef = nil
                for _, o in ipairs(pool) do if o.id == nb.oreId then oreDef = o; break end end
                trackKey(snapshot, blocks, nk)
                blocks[nk] = nil; air[nk] = true
                self:_revealNeighbors(uid, nx, nz, ny, snapshot)
                return oreDef
            end
        end
    end
    return nil
end

function MiningEngine:resetPlayer(player)
    self._blocks[player.UserId] = nil; self._air[player.UserId] = nil
end

return MiningEngine
