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
    -- ── TIER 1: Stat improvements ─────────────────────────────────────────
    {
        Id          = "BonusHP",
        Name        = "Survivor's Spirit",
        Category    = "Stat",
        Description = "Start every run with +10% Max HP per level.",
        Cost        = 100,
        MaxLevel    = 3,
        Apply = function(stats, level)
            stats.MaxHP = math.floor(stats.MaxHP * (1 + level * 0.10))
        end,
    },
    {
        Id          = "BonusDamage",
        Name        = "Battle-Hardened",
        Category    = "Stat",
        Description = "Start every run with +5 Attack per level.",
        Cost        = 120,
        MaxLevel    = 4,
        Apply = function(stats, level)
            stats.Atk = stats.Atk + level * 5
        end,
    },
    {
        Id          = "LootFortune",
        Name        = "Fortune's Hand",
        Category    = "Stat",
        Description = "Loot drop quality improved (+15% rare-item chance per level).",
        Cost        = 150,
        MaxLevel    = 2,
        Apply = function(stats, level)
            stats.LootLuck = (stats.LootLuck or 1.0) + level * 0.15
        end,
    },
    {
        Id          = "CritEdge",
        Name        = "Killer Insight",
        Category    = "Stat",
        Description = "Start every run with +3% global critical hit chance per level.",
        Cost        = 180,
        MaxLevel    = 3,
        Apply = function(stats, level)
            stats.CritChance = (stats.CritChance or 0.05) + level * 0.03
        end,
    },
    {
        Id          = "CooldownMastery",
        Name        = "Technique Mastery",
        Category    = "Stat",
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
        Category    = "Stat",
        Description = "Start every run with +50 Bounty (gold) per level.",
        Cost        = 80,
        MaxLevel    = 4,
        Apply = function(stats, level)
            stats.BonusStartGold = (stats.BonusStartGold or 0) + level * 50
        end,
    },

    -- ── TIER 2: Content unlocks ───────────────────────────────────────────
    -- These change WHAT is available, not just numbers.
    {
        Id          = "ShardMemoryBonus",
        Name        = "Shard Memory",
        Category    = "Content",
        Description = "Unlock additional Event room outcomes: Ancient Blessing and Void Whisper.",
        UnlockLore  = "You've read enough Shards to recognize the echoes they leave behind.",
        Cost        = 175,
        MaxLevel    = 1,
        Apply = function(stats, level)
            stats.UnlockShardMemoryEvents = true
        end,
    },
    {
        Id          = "CurseExpertise",
        Name        = "Curse Expertise",
        Category    = "Content",
        Description = "Sealed Chamber rooms offer a third Curse option instead of two.",
        UnlockLore  = "You've accepted enough Void bargains to recognize a good deal.",
        Cost        = 220,
        MaxLevel    = 1,
        Apply = function(stats, level)
            stats.SealedChamberExtraOption = true
        end,
    },
    {
        Id          = "BountyVeteran",
        Name        = "Coalition Veteran",
        Category    = "Content",
        Description = "Bounty Board refreshes with one guaranteed Tier 3 contract instead of weighted random.",
        UnlockLore  = "Your track record earns access to high-priority contracts.",
        Cost        = 250,
        MaxLevel    = 1,
        Apply = function(stats, level)
            stats.GuaranteedTier3Bounty = true
        end,
    },
    {
        Id          = "ShrineMastery",
        Name        = "Shrine Sensitivity",
        Category    = "Content",
        Description = "Shrines now offer 4 options instead of 3. Ancient Blessing has a reduced gold cost.",
        UnlockLore  = "Your resonance is strong enough to read the older shrines more clearly.",
        Cost        = 300,
        MaxLevel    = 1,
        Apply = function(stats, level)
            stats.ShrineExtraOption = true
            stats.AncientBlessingCostMult = 0.70   -- 30% cheaper
        end,
    },
    {
        Id          = "OriginUnlock",
        Name        = "Deep Resonance",
        Category    = "Content",
        Description = "Unlock one additional Origin per archetype (the 3rd Origin for each becomes available).",
        UnlockLore  = "You've been through enough to understand who you really are in these Shards.",
        Cost        = 400,
        MaxLevel    = 1,
        Apply = function(stats, level)
            stats.UnlockTier2Origins = true
        end,
    },
    {
        Id          = "AwakeningBoost",
        Name        = "Resonance Overflow",
        Category    = "Content",
        Description = "Awakening duration increased by 3 seconds for all archetypes.",
        UnlockLore  = "The resonance inside you has grown past what it was designed to hold.",
        Cost        = 350,
        MaxLevel    = 2,
        Apply = function(stats, level)
            stats.AwakeningDurationBonus = (stats.AwakeningDurationBonus or 0) + level * 3
        end,
    },
}

