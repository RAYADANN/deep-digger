--!strict
-- PromoCodeLogic.lua — валидация промокодов (shared, без side-effects).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PromoCodes = require(ReplicatedStorage:WaitForChild("shared").data.PromoCodes)

export type ValidateResult = {
	ok: boolean,
	error: string?,
	message: string?,
	def: PromoCodes.PromoCodeDef?,
	normalizedCode: string?,
}

local PromoCodeLogic = {}

function PromoCodeLogic.normalize(raw: string): string?
	if typeof(raw) ~= "string" then
		return nil
	end
	local trimmed = raw:gsub("^%s+", ""):gsub("%s+$", "")
	if trimmed == "" then
		return nil
	end
	return string.upper(trimmed)
end

function PromoCodeLogic.ensureRedeemed(data: any): { [string]: boolean }
	if typeof(data.redeemedCodes) ~= "table" then
		data.redeemedCodes = {}
	end
	return data.redeemedCodes
end

function PromoCodeLogic.isRedeemed(data: any, code: string): boolean
	local redeemed = PromoCodeLogic.ensureRedeemed(data)
	return redeemed[code] == true
end

function PromoCodeLogic.validate(data: any, rawCode: string, now: number?): ValidateResult
	local normalized = PromoCodeLogic.normalize(rawCode)
	if not normalized then
		return { ok = false, error = "empty", message = "Введите код" }
	end

	local def = PromoCodes.getByCode(normalized)
	if not def then
		return { ok = false, error = "unknown", message = "Код не найден" }
	end

	if def.expiresAt and (now or os.time()) > def.expiresAt then
		return { ok = false, error = "expired", message = "Срок действия кода истёк" }
	end

	if PromoCodeLogic.isRedeemed(data, normalized) then
		return { ok = false, error = "already", message = "Код уже использован" }
	end

	return { ok = true, def = def, normalizedCode = normalized }
end

return PromoCodeLogic
