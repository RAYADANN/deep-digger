-- HubBuild.luau — одноразовая сборка фэнтези-хаба через MCP execute_luau (Edit mode).
-- Не часть игры. Запуск: execute_luau с этим кодом, datamodel_type = "Edit".

local Workspace = workspace
local Lighting = game:GetService("Lighting")

local old = Workspace:FindFirstChild("Hub")
if old then old:Destroy() end

local C = {
	stone = Color3.fromRGB(107, 110, 120),
	dark = Color3.fromRGB(62, 64, 73),
	path = Color3.fromRGB(135, 138, 147),
	gold = Color3.fromRGB(242, 178, 51),
	teal = Color3.fromRGB(79, 224, 208),
	purple = Color3.fromRGB(164, 91, 255),
	wood = Color3.fromRGB(106, 74, 46),
	banner = Color3.fromRGB(176, 48, 58),
	cream = Color3.fromRGB(244, 236, 216),
	moss = Color3.fromRGB(94, 123, 69),
	flame = Color3.fromRGB(255, 158, 61),
	trunk = Color3.fromRGB(90, 61, 39),
	leaf = Color3.fromRGB(111, 157, 84),
}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = props.collide ~= false
	p.CanTouch = false
	p.CastShadow = false
	p.Name = props.name or "Part"
	p.Size = props.size
	if props.cf then
		p.CFrame = props.cf
	else
		p.Position = props.pos or Vector3.zero
	end
	p.Color = props.color or C.stone
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Transparency = props.transparency or 0
	if props.shape then p.Shape = props.shape end
	if props.orient then p.Orientation = props.orient end
	p.Parent = props.parent
	return p
end

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function strip(parent, name, minX, maxX, minZ, maxZ, y, h, color, mat)
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	return part({
		parent = parent,
		name = name,
		size = Vector3.new(maxX - minX, h, maxZ - minZ),
		pos = Vector3.new(cx, y + h / 2, cz),
		color = color,
		material = mat,
	})
end

local function surfaceText(facePart, text, textColor)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.Parent = facePart
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.TextColor3 = textColor
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.Parent = sg
end

local hub = model("Hub", Workspace)
local plaza = folder("Plaza", hub)
local spawnF = folder("Spawn", hub)
local entrance = folder("MineEntrance", hub)
local shops = folder("Shops", hub)
local leaderboardF = folder("Leaderboard", hub)
local propsF = folder("Props", hub)
local environment = folder("Environment", hub)

-- === PLAZA (кольцо вокруг ямы, яму не накрываем) ===
local floorY, floorH = -0.5, 1
strip(plaza, "FloorSouth", -52, 52, -20, -3.75, floorY, floorH, C.stone, Enum.Material.Slate)
strip(plaza, "FloorNorth", -52, 52, 63.75, 80, floorY, floorH, C.stone, Enum.Material.Slate)
strip(plaza, "FloorWest", -52, -33.75, -3.75, 63.75, floorY, floorH, C.stone, Enum.Material.Slate)
strip(plaza, "FloorEast", 33.75, 52, -3.75, 63.75, floorY, floorH, C.stone, Enum.Material.Slate)

local borderY, borderH = 0.4, 0.8
strip(plaza, "BorderSouth", -33.75, 33.75, -3.75, -1.75, borderY, borderH, C.dark, Enum.Material.Slate)
strip(plaza, "BorderNorth", -33.75, 33.75, 61.75, 63.75, borderY, borderH, C.dark, Enum.Material.Slate)
strip(plaza, "BorderWest", -33.75, -31.75, -1.75, 61.75, borderY, borderH, C.dark, Enum.Material.Slate)
strip(plaza, "BorderEast", 31.75, 33.75, -1.75, 61.75, borderY, borderH, C.dark, Enum.Material.Slate)

strip(plaza, "GlowSouth", -33.75, 33.75, -3.75, -3.2, 0.85, 0.22, C.teal, Enum.Material.Neon)
strip(plaza, "GlowNorth", -33.75, 33.75, 63.2, 63.75, 0.85, 0.22, C.teal, Enum.Material.Neon)
strip(plaza, "GlowWest", -33.75, -33.2, -1.75, 61.75, 0.85, 0.22, C.teal, Enum.Material.Neon)
strip(plaza, "GlowEast", 33.2, 33.75, -1.75, 61.75, 0.85, 0.22, C.teal, Enum.Material.Neon)

