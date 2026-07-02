--!strict
-- PlayerTag — тег над головой игрока + ауры.
-- Сервер-сайд → BillboardGui, Highlight и ParticleEmitter реплицируются всем клиентам.
--
-- Тиры по ребёртам:
--   0          Новичок   — серый,  нет ауры
--   1–4        Шахтёр    — зелёный, тонкий контур
--   5–9        Ветеран   — синий,  контур + свет
--   10–24      Легенда   — фиолет, контур + свет + частицы
--   25–49      Мастер    — оранж,  контур + свет + больше частиц
--   50+        Бог Шахты — красный, максимальный эффект
--   VIP (любой тир) — золотой оверрайд цвета + корона в тайтле

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("shared")
local MonetizationLogic = require(shared.util.MonetizationLogic)

-- ── Тиры ──────────────────────────────────────────────────────────────────────
type TierDef = {
	min:          number,
	title:        string,
	color:        Color3,
	particleRate: number,
}

local TIERS: { TierDef } = {
	{ min = 50, title = "Бог Шахты", color = Color3.fromRGB(255, 60,  60),  particleRate = 45 },
	{ min = 25, title = "Мастер",    color = Color3.fromRGB(255, 168, 0),   particleRate = 28 },
	{ min = 10, title = "Легенда",   color = Color3.fromRGB(188, 68,  236), particleRate = 16 },
	{ min = 5,  title = "Ветеран",   color = Color3.fromRGB(64,  156, 255), particleRate = 0  },
	{ min = 1,  title = "Шахтёр",   color = Color3.fromRGB(72,  218, 116), particleRate = 0  },
	{ min = 0,  title = "Новичок",   color = Color3.fromRGB(150, 160, 180), particleRate = 0  },
}

local VIP_COLOR = Color3.fromRGB(255, 212, 38)
local WHITE     = Color3.fromRGB(255, 255, 255)
local DARK_BG   = Color3.fromRGB(10, 12, 22)
local BLACK     = Color3.fromRGB(0, 0, 0)

-- Титул под ником: ×3 к прежнему TextSize 11 → 33. BillboardGui в world-space —
-- одинаково читается на всех клиентах (не зависит от phone/desktop HUD tier).
local NAME_TEXT_SIZE   = 14
local NAME_ROW_H       = 22
local TITLE_TEXT_SIZE  = 33
local TITLE_ROW_H      = 40
local BADGE_PAD_V      = 6
local BADGE_PAD_H      = 12
local BADGE_GAP        = 8
local BADGE_H          = TITLE_ROW_H + BADGE_PAD_V * 2
local BILLBOARD_W      = 300
local BILLBOARD_H_NAME = NAME_ROW_H
local BILLBOARD_H_FULL = NAME_ROW_H + BADGE_GAP + BADGE_H + 4

