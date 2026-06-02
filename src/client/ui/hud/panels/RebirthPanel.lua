--!strict
-- RebirthPanel.lua — Phase 9.
--
-- Контент 4-го таба HUD. Показывает:
--   * Заголовок «Ребёрты: N» + «Множитель: x1.X».
--   * Кнопка REBIRTH (стоимость, disabled если не хватает монет).
--   * Информационные секции: что сохранится / сбросится / следующий бонус.
--
-- На клик [REBIRTH] открывается RebirthConfirmModal (anti-misclick 0.3с),
-- по подтверждению — Net:Invoke("Rebirth"). Сервер возвращает success или
-- ошибку (which is shown через Notification). FX/тост приходят отдельно
-- через Net:Connect("Notify") с kind="rebirth".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)
local RebirthLogic = require(ReplicatedStorage:WaitForChild("shared").util.RebirthLogic)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local SoundManager = require(script.Parent.Parent.Parent.Parent.core.SoundManager)
local Notification = require(script.Parent.Parent.Parent.Notification)
local RebirthConfirmModal = require(script.Parent.Parent.components.RebirthConfirmModal)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C

local RebirthPanel = {}

local function buildBodyText(currentRebirths: number, currentMultiplier: number, nextMultiplier: number): string
    -- RichText. Используется в RebirthConfirmModal: важно, чтобы текст
    -- читался за 1-2 секунды (anti-misclick 0.3с — это floor, игрок всё
    -- равно может ткнуть быстро).
    local lines = {
        ("<b>Текущий ребёрт:</b> #%d → #%d"):format(currentRebirths, currentRebirths + 1),
        ("<b>Множитель к ценам руд:</b> x%.1f → <font color=\"rgb(255,210,50)\">x%.1f</font>"):format(currentMultiplier, nextMultiplier),
        "",
        "<font color=\"rgb(150,255,150)\">✓ Сохранится:</font> ребёрты, статистика, рекорды глубины, туториал.",
        "<font color=\"rgb(255,140,90)\">✗ Сбросится:</font> монеты, инвентарь, ВСЕ апгрейды, авто-продажа.",
    }
    local nextThreshold = RebirthLogic.nextPickaxeBonusThreshold(currentRebirths)
    if nextThreshold then
        local remaining = nextThreshold - currentRebirths
        table.insert(lines, "")
        table.insert(lines, ("<font color=\"rgb(120,200,255)\">⛏ Следующий бонус кирки:</font> +1 maxLevel на R%d (осталось %d)")
            :format(nextThreshold, remaining))
    end
    return table.concat(lines, "\n")
end

local function panelHeader(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("Frame")({
        Name = "Header",
        Size = UDim2.new(1, -8, 0, 78),
        BackgroundColor3 = C.btnBg,
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
            s:New("UIStroke")({ Color = C.gold, Thickness = 1.5, Transparency = 0.4 }),
            s:New("TextLabel")({
                Size = UDim2.new(0.5, -16, 0, 22),
                Position = UDim2.new(0, 14, 0, 12),
                BackgroundTransparency = 1,
                Text = "💠 РЕБЁРТЫ",
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.textLabel,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.5, -16, 0, 30),
                Position = UDim2.new(0, 14, 0, 34),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    return tostring(math.floor(use(state.rebirths) or 0))
                end),
                TextSize = 26,
                Font = Enum.Font.GothamBlack,
                TextColor3 = C.gold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.5, -16, 0, 22),
                Position = UDim2.new(0.5, 0, 0, 12),
                BackgroundTransparency = 1,
                Text = "✨ МНОЖИТЕЛЬ К ЦЕНАМ",
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.textLabel,
                TextXAlignment = Enum.TextXAlignment.Right,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.5, -16, 0, 30),
                Position = UDim2.new(0.5, 0, 0, 34),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local mult = use(state.rebirthMultiplier) or 1
                    return ("x%.1f"):format(mult)
                end),
                TextSize = 26,
                Font = Enum.Font.GothamBlack,
                TextColor3 = C.gold,
                TextXAlignment = Enum.TextXAlignment.Right,
            }),
        },
    })
end

