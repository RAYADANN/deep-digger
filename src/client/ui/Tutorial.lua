--!strict
-- Tutorial.lua — Phase 8, онбординг новичка (polish-итерация).
--
-- Orchestrator над:
--   * `tutorial/TutorialFlow`   — data-driven последовательность сцен;
--   * `tutorial/TutorialDialog` — боттом-диалог наставника с typewriter;
--   * `tutorial/TutorialTracker`— верхний баннер цели с progress + ✓;
--   * `TutorialPathGuide`       — дорожка-маркеры на земле к цели.
--
-- Серверная семантика осталась той же (server tracks 0/1/2/3):
--   0 = NOT_STARTED              → welcome + step 0 (добыть блок)
--   1 = MINED_FIRST_BLOCK         → step 1 (продажа в зоне SELL)
--   2 = SOLD_FIRST_ORE            → step 2 (зона UPGRADE + купить кирку)
--   3 = COMPLETED                 → ничего не показываем
--
-- Сцен на клиенте больше (welcome / task / success / finale); они НЕ
-- персистятся на сервере — только server-видимые шаги в TutorialFlow
-- (`SERVER_STEP_AFTER`) триггерят `Net:Invoke("UpdateTutorialStep")`.
--
-- Источник прогресса — серверный `PlayerStats`. Сцены с `completeOn = "tab_inventory"`
-- слушают клик по табу; `upgrades_ready` — когда видна строка UpgRow_pickaxe;
-- остальные ждут изменения totalBlocksMined / totalCoinsEarned / pickaxeLevel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Net = require(modules.Net)
local TutorialArrow = require(script.Parent.TutorialArrow)
local TutorialPathGuide = require(script.Parent.tutorial.TutorialPathGuide)
local TutorialDialog = require(script.Parent.tutorial.TutorialDialog)
local TutorialTracker = require(script.Parent.tutorial.TutorialTracker)
local TutorialFlow = require(script.Parent.tutorial.TutorialFlow)
local SoundManager = require(script.Parent.Parent.core.SoundManager)

local Tutorial = {}

type StatsPayload = {
    coins: number?,
    totalBlocksMined: number?,
    totalCoinsEarned: number?,
    pickaxeLevel: number?,
    tutorialStep: number?,
}

type Scene = TutorialFlow.Scene

-- Singleton-стейт. Повторные `Tutorial.start` идемпотентны.
local state: {
    running: boolean,
    sceneId: string?,
    serverStep: number,
    dialog: any?,
    tracker: any?,
    arrow: any?,
    arrowGuiTarget: GuiObject?,
    lockedBlockPart: BasePart?,
    pathGuide: TutorialPathGuide.Handle?,
    -- baseline-значения PlayerStats на момент входа в сцену с `completeOn`.
    baseBlocks: number,
    baseCoinsEarned: number,
    -- Кеш самых свежих stats — нужен Tutorial.refresh() при респавне.
    lastStats: StatsPayload?,
    statsConn: any?,
    tabConn: any?,
    pollTask: thread?,
    pollGeneration: number,
    advancing: boolean,
    finalizing: boolean,
} = {
    running = false,
    sceneId = nil,
    serverStep = 0,
    dialog = nil,
    tracker = nil,
    arrow = nil,
    arrowGuiTarget = nil,
    lockedBlockPart = nil,
    pathGuide = nil,
    baseBlocks = 0,
    baseCoinsEarned = 0,
    lastStats = nil,
    statsConn = nil,
    tabConn = nil,
    pollTask = nil,
    pollGeneration = 0,
    advancing = false,
    finalizing = false,
}

-- ===================================================================
-- Helpers: cleanup / target search
-- ===================================================================

local findHudGui: () -> ScreenGui?

local function sweepHudTutorialChrome(hud: Instance)
	for _, desc in hud:GetDescendants() do
		if desc.Name == "TutorialOverlay" or desc.Name == "TutorialOverlayLabel" then
			desc:Destroy()
		end
	end
end

