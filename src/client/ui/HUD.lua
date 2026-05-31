--!strict
-- HUD.lua — главный HUD Deep Digger (Fusion 0.3, scoped)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages.Fusion)
local scope = Fusion.scoped(Fusion)
local OnEvent = Fusion.OnEvent
local Children = Fusion.Children

-- ============================================================
-- Цвета Terraria
-- ============================================================
local C = {
    panelBg = Color3.fromRGB(42,30,18), panelBorder = Color3.fromRGB(101,72,36),
    panelInner = Color3.fromRGB(58,42,24), gold = Color3.fromRGB(255,210,50),
    gem = Color3.fromRGB(100,200,255), depthText = Color3.fromRGB(200,220,180),
    layerText = Color3.fromRGB(240,200,120), textMain = Color3.fromRGB(255,245,210),
    textMuted = Color3.fromRGB(160,140,100),
    common = Color3.fromRGB(200,200,200), uncommon = Color3.fromRGB(100,220,100),
    rare = Color3.fromRGB(80,150,255), epic = Color3.fromRGB(190,80,230),
    legendary = Color3.fromRGB(255,165,0), mythic = Color3.fromRGB(255,60,60),
    upgradeBg = Color3.fromRGB(35,25,15), barBg = Color3.fromRGB(25,18,10),
    barFill = Color3.fromRGB(160,100,40), barGlow = Color3.fromRGB(220,160,60),
}
local RAR_C = {common=C.common, uncommon=C.uncommon, rare=C.rare, epic=C.epic, legendary=C.legendary, mythic=C.mythic}
local ORE_ICO = {dirt="⬛", pebble="⬜", clay="🟫", coal="🪨", root="🌿", fossil="🦴", stone="🪨", copper="🟧", iron="⚙️", silver="🔘", gold="🟡", sapphire="💎", ruby="🔴"}
local UP_N = {pickaxe="⛏ Кирка", speed="⚡ Скорость", fortune="🍀 Удача", inventory="🎒 Рюкзак", crit="💥 Крит", multiSell="💰 Продажа", autoSell="🔄 Авто"}

local function sn(n)
    if n>=1e9 then return ("%.1fB"):format(n/1e9)
    elseif n>=1e6 then return ("%.1fM"):format(n/1e6)
    elseif n>=1e3 then return ("%.1fK"):format(n/1e3)
    else return tostring(math.floor(n)) end
end

local function uc(base, exp, lv) return math.floor(base * (exp ^ (lv - 1))) end

local E={sapphire=true, ruby=true, emerald=true, diamond=true, shadow_gem=true, galaxy_opal=true}
local R={fossil=true, silver=true, gold=true, topaz=true, moonstone=true, spirit_shard=true, star_fragment=true}
local U={coal=true, iron=true, malachite=true, blood_opal=true, amethyst=true, nebula_crystal=true}
local L={fire_opal=true, astralite=true}; local M={void_crystal=true}
local function rar(oid)
    if M[oid] then return "mythic" elseif L[oid] then return "legendary"
    elseif E[oid] then return "epic" elseif R[oid] then return "rare"
    elseif U[oid] then return "uncommon" else return "common" end
end

local function InvSlot(oreId, cnt)
    local r = rar(oreId); local rc = RAR_C[r] or C.common; local ic = ORE_ICO[oreId] or "❓"
    local hv = scope:Value(false)
    return scope:New("Frame")({
        Size = UDim2.new(0,52,0,52),
        BackgroundColor3 = scope:Computed(function(u) return u(hv) and C.panelBorder or C.upgradeBg end),
        BorderSizePixel = 0,
        [Children] = {
            scope:New("UICorner")({CornerRadius=UDim.new(0,6)}),
            scope:New("UIStroke")({Color=rc, Thickness=1.5, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}),
            scope:New("TextLabel")({Size=UDim2.new(1,0,0.65,0), Position=UDim2.new(0,0,0,4), BackgroundTransparency=1, Text=ic, TextScaled=true, Font=Enum.Font.GothamBold, TextColor3=C.textMain}),
            scope:New("TextLabel")({Size=UDim2.new(1,-4,0.3,0), Position=UDim2.new(0,0,0.68,0), BackgroundTransparency=1, Text=sn(cnt), TextSize=11, Font=Enum.Font.GothamBold, TextColor3=rc, TextXAlignment=Enum.TextXAlignment.Center}),
            scope:New("TextButton")({Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="", ZIndex=5, [OnEvent("MouseEnter")]=function() hv:set(true) end, [OnEvent("MouseLeave")]=function() hv:set(false) end}),
        },
    })
