--!strict
-- PetHatchFX.lua — Phase 11 (Pets MVP).
--
-- Полноэкранная анимация открытия яйца (вызывается PetsPanel после успешного
-- Net:Invoke("HatchEgg")). Поддерживает батч (1× и 10×).
--
-- Последовательность:
--   1) Затемнение фона + 🥚 в центре, яйцо «трясётся» (rotation tween) ~0.7с.
--   2) Burst: rarity-цветные shockwave-кольца (по лучшей редкости в партии).
--   3) Reveal: сетка карточек вылупившихся петов с pop-in (stagger).
--   4) Авто-закрытие через ~2.6с или по клику (tap-to-skip).
--
-- Принципы Phase 7: это «event-celebration» (как daily-claim RewardFX), не
-- momentary gameplay feedback — полноэкранный overlay допустим. pcall-обёртка:
-- падение FX не срывает hatch (пет уже в профиле).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetLogic = require(ReplicatedStorage:WaitForChild("shared").util.PetLogic)
local PetDatabase = require(ReplicatedStorage:WaitForChild("shared").data.PetDatabase)

local PetHatchFX = {}

local FX_GUI_NAME = "DeepDigger_PetHatchFX"

local RARITY_COLOR: { [string]: Color3 } = {
    common = Color3.fromRGB(200, 200, 200),
    uncommon = Color3.fromRGB(120, 230, 120),
    rare = Color3.fromRGB(80, 160, 255),
    epic = Color3.fromRGB(200, 80, 240),
    legendary = Color3.fromRGB(255, 180, 30),
    mythic = Color3.fromRGB(255, 70, 70),
}

local RARITY_WEIGHT = {
    common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6,
}

local _activeGui: ScreenGui? = nil

local function getPlayerGui(): Instance?
    local player = Players.LocalPlayer
    return player and player:FindFirstChildOfClass("PlayerGui")
end

-- Лучшая (самая редкая) rarity в партии — цвет burst'а.
local function bestRarity(hatched: { any }): string
    local best = "common"
    local bestW = 0
    for _, p in ipairs(hatched) do
        local r = p.rarity or "common"
        local w = RARITY_WEIGHT[r] or 1
        if w > bestW then
            bestW = w
            best = r
        end
    end
    return best
end

local function shockwave(parent: Instance, color: Color3, delay: number, finalScale: number)
    task.delay(delay, function()
        if not parent.Parent then return end
        local ring = Instance.new("Frame")
        ring.Size = UDim2.fromOffset(20, 20)
        ring.Position = UDim2.fromScale(0.5, 0.42)
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.BackgroundTransparency = 1
        ring.BorderSizePixel = 0
        ring.ZIndex = 6
        ring.Parent = parent
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = ring
        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = 5
        stroke.Transparency = 0.05
        stroke.Parent = ring
        local dur = 0.6
        TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(finalScale, finalScale),
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1, Thickness = 1,
        }):Play()
        Debris:AddItem(ring, dur + 0.2)
    end)
end

-- Одна reveal-карточка пета.
local function revealCard(parent: Instance, def: PetDatabase.Pet, layoutOrder: number, big: boolean, popDelay: number)
    local color = RARITY_COLOR[def.rarity] or RARITY_COLOR.common
    local w = if big then 200 else 96
    local h = if big then 240 else 116

    local card = Instance.new("Frame")
    card.Size = UDim2.fromOffset(0, 0) -- pop-in от нуля
    card.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    card.BorderSizePixel = 0
    card.LayoutOrder = layoutOrder
    card.ZIndex = 7
    card.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = if big then 3 else 2
    stroke.Transparency = 0.1
    stroke.Parent = card

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(1, 0, 0, if big then 120 else 56)
    icon.Position = UDim2.new(0, 0, 0, if big then 16 else 8)
    icon.BackgroundTransparency = 1
    icon.Text = def.icon
    icon.TextScaled = true
    icon.Font = Enum.Font.GothamBold
    icon.TextColor3 = color
    icon.ZIndex = 8
    icon.Parent = card

    local name = Instance.new("TextLabel")
    name.Size = UDim2.new(1, -8, 0, if big then 28 else 16)
    name.Position = UDim2.new(0, 4, 0, if big then 142 else 66)
    name.BackgroundTransparency = 1
    name.Text = def.name
    name.TextScaled = big
    name.TextSize = 12
    name.Font = Enum.Font.GothamBlack
    name.TextColor3 = Color3.fromRGB(240, 235, 220)
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.ZIndex = 8
    name.Parent = card

    local effect = Instance.new("TextLabel")
    effect.Size = UDim2.new(1, -8, 0, if big then 24 else 16)
    effect.Position = UDim2.new(0, 4, 0, if big then 176 else 84)
    effect.BackgroundTransparency = 1
    effect.Text = PetLogic.effectShort(def.effect)
    effect.TextSize = if big then 14 else 10
    effect.Font = Enum.Font.GothamBold
    effect.TextColor3 = color
    effect.ZIndex = 8
    effect.Parent = card

    -- Pop-in: Size 0 → final (Back/Out) с задержкой по stagger.
    task.delay(popDelay, function()
        if not card.Parent then return end
        TweenService:Create(card, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(w, h),
        }):Play()
    end)
end

