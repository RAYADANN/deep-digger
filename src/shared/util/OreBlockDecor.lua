--!strict
-- Визуал блока руды — единый источник для OreReferenceBlocks_Restyled и MiningRenderer.

export type OreDecorDef = {
	id: string,
	color: Color3,
	rarity: string,
	weight: number?,
}

export type GlowCfg = {
	range: number,
	brightness: number,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("shared")
local Constants = require(shared.constants)
local OreFXPalette = require(shared.util.OreFXPalette)
local OreShellMeshes = require(shared.util.OreShellMeshes)

local OreBlockDecor = {}

OreBlockDecor.FILLER_WEIGHT = 300
OreBlockDecor.SHELL_BRIGHTEN = 0.12
OreBlockDecor.AMBIENT_FX_HOLDER = "AmbientFXHolder"
OreBlockDecor.AMBIENT_FX_FOLDER = "OreAmbientFX"

OreBlockDecor.FACE_NORMALS = {
	Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
	Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
	Vector3.new(0, 1, 0), Vector3.new(0, -1, 0),
} :: { Vector3 }

local SHELL_NEON: { [string]: boolean } = { legendary = true, mythic = true }

local FX_RARITY: { [string]: boolean } = {
	uncommon = true, rare = true, epic = true, legendary = true, mythic = true,
}

local GLOW_CFG: { [string]: GlowCfg } = {
	epic = { range = 8, brightness = 1.0 },
	legendary = { range = 10, brightness = 1.6 },
	mythic = { range = 13, brightness = 2.2 },
}

local function lum(c: Color3): number
	return c.R * 0.299 + c.G * 0.587 + c.B * 0.114
end

function OreBlockDecor.isFiller(def: OreDecorDef): boolean
	return (def.weight or 0) >= OreBlockDecor.FILLER_WEIGHT
end

function OreBlockDecor.rarityColor(rarity: string): Color3
	return Constants.RARITY_COLORS[rarity] or Constants.RARITY_COLORS.common
end

function OreBlockDecor.hostColor(def: OreDecorDef): Color3
	if OreBlockDecor.isFiller(def) then
		return def.color
	end
	return def.color:Lerp(Color3.new(0, 0, 0), 0.42)
end

function OreBlockDecor.shellColor(oreColor: Color3, rarity: string): Color3
	if lum(oreColor) < 0.14 then
		return OreBlockDecor.rarityColor(rarity):Lerp(Color3.new(1, 1, 1), 0.1)
	end
	return oreColor:Lerp(Color3.new(1, 1, 1), OreBlockDecor.SHELL_BRIGHTEN)
end

function OreBlockDecor.faceKey(normal: Vector3): string
	return string.format("%d_%d_%d", normal.X, normal.Y, normal.Z)
end

function OreBlockDecor.smoothSurfaces(part: BasePart)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.LeftSurface = Enum.SurfaceType.Smooth
	part.RightSurface = Enum.SurfaceType.Smooth
	part.FrontSurface = Enum.SurfaceType.Smooth
	part.BackSurface = Enum.SurfaceType.Smooth
end

function OreBlockDecor.applyHostStyle(part: BasePart, def: OreDecorDef)
	part.Color = OreBlockDecor.hostColor(def)
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0
	part.CastShadow = false
	OreBlockDecor.smoothSurfaces(part)
	part:SetAttribute("oreId", def.id)
end

function OreBlockDecor.createShellFace(
	blockPos: Vector3,
	normal: Vector3,
	shellColor: Color3,
	rarity: string,
	blockSize: number
): BasePart
	local shellMesh = OreShellMeshes.get(rarity, blockSize)
	local right = normal.Unit
	local up0 = if math.abs(right.Y) < 0.9 then Vector3.new(0, 1, 0) else Vector3.new(0, 0, 1)
	local up = (up0 - right * right:Dot(up0)).Unit
	local back = right:Cross(up)

	local host = Instance.new("Part")
	host.Name = "Face"
	host.Size = Vector3.new(1, 1, 1)
	host.Anchored = true
	host.CanCollide = false
	host.CanTouch = false
	host.CanQuery = false
	host.CastShadow = false
	host.Massless = true
	host.Reflectance = 0
	host.Material = if SHELL_NEON[rarity] then Enum.Material.Neon else Enum.Material.SmoothPlastic
	host.Color = shellColor
	host.CFrame = CFrame.fromMatrix(blockPos + right * (blockSize / 2 + 0.12), right, up, back)

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = shellMesh.meshId
	local s = shellMesh.scale
	mesh.Scale = Vector3.new(s, s, s)
	mesh.Parent = host

	host:SetAttribute("RestCF", host.CFrame)
	host:SetAttribute("FaceKey", OreBlockDecor.faceKey(normal))
	return host
end

function OreBlockDecor.stripCrystals(part: BasePart)
	for _, c in part:GetChildren() do
		if c.Name == "Crystal" and c:IsA("BasePart") then
			c:Destroy()
		end
	end
end

function OreBlockDecor.mountShell(part: BasePart, normals: { Vector3 }, def: OreDecorDef, blockSize: number): boolean
	local oldShell = part:FindFirstChild("OreShell")
	if oldShell then
		oldShell:Destroy()
	end
	if OreBlockDecor.isFiller(def) or #normals == 0 then
		return false
	end

	local shellColor = OreBlockDecor.shellColor(def.color, def.rarity)
	local folder = Instance.new("Folder")
	folder.Name = "OreShell"
	for _, normal in normals do
		OreBlockDecor.createShellFace(part.Position, normal, shellColor, def.rarity, blockSize).Parent = folder
	end
	if #folder:GetChildren() == 0 then
		folder:Destroy()
		return false
	end
	folder.Parent = part
	return true
end

function OreBlockDecor.shouldAmbientFX(rarity: string): boolean
	return FX_RARITY[rarity] == true
end

function OreBlockDecor.resolveGlow(rarity: string): GlowCfg?
	return GLOW_CFG[rarity]
end

function OreBlockDecor.fxPalette(def: OreDecorDef): OreFXPalette.Palette
	return OreFXPalette.fromColors(def.color, OreBlockDecor.rarityColor(def.rarity))
end

function OreBlockDecor.attachAmbientFX(part: BasePart, def: OreDecorDef, fxFolder: Instance?): boolean
	if not OreBlockDecor.shouldAmbientFX(def.rarity) then
		return false
	end
	local folder = fxFolder or ReplicatedStorage:FindFirstChild(OreBlockDecor.AMBIENT_FX_FOLDER)
	if not folder then
		return false
	end
	local tmpl = folder:FindFirstChild(def.rarity)
	if not tmpl or not tmpl:IsA("BasePart") then
		return false
	end

	local oldFx = part:FindFirstChild(OreBlockDecor.AMBIENT_FX_HOLDER)
	if oldFx then
		oldFx:Destroy()
	end

	local fx = tmpl:Clone()
	fx.Name = OreBlockDecor.AMBIENT_FX_HOLDER
	fx.CFrame = part.CFrame
	fx.Transparency = 1
	fx.CanCollide = false
	fx.CanTouch = false
	fx.CanQuery = false
	fx.CastShadow = false
	OreFXPalette.tintDescendants(fx, OreBlockDecor.fxPalette(def))
	fx.Parent = part
	return true
end

function OreBlockDecor.attachRarityGlow(part: BasePart, def: OreDecorDef): boolean
	local glowCfg = OreBlockDecor.resolveGlow(def.rarity)
	if not glowCfg then
		return false
	end

	local oldGlow = part:FindFirstChild("RarityGlow")
	if oldGlow then
		oldGlow:Destroy()
	end

	local glow = Instance.new("PointLight")
	glow.Name = "RarityGlow"
	glow.Color = OreBlockDecor.fxPalette(def).glow
	glow.Range = glowCfg.range
	glow.Brightness = glowCfg.brightness
	glow.Shadows = false
	glow.Parent = part
	return true
end

function OreBlockDecor.syncRarityGlow(part: BasePart, def: OreDecorDef)
	local glow = part:FindFirstChild("RarityGlow")
	local glowCfg = OreBlockDecor.resolveGlow(def.rarity)
	if not glow or not glow:IsA("PointLight") or not glowCfg then
		return
	end
	glow.Color = OreBlockDecor.fxPalette(def).glow
	glow.Range = glowCfg.range
	glow.Brightness = glowCfg.brightness
end

return OreBlockDecor
