--!strict
-- Фасад HUD: собирает панели, держит состояние и синк с сервером.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.hud.ScopeFactory)
local HudStateModule = require(script.Parent.hud.HudState)
local PlayerDataMapper = require(script.Parent.hud.PlayerDataMapper)
local CurrencyRibbon   = require(script.Parent.hud.components.CurrencyRibbon)
local InventoryWidget  = require(script.Parent.hud.components.InventoryWidget)
local TopRightActionRow = require(script.Parent.hud.components.TopRightActionRow)
local BuffBar          = require(script.Parent.hud.components.BuffBar)
local QuestTracker     = require(script.Parent.hud.components.QuestTracker)
local LeftSidebar      = require(script.Parent.hud.panels.LeftSidebar)
local MainPanel        = require(script.Parent.hud.panels.MainPanel)
local ViewportLayout   = require(script.Parent.util.ViewportLayout)
local VerifyHudLayout  = require(script.Parent.util.VerifyHudLayout)
local UiScreen         = require(script.Parent.util.UiScreen)

local Children = Fusion.Children
local peek = Fusion.peek

export type HUD = {
    _scope: ScopeFactory.HudScope?,
    _state: HudStateModule.HudState?,
    _gui: ScreenGui?,
    setPlayerData: (self: HUD, payload: PlayerDataMapper.ServerPlayerPayload) -> (),
    applyMiningDelta: (self: HUD, delta: HudStateModule.MiningHudDelta) -> (),
    setCoins: (self: HUD, amount: number) -> (),
    setGems: (self: HUD, amount: number) -> (),
    setDepth: (self: HUD, depth: number, layerId: string?, layerName: string?) -> (),
    setInventory: (self: HUD, inventory: { PlayerDataMapper.InventoryEntry }) -> (),
    openTab: (self: HUD, tabId: string) -> (),
    closePanel: (self: HUD) -> (),
    isUpgradesOpen: (self: HUD) -> boolean,
    destroy: (self: HUD) -> (),
}

local HUD = {}
HUD.__index = HUD

function HUD.new(player: Player, homeCallback: (() -> ())?): HUD
    local self = setmetatable({}, HUD) :: HUD
    local scope = ScopeFactory.new()
    local state = HudStateModule.create(scope)

    self._scope = scope
    self._state = state
    ViewportLayout.start()
    self._gui = scope:New("ScreenGui")({
        Name = "DeepDiggerHUD",
        ResetOnSpawn = false,
        Parent = player:WaitForChild("PlayerGui"),
        [Children] = {
            CurrencyRibbon.create(scope, state),
            InventoryWidget.create(scope, state),
            TopRightActionRow.create(scope, state),
            BuffBar.create(scope, state),
            QuestTracker.create(scope, state),
            LeftSidebar.create(scope, state, homeCallback or function() end),
            MainPanel.create(scope, state),
        },
    }) :: ScreenGui

    UiScreen.apply(self._gui, "hud")
    task.defer(function()
        if self._gui and self._gui.Parent then
            UiScreen.apply(self._gui, "hud")
            VerifyHudLayout.check(self._gui)
        end
    end)

    return self
end

function HUD:setCoins(amount: number)
    if self._state then
        self._state.coins:set(amount)
    end
end

function HUD:setGems(amount: number)
    if self._state then
        self._state.gems:set(amount)
    end
end

function HUD:setDepth(depth: number, layerId: string?, layerName: string?)
    local state = self._state
    if not state then
        return
    end
    HudStateModule.applyDepth(state, depth, layerId or "dirt", layerName or "Grassland")
end

function HUD:setInventory(inventory: { PlayerDataMapper.InventoryEntry })
    local state = self._state
    if not state then
        return
    end
    HudStateModule.sortInventory(inventory)
    local used = 0
    for _, e in ipairs(inventory) do
        used += e.count
    end
    state.inventoryUsed:set(used)
    ;(state :: any)._pendingInventory = nil
    state.inventory:set(inventory)
end

function HUD:setPlayerData(payload: PlayerDataMapper.ServerPlayerPayload)
    local state = self._state
    if not state then
        return
    end
    HudStateModule.applyServerPayload(state, payload)
end

function HUD:applyMiningDelta(delta: HudStateModule.MiningHudDelta)
    local state = self._state
    if not state then
        return
    end
    HudStateModule.applyMiningDelta(state, delta)
end

function HUD:openTab(tabId: string)
    local state = self._state
    if not state then
        return
    end
    state.activeTab:set(tabId)
    state.panelOpen:set(true)
    if tabId == "inventory" then
        HudStateModule.flushPendingInventory(state)
    end
end

function HUD:closePanel()
    local state = self._state
    if not state then
        return
    end
    state.panelOpen:set(false)
end

function HUD:isUpgradesOpen(): boolean
    local state = self._state
    if not state then
        return false
    end
    return peek(state.panelOpen) and peek(state.activeTab) == "upgrades"
end

function HUD:destroy()
    if self._gui then
        self._gui:Destroy()
        self._gui = nil
    end
    if self._scope then
        Fusion.doCleanup(self._scope)
        self._scope = nil
    end
    self._state = nil
end

return HUD
