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

-- Создаём рендер и HUD
local renderer = MiningRenderer.new()
local hud = HUD.new()

-- Слушаем статы с сервера
Net:Connect("PlayerStats", function(data)
    hud:update(data)
end)

-- Запускаем, когда персонаж появляется
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function onCharacterAdded(character: Model)
    log:info("Character spawned, starting mining renderer")
    renderer:start()
    hud:create()
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Остановка при выходе игрока
player.AncestryChanged:Connect(function()
    if player.Parent == nil then
        renderer:stop()
        hud:destroy()
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