local function clearPathGuide()
    if state.pathGuide then
        state.pathGuide:destroy()
        state.pathGuide = nil
    end
end

local function clearArrow()
    clearPathGuide()
    if state.arrow then
        state.arrow:destroy()
        state.arrow = nil
    end
    state.arrowGuiTarget = nil
    local hud = findHudGui()
    if hud then
        sweepHudTutorialChrome(hud)
    end
end

local function clearTabConn()
    if state.tabConn then
        state.tabConn:Disconnect()
        state.tabConn = nil
    end
end

local function clearPollTask()
    state.pollGeneration += 1
    state.pollTask = nil
end

local function clearDialog()
    if state.dialog then
        state.dialog:destroy()
        state.dialog = nil
    end
end

local function clearTracker()
    if state.tracker then
        state.tracker:destroy()
        state.tracker = nil
    end
end

findHudGui = function(): ScreenGui?
    local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    return pg:FindFirstChild("DeepDiggerHUD") :: ScreenGui?
end

local function findHudChild(name: string): GuiObject?
    local hud = findHudGui()
    if not hud then return nil end
    local found = hud:FindFirstChild(name, true)
    if found and found:IsA("GuiObject") then
        return found :: GuiObject
    end
    return nil
end

local function isGuiChainVisible(gui: GuiObject): boolean
	local node: Instance? = gui
	while node do
		if node:IsA("GuiObject") and not (node :: GuiObject).Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

local function scrollIntoView(gui: GuiObject)
	local scroll = gui:FindFirstAncestorWhichIsA("ScrollingFrame")
	if not scroll then
		return
	end
	local row: Instance? = gui
	while row and row.Parent ~= scroll do
		row = row.Parent
	end
	if not row or not row:IsA("GuiObject") then
		return
	end
	local rowGui = row :: GuiObject
	local y = rowGui.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
	local targetY = math.max(0, y - scroll.AbsoluteSize.Y * 0.2)
	scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, targetY)
end

-- UpgRow_* → только кнопка «+» (BuyButton); строка целиком не подсвечивается.
local function findTutorialGuiTarget(name: string): GuiObject?
	if string.sub(name, 1, 7) == "UpgRow_" then
		local row = findHudChild(name)
		if not row or not isGuiChainVisible(row) or row.AbsoluteSize.X <= 4 then
			return nil
		end
		local buy = row:FindFirstChild("BuyButton")
		if buy and buy:IsA("GuiObject") and buy.Visible and buy.AbsoluteSize.X > 4 then
			scrollIntoView(row)
			return buy :: GuiObject
		end
		return nil
	end
	local found = findHudChild(name)
	if found and found.Visible and found.AbsoluteSize.X > 4 and isGuiChainVisible(found) then
		return found
	end
	return nil
end

local HUB_ZONE_MODELS: { [string]: string } = {
	HubZone_SELL = "SELL",
	HubZone_UPGRADE = "UPGRADE",
}

local function findHubZoneHost(targetName: string): BasePart?
	local modelName = HUB_ZONE_MODELS[targetName]
	if not modelName then
		return nil
	end
	local model = workspace:FindFirstChild(modelName)
	if not model or not model:IsA("Model") then
		return nil
	end
	local core = model:FindFirstChild("LightCore")
	if core and core:IsA("BasePart") then
		return core
	end
	if model.PrimaryPart then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function isUpgradesPanelReady(): boolean
	return findTutorialGuiTarget("UpgRow_pickaxe") ~= nil
end

local function parseBlockKey(name: string): (number?, number?, number?)
	local parts = string.split(name, "_")
	return tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
end

local function isTutorialBlockValid(part: BasePart?): boolean
	if not part or not part.Parent then
		return false
	end
	if part:GetAttribute("_destroying") then
		return false
	end
	return true
end

local function findNearestBlock(): BasePart?
    local folder = workspace:FindFirstChild("DeepDigger_Mine")
    if not folder then return nil end
    local player = Players.LocalPlayer
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local origin = (root and (root :: BasePart).Position) or Vector3.new(0, 0, 30)

    local best: BasePart? = nil
    local bestDist = math.huge
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") then
            local d = (child.Position - origin).Magnitude
            if d < bestDist then
                bestDist = d
                best = child :: BasePart
            end
        end
    end
    return best
