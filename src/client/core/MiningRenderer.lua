--!strict
-- MiningRenderer.lua — 3D рендер шахты (поверхность + чанки)

local shared = game:GetService("ReplicatedStorage"):WaitForChild("shared")
local modules = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Logger = require(shared.util.Logger)
local Constants = require(shared.constants)
local LayerProfile = require(shared.data.LayerProfile)
local UpgradeLogic = require(shared.util.UpgradeLogic)
local PerfBeacon = require(shared.util.PerfBeacon)
local OreFXPalette = require(shared.util.OreFXPalette)
local OreBlockDecor = require(shared.util.OreBlockDecor)
-- P2.9: оттенок/название мутации руды (единый источник client+server).
local MutationLogic = require(shared.util.MutationLogic)
local MiningBlockDecor = require(script.Parent.MiningBlockDecor)
local MiningReach = require(shared.util.MiningReach)
local MineZoneWorkspace = require(shared.util.MineZoneWorkspace)
local Net = require(modules.Net)
local OreLookup = require(script.Parent.OreLookup)
local SoundManager = require(script.Parent.SoundManager)
local CameraShake = require(script.Parent.CameraShake)
local Haptics = require(script.Parent.Haptics)

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

-- Луч прицела: ищем блок вдоль взгляда; дистанция от персонажа — MAX_MINE_REACH_BLOCKS.
local RAYCAST_MAX_DISTANCE = 200

local function appendMiningRaycastExcludes(exclude: { Instance })
	for _, name in ({ "MineZoneMarker", "DeepDigger_TutorialPath", "MineRespawn" } :: { string }) do
		local inst = workspace:FindFirstChild(name)
		if inst then
			table.insert(exclude, inst)
		end
	end
end

-- Сколько ждать появления MineZoneMarker (репликация/стриминг) до создания
-- блоков. Пока маркер не готов — блоки висят в очереди (не кладутся на фоллбэк).
-- После таймаута используется фоллбэк-точка, чтобы шахта не зависла невидимой
-- при реально отсутствующем/неверно настроенном маркере.
local ORIGIN_WAIT_TIMEOUT = 15

-- Бюджет создания блоков на кадр. Сервер при пробитии полости/комнаты шлёт
-- дельту на десятки-сотни блоков; если строить их все синхронно в одном
-- кадре — фриз 400–650 мс (замерено). Размазываем создание по кадрам:
-- очередь дренируется по CREATE_BUDGET_PER_FRAME штук за Heartbeat.
-- 25/кадр: стартовый снапшот (~2250) раскладывается за ~1.5 c, всплеск
-- delta на 137 блоков — за ~6 кадров (~100 мс) вместо одного фриза.
local CREATE_BUDGET_PER_FRAME = 50

-- Массовое удаление в одной delta (комната/полость) — десятки _animateDestroy
-- подряд, каждый с chunkBurst + dust + shockwave = фриз 400–1300 мс (замерено:
-- Delta «-39» в одном кадре). Одиночный удар игрока = 1 removed → полный juice.
local FAST_REMOVE_THRESHOLD = 3

-- ===== Perf-инструментация (диагностика дублей подписки SyncBlocks) =====
-- Публикуем счётчики атрибутами на workspace, чтобы читать из command bar / MCP
-- во время Play (execute_luau видит инстансы клиента, но его _G изолирован от
-- LocalScript-VM, поэтому атрибуты — надёжный общий канал).
-- DD_syncListeners — активных подписок SyncBlocks (ждём ровно 1 после N респавнов).
-- DD_dupFires — сколько раз ОДИН И ТОТ ЖЕ message обработан повторно (>0 = утечка
-- листенера: Net вызывает все коннекшены с одной и той же таблицей message).
-- DD_maxBatchCreated — самый большой created-батч за дельту.
local PERF = {
    syncListeners = 0,
    deltaCalls = 0,
    snapshotCalls = 0,
    dupFires = 0,
    lastBatchCreated = 0,
    maxBatchCreated = 0,
    totalCreatedSeen = 0,
    createPartCount = 0,
    createPartMsSum = 0,
    createPartMsMax = 0,
    drainMsMax = 0,
    applyDeltaMsMax = 0,
    fastRemoves = 0,
    _seen = setmetatable({}, { __mode = "k" }), -- weak: message -> os.clock()
}
local function perfPublish()
    workspace:SetAttribute("DD_syncListeners", PERF.syncListeners)
    workspace:SetAttribute("DD_deltaCalls", PERF.deltaCalls)
    workspace:SetAttribute("DD_snapshotCalls", PERF.snapshotCalls)
    workspace:SetAttribute("DD_dupFires", PERF.dupFires)
    workspace:SetAttribute("DD_lastBatchCreated", PERF.lastBatchCreated)
    workspace:SetAttribute("DD_maxBatchCreated", PERF.maxBatchCreated)
    workspace:SetAttribute("DD_totalCreatedSeen", PERF.totalCreatedSeen)
    if PERF.createPartCount > 0 then
        workspace:SetAttribute("DD_createPartMsAvg", math.floor(PERF.createPartMsSum / PERF.createPartCount))
        workspace:SetAttribute("DD_createPartMsMax", math.floor(PERF.createPartMsMax))
    end
    workspace:SetAttribute("DD_drainMsMax", math.floor(PERF.drainMsMax))
    workspace:SetAttribute("DD_applyDeltaMsMax", math.floor(PERF.applyDeltaMsMax))
    workspace:SetAttribute("DD_fastRemoves", PERF.fastRemoves)
end

local function parseKey(k: string): (number, number, number)
    local parts = string.split(k, "_")
    return tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0
end

local MiningRenderer = {}
MiningRenderer.__index = MiningRenderer

local BS = Constants.BLOCK_SIZE_STUDS
local BSv = Vector3.new(BS, BS, BS)
local HOVER_BSv = BSv * 1.05

-- ===== Phase 7: Mining-style juice helpers =====
-- Принципы:
--   1. Фидбек локализован в точке блока (chunks + dust + shockwave-сфера),
--      а НЕ в глазах игрока (никакого fullscreen flash, никакого slow-mo).
--   2. Camera shake — только на разрушении и только начиная с rare. На каждом
--      hit'е и крите его НЕТ: игрок кликает 4 раза в секунду, любая тряска
--      превращается в эпилептический припадок.
--   3. Главный фидбек майнинга — coin-pop ("+5 💰"), вылетающий из блока.
--      Это то, ради чего игрок копает, и именно это должно быть видно ярче всего.
--   4. Chunks — настоящие Part'ы с физикой (gravity + LinearVelocity), а не
--      sparkle-частицы. Это "руда разлетелась на куски", не "магия".

-- Сколько физических осколков на break, по rarity. На каждом chunk'е GC висит
-- через Debris. Урезано (perf): common-руды = 80% копания, лишние парты с
-- физикой на каждом разрушении = микрофризы при быстром копании.
local BREAK_CHUNK_COUNT = {
    common = 3,
    uncommon = 4,
    rare = 6,
    epic = 9,
    legendary = 14,
    mythic = 20,
}
local BREAK_DUST_COUNT = {
    common = 4,
    uncommon = 5,
    rare = 8,
    epic = 11,
    legendary = 16,
    mythic = 22,
}
local BREAK_CHUNK_SPEED = {
    common = 10,
    uncommon = 12,
    rare = 14,
    epic = 16,
    legendary = 20,
    mythic = 26,
}
-- Shockwave (расширяющаяся neon-сфера в точке блока). Локальный взрыв,
-- видный только если игрок смотрит в его сторону — это сильнее «глобальной»
-- screen-vignette, потому что подсказывает «что-то редкое произошло ЗДЕСЬ».
-- nil = не показывать (common / uncommon).
local SHOCKWAVE_BY_RARITY: { [string]: { size: number, duration: number } } = {
    rare = { size = BS * 2.8, duration = 0.35 },
    epic = { size = BS * 3.8, duration = 0.45 },
    legendary = { size = BS * 5.5, duration = 0.55 },
    mythic = { size = BS * 8.0, duration = 0.7 },
}

local function shortNumber(n: number): string
    if n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(n) end
end

-- ===== Rarity-driven block identity (visual telegraph) =====
-- Каждый блок «читается» по редкости ещё ДО клика: материал, блеск, свечение
-- и частицы намекают «тут что-то ценное». Перформанс: PointLight / частицы
-- создаются ТОЛЬКО для rare+ (их единицы среди тысяч common-блоков), поэтому
-- 2250 common-блоков остаются дешёвыми (SmoothPlastic без света).
--
-- PointLight epic+ ограничен MAX_ORE_GLOWS (proximity, см. _refreshBlockDecorations).
local MAX_ORE_GLOWS = 80

local function smoothSurfaces(p: BasePart)
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.LeftSurface = Enum.SurfaceType.Smooth
    p.RightSurface = Enum.SurfaceType.Smooth
    p.FrontSurface = Enum.SurfaceType.Smooth
    p.BackSurface = Enum.SurfaceType.Smooth
end

local FILLER_WEIGHT = OreBlockDecor.FILLER_WEIGHT
-- Накидки только в конусе камеры (как ambient/glow — не на все 500 блоков сразу).
local MAX_VISIBLE_SHELLS = 140
local DECOR_RANGE = 96
local DECOR_FOV_ATTACH = 0.38
local DECOR_FOV_KEEP = 0.24
local DECOR_FOV_WEIGHT = 52

local AMBIENT_FX_FOLDER = "OreAmbientFX"
local AMBIENT_FX_HOLDER = "AmbientFXHolder"
local AMBIENT_FX_RARITY: { [string]: boolean } = {
    uncommon = true, rare = true, epic = true, legendary = true, mythic = true,
}
local AMBIENT_FX_RANGE = 96
local SHELL_RANGE = 128
local AMBIENT_FX_TICK = 0.175
local MAX_AMBIENT_FX = 80

