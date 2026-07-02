--!strict
-- init.client.lua — точка входа клиента.
-- Инициализирует рендер шахты, UI, подключает сеть.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local FreezeDiagnostics = require(script.core.FreezeDiagnostics)
local MiningRenderer = require(script.core.MiningRenderer)
local DepthTracker = require(script.core.DepthTracker)
local LayerEnvironment = require(script.core.LayerEnvironment)
local LayerAmbience = require(script.core.LayerAmbience)
local Headlamp = require(script.core.Headlamp)
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
local HomeFX = require(script.ui.HomeFX)
local EggMachines = require(script.core.EggMachines)
local HubZones = require(script.core.HubZones)
local WorldLeaderboard = require(script.core.WorldLeaderboard)
local PlayerTagScale = require(script.core.PlayerTagScale)
local SellButton = require(script.ui.hud.components.SellButton)
local PetLogic = require(shared.util.PetLogic)
local UpgradeLogic = require(shared.util.UpgradeLogic)
local PetModelKit = require(shared.util.PetModelKit)
local ScopeFactory = require(script.ui.hud.ScopeFactory)
local Net = require(modules.Net)

-- Phase 7: запускаем юс-модули ОДИН раз (синглтоны) на старте клиента,
-- до первого CharacterAdded — звуки и shake должны быть готовы к моменту,
-- когда серверный snapshot прилетает и игрок начинает кликать.
SoundManager.start()
-- Не фиксируем камеру: при респавне CurrentCamera пересоздаётся, а внутренний
-- currentCamera() в модуле умеет fallback на workspace.CurrentCamera каждый кадр.
CameraShake.start()
PlayerTagScale.start()

-- Диагностика фризов: стартует сразу, чтобы поймать причины просадок FPS с
-- первого кадра. Печатает причину каждого фриза (>100 мс) в консоль; полный
-- отчёт — /diagreport. Переживает респавн (состояние в _G). Оверхед минимален
-- (один Heartbeat + дешёвые счётчики PerfBeacon).
FreezeDiagnostics.start({ freezeMs = 100 })

local log = Logger.new("Client:Init")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Создаём рендер и HUD
local renderer = MiningRenderer.new()
local hud: HUD? = nil
local depthTracker = DepthTracker.new(player)
local layerEnvironment = LayerEnvironment.new()
local layerAmbience = LayerAmbience.new()
local headlamp = Headlamp.new()
depthTracker:onChanged(function(info)
    if hud then
        hud:setDepth(info.depth, info.layerId, info.layerName)
    end
    layerEnvironment:apply(info.layerId)
    local character = player.Character
    layerAmbience:apply(info.layerId, character, info.layerChanged)
    headlamp:setDepth(info.depth)
    pcall(function()
        Net:Invoke("UpdateDepth", info.depth)
    end)
end)

-- Слушаем полные данные с сервера (PlayerStats + PlayerInventory коалесим).
local playerDataBuffer = {}

local PerfBeacon = require(shared.util.PerfBeacon)

--[[
    Сервер шлёт PlayerStats и PlayerInventory с ОДИНАКОВЫМ payload (syncPlayerHud).
    Без коалесинга клиент дважды прогоняет applyServerPayload (~150 мс ×2).
    Склеиваем в один apply на следующий Heartbeat.
]]
local coalesceScheduled = false
local coalescePayload: any = nil

local function applyPlayerPayload(data)
    PerfBeacon.bump("playerPayloadApply")
    for k, v in pairs(data) do
        playerDataBuffer[k] = v
    end
    renderer:setSwingDelay(
        data.speedLevel or 1,
        UpgradeLogic.speedBoostMultiplier(data.activeBoosts)
    )
    if hud then
        local t0 = os.clock()
        hud:setPlayerData(playerDataBuffer)
        PerfBeacon.addTime("hudSetDataMs", (os.clock() - t0) * 1000)
        PerfBeacon.bump("hudSetData")
    end
    pcall(function()
        local equippedPets = PetLogic.getEquippedPets(playerDataBuffer)
        local petIds: { string } = {}
        for _, def in ipairs(equippedPets) do
            table.insert(petIds, def.id)
        end
        PetVisual.setEquippedPets(petIds)
    end)
end

local function scheduleFullHudApply(data)
    coalescePayload = data
    if coalesceScheduled then return end
    coalesceScheduled = true
    task.defer(function()
        coalesceScheduled = false
        local payload = coalescePayload
        coalescePayload = nil
        if payload then
            applyPlayerPayload(payload)
        end
    end)
end

