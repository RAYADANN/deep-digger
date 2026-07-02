--!strict
-- Единый реестр UI-иконок. rbxassetid — основной источник; Rojo uiAssets — для локальной итерации.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type IconKey =
	"coin"
	| "depth"
	| "tab_inventory"
	| "tab_upgrades"
	| "tab_goals"
	| "tab_journal"
	| "tab_stats"
	| "tab_rebirth"
	| "tab_leaderboard"
	| "tab_shop"
	| "tab_pets"
	| "tab_sell"
	| "tab_more"
	| "tab_home"
	| "upg_pickaxe"
	| "upg_speed"
	| "upg_fortune"
	| "upg_inventory"
	| "upg_crit"
	| "upg_multisell"
	| "upg_autosell"
	| "buff_damage"
	| "buff_luck"
	| "buff_coin"
	| "buff_multimine"
	| "icon_gift"
	| "icon_streak"
	| "icon_crown"
	| "icon_gem"
	| "icon_egg"
	| "icon_warning"
	| "icon_check"
	| "icon_close"
	| "icon_medal"
	| "icon_sparkle"
	| "icon_empty"
	| "icon_boss"
	| "icon_robux"
	| "icon_tutorial_arrow"
	| "icon_social_reward"
	| "icon_promo_code"
	| "tutorial_objective_bg"
	| "tutorial_path_marker"
	| "tutorial_goal_pin"
	| "pack_starter"
	| "pack_miner"
	| "pack_mega"

local FILE_BY_KEY: { [IconKey]: string } = {
	coin = "coin",
	depth = "depth",
	tab_inventory = "tab_inventory",
	tab_upgrades = "tab_upgrades",
	tab_goals = "tab_goals",
	tab_journal = "tab_journal",
	tab_stats = "tab_stats",
	tab_rebirth = "tab_rebirth",
	tab_leaderboard = "tab_leaderboard",
	tab_shop = "tab_shop",
	tab_pets = "tab_pets",
	tab_sell = "tab_sell",
	tab_more = "tab_more",
	tab_home = "tab_home",
	upg_pickaxe = "upg_pickaxe",
	upg_speed = "upg_speed",
	upg_fortune = "upg_fortune",
	upg_inventory = "upg_inventory",
	upg_crit = "upg_crit",
	upg_multisell = "upg_multisell",
	upg_autosell = "upg_autosell",
	buff_damage = "buff_damage",
	buff_luck = "buff_luck",
	buff_coin = "buff_coin",
	buff_multimine = "buff_multimine",
	icon_gift = "icon_gift",
	icon_streak = "icon_streak",
	icon_crown = "icon_crown",
	icon_gem = "icon_gem",
	icon_egg = "icon_egg",
	icon_warning = "icon_warning",
	icon_check = "icon_check",
	icon_close = "icon_close",
	icon_medal = "icon_medal",
	icon_sparkle = "icon_sparkle",
	icon_empty = "icon_empty",
	icon_boss = "icon_boss",
	icon_robux = "icon_robux",
	icon_tutorial_arrow = "icon_tutorial_arrow",
	icon_social_reward = "icon_social_reward",
	icon_promo_code = "icon_promo_code",
	tutorial_objective_bg = "tutorial_objective_bg",
	tutorial_path_marker = "tutorial_path_marker",
	tutorial_goal_pin = "tutorial_goal_pin",
	pack_starter = "pack_starter",
	pack_miner = "pack_miner",
	pack_mega = "pack_mega",
}

local UPGRADE_ICON: { [string]: IconKey } = {
	pickaxe = "upg_pickaxe",
	speed = "upg_speed",
	fortune = "upg_fortune",
	inventory = "upg_inventory",
	crit = "upg_crit",
	multiSell = "upg_multisell",
	autoSell = "upg_autosell",
}

local TAB_ICON: { [string]: IconKey } = {
	inventory = "tab_inventory",
	upgrades = "tab_upgrades",
	goals = "tab_goals",
	journal = "tab_journal",
	stats = "tab_stats",
	rebirth = "tab_rebirth",
	leaderboard = "tab_leaderboard",
	shop = "tab_shop",
	pets = "tab_pets",
	sell = "tab_sell",
	more = "tab_more",
	home = "tab_home",
}

