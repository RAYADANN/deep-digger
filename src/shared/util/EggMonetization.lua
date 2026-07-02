--!strict
-- Robux-цены и ключи девпродуктов для покупки яиц у машин.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local EggMonetization = {}

local ROBUX: { [string]: { one: number, ten: number } } = {
	basic = { one = 19, ten = 149 },
	desert = { one = 29, ten = 219 },
	candy = { one = 49, ten = 349 },
	ocean = { one = 79, ten = 549 },
	lava = { one = 99, ten = 749 },
	explosive_hydro = { one = 149, ten = 999 },
}

function EggMonetization.productKey(eggId: string, count: number): string
	local n = if count >= 10 then 10 else 1
	return ("egg_%s_%d"):format(eggId, n)
end

function EggMonetization.robuxPrice(eggId: string, count: number): number
	local tier = ROBUX[eggId]
	if not tier then
		return 0
	end
	return if count >= 10 then tier.ten else tier.one
end

function EggMonetization.registerDevProducts()
	local products = Constants.DEVPRODUCTS
	if not products then
		return
	end
	local eggs = (Constants.PETS or {}).eggs or {}
	for eggId, eggDef in pairs(eggs) do
		if typeof(eggDef) == "table" then
			for _, count in ipairs({ 1, 10 }) do
				local key = EggMonetization.productKey(eggId, count)
				if not products[key] then
					local price = EggMonetization.robuxPrice(eggId, count)
					products[key] = {
						key = key,
						id = 0,
						name = if count == 1
							then ("%s · 1×"):format(eggDef.name or eggId)
							else ("%s · %d×"):format(eggDef.name or eggId, count),
						icon = "icon_egg",
						priceRobux = price,
						kind = "egg_hatch",
						eggId = eggId,
						amount = count,
						desc = if count == 1 then "1 вылупление" else ("%d вылуплений"):format(count),
					}
				end
			end
		end
	end
end

EggMonetization.registerDevProducts()

return EggMonetization
