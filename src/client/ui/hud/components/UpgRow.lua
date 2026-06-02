--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local UpgradeMeta = require(script.Parent.Parent.UpgradeMeta)
local SoundManager = require(script.Parent.Parent.Parent.Parent.core.SoundManager)
local UpgradeLogic = require(ReplicatedStorage:WaitForChild("shared").util.UpgradeLogic)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local Notification = require(script.Parent.Parent.Parent.Notification)
local Tooltip = require(script.Parent.Tooltip)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C

local FEEDBACK_SECONDS = 2

-- Phase 8: цвета для error-тостов. Серверная экономика возвращает локализованный
-- `result.message` — мы лишь подбираем цвет под код ошибки.
local ERROR_COLOR_BY_CODE = {
    not_enough_coins = Color3.fromRGB(255, 90, 60),
    max_level = Color3.fromRGB(180, 180, 180),
}
local DEFAULT_ERROR_COLOR = Color3.fromRGB(255, 140, 60)

export type Props = {
    upgradeId: string,
    level: number,
    maxLevel: number,
    -- Phase 9: количество ребёртов нужно для UpgradeLogic.describeNextLevel
    -- (после R5/R10/R25 у pickaxe появляется новый next-level, иначе
    -- tooltip говорит «улучшать нечего», а сервер при этом принимает Buy).
    rebirths: number?,
    cost: number,
    canAfford: boolean,
    canAffordNow: () -> boolean,
    coinsNow: () -> number,
    onBuy: () -> any,
}

local UpgRow = {}