strip(plaza, "Path", -4, 4, -12, -4, 0.05, 0.2, C.path, Enum.Material.Slate)

-- === SPAWN ===
local pedestal = part({
	parent = spawnF,
	name = "Pedestal",
	size = Vector3.new(22, 1, 14),
	pos = Vector3.new(0, 0.5, -13),
	color = C.dark,
	material = Enum.Material.Slate,
})
part({
	parent = spawnF,
	name = "GoldTrim",
	size = Vector3.new(22.4, 0.15, 14.4),
	pos = Vector3.new(0, 1.08, -13),
	color = C.gold,
	material = Enum.Material.Foil,
})

local spawn = Instance.new("SpawnLocation")
spawn.Name = "HubSpawn"
spawn.Size = Vector3.new(18, 0.5, 12)
spawn.Anchored = true
spawn.CanCollide = false
spawn.Neutral = true
spawn.Duration = 0
spawn.CFrame = CFrame.new(0, 1.25, -13)
spawn.Color = C.gold
spawn.Material = Enum.Material.Foil
spawn.Transparency = 0.85
spawn.Parent = spawnF

for _, x in ipairs({ -9, 9 }) do
	part({ parent = spawnF, name = "Column", size = Vector3.new(2, 9, 2), pos = Vector3.new(x, 4.5, -7), color = C.dark, material = Enum.Material.Slate })
	part({ parent = spawnF, name = "Capital", size = Vector3.new(2.6, 0.8, 2.6), pos = Vector3.new(x, 9.4, -7), color = C.gold, material = Enum.Material.Foil })
end

-- === MINE ENTRANCE (звезда сцены) ===
local arch = model("Arch", entrance)
part({ parent = arch, name = "PillarL", size = Vector3.new(2, 12, 2), pos = Vector3.new(-10, 6, -4), color = C.wood, material = Enum.Material.SmoothPlastic })
part({ parent = arch, name = "PillarR", size = Vector3.new(2, 12, 2), pos = Vector3.new(10, 6, -4), color = C.wood, material = Enum.Material.SmoothPlastic })
part({ parent = arch, name = "Beam", size = Vector3.new(22, 1.5, 2.5), pos = Vector3.new(0, 12.75, -4), color = C.wood, material = Enum.Material.SmoothPlastic })
part({ parent = arch, name = "BeamGold", size = Vector3.new(22, 0.3, 2.7), pos = Vector3.new(0, 13.6, -4), color = C.gold, material = Enum.Material.Foil })

for i, x in ipairs({ -6, -2, 2, 6 }) do
	part({
		parent = arch,
		name = "Rune" .. i,
		size = Vector3.new(1.2, 1.2, 0.2),
		pos = Vector3.new(x, 10.5, -2.8),
		color = (i % 2 == 0) and C.teal or C.purple,
		material = Enum.Material.Neon,
	})
end

local signBoard = part({ parent = arch, name = "SignBoard", size = Vector3.new(12, 3, 0.3), pos = Vector3.new(0, 14.5, -4), color = C.dark, material = Enum.Material.Slate })
surfaceText(signBoard, "⛏ ШАХТА ↓ КОПАЙ", C.gold)

local crystals = {
	{ -18, 2, 4, C.teal }, { -14, 0, 3, C.purple },
	{ 18, 2, 4, C.teal }, { 14, 0, 3, C.purple },
	{ -22, 8, 2.5, C.teal }, { 22, 8, 2.5, C.purple },
	{ -8, 6, 2, C.purple }, { 8, 6, 2, C.teal },
}
for i, c in ipairs(crystals) do
	part({
		parent = entrance,
		name = "Crystal" .. i,
		size = Vector3.new(1.5, c[3], 1.5),
		pos = Vector3.new(c[1], c[3] / 2 + 0.2, c[2]),
		color = c[4],
		material = Enum.Material.Neon,
		orient = Vector3.new(math.random(-12, 12), math.random(0, 360), math.random(-12, 12)),
	})
end

