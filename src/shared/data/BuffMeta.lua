--!strict
-- Метаданные бафов: иконки, цвета, подписи. Единый источник для BuffBar.

export type BuffKind = "damage" | "luck" | "coin" | "multiMine" | "speed"

export type BuffSource = "pet" | "item" | "vip"

local BuffMeta = {}

BuffMeta.ICON = {
	damage    = "buff_damage",
	luck      = "buff_luck",
	coin      = "buff_coin",
	multiMine = "buff_multimine",
	speed     = "upg_speed",
} :: { [BuffKind]: string }

BuffMeta.ACCENT = {
	damage    = Color3.fromRGB(255, 110, 90),
	luck      = Color3.fromRGB(70, 220, 130),
	coin      = Color3.fromRGB(255, 210, 60),
	multiMine = Color3.fromRGB(100, 180, 255),
	speed     = Color3.fromRGB(90, 200, 255),
} :: { [BuffKind]: Color3 }

BuffMeta.LABEL = {
	damage    = "Урон",
	luck      = "Удача",
	coin      = "Монеты",
	multiMine = "×2 блок",
	speed     = "Скорость",
} :: { [BuffKind]: string }

-- Маппинг kind из PlayerBoosts (временные предметы).
BuffMeta.BOOST_KIND = {
	coins  = "coin",
	luck   = "luck",
	damage = "damage",
	speed  = "speed",
} :: { [string]: BuffKind }

function BuffMeta.kindFromPetEffect(petKind: string): BuffKind?
	if petKind == "damageBoost" then return "damage" end
	if petKind == "luckBoost" then return "luck" end
	if petKind == "coinBoost" then return "coin" end
	if petKind == "multiMine" then return "multiMine" end
	return nil
end

return BuffMeta