-- Legacy emoji → iconKey (уведомления, старые data-поля).
local EMOJI_TO_KEY: { [string]: IconKey } = {
	["💰"] = "coin",
	["🪙"] = "coin",
	["⛏"] = "upg_pickaxe",
	["⛏️"] = "upg_pickaxe",
	["⚒"] = "tab_upgrades",
	["🎯"] = "tab_goals",
	["📖"] = "tab_journal",
	["🏆"] = "tab_leaderboard",
	["💠"] = "tab_rebirth",
	["🐾"] = "tab_pets",
	["🛒"] = "tab_shop",
	["📊"] = "tab_stats",
	["⬇"] = "depth",
	["⬇️"] = "depth",
	["📦"] = "tab_inventory",
	["⚡"] = "upg_speed",
	["🔥"] = "icon_streak",
	["🎁"] = "icon_gift",
	["👑"] = "icon_crown",
	["💎"] = "icon_gem",
	["🥚"] = "icon_egg",
	["⚠"] = "icon_warning",
	["⚠️"] = "icon_warning",
	["✓"] = "icon_check",
	["✅"] = "icon_check",
	["✕"] = "icon_close",
	["❌"] = "icon_close",
	["🏅"] = "icon_medal",
	["✨"] = "icon_sparkle",
	["📭"] = "icon_empty",
	["👹"] = "icon_boss",
	["🕳"] = "depth",
	["♻"] = "upg_autosell",
	["♻️"] = "upg_autosell",
	["🛠"] = "tab_upgrades",
	["🛠️"] = "tab_upgrades",
	["⚔"] = "buff_damage",
	["✦"] = "icon_sparkle",
}

local ACHIEVEMENT_ICON: { [string]: IconKey } = {
	first_ore = "upg_pickaxe",
	deep_100 = "depth",
	deep_500 = "depth",
	collector_10 = "tab_inventory",
	boss_slayer = "icon_boss",
	millionaire = "coin",
	shaft_finder = "icon_sparkle",
}

local ROBLOX_IMAGES: { [string]: string } = {
	coin = "rbxassetid://107741866383219",
	depth = "rbxassetid://94728814991680",
	tab_inventory = "rbxassetid://90557162643994",
	tab_upgrades = "rbxassetid://90434001784856",
	tab_goals = "rbxassetid://91744687523715",
	tab_journal = "rbxassetid://112721086732203",
	tab_stats = "rbxassetid://120823584035890",
	tab_rebirth = "rbxassetid://93667538204921",
	tab_leaderboard = "rbxassetid://96540428388673",
	tab_shop = "rbxassetid://81920992739704",
	tab_pets = "rbxassetid://135480991829541",
	tab_sell = "rbxassetid://122374239377128",
	tab_more = "rbxassetid://124582958034012",
	upg_pickaxe = "rbxassetid://126378659429587",
	upg_speed = "rbxassetid://136992578784982",
	upg_fortune = "rbxassetid://109606328247622",
	upg_inventory = "rbxassetid://81158792396433",
	upg_crit = "rbxassetid://88048766668961",
	upg_multisell = "rbxassetid://113754061849324",
	upg_autosell = "rbxassetid://82890240298361",
	buff_damage = "rbxassetid://113136306816526",
	buff_luck = "rbxassetid://139510414936011",
	buff_coin = "rbxassetid://128653844307473",
	buff_multimine = "rbxassetid://74662192549297",
	tab_home = "rbxassetid://93667538204921",
	-- Новые HUD-иконки: заполняются после upload в Creator Hub; локально — assets/ui/icon_*.png
	icon_gift = "rbxassetid://81166964840678",
	icon_streak = "rbxassetid://121927187311885",
	icon_crown = "rbxassetid://85178114144637",
	icon_gem = "rbxassetid://137562112385172",
	icon_egg = "rbxassetid://86131609535310",
	icon_warning = "rbxassetid://80667854559235",
	icon_check = "rbxassetid://89321838583234",
	icon_close = "rbxassetid://86108768543774",
	icon_medal = "rbxassetid://128106685523633",
	icon_sparkle = "rbxassetid://91984443548921",
	icon_empty = "rbxassetid://95522031196494",
	icon_boss = "rbxassetid://110231832203250",
	icon_robux = "rbxassetid://122702763748385",
	icon_tutorial_arrow = "rbxassetid://106021566118197",
	icon_social_reward = "rbxassetid://126058376087998",
	icon_promo_code = "rbxassetid://105183216335516",
	tutorial_objective_bg = "rbxassetid://95995140772550",
	tutorial_path_marker = "rbxassetid://125418711051244",
	tutorial_goal_pin = "rbxassetid://123208783123903",
	pack_starter = "rbxassetid://96686185257071",
	pack_miner = "rbxassetid://126858707388068",
	pack_mega = "rbxassetid://113358967472700",
}

