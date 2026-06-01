--!strict
-- Единая логика слоёв и глубины (клиент + сервер).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

export type LayerDef = typeof(Constants.LAYERS[1])

local LayerUtil = {}

function LayerUtil.depthFromY(y: number): number
    return math.max(0, math.floor(-y / Constants.BLOCK_SIZE_STUDS))
end

function LayerUtil.getLayer(layerId: string): LayerDef?
    for _, layer in ipairs(Constants.LAYERS) do
        if layer.id == layerId then
            return layer
        end
    end
    return nil
end

function LayerUtil.layerFromDepth(depth: number): LayerDef
    for _, layer in ipairs(Constants.LAYERS) do
        if depth >= layer.depthStart and depth <= layer.depthEnd then
            return layer
        end
    end
    return Constants.LAYERS[#Constants.LAYERS]
end

function LayerUtil.layerIdFromDepth(depth: number): string
    return LayerUtil.layerFromDepth(depth).id
end

function LayerUtil.colorToPayload(color: Color3): { r: number, g: number, b: number }
    return {
        r = math.floor(color.R * 255 + 0.5),
        g = math.floor(color.G * 255 + 0.5),
        b = math.floor(color.B * 255 + 0.5),
    }
end

return LayerUtil