-- Shockwave: расширяющаяся neon-сфера. Это "ударная волна" в точке разрушения.
-- Полностью локальный эффект — никаких ScreenGui, никаких CC-эффектов.
local function shockwave(parent: Instance, position: Vector3, color: Color3, finalSize: number, duration: number)
    PerfBeacon.bump("fxShockwave")
    local sphere = Instance.new("Part")
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(0.5, 0.5, 0.5)
    sphere.Position = position
    sphere.Anchored = true
    sphere.CanCollide = false; sphere.CanTouch = false; sphere.CastShadow = false
    sphere.Material = Enum.Material.ForceField -- "edge-glow" вид: видна только оболочка
    sphere.Color = color
    sphere.Transparency = 0.2
    sphere.Parent = parent
    TweenService:Create(sphere, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = Vector3.new(finalSize, finalSize, finalSize),
        Transparency = 1,
    }):Play()
    Debris:AddItem(sphere, duration + 0.1)
end

-- Chunks: реальные Part'ы с физикой. Это и есть "руда разлетелась на куски" —
-- ключевой mining-эффект. SmoothPlastic + цвет руды, gravity-affected, fade
-- через Debris.
local function chunkBurst(parent: Instance, position: Vector3, color: Color3, count: number, scatter: number)
    PerfBeacon.bump("fxChunks", count)
    local chunkSize = BS * 0.18
    for _ = 1, count do
        local size = chunkSize * (0.6 + math.random() * 0.7)
        local chunk = Instance.new("Part")
        chunk.Size = Vector3.new(size, size, size)
        chunk.CFrame = CFrame.new(position + Vector3.new(
            (math.random() - 0.5) * BS * 0.4,
            (math.random() - 0.5) * BS * 0.4,
            (math.random() - 0.5) * BS * 0.4
        )) * CFrame.Angles(
            math.random() * math.pi * 2,
            math.random() * math.pi * 2,
            math.random() * math.pi * 2
        )
        chunk.Anchored = false
        chunk.CanCollide = false; chunk.CanTouch = false; chunk.CastShadow = false
        chunk.Material = Enum.Material.SmoothPlastic
        chunk.Color = color
        chunk.Massless = true
        chunk.Parent = parent

        local dir = Vector3.new(
            (math.random() - 0.5) * 2,
            math.random() * 1.5 + 0.4, -- bias upward — куски летят "из" блока вверх
            (math.random() - 0.5) * 2
        )
        if dir.Magnitude > 0 then
            dir = dir.Unit
        end
        chunk.AssemblyLinearVelocity = dir * scatter
        chunk.AssemblyAngularVelocity = Vector3.new(
            (math.random() - 0.5) * 30,
            (math.random() - 0.5) * 30,
            (math.random() - 0.5) * 30
        )

        task.delay(0.7, function()
            if chunk.Parent then
                TweenService:Create(chunk, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
            end
        end)
        Debris:AddItem(chunk, 1.4)
    end
end

-- Dust cloud: облако пыли цвета руды. Используется smoke_main (не sparkle) —
-- даёт ощущение "блок осыпался", а не "магическая вспышка".
local function dustCloud(host: BasePart, color: Color3, count: number, scale: number?, lightEmission: number?)
    PerfBeacon.bump("fxDust")
    local s = scale or 1
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxasset://textures/particles/smoke_main.dds"
    e.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(1, Color3.new(color.R * 0.45, color.G * 0.45, color.B * 0.45)),
    })
    e.LightEmission = lightEmission or 0
    e.LightInfluence = 1
    e.Rate = 0
    e.Lifetime = NumberRange.new(0.5 * s, 1.0 * s)
    e.Speed = NumberRange.new(2, 5 + 2 * s)
    e.SpreadAngle = Vector2.new(180, 180)
    e.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8 * s),
        NumberSequenceKeypoint.new(1, 2.2 * s),
    })
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(0.6, 0.7),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-90, 90)
    e.VelocityInheritance = 0
    e.Acceleration = Vector3.new(0, 1.5, 0) -- пыль чуть всплывает
    e.Enabled = false
    e.Parent = host
    e:Emit(count)
end

-- Coin-pop: всплывающее "+X 💰" из позиции блока. Это сердце mining-feedback'а —
-- игрок копает РАДИ ЭТОГО, и каждое разрушение должно показывать награду.
local function coinPop(parent: Instance, position: Vector3, value: number, rarity: string)
    if value <= 0 then return end
    PerfBeacon.bump("fxCoinPop")
    local host = Instance.new("Part")
    host.Size = Vector3.new(0.1, 0.1, 0.1)
    host.Anchored = true; host.CanCollide = false; host.CanTouch = false
    host.Transparency = 1; host.Position = position; host.Parent = parent

    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.fromOffset(150, 44)
    gui.StudsOffset = Vector3.new(0, 1.5, 0)
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Parent = host

    local isBig = rarity == "rare" or rarity == "epic" or rarity == "legendary" or rarity == "mythic"
    local row = Instance.new("Frame")
    row.Size = UDim2.fromScale(1, 1)
    row.BackgroundTransparency = 1
    row.Parent = gui

    local coinIcon = Instance.new("ImageLabel")
    coinIcon.Size = UDim2.fromOffset(isBig and 26 or 20, isBig and 26 or 20)
    coinIcon.Position = UDim2.new(0.5, isBig and -52 or -42, 0.5, isBig and -13 or -10)
    coinIcon.BackgroundTransparency = 1
    coinIcon.Image = UiAssets.coin()
    coinIcon.ScaleType = Enum.ScaleType.Fit
    coinIcon.Parent = row

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1
    l.Text = "+" .. shortNumber(value)
    l.Font = Enum.Font.GothamBlack
    l.TextSize = isBig and 28 or 22
    l.TextColor3 = Color3.fromRGB(255, 215, 90)
    l.TextStrokeTransparency = 0
    l.TextStrokeColor3 = Color3.fromRGB(40, 25, 0)
    l.Parent = row

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 50, 0)
    stroke.Thickness = isBig and 2 or 1.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Parent = l

    -- Bounce-in (mining-сим читается мягко, без шутерного overshoot).
    l.TextSize = 1
    TweenService:Create(l, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextSize = isBig and 28 or 22,
    }):Play()

    local startedAt = os.clock()
    local TOTAL = 1.3
    local HOLD = 0.7
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local el = os.clock() - startedAt
        if el > TOTAL then
            conn:Disconnect()
            if host.Parent then host:Destroy() end
            return
        end
        gui.StudsOffset = Vector3.new(0, 1.5 + el * 3.2, 0)
        if el > HOLD then
            local a = (el - HOLD) / (TOTAL - HOLD)
            l.TextTransparency = a
            stroke.Transparency = a
        end
    end)
end

-- Block squash: блок чуть приплющивается при ударе и упруго возвращается.
-- Это замена camera shake на hit'е — фидбек идёт от самого блока, не от глаз.
local function blockSquash(part: BasePart)
    if part:GetAttribute("_destroying") then return end
    if part:GetAttribute("_squashing") then return end
    part:SetAttribute("_squashing", true)
    local squashed = Vector3.new(BS * 1.07, BS * 0.88, BS * 1.07)
    local rest = part:GetAttribute("_hovered") and HOVER_BSv or BSv
    local t1 = TweenService:Create(part, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = squashed })
    t1:Play()
    t1.Completed:Once(function()
        if part:GetAttribute("_destroying") then
            part:SetAttribute("_squashing", false)
            return
        end
        local target = part:GetAttribute("_hovered") and HOVER_BSv or rest
        local t2 = TweenService:Create(part, TweenInfo.new(0.09, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = target })
        t2:Play()
        t2.Completed:Once(function()
            part:SetAttribute("_squashing", false)
        end)
    end)
end

local function formatHP(hp, maxHp)
    local function s(n)
        if n >= 1e6 then return string.format("%.1fM", n/1e6)
        elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
        else return tostring(n) end
    end
    return s(hp) .. " / " .. s(maxHp)
end

function MiningRenderer.new()
    local self = setmetatable({}, MiningRenderer)
    self._parts = {}; self._blockData = {}; self._parent = nil; self._enabled = false
    self._showRarity = false; self._showHPBar = true
    self._activeGlows = 0
    self._activeShells = 0
    self._activeAmbientFX = 0
    self._lastSwingAt = 0
    self._swingDelay = UpgradeLogic.swingDelaySeconds(1)
    self._log = Logger.new("MiningRenderer")
    self._hoveredKey = nil :: string?
    self._cursorLightHost = nil :: BasePart?
    self._cursorLight = nil :: PointLight?
    self._rayParams = nil :: RaycastParams?
    self._obstacleRayFilter = nil :: RaycastParams?
    self._minePlatformExcludes = {} :: { Instance }
    self._inputConn = nil :: RBXScriptConnection?
    self._hoverConn = nil :: RBXScriptConnection?
    -- Очередь отложенного создания блоков (анти-фриз, см. CREATE_BUDGET_PER_FRAME).
    self._createQueue = {}      -- FIFO-массив entry'ев {key,x,z,y,oreId,hp,maxHp}
    self._createHead = 1        -- индекс головы очереди (без table.remove, O(1))
    self._createPending = {}    -- key -> entry: для отмены/замены до создания
    self._createConn = nil :: RBXScriptConnection?
    self._ambientFxConn = nil :: RBXScriptConnection?
    self._ambientFxAccum = 0
    self._syncConn = nil :: RBXScriptConnection?
    self._gen = 0 -- поколение (см. _isStale); проставляется в start()
    self._origin = nil :: Vector3? -- мировой центр шахты, кэш (см. _mineOrigin)
    self._originDeadline = 0 -- до этого времени ждём MineZoneMarker (см. _drainCreateQueue)
    return self
end

