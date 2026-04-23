-- CosmeticsData.lua
-- Defines all unlockable cosmetic items: auras, titles, and weapon trails.
-- Unlock requirements reference MetaProgression achievement keys or run milestones.

local CosmeticsData = {}

-- ────────────────────────────────────────────────
-- AURAS
-- Each aura wraps the player in a SelectionBox + PointLight + ParticleEmitter.
-- Color      = aura color
-- LightRange = PointLight range (studs)
-- Style      = "wisp" | "flame" | "void" | "crystal" | "storm" (interpreted by CosmeticsSystem)
-- Requirement = human-readable unlock description
-- ────────────────────────────────────────────────

CosmeticsData.Auras = {
    None = {
        DisplayName = "None",
        Color       = Color3.new(0, 0, 0),
        Style       = "none",
        Requirement = "Default — always available",
        Free        = true,
    },
    SilverEdge = {
        DisplayName = "Silver Edge",
        Color       = Color3.fromRGB(200, 220, 255),
        LightRange  = 14,
        Style       = "wisp",
        Requirement = "Complete your first run",
        AchievementKey = "FirstRunComplete",
    },
    FlameSoul = {
        DisplayName = "Flame Soul",
        Color       = Color3.fromRGB(255, 80, 20),
        LightRange  = 20,
        Style       = "flame",
        Requirement = "Reach Floor 10 in a single run",
        AchievementKey = "ReachFloor10",
    },
    VoidWalker = {
        DisplayName = "Void Walker",
        Color       = Color3.fromRGB(140, 30, 255),
        LightRange  = 22,
        Style       = "void",
        Requirement = "Clear the Shadow Gate dungeon",
        AchievementKey = "ClearShadowGate",
    },
    StormCrown = {
        DisplayName = "Storm Crown",
        Color       = Color3.fromRGB(120, 210, 255),
        LightRange  = 18,
        Style       = "storm",
        Requirement = "Land 50 Lightning-type hits in one run",
        AchievementKey = "LightningHits50",
    },
    BankaiFlare = {
        DisplayName = "Bankai Flare",
        Color       = Color3.fromRGB(255, 200, 50),
        LightRange  = 26,
        Style       = "flame",
        Requirement = "Activate Bankai Frenzy 20 times across all runs",
        AchievementKey = "BankaiActivations20",
    },
    AbyssalTide = {
        DisplayName = "Abyssal Tide",
        Color       = Color3.fromRGB(30, 200, 180),
        LightRange  = 18,
        Style       = "crystal",
        Requirement = "Complete the Drowned Kingdom dungeon 3 times",
        AchievementKey = "DrownedKingdom3Clears",
    },
    ShadowMonarch = {
        DisplayName = "Shadow Monarch",
        Color       = Color3.fromRGB(100, 0, 200),
        LightRange  = 30,
        Style       = "void",
        Requirement = "Achieve a 100-hit combo in a single run",
        AchievementKey = "Combo100",
        Legendary   = true,
    },
    CosmicFlux = {
        DisplayName = "Cosmic Flux",
        Color       = Color3.fromRGB(255, 120, 255),
        LightRange  = 32,
        Style       = "storm",
        Requirement = "Complete 10 full runs",
        AchievementKey = "TenRunsComplete",
        Legendary   = true,
    },
}

-- ────────────────────────────────────────────────
-- TITLES
-- Displayed above the player's head via BillboardGui.
-- ────────────────────────────────────────────────

