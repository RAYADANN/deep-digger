--!strict
-- Машины яиц в Workspace.Eggs: авто-открытие EggShopModal по дистанции.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local Formatters = require(script.Parent.Parent.ui.hud.formatters)
local SoundManager = require(script.Parent.SoundManager)
local EggShopModal = require(script.Parent.Parent.ui.EggShopModal)

local EggMachines = {}

export type InitOptions = {
	getCoins: (() -> number)?,
}

type WiredMachine = {
	model: Model,
	eggId: string?,
	eggDef: any?,
	host: BasePart,
}

-- Дистанция до pivot/Key; гистерезис чтобы UI не мигал на границе.
local OPEN_DIST = 22
local CLOSE_DIST = 28

local _machines: { WiredMachine } = {}
local _proximityConn: RBXScriptConnection? = nil
local _activeProximityEggId: string? = nil
local _suppressedEggId: string? = nil
local _initialized = false
local _lastRetryRefresh = 0

local EGG_ID_BY_MODEL: { [string]: string } = {
	Basic = "basic",
	Desert = "desert",
	Candy = "candy",
	Ocean = "ocean",
	Lava = "lava",
	["Explosive Hydro"] = "explosive_hydro",
}

local _getCoins: () -> number = function()
	return 0
end

local function eggDefForModel(modelName: string): any?
	local eggId = EGG_ID_BY_MODEL[modelName]
	if not eggId then
		return nil
	end
	local eggs = (Constants.PETS or {}).eggs or {}
	return eggs[eggId]
end

local function findPromptHost(machine: Model): BasePart?
	local key = machine:FindFirstChild("Key", true)
	if key and key:IsA("BasePart") then
		return key
	end
	local primary = machine.PrimaryPart
	if primary then
		return primary
	end
	return machine:FindFirstChildWhichIsA("BasePart", true)
end

local function waitForHost(machine: Model, timeoutSec: number): BasePart?
	local deadline = os.clock() + timeoutSec
	while os.clock() < deadline do
		local host = findPromptHost(machine)
		if host then
			return host
		end
		if not machine.Parent then
			return nil
		end
		task.wait(0.2)
	end
	return findPromptHost(machine)
end

local function playerRoot(): BasePart?
	local player = Players.LocalPlayer
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function distanceToEntry(entry: WiredMachine): number
	local root = playerRoot()
	if not root then
		return math.huge
	end
	local playerPos = root.Position
	local dHost = (entry.host.Position - playerPos).Magnitude
	local dPivot = (entry.model:GetPivot().Position - playerPos).Magnitude
	return math.min(dHost, dPivot)
end

local function updateBillboards(machine: Model, eggDef: any?)
	local nameText = if eggDef then eggDef.name else machine.Name
	local priceText = if eggDef and eggDef.cost
		then Formatters.shortNumber(eggDef.cost) .. " монет"
		else "Скоро"
	for _, gui in ipairs(machine:GetDescendants()) do
		if gui:IsA("BillboardGui") then
			local nameLabel = gui:FindFirstChild("NameLabel", true)
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = nameText
			end
			local priceLabel = gui:FindFirstChild("PriceLabel", true)
			if priceLabel and priceLabel:IsA("TextLabel") then
				priceLabel.Text = priceText
			end
		end
	end
end

local function openShop(eggId: string, eggDef: any, playClickSound: boolean?)
	if playClickSound ~= false then
		SoundManager.play("ui_click")
	end
	EggShopModal.show({
		eggId = eggId,
		eggDef = eggDef,
		getCoins = _getCoins,
		onClose = function()
			if _activeProximityEggId == eggId then
				_suppressedEggId = eggId
			end
		end,
	})
end

local function openShopFromProximity(eggId: string, eggDef: any)
	if _suppressedEggId == eggId then
		return
	end
	if EggShopModal.isOpenForEgg(eggId) then
		_activeProximityEggId = eggId
		return
	end
	_activeProximityEggId = eggId
	local ok, err = pcall(function()
		openShop(eggId, eggDef, false)
	end)
	if not ok then
		warn("[EggMachines] не удалось открыть магазин яйца:", err)
		_activeProximityEggId = nil
	end