--[[
    Опорная точка шахты = зона workspace.MineZoneMarker. Координата блока (0,0,0)
    кладётся в ВЕРХ-ЦЕНТР коробки MineZoneMarker.Volume:
      • X / Z   — горизонтальный центр зоны → поле 15×15 ровно внутри коробки.
      • Y       — верхняя грань коробки: поверхность шахты совпадает с верхом
                  зоны, дальше блоки копаются вниз (Neighbor Reveal) и заполняют
                  всю коробку (её высота = стартовый куб, SURFACE_H блоков).
    Шахта появляется ровно в зоне маркера и следует за ним, если его подвинуть.
    Кэшируется на жизнь renderer'а (блоков тысячи — не читаем workspace на каждый).

    ВАЖНО (фикс «шахта иногда не в зоне»): origin кэшируется ТОЛЬКО когда найден
    реальный MineZoneMarker.Volume. Раньше при гонке загрузки (маркер ещё не
    реплицировался/не стримнулся к моменту первого блока) кэшировался фоллбэк и
    вся шахта на сессию уезжала. Теперь создание блоков ждёт маркер (см.
    _drainCreateQueue), фоллбэк — только после таймаута, чтобы шахта не зависла
    невидимой при реально отсутствующем маркере.
]]
function MiningRenderer:_resolveOrigin(): Vector3?
    if self._origin then return self._origin end
    local marker = workspace:FindFirstChild("MineZoneMarker")
    local volume = marker and marker:FindFirstChild("Volume")
    if volume and volume:IsA("BasePart") then
        -- верх-центр коробки: блок y=0 верхней гранью ложится на верх зоны
        self._origin = volume.Position + Vector3.new(0, volume.Size.Y / 2, 0)
    end
    return self._origin
end

function MiningRenderer:_fallbackOrigin(): Vector3
    local mr = workspace:FindFirstChild("MineRespawn")
    if mr and mr:IsA("BasePart") then return mr.Position end
    return Vector3.new(0, 0, 30)
end

-- Гарантированно возвращает Vector3 (для позиционирования). К моменту вызова из
-- _createPart origin уже резолвнут гейтом в _drainCreateQueue; этот геттер —
-- страховка, чтобы вызывающие никогда не получили nil.
function MiningRenderer:_mineOrigin(): Vector3
    return self._origin or self:_resolveOrigin() or self:_fallbackOrigin()
end

function MiningRenderer:setSwingDelay(speedLevel: number, speedBoostMult: number?)
    self._swingDelay = UpgradeLogic.swingDelaySeconds(speedLevel, speedBoostMult)
end

function MiningRenderer:_folder()
    if self._parent and self._parent.Parent then return end
    -- Чистим осиротевшие папки от прошлых жизней. Клиентские скрипты
    -- перезагружаются на КАЖДОМ респавне (PlayerGui reset), и старый renderer
    -- НЕ получает stop() — его DeepDigger_Mine с 2250+ партами остаётся в
    -- workspace навсегда (парты не привязаны к скрипту). За N смертей это
    -- N×2900 партов в сцене → нарастающий overdraw и фризы. Сносим всё лишнее.
    for _, c in workspace:GetChildren() do
        if c.Name == "DeepDigger_Mine" then c:Destroy() end
    end
    local f = Instance.new("Folder"); f.Name = "DeepDigger_Mine"; f.Parent = workspace; self._parent = f
    self._rayParams = nil
    self._obstacleRayFilter = nil
end

-- Поколение активного renderer'а. _G переживает респавн (Luau-VM клиента не
-- пересоздаётся, только скрипты), поэтому это надёжный кросс-жизненный токен.
-- Любой renderer из прошлой жизни (если его коннекшены пережили destroy
-- скрипта) увидит, что он больше не активен, и сам себя выключит.
function MiningRenderer:_isStale(): boolean
    return self._gen ~= (_G :: any).DD_RENDER_GEN
end

function MiningRenderer:_raycastParams(): RaycastParams?
    if not self._parent then return nil end
    if not self._rayParams then
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Include
        p.IgnoreWater = true
        self._rayParams = p
    end
    self._rayParams.FilterDescendantsInstances = { self._parent }
    return self._rayParams
end

function MiningRenderer:_obstacleRayParams(): RaycastParams?
    if not self._parent then
        return nil
    end
    if not self._obstacleRayFilter then
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Exclude
        p.IgnoreWater = true
        self._obstacleRayFilter = p
    end
    local exclude: { Instance } = { self._parent :: Instance }
    local char = Players.LocalPlayer.Character
    if char then
        table.insert(exclude, char)
    end
    if self._cursorLightHost then
        table.insert(exclude, self._cursorLightHost)
    end
    appendMiningRaycastExcludes(exclude)
    for _, inst in self._minePlatformExcludes do
        if inst.Parent then
            table.insert(exclude, inst)
        end
    end
    self._obstacleRayFilter.FilterDescendantsInstances = exclude
    return self._obstacleRayFilter
end

function MiningRenderer:_playerRoot(): BasePart?
    local char = Players.LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root :: BasePart
    end
    return nil
end

function MiningRenderer:_withinMineReach(worldPos: Vector3): boolean
    local root = self:_playerRoot()
    if not root then
        return false
    end
    return MiningReach.isWithinReach(root.Position, worldPos)
end

function MiningRenderer:_pickBlockFromHit(hit: RaycastResult?): BasePart?
    if not hit or not hit.Instance:IsA("BasePart") then
        return nil
    end
    if not self._parts[hit.Instance.Name] then
        return nil
    end
    if hit.Instance:GetAttribute("_destroying") then
        return nil
    end
    return hit.Instance
end

function MiningRenderer:_raycastMine(screenPos: Vector2?): RaycastResult?
    local cam = workspace.CurrentCamera
    local mineParams = self:_raycastParams()
    local obstacleParams = self:_obstacleRayParams()
    if not cam or not mineParams or not obstacleParams then
        return nil
    end
    PerfBeacon.bump("raycasts")
    local mouse = screenPos or UserInputService:GetMouseLocation()
    local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
    local direction = ray.Direction

    local mineHit = workspace:Raycast(ray.Origin, direction * RAYCAST_MAX_DISTANCE, mineParams)
    if not mineHit then
        return nil
    end

    local part = self:_pickBlockFromHit(mineHit)
    if not part or not self:_withinMineReach(part.Position) then
        return nil
    end

    PerfBeacon.bump("raycasts")
    local obstacleHit = workspace:Raycast(ray.Origin, direction * mineHit.Distance, obstacleParams)
    if obstacleHit and obstacleHit.Distance < mineHit.Distance - 0.05 then
        return nil
    end

    return mineHit
end

function MiningRenderer:_raycastBlockPart(screenPos: Vector2?): BasePart?
    return self:_pickBlockFromHit(self:_raycastMine(screenPos))
end

function MiningRenderer:_hoverEnter(key: string)
    local part = self._parts[key]
    if not part or part:GetAttribute("_destroying") then return end
    part:SetAttribute("_hovered", true)
    if self._showHPBar then
        local gui = self:_ensureHPBar(key)
        if gui then gui.Enabled = true end
    end
    local d = self._blockData[key]
    local oreId = d and d.oreId or "dirt"
    local rarity = OreLookup.getRarity(oreId)
    local rarColor = OreLookup.getRarityColor(oreId)
    local oreName = OreLookup.getName(oreId)
    -- Обычные руды обводятся/подписываются белым (их rarity-серый сливается с
    -- камнем); rare+ — своим цветом редкости.
    local outlineColor = if rarity == "common" then Color3.new(1, 1, 1) else rarColor

    -- Название руды чуть выше HP-бара (HP-бар на Y=-2.8) — цвет = outlineColor.
    local nameGui = Instance.new("BillboardGui")
    nameGui.Name = "HoverName"
    nameGui.Size = UDim2.fromOffset(180, 28)
    nameGui.StudsOffset = Vector3.new(0, -1.5, 0)
    nameGui.AlwaysOnTop = true
    nameGui.LightInfluence = 0
    nameGui.Parent = part
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.fromScale(1, 1)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = oreName
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 15
    nameLbl.TextColor3 = outlineColor
    nameLbl.TextStrokeTransparency = 0.25
    nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLbl.Parent = nameGui

    -- Обводка блока — цвет редкости (common = белый), линия пожирнее.
    local sel = Instance.new("SelectionBox")
    sel.Name = "HoverSel"
    sel.Adornee = part
    sel.LineThickness = 0.12
    sel.Color3 = outlineColor
    sel.SurfaceTransparency = 0.92
    sel.Parent = part

    if not part:GetAttribute("_squashing") then
        TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Size = HOVER_BSv }):Play()
    end
    -- Каждая накидка выезжает наружу по нормали своей грани.
    self:_forEachShellFace(part, function(shell)
        local rest = shell:GetAttribute("RestCF")
        if typeof(rest) == "CFrame" then
            TweenService:Create(shell, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
                CFrame = rest + rest.RightVector * (BS * 0.025),
            }):Play()
        end
    end)
end

function MiningRenderer:_hoverLeave(key: string)
    local part = self._parts[key]
    if not part then return end
    part:SetAttribute("_hovered", false)
    local hd = self._blockData[key]
    if hd and hd.hpGui then hd.hpGui.Enabled = false end
    local nameGui = part:FindFirstChild("HoverName"); if nameGui then nameGui:Destroy() end
    local sel = part:FindFirstChild("HoverSel"); if sel then sel:Destroy() end
    if part:GetAttribute("_destroying") then return end
    if not part:GetAttribute("_squashing") then
        TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Size = BSv }):Play()
    end
    self:_forEachShellFace(part, function(shell)
        local rest = shell:GetAttribute("RestCF")
        if typeof(rest) == "CFrame" then
            TweenService:Create(shell, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { CFrame = rest }):Play()
        end
    end)
end