end

-- Первый блок туториала: один раз выбираем ближайший блок поверхности (y=0)
-- и держим пин на нём, пока не сломают (не перескакиваем на «ближайший к игроку»).
local function findTutorialBlockTarget(): BasePart?
	if isTutorialBlockValid(state.lockedBlockPart) then
		return state.lockedBlockPart
	end
	state.lockedBlockPart = nil

	local folder = workspace:FindFirstChild("DeepDigger_Mine")
	if not folder then
		return nil
	end
	local player = Players.LocalPlayer
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local origin = (root and (root :: BasePart).Position) or Vector3.new(0, 0, 30)

	local bestSurface: BasePart? = nil
	local bestSurfaceDist = math.huge
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and isTutorialBlockValid(child :: BasePart) then
			local _, _, depth = parseBlockKey(child.Name)
			if depth == 0 then
				local d = ((child :: BasePart).Position - origin).Magnitude
				if d < bestSurfaceDist then
					bestSurfaceDist = d
					bestSurface = child :: BasePart
				end
			end
		end
	end

	local chosen = bestSurface or findNearestBlock()
	if chosen then
		state.lockedBlockPart = chosen
	end
	return chosen
end

local function setTutorialMineHint(active: boolean)
	workspace:SetAttribute("DD_TutorialMineHint", active)
end

local function mergeStats(data: StatsPayload): StatsPayload
    local merged: StatsPayload = state.lastStats or {}
    for key, value in pairs(data) do
        (merged :: any)[key] = value
    end
    state.lastStats = merged
    return merged
end

local function evaluateTaskProgress(scene: Scene, data: StatsPayload): boolean
    if not state.running or state.sceneId ~= scene.id or state.advancing then
        return false
    end
    if scene.kind ~= "task" then
        return false
    end
    local criterion = scene.completeOn
    if not criterion then
        return false
    end

    if criterion == "block_mined" then
        local now = data.totalBlocksMined or 0
        local progress = math.max(0, now - state.baseBlocks)
        if state.tracker and scene.task and scene.task.goal then
            state.tracker:setProgress(progress, scene.task.goal)
        end
        if now > state.baseBlocks then
            return true
        end
    elseif criterion == "ore_sold" then
        local now = data.totalCoinsEarned or 0
        if now > state.baseCoinsEarned then
            return true
        end
    elseif criterion == "pickaxe_bought" then
        if (data.pickaxeLevel or 1) > 1 then
            return true
        end
    elseif criterion == "upgrades_ready" then
        return isUpgradesPanelReady()
    end
    return false
end

local function notifyServer(step: number)
    pcall(function()
        Net:Invoke("UpdateTutorialStep", step)
    end)
end

local function playClick()
    pcall(function() SoundManager.play("ui_click") end)
end

local function playSuccess()
    pcall(function() SoundManager.play("sell_success") end)
end

-- ===================================================================
-- Target acquisition
-- ===================================================================

-- forward declare для взаимного вызова arrow → tab click → next arrow.
local enterScene: (sceneId: string) -> ()
local advanceTo: (sceneId: string) -> ()
local goNext: () -> ()
local tryCompleteUpgradesReady: (scene: Scene) -> ()
local completeTaskAndAdvance: (scene: Scene) -> ()

local function sceneUsesGuiUpgradeTarget(scene: Scene): boolean
	local target = scene.target
	return target ~= nil and string.sub(target, 1, 7) == "UpgRow_"
end

local function sceneUsesWorldPath(scene: Scene): boolean
	if not scene.target then
		return false
	end
	return scene.target == "block" or HUB_ZONE_MODELS[scene.target] ~= nil
end

local function startWorldPath(target: Vector3 | BasePart)
	clearPathGuide()
	state.pathGuide = TutorialPathGuide.follow(target)
end

