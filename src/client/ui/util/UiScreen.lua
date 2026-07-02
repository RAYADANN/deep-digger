--!strict

-- Единые настройки ScreenGui: safe area как в топовых Roblox-играх.

-- Важно: ScreenInsets выставлять ДО IgnoreGuiInset=false — иначе Roblox

-- принудительно включает IgnoreGuiInset при DeviceSafeInsets.

local SafeArea = require(script.Parent.SafeArea)

export type Profile = "hud" | "modal" | "toast" | "tutorial" | "tooltip" | "fx"



local DISPLAY_ORDERS: { [Profile]: number } = {

	hud = 20,

	tutorial = 80,

	modal = 92,

	toast = 100,

	tooltip = 110,

	fx = 200,

}



local UiScreen = {}



function UiScreen.apply(gui: ScreenGui, profile: Profile)

	gui.ResetOnSpawn = false

	gui.DisplayOrder = DISPLAY_ORDERS[profile]



	if profile == "fx" then

		gui.ScreenInsets = Enum.ScreenInsets.None

		gui.IgnoreGuiInset = true

	else

		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

		gui.IgnoreGuiInset = false

	end

end



function UiScreen.ensure(parent: Instance, name: string, profile: Profile): ScreenGui

	local existing = parent:FindFirstChild(name)

	if existing and existing:IsA("ScreenGui") then

		UiScreen.apply(existing, profile)

		return existing

	end



	local gui = Instance.new("ScreenGui")

	gui.Name = name

	gui.Parent = parent

	UiScreen.apply(gui, profile)

	return gui

end

-- ScreenGui с CoreUISafeInsets: Y=0 — низ topbar. Растягиваем backdrop вверх,
-- чтобы затемнение покрывало весь экран без светлой полосы сверху.
function UiScreen.backdropSize(): UDim2
	SafeArea.start()
	local top = SafeArea.topInset()
	return UDim2.new(1, 0, 1, top)
end

function UiScreen.backdropPosition(): UDim2
	SafeArea.start()
	local top = SafeArea.topInset()
	return UDim2.new(0, 0, 0, -top)
end

return UiScreen