-- Небольшой PointLight следует за лучом мыши в шахте (вместо фонарика на игроке).
function MiningRenderer:_ensureCursorLight()
    if self._cursorLightHost then return end
    local cfg = Constants.CURSOR_LIGHT or {
        brightness = 0.85, range = 11,
        color = Color3.fromRGB(255, 248, 230), fallbackDistance = 14,
    }
    local host = Instance.new("Part")
    host.Name = "CursorLightHost"
    host.Size = Vector3.new(0.1, 0.1, 0.1)
    host.Anchored = true
    host.CanCollide = false; host.CanTouch = false; host.CanQuery = false
    host.Transparency = 1; host.CastShadow = false; host.Massless = true
    local light = Instance.new("PointLight")
    light.Name = "CursorLight"
    light.Brightness = cfg.brightness
    light.Range = cfg.range
    light.Color = cfg.color
    light.Shadows = false
    light.Parent = host
    host.Parent = self._parent
    self._cursorLightHost = host
    self._cursorLight = light
end

function MiningRenderer:_applyCursorLight(hit: RaycastResult?)
    if not self._parent then
        return
    end
    self:_ensureCursorLight()
    local host = self._cursorLightHost
    local light = self._cursorLight
    if not host or not light then
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then
        light.Enabled = false
        return
    end
    if workspace:GetAttribute("DD_TutorialMineHint") then
        light.Enabled = false
        return
    end
    local cfg = Constants.CURSOR_LIGHT or { fallbackDistance = 14 }
    local pos: Vector3
    if hit then
        pos = hit.Position + hit.Normal * 0.25
    else
        local mouse = UserInputService:GetMouseLocation()
        local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
        pos = ray.Origin + ray.Direction * (cfg.fallbackDistance or 14)
    end
    host.Position = pos
    light.Enabled = true
end

function MiningRenderer:_destroyCursorLight()
    if self._cursorLightHost then
        self._cursorLightHost:Destroy()
        self._cursorLightHost = nil
        self._cursorLight = nil
    end
end

function MiningRenderer:_updateHover()
    local hit = self:_raycastMine()
    self:_applyCursorLight(hit)
    local part = self:_pickBlockFromHit(hit)
    local key = if part then part.Name else nil
    if key == self._hoveredKey then
        return
    end
    if self._hoveredKey then
        self:_hoverLeave(self._hoveredKey)
    end
    self._hoveredKey = key
    if key then
        self:_hoverEnter(key)
    end
end

function MiningRenderer:_setupInput()
    self:_teardownInput()
    self._inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if self:_isStale() then self:stop(); return end
        if not self._enabled or gameProcessed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local screenPos = if input.UserInputType == Enum.UserInputType.Touch
            then Vector2.new(input.Position.X, input.Position.Y)
            else nil
        local part = self:_raycastBlockPart(screenPos)
        if not part then return end
        local key = part.Name
        local x, z, y = parseKey(key)
        self:_onClick(key, x, z, y)
    end)
    self._hoverConn = RunService.RenderStepped:Connect(function()
        if self:_isStale() then self:stop(); return end
        if self._enabled then
            self:_updateHover()
        end
    end)
    -- Дренаж очереди создания блоков (анти-фриз). На Heartbeat, чтобы не
    -- конкурировать с рендером за время кадра.
    self._createConn = RunService.Heartbeat:Connect(function()
        if self:_isStale() then self:stop(); return end
        if self._enabled then
            self:_drainCreateQueue()
        end
    end)
    self._ambientFxAccum = 0
    self._ambientFxConn = RunService.Heartbeat:Connect(function(dt)
        if self:_isStale() then self:stop(); return end
        if not self._enabled then return end
        self._ambientFxAccum += dt
        if self._ambientFxAccum >= AMBIENT_FX_TICK then
            self._ambientFxAccum = 0
            self:_refreshBlockDecorations()
        end
    end)
end

function MiningRenderer:_teardownInput()
    if self._inputConn then self._inputConn:Disconnect(); self._inputConn = nil end
    if self._hoverConn then self._hoverConn:Disconnect(); self._hoverConn = nil end
    if self._createConn then self._createConn:Disconnect(); self._createConn = nil end
    if self._ambientFxConn then self._ambientFxConn:Disconnect(); self._ambientFxConn = nil end
    if self._hoveredKey then
        self:_hoverLeave(self._hoveredKey)
        self._hoveredKey = nil
    end
end

function MiningRenderer:_makeHPBar(hp, maxHp)
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.fromOffset(120, 20); gui.StudsOffset = Vector3.new(0, -2.8, 0)
    gui.AlwaysOnTop = true; gui.ClipsDescendants = true; gui.Enabled = false
    local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(8, 8, 16); bg.BackgroundTransparency = 0.05
    bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 5)
    -- Жирная обводка, чтобы бар читался поверх любого блока, а не сливался.
    local barStroke = Instance.new("UIStroke")
    barStroke.Thickness = 2.5
    barStroke.Color = Color3.fromRGB(15, 15, 25)
    barStroke.Parent = bg
    -- Внутренний отступ, чтобы fill не залезал под обводку.
    local pad = Instance.new("Frame"); pad.Size = UDim2.new(1, -4, 1, -4); pad.Position = UDim2.fromOffset(2, 2)
    pad.BackgroundColor3 = Color3.fromRGB(30, 32, 42); pad.BorderSizePixel = 0
    Instance.new("UICorner", pad).CornerRadius = UDim.new(0, 4); pad.Parent = bg
    local fill = Instance.new("Frame"); fill.Name = "Fill"
    fill.Size = UDim2.fromScale(math.max(0.02, hp / maxHp), 1)
    fill.BackgroundColor3 = Color3.fromRGB(60, 230, 60); fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4); fill.Parent = pad
    local txt = Instance.new("TextLabel"); txt.Size = UDim2.fromScale(1, 1)
    txt.BackgroundTransparency = 1; txt.Text = formatHP(hp, maxHp)
    txt.Font = Enum.Font.GothamBold; txt.TextSize = 12; txt.TextScaled = true
    txt.TextColor3 = Color3.new(1, 1, 1); txt.TextStrokeTransparency = 0.2; txt.TextStrokeColor3 = Color3.new(0, 0, 0)
    txt.ZIndex = 3; txt.Parent = bg
    bg.Parent = gui
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

-- Ленивое создание HP-бара: BillboardGui строится при первом наведении, а не
-- для каждого из тысяч блоков сразу. Наводится всегда один блок за раз.
function MiningRenderer:_ensureHPBar(key)
    local d = self._blockData[key]; local part = self._parts[key]
    if not d or not part then return nil end
    if d.hpGui then return d.hpGui end
    local gui, fill, txt = self:_makeHPBar(d.hp, d.maxHp)
    gui.Parent = part
    d.hpGui = gui; d.hpFill = fill; d.hpTxt = txt
    return gui
end

-- Ленивое создание rarity-плашки: по умолчанию выключена (/rarity), большинство
-- игроков её не включает — не плодим тысячи скрытых BillboardGui.
function MiningRenderer:_ensureRarityTag(key)
    local d = self._blockData[key]; local part = self._parts[key]
    if not d or not part then return nil end
    if d.rarityTag then return d.rarityTag end
    local rarColor = OreLookup.getRarityColor(d.oreId)
    local tag = Instance.new("BillboardGui"); tag.Size = UDim2.fromOffset(50, 6)
    tag.StudsOffset = Vector3.new(0, 3.2, 0); tag.AlwaysOnTop = true
    tag.ClipsDescendants = false; tag.Enabled = false
    local bar = Instance.new("Frame"); bar.Size = UDim2.fromScale(1, 1)
    bar.BackgroundColor3 = rarColor; bar.BorderSizePixel = 0; bar.BackgroundTransparency = 0.1
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 3); bar.Parent = tag; tag.Parent = part
    d.rarityTag = tag
    return tag
end

function MiningRenderer:_decorDef(oreId: string): OreBlockDecor.OreDecorDef?
    local def = OreLookup.getDef(oreId)
    if not def then return nil end
    return {
        id = oreId,
        color = OreLookup.getColor(oreId),
        rarity = OreLookup.getRarity(oreId),
        weight = def.weight,
    }
end

function MiningRenderer:_shellFaceNormal(x: number, z: number, y: number): Vector3
    local faces = {
        { key = string.format("%d_%d_%d", x + 1, z, y), n = Vector3.new(1, 0, 0) },
        { key = string.format("%d_%d_%d", x - 1, z, y), n = Vector3.new(-1, 0, 0) },
        { key = string.format("%d_%d_%d", x, z + 1, y), n = Vector3.new(0, 0, 1) },
        { key = string.format("%d_%d_%d", x, z - 1, y), n = Vector3.new(0, 0, -1) },
        { key = string.format("%d_%d_%d", x, z, y - 1), n = Vector3.new(0, 1, 0) },
        { key = string.format("%d_%d_%d", x, z, y + 1), n = Vector3.new(0, -1, 0) },
    }
    local o = self:_mineOrigin()
    local blockPos = Vector3.new(o.X + x * BS, o.Y - (y * BS + BS / 2), o.Z + z * BS)
    local cam = workspace.CurrentCamera
    local toCam = if cam then (cam.CFrame.Position - blockPos) else Vector3.new(0, 1, 0)
    local best, bestScore = nil, -math.huge
    for _, f in ipairs(faces) do
        local occupied = self._parts[f.key] ~= nil or self._createPending[f.key] ~= nil
        if not occupied then
            local score = f.n:Dot(toCam)
            if score > bestScore then bestScore = score; best = f.n end
        end
    end
    return best or Vector3.new(1, 0, 0)
end

