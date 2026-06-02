--!strict
-- TutorialFlow.lua — Phase 8 polish: data-driven последовательность сцен
-- онбординга. Один файл правды по текстам туториала, чтобы переписать
-- любую реплику можно было без правок логики.
--
-- Каждый шаг (`step`) описывает «сцену»: что показать игроку (диалог
-- наставника + трекер задания + куда указывает стрелка) и какое условие
-- завершает шаг (`completeOn`). Состояния обработки рассчитывает
-- `Tutorial.lua`.
--
-- Конвенция таргетов:
--   * `target = "block"`        → ближайший part в workspace.DeepDigger_Mine
--   * `target = "Tab_inventory"`→ HUD.findChild по Name
--   * `target = "SellButton"`, `"Tab_upgrades"`, `"UpgRow_pickaxe"` — то же
--   * `target = nil`           → стрелка не показывается (только диалог)
--
-- `completeOn` описывает критерий продвижения дальше. Tutorial.lua слушает
-- `PlayerStats` и сравнивает baseline на момент входа в шаг с текущим:
--   * `"block_mined"`     → totalBlocksMined увеличился
--   * `"ore_sold"`        → totalCoinsEarned увеличился
--   * `"pickaxe_bought"`  → pickaxeLevel > 1
--   * `"tab_inventory"`   → клик по Tab_inventory (локальное событие)
--   * `"tab_upgrades"`    → клик по Tab_upgrades
--   * `nil`               → шаг сам не завершается (только Понятно)

export type CompleteCriterion =
    "block_mined"
    | "ore_sold"
    | "pickaxe_bought"
    | "tab_inventory"
    | "tab_upgrades"

export type Scene = {
    id: string,
    -- Диалог наставника.
    speaker: string,             -- emoji-аватар, напр. "⛏️"
    name: string,                -- имя наставника
    text: string,                -- основной текст
    -- Задание для трекера. Если nil — трекер скрывается.
    task: { title: string, description: string, goal: number? }?,
    -- Куда показывает стрелка. Если nil — стрелки нет.
    target: string?,
    arrowText: string?,          -- подпись возле стрелки
    -- Условие автопродвижения. Если nil — игрок жмёт «Понятно ✓».
    completeOn: CompleteCriterion?,
    -- Скрипт-кнопка диалога. По умолчанию «Понятно ✓» с продвижением вперёд.
    -- Если true — кнопка скрыта (шаг ждёт автозавершения).
    hideAdvanceButton: boolean?,
    -- Тип сцены: "intro" (приветствие), "task" (с заданием), "success"
    -- (поздравление после выполнения), "finale" (последняя). Используется
    -- для подбора цвета и звука.
    kind: "intro" | "task" | "success" | "finale",
    -- Ссылка на следующую сцену. Если nil — следующая по порядку из STEPS.
    next: string?,
}

-- Нейтральный персонаж-помощник без сленга и характера: «Гид» с emoji-роботом.
-- Робот выбран осознанно: гендерно-нейтральный, не «герой со своим тоном»,
-- говорит формально и спокойно — никакого «Здорóво» / «Бородач» / «Молодец».
-- Тон диалогов: на «ты», вежливо, без восклицаний и жаргона.
local NARRATOR_NAME = "Гид"
local NARRATOR_ICON = "🤖"

local TutorialFlow = {}

-- Линейная последовательность сцен. Tutorial.lua идёт по этому массиву
-- слева направо: после `success`-сцены — следующий `intro`, и т.д.
TutorialFlow.STEPS = {
    -- ===== WELCOME (server step 0 = NOT_STARTED) =====
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
        text = "Кликни по блоку перед собой, чтобы добыть руду.",
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
        text = "Готово. Руда добавлена в инвентарь. Теперь её можно продать за монеты.",
    } :: Scene,

    -- ===== STEP 1: открыть инвентарь и продать =====
    {
        id = "step_1_open_inventory",
        kind = "task",
        speaker = NARRATOR_ICON,
        name = NARRATOR_NAME,
        text = "Открой вкладку «Инвентарь» — там хранится всё, что ты добыл.",
        task = { title = "Задание 2 из 3", description = "Открыть инвентарь" },
        target = "Tab_inventory",
        arrowText = "Инвентарь",
        completeOn = "tab_inventory",
        hideAdvanceButton = true,
    } :: Scene,
    {
        id = "step_1_sell",
        kind = "task",
        speaker = NARRATOR_ICON,
        name = NARRATOR_NAME,
        text = "Нажми кнопку «Продать руды». За каждую руду ты получишь монеты.",
        task = { title = "Задание 2 из 3", description = "Продать руду" },
        target = "SellButton",
        arrowText = "Продать",
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

    -- ===== STEP 2: купить улучшение кирки =====
    {
        id = "step_2_open_upgrades",
        kind = "task",
        speaker = NARRATOR_ICON,
        name = NARRATOR_NAME,
        text = "Открой вкладку «Улучшения». Здесь можно усилить кирку и инвентарь.",
        task = { title = "Задание 3 из 3", description = "Открыть улучшения" },
        target = "Tab_upgrades",
        arrowText = "Улучшения",
        completeOn = "tab_upgrades",
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

    -- ===== FINAL =====
    {
        id = "finale",
        kind = "finale",
        speaker = NARRATOR_ICON,
        name = NARRATOR_NAME,
        text = "Туториал завершён. Копай глубже, чтобы находить редкие руды, и улучшай снаряжение. Удачи.",
    } :: Scene,
}

-- Маппинг scene → server-видимый tutorialStep, чтобы клиент знал,
-- когда вызвать `Net:Invoke("UpdateTutorialStep", N)`. Server валидирует
-- монотонный рост и хранит шаг для перезаходов.
TutorialFlow.SERVER_STEP_AFTER = {
    step_0_success = 1, -- после добычи первого блока
    step_1_success = 2, -- после продажи руды
    finale = 3,         -- после покупки кирки
}

-- Какой scene показать при `Tutorial.start(serverStep)` (когда сервер
-- сказал нам tutorialStep = N). 0 → начинаем с welcome, 1 → с step_1_intro,
-- 2 → с step_2_intro, 3 → сразу скрываем туториал.
TutorialFlow.ENTRY_BY_SERVER_STEP = {
    [0] = "welcome",
    [1] = "step_1_open_inventory",
    [2] = "step_2_open_upgrades",
    [3] = nil, -- 3 = completed, не показываем
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
    if not idx then return nil end
    return TutorialFlow.STEPS[idx]
end

function TutorialFlow.getNext(sceneId: string): Scene?
    local scene = TutorialFlow.getById(sceneId)
    if not scene then return nil end
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
