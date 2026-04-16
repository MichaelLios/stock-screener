-- MetaProgression.server.lua
-- Persists mastery points and passive unlocks across runs using DataStoreService.
--
-- Mastery Points (MP) are earned each run:
--   • +10 per floor reached
--   • +25 bonus for defeating the floor boss
--   • +5 per Elite room cleared
--
-- Spend MP on permanent passives that carry into every future run.
-- Passives are applied by CombatSystem.InitPlayer via MetaProgression.GetPassiveBonuses.

local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents  = ReplicatedStorage:WaitForChild("RemoteEvents")
local MetaSyncEvt   = RemoteEvents:WaitForChild("MetaSync",    15)
local MetaUpgradeEvt = RemoteEvents:WaitForChild("MetaUpgrade", 15)
local UpdateHUD     = RemoteEvents:WaitForChild("UpdateHUD",   15)

-- Guard against Studio / offline environments where DataStore is unavailable.
-- All load/save calls below check MetaStore before proceeding, so the game
-- runs fine without persistence (defaults to 0 points, no unlocks).
local MetaStore = nil
local _ok, _result = pcall(function()
    MetaStore = DataStoreService:GetDataStore("AnimeRoguelike_Meta_v1")
end)
if not _ok then
    warn("[MetaProgression] DataStore unavailable (Studio / no API access). Progress will not be saved.")
end

local MetaProgression = {}

-- ────────────────────────────────────────────────
-- PASSIVE DEFINITIONS
-- ────────────────────────────────────────────────

MetaProgression.Passives = {
    {
        Id          = "BonusHP",
        Name        = "Survivor's Spirit",
        Description = "Start every run with +10% Max HP.",
        Cost        = 100,
        MaxLevel    = 3,
        Apply = function(stats, level)
            stats.MaxHP = math.floor(stats.MaxHP * (1 + level * 0.10))
        end,
    },
    {
        Id          = "BonusDamage",
        Name        = "Battle-Hardened",
        Description = "Start every run with +5 Attack.",
        Cost        = 120,
        MaxLevel    = 4,
        Apply = function(stats, level)
            stats.Atk = stats.Atk + level * 5
        end,
    },
    {
        Id          = "LootFortune",
        Name        = "Fortune's Hand",
        Description = "Loot drop quality improved (rare+ items more common).",
        Cost        = 150,
        MaxLevel    = 2,
        Apply = function(stats, level)
            stats.LootLuck = (stats.LootLuck or 1.0) + level * 0.15
        end,
    },
    {
        Id          = "CritEdge",
        Name        = "Killer Insight",
        Description = "Start every run with +3% global critical hit chance.",
        Cost        = 180,
        MaxLevel    = 3,
        Apply = function(stats, level)
            stats.CritChance = (stats.CritChance or 0.05) + level * 0.03
        end,
    },
    {
        Id          = "CooldownMastery",
        Name        = "Technique Mastery",
        Description = "All ability cooldowns reduced by 5% per level.",
        Cost        = 200,
        MaxLevel    = 3,
        Apply = function(stats, level)
            stats.CooldownReduction = (stats.CooldownReduction or 0) + level * 0.05
        end,
    },
    {
        Id          = "StartingGold",
        Name        = "Pirate Legacy",
        Description = "Start every run with +50 Bounty.",
        Cost        = 80,
        MaxLevel    = 4,
        Apply = function(stats, level)
            stats.BonusStartGold = (stats.BonusStartGold or 0) + level * 50
        end,
    },
}

-- ────────────────────────────────────────────────
-- PLAYER DATA  (in-memory cache)
-- ────────────────────────────────────────────────

local PlayerMeta = {}   -- [player] = { MasteryPoints, TotalRuns, BestFloor, Unlocked = {[id] = level} }

local DEFAULT_META = {
    MasteryPoints = 0,
    TotalRuns     = 0,
    BestFloor     = 0,
    Unlocked      = {},   -- { [passiveId] = level }
}

local function deepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and deepCopy(v) or v
    end
    return copy
end

local function loadMeta(player)
    if not MetaStore then return deepCopy(DEFAULT_META) end
    local key = "player_" .. player.UserId
    local ok, data = pcall(function()
        return MetaStore:GetAsync(key)
    end)
    if ok and data then
        -- Merge in any new defaults
        for k, v in pairs(DEFAULT_META) do
            if data[k] == nil then
                data[k] = type(v) == "table" and deepCopy(v) or v
            end
        end
        return data
    end
    return deepCopy(DEFAULT_META)
