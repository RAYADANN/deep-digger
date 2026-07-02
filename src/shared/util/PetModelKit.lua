--!strict
-- Резолв и подготовка 3D-моделей питомцев/яиц из ReplicatedStorage.PetKit
-- (сервер копирует Workspace.Pets / Workspace.Eggs при старте) или напрямую из Workspace.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

export type DisplayModel = {
	model: Model,
	pivot: BasePart,
}

local KIT_NAME = "PetKit"
local PETS_FOLDER = "Pets"
local EGGS_FOLDER = "Eggs"

local DISPLAY_HEIGHT_FOLLOW = 1.45
local DISPLAY_HEIGHT_REVEAL = 2.0
local DISPLAY_HEIGHT_CARD = 1.35
local DISPLAY_HEIGHT_WORLD = 1.55

local RunService = game:GetService("RunService")

local PetModelKit = {}

local _nameIndexByFolder: { [Instance]: { [string]: string } } = {}
local _archetypes: { [string]: Model } = {}
local _archetypeFolder: Folder? = nil

type SpinEntry = { model: Model, speed: number }
local _spinners: { SpinEntry } = {}
local _spinConn: RBXScriptConnection? = nil

local function archetypeFolder(): Folder
	if not _archetypeFolder then
		_archetypeFolder = Instance.new("Folder")
		_archetypeFolder.Name = "PetModelKitArchetypes"
		_archetypeFolder.Parent = ReplicatedStorage
	end
	return _archetypeFolder
end

local function archetypeKey(modelName: string, targetHeight: number, eggOnly: boolean): string
	return (if eggOnly then "e:" else "p:") .. modelName .. ":" .. string.format("%.2f", targetHeight)
end

local function unregisterSpin(model: Model)
	for i = #_spinners, 1, -1 do
		if _spinners[i].model == model then
			table.remove(_spinners, i)
		end
	end
	if #_spinners == 0 and _spinConn then
		_spinConn:Disconnect()
		_spinConn = nil
	end
end

local function registerSpin(model: Model, speed: number)
	unregisterSpin(model)
	table.insert(_spinners, { model = model, speed = speed })
	if _spinConn then
		return
	end
	_spinConn = RunService.Heartbeat:Connect(function(dt)
		for i = #_spinners, 1, -1 do
			local entry = _spinners[i]
			if not entry.model.Parent then
				table.remove(_spinners, i)
			else
				entry.model:PivotTo(entry.model:GetPivot() * CFrame.Angles(0, dt * entry.speed, 0))
			end
		end
		if #_spinners == 0 and _spinConn then
			_spinConn:Disconnect()
			_spinConn = nil
		end
	end)
end

local function normalizeName(name: string): string
	return name:lower():gsub("%s+", "")
end

local function kitRoot(): Folder?
	return ReplicatedStorage:FindFirstChild(KIT_NAME) :: Folder?
end

local function petsFolder(): Folder?
	local kit = kitRoot()
	if kit then
		local f = kit:FindFirstChild(PETS_FOLDER)
		if f and f:IsA("Folder") then
			return f
		end
	end
	local ws = Workspace:FindFirstChild(PETS_FOLDER)
	if ws and ws:IsA("Folder") then
		return ws
	end
	return nil
end

local function eggsFolder(): Folder?
	local kit = kitRoot()
	if kit then
		local f = kit:FindFirstChild(EGGS_FOLDER)
		if f and f:IsA("Folder") then
			return f
		end
	end
	local ws = Workspace:FindFirstChild(EGGS_FOLDER)
	if ws and ws:IsA("Folder") then
		return ws
	end
	return nil
end

local function resolveModelName(folder: Folder, modelName: string): string?
	local index = _nameIndexByFolder[folder]
	if not index then
		index = {}
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") then
				index[normalizeName(child.Name)] = child.Name
			end
		end
		_nameIndexByFolder[folder] = index
	end
	return index[normalizeName(modelName)]
end

local function findTemplate(folder: Folder?, modelName: string): Model?
	if not folder then
		return nil
	end
	local resolved = resolveModelName(folder, modelName)
	if not resolved then
		return nil
	end
	local inst = folder:FindFirstChild(resolved)
	if inst and inst:IsA("Model") then
		return inst
	end
	return nil
end

local function pickPivotPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local root = model:FindFirstChild("Root", true)
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
		return root
	end
	local egg = model:FindFirstChild("Egg", true)
	if egg and egg:IsA("BasePart") then
		model.PrimaryPart = egg
		return egg
	end
	local best: BasePart? = nil
	local bestVol = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local vol = d.Size.X * d.Size.Y * d.Size.Z
			if vol > bestVol then
				bestVol = vol
				best = d
			end
		end
	end
	if best then
		model.PrimaryPart = best
	end
	return best
end

