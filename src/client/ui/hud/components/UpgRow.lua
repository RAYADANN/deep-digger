--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local UpgradeMeta = require(script.Parent.Parent.UpgradeMeta)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C

local FEEDBACK_SECONDS = 2

export type Props = {
    upgradeId: string,
    level: number,
    maxLevel: number,
    cost: number,
    canAfford: boolean,
    canAffordNow: () -> boolean,
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

    local function tryPurchase()
        if peek(buyBusy) or isMax then
            return
        end
        if not props.canAffordNow() then
            buyHint:set("💰?")
            task.delay(FEEDBACK_SECONDS, function()
                buyHint:set("")
            end)
            return
        end

        buyBusy:set(true)
        buyHint:set("...")

        local ok, result = pcall(props.onBuy)
        if not ok then
            buyHint:set("Ошибка")
            buyBusy:set(false)
            return
        end

        if typeof(result) == "table" and result.success then
            buyHint:set("✓")
        elseif typeof(result) == "table" and result.message then
            buyHint:set(result.message)
        else
            buyHint:set("Ошибка")
        end

        task.delay(FEEDBACK_SECONDS, function()
            buyHint:set("")
            buyBusy:set(false)
        end)
    end

    return s:New("Frame")({
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
end

return UpgRow
