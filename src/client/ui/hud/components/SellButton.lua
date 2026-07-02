--!strict
-- Логика продажи (PS99: кнопка в sidebar, не отдельный FAB).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)

local Formatters = require(script.Parent.Parent.formatters)
local SoundManager = require(script.Parent.Parent.Parent.Parent.core.SoundManager)
local Notification = require(script.Parent.Parent.Parent.Notification)

local EMPTY_COLOR = Color3.fromRGB(180, 180, 195)
local ERROR_COLOR = Color3.fromRGB(255, 140, 60)
local FEEDBACK_SECONDS = 2

local busy = false

local SellButton = {}

function SellButton.activate()
	if busy then
		return
	end
	busy = true

	local result = Net:Invoke("SellOres")
	if typeof(result) ~= "table" then
		Notification.show({
			text = "Сетевая ошибка продажи",
			icon = "icon_warning",
			color = ERROR_COLOR,
			duration = 2.5,
		})
		busy = false
		return
	end

	if result.success then
		local earned = result.coinsEarned or 0
		SoundManager.play("sell_success")
		Notification.show({
			text = "+" .. Formatters.shortNumber(earned) .. " монет",
			icon = "coin",
			color = Color3.fromRGB(255, 220, 60),
			duration = 2,
		})
	else
		SoundManager.play("sell_fail")
		local msg = result.message or "Инвентарь пуст. Накопайте руды!"
		Notification.show({
			text = msg,
			icon = "icon_empty",
			color = EMPTY_COLOR,
			duration = 2.5,
		})
	end

	task.delay(FEEDBACK_SECONDS, function()
		busy = false
	end)
end

return SellButton
