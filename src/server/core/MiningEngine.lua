--!strict
-- MiningEngine.lua — бесконечная 3D шахта через Neighbor Reveal.
-- Блоки генерируются только когда нужны (при ломке соседнего).
-- Никаких чанков — никаких дыр.

local shared = game:GetService("ReplicatedStorage"):WaitForChild("shared")
local Signal = require(shared.util.Signal)
local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local OreTypes = require(shared.types.OreTypes)

local MiningEngine = {}
MiningEngine.__index = MiningEngine

type OreDef = OreTypes.OreDef
type PlayerData = OreTypes.PlayerData

local NEIGHBORS = {
    {1,0,0}, {-1,0,0},
    {0,1,0}, {0,-1,0},
    {0,0,1}, {0,0,-1},
}

local SW = Constants.SURFACE_W -- 15
local SD = Constants.SURFACE_D -- 15
local SH = Constants.SURFACE_H -- 10

local function key(x, z, y) return string.format("%d_%d_%d", x, z, y) end
local function parseKey(k)
    local parts = string.split(k, "_")
    return tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0
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

function MiningEngine:_roll(layerId)
    local pool = self._db[layerId] or self._db["dirt"]
    local items = {}
    for rar, ch in pairs(Constants.RARITY_CHANCES) do table.insert(items, {rar = rar, ch = ch}) end
    table.sort(items, function(a, b) return a.ch > b.ch end)
    local r, c = math.random(), 0
    for _, e in ipairs(items) do
        c += e.ch; if r <= c then
            local cand = {}
            for _, o in ipairs(pool) do if o.rarity == e.rar then cand[#cand+1] = o end end
            if #cand > 0 then return cand[math.random(1, #cand)] end
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

function MiningEngine:_revealNeighbors(userId, x, z, y)
    local blocks, air = self._blocks[userId], self._air[userId]
    for _, d in ipairs(NEIGHBORS) do
        local nx, nz, ny = x + d[1], z + d[3], y + d[2]
        if ny >= 0 then
            local k = key(nx, nz, ny)
            if not (air and air[k]) and not (blocks and blocks[k]) then
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
    Инициализация + генерация поверхности при первом вызове.
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
]]
function MiningEngine:hitBlock(player, playerData, x, z, y, isCrit)
    local uid = player.UserId
    if not self._blocks[uid] then self._blocks[uid] = {}; self._air[uid] = {} end
    local blocks, air = self._blocks[uid], self._air[uid]
    local k = key(x, z, y)
    local block = blocks[k]
    if not block then return { success = false, error = "Block not found" } end

    local power = 1 + (playerData.pickaxeLevel - 1) * 2
    local dmg = isCrit and (power * 3) or power
    block.hp -= dmg
    if block.hp > 0 then
        return { success = true, mined = false, damage = dmg, crit = isCrit, remainingHp = block.hp }
    end

    local pool = self._db[self:_layer(block.depth)] or {}
    local oreDef = nil
    for _, o in ipairs(pool) do if o.id == block.oreId then oreDef = o; break end end
    blocks[k] = nil; air[k] = true

    -- Neighbor Reveal: соседи появляются немедленно
    self:_revealNeighbors(uid, x, z, y)

    if oreDef then
        playerData.depth += math.ceil(oreDef.hp / 10)
        playerData.layer = self:_layer(math.floor(playerData.depth))
        playerData.totalBlocksMined += 1
    end
    self.onOreMined:fire(player, oreDef, block.depth)

    -- Комната (15% шанс)
    if oreDef and math.random() <= 0.15 + playerData.depth * 0.00002 then
        local steps = 4 + math.random(0, 6)
        local cx, cz, cy = x, z, y
        local minY = math.max(0, y - 1)
        for _ = 1, steps do
            local d = NEIGHBORS[math.random(1, #NEIGHBORS)]
            local nx, nz, ny = cx + d[1], cz + d[3], math.max(minY, cy + d[2])
            for dx = -1, 1 do for dz = -1, 1 do for dy = -1, 1 do
                local rny = ny + dy
                if rny >= minY and math.random() < 0.7 then
                    local rk = key(nx+dx, nz+dz, rny)
                    if blocks[rk] and not air[rk] then
                        blocks[rk] = nil; air[rk] = true
                        self:_revealNeighbors(uid, nx+dx, nz+dz, rny)
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
            local nri = math.min(#rarities, ri + 1 + math.random(0, 2))
            for _, o in ipairs(pool) do if o.rarity == rarities[nri] then ro = o; break end end
            blocks[ek] = { oreId = ro.id, hp = ro.hp*(3+math.random(0,3)), maxHp = ro.hp*(3+math.random(0,3)), depth = block.depth }
        end
    end

    return { success = true, mined = true, oreDef = oreDef, damage = dmg, crit = isCrit }
end

function MiningEngine:resetPlayer(player)
    self._blocks[player.UserId] = nil; self._air[player.UserId] = nil
end

return MiningEngine
