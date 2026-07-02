--!strict
-- Modern dark mining UI — тёмный navy, яркие акценты, читаемые шрифты.

local C = {
	-- Базовые фоны
	bg1        = Color3.fromRGB(8,  10, 18),    -- самый тёмный (backdrop)
	bg2        = Color3.fromRGB(14, 17, 30),    -- фон ScreenGui-панелей
	bg3        = Color3.fromRGB(22, 26, 44),    -- карточки / строки
	bg4        = Color3.fromRGB(30, 36, 58),    -- hover / active fill
	bgChip     = Color3.fromRGB(16, 20, 36),    -- чипы валюты
	dockBg     = Color3.fromRGB(11, 13, 24),    -- нижний докинг
	dockBorder = Color3.fromRGB(38, 46, 74),    -- рамка дока и чипов

	-- Акценты
	primary    = Color3.fromRGB(82, 126, 255),
	primaryHi  = Color3.fromRGB(112, 154, 255),

	-- Валюта
	gold       = Color3.fromRGB(255, 212, 38),
	goldHi     = Color3.fromRGB(255, 238, 130),

	-- Продать
	sell       = Color3.fromRGB(44, 210, 108),
	sellHi     = Color3.fromRGB(70, 238, 136),
	sellDark   = Color3.fromRGB(20, 108, 55),

	-- Панели
	panelBg    = Color3.fromRGB(18, 22, 38),
	panelBody  = Color3.fromRGB(22, 26, 44),
	panelInner = Color3.fromRGB(28, 32, 52),

	-- Текст
	textMain   = Color3.fromRGB(228, 234, 255),
	textSub    = Color3.fromRGB(148, 158, 195),
	textMuted  = Color3.fromRGB(76, 88, 120),
	textDark   = Color3.fromRGB(24, 28, 46),
	white      = Color3.fromRGB(255, 255, 255),

	-- Контуры
	outline     = Color3.fromRGB(255, 255, 255),
	outlineDark = Color3.fromRGB(0, 0, 0),

	-- Глубина
	depthFill  = Color3.fromRGB(100, 180, 255),
	depthBg    = Color3.fromRGB(28, 36, 60),

	-- Gem
	gem        = Color3.fromRGB(120, 200, 255),

	-- Прочее
	closeBg    = Color3.fromRGB(220, 55, 75),
	backdrop   = Color3.fromRGB(0, 0, 0),

	-- Редкости
	common     = Color3.fromRGB(175, 180, 200),
	uncommon   = Color3.fromRGB(72, 218, 116),
	rare       = Color3.fromRGB(64, 156, 255),
	epic       = Color3.fromRGB(188, 68, 236),
	legendary  = Color3.fromRGB(255, 168, 0),
	mythic     = Color3.fromRGB(255, 60, 60),

	-- Старые алиасы (совместимость с панелями)
	panelHeader   = Color3.fromRGB(82, 126, 255),
	panelHeaderHi = Color3.fromRGB(112, 154, 255),
	panelBorder   = Color3.fromRGB(38, 46, 74),
	panelInnerOld = Color3.fromRGB(28, 32, 52),
	outlineSoft   = Color3.fromRGB(38, 46, 74),
	btnBg         = Color3.fromRGB(22, 26, 44),
	btnHover      = Color3.fromRGB(30, 36, 58),
	btnBorder     = Color3.fromRGB(8, 10, 18),
	currencyBg    = Color3.fromRGB(16, 20, 36),
	currencyStroke = Color3.fromRGB(38, 46, 74),
	sellBg        = Color3.fromRGB(44, 210, 108),
	sellBgHi      = Color3.fromRGB(70, 238, 136),
	sellText      = Color3.fromRGB(255, 255, 255),
	sellStroke    = Color3.fromRGB(8, 10, 18),
	gemBg         = Color3.fromRGB(20, 40, 60),
	textLabel     = Color3.fromRGB(148, 158, 195),
	btnDisabled   = Color3.fromRGB(50, 58, 88),
	goldBg        = Color3.fromRGB(40, 32, 8),
}

