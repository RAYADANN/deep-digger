--!strict
-- 3D-лидерборд: SurfaceGui на модели в Workspace (как Hub/Leaderboard в HubDesign).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ui.hud.ScopeFactory)
local LeaderboardPanel = require(script.Parent.Parent.ui.hud.panels.LeaderboardPanel)
local HudStateModule = require(script.Parent.Parent.ui.hud.HudState)

local WorldLeaderboard = {}

local MODEL_NAMES = { "Leaderboard", "leaderboard", "LEADERBOARD", "leaderbord" }
local SCREEN_NAMES = { "Screen", "Display", "Board", "Canvas", "Gui" }
local PIXELS_PER_STUD = 44
local DECOR_GAP_STUDS = 0.2
local DEFAULT_TOP_INSET = 0.18

local _scope: ScopeFactory.HudScope? = nil
local _surfaceGui: SurfaceGui? = nil
local _wiredModel: Model? = nil

local function parseGuiFace(part: BasePart): Enum.NormalId
	local attr = part:GetAttribute("GuiFace")
	if typeof(attr) == "string" then
		local face = (Enum.NormalId :: any)[attr]
		if typeof(face) == "EnumItem" then
			return face
		end
	end
	return Enum.NormalId.Front
end

local CORNER_SIGNS = {
	{ -1, -1, -1 }, { -1, -1, 1 }, { -1, 1, -1 }, { -1, 1, 1 },
	{ 1, -1, -1 }, { 1, -1, 1 }, { 1, 1, -1 }, { 1, 1, 1 },
}

local function isThreeDTextPart(part: BasePart, screen: BasePart): boolean
	if part == screen then
		return false
	end
	local current: Instance? = part.Parent
	while current do
		if current.Name == "ThreeDTextObject" then
			return true
		end
		current = current.Parent
	end
	return false
end

local function readTopInsetAttr(screen: BasePart): number?
	local scale = screen:GetAttribute("GuiTopInset")
	if typeof(scale) == "number" and scale >= 0 and scale < 0.5 then
		return scale
	end
	local studs = screen:GetAttribute("GuiTopInsetStuds")
	if typeof(studs) == "number" and studs >= 0 then
		return math.clamp(studs / screen.Size.Y, 0, 0.5)
	end
	return nil
end

-- Доля высоты экрана, занятая 3D-надписью сверху; UI рисуем ниже.
local function computeTopInsetScale(screen: BasePart, model: Model): number
	local attrInset = readTopInsetAttr(screen)
	if attrInset then
		return attrInset
	end

	local halfY = screen.Size.Y * 0.5
	local decorBottomLocalY: number? = nil

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and isThreeDTextPart(desc, screen) then
			local half = desc.Size * 0.5
			for _, sign in CORNER_SIGNS do
				local corner = desc.CFrame * Vector3.new(half.X * sign[1], half.Y * sign[2], half.Z * sign[3])
				local localPos = screen.CFrame:PointToObjectSpace(corner)
				decorBottomLocalY = if decorBottomLocalY
					then math.min(decorBottomLocalY, localPos.Y)
					else localPos.Y
			end
		end
	end

	if not decorBottomLocalY then
		return DEFAULT_TOP_INSET
	end

	local insetStuds = (halfY - decorBottomLocalY) + DECOR_GAP_STUDS
	return math.clamp(insetStuds / screen.Size.Y, 0.1, 0.45)
end

local function nameLooksLikeLeaderboard(name: string): boolean
	local lower = string.lower(name)
	return string.find(lower, "leader", 1, true) ~= nil
end

local function findLeaderboardModel(): Model?
	for _, name in MODEL_NAMES do
		local inst = Workspace:FindFirstChild(name)
		if inst and inst:IsA("Model") then
			return inst
		end
	end
	local hub = Workspace:FindFirstChild("Hub")
	if hub then
		for _, name in MODEL_NAMES do
			local nested = hub:FindFirstChild(name)
			if nested and nested:IsA("Model") then
				return nested
			end
		end
	end
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and nameLooksLikeLeaderboard(child.Name) then
			return child
		end
	end
	return nil
end

local function findScreenPart(model: Model): BasePart?
	for _, name in SCREEN_NAMES do
		local inst = model:FindFirstChild(name)
		if inst and inst:IsA("BasePart") then
			return inst
		end
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	local best: BasePart? = nil
	local bestArea = 0
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			local s = desc.Size
			local area = s.X * s.Y + s.Y * s.Z + s.X * s.Z
			if area > bestArea then
				bestArea = area
				best = desc
			end
		end
	end
	return best
end

local function teardown()
	if _scope then
		Fusion.doCleanup(_scope)
		_scope = nil
	end
	if _surfaceGui then
		_surfaceGui:Destroy()
		_surfaceGui = nil
	end
	_wiredModel = nil
end

local function mountOn(screen: BasePart, model: Model)
	teardown()

	local scope = ScopeFactory.new()
	local panelState = {
		activeTab = scope:Value("leaderboard"),
		panelOpen = scope:Value(true),
	} :: HudStateModule.HudState

	local face = parseGuiFace(screen)
	local topInset = computeTopInsetScale(screen, model)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Adornee = screen
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ClipsDescendants = true
	gui.Parent = screen

	local viewport = Instance.new("Frame")
	viewport.Name = "LeaderboardViewport"
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Position = UDim2.fromScale(0, topInset)
	viewport.Size = UDim2.fromScale(1, 1 - topInset)
	viewport.ClipsDescendants = true
	viewport.Parent = gui

	local panel = LeaderboardPanel.create(scope, panelState)
	panel.Size = UDim2.fromScale(1, 1)
	panel.Visible = true
	panel.Parent = viewport

	_scope = scope
	_surfaceGui = gui
end

local _screenWarned = false

local function tryWire(): boolean
	local model = findLeaderboardModel()
	if not model then
		return false
	end
	if _wiredModel == model and _surfaceGui and _surfaceGui.Parent then
		return true
	end
	local screen = findScreenPart(model)
	if not screen then
		if not _screenWarned then
			_screenWarned = true
			warn("[WorldLeaderboard] нет Screen/Display у", model:GetFullName())
		end
		return false
	end
	_wiredModel = model
	mountOn(screen, model)
	return true
end

function WorldLeaderboard.init()
	if tryWire() then
		return
	end
	task.spawn(function()
		local deadline = os.clock() + 45
		while os.clock() < deadline do
			if tryWire() then
				return
			end
			task.wait(0.5)
		end
		warn("[WorldLeaderboard] модель Leaderboard/leaderbord не найдена в Workspace")
	end)
end

function WorldLeaderboard.refresh()
	tryWire()
end

return WorldLeaderboard
