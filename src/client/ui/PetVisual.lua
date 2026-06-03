--!strict
-- PetVisual.lua — Phase 11 (Pets MVP).
--
-- Парящая модель экипированного питомца рядом с локальным игроком.
--   * Part (Neon, rarity-цвет) с BillboardGui-иконкой (emoji) пета.
--   * Каждый кадр позиционируется относительно HumanoidRootPart:
--       offset вбок + bobbing (sin по Y) + вращение части вокруг своей оси.
--   * Респавн обрабатывается автоматически — позиция берётся от текущего
--     character.HumanoidRootPart каждый кадр (нет явного re-attach).
--
-- API:
--   PetVisual.setEquipped(petId: string?)  — показать/сменить/скрыть пета.
--   PetVisual.destroy()                    — полный teardown (выход игрока).
--
-- Самодостаточен (не лезет в MiningRenderer / HUD). pcall в init.client.lua
-- вокруг setEquipped — падение визуала не должно ронять синк HUD.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetDatabase = require(ReplicatedStorage:WaitForChild("shared").data.PetDatabase)

local PetVisual = {}

local currentPetId: string? = nil
local model: BasePart? = nil
local conn: RBXScriptConnection? = nil
local startClock = os.clock()

-- Параметры парения.
local SIDE_OFFSET = 3.2     -- вбок от игрока (студы)
local HEIGHT_OFFSET = 2.4   -- высота центра парения
local BOB_AMPLITUDE = 0.45  -- размах bobbing'а
local BOB_SPEED = 2.2       -- скорость bobbing'а
local SPIN_SPEED = 1.6      -- скорость вращения части (рад/с)

local function getRoot(): BasePart?
    local player = Players.LocalPlayer
    if not player then return nil end
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    return nil
end

local function destroyModel()
    if model then
        model:Destroy()
        model = nil
    end
end

local function buildModel(def: PetDatabase.Pet)
    destroyModel()
    local part = Instance.new("Part")
    part.Name = "DeepDigger_Pet"
    part.Shape = Enum.PartType.Ball
    part.Size = Vector3.new(1.6, 1.6, 1.6)
    part.Material = Enum.Material.Neon
    part.Color = def.color
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Transparency = 0.15

    -- Иконка пета (emoji) в BillboardGui над сферой.
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromOffset(46, 46)
    billboard.StudsOffset = Vector3.new(0, 1.4, 0)
    billboard.AlwaysOnTop = false
    billboard.LightInfluence = 0
    billboard.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = def.icon
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Parent = billboard

    part.Parent = workspace
    model = part
end

local function ensureLoop()
    if conn then return end
    conn = RunService.RenderStepped:Connect(function()
        if not model then return end
        local root = getRoot()
        if not root then
            -- Персонаж не готов (респавн) — прячем модель до возврата.
            model.Transparency = 1
            return
        end
        model.Transparency = 0.15
        local t = os.clock() - startClock
        local bob = math.sin(t * BOB_SPEED) * BOB_AMPLITUDE
        -- Позиция: сбоку от игрока (в его локальном пространстве) + bobbing.
        local base = root.CFrame * CFrame.new(SIDE_OFFSET, HEIGHT_OFFSET + bob, 0)
        -- Вращение части вокруг своей оси (world-space, чтобы крутилась
        -- независимо от поворота игрока).
        local spin = CFrame.Angles(0, t * SPIN_SPEED, 0)
        model.CFrame = CFrame.new(base.Position) * spin
    end)
end

--[[
    Показать/сменить/скрыть пета по petId. nil → скрыть.
    Идемпотентен: повторный вызов с тем же petId — no-op.
]]
function PetVisual.setEquipped(petId: string?)
    if petId == currentPetId then
        return
    end
    currentPetId = petId
    if not petId then
        destroyModel()
        return
    end
    local def = PetDatabase.get(petId)
    if not def then
        destroyModel()
        currentPetId = nil
        return
    end
    buildModel(def)
    ensureLoop()
end

function PetVisual.destroy()
    if conn then
        conn:Disconnect()
        conn = nil
    end
    destroyModel()
    currentPetId = nil
end

return PetVisual