-- Стрелка на target сцены. Возвращает true если target нашёлся
-- (нужно для polling — если NIL, попробуем повторно через 0.5с).
local function pointArrowAt(scene: Scene): boolean
    local target = scene.target
    if not target or target == "" then
        clearArrow()
        return true
    end
    local text = scene.arrowText or ""

    if target == "block" then
        local blockPart = findTutorialBlockTarget()
        if not blockPart then
            return false
        end
        if state.arrow and state.lockedBlockPart == blockPart then
            if state.pathGuide then
                state.pathGuide:setTarget(blockPart)
            else
                startWorldPath(blockPart)
            end
            return true
        end
        clearArrow()
        state.lockedBlockPart = blockPart
        state.arrow = TutorialArrow.pointAt(blockPart, text)
        startWorldPath(blockPart)
        return true
    end

    local hubHost = findHubZoneHost(target)
    if hubHost then
        clearArrow()
        state.arrow = TutorialArrow.pointAt(hubHost, text)
        startWorldPath(hubHost)
        return true
    end

    local gui = findTutorialGuiTarget(target)
    if gui then
        if state.arrowGuiTarget == gui and state.arrow then
            return true
        end
        clearArrow()
        state.arrow = TutorialArrow.pointAt(gui, text)
        state.arrowGuiTarget = gui
        return true
    end

    clearArrow()
    return false
end

-- Forward-declare: startTargetPolling вызывает attachTabClickListener
-- (для ретая подписки на таб, если HUD ещё не был готов), а
-- attachTabClickListener вызывает goNext, который вызывает enterScene,
-- который вызывает startTargetPolling. Нужны forward-locals.
local startTargetPolling: (scene: Scene) -> ()
local attachTabClickListener: (scene: Scene) -> ()

-- Стартует поллинг для сцен где target может появляться с задержкой:
--   * `block` — блоки рендерятся когда сервер пришлёт snapshot;
--   * `UpgRow_pickaxe` — появляется после открытия панели улучшений;
--   * `HubZone_SELL` / `HubZone_UPGRADE` — модели зон в Workspace.
--   * HUD ещё не создан (PlayerStats прилетел до CharacterAdded) —
--     даже Tab_inventory будет nil несколько кадров.
-- Также реатачит tab-listener, если он не успел подписаться при первом enterScene.
startTargetPolling = function(scene: Scene)
    clearPollTask()
    local gen = state.pollGeneration
    state.pollTask = task.spawn(function()
        while state.running and state.sceneId == scene.id and gen == state.pollGeneration do
            task.wait(0.45)
            if state.running and state.sceneId == scene.id and gen == state.pollGeneration then
                local need = false
                if not state.arrow then
                    need = true
                elseif scene.target == "block" then
                    need = not state.arrow or not isTutorialBlockValid(state.lockedBlockPart)
                elseif HUB_ZONE_MODELS[scene.target or ""] ~= nil then
                    need = true
                elseif sceneUsesGuiUpgradeTarget(scene) then
                    need = true
                end
                if need then
                    pointArrowAt(scene)
                elseif sceneUsesWorldPath(scene) and state.pathGuide == nil then
                    local t = scene.target
                    if t == "block" then
                        local locked = findTutorialBlockTarget()
                        if locked then
                            startWorldPath(locked)
                        end
                    elseif t then
                        local host = findHubZoneHost(t)
                        if host then
                            startWorldPath(host)
                        end
                    end
                end
                if state.tabConn == nil and scene.completeOn == "tab_inventory" then
                    attachTabClickListener(scene)
                end
                local stats = state.lastStats
                if stats and evaluateTaskProgress(scene, stats) then
                    completeTaskAndAdvance(scene)
                end
            end
        end
    end)
end