local function tryRebirth(s: ScopeFactory.HudScope, state: HudStateModule.HudState, isBusy: any)
    if peek(isBusy) then
        return
    end
    local rebirths = peek(state.rebirths) or 0
    local cost = RebirthLogic.cost(rebirths)
    local coins = peek(state.coins) or 0
    if coins < cost then
        SoundManager.play("buy_fail")
        Notification.show({
            text = ("Не хватает %d монет для ребёрта"):format(cost - coins),
            icon = "💠",
            color = Color3.fromRGB(255, 140, 60),
            duration = 2.5,
        })
        return
    end

    -- Открываем confirm-модал. Сам Net:Invoke происходит ТОЛЬКО после
    -- подтверждения (см. opts.confirm).
    local currentMult = peek(state.rebirthMultiplier) or 1
    local nextMult = RebirthLogic.valueMultiplier(rebirths + 1)
    RebirthConfirmModal.show({
        scope = s,
        title = ("Ребёрт #%d"):format(rebirths + 1),
        body = buildBodyText(rebirths, currentMult, nextMult),
        confirmText = ("РЕБЁРТ (%s 💰)"):format(Formatters.shortNumber(cost)),
        cancelText = "ОТМЕНА",
        confirm = function()
            isBusy:set(true)
            local ok, result = pcall(function()
                return Net:Invoke("Rebirth")
            end)
            isBusy:set(false)
            if not ok then
                SoundManager.play("buy_fail")
                Notification.show({
                    text = "Сетевая ошибка ребёрта",
                    icon = "⚠",
                    color = Color3.fromRGB(255, 140, 60),
                    duration = 2.5,
                })
                return
            end
            if typeof(result) == "table" and result.success then
                -- Тост и FX придут через Notify("Rebirth") — здесь
                -- ничего не добавляем, чтобы не было двойного спама.
                return
            end
            if typeof(result) == "table" and result.message then
                SoundManager.play("buy_fail")
                Notification.show({
                    text = result.message,
                    icon = "⚠",
                    color = Color3.fromRGB(255, 140, 60),
                    duration = 2.5,
                })
            end
        end,
    })
end

function RebirthPanel.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    local isBusy = s:Value(false)
    local hovered = s:Value(false)

    -- Computed: текущая стоимость ребёрта (зависит от rebirths).
    local rebirthCost = s:Computed(function(use)
        return RebirthLogic.cost(use(state.rebirths) or 0)
    end)

    local canAfford = s:Computed(function(use)
        return (use(state.coins) or 0) >= use(rebirthCost)
    end)

    return s:New("ScrollingFrame")({
        Name = "Rebirth",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "rebirth"
        end),
        [Children] = {
            s:New("UIPadding")({
                PaddingTop = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
                PaddingBottom = UDim.new(0, 8),
            }),
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 10),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            panelHeader(s, state),
            -- Кнопка REBIRTH. Размер крупный — это «фокус» вкладки.
            s:New("TextButton")({
                Name = "RebirthButton",
                Size = UDim2.new(1, -8, 0, 56),
                BackgroundColor3 = s:Computed(function(use)
                    if use(isBusy) then
                        return C.btnDisabled
                    end
                    if not use(canAfford) then
                        return C.btnDisabled
                    end
                    return use(hovered) and Color3.fromRGB(220, 180, 30) or C.gold
                end),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = s:Computed(function(use)
                    local cost = use(rebirthCost)
                    if not use(canAfford) then
                        local coins = use(state.coins) or 0
                        local deficit = math.max(0, cost - coins)
                        return ("Не хватает %s 💰"):format(Formatters.shortNumber(deficit))
                    end
                    return ("REBIRTH  (%s 💰)"):format(Formatters.shortNumber(cost))
                end),
                TextSize = 18,
                Font = Enum.Font.GothamBlack,
                TextColor3 = s:Computed(function(use)
                    return if use(canAfford) and not use(isBusy)
                        then Color3.fromRGB(40, 25, 0)
                        else C.textMuted
                end),
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
                    s:New("UIStroke")({
                        Color = s:Computed(function(use)
                            return use(canAfford) and Color3.fromRGB(255, 240, 150) or C.btnBorder
                        end),
                        Thickness = 2,
                        Transparency = 0.2,
                    }),
                },
                [OnEvent("MouseEnter")] = function() hovered:set(true) end,
                [OnEvent("MouseLeave")] = function() hovered:set(false) end,
                [OnEvent("Activated")] = function()
                    tryRebirth(s, state, isBusy)
                end,
            }),
            -- Информационная подсказка.
            s:New("TextLabel")({
                Name = "RewardLine",
                Size = UDim2.new(1, -8, 0, 18),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    return RebirthLogic.describeReward(use(state.rebirths) or 0)
                end),
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextColor3 = C.gold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            -- Что сохранится.
            s:New("TextLabel")({
                Size = UDim2.new(1, -8, 0, 18),
                BackgroundTransparency = 1,
                Text = "✓ Сохранится: ребёрты, статистика, рекорд глубины, туториал.",
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(150, 255, 150),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
            }),
            -- Что сбросится.
            s:New("TextLabel")({
                Size = UDim2.new(1, -8, 0, 32),
                BackgroundTransparency = 1,
                Text = "✗ Сбросится: монеты, инвентарь, все апгрейды (включая авто-продажу).",
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(255, 140, 90),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
            }),
            -- Следующий бонус (если есть).
            s:New("TextLabel")({
                Size = UDim2.new(1, -8, 0, 32),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local current = use(state.rebirths) or 0
                    local nextT = RebirthLogic.nextPickaxeBonusThreshold(current)
                    if not nextT then
                        return "⛏ Все бонусы кирки разблокированы (R5/R10/R25)."
                    end
                    local remaining = nextT - current
                    return ("⛏ Следующий бонус кирки: +1 maxLevel на R%d (осталось %d ребёртов)")
                        :format(nextT, remaining)
                end),
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(120, 200, 255),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
            }),
        },
    })
end

return RebirthPanel
