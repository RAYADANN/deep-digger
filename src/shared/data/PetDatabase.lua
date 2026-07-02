--!strict
-- Единственный источник правды по питомцам (30 playable).
-- Пулы яиц — shared/data/EggPoolDatabase.lua.

local Entries = require(script.Parent.PetDatabaseEntries)

export type PetEffectKind = Entries.PetEffectKind
export type PetRarity = Entries.PetRarity
export type PetEffect = Entries.PetEffect
export type Pet = Entries.Pet

local PETS: { Pet } = Entries

local byId: { [string]: Pet } = {}
for _, def in ipairs(PETS) do
	byId[def.id] = def
end

local byRarity: { [string]: { Pet } } = {}
for _, def in ipairs(PETS) do
	local bucket = byRarity[def.rarity]
	if not bucket then
		bucket = {}
		byRarity[def.rarity] = bucket
	end
	table.insert(bucket, def)
end

local module = {}

function module.get(petId: string): Pet?
	return byId[petId]
end

function module.getAll(): { Pet }
	return PETS
end

function module.getByRarity(rarity: string): { Pet }
	return byRarity[rarity] or {}
end

function module.count(): number
	return #PETS
end

return module
