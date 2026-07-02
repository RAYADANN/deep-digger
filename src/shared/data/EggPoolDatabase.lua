--!strict
-- Пулы питомцев по типам яиц. Каждое яйцо — свой набор petId + weight (gacha-style).

export type PoolEntry = {
	petId: string,
	weight: number,
}

local POOLS: { [string]: { PoolEntry } } = {
	-- Стартовое яйце: 6 простых питомцев, без «лотереи по редкости».
	basic = {
		{ petId = "pebble_pup", weight = 28 },
		{ petId = "coin_chick", weight = 25 },
		{ petId = "spot_lady", weight = 22 },
		{ petId = "nut_squirrel", weight = 15 },
		{ petId = "mole_digger", weight = 8 },
		{ petId = "lucky_cat", weight = 2 },
	},
	-- Пустынное яйцо (гемы): змеи, скорпион, редкие пустынные.
	desert = {
		{ petId = "sand_snake", weight = 30 },
		{ petId = "dune_serpent", weight = 25 },
		{ petId = "sand_scorpion", weight = 22 },
		{ petId = "gem_fox", weight = 12 },
		{ petId = "meadow_bull", weight = 8 },
		{ petId = "frost_ram", weight = 3 },
	},
	candy = {
		{ petId = "pink_flamingo", weight = 25 },
		{ petId = "coin_chick", weight = 20 },
		{ petId = "spot_lady", weight = 18 },
		{ petId = "ice_seal", weight = 18 },
		{ petId = "crystal_owl", weight = 12 },
		{ petId = "royal_peacock", weight = 7 },
	},
	ocean = {
		{ petId = "wave_dolphin", weight = 28 },
		{ petId = "ice_seal", weight = 22 },
		{ petId = "reef_shark", weight = 20 },
		{ petId = "tusk_walrus", weight = 15 },
		{ petId = "river_hippo", weight = 10 },
		{ petId = "star_penguin", weight = 5 },
	},
	lava = {
		{ petId = "cave_bat", weight = 22 },
		{ petId = "drill_bot", weight = 20 },
		{ petId = "jungle_titan", weight = 22 },
		{ petId = "swamp_croc", weight = 18 },
		{ petId = "phoenix_drake", weight = 12 },
		{ petId = "void_titan", weight = 6 },
	},
	explosive_hydro = {
		{ petId = "drill_bot", weight = 15 },
		{ petId = "midas_hound", weight = 20 },
		{ petId = "phoenix_drake", weight = 25 },
		{ petId = "sky_sovereign", weight = 22 },
		{ petId = "thunder_buffalo", weight = 12 },
		{ petId = "void_titan", weight = 6 },
	},
}

local module = {}

function module.getPool(eggId: string): { PoolEntry }
	return POOLS[eggId] or POOLS.basic or {}
end

function module.getAllEggIds(): { string }
	local ids: { string } = {}
	for id in pairs(POOLS) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return module
