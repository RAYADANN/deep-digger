--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)

local Children = Fusion.Children
local C = theme.C

export type Props = {
    position: UDim2,
    bgColor: Color3,
    strokeColor: Color3,
    prefix: string,
    textColor: Color3,
    amount: Fusion.Value<number>,
}

local ResourceChip = {}

function ResourceChip.create(s: ScopeFactory.HudScope, props: Props)
    return s:New("Frame")({
        Size = UDim2.new(0, 114, 0, 28),
        Position = props.position,
        BackgroundColor3 = props.bgColor,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
            s:New("UIStroke")({ Color = props.strokeColor, Thickness = 1, Transparency = 0.5 }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -8, 1, 0),
                Position = UDim2.new(0, 4, 0, 0),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    return props.prefix .. Formatters.shortNumber(use(props.amount))
                end),
                TextSize = 14,
                Font = Enum.Font.GothamBold,
                TextColor3 = props.textColor,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        },
    })
end

return ResourceChip