local _cache: { [string]: string } = {}

local function contentIdFromInstance(inst: Instance): string?
	if inst:IsA("Image") then
		local id = (inst :: Image).ContentId
		if id ~= "" then
			return id
		end
	end
	if inst:IsA("ImageLabel") then
		local img = (inst :: ImageLabel).Image
		if img ~= "" then
			return img
		end
	end
	if inst:IsA("Decal") then
		local tex = (inst :: Decal).Texture
		if tex ~= "" then
			return tex
		end
	end
	return nil
end

local function isIconKey(key: string): boolean
	return FILE_BY_KEY[key :: IconKey] ~= nil
end

local UiAssets = {}

function UiAssets.image(key: IconKey | string): string
	local cacheKey = tostring(key)
	local cached = _cache[cacheKey]
	if cached then
		return cached
	end

	local fileName = FILE_BY_KEY[key :: IconKey] or cacheKey

	local rbxId = ROBLOX_IMAGES[fileName] or ROBLOX_IMAGES[cacheKey]
	if rbxId and rbxId ~= "" then
		_cache[cacheKey] = rbxId
		return rbxId
	end

	local root = ReplicatedStorage:FindFirstChild("uiAssets")
	if root then
		local asset = root:FindFirstChild(fileName)
		if asset then
			local id = contentIdFromInstance(asset)
			if id and id ~= "" then
				_cache[cacheKey] = id
				return id
			end
		end
	end

	_cache[cacheKey] = ""
	return ""
end

-- emoji, iconKey, achievementId или rbxassetid → content id.
function UiAssets.resolve(source: string?): string
	if not source or source == "" then
		return ""
	end
	if string.find(source, "rbxassetid://", 1, true) then
		return source
	end

	local achievementKey = ACHIEVEMENT_ICON[source]
	if achievementKey then
		return UiAssets.image(achievementKey)
	end

	local emojiKey = EMOJI_TO_KEY[source]
	if emojiKey then
		return UiAssets.image(emojiKey)
	end

	if isIconKey(source) then
		return UiAssets.image(source)
	end

	return ""
end

function UiAssets.robux(): string
	return UiAssets.image("icon_robux")
end

function UiAssets.coin(): string
	return UiAssets.image("coin")
end

function UiAssets.tab(tabId: string): string
	local key = TAB_ICON[tabId]
	if key then
		return UiAssets.image(key)
	end
	return ""
end

function UiAssets.upgrade(upgradeId: string): string
	local key = UPGRADE_ICON[upgradeId]
	if key then
		return UiAssets.image(key)
	end
	return ""
end

local BUFF_ICON: { [string]: IconKey } = {
	damage = "buff_damage",
	luck = "buff_luck",
	coin = "buff_coin",
	multiMine = "buff_multimine",
	damageBoost = "buff_damage",
	luckBoost = "buff_luck",
	coinBoost = "buff_coin",
	multiMine = "buff_multimine",
	coins = "buff_coin",
}

function UiAssets.buff(kind: string): string
	local key = BUFF_ICON[kind]
	if key then
		return UiAssets.image(key)
	end
	return ""
end

function UiAssets.achievement(achievementId: string): string
	local key = ACHIEVEMENT_ICON[achievementId]
	if key then
		return UiAssets.image(key)
	end
	return ""
end

return UiAssets
