--!strict
-- Сырые записи питомцев (30 шт., по одной 3D-модели на пета из PetKit).

export type PetEffectKind = "damageBoost" | "luckBoost" | "coinBoost" | "multiMine"
export type PetRarity = "common" | "uncommon" | "rare" | "epic" | "legendary" | "mythic"

export type PetEffect = {
	kind: PetEffectKind,
	value: number,
}

export type Pet = {
	id: string,
	name: string,
	rarity: PetRarity,
	icon: string,
	modelName: string,
	color: Color3,
	effect: PetEffect,
}

local function pet(
	id: string,
	name: string,
	rarity: PetRarity,
	icon: string,
	modelName: string,
	color: Color3,
	kind: PetEffectKind,
	value: number
): Pet
	return {
		id = id,
		name = name,
		rarity = rarity,
		icon = icon,
		modelName = modelName,
		color = color,
		effect = { kind = kind, value = value },
	}
end

local C = Color3.fromRGB

local PETS: { Pet } = {
	-- common ×6
	pet("pebble_pup", "Камешек", "common", "🐀", "rat", C(170, 160, 150), "damageBoost", 0.10),
	pet("coin_chick", "Монетка", "common", "🐤", "chicken", C(200, 190, 120), "coinBoost", 0.10),
	pet("spot_lady", "Божья коровка", "common", "🐞", "ladybug", C(220, 60, 80), "luckBoost", 0.10),
	pet("nut_squirrel", "Белочка", "common", "🐿️", "squirrel", C(180, 130, 90), "coinBoost", 0.10),
	pet("sand_snake", "Песчаный змей", "common", "🐍", "snake", C(160, 180, 100), "damageBoost", 0.10),
	pet("pink_flamingo", "Фламинго", "common", "🦩", "flamingo", C(255, 120, 180), "luckBoost", 0.10),

	-- uncommon ×6
	pet("mole_digger", "Кротёныш", "uncommon", "🪱", "worm", C(120, 200, 120), "damageBoost", 0.20),
	pet("lucky_cat", "Удачливый кот", "uncommon", "🐱", "cat", C(120, 210, 140), "luckBoost", 0.20),
	pet("cave_bat", "Летучая мышь", "uncommon", "🦇", "bat", C(90, 80, 120), "luckBoost", 0.20),
	pet("ice_seal", "Тюлень", "uncommon", "🦭", "seal", C(190, 210, 230), "coinBoost", 0.20),
	pet("dune_serpent", "Пустынный удав", "uncommon", "🐍", "desert snake", C(210, 170, 90), "damageBoost", 0.20),
	pet("wave_dolphin", "Дельфин", "uncommon", "🐬", "dolphin", C(80, 170, 230), "coinBoost", 0.20),

	-- rare ×6
	pet("gem_fox", "Самоцветный лис", "rare", "🦊", "fox", C(60, 140, 255), "coinBoost", 0.25),
	pet("drill_bot", "Бур-бот", "rare", "🐝", "bee", C(80, 150, 255), "multiMine", 0.15),
	pet("reef_shark", "Акула", "rare", "🦈", "shark", C(100, 150, 200), "damageBoost", 0.25),
	pet("sand_scorpion", "Скорпион", "rare", "🦂", "scorpion", C(200, 120, 60), "multiMine", 0.15),
	pet("tusk_walrus", "Морж", "rare", "🦭", "walrus", C(150, 170, 190), "coinBoost", 0.25),
	pet("meadow_bull", "Бык", "rare", "🐂", "bull", C(160, 100, 70), "damageBoost", 0.25),

	-- epic ×5
	pet("crystal_owl", "Кристальная сова", "epic", "🦉", "owl", C(180, 60, 220), "damageBoost", 0.40),
	pet("midas_hound", "Золотой гончий", "epic", "🦚", "goldenpeacock", C(230, 190, 60), "coinBoost", 0.40),
	pet("swamp_croc", "Крокодил", "epic", "🐊", "crocodile", C(70, 150, 90), "multiMine", 0.22),
	pet("jungle_titan", "Слон", "epic", "🐘", "elephant", C(140, 130, 150), "damageBoost", 0.40),
	pet("river_hippo", "Бегемот", "epic", "🦛", "hippo", C(120, 150, 180), "coinBoost", 0.40),

	-- legendary ×4
	pet("phoenix_drake", "Огненный дракончик", "legendary", "🐉", "dragon", C(255, 160, 0), "multiMine", 0.30),
	pet("sky_sovereign", "Небесный орёл", "legendary", "🦅", "eagle", C(200, 180, 100), "damageBoost", 0.55),
	pet("royal_peacock", "Королевский павлин", "legendary", "🦚", "peacock", C(100, 200, 255), "luckBoost", 0.55),
	pet("frost_ram", "Снежный баран", "legendary", "🐏", "snow ram", C(220, 235, 255), "coinBoost", 0.55),

	-- mythic ×3
	pet("void_titan", "Титан Бездны", "mythic", "👾", "SUPER FOX", C(255, 60, 60), "damageBoost", 1.00),
	pet("thunder_buffalo", "Громовой буйвол", "mythic", "🐃", "buffalo", C(180, 140, 90), "damageBoost", 0.85),
	pet("star_penguin", "Звёздный пингвин", "mythic", "🐧", "penguin", C(80, 180, 255), "multiMine", 0.45),
}

return PETS
