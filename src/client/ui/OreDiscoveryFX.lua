--!strict
-- OreDiscoveryFX.lua — Phase 13 (Ore Discovery Index).
--
-- Качественная анимация «НОВАЯ НАХОДКА» при первой добыче руды, которую игрок
-- ещё не открывал (server шлёт notify kind="ore_discovered"). Это момент-награда
-- кор-механики коллекционирования — должен ощущаться как событие, не как тост.
--
-- Дизайн (как в проф. играх — gacha/collection reveal):
--   1) Радиальная аура цвета редкости + 2–3 shockwave-кольца.
--   2) Большая иконка руды pop-in (Back/Out) + лёгкий wobble.
--   3) Баннер «✦ НОВАЯ НАХОДКА ✦», имя руды, подпись редкости.
--   4) Разлетающиеся ✦-искры.
--   5) Hold ~1.4с (дольше для rare+), затем fade-out.
--
-- Принципы Phase 7: НЕ блокирует геймплей (backdrop Active=false, без затемнения
-- всего экрана и без full-screen кнопки — игрок продолжает копать). Несколько
-- находок подряд (fortune / multiMine) ставятся в очередь и проигрываются
-- последовательно. pcall-обёртка: падение FX не влияет на запись в журнал.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local CameraShake = require(script.Parent.Parent.core.CameraShake)

local OreDiscoveryFX = {}

local FX_GUI_NAME = "DeepDigger_OreDiscoveryFX"

local RARITY_COLOR: { [string]: Color3 } = {
    common = Color3.fromRGB(200, 200, 200),
    uncommon = Color3.fromRGB(120, 230, 120),
    rare = Color3.fromRGB(80, 160, 255),
    epic = Color3.fromRGB(200, 80, 240),
    legendary = Color3.fromRGB(255, 180, 30),
    mythic = Color3.fromRGB(255, 80, 80),
}

local RARITY_LABEL: { [string]: string } = {
    common = "Обычная",
    uncommon = "Необычная",
    rare = "Редкая",
    epic = "Эпическая",
    legendary = "Легендарная",
    mythic = "Мифическая",
}

local RARITY_WEIGHT = {
    common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6,
}

-- Очередь находок: несколько руд за один удар (fortune/multiMine) не должны
-- накладываться друг на друга.
local _queue: { { oreId: string, name: string, icon: string, rarity: string } } = {}
local _playing = false
local _activeGui: ScreenGui? = nil

local function getPlayerGui(): Instance?
    local player = Players.LocalPlayer
    return player and player:FindFirstChildOfClass("PlayerGui")
end

