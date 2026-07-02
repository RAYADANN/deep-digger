--!strict
-- Сборка списка активных бафов для BuffBar из HudState.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuffMeta = require(ReplicatedStorage:WaitForChild("shared").data.BuffMeta)
local MonetizationLogic = require(ReplicatedStorage:WaitForChild("shared").util.MonetizationLogic)

local BuffLogic = {}

export type BuffEntry = {
	id: string,
	kind: BuffMeta.BuffKind,
	iconKey: string,
	label: string,
	valueText: string,
	remaining: number?, -- nil = постоянный (питомец / VIP)
	source: BuffMeta.BuffSource,
}

local function pctFromMultiplier(mult: number): string
	return ("+%d%%"):format(math.floor((mult - 1) * 100 + 0.5))
end

local function pctFromAdditive(v: number): string
	return ("+%d%%"):format(math.floor(v * 100 + 0.5))
end

local function chancePct(v: number): string
	return ("%d%%"):format(math.floor(v * 100 + 0.5))
end

local function makeEntry(
	id: string,
	kind: BuffMeta.BuffKind,
	valueText: string,
	source: BuffMeta.BuffSource,
	remaining: number?
): BuffEntry
	return {
		id = id,
		kind = kind,
		iconKey = BuffMeta.ICON[kind],
		label = BuffMeta.LABEL[kind],
		valueText = valueText,
		remaining = remaining,
		source = source,
	}
end

--[[
    Строит плоский список бафов:
      • сводка экипированных питомцев (petEffects),
      • временные предметные бусты (activeBoosts),
      • VIP coinBoost (если есть).
]]
function BuffLogic.collect(
	petEffects: any,
	activeBoosts: { any }?,
	gamepasses: { [string]: boolean }?
): { BuffEntry }
	local entries: { BuffEntry } = {}
	local fx = petEffects or {}

	if (fx.damage or 1) > 1.001 then
		table.insert(entries, makeEntry(
			"pet_damage",
			"damage",
			pctFromMultiplier(fx.damage),
			"pet",
			nil
		))
	end
	if (fx.luck or 1) > 1.001 then
		table.insert(entries, makeEntry(
			"pet_luck",
			"luck",
			pctFromMultiplier(fx.luck),
			"pet",
			nil
		))
	end
	if (fx.coin or 0) > 0.001 then
		table.insert(entries, makeEntry(
			"pet_coin",
			"coin",
			pctFromAdditive(fx.coin),
			"pet",
			nil
		))
	end
	if (fx.multiMine or 0) > 0.001 then
		table.insert(entries, makeEntry(
			"pet_multimine",
			"multiMine",
			chancePct(fx.multiMine),
			"pet",
			nil
		))
	end

	if typeof(activeBoosts) == "table" then
		for i, boost in ipairs(activeBoosts) do
			if typeof(boost) == "table" then
				local rem = boost.remaining or 0
				if rem > 0 then
					local mapped = BuffMeta.BOOST_KIND[boost.kind or ""]
					if mapped then
						local mult = boost.multiplier or 1
						table.insert(entries, makeEntry(
							"item_" .. tostring(boost.kind) .. "_" .. tostring(i),
							mapped,
							("x%.1g"):format(mult),
							"item",
							rem
						))
					end
				end
			end
		end
	end

	local gpData = { gamepasses = gamepasses or {} }
	local vipCoin = MonetizationLogic.coinBoost(gpData)
	if vipCoin > 0.001 then
		table.insert(entries, makeEntry(
			"vip_coin",
			"coin",
			pctFromAdditive(vipCoin),
			"vip",
			nil
		))
	end

	return entries
end

function BuffLogic.entriesEqual(a: { BuffEntry }, b: { BuffEntry }): boolean
	if #a ~= #b then return false end
	for i = 1, #a do
		local x, y = a[i], b[i]
		if x.id ~= y.id
			or x.valueText ~= y.valueText
			or x.remaining ~= y.remaining
		then
			return false
		end
	end
	return true
end

return BuffLogic