local function stripWorldUi(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
end

local function prepareParts(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
end

local function modelScale(model: Model): number
	local ok, scale = pcall(function()
		return model:GetScale()
	end)
	if ok and typeof(scale) == "number" and scale > 0 then
		return scale
	end
	return 1
end

-- ScaleTo задаёт масштаб относительно канонического импорта (scale=1), не текущего bbox.
local function scaleToHeight(model: Model, targetHeight: number)
	local currentScale = modelScale(model)
	local _, size = model:GetBoundingBox()
	local currentHeight = math.max(size.Y, 0.05)
	local canonicalHeight = currentHeight / currentScale
	if canonicalHeight < 0.05 then
		return
	end

	local targetScale = math.clamp(targetHeight / canonicalHeight, 0.001, 10)
	if math.abs(targetScale - currentScale) < 0.001 then
		return
	end

	pcall(function()
		model:ScaleTo(targetScale)
	end)
end

local function displayExtents(display: DisplayModel): Vector3
	local _, size = display.model:GetBoundingBox()
	return size
end

-- Для hatch/UI — модель яйца без Key и подставки, с вложенным mesh и weld.
local function cloneEggForDisplay(template: Model, displayName: string): Model
	local clone = template:Clone()
	clone.Name = displayName

	local key = clone:FindFirstChild("Key")
	if key then
		key:Destroy()
	end
	for _, child in clone:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "Egg" then
			child:Destroy()
		end
	end

	stripWorldUi(clone)
	prepareParts(clone)
	return clone
end

local function buildDisplay(template: Model, displayName: string, targetHeight: number, eggOnly: boolean): DisplayModel?
	local clone = if eggOnly
		then cloneEggForDisplay(template, displayName)
		else template:Clone()
	if not eggOnly then
		clone.Name = displayName
	end
	stripWorldUi(clone)
	prepareParts(clone)
	scaleToHeight(clone, targetHeight)
	local pivot = pickPivotPart(clone)
	if not pivot then
		clone:Destroy()
		return nil
	end
	return { model = clone, pivot = pivot }
end

local function acquireDisplayModel(
	template: Model,
	displayName: string,
	targetHeight: number,
	eggOnly: boolean,
	modelName: string
): Model?
	local key = archetypeKey(modelName, targetHeight, eggOnly)
	local archetype = _archetypes[key]
	if not archetype then
		local built = buildDisplay(template, displayName, targetHeight, eggOnly)
		if not built then
			return nil
		end
		archetype = built.model
		archetype.Name = "Archetype_" .. key
		archetype.Parent = archetypeFolder()
		_archetypes[key] = archetype
	end
	return archetype:Clone()
end

local function cloneDisplay(
	template: Model?,
	displayName: string,
	targetHeight: number,
	eggOnly: boolean,
	modelName: string
): DisplayModel?
	if not template then
		return nil
	end
	local model = acquireDisplayModel(template, displayName, targetHeight, eggOnly, modelName)
	if not model then
		return nil
	end
	local pivot = pickPivotPart(model)
	if not pivot then
		model:Destroy()
		return nil
	end
	return { model = model, pivot = pivot }
end

function PetModelKit.invalidateCache()
	table.clear(_nameIndexByFolder)
	for _, archetype in _archetypes do
		archetype:Destroy()
	end
	table.clear(_archetypes)
	for i = #_spinners, 1, -1 do
		table.remove(_spinners, i)
	end
	if _spinConn then
		_spinConn:Disconnect()
		_spinConn = nil
	end
end

function PetModelKit.hasKit(): boolean
	return kitRoot() ~= nil or Workspace:FindFirstChild(PETS_FOLDER) ~= nil
end

function PetModelKit.findPetTemplate(modelName: string): Model?
	return findTemplate(petsFolder(), modelName)
end

function PetModelKit.findEggTemplate(modelName: string): Model?
	return findTemplate(eggsFolder(), modelName)
end

function PetModelKit.clonePetDisplay(modelName: string, targetHeight: number?): DisplayModel?
	return cloneDisplay(
		PetModelKit.findPetTemplate(modelName),
		"PetDisplay_" .. modelName,
		targetHeight or DISPLAY_HEIGHT_FOLLOW,
		false,
		modelName
	)
end

function PetModelKit.cloneWorldPetDisplay(modelName: string, targetHeight: number?): DisplayModel?
	return cloneDisplay(
		PetModelKit.findPetTemplate(modelName),
		"PetWorld_" .. modelName,
		targetHeight or DISPLAY_HEIGHT_WORLD,
		false,
		modelName
	)
end

function PetModelKit.cloneEggDisplay(modelName: string, targetHeight: number?): DisplayModel?
	return cloneDisplay(
		PetModelKit.findEggTemplate(modelName),
		"EggDisplay_" .. modelName,
		targetHeight or DISPLAY_HEIGHT_REVEAL,
		true,
		modelName
	)
end

function PetModelKit.displayHeights(): { follow: number, reveal: number, card: number, world: number }
	return {
		follow = DISPLAY_HEIGHT_FOLLOW,
		reveal = DISPLAY_HEIGHT_REVEAL,
		card = DISPLAY_HEIGHT_CARD,
		world = DISPLAY_HEIGHT_WORLD,
	}
end

export type ViewportMountOptions = {
	cameraDistance: number?,
	spinSpeed: number?,
	zIndex: number?,
}

function PetModelKit.mountInViewport(
	parent: GuiObject,
	display: DisplayModel,
	cameraDistance: number?,
	options: ViewportMountOptions?
): { viewport: ViewportFrame, world: WorldModel, camera: Camera, destroy: () -> () }
	local opts = options or {}
	local extents = displayExtents(display)
	local maxDim = math.max(extents.X, extents.Y, extents.Z, 0.5)
	local dist = opts.cameraDistance or cameraDistance or (maxDim * 2.4 + 1.2)
	local spinSpeed = opts.spinSpeed or 0
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(210, 210, 225)
	viewport.LightColor = Color3.fromRGB(255, 252, 245)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.3)
	viewport.ZIndex = opts.zIndex or math.max(parent.ZIndex + 1, 2)
	viewport.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local model = display.model
	model.Parent = world
	model:PivotTo(CFrame.new(0, 0, 0))

	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.new(Vector3.new(dist * 0.35, dist * 0.2, dist), Vector3.zero)
	cam.Parent = world
	viewport.CurrentCamera = cam

	if spinSpeed > 0 then
		registerSpin(model, spinSpeed)
	end

	local function destroy()
		unregisterSpin(model)
		if viewport.Parent then
			viewport:Destroy()
		end
	end

	return { viewport = viewport, world = world, camera = cam, destroy = destroy }
end

return PetModelKit
