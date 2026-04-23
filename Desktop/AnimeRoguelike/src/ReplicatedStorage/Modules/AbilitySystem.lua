-- AbilitySystem.lua
-- Defines all anime-inspired abilities, their costs, effects, and cooldowns.

local AbilitySystem = {}

-- Effect types handled by CombatSystem on the server
local ET = {
    Damage       = "Damage",
    Heal         = "Heal",
    AOE          = "AOE",
    Knockback    = "Knockback",
    Buff         = "Buff",
    Debuff       = "Debuff",
    Teleport     = "Teleport",
    Summon       = "Summon",
}

AbilitySystem.Abilities = {
    -- ===================== SWORDSMAN =====================
    BasicSlash = {
        Name = "Basic Slash",
        Description = "A swift sword swing dealing physical damage.",
        Icon = "rbxassetid://0",
        MPCost = 0,
        Cooldown = 0,
        Range = 8,
        Effects = {
            { Type = ET.Damage, Multiplier = 1.0, DamageType = "Physical" },
        },
        Animation = "SwordSlash",
        VFX = "SlashVFX",
    },
    QuickDash = {
        Name = "Quick Dash",
        Description = "Dash forward, passing through enemies and dealing light damage.",
        Icon = "rbxassetid://0",
        MPCost = 15,
        Cooldown = 2,
        Range = 20,
        Effects = {
            { Type = ET.Teleport, Distance = 20 },
            { Type = ET.Damage, Multiplier = 0.6, DamageType = "Physical", HitOnPath = true },
        },
        Animation = "DashForward",
        VFX = "DashTrailVFX",
    },
    BladeTornado = {
        Name = "Blade Tornado",
        Description = "Spin rapidly creating a vortex of slashes around you.",
        Icon = "rbxassetid://0",
        MPCost = 30,
        Cooldown = 4,
        Range = 12,
        Effects = {
            { Type = ET.AOE, Radius = 12, Damage = true, Multiplier = 1.4, DamageType = "Physical" },
            { Type = ET.Knockback, Force = 40 },
        },
        Animation = "SpinAttack",
        VFX = "TornadoVFX",
    },
    ThunderClap = {
        Name = "Thunder Clap",
        Description = "Breathing Technique — Thunder: a lightning-fast slash that stuns.",
        Icon = "rbxassetid://0",
        MPCost = 45,
        Cooldown = 5,
        Range = 15,
        Effects = {
            { Type = ET.Damage, Multiplier = 2.2, DamageType = "Lightning" },
            { Type = ET.Debuff, Debuff = "Stun", Duration = 2 },
        },
        Animation = "ThunderSlash",
        VFX = "LightningVFX",
    },

    -- ===================== MAGE =====================
    MagicBolt = {
        Name = "Magic Bolt",
        Description = "Fire a concentrated bolt of magical energy.",
        Icon = "rbxassetid://0",
        MPCost = 10,
        Cooldown = 1,
        Range = 40,
        Effects = {
            { Type = ET.Damage, Multiplier = 1.1, DamageType = "Magic" },
        },
        Animation = "CastForward",
        VFX = "MagicBoltVFX",
        Projectile = true,
        ProjectileSpeed = 60,
    },
    ManaShield = {
        Name = "Mana Shield",
        Description = "Erect a barrier of mana that absorbs the next hit.",
        Icon = "rbxassetid://0",
        MPCost = 25,
        Cooldown = 5,
        Range = 0,
        Effects = {
            { Type = ET.Buff, Buff = "ManaShield", Duration = 6, AbsorbAmount = 80 },
        },
        Animation = "ShieldCast",
        VFX = "ShieldVFX",
    },
    ElementalBurst = {
        Name = "Elemental Burst",
        Description = "Unleash a burst of combined fire, ice, and lightning in all directions.",
        Icon = "rbxassetid://0",
        MPCost = 60,
        Cooldown = 7,
        Range = 0,
        Effects = {
            { Type = ET.AOE, Radius = 18, Damage = true, Multiplier = 1.8, DamageType = "Magic" },
            { Type = ET.Debuff, Debuff = "Burn", Duration = 3 },
        },
        Animation = "BurstCast",
        VFX = "ElementalBurstVFX",
    },

    -- ===================== BRAWLER =====================
    HeavyPunch = {
        Name = "Heavy Punch",
        Description = "A devastating punch that deals massive physical damage.",
        Icon = "rbxassetid://0",
        MPCost = 0,
        Cooldown = 1,
        Range = 6,
        Effects = {
            { Type = ET.Damage, Multiplier = 1.2, DamageType = "Physical" },
            { Type = ET.Knockback, Force = 20 },
        },
        Animation = "Punch",
        VFX = "ImpactVFX",
    },
    Taunt = {
        Name = "Taunt",
        Description = "Draw all nearby enemies to target you and boost your defense.",
        Icon = "rbxassetid://0",
        MPCost = 20,
        Cooldown = 6,
        Range = 0,
        Effects = {
            { Type = ET.AOE, Radius = 25, Debuff = "Taunted", Duration = 5 },
            { Type = ET.Buff, Buff = "DefenseUp", Multiplier = 1.4, Duration = 5 },
        },
        Animation = "TauntPose",
        VFX = "TauntVFX",
    },
    RagingRush = {
        Name = "Raging Rush",
        Description = "Charge forward smashing through every enemy in the way.",
        Icon = "rbxassetid://0",
        MPCost = 35,
        Cooldown = 5,
        Range = 30,
        Effects = {
            { Type = ET.Teleport, Distance = 30 },
            { Type = ET.Damage, Multiplier = 1.6, DamageType = "Physical", HitOnPath = true },
            { Type = ET.Knockback, Force = 60 },
        },
        Animation = "ChargeRush",
        VFX = "RushVFX",
    },

    -- ===================== ASSASSIN =====================
    ShadowStep = {
        Name = "Shadow Step",
        Description = "Teleport behind a targeted enemy and deal a backstab.",
        Icon = "rbxassetid://0",
        MPCost = 25,
        Cooldown = 3,
        Range = 30,
        Effects = {
            { Type = ET.Teleport, ToBehindTarget = true },
            { Type = ET.Damage, Multiplier = 2.0, DamageType = "Physical", IsCrit = true },
        },
        Animation = "ShadowTeleport",
        VFX = "ShadowVFX",
    },
    PoisonBlade = {
        Name = "Poison Blade",
        Description = "Coat your blade in lethal poison for the next 3 attacks.",
        Icon = "rbxassetid://0",
        MPCost = 20,
        Cooldown = 4,
        Range = 0,
        Effects = {
            { Type = ET.Buff, Buff = "PoisonCoat", Duration = 10, Stacks = 3 },
        },
        Animation = "CoatBlade",
        VFX = "PoisonCoatVFX",
    },
    DeathMark = {
        Name = "Death Mark",
        Description = "Mark an enemy — the next ability hit deals triple damage.",
        Icon = "rbxassetid://0",
        MPCost = 40,
        Cooldown = 7,
        Range = 40,
        Effects = {
            { Type = ET.Debuff, Debuff = "DeathMark", Duration = 8, DamageMultiplier = 3.0 },
        },
        Animation = "MarkCast",
        VFX = "MarkVFX",
        Projectile = true,
        ProjectileSpeed = 50,
    },

    -- ===================== SPIRIT USER =====================
    SpiritBlast = {
        Name = "Spirit Blast",
        Description = "Fire a concentrated beam of spirit energy.",
        Icon = "rbxassetid://0",
        MPCost = 20,
        Cooldown = 3,
        Range = 45,
        Effects = {
            { Type = ET.Damage, Multiplier = 1.5, DamageType = "Spirit" },
        },
        Animation = "SpiritShot",
        VFX = "SpiritBlastVFX",
        Projectile = true,
        ProjectileSpeed = 70,
    },
    AuraWall = {
        Name = "Aura Wall",
        Description = "Release a shockwave of spirit pressure that pushes enemies back.",
        Icon = "rbxassetid://0",
        MPCost = 30,
        Cooldown = 4,
        Range = 0,
        Effects = {
            { Type = ET.AOE, Radius = 15, Damage = true, Multiplier = 0.8, DamageType = "Spirit" },
            { Type = ET.Knockback, Force = 50 },
            { Type = ET.Debuff, Debuff = "Slow", Duration = 3 },
        },
        Animation = "AuraBurst",
        VFX = "AuraWallVFX",
    },
    BankaiFrenzy = {
        Name = "Bankai Frenzy",
        Description = "Release your true form — enter a frenzied state boosting all stats for 10 seconds.",
        Icon = "rbxassetid://0",
        MPCost = 60,
        Cooldown = 15,
        Range = 0,
        Effects = {
            { Type = ET.Buff, Buff = "BankaiState", Duration = 10, AtkMultiplier = 2.0, SpdMultiplier = 1.5, DefMultiplier = 1.3 },
        },
        Animation = "BankaiRelease",
        VFX = "BankaiVFX",
    },

    -- ===================== SWORDSMAN (UNLOCKABLE) =====================
    SkywardSlash = {
        Name = "Skyward Slash",
        Description = "A rising slash that launches enemies upward, then slams them down.",
        Icon = "rbxassetid://0",
        MPCost = 35,
        Cooldown = 4,
        Range = 10,
        Effects = {
            { Type = ET.AOE, Radius = 8, Damage = true, Multiplier = 1.2, DamageType = "Physical" },
            { Type = ET.Knockback, Force = 70 },
        },
        Animation = "RisingSlash",
        VFX = "SkyVFX",
    },
    CounterStance = {
        Name = "Counter Stance",
        Description = "Enter a ready stance — your next attack deals 3x damage.",
        Icon = "rbxassetid://0",
        MPCost = 30,
        Cooldown = 6,
        Range = 0,
        Effects = {
            { Type = ET.Buff, Buff = "CounterReady", Duration = 5, DamageMultiplier = 3.0 },
        },
        Animation = "StanceReady",
        VFX = "CounterVFX",
    },

    -- ===================== MAGE (UNLOCKABLE) =====================
    FrostNova = {
        Name = "Frost Nova",
        Description = "Releases a burst of ice that slows all enemies nearby.",
        Icon = "rbxassetid://0",
        MPCost = 40,
        Cooldown = 5,
        Range = 0,
        Effects = {
            { Type = ET.AOE, Radius = 14, Damage = true, Multiplier = 1.0, DamageType = "Ice" },
            { Type = ET.Debuff, Debuff = "Slow", Duration = 4 },
        },
        Animation = "IceBurst",
        VFX = "FrostVFX",
    },
    ArcaneOrb = {
        Name = "Arcane Orb",
        Description = "A slow but massive orb of pure mana that detonates on impact.",
        Icon = "rbxassetid://0",
        MPCost = 50,
        Cooldown = 6,
        Range = 50,
        Effects = {
            { Type = ET.Damage, Multiplier = 3.2, DamageType = "Magic" },
        },
        Animation = "OrbCast",
        VFX = "ArcaneOrbVFX",
        Projectile = true,
        ProjectileSpeed = 18,
    },

    -- ===================== BRAWLER (UNLOCKABLE) =====================
    GroundSlam = {
        Name = "Ground Slam",
        Description = "Slam the ground with Haki force, stunning all nearby enemies.",
        Icon = "rbxassetid://0",
        MPCost = 30,
        Cooldown = 5,
        Range = 0,
        Effects = {
            { Type = ET.AOE, Radius = 12, Damage = true, Multiplier = 1.3, DamageType = "Physical" },
            { Type = ET.Debuff, Debuff = "Stun", Duration = 2.5 },
        },
        Animation = "GroundPound",
        VFX = "SlamVFX",
    },
    IronDefense = {
        Name = "Iron Defense",
        Description = "Coat your body in Armament Haki — halves all incoming damage for 8 seconds.",
        Icon = "rbxassetid://0",
        MPCost = 35,
        Cooldown = 9,
        Range = 0,
        Effects = {
            { Type = ET.Buff, Buff = "IronSkin", Duration = 8, DamageReduction = 0.5 },
        },
        Animation = "HakiCoat",
        VFX = "HakiCoatVFX",
    },

    -- ===================== ASSASSIN (UNLOCKABLE) =====================
    SmokeBomb = {
        Name = "Smoke Bomb",
        Description = "Throw a smoke bomb that slows all enemies caught in the cloud.",
        Icon = "rbxassetid://0",
        MPCost = 20,
        Cooldown = 5,
        Range = 18,
        Effects = {
            { Type = ET.AOE, Radius = 12, Debuff = "Slow", Duration = 4 },
        },
        Animation = "ThrowBomb",
        VFX = "SmokeVFX",
    },
    VenomStrike = {
        Name = "Venom Strike",
        Description = "A quick stab that injects lethal poison for 6 seconds.",
        Icon = "rbxassetid://0",
        MPCost = 25,
        Cooldown = 3,
        Range = 6,
        Effects = {
            { Type = ET.Damage, Multiplier = 0.8, DamageType = "Poison" },
            { Type = ET.Debuff, Debuff = "Poison", Duration = 6 },
        },
        Animation = "PoisonStab",
        VFX = "VenomVFX",
    },

    -- ===================== SPIRIT USER (UNLOCKABLE) =====================
    SoulDrain = {
        Name = "Soul Drain",
        Description = "Drain the life force of nearby enemies, healing yourself.",
        Icon = "rbxassetid://0",
        MPCost = 40,
        Cooldown = 6,
        Range = 0,
        Effects = {
            { Type = ET.AOE, Radius = 14, Damage = true, Multiplier = 0.8, DamageType = "Spirit" },
            { Type = ET.Heal, Amount = 60 },
        },
        Animation = "DrainAura",
        VFX = "SoulDrainVFX",
    },
    ChakraStrike = {
        Name = "Chakra Strike",
        Description = "Focus all chakra into one devastating blow. Restores 40 Haki on hit.",
        Icon = "rbxassetid://0",
        MPCost = 50,
        Cooldown = 5,
        Range = 8,
        Effects = {
            { Type = ET.Damage, Multiplier = 2.5, DamageType = "Spirit" },
            { Type = ET.RestoreMP, Amount = 40 },
        },
        Animation = "ChakraFocus",
        VFX = "ChakraStrikeVFX",
    },

    -- ===================== SHARED / UNLOCKABLE =====================
    HealingSpring = {
        Name = "Healing Spring",
        Description = "Create a healing pool that restores HP over time.",
        Icon = "rbxassetid://0",
        MPCost = 35,
        Cooldown = 8,
        Range = 0,
        Effects = {
            { Type = ET.Heal, Amount = 40, OverTime = true, Duration = 6, Interval = 1 },
        },
        Animation = "HealCast",
        VFX = "HealPoolVFX",
    },
    UltimateKamehameha = {
        Name = "Spirit Cannon",
        Description = "Channel energy into a massive beam that destroys everything in its path.",
        Icon = "rbxassetid://0",
        MPCost = 100,
        Cooldown = 20,
        Range = 80,
        Effects = {
            { Type = ET.Damage, Multiplier = 5.0, DamageType = "Spirit", IsBeam = true, Width = 6 },
        },
        Animation = "ChargeBeam",
        VFX = "BeamVFX",
        ChargeTime = 1.5,
    },
}

-- Returns a copy of an ability definition
function AbilitySystem.GetAbility(name)
    local ab = AbilitySystem.Abilities[name]
    if not ab then
        warn("AbilitySystem: unknown ability '" .. tostring(name) .. "'")
        return nil
    end
    return ab
end

-- Returns list of abilities for an archetype from CharacterStats
function AbilitySystem.GetAbilitiesForArchetype(archData)
    local result = {}
    for _, name in ipairs(archData.StartingAbilities) do
        result[name] = AbilitySystem.GetAbility(name)
    end
    return result
end

return AbilitySystem