-- ────────────────────────────────────────────────
-- PLAYER DATA  (in-memory cache)
-- ────────────────────────────────────────────────

local PlayerMeta = {}   -- [player] = { MasteryPoints, TotalRuns, BestFloor, Unlocked = {[id] = level} }

local DEFAULT_META = {
    MasteryPoints  = 0,
    TotalRuns      = 0,
    BestFloor      = 0,
    Unlocked       = {},   -- { [passiveId] = level }
    -- Bounty system
    ActiveBounties    = {},  -- { [bountyId] = { progress = N } }
    CompletedBounties = {},  -- { [bountyId] = true }
    BossesDefeated    = {},  -- { [bossKey] = N }
    UnlockedOrigins   = {},  -- { [originId] = true }
    -- Achievement + cosmetic unlock tracking
    CompletedAchievements = {},  -- { [achievementKey] = true }
    -- Collectible lore fragments
    CollectedLore = {},          -- { [loreId] = true }
    -- Per-run challenge history
    CompletedChallenges = {},    -- { [challengeId] = count }
    -- Lifetime stats for leaderboard / achievements
    TotalStats = {
        TotalDamageDealt = 0,
        TotalKills       = 0,
        TotalGoldEarned  = 0,
        BossesDefeated   = 0,
        AwakenActivations = 0,
    },
    -- Personalization: last chosen starting bonus
    LastBonusId = "None",
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

-- ────────────────────────────────────────────────
-- BOUNTY SYSTEM
-- ────────────────────────────────────────────────

local BountyData = require(ReplicatedStorage.Modules.BountyData)

-- Give a player a starting set of active bounties if they have none
local function ensureBounties(meta)
    if next(meta.ActiveBounties) == nil then
        local opts = BountyData.GenerateBoardOptions()
        for _, b in ipairs(opts) do
            -- Take up to MaxActive
            local count = 0
            for _ in pairs(meta.ActiveBounties) do count = count + 1 end
            if count < BountyData.BoardConfig.MaxActive then
                meta.ActiveBounties[b.Id] = { Progress = 0 }
            end
        end
    end
end

-- Reset PerRun bounty progress at the start of each run
function MetaProgression.ResetPerRunBountyProgress(player)
    local meta = PlayerMeta[player]
    if not meta then return end
    for bountyId in pairs(meta.ActiveBounties) do
        local b = BountyData.GetById(bountyId)
        if b and b.Condition.Scope == "PerRun" then
            meta.ActiveBounties[bountyId].Progress = 0
        end
    end
end

-- Process a game event against the player's active bounties
-- eventName matches Condition.Event strings in BountyData
-- data carries context (Floor, BossKey, Gold, etc.)
function MetaProgression.TrackBountyEvent(player, eventName, data)
    local meta = PlayerMeta[player]
    if not meta then return end
    ensureBounties(meta)
    data = data or {}

    local activeBountyIds = {}
    for id in pairs(meta.ActiveBounties) do table.insert(activeBountyIds, id) end

    local matches = BountyData.CheckProgress(activeBountyIds, eventName, data)
    local completedNames = {}

    for _, match in ipairs(matches) do
        local entry = meta.ActiveBounties[match.BountyId]
        if not entry then continue end

        entry.Progress = (entry.Progress or 0) + 1

        if entry.Progress >= match.Threshold then
            -- Bounty completed
            meta.ActiveBounties[match.BountyId] = nil
            meta.CompletedBounties[match.BountyId] = true

            local b = BountyData.GetById(match.BountyId)
            if b then table.insert(completedNames, b.Name) end

            -- Award reward
            local reward = match.Reward
            if reward then
                if reward.Type == "Gold" then
                    -- Credit gold to current run state via UpdateHUD
                    UpdateHUD:FireClient(player, {
                        Gold    = reward.Amount,  -- GameManager adds this on next HUD push
                        Message = "Bounty Complete: +" .. reward.Amount .. " Bounty!",
                        Duration = 4,
                    })
                elseif reward.Type == "MasteryPoints" then
                    meta.MasteryPoints = meta.MasteryPoints + reward.Amount
                    UpdateHUD:FireClient(player, {
                        Message  = "Bounty Complete: +" .. reward.Amount .. " Mastery Points!",
                        Duration = 4,
                    })
                elseif reward.Type == "UnlockOrigin" and reward.OriginId then
                    meta.UnlockedOrigins[reward.OriginId] = true
                    UpdateHUD:FireClient(player, {
                        Message  = "Origin Unlocked: " .. reward.OriginId,
                        Duration = 5,
                    })
                end
            end

            -- Replace completed bounty with a new one from the board
            local opts = BountyData.GenerateBoardOptions()
            for _, newB in ipairs(opts) do
                if not meta.ActiveBounties[newB.Id] and not meta.CompletedBounties[newB.Id] then
                    meta.ActiveBounties[newB.Id] = { Progress = 0 }
                    break
                end
            end
        end
    end

    if #completedNames > 0 then
        saveMeta(player)
        syncToClient(player)
    end
end

-- Track total runs (call on run end/death)
function MetaProgression.TrackRunCompleted(player)
    MetaProgression.TrackBountyEvent(player, "RunCompleted", {})
end

-- ────────────────────────────────────────────────
-- ACHIEVEMENT & COSMETIC UNLOCK TRACKING
-- ────────────────────────────────────────────────

-- Mark an achievement as completed; triggers CosmeticsSystem notification.
function MetaProgression.TrackAchievement(player, achievementKey)
    local meta = PlayerMeta[player]
    if not meta then return end
    if meta.CompletedAchievements[achievementKey] then return end  -- already unlocked
    meta.CompletedAchievements[achievementKey] = true
    saveMeta(player)
    syncToClient(player)
    -- Let CosmeticsSystem know so it can re-sync
    local ok, CosmeticsSystem = pcall(require, script.Parent.CosmeticsSystem)
    if ok and CosmeticsSystem and CosmeticsSystem.OnAchievementUnlocked then
        CosmeticsSystem.OnAchievementUnlocked(player, achievementKey)
    end
end

-- ────────────────────────────────────────────────
-- LORE FRAGMENT COLLECTION
-- ────────────────────────────────────────────────

function MetaProgression.CollectLore(player, loreId)
    local meta = PlayerMeta[player]
    if not meta then return false end
    if meta.CollectedLore[loreId] then return false end  -- already collected
    meta.CollectedLore[loreId] = true
    saveMeta(player)
    if UpdateHUD then
        UpdateHUD:FireClient(player, {
            Message  = "📖 Lore Fragment Collected!",
            SubText  = "Check the Codex in the lobby.",
            Duration = 4,
            Color    = Color3.fromRGB(200, 160, 255),
        })
    end
    -- Track achievement if all fragments in a theme collected (check elsewhere)
    syncToClient(player)
    return true
end

function MetaProgression.GetCollectedLore(player)
    local meta = PlayerMeta[player]
    return meta and meta.CollectedLore or {}
end

-- ────────────────────────────────────────────────
-- LIFETIME STATS TRACKING
-- ────────────────────────────────────────────────

function MetaProgression.TrackStats(player, statsToAdd)
    local meta = PlayerMeta[player]
    if not meta then return end
    local ts = meta.TotalStats
    for k, v in pairs(statsToAdd) do
        ts[k] = (ts[k] or 0) + v
    end
    -- Trigger achievements based on milestones
    if ts.TotalKills >= 100 and not meta.CompletedAchievements["VoidStacks20"] then
        MetaProgression.TrackAchievement(player, "VoidStacks20")
    end
    if ts.BossesDefeated >= 1 and not meta.CompletedAchievements["ClearShadowGate"] then
        -- actual ShadowGate check is done in GameManager; this is a fallback
    end
end

-- ────────────────────────────────────────────────
-- CHALLENGE COMPLETION TRACKING
-- ────────────────────────────────────────────────

function MetaProgression.RecordChallengeComplete(player, challengeId)
    local meta = PlayerMeta[player]
    if not meta then return end
    meta.CompletedChallenges[challengeId] = (meta.CompletedChallenges[challengeId] or 0) + 1
    saveMeta(player)
end

-- ────────────────────────────────────────────────
-- STATE ACCESS (for CosmeticsSystem, ChallengeTracker)
-- ────────────────────────────────────────────────

function MetaProgression.GetState(player)
    return PlayerMeta[player]
end

print("[MetaProgression] Loaded.")

return MetaProgression
