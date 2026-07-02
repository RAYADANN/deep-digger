--!strict
-- Санитизация Workspace вокруг шахты: маркер зоны, площадки у входа, exclude для лучей.

local Constants = require(script.Parent.Parent.constants)

local MineZoneWorkspace = {}

export type SanitizeResult = {
	raycastExcludes: { Instance },
	deckParts: { BasePart },
}

local RAYCAST_EXCLUDE_NAMES = { "MineZoneMarker", "DeepDigger_TutorialPath", "MineRespawn" }

local function isMineEntrancePlatform(part: BasePart, volume: BasePart, mineFolder: Instance?): boolean
	if mineFolder and part:IsDescendantOf(mineFolder) then
		return false
	end
	local marker = volume.Parent
	if marker and part:IsDescendantOf(marker) then
		return false
	end
	local topY = volume.Position.Y + volume.Size.Y / 2
	local volCF = volume.CFrame
	local half = volume.Size / 2
	local rel = volCF:PointToObjectSpace(part.Position)
	local padX = part.Size.X / 2 + 1
	local padZ = part.Size.Z / 2 + 1
	if math.abs(rel.X) > half.X + padX or math.abs(rel.Z) > half.Z + padZ then
		return false
	end
	local partTop = part.Position.Y + part.Size.Y / 2
	local partBottom = part.Position.Y - part.Size.Y / 2
	return partBottom <= topY + 2 and partTop >= topY - 8
end

function MineZoneWorkspace.sanitize(ws: Workspace): SanitizeResult
	local raycastExcludes: { Instance } = {}
	local deckParts: { BasePart } = {}

	for _, name in RAYCAST_EXCLUDE_NAMES do
		local inst = ws:FindFirstChild(name)
		if inst then
			table.insert(raycastExcludes, inst)
		end
	end

	local marker = ws:FindFirstChild("MineZoneMarker")
	if not marker then
		return { raycastExcludes = raycastExcludes, deckParts = deckParts }
	end

	local volume = marker:FindFirstChild("Volume")
	if not volume or not volume:IsA("BasePart") then
		return { raycastExcludes = raycastExcludes, deckParts = deckParts }
	end

	for _, desc in marker:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CanQuery = false
			desc.CanCollide = false
		end
	end

	local respawn = ws:FindFirstChild("MineRespawn")
	if respawn and respawn:IsA("BasePart") then
		respawn.CanQuery = false
	end

	local mineFolder = ws:FindFirstChild("DeepDigger_Mine")
	for _, inst in ws:GetDescendants() do
		if inst:IsA("BasePart") and isMineEntrancePlatform(inst :: BasePart, volume, mineFolder) then
			local part = inst :: BasePart
			part.CanQuery = false
			-- Коллайдер обязателен: иначе провал под весь Union/пол.
			-- Проход в прокопанную ячейку — через MineDeckCollision (PASS_GROUP).
			part.CanCollide = true
			table.insert(deckParts, part)
			table.insert(raycastExcludes, inst)
		end
	end

	return { raycastExcludes = raycastExcludes, deckParts = deckParts }
end

function MineZoneWorkspace.columnInSurfaceGrid(gx: number, gz: number): boolean
	local hw = math.floor(Constants.SURFACE_W / 2)
	local hd = math.floor(Constants.SURFACE_D / 2)
	return gx >= -hw and gx <= hw and gz >= -hd and gz <= hd
end

return MineZoneWorkspace
