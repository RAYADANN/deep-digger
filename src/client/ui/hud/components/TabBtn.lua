--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C

export type Props = {
    icon: string,
    label: string,
    tabId: string,
    activeTab: any,
    panelOpen: any,
}

local TabBtn = {}

function TabBtn.create(s: ScopeFactory.HudScope, props: Props)
    local isActive = s:Computed(function(use)
        return use(props.panelOpen) and use(props.activeTab) == props.tabId
    end)

    return s:New("TextButton")({
        -- Phase 8: Name="Tab_<id>" — TutorialArrow находит кнопку по этому
        -- имени, чтобы навести стрелку («Открой инвентарь» / «Открой
        -- апгрейды»). Не ломает существующий UI, имя не отображается.
        Name = "Tab_" .. props.tabId,
        Size = UDim2.new(0, 58, 0, 64),
        BackgroundColor3 = s:Computed(function(use)
            return use(isActive) and C.tabActive or C.tabInactive
        end),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Text = "",
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
            s:New("UIStroke")({
                Color = s:Computed(function(use)
                    return use(isActive) and C.gem or C.tabBorder
                end),
                Thickness = 1.5,
                Transparency = 0.3,
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, 34),
                Position = UDim2.new(0, 0, 0, 6),
                BackgroundTransparency = 1,
                Text = props.icon,
                TextScaled = true,
                Font = Enum.Font.GothamBold,
                TextColor3 = s:Computed(function(use)
                    return use(isActive) and C.white or C.textMuted
                end),
            }),
            s:New("TextLabel")({
                Size = UDim2.new(1, -4, 0, 14),
                Position = UDim2.new(0, 2, 0, 42),
                BackgroundTransparency = 1,
                Text = props.label,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                TextColor3 = s:Computed(function(use)
                    return use(isActive) and C.gem or C.textMuted
                end),
                TextXAlignment = Enum.TextXAlignment.Center,
            }),
        },
        [OnEvent("Activated")] = function()
            if peek(props.panelOpen) and peek(props.activeTab) == props.tabId then
                props.panelOpen:set(false)
            else
                props.activeTab:set(props.tabId)
                props.panelOpen:set(true)
            end
        end,
    })
end

return TabBtn
