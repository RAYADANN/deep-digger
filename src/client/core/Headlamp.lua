--!strict
-- Headlamp.lua — шахтёрский фонарик игрока.
--
-- Один PointLight, привязанный к HumanoidRootPart персонажа. Всегда освещает
-- блоки рядом, поэтому глубокие тёмные слои (LAYER_LIGHTING void = почти тьма)
-- остаются проходимыми, а атмосфера «спуска во тьму» сохраняется на расстоянии.
--
-- Перф: ровно один динамический источник света на игрока, без теней
-- (Constants.HEADLAMP.shadows = false). Глубже свет плавно ярче/дальше, чтобы
-- во void было видно.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local Constants = require(shared.constants)
local Logger = require(shared.util.Logger)

local LIGHT_NAME = "DeepDigger_Headlamp"

local Headlamp = {}
Headlamp.__index = Headlamp

function Headlamp.new()
    local self = setmetatable({}, Headlamp)
    self._log = Logger.new("Headlamp")
    self._light = nil :: PointLight?
    self._host = nil :: BasePart?
    return self
end

local function config()
    return Constants.HEADLAMP or {
        color = Color3.fromRGB(255, 244, 214),
        baseRange = 26, maxRange = 42,
        baseBrightness = 1.6, maxBrightness = 3.0,
        fullPowerDepth = 1200, shadows = false,
    }
end

--[[
    Привязать фонарик к персонажу. Идемпотентно: повторный вызов на том же
    персонаже переиспользует существующий PointLight. На респавне персонаж
    новый — создаём заново.
]]
function Headlamp:attach(character: Model)
    if config().enabled == false then
        return
    end
    local root = character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Head")
    if not root or not root:IsA("BasePart") then
        -- Персонаж ещё не собрался — ждём появления HumanoidRootPart.
        task.spawn(function()
            local hrp = character:WaitForChild("HumanoidRootPart", 5)
            if hrp and hrp:IsA("BasePart") and character.Parent then
                self:_mount(hrp)
            end
        end)
        return
    end
    self:_mount(root)
end

function Headlamp:_mount(host: BasePart)
    local c = config()
    local existing = host:FindFirstChild(LIGHT_NAME)
    local light: PointLight
    if existing and existing:IsA("PointLight") then
        light = existing
    else
        light = Instance.new("PointLight")
        light.Name = LIGHT_NAME
    end
    light.Color = c.color
    light.Range = c.baseRange
    light.Brightness = c.baseBrightness
    light.Shadows = c.shadows == true
    light.Parent = host
    self._light = light
    self._host = host
    self._log:info("Headlamp attached")
end

--[[
    Обновить силу света под глубину. Зовётся из depthTracker:onChanged —
    дёшево (две интерполяции + запись свойств), без отдельного Heartbeat.
]]
function Headlamp:setDepth(depth: number)
    if config().enabled == false then
        return
    end
    local light = self._light
    if not light or not light.Parent then
        return
    end
    local c = config()
    local full = math.max(1, c.fullPowerDepth)
    local t = math.clamp(depth / full, 0, 1)
    light.Range = c.baseRange + (c.maxRange - c.baseRange) * t
    light.Brightness = c.baseBrightness + (c.maxBrightness - c.baseBrightness) * t
end

function Headlamp:destroy()
    if self._light then
        self._light:Destroy()
        self._light = nil
    end
    self._host = nil
end

return Headlamp
