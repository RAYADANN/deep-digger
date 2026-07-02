--!strict
-- RefreshOreReferenceStand — обновить Workspace.OreReferenceBlocks_Restyled
-- по OreBlockDecor (тот же визуал, что в шахте).
-- Studio: print(require(game.ReplicatedStorage.shared.dev.RefreshOreReferenceStand).refresh())

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("shared")
local OreDatabase = require(shared.data.OreDatabase).new()
local OreBlockDecor = require(shared.util.OreBlockDecor)
local OreShellMeshes = require(shared.util.OreShellMeshes)
local Constants = require(shared.constants)

local BS = Constants.BLOCK_SIZE_STUDS

local RefreshOreReferenceStand = {}

function RefreshOreReferenceStand.refresh(folderName: string?): string
	OreShellMeshes.invalidateCache()
	local folder = Workspace:FindFirstChild(folderName or "OreReferenceBlocks_Restyled")
	if not folder then
		return "Folder not found: " .. tostring(folderName or "OreReferenceBlocks_Restyled")
	end

	local stats = { ok = 0, skip = 0, missing = 0, rareShell = 0, epicShell = 0, errors = {} :: { string } }

	for _, block in folder:GetChildren() do
		if block.Name == "JitterDemo_Dirt" or not block:IsA("BasePart") then
			stats.skip += 1
			continue
		end
		local def = OreDatabase:getOre(block.Name)
		if not def then
			stats.missing += 1
			table.insert(stats.errors, block.Name .. ": no def")
			continue
		end

		local decorDef: OreBlockDecor.OreDecorDef = {
			id = def.id,
			color = def.color,
			rarity = def.rarity,
			weight = def.weight,
		}

		OreBlockDecor.applyHostStyle(block, decorDef)
		OreBlockDecor.stripCrystals(block)
		OreBlockDecor.mountShell(block, OreBlockDecor.FACE_NORMALS, decorDef, BS)
		OreBlockDecor.attachAmbientFX(block, decorDef, nil)
		OreBlockDecor.attachRarityGlow(block, decorDef)

		if not OreBlockDecor.isFiller(decorDef) then
			if def.rarity == "rare" then
				stats.rareShell += 1
			elseif def.rarity == "epic" then
				stats.epicShell += 1
			end
		end

		local gui = block:FindFirstChildWhichIsA("BillboardGui", true)
		if gui then
			local tl = gui:FindFirstChildWhichIsA("TextLabel", true)
			if tl then
				tl.Text = def.name .. " (" .. def.rarity .. ")"
			end
		end

		stats.ok += 1
	end

	local rareMesh = OreShellMeshes.get("rare", BS)
	local epicMesh = OreShellMeshes.get("epic", BS)
	return string.format(
		"Updated %d blocks (%d rare, %d epic shells; rare=%s %.4f, epic=%s %.4f), skipped %d, missing %d\n%s",
		stats.ok,
		stats.rareShell,
		stats.epicShell,
		rareMesh.meshId,
		rareMesh.scale,
		epicMesh.meshId,
		epicMesh.scale,
		stats.skip,
		stats.missing,
		table.concat(stats.errors, "\n")
	)
end

return RefreshOreReferenceStand