-- Tab-click listener для сцен с `completeOn = "tab_inventory"`.
attachTabClickListener = function(scene: Scene)
    clearTabConn()
    if scene.completeOn ~= "tab_inventory" then
        return
    end
    local tabName = scene.target
    if not tabName then return end
    local tab = findHudChild(tabName)
    if not tab then return end
    if not (tab:IsA("TextButton") or tab:IsA("ImageButton")) then
        return
    end
    state.tabConn = (tab :: any).Activated:Connect(function()
        if not state.running or state.sceneId ~= scene.id then return end
        -- Дадим панели раскрыться (TabBar анимирует ~0.1с), затем продвинем.
        task.delay(0.1, function()
            if state.running and state.sceneId == scene.id then
                goNext()
            end
        end)
    end)
end

-- ===================================================================
-- Scene rendering
-- ===================================================================

local function showDialogForScene(scene: Scene)
    -- Если диалог уже создан и игрок прокликивает — обновляем содержимое
    -- (cheaper чем destroy → create заново).
    if state.dialog then
        state.dialog:update({
            speaker = scene.speaker,
            name = scene.name,
            text = scene.text,
            kind = scene.kind,
            hideAdvanceButton = scene.hideAdvanceButton or false,
            onAdvance = function()
                playClick()
                if state.running and state.sceneId == scene.id then
                    goNext()
                end
            end,
            onSkip = function()
                playClick()
                Tutorial.skip()
            end,
        })
        return
    end

    state.dialog = TutorialDialog.show({
        speaker = scene.speaker,
        name = scene.name,
        text = scene.text,
        kind = scene.kind,
        hideAdvanceButton = scene.hideAdvanceButton or false,
        onAdvance = function()
            playClick()
            if state.running and state.sceneId == scene.id then
                goNext()
            end
        end,
        onSkip = function()
            playClick()
            Tutorial.skip()
        end,
    })
end

local function showTrackerForScene(scene: Scene)
    if not scene.task then
        clearTracker()
        return
    end
    local task_ = scene.task
    if state.tracker then
        state.tracker:update({
            title = task_.title,
            description = task_.description,
            goal = task_.goal,
        })
        if task_.goal then
            state.tracker:setProgress(0, task_.goal)
        end
    else
        state.tracker = TutorialTracker.show({
            title = task_.title,
            description = task_.description,
            goal = task_.goal,
            icon = if scene.id == "step_0_task"
                then "upg_pickaxe"
                elseif scene.id == "step_1_sell"
                then "coin"
                elseif scene.id == "step_2_go_upgrades"
                then "tab_upgrades"
                elseif scene.id == "step_2_buy_pickaxe"
                then "upg_pickaxe"
                else "tab_journal",
        })
    end
end

-- Финализация после задания: показываем `complete()` в трекере, ждём
-- 1.4с пока проиграется галочка, потом переходим к следующей сцене.
-- На этот период трекер сам себя задестроит.
local function completeTrackerAndAdvance()
    if state.tracker then
        state.tracker:complete()
        state.tracker = nil
    end
end

completeTaskAndAdvance = function(scene: Scene)
    if state.advancing or not state.running or state.sceneId ~= scene.id then
        return
    end
    state.advancing = true
    playSuccess()
    completeTrackerAndAdvance()
    task.delay(0.45, function()
        state.advancing = false
        if state.running and state.sceneId == scene.id then
            goNext()
        end
    end)
end

tryCompleteUpgradesReady = function(scene: Scene)
    local stats = state.lastStats or {}
    if evaluateTaskProgress(scene, stats) then
        completeTaskAndAdvance(scene)
    end
end

-- ===================================================================
-- State machine
-- ===================================================================

-- Сохраняем baseline только для server-step-meaningful сцен. Для task-сцен
-- с `completeOn` сюда фиксируется текущее значение `lastStats`, чтобы
-- `onPlayerStats` понимал «выросло относительно начала сцены».
local function captureBaseline(scene: Scene)
    local stats = state.lastStats or {} :: StatsPayload
    if scene.completeOn == "block_mined" then
        state.baseBlocks = stats.totalBlocksMined or 0
    elseif scene.completeOn == "ore_sold" then
        state.baseCoinsEarned = stats.totalCoinsEarned or 0
    end
end

