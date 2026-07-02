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
local UiIcon = require(script.Parent.Parent.components.UiIcon)
local PanelScale = require(script.Parent.Parent.PanelScale)
local UiAssets = require(ReplicatedStorage:WaitForChild("shared").data.UiAssets)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text
local tsize = PanelScale.tsize

local RebirthPanel = {}

local function buildBodyText(currentRebirths: number, currentMultiplier: number, nextMultiplier: number): string
    -- RichText. Используется в RebirthConfirmModal: важно, чтобы текст
    -- читался за 1-2 секунды (anti-misclick 0.3с — это floor, игрок всё
    -- равно может ткнуть быстро).
    local invPerRebirth = (Constants.REBIRTH and Constants.REBIRTH.inventorySlotsPerRebirth) or 0
    local lines = {
        ("<b>Текущий ребёрт:</b> #%d → #%d"):format(currentRebirths, currentRebirths + 1),
        ("<b>Множитель к ценам руд:</b> %s → <font color=\"rgb(255,210,50)\">%s</font>"):format(
            RebirthLogic.formatMultiplier(currentMultiplier),
            RebirthLogic.formatMultiplier(nextMultiplier)
        ),
        "",
        "<font color=\"rgb(150,255,150)\">Сохранится:</font> ребёрты, статистика, рекорды глубины, туториал.",
        "<font color=\"rgb(255,140,90)\">Сбросится:</font> монеты, инвентарь, ВСЕ апгрейды, авто-продажа.",
    }
    if invPerRebirth > 0 then
        table.insert(lines, ("<font color=\"rgb(120,200,255)\">Анлок:</font> +%d слотов рюкзака навсегда.")
            :format(invPerRebirth))
    end
    local nextThreshold = RebirthLogic.nextPickaxeBonusThreshold(currentRebirths)
    if nextThreshold then
        local remaining = nextThreshold - currentRebirths
        table.insert(lines, ("<font color=\"rgb(120,200,255)\">Следующий бонус кирки:</font> +1 maxLevel на R%d (осталось %d)")
            :format(nextThreshold, remaining))
    end
    return table.concat(lines, "\n")
end