CosmeticsData.Titles = {
    Newcomer = {
        DisplayName    = "Newcomer",
        Color          = Color3.fromRGB(200, 200, 200),
        Requirement    = "Default",
        Free           = true,
    },
    Pirate = {
        DisplayName    = "Pirate",
        Color          = Color3.fromRGB(220, 140, 40),
        Requirement    = "Complete your first run",
        AchievementKey = "FirstRunComplete",
    },
    ShadowHunter = {
        DisplayName    = "Shadow Hunter",
        Color          = Color3.fromRGB(160, 60, 255),
        Requirement    = "Defeat the Shadow Gate boss",
        AchievementKey = "ClearShadowGate",
    },
    StormKing = {
        DisplayName    = "Storm King",
        Color          = Color3.fromRGB(140, 220, 255),
        Requirement    = "Activate the Storm King synergy",
        AchievementKey = "ActivateStormKing",
    },
    BankaiMaster = {
        DisplayName    = "Bankai Master",
        Color          = Color3.fromRGB(255, 220, 80),
        Requirement    = "Max out Bankai Frenzy to Stage 2",
        AchievementKey = "BankaiStage2",
    },
    TheVoid = {
        DisplayName    = "The Void",
        Color          = Color3.fromRGB(90, 0, 180),
        Requirement    = "Stack 20 Void stacks in a single run",
        AchievementKey = "VoidStacks20",
        Legendary      = true,
    },
    Deathbringer = {
        DisplayName    = "Death Bringer",
        Color          = Color3.fromRGB(140, 200, 20),
        Requirement    = "Activate the Death Bringer synergy",
        AchievementKey = "ActivateDeathBringer",
    },
    Undefeated = {
        DisplayName    = "Undefeated",
        Color          = Color3.fromRGB(255, 215, 0),
        Requirement    = "Complete 5 full runs without dying",
        AchievementKey = "FiveDeathlessRuns",
        Legendary      = true,
    },
}

-- ────────────────────────────────────────────────
-- WEAPON TRAILS
-- Visual trail that follows the player's active weapon/hand during combat.
-- Color, Width (studs), Duration (seconds), Style
-- ────────────────────────────────────────────────

CosmeticsData.Trails = {
    None = {
        DisplayName = "None",
        Free        = true,
    },
    SlashTrail = {
        DisplayName    = "Slash Trail",
        Color          = Color3.fromRGB(255, 240, 160),
        Width          = 0.35,
        Duration       = 0.18,
        Requirement    = "Complete your first run",
        AchievementKey = "FirstRunComplete",
    },
    FlameTrail = {
        DisplayName    = "Flame Trail",
        Color          = Color3.fromRGB(255, 90, 20),
        Width          = 0.55,
        Duration       = 0.28,
        Requirement    = "Reach Floor 10",
        AchievementKey = "ReachFloor10",
    },
    VoidTrail = {
        DisplayName    = "Void Trail",
        Color          = Color3.fromRGB(160, 40, 255),
        Width          = 0.65,
        Duration       = 0.35,
        Requirement    = "Clear the Shadow Gate",
        AchievementKey = "ClearShadowGate",
    },
    IceTrail = {
        DisplayName    = "Ice Trail",
        Color          = Color3.fromRGB(160, 230, 255),
        Width          = 0.45,
        Duration       = 0.22,
        Requirement    = "Clear the Glacial Keep dungeon",
        AchievementKey = "ClearGlacialKeep",
    },
    GoldenTrail = {
        DisplayName    = "Golden Trail",
        Color          = Color3.fromRGB(255, 215, 0),
        Width          = 0.8,
        Duration       = 0.40,
        Requirement    = "Complete 10 full runs",
        AchievementKey = "TenRunsComplete",
        Legendary      = true,
    },
}

-- ────────────────────────────────────────────────
-- Utility: check if a player has unlocked a cosmetic
-- (delegates to MetaProgression achievements in the full implementation)
-- ────────────────────────────────────────────────

function CosmeticsData.IsUnlocked(player, cosmeticType, cosmeticKey, metaState)
    local tbl = CosmeticsData[cosmeticType]
    if not tbl then return false end
    local entry = tbl[cosmeticKey]
    if not entry then return false end
    if entry.Free then return true end
    if not entry.AchievementKey then return false end
    -- Check MetaProgression achievement completion
    if metaState and metaState.CompletedAchievements then
        return metaState.CompletedAchievements[entry.AchievementKey] == true
    end
    return false
end

return CosmeticsData