end

local function clearSuppressedIfLeftRange()
	if not _suppressedEggId then
		return
	end
	for _, entry in ipairs(_machines) do
		if entry.eggId == _suppressedEggId then
			if distanceToEntry(entry) > CLOSE_DIST then
				_suppressedEggId = nil
			end
			return
		end
	end
	_suppressedEggId = nil
end

local function findNearestEligible(): WiredMachine?
	local best: WiredMachine? = nil
	local bestDist = math.huge
	for _, entry in ipairs(_machines) do
		if entry.eggDef and entry.model.Parent and entry.host.Parent then
			local dist = distanceToEntry(entry)
			if dist < bestDist then
				bestDist = dist
				best = entry
			end
		end
	end
	if best and bestDist <= OPEN_DIST then
		return best
	end
	return nil
end

local function distanceToActiveEgg(): number
	if not _activeProximityEggId then
		return math.huge
	end
	for _, entry in ipairs(_machines) do
		if entry.eggId == _activeProximityEggId then
			return distanceToEntry(entry)
		end
	end
	return math.huge
end

local function registerMachine(machine: Model, host: BasePart, eggDef: any?)
	for _, entry in ipairs(_machines) do
		if entry.model == machine then
			return
		end
	end

	local legacyPrompt = host:FindFirstChild("DeepDigger_EggPrompt")
	if legacyPrompt then
		legacyPrompt:Destroy()
	end

	table.insert(_machines, {
		model = machine,
		eggId = eggDef and eggDef.id,
		eggDef = eggDef,
		host = host,
	})

	machine:SetAttribute("DeepDigger_EggWired", true)
end

local function wireMachine(machine: Model)
	for _, entry in ipairs(_machines) do
		if entry.model == machine then
			return
		end
	end

	local eggDef = eggDefForModel(machine.Name)
	updateBillboards(machine, eggDef)

	local host = findPromptHost(machine)
	if host then
		registerMachine(machine, host, eggDef)
		return
	end

	-- Модель яйца может догрузиться после Client:Init — ждём части в фоне.
	task.spawn(function()
		local resolvedHost = waitForHost(machine, 45)
		if not resolvedHost then
			warn("[EggMachines] нет host-части у", machine:GetFullName())
			return
		end
		updateBillboards(machine, eggDef)
		registerMachine(machine, resolvedHost, eggDef)
	end)
end

local function refreshMachines()
	local folder = Workspace:FindFirstChild("Eggs")
	if not folder or not folder:IsA("Folder") then
		return
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			wireMachine(child)
		end
	end
end

local function tickProximity()
	local folder = Workspace:FindFirstChild("Eggs")
	if folder and folder:IsA("Folder") then
		local modelCount = 0
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") then
				modelCount += 1
			end
		end
		if #_machines < modelCount and os.clock() - _lastRetryRefresh > 0.5 then
			_lastRetryRefresh = os.clock()
			refreshMachines()
		end
	end

	if #_machines == 0 then
		return
	end

	clearSuppressedIfLeftRange()

	local nearest = findNearestEligible()
	if nearest and nearest.eggId and nearest.eggDef then
		openShopFromProximity(nearest.eggId, nearest.eggDef)
		return
	end

	if _activeProximityEggId and distanceToActiveEgg() > CLOSE_DIST then
		_activeProximityEggId = nil
		_suppressedEggId = nil
		EggShopModal.close()
	end
end

local function startProximityLoop()
	if _proximityConn then
		return
	end
	_proximityConn = RunService.Heartbeat:Connect(tickProximity)
end

function EggMachines.init(opts: InitOptions?)
	if opts and opts.getCoins then
		_getCoins = opts.getCoins
	end

	refreshMachines()

	if not _initialized then
		_initialized = true
		local folder = Workspace:FindFirstChild("Eggs")
		if folder and folder:IsA("Folder") then
			folder.ChildAdded:Connect(function(child)
				if child:IsA("Model") then
					task.defer(function()
						wireMachine(child)
					end)
				end
			end)
		end
		startProximityLoop()
	end
end

return EggMachines
