--!strict
-- Фасад HUD: собирает панели, держит состояние и синк с сервером.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage:WaitForChild("Packages").Fusion)

local ScopeFactory = require(script.Parent.hud.ScopeFactory)
local HudStateModule = require(script.Parent.hud.HudState)
local PlayerDataMapper = require(script.Parent.hud.PlayerDataMapper)
local TopBar = require(script.Parent.hud.panels.TopBar)
local TabBar = require(script.Parent.hud.panels.TabBar)
local MainPanel = require(script.Parent.hud.panels.MainPanel)

local Children = Fusion.Children

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
    destroy: (self: HUD) -> (),
}

local HUD = {}
HUD.__index = HUD

function HUD.new(player: Player): HUD
    local self = setmetatable({}, HUD) :: HUD
    local scope = ScopeFactory.new()
    local state = HudStateModule.create(scope)

    self._scope = scope
    self._state = state
    self._gui = scope:New("ScreenGui")({
        Name = "DeepDiggerHUD",
        ResetOnSpawn = false,
        DisplayOrder = 20,
        Parent = player:WaitForChild("PlayerGui"),
        [Children] = {
            TopBar.create(scope, state),
            TabBar.create(scope, state),
            MainPanel.create(scope, state),
        },
    }) :: ScreenGui

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
    HudStateModule.applyDepth(state, depth, layerId or "dirt", layerName or "Dirt Layer")
end

function HUD:setInventory(inventory: { PlayerDataMapper.InventoryEntry })
    local state = self._state
    if not state then
        return
    end
    HudStateModule.sortInventory(inventory)
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