--[[
    Горячая дельта после копания: только coins/inventory/stats (~4 поля Fusion
    вместо ~30 ×2). Сервер шлёт PlayerHudDelta вместо полного syncPlayerHud.
]]
local function applyMiningHudDelta(delta)
    if typeof(delta) ~= "table" then return end
    PerfBeacon.bump("miningHudDelta")
    if delta.coins ~= nil then playerDataBuffer.coins = delta.coins end
    if delta.inventory ~= nil then playerDataBuffer.inventory = delta.inventory end
    if delta.totalBlocksMined ~= nil then playerDataBuffer.totalBlocksMined = delta.totalBlocksMined end
    if delta.totalCoinsEarned ~= nil then playerDataBuffer.totalCoinsEarned = delta.totalCoinsEarned end
    if hud then
        local t0 = os.clock()
        hud:applyMiningDelta(delta)
        PerfBeacon.addTime("hudMiningDeltaMs", (os.clock() - t0) * 1000)
        PerfBeacon.bump("hudMiningDelta")
    end
    Tutorial.applyStats(delta)
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
    scheduleFullHudApply(data)
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
    scheduleFullHudApply(data)
end)
Net:Connect("PlayerHudDelta", function(delta)
    applyMiningHudDelta(delta)
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
            local modelName = payload.eggModelName
            if not modelName then
                local eggId = payload.eggId
                local eggs = (Constants.PETS or {}).eggs
                local def = eggs and eggId and eggs[eggId]
                modelName = def and def.modelName
            end
            if not modelName then
                local basic = (Constants.PETS or {}).eggs and Constants.PETS.eggs.basic
                modelName = basic and basic.modelName
            end
            PetHatchFX.play(payload.pets, modelName)
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
    -- P2.9: добыта мутировавшая руда — celebration (coin-burst + звук).
    elseif payload.kind == "mutation" then
        pcall(function()
            RewardFX.burst("legendary")
            SoundManager.play("sell_success")
        end)
    elseif payload.kind == "social_reward" then
        pcall(function()
            RewardFX.burst("epic")
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
    renderer:stop() -- сброс сети/очереди перед повторным start (респавн)
    renderer:start()
    hud = HUD.new(player, function()
        HomeFX.play(function()
            pcall(function() Net:Invoke("GoHome") end)
        end)
    end)
    if RunService:IsStudio() then
        log:info("Studio HUD ready (DDHud debug export removed)")
    end
    layerEnvironment:reset()
    layerAmbience:reset()
    -- Фонарик: персонаж новый на каждом респавне → привязываем заново.
    headlamp:attach(character)
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
        headlamp:destroy()
        layerAmbience:destroy()
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
    elseif cmd == "/diagreport" then
        FreezeDiagnostics.report()
    elseif cmd == "/diagstop" then
        FreezeDiagnostics.stop()
    elseif cmd == "/diagstart" then
        FreezeDiagnostics.start({ freezeMs = 100 })
    elseif cmd == "/diagreset" then
        FreezeDiagnostics.reset()
    elseif cmd == "/refreshstand" then
        if RunService:IsStudio() then
            local ok, result = pcall(function()
                return require(ReplicatedStorage:WaitForChild("shared").dev.RefreshOreReferenceStand).refresh()
            end)
            if ok then
                print("[RefreshStand]", result)
            else
                print("[RefreshStand] error:", result)
            end
        end
    elseif cmd == "/help" then
        print("--- Deep Digger Commands ---")
        print("/rarity - toggle rarity strips")
        print("/hpbar - toggle HP bars on hover")
        print("/refreshstand - обновить OreReferenceBlocks_Restyled (Studio)")
        print("/diagreport - печать отчёта о фризах/FPS с причинами")
        print("/diagstop - стоп диагностики (+ финальный отчёт)")
        print("/diagstart - старт диагностики")
        print("/diagreset - сброс и перезапуск диагностики")
        print("/help - this message")
    end
end)

log:info("Client initialized")

local function eggMachineGetCoins(): number
	return playerDataBuffer.coins or 0
end

local function initEggMachines()
	EggMachines.init({ getCoins = eggMachineGetCoins })
end

-- Яйца: не ждём PetKit — proximity и модалка должны работать сразу после спавна.
task.defer(function()
	local eggs = Workspace:WaitForChild("Eggs", 30)
	if eggs then
		initEggMachines()
	else
		warn("[Client:Init] Workspace.Eggs не найден — машины яиц отключены")
	end
end)

task.defer(function()
	Workspace:WaitForChild("SELL", 20)
	Workspace:WaitForChild("UPGRADE", 20)
	local function initHubZones()
		HubZones.init({
			onSell = function()
				SellButton.activate()
			end,
			onUpgrades = function()
				if hud then
					hud:openTab("upgrades")
				end
			end,
			onLeaveUpgrades = function()
				if hud and hud:isUpgradesOpen() then
					hud:closePanel()
				end
			end,
			isUpgradesOpen = function()
				return hud ~= nil and hud:isUpgradesOpen()
			end,
		})
	end
	initHubZones()
	WorldLeaderboard.init()
	player.CharacterAdded:Connect(function()
		task.defer(function()
			HubZones.refresh()
			WorldLeaderboard.refresh()
		end)
	end)
end)

task.spawn(function()
	ReplicatedStorage:WaitForChild("PetKit", 60)
	PetModelKit.invalidateCache()
end)

local localPlayer = Players.LocalPlayer
if localPlayer then
	localPlayer.CharacterAdded:Connect(function()
		task.defer(initEggMachines)
	end)
end
