--!strict
-- 3D-превью яйца в EggShopModal (один ViewportFrame, монтируется после открытия модалки).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)
local PetModelKit = require(ReplicatedStorage:WaitForChild("shared").util.PetModelKit)
local UiMotion = require(script.Parent.Parent.Parent.util.UiMotion)

local Children = Fusion.Children
local C = theme.C

local PREVIEW_SIZE = 168

export type Props = {
	modelName: string,
	accent: Color3,
	icon: string?,
	size: number?,
	position: UDim2?,
}

local EggShopEggPreview = {}

function EggShopEggPreview.create(s: ScopeFactory.HudScope, props: Props)
	local previewHost = s:New("Frame")({
		Name = "PreviewHost",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	})

	local previewSize = props.size or PREVIEW_SIZE
	local frame = s:New("Frame")({
		Name = "EggViewport",
		Size = UDim2.fromOffset(previewSize, previewSize),
		Position = props.position or UDim2.new(0, 16, 0, 52),
		BackgroundColor3 = C.bg3,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 4,
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
			s:New("UIStroke")({ Color = props.accent, Thickness = 2, Transparency = 0.2 }),
			previewHost,
		},
	})

	UiMotion.defer(s, frame, function(host)
		local inner = host:FindFirstChild("PreviewHost")
		if not inner or not inner:IsA("GuiObject") then
			return nil
		end
		local display = PetModelKit.cloneEggDisplay(props.modelName, PetModelKit.displayHeights().reveal)
		if display then
			local mounted = PetModelKit.mountInViewport(inner, display, 3.4, { zIndex = 5 })
			return mounted.destroy
		end
		local icon = Instance.new("ImageLabel")
		icon.Name = "EggFallback"
		icon.Size = UDim2.fromScale(0.72, 0.72)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = UiAssets.resolve(props.icon or "icon_egg")
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 5
		icon.Parent = inner
		return function()
			icon:Destroy()
		end
	end)

	return frame
end

return EggShopEggPreview
