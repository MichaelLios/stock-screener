-- DynamicEventManager.lua
-- Server module that triggers and manages dynamic room events.
-- Tracks active events per room and exposes modifier queries to CombatSystem.
--
-- Integration hooks (add these calls to GameManager.server.lua):
--   In handleRoomEnter, after the flavor-line block:
--     DynamicEventManager.OnRoomEnter(players, roomType, roomId, floor)
--   In the room-cleared block, before RoomCleared:FireAllClients:
--     DynamicEventManager.OnRoomCleared(roomId)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DynamicEvents = require(ReplicatedStorage.Modules.DynamicEvents)

local RemoteEvents   = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateHUD      = RemoteEvents:WaitForChild("UpdateHUD")

local DynamicEventManager = {}

-- Active event per room: { [roomId] = { Event data, StartTime, ExpiresAt|nil } }
local ActiveEvents = {}

-- Per-player chaos stat cache (ChaosMode event)
local ChaosMults = {}   -- { [player] = { AtkMult, DefMult } }

-- ─── Internal helpers ─────────────────────────────────────────────────────────

local function broadcastEventToPlayers(players, evt)
    if not evt then return end
    for _, player in ipairs(players) do
        UpdateHUD:FireClient(player, {
            Message  = evt.HUDMessage,
            Duration = 5,
            IsEvent  = true,
        })
    end
end

local function applyInstantModifiers(players, evt, combatSystem)
    local mods = evt.Modifiers or {}

    -- Full restore on entry
    if mods.FullRestoreOnEntry then
        for _, p in ipairs(players) do
            local state = combatSystem.GetPlayerState(p)
            if state then
                state.HP = state.Stats.MaxHP
                state.MP = state.Stats.MaxMP
                UpdateHUD:FireClient(p, {
                    HP = state.HP, MaxHP = state.Stats.MaxHP,
                    MP = state.MP, MaxMP = state.Stats.MaxMP,
                })
            end
        end
    end

    -- Enemy HP modifier: apply to all enemies in the room via attributes
    -- (enemies were spawned before room entry; we scale their HP now)
    if mods.EnemyHPMult then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:GetAttribute("IsEnemy") then
                local hp = obj:GetAttribute("HP")
                if hp then
                    obj:SetAttribute("HP", math.max(1, math.floor(hp * mods.EnemyHPMult)))
                end
            end
        end
    end

    -- Speed modifier for players
    if mods.AllSpdMult and mods.AllSpdMult ~= 1 then
        for _, p in ipairs(players) do
            local char = p.Character
            local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
            if hum then
                hum.WalkSpeed = math.floor(hum.WalkSpeed * mods.AllSpdMult)
            end
        end
    end

    -- Player Atk multiplier: stored on the event so CombatSystem.GetEventModifier can read it
    -- (see GetActiveModifier below)
end

local function revertInstantModifiers(players, evt)
    local mods = evt and evt.Modifiers or {}
    if mods.AllSpdMult and mods.AllSpdMult ~= 1 then
        for _, p in ipairs(players) do
            local char = p.Character
            local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
            if hum then
                hum.WalkSpeed = 16  -- restore default
            end
        end
    end
    -- Clear chaos mults for all players
    for _, p in ipairs(players) do
        ChaosMults[p] = nil
    end
end

-- ─── ChaosMode stat randomiser ────────────────────────────────────────────────