local particleHost = part({
	parent = entrance,
	name = "ParticleHost",
	size = Vector3.new(1, 1, 1),
	pos = Vector3.new(0, 8, 0),
	color = C.teal,
	transparency = 1,
	collide = false,
})
local pe = Instance.new("ParticleEmitter")
pe.Color = ColorSequence.new(C.teal)
pe.LightEmission = 1
pe.Size = NumberSequence.new(0.2, 0)
pe.Lifetime = NumberRange.new(1.5, 2.5)
pe.Rate = 8
pe.Speed = NumberRange.new(0.5, 1.5)
pe.SpreadAngle = Vector2.new(30, 30)
pe.Parent = particleHost

-- === SHOPS ===
local sellPad = part({
	parent = shops,
	name = "SellPad",
	size = Vector3.new(8, 0.3, 8),
	pos = Vector3.new(-22, 0.15, -10),
	color = C.teal,
	material = Enum.Material.Neon,
	transparency = 0.2,
})
local sellLight = Instance.new("PointLight")
sellLight.Color = C.teal
sellLight.Brightness = 1.2
sellLight.Range = 14
sellLight.Shadows = false
sellLight.Parent = sellPad
local sellSign = part({ parent = shops, name = "SellSign", size = Vector3.new(6, 1, 0.2), pos = Vector3.new(-22, 2.5, -10), color = C.dark, material = Enum.Material.Slate })
surfaceText(sellSign, "💰 ПРОДАТЬ", C.gold)

local shop = model("ShopStall", shops)
part({ parent = shop, name = "Floor", size = Vector3.new(10, 0.5, 8), pos = Vector3.new(-44, 0.25, 6), color = C.dark, material = Enum.Material.Slate })
for _, o in ipairs({ { -4, -3 }, { 4, -3 }, { -4, 3 }, { 4, 3 } }) do
	part({ parent = shop, name = "Post", size = Vector3.new(0.8, 7, 0.8), pos = Vector3.new(-44 + o[1], 3.5, 6 + o[2]), color = C.wood, material = Enum.Material.SmoothPlastic })
end
for i = 0, 4 do
	part({
		parent = shop,
		name = "Awning" .. i,
		size = Vector3.new(9, 0.3, 1.6),
		pos = Vector3.new(-44, 7.8, 6 - 3.2 + i * 1.6),
		color = (i % 2 == 0) and C.banner or C.cream,
		material = Enum.Material.SmoothPlastic,
	})
end
local shopSign = part({ parent = shop, name = "ShopSign", size = Vector3.new(6, 1.5, 0.2), pos = Vector3.new(-44, 8.8, 2.2), color = C.gold, material = Enum.Material.Foil })
surfaceText(shopSign, "🛒 МАГАЗИН", C.dark)

local eggStand = model("EggPedestal", shops)
part({ parent = eggStand, name = "Base", size = Vector3.new(6, 1.2, 6), pos = Vector3.new(44, 0.6, 6), color = C.dark, material = Enum.Material.Slate })
part({ parent = eggStand, name = "Ring", size = Vector3.new(5.2, 0.2, 5.2), pos = Vector3.new(44, 1.3, 6), color = C.teal, material = Enum.Material.Neon })
part({ parent = eggStand, name = "Egg", size = Vector3.new(2.8, 3.6, 2.8), pos = Vector3.new(44, 3.2, 6), color = C.gold, material = Enum.Material.Foil, shape = Enum.PartType.Ball })
local eggSign = part({ parent = eggStand, name = "EggSign", size = Vector3.new(5, 1, 0.2), pos = Vector3.new(44, 5.5, 6), color = C.gold, material = Enum.Material.Foil })
surfaceText(eggSign, "🥚 ЯЙЦА", C.dark)

-- === LEADERBOARD ===
local lb = model("LeaderboardBoard", leaderboardF)
part({ parent = lb, name = "Frame", size = Vector3.new(18, 10, 1), pos = Vector3.new(0, 5, 77), color = C.gold, material = Enum.Material.Foil })
part({ parent = lb, name = "Screen", size = Vector3.new(16, 8, 0.4), pos = Vector3.new(0, 5, 77.3), color = C.dark, material = Enum.Material.Slate })
local lbTitle = part({ parent = lb, name = "Title", size = Vector3.new(14, 1.2, 0.2), pos = Vector3.new(0, 9.2, 77.5), color = C.gold, material = Enum.Material.Foil })
surfaceText(lbTitle, "🏆 ЛИДЕРБОРД", C.dark)

