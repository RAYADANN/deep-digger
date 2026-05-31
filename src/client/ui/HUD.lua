-- HUD.lua — Deep Digger HUD (Fusion 0.3 scoped, RPG стиль)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Fusion = require(Packages.Fusion)
local Net = require(Packages.Net)
local Constants = require(ReplicatedStorage:WaitForChild("shared").constants)

local scope = Fusion.scoped(Fusion)
local OnEvent = Fusion.OnEvent
local Children = Fusion.Children
local TweenService = game:GetService("TweenService")

-- Цвета
local C = {
    panelBg=Color3.fromRGB(18,18,28), panelBorder=Color3.fromRGB(60,60,90),
    panelInner=Color3.fromRGB(25,25,40), panelHeader=Color3.fromRGB(30,30,50),
    depthFill=Color3.fromRGB(60,140,220), depthBg=Color3.fromRGB(15,30,60),
    gold=Color3.fromRGB(255,210,50), goldBg=Color3.fromRGB(50,40,10),
    gem=Color3.fromRGB(80,200,255), gemBg=Color3.fromRGB(10,35,55),
    textMain=Color3.fromRGB(240,235,220), textMuted=Color3.fromRGB(130,125,145),
    textLabel=Color3.fromRGB(160,155,180), white=Color3.fromRGB(255,255,255),
    common=Color3.fromRGB(180,180,180), uncommon=Color3.fromRGB(80,210,80),
    rare=Color3.fromRGB(60,140,255), epic=Color3.fromRGB(180,60,220),
    legendary=Color3.fromRGB(255,160,0), mythic=Color3.fromRGB(255,50,50),
    btnBg=Color3.fromRGB(35,35,55), btnBorder=Color3.fromRGB(70,70,105),
    btnHover=Color3.fromRGB(50,50,75), btnDisabled=Color3.fromRGB(25,25,38),
    tabActive=Color3.fromRGB(55,55,85), tabInactive=Color3.fromRGB(28,28,45),
    tabBorder=Color3.fromRGB(80,80,120),
}
local ORE_RARITY = {dirt="common",pebble="common",clay="common",root="common",coal="uncommon",stone="common",copper="common",iron="uncommon",fossil="rare",silver="uncommon",gold="uncommon",sapphire="rare",ruby="rare",limestone="common",marble_chip="common",malachite="uncommon",topaz="rare",emerald="epic",crimson_rock="common",redstone="common",blood_opal="uncommon",oil_deposit="uncommon",diamond="epic",fire_opal="legendary",marble="common",white_quartz="common",calcite="uncommon",moonstone="rare",astralite="legendary",obsidian="common",dark_quartz="common",amethyst="uncommon",spirit_shard="rare",shadow_gem="epic",void_stone="common",nebula_crystal="uncommon",star_fragment="rare",galaxy_opal="epic",void_crystal="mythic"}
local ORE_ICON = {dirt="🟫",pebble="⬜",clay="🟤",coal="⬛",root="🌿",fossil="🦴",stone="🪨",copper="🟧",iron="⚙",silver="⬡",gold="★",sapphire="◆",ruby="♦",limestone="□",marble_chip="◇",malachite="◈",topaz="◉",emerald="◆",crimson_rock="▪",redstone="●",blood_opal="◎",oil_deposit="▼",diamond="◆",fire_opal="◈",marble="□",white_quartz="◇",calcite="○",moonstone="◉",astralite="✦",obsidian="■",dark_quartz="◆",amethyst="◈",spirit_shard="✦",shadow_gem="◆",void_stone="▪",nebula_crystal="✦",star_fragment="★",galaxy_opal="◎",void_crystal="✦"}
local UPGRADE_NAMES = {pickaxe="Кирка",speed="Скорость",fortune="Удача",inventory="Рюкзак",crit="Крит",multiSell="Продажа",autoSell="Авто-продажа"}
local UPGRADE_DESC = {pickaxe="Увеличивает урон по блокам",speed="Ускоряет добычу",fortune="Шанс редких руд",inventory="Слоты инвентаря",crit="Шанс крит. удара",multiSell="Бонус к продаже",autoSell="Авто-продажа руд"}
local UPGRADE_ORDER = {"pickaxe","speed","fortune","inventory","crit","multiSell","autoSell"}
local LAYER_COLORS = {dirt=Color3.fromRGB(180,130,70),stone=Color3.fromRGB(160,160,175),limestone=Color3.fromRGB(220,200,160),crimson=Color3.fromRGB(220,60,60),marble=Color3.fromRGB(210,210,230),obsidian=Color3.fromRGB(140,80,220),void=Color3.fromRGB(80,40,160)}
local RARITY_COLOR = {common=C.common,uncommon=C.uncommon,rare=C.rare,epic=C.epic,legendary=C.legendary,mythic=C.mythic}
local UPGRADE_COLORS = {pickaxe=Color3.fromRGB(220,80,80),speed=Color3.fromRGB(80,200,80),fortune=Color3.fromRGB(80,160,255),inventory=Color3.fromRGB(180,80,220),crit=Color3.fromRGB(255,160,0),multiSell=Color3.fromRGB(255,210,50),autoSell=Color3.fromRGB(80,220,200)}

