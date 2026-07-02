--!strict
-- Клиентская активация промокода.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local peek = Fusion.peek
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)

local Notification = require(script.Parent.Parent.Parent.Notification)
local theme = require(script.Parent.Parent.theme)

local C = theme.C

local PromoCodeActions = {}

function PromoCodeActions.tryRedeem(code: string, isBusy: any): boolean
	if peek(isBusy) then
		return false
	end
	local trimmed = code:gsub("^%s+", ""):gsub("%s+$", "")
	if trimmed == "" then
		Notification.show({ text = "Введите код", color = C.closeBg, duration = 2.5 })
		return false
	end
	isBusy:set(true)
	task.spawn(function()
		local ok, result = pcall(function()
			return Net:Invoke("RedeemCode", trimmed)
		end)
		isBusy:set(false)
		if not ok then
			Notification.show({ text = "Ошибка сети", color = C.closeBg, duration = 3 })
			return
		end
		if typeof(result) == "table" and result.success then
			return
		end
		local msg = if typeof(result) == "table" and typeof(result.message) == "string"
			then result.message
			else "Код недействителен"
		Notification.show({ text = msg, color = C.closeBg, duration = 3.5 })
	end)
	return true
end

return PromoCodeActions
