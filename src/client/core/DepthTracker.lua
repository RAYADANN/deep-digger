--!strict
-- Считает глубину игрока по позиции HumanoidRootPart.
-- Один источник истины для глубины и текущего слоя на клиенте.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local Logger = require(ReplicatedStorage:WaitForChild("shared").util.Logger)

export type DepthInfo = {
    depth: number,
    layerId: string,
    layerName: string,
}

export type Listener = (info: DepthInfo) -> ()

local DepthTracker = {}
DepthTracker.__index = DepthTracker

local UPDATE_INTERVAL = 0.05

local function depthFromY(y: number): number
    return math.max(0, math.floor(-y / Constants.BLOCK_SIZE_STUDS))
end

local function layerFromDepth(depth: number): (string, string)
    for _, layer in ipairs(Constants.LAYERS) do
        if depth >= layer.depthStart and depth <= layer.depthEnd then
            return layer.id, layer.name
        end
    end
    return "void", "Void Layer"
end

function DepthTracker.new(player: Player)
    local self = setmetatable({}, DepthTracker)
    self._player = player
    self._log = Logger.new("DepthTracker")
    self._listener = nil :: Listener?
    self._lastDepth = -1
    self._connection = nil :: RBXScriptConnection?
    self._accumulator = 0
    return self
end

function DepthTracker:onChanged(listener: Listener)
    self._listener = listener
end

function DepthTracker:_emit(depth: number)
    if not self._listener then
        return
    end
    local layerId, layerName = layerFromDepth(depth)
    self._listener({
        depth = depth,
        layerId = layerId,
        layerName = layerName,
    })
end

function DepthTracker:_findRoot(): BasePart?
    local character = self._player.Character
    if not character then
        return nil
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root :: BasePart
    end
    if character:IsA("Model") and character.PrimaryPart then
        return character.PrimaryPart
    end
    return nil
end

function DepthTracker:peek(): number
    local root = self:_findRoot()
    if not root then
        return self._lastDepth
    end
    return depthFromY(root.Position.Y)
end

function DepthTracker:start()
    self:stop()
    self._accumulator = 0
    self._lastDepth = -1
    self._log:info("DepthTracker started")

    self._connection = RunService.Heartbeat:Connect(function(dt)
        self._accumulator += dt
        if self._accumulator < UPDATE_INTERVAL then
            return
        end
        self._accumulator = 0

        local root = self:_findRoot()
        if not root then
            return
        end
        local depth = depthFromY(root.Position.Y)
        if depth ~= self._lastDepth then
            self._lastDepth = depth
            self._log:debug("Depth changed:", depth, "from y=", root.Position.Y)
            self:_emit(depth)
        end
    end)
end

function DepthTracker:stop()
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
end

return DepthTracker
