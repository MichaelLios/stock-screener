-- BountyData.lua
-- Bounty board / mission system.  Gives players short-term goals across runs,
-- rewarding mastery points, gold, exclusive items, or ability scrolls.
--
-- Bounties are persistent (survive multiple runs) until completed.
-- Players hold at most 3 active bounties simultaneously.
-- The board refreshes 3 new options after each run (completed or not).
--
-- Integration:
--   MetaProgression tracks BountyProgress in the saved data block.
--   GameManager checks BountyData.CheckProgress(player, event) after key game events.
--   UI reads BountyData.GetActiveBounties(player) to display the board.

local BountyData = {}

-- ──────────────────────────────────────────────────────────────────────────
-- BOUNTY DEFINITIONS
-- ──────────────────────────────────────────────────────────────────────────
-- Each bounty has:
--   Id, Name, Description, Tier (1=easy, 2=medium, 3=hard, 4=legendary)
--   Condition: { Event, Threshold, ... }  — what GameManager checks
--   Reward: { Type, ... }

BountyData.Bounties = {

    -- ── TIER 1: Easy ──────────────────────────────────────────────────────

    {
        Id          = "FirstBlood",
        Name        = "First Blood",
        Tier        = 1,
        Description = "Defeat 10 enemies in a single run.",
        Condition   = { Event = "EnemyKilled", Threshold = 10, Scope = "PerRun" },
        Reward      = { Type = "Gold", Amount = 80 },
        FlavorText  = "Everyone starts somewhere.",
    },
    {
        Id          = "ShardRunner",
        Name        = "Shard Runner",
        Tier        = 1,
        Description = "Reach Floor 3 in a single run.",
        Condition   = { Event = "FloorReached", Threshold = 3, Scope = "PerRun" },
        Reward      = { Type = "MasteryPoints", Amount = 30 },
        FlavorText  = "The Waypoint notes your progress.",
    },
    {
        Id          = "EliteSurvivor",
        Name        = "Elite Survivor",
        Tier        = 1,
        Description = "Clear an Elite room without using any potions.",
        Condition   = { Event = "EliteRoomClearedNoPotions", Threshold = 1, Scope = "PerRun" },
        Reward      = { Type = "Gold", Amount = 120 },
        FlavorText  = "Divers who survive on skill alone earn respect.",
    },
    {
        Id          = "ShopLocal",
        Name        = "Support Local Business",
        Tier        = 1,
        Description = "Buy an item from a shop during a run.",
        Condition   = { Event = "ItemBought", Threshold = 1, Scope = "PerRun" },
        Reward      = { Type = "Gold", Amount = 60 },
        FlavorText  = "Nami says thank you.  She means the gold.",
    },
    {
        Id          = "AwakeningBaptism",
        Name        = "First Awakening",
        Tier        = 1,
        Description = "Activate your Awakening for the first time.",
        Condition   = { Event = "AwakeningActivated", Threshold = 1, Scope = "Lifetime" },
        Reward      = { Type = "MasteryPoints", Amount = 50 },
        FlavorText  = "The resonance inside you finally answered.",
    },

    -- ── TIER 2: Medium ────────────────────────────────────────────────────

    {
        Id          = "BossHunter",
        Name        = "Boss Hunter",
        Tier        = 2,
        Description = "Defeat 3 Anchors (bosses) across any number of runs.",
        Condition   = { Event = "BossDefeated", Threshold = 3, Scope = "Lifetime" },
        Reward      = { Type = "MasteryPoints", Amount = 80 },
        FlavorText  = "The Coalition is starting to take you seriously.",
    },
    {
        Id          = "ClearSpeedrun",
        Name        = "Clean Sweep",
        Tier        = 2,
        Description = "Clear all combat rooms on a floor without entering a Rest room.",
        Condition   = { Event = "FloorClearedNoRest", Threshold = 1, Scope = "PerRun" },
        Reward      = { Type = "ItemScroll", AbilityName = "HealingSpring" },
        FlavorText  = "Rest is for after.  The Shard doesn't take breaks.",
    },
    {
        Id          = "SynergyScholar",
        Name        = "Synergy Scholar",
        Tier        = 2,
        Description = "Trigger a synergy bonus 5 times in a single run.",
        Condition   = { Event = "SynergyTriggered", Threshold = 5, Scope = "PerRun" },
        Reward      = { Type = "Gold", Amount = 200 },
        FlavorText  = "The right combination of power creates something greater.",
    },
    {
        Id          = "UndyingWill",
        Name        = "Undying Will",
        Tier        = 2,
        Description = "Reach Floor 5 without dying.",
        Condition   = { Event = "FloorReachedNoDeath", Threshold = 5, Scope = "PerRun" },
        Reward      = { Type = "MasteryPoints", Amount = 100 },
        FlavorText  = "Five floors, no tombstone.  The Oracle takes notice.",
    },
    {
        Id          = "CorruptionTolerant",
        Name        = "Void-Tempered",
        Tier        = 2,
        Description = "Accept a Curse and complete a floor while under its effects.",
        Condition   = { Event = "FloorClearedWhileCursed", Threshold = 1, Scope = "PerRun" },
        Reward      = { Type = "Gold", Amount = 250 },
        FlavorText  = "The Void tried to slow you down.  You adapted.",
    },
    {
        Id          = "AmbushSpecialist",
        Name        = "Ambush Specialist",
        Tier        = 2,
        Description = "Clear 5 Ambush rooms across any number of runs.",
        Condition   = { Event = "AmbushRoomCleared", Threshold = 5, Scope = "Lifetime" },
        Reward      = { Type = "MasteryPoints", Amount = 75 },
        FlavorText  = "You've stopped flinching when the second wave hits.",
    },

    -- ── TIER 3: Hard ──────────────────────────────────────────────────────

    {
        Id          = "DeepDiver",
        Name        = "Deep Diver",
        Tier        = 3,
        Description = "Reach Floor 10 in a single run.",
        Condition   = { Event = "FloorReached", Threshold = 10, Scope = "PerRun" },
        Reward      = { Type = "MasteryPoints", Amount = 200 },
        FlavorText  = "Two full Shard cycles.  The Waypoint opens new portals for you.",
    },
    {
        Id          = "FlawlessAnchor",
        Name        = "Flawless Anchor Kill",
        Tier        = 3,
        Description = "Defeat a boss without taking damage during the fight.",
        Condition   = { Event = "BossDefeatedNoDamage", Threshold = 1, Scope = "PerRun" },
        Reward      = { Type = "ItemScroll", AbilityName = "UltimateKamehameha" },
        FlavorText  = "Perfect execution.  The boss never had a chance.",
    },
    {
        Id          = "AwakenThrice",
        Name        = "Resonance Overload",
        Tier        = 3,
        Description = "Activate your Awakening 3 times in a single run.",
        Condition   = { Event = "AwakeningActivated", Threshold = 3, Scope = "PerRun" },
        Reward      = { Type = "MasteryPoints", Amount = 150 },
        FlavorText  = "The resonance saturates you.  Something about you has permanently shifted.",
    },
    {
        Id          = "GoldHoarder",
        Name        = "Bounty Hoarder",
        Tier        = 3,
        Description = "Exit a run with more than 500 gold (unspent).",
        Condition   = { Event = "RunEndedWithGold", Threshold = 500, Scope = "PerRun" },
        Reward      = { Type = "MasteryPoints", Amount = 120 },
        FlavorText  = "Nami is furious.  The Board is impressed.",
    },

    -- ── TIER 4: Legendary ─────────────────────────────────────────────────

    {
        Id          = "ShardVeteran",
        Name        = "Shard Veteran",
        Tier        = 4,
        Description = "Complete 25 total runs (any outcome).",
        Condition   = { Event = "RunCompleted", Threshold = 25, Scope = "Lifetime" },
        Reward      = { Type = "UnlockOrigin", OriginId = "VoidTouched" },  -- see OriginData
        FlavorText  = "Twenty-five dives.  The Void has seen your face more than once.  It's starting to remember you.",
    },
    {
        Id          = "AllAnchors",
        Name        = "Anchor Collector",
        Tier        = 4,
        Description = "Defeat all 5 unique Anchors at least once.",
        Condition   = { Event = "AllBossesDefeated", Threshold = 1, Scope = "Lifetime" },
        Reward      = { Type = "UnlockOrigin", OriginId = "AnchorBreaker" },
        FlavorText  = "You've met every corruption source in the Shard cycle.  Every one of them fell.",
    },
    {
        Id          = "CursedLegend",
        Name        = "Cursed Legend",
        Tier        = 4,
        Description = "Complete a full run (reach and defeat the boss on every floor) with an active Curse.",
        Condition   = { Event = "FullRunWithCurse", Threshold = 1, Scope = "PerRun" },
        Reward      = { Type = "MasteryPoints", Amount = 400 },
        FlavorText  = "The Void offered you a handicap.  You turned it into a weapon.",
    },
}