function UpgRow.create(s: ScopeFactory.HudScope, props: Props)
    local isMax = if props.upgradeId == "autoSell"
        then props.level >= 1
        else props.level >= props.maxLevel
    local accent = theme.UPGRADE_COLORS[props.upgradeId] or C.rare
    local hovered = s:Value(false)
    local buyBusy = s:Value(false)
    local buyHint = s:Value("")

    -- Phase 8: формируем текст tooltip'a динамически (через UpgradeLogic),
    -- чтобы tooltip всегда показывал актуальное состояние и сравнение
    -- с next-level. На MAX-уровне tooltip объясняет, что улучшать нечего.
    local function buildTooltipText(): string
        local name = UpgradeMeta.NAMES[props.upgradeId] or props.upgradeId
        local desc = UpgradeMeta.DESC[props.upgradeId] or ""
        local levelLabel
        if props.upgradeId == "autoSell" then
            levelLabel = if props.level >= 1 then "Куплено" else "Не куплено"
        else
            levelLabel = ("Уровень %d / %d"):format(props.level, props.maxLevel)
        end
        local now = UpgradeLogic.describeCurrentLevel(props.upgradeId, props.level)
        local nextStr = UpgradeLogic.describeNextLevel(props.upgradeId, props.level, props.rebirths or 0)
        local lines = {
            "<b>" .. name .. "</b>",
            desc,
            levelLabel,
            "Сейчас: " .. now,
        }
        if nextStr and not isMax then
            table.insert(lines, "<font color=\"rgb(255,210,50)\">Далее: " .. nextStr .. "</font>")
        elseif isMax then
            table.insert(lines, "<font color=\"rgb(180,180,180)\">Максимальный уровень</font>")
        end
        -- Дополнительно — подсказка о нехватке монет, если не хватает.
        if not isMax then
            local coins = props.coinsNow and props.coinsNow() or 0
            if coins < props.cost then
                local deficit = props.cost - coins
                table.insert(lines, ("<font color=\"rgb(255,120,90)\">Не хватает %d 💰</font>"):format(deficit))
            end
        end
        return table.concat(lines, "\n")
    end

    local function tryPurchase()
        if peek(buyBusy) or isMax then
            return
        end
        if not props.canAffordNow() then
            SoundManager.play("buy_fail")
            buyHint:set("💰?")
            local coins = props.coinsNow and props.coinsNow() or 0
            local deficit = math.max(1, props.cost - coins)
            local name = UpgradeMeta.NAMES[props.upgradeId] or props.upgradeId
            Notification.show({
                text = ("%s: не хватает %d монет"):format(name, deficit),
                icon = "💰",
                color = ERROR_COLOR_BY_CODE.not_enough_coins,
                duration = 2.5,
            })
            task.delay(FEEDBACK_SECONDS, function()
                buyHint:set("")
            end)
            return
        end

        buyBusy:set(true)
        buyHint:set("...")

        local ok, result = pcall(props.onBuy)
        if not ok then
            SoundManager.play("buy_fail")
            buyHint:set("Ошибка")
            Notification.show({
                text = "Сетевая ошибка покупки",
                icon = "⚠",
                color = DEFAULT_ERROR_COLOR,
                duration = 2.5,
            })
            buyBusy:set(false)
            return
        end

        if typeof(result) == "table" and result.success then
            SoundManager.play("buy_upgrade")
            buyHint:set("✓")
        elseif typeof(result) == "table" and result.message then
            SoundManager.play("buy_fail")
            buyHint:set(result.message)
            local color = ERROR_COLOR_BY_CODE[result.error or ""] or DEFAULT_ERROR_COLOR
            Notification.show({
                text = result.message,
                icon = "⚠",
                color = color,
                duration = 2.5,
            })
        else
            SoundManager.play("buy_fail")
            buyHint:set("Ошибка")
            Notification.show({
                text = "Покупка не выполнена",
                icon = "⚠",
                color = DEFAULT_ERROR_COLOR,
                duration = 2.5,
            })
        end

        task.delay(FEEDBACK_SECONDS, function()
            buyHint:set("")
            buyBusy:set(false)
        end)
    end

    -- `Name` поле — конвенция Phase 8: TutorialArrow ищет таргет именно
    -- по этому имени (PlayerGui.DeepDiggerHUD:FindFirstChild(..., true)).
    -- В свою очередь Tooltip привязываемся к этому же frame'у через scope,
    -- так что cleanup идёт через Fusion.doCleanup(scope) автоматически.
    local rowFrame = s:New("Frame")({
        Name = "UpgRow_" .. props.upgradeId,
        Size = UDim2.new(1, -8, 0, 54),
        BackgroundColor3 = s:Computed(function(use)
            return use(hovered) and C.btnHover or C.btnBg
        end),
        BorderSizePixel = 0,
        [OnEvent("MouseEnter")] = function()
            hovered:set(true)
        end,
        [OnEvent("MouseLeave")] = function()
            hovered:set(false)
        end,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
            s:New("UIStroke")({ Color = C.btnBorder, Thickness = 1, Transparency = 0.5 }),
            s:New("Frame")({
                Size = UDim2.new(0, 4, 1, -8),
                Position = UDim2.new(0, 4, 0, 4),
                BackgroundColor3 = accent,
                BorderSizePixel = 0,
                [Children] = { s:New("UICorner")({ CornerRadius = UDim.new(0, 2) }) },
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.55, 0, 0, 22),
                Position = UDim2.new(0, 16, 0, 6),
                BackgroundTransparency = 1,
                Text = UpgradeMeta.NAMES[props.upgradeId] or props.upgradeId,
                TextSize = 16,
                Font = Enum.Font.GothamBold,
                TextColor3 = accent,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.55, 0, 0, 14),
                Position = UDim2.new(0, 16, 0, 28),
                BackgroundTransparency = 1,
                Text = UpgradeMeta.DESC[props.upgradeId] or "",
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextColor3 = C.textMuted,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.2, 0, 0, 22),
                Position = UDim2.new(0.58, 0, 0, 6),
                BackgroundTransparency = 1,
                Text = isMax and "МАКС" or (if props.upgradeId == "autoSell" and props.level < 1 then "—" else tostring(props.level)),
                TextSize = 18,
                Font = Enum.Font.GothamBlack,
                TextColor3 = isMax and C.gold or C.textMain,
                TextXAlignment = Enum.TextXAlignment.Right,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.2, 0, 0, 14),
                Position = UDim2.new(0.58, 0, 0, 30),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local hint = use(buyHint)
                    if hint ~= "" then
                        return hint
                    end
                    if isMax then
                        return ""
                    end
                    return "💰 " .. Formatters.shortNumber(props.cost)
                end),
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextColor3 = s:Computed(function(use)
                    if use(buyHint) ~= "" then
                        return C.gold
                    end
                    return props.canAfford and C.gold or C.textMuted
                end),
                TextXAlignment = Enum.TextXAlignment.Right,
            }),
            s:New("TextButton")({
                Name = "BuyButton",
                Size = UDim2.new(0, 36, 0, 36),
                Position = UDim2.new(1, -44, 0.5, -18),
                ZIndex = 2,
                BackgroundColor3 = s:Computed(function(use)
                    if isMax then
                        return C.btnDisabled
                    end
                    return if props.canAfford then accent else C.btnDisabled
                end),
                BorderSizePixel = 0,
                Text = isMax and "✓" or "+",
                TextSize = 20,
                Font = Enum.Font.GothamBlack,
                TextColor3 = C.white,
                Active = not isMax,
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
                    s:New("UIStroke")({
                        Color = if props.canAfford and not isMax then C.white else C.btnBorder,
                        Thickness = 1.5,
                        Transparency = 0.5,
                    }),
                },
                [OnEvent("Activated")] = tryPurchase,
            }),
        },
    })

    Tooltip.attach(s, rowFrame, buildTooltipText)
    return rowFrame
end

return UpgRow
