--!strict
-- Data-driven последовательность сцен онбординга.
--
-- Конвенция таргетов:
--   * `block`              → ближайший part в workspace.DeepDigger_Mine
--   * `Tab_inventory`      → кнопка рюкзака в нижнем доке
--   * `HubZone_SELL`       → Workspace.SELL (зона продажи в хабе)
--   * `HubZone_UPGRADE`    → Workspace.UPGRADE (зона улучшений)
--   * `UpgRow_pickaxe`     → строка покупки кирки в открытой панели
--
-- `completeOn`:
--   * `block_mined`      → totalBlocksMined вырос
--   * `ore_sold`         → totalCoinsEarned вырос (авто-продажа в зоне SELL)
--   * `upgrades_ready`   → панель улучшений открыта (UpgRow_pickaxe виден)
--   * `pickaxe_bought`   → pickaxeLevel > 1
--   * `tab_inventory`    → клик по Tab_inventory (опционально)

export type CompleteCriterion =
	"block_mined"
	| "ore_sold"
	| "pickaxe_bought"
	| "tab_inventory"
	| "upgrades_ready"

export type Scene = {
	id: string,
	speaker: string,
	name: string,
	text: string,
	task: { title: string, description: string, goal: number? }?,
	target: string?,
	arrowText: string?,
	completeOn: CompleteCriterion?,
	hideAdvanceButton: boolean?,
	kind: "intro" | "task" | "success" | "finale",
	next: string?,
}

local NARRATOR_NAME = "Гид"
local NARRATOR_ICON = "🤖"

local TutorialFlow = {}

TutorialFlow.STEPS = {
	{
		id = "welcome",
		kind = "intro",
		speaker = NARRATOR_ICON,
		name = NARRATOR_NAME,
		text = "Привет. Я помогу разобраться с игрой. Это займёт меньше минуты.",
	} :: Scene,

	-- ===== STEP 0: добыть первый блок =====
	{
		id = "step_0_task",
		kind = "task",
		speaker = NARRATOR_ICON,
		name = NARRATOR_NAME,
        text = "Кликни по ближайшему блоку. Дорожка на земле покажет, куда идти.",
		task = { title = "Задание 1 из 3", description = "Добыть руду", goal = 1 },
		target = "block",
		arrowText = "Кликни сюда",
		completeOn = "block_mined",
		hideAdvanceButton = true,
	} :: Scene,
	{
		id = "step_0_success",
		kind = "success",
		speaker = NARRATOR_ICON,
		name = NARRATOR_NAME,
		text = "Готово. Руда в рюкзаке — её можно посмотреть кнопкой «Рюкзак» внизу экрана.",
	} :: Scene,

	-- ===== STEP 1: продажа в зоне хаба =====
	{
		id = "step_1_sell",
		kind = "task",
		speaker = NARRATOR_ICON,
		name = NARRATOR_NAME,
        text = "Следуй по дорожке к станции «Продажа». В зоне руда продастся сама.",
		task = { title = "Задание 2 из 3", description = "Продать руду в хабе" },
		target = "HubZone_SELL",
		arrowText = "Станция продажи",
		completeOn = "ore_sold",
		hideAdvanceButton = true,
	} :: Scene,
	{
		id = "step_1_success",
		kind = "success",
		speaker = NARRATOR_ICON,
		name = NARRATOR_NAME,
		text = "Монеты получены. Их можно потратить на улучшения снаряжения.",
	} :: Scene,

	-- ===== STEP 2: улучшения в зоне хаба =====
	{
		id = "step_2_go_upgrades",
		kind = "task",
		speaker = NARRATOR_ICON,
		name = NARRATOR_NAME,
		text = "Подойди к станции «Улучшения». Панель откроется сама, когда ты окажешься рядом.",
		task = { title = "Задание 3 из 3", description = "Открыть улучшения" },
		target = "HubZone_UPGRADE",
		arrowText = "Станция улучшений",
		completeOn = "upgrades_ready",
		hideAdvanceButton = true,
	} :: Scene,
	{
		id = "step_2_buy_pickaxe",
		kind = "task",
		speaker = NARRATOR_ICON,
		name = NARRATOR_NAME,
		text = "Купи улучшение кирки. Каждый уровень повышает урон. Стартовых монет хватит на первый.",
		task = { title = "Задание 3 из 3", description = "Купить улучшение кирки" },
		target = "UpgRow_pickaxe",
		arrowText = "Купить",
		completeOn = "pickaxe_bought",
		hideAdvanceButton = true,
	} :: Scene,

	{
		id = "finale",
		kind = "finale",
		speaker = NARRATOR_ICON,
		name = NARRATOR_NAME,
		text = "Туториал завершён. Копай глубже, чтобы находить редкие руды, и улучшай снаряжение в хабе. Удачи.",
	} :: Scene,
}

TutorialFlow.SERVER_STEP_AFTER = {
	step_0_success = 1,
	step_1_success = 2,
	finale = 3,
}

TutorialFlow.ENTRY_BY_SERVER_STEP = {
	[0] = "welcome",
	[1] = "step_1_sell",
	[2] = "step_2_go_upgrades",
	[3] = nil,
}

function TutorialFlow.findIndex(sceneId: string): number?
	for i, scene in ipairs(TutorialFlow.STEPS) do
		if scene.id == sceneId then
			return i
		end
	end
	return nil
end

function TutorialFlow.getById(sceneId: string): Scene?
	local idx = TutorialFlow.findIndex(sceneId)
	if not idx then
		return nil
	end
	return TutorialFlow.STEPS[idx]
end

function TutorialFlow.getNext(sceneId: string): Scene?
	local scene = TutorialFlow.getById(sceneId)
	if not scene then
		return nil
	end
	if scene.next then
		return TutorialFlow.getById(scene.next)
	end
	local idx = TutorialFlow.findIndex(sceneId)
	if idx then
		return TutorialFlow.STEPS[idx + 1]
	end
	return nil
end

return TutorialFlow