-- ──────────────────────────────────────────────────────────────────────────
-- BOARD DISPLAY CONFIG
-- ──────────────────────────────────────────────────────────────────────────

BountyData.BoardConfig = {
    MaxActive        = 3,       -- player holds 3 bounties at a time
    RefreshOnRunEnd  = true,    -- board offers new options after each run
    TierColors = {
        [1] = Color3.fromRGB(200, 200, 200),   -- grey: easy
        [2] = Color3.fromRGB(80, 200, 80),     -- green: medium
        [3] = Color3.fromRGB(100, 150, 255),   -- blue: hard
        [4] = Color3.fromRGB(255, 165, 0),     -- orange: legendary
    },
    TierLabels = {
        [1] = "Routine",
        [2] = "Notable",
        [3] = "Dangerous",
        [4] = "Legendary",
    },
}

-- ──────────────────────────────────────────────────────────────────────────
-- API
-- ──────────────────────────────────────────────────────────────────────────

-- Returns all bounties of a given tier
function BountyData.GetByTier(tier)
    local results = {}
    for _, b in ipairs(BountyData.Bounties) do
        if b.Tier == tier then table.insert(results, b) end
    end
    return results
end

-- Returns a bounty by Id
function BountyData.GetById(id)
    for _, b in ipairs(BountyData.Bounties) do
        if b.Id == id then return b end
    end
    return nil
