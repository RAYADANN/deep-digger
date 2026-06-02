--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)
local Net = require(ReplicatedStorage:WaitForChild("Packages").Net)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local theme = require(script.Parent.Parent.theme)
local Formatters = require(script.Parent.Parent.formatters)
local SoundManager = require(script.Parent.Parent.Parent.Parent.core.SoundManager)
local Notification = require(script.Parent.Parent.Parent.Notification)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local peek = Fusion.peek
local C = theme.C

local DEFAULT_LABEL = "ПРОДАТЬ РУДЫ"
local FEEDBACK_SECONDS = 2

-- Phase 8: цвет тоста при ошибке. Пустой инвентарь — нейтральный серый,
-- сетевые ошибки — оранжевый (нестандартная ситуация).
local EMPTY_COLOR = Color3.fromRGB(180, 180, 195)
local ERROR_COLOR = Color3.fromRGB(255, 140, 60)

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
        -- Phase 8: Name — конвенция для TutorialArrow, чтобы найти кнопку
        -- через `gui:FindFirstChild("SellButton", true)`.
        Name = "SellButton",
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
                Notification.show({
                    text = "Сетевая ошибка продажи",
                    icon = "⚠",
                    color = ERROR_COLOR,
                    duration = 2.5,
                })
                showFeedback("Ошибка сети")
                return
            end

            if result.success then
                local earned = result.coinsEarned or 0
                SoundManager.play("sell_success")
                showFeedback("+" .. Formatters.shortNumber(earned) .. " 💰")
            else
                SoundManager.play("sell_fail")
                -- Phase 8: вместо silent inline-фидбека показываем явный тост
                -- в центре экрана, чтобы игрок (особенно новичок) сразу видел
                -- причину отказа.
                local msg = result.message or "Инвентарь пуст. Накопайте руды!"
                Notification.show({
                    text = msg,
                    icon = "📭",
                    color = EMPTY_COLOR,
                    duration = 2.5,
                })
                showFeedback(msg)
            end
        end,
    })
end

return SellButton
