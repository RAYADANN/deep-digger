--!strict
-- PetManager.lua — Phase 11 (Pets MVP).
--
-- Серверная часть пет-системы. Структура совпадает с RebirthManager (Phase 9)
-- и DailyReward (Phase 10): DI через Deps, Net:Handle в new(), onProfileLoaded
-- идемпотентен.
--
-- Хендлеры:
--   Net:Handle("HatchEgg", eggId, count) — купить + вылупить count яиц у машины.
--                                    Серверная валидация монет, weighted roll
--                                    через EggManager/PetLogic, запись в
--                                    playerData.pets, авто-equip первого пета
--                                    если слот пуст. Возвращает hatched-список
--                                    для клиентского PetHatchFX.
--   Net:Handle("EquipPet", uid)    — экипировать пета (1 slot MVP: заменяет).
--   Net:Handle("UnequipPet")       — снять экипировку.
--
-- onProfileLoaded(player) — гарантирует наличие полей (pets / equippedPet /
--   petUidCounter) и чистит «висячий» equippedPet (uid, которого нет в pets).
--
-- DevHooks: devHatch / devGivePet / devClearPets для DevCommands.
--
-- Эффекты петов (damage / luck / coins / multiMine) этот модуль НЕ применяет —
-- они считаются в MiningEngine / SellInventory через PetLogic. PetManager
-- отвечает только за владение и экипировку.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local Net = require(modules.Net)
local PetLogic = require(shared.util.PetLogic)
local PetDatabase = require(shared.data.PetDatabase)
local EggManager = require(script.Parent.EggManager)

export type Deps = {
    profileManager: any,
    onProfileChanged: ((player: Player) -> ())?,
    notify: ((player: Player, payload: any) -> ())?,
}

local PetManager = {}
PetManager.__index = PetManager

-- MVP: единственный тип яйца.
local DEFAULT_EGG_ID = "basic"

function PetManager.new(deps: Deps)
    local self = setmetatable({}, PetManager)
    self._log = Logger.new("PetManager")
    self._profileManager = deps.profileManager
    self._onProfileChanged = deps.onProfileChanged
    self._notify = deps.notify

    Net:Handle("HatchEgg", function(player: Player, eggId: string?, count: number?, currency: string?)
        return self:_handleHatch(player, eggId, count, currency)
    end)
    Net:Handle("EquipPet", function(player: Player, uid: string?)
        return self:_handleEquip(player, uid)
    end)
    Net:Handle("UnequipPet", function(player: Player, uid: string?)
        return self:_handleUnequip(player, uid)
    end)

    self._log:info("PetManager initialized")
    return self
end

function PetManager:_data(player: Player)
    return self._profileManager:getData(player)
end

function PetManager:_sync(player: Player)
    if self._onProfileChanged then
        self._onProfileChanged(player)
    end
end

local function ensurePetFields(data: any)
    if typeof(data.pets) ~= "table" then
        data.pets = {}
    end
    if typeof(data.petUidCounter) ~= "number" then
        data.petUidCounter = 0
    end
    -- equippedPet может быть nil (ничего не экипировано) — это валидно.
    if data.equippedPet ~= nil and typeof(data.equippedPet) ~= "string" and typeof(data.equippedPet) ~= "table" then
        data.equippedPet = nil
    end
end

-- Найти запись пета по uid в data.pets.
local function findRecord(data: any, uid: string): any?
    for _, rec in ipairs(data.pets) do
        if typeof(rec) == "table" and rec.uid == uid then
            return rec
        end
    end
    return nil
end

-- Сгенерировать новый uid через монотонный счётчик.
local function nextUid(data: any): string
    data.petUidCounter = (data.petUidCounter or 0) + 1
    return "p" .. tostring(data.petUidCounter)
end

-- Добавить пета по petId, вернуть запись { uid, petId } (или nil если petId
-- неизвестен).
local function addPet(data: any, petId: string): any?
    if not PetDatabase.get(petId) then
        return nil
    end
    local rec = { uid = nextUid(data), petId = petId }
    table.insert(data.pets, rec)
    return rec
end

-- Phase 12: нормализует список экипированных uid'ов обратно в поле
-- equippedPet. 0 → nil, 1 → строка (backward-compat со старыми 1-slot
-- профилями), >1 → список (multi-slot после gamepass «+2 pet slots»).
-- PetLogic.getEquippedUids читает обе формы.
local function storeEquipped(uids: { string }): any
    if #uids == 0 then
        return nil
    elseif #uids == 1 then
        return uids[1]
    end
    local copy = {}
    for _, u in ipairs(uids) do
        table.insert(copy, u)
    end
    return copy
