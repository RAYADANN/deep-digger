--!strict
-- Покупка товара / gamepass из ShopPanel.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Notification = require(script.Parent.Parent.Parent.Notification)

local ShopPurchase = {}

function ShopPurchase.prompt(item: {
	id: number,
	name: string,
	kind: "gamepass" | "product",
})
	if item.id == 0 then
		Notification.show({
			text = "ID не настроен в Creator Hub. В Studio: /grantpass или /grantproduct",
			icon = "tab_upgrades",
			color = Color3.fromRGB(120, 200, 255),
			duration = 3,
		})
		return
	end
	pcall(function()
		local player = Players.LocalPlayer
		if item.kind == "gamepass" then
			MarketplaceService:PromptGamePassPurchase(player, item.id)
		else
			MarketplaceService:PromptProductPurchase(player, item.id)
		end
	end)
end

return ShopPurchase
