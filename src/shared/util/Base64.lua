--!strict
-- Минимальный base64 → buffer (Studio без buffer.frombase64).

local Base64 = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local LUT: { [string]: number } = {}
for i = 1, #ALPHABET do
	LUT[string.sub(ALPHABET, i, i)] = i - 1
end

function Base64.decode(data: string): buffer
	local len = #data
	local outLen = math.floor(len * 3 / 4)
	if string.sub(data, -2) == "==" then
		outLen -= 2
	elseif string.sub(data, -1) == "=" then
		outLen -= 1
	end

	local out = buffer.create(outLen)
	local j = 0
	local i = 1
	while i <= len do
		local a = LUT[string.sub(data, i, i)] or 0
		local b = LUT[string.sub(data, i + 1, i + 1)] or 0
		local c = LUT[string.sub(data, i + 2, i + 2)] or 0
		local d = LUT[string.sub(data, i + 3, i + 3)] or 0

		local n = a * 262144 + b * 4096 + c * 64 + d
		buffer.writeu8(out, j, bit32.rshift(n, 16))
		j += 1
		if j < outLen then
			buffer.writeu8(out, j, bit32.band(bit32.rshift(n, 8), 0xFF))
			j += 1
		end
		if j < outLen then
			buffer.writeu8(out, j, bit32.band(n, 0xFF))
			j += 1
		end
		i += 4
	end
	return out
end

return Base64