end

-- Generate a fresh board: weighted toward lower tiers, with at least 1 tier 2+
-- Returns an array of 4 bounty definitions for the player to pick 3 from
function BountyData.GenerateBoardOptions()
    local pool = {}
    -- Weight: tier 1 = 40%, tier 2 = 35%, tier 3 = 20%, tier 4 = 5%
    local weights = { [1] = 40, [2] = 35, [3] = 20, [4] = 5 }
    for _, b in ipairs(BountyData.Bounties) do
        local w = weights[b.Tier] or 0
        for _ = 1, w do table.insert(pool, b) end
    end

    -- Shuffle and pick 4 unique bounties
    local picked = {}
    local seen = {}
    local tries = 0
    while #picked < 4 and tries < 200 do
        tries = tries + 1
        local idx = math.random(#pool)
        local b = pool[idx]
        if not seen[b.Id] then
            seen[b.Id] = true
            table.insert(picked, b)
        end
    end
    return picked
end

-- Check whether a game event advances or completes any active bounty for a player.
-- Returns an array of { BountyId, Completed, NewProgress } for each affected bounty.
-- GameManager calls this after relevant events.
function BountyData.CheckProgress(activeBountyIds, eventName, eventData)
    local results = {}
    for _, bountyId in ipairs(activeBountyIds) do
        local bounty = BountyData.GetById(bountyId)
        if bounty and bounty.Condition.Event == eventName then
            -- Return which bounty matched so MetaProgression can update counters
            table.insert(results, {
                BountyId  = bountyId,
                Threshold = bounty.Condition.Threshold,
                Scope     = bounty.Condition.Scope,
                Reward    = bounty.Reward,
            })
        end
    end
    return results
end

return BountyData
