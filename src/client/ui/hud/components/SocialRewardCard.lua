--!strict
-- SocialRewardCard — бесплатная награда за группу + избранное (таб «Магазин»).

local GroupService = game:GetService("GroupService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local peek = Fusion.peek
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local PanelScale = require(script.Parent.Parent.PanelScale)
local Notification = require(script.Parent.Parent.Parent.Notification)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local SocialRewardLogic = require(ReplicatedStorage:WaitForChild("shared").util.SocialRewardLogic)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local C = theme.C
local ACCENT = theme.TAB_ACCENTS.shop
local sc = PanelScale.gsc
local text = PanelScale.text

local SocialRewardCard = {}

local function statusMark(done: boolean): string
	return if done then "✓" else "✗"
end

local function rewardSummary(): string
	local rewards = (Constants.SOCIAL_REWARD or {}).rewards or {}
	local parts: { string } = {}
	if rewards.coins and rewards.coins > 0 then
		table.insert(parts, ("+%d монет"):format(rewards.coins))
	end
	if rewards.gems and rewards.gems > 0 then
		table.insert(parts, ("+%d крист."):format(rewards.gems))
	end
	if rewards.boost then
		table.insert(parts, ("буст x%d"):format(math.floor(rewards.boost.multiplier or 2)))
	end
	return table.concat(parts, "  ·  ")
end

local function promptGroup(isBusy: any)
	if peek(isBusy) then
		return
	end
	local groupId = SocialRewardLogic.groupId()
	if groupId <= 0 then
		Notification.show({ text = "Группа ещё не настроена", color = C.closeBg, duration = 3 })
		return
	end
	isBusy:set(true)
	task.spawn(function()
		pcall(function()
			GroupService:PromptGroupMembership(groupId)
		end)
		task.wait(2)
		pcall(function()
			Net:Invoke("RefreshSocialStatus")
		end)
		isBusy:set(false)
	end)
end

local function promptFavorite(isBusy: any)
	if peek(isBusy) then
		return
	end
	local universeId = SocialRewardLogic.universeId()
	if universeId <= 0 then
		Notification.show({ text = "Игра ещё не настроена", color = C.closeBg, duration = 3 })
		return
	end
	isBusy:set(true)
	task.spawn(function()
		local prompted = pcall(function()
			AvatarEditorService:PromptSetFavorite(universeId, true)
		end)
		if prompted then
			pcall(function()
				Net:Invoke("ConfirmSocialFavorite")
			end)
		end
		isBusy:set(false)
	end)
end

local function tryClaim(isBusy: any)
	if peek(isBusy) then
		return
	end
	isBusy:set(true)
	task.spawn(function()
		local ok, result = pcall(function()
			return Net:Invoke("ClaimSocialReward")
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
			else "Условия не выполнены"
		Notification.show({ text = msg, color = C.closeBg, duration = 3.5 })
	end)
end

function SocialRewardCard.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState, layoutOrder: number)
	local isBusy = s:Value(false)

	return s:New("Frame")({
		Name = "SocialRewardCard",
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, -sc(8), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.btnBg,
		BorderSizePixel = 0,
		Visible = s:Computed(function(use)
			local social = use(state.socialReward) or {}
			return social.claimed ~= true
		end),
		[Children] = {
			s:New("UICorner")({ CornerRadius = UDim.new(0, sc(10)) }),
			s:New("UIStroke")({ Color = ACCENT, Thickness = sc(1.5), Transparency = 0.35 }),
			s:New("UIPadding")({
				PaddingTop = PanelScale.pad(10),
				PaddingBottom = PanelScale.pad(10),
				PaddingLeft = PanelScale.pad(12),
				PaddingRight = PanelScale.pad(12),
			}),
			s:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				Padding = PanelScale.pad(8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			s:New("TextLabel")({
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, sc(20)),
				BackgroundTransparency = 1,
				Text = "🎁 Бесплатная награда",
				TextSize = text(14),
				Font = Enum.Font.GothamBlack,
				TextColor3 = C.gold,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Text = rewardSummary(),
				TextSize = text(12),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textLabel,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, sc(18)),
				BackgroundTransparency = 1,
				Text = s:Computed(function(use)
					local social = use(state.socialReward) or {}
					return ("Группа %s   ·   Избранное %s"):format(
						statusMark(social.inGroup == true),
						statusMark(social.favoriteConfirmed == true)
					)
				end),
				TextSize = text(12),
				Font = Enum.Font.GothamBold,
				TextColor3 = C.textMain,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),
			s:New("Frame")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, sc(36)),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, sc(8)),
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
					}),
					s:New("TextButton")({
						LayoutOrder = 0,
						Size = UDim2.new(0.5, -sc(4), 1, 0),
						BackgroundColor3 = C.panelInner,
						BorderSizePixel = 0,
						Text = "ВСТУПИТЬ В ГРУППУ",
						TextSize = text(11),
						Font = Enum.Font.GothamBold,
						TextColor3 = C.textMain,
						AutoButtonColor = false,
						ZIndex = 2,
						[Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
						},
						[OnEvent("Activated")] = function()
							promptGroup(isBusy)
						end,
					}),
					s:New("TextButton")({
						LayoutOrder = 1,
						Size = UDim2.new(0.5, -sc(4), 1, 0),
						BackgroundColor3 = C.panelInner,
						BorderSizePixel = 0,
						Text = "ДОБАВИТЬ В ИЗБРАННОЕ",
						TextSize = text(11),
						Font = Enum.Font.GothamBold,
						TextColor3 = C.textMain,
						AutoButtonColor = false,
						ZIndex = 2,
						[Children] = {
							s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
						},
						[OnEvent("Activated")] = function()
							promptFavorite(isBusy)
						end,
					}),
				},
			}),
			s:New("TextButton")({
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, sc(38)),
				BackgroundColor3 = s:Computed(function(use)
					local social = use(state.socialReward) or {}
					return if social.canClaim then C.gold else C.btnDisabled
				end),
				BackgroundTransparency = s:Computed(function(use)
					local social = use(state.socialReward) or {}
					return if social.canClaim then 0 else 0.3
				end),
				BorderSizePixel = 0,
				Text = "ЗАБРАТЬ НАГРАДУ",
				TextSize = text(13),
				Font = Enum.Font.GothamBlack,
				TextColor3 = Color3.fromRGB(40, 25, 0),
				AutoButtonColor = false,
				ZIndex = 2,
				[Children] = {
					s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
				},
				[OnEvent("Activated")] = function()
					tryClaim(isBusy)
				end,
			}),
		},
	})
end

return SocialRewardCard
