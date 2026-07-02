--!strict
-- Зоны хаба Workspace.SELL / UPGRADE: Billboard + авто-действие при входе.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local theme = require(script.Parent.Parent.ui.hud.theme)
local ZoneBillboard = require(script.Parent.Parent.ui.world.ZoneBillboard)

local HubZones = {}

export type InitOptions = {
	onSell: () -> (),
	onUpgrades: () -> (),
	onLeaveUpgrades: () -> (),
	isUpgradesOpen: () -> boolean,
}

type ZoneKind = "sell" | "upgrade"

type ZoneDef = {
	kind: ZoneKind,
	modelName: string,
	accent: Color3,
	iconKey: string,
	title: string,
	onActivate: () -> (),
}

type WiredZone = {
	kind: ZoneKind,
	model: Model,
	host: BasePart,
	billboard: ZoneBillboard.Handle,
}

local ENTER_RADIUS = 17
local EXIT_RADIUS = 22

local _zones: { WiredZone } = {}
local _wiredByName: { [string]: WiredZone } = {}
local _heartbeatConn: RBXScriptConnection? = nil
local _initialized = false

local _inSellZone = false
local _inUpgradeZone = false
local _suppressUpgrade = false
local _upgradeWasOpen = false

local _opts: InitOptions? = nil
local _missingHostWarned: { [string]: boolean } = {}

local ZONE_DEFS: { ZoneDef } = {
	{
		kind = "sell",
		modelName = "SELL",
		accent = theme.TAB_ACCENTS.sell,
		iconKey = "coin",
		title = "Продажа",
		onActivate = function() end,
	},
	{
		kind = "upgrade",
		modelName = "UPGRADE",
		accent = theme.TAB_ACCENTS.upgrades,
		iconKey = "tab_upgrades",
		title = "Улучшения",
		onActivate = function() end,
	},
}

local function findHost(model: Model): BasePart?
	local core = model:FindFirstChild("LightCore")
	if core and core:IsA("BasePart") then
		return core
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function findBillboard(model: Model): BillboardGui?
	local direct = model:FindFirstChild("BillboardGui")
	if direct and direct:IsA("BillboardGui") then
		return direct
	end
	return model:FindFirstChildWhichIsA("BillboardGui", true)
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

local function distanceToZone(entry: WiredZone): number
	local root = playerRoot()
	if not root then
		return math.huge
	end
	local pos = root.Position
	local dHost = (entry.host.Position - pos).Magnitude
	local dPivot = (entry.model:GetPivot().Position - pos).Magnitude
	return math.min(dHost, dPivot)
end

local function wireZone(def: ZoneDef): WiredZone?
	local model = Workspace:FindFirstChild(def.modelName)
	if not model or not model:IsA("Model") then
		return nil
	end
	local host = findHost(model)
	if not host then
		if not _missingHostWarned[def.modelName] then
			_missingHostWarned[def.modelName] = true
			warn("[HubZones] нет host-части у", def.modelName)
		end
		return nil
	end
	local billboardGui = findBillboard(model)
	if not billboardGui then
		billboardGui = Instance.new("BillboardGui")
		billboardGui.Name = "BillboardGui"
		billboardGui.Parent = model
	end

	local handle = ZoneBillboard.apply(billboardGui, host, {
		accent = def.accent,
		iconKey = def.iconKey,
		title = def.title,
	})

	local oldPrompt = host:FindFirstChild("HubZonePrompt")
	if oldPrompt then
		oldPrompt:Destroy()
	end

	return {
		kind = def.kind,
		model = model,
		host = host,
		billboard = handle,
	}
end

local function handleSellZone(entry: WiredZone, dist: number)
	local inside = dist <= ENTER_RADIUS
	local outside = dist > EXIT_RADIUS

	if inside and not _inSellZone then
		_inSellZone = true
		local opts = _opts
		if opts then
			opts.onSell()
		end
	elseif outside then
		_inSellZone = false
	end
end

local function handleUpgradeZone(entry: WiredZone, dist: number)
	local opts = _opts
	if not opts then
		return
	end

	local inside = dist <= ENTER_RADIUS
	local outside = dist > EXIT_RADIUS
	local upgradesOpen = opts.isUpgradesOpen()

	if _inUpgradeZone and _upgradeWasOpen and not upgradesOpen then
		_suppressUpgrade = true
	end
	_upgradeWasOpen = upgradesOpen

	if inside then
		entry.billboard.setInZone(true)
		if not _inUpgradeZone then
			_inUpgradeZone = true
			if not _suppressUpgrade then
				opts.onUpgrades()
			end
		end
	elseif outside then
		entry.billboard.setInZone(false)
		if _inUpgradeZone then
			_inUpgradeZone = false
			_suppressUpgrade = false
			_upgradeWasOpen = false
			if opts.isUpgradesOpen() then
				opts.onLeaveUpgrades()
			end
		end
	else
		entry.billboard.setInZone(true)
	end
end

local function refreshProximity()
	for _, entry in _zones do
		local dist = distanceToZone(entry)
		if entry.kind == "sell" then
			entry.billboard.setInZone(dist <= ENTER_RADIUS)
			handleSellZone(entry, dist)
		else
			handleUpgradeZone(entry, dist)
		end
	end
end

local function startHeartbeat()
	if _heartbeatConn then
		return
	end
	_heartbeatConn = RunService.Heartbeat:Connect(refreshProximity)
end

local function wireAll(opts: InitOptions)
	_opts = opts
	ZONE_DEFS[1].onActivate = opts.onSell
	ZONE_DEFS[2].onActivate = opts.onUpgrades

	for _, def in ZONE_DEFS do
		if _wiredByName[def.modelName] then
			continue
		end
		local wired = wireZone(def)
		if wired then
			_wiredByName[def.modelName] = wired
			table.insert(_zones, wired)
		end
	end
	if #_zones > 0 then
		startHeartbeat()
		refreshProximity()
	end
end

function HubZones.init(opts: InitOptions)
	wireAll(opts)

	if _initialized then
		return
	end
	_initialized = true

	task.spawn(function()
		local deadline = os.clock() + 30
		while os.clock() < deadline and #_zones < #ZONE_DEFS do
			task.wait(0.5)
			wireAll(opts)
		end
	end)
end

function HubZones.refresh()
	_inSellZone = false
	_inUpgradeZone = false
	_suppressUpgrade = false
	_upgradeWasOpen = false
	refreshProximity()
end

return HubZones
