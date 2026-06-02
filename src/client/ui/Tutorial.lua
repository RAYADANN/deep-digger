--!strict
-- Tutorial.lua — Phase 8, онбординг новичка (polish-итерация).
--
-- Orchestrator над:
--   * `tutorial/TutorialFlow`   — data-driven последовательность сцен;
--   * `tutorial/TutorialDialog` — боттом-диалог наставника с typewriter;
--   * `tutorial/TutorialTracker`— боковой трекер заданий с progress + ✓;
--   * `TutorialArrow`           — стрелка/highlight на target.
--
-- Серверная семантика осталась той же (server tracks 0/1/2/3):
--   0 = NOT_STARTED              → welcome + step 0 (добыть блок)
--   1 = MINED_FIRST_BLOCK         → step 1 (открыть инвент + продать)
--   2 = SOLD_FIRST_ORE            → step 2 (открыть апгрейды + купить кирку)
--   3 = COMPLETED                 → ничего не показываем
--
-- Сцен на клиенте больше (welcome / task / success / finale); они НЕ
-- персистятся на сервере — только server-видимые шаги в TutorialFlow
-- (`SERVER_STEP_AFTER`) триггерят `Net:Invoke("UpdateTutorialStep")`.
--
-- Источник прогресса — серверный `PlayerStats`. Сцены с
-- `completeOn = "tab_inventory" | "tab_upgrades"` слушают локальный клик
-- по tab, остальные ждут изменения totalBlocksMined / totalCoinsEarned /
-- pickaxeLevel из стейтсов.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Net = require(modules.Net)
local TutorialArrow = require(script.Parent.TutorialArrow)
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
    -- baseline-значения PlayerStats на момент входа в сцену с `completeOn`.
    baseBlocks: number,
    baseCoinsEarned: number,
    -- Кеш самых свежих stats — нужен Tutorial.refresh() при респавне.
    lastStats: StatsPayload?,
    statsConn: any?,
    tabConn: any?,
    pollTask: thread?,
    finalizing: boolean,
} = {
    running = false,
    sceneId = nil,
    serverStep = 0,
    dialog = nil,
    tracker = nil,
    arrow = nil,
    baseBlocks = 0,
    baseCoinsEarned = 0,
    lastStats = nil,
    statsConn = nil,
    tabConn = nil,
    pollTask = nil,
    finalizing = false,
}

-- ===================================================================
-- Helpers: cleanup / target search
-- ===================================================================

local function clearArrow()
    if state.arrow then
        state.arrow:destroy()
        state.arrow = nil
    end
end

local function clearTabConn()
    if state.tabConn then
        state.tabConn:Disconnect()
        state.tabConn = nil
    end
end

local function clearPollTask()
    if state.pollTask then
        task.cancel(state.pollTask)
        state.pollTask = nil
    end
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

local function findHudGui(): ScreenGui?
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

-- Стрелка на target сцены. Возвращает true если target нашёлся
-- (нужно для polling — если NIL, попробуем повторно через 0.5с).
local function pointArrowAt(scene: Scene): boolean
    clearArrow()
    local target = scene.target
    if not target or target == "" then
        return true -- сцена без target: ОК.
    end
    local text = scene.arrowText or ""

    if target == "block" then
        local nearest = findNearestBlock()
        if nearest then
            state.arrow = TutorialArrow.pointAt(nearest, text)
            return true
        end
        return false
    end

    local gui = findHudChild(target)
    if gui then
        state.arrow = TutorialArrow.pointAt(gui, text)
        return true
    end
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
--   * `UpgRow_pickaxe`, `SellButton` — появляются после открытия панели;
--   * HUD ещё не создан (PlayerStats прилетел до CharacterAdded) —
--     даже Tab_inventory будет nil несколько кадров.
-- Также реатачит tab-listener, если он не успел подписаться при первом enterScene.
startTargetPolling = function(scene: Scene)
    clearPollTask()
    state.pollTask = task.spawn(function()
        while state.running and state.sceneId == scene.id do
            task.wait(0.6)
            if state.running and state.sceneId == scene.id then
                -- 1) Arrow — пересоздаём если отсутствует ИЛИ это блок
                -- (TutorialArrow прячет UI когда target.Parent == nil, но
                -- сам не мигрирует на новый ближайший).
                local need = false
                if not state.arrow then
                    need = true
                elseif scene.target == "block" then
                    need = true
                end
                if need then
                    pointArrowAt(scene)
                end
                -- 2) Tab-listener — мог не успеть подписаться, если HUD
                -- ещё не был готов на момент enterScene. Пытаемся снова
                -- через attachTabClickListener (без clear, чтобы старая
                -- подписка не сорвалась — но если её нет, attach создаст).
                if state.tabConn == nil
                    and (scene.completeOn == "tab_inventory" or scene.completeOn == "tab_upgrades")
                then
                    attachTabClickListener(scene)
                end
            end
        end
    end)
