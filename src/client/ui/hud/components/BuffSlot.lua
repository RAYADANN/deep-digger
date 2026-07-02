--!strict
-- Один слот бафа: иконка + значение + опциональный таймер.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory   = require(script.Parent.Parent.ScopeFactory)
local theme          = require(script.Parent.Parent.theme)
local BuffMeta       = require(ReplicatedStorage:WaitForChild("shared").data.BuffMeta)
local BuffIcon       = require(script.Parent.BuffIcon)
local BuffLogic      = require(script.Parent.Parent.util.BuffLogic)
local ViewportLayout = require(script.Parent.Parent.Parent.util.ViewportLayout)

local Children = Fusion.Children
local C        = theme.C

-- Дизайн-эталон слота (масштабируется пропорционально buffSlotPx).
local SLOT_W = 54
local SLOT_H = 62

local BuffSlot = {}

local function fmtTime(secs: number): string
	secs = math.max(0, math.floor(secs))
	local m = math.floor(secs / 60)
	local s = secs % 60
	return ("%d:%02d"):format(m, s)
end

function BuffSlot.create(
	s: ScopeFactory.HudScope,
	entry: BuffLogic.BuffEntry,
	remaining: any?,
	slotW: any?
)
	local accent = BuffMeta.ACCENT[entry.kind]

	-- Если parent не передал реактивный slotW — заводим собственный.
	local widthVal = slotW
	if not widthVal then
		widthVal = s:Value(ViewportLayout.buffSlotPx())
		ViewportLayout.subscribe(function()
			widthVal:set(ViewportLayout.buffSlotPx())
		end, s)
	end

	-- Размер текста тянется от ширины слота (всё остальное — scale-based,
	-- поэтому масштабируется автоматически вместе с фреймом слота).
	local function textPx(use: any, designN: number, minN: number): number
		return math.max(minN, math.floor(designN * (use(widthVal) / SLOT_W) + 0.5))
	end

	local showTimer = s:Computed(function(use)
		if not remaining then return false end
		return (use(remaining) or 0) > 0
	end)

	return s:New("Frame")({
		Name             = "Buff_" .. entry.id,
		Size             = s:Computed(function(use)
			local w = use(widthVal)
			return UDim2.fromOffset(w, math.floor(w * (SLOT_H / SLOT_W) + 0.5))
		end),
		BackgroundColor3 = C.bgChip,
		BackgroundTransparency = 0,
		BorderSizePixel  = 0,
		LayoutOrder      = 1,
		[Children] = {
			s:New("UICorner")({ CornerRadius = theme.RADIUS.chip }),
			s:New("UIStroke")({
				Color     = accent,
				Thickness = theme.STROKE.medium,
				Transparency = 0.35,
			}),
			-- Левый акцент-бар
			s:New("Frame")({
				Size             = UDim2.fromScale(3 / SLOT_W, (SLOT_H - 14) / SLOT_H),
				Position         = UDim2.fromScale(0, 0.5),
				AnchorPoint      = Vector2.new(0, 0.5),
				BackgroundColor3 = accent,
				BorderSizePixel  = 0,
				ZIndex           = 2,
				[Children] = { s:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
			}),
			-- Иконка
			BuffIcon.create(s, {
				kind        = entry.kind,
				size        = UDim2.fromScale(30 / SLOT_W, 30 / SLOT_H),
				position    = UDim2.fromScale(0.5, 6 / SLOT_H),
				anchorPoint = Vector2.new(0.5, 0),
				zIndex      = 3,
			}),
			-- Значение (+40% / x2)
			s:New("TextLabel")({
				Size                   = UDim2.fromScale(1 - 4 / SLOT_W, 14 / SLOT_H),
				Position               = UDim2.fromScale(2 / SLOT_W, 36 / SLOT_H),
				BackgroundTransparency = 1,
				Text                   = entry.valueText,
				TextSize               = s:Computed(function(use)
					return textPx(use, 11, 8)
				end),
				Font                   = theme.FONT.title,
				TextColor3             = C.textMain,
				TextXAlignment         = Enum.TextXAlignment.Center,
				TextTruncate           = Enum.TextTruncate.AtEnd,
				ZIndex                 = 3,
			}),
			-- Таймер (только для предметных бустов)
			s:New("TextLabel")({
				Size                   = UDim2.fromScale(1 - 4 / SLOT_W, 10 / SLOT_H),
				Position               = UDim2.new(2 / SLOT_W, 0, 1, 0),
				AnchorPoint            = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				Text                   = if remaining
					then s:Computed(function(use)
						return fmtTime(use(remaining) or 0)
					end)
					else "",
				TextSize               = s:Computed(function(use)
					return textPx(use, 9, 7)
				end),
				Font                   = theme.FONT.label,
				TextColor3             = accent,
				TextXAlignment         = Enum.TextXAlignment.Center,
				Visible                = showTimer,
				ZIndex                 = 3,
			}),
		},
	})
end

return BuffSlot