local function getTier(rebirths: number): TierDef
	for _, t in TIERS do
		if rebirths >= t.min then
			return t
		end
	end
	return TIERS[#TIERS]
end

local function resolveTitleDisplay(
	data: any,
	tier: TierDef,
	isVip: boolean,
	achievementManager: any?
): (string?, Color3, boolean)
	local eqId = data.equippedTitleId
	if typeof(eqId) == "string" and eqId ~= "" and achievementManager then
		if achievementManager:isUnlocked(data, eqId) then
			local ach = achievementManager:getById(eqId)
			if ach then
				local text = if isVip then "VIP  ·  " .. ach.name else ach.name
				return text, if isVip then VIP_COLOR else tier.color, true
			end
		end
	end

	local rebirths = data.rebirths or 0
	if rebirths > 0 or isVip then
		local titleText = if isVip then "VIP  ·  " .. tier.title else tier.title
		return titleText, if isVip then VIP_COLOR else tier.color, true
	end
	return nil, tier.color, false
end

-- ── BillboardGui ──────────────────────────────────────────────────────────────
local function rebuildBillboard(char: Model, playerName: string, data: any, achievementManager: any?)
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head then return end

	local old = head:FindFirstChild("PlayerTag")
	if old then old:Destroy() end

	local rebirths  = data.rebirths or 0
	local isVip     = MonetizationLogic.isVip(data)
	local tier      = getTier(rebirths)
	local titleText, badgeColor, showBadge = resolveTitleDisplay(data, tier, isVip, achievementManager)

	local bill = Instance.new("BillboardGui")
	bill.Name           = "PlayerTag"
	bill.Size           = UDim2.fromOffset(BILLBOARD_W, if showBadge then BILLBOARD_H_FULL else BILLBOARD_H_NAME)
	bill.StudsOffset    = Vector3.new(0, if showBadge then 2.8 else 2.3, 0)
	bill.AlwaysOnTop    = false
	bill.LightInfluence = 0.25
	bill.MaxDistance    = 100
	bill.Adornee        = head
	bill.Parent         = head

	bill:SetAttribute("BaseBillW", BILLBOARD_W)
	bill:SetAttribute("BaseBillHName", BILLBOARD_H_NAME)
	bill:SetAttribute("BaseBillHFull", BILLBOARD_H_FULL)
	bill:SetAttribute("BaseNameRowH", NAME_ROW_H)
	bill:SetAttribute("BaseNameTextSize", NAME_TEXT_SIZE)
	bill:SetAttribute("BaseTitleTextSize", TITLE_TEXT_SIZE)
	bill:SetAttribute("BaseTitleRowH", TITLE_ROW_H)
	bill:SetAttribute("BaseBadgePadV", BADGE_PAD_V)
	bill:SetAttribute("BaseBadgePadH", BADGE_PAD_H)
	bill:SetAttribute("BaseBadgeGap", BADGE_GAP)
	bill:SetAttribute("BaseBadgeH", BADGE_H)
	bill:SetAttribute("BaseStudsName", 2.3)
	bill:SetAttribute("BaseStudsFull", 2.8)
	bill:SetAttribute("HasBadge", showBadge)

	-- Имя игрока
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size                  = UDim2.new(1, 0, 0, NAME_ROW_H)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text                  = playerName
	nameLbl.TextColor3            = WHITE
	nameLbl.TextStrokeColor3      = BLACK
	nameLbl.TextStrokeTransparency = 0.45
	nameLbl.TextSize              = NAME_TEXT_SIZE
	nameLbl.Font                  = Enum.Font.GothamBlack
	nameLbl.TextXAlignment        = Enum.TextXAlignment.Center
	nameLbl.Parent                = bill

	if not showBadge or not titleText then return end

	-- Контейнер бейджа (авто-ширина по контенту)
	local badgeBg = Instance.new("Frame")
	badgeBg.Name              = "BadgeBg"
	badgeBg.Size              = UDim2.fromOffset(0, BADGE_H)
	badgeBg.Position          = UDim2.new(0.5, 0, 0, NAME_ROW_H + BADGE_GAP)
	badgeBg.AnchorPoint       = Vector2.new(0.5, 0)
	badgeBg.BackgroundColor3  = DARK_BG
	badgeBg.BackgroundTransparency = 0.25
	badgeBg.AutomaticSize     = Enum.AutomaticSize.X
	badgeBg.BorderSizePixel   = 0
	badgeBg.Parent            = bill

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badgeBg

	local stroke = Instance.new("UIStroke")
	stroke.Color       = badgeColor
	stroke.Thickness   = 1.2
	stroke.Transparency = 0.3
	stroke.Parent = badgeBg

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft   = UDim.new(0, BADGE_PAD_H)
	pad.PaddingRight  = UDim.new(0, BADGE_PAD_H)
	pad.PaddingTop    = UDim.new(0, BADGE_PAD_V)
	pad.PaddingBottom = UDim.new(0, BADGE_PAD_V)
	pad.Parent = badgeBg

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size                  = UDim2.fromOffset(0, TITLE_ROW_H)
	titleLbl.AutomaticSize         = Enum.AutomaticSize.X
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text                  = titleText
	titleLbl.TextColor3            = badgeColor
	titleLbl.TextStrokeColor3      = BLACK
	titleLbl.TextStrokeTransparency = 0.5
	titleLbl.TextSize              = TITLE_TEXT_SIZE
	titleLbl.Font                  = Enum.Font.GothamBold
	titleLbl.TextXAlignment        = Enum.TextXAlignment.Center
	titleLbl.Parent                = badgeBg
end

-- ── Highlight + свет + частицы ────────────────────────────────────────────────
local function rebuildAura(char: Model, data: any)
	-- Чистим старые
	local oldHl = char:FindFirstChildOfClass("Highlight")
	if oldHl then oldHl:Destroy() end

	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local oldAtt = root:FindFirstChild("AuraAttachment")
		if oldAtt then oldAtt:Destroy() end
		local oldLight = root:FindFirstChild("AuraLight")
		if oldLight then oldLight:Destroy() end
	end

	local rebirths = data.rebirths or 0
	local isVip    = MonetizationLogic.isVip(data)
	if rebirths == 0 and not isVip then return end

	local tier      = getTier(rebirths)
	local auraColor = if isVip then VIP_COLOR else tier.color
	local lightBrightness = if isVip then 0.65
		else math.min(0.18 + rebirths * 0.006, 0.55)

	-- Highlight — контур + слабая заливка
	local hl = Instance.new("Highlight")
	hl.Adornee           = char
	hl.FillColor         = auraColor
	hl.FillTransparency  = 0.92
	hl.OutlineColor      = auraColor
	hl.OutlineTransparency = 0.22
	hl.Parent            = char

	if not root then return end

	-- Цветной свет от персонажа
	local light = Instance.new("PointLight")
	light.Name       = "AuraLight"
	light.Color      = auraColor
	light.Range      = 16
	light.Brightness = lightBrightness
	light.Parent     = root

	-- Частицы: только для тиров с particleRate > 0
	if tier.particleRate <= 0 then return end

	local att = Instance.new("Attachment")
	att.Name     = "AuraAttachment"
	att.Position = Vector3.new(0, 0, 0)
	att.Parent   = root

	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   auraColor),
		ColorSequenceKeypoint.new(0.5, auraColor:Lerp(WHITE, 0.25)),
		ColorSequenceKeypoint.new(1,   auraColor),
	})
	pe.LightEmission    = 0.55
	pe.LightInfluence   = 0.15
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0),
		NumberSequenceKeypoint.new(0.25, 0.22),
		NumberSequenceKeypoint.new(1,   0),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.5),
		NumberSequenceKeypoint.new(0.4, 0.2),
		NumberSequenceKeypoint.new(1,   1),
	})
	pe.Speed              = NumberRange.new(2, 5)
	pe.VelocityInheritance = 0
	pe.SpreadAngle        = Vector2.new(360, 0)
	pe.Rate               = tier.particleRate
	pe.Lifetime           = NumberRange.new(0.8, 1.6)
	pe.RotSpeed           = NumberRange.new(-60, 60)
	pe.Rotation           = NumberRange.new(0, 360)
	pe.Parent             = att
