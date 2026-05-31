--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)

local Children = Fusion.Children
local C = theme.C

export type Props = {
    label: string,
    valueText: any,
    valueColor: Color3?,
}

local StatRow = {}

function StatRow.create(s: ScopeFactory.HudScope, props: Props)
    local valueColor = props.valueColor or C.gold
    local textBinding = if typeof(props.valueText) == "string"
        then props.valueText
        else props.valueText

    return s:New("Frame")({
        Size = UDim2.new(1, -8, 0, 36),
        BackgroundColor3 = C.btnBg,
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
            s:New("TextLabel")({
                Size = UDim2.new(0.6, 0, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = props.label,
                TextSize = 13,
                Font = Enum.Font.Gotham,
                TextColor3 = C.textLabel,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(0.4, -10, 1, 0),
                Position = UDim2.new(0.6, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = textBinding,
                TextSize = 15,
                Font = Enum.Font.GothamBold,
                TextColor3 = valueColor,
                TextXAlignment = Enum.TextXAlignment.Right,
            }),
        },
    })
end

return StatRow
