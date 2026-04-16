-- CharacterStats.lua
-- Manages player base stats and scaling. Anime-style power system.

local CharacterStats = {}

-- Archetypes inspired by anime character roles
CharacterStats.Archetypes = {
    Swordsman = {
        DisplayName = "Swordsman",
        Description = "A blade-focused warrior with high physical damage and mobility.",
        BaseHP = 120,
        BaseMP = 60,
        BaseAtk = 14,
        BaseDef = 8,
        BaseSpd = 12,
        HPPerLevel = 18,
        MPPerLevel = 6,
        AtkPerLevel = 3,
        DefPerLevel = 2,
        SpdPerLevel = 1,
        StartingAbilities = { "BasicSlash", "QuickDash", "BladeTornado" },
        AbilityPool = { "ThunderClap", "SkywardSlash", "CounterStance", "HealingSpring" },
        PassiveBonus = "CriticalEdge", -- 15% bonus crit chance
        BaseCritChance = 0.15,  -- CriticalEdge: highest base crit of all archetypes
        BaseCritMult   = 1.9,
        Color = Color3.fromRGB(200, 50, 50),
    },
    Mage = {
        DisplayName = "Mage",
        Description = "A powerful caster that harnesses elemental and spiritual energy.",
        BaseHP = 80,
        BaseMP = 140,
        BaseAtk = 18,
        BaseDef = 5,
        BaseSpd = 9,
        HPPerLevel = 10,
        MPPerLevel = 20,
        AtkPerLevel = 4,
        DefPerLevel = 1,
        SpdPerLevel = 1,
        StartingAbilities = { "MagicBolt", "ManaShield", "ElementalBurst" },
        AbilityPool = { "FrostNova", "ArcaneOrb", "HealingSpring", "UltimateKamehameha" },
        PassiveBonus = "ArcaneAmplify", -- spells deal 20% more damage
        BaseCritChance = 0.06,
        BaseCritMult   = 1.8,
        Color = Color3.fromRGB(80, 80, 220),
    },
    Brawler = {
        DisplayName = "Brawler",
        Description = "A tank fighter who hits hard and takes punishment.",
        BaseHP = 160,
        BaseMP = 40,
        BaseAtk = 12,
        BaseDef = 14,
        BaseSpd = 8,
        HPPerLevel = 25,
        MPPerLevel = 4,
        AtkPerLevel = 2,
        DefPerLevel = 3,
        SpdPerLevel = 1,
        StartingAbilities = { "HeavyPunch", "Taunt", "RagingRush" },
        AbilityPool = { "GroundSlam", "IronDefense", "HealingSpring", "ThunderClap" },
        PassiveBonus = "IronBody", -- 20% damage reduction when below 50% HP
        BaseCritChance = 0.05,  -- rare crits, but they hit like a truck
        BaseCritMult   = 2.2,
        Color = Color3.fromRGB(220, 140, 40),
    },
    Assassin = {
        DisplayName = "Assassin",
        Description = "A swift shadow-arts user. Kills fast, dies fast.",
        BaseHP = 90,
        BaseMP = 80,
        BaseAtk = 16,
        BaseDef = 6,
        BaseSpd = 18,
        HPPerLevel = 12,
        MPPerLevel = 10,
        AtkPerLevel = 3,
        DefPerLevel = 1,
        SpdPerLevel = 2,
        StartingAbilities = { "ShadowStep", "PoisonBlade", "DeathMark" },
        AbilityPool = { "SmokeBomb", "VenomStrike", "QuickDash", "UltimateKamehameha" },
        PassiveBonus = "NightVeil", -- first hit of combat deals 2x damage
        BaseCritChance = 0.22,  -- highest crit rate; fits burst playstyle
        BaseCritMult   = 2.2,
        Color = Color3.fromRGB(80, 20, 80),
    },
    SpiritUser = {
        DisplayName = "Spirit User",
        Description = "Channels spirit energy (reiatsu/chakra) for devastating techniques.",
        BaseHP = 100,
        BaseMP = 120,
        BaseAtk = 15,
        BaseDef = 7,
        BaseSpd = 11,
        HPPerLevel = 15,
        MPPerLevel = 16,
        AtkPerLevel = 3,
        DefPerLevel = 2,
        SpdPerLevel = 1,
        StartingAbilities = { "SpiritBlast", "AuraWall", "BankaiFrenzy" },
        AbilityPool = { "SoulDrain", "ChakraStrike", "HealingSpring", "UltimateKamehameha" },
        PassiveBonus = "SpiritSurge", -- abilities restore HP equal to 10% of damage dealt
        BaseCritChance = 0.10,
        BaseCritMult   = 1.8,
        Color = Color3.fromRGB(100, 220, 200),
    },
}

-- Build a stat block for a player at a given level
function CharacterStats.BuildStats(archetypeName, level)
    local arch = CharacterStats.Archetypes[archetypeName]
    assert(arch, "Unknown archetype: " .. tostring(archetypeName))
    level = math.max(1, level)
    local lvl = level - 1
    return {
        Archetype    = archetypeName,
        Level        = level,
        MaxHP        = arch.BaseHP + arch.HPPerLevel * lvl,
        MaxMP        = arch.BaseMP + arch.MPPerLevel * lvl,
        Atk          = arch.BaseAtk + arch.AtkPerLevel * lvl,
        Def          = arch.BaseDef + arch.DefPerLevel * lvl,
        Spd          = arch.BaseSpd + arch.SpdPerLevel * lvl,
        PassiveBonus = arch.PassiveBonus,
        Abilities    = table.clone(arch.StartingAbilities),
        -- Combat feel stats (augmented by run upgrades at runtime)
        CritChance   = arch.BaseCritChance or 0.05,
        CritMult     = arch.BaseCritMult   or 1.8,
    }
end

-- XP needed to reach next level (scales exponentially)
function CharacterStats.XPForLevel(level)
    return math.floor(100 * (level ^ 1.6))
end

-- Calculate damage after defense mitigation
function CharacterStats.CalcDamage(rawAtk, targetDef)
    local mitigation = targetDef / (targetDef + 50)
    return math.max(1, math.floor(rawAtk * (1 - mitigation)))
end

return CharacterStats
