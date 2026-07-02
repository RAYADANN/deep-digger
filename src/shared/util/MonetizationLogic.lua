--!strict
-- MonetizationLogic.lua — Phase 12 (Монетизация).
--
-- Единственный источник формул и лукапов монетизации (по аналогии с
-- RebirthLogic / DailyLogic / PetLogic). Любой потребитель — сервер
-- (MonetizationManager, SellInventory), клиент (ShopPanel, TopBar) — обязан
-- звать функции отсюда. Дубликаты «VIP даёт +10%» в нескольких местах =
-- рассинхрон при первой смене баланса.
--
-- Эффекты геймпассов аддитивны и согласованы с daily-boost / pet coinBoost
-- стеком: VIP +10% складывается в ту же boost-стадию SellInventory, что и
-- остальные coinBoost'ы (1 + Σ daily + Σ pet + VIP).
--
-- Источник истины по владению — MarketplaceService:UserOwnsGamePassAsync
-- (дёргается MonetizationManager). Здесь читаем только кэш playerData.gamepasses
-- (булев флаг по key). Это позволяет UI/SellInventory не делать сетевых
-- запросов на каждый кадр/продажу.
--
-- API:
--   MonetizationLogic.ownsGamepass(data, key)   -> boolean
--   MonetizationLogic.isVip(data)               -> boolean
--   MonetizationLogic.coinBoost(data)           -> number  (Σ gamepass coinBoost, аддитив)
--   MonetizationLogic.petSlotBonus(data)        -> number  (Σ gamepass slotBonus)
--   MonetizationLogic.gamepassById(id)          -> def?    (reverse lookup)
--   MonetizationLogic.productById(id)           -> def?    (reverse lookup)
--   MonetizationLogic.vipNameColor()            -> Color3

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local Constants = require(shared.constants)

local MonetizationLogic = {}

local function gamepasses()
    return Constants.GAMEPASSES or {}
end

local function devproducts()
    return Constants.DEVPRODUCTS or {}
end

--[[
    Владеет ли игрок геймпассом `key`. Читает кэш playerData.gamepasses —
    MonetizationManager заполняет его из UserOwnsGamePassAsync на заходе и на
    PromptGamePassPurchaseFinished.
]]
function MonetizationLogic.ownsGamepass(data: any, key: string): boolean
    if not data or typeof(data.gamepasses) ~= "table" then
        return false
    end
    return data.gamepasses[key] == true
end

function MonetizationLogic.isVip(data: any): boolean
    return MonetizationLogic.ownsGamepass(data, "vip")
end

--[[
    Суммарный аддитивный coinBoost от геймпассов (сейчас только VIP +0.10).
    Складывается в boost-стадию SellInventory: boostMult = 1 + Σ(daily) +
    Σ(pet coinBoost) + Σ(gamepass coinBoost).
]]
function MonetizationLogic.coinBoost(data: any): number
    local sum = 0
    for key, def in pairs(gamepasses()) do
        if typeof(def) == "table" and typeof(def.coinBoost) == "number" then
            if MonetizationLogic.ownsGamepass(data, key) then
                sum += def.coinBoost
            end
        end
    end
    return sum
end

--[[
    Суммарный бонус к числу слотов питомцев от геймпассов (petSlots → +2).
    PetLogic.maxEquipped(data) = base + этот бонус.
]]
function MonetizationLogic.petSlotBonus(data: any): number
    local sum = 0
    for key, def in pairs(gamepasses()) do
        if typeof(def) == "table" and typeof(def.slotBonus) == "number" then
            if MonetizationLogic.ownsGamepass(data, key) then
                sum += def.slotBonus
            end
        end
    end
    return math.floor(sum)
end

-- Reverse-lookup по реальному Gamepass ID (для PromptGamePassPurchaseFinished).
function MonetizationLogic.gamepassById(id: number): any?
    for _, def in pairs(gamepasses()) do
        if typeof(def) == "table" and def.id == id and id ~= 0 then
            return def
        end
    end
    return nil
end

-- Reverse-lookup по внутреннему ключу (EggShopModal, DevCommands).
function MonetizationLogic.productByKey(key: string): any?
	local def = devproducts()[key]
	if typeof(def) == "table" then
		return def
	end
	return nil
end

-- Reverse-lookup по реальному DeveloperProduct ID (для ProcessReceipt).
function MonetizationLogic.productById(id: number): any?
    for _, def in pairs(devproducts()) do
        if typeof(def) == "table" and def.id == id and id ~= 0 then
            return def
        end
    end
    return nil
end

function MonetizationLogic.vipNameColor(): Color3
    local def = gamepasses().vip
    if def and typeof(def.nameColor) == "Color3" then
        return def.nameColor
    end
    return Color3.fromRGB(255, 210, 50)
end

return MonetizationLogic