enterScene = function(sceneId: string)
    local scene = TutorialFlow.getById(sceneId)
    if not scene then
        Tutorial.destroy()
        return
    end

    state.sceneId = sceneId
    state.advancing = false
    if scene.target == "block" then
        setTutorialMineHint(true)
    else
        setTutorialMineHint(false)
        state.lockedBlockPart = nil
    end
    clearArrow()
    clearTabConn()
    clearPollTask()
    -- Трекер не чистим тут — completeTrackerAndAdvance сам это сделает
    -- между задачей и success-сценой. Зато при переходе на новую задачу
    -- (task → task) нужно сбросить.
    if scene.kind ~= "task" then
        clearTracker()
    elseif state.tracker == nil then
        -- ok, create later
    end

    captureBaseline(scene)

    local statsNow = state.lastStats
    if statsNow and scene.kind == "task" and evaluateTaskProgress(scene, statsNow) then
        task.defer(function()
            if state.running and state.sceneId == sceneId then
                completeTaskAndAdvance(scene)
            end
        end)
    end

    showDialogForScene(scene)
    if scene.kind == "task" then
        showTrackerForScene(scene)
    end

    -- Стрелка нужна для task-сцен с target. Стартуем поллинг, если target
    -- не нашёлся сразу или может меняться.
    if scene.target or scene.completeOn == "upgrades_ready" then
        local found = if scene.target then pointArrowAt(scene) else true
        local hubTarget = scene.target and HUB_ZONE_MODELS[scene.target] ~= nil
        local needsPoll = not found
            or scene.target == "block"
            or hubTarget
            or scene.target == "UpgRow_pickaxe"
            or scene.completeOn == "upgrades_ready"
        if needsPoll then
            startTargetPolling(scene)
        end
    end

    if scene.completeOn == "tab_inventory" then
        attachTabClickListener(scene)
    elseif scene.completeOn == "upgrades_ready" and isUpgradesPanelReady() then
        task.defer(function()
            if state.running and state.sceneId == scene.id then
                tryCompleteUpgradesReady(scene)
            end
        end)
    end

    -- Если сцена помечена SERVER_STEP_AFTER — это переход «после успеха»;
    -- информируем сервер о новом шаге. Делаем это как только показываем
    -- success-сцену, чтобы при дисконнекте игрок не зацикливался на
    -- задании, которое уже выполнил.
    local serverStep = TutorialFlow.SERVER_STEP_AFTER[sceneId]
    if serverStep and serverStep > state.serverStep then
        state.serverStep = serverStep
        notifyServer(serverStep)
    end

    -- Final scene: проигрываем виктори-звук и автоматически закрываем
    -- через 5 секунд (или по клику Понятно).
    if scene.kind == "finale" then
        playSuccess()
        task.delay(5.5, function()
            if state.running and state.sceneId == sceneId then
                Tutorial.destroy()
            end
        end)
    elseif scene.kind == "success" then
        playSuccess()
    end
end

goNext = function()
    if not state.sceneId then return end
    local nextScene = TutorialFlow.getNext(state.sceneId)
    if not nextScene then
        Tutorial.destroy()
        return
    end
    enterScene(nextScene.id)
end

advanceTo = function(sceneId: string)
    if state.sceneId == sceneId then return end
    enterScene(sceneId)
end

-- ===================================================================
-- PlayerStats listener: автоматическое продвижение task-сцен
-- ===================================================================

local function onPlayerStats(data: StatsPayload)
    if typeof(data) ~= "table" then
        return
    end
    local merged = mergeStats(data)
    if not state.running or not state.sceneId then
        return
    end
    local scene = TutorialFlow.getById(state.sceneId)
    if not scene then
        return
    end
    if evaluateTaskProgress(scene, merged) then
        completeTaskAndAdvance(scene)
    end
end

-- ===================================================================
-- Public API
-- ===================================================================