end

local function UpgBtn(props)
    local can = props.coins >= props.cost; local maxed = props.level >= props.maxLevel
    return scope:New("Frame")({
        Size = UDim2.new(0,110,0,56), BackgroundColor3 = C.upgradeBg, BorderSizePixel = 0,
        [Children] = {
            scope:New("UICorner")({CornerRadius=UDim.new(0,6)}),
            scope:New("UIStroke")({Color=maxed and C.textMuted or can and C.panelBorder or Color3.fromRGB(60,40,20), Thickness=1.5}),
            scope:New("TextLabel")({Size=UDim2.new(1,-8,0,18), Position=UDim2.new(0,4,0,4), BackgroundTransparency=1, Text=UP_N[props.upgradeId]or props.upgradeId, TextSize=11, Font=Enum.Font.GothamBold, TextColor3=C.layerText, TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd}),
            scope:New("TextLabel")({Size=UDim2.new(0.5,-4,0,14), Position=UDim2.new(0,4,0,22), BackgroundTransparency=1, Text=maxed and "МАКС" or ("Lv."..props.level), TextSize=10, Font=Enum.Font.Gotham, TextColor3=maxed and C.gold or C.textMuted, TextXAlignment=Enum.TextXAlignment.Left}),
            scope:New("TextLabel")({Size=UDim2.new(1,-8,0,14), Position=UDim2.new(0,4,0,37), BackgroundTransparency=1, Text=maxed and "" or ("💰 "..sn(props.cost)), TextSize=11, Font=Enum.Font.GothamBold, TextColor3=maxed and C.textMuted or can and C.gold or C.textMuted, TextXAlignment=Enum.TextXAlignment.Left}),
            scope:New("TextButton")({Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="", ZIndex=5, [OnEvent("Activated")]=function() if not maxed and can then props.onBuy() end end}),
        },
    })
end

