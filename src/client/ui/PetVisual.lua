--!strict
-- 3D-модели экипированных питомцев: плавное следование за игроком (без карусели).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetDatabase = require(ReplicatedStorage:WaitForChild("shared").data.PetDatabase)
local PetModelKit = require(ReplicatedStorage:WaitForChild("shared").util.PetModelKit)

local PetVisual = {}

type ActivePet = {
	petId: string,
	model: Model,
	parts: { BasePart },
	visible: boolean,
	position: Vector3?,
	orientation: CFrame?,
	phase: number,
}

local currentPetIds: { string } = {}
local active: { [string]: ActivePet } = {}
local conn: RBXScriptConnection? = nil

local HEIGHT_BASE = 1.5
local BOB_AMPLITUDE = 0.12
local BOB_SPEED = 2.4
local POS_SMOOTH = 10
local YAW_SMOOTH = 12
local MAX_DT = 1 / 20

local function getRoot(): BasePart?
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local char = player.Character
	if not char then
		return nil
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function expAlpha(speed: number, dt: number): number
	return 1 - math.exp(-speed * dt)
end

local function buildOrientation(position: Vector3, root: BasePart): CFrame
	local rootRotation = root.CFrame - root.CFrame.Position
	return CFrame.new(position) * rootRotation
end

local function cacheModelParts(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			parts[#parts + 1] = d
		end
	end
	return parts
end

-- Слоты за спиной игрока: плечо / дуга, как в pet-sim играх.
local function slotLocalOffset(index: number, count: number): Vector3
	if count <= 1 then
		return Vector3.new(2.0, 0, 3.6)
	end
	if count == 2 then
		local side = if index == 1 then -2.2 else 2.2
		return Vector3.new(side, 0, 3.4)
	end
	local span = math.pi * 0.72
	local t = if count == 1 then 0.5 else (index - 1) / (count - 1)
	local angle = -span * 0.5 + span * t
	return Vector3.new(math.sin(angle) * 3.0, 0, 3.2 + math.cos(angle) * 1.4)
end

local function targetWorldPosition(root: BasePart, index: number, count: number, bob: number): Vector3
	local localOffset = slotLocalOffset(index, count)
	local worldOffset = root.CFrame:VectorToWorldSpace(localOffset)
	return root.Position + worldOffset + Vector3.new(0, HEIGHT_BASE + bob, 0)
end

local function setEntryVisible(entry: ActivePet, visible: boolean)
	if entry.visible == visible then
		return
	end
	entry.visible = visible
	local transparency = if visible then 0 else 1
	for _, part in ipairs(entry.parts) do
		part.Transparency = transparency
	end
end

local function destroyPet(petId: string)
	local entry = active[petId]
	if entry then
		entry.model:Destroy()
		active[petId] = nil
	end
end

local function destroyAll()
	for petId in pairs(active) do
		destroyPet(petId)
	end
end

local function petIdsEqual(a: { string }, b: { string }): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function ensurePetModel(petId: string, phase: number): ActivePet?
	if active[petId] then
		return active[petId]
	end
	local def = PetDatabase.get(petId)
	if not def then
		return nil
	end
	local display = PetModelKit.clonePetDisplay(def.modelName)
	if not display then
		return nil
	end
	display.model.Name = "DeepDigger_Pet_" .. petId
	display.model.Parent = workspace
	local entry: ActivePet = {
		petId = petId,
		model = display.model,
		parts = cacheModelParts(display.model),
		visible = true,
		position = nil,
		orientation = nil,
		phase = phase,
	}
	active[petId] = entry
	return entry
end

local function ensureLoop()
	if conn then
		return
	end
	conn = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, MAX_DT)
		local root = getRoot()
		local count = #currentPetIds
		if count == 0 then
			return
		end

		local clock = os.clock()
		local horizontalSpeed = 0
		if root then
			local vel = root.AssemblyLinearVelocity
			horizontalSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		end
		local posSmooth = POS_SMOOTH + math.min(horizontalSpeed * 0.06, 5)

		for i, petId in ipairs(currentPetIds) do
			local entry = active[petId]
			if not entry then
				continue
			end
			local model = entry.model
			if not root then
				setEntryVisible(entry, false)
				continue
			end
			setEntryVisible(entry, true)

			local bob = math.sin(clock * BOB_SPEED + entry.phase) * BOB_AMPLITUDE
			local targetPos = targetWorldPosition(root, i, count, bob)

			if not entry.position then
				entry.position = targetPos
			else
				entry.position = entry.position:Lerp(targetPos, expAlpha(posSmooth, dt))
			end

			local targetCF = buildOrientation(entry.position, root)
			if not entry.orientation then
				entry.orientation = targetCF
			else
				entry.orientation = entry.orientation:Lerp(targetCF, expAlpha(YAW_SMOOTH, dt))
			end

			model:PivotTo(entry.orientation)
		end
	end)
end

local function applyPetIds(petIds: { string })
	local normalized: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, petId in ipairs(petIds) do
		if typeof(petId) == "string" and petId ~= "" and not seen[petId] then
			seen[petId] = true
			table.insert(normalized, petId)
		end
	end

	if petIdsEqual(normalized, currentPetIds) then
		return
	end

	for petId in pairs(active) do
		local keep = false
		for _, id in ipairs(normalized) do
			if id == petId then
				keep = true
				break
			end
		end
		if not keep then
			destroyPet(petId)
		end
	end

	currentPetIds = normalized
	if #normalized == 0 then
		destroyAll()
		return
	end

	for i, petId in ipairs(normalized) do
		ensurePetModel(petId, i * 1.9)
	end
	ensureLoop()
end

function PetVisual.setEquippedPets(petIds: { string })
	applyPetIds(petIds)
end

function PetVisual.setEquipped(petId: string?)
	if petId and petId ~= "" then
		applyPetIds({ petId })
	else
		applyPetIds({})
	end
end

function PetVisual.destroy()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	destroyAll()
	currentPetIds = {}
end

return PetVisual