-- === PROPS ===
local function makeCart(cx, cz, withOre)
	local cart = model("Minecart", propsF)
	part({ parent = cart, name = "Body", size = Vector3.new(4, 1.2, 3), pos = Vector3.new(cx, 0.6, cz), color = C.wood, material = Enum.Material.SmoothPlastic })
	part({ parent = cart, name = "Rim", size = Vector3.new(4.2, 0.2, 3.2), pos = Vector3.new(cx, 1.3, cz), color = C.gold, material = Enum.Material.Foil })
	for _, wx in ipairs({ -1.3, 1.3 }) do
		for _, wz in ipairs({ -1, 1 }) do
			part({
				parent = cart,
				name = "Wheel",
				size = Vector3.new(0.6, 0.6, 0.6),
				pos = Vector3.new(cx + wx, 0.3, cz + wz),
				color = C.dark,
				material = Enum.Material.Slate,
				shape = Enum.PartType.Cylinder,
				orient = Vector3.new(0, 0, 90),
			})
		end
	end
	if withOre then
		part({ parent = cart, name = "Ore", size = Vector3.new(2.5, 1, 2), pos = Vector3.new(cx, 1.5, cz), color = C.purple, material = Enum.Material.Neon })
	end
end
makeCart(-14, -8, true)
makeCart(14, -8, false)

for x = -18, 18, 3 do
	part({ parent = propsF, name = "Rail", size = Vector3.new(0.3, 0.2, 14), pos = Vector3.new(x, 0.1, -8), color = C.gold, material = Enum.Material.Foil })
end

local function makeTorch(x, z)
	local torch = model("Torch", propsF)
	part({ parent = torch, name = "Pole", size = Vector3.new(0.4, 5, 0.4), pos = Vector3.new(x, 2.5, z), color = C.wood, material = Enum.Material.SmoothPlastic })
	part({ parent = torch, name = "Bowl", size = Vector3.new(1, 0.5, 1), pos = Vector3.new(x, 5.2, z), color = C.gold, material = Enum.Material.Foil })
	local flame = part({ parent = torch, name = "Flame", size = Vector3.new(0.8, 1.2, 0.8), pos = Vector3.new(x, 5.9, z), color = C.flame, material = Enum.Material.Neon, transparency = 0.2 })
	local pl = Instance.new("PointLight")
	pl.Color = C.flame
	pl.Brightness = 1
	pl.Range = 12
	pl.Shadows = false
	pl.Parent = flame
	local fpe = Instance.new("ParticleEmitter")
	fpe.Color = ColorSequence.new(C.flame)
	fpe.Size = NumberSequence.new(0.4, 0)
	fpe.Lifetime = NumberRange.new(0.4, 0.8)
	fpe.Rate = 6
	fpe.Speed = NumberRange.new(0.5, 1)
	fpe.LightEmission = 1
	fpe.Parent = flame
end
for _, z in ipairs({ -11, -6 }) do
	makeTorch(-5, z)
	makeTorch(5, z)
end
makeTorch(-12, -4)
makeTorch(12, -4)

local function makeBanner(x, z)
	local b = model("Banner", propsF)
	part({ parent = b, name = "Pole", size = Vector3.new(0.3, 8, 0.3), pos = Vector3.new(x, 4, z), color = C.wood, material = Enum.Material.SmoothPlastic })
	part({ parent = b, name = "Flag", size = Vector3.new(3, 4, 0.15), pos = Vector3.new(x + 1.5, 6.5, z), color = C.banner, material = Enum.Material.SmoothPlastic })
	part({ parent = b, name = "Trim", size = Vector3.new(3.1, 0.2, 0.2), pos = Vector3.new(x + 1.5, 8.4, z), color = C.gold, material = Enum.Material.Foil })
end
makeBanner(-9, -5)
makeBanner(9, -5)
makeBanner(-42, 2)
makeBanner(42, 2)

