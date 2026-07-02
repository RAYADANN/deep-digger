--!strict
-- Декодированные PNG-иконки руд (64×64 RGBA). Генерация: python tools/bake_ore_icons.py
-- Требует Game Settings → Security → Allow Mesh / Image APIs (EditableImage).

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:FindFirstChild("shared") :: Folder
local Base64 = require(shared.util.Base64)

local OreIconPixelLoader = {}

local PIXEL_SIZE = 64
local _folder: Folder? = nil
local _contentCache: { [string]: Content } = {}
local _editableCache: { [string]: EditableImage } = {}
local _apiState: "unknown" | "yes" | "no" = "unknown"
local _apiWarned = false
local _probing = false

local function getFolder(): Folder
	if _folder then
		return _folder
	end
	local data = shared:FindFirstChild("data")
	local found = data and data:FindFirstChild("OreIconPixels")
	if not found or not found:IsA("Folder") then
		error("OreIconPixels folder missing under ReplicatedStorage.shared.data")
	end
	_folder = found
	return _folder
end

local function loadModule(oreId: string): string?
	local mod = getFolder():FindFirstChild(oreId)
	if not mod or not mod:IsA("ModuleScript") then
		return nil
	end
	local ok, data = pcall(require, mod)
	if not ok or type(data) ~= "string" or data == "" then
		return nil
	end
	return data
end

--[[
    CreateEditableImage в Studio может «успешно» вернуть объект в pcall, но
    WritePixelsBuffer падает, если API выключен в Security. Проверяем полный
    цикл один раз; параллельные вызовы во время пробы не трогают API.
]]
function OreIconPixelLoader.isApiAvailable(): boolean
	if _apiState == "yes" then
		return true
	end
	if _apiState == "no" then
		return false
	end
	if _probing then
		return false
	end

	_probing = true
	local ok, err = pcall(function()
		local probe = AssetService:CreateEditableImage({ Size = Vector2.new(1, 1) })
		probe:WritePixelsBuffer(Vector2.zero, Vector2.new(1, 1), buffer.create(4))
		probe:Destroy()
	end)
	_probing = false
	_apiState = if ok then "yes" else "no"

	if not ok and not _apiWarned then
		_apiWarned = true
		warn(
			"[OreIcons] EditableImage недоступен — baked-fallback отключён. "
				.. "Иконки из OreAssets ROBLOX_IMAGES работают без этого. ",
			err
		)
	end
	return ok
end

function OreIconPixelLoader.has(oreId: string): boolean
	return getFolder():FindFirstChild(oreId) ~= nil
end

function OreIconPixelLoader.content(oreId: string): Content?
	if not OreIconPixelLoader.isApiAvailable() then
		return nil
	end

	local cached = _contentCache[oreId]
	if cached then
		return cached
	end

	local b64 = loadModule(oreId)
	if not b64 then
		return nil
	end

	local ok, raw = pcall(Base64.decode, b64)
	if not ok or raw == nil then
		return nil
	end

	local expected = PIXEL_SIZE * PIXEL_SIZE * 4
	if buffer.len(raw) ~= expected then
		return nil
	end

	local okBuild, built = pcall(function()
		local editable = AssetService:CreateEditableImage({ Size = Vector2.new(PIXEL_SIZE, PIXEL_SIZE) })
		editable:WritePixelsBuffer(Vector2.zero, Vector2.new(PIXEL_SIZE, PIXEL_SIZE), raw)
		_editableCache[oreId] = editable
		return Content.fromObject(editable)
	end)
	if not okBuild then
		_apiState = "no"
		return nil
	end

	_contentCache[oreId] = built
	return built
end

return OreIconPixelLoader
