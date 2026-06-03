--!strict
-- init.client.lua — точка входа клиента.
-- Инициализирует рендер шахты, UI, подключает сеть.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local MiningRenderer = require(script.core.MiningRenderer)
local DepthTracker = require(script.core.DepthTracker)
local LayerEnvironment = require(script.core.LayerEnvironment)
local SoundManager = require(script.core.SoundManager)
local CameraShake = require(script.core.CameraShake)
local HUD = require(script.ui.HUD)
local Notification = require(script.ui.Notification)
local Tutorial = require(script.ui.Tutorial)
local RebirthFX = require(script.ui.RebirthFX)
local DailyRewardModal = require(script.ui.DailyRewardModal)
local RewardFX = require(script.ui.RewardFX)
local PetVisual = require(script.ui.PetVisual)
local PetHatchFX = require(script.ui.PetHatchFX)
local OreDiscoveryFX = require(script.ui.OreDiscoveryFX)
local PetLogic = require(shared.util.PetLogic)
local ScopeFactory = require(script.ui.hud.ScopeFactory)
local Net = require(modules.Net)

-- Phase 7: запускаем юс-модули ОДИН раз (синглтоны) на старте клиента,
-- до первого CharacterAdded — звуки и shake должны быть готовы к моменту,
-- когда серверный snapshot прилетает и игрок начинает кликать.
SoundManager.start()
-- Не фиксируем камеру: при респавне CurrentCamera пересоздаётся, а внутренний
-- currentCamera() в модуле умеет fallback на workspace.CurrentCamera каждый кадр.
CameraShake.start()

local log = Logger.new("Client:Init")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Создаём рендер и HUD
local renderer = MiningRenderer.new()
local hud: HUD? = nil
local depthTracker = DepthTracker.new(player)
local layerEnvironment = LayerEnvironment.new()
depthTracker:onChanged(function(info)
    if hud then
        hud:setDepth(info.depth, info.layerId, info.layerName)
    end
    layerEnvironment:apply(info.layerId)
    pcall(function()
        Net:Invoke("UpdateDepth", info.depth)
    end)
end)

-- Слушаем полные данные с сервера
-- Пока два события, объединяем:
local playerDataBuffer = {}

local function applyPlayerPayload(data)
    for k, v in pairs(data) do
        playerDataBuffer[k] = v
    end
    renderer:setSwingDelay(data.speedLevel or 1)
    if hud then
        hud:setPlayerData(playerDataBuffer)
    end
    -- Phase 11: парящий питомец отражает экипировку из payload'а.
    -- equippedPet — это UID, а PetVisual ждёт petId; резолвим через PetLogic
    -- (uid → запись в pets → petId). nil/нет пета → скрыть. pcall — падение
    -- визуала не должно сорвать синк HUD.
    pcall(function()
        local equippedPets = PetLogic.getEquippedPets(playerDataBuffer)
        local def = equippedPets[1]
        PetVisual.setEquipped(def and def.id or nil)
    end)
end

-- Phase 10: persistent scope для модального оверлея DailyRewardModal.
-- Создаём отдельный scope от HUD'a — модал переживает HUD-destroy при
-- respawn'е. doCleanup не вызывается явно: Fusion.scoped сам управляет
-- lifetime через PlayerGui.
local modalScope = ScopeFactory.new()
-- Сессионный флаг: один раз открываем модал автоматически (на первом
-- PlayerStats с canClaim=true). Дальше — только через /daily или
-- Notify kind="daily_available".
local _autoOpenedThisSession = false

local function tryOpenDailyModal(dailyState: any)
    if not dailyState or not dailyState.canClaim then
        return
    end
    if DailyRewardModal.isOpen() then
        return
    end
    DailyRewardModal.show({
        scope = modalScope,
        streak = dailyState.currentStreak or 0,
        nextDay = dailyState.nextDay or 1,
    })
end

Net:Connect("PlayerStats", function(data)
    applyPlayerPayload(data)
    -- Phase 8: запускаем туториал, как только сервер прислал tutorialStep.
    -- Tutorial.start идемпотентен (early-return если уже running и если
    -- step >= 3), поэтому безопасно вызывать на каждый PlayerStats:
    --   * первый заход с tutorialStep < 3 → старт,
    --   * пройденный профиль (3) → no-op,
    --   * /reset после прохождения → Tutorial.destroy уже выставил
    --     running=false, новый tutorialStep=0 → старт заново.
    -- Baseline-значения totalBlocksMined / totalCoinsEarned передаём, чтобы
    -- Tutorial не принял прошлый прогресс за «свежий клик».
    if typeof(data) == "table" and data.tutorialStep ~= nil then
        Tutorial.start(data.tutorialStep, data)
    end
    -- Phase 10: автооткрытие DailyRewardModal на первом PlayerStats с
    -- canClaim=true в этой сессии. Открытие после rejoin'a — естественное,
    -- но не на каждом sync HUD'a (иначе игрок не сможет закрыть модал —
    -- сервер шлёт PlayerStats после каждой sell/buy).
    if typeof(data) == "table" and data.dailyState and not _autoOpenedThisSession then
        if data.dailyState.canClaim then
            _autoOpenedThisSession = true
            tryOpenDailyModal(data.dailyState)
        end
    end