-- World-beam: световой столб цвета редкости у игрока (там, где он копает).
-- Это «celebration в мире», а не только на экране. Самодостаточен (pcall),
-- авто-очистка через Debris. Создаётся только для rare+ — для common это шум.
local function worldBeam(color: Color3, height: number, duration: number)
    local player = Players.LocalPlayer
    local char = player and player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        return
    end

    local basePos = root.Position

    local pillar = Instance.new("Part")
    pillar.Name = "DeepDigger_DiscoveryBeam"
    pillar.Shape = Enum.PartType.Cylinder
    pillar.Size = Vector3.new(0.5, 4, 0.5)
    pillar.Anchored = true
    pillar.CanCollide = false
    pillar.CanTouch = false
    pillar.CastShadow = false
    pillar.Material = Enum.Material.Neon
    pillar.Color = color
    pillar.Transparency = 0.25
    -- Cylinder растёт по локальной X → ставим вертикально.
    pillar.CFrame = CFrame.new(basePos) * CFrame.Angles(0, 0, math.rad(90))
    pillar.Parent = Workspace

    local light = Instance.new("PointLight")
    light.Color = color
    light.Range = 18
    light.Brightness = 3
    light.Shadows = false
    light.Parent = pillar

    -- Восходящие искры по столбу.
    local sparks = Instance.new("ParticleEmitter")
    sparks.Texture = "rbxasset://textures/particles/sparkle_main.dds"
    sparks.Color = ColorSequence.new(color)
    sparks.LightEmission = 0.8
    sparks.Rate = 0
    sparks.Lifetime = NumberRange.new(0.6, 1.2)
    sparks.Speed = NumberRange.new(8, 16)
    sparks.SpreadAngle = Vector2.new(12, 12)
    sparks.Acceleration = Vector3.new(0, 12, 0)
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparks.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    sparks.Parent = pillar
    sparks:Emit(24)

    -- Вырастает вверх, потом истончается и гаснет.
    local grow = TweenService:Create(
        pillar,
        TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {
            Size = Vector3.new(height, 3.5, 3.5),
            CFrame = CFrame.new(basePos + Vector3.new(0, height / 2 - 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        }
    )
    grow:Play()
    task.delay(duration * 0.5, function()
        if pillar.Parent then
            TweenService:Create(pillar, TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad), {
                Transparency = 1,
                Size = Vector3.new(height, 0.4, 0.4),
            }):Play()
            TweenService:Create(light, TweenInfo.new(duration * 0.5), { Brightness = 0 }):Play()
        end
    end)
    Debris:AddItem(pillar, duration + 0.3)
end

local function dim(color: Color3, k: number): Color3
    return Color3.new(color.R * k, color.G * k, color.B * k)
end

local function shockwave(parent: Instance, color: Color3, delayT: number, finalScale: number, thickness: number)
    task.delay(delayT, function()
        if not parent.Parent then return end
        local ring = Instance.new("Frame")
        ring.Size = UDim2.fromOffset(40, 40)
        ring.Position = UDim2.fromScale(0.5, 0.5)
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.BackgroundTransparency = 1
        ring.BorderSizePixel = 0
        ring.ZIndex = 3
        ring.Parent = parent
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = ring
        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = thickness
        stroke.Transparency = 0.05
        stroke.Parent = ring
        local dur = 0.65
        TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(finalScale, finalScale),
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1, Thickness = 1,
        }):Play()
        Debris:AddItem(ring, dur + 0.2)
    end)
end

-- Разлетающиеся ✦-искры вокруг иконки.
local function sparkles(parent: Instance, color: Color3, count: number)
    for i = 1, count do
        local ang = (i / count) * math.pi * 2 + math.random() * 0.4
        local dist = 70 + math.random() * 50
        local star = Instance.new("TextLabel")
        star.Size = UDim2.fromOffset(0, 0)
        star.Position = UDim2.fromScale(0.5, 0.5)
        star.AnchorPoint = Vector2.new(0.5, 0.5)
        star.BackgroundTransparency = 1
        star.Text = "✦"
        star.TextColor3 = color
        star.TextScaled = true
        star.Font = Enum.Font.GothamBold
        star.TextTransparency = 0.1
        star.ZIndex = 6
        star.Parent = parent
        local sz = 14 + math.random() * 14
        local target = UDim2.new(0.5, math.cos(ang) * dist, 0.5, math.sin(ang) * dist)
        TweenService:Create(star, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(sz, sz),
            Position = target,
        }):Play()
        TweenService:Create(star, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {
            TextTransparency = 1,
            Rotation = (math.random() - 0.5) * 180,
        }):Play()
        Debris:AddItem(star, 0.9)
    end
end

