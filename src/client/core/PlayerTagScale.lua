--!strict
-- Клиентский tier-scale для PlayerTag (BillboardGui на Head).
-- Сервер создаёт тег в desktop-каноне (×3); здесь ужимаем на phone/tablet.

local Players = game:GetService("Players")
local ViewportLayout = require(script.Parent.Parent.ui.util.ViewportLayout)

local PlayerTagScale = {}

local TAG_NAME = "PlayerTag"

type BaseLayout = {
	billW: number,
	billHName: number,
	billHFull: number,
	nameRowH: number,
	nameTextSize: number,
	titleTextSize: number,
	titleRowH: number,
	badgePadV: number,
	badgePadH: number,
	badgeGap: number,
	badgeH: number,
	studsName: number,
	studsFull: number,
}

local function readBase(bill: BillboardGui): BaseLayout?
	local w = bill:GetAttribute("BaseBillW")
	if typeof(w) ~= "number" then
		return nil
	end
	return {
		billW = w,
		billHName = bill:GetAttribute("BaseBillHName") :: number,
		billHFull = bill:GetAttribute("BaseBillHFull") :: number,
		nameRowH = bill:GetAttribute("BaseNameRowH") :: number,
		nameTextSize = bill:GetAttribute("BaseNameTextSize") :: number,
		titleTextSize = bill:GetAttribute("BaseTitleTextSize") :: number,
		titleRowH = bill:GetAttribute("BaseTitleRowH") :: number,
		badgePadV = bill:GetAttribute("BaseBadgePadV") :: number,
		badgePadH = bill:GetAttribute("BaseBadgePadH") :: number,
		badgeGap = bill:GetAttribute("BaseBadgeGap") :: number,
		badgeH = bill:GetAttribute("BaseBadgeH") :: number,
		studsName = bill:GetAttribute("BaseStudsName") :: number,
		studsFull = bill:GetAttribute("BaseStudsFull") :: number,
	}
end

local function scaleDim(n: number, mult: number): number
	return math.max(1, math.floor(n * mult + 0.5))
end

local function applyToBillboard(bill: BillboardGui, mult: number)
	local base = readBase(bill)
	if not base then
		return
	end

	local showBadge = bill:GetAttribute("HasBadge") == true
	bill.Size = UDim2.fromOffset(
		scaleDim(base.billW, mult),
		scaleDim(if showBadge then base.billHFull else base.billHName, mult)
	)
	bill.StudsOffset = Vector3.new(
		0,
		(if showBadge then base.studsFull else base.studsName) * mult,
		0
	)

	local nameLbl = bill:FindFirstChildWhichIsA("TextLabel")
	if nameLbl then
		nameLbl.Size = UDim2.new(1, 0, 0, scaleDim(base.nameRowH, mult))
		nameLbl.TextSize = scaleDim(base.nameTextSize, mult)
	end

	local badgeBg = bill:FindFirstChild("BadgeBg")
	if badgeBg and badgeBg:IsA("Frame") then
		badgeBg.Size = UDim2.fromOffset(0, scaleDim(base.badgeH, mult))
		badgeBg.Position = UDim2.new(0.5, 0, 0, scaleDim(base.nameRowH + base.badgeGap, mult))

		local pad = badgeBg:FindFirstChildOfClass("UIPadding")
		if pad then
			pad.PaddingLeft = UDim.new(0, scaleDim(base.badgePadH, mult))
			pad.PaddingRight = UDim.new(0, scaleDim(base.badgePadH, mult))
			pad.PaddingTop = UDim.new(0, scaleDim(base.badgePadV, mult))
			pad.PaddingBottom = UDim.new(0, scaleDim(base.badgePadV, mult))
		end

		local corner = badgeBg:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, scaleDim(8, mult))
		end

		local stroke = badgeBg:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = math.max(0.5, base.badgePadV * 0.2 * mult)
		end

		local titleLbl = badgeBg:FindFirstChildWhichIsA("TextLabel")
		if titleLbl then
			titleLbl.Size = UDim2.fromOffset(0, scaleDim(base.titleRowH, mult))
			titleLbl.TextSize = scaleDim(base.titleTextSize, mult)
		end
	end

	bill:SetAttribute("AppliedTagMult", mult)
end

local function applyAll(mult: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if not char then
			continue
		end
		local head = char:FindFirstChild("Head")
		if not head then
			continue
		end
		local bill = head:FindFirstChild(TAG_NAME)
		if bill and bill:IsA("BillboardGui") then
			applyToBillboard(bill, mult)
		end
	end
end

local function onTagAdded(bill: Instance)
	if not bill:IsA("BillboardGui") or bill.Name ~= TAG_NAME then
		return
	end
	task.defer(function()
		if bill.Parent then
			applyToBillboard(bill, ViewportLayout.tagTitleMult())
		end
	end)
end

local function watchCharacter(char: Model)
	local head = char:WaitForChild("Head", 8)
	if not head then
		return
	end
	head.ChildAdded:Connect(onTagAdded)
	local existing = head:FindFirstChild(TAG_NAME)
	if existing then
		onTagAdded(existing)
	end
end

function PlayerTagScale.start()
	ViewportLayout.subscribe(function()
		applyAll(ViewportLayout.tagTitleMult())
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(watchCharacter, player.Character)
		end
		player.CharacterAdded:Connect(watchCharacter)
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(watchCharacter)
	end)

	applyAll(ViewportLayout.tagTitleMult())
end

return PlayerTagScale
