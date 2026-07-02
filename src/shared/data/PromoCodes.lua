--!strict
-- PromoCodes.lua — таблица промокодов (единый источник клиент+сервер).
--
--   code            — ключ в верхнем регистре (LAUNCH2026).
--   reward          — coins / gems / boost (временный мультипликатор).
--   expiresAt       — unix os.time(); nil = без срока.
--   maxRedemptions  — глобальный лимит использований (DataStore-счётчик);
--                     nil = без лимита.

export type PromoBoostReward = {
	kind: string,
	multiplier: number,
	durationSec: number,
}

export type PromoReward = {
	coins: number?,
	gems: number?,
	boost: PromoBoostReward?,
}

export type PromoCodeDef = {
	code: string,
	reward: PromoReward,
	expiresAt: number?,
	maxRedemptions: number?,
}

local PromoCodes = {}

local DEFINITIONS: { [string]: PromoCodeDef } = {
	LAUNCH2026 = {
		code = "LAUNCH2026",
		reward = {
			coins = 15000,
			gems = 25,
			boost = { kind = "coins", multiplier = 2, durationSec = 1800 },
		},
		expiresAt = nil,
		maxRedemptions = 10000,
	},
	WELCOME = {
		code = "WELCOME",
		reward = {
			coins = 5000,
			gems = 10,
		},
		expiresAt = nil,
		maxRedemptions = nil,
	},
}

function PromoCodes.getAll(): { PromoCodeDef }
	local list: { PromoCodeDef } = {}
	for _, def in pairs(DEFINITIONS) do
		table.insert(list, def)
	end
	table.sort(list, function(a, b)
		return a.code < b.code
	end)
	return list
end

function PromoCodes.getByCode(code: string): PromoCodeDef?
	local key = string.upper((code :: string):gsub("^%s+", ""):gsub("%s+$", ""))
	return DEFINITIONS[key]
end

return PromoCodes