local function playOne(entry: { oreId: string, name: string, icon: string, rarity: string }, onDone: () -> ())
    local pg = getPlayerGui()
    if not pg then
        onDone()
        return
    end

    if _activeGui and _activeGui.Parent then
        _activeGui:Destroy()
    end

    local rarity = entry.rarity or "common"
    local color = RARITY_COLOR[rarity] or RARITY_COLOR.common
    local weight = RARITY_WEIGHT[rarity] or 1
    local isRare = weight >= 3
    -- Дольше держим на экране (исчезало слишком быстро); редкие — ещё дольше.
    local holdTime = 2.6 + weight * 0.35

    local gui = Instance.new("ScreenGui")
    gui.Name = FX_GUI_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 94
    gui.Parent = pg
    _activeGui = gui

    -- Корневой контейнер — НЕ интерактивный (геймплей продолжается).
    local root = Instance.new("Frame")
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundTransparency = 1
    root.Active = false
    root.ZIndex = 1
    root.Parent = gui

    -- Затемнение фона (мягкое, не блокирует ввод) — фокус на находке.
    local backdrop = Instance.new("Frame")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 1
    backdrop.BorderSizePixel = 0
    backdrop.Active = false
    backdrop.ZIndex = 1
    backdrop.Parent = root
    local backdropGrad = Instance.new("UIGradient")
    -- Радиальный-ish: ярче по центру (через прозрачность краёв).
    backdropGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.5, 0.1),
        NumberSequenceKeypoint.new(1, 0.5),
    })
    backdropGrad.Rotation = 90
    backdropGrad.Parent = backdrop
    local dimTarget = isRare and 0.42 or 0.3
    TweenService:Create(backdrop, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        BackgroundTransparency = dimTarget,
    }):Play()

    -- Тряска камеры + world-beam — celebration в мире (rare+).
    if isRare then
        pcall(function()
            if weight >= 6 then
                CameraShake.shakePreset("legendary_break")
            elseif weight >= 5 then
                CameraShake.shake(0.16, 0.2)
            else
                CameraShake.shakePreset("rare_break")
            end
        end)
    end
    pcall(function()
        worldBeam(color, isRare and (40 + weight * 8) or 26, holdTime * 0.7)
    end)

    -- Центр композиции — чуть выше середины, чтобы не перекрывать руки/HUD.
    local center = Instance.new("Frame")
    center.Size = UDim2.fromOffset(360, 360)
    center.Position = UDim2.fromScale(0.5, 0.4)
    center.AnchorPoint = Vector2.new(0.5, 0.5)
    center.BackgroundTransparency = 1
    center.Active = false
    center.ZIndex = 2
    center.Parent = root

    -- Аура свечения (мягкий круг цвета редкости).
    local aura = Instance.new("Frame")
    aura.Size = UDim2.fromOffset(40, 40)
    aura.Position = UDim2.fromScale(0.5, 0.5)
    aura.AnchorPoint = Vector2.new(0.5, 0.5)
    aura.BackgroundColor3 = color
    aura.BackgroundTransparency = 1
    aura.BorderSizePixel = 0
    aura.ZIndex = 2
    aura.Parent = center
    Instance.new("UICorner", aura).CornerRadius = UDim.new(1, 0)
    local auraGrad = Instance.new("UIGradient")
    auraGrad.Color = ColorSequence.new(color, dim(color, 0.3))
    auraGrad.Rotation = 90
    auraGrad.Parent = aura
    TweenService:Create(aura, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(220, 220),
        BackgroundTransparency = 0.8,
    }):Play()

    -- Shockwave-кольца (больше для редких).
    shockwave(center, color, 0.02, 240, 5)
    if isRare then
        shockwave(center, color, 0.14, 320, 4)
    end
    if weight >= 5 then
        shockwave(center, color, 0.26, 400, 3)
    end

    -- Иконка руды — pop-in от нуля (Back/Out) + лёгкий wobble.
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.fromOffset(0, 0)
    icon.Position = UDim2.fromScale(0.5, 0.46)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.BackgroundTransparency = 1
    icon.Text = entry.icon ~= "" and entry.icon or "⛏"
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.TextColor3 = Color3.fromRGB(255, 255, 255)
    icon.ZIndex = 5
    icon.Parent = center
    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = color
    iconStroke.Thickness = 2
    iconStroke.Transparency = 0.2
    iconStroke.Parent = icon
    TweenService:Create(icon, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(120, 120),
    }):Play()
    task.delay(0.42, function()
        if not icon.Parent then return end
        -- Лёгкий wobble после появления.
        local w1 = TweenService:Create(icon, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 1, true), { Rotation = 6 })
        w1:Play()
    end)

    -- Баннер сверху.
    local banner = Instance.new("TextLabel")
    banner.Size = UDim2.fromOffset(340, 26)
    banner.Position = UDim2.fromScale(0.5, 0.16)
    banner.AnchorPoint = Vector2.new(0.5, 0.5)
    banner.BackgroundTransparency = 1
    banner.Text = "✦ НОВАЯ НАХОДКА ✦"
    banner.TextSize = 18
    banner.Font = Enum.Font.GothamBlack
    banner.TextColor3 = color
    banner.TextTransparency = 1
    banner.TextStrokeTransparency = 0.4
    banner.ZIndex = 6
    banner.Parent = center
    TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()

    -- Имя руды.
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.fromOffset(360, 34)
    nameLbl.Position = UDim2.fromScale(0.5, 0.74)
    nameLbl.AnchorPoint = Vector2.new(0.5, 0.5)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = entry.name ~= "" and entry.name or entry.oreId
    nameLbl.TextSize = 28
    nameLbl.Font = Enum.Font.GothamBlack
    nameLbl.TextColor3 = Color3.fromRGB(245, 240, 230)
    nameLbl.TextTransparency = 1
    nameLbl.TextStrokeColor3 = dim(color, 0.4)
    nameLbl.TextStrokeTransparency = 0.3
    nameLbl.ZIndex = 6
    nameLbl.Parent = center
    task.delay(0.22, function()
        if not nameLbl.Parent then return end
        nameLbl.Position = UDim2.fromScale(0.5, 0.78)
        TweenService:Create(nameLbl, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            TextTransparency = 0,
            Position = UDim2.fromScale(0.5, 0.74),
        }):Play()
    end)

    -- Подпись редкости.
    local rarLbl = Instance.new("TextLabel")
    rarLbl.Size = UDim2.fromOffset(360, 20)
    rarLbl.Position = UDim2.fromScale(0.5, 0.85)
    rarLbl.AnchorPoint = Vector2.new(0.5, 0.5)
    rarLbl.BackgroundTransparency = 1
    rarLbl.Text = (RARITY_LABEL[rarity] or rarity):upper()
    rarLbl.TextSize = 14
    rarLbl.Font = Enum.Font.GothamBold
    rarLbl.TextColor3 = color
    rarLbl.TextTransparency = 1
    rarLbl.ZIndex = 6
    rarLbl.Parent = center
    task.delay(0.3, function()
        if not rarLbl.Parent then return end
        TweenService:Create(rarLbl, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { TextTransparency = 0 }):Play()
    end)

    -- Искры.
    task.delay(0.38, function()
        if center.Parent then
            sparkles(center, color, isRare and 10 or 6)
        end
    end)

    -- Hold → fade-out всего контейнера.
    task.delay(holdTime, function()
        if not gui.Parent then
            onDone()
            return
        end
        for _, d in ipairs(center:GetDescendants()) do
            if d:IsA("TextLabel") then
                TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
            elseif d:IsA("Frame") then
                TweenService:Create(d, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
            end
        end
        TweenService:Create(backdrop, TweenInfo.new(0.32), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(icon, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(0, 0),
        }):Play()
        task.delay(0.34, function()
            if _activeGui == gui then
                _activeGui = nil
            end
            if gui then
                gui:Destroy()
            end
            onDone()
        end)
    end)
end

local function pump()
    if _playing then return end
    local entry = table.remove(_queue, 1)
    if not entry then return end
    _playing = true
    local ok, err = pcall(function()
        playOne(entry, function()
            _playing = false
            -- Небольшая пауза между находками в очереди.
            task.delay(0.12, pump)
        end)
    end)
    if not ok then
        warn("[OreDiscoveryFX] play failed:", err)
        _playing = false
        task.delay(0.05, pump)
    end
end

--[[
    Главный API. payload — notify-таблица с полями:
      { oreId, text, icon, rarity, ... }
    Имя резолвится из payload.name, иначе из text.
]]
function OreDiscoveryFX.play(payload: any)
    if typeof(payload) ~= "table" or typeof(payload.oreId) ~= "string" then
        return
    end
    -- Очередь не должна разрастаться бесконечно (например авто-копание ботом).
    if #_queue >= 6 then
        return
    end
    table.insert(_queue, {
        oreId = payload.oreId,
        name = payload.oreName or payload.name or "",
        icon = payload.icon or "⛏",
        rarity = payload.rarity or "common",
    })
    pump()
end

return OreDiscoveryFX
