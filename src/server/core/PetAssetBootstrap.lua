--!strict
-- Копирует Workspace.Pets и Workspace.Eggs в ReplicatedStorage.PetKit при старте
-- сервера — клиенты клонируют оттуда (без гонки с Workspace-каталогом).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Logger = require(ReplicatedStorage:WaitForChild("shared").util.Logger)
local PetDatabase = require(ReplicatedStorage:WaitForChild("shared").data.PetDatabase)

local KIT_NAME = "PetKit"
local log = Logger.new("PetAssetBootstrap")

local PetAssetBootstrap = {}

local function cloneModels(source: Folder, dest: Folder)
	for _, child in ipairs(source:GetChildren()) do
		if child:IsA("Model") then
			local existing = dest:FindFirstChild(child.Name)
			if existing then
				existing:Destroy()
			end
			local clone = child:Clone()
			clone.Name = child.Name
			clone.Parent = dest
		end
	end
end

local function normalizeName(name: string): string
	return name:lower():gsub("%s+", "")
end

local function validatePetModels(petsFolder: Folder)
	local index: { [string]: boolean } = {}
	for _, child in ipairs(petsFolder:GetChildren()) do
		if child:IsA("Model") then
			index[normalizeName(child.Name)] = true
		end
	end
	local missing: { string } = {}
	for _, def in ipairs(PetDatabase.getAll()) do
		if not index[normalizeName(def.modelName)] then
			table.insert(missing, def.modelName)
		end
	end
	if #missing > 0 then
		log:warn("PetKit: нет 3D-моделей для петов:", table.concat(missing, ", "))
	end
end

function PetAssetBootstrap.run()
	if ReplicatedStorage:FindFirstChild(KIT_NAME) then
		return
	end

	local wsPets = Workspace:FindFirstChild("Pets")
	local wsEggs = Workspace:FindFirstChild("Eggs")
	if not wsPets and not wsEggs then
		log:warn("Workspace.Pets / Workspace.Eggs не найдены — 3D питомцы недоступны")
		return
	end

	local kit = Instance.new("Folder")
	kit.Name = KIT_NAME
	kit.Parent = ReplicatedStorage

	if wsPets and wsPets:IsA("Folder") then
		local folder = Instance.new("Folder")
		folder.Name = "Pets"
		folder.Parent = kit
		cloneModels(wsPets, folder)
		log:info("PetKit: скопировано питомцев:", #folder:GetChildren())
		validatePetModels(folder)
		-- Каталог в Workspace не показываем игрокам — только ReplicatedStorage.
		wsPets.Parent = ServerStorage
		wsPets.Name = "Pets_Catalog"
	end

	if wsEggs and wsEggs:IsA("Folder") then
		local folder = Instance.new("Folder")
		folder.Name = "Eggs"
		folder.Parent = kit
		cloneModels(wsEggs, folder)
		log:info("PetKit: скопировано яиц:", #folder:GetChildren())
	end
end

return PetAssetBootstrap
