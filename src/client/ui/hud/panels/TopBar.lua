--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local DepthBar = require(script.Parent.Parent.components.DepthBar)

local Children = Fusion.Children

local TopBar = {}

function TopBar.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
	return s:New("Frame")({
		Name = "TopBar",
		Size = UDim2.fromOffset(200, 56),
		Position = UDim2.new(1, -212, 0, 10),
		BackgroundTransparency = 1,
		[Children] = {
			DepthBar.create(s, state),
		},
	})
end

return TopBar