end

-- Tab-click listener для сцен с `completeOn = "tab_inventory" | "tab_upgrades"`.
-- Альтернатива polling'у PlayerStats (тут стейтсы не меняются от клика
-- по табу — нужен локальный листенер).
attachTabClickListener = function(scene: Scene)
    clearTabConn()
    if scene.completeOn ~= "tab_inventory" and scene.completeOn ~= "tab_upgrades" then
        return
    end
    local tabName = scene.target -- "Tab_inventory" или "Tab_upgrades"
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
            icon = "📜",
        })
    end
end

-- Финализация после задания: показываем `complete()` в трекере, ждём
-- 1.4с пока проиграется галочка, потом переходим к следующей сцене.
-- На этот период трекер сам себя задестроит.
local function completeTrackerAndAdvance()
    if state.tracker then
        state.tracker:complete()
        state.tracker = nil -- TutorialTracker:complete сам деструктится
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

    showDialogForScene(scene)
    if scene.kind == "task" then
        showTrackerForScene(scene)
    end

    -- Стрелка нужна для task-сцен с target. Стартуем поллинг, если target
    -- не нашёлся сразу или может меняться.
    if scene.target then
        local found = pointArrowAt(scene)
        if not found or scene.target == "block" then
            startTargetPolling(scene)
        end
    end

    -- Tab-click listener.
    if scene.completeOn == "tab_inventory" or scene.completeOn == "tab_upgrades" then
        attachTabClickListener(scene)
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
    if typeof(data) ~= "table" then return end
    state.lastStats = data
    if not state.running or not state.sceneId then return end

    local scene = TutorialFlow.getById(state.sceneId)
    if not scene or scene.kind ~= "task" then return end

    local criterion = scene.completeOn
    if not criterion then return end

    if criterion == "block_mined" then
        local now = data.totalBlocksMined or 0
        local progress = math.max(0, now - state.baseBlocks)
        if state.tracker and scene.task and scene.task.goal then
            state.tracker:setProgress(progress, scene.task.goal)
        end
        if now > state.baseBlocks then
            playSuccess()
            completeTrackerAndAdvance()
            goNext()
        end
    elseif criterion == "ore_sold" then
        local now = data.totalCoinsEarned or 0
        if now > state.baseCoinsEarned then
            playSuccess()
            completeTrackerAndAdvance()
            goNext()
        end
    elseif criterion == "pickaxe_bought" then
        local pickaxe = data.pickaxeLevel or 1
        if pickaxe > 1 then
            playSuccess()
            completeTrackerAndAdvance()
            goNext()
        end
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
    if scene.target then
        local found = pointArrowAt(scene)
        if not found or scene.target == "block" then
            startTargetPolling(scene)
        end
    end
    if scene.completeOn == "tab_inventory" or scene.completeOn == "tab_upgrades" then
        attachTabClickListener(scene)
    end
end

return Tutorial
