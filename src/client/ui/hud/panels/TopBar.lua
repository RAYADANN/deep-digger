--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.Parent.ScopeFactory)
local HudStateModule = require(script.Parent.Parent.HudState)
local theme = require(script.Parent.Parent.theme)
local DepthBar = require(script.Parent.Parent.components.DepthBar)
local ResourceChip = require(script.Parent.Parent.components.ResourceChip)
local SellButton = require(script.Parent.Parent.components.SellButton)
local BoostChip = require(script.Parent.Parent.components.BoostChip)
local StreakChip = require(script.Parent.Parent.components.StreakChip)

local Children = Fusion.Children
local C = theme.C

local TopBar = {}

function TopBar.create(s: ScopeFactory.HudScope, state: HudStateModule.HudState)
    local layerColor = s:Computed(function(use)
        return theme.LAYER_COLORS[use(state.layerId)] or C.depthFill
    end)

    return s:New("Frame")({
        -- Phase 10/12: высота под BoostChip + StreakChip + VIP-chip.
        Size = UDim2.new(0, 240, 0, 168),
        Position = UDim2.new(0, 8, 0, 36),
        BackgroundTransparency = 1,
        [Children] = {
            DepthBar.create(s, state),
            s:New("TextLabel")({
                Size = UDim2.new(1, 0, 0, 18),
                Position = UDim2.new(0, 0, 0, 28),
                BackgroundTransparency = 1,
                Text = s:Computed(function(use)
                    return "▼ " .. use(state.layerName)
                end),
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextColor3 = layerColor,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            ResourceChip.create(s, {
                position = UDim2.new(0, 0, 0, 50),
                bgColor = C.goldBg,
                strokeColor = C.gold,
                prefix = "💰 ",
                textColor = C.gold,
                -- Phase 8: чип читает coinsDisplay (плавный count-up),
                -- но проверки «хватит ли монет» в UpgradesPanel работают по
                -- state.coins (авторитативное, мгновенное).
                amount = state.coinsDisplay,
            }),
            ResourceChip.create(s, {
                position = UDim2.new(0, 122, 0, 50),
                bgColor = C.gemBg,
                strokeColor = C.gem,
                prefix = "💎 ",
                textColor = C.gem,
                amount = state.gems,
            }),
            -- Phase 9: prestige-чип. Появляется только при rebirths > 0,
            -- чтобы новичок не видел пустой «💠 0» — пока ребёрт ещё не
            -- сделан, эта строка должна быть невидима (loop отсутствует).
            s:New("Frame")({
                Name = "RebirthChip",
                Size = UDim2.new(0, 80, 0, 22),
                Position = UDim2.new(0, 0, 0, 84),
                BackgroundColor3 = C.goldBg,
                BackgroundTransparency = 0.1,
                BorderSizePixel = 0,
                Visible = s:Computed(function(use)
                    return (use(state.rebirths) or 0) > 0
                end),
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
                    s:New("UIStroke")({ Color = C.gold, Thickness = 1, Transparency = 0.5 }),
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -8, 1, 0),
                        Position = UDim2.new(0, 4, 0, 0),
                        BackgroundTransparency = 1,
                        Text = s:Computed(function(use)
                            local r = math.floor(use(state.rebirths) or 0)
                            local mult = use(state.rebirthMultiplier) or 1
                            return ("💠 %d  x%.1f"):format(r, mult)
                        end),
                        TextSize = 12,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = C.gold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }),
                },
            }),
            -- Phase 10: BoostChip — Visible только при активном boost'е.
            --   y=112: ниже rebirth-chip (84+22=106) с маленьким gap'ом.
            BoostChip.create(s, state, UDim2.new(0, 0, 0, 112)),
            -- Phase 10: StreakChip — Visible при streak >= 2 (новичок не видит).
            --   x=116: правее BoostChip (108 + 8 gap).
            StreakChip.create(s, state, UDim2.new(0, 116, 0, 112)),
            -- Phase 12: VIP-chip. Visible при владении геймпассом vip.
            s:New("Frame")({
                Name = "VipChip",
                Size = UDim2.new(0, 56, 0, 22),
                Position = UDim2.new(0, 0, 0, 136),
                BackgroundColor3 = C.goldBg,
                BackgroundTransparency = 0.1,
                BorderSizePixel = 0,
                Visible = s:Computed(function(use)
                    local gp = use(state.gamepasses) or {}
                    return gp.vip == true
                end),
                [Children] = {
                    s:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
                    s:New("UIStroke")({ Color = C.gold, Thickness = 1, Transparency = 0.4 }),
                    s:New("TextLabel")({
                        Size = UDim2.new(1, -8, 1, 0),
                        Position = UDim2.new(0, 4, 0, 0),
                        BackgroundTransparency = 1,
                        Text = "👑 VIP",
                        TextSize = 12,
                        Font = Enum.Font.GothamBold,
                        TextColor3 = C.gold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 2,
                    }),
                },
            }),
            SellButton.create(s),
        },
    })
end

return TopBar