end

local function saveMeta(player)
    if not MetaStore then return end
    local meta = PlayerMeta[player]
    if not meta then return end
    local key = "player_" .. player.UserId
    pcall(function()
        MetaStore:SetAsync(key, meta)
    end)
end

local function syncToClient(player)
    local meta = PlayerMeta[player]
    if not meta or not MetaSyncEvt then return end

    -- Build the passive list with current levels for the UI
    local passiveList = {}
    for _, passive in ipairs(MetaProgression.Passives) do
        local currentLevel = meta.Unlocked[passive.Id] or 0
        table.insert(passiveList, {
            Id          = passive.Id,
            Name        = passive.Name,
            Description = passive.Description,
            Cost        = passive.Cost,
            MaxLevel    = passive.MaxLevel,
            CurrentLevel = currentLevel,
            Maxed       = currentLevel >= passive.MaxLevel,
        })
    end

    MetaSyncEvt:FireClient(player, {
        MasteryPoints = meta.MasteryPoints,
        TotalRuns     = meta.TotalRuns,
        BestFloor     = meta.BestFloor,
        Passives      = passiveList,
    })
end

-- ────────────────────────────────────────────────
-- PUBLIC API
-- ────────────────────────────────────────────────

-- Apply all unlocked passive bonuses to a stat block (called by GameManager during InitPlayer)
function MetaProgression.ApplyPassiveBonuses(player, stats)
    local meta = PlayerMeta[player]
    if not meta then return end
    for _, passive in ipairs(MetaProgression.Passives) do
        local level = meta.Unlocked[passive.Id] or 0
        if level > 0 then
            passive.Apply(stats, level)
        end
    end
    -- Apply bonus starting gold to initial player state (GameManager reads this)
    if stats.BonusStartGold then
        stats._StartingGold = stats.BonusStartGold
    end
end

-- Called by GameManager when player advances a floor or dies
function MetaProgression.AwardRunPoints(player, floorReached, bossKilled, eliteRoomsCleared)
    local meta = PlayerMeta[player]
    if not meta then return end

    local earned = floorReached * 10
        + (bossKilled and 25 or 0)
        + (eliteRoomsCleared or 0) * 5

    meta.MasteryPoints = meta.MasteryPoints + earned
    meta.TotalRuns     = meta.TotalRuns + 1
    if floorReached > meta.BestFloor then
        meta.BestFloor = floorReached
    end

    saveMeta(player)
    syncToClient(player)

    if UpdateHUD and earned > 0 then
        UpdateHUD:FireClient(player, {
            Message  = "+" .. earned .. " Mastery Points earned!",
            Duration = 3,
        })
    end
end

-- ────────────────────────────────────────────────
-- PLAYER JOIN / LEAVE
-- ────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    PlayerMeta[player] = loadMeta(player)
    task.wait(2)  -- wait for client scripts to load
    syncToClient(player)
end)

Players.PlayerRemoving:Connect(function(player)
    saveMeta(player)
    PlayerMeta[player] = nil
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Purchase a passive upgrade
-- ────────────────────────────────────────────────

MetaUpgradeEvt.OnServerEvent:Connect(function(player, passiveId)
    local meta = PlayerMeta[player]
    if not meta then return end

    -- Find the passive
    local chosen = nil
    for _, p in ipairs(MetaProgression.Passives) do
        if p.Id == passiveId then chosen = p; break end
    end
    if not chosen then return end

    local currentLevel = meta.Unlocked[passiveId] or 0
    if currentLevel >= chosen.MaxLevel then
        UpdateHUD:FireClient(player, { Message = "Already maxed!", Duration = 2 })
        return
    end

    -- Cost scales with current level (buy level 2 costs 2×, level 3 costs 3×)
    local totalCost = chosen.Cost * (currentLevel + 1)
    if meta.MasteryPoints < totalCost then
        UpdateHUD:FireClient(player, {
            Message  = "Need " .. totalCost .. " Mastery Points",
            Duration = 2,
        })
        return
    end

    meta.MasteryPoints = meta.MasteryPoints - totalCost
    meta.Unlocked[passiveId] = currentLevel + 1

    saveMeta(player)
    syncToClient(player)

    UpdateHUD:FireClient(player, {
        Message  = chosen.Name .. " upgraded to level " .. meta.Unlocked[passiveId] .. "!",
        Duration = 3,
    })
end)

print("[MetaProgression] Loaded.")

return MetaProgression
