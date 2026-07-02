--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local Children = Fusion.Children
local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local UiIcon = require(script.Parent.UiIcon)
local PanelScale = require(script.Parent.Parent.PanelScale)

local C = theme.C
-- Десктоп: геометрия ×2 синхронно с ×2 текстом (gsc). Phone/tablet без изменений.
local sc = PanelScale.gsc
local text = PanelScale.text

export type Props = {
    label: string,
    iconSource: string?,
    valueText: any,
    valueColor: Color3?,
}

local StatRow = {}

function StatRow.create(s: ScopeFactory.HudScope, props: Props)
    local valueColor = props.valueColor or C.gold
    local textBinding = if typeof(props.valueText) == "string"
        then props.valueText
        else props.valueText

    local labelChildren: { any } = {}
    if props.iconSource then
        labelChildren = {
            UiIcon.create(s, {
                source = props.iconSource,
                size = UDim2.fromOffset(sc(16), sc(16)),
                position = UDim2.new(0, 0, 0.5, -sc(8)),
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -sc(22), 1, 0),
                Position = UDim2.new(0, sc(22), 0, 0),
                BackgroundTransparency = 1,
                Text = props.label,
                TextSize = text(14),
                Font = Enum.Font.Gotham,
                TextColor3 = C.textLabel,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),
        }
    else
        labelChildren = {
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = props.label,
                TextSize = text(14),
                Font = Enum.Font.Gotham,
                TextColor3 = C.textLabel,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),
        }
    end

    return s:New("Frame")({
        Size = UDim2.new(1, -sc(8), 0, sc(36)),
        BackgroundColor3 = C.btnBg,
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, sc(6)) }),
            s:New("Frame")({
                Size = UDim2.new(0.6, 0, 1, 0),
                Position = UDim2.new(0, sc(10), 0, 0),
                BackgroundTransparency = 1,
                [Children] = labelChildren,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.4, -sc(10), 1, 0),
                Position = UDim2.new(0.6, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = textBinding,
                TextSize = text(16),
                Font = Enum.Font.GothamBold,
                TextColor3 = valueColor,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),
        },
    })
end

return StatRow
