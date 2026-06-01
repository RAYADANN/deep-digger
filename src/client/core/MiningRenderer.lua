--!strict
-- MiningRenderer.lua — 3D рендер шахты (поверхность + чанки)

local shared = game:GetService("ReplicatedStorage"):WaitForChild("shared")
local modules = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local UpgradeLogic = require(shared.util.UpgradeLogic)
local Net = require(modules.Net)

local MiningRenderer = {}
MiningRenderer.__index = MiningRenderer

local BS = Constants.BLOCK_SIZE_STUDS
local BSv = Vector3.new(BS, BS, BS)
local TweenService = game:GetService("TweenService")

local function formatHP(hp, maxHp)
    local function s(n)
        if n >= 1e6 then return string.format("%.1fM", n/1e6)
        elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
        else return tostring(n) end
    end
    return s(hp) .. " / " .. s(maxHp)
end

local ORE_C = {
    dirt = Color3.fromRGB(160, 120, 70), pebble = Color3.fromRGB(180, 180, 180),
    clay = Color3.fromRGB(210, 175, 130), coal = Color3.fromRGB(40, 40, 45),
    root = Color3.fromRGB(110, 65, 35), fossil = Color3.fromRGB(235, 210, 160),
    stone = Color3.fromRGB(145, 145, 150), copper = Color3.fromRGB(200, 120, 50),
    iron = Color3.fromRGB(195, 155, 105), silver = Color3.fromRGB(200, 210, 220),
    gold = Color3.fromRGB(255, 210, 50), sapphire = Color3.fromRGB(40, 110, 235),
    ruby = Color3.fromRGB(235, 35, 85),
}
local ORE_R = {
    dirt = "common", pebble = "common", clay = "common", coal = "uncommon",
    root = "rare", fossil = "rare", stone = "common", copper = "uncommon",
    iron = "uncommon", silver = "rare", gold = "rare", sapphire = "epic", ruby = "epic",
}
local RAR_C = {
    common = Color3.fromRGB(180,180,180), uncommon = Color3.fromRGB(100,200,100),
    rare = Color3.fromRGB(60,140,255), epic = Color3.fromRGB(180,60,220),
    legendary = Color3.fromRGB(255,160,0), mythic = Color3.fromRGB(255,50,50),
}

function MiningRenderer.new()
    local self = setmetatable({}, MiningRenderer)
    self._parts = {}; self._blockData = {}; self._parent = nil; self._enabled = false
    self._showRarity = false; self._showHPBar = true
    self._lastSwingAt = 0
    self._swingDelay = UpgradeLogic.swingDelaySeconds(1)
    self._log = Logger.new("MiningRenderer")
    return self
end

function MiningRenderer:setSwingDelay(speedLevel: number)
    self._swingDelay = UpgradeLogic.swingDelaySeconds(speedLevel)
end

function MiningRenderer:_folder()
    if self._parent and self._parent.Parent then return end
    local f = Instance.new("Folder"); f.Name = "DeepDigger_Mine"; f.Parent = workspace; self._parent = f
end

function MiningRenderer:_makeHPBar(hp, maxHp)
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.fromOffset(110, 16); gui.StudsOffset = Vector3.new(0, -2.8, 0)
    gui.AlwaysOnTop = true; gui.ClipsDescendants = true; gui.Enabled = false
    local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(5, 5, 15); bg.BackgroundTransparency = 0.25
    bg.BorderSizePixel = 2; bg.BorderColor3 = Color3.fromRGB(160, 170, 200)
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)
    local fill = Instance.new("Frame"); fill.Name = "Fill"
    fill.Size = UDim2.fromScale(math.max(0.02, hp / maxHp), 1)
    fill.BackgroundColor3 = Color3.fromRGB(55, 220, 55); fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)
    local txt = Instance.new("TextLabel"); txt.Size = UDim2.fromScale(1, 1)
    txt.BackgroundTransparency = 1; txt.Text = formatHP(hp, maxHp)
    txt.Font = Enum.Font.GothamBold; txt.TextSize = 11; txt.TextScaled = true
    txt.TextColor3 = Color3.new(1, 1, 1); txt.TextStrokeTransparency = 0.3; txt.TextStrokeColor3 = Color3.new(0, 0, 0)
    fill.Parent = bg; txt.Parent = bg; bg.Parent = gui
    return gui, fill, txt