for i, o in ipairs({ { 0, 0 }, { 2, 1 }, { -1.5, 2 } }) do
	part({
		parent = propsF,
		name = "Barrel" .. i,
		size = Vector3.new(1.8, 2.2, 1.8),
		pos = Vector3.new(-48 + o[1], 1.1, 8 + o[2]),
		color = C.wood,
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Cylinder,
		orient = Vector3.new(0, 0, 90),
	})
end
part({ parent = propsF, name = "Crate", size = Vector3.new(2, 2, 2), pos = Vector3.new(-40, 1, 10), color = C.wood, material = Enum.Material.SmoothPlastic })
part({ parent = propsF, name = "PickHandle", size = Vector3.new(0.3, 3.5, 0.3), pos = Vector3.new(-46, 1.8, 9), color = C.wood, material = Enum.Material.SmoothPlastic, collide = false })
part({ parent = propsF, name = "PickHead", size = Vector3.new(2.2, 0.4, 0.4), pos = Vector3.new(-46, 3.4, 9), color = C.gold, material = Enum.Material.Foil, collide = false })

-- === ENVIRONMENT ===
local function makeRock(x, z, sx, sy, sz)
	part({
		parent = environment,
		name = "Rock",
		size = Vector3.new(sx, sy, sz),
		pos = Vector3.new(x, sy / 2 - 0.2, z),
		color = C.dark,
		material = Enum.Material.Slate,
		orient = Vector3.new(math.random(-8, 8), math.random(0, 360), math.random(-8, 8)),
	})
end
for _, r in ipairs({
	{ -54, -18, 8, 5, 6 }, { 54, -18, 7, 4, 5 },
	{ -54, 75, 9, 6, 7 }, { 54, 75, 8, 5, 6 },
	{ -54, 30, 6, 8, 5 }, { 54, 30, 7, 9, 6 },
	{ 0, 82, 12, 4, 8 }, { -30, 82, 8, 5, 6 }, { 30, 82, 8, 5, 6 },
}) do
	makeRock(r[1], r[2], r[3], r[4], r[5])
end

local function makeHill(x, z, sx, sy, sz)
	part({ parent = environment, name = "Hill", size = Vector3.new(sx, sy, sz), pos = Vector3.new(x, sy / 2 - 1, z), color = C.moss, material = Enum.Material.Grass })
end
makeHill(-58, 30, 14, 6, 20)
makeHill(58, 30, 14, 6, 20)
makeHill(0, 88, 30, 5, 10)
makeHill(-35, 88, 16, 4, 8)
makeHill(35, 88, 16, 4, 8)

local function makeTree(x, z)
	local tree = model("Tree", environment)
	part({ parent = tree, name = "Trunk", size = Vector3.new(1.2, 5, 1.2), pos = Vector3.new(x, 2.5, z), color = C.trunk, material = Enum.Material.SmoothPlastic })
	part({ parent = tree, name = "Leaves1", size = Vector3.new(5, 3, 5), pos = Vector3.new(x, 6.5, z), color = C.moss, material = Enum.Material.Grass })
	part({ parent = tree, name = "Leaves2", size = Vector3.new(3.5, 2.5, 3.5), pos = Vector3.new(x, 8.5, z), color = C.leaf, material = Enum.Material.Grass })
end
for _, t in ipairs({ { -56, -10 }, { -56, 20 }, { -56, 50 }, { -56, 72 }, { 56, -10 }, { 56, 20 }, { 56, 50 }, { 56, 72 }, { -20, 86 }, { 20, 86 } }) do
	makeTree(t[1], t[2])
end

for i, spot in ipairs({ { -16, 1 }, { 16, 1 }, { -8, -2 }, { 8, -2 } }) do
	part({ parent = environment, name = "Moss" .. i, size = Vector3.new(3, 0.15, 3), pos = Vector3.new(spot[1], 0.08, spot[2]), color = C.moss, material = Enum.Material.Grass })
end

hub.PrimaryPart = pedestal

if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.3
	atmo.Haze = 1
	atmo.Color = Color3.fromRGB(180, 175, 165)
	atmo.Decay = Color3.fromRGB(120, 115, 105)
	atmo.Parent = Lighting
end

return string.format("Hub built OK — %d descendants", #hub:GetDescendants())