local function startChaosCycle(players, evt, roomId)
    local mods = evt.Modifiers or {}
    task.spawn(function()
        while ActiveEvents[roomId] and ActiveEvents[roomId].Event.Id == "ChaosMode" do
            for _, p in ipairs(players) do
                if p.Parent then
                    local atkMult = mods.ChaosStatMin + math.random() * (mods.ChaosStatMax - mods.ChaosStatMin)
                    local spdMult = mods.ChaosStatMin + math.random() * (mods.ChaosStatMax - mods.ChaosStatMin)
                    ChaosMults[p] = { AtkMult = atkMult, SpdMult = spdMult }
                    local char = p.Character
                    local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
                    if hum then hum.WalkSpeed = math.clamp(16 * spdMult, 4, 50) end
                end
            end
            task.wait(mods.ChaosStatInterval or 15)
        end
        -- Restore on exit
        for _, p in ipairs(players) do
            ChaosMults[p] = nil
            local char = p.Parent and p.Character
            local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- Call from GameManager.handleRoomEnter
function DynamicEventManager.OnRoomEnter(players, roomType, roomId, floor, combatSystem)
    -- Clear any lingering event from a previous room of the same ID
    ActiveEvents[roomId] = nil

    local evt = DynamicEvents.Roll(roomType)
    if not evt then return end

    ActiveEvents[roomId] = {
        Event     = evt,
        StartTime = tick(),
        Players   = players,
    }

    broadcastEventToPlayers(players, evt)
    applyInstantModifiers(players, evt, combatSystem)

    -- Launch timed/periodic effects
    if evt.Id == "ChaosMode" then
        startChaosCycle(players, evt, roomId)
    end
end

-- Call from GameManager room-cleared block
function DynamicEventManager.OnRoomCleared(roomId, lootSystem, floor, players)
    local entry = ActiveEvents[roomId]
    if not entry then return end

    local evt = entry.Event
    revertInstantModifiers(entry.Players or players or {}, evt)

    -- Apply on-clear reward
    local reward = evt.Reward
    if reward and reward.Type == "LootChoice" and lootSystem and players then
        local choices = lootSystem.GenerateLootChoices(reward.Table, floor, reward.Choices or 3)
        local RemEvts = ReplicatedStorage:WaitForChild("RemoteEvents")
        local lootChoiceEvt = RemEvts:WaitForChild("LootChoice")
        lootChoiceEvt:FireAllClients({
            Choices  = choices,
            RoomId   = roomId,
            RoomType = "DynamicReward",
        })
    end

    ActiveEvents[roomId] = nil
end

-- Called by CombatSystem to read active player Atk multiplier from an event
function DynamicEventManager.GetPlayerAtkMult(player)
    local mult = 1
    -- Find the active event for the player's current room
    local char  = player.Character
    local root  = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return mult end

    for _, entry in pairs(ActiveEvents) do
        if entry.Event and entry.Event.Modifiers then
            local m = entry.Event.Modifiers
            if m.PlayerAtkMult then
                mult = mult * m.PlayerAtkMult
            end
            if m.AbilityDmgBonus then
                mult = mult + m.AbilityDmgBonus
            end
        end
    end

    -- Chaos mode personal mult
    local chaosMult = ChaosMults[player]
    if chaosMult then
        mult = mult * chaosMult.AtkMult
    end

    return mult
end

-- Returns true if any active event has a given modifier flag
function DynamicEventManager.HasModifier(modKey)
    for _, entry in pairs(ActiveEvents) do
        if entry.Event and entry.Event.Modifiers and entry.Event.Modifiers[modKey] then
            return true, entry.Event.Modifiers[modKey]
        end
    end
    return false, nil
end

-- Returns true + value if ZeroMPCost is active for any player (any active event)
function DynamicEventManager.IsZeroMPCost()
    return DynamicEventManager.HasModifier("ZeroMPCost")
end

-- Returns cooldown multiplier from active events (1 if none)
function DynamicEventManager.GetCooldownMult()
    local mult = 1
    for _, entry in pairs(ActiveEvents) do
        local m = entry.Event and entry.Event.Modifiers
        if m and m.CooldownMult then
            mult = mult * m.CooldownMult
        end
    end
    return mult
end

-- Returns true if AbilityDoublefire is active
function DynamicEventManager.IsDoublefire()
    return DynamicEventManager.HasModifier("AbilityDoublefire")
end

-- Returns MPCostMult from active events (1 if none)
function DynamicEventManager.GetMPCostMult()
    local mult = 1
    for _, entry in pairs(ActiveEvents) do
        local m = entry.Event and entry.Event.Modifiers
        if m and m.MPCostMult then
            mult = mult * m.MPCostMult
        end
    end
    return mult
end

-- Returns chain AOE data if AbilityResonance is active (nil otherwise)
function DynamicEventManager.GetAbilityChainAOE()
    local ok, val = DynamicEventManager.HasModifier("AbilityChainAOE")
    if not ok then return nil end
    for _, entry in pairs(ActiveEvents) do
        local m = entry.Event and entry.Event.Modifiers
        if m and m.AbilityChainAOE then
            return { Radius = m.AbilityChainRadius or 8, Mult = m.AbilityChainMult or 0.35 }
        end
    end
    return nil
end

return DynamicEventManager