local TAB_ACCENTS = {
	inventory   = Color3.fromRGB(255, 140, 55),
	upgrades    = Color3.fromRGB(72, 206, 255),
	goals       = Color3.fromRGB(255, 85, 115),
	journal     = Color3.fromRGB(168, 115, 255),
	stats       = Color3.fromRGB(96, 165, 250),
	rebirth     = Color3.fromRGB(50, 225, 255),
	leaderboard = Color3.fromRGB(255, 200, 60),
	shop        = Color3.fromRGB(255, 120, 175),
	pets        = Color3.fromRGB(255, 140, 95),
	more        = Color3.fromRGB(120, 132, 168),
	sell        = Color3.fromRGB(44, 210, 108),
	home        = Color3.fromRGB(52, 188, 255),
}

-- Подписи для нижнего дока (короткие — 7 кнопок в ряд)
local TAB_LABELS: { [string]: string } = {
	inventory   = "Рюкзак",
	upgrades    = "Кирка",
	goals       = "Цели",
	journal     = "Журнал",
	sell        = "ПРОДАТЬ",
	more        = "Ещё",
	stats       = "Статы",
	rebirth     = "Ребёрт",
	leaderboard = "Топ",
	shop        = "МАГАЗИН",
	pets        = "Питомцы",
	home        = "Домой",
}

local RARITY_COLOR = {
	common    = C.common,
	uncommon  = C.uncommon,
	rare      = C.rare,
	epic      = C.epic,
	legendary = C.legendary,
	mythic    = C.mythic,
}

local LAYER_COLORS = {
	dirt      = Color3.fromRGB(140, 200, 80),
	stone     = Color3.fromRGB(160, 165, 180),
	limestone = Color3.fromRGB(220, 200, 155),
	crimson   = Color3.fromRGB(230, 65, 65),
	marble    = Color3.fromRGB(210, 215, 235),
	obsidian  = Color3.fromRGB(148, 88, 230),
	void      = Color3.fromRGB(88, 44, 168),
}

local UPGRADE_COLORS = {
	pickaxe   = Color3.fromRGB(255, 100, 90),
	speed     = Color3.fromRGB(90, 220, 120),
	fortune   = Color3.fromRGB(80, 170, 255),
	inventory = Color3.fromRGB(180, 120, 255),
	crit      = Color3.fromRGB(255, 170, 50),
	multiSell = Color3.fromRGB(255, 213, 74),
	autoSell  = Color3.fromRGB(80, 230, 210),
}

local RARITY_ORDER = {
	mythic = 1, legendary = 2, epic = 3,
	rare = 4, uncommon = 5, common = 6,
}

local FONT = {
	title    = Enum.Font.GothamBlack,
	body     = Enum.Font.GothamBold,
	label    = Enum.Font.GothamMedium,
	currency = Enum.Font.GothamBlack,
}

local RADIUS = {
	panel   = UDim.new(0, 16),
	chip    = UDim.new(0, 12),
	btn     = UDim.new(0, 10),
	navBtn  = UDim.new(0, 10),
	icon    = UDim.new(0, 8),
	pill    = UDim.new(1, 0),
	-- старые алиасы
	sidebarBtn = UDim.new(0, 10),
}

local STROKE = {
	thick  = 2,
	medium = 1.5,
	thin   = 1,
}

-- Яркость HUD-иконок (магазин — эталон: белый tint, без лишней прозрачности).
local ICON = {
	tint           = Color3.fromRGB(255, 255, 255),
	inactiveAlpha  = 0.12,
	mutedAlpha     = 0.22,
	circleBgAlpha  = 0.78,
}

return {
	C              = C,
	TAB_ACCENTS    = TAB_ACCENTS,
	TAB_LABELS     = TAB_LABELS,
	RARITY_COLOR   = RARITY_COLOR,
	LAYER_COLORS   = LAYER_COLORS,
	UPGRADE_COLORS = UPGRADE_COLORS,
	RARITY_ORDER   = RARITY_ORDER,
	FONT           = FONT,
	RADIUS         = RADIUS,
	STROKE         = STROKE,
	ICON           = ICON,
}
