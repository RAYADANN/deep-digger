--!strict
-- Порядок секций и товаров магазина. Данные товаров — Constants.DEVPRODUCTS / GAMEPASSES.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

export type SectionId = "starter" | "featured" | "boosts" | "coins" | "eggs" | "gamepasses"

export type SectionDef = {
	id: SectionId,
	title: string,
	subtitle: string?,
	iconKey: string,
	accentKey: "shop" | "gold" | "luck" | "damage",
	layout: "hero" | "grid" | "list",
}

local SECTIONS: { SectionDef } = {
	{
		id = "starter",
		title = "СТАРТОВЫЙ НАБОР",
		subtitle = "Один раз — лучшая цена для новичка",
		iconKey = "icon_gift",
		accentKey = "shop",
		layout = "hero",
	},
	{
		id = "featured",
		title = "ХИТЫ ПРОДАЖ",
		subtitle = "Выгодные наборы со скидкой",
		iconKey = "icon_sparkle",
		accentKey = "gold",
		layout = "hero",
	},
	{
		id = "boosts",
		title = "БУСТЫ",
		subtitle = "Временные усиления для копания",
		iconKey = "buff_luck",
		accentKey = "luck",
		layout = "grid",
	},
	{
		id = "coins",
		title = "МОНЕТЫ",
		subtitle = "Мгновенное пополнение кошелька",
		iconKey = "coin",
		accentKey = "gold",
		layout = "list",
	},
	{
		id = "eggs",
		title = "ЯЙЦА",
		subtitle = "Вылупи редких питомцев",
		iconKey = "icon_egg",
		accentKey = "shop",
		layout = "list",
	},
	{
		id = "gamepasses",
		title = "GAME PASSES",
		subtitle = "Навсегда — без подписки",
		iconKey = "icon_crown",
		accentKey = "shop",
		layout = "list",
	},
}

local PRODUCT_ORDER: { [SectionId]: { string } } = {
	starter = { "starterPack" },
	featured = { "bundleMiner", "bundleMega" },
	boosts = {
		"boostLuck15",
		"boostLuck60",
		"boostCoins15",
		"boostCoins60",
		"boostDamage15",
		"boostSpeed15",
	},
	coins = { "coinsSmall", "coinsMedium", "coinsLarge", "coinsMega" },
	eggs = { "egg5", "egg10", "egg25" },
	gamepasses = {},
}

local GAMEPASS_ORDER = { "vip", "autoSell", "petSlots" }

local ShopCatalog = {}

function ShopCatalog.sections(): { SectionDef }
	return SECTIONS
end

function ShopCatalog.productKeys(sectionId: SectionId): { string }
	return PRODUCT_ORDER[sectionId] or {}
end

function ShopCatalog.gamepassKeys(): { string }
	return GAMEPASS_ORDER
end

function ShopCatalog.productDef(key: string): any?
	local def = (Constants.DEVPRODUCTS or {})[key]
	if typeof(def) == "table" then
		return def
	end
	return nil
end

function ShopCatalog.gamepassDef(key: string): any?
	local def = (Constants.GAMEPASSES or {})[key]
	if typeof(def) == "table" then
		return def
	end
	return nil
end

return ShopCatalog