end

-- Сериализация записи пета для клиента (FX + панель): добавляем def-поля.
local function toPayload(rec: any): any?
    if not rec then
        return nil
    end
    local def = PetDatabase.get(rec.petId)
    if not def then
        return nil
    end
    return {
        uid = rec.uid,
        petId = rec.petId,
        name = def.name,
        rarity = def.rarity,
        icon = def.icon,
        effect = { kind = def.effect.kind, value = def.effect.value },
    }
end

--[[
    Внутренняя вылупка `n` петов в data.pets (без списания монет — цену
    проверяет вызывающий). Возвращает hatched-список (toPayload). Авто-equip
    первого пета, если ничего не экипировано (жанровый UX: первый пет сразу
    даёт буст без лишнего клика). Используется и платным HatchEgg, и
    бесплатным grantHatch (Phase 12 «Egg 10x» / dev).
]]
function PetManager:_hatchInto(data: any, eggId: string, n: number)
    local petIds = EggManager.hatch(eggId, n)
    local hatched = {}
    for _, petId in ipairs(petIds) do
        local rec = addPet(data, petId)
        if rec then
            table.insert(hatched, toPayload(rec))
        end
    end
    if #PetLogic.getEquippedUids(data) == 0 and #hatched > 0 then
        data.equippedPet = hatched[1].uid
    end
    return hatched
end

