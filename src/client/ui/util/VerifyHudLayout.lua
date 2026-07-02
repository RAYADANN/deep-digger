--!strict

-- Studio smoke: HUD в safe area, не под системным UI Roblox.



local GuiService = game:GetService("GuiService")

local RunService = game:GetService("RunService")



local SafeArea = require(script.Parent.SafeArea)

local ViewportLayout = require(script.Parent.ViewportLayout)



local VerifyHudLayout = {}



local TOP_NODES = { "CurrencyRibbon", "InventoryWidget", "TopRightActionRow", "PromoCodeButton", "SocialRewardButton", "QuestTrackerHost" }



function VerifyHudLayout.check(gui: ScreenGui)

	if not RunService:IsStudio() then

		return

	end



	task.defer(function()

		if not gui.Parent then

			return

		end



		local vp = ViewportLayout.getSize()

		local playH = ViewportLayout.playableHeight()

		local availW = ViewportLayout.availableWidth()

		local topInset = SafeArea.topInset()

		local issues: { string } = {}



		if gui.IgnoreGuiInset then

			issues[#issues + 1] = "HUD IgnoreGuiInset=true (UI may sit under topbar)"

		end

		if gui.ScreenInsets ~= Enum.ScreenInsets.CoreUISafeInsets then

			issues[#issues + 1] = "HUD ScreenInsets not CoreUISafeInsets"

		end



		local guiPos = gui.AbsolutePosition

		local guiOriginY = gui.AbsolutePosition.Y

		if guiPos.Y < guiOriginY - 2 then

			issues[#issues + 1] = (`HUD ScreenGui above safe area (y={math.floor(guiPos.Y)})`)

		end



		local function checkNode(name: string, maxW: number?, maxH: number?)

			local node = gui:FindFirstChild(name, true)

			if not node or not node:IsA("GuiObject") then

				return

			end

			local abs = node.AbsoluteSize

			local pos = node.AbsolutePosition

			if pos.Y < guiOriginY - 2 then

				issues[#issues + 1] = (`{name} above HUD origin (y={math.floor(pos.Y)})`)

			end

			if abs.X > vp.X + 2 then

				issues[#issues + 1] = (`{name} wider than screen ({math.floor(abs.X)} > {math.floor(vp.X)})`)

			end

			if abs.Y > playH + topInset + 2 then

				issues[#issues + 1] = (`{name} taller than playable ({math.floor(abs.Y)} > {math.floor(playH + topInset)})`)

			end

			if maxW and abs.X > maxW + 2 then

				issues[#issues + 1] = (`{name} exceeds maxW ({math.floor(abs.X)} > {maxW})`)

			end

			if maxH and abs.Y > maxH + 2 then

				issues[#issues + 1] = (`{name} exceeds maxH ({math.floor(abs.Y)} > {maxH})`)

			end

		end



		local modalW, modalH = ViewportLayout.modalPixels(600, 450)

		checkNode("Modal", modalW, modalH)

		checkNode("LeftSidebar", availW)

		for _, nodeName in TOP_NODES do

			checkNode(nodeName)

		end

		local inv = gui:FindFirstChild("InventoryWidget", true)
		if inv and inv:IsA("GuiObject") then
			local abs = inv.AbsoluteSize
			if abs.X < 48 or abs.Y < 20 then
				issues[#issues + 1] = (`InventoryWidget too small ({math.floor(abs.X)}x{math.floor(abs.Y)})`)
			end
			local count = inv:FindFirstChild("Count", true)
			if count and count:IsA("TextLabel") and count.Text == "" then
				issues[#issues + 1] = "InventoryWidget Count label empty"
			end
		end



		if #issues > 0 then

			warn(

				"[HudLayout] tier=",

				ViewportLayout.tier(),

				"vp=",

				vp,

				"inset=",

				GuiService:GetGuiInset(),

				"issues:",

				table.concat(issues, "; ")

			)

		else

			print(

				"[HudLayout] OK tier=",

				ViewportLayout.tier(),

				"vp=",

				vp.X,

				"x",

				vp.Y,

				"inset=",

				topInset

			)

		end

	end)

end



return VerifyHudLayout