local function sn(n) if n>=1e9 then return ("%.1fB"):format(n/1e9) elseif n>=1e6 then return ("%.1fM"):format(n/1e6) elseif n>=1e3 then return ("%.1fK"):format(n/1e3) else return tostring(math.floor(n)) end end
local function uc(id,lv) local cfg=Constants.UPGRADES[id]; if not cfg then return 0 end; return math.floor(cfg.baseCost*((cfg.exponent or 1.5)^(lv-1))) end
local RARITY_ORDER = {mythic=1,legendary=2,epic=3,rare=4,uncommon=5,common=6}

-- Инвентарь слот
local function InvSlot(oreId,cnt)
    local r=ORE_RARITY[oreId]or"common"; local rc=RARITY_COLOR[r]or C.common; local ic=ORE_ICON[oreId]or"?"
    local hv=scope:Value(false)
    return scope:New("Frame")({
        Size=UDim2.new(0,58,0,68),
        BackgroundColor3=scope:Computed(function(u) return u(hv)and C.btnHover or C.btnBg end),
        BorderSizePixel=0,
        [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,6)}),
            scope:New("UIStroke")({Color=rc,Thickness=1.5,Transparency=0.2}),
            scope:New("Frame")({Size=UDim2.new(1,0,0,3),BackgroundColor3=rc,BorderSizePixel=0,[Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,3)})}}),
            scope:New("TextLabel")({Size=UDim2.new(1,0,0,36),Position=UDim2.new(0,0,0,8),BackgroundTransparency=1,Text=ic,TextScaled=true,Font=Enum.Font.GothamBold,TextColor3=rc,ZIndex=2}),
            scope:New("TextLabel")({Size=UDim2.new(1,-4,0,14),Position=UDim2.new(0,2,0,44),BackgroundTransparency=1,Text=oreId:gsub("_"," "):sub(1,10),TextSize=9,Font=Enum.Font.Gotham,TextColor3=C.textMuted,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=2}),
            scope:New("TextLabel")({Size=UDim2.new(1,-4,0,14),Position=UDim2.new(0,2,0,54),BackgroundTransparency=1,Text="x"..sn(cnt),TextSize=11,Font=Enum.Font.GothamBold,TextColor3=rc,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=2}),
            scope:New("TextButton")({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=5,[OnEvent("MouseEnter")]=function() hv:set(true) end,[OnEvent("MouseLeave")]=function() hv:set(false) end}),
        },
    })
end

