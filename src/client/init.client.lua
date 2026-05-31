--!strict
-- init.client.lua — точка входа клиента.
-- Инициализирует рендер шахты, UI, подключает сеть.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local modules = ReplicatedStorage:WaitForChild("Packages")

local Logger = require(shared.util.Logger)
local MiningRenderer = require(script.core.MiningRenderer)
local DepthTracker = require(script.core.DepthTracker)
local HUD = require(script.ui.HUD)
local Notification = require(script.ui.Notification)
local Net = require(modules.Net)

local log = Logger.new("Client:Init")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Создаём рендер и HUD
local renderer = MiningRenderer.new()
local hud: HUD? = nil
local depthTracker = DepthTracker.new(player)
depthTracker:onChanged(function(info)
    if hud then
        hud:setDepth(info.depth, info.layerId, info.layerName)
    end
end)

-- Слушаем полные данные с сервера
-- Пока два события, объединяем:
local playerDataBuffer = {}

local function applyPlayerPayload(data)
    for k, v in pairs(data) do
        playerDataBuffer[k] = v
    end
    renderer:setSwingDelay(data.speedLevel or 1)
    if hud then
        hud:setPlayerData(playerDataBuffer)
    end
end

Net:Connect("PlayerStats", function(data)
    applyPlayerPayload(data)
end)
Net:Connect("PlayerInventory", function(data)
    applyPlayerPayload(data)
end)

Net:Connect("Notify", function(payload)
    if typeof(payload) ~= "table" or typeof(payload.text) ~= "string" then
        return
    end
    local color
    if typeof(payload.color) == "table" then
        color = Color3.fromRGB(payload.color.r or 255, payload.color.g or 255, payload.color.b or 255)
    end
    Notification.show({
        text = payload.text,
        color = color,
        icon = payload.icon,
        duration = payload.duration,
    })
end)

-- Запускаем, когда персонаж появляется
local function onCharacterAdded(character: Model)
    log:info("Character spawned, starting mining renderer")
    if hud then
        hud:destroy()
        hud = nil
    end
    renderer:start()
    hud = HUD.new(player)
    depthTracker:start()
end

if player.Character then
    onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Остановка при выходе игрока
player.AncestryChanged:Connect(function()
    if player.Parent == nil then
        renderer:stop()
        depthTracker:stop()
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
