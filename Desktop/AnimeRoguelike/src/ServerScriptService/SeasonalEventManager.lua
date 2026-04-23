-- SeasonalEventManager.lua
-- Applies the current weekly modifier to game systems and broadcasts it to clients.
-- Other systems (CombatSystem, GameManager) call the query functions here
-- rather than reading SeasonalEvents directly, so there's a single source of truth.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SeasonalEvents = require(ReplicatedStorage.Modules.SeasonalEvents)
local RemoteEvents   = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateHUD      = RemoteEvents:WaitForChild("UpdateHUD",        15)
local WeeklyModEvt   = RemoteEvents:WaitForChild("WeeklyModifier",   15)

-- ── Current modifier (cached at startup; changes require server restart or daily reset) ──

local CurrentPacket   = SeasonalEvents.GetCurrentEventPacket()
local CurrentMods     = CurrentPacket.WeeklyModifiers or {}

-- ── Public API ────────────────────────────────────────────────────────────────

local SeasonalEventManager = {}

-- Query functions for CombatSystem and GameManager ──────────────────────────

function SeasonalEventManager.GetEnemyHPMult()
    return CurrentMods.EnemyHPMult or 1.0
end

function SeasonalEventManager.GetGoldDropMult()
    return CurrentMods.GoldDropMult or 1.0
end

function SeasonalEventManager.GetShopCostMult()
    return CurrentMods.ShopCostMult or 1.0
end

function SeasonalEventManager.GetPlayerSpdMult()
    return CurrentMods.PlayerSpdMult or 1.0
end

function SeasonalEventManager.GetCDMult()
    return CurrentMods.CDMult or 1.0
end

function SeasonalEventManager.GetEvoXPMult()
    return CurrentMods.EvoXPMult or 1.0
end

function SeasonalEventManager.GetMPCostMult()
    return CurrentMods.MPCostMult or 1.0
end

function SeasonalEventManager.GetMasteryMult()
    return CurrentMods.MasteryMult or 1.0
end

function SeasonalEventManager.GetBonusCritChance()
    return CurrentMods.BonusCritChance or 0.0
end

function SeasonalEventManager.GetAbilityDmgMult()
    return CurrentMods.PlayerAbilityDmgMult or 1.0
end

-- Returns true if abilities should have a 20% echo-fire chance
function SeasonalEventManager.GetAbilityEchoChance()
    return CurrentMods.AbilityEchoChance or 0.0
end

-- Returns true if all Combat rooms should be treated as Elite this week
function SeasonalEventManager.AllCombatAreElite()
    return CurrentMods.AllCombatBecomesElite == true
end

-- Returns true if bonus enemy should spawn per room this week
function SeasonalEventManager.GetBonusEnemyPerRoom()
    return CurrentMods.BonusEnemyPerRoom or 0
end

function SeasonalEventManager.GetHealMult()
    return CurrentMods.HealMult or 1.0
end

-- Returns how many extra Bounty Board slots this week grants
function SeasonalEventManager.GetBountyBoardBonusSlots()
    return CurrentMods.BountyBoardBonusSlots or 0
end

-- Returns true if crits should apply a brief stun this week
function SeasonalEventManager.CritAppliesStun()
    return CurrentMods.CritAppliesStun == true, CurrentMods.CritStunDuration or 0
end

-- ── Broadcast helpers ────────────────────────────────────────────────────────

function SeasonalEventManager.BroadcastToPlayer(player)
    if not WeeklyModEvt then return end
    WeeklyModEvt:FireClient(player, CurrentPacket)
end

function SeasonalEventManager.BroadcastToAll()
    if not WeeklyModEvt then return end
    WeeklyModEvt:FireAllClients(CurrentPacket)
end

-- ── Auto-announce on join ─────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    task.delay(4, function()  -- wait for client GUI to initialize
        SeasonalEventManager.BroadcastToPlayer(player)
        -- Also show a HUD notification with the weekly modifier name
        if UpdateHUD then
            UpdateHUD:FireClient(player, {
                Message  = CurrentPacket.WeeklyIcon .. " This Week: " .. CurrentPacket.WeeklyName,
                SubText  = CurrentPacket.WeeklyDescription,
                Duration = 7,
                Color    = CurrentPacket.WeeklyColor,
            })
        end
    end)
end)

print("[SeasonalEventManager] Active modifier: " .. CurrentPacket.WeeklyName)

return SeasonalEventManager
