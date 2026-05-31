--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C

local DEFAULT_LABEL = "ПРОДАТЬ РУДЫ"
local FEEDBACK_SECONDS = 2

local SellButton = {}

function SellButton.create(s: ScopeFactory.HudScope)
    local label = s:Value(DEFAULT_LABEL)
    local busy = s:Value(false)

    local function resetFeedback()
        label:set(DEFAULT_LABEL)
        busy:set(false)
    end

    local function showFeedback(text: string)
        label:set(text)
        task.delay(FEEDBACK_SECONDS, resetFeedback)
    end

    return s:New("TextButton")({
        Size = UDim2.new(0, 240, 0, 24),
        Position = UDim2.new(0, 0, 0, 84),
        BackgroundColor3 = C.sellBg,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Text = label,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextColor3 = C.sellText,
        [Children] = {
            s:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
            s:New("UIStroke")({ Color = C.sellStroke, Thickness = 1, Transparency = 0.3 }),
        },
        [OnEvent("Activated")] = function()
            if peek(busy) then
                return
            end
            busy:set(true)
            label:set("...")

            local result = Net:Invoke("SellOres")
            if typeof(result) ~= "table" then
                showFeedback("Ошибка сети")
                return
            end

            if result.success then
                local earned = result.coinsEarned or 0
                showFeedback("+" .. Formatters.shortNumber(earned) .. " 💰")
            else
                showFeedback(result.message or "Инвентарь пуст")
            end
        end,
    })
end

return SellButton