--[[
    Запуск туториала. Идемпотентен: повторные вызовы при одинаковом
    serverStep — no-op; при изменении serverStep (после /reset или
    переходе) — переключаем сцену.
]]
function Tutorial.start(initialStep: number?, initialStats: StatsPayload?)
    local serverStep = math.floor(tonumber(initialStep) or 0)
    state.lastStats = initialStats

    -- Если туториал пройден на сервере — ничего не показываем.
    if serverStep >= 3 then
        if state.running then
            Tutorial.destroy()
        end
        return
    end

    -- Уже работаем и serverStep тот же → no-op.
    if state.running and state.serverStep == serverStep then
        return
    end

    -- Запустить с правильной точки входа.
    local entryId = TutorialFlow.ENTRY_BY_SERVER_STEP[serverStep]
    if not entryId then
        if state.running then
            Tutorial.destroy()
        end
        return
    end

    state.running = true
    state.serverStep = serverStep
    state.baseBlocks = (initialStats and initialStats.totalBlocksMined) or 0
    state.baseCoinsEarned = (initialStats and initialStats.totalCoinsEarned) or 0

    -- Подписка на PlayerStats живёт до Tutorial.destroy(). Защита от
    -- двойной подписки: если повторный start попадает в эту ветку
    -- (например, после /reset на другом serverStep) — сначала отключаем.
    if state.statsConn then
        pcall(function() state.statsConn:Disconnect() end)
        state.statsConn = nil
    end
    state.statsConn = Net:Connect("PlayerStats", onPlayerStats)

    enterScene(entryId)
end

function Tutorial.destroy()
    if state.finalizing then return end
    state.finalizing = true

    state.running = false
    state.sceneId = nil
    setTutorialMineHint(false)
    state.lockedBlockPart = nil

    if state.statsConn then
        pcall(function() state.statsConn:Disconnect() end)
        state.statsConn = nil
    end
    clearArrow()
    clearTabConn()
    clearPollTask()
    clearDialog()
    clearTracker()

    state.finalizing = false
end

--[[
    Принудительное завершение туториала (кнопка ✕ в диалоге или /skiptut).
    Уведомляем сервер выставить tutorialStep = 3 и destroy локально.
]]
function Tutorial.skip()
    if not state.running then return end
    notifyServer(3)
    state.serverStep = 3
    Tutorial.destroy()
end

function Tutorial.currentStep(): number
    return state.serverStep
end

function Tutorial.applyStats(data: StatsPayload)
    onPlayerStats(data)
end

function Tutorial.isRunning(): boolean
    return state.running
end

--[[
    Пересоздать UI после respawn персонажа: HUD пересоздан, наши Arrow-
    handle указывают на destroyed-инстансы. Повторно входим в текущую
    сцену — это пересоберёт стрелку, но НЕ диалог/трекер (они живут в
    отдельном `DeepDigger_Tutorial` ScreenGui с ResetOnSpawn=false).
]]
function Tutorial.refresh()
    if not state.running or not state.sceneId then return end
    local sceneId = state.sceneId
    -- Хитрость: пересоздаём только arrow и tab-listener — диалог/трекер
    -- не трогаем. Для этого временно сбрасываем sceneId, потом enterScene
    -- сделает всё чисто.
    local scene = TutorialFlow.getById(sceneId)
    if not scene then return end
    clearArrow()
    clearTabConn()
    clearPollTask()
    if scene.target or scene.completeOn == "upgrades_ready" then
        local found = if scene.target then pointArrowAt(scene) else true
        local hubTarget = scene.target and HUB_ZONE_MODELS[scene.target] ~= nil
        local needsPoll = not found
            or scene.target == "block"
            or hubTarget
            or scene.target == "UpgRow_pickaxe"
            or scene.completeOn == "upgrades_ready"
        if needsPoll then
            startTargetPolling(scene)
        end
    end
    if scene.completeOn == "tab_inventory" then
        attachTabClickListener(scene)
    elseif scene.completeOn == "upgrades_ready" and isUpgradesPanelReady() then
        task.defer(function()
            if state.running and state.sceneId == scene.id then
                tryCompleteUpgradesReady(scene)
            end
        end)
    end
end

return Tutorial
