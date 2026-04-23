-- AbilityEvolution.lua
-- Mid-run ability growth system. Each ability accumulates XP per successful hit,
-- then evolves through two stages that unlock permanent bonuses for the rest of the run.
--
-- Stage 0 = Base (always active, no bonus)
-- Stage 1 = Enhanced (first threshold — hit count)
-- Stage 2 = Apex    (second threshold)
--
-- CombatSystem tracks EvoXP[abilityName] and EvoStage[abilityName] per player.
-- Bonus keys consumed by CombatSystem:
--   DmgMult          (number)  — multiply final damage before dealing
--   LifeSteal        (number)  — fraction of damage dealt returned as HP
--   CDRefund         (number)  — seconds shaved off ability CD per successful hit
--   ExtraAOEOnHit    (table)   — { Radius, Multiplier } AOE chain after primary hit
--   AOERadiusBonus   (number)  — added to AOE radius for AOE-type effects
--   DebuffDurMult    (number)  — multiply duration of debuffs this ability applies
--   MPCostFlat       (number)  — flat MP reduction for this ability

local AbilityEvolution = {}

AbilityEvolution.Evolutions = {

    -- ── SWORDSMAN ─────────────────────────────────────────────────────────────

    BasicSlash = {
        XPThresholds = { 20, 50 },
        Stages = {
            [1] = {
                Name        = "Precise Slash",
                Description = "Each hit restores 6% of damage dealt as HP.",
                Bonus       = { LifeSteal = 0.06 },
            },
            [2] = {
                Name        = "Void Rend",
                Description = "Slash damage ×1.4 and chains to 1 nearby enemy at 60% power.",
                Bonus       = { DmgMult = 1.4, ExtraAOEOnHit = { Radius = 8, Multiplier = 0.60 } },
            },
        },
    },

    QuickDash = {
        XPThresholds = { 12, 30 },
        Stages = {
            [1] = {
                Name        = "Phantom Dash",
                Description = "Each hit refunds 1.5 s of Quick Dash's own cooldown.",
                Bonus       = { CDRefund = 1.5 },
            },
            [2] = {
                Name        = "Void Step",
                Description = "Dash damage ×1.5 and heals 8% of damage dealt.",
                Bonus       = { DmgMult = 1.5, LifeSteal = 0.08 },
            },
        },
    },

    BladeTornado = {
        XPThresholds = { 8, 22 },
        Stages = {
            [1] = {
                Name        = "Storm Blade",
                Description = "AOE radius +5 studs and each hit steals 4% as HP.",
                Bonus       = { AOERadiusBonus = 5, LifeSteal = 0.04 },
            },
            [2] = {
                Name        = "Heaven's Cyclone",
                Description = "All tornado hits deal ×1.6 damage and refund 0.8 s of cooldown.",
                Bonus       = { DmgMult = 1.6, CDRefund = 0.8 },
            },
        },
    },

    ThunderClap = {
        XPThresholds = { 10, 25 },
        Stages = {
            [1] = {
                Name        = "Chain Thunder",
                Description = "Hit chains to 2 nearby enemies at 50% power.",
                Bonus       = { ExtraAOEOnHit = { Radius = 18, Multiplier = 0.50 } },
            },
            [2] = {
                Name        = "God's Verdict",
                Description = "Thunder Clap deals ×1.8 damage and Stun duration doubled.",
                Bonus       = { DmgMult = 1.8, DebuffDurMult = 2.0 },
            },
        },
    },

    -- ── MAGE ──────────────────────────────────────────────────────────────────

    MagicBolt = {
        XPThresholds = { 18, 45 },
        Stages = {
            [1] = {
                Name        = "Piercing Bolt",
                Description = "Bolt damage ×1.25 and refunds 0.5 s on hit.",
                Bonus       = { DmgMult = 1.25, CDRefund = 0.5 },
            },
            [2] = {
                Name        = "Arcane Lance",
                Description = "Bolt chains to 1 nearby enemy at 70% power.",
                Bonus       = { ExtraAOEOnHit = { Radius = 12, Multiplier = 0.70 } },
            },
        },
    },

    ManaShield = {
        XPThresholds = { 6, 15 },
        Stages = {
            [1] = {
                Name        = "Hardened Shield",
                Description = "Mana Shield absorb value increases by 40 flat.",
                Bonus       = { AbsorbBonus = 40 },
            },
            [2] = {
                Name        = "Mirror Barrier",
                Description = "Mana Shield also reflects 25% of absorbed damage back to the attacker.",
                Bonus       = { ShieldReflect = 0.25 },
            },
        },
    },

    ElementalBurst = {
        XPThresholds = { 6, 16 },
        Stages = {
            [1] = {
                Name        = "Wild Burst",
                Description = "AOE radius +6 studs.",
                Bonus       = { AOERadiusBonus = 6 },
            },
            [2] = {
                Name        = "Cataclysm",
                Description = "Burst deals ×1.5 damage and all burn durations doubled.",
                Bonus       = { DmgMult = 1.5, DebuffDurMult = 2.0 },
            },
        },
    },

    -- ── BRAWLER ───────────────────────────────────────────────────────────────

    HeavyPunch = {
        XPThresholds = { 15, 40 },
        Stages = {
            [1] = {
                Name        = "Crushing Blow",
                Description = "Punch heals 5% of damage as HP.",
                Bonus       = { LifeSteal = 0.05 },
            },
            [2] = {
                Name        = "Titan Fist",
                Description = "Damage ×1.5 and sends a shockwave that hits 2 nearby enemies at 50%.",
                Bonus       = { DmgMult = 1.5, ExtraAOEOnHit = { Radius = 10, Multiplier = 0.50 } },
            },
        },
    },

    Taunt = {
        XPThresholds = { 8, 20 },
        Stages = {
            [1] = {
                Name        = "Battle Cry",
                Description = "Taunt radius +10 studs and taunted duration +2 s.",
                Bonus       = { AOERadiusBonus = 10, DebuffDurMult = 1.4 },
            },
            [2] = {
                Name        = "Conqueror's Roar",
                Description = "Taunt also reduces all nearby enemies' Atk by 30% for 4 s.",
                Bonus       = { AOERadiusBonus = 15, DebuffDurMult = 1.8 },
            },
        },
    },

    RagingRush = {
        XPThresholds = { 10, 25 },
        Stages = {
            [1] = {
                Name        = "Oni Charge",
                Description = "Each hit during the rush heals 7% as HP.",
                Bonus       = { LifeSteal = 0.07 },
            },
            [2] = {
                Name        = "Unstoppable Force",
                Description = "Rush damage ×1.6 and every hit refunds 2 s of cooldown.",
                Bonus       = { DmgMult = 1.6, CDRefund = 2.0 },
            },
        },
    },

    -- ── ASSASSIN ──────────────────────────────────────────────────────────────

    ShadowStep = {
        XPThresholds = { 10, 24 },
        Stages = {
            [1] = {
                Name        = "Silent Kill",
                Description = "Backstab heals 10% of damage dealt as HP.",
                Bonus       = { LifeSteal = 0.10 },
            },
            [2] = {
                Name        = "Void Assassin",
                Description = "Backstab deals ×1.6 and refunds 3 s of cooldown.",
                Bonus       = { DmgMult = 1.6, CDRefund = 3.0 },
            },
        },
    },

    PoisonBlade = {
        XPThresholds = { 8, 20 },
        Stages = {
            [1] = {
                Name        = "Lethal Coat",
                Description = "Poison duration extended by 2 s.",
                Bonus       = { DebuffDurMult = 1.5 },
            },
            [2] = {
                Name        = "Venom Master",
                Description = "Poisoned enemies take 20% extra damage from all sources.",
                Bonus       = { PoisonedTargetDmgBonus = 0.20 },
            },
        },
    },

    DeathMark = {
        XPThresholds = { 8, 20 },
        Stages = {
            [1] = {
                Name        = "Branded",
                Description = "Death Mark lasts 4 s longer.",
                Bonus       = { DebuffDurMult = 1.5 },
            },
            [2] = {
                Name        = "Executioner's Mark",
                Description = "Death Mark triples damage on next hit AND the one after.",
                Bonus       = { DeathMarkCharges = 2 },
            },
        },
    },

    -- ── SPIRIT USER ───────────────────────────────────────────────────────────

    SpiritBlast = {
        XPThresholds = { 15, 38 },
        Stages = {
            [1] = {
                Name        = "Focused Spirit",
                Description = "Blast damage ×1.3 and restores 3 MP per hit.",
                Bonus       = { DmgMult = 1.3, MPRestore = 3 },
            },
            [2] = {
                Name        = "Soul Cannon",
                Description = "Blast chains to 2 enemies at 65% power.",
                Bonus       = { ExtraAOEOnHit = { Radius = 20, Multiplier = 0.65 } },
            },
        },
    },

    AuraWall = {
        XPThresholds = { 8, 20 },
        Stages = {
            [1] = {
                Name        = "Spirit Wave",
                Description = "Shockwave radius +8 studs.",
                Bonus       = { AOERadiusBonus = 8 },
            },
            [2] = {
                Name        = "Pressure Collapse",
                Description = "AOE damage ×1.5 and Slow duration doubled.",
                Bonus       = { DmgMult = 1.5, DebuffDurMult = 2.0 },
            },
        },
    },

    BankaiFrenzy = {
        XPThresholds = { 4, 10 },
        Stages = {
            [1] = {
                Name        = "True Bankai",
                Description = "Bankai Frenzy duration +5 s.",
                Bonus       = { BankaiFrenzDurBonus = 5 },
            },
            [2] = {
                Name        = "Final Bankai",
                Description = "While Bankai is active, all ability damage ×1.4 and you cannot die (revive at 1 HP once).",
                Bonus       = { BankaiDmgBonus = 1.4, BankaiRevive = true },
            },
        },
    },

    -- ── SWORDSMAN UNLOCKABLE ──────────────────────────────────────────────────

    SkywardSlash = {
        XPThresholds = { 10, 25 },
        Stages = {
            [1] = {
                Name        = "Rising Blade",
                Description = "AOE radius +4 studs and heals 6% as HP.",
                Bonus       = { AOERadiusBonus = 4, LifeSteal = 0.06 },
            },
            [2] = {
                Name        = "Heaven's Divide",
                Description = "Damage ×1.7 and a second slam crashes down 1 s later for 60% damage.",
                Bonus       = { DmgMult = 1.7, ExtraAOEOnHit = { Radius = 12, Multiplier = 0.60 } },
            },
        },
    },

    CounterStance = {
        XPThresholds = { 8, 20 },
        Stages = {
            [1] = {
                Name        = "Perfect Timing",
                Description = "Counter window lasts 2 s longer.",
                Bonus       = { CounterDurBonus = 2 },
            },
            [2] = {
                Name        = "Mirror Counter",
                Description = "Counter-hit chains to all enemies within 12 studs at 50% power.",
                Bonus       = { ExtraAOEOnHit = { Radius = 12, Multiplier = 0.50 } },
            },
        },
    },

    -- ── MAGE UNLOCKABLE ───────────────────────────────────────────────────────

    FrostNova = {
        XPThresholds = { 8, 20 },
        Stages = {
            [1] = {
                Name        = "Glacial Nova",
                Description = "Frost radius +6 studs and Slow duration +2 s.",
                Bonus       = { AOERadiusBonus = 6, DebuffDurMult = 1.5 },
            },
            [2] = {
                Name        = "Absolute Zero",
                Description = "Frost damage ×1.5 and Slow becomes Stun for 1.5 s.",
                Bonus       = { DmgMult = 1.5, FrostStunUpgrade = true },
            },
        },
    },

    ArcaneOrb = {
        XPThresholds = { 8, 20 },
        Stages = {
            [1] = {
                Name        = "Charged Orb",
                Description = "Orb damage ×1.3.",
                Bonus       = { DmgMult = 1.3 },
            },
            [2] = {
                Name        = "Singularity",
                Description = "Orb pulls all enemies within 14 studs toward impact point then detonates for ×1.6 total.",
                Bonus       = { DmgMult = 1.6, ExtraAOEOnHit = { Radius = 14, Multiplier = 0.70 } },
            },
        },
    },

    -- ── BRAWLER UNLOCKABLE ────────────────────────────────────────────────────

    GroundSlam = {
        XPThresholds = { 8, 20 },
        Stages = {
            [1] = {
                Name        = "Tectonic Slam",
                Description = "Slam radius +5 studs and Stun duration +1 s.",
                Bonus       = { AOERadiusBonus = 5, DebuffDurMult = 1.4 },
            },
            [2] = {
                Name        = "World Breaker",
                Description = "Slam damage ×1.8 and leaves a burning field for 4 s.",
                Bonus       = { DmgMult = 1.8, GroundSlamFireField = true },
            },
        },
    },

    IronDefense = {
        XPThresholds = { 6, 14 },
        Stages = {
            [1] = {
                Name        = "Black Armor",
                Description = "Armor duration +4 s.",
                Bonus       = { IronDefenseDurBonus = 4 },
            },
            [2] = {
                Name        = "Indestructible",
                Description = "While active, each hit you take restores 8% of your max HP.",
                Bonus       = { IronDefenseHealOnHit = 0.08 },
            },
        },
    },

    -- ── ASSASSIN UNLOCKABLE ───────────────────────────────────────────────────

    SmokeBomb = {
        XPThresholds = { 8, 20 },
        Stages = {
            [1] = {
                Name        = "Toxic Cloud",
                Description = "Smoke also applies Poison to enemies caught inside.",
                Bonus       = { SmokeBombPoisons = true, DebuffDurMult = 1.3 },
            },
            [2] = {
                Name        = "Death Fog",
                Description = "Cloud radius +5 studs and enemies inside take 10% bonus damage from all hits.",
                Bonus       = { AOERadiusBonus = 5, SmokeBombPoisons = true },
            },
        },
    },

    VenomStrike = {
        XPThresholds = { 12, 30 },
        Stages = {
            [1] = {
                Name        = "Deep Venom",
                Description = "Poison duration +3 s and damage ×1.2.",
                Bonus       = { DmgMult = 1.2, DebuffDurMult = 1.5 },
            },
            [2] = {
                Name        = "Fatal Venom",
                Description = "Venom Strike hits 2 nearby enemies at 80% power.",
                Bonus       = { ExtraAOEOnHit = { Radius = 8, Multiplier = 0.80 } },
            },
        },
    },

    -- ── SPIRIT USER UNLOCKABLE ────────────────────────────────────────────────

    SoulDrain = {
        XPThresholds = { 8, 20 },
        Stages = {
            [1] = {
                Name        = "Ravenous Drain",
                Description = "Healing from Soul Drain increased by 30%.",
                Bonus       = { SoulDrainHealMult = 1.30 },
            },
            [2] = {
                Name        = "Soul Hunger",
                Description = "Drain radius +6 studs and drain damage ×1.4.",
                Bonus       = { DmgMult = 1.4, AOERadiusBonus = 6 },
            },
        },
    },

    ChakraStrike = {
        XPThresholds = { 10, 25 },
        Stages = {
            [1] = {
                Name        = "Pure Focus",
                Description = "Strike damage ×1.3 and refunds 2 s of cooldown.",
                Bonus       = { DmgMult = 1.3, CDRefund = 2.0 },
            },
            [2] = {
                Name        = "Seventh Gate",
                Description = "Strike damage ×1.8 and restores 20 extra MP on hit.",
                Bonus       = { DmgMult = 1.8, MPRestore = 20 },
            },
        },
    },

    -- ── SHARED ───────────────────────────────────────────────────────────────

    HealingSpring = {
        XPThresholds = { 6, 14 },
        Stages = {
            [1] = {
                Name        = "Radiant Spring",
                Description = "Healing pool restores 30% more HP total.",
                Bonus       = { HealAmountMult = 1.30 },
            },
            [2] = {
                Name        = "Fountain of Life",
                Description = "Heal pool radius +5 studs and duration +3 s.",
                Bonus       = { HealPoolDurBonus = 3, HealAmountMult = 1.5 },
            },
        },
    },

    UltimateKamehameha = {
        XPThresholds = { 3, 8 },
        Stages = {
            [1] = {
                Name        = "Focused Beam",
                Description = "Beam damage ×1.4 and width +2 studs.",
                Bonus       = { DmgMult = 1.4 },
            },
            [2] = {
                Name        = "Omega Cannon",
                Description = "Beam damage ×2.0 and refunds 15 s of cooldown on successful hit.",
                Bonus       = { DmgMult = 2.0, CDRefund = 15.0 },
            },
        },
    },
}

-- ─── API ──────────────────────────────────────────────────────────────────────

function AbilityEvolution.GetEvolution(abilityName)
    return AbilityEvolution.Evolutions[abilityName]
end

function AbilityEvolution.GetStageName(abilityName, stage)
    local evo = AbilityEvolution.Evolutions[abilityName]
    if not evo or stage <= 0 then return "Base" end
    local s = evo.Stages[stage]
    return s and s.Name or "Enhanced"
end

return AbilityEvolution
