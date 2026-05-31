--!strict
-- init.client.lua — точка входа клиента.
-- Инициализирует рендер шахты, UI, подключает сеть.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local MiningRenderer = require(script.core.MiningRenderer)
local HUD = require(script.ui.HUD)
local Net = require(modules.Net)

local log = Logger.new("Client:Init")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Создаём рендер и HUD
local renderer = MiningRenderer.new()
local hud: HUD? = nil

-- Слушаем статы с сервера
Net:Connect("PlayerStats", function(data)
    if not hud then return end
    hud:setCoins(data.coins or 0)
    hud:setGems(data.gems or 0)
    hud:setDepth(data.depth or 0, data.layer or "Dirt Layer")
end)

Net:Connect("PlayerInventory", function(data)
    if not hud then return end
    hud:setInventory(data.inventory or {})
    hud:setUpgrades(data.upgrades or {})
end)

-- Запускаем, когда персонаж появляется
local function onCharacterAdded(character: Model)
    log:info("Character spawned, starting mining renderer")
    renderer:start()
    hud = HUD.new(player)
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Остановка при выходе игрока
player.AncestryChanged:Connect(function()
    if player.Parent == nil then
        renderer:stop()
        if hud then hud:destroy(); hud = nil end
    end
end)

-- Команды через чат (для отладки UI)
player.Chatted:Connect(function(msg)
    local cmd = msg:lower()
    if cmd == "/rarity" then
        local on = renderer:toggleRarity()
        log:info("Rarity tags:", if on then "ON" else "OFF")
    elseif cmd == "/hpbar" then
        local on = renderer:toggleHPBar()
        log:info("HP bars:", if on then "ON" else "OFF")
    elseif cmd == "/help" then
        print("--- Deep Digger Commands ---")
        print("/rarity - toggle rarity strips")
        print("/hpbar - toggle HP bars on hover")
        print("/help - this message")
    end
end)

log:info("Client initialized")