local function dismiss(gui: ScreenGui)
    if _activeGui == gui then
        _activeGui = nil
    end
    if not gui.Parent then return end
    local backdrop = gui:FindFirstChild("Backdrop")
    if backdrop and backdrop:IsA("Frame") then
        TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
    end
    task.delay(0.22, function()
        if gui then gui:Destroy() end
    end)
end

--[[
    Главный API. hatched — список { petId, name, rarity, icon, effect, uid }
    (как присылает PetManager). Безопасен: пустой список / no PlayerGui → no-op.
]]
function PetHatchFX.play(hatched: { any }?)
    local ok, err = pcall(function()
        if typeof(hatched) ~= "table" or #hatched == 0 then
            return
        end
        local pg = getPlayerGui()
        if not pg then return end

        -- Один активный оверлей за раз.
        if _activeGui and _activeGui.Parent then
            _activeGui:Destroy()
        end

        local gui = Instance.new("ScreenGui")
        gui.Name = FX_GUI_NAME
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 96
        gui.Parent = pg
        _activeGui = gui

        local backdrop = Instance.new("Frame")
        backdrop.Name = "Backdrop"
        backdrop.Size = UDim2.fromScale(1, 1)
        backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        backdrop.BackgroundTransparency = 1
        backdrop.BorderSizePixel = 0
        backdrop.ZIndex = 1
        backdrop.Parent = gui
        TweenService:Create(backdrop, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()

        -- Tap-to-skip: клик по фону закрывает.
        local skipBtn = Instance.new("TextButton")
        skipBtn.Size = UDim2.fromScale(1, 1)
        skipBtn.BackgroundTransparency = 1
        skipBtn.Text = ""
        skipBtn.ZIndex = 2
        skipBtn.Parent = backdrop
        skipBtn.Activated:Connect(function()
            dismiss(gui)
        end)

        local color = RARITY_COLOR[bestRarity(hatched)] or RARITY_COLOR.common
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1024, 768)
        local maxScale = math.max(viewport.X, viewport.Y)

        -- Фаза 1: трясущееся яйцо.
        local egg = Instance.new("TextLabel")
        egg.Size = UDim2.fromOffset(140, 140)
        egg.Position = UDim2.fromScale(0.5, 0.42)
        egg.AnchorPoint = Vector2.new(0.5, 0.5)
        egg.BackgroundTransparency = 1
        egg.Text = "🥚"
        egg.TextScaled = true
        egg.Font = Enum.Font.GothamBold
        egg.TextColor3 = Color3.fromRGB(255, 255, 255)
        egg.ZIndex = 5
        egg.Parent = backdrop

        task.spawn(function()
            -- Тряска: ±18° туда-сюда несколько раз, ускоряясь.
            for i = 1, 5 do
                local ang = (i % 2 == 0) and 16 or -16
                TweenService:Create(egg, TweenInfo.new(0.12, Enum.EasingStyle.Sine), { Rotation = ang }):Play()
                task.wait(0.13)
            end
            TweenService:Create(egg, TweenInfo.new(0.08), { Rotation = 0 }):Play()
            task.wait(0.1)
            -- Burst + скрытие яйца.
            TweenService:Create(egg, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
                TextTransparency = 1,
                Size = UDim2.fromOffset(40, 40),
            }):Play()
            shockwave(backdrop, color, 0, maxScale * 0.5)
            shockwave(backdrop, color, 0.12, maxScale * 0.8)

            -- Заголовок «Вылупилось!».
            local title = Instance.new("TextLabel")
            title.Size = UDim2.fromOffset(360, 30)
            title.Position = UDim2.fromScale(0.5, 0.16)
            title.AnchorPoint = Vector2.new(0.5, 0.5)
            title.BackgroundTransparency = 1
            title.Text = if #hatched > 1 then ("Вылупилось питомцев: %d"):format(#hatched) else "Новый питомец!"
            title.TextSize = 22
            title.Font = Enum.Font.GothamBlack
            title.TextColor3 = color
            title.ZIndex = 7
            title.Parent = backdrop

            -- Reveal-карточки.
            local container = Instance.new("Frame")
            container.AnchorPoint = Vector2.new(0.5, 0.5)
            container.Position = UDim2.fromScale(0.5, 0.5)
            container.BackgroundTransparency = 1
            container.ZIndex = 7
            container.Parent = backdrop

            local big = #hatched == 1
            if big then
                container.Size = UDim2.fromOffset(200, 240)
                local layout = Instance.new("UIListLayout")
                layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
                layout.VerticalAlignment = Enum.VerticalAlignment.Center
                layout.Parent = container
            else
                -- Грид до 5 в ряд.
                container.Size = UDim2.fromOffset(5 * 96 + 4 * 8, 2 * 116 + 8)
                local grid = Instance.new("UIGridLayout")
                grid.CellSize = UDim2.fromOffset(96, 116)
                grid.CellPadding = UDim2.fromOffset(8, 8)
                grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
                grid.VerticalAlignment = Enum.VerticalAlignment.Center
                grid.Parent = container
            end

            for i, p in ipairs(hatched) do
                local def = PetDatabase.get(p.petId)
                if def then
                    revealCard(container, def, i, big, 0.05 * i)
                end
            end

            -- Авто-закрытие.
            task.delay(2.6, function()
                dismiss(gui)
            end)
        end)
    end)
    if not ok then
        warn("[PetHatchFX] play failed:", err)
    end
end

return PetHatchFX