local function panelHeader(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    return s:New("Frame")({
        Name = "Header",
        Size = UDim2.new(1, -sc(8), 0, sc(78)),
        BackgroundColor3 = C.btnBg,
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
            s:New("UIStroke")({ Color = C.gold, Thickness = sc(1.5), Transparency = 0.4 }),
            UiIcon.titleRow(s, {
                source = "tab_rebirth",
                text = "РЕБЁРТЫ",
                textSize = sc(13),
                font = Enum.Font.GothamBold,
                textColor = C.textLabel,
                size = UDim2.new(0.5, -sc(16), 0, sc(22)),
                position = UDim2.new(0, sc(14), 0, sc(12)),
                iconSize = sc(16),
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.5, -sc(16), 0, sc(30)),
                Position = UDim2.new(0, sc(14), 0, sc(34)),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    return tostring(math.floor(use(state.rebirths) or 0))
                end),
                TextSize = tsize(26),
                Font = Enum.Font.GothamBlack,
                TextColor3 = C.gold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            UiIcon.titleRow(s, {
                source = "icon_sparkle",
                text = "МНОЖИТЕЛЬ К ЦЕНАМ",
                textSize = sc(13),
                font = Enum.Font.GothamBold,
                textColor = C.textLabel,
                size = UDim2.new(0.5, -sc(16), 0, sc(22)),
                position = UDim2.new(0.5, 0, 0, sc(12)),
                iconSize = sc(16),
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.5, -sc(16), 0, sc(30)),
                Position = UDim2.new(0.5, 0, 0, sc(34)),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    local mult = use(state.rebirthMultiplier) or 1
                    return RebirthLogic.formatMultiplier(mult)
                end),
                TextSize = tsize(26),
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
            icon = "tab_rebirth",
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
        confirmText = ("РЕБЁРТ (%s)"):format(Formatters.shortNumber(cost)),
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
                    icon = "icon_warning",
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
                    icon = "icon_warning",
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
        ScrollBarThickness = PanelScale.scrollBar(),
        ScrollBarImageColor3 = C.panelBorder,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = s:Computed(function(use)
            return use(state.activeTab) == "rebirth"
        end),
        [Children] = {
            s:New("UIPadding")({
                PaddingTop = PanelScale.pad(4),
                PaddingLeft = PanelScale.pad(4),
                PaddingRight = PanelScale.pad(4),
                PaddingBottom = PanelScale.pad(8),
            }),
            s:New("UIListLayout")({
                FillDirection = Enum.FillDirection.Vertical,
                Padding = PanelScale.pad(10),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            panelHeader(s, state),
            -- Кнопка REBIRTH. Размер крупный — это «фокус» вкладки.
            s:New("TextButton")({
                Name = "RebirthButton",
                Size = UDim2.new(1, -sc(8), 0, sc(56)),
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
                        return ("Не хватает %s"):format(Formatters.shortNumber(deficit))
                    end
                    return ("REBIRTH  (%s)"):format(Formatters.shortNumber(cost))
                end),
                TextSize = tsize(18),
                Font = Enum.Font.GothamBlack,
                TextColor3 = s:Computed(function(use)
                    return if use(canAfford) and not use(isBusy)
                        then Color3.fromRGB(40, 25, 0)
                        else C.textMuted
                end),
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, sc(8)) }),
                    s:New("UIStroke")({
                        Color = s:Computed(function(use)
                            return use(canAfford) and Color3.fromRGB(255, 240, 150) or C.btnBorder
                        end),
                        Thickness = sc(2),
                        Transparency = 0.2,
                    }),
                    s:New("ImageLabel")({
                        Size = UDim2.fromOffset(sc(16), sc(16)),
                        Position = UDim2.new(0.72, 0, 0.5, -sc(8)),
                        BackgroundTransparency = 1,
                        Image = UiAssets.image("coin"),
                        ScaleType = Enum.ScaleType.Fit,
                        Visible = canAfford,
                        ZIndex = 3,
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
                Size = UDim2.new(1, -sc(8), 0, sc(18)),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    return RebirthLogic.describeReward(use(state.rebirths) or 0)
                end),
                TextSize = text(13),
                Font = Enum.Font.GothamBold,
                TextColor3 = C.gold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            s:New("Frame")({
                Size = UDim2.new(1, -sc(8), 0, sc(18)),
                BackgroundTransparency = 1,
                [Children] = {
                    UiIcon.create(s, {
                        source = "icon_check",
                        size = UDim2.fromOffset(sc(14), sc(14)),
                        position = UDim2.new(0, 0, 0.5, -sc(7)),
                    }),
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -sc(20), 1, 0),
                        Position = UDim2.new(0, sc(20), 0, 0),
                        BackgroundTransparency = 1,
                        Text = "Сохранится: ребёрты, статистика, рекорд глубины, туториал.",
                        TextSize = text(12),
                        Font = Enum.Font.Gotham,
                        TextColor3 = Color3.fromRGB(150, 255, 150),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextWrapped = true,
                    }),
                },
            }),
            -- Что сбросится.
            s:New("Frame")({
                Size = UDim2.new(1, -sc(8), 0, sc(32)),
                BackgroundTransparency = 1,
                [Children] = {
                    UiIcon.create(s, {
                        source = "icon_close",
                        size = UDim2.fromOffset(sc(14), sc(14)),
                        position = UDim2.new(0, 0, 0, sc(2)),
                    }),
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -sc(20), 1, 0),
                        Position = UDim2.new(0, sc(20), 0, 0),
                        BackgroundTransparency = 1,
                        Text = "Сбросится: монеты, инвентарь, все апгрейды (включая авто-продажу).",
                        TextSize = text(12),
                        Font = Enum.Font.Gotham,
                        TextColor3 = Color3.fromRGB(255, 140, 90),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextWrapped = true,
                    }),
                },
            }),
            -- Следующий бонус (если есть).
            s:New("Frame")({
                Size = UDim2.new(1, -sc(8), 0, sc(32)),
                BackgroundTransparency = 1,
                [Children] = {
                    UiIcon.create(s, {
                        source = "upg_pickaxe",
                        size = UDim2.fromOffset(sc(14), sc(14)),
                        position = UDim2.new(0, 0, 0, sc(2)),
                    }),
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -sc(20), 1, 0),
                        Position = UDim2.new(0, sc(20), 0, 0),
                        BackgroundTransparency = 1,
                        Text = s:Computed(function(use)
                            local current = use(state.rebirths) or 0
                            local nextT = RebirthLogic.nextPickaxeBonusThreshold(current)
                            if not nextT then
                                return "Все бонусы кирки разблокированы (R5/R10/R25)."
                            end
                            local remaining = nextT - current
                            return ("Следующий бонус кирки: +1 maxLevel на R%d (осталось %d ребёртов)")
                                :format(nextT, remaining)
                        end),
                        TextSize = text(12),
                        Font = Enum.Font.Gotham,
                        TextColor3 = Color3.fromRGB(120, 200, 255),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextWrapped = true,
                    }),
                },
            }),
        },
    })
end

return RebirthPanel
