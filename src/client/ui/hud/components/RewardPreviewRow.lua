--!strict
-- Горизонтальный ряд чипов награды из таблицы reward (дизайн-пиксели под UIScale модала).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local PanelScale = require(script.Parent.Parent.PanelScale)
local RewardPreviewChip = require(script.Parent.RewardPreviewChip)

local Children = Fusion.Children
local C = theme.C

export type RewardTable = {
	coins: number?,
	gems: number?,
	boost: { kind: string?, multiplier: number?, durationSec: number? }?,
}

export type Props = {
	rewards: RewardTable,
	layoutOrder: number?,
	fitScale: any?,
}

local RewardPreviewRow = {}

local function chipsFromRewards(rewards: RewardTable): { RewardPreviewChip.Props }
	local chips: { RewardPreviewChip.Props } = {}
	if rewards.coins and rewards.coins > 0 then
		table.insert(chips, {
			label = ("+%s"):format(tostring(rewards.coins)),
			iconKey = "coin",
			accent = C.gold,
		})
	end
	if rewards.gems and rewards.gems > 0 then
		table.insert(chips, {
			label = ("+%s"):format(tostring(rewards.gems)),
			iconKey = "icon_gem",
			accent = C.gem,
		})
	end
	local boost = rewards.boost
	if boost and (boost.multiplier or 0) > 0 then
		local mult = math.floor(boost.multiplier or 2)
		table.insert(chips, {
			label = ("x%d буст"):format(mult),
			iconKey = "buff_coin",
			accent = theme.TAB_ACCENTS.shop,
		})
	end
	return chips
end

function RewardPreviewRow.create(s: ScopeFactory.HudScope, props: Props)
	local chipProps = chipsFromRewards(props.rewards)
	local fitScale = props.fitScale
	local children: { Instance } = {
		s:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	}
	for i, chip in ipairs(chipProps) do
		chip.layoutOrder = i
		chip.fitScale = fitScale
		children[#children + 1] = RewardPreviewChip.create(s, chip)
	end

	return s:New("Frame")({
		Name = "RewardPreviewRow",
		LayoutOrder = props.layoutOrder,
		Size = if fitScale
			then UDim2.new(1, 0, 0, s:Computed(function(use)
				return PanelScale.modalGsc(38, use(fitScale))
			end))
			else UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		[Children] = children,
	})
end

return RewardPreviewRow