-- Все открытые (без соседа) грани блока.
function MiningRenderer:_shellOpenFaceNormals(x: number, z: number, y: number): { Vector3 }
    local faces = {
        { key = string.format("%d_%d_%d", x + 1, z, y), n = Vector3.new(1, 0, 0) },
        { key = string.format("%d_%d_%d", x - 1, z, y), n = Vector3.new(-1, 0, 0) },
        { key = string.format("%d_%d_%d", x, z + 1, y), n = Vector3.new(0, 0, 1) },
        { key = string.format("%d_%d_%d", x, z - 1, y), n = Vector3.new(0, 0, -1) },
        { key = string.format("%d_%d_%d", x, z, y - 1), n = Vector3.new(0, 1, 0) },
        { key = string.format("%d_%d_%d", x, z, y + 1), n = Vector3.new(0, -1, 0) },
    }
    local open: { Vector3 } = {}
    for _, f in ipairs(faces) do
        local occupied = self._parts[f.key] ~= nil or self._createPending[f.key] ~= nil
        if not occupied then
            table.insert(open, f.n)
        end
    end
    return open
end

function MiningRenderer:_forEachShellFace(part: BasePart, fn: (BasePart) -> ())
    local shell = part:FindFirstChild("OreShell")
    if not shell then return end
    if shell:IsA("BasePart") then
        fn(shell)
        return
    end
    for _, child in shell:GetChildren() do
        if child:IsA("BasePart") then
            fn(child)
        end
    end
end

function MiningRenderer:_decorVisConfig(): MiningBlockDecor.VisConfig
    return {
        range = DECOR_RANGE,
        fovAttach = DECOR_FOV_ATTACH,
        fovKeep = DECOR_FOV_KEEP,
        fovWeight = DECOR_FOV_WEIGHT,
    }
end

function MiningRenderer:_decorCameraBasis(): (Vector3?, Vector3?)
    local cam = workspace.CurrentCamera
    if cam then
        return cam.CFrame.Position, cam.CFrame.LookVector
    end
    return self:_ambientFXOrigin(), nil
end

function MiningRenderer:_reconcileNeighborShells(x: number, z: number, y: number)
    local offsets = {
        { 1, 0, 0 }, { -1, 0, 0 },
        { 0, 1, 0 }, { 0, -1, 0 },
        { 0, 0, 1 }, { 0, 0, -1 },
    }
    for _, off in ipairs(offsets) do
        local nx, nz, ny = x + off[1], z + off[2], y + off[3]
        local nKey = string.format("%d_%d_%d", nx, nz, ny)
        local part = self._parts[nKey]
        local d = self._blockData[nKey]
        if part and d and d.hasShell and not self:_isFillerOre(d.oreId) then
            self:_reconcileShellFaces(part, nx, nz, ny, d.oreId, OreLookup.getRarity(d.oreId))
        end
    end
end

function MiningRenderer:_refreshVisibleShells(camPos: Vector3, camLook: Vector3)
    local visCfg = self:_decorVisConfig()
    local entries: { MiningBlockDecor.Entry } = {}

    for key, part in pairs(self._parts) do
        local d = self._blockData[key]
        if not d or self:_isFillerOre(d.oreId) then
            continue
        end
        table.insert(entries, {
            key = key,
            hasDecor = d.hasShell == true,
            vis = MiningBlockDecor.computeVisibility(part.Position, camPos, camLook, visCfg),
        })
    end

    local pick = MiningBlockDecor.pick(entries, MAX_VISIBLE_SHELLS, self._hoveredKey)

    for key, _ in pairs(pick.remove) do
        local part = self._parts[key]
        local d = self._blockData[key]
        if part and d and d.hasShell then
            self:_detachShell(part, d)
        end
    end

    for key, _ in pairs(pick.attach) do
        local part = self._parts[key]
        local d = self._blockData[key]
        if not part or not d or d.hasShell then
            continue
        end
        local bx, bz, by = parseKey(key)
        if self:_addShell(part, bx, bz, by, d.oreId, OreLookup.getRarity(d.oreId)) then
            d.hasShell = true
        end
    end

    for key, _ in pairs(pick.keep) do
        if pick.attach[key] then
            continue
        end
        local part = self._parts[key]
        local d = self._blockData[key]
        if not part or not d or not d.hasShell then
            continue
        end
        local bx, bz, by = parseKey(key)
        self:_reconcileShellFaces(part, bx, bz, by, d.oreId, OreLookup.getRarity(d.oreId))
    end
end

-- Накидка-меш на открытые грани (как OreReferenceBlocks_Restyled, без закрытых соседей).
function MiningRenderer:_addShell(part: BasePart, x: number, z: number, y: number, oreId: string, _rarity: string): boolean
    self:_cleanupStaleOreShell(part, nil)
    local existing = part:FindFirstChild("OreShell")
    if existing and existing:IsA("Folder") and #existing:GetChildren() > 0 then
        return true
    end

    local decorDef = self:_decorDef(oreId)
    if not decorDef or OreBlockDecor.isFiller(decorDef) then return false end

    local normals = self:_shellOpenFaceNormals(x, z, y)
    if #normals == 0 then
        normals = { self:_shellFaceNormal(x, z, y) }
    end

    if OreBlockDecor.mountShell(part, normals, decorDef, BS) then
        self._activeShells += 1
        return true
    end
    return false
end

-- Досоздаёт/снимает грани при раскопке соседей.
function MiningRenderer:_reconcileShellFaces(part: BasePart, x: number, z: number, y: number, oreId: string, _rarity: string)
    local folder = part:FindFirstChild("OreShell")
    if not folder or folder:IsA("BasePart") then return end

    local decorDef = self:_decorDef(oreId)
    if not decorDef then return end

    local openSet: { [string]: Vector3 } = {}
    for _, n in ipairs(self:_shellOpenFaceNormals(x, z, y)) do
        openSet[OreBlockDecor.faceKey(n)] = n
    end

    local present: { [string]: boolean } = {}
    for _, child in folder:GetChildren() do
        if child:IsA("BasePart") then
            local fk = child:GetAttribute("FaceKey")
            if typeof(fk) == "string" and openSet[fk] then
                present[fk] = true
            else
                child:Destroy()
            end
        end
    end

    local shellColor = OreBlockDecor.shellColor(decorDef.color, decorDef.rarity)
    for fk, normal in pairs(openSet) do
        if not present[fk] then
            OreBlockDecor.createShellFace(part.Position, normal, shellColor, decorDef.rarity, BS).Parent = folder
        end
    end
end

-- Шаблон ambient-FX для редкости (legacy; создание через OreBlockDecor).
function MiningRenderer:_ambientFXOrigin(): Vector3?
    local lp = game:GetService("Players").LocalPlayer
    if lp and lp.Character then
        local hrp = lp.Character:FindFirstChild("HumanoidRootPart")
        if hrp and hrp:IsA("BasePart") then
            return hrp.Position
        end
    end
    local cam = workspace.CurrentCamera
    return if cam then cam.CFrame.Position else nil
end

function MiningRenderer:_detachAmbientFX(part: BasePart, d: any?)
    local holder = part:FindFirstChild(AMBIENT_FX_HOLDER)
    if not holder then return end
    holder:Destroy()
    if d then d.hasAmbientFX = false end
    self:_syncDecorFlag(part)
end

function MiningRenderer:_oreFXPalette(oreId: string): OreFXPalette.Palette
    return OreFXPalette.fromColors(OreLookup.getColor(oreId), OreLookup.getRarityColor(oreId))
end

local AMBIENT_FX_TINT_ATTR = "OreTintId"
-- Bump при смене алгоритма перекраски — все holder'ы перетинтуются на refresh.
local AMBIENT_FX_TINT_VER = 2

function MiningRenderer:_tintAmbientFXHolder(holder: Instance, oreId: string)
    OreFXPalette.tintDescendants(holder, self:_oreFXPalette(oreId))
    holder:SetAttribute(AMBIENT_FX_TINT_ATTR, oreId)
    holder:SetAttribute("OreTintVer", AMBIENT_FX_TINT_VER)
end

function MiningRenderer:_ensureAmbientFXTinted(part: BasePart, oreId: string)
    local holder = part:FindFirstChild(AMBIENT_FX_HOLDER)
    if not holder then return end
    if holder:GetAttribute(AMBIENT_FX_TINT_ATTR) == oreId
        and holder:GetAttribute("OreTintVer") == AMBIENT_FX_TINT_VER then
        return
    end
    self:_tintAmbientFXHolder(holder, oreId)
end

type OreGlowCfg = { range: number, brightness: number }

function MiningRenderer:_resolveOreGlow(oreId: string): OreGlowCfg?
    if self:_isFillerOre(oreId) then return nil end
    local cfg = OreBlockDecor.resolveGlow(OreLookup.getRarity(oreId))
    if not cfg then return nil end
    return { range = cfg.range, brightness = cfg.brightness }
end

function MiningRenderer:_detachOreGlow(part: BasePart, d: any?)
    local glow = part:FindFirstChild("RarityGlow")
    if not glow then return end
    glow:Destroy()
    if d then d.hasGlow = false end
    self:_syncDecorFlag(part)
end

function MiningRenderer:_syncOreGlow(part: BasePart, oreId: string, cfg: OreGlowCfg)
    local glow = part:FindFirstChild("RarityGlow")
    if not glow or not glow:IsA("PointLight") then return end
    local decorDef = self:_decorDef(oreId)
    if decorDef then
        OreBlockDecor.syncRarityGlow(part, decorDef)
    else
        glow.Color = self:_oreFXPalette(oreId).glow
        glow.Range = cfg.range
        glow.Brightness = cfg.brightness
    end
end

function MiningRenderer:_attachOreGlow(part: BasePart, oreId: string, d: any?): boolean
    local decorDef = self:_decorDef(oreId)
    if not decorDef or not OreBlockDecor.attachRarityGlow(part, decorDef) then
        return false
    end
    if d then d.hasGlow = true end
    part:SetAttribute("_hasDecor", true)
    return true
end

