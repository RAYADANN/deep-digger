--!strict
-- OreShellMeshes — mesh/scale накидки OreShell по редкости.
-- rare/epic — отдельные шаблоны в Kit; остальное — Version1.
-- SpecialMesh.Scale умножает сырой bbox ассета, не MeshPart.Size шаблона.

export type ShellMesh = {
	meshId: string,
	scale: number,
}

type RarityShellDef = {
	meshId: string,
	scale: number,
	workspaceNames: { string },
	kitNames: { string },
	rsName: string,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local OreShellMeshes = {}

local REF_BLOCK_STUDS = 4.5
local SHELL_FACE_COVER = 1.05

local DEFAULT_MESH_ID = "rbxassetid://71939651950188"
local DEFAULT_SCALE = 0.024

local RARITY_SHELLS: { [string]: RarityShellDef } = {
	rare = {
		meshId = "rbxassetid://133929637061671",
		scale = 0.022,
		workspaceNames = { "Rare" },
		kitNames = { "Rare", "rare", "Version2", "Version 2" },
		rsName = "rare",
	},
	epic = {
		meshId = "rbxassetid://74350601313457",
		-- Сырой bbox ~210 studs (как Version1); чуть меньше 0.024 под размер шаблона.
		scale = 0.022,
		workspaceNames = { "Epic" },
		kitNames = { "Epic", "epic" },
		rsName = "epic",
	},
}

local MESH_SCALES: { [string]: number } = {
	[DEFAULT_MESH_ID] = DEFAULT_SCALE,
}
for _, def in pairs(RARITY_SHELLS) do
	MESH_SCALES[def.meshId] = def.scale
end

local _cache: { [string]: ShellMesh? } = {}

local function meshIdFromInstance(inst: Instance): string?
	if inst:IsA("MeshPart") and inst.MeshId ~= "" then
		return inst.MeshId
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("MeshPart") and d.MeshId ~= "" then
			return d.MeshId
		end
		if d:IsA("SpecialMesh") and d.MeshId ~= "" then
			return d.MeshId
		end
	end
	return nil
end

local function scaleForMeshId(meshId: string, blockStuds: number): number
	local base = MESH_SCALES[meshId] or DEFAULT_SCALE
	return base * (blockStuds * SHELL_FACE_COVER) / (REF_BLOCK_STUDS * SHELL_FACE_COVER)
end

local function scaleForTemplate(inst: Instance, meshId: string, blockStuds: number): number
	local attr = inst:GetAttribute("ShellScale")
	if typeof(attr) == "number" and attr > 0 then
		return attr * (blockStuds * SHELL_FACE_COVER) / (REF_BLOCK_STUDS * SHELL_FACE_COVER)
	end
	return scaleForMeshId(meshId, blockStuds)
end

local function shellFromTemplate(inst: Instance, blockStuds: number): ShellMesh?
	local meshId = meshIdFromInstance(inst)
	if not meshId then
		return nil
	end
	return {
		meshId = meshId,
		scale = scaleForTemplate(inst, meshId, blockStuds),
	}
end

local function isKitShellCandidate(name: string, rarityKey: string): boolean
	local n = name:lower():gsub("%s+", "")
	if n == "version1" then
		return false
	end
	if rarityKey == "rare" then
		return n:find("rare", 1, true) ~= nil or n:find("version2", 1, true) ~= nil
	end
	if rarityKey == "epic" then
		return n:find("epic", 1, true) ~= nil
	end
	return false
end

local function resolveRarityTemplate(rarityKey: string, blockStuds: number): ShellMesh
	local def = RARITY_SHELLS[rarityKey]
	if not def then
		return { meshId = DEFAULT_MESH_ID, scale = scaleForMeshId(DEFAULT_MESH_ID, blockStuds) }
	end

	for _, wsName in def.workspaceNames do
		local inst = Workspace:FindFirstChild(wsName)
		if inst then
			local shell = shellFromTemplate(inst, blockStuds)
			if shell then
				return shell
			end
		end
	end

	local rsFolder = ReplicatedStorage:FindFirstChild("OreShellMeshes")
	if rsFolder then
		local tmpl = rsFolder:FindFirstChild(def.rsName)
		if tmpl then
			local shell = shellFromTemplate(tmpl, blockStuds)
			if shell then
				return shell
			end
		end
	end

	local kit = Workspace:FindFirstChild("Kit")
	if kit then
		for _, kitName in def.kitNames do
			local preferred = kit:FindFirstChild(kitName)
			if preferred then
				local shell = shellFromTemplate(preferred, blockStuds)
				if shell then
					return shell
				end
			end
		end
		for _, child in ipairs(kit:GetChildren()) do
			if isKitShellCandidate(child.Name, rarityKey) then
				local shell = shellFromTemplate(child, blockStuds)
				if shell then
					return shell
				end
			end
		end
	end

	local rarityLower = rarityKey:lower()
	for _, child in ipairs(Workspace:GetChildren()) do
		local nameLower = child.Name:lower()
		if nameLower:find(rarityLower, 1, true) and not nameLower:find("reference", 1, true) then
			if child:IsA("Model") or child:IsA("MeshPart") or child:IsA("Folder") then
				local shell = shellFromTemplate(child, blockStuds)
				if shell then
					return shell
				end
			end
		end
	end

	return { meshId = def.meshId, scale = scaleForMeshId(def.meshId, blockStuds) }
end

function OreShellMeshes.invalidateCache()
	table.clear(_cache)
end

function OreShellMeshes.get(rarity: string, blockStuds: number?): ShellMesh
	local bs = blockStuds or REF_BLOCK_STUDS
	local def = RARITY_SHELLS[rarity]
	if def then
		if _cache[rarity] == nil then
			_cache[rarity] = resolveRarityTemplate(rarity, bs)
		end
		return _cache[rarity] :: ShellMesh
	end
	return { meshId = DEFAULT_MESH_ID, scale = scaleForMeshId(DEFAULT_MESH_ID, bs) }
end

return OreShellMeshes
