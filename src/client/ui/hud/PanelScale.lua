--!strict
-- Масштаб HUD-модалок: uiScale() от ViewportLayout × дизайн-пиксели.

local ViewportLayout = require(script.Parent.Parent.util.ViewportLayout)

local PanelScale = {}

PanelScale.MODAL_W = 600
PanelScale.MODAL_H = 450
PanelScale.HEADER_H = 56

-- Нижний порог читаемости текста в пикселях. На телефоне uiScale < 1 ужимает
-- дизайн-размеры (sc(12) → ~10px), из-за чего подписи становятся нечитаемыми.
-- `text()` гарантирует, что итог не опустится ниже порога независимо от тира.
PanelScale.MIN_TEXT = 12

function PanelScale.layoutScale(): number
	return ViewportLayout.uiScale()
end

function PanelScale.sc(n: number): number
	return ViewportLayout.px(n)
end

-- Геометрия, синхронная с ×2 текстом десктопа: sc(design) × textMult(). На
-- desktop удваивает высоты строк/боксов/иконок, чтобы увеличенный (×2) текст
-- помещался без обрезки. На phone/tablet (textMult=1.0) == sc(design), т.е. байт-
-- в-байт прежние размеры. Компоненты, где нужно «десктоп = телефон ×2», просто
-- переопределяют `local sc = PanelScale.gsc`.
function PanelScale.gsc(n: number): number
	return math.max(1, math.floor(ViewportLayout.px(n) * ViewportLayout.textMult() + 0.5))
end

-- Размер текста ценника с дополнительным акцентом на десктопе (сверх ×2), чтобы
-- число цены было заметно крупнее и пропорционально остальному. Phone/tablet без
-- изменений (textMult=1.0 → == text(design)).
function PanelScale.priceText(design: number): number
	local base = PanelScale.text(design)
	if ViewportLayout.tier() == "desktop" then
		return math.floor(base * 1.25 + 0.5)
	end
	return base
end

-- Масштабированный размер текста с полом читаемости. `minPx` переопределяет
-- порог для узких мест (микро-подписи в маленьких ячейках).
-- На desktop итог домножается на текстовый множитель тира (×2) — телефон/планшет
-- не меняются (множитель = 1.0), поэтому их размеры остаются прежними.
function PanelScale.text(design: number, minPx: number?): number
	local base = math.max(minPx or PanelScale.MIN_TEXT, ViewportLayout.px(design))
	return math.floor(base * ViewportLayout.textMult() + 0.5)
end

-- Размер текста, заданный через дизайн-пиксели БЕЗ нижнего порога (аналог sc(),
-- но с текстовым множителем тира). Для строк, где sc()/px() раньше задавал
-- размер шрифта напрямую — сохраняет прежнее поведение phone/tablet.
function PanelScale.tsize(design: number): number
	return ViewportLayout.textPx(design)
end

-- Текстовый множитель тира (2.0 desktop, 1.0 иначе). Для ручного домножения
-- заранее вычисленных/хардкодных размеров текста.
function PanelScale.textMult(): number
	return ViewportLayout.textMult()
end

-- Размер текста в дизайн-пространстве модалки (UIScale fitScale): итог на экране
-- ≈ PanelScale.text(design), как в MainPanel / GoalsPanel.
function PanelScale.modalText(design: number, fitScale: number, minPx: number?): number
	local target = PanelScale.text(design, minPx)
	return math.max(1, math.floor(target / math.max(fitScale, 0.01) + 0.5))
end

function PanelScale.modalTsize(design: number, fitScale: number): number
	return math.max(1, math.floor(PanelScale.tsize(design) / math.max(fitScale, 0.01) + 0.5))
end

-- Геометрия строк/кнопок в дизайн-пространстве модалки (синхронно с modalText).
function PanelScale.modalGsc(design: number, fitScale: number): number
	return math.max(1, math.floor(PanelScale.gsc(design) / math.max(fitScale, 0.01) + 0.5))
end

function PanelScale.scrollBar(): number
	return math.max(4, PanelScale.sc(5))
end

function PanelScale.pad(n: number): UDim
	return UDim.new(0, PanelScale.sc(n))
end

return PanelScale