-- ============================================================
-- HUD
-- ============================================================
local HUD = {}; HUD.__index = HUD
function HUD.new(p)
    local self = setmetatable({}, HUD)
    self._c = scope:Value(0); self._g = scope:Value(0); self._d = scope:Value(0)
    self._l = scope:Value("Dirt Layer"); self._mx = scope:Value(1500)
    self._inv = scope:Value({}::{{oreId:string,count:number}})
    self._up = scope:Value({}::{[string]:{level:number,maxLevel:number}})
    local dp = scope:Computed(function(u) return math.clamp(u(self._d)/math.max(u(self._mx),1),0,1) end)
    local ta = scope:Value("inventory")

    self._gui = scope:New("ScreenGui")({
        Name="DeepDiggerHUD", ResetOnSpawn=false, DisplayOrder=10, Parent=p:WaitForChild("PlayerGui"),
        [Children] = {
            -- TopBar
            scope:New("Frame")({
                Size=UDim2.new(0,420,0,54), Position=UDim2.new(0.5,0,0,10), AnchorPoint=Vector2.new(0.5,0),
                BackgroundColor3=C.panelBg, BorderSizePixel=0,
                [Children] = {
                    scope:New("UICorner")({CornerRadius=UDim.new(0,8)}),
                    scope:New("UIStroke")({Color=C.panelBorder, Thickness=2}),
                    scope:New("Frame")({Size=UDim2.new(0,110,1,-8), Position=UDim2.new(0,8,0,4), BackgroundTransparency=1,
                        [Children] = {
                            scope:New("TextLabel")({Size=UDim2.new(1,0,0.45,0), BackgroundTransparency=1, Text="💰 МОНЕТЫ", TextSize=10, Font=Enum.Font.GothamBold, TextColor3=C.textMuted, TextXAlignment=Enum.TextXAlignment.Left}),
                            scope:New("TextLabel")({Size=UDim2.new(1,0,0.55,0), Position=UDim2.new(0,0,0.45,0), BackgroundTransparency=1, Text=scope:Computed(function(u) return sn(u(self._c)) end), TextSize=20, Font=Enum.Font.GothamBlack, TextColor3=C.gold, TextXAlignment=Enum.TextXAlignment.Left}),
                        },
                    }),
                    scope:New("Frame")({Size=UDim2.new(0,1,0.7,0), Position=UDim2.new(0,122,0.15,0), BackgroundColor3=C.panelBorder, BorderSizePixel=0}),
                    scope:New("Frame")({Size=UDim2.new(0,90,1,-8), Position=UDim2.new(0,130,0,4), BackgroundTransparency=1,
                        [Children] = {
                            scope:New("TextLabel")({Size=UDim2.new(1,0,0.45,0), BackgroundTransparency=1, Text="💎 ГЕМЫ", TextSize=10, Font=Enum.Font.GothamBold, TextColor3=C.textMuted, TextXAlignment=Enum.TextXAlignment.Left}),
                            scope:New("TextLabel")({Size=UDim2.new(1,0,0.55,0), Position=UDim2.new(0,0,0.45,0), BackgroundTransparency=1, Text=scope:Computed(function(u) return sn(u(self._g)) end), TextSize=20, Font=Enum.Font.GothamBlack, TextColor3=C.gem, TextXAlignment=Enum.TextXAlignment.Left}),
                        },
                    }),
                    scope:New("Frame")({Size=UDim2.new(0,1,0.7,0), Position=UDim2.new(0,225,0.15,0), BackgroundColor3=C.panelBorder, BorderSizePixel=0}),
                    scope:New("Frame")({Size=UDim2.new(0,180,1,-8), Position=UDim2.new(0,232,0,4), BackgroundTransparency=1,
                        [Children] = {
                            scope:New("TextLabel")({Size=UDim2.new(1,0,0,14), BackgroundTransparency=1, Text=scope:Computed(function(u) return u(self._l) end), TextSize=11, Font=Enum.Font.GothamBold, TextColor3=C.layerText, TextXAlignment=Enum.TextXAlignment.Left}),
                            scope:New("TextLabel")({Size=UDim2.new(0.6,0,0,20), Position=UDim2.new(0,0,0,14), BackgroundTransparency=1, Text=scope:Computed(function(u) return "⬇ "..math.floor(u(self._d)).."м" end), TextSize=18, Font=Enum.Font.GothamBlack, TextColor3=C.depthText, TextXAlignment=Enum.TextXAlignment.Left}),
                            scope:New("Frame")({Size=UDim2.new(1,0,0,5), Position=UDim2.new(0,0,1,-5), BackgroundColor3=C.barBg, BorderSizePixel=0, ClipsDescendants=true,
                                [Children] = {
                                    scope:New("UICorner")({CornerRadius=UDim.new(1,0)}),
                                    scope:New("Frame")({Size=scope:Computed(function(u) return UDim2.new(u(dp),0,1,0) end), BackgroundColor3=C.barFill, BorderSizePixel=0,
                                        [Children] = {
                                            scope:New("UICorner")({CornerRadius=UDim.new(1,0)}),
                                            scope:New("UIGradient")({Color=ColorSequence.new({ColorSequenceKeypoint.new(0,C.barFill),ColorSequenceKeypoint.new(1,C.barGlow)})}),
                                        },
                                    }),
                                },
                            }),
                        },
                    }),
                },
            }),
            -- BottomBar
            scope:New("Frame")({
                Size=UDim2.new(0,560,0,130), Position=UDim2.new(0.5,0,1,-10), AnchorPoint=Vector2.new(0.5,1),
                BackgroundColor3=C.panelBg, BorderSizePixel=0,
                [Children]={
                    scope:New("UICorner")({CornerRadius=UDim.new(0,8)}), scope:New("UIStroke")({Color=C.panelBorder,Thickness=2}),
                    -- Табы
                    scope:New("Frame")({Size=UDim2.new(1,-8,0,30), Position=UDim2.new(0,4,0,4), BackgroundTransparency=1,
                        [Children]={
                            scope:New("UIListLayout")({FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,4)}),
                            scope:New("TextButton")({Size=UDim2.new(0,110,0,28),
                                BackgroundColor3=scope:Computed(function(u) return u(ta)=="inventory" and C.panelBorder or C.panelBg end),
                                BorderSizePixel=0, Text="🎒 Инвентарь", TextSize=12, Font=Enum.Font.GothamBold,
                                TextColor3=scope:Computed(function(u) return u(ta)=="inventory" and C.gold or C.textMuted end),
                                [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,4)})},
                                [OnEvent("Activated")]=function() ta:set("inventory") end,
                            }),
                            scope:New("TextButton")({Size=UDim2.new(0,110,0,28),
                                BackgroundColor3=scope:Computed(function(u) return u(ta)=="upgrades" and C.panelBorder or C.panelBg end),
                                BorderSizePixel=0, Text="⚒ Апгрейды", TextSize=12, Font=Enum.Font.GothamBold,
                                TextColor3=scope:Computed(function(u) return u(ta)=="upgrades" and C.gold or C.textMuted end),
                                [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,4)})},
                                [OnEvent("Activated")]=function() ta:set("upgrades") end,
                            }),
                        },
                    }),
                    -- Инвентарь
                    scope:New("ScrollingFrame")({
                        Name="InventoryContent", Size=UDim2.new(1,-8,0,82), Position=UDim2.new(0,4,0,38),
                        BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
                        ScrollBarImageColor3=C.panelBorder, CanvasSize=UDim2.new(0,0,0,0),
                        AutomaticCanvasSize=Enum.AutomaticSize.X,
                        Visible=scope:Computed(function(u) return u(ta)=="inventory" end),
                        [Children]={
                            scope:New("UIListLayout")({FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),VerticalAlignment=Enum.VerticalAlignment.Center}),
                            scope:New("UIPadding")({PaddingLeft=UDim.new(0,4),PaddingTop=UDim.new(0,4)}),
                            scope:Computed(function(u)
                                local slots={}; for _,item in ipairs(u(self._inv)) do slots[#slots+1]=InvSlot(item.oreId,item.count) end; return slots
                            end),
                        },
                    }),
                    -- Апгрейды
                    scope:New("ScrollingFrame")({
                        Name="UpgradesContent", Size=UDim2.new(1,-8,0,82), Position=UDim2.new(0,4,0,38),
                        BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4,
                        ScrollBarImageColor3=C.panelBorder, CanvasSize=UDim2.new(0,0,0,0),
                        AutomaticCanvasSize=Enum.AutomaticSize.X,
                        Visible=scope:Computed(function(u) return u(ta)=="upgrades" end),
                        [Children]={
                            scope:New("UIListLayout")({FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),VerticalAlignment=Enum.VerticalAlignment.Center}),
                            scope:New("UIPadding")({PaddingLeft=UDim.new(0,4),PaddingTop=UDim.new(0,4)}),
                            scope:Computed(function(u)
                                local btns={}; local ups=u(self._up); local coins=u(self._c)
                                local Constants=require(ReplicatedStorage.shared.constants)
                                for uid,data in pairs(ups) do
                                    local cfg=Constants.UPGRADES[uid]
                                    if cfg then
                                        local cost=uc(cfg.baseCost,cfg.exponent or 1.5,data.level)
                                        btns[#btns+1]=UpgBtn({upgradeId=uid, level=data.level, maxLevel=cfg.maxLevel, cost=cost, coins=coins, onBuy=function()
                                            require(Packages.Net):Invoke("BuyUpgrade", uid)
                                        end})
                                    end
                                end; return btns
                            end),
                        },
                    }),
                },
            }),
        },
    })
    return self
end

function HUD:setCoins(n) self._c:set(n) end
function HUD:setGems(n) self._g:set(n) end
function HUD:setDepth(d, l) self._d:set(d); if l then self._l:set(l) end end
function HUD:setInventory(inv)
    local ro={mythic=1,legendary=2,epic=3,rare=4,uncommon=5,common=6}
    table.sort(inv, function(a,b) return (ro[rar(a.oreId)] or 6) < (ro[rar(b.oreId)] or 6) end)
    self._inv:set(inv)
end
function HUD:setUpgrades(pd)
    local r={}; for _,id in ipairs({"pickaxe","speed","fortune","inventory","crit","multiSell"}) do r[id]={level=pd[id.."Level"]or 1, maxLevel=100} end
    if pd.autoSellUnlocked then r["autoSell"]={level=1,maxLevel=1} end; self._up:set(r)
end
function HUD:destroy() if self._gui then self._gui:Destroy() end end
return HUD