end

-- ── Публичный API ──────────────────────────────────────────────────────────────
local PlayerTag = {}
PlayerTag.__index = PlayerTag

-- Кэш последнего состояния — не перестраиваем ауру на каждый тик
type CacheEntry = { rebirths: number, isVip: boolean, equippedTitleId: string? }

local _cache: { [number]: CacheEntry } = {}

function PlayerTag.new(deps: { achievementManager: any }?)
	return setmetatable({
		_achievementManager = deps and deps.achievementManager,
	}, PlayerTag)
end

-- Вызывается при join и после ребёрта/покупки gamepass.
-- Безопасен для вызова часто: перестраивает только если данные изменились.
function PlayerTag:apply(player: Player, data: any)
	local char = player.Character
	if not char then return end

	local rebirths = data.rebirths or 0
	local isVip    = MonetizationLogic.isVip(data)
	local eqTitle  = if typeof(data.equippedTitleId) == "string" then data.equippedTitleId else nil

	local uid = player.UserId
	local cached = _cache[uid]
	local changed = not cached
		or cached.rebirths ~= rebirths
		or cached.isVip ~= isVip
		or cached.equippedTitleId ~= eqTitle
	if not changed then return end

	_cache[uid] = { rebirths = rebirths, isVip = isVip, equippedTitleId = eqTitle }
	pcall(rebuildBillboard, char, player.Name, data, self._achievementManager)
	pcall(rebuildAura, char, data)
end

-- Вызывается при CharacterAdded — всегда перестраиваем (персонаж новый).
function PlayerTag:onCharacterAdded(player: Player, data: any)
	local char = player.Character or player.CharacterAdded:Wait()
	-- ждём ключевые части
	char:WaitForChild("Head", 6)
	char:WaitForChild("HumanoidRootPart", 6)

	-- Сбрасываем кэш чтобы гарантированно перестроить
	_cache[player.UserId] = nil
	self:apply(player, data)
end

function PlayerTag:onPlayerRemoving(player: Player)
	_cache[player.UserId] = nil
end

return PlayerTag
