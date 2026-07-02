--!strict
-- SoundManager.lua — клиентский синглтон для воспроизведения звуков.
--
-- Принципы:
--   * Один Sound-инстанс на eventId хранится в SoundService под папкой DeepDigger_Sounds.
--     На каждый play() — :Stop() + :Play() (не создаём новый инстанс).
--   * 3D звуки: клонируем кэшированный Sound в Workspace, привязываем к временному
--     Attachment, через 2 сек чистим. Атрибуты Volume/Pitch берутся из SoundDatabase.
--   * Категории "sfx" и "ui" имеют отдельные SoundGroup'ы — будущий setVolume панелью
--     настроек правит их Volume глобально.
--   * Никаких yield'ов в горячем пути play(); preload через ContentProvider один раз
--     при start().

local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local SoundDatabase = require(ReplicatedStorage:WaitForChild("shared").data.SoundDatabase)
local Logger = require(ReplicatedStorage:WaitForChild("shared").util.Logger)

local SoundManager = {}

local FOLDER_NAME = "DeepDigger_Sounds"
local SFX_GROUP = "DD_SFX"
local UI_GROUP = "DD_UI"
local MUSIC_GROUP = "DD_Music"

local log = Logger.new("SoundManager")

local _started = false
local _folder: Folder? = nil
local _sfxGroup: SoundGroup? = nil
local _uiGroup: SoundGroup? = nil
local _musicGroup: SoundGroup? = nil
local _cache: { [string]: Sound } = {}
-- Phase 7 TODO playtest: некоторые soundIds в SoundDatabase «битые» —
-- Roblox в 2024+ ужесточил audio-модерацию, часть старых IDs больше не
-- отдаётся как Audio (status = Failure). Если play2D / play3D будут пытаться
-- проиграть их, на каждом клике `:Clone()` повторяет запрос и спамит
-- output `Asset type does not match requested type`. Поэтому помечаем
-- такие events как broken один раз при preload — дальше Play() для них
-- silently no-op. Список broken event'ов попадает в один warning на старте,
-- чтобы было видно ЧТО менять в SoundDatabase.
local _broken: { [string]: boolean } = {}
local _loopSound: Sound? = nil
local _loopEventId: string? = nil
local _loopFadeTween: Tween? = nil

local function ensureGroup(name: string): SoundGroup
    local existing = SoundService:FindFirstChild(name)
    if existing and existing:IsA("SoundGroup") then
        return existing
    end
    local g = Instance.new("SoundGroup")
    g.Name = name
    g.Volume = 1
    g.Parent = SoundService
    return g
end

local function applyPitch(sound: Sound, entry: SoundDatabase.SoundEntry)
    local range = entry.pitchRange
    if range then
        sound.PlaybackSpeed = range.min + math.random() * (range.max - range.min)
    else
        sound.PlaybackSpeed = 1
    end
end

local function buildSound(eventId: string, entry: SoundDatabase.SoundEntry): Sound
    local sound = Instance.new("Sound")
    sound.Name = eventId
    sound.SoundId = entry.soundId
    sound.Volume = entry.volume
    sound.RollOffMinDistance = 10
    sound.RollOffMaxDistance = 120
    local cat = SoundDatabase.getCategory(eventId)
    sound.SoundGroup = if cat == "ui" then _uiGroup
        elseif cat == "music" then _musicGroup
        else _sfxGroup
    return sound
end

