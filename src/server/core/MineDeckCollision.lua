--!strict
-- Провал через прокопанные ячейки surface (y=0) под общим полом Workspace.Union.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MiningReach = require(game:GetService("ReplicatedStorage"):WaitForChild("shared").util.MiningReach)
local MineZoneWorkspace = require(game:GetService("ReplicatedStorage"):WaitForChild("shared").util.MineZoneWorkspace)

local DECK_GROUP = "MineDeck"
local PASS_GROUP = "MinePass"
local DEFAULT_GROUP = "Default"

local MineDeckCollision = {}

export type HasSurfaceBlockFn = (userId: number, gx: number, gz: number) -> boolean

local _hasSurfaceBlock: HasSurfaceBlockFn = function()
	return true
end

local function ensureGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(DECK_GROUP)
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PASS_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(PASS_GROUP, DECK_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(DEFAULT_GROUP, DECK_GROUP, true)
end

local function applyPartGroup(part: BasePart, groupName: string)
	if part.CollisionGroup ~= groupName then
		part.CollisionGroup = groupName
	end
end

local function setCharacterGroup(character: Model, groupName: string)
	for _, desc in character:GetDescendants() do
		if desc:IsA("BasePart") then
			applyPartGroup(desc :: BasePart, groupName)
		end
	end
end

local function tagDeckParts(deckParts: { BasePart })
	for _, part in deckParts do
		if part.Parent then
			applyPartGroup(part, DECK_GROUP)
		end
	end
end

local function shouldPassThrough(hrp: BasePart, userId: number): boolean
	local origin = MiningReach.resolveOrigin(Workspace)
	local surfaceTop = MiningReach.surfaceTopY(origin)
	local y = hrp.Position.Y
	if y < surfaceTop - 3 or y > surfaceTop + 14 then
		return false
	end
	local gx, gz = MiningReach.worldToColumn(origin, hrp.Position)
	if not MineZoneWorkspace.columnInSurfaceGrid(gx, gz) then
		return false
	end
	return not _hasSurfaceBlock(userId, gx, gz)
end

function MineDeckCollision.applySanitize()
	ensureGroups()
	local result = MineZoneWorkspace.sanitize(Workspace)
	tagDeckParts(result.deckParts)
	return result
end

function MineDeckCollision.start(hasSurfaceBlock: HasSurfaceBlockFn)
	_hasSurfaceBlock = hasSurfaceBlock
	ensureGroups()
	MineDeckCollision.applySanitize()

	task.defer(function()
		MineDeckCollision.applySanitize()
	end)

	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not character or not hrp or not hrp:IsA("BasePart") then
				continue
			end
			local pass = shouldPassThrough(hrp :: BasePart, player.UserId)
			setCharacterGroup(character, if pass then PASS_GROUP else DEFAULT_GROUP)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			character.DescendantAdded:Connect(function(desc)
				if desc:IsA("BasePart") then
					task.defer(function()
						local hrp = character:FindFirstChild("HumanoidRootPart")
						if hrp and hrp:IsA("BasePart") then
							local pass = shouldPassThrough(hrp :: BasePart, player.UserId)
							applyPartGroup(desc :: BasePart, if pass then PASS_GROUP else DEFAULT_GROUP)
						end
					end)
				end
			end)
		end)
	end)
end

return MineDeckCollision