end

function MiningRenderer:_updateHPBar(hp, maxHp, fill, txt)
    local pct = math.max(0.01, hp / maxHp)
    fill:TweenSize(UDim2.fromScale(pct, 1), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, 0.15, true)
    txt.Text = formatHP(hp, maxHp)
    if pct > 0.6 then fill.BackgroundColor3 = Color3.fromRGB(55, 220, 55)
    elseif pct > 0.3 then fill.BackgroundColor3 = Color3.fromRGB(240, 190, 35)
    else fill.BackgroundColor3 = Color3.fromRGB(240, 45, 45) end
end

function MiningRenderer:_createPart(x, z, y, oreId, hp, maxHp)
    local key = string.format("%d_%d_%d", x, z, y)
    local part = Instance.new("Part")
    part.Name = key; part.Size = BSv; part.Anchored = true
    part.CanCollide = true; part.CanTouch = false; part.CastShadow = true
    part.Material = Enum.Material.SmoothPlastic; part.Reflectance = 0.05
    part.BrickColor = BrickColor.new(ORE_C[oreId] or Color3.fromRGB(140, 140, 150))
    part.Parent = self._parent
    local px = x * BS; local pz = z * BS + 30
    local py = -(y * BS + BS / 2)
    part.Position = Vector3.new(px, py, pz)

    local det = Instance.new("ClickDetector")
    det.MaxActivationDistance = 200; det.Parent = part
    det.MouseClick:Connect(function(plr)
        if plr == game:GetService("Players").LocalPlayer then self:_onClick(key, x, z, y) end
    end)

    local hpGui, hpFill, hpTxt = self:_makeHPBar(hp, maxHp)
    hpGui.Parent = part

    det.MouseHoverEnter:Connect(function()
        if self._showHPBar then hpGui.Enabled = true end
        local light = Instance.new("PointLight")
        light.Name = "HoverLight"; light.Brightness = 1.2; light.Range = 6
        light.Color = Color3.fromRGB(255, 210, 80); light.Parent = part
        local sel = Instance.new("SelectionBox")
        sel.Name = "HoverSel"; sel.Adornee = part; sel.LineThickness = 0.04
        sel.Color3 = Color3.fromRGB(255, 230, 120); sel.SurfaceTransparency = 0.9; sel.Parent = part
    end)
    det.MouseHoverLeave:Connect(function()
        hpGui.Enabled = false
        local li = part:FindFirstChild("HoverLight"); if li then li:Destroy() end
        local sel = part:FindFirstChild("HoverSel"); if sel then sel:Destroy() end
    end)

    local rar = ORE_R[oreId] or "common"
    local tag = Instance.new("BillboardGui"); tag.Size = UDim2.fromOffset(50, 6)
    tag.StudsOffset = Vector3.new(0, 3.2, 0); tag.AlwaysOnTop = true
    tag.ClipsDescendants = false; tag.Enabled = self._showRarity
    local bar = Instance.new("Frame"); bar.Size = UDim2.fromScale(1, 1)
    bar.BackgroundColor3 = RAR_C[rar] or RAR_C.common; bar.BorderSizePixel = 0; bar.BackgroundTransparency = 0.1
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 3); bar.Parent = tag; tag.Parent = part

    if rar == "epic" or rar == "legendary" or rar == "mythic" then
        local sp = Instance.new("ParticleEmitter")
        sp.Texture = "rbxasset://textures/particles/sparkle_main.dds"
        sp.Color = ColorSequence.new(RAR_C[rar] or Color3.new(1, 1, 1))
        sp.Rate = 6 + (rar == "mythic" and 8 or rar == "legendary" and 4 or 2)
        sp.Lifetime = NumberRange.new(1.5, 3.0); sp.Speed = NumberRange.new(0.2, 0.8)
        sp.SpreadAngle = Vector2.new(40, 40); sp.VelocityInheritance = 0; sp.Enabled = true
        sp.Transparency = NumberSequence.new(0.3, 0.9); sp.Size = NumberSequence.new(0.4, 0)
        sp.Parent = part
    end

    self._parts[key] = part
    self._blockData[key] = { oreId = oreId, hp = hp, maxHp = maxHp, hpFill = hpFill, hpTxt = hpTxt, hpGui = hpGui, rarityTag = tag }