-- Апгрейд строка
local function UpgRow(props)
    local isMax=props.level>=props.maxLevel; local ac=props.upgradeId
    local accentBar=UPGRADE_COLORS[ac]or C.rare
    local hv=scope:Value(false)
    return scope:New("Frame")({
        Size=UDim2.new(1,-8,0,54),
        BackgroundColor3=scope:Computed(function(u) return u(hv)and C.btnHover or C.btnBg end),BorderSizePixel=0,
        [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,6)}),
            scope:New("UIStroke")({Color=C.btnBorder,Thickness=1,Transparency=0.5}),
            scope:New("Frame")({Size=UDim2.new(0,4,1,-8),Position=UDim2.new(0,4,0,4),BackgroundColor3=accentBar,BorderSizePixel=0,[Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,2)})}}),
            scope:New("TextLabel")({Size=UDim2.new(0.55,0,0,22),Position=UDim2.new(0,16,0,6),BackgroundTransparency=1,Text=UPGRADE_NAMES[ac]or ac,TextSize=16,Font=Enum.Font.GothamBold,TextColor3=accentBar,TextXAlignment=Enum.TextXAlignment.Left}),
            scope:New("TextLabel")({Size=UDim2.new(0.55,0,0,14),Position=UDim2.new(0,16,0,28),BackgroundTransparency=1,Text=UPGRADE_DESC[ac]or"",TextSize=11,Font=Enum.Font.Gotham,TextColor3=C.textMuted,TextXAlignment=Enum.TextXAlignment.Left}),
            scope:New("TextLabel")({Size=UDim2.new(0.2,0,0,22),Position=UDim2.new(0.58,0,0,6),BackgroundTransparency=1,Text=isMax and"МАКС"or tostring(props.level),TextSize=18,Font=Enum.Font.GothamBlack,TextColor3=isMax and C.gold or C.textMain,TextXAlignment=Enum.TextXAlignment.Right}),
            scope:New("TextLabel")({Size=UDim2.new(0.2,0,0,14),Position=UDim2.new(0.58,0,0,30),BackgroundTransparency=1,Text=isMax and""or("💰 "..sn(props.cost)),TextSize=11,Font=Enum.Font.Gotham,TextColor3=props.canAfford and C.gold or C.textMuted,TextXAlignment=Enum.TextXAlignment.Right}),
            scope:New("TextButton")({Size=UDim2.new(0,36,0,36),Position=UDim2.new(1,-44,0.5,-18),
                BackgroundColor3=isMax and C.btnDisabled or props.canAfford and accentBar or C.btnDisabled,
                BorderSizePixel=0,Text=isMax and"✓"or"+",TextSize=20,Font=Enum.Font.GothamBlack,TextColor3=C.white,
                [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,6)}),scope:New("UIStroke")({Color=props.canAfford and not isMax and C.white or C.btnBorder,Thickness=1.5,Transparency=0.5})},
                [OnEvent("Activated")]=function() if not isMax and props.canAfford then props.onBuy() end end,
            }),
            scope:New("TextButton")({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=4,[OnEvent("MouseEnter")]=function() hv:set(true) end,[OnEvent("MouseLeave")]=function() hv:set(false) end}),
        },
    })
end

-- Кнопка таба
local function TabBtn(props)
    local isActive=scope:Computed(function(u) return u(props.panelOpen)and u(props.activeTab)==props.tabId end)
    return scope:New("TextButton")({
        Size=UDim2.new(0,58,0,64),
        BackgroundColor3=scope:Computed(function(u) return u(isActive)and C.tabActive or C.tabInactive end),
        BackgroundTransparency=0.1,BorderSizePixel=0,Text="",
        [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,8)}),
            scope:New("UIStroke")({Color=scope:Computed(function(u) return u(isActive)and C.gem or C.tabBorder end),Thickness=1.5,Transparency=0.3}),
            scope:New("TextLabel")({Size=UDim2.new(1,0,0,34),Position=UDim2.new(0,0,0,6),BackgroundTransparency=1,Text=props.icon,TextScaled=true,Font=Enum.Font.GothamBold,TextColor3=scope:Computed(function(u) return u(isActive)and C.white or C.textMuted end)}),
            scope:New("TextLabel")({Size=UDim2.new(1,-4,0,14),Position=UDim2.new(0,2,0,42),BackgroundTransparency=1,Text=props.label,TextSize=10,Font=Enum.Font.GothamBold,TextColor3=scope:Computed(function(u) return u(isActive)and C.gem or C.textMuted end),TextXAlignment=Enum.TextXAlignment.Center}),
        },
        [OnEvent("Activated")]=function() if props.panelOpen:get() and props.activeTab:get() == props.tabId then props.panelOpen:set(false) else props.activeTab:set(props.tabId); props.panelOpen:set(true) end end,
    })