function SoundManager.start(parent: Instance?)
    if _started then
        return
    end
    _started = true

    _sfxGroup = ensureGroup(SFX_GROUP)
    _uiGroup = ensureGroup(UI_GROUP)
    _musicGroup = ensureGroup(MUSIC_GROUP)
    _musicGroup.Volume = 0.85

    local holder = parent or SoundService
    local existing = holder:FindFirstChild(FOLDER_NAME)
    if existing and existing:IsA("Folder") then
        _folder = existing
    else
        local f = Instance.new("Folder")
        f.Name = FOLDER_NAME
        f.Parent = holder
        _folder = f
    end

    -- Прогрев кэша + asset preload, чтобы первый клик не висел.
    local assets: { Sound } = {}
    -- Обратный лукап `soundId → { eventId, ... }` — один soundId может быть
    -- расшарен между событиями (break_common == break_uncommon в Phase 7).
    -- Поэтому маркируем broken по soundId, потом разворачиваем во все
    -- зависимые eventId. Без этого callback PreloadAsync пришлёт нам
    -- contentString=soundId, и мы не сможем сопоставить с eventId напрямую.
    local soundIdToEvents: { [string]: { string } } = {}
    for eventId, entry in pairs(SoundDatabase.EVENTS) do
        local sound = buildSound(eventId, entry)
        sound.Parent = _folder
        _cache[eventId] = sound
        table.insert(assets, sound)
        local list = soundIdToEvents[entry.soundId]
        if not list then
            list = {}
            soundIdToEvents[entry.soundId] = list
        end
        table.insert(list, eventId)
    end

    task.spawn(function()
        -- PreloadAsync с per-asset callback (Roblox 2024+ API). Если контекст
        -- не поддерживает callback (старый Studio) — fallback к pcall без
        -- callback'a, потом проверим IsLoaded.
        local ok, err = pcall(function()
            ContentProvider:PreloadAsync(assets, function(contentString: string, fetchStatus: Enum.AssetFetchStatus)
                if fetchStatus == Enum.AssetFetchStatus.Failure then
                    local events = soundIdToEvents[contentString]
                    if events then
                        for _, eventId in ipairs(events) do
                            _broken[eventId] = true
                        end
                    end
                end
            end)
        end)
        if not ok then
            log:warn("PreloadAsync failed:", err, "— falling back to IsLoaded check")
        end

        -- Подстраховка: если callback не пришёл (старый Studio / редкая
        -- асинхронная ошибка), детектим broken по `Sound.IsLoaded = false`.
        -- К этому моменту PreloadAsync завершился — broken-сounds не загрузятся.
        for eventId, sound in pairs(_cache) do
            if not _broken[eventId] and not sound.IsLoaded then
                _broken[eventId] = true
            end
        end

        local brokenList: { string } = {}
        for eventId, _ in pairs(_broken) do
            table.insert(brokenList, eventId)
        end
        if #brokenList > 0 then
            table.sort(brokenList)
            log:warn(("Broken audio assets in SoundDatabase (%d events): %s — replace `soundId` в shared/data/SoundDatabase.lua"):format(
                #brokenList,
                table.concat(brokenList, ", ")
            ))
        end
    end)

    log:info("SoundManager started (", #assets, "events)")
end

local function play2D(eventId: string)
    -- Phase 7 TODO playtest hardening: silently игнорируем broken soundIds.
    -- Иначе :Play() триггерит повторный asset-load на каждом клике, и
    -- Studio output превращается в спам `Asset type does not match`.
    if _broken[eventId] then
        return
    end
    local sound = _cache[eventId]
    if not sound then
        return
    end
    local entry = SoundDatabase.get(eventId)
    if entry then
        applyPitch(sound, entry)
    end
    sound:Stop()
    sound:Play()
end

local function play3D(eventId: string, position: Vector3)
    if _broken[eventId] then
        return
    end
    local cached = _cache[eventId]
    local entry = SoundDatabase.get(eventId)
    if not cached or not entry then
        return
    end

    -- Клонируем, чтобы overlapping звуки в разных точках не глушили друг друга.
    -- Attachment нужен для позиционного звука без привязки к Part'у.
    local attach = Instance.new("Attachment")
    attach.WorldPosition = position
    attach.Parent = Workspace.Terrain

    local clone = cached:Clone()
    clone.Parent = attach
    applyPitch(clone, entry)
    clone:Play()

    -- Чистка через 2 сек или после Ended (что раньше). Debris страхует от утечки,
    -- если Ended почему-то не стрельнет (короткие звуки с loop=false обычно норм).
    Debris:AddItem(attach, 2)
    clone.Ended:Connect(function()
        if attach.Parent then
            attach:Destroy()
        end
    end)
end

function SoundManager.play(eventId: string, position: Vector3?)
    if not _started then
        return
    end
    if position then
        play3D(eventId, position)
    else
        play2D(eventId)
    end
end

-- Хелпер для рудно-зависимых событий: SoundManager.playForOre("hit"|"break", oreId).
-- Резолв rarity делегирован OreLookup, чтобы не таскать OreDatabase напрямую.
function SoundManager.playForOre(
    eventType: string,
    oreId: string,
    rarity: string?,
    position: Vector3?
)
    if not _started then
        return
    end
    local r = rarity or "common"
    local eventId
    if eventType == "hit" then
        eventId = SoundDatabase.hitEventForRarity(r)
    elseif eventType == "break" then
        eventId = SoundDatabase.breakEventForOre(oreId, r)
    else
        return
    end
    SoundManager.play(eventId, position)
end

function SoundManager.setVolume(category: string, volume: number)
    volume = math.clamp(volume, 0, 1)
    if category == "sfx" and _sfxGroup then
        _sfxGroup.Volume = volume
    elseif category == "ui" and _uiGroup then
        _uiGroup.Volume = volume
    elseif category == "music" and _musicGroup then
        _musicGroup.Volume = volume
    end
end

-- Ambient loop для слоёв. Отдельный инстанс, не трогает one-shot кэш.
-- targetVolume — абсолютная громкость; если nil, берётся из SoundDatabase.
function SoundManager.playLoop(eventId: string, targetVolume: number?)
	if not _started then
		return
	end
	if _loopEventId == eventId and _loopSound and _loopSound.IsPlaying then
		return
	end

	-- Всегда гасим предыдущий loop при смене трека (в т.ч. если новый broken).
	if _loopSound then
		SoundManager.stopLoop(0.4)
	end

	if _broken[eventId] then
		return
	end

	local entry = SoundDatabase.get(eventId)
	if not entry or not _folder then
		return
	end

	local sound = buildSound(eventId, entry)
    sound.Looped = entry.loop == true
    sound.Volume = 0
    if entry.playbackSpeed then
        sound.PlaybackSpeed = entry.playbackSpeed
    end
    sound.Parent = _folder
    sound:Play()

    local target = targetVolume or entry.volume
    if _loopFadeTween then _loopFadeTween:Cancel() end
    _loopFadeTween = TweenService:Create(sound, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Volume = target })
    _loopFadeTween:Play()

    _loopSound = sound
    _loopEventId = eventId
end

function SoundManager.stopLoop(fadeSec: number?)
    if not _loopSound then return end
    local sound = _loopSound
    _loopSound = nil
    _loopEventId = nil
    if _loopFadeTween then
        _loopFadeTween:Cancel()
        _loopFadeTween = nil
    end
    local fade = fadeSec or 0.5
    if fade <= 0 then
        sound:Stop()
        sound:Destroy()
        return
    end
    local tw = TweenService:Create(sound, TweenInfo.new(fade, Enum.EasingStyle.Quad), { Volume = 0 })
    tw:Play()
    tw.Completed:Connect(function()
        sound:Stop()
        sound:Destroy()
    end)
end

return SoundManager
