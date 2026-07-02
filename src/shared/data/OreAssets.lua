--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OreIconPixelLoader = require(script.Parent.OreIconPixelLoader)

local OreAssets = {}

-- Creator Hub upload из assets/ui/ores/*.png (2026-06-24).
local ROBLOX_IMAGES: { [string]: string } = {
	amber = "rbxassetid://134527998694949",
	amethyst = "rbxassetid://72538263758871",
	ancient_relic = "rbxassetid://113871422226887",
	aquamarine = "rbxassetid://95528140690712",
	astralite = "rbxassetid://71403472928680",
	black_opal = "rbxassetid://86901155114854",
	blood_opal = "rbxassetid://123431776839798",
	calcite = "rbxassetid://106513655221770",
	cinnabar = "rbxassetid://96890055946164",
	clay = "rbxassetid://126703014492563",
	coal = "rbxassetid://122035432452912",
	copper = "rbxassetid://70620441132074",
	crimson_rock = "rbxassetid://70609569569492",
	dark_quartz = "rbxassetid://82679908528158",
	diamond = "rbxassetid://92055666748626",
	dino_egg = "rbxassetid://111908261723689",
	dirt = "rbxassetid://81548374559246",
	eclipse_stone = "rbxassetid://76541427139244",
	emerald = "rbxassetid://95468665335905",
	fire_opal = "rbxassetid://94266790569161",
	fossil = "rbxassetid://110947240265077",
	galaxy_opal = "rbxassetid://80243828576383",
	gold = "rbxassetid://87162546932208",
	iron = "rbxassetid://132172110633073",
	jade_idol = "rbxassetid://88928560028400",
	limestone = "rbxassetid://85647308142442",
	malachite = "rbxassetid://118135536753867",
	marble = "rbxassetid://94233699581862",
	marble_chip = "rbxassetid://119995900741395",
	moonstone = "rbxassetid://88470284029329",
	nebula_crystal = "rbxassetid://86863191972636",
	obsidian = "rbxassetid://70873493150386",
	oil_deposit = "rbxassetid://135377918692262",
	pebble = "rbxassetid://81619404931063",
	phoenix_heart = "rbxassetid://103133499241358",
	prismarine_core = "rbxassetid://99873462434096",
	redstone = "rbxassetid://138946234549617",
	root = "rbxassetid://87646775965210",
	ruby = "rbxassetid://133718195640264",
	sapphire = "rbxassetid://116699521295033",
	selenite = "rbxassetid://128772359456337",
	seraph_tear = "rbxassetid://130223251377664",
	shadow_gem = "rbxassetid://79258315626483",
	silver = "rbxassetid://78484892937663",
	singularity_shard = "rbxassetid://109244762953528",
	soul_crystal = "rbxassetid://92772480970581",
	spirit_shard = "rbxassetid://107956738869863",
	star_fragment = "rbxassetid://74694905621091",
	star_sapphire = "rbxassetid://100558068781917",
	stone = "rbxassetid://118173566273481",
	topaz = "rbxassetid://76185685378800",
	void_crystal = "rbxassetid://102210849469819",
	void_stone = "rbxassetid://79509766359151",
	white_quartz = "rbxassetid://109467493857134",
}

local _rbxCache: { [string]: string } = {}
local _hasPixels: { [string]: boolean } = {}
local _contentCache: { [string]: Content } = {}
local _uiAssetCache: { [string]: boolean } = {}
local _iconHintWarned = false

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

local function getOresFolder(): Folder?
	local root = ReplicatedStorage:FindFirstChild("uiAssets")
	local ores = root and root:FindFirstChild("ores")
	if ores and ores:IsA("Folder") then
		return ores
	end
	return nil
end

local function warnIconHintOnce()
	if _iconHintWarned then
		return
	end
	if OreIconPixelLoader.isApiAvailable() then
		return
	end
	if OreAssets.image("coal") ~= "" or OreAssets.hasUiAssetImage("coal") then
		return
	end
	_iconHintWarned = true
	warn(
		"[OreIcons] Иконки руд: Game Settings → Security → Allow Mesh / Image APIs. "
			.. "Без этого в журнале/инвентаре — emoji-fallback (baked-пиксели из OreIconPixels)."
	)
end

local function findUiAsset(oreId: string): Instance?
	local ores = getOresFolder()
	if not ores then
		return nil
	end
	return ores:FindFirstChild(oreId)
end

local function contentFromUiAsset(oreId: string): Content?
	local asset = findUiAsset(oreId)
	if not asset or not asset:IsA("Image") then
		return nil
	end
	local ok, content = pcall(Content.fromObject, asset)
	if ok and content then
		return content
	end
	return nil
end

function OreAssets.image(oreId: string): string
	local cached = _rbxCache[oreId]
	if cached then
		return cached
	end

	local rbxId = ROBLOX_IMAGES[oreId]
	if rbxId and rbxId ~= "" then
		_rbxCache[oreId] = rbxId
		return rbxId
	end

	local asset = findUiAsset(oreId)
	if asset then
		local id = contentIdFromInstance(asset)
		if id and id ~= "" then
			_rbxCache[oreId] = id
			return id
		end
	end

	_rbxCache[oreId] = ""
	return ""
end

function OreAssets.hasUiAssetImage(oreId: string): boolean
	if _uiAssetCache[oreId] ~= nil then
		return _uiAssetCache[oreId]
	end
	local has = contentFromUiAsset(oreId) ~= nil
	_uiAssetCache[oreId] = has
	return has
end

function OreAssets.hasPixelIcon(oreId: string): boolean
	if not OreIconPixelLoader.isApiAvailable() then
		return false
	end
	if _hasPixels[oreId] ~= nil then
		return _hasPixels[oreId]
	end
	local has = OreIconPixelLoader.has(oreId)
	_hasPixels[oreId] = has
	return has
end

function OreAssets.hasImage(oreId: string): boolean
	return OreAssets.image(oreId) ~= ""
		or OreAssets.hasUiAssetImage(oreId)
		or OreAssets.hasPixelIcon(oreId)
end

--[[
    Content для ImageLabel.ImageContent, если нет rbxassetid-строки.
    Порядок: uiAssets/ores (Rojo Image) → baked pixels (EditableImage API).
]]
function OreAssets.iconContent(oreId: string): Content?
	warnIconHintOnce()

	if OreAssets.image(oreId) ~= "" then
		return nil
	end

	local cached = _contentCache[oreId]
	if cached then
		return cached
	end

	local fromAsset = contentFromUiAsset(oreId)
	if fromAsset then
		_contentCache[oreId] = fromAsset
		return fromAsset
	end

	local fromPixels = OreIconPixelLoader.content(oreId)
	if fromPixels then
		_contentCache[oreId] = fromPixels
	end
	return fromPixels
end

-- Совместимость со старыми вызовами.
function OreAssets.pixelContent(oreId: string): Content?
	return OreAssets.iconContent(oreId)
end

return OreAssets
