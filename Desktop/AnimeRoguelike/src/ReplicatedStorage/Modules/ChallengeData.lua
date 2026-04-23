-- ChallengeData.lua
-- Defines per-run optional challenges players can activate at run start.
-- Challenges track conditions during the run and award exclusive rewards on success.
-- Players can activate up to 2 simultaneous challenges per run.

local ChallengeData = {}

ChallengeData.MaxActiveChallenges = 2

-- ────────────────────────────────────────────────
-- CHALLENGE DEFINITIONS
-- ────────────────────────────────────────────────
-- Condition.Type: "NoDeaths", "KillCount", "MinFloor", "NoShop", "NoRest",
--                "NoDamageTakenRooms", "MaxAbilitySlots", "FloorSpeedClear",
--                "BossNoDamage", "SingleAbility"
-- Condition.Threshold: numeric target if applicable
-- Reward.Type: "Cosmetic", "MasteryPoints", "ItemPool", "StatBonus"

ChallengeData.Challenges = {

    -- ── BEGINNER ──────────────────────────────────────────────────────────
    {
        Id          = "Survivor",
        Name        = "Survivor",
        Tier        = 1,
        Color       = Color3.fromRGB(100, 220, 80),
        Description = "Complete a run without dying.",
        Condition   = { Type = "NoDeaths", Threshold = 0 },
        Reward      = {
            Type          = "MasteryPoints",
            Amount        = 150,
            DisplayText   = "+150 Mastery Points",
        },
        AchievementKey = "FirstRunComplete",
    },

    {
        Id          = "Frugal",
        Name        = "Frugal",
        Tier        = 1,
        Color       = Color3.fromRGB(255, 215, 0),
        Description = "Complete a run spending zero gold at any Shop.",
        Condition   = { Type = "NoShop" },
        Reward      = {
            Type        = "MasteryPoints",
            Amount      = 100,
            DisplayText = "+100 Mastery Points",
        },
    },

    {
        Id          = "Relentless",
        Name        = "Relentless",
        Tier        = 1,
        Color       = Color3.fromRGB(255, 140, 50),
        Description = "Clear 20 enemies in a single run.",
        Condition   = { Type = "KillCount", Threshold = 20 },
        Reward      = {
            Type        = "MasteryPoints",
            Amount      = 80,
            DisplayText = "+80 Mastery Points",
        },
    },

    -- ── INTERMEDIATE ──────────────────────────────────────────────────────
    {
        Id          = "Ascetic",
        Name        = "Ascetic",
        Tier        = 2,
        Color       = Color3.fromRGB(180, 100, 255),
        Description = "Complete a run without using any Rest rooms.",
        Condition   = { Type = "NoRest" },
        Reward      = {
            Type          = "MasteryPoints",
            Amount        = 180,
            DisplayText   = "+180 Mastery Points",
        },
    },

    {
        Id          = "Focused",
        Name        = "Focused",
        Tier        = 2,
        Color       = Color3.fromRGB(100, 180, 255),
        Description = "Complete a run with only 2 ability slots filled (the other 3 must stay empty).",
        Condition   = { Type = "MaxAbilitySlots", Threshold = 2 },
        Reward      = {
            Type        = "Cosmetic",
            Key         = "SlashTrail",
            CosType     = "Trails",
            DisplayText = "Unlocks: Slash Trail",
        },
        AchievementKey = "FirstRunComplete",
    },

    {
        Id          = "NoDamageStreak",
        Name        = "Ghost",
        Tier        = 2,
        Color       = Color3.fromRGB(200, 200, 220),
        Description = "Clear 3 consecutive Combat rooms without taking any damage.",
        Condition   = { Type = "NoDamageTakenRooms", Threshold = 3 },
        Reward      = {
            Type        = "MasteryPoints",
            Amount      = 200,
            DisplayText = "+200 Mastery Points",
        },
    },

    {
        Id          = "FloorRacer",
        Name        = "Floor Racer",
        Tier        = 2,
        Color       = Color3.fromRGB(255, 240, 60),
        Description = "Complete Floor 3 clearing every Combat room in under 90 seconds total.",
        Condition   = { Type = "FloorSpeedClear", Floor = 3, TimeLimitSeconds = 90 },
        Reward      = {
            Type        = "Cosmetic",
            Key         = "StormCrown",
            CosType     = "Auras",
            DisplayText = "Unlocks: Storm Crown Aura",
        },
        AchievementKey = "LightningHits50",
    },

    -- ── ADVANCED ──────────────────────────────────────────────────────────
    {
        Id          = "IronWill",
        Name        = "Iron Will",
        Tier        = 3,
        Color       = Color3.fromRGB(180, 50, 50),
        Description = "Reach Floor 5 without dying and without using any Rest rooms.",
        Condition   = { Type = "NoDeaths", ExtraConditions = { Type = "NoRest" }, MinFloor = 5 },
        Reward      = {
            Type        = "Cosmetic",
            Key         = "FlameSoul",
            CosType     = "Auras",
            DisplayText = "Unlocks: Flame Soul Aura",
        },
        AchievementKey = "ReachFloor10",
    },

    {
        Id          = "BossNoDamage",
        Name        = "Untouchable",
        Tier        = 3,
        Color       = Color3.fromRGB(255, 220, 50),
        Description = "Defeat any Boss without taking damage during the boss fight.",
        Condition   = { Type = "BossNoDamage" },
        Reward      = {
            Type        = "Cosmetic",
            Key         = "Undefeated",
            CosType     = "Titles",
            DisplayText = "Unlocks: Title — Undefeated",
        },
        AchievementKey = "FiveDeathlessRuns",
    },

    {
        Id          = "MasterSlayer",
        Name        = "Master Slayer",
        Tier        = 3,
        Color       = Color3.fromRGB(220, 60, 255),
        Description = "Clear 50 enemies in a single run.",
        Condition   = { Type = "KillCount", Threshold = 50 },
        Reward      = {
            Type        = "MasteryPoints",
            Amount      = 350,
            DisplayText = "+350 Mastery Points",
        },
    },

    -- ── LEGENDARY ─────────────────────────────────────────────────────────
    {
        Id          = "PerfectRun",
        Name        = "Perfect Run",
        Tier        = 4,
        Color       = Color3.fromRGB(255, 215, 0),
        Description = "LEGENDARY — Complete a full run (Floor 5 boss defeated) without dying or taking damage in any Boss fight.",
        Condition   = { Type = "NoDeaths", ExtraConditions = { Type = "BossNoDamage" }, MinFloor = 5, BossCount = 1 },
        Reward      = {
            Type        = "Cosmetic",
            Key         = "ShadowMonarch",
            CosType     = "Auras",
            DisplayText = "Unlocks: Shadow Monarch Aura (LEGENDARY)",
        },
        AchievementKey = "FiveDeathlessRuns",
        Legendary   = true,
    },

    {
        Id          = "SoloAbility",
        Name        = "One Truth",
        Tier        = 4,
        Color       = Color3.fromRGB(200, 50, 255),
        Description = "LEGENDARY — Complete a full run using only 1 ability slot (the other 4 must stay empty).",
        Condition   = { Type = "MaxAbilitySlots", Threshold = 1, MinFloor = 5 },
        Reward      = {
            Type        = "MasteryPoints",
            Amount      = 500,
            DisplayText = "+500 Mastery Points",
        },
        AchievementKey = "TenRunsComplete",
        Legendary   = true,
    },
}

-- ────────────────────────────────────────────────
-- UTILITY
-- ────────────────────────────────────────────────

function ChallengeData.GetById(id)
    for _, c in ipairs(ChallengeData.Challenges) do
        if c.Id == id then return c end
    end
    return nil
end

function ChallengeData.GetByTier(tier)
    local results = {}
    for _, c in ipairs(ChallengeData.Challenges) do
        if c.Tier == tier then table.insert(results, c) end
    end
    return results
end

return ChallengeData