end

function MiningRenderer:_destroyPart(key)
    local p = self._parts[key]; if p then p:Destroy(); self._parts[key] = nil; self._blockData[key] = nil end
end

function MiningRenderer:_updateVisual(key, hp)
    local d = self._blockData[key]
    if not d then return end; d.hp = hp
    if d.hpFill and d.hpTxt then self:_updateHPBar(hp, d.maxHp, d.hpFill, d.hpTxt) end
end

function MiningRenderer:_hitParticles(key, oreId)
    local p = self._parts[key]; if not p then return end
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxasset://textures/particles/sparkle_main.dds"
    e.Color = ColorSequence.new(ORE_C[oreId] or Color3.fromRGB(200, 200, 200))
    e.Rate = 0; e.Lifetime = NumberRange.new(0.2, 0.5); e.Speed = NumberRange.new(3, 10)
    e.VelocityInheritance = 0; e.Enabled = false; e.Parent = p; e:Emit(8)
    task.delay(0.8, function() e:Destroy() end)
end

function MiningRenderer:_breakEffect(key, oreId)
    local p = self._parts[key]; if not p then return end
    local pos = p.Position
    local flash = Instance.new("Part"); flash.Size = BSv; flash.Anchored = true
    flash.CanCollide = false; flash.Transparency = 0; flash.Material = Enum.Material.Neon
    flash.Color = ORE_C[oreId] or Color3.new(1, 1, 1); flash.Position = pos; flash.Parent = self._parent
    TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Transparency = 1, Size = BSv * 1.5 }):Play()
    task.delay(0.35, function() flash:Destroy() end)
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxasset://textures/particles/sparkle_main.dds"
    e.Color = ColorSequence.new(ORE_C[oreId] or Color3.fromRGB(255, 255, 255))
    e.Rate = 0; e.Lifetime = NumberRange.new(0.3, 0.8); e.Speed = NumberRange.new(4, 14)
    e.VelocityInheritance = 0; e.Enabled = false; e.Parent = self._parent; e:Emit(20)
    task.delay(1.2, function() if e then e:Destroy() end end)
end

function MiningRenderer:_animateDestroy(key)
    local p = self._parts[key]; if not p then return end
    if p:GetAttribute("_destroying") then return end
    p:SetAttribute("_destroying", true)
    local d = self._blockData[key]; self:_breakEffect(key, d and d.oreId or "dirt")
    local cf = p.CFrame
    TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 0.8 }):Play()
    TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { CFrame = cf * CFrame.new(0, -BS/2, 0) }):Play()
    -- Гард: если за 0.3 с по тому же ключу появится НОВЫЙ part (replace
    -- через delta), не сносить его — сверяемся по конкретному инстансу.
    -- Старый part всё равно убираем, чтобы не оставить мусор в workspace.
    task.delay(0.3, function()
        if self._parts[key] == p then
            self:_destroyPart(key)
        elseif p.Parent then
            p:Destroy()
        end
    end)
end

function MiningRenderer:_dmgNumber(key, dmg, crit)
    local p = self._parts[key]; if not p then return end
    local gui = Instance.new("BillboardGui"); gui.Size = UDim2.fromOffset(120, 50)
    gui.StudsOffset = Vector3.new(0, 3.5, 0); gui.AlwaysOnTop = true; gui.ClipsDescendants = false
    local l = Instance.new("TextLabel"); l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1
    l.Text = tostring(dmg); l.Font = Enum.Font.GothamBlack
    l.TextSize = if crit then 42 else 30
    l.TextColor3 = if crit then Color3.fromRGB(255, 230, 50) else Color3.fromRGB(255, 255, 255)
    l.TextStrokeTransparency = 0.2; l.TextStrokeColor3 = Color3.new(0, 0, 0); l.Parent = gui; gui.Parent = p
    l.TextTransparency = 1
    TweenService:Create(l, TweenInfo.new(0.1, Enum.EasingStyle.Back), { TextTransparency = 0 }):Play()
    local st, conn = tick()
    conn = game:GetService("RunService").Heartbeat:Connect(function()
        local el = tick() - st; if el > 1.0 then conn:Disconnect(); gui:Destroy(); return end
        if el > 0.3 then l.TextTransparency = (el - 0.3) / 0.7 end
        gui.StudsOffset = Vector3.new(0, 3.5 + el * 4, 0)
    end)
