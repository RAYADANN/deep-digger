--!strict
-- Мягкая дорожка-указатель на земле + пин цели (без луча).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local FOLDER_NAME = "DeepDigger_TutorialPath"
local MARKER_SPACING = 8.5
local MAX_MARKERS = 9
local AHEAD_STUDS = 68
local ARRIVE_DIST = 14
local MARKER_SIZE = Vector3.new(4.2, 0.02, 6.2)

export type Handle = {
	destroy: (self: Handle) -> (),
	setTarget: (self: Handle, target: Vector3 | BasePart) -> (),
}

local TutorialPathGuide = {}

local function markerTexture(): string
	local tex = UiAssets.image("tutorial_path_marker")
	if tex ~= "" then
		return tex
	end
	return UiAssets.image("icon_tutorial_arrow")
end

local function goalTexture(): string
	local tex = UiAssets.image("tutorial_goal_pin")
	if tex ~= "" then
		return tex
	end
	return UiAssets.image("icon_tutorial_arrow")
end

local function resolveTarget(target: Vector3 | BasePart): Vector3
	if typeof(target) == "Instance" and target:IsA("BasePart") then
		return target.Position
	end
	return target :: Vector3
end

local function groundAt(x: number, z: number, fallbackY: number, ignore: { Instance }): Vector3
	local origin = Vector3.new(x, fallbackY + 16, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(origin, Vector3.new(0, -52, 0), params)
	if hit then
		return hit.Position + Vector3.new(0, 0.12, 0)
	end
	return Vector3.new(x, fallbackY, z)
end

local function makeMarker(index: number, folder: Folder): Part
	local part = Instance.new("Part")
	part.Name = "Marker_" .. index
	part.Size = MARKER_SIZE
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 1
	part.Parent = folder

	local decal = Instance.new("Decal")
	decal.Name = "Top"
	decal.Face = Enum.NormalId.Top
	decal.Texture = markerTexture()
	decal.Transparency = 1
	decal.Parent = part

	return part
end

function TutorialPathGuide.follow(target: Vector3 | BasePart): Handle
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	local ignoreList: { Instance } = { folder }
	local markers: { Part } = {}
	for i = 1, MAX_MARKERS do
		markers[i] = makeMarker(i, folder)
	end

	local goalAnchor = Instance.new("Part")
	goalAnchor.Name = "GoalAnchor"
	goalAnchor.Anchored = true
	goalAnchor.CanCollide = false
	goalAnchor.CanQuery = false
	goalAnchor.CanTouch = false
	goalAnchor.Transparency = 1
	goalAnchor.Size = Vector3.new(1, 1, 1)
	goalAnchor.Parent = folder
	table.insert(ignoreList, goalAnchor)

	local goalBillboard = Instance.new("BillboardGui")
	goalBillboard.Name = "GoalPin"
	goalBillboard.Size = UDim2.fromOffset(120, 120)
	goalBillboard.StudsOffset = Vector3.new(0, 4.5, 0)
	goalBillboard.AlwaysOnTop = true
	goalBillboard.LightInfluence = 0
	goalBillboard.MaxDistance = 700
	goalBillboard.Adornee = goalAnchor
	goalBillboard.Parent = folder

	local goalImage = Instance.new("ImageLabel")
	goalImage.Size = UDim2.fromScale(1, 1)
	goalImage.BackgroundTransparency = 1
	goalImage.Image = goalTexture()
	goalImage.ScaleType = Enum.ScaleType.Fit
	goalImage.Parent = goalBillboard

	local pulseT = 0
	local destroyed = false
	local conn: RBXScriptConnection

	local function hideMarker(part: Part)
		part.Transparency = 1
		local decal = part:FindFirstChild("Top") :: Decal?
		if decal then
			decal.Transparency = 1
		end
	end

	local function showMarker(part: Part, cf: CFrame, alpha: number, pulse: number)
		part.CFrame = cf
		part.Transparency = 1
		local decal = part:FindFirstChild("Top") :: Decal?
		if decal and decal.Texture ~= "" then
			local fade = math.clamp(alpha + pulse * 0.08, 0.02, 0.55)
			decal.Transparency = fade
		end
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		if destroyed then
			return
		end

		pulseT += dt
		local pulse = (math.sin(pulseT * 2.8) + 1) * 0.5

		local player = Players.LocalPlayer
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			for _, part in markers do
				hideMarker(part)
			end
			goalBillboard.Enabled = false
			return
		end

		local goalPos = resolveTarget(target)
		local goalGround = groundAt(goalPos.X, goalPos.Z, goalPos.Y, ignoreList)
		goalAnchor.CFrame = CFrame.new(goalGround)
		goalBillboard.Enabled = true
		goalImage.ImageTransparency = 0.05 + pulse * 0.12

		local from = root.Position
		local flatDelta = Vector3.new(goalPos.X - from.X, 0, goalPos.Z - from.Z)
		local dist = flatDelta.Magnitude
		if dist < ARRIVE_DIST then
			for _, part in markers do
				hideMarker(part)
			end
			return
		end

		local dir = flatDelta.Unit
		local used = 0
		local step = 0
		local startOffset = 6
		local endOffset = math.min(dist - 10, AHEAD_STUDS)
		while used < MAX_MARKERS do
			local along = startOffset + step * MARKER_SPACING
			if along > endOffset then
				break
			end
			local sample = from + dir * along
			local ground = groundAt(sample.X, sample.Z, from.Y, ignoreList)
			local look = CFrame.new(ground) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0)
			local fade = 0.08 + (along / math.max(endOffset, 1)) * 0.22
			showMarker(markers[used + 1], look, fade, pulse)
			used += 1
			step += 1
		end
		for i = used + 1, MAX_MARKERS do
			hideMarker(markers[i])
		end
	end)

	return {
		destroy = function(_self: Handle)
			if destroyed then
				return
			end
			destroyed = true
			conn:Disconnect()
			folder:Destroy()
		end,
		setTarget = function(_self: Handle, newTarget: Vector3 | BasePart)
			target = newTarget
		end,
	}
end

return TutorialPathGuide