--[[
    HatchEgg: купить и вылупить count яиц. `currency` — "coins" (по умолчанию)
    или "gems" (P1.6: Desert Egg за кристаллы). Возвращает hatched-список для
    клиентского PetHatchFX. Авто-equip первого пета если слот пуст.
]]
function PetManager:_handleHatch(player: Player, eggId: string?, count: number?, currency: string?)
    local data = self:_data(player)
    if not data then
        return { success = false, error = "no_profile", message = "Профиль не загружен" }
    end
    ensurePetFields(data)

    local resolvedEggId = if typeof(eggId) == "string" and eggId ~= "" then eggId else DEFAULT_EGG_ID
    local useGems = currency == "gems"
    local n = EggManager.clampCount(count)
    local egg = EggManager.getEgg(resolvedEggId)
    if not egg then
        return { success = false, error = "no_egg", message = "Яйцо не настроено" }
    end

    if useGems then
        if not EggManager.acceptsGems(resolvedEggId) then
            return { success = false, error = "no_gem_price", message = "Это яйцо нельзя купить за кристаллы" }
        end
        local cost = EggManager.totalPrice(resolvedEggId, n, "gems")
        local gems = data.gems or 0
        if gems < cost then
            return {
                success = false,
                error = "not_enough_gems",
                message = ("Не хватает %d кристаллов"):format(cost - gems),
                requiredGems = cost,
            }
        end
        data.gems = gems - cost
        local hatched = self:_hatchInto(data, resolvedEggId, n)
        self:_sync(player)
        self._log:info("Hatch(gems) by", player.UserId, "- egg:", resolvedEggId, "- count:", n, "- gems:", cost, "- pets:", #hatched)
        return {
            success = true,
            hatched = hatched,
            gemsSpent = cost,
            count = n,
            eggId = resolvedEggId,
            currency = "gems",
        }
    end

    local cost = EggManager.totalCost(resolvedEggId, n)
    local coins = data.coins or 0
    if coins < cost then
        return {
            success = false,
            error = "not_enough_coins",
            message = ("Не хватает %d монет"):format(cost - coins),
            requiredCoins = cost,
        }
    end

    data.coins = coins - cost
    local hatched = self:_hatchInto(data, resolvedEggId, n)

    self:_sync(player)

    self._log:info(
        "Hatch by", player.UserId,
        "- egg:", resolvedEggId,
        "- count:", n,
        "- cost:", cost,
        "- pets:", #hatched
    )

    return {
        success = true,
        hatched = hatched,
        coinsSpent = cost,
        count = n,
        eggId = resolvedEggId,
        currency = "coins",
    }
end

--[[
    EquipPet: экипировать пета. Слотов maxEquipped(data) — 1 на старте, 3 с
    геймпассом «+2 pet slots» (Phase 12). Поведение:
      * uid уже экипирован → no-op success (idempotent).
      * есть свободный слот → добавляем.
      * слоты заняты → вытесняем самого старого (FIFO) — согласовано со
        старым 1-slot UX, где equip «заменял» текущего пета.
]]
function PetManager:_handleEquip(player: Player, uid: string?)
    local data = self:_data(player)
    if not data then
        return { success = false, error = "no_profile" }
    end
    ensurePetFields(data)
    if typeof(uid) ~= "string" or uid == "" then
        return { success = false, error = "bad_uid", message = "Неверный питомец" }
    end
    if not findRecord(data, uid) then
        return { success = false, error = "not_owned", message = "Питомец не найден" }
    end

    local maxN = PetLogic.maxEquipped(data)
    local current = PetLogic.getEquippedUids(data)
    for _, u in ipairs(current) do
        if u == uid then
            -- Уже экипирован — идемпотентный успех.
            return { success = true, equippedPet = data.equippedPet }
        end
    end
    table.insert(current, uid)
    -- Вытесняем самого старого, пока не уложимся в слоты.
    while #current > maxN do
        table.remove(current, 1)
    end
    data.equippedPet = storeEquipped(current)
    self:_sync(player)
    return { success = true, equippedPet = data.equippedPet }
end

--[[
    UnequipPet: снять экипировку. Если передан uid — снимаем именно его
    (multi-slot). Без uid — очищаем все слоты. Idempotent.
]]
function PetManager:_handleUnequip(player: Player, uid: string?)
    local data = self:_data(player)
    if not data then
        return { success = false, error = "no_profile" }
    end
    ensurePetFields(data)
    if typeof(uid) == "string" and uid ~= "" then
        local current = PetLogic.getEquippedUids(data)
        local kept: { string } = {}
        for _, u in ipairs(current) do
            if u ~= uid then
                table.insert(kept, u)
            end
        end
        data.equippedPet = storeEquipped(kept)
    else
        data.equippedPet = nil
    end
    self:_sync(player)
    return { success = true, equippedPet = data.equippedPet }
end

--[[
    Вызывается из init.server.lua после ProfileManager:loadProfile.
    Идемпотентен: чинит поля и «висячий» equippedPet (uid удалённого пета).
]]
function PetManager:onProfileLoaded(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    ensurePetFields(data)
    -- Чистим equippedPet от uid'ов удалённых петов, сохраняя multi-slot
    -- (geteEquippedUids уже клампит длину по maxEquipped(data)).
    local equipped = PetLogic.getEquippedUids(data)
    local valid: { string } = {}
    for _, uid in ipairs(equipped) do
        if findRecord(data, uid) then
            table.insert(valid, uid)
        end
    end
    data.equippedPet = storeEquipped(valid)
end

----------------------------------------------------------------------
-- DevHooks (DevCommands, только Studio)
----------------------------------------------------------------------

--[[
    grantHatch: бесплатно вылупить `count` петов (без списания монет). Публичный
    хук для Phase 12 (девпродукт «Egg 10x» в MonetizationManager) и DevCommands.
    Возвращает hatched-список для клиентского PetHatchFX.
]]
function PetManager:grantHatch(player: Player, count: number?, eggId: string?)
    local data = self:_data(player)
    if not data then
        return nil
    end
    ensurePetFields(data)
    local n = EggManager.clampCount(count)
    local resolvedEggId = if typeof(eggId) == "string" and eggId ~= "" then eggId else DEFAULT_EGG_ID
    local hatched = self:_hatchInto(data, resolvedEggId, n)
    self:_sync(player)
    return hatched
end

-- /egg [N] и /hatch: бесплатно вылупить count петов (без списания монет).
function PetManager:devHatch(player: Player, count: number?)
    return self:grantHatch(player, count)
end

-- /pet <id>: выдать конкретного пета по petId.
function PetManager:devGivePet(player: Player, petId: string)
    local data = self:_data(player)
    if not data then
        return nil
    end
    ensurePetFields(data)
    local rec = addPet(data, petId)
    if not rec then
        return nil
    end
    if #PetLogic.getEquippedUids(data) == 0 then
        data.equippedPet = rec.uid
    end
    self:_sync(player)
    return toPayload(rec)
end

-- /clearpets: удалить всех петов и снять экипировку.
function PetManager:devClearPets(player: Player)
    local data = self:_data(player)
    if not data then
        return
    end
    data.pets = {}
    data.equippedPet = nil
    data.petUidCounter = 0
    self:_sync(player)
end

return PetManager
