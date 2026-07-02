--!strict
-- Геометрия EggShopModal: размер окна, секций (шапка/превью/стоимость/шансы/пул/футер)
-- и сетки пула питомцев. Отдельный модуль, чтобы EggShopModal не разрастался и
-- пропорции окна можно было менять в одном месте.

local ViewportLayout = require(script.Parent.util.ViewportLayout)

local EggShopLayout = {}

-- Доп. множитель текста тела egg-модалки на десктопе. Полный ×2 не влезает в
-- «пейзажную» правую панель (шансы), поэтому берём 1.5 — текст заметно крупнее,
-- а список шансов всё ещё показывает несколько строк (остальное — скролл).
-- Phone/tablet = 1.0 (без изменений).
EggShopLayout.DESKTOP_TEXT_MULT = 1.5

function EggShopLayout.textMult(): number
	if ViewportLayout.tier() == "desktop" then
		return EggShopLayout.DESKTOP_TEXT_MULT
	end
	return 1.0
end

-- Дизайн-пропорция окна. Aspect (H/W ≈ 0.77) подобран так, чтобы на десктопе
-- окно НЕ упиралось в максимум по высоте (см. ViewportLayout.modalPixels): при
-- aspect ≥ 0.886 targetH клампился к capH и окно выглядело «избыточно большим».
EggShopLayout.MODAL_W = 620
EggShopLayout.MODAL_H = 480
EggShopLayout.FOOTER_BTN_H = 50
EggShopLayout.FOOTER_GAP = 10
EggShopLayout.FOOTER_H = EggShopLayout.FOOTER_BTN_H * 2 + EggShopLayout.FOOTER_GAP

export type Layout = {
	scale: number,
	sidePad: number,
	headerH: number,
	footerH: number,
	footerPad: number,
	previewSize: number,
	previewX: number,
	previewY: number,
	rightX: number,
	rightW: number,
	rightY: number,
	rightH: number,
	costLabelH: number,
	costBoxH: number,
	oddsLabelH: number,
	oddsListY: number,
	oddsListH: number,
	poolLabelY: number,
	poolLabelH: number,
	poolY: number,
	poolH: number,
	poolW: number,
	poolPad: number,
	gridGap: number,
}

function EggShopLayout.compute(eggW: number, eggH: number): Layout
	local scale = math.clamp(eggH / EggShopLayout.MODAL_H, 0.58, 1.15)
	local et = EggShopLayout.textMult()
	local function d(n: number): number
		return math.floor(n * scale + 0.5)
	end
	-- dt: высота блоков, которые ДЕРЖАТ текст (подписи, коробка стоимости).
	-- На десктопе растёт вместе с текстом (×et), чтобы 1.5× шрифт не обрезался.
	local function dt(n: number): number
		return math.floor(n * scale * et + 0.5)
	end

	local sidePad = d(16)
	local headerH = d(46)
	local topGap = d(12)
	local footerPad = d(14)
	local footerH = d(EggShopLayout.FOOTER_H)
	local sectionGap = d(10)

	local bodyTop = headerH + topGap
	local bodyBottom = eggH - footerPad - footerH
	local bodyH = math.max(d(120), bodyBottom - bodyTop)

	-- Верхний блок (превью слева + стоимость/шансы справа) — фиксированная доля
	-- тела. Правая панель ровно по высоте превью → нет «мёртвого» зазора.
	local previewSize = math.clamp(math.floor(bodyH * 0.44 + 0.5), d(112), d(188))
	local previewX = sidePad
	local previewY = bodyTop
	local rightX = previewX + previewSize + sectionGap
	local rightW = math.max(d(120), eggW - rightX - sidePad)
	local rightY = previewY
	local rightH = previewSize

	local costLabelH = dt(15)
	local costBoxH = dt(32)
	local oddsLabelH = dt(15)
	local innerGap = d(6)
	local oddsListY = costLabelH + costBoxH + innerGap + oddsLabelH + d(2)
	local oddsListH = math.max(d(40), rightH - oddsListY)

	local poolLabelY = bodyTop + previewSize + sectionGap
	local poolLabelH = dt(16)
	local poolY = poolLabelY + poolLabelH + d(4)
	local poolH = math.max(d(84), bodyBottom - poolY)
	local poolW = eggW - sidePad * 2
	local poolPad = d(8)
	local gridGap = d(8)

	return {
		scale = scale,
		sidePad = sidePad,
		headerH = headerH,
		footerH = footerH,
		footerPad = footerPad,
		previewSize = previewSize,
		previewX = previewX,
		previewY = previewY,
		rightX = rightX,
		rightW = rightW,
		rightY = rightY,
		rightH = rightH,
		costLabelH = costLabelH,
		costBoxH = costBoxH,
		oddsLabelH = oddsLabelH,
		oddsListY = oddsListY,
		oddsListH = oddsListH,
		poolLabelY = poolLabelY,
		poolLabelH = poolLabelH,
		poolY = poolY,
		poolH = poolH,
		poolW = poolW,
		poolPad = poolPad,
		gridGap = gridGap,
	}
end

-- Сетка пула: окна тут «пейзажные» (шире, чем выше), поэтому при низком пуле
-- раскладываем питомцев в ОДИН ряд (cols = petCount) — он заполняет ширину без
-- горизонтальных «дыр» и без вертикального скролла. Если пул высокий (портретное
-- окно) — обычная сетка 3×N с крупными плитками и вертикальным скроллом.
function EggShopLayout.poolGrid(
	petCount: number,
	poolW: number,
	poolH: number,
	poolPad: number,
	gridGap: number,
	scale: number
): (number, number)
	local function d(n: number): number
		return math.max(1, math.floor(n * scale + 0.5))
	end
	local innerW = poolW - poolPad * 2
	local innerH = poolH - poolPad * 2
	local count = math.max(1, petCount)

	local twoRowCellH = math.floor((innerH - gridGap) / 2)
	local bigTileH = d(122)

	if twoRowCellH >= bigTileH then
		local cols = math.clamp(math.min(count, 3), 1, 3)
		local rows = math.max(1, math.ceil(count / cols))
		local cellW = math.floor((innerW - gridGap * (cols - 1)) / cols)
		local cellH = math.clamp(
			math.floor((innerH - gridGap * (rows - 1)) / rows),
			bigTileH,
			d(176)
		)
		return math.max(1, cellW), cellH
	end

	local cols = math.clamp(count, 1, 6)
	local cellW = math.floor((innerW - gridGap * (cols - 1)) / cols)
	local cellH = math.clamp(innerH, d(78), d(190))
	return math.max(1, cellW), cellH
end

return EggShopLayout
