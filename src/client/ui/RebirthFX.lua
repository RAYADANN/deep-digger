--!strict
-- RebirthFX.lua — Phase 9.
--
-- Локальный визуальный эффект ребёрта в точке игрока:
--   * большое золотое shockwave-кольцо (mining-style, ForceField-сфера),
--   * 30 золотых физических chunks с gravity (paтерн Phase 7 chunkBurst),
--   * вторая, отложенная shockwave-волна — для «двойного удара» (mythic-tier).
--
-- НЕ используем:
--   * camera shake — это шутерный эффект, нарушает Phase 7 mining-style;
--   * slow-mo — то же самое (renderer'у это запрещено);
--   * fullscreen flash — резкий ScreenGui-overlay ломает атмосферу шахты.
--
-- Модуль самодостаточен (не лезет в MiningRenderer). Если RebirthFX упадёт —
-- ребёрт всё равно состоится: тост от RebirthManager придёт через Notify.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local RebirthFX = {}

local GOLD = Color3.fromRGB(255, 215, 90)
local GOLD_BRIGHT = Color3.fromRGB(255, 240, 150)
local CHUNK_COUNT = 30
local FX_LIFETIME = 1.4

local function getPlayerCFrame(): CFrame?
    local player = Players.LocalPlayer
    if not player then
        return nil
    end
    local character = player.Character
    if not character then
        return nil
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        return nil
    end
    return root.CFrame
end

local function shockwave(parent: Instance, position: Vector3, color: Color3, finalSize: number, duration: number, delay: number?)
    task.delay(delay or 0, function()
        if not parent.Parent and parent ~= workspace then
            -- если parent уже уничтожен — fallback на workspace
            parent = workspace
        end
        local sphere = Instance.new("Part")
        sphere.Shape = Enum.PartType.Ball
        sphere.Size = Vector3.new(0.5, 0.5, 0.5)
        sphere.Position = position
        sphere.Anchored = true
        sphere.CanCollide = false
        sphere.CanTouch = false
        sphere.CastShadow = false
        sphere.Material = Enum.Material.ForceField
        sphere.Color = color
        sphere.Transparency = 0.15
        sphere.Parent = parent
        TweenService:Create(sphere, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = Vector3.new(finalSize, finalSize, finalSize),
            Transparency = 1,
        }):Play()
        Debris:AddItem(sphere, duration + 0.1)
    end)
end

local function goldenChunks(parent: Instance, position: Vector3, count: number)
    -- В отличие от MiningRenderer.chunkBurst, у нас нет привязки к BS блока:
    -- размер фиксируем небольшим (~0.7 студ) чтобы куски смотрелись как
    -- «искры», а не как куски руды.
    local baseSize = 0.55
    for _ = 1, count do
        local size = baseSize * (0.7 + math.random() * 0.7)
        local chunk = Instance.new("Part")
        chunk.Size = Vector3.new(size, size, size)
        -- Стартуем вокруг torso (position уже это с учётом offset'а).
        chunk.CFrame = CFrame.new(position + Vector3.new(
            (math.random() - 0.5) * 1.6,
            (math.random() - 0.5) * 1.6,
            (math.random() - 0.5) * 1.6
        )) * CFrame.Angles(
            math.random() * math.pi * 2,
            math.random() * math.pi * 2,
            math.random() * math.pi * 2
        )
        chunk.Anchored = false
        chunk.CanCollide = false
        chunk.CanTouch = false
        chunk.CastShadow = false
        chunk.Material = Enum.Material.Neon
        chunk.Color = if math.random() < 0.4 then GOLD_BRIGHT else GOLD
        chunk.Massless = true
        chunk.Parent = parent

        local dir = Vector3.new(
            (math.random() - 0.5) * 2,
            math.random() * 1.5 + 0.5,
            (math.random() - 0.5) * 2
        )
        if dir.Magnitude > 0 then
            dir = dir.Unit
        end
        chunk.AssemblyLinearVelocity = dir * (18 + math.random() * 12)
        chunk.AssemblyAngularVelocity = Vector3.new(
            (math.random() - 0.5) * 40,
            (math.random() - 0.5) * 40,
            (math.random() - 0.5) * 40
        )

        task.delay(0.8, function()
            if chunk.Parent then
                TweenService:Create(chunk, TweenInfo.new(0.55, Enum.EasingStyle.Quad), {
                    Transparency = 1,
                }):Play()
            end
        end)
        Debris:AddItem(chunk, FX_LIFETIME)
    end
end

--[[
    Главный API. Запускает эффект в позиции игрока.
    Идемпотентен: можно звать многократно, эффекты сложатся.
    Безопасен: если у игрока нет персонажа — no-op.
]]
function RebirthFX.burst()
    local cf = getPlayerCFrame()
    if not cf then
        return
    end
    -- Центр FX — torso (HumanoidRootPart). Слегка приподнимаем, чтобы
    -- shockwave не утопал в полу.
    local origin = cf.Position + Vector3.new(0, 1.5, 0)
    local parent = workspace

    -- Первая волна: яркий золотой shockwave большого радиуса.
    shockwave(parent, origin, GOLD, 22, 0.6, 0)
    -- Вторая волна: чуть позже, ярче и больше — «двойной удар».
    shockwave(parent, origin, GOLD_BRIGHT, 32, 0.7, 0.15)
    -- Третья — тонкое кольцо «эхо», для законченного звучания.
    shockwave(parent, origin, GOLD, 40, 0.85, 0.35)

    -- Чанки: физические искры.
    goldenChunks(parent, origin, CHUNK_COUNT)
end

return RebirthFX