function MiningRenderer:_attachAmbientFX(part: BasePart, oreId: string, _rarity: string): boolean
    local existing = part:FindFirstChild(AMBIENT_FX_HOLDER)
    if existing then
        self:_ensureAmbientFXTinted(part, oreId)
        part:SetAttribute("_hasDecor", true)
        return true
    end
    local decorDef = self:_decorDef(oreId)
    if not decorDef or not OreBlockDecor.attachAmbientFX(part, decorDef, ReplicatedStorage:FindFirstChild(AMBIENT_FX_FOLDER)) then
        return false
    end
    self:_tintAmbientFXHolder(part:FindFirstChild(AMBIENT_FX_HOLDER) :: Instance, oreId)
    part:SetAttribute("_hasDecor", true)
    return true
end

function MiningRenderer:_detachShell(part: BasePart, d: any?)
    local shell = part:FindFirstChild("OreShell")
    if not shell then return end
    shell:Destroy()
    if d and d.hasShell then
        d.hasShell = false
        self._activeShells = math.max(0, self._activeShells - 1)
    end
    self:_syncDecorFlag(part)
end

-- Legacy single-face Part и пустой Folder мешают повесить multi-face накидку.
function MiningRenderer:_cleanupStaleOreShell(part: BasePart, d: any?)
    local shell = part:FindFirstChild("OreShell")
    if not shell then return end

    local stale = shell:IsA("BasePart")
        or (shell:IsA("Folder") and #shell:GetChildren() == 0)
    if not stale then return end

    shell:Destroy()
    if d then d.hasShell = false end
    self._activeShells = math.max(0, self._activeShells - 1)
    self:_syncDecorFlag(part)
end

function MiningRenderer:_syncDecorFlag(part: BasePart)
    local has = part:FindFirstChild("OreShell") ~= nil
        or part:FindFirstChild(AMBIENT_FX_HOLDER) ~= nil
        or part:FindFirstChild("RarityGlow") ~= nil
    part:SetAttribute("_hasDecor", has)
end

function MiningRenderer:_stripFarDecorations(part: BasePart, d: any?)
    self:_detachAmbientFX(part, d)
    self:_detachOreGlow(part, d)
    self:_detachShell(part, d)
end

function MiningRenderer:_isFillerOre(oreId: string): boolean
    local def = OreLookup.getDef(oreId)
    return (not def) or ((def.weight or 0) >= FILLER_WEIGHT)
end

-- Proximity: ambient-FX, glow и накидки (FOV-бюджет) от камеры/игрока.
function MiningRenderer:_refreshBlockDecorations()
    local camPos, camLook = self:_decorCameraBasis()
    if not camPos then
        return
    end
    if not camLook then
        camLook = Vector3.new(0, 0, -1)
    end
    local origin = camPos

    local activeFx = 0
    local activeGlows = 0
    local fxCandidates: { { key: string, part: BasePart, dist: number, oreId: string, rarity: string } } = {}
    local glowCandidates: { { key: string, part: BasePart, dist: number, oreId: string } } = {}

    for key, part in pairs(self._parts) do
        local d = self._blockData[key]
        if not d then continue end
        local dist = (part.Position - origin).Magnitude

        if dist > SHELL_RANGE + BS then
            self:_stripFarDecorations(part, d)
            continue
        end

        local rarity = OreLookup.getRarity(d.oreId)

        local hasFx = part:FindFirstChild(AMBIENT_FX_HOLDER) ~= nil
        if dist > AMBIENT_FX_RANGE then
            if hasFx then self:_detachAmbientFX(part, d) end
        elseif hasFx then
            activeFx += 1
            self:_ensureAmbientFXTinted(part, d.oreId)
        elseif AMBIENT_FX_RARITY[rarity] then
            table.insert(fxCandidates, { key = key, part = part, dist = dist, oreId = d.oreId, rarity = rarity })
        end

        local glowCfg = self:_resolveOreGlow(d.oreId)
        local hasGlow = part:FindFirstChild("RarityGlow") ~= nil
        if dist > SHELL_RANGE or not glowCfg then
            if hasGlow then self:_detachOreGlow(part, d) end
        elseif hasGlow then
            activeGlows += 1
            self:_syncOreGlow(part, d.oreId, glowCfg)
        else
            table.insert(glowCandidates, { key = key, part = part, dist = dist, oreId = d.oreId })
        end
    end

    table.sort(fxCandidates, function(a, b) return a.dist < b.dist end)
    for _, c in ipairs(fxCandidates) do
        if activeFx >= MAX_AMBIENT_FX then break end
        if self:_attachAmbientFX(c.part, c.oreId, c.rarity) then
            local d = self._blockData[c.key]
            if d then d.hasAmbientFX = true end
            activeFx += 1
        end
    end
    self._activeAmbientFX = activeFx

    table.sort(glowCandidates, function(a, b) return a.dist < b.dist end)
    for _, c in ipairs(glowCandidates) do
        if activeGlows >= MAX_ORE_GLOWS then break end
        if self:_attachOreGlow(c.part, c.oreId, self._blockData[c.key]) then
            activeGlows += 1
        end
    end
    self._activeGlows = activeGlows

    self:_refreshVisibleShells(camPos, camLook)
end

function MiningRenderer:_createPart(x, z, y, oreId, hp, maxHp, mutation)
    PerfBeacon.bump("partsCreated")
    local key = string.format("%d_%d_%d", x, z, y)
    local part = Instance.new("Part")
    part.Name = key; part.Size = BSv; part.Anchored = true
    part:SetAttribute("oreId", oreId)
    -- CastShadow=false: блоки под землёй, их тени не видны игроку, а ~2250+
    -- shadow-casting парт'ов — главный убийца FPS (shadowmap/voxel lighting
    -- считает тени для каждого). Все динамические FX тоже идут без теней.
    part.CanCollide = true; part.CanTouch = false; part.CastShadow = false

    local mutationTint = MutationLogic.tint(mutation)
    if mutationTint then
        -- P2.9: мутировавший блок светится своим оттенком прямо в стене —
        -- это и есть «трейлерный» момент: игрок видит его издалека.
        part:SetAttribute("mutation", mutation)
        part.Color = mutationTint
        part.Material = Enum.Material.Neon
        part.Reflectance = 0.15
        smoothSurfaces(part)
    else
        local decorDef = self:_decorDef(oreId)
        if decorDef then
            OreBlockDecor.applyHostStyle(part, decorDef)
        else
            part.Color = OreLookup.getColor(oreId)
            part.Material = Enum.Material.SmoothPlastic
            part.Reflectance = 0
            smoothSurfaces(part)
        end
    end
    part.Parent = self._parent
    local o = self:_mineOrigin()
    part.Position = Vector3.new(
        o.X + x * BS,
        o.Y - (y * BS + BS / 2),
        o.Z + z * BS
    )
    -- PointLight и AmbientFX — в _refreshBlockDecorations (proximity, как на стенде).

    self._parts[key] = part
    self._blockData[key] = {
        oreId = oreId, hp = hp, maxHp = maxHp, mutation = mutation,
        hasGlow = false, hasShell = false, hasAmbientFX = false,
    }

    -- Если плашки редкости включены глобально (/rarity), показать её и на
    -- свежесозданном блоке (например, пришедшем delta'ой).
    if self._showRarity then
        local t = self:_ensureRarityTag(key)
        if t then t.Enabled = true end
    end
end

function MiningRenderer:_destroyPart(key)
    PerfBeacon.bump("partsDestroyed")
    if self._hoveredKey == key then
        self:_hoverLeave(key)
        self._hoveredKey = nil
    end
    local d = self._blockData[key]
    if d and d.hasGlow then self._activeGlows = math.max(0, self._activeGlows - 1) end
    if d and d.hasShell then self._activeShells = math.max(0, self._activeShells - 1) end
    local bx, bz, by = parseKey(key)
    self:_reconcileNeighborShells(bx, bz, by)
    local p = self._parts[key]
    if p and p:FindFirstChild(AMBIENT_FX_HOLDER) then
        self._activeAmbientFX = math.max(0, self._activeAmbientFX - 1)
    end
    if p then p:Destroy(); self._parts[key] = nil; self._blockData[key] = nil end
end

function MiningRenderer:_updateVisual(key, hp)
    local d = self._blockData[key]
    if not d then return end; d.hp = hp
    if d.hpFill and d.hpTxt then self:_updateHPBar(hp, d.maxHp, d.hpFill, d.hpTxt) end
end

function MiningRenderer:_hitParticles(key, oreId)
    local p = self._parts[key]; if not p then return end
    local color = OreLookup.getColor(oreId)
    -- Срабатывает на КАЖДЫЙ удар (~4/сек) — держим минимум: 2 частицы пыли,
    -- без chunk-партов (их физика на каждом тычке = постоянная нагрузка).
    -- Полноценный разлёт chunks остаётся на разрушении (_breakEffect).
    dustCloud(p, color, 2, 0.6)
end

function MiningRenderer:_breakEffect(key, oreId)
    local p = self._parts[key]; if not p then return end
    local pos = p.Position
    local def = OreLookup.getDef(oreId)
    local oreColor = OreLookup.getColor(oreId)
    local rarity = OreLookup.getRarity(oreId)
    local rarityColor = OreLookup.getRarityColor(oreId)

    -- 1. Главный эффект: разлетающиеся chunks с физикой. Это и есть "блок
    --    разлетелся на куски". Без них любой mining ощущается как клик по
    --    дидактическому квадрату.
    local chunkCount = BREAK_CHUNK_COUNT[rarity] or 6
    local scatter = BREAK_CHUNK_SPEED[rarity] or 10
    chunkBurst(self._parent, pos, oreColor, chunkCount, scatter)

    -- 2. Облако пыли (большое и долгое для редких руд).
    local dustHost = Instance.new("Part")
    dustHost.Size = Vector3.new(0.1, 0.1, 0.1)
    dustHost.Position = pos
    dustHost.Anchored = true; dustHost.CanCollide = false; dustHost.CanTouch = false
    dustHost.Transparency = 1; dustHost.Parent = self._parent
    local dustScale = if rarity == "mythic" then 1.6
        elseif rarity == "legendary" then 1.4
        elseif rarity == "epic" then 1.2
        else 1.0
    local layerDust = def and LayerProfile.IDENTITY[def.layer]
    if layerDust and layerDust.breakDust then
        local bd = layerDust.breakDust
        dustScale *= bd.scaleMul or 1
    end
    local dustColor = oreColor
    local dustEmission = 0
    local dustCount = BREAK_DUST_COUNT[rarity] or 8
    if layerDust and layerDust.breakDust then
        local bd = layerDust.breakDust
        if bd.tint then dustColor = oreColor:Lerp(bd.tint, 0.4) end
        dustEmission = bd.lightEmission or 0
        dustCount = math.floor(dustCount * (bd.countMul or 1))
    end
    dustCloud(dustHost, dustColor, dustCount, dustScale, dustEmission)
    Debris:AddItem(dustHost, 2.5)

    -- 3. Shockwave-сфера ЦВЕТА РЕДКОСТИ для rare+. Локальный взрыв в точке,
    --    видно издалека. Mythic получает второе золотое кольцо с задержкой
    --    0.15с — двухслойный «бабах» читается как «легендарное событие».
    local shock = SHOCKWAVE_BY_RARITY[rarity]
    if shock then
        shockwave(self._parent, pos, rarityColor, shock.size, shock.duration)
        if rarity == "mythic" then
            task.delay(0.15, function()
                shockwave(self._parent, pos, Color3.fromRGB(255, 215, 90), BS * 5.5, 0.55)
            end)
        end
    end
end

function MiningRenderer:_animateDestroy(key)
    local p = self._parts[key]; if not p then return end
    if p:GetAttribute("_destroying") then return end
    PerfBeacon.bump("animDestroy")
    p:SetAttribute("_destroying", true)

    local d = self._blockData[key]
    local oreId = d and d.oreId or "dirt"
    local rarity = OreLookup.getRarity(oreId)
    local pos = p.Position

    self:_breakEffect(key, oreId)

    -- Coin-pop: главный mining-фидбек. Игрок копает за награду, и она
    -- должна вылетать из блока, а не считаться где-то в HUD молча.
    local def = OreLookup.getDef(oreId)
    local value = (def and def.value) or 0
    coinPop(self._parent, pos + Vector3.new(0, 0.5, 0), value, rarity)

    -- 3D-звук разрушения в точке блока.
    SoundManager.playForOre("break", oreId, rarity, pos)

    -- Camera shake — только для rare+, mythic с легендарным пресетом.
    -- Common/uncommon разрушение НЕ трясёт камеру: 80% копания идёт по
    -- ним, любая тряска утомляет.
    if rarity == "mythic" then
        CameraShake.shakePreset("legendary_break")
        Haptics.pulse("legendary_break")
    elseif rarity == "legendary" then
        CameraShake.shakePreset("legendary_break")
        Haptics.pulse("legendary_break")
    elseif rarity == "epic" then
        CameraShake.shakePreset("break")
        Haptics.pulse("break")
    elseif rarity == "rare" then
        CameraShake.shakePreset("rare_break")
        Haptics.pulse("break")
    else
        -- common/uncommon: только звук + chunks + dust, без shake.
        -- Haptics на телефоне даём лёгкий — небольшая отдача от удачного выноса.
        Haptics.pulse("hit")
    end

    local cf = p.CFrame
    TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 0.8 }):Play()
    TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { CFrame = cf * CFrame.new(0, -BS/2, 0) }):Play()
    self:_forEachShellFace(p, function(shell)
        TweenService:Create(shell, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {
            Transparency = 1,
            CFrame = shell.CFrame + Vector3.new(0, -BS / 2, 0),
        }):Play()
    end)
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

