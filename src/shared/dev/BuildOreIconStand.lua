--!strict
-- Стенд для съёмки иконок руд (Studio edit mode).
-- print(require(game.ReplicatedStorage.shared.dev.BuildOreIconStand).build())

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("shared")
local Constants = require(shared.constants)
local OreDatabase = require(shared.data.OreDatabase).new()
local RefreshOreReferenceStand = require(shared.dev.RefreshOreReferenceStand)

local BS = Constants.BLOCK_SIZE_STUDS
local GRID_COLS = 10
local GRID_GAP = BS * 2.2
local ORIGIN = Vector3.new(280, BS / 2, 280)

local BuildOreIconStand = {}

local function isTestOre(oreId: string): boolean
	return string.find(oreId, "test", 1, true) ~= nil
end

local function collectOreIds(): { string }
	local ids: { string } = {}
	for _, pool in pairs(OreDatabase:getAll()) do
		for _, ore in ipairs(pool) do
			if not isTestOre(ore.id) then
				table.insert(ids, ore.id)
			end
		end
	end
	table.sort(ids)
	return ids
end

function BuildOreIconStand.build(folderName: string?): { oreId: string, position: Vector3 } }
	local name = folderName or "OreReferenceBlocks_Restyled"
	local old = Workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = Workspace

	local backdrop = Instance.new("Part")
	backdrop.Name = "_Backdrop"
	backdrop.Size = Vector3.new(GRID_COLS * GRID_GAP + 40, 1, 400)
	backdrop.Position = ORIGIN + Vector3.new(GRID_COLS * GRID_GAP * 0.45, -BS, 80)
	backdrop.Anchored = true
	backdrop.CanCollide = false
	backdrop.CastShadow = false
	backdrop.Color = Color3.fromRGB(18, 22, 32)
	backdrop.Material = Enum.Material.SmoothPlastic
	backdrop.Parent = folder

	local positions: { { oreId: string, position: Vector3 } } = {}
	local ids = collectOreIds()

	for i, oreId in ipairs(ids) do
		local col = (i - 1) % GRID_COLS
		local row = math.floor((i - 1) / GRID_COLS)
		local pos = ORIGIN + Vector3.new(col * GRID_GAP, 0, row * GRID_GAP)

		local block = Instance.new("Part")
		block.Name = oreId
		block.Size = Vector3.new(BS, BS, BS)
		block.Position = pos
		block.Anchored = true
		block.CanCollide = false
		block.Parent = folder

		table.insert(positions, { oreId = oreId, position = pos })
	end

	RefreshOreReferenceStand.refresh(name)

	return positions
end

return BuildOreIconStand
