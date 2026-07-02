--!strict
-- Дистанция копания и мировые координаты блока сетки.

local Constants = require(script.Parent.Parent.constants)

local MiningReach = {}

function MiningReach.maxStuds(): number
	return Constants.MAX_MINE_REACH_BLOCKS * Constants.BLOCK_SIZE_STUDS
end

function MiningReach.slackStuds(): number
	return Constants.BLOCK_SIZE_STUDS * 0.5
end

function MiningReach.blockCenter(origin: Vector3, x: number, z: number, y: number): Vector3
	local bs = Constants.BLOCK_SIZE_STUDS
	return Vector3.new(
		origin.X + x * bs,
		origin.Y - (y * bs + bs / 2),
		origin.Z + z * bs
	)
end

function MiningReach.resolveOrigin(ws: Workspace): Vector3
	local marker = ws:FindFirstChild("MineZoneMarker")
	if marker then
		local volume = marker:FindFirstChild("Volume")
		if volume and volume:IsA("BasePart") then
			return volume.Position + Vector3.new(0, volume.Size.Y / 2, 0)
		end
	end
	local respawn = ws:FindFirstChild("MineRespawn")
	if respawn and respawn:IsA("BasePart") then
		return respawn.Position
	end
	return Vector3.new(0, 0, 30)
end

function MiningReach.surfaceTopY(origin: Vector3): number
	return origin.Y
end

-- Обратное к blockCenter: ближайшая колонка сетки (x, z) по мировой позиции.
function MiningReach.worldToColumn(origin: Vector3, worldPos: Vector3): (number, number)
	local bs = Constants.BLOCK_SIZE_STUDS
	local rel = worldPos - origin
	local gx = math.round(rel.X / bs)
	local gz = math.round(rel.Z / bs)
	return gx, gz
end

function MiningReach.isWithinReach(from: Vector3, blockCenter: Vector3): boolean
	return (blockCenter - from).Magnitude <= MiningReach.maxStuds() + MiningReach.slackStuds()
end

return MiningReach