function MiningRenderer:_dmgNumber(key, dmg, crit, oreId)
    local p = self._parts[key]; if not p then return end
    PerfBeacon.bump("fxDmgNumber")
    local d = self._blockData[key]
    oreId = oreId or (d and d.oreId) or "dirt"

    -- Размер скейлится от damage относительно maxHp: один тычок по
    -- mythic-блоку (1% хп) — мелкая цифра; вынос common-блока — крупная.
    local maxHp = d and d.maxHp or 1
    local ratio = math.clamp(dmg / math.max(maxHp, 1), 0.05, 1.0)
    local baseSize = if crit then 42 else 30
    local finalSize = math.floor(baseSize * (0.8 + ratio * 0.6) + 0.5)
    if crit then
        finalSize = math.floor(finalSize * 1.4 + 0.5)
    end

    local color
    if crit then
        color = Color3.fromRGB(255, 230, 50) -- золото
    else
        color = OreLookup.getColor(oreId)
    end
    -- Контрастная обводка: тёмная для светлых руд, светлая для тёмных.
    local lum = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
    local strokeColor = if lum > 0.55 then Color3.new(0, 0, 0) else Color3.fromRGB(35, 25, 5)

    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.fromOffset(160, 70)
    gui.StudsOffset = Vector3.new(0, 3.5, 0)
    gui.AlwaysOnTop = true; gui.ClipsDescendants = false
    gui.LightInfluence = 0

    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1
    l.Text = tostring(dmg)
    l.Font = Enum.Font.GothamBlack
    l.TextSize = 1 -- стартуем с минимума, разворачиваемся в finalSize за 0.1с (Quad/Out)
    l.TextColor3 = color
    l.TextStrokeTransparency = 0
    l.TextStrokeColor3 = strokeColor

    -- Доп. внешний контур через UIStroke: жирная читаемая цифра поверх
    -- любого цвета блока (TextStrokeTransparency сам по себе тонок).
    local stroke = Instance.new("UIStroke")
    stroke.Color = strokeColor
    stroke.Thickness = if crit then 3 else 2
    stroke.Transparency = 0
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    stroke.Parent = l

    l.Parent = gui; gui.Parent = p

    -- Pop-in: 0 → finalSize за 0.1с (Quad/Out — мягко, без шутерного overshoot).
    TweenService:Create(l, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextSize = finalSize,
    }):Play()

    local st = os.clock()
    local TOTAL = 0.85
    local HOLD = 0.35 -- сколько держим полную видимость до fade
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local el = os.clock() - st
        if el > TOTAL then
            conn:Disconnect()
            gui:Destroy()
            return
        end
        if el > HOLD then
            local alpha = (el - HOLD) / (TOTAL - HOLD)
            l.TextTransparency = alpha
            stroke.Transparency = alpha
        end
        gui.StudsOffset = Vector3.new(0, 3.5 + el * 4, 0)
    end)
end

function MiningRenderer:_critEffect(key)
    local p = self._parts[key]; if not p then return end
    local gold = Color3.fromRGB(255, 215, 90)
    -- Золотое расширяющееся кольцо — заменяет шутерный slow-mo, локальный эффект.
    shockwave(self._parent, p.Position, gold, BS * 2.6, 0.4)
    -- Золотые chunks: 6 кусков "удар выбил золото". Меньше частиц чем у break,
    -- т.к. сам блок ещё цел.
    chunkBurst(self._parent, p.Position, gold, 6, 12)
end

function MiningRenderer:_onClick(key, x, z, y)
    local now = os.clock()
    if now - self._lastSwingAt < self._swingDelay * 0.95 then
        return
    end
    self._lastSwingAt = now

    PerfBeacon.bump("mineInvokes")
    local ok, res = pcall(function() return Net:Invoke("MineBlock", { { x = x, z = z, y = y } }) end)
    if not ok or not res then return end
    local r = res[1]; if not r or not r.success then return end
    if r.damage then
        local cached = self._blockData[key]
        local oreId = (r.oreDef and r.oreDef.id) or (cached and cached.oreId) or "dirt"
        local rarity = OreLookup.getRarity(oreId)
        local isCrit = r.crit or false
        local part = self._parts[key]
        local pos = part and part.Position or nil

        self:_dmgNumber(key, r.damage, isCrit, oreId)
        self:_hitParticles(key, oreId)
        if part then
            blockSquash(part) -- замена шутерному camera shake на hit
        end

        -- 3D-звук в точке блока. Haptics — мягкий на каждом hit, выраженный
        -- на крите. НИКАКОГО camera shake и НИКАКОГО slow-mo на ударе:
        -- в mining-сим игрок кликает 4 раза/сек, любой shake/freeze превращает
        -- картинку в кашу.
        SoundManager.playForOre("hit", oreId, rarity, pos)
        Haptics.pulse("hit")

        if isCrit then
            self:_critEffect(key)
            SoundManager.play("crit", pos)
            Haptics.pulse("crit") -- сверху hit-пульса, как «двойной тык»
        end
    end
    -- Оптимистично обновляем HP-бар, чтобы цифра реагировала без ожидания
    -- delta. Сервер всё равно пришлёт то же значение через SyncBlocks —
    -- источник правды у блочного состояния один (сервер).
    if not r.mined and r.remainingHp then
        self:_updateVisual(key, r.remainingHp)
    end
end

