--!strict
-- Переносимый корневой scope Fusion для HUD-деревьев.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local rootScope = Fusion.scoped(Fusion)

export type HudScope = typeof(rootScope:innerScope())

local ScopeFactory = {}

function ScopeFactory.new(): HudScope
    return rootScope:innerScope()
end

return ScopeFactory