end

function MiningRenderer:_onClick(key, x, z, y)
    local now = os.clock()
    if now - self._lastSwingAt < self._swingDelay * 0.95 then
        return
    end
    self._lastSwingAt = now

    local ok, res = pcall(function() return Net:Invoke("MineBlock", { { x = x, z = z, y = y } }) end)
    if not ok or not res then return end
    local r = res[1]; if not r or not r.success then return end
    if r.damage then
        local cached = self._blockData[key]
        local oreId = (r.oreDef and r.oreDef.id) or (cached and cached.oreId) or "dirt"
        self:_dmgNumber(key, r.damage, r.crit or false)
        self:_hitParticles(key, oreId)
    end
    -- Оптимистично обновляем HP-бар, чтобы цифра реагировала без ожидания
    -- delta. Сервер всё равно пришлёт то же значение через SyncBlocks —
    -- источник правды у блочного состояния один (сервер).
    if not r.mined and r.remainingHp then
        self:_updateVisual(key, r.remainingHp)
    end
end

local function parseKey(k: string): (number, number, number)
    local parts = string.split(k, "_")
    return tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0
end

--[[
    Полная замена видимых блоков. Используется один раз при заходе
    игрока (и теоретически после resetPlayer).
]]
function MiningRenderer:applySnapshot(blocks)
    self._log:debug("Snapshot:", #blocks, "blocks")
    for k, _ in pairs(self._parts) do self:_destroyPart(k) end
    for _, b in ipairs(blocks) do
        local x, z, y = parseKey(b.key)
        self:_createPart(x, z, y, b.oreId, b.hp, b.maxHp)
    end
end

--[[
    Точечный апдейт от сервера. Клиент верит серверу — никаких
    собственных diff-расчётов.
]]
function MiningRenderer:applyDelta(delta)
    if typeof(delta) ~= "table" then return end
    self._log:debug("Delta: +", #(delta.created or {}), "~", #(delta.updated or {}), "-", #(delta.removed or {}))
    for _, k in ipairs(delta.removed or {}) do
        if self._parts[k] then
            self:_animateDestroy(k)
        end
    end
    for _, b in ipairs(delta.created or {}) do
        if self._parts[b.key] then
            self:_destroyPart(b.key)
        end
        local x, z, y = parseKey(b.key)
        self:_createPart(x, z, y, b.oreId, b.hp, b.maxHp)
    end
    for _, u in ipairs(delta.updated or {}) do
        self:_updateVisual(u.key, u.hp)
    end
end

--[[
    Диспетчер SyncBlocks. Формат: { kind = "snapshot" | "delta", payload = ... }.
]]
function MiningRenderer:syncBlocks(message)
    if typeof(message) ~= "table" then return end
    if message.kind == "snapshot" then
        self:applySnapshot(message.payload or {})
    elseif message.kind == "delta" then
        self:applyDelta(message.payload or {})
    end
end

function MiningRenderer:toggleRarity()
    self._showRarity = not self._showRarity
    for _, d in pairs(self._blockData) do if d.rarityTag then d.rarityTag.Enabled = self._showRarity end end
    return self._showRarity
end
function MiningRenderer:toggleHPBar()
    self._showHPBar = not self._showHPBar
    for _, d in pairs(self._blockData) do if d.hpGui then d.hpGui.Enabled = self._showHPBar end end
    return self._showHPBar
end

function MiningRenderer:start()
    self._enabled = true; self:_folder()
    Net:Connect("SyncBlocks", function(blocks) if self._enabled then self:syncBlocks(blocks) end end)
    self._log:info("MiningRenderer started")
end

function MiningRenderer:stop()
    self._enabled = false
    for _, p in pairs(self._parts) do p:Destroy() end
    self._parts = {}; self._blockData = {}
    if self._parent then self._parent:Destroy(); self._parent = nil end
end

return MiningRenderer