--[[
    Ставит блок в очередь на создание. Если он уже ждёт в очереди — обновляет
    данные на месте (последнее состояние сервера побеждает). Реальное создание
    происходит в _drainCreateQueue по бюджету на кадр.
]]
function MiningRenderer:_queueCreate(key, x, z, y, oreId, hp, maxHp, mutation)
    local existing = self._createPending[key]
    if existing then
        existing.x, existing.z, existing.y = x, z, y
        existing.oreId, existing.hp, existing.maxHp = oreId, hp, maxHp
        existing.mutation = mutation
        return
    end
    local entry = { key = key, x = x, z = z, y = y, oreId = oreId, hp = hp, maxHp = maxHp, mutation = mutation }
    self._createPending[key] = entry
    self._createQueue[#self._createQueue + 1] = entry
end

--[[
    Полностью очищает очередь создания (при снапшоте/стопе).
]]
function MiningRenderer:_clearCreateQueue()
    self._createQueue = {}
    self._createHead = 1
    self._createPending = {}
end

--[[
    Дренаж очереди: создаём до CREATE_BUDGET_PER_FRAME блоков за кадр.
    Отменённые entry'и (key убран из _createPending) пропускаем, не тратя бюджет.
]]
function MiningRenderer:_drainCreateQueue()
    local q = self._createQueue
    local n = #q
    local head = self._createHead
    if head > n then return end
    -- Гейт: шахта кладётся относительно MineZoneMarker. Пока маркер не
    -- реплицировался/не стримнулся — НЕ создаём блоки (иначе закэшируем фоллбэк
    -- и шахта уедет из зоны). Блоки остаются в очереди до появления маркера.
    -- После таймаута — фоллбэк, чтобы шахта не зависла невидимой навсегда.
    if not self._origin and self:_resolveOrigin() == nil then
        if os.clock() >= self._originDeadline then
            self._origin = self:_fallbackOrigin()
            self._log:warn("MineZoneMarker не найден за", ORIGIN_WAIT_TIMEOUT, "с — шахта на фоллбэк-точке")
        else
            return -- ждём маркер, блоки остаются в очереди
        end
    end
    local drainT0 = os.clock()
    local budget = CREATE_BUDGET_PER_FRAME
    local created = 0
    while budget > 0 and head <= n do
        local entry = q[head]
        q[head] = nil
        head += 1
        if entry and self._createPending[entry.key] == entry then
            self._createPending[entry.key] = nil
            if not self._parts[entry.key] then
                local t0 = os.clock()
                self:_createPart(entry.x, entry.z, entry.y, entry.oreId, entry.hp, entry.maxHp, entry.mutation)
                local ms = (os.clock() - t0) * 1000
                PERF.createPartCount += 1
                PERF.createPartMsSum += ms
                if ms > PERF.createPartMsMax then PERF.createPartMsMax = ms end
                created += 1
            end
            budget -= 1
        end
    end
    self._createHead = head
    if head > n then -- очередь исчерпана — сбрасываем буфер
        self._createQueue = {}
        self._createHead = 1
        self:_refreshBlockDecorations()
    end
    local drainMs = (os.clock() - drainT0) * 1000
    if drainMs > PERF.drainMsMax then PERF.drainMsMax = drainMs end
    if created > 0 then perfPublish() end
    -- FX навешивает периодический таймер (_ambientFxConn, раз в AMBIENT_FX_TICK).
    -- НЕ дёргаем _refreshAmbientFX здесь: при загрузке снапшота (2250 блоков по
    -- 25/кадр = ~90 дренажей) это давало сотни тысяч лишних итераций в момент,
    -- когда кадр и так перегружен созданием блоков.
end

--[[
    Полная замена видимых блоков. Используется один раз при заходе
    игрока (и теоретически после resetPlayer). Создание размазано по кадрам.
]]
function MiningRenderer:applySnapshot(blocks)
    PERF.snapshotCalls += 1
    PerfBeacon.bump("snapshotCalls")
    perfPublish()
    self._log:debug("Snapshot:", #blocks, "blocks")
    -- Нельзя pairs+_destroyPart в одном цикле: destroy удаляет ключ из _parts.
    local keys: { string } = {}
    for k in pairs(self._parts) do
        table.insert(keys, k)
    end
    for _, k in ipairs(keys) do
        self:_destroyPart(k)
    end
    self._activeGlows = 0
    self._activeShells = 0
    self._activeAmbientFX = 0
    self:_clearCreateQueue()
    for _, b in ipairs(blocks) do
        local x, z, y = parseKey(b.key)
        self:_queueCreate(b.key, x, z, y, b.oreId, b.hp, b.maxHp, b.mutation)
    end
end

--[[
    Точечный апдейт от сервера. Клиент верит серверу — никаких
    собственных diff-расчётов.
]]
function MiningRenderer:applyDelta(delta)
    if typeof(delta) ~= "table" then return end
    local deltaT0 = os.clock()
    local createdN = #(delta.created or {})
    local removedN = #(delta.removed or {})
    local updatedN = #(delta.updated or {})
    PERF.deltaCalls += 1
    PERF.lastBatchCreated = createdN
    PERF.totalCreatedSeen += createdN
    if createdN > PERF.maxBatchCreated then PERF.maxBatchCreated = createdN end
    PerfBeacon.bump("deltaCalls")
    PerfBeacon.bump("deltaCreated", createdN)
    PerfBeacon.bump("deltaRemoved", removedN)
    PerfBeacon.bump("deltaUpdated", updatedN)
    self._log:debug("Delta: +", createdN, "~", #(delta.updated or {}), "-", removedN)
    local fastRemove = removedN > FAST_REMOVE_THRESHOLD
    for _, k in ipairs(delta.removed or {}) do
        -- Если блок ещё ждёт создания в очереди — отменяем, чтобы не построить
        -- уже удалённый блок.
        if self._createPending[k] then self._createPending[k] = nil end
        if self._parts[k] then
            if fastRemove then
                PERF.fastRemoves += 1
                self:_destroyPart(k)
            else
                self:_animateDestroy(k)
            end
        end
    end
    for _, b in ipairs(delta.created or {}) do
        if self._parts[b.key] then
            self:_destroyPart(b.key)
        end
        local x, z, y = parseKey(b.key)
        self:_queueCreate(b.key, x, z, y, b.oreId, b.hp, b.maxHp, b.mutation)
    end
    for _, u in ipairs(delta.updated or {}) do
        local pending = self._createPending[u.key]
        if pending then
            pending.hp = u.hp -- блок ещё не создан — обновим стартовый hp
        else
            self:_updateVisual(u.key, u.hp)
        end
    end
    local deltaMs = (os.clock() - deltaT0) * 1000
    if deltaMs > PERF.applyDeltaMsMax then PERF.applyDeltaMsMax = deltaMs end
    perfPublish()
end

--[[
    Диспетчер SyncBlocks. Формат: { kind = "snapshot" | "delta", payload = ... }.
]]
function MiningRenderer:syncBlocks(message)
    if typeof(message) ~= "table" then return end
    if self:_isStale() then self:stop(); return end
    -- Детект дубля листенера: Net вызывает ВСЕ подписки с одной и той же
    -- таблицей message. Если мы уже видели этот объект — обрабатываем повторно.
    if PERF._seen[message] then
        PERF.dupFires += 1
        perfPublish()
    else
        PERF._seen[message] = os.clock()
    end
    if message.kind == "snapshot" then
        self:applySnapshot(message.payload or {})
    elseif message.kind == "delta" then
        self:applyDelta(message.payload or {})
    end
end

function MiningRenderer:toggleRarity()
    self._showRarity = not self._showRarity
    -- Включение плашек строит их лениво (один проход по видимым блокам).
    -- Выключение — просто гасит уже созданные.
    for key, d in pairs(self._blockData) do
        if self._showRarity then
            local t = self:_ensureRarityTag(key)
            if t then t.Enabled = true end
        elseif d.rarityTag then
            d.rarityTag.Enabled = false
        end
    end
    return self._showRarity
end
function MiningRenderer:toggleHPBar()
    self._showHPBar = not self._showHPBar
    -- HP-бар появляется по наведению; при выключении гасим уже созданные.
    if not self._showHPBar then
        for _, d in pairs(self._blockData) do if d.hpGui then d.hpGui.Enabled = false end end
    end
    return self._showHPBar
end

function MiningRenderer:_refreshMineRaycastSanitize()
    local result = MineZoneWorkspace.sanitize(workspace)
    self._minePlatformExcludes = result.raycastExcludes
    self._obstacleRayFilter = nil
end

function MiningRenderer:start()
    self._enabled = true
    self:_refreshMineRaycastSanitize()
    task.defer(function()
        if self._enabled and not self:_isStale() then
            self:_refreshMineRaycastSanitize()
        end
    end)
    self._origin = nil -- перечитать зону MineZoneMarker после респавна
    self._originDeadline = os.clock() + ORIGIN_WAIT_TIMEOUT
    -- Захватываем поколение ДО создания папки: новый активный renderer, любой
    -- старый автоматически считается stale и выключится на следующем тике.
    local gen = ((_G :: any).DD_RENDER_GEN or 0) + 1
    ;(_G :: any).DD_RENDER_GEN = gen
    self._gen = gen
    self:_folder()
    self:_setupInput()
    -- Один listener на SyncBlocks. start() вызывается на каждый CharacterAdded;
    -- без отписки каждый респавн дублировал обработку delta (×2, ×3…) и
    -- раздувал очередь/фризы даже с CREATE_BUDGET_PER_FRAME.
    if self._syncConn then
        self._syncConn:Disconnect(); self._syncConn = nil
        PERF.syncListeners = math.max(0, PERF.syncListeners - 1)
    end
    self._syncConn = Net:Connect("SyncBlocks", function(blocks)
        if self:_isStale() then self:stop(); return end
        if self._enabled then self:syncBlocks(blocks) end
    end)
    PERF.syncListeners += 1
    perfPublish()
    self._log:info("MiningRenderer started")
end

function MiningRenderer:stop()
    self._enabled = false
    if self._syncConn then
        self._syncConn:Disconnect(); self._syncConn = nil
        PERF.syncListeners = math.max(0, PERF.syncListeners - 1)
        perfPublish()
    end
    self:_teardownInput()
    self:_destroyCursorLight()
    for _, p in pairs(self._parts) do p:Destroy() end
    self._parts = {}; self._blockData = {}
    self._activeGlows = 0; self._activeShells = 0; self._activeAmbientFX = 0
    self:_clearCreateQueue()
    if self._parent then self._parent:Destroy(); self._parent = nil end
end

return MiningRenderer