end

-- HUD
local HUD={}; HUD.__index=HUD
function HUD.new(p)
    local self=setmetatable({},HUD)
    self._c=scope:Value(0); self._g=scope:Value(0); self._d=scope:Value(0)
    self._li=scope:Value("dirt"); self._ln=scope:Value("Dirt Layer")
    self._inv=scope:Value({}::{{oreId:string,count:number}})
    self._up=scope:Value({}::{[string]:{level:number}})
    self._open=scope:Value(false); self._tab=scope:Value("inventory")
    local dp=scope:Computed(function(u) local d=u(self._d); for _,l in ipairs(Constants.LAYERS)do if l.id==u(self._li)then local rg=l.depthEnd-l.depthStart; if rg<=0 or l.depthEnd==math.huge then return 0.5 end; return math.clamp((d-l.depthStart)/rg,0,1) end end; return 0 end)
    local lc=scope:Computed(function(u) return LAYER_COLORS[u(self._li)]or C.depthFill end)
    self._gui=scope:New("ScreenGui")({
        Name="DeepDiggerHUD",ResetOnSpawn=false,DisplayOrder=20,Parent=p:WaitForChild("PlayerGui"),
        [Children]={
            -- TopLeft
            scope:New("Frame")({
                Size=UDim2.new(0,240,0,118),Position=UDim2.new(0,8,0,36),BackgroundTransparency=1,
                [Children]={
                    scope:New("Frame")({Size=UDim2.new(1,0,0,26),BackgroundColor3=C.depthBg,BackgroundTransparency=0.1,BorderSizePixel=0,ClipsDescendants=true,
                        [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,5)}),scope:New("UIStroke")({Color=C.panelBorder,Thickness=1,Transparency=0.4}),
                            scope:New("Frame")({Size=scope:Computed(function(u) return UDim2.new(u(dp),0,1,0)end),BackgroundColor3=lc,BackgroundTransparency=0.2,BorderSizePixel=0,[Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,5)})}}),
                            scope:New("TextLabel")({Size=UDim2.new(0.4,0,1,0),Position=UDim2.new(0,8,0,0),BackgroundTransparency=1,Text="ГЛУБИНА",TextSize=11,Font=Enum.Font.GothamBold,TextColor3=C.white,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=3}),
                            scope:New("TextLabel")({Size=UDim2.new(0.6,-8,1,0),Position=UDim2.new(0.4,0,0,0),BackgroundTransparency=1,Text=scope:Computed(function(u) return math.floor(u(self._d)).."м"end),TextSize=11,Font=Enum.Font.GothamBold,TextColor3=C.white,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=3}),
                        },
                    }),
                    scope:New("TextLabel")({Size=UDim2.new(1,0,0,18),Position=UDim2.new(0,0,0,28),BackgroundTransparency=1,Text=scope:Computed(function(u) return"▼ "..u(self._ln)end),TextSize=12,Font=Enum.Font.GothamBold,TextColor3=lc,TextXAlignment=Enum.TextXAlignment.Left}),
                    scope:New("Frame")({Size=UDim2.new(0,114,0,28),Position=UDim2.new(0,0,0,50),BackgroundColor3=C.goldBg,BackgroundTransparency=0.1,BorderSizePixel=0,
                        [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,5)}),scope:New("UIStroke")({Color=C.gold,Thickness=1,Transparency=0.5}),scope:New("TextLabel")({Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,4,0,0),BackgroundTransparency=1,Text=scope:Computed(function(u) return"💰 "..sn(u(self._c))end),TextSize=14,Font=Enum.Font.GothamBold,TextColor3=C.gold,TextXAlignment=Enum.TextXAlignment.Left})},
                    }),
                    scope:New("Frame")({Size=UDim2.new(0,114,0,28),Position=UDim2.new(0,122,0,50),BackgroundColor3=C.gemBg,BackgroundTransparency=0.1,BorderSizePixel=0,
                        [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,5)}),scope:New("UIStroke")({Color=C.gem,Thickness=1,Transparency=0.5}),scope:New("TextLabel")({Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,4,0,0),BackgroundTransparency=1,Text=scope:Computed(function(u) return"💎 "..sn(u(self._g))end),TextSize=14,Font=Enum.Font.GothamBold,TextColor3=C.gem,TextXAlignment=Enum.TextXAlignment.Left})},
                    }),
                    scope:New("TextButton")({Size=UDim2.new(0,240,0,24),Position=UDim2.new(0,0,0,84),BackgroundColor3=Color3.fromRGB(40,100,40),BackgroundTransparency=0.1,BorderSizePixel=0,Text="ПРОДАТЬ РУДЫ",TextSize=12,Font=Enum.Font.GothamBold,TextColor3=Color3.fromRGB(150,255,120),
                        [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,5)}),scope:New("UIStroke")({Color=Color3.fromRGB(80,180,80),Thickness=1,Transparency=0.3})},
                        [OnEvent("Activated")]=function() Net:Invoke("SellOres") end,
                    }),
                },
            }),
            -- TabBar
            scope:New("Frame")({Size=UDim2.new(0,200,0,72),Position=UDim2.new(0,8,1,-80),BackgroundTransparency=1,
                [Children]={scope:New("UIListLayout")({FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),VerticalAlignment=Enum.VerticalAlignment.Center}),
                    TabBtn({icon="⛏",label="ИНВЕНТ",tabId="inventory",activeTab=self._tab,panelOpen=self._open}),
                    TabBtn({icon="⚒",label="АПГРЕЙД",tabId="upgrades",activeTab=self._tab,panelOpen=self._open}),
                    TabBtn({icon="📊",label="СТАТЫ",tabId="stats",activeTab=self._tab,panelOpen=self._open}),
                },
            }),
            -- MainPanel
            scope:New("Frame")({
                Size=UDim2.new(0,540,0,340),Position=UDim2.new(0,8,1,-428),
                Visible=scope:Computed(function(u) return u(self._open)end),
                BackgroundColor3=C.panelBg,BackgroundTransparency=0.05,BorderSizePixel=0,
                [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,10)}),scope:New("UIStroke")({Color=C.panelBorder,Thickness=1.5,Transparency=0.2}),
                    -- Header
                    scope:New("Frame")({Size=UDim2.new(1,0,0,38),BackgroundColor3=C.panelHeader,BackgroundTransparency=0.1,BorderSizePixel=0,
                        [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,10)}),
                            scope:New("TextLabel")({Size=UDim2.new(0,30,1,0),Position=UDim2.new(0,8,0,0),BackgroundTransparency=1,Text="✦",TextSize=18,Font=Enum.Font.GothamBold,TextColor3=C.gem}),
                            scope:New("TextLabel")({Size=UDim2.new(0.7,0,1,0),Position=UDim2.new(0,40,0,0),BackgroundTransparency=1,Text=scope:Computed(function(u) local t=u(self._tab); if t=="inventory"then return"ИНВЕНТАРЬ"elseif t=="upgrades"then return"УЛУЧШЕНИЯ"else return"СТАТИСТИКА"end end),TextSize=16,Font=Enum.Font.GothamBlack,TextColor3=C.textMain,TextXAlignment=Enum.TextXAlignment.Left}),
                            scope:New("TextButton")({Size=UDim2.new(0,32,0,32),Position=UDim2.new(1,-38,0.5,-16),BackgroundColor3=Color3.fromRGB(120,30,30),BackgroundTransparency=0.2,BorderSizePixel=0,Text="✕",TextSize=14,Font=Enum.Font.GothamBold,TextColor3=C.white,
                                [Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,6)}),scope:New("UIStroke")({Color=Color3.fromRGB(200,60,60),Thickness=1.5,Transparency=0.3})},
                                [OnEvent("Activated")]=function() self._open:set(false) end,
                            }),
                        },
                    }),
                    -- Content
                    scope:New("Frame")({Size=UDim2.new(1,-8,1,-46),Position=UDim2.new(0,4,0,42),BackgroundTransparency=1,
                        [Children]={
                            -- Inventory
                            scope:New("ScrollingFrame")({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=C.panelBorder,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=scope:Computed(function(u) return u(self._tab)=="inventory"end),
                                [Children]={scope:New("UIGridLayout")({CellSize=UDim2.new(0,58,0,68),CellPadding=UDim2.new(0,8,0,8),SortOrder=Enum.SortOrder.Name}),scope:New("UIPadding")({PaddingLeft=UDim.new(0,4),PaddingTop=UDim.new(0,4)}),scope:Computed(function(u) local slots={}; for _,item in ipairs(u(self._inv))do slots[#slots+1]=InvSlot(item.oreId,item.count)end; return slots end)},
                            }),
                            -- Upgrades
                            scope:New("ScrollingFrame")({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=C.panelBorder,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=scope:Computed(function(u) return u(self._tab)=="upgrades"end),
                                [Children]={scope:New("UIListLayout")({FillDirection=Enum.FillDirection.Vertical,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder}),scope:New("UIPadding")({PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),PaddingTop=UDim.new(0,4)}),scope:Computed(function(u) local rows={}; local ups=u(self._up); local coins=u(self._c); for i,id in ipairs(UPGRADE_ORDER)do local d=ups[id]; if d then local cfg=Constants.UPGRADES[id]; if cfg then local cost=uc(id,d.level); rows[#rows+1]=UpgRow({upgradeId=id,level=d.level,maxLevel=cfg.maxLevel,cost=cost,canAfford=coins>=cost,onBuy=function()Net:Invoke("BuyUpgrade",id)end})end end end; return rows end)},
                            }),
                            -- Stats
                            scope:New("ScrollingFrame")({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=C.panelBorder,CanvasSize=UDim2.new(0,0,0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=scope:Computed(function(u) return u(self._tab)=="stats"end),
                                [Children]={scope:New("UIPadding")({PaddingTop=UDim.new(0,4),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)}),scope:New("UIListLayout")({FillDirection=Enum.FillDirection.Vertical,Padding=UDim.new(0,8)}),
                                    scope:New("Frame")({Size=UDim2.new(1,-8,0,36),BackgroundColor3=C.btnBg,BorderSizePixel=0,[Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,6)}),scope:New("TextLabel")({Size=UDim2.new(0.6,0,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text="⬇ Макс. глубина",TextSize=13,Font=Enum.Font.Gotham,TextColor3=C.textLabel,TextXAlignment=Enum.TextXAlignment.Left}),scope:New("TextLabel")({Size=UDim2.new(0.4,-10,1,0),Position=UDim2.new(0.6,0,0,0),BackgroundTransparency=1,Text=scope:Computed(function(u) return math.floor(u(self._d)).." м"end),TextSize=15,Font=Enum.Font.GothamBold,TextColor3=C.depthFill,TextXAlignment=Enum.TextXAlignment.Right})},}),
                                    scope:New("Frame")({Size=UDim2.new(1,-8,0,36),BackgroundColor3=C.btnBg,BorderSizePixel=0,[Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,6)}),scope:New("TextLabel")({Size=UDim2.new(0.6,0,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text="⛏ Блоков сломано",TextSize=13,Font=Enum.Font.Gotham,TextColor3=C.textLabel,TextXAlignment=Enum.TextXAlignment.Left}),scope:New("TextLabel")({Name="BlocksMined",Size=UDim2.new(0.4,-10,1,0),Position=UDim2.new(0.6,0,0,0),BackgroundTransparency=1,Text="0",TextSize=15,Font=Enum.Font.GothamBold,TextColor3=C.gold,TextXAlignment=Enum.TextXAlignment.Right})},}),
                                    scope:New("Frame")({Size=UDim2.new(1,-8,0,36),BackgroundColor3=C.btnBg,BorderSizePixel=0,[Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,6)}),scope:New("TextLabel")({Size=UDim2.new(0.6,0,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text="💰 Монет заработано",TextSize=13,Font=Enum.Font.Gotham,TextColor3=C.textLabel,TextXAlignment=Enum.TextXAlignment.Left}),scope:New("TextLabel")({Name="TotalCoins",Size=UDim2.new(0.4,-10,1,0),Position=UDim2.new(0.6,0,0,0),BackgroundTransparency=1,Text="0",TextSize=15,Font=Enum.Font.GothamBold,TextColor3=C.gold,TextXAlignment=Enum.TextXAlignment.Right})},}),
                                    scope:New("Frame")({Size=UDim2.new(1,-8,0,36),BackgroundColor3=C.btnBg,BorderSizePixel=0,[Children]={scope:New("UICorner")({CornerRadius=UDim.new(0,6)}),scope:New("TextLabel")({Size=UDim2.new(0.6,0,1,0),Position=UDim2.new(0,10,0,0),BackgroundTransparency=1,Text="🏆 Боссов убито",TextSize=13,Font=Enum.Font.Gotham,TextColor3=C.textLabel,TextXAlignment=Enum.TextXAlignment.Left}),scope:New("TextLabel")({Name="BossesDefeated",Size=UDim2.new(0.4,-10,1,0),Position=UDim2.new(0.6,0,0,0),BackgroundTransparency=1,Text="0",TextSize=15,Font=Enum.Font.GothamBold,TextColor3=C.mythic,TextXAlignment=Enum.TextXAlignment.Right})},}),
                                },
                            }),
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
function HUD:setDepth(d,i,n) self._d:set(d); if i then self._li:set(i) end; if n then self._ln:set(n) end end
function HUD:setInventory(inv) table.sort(inv,function(a,b)return(RARITY_ORDER[ORE_RARITY[a.oreId]or"common"] or 6)<(RARITY_ORDER[ORE_RARITY[b.oreId]or"common"] or 6)end); self._inv:set(inv) end
function HUD:setPlayerData(d)
    self._c:set(d.coins or 0); self._g:set(d.gems or 0); self._d:set(d.depth or 0)
    local ln=d.layer or"dirt"; for _,l in ipairs(Constants.LAYERS)do if l.id==d.layer then ln=l.name; break end end
    self._li:set(d.layer or"dirt"); self._ln:set(ln)
    local inv={}; for oId,c in pairs(d.inventory or{})do if c>0 then inv[#inv+1]={oreId=oId,count=c}end end; self:setInventory(inv)
    local ups={}; for _,id in ipairs(UPGRADE_ORDER)do ups[id]={level=d[id.."Level"]or 1}end; if d.autoSellUnlocked then ups["autoSell"]={level=1}end; self._up:set(ups)
    local sf=self._gui and self._gui:FindFirstChild("MainPanel",true)and self._gui.MainPanel and self._gui.MainPanel:FindFirstChild("Content",true)and self._gui.MainPanel.Content:FindFirstChild("Stats",true)
    if sf then local function setText(nm,val)local l=sf:FindFirstChild(nm,true); if l then l.Text=val end end; setText("BlocksMined",sn(d.totalBlocksMined or 0)); setText("TotalCoins",sn(d.totalCoinsEarned or 0)); setText("BossesDefeated",tostring(d.bossesDefeated or 0))end
end
function HUD:destroy() if self._gui then self._gui:Destroy() end end
return HUD