end)
Net:Connect("PlayerInventory", function(data)
    applyPlayerPayload(data)
end)

Net:Connect("Notify", function(payload)
    if typeof(payload) ~= "table" or typeof(payload.text) ~= "string" then
        return
    end
    local color
    if typeof(payload.color) == "table" then
        color = Color3.fromRGB(payload.color.r or 255, payload.color.g or 255, payload.color.b or 255)
    end
    -- Phase 13: для «новой находки» обычный тост не показываем — его заменяет
    -- полноценная reveal-анимация OreDiscoveryFX (иначе двойной фидбек).
    if payload.kind ~= "ore_discovered" then
        Notification.show({
            text = payload.text,
            color = color,
            icon = payload.icon,
            duration = payload.duration,
        })
    end
    -- Phase 9: RebirthManager шлёт kind="rebirth" вместе с тостом. RebirthFX
    -- работает локально (точка игрока), pcall — чтобы упавший FX не сорвал
    -- сам тост ребёрта.
    if payload.kind == "rebirth" then
        pcall(RebirthFX.burst)
    end
    -- Phase 10: DailyReward.kind="daily_available" → открыть модал.
    -- kind="daily_reward" → запустить RewardFX (тост уже показан выше).
    if payload.kind == "daily_available" then
        -- buffer'им: модал имеет смысл показывать только если в текущем
        -- PlayerStats тоже canClaim. Дёрнем через playerDataBuffer'a.
        local daily = playerDataBuffer.dailyState
        if daily then
            tryOpenDailyModal(daily)
        end
    elseif payload.kind == "daily_reward" then
        pcall(function()
            RewardFX.burst(payload.rarity)
        end)
    -- Phase 12: девпродукт «Egg 10x» — server-authoritative hatch FX.
    elseif payload.kind == "egg_purchase" then
        pcall(function()
            PetHatchFX.play(payload.pets)
        end)
    -- Phase 13: первая добыча новой руды → reveal-анимация «НОВАЯ НАХОДКА»
    -- (очередь внутри FX обрабатывает несколько находок за удар).
    elseif payload.kind == "ore_discovered" then
        pcall(function()
            OreDiscoveryFX.play(payload)
            if typeof(payload.oreId) == "string" then
                SoundManager.playForOre("break", payload.oreId, payload.rarity)
            end
        end)
    -- Полностью открытый слой — celebration: coin-rain + звук продажи.
    elseif payload.kind == "layer_milestone" then
        pcall(function()
            RewardFX.burst(payload.rarity or "legendary")
            SoundManager.play("sell_success")
        end)
    end
end)

-- Запускаем, когда персонаж появляется
local function onCharacterAdded(character: Model)
    log:info("Character spawned, starting mining renderer")
    if hud then
        hud:destroy()
        hud = nil
    end
    renderer:start()
    hud = HUD.new(player)
    layerEnvironment:reset()
    depthTracker:start()
    -- Phase 8: HUD пересоздан → старые TutorialArrow-хэндлы указывают на
    -- destroyed-фреймы. Пересобираем стрелку под новый HUD. Если туториал
    -- уже завершён (или ещё не стартовал) — refresh — это no-op.
    if Tutorial.isRunning() then
        task.defer(function()
            Tutorial.refresh()
        end)
    end
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Остановка при выходе игрока
player.AncestryChanged:Connect(function()
    if player.Parent == nil then
        renderer:stop()
        depthTracker:stop()
        if hud then hud:destroy(); hud = nil end
        Tutorial.destroy()
        PetVisual.destroy()
    end
end)

-- Команды через чат (для отладки UI)
player.Chatted:Connect(function(msg)
    local cmd = msg:lower()
    if cmd == "/rarity" then
        local on = renderer:toggleRarity()
        log:info("Rarity tags:", if on then "ON" else "OFF")
    elseif cmd == "/hpbar" then
        local on = renderer:toggleHPBar()
        log:info("HP bars:", if on then "ON" else "OFF")
    elseif cmd == "/help" then
        print("--- Deep Digger Commands ---")
        print("/rarity - toggle rarity strips")
        print("/hpbar - toggle HP bars on hover")
        print("/help - this message")
    end
end)

log:info("Client initialized")
