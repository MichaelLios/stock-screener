-- SynergySystem.lua
-- Defines passive bonuses that activate when the player has specific ability combos equipped.
-- Used by CombatSystem on the server (damage/effect calculation) and by HUD for display.
--
-- Usage:
--   local SynergySystem = require(ReplicatedStorage.Modules.SynergySystem)
--   local active = SynergySystem.GetActiveSynergies(activeSlots)   -- slots is {name|false}×5
--   -- active = { [synergyName] = synergyData, ... }

local SynergySystem = {}

-- ────────────────────────────────────────────────
-- SYNERGY DEFINITIONS
-- ────────────────────────────────────────────────
-- RequiredAbilities: ALL must be in the player's equipped slots.
-- Bonuses are read by CombatSystem when applying damage/effects.

SynergySystem.Synergies = {

    -- Swordsman combos
    StormStyle = {
        DisplayName = "Storm Style",
        RequiredAbilities = { "ThunderClap", "BladeTornado" },
        Color       = Color3.fromRGB(255, 240, 60),
        Description = "Thunder Clap deals +20% Lightning damage.\nBlade Tornado stuns enemies hit.",
        Bonuses = {
            ThunderClapDmgMult = 1.20,   -- multiplier on top of base when using ThunderClap
            BladeTornadoStun   = true,    -- BladeTornado applies Stun debuff
        },
    },

    PhantomCounter = {
        DisplayName = "Phantom Counter",
        RequiredAbilities = { "CounterStance", "ShadowStep" },
        Color       = Color3.fromRGB(140, 60, 255),
        Description = "Counter Stance multiplier increases from 3× to 5×.\nShadow Step backstab crits deal +25% damage.",
        Bonuses = {
            CounterMult        = 5.0,    -- override default 3× CounterReady multiplier
            ShadowStepCritMult = 1.25,   -- additional crit multiplier on ShadowStep
        },
    },

    -- Mage combos
    Fortress = {
        DisplayName = "Fortress",
        RequiredAbilities = { "ManaShield", "IronDefense" },
        Color       = Color3.fromRGB(80, 140, 255),
        Description = "Mana Shield absorbs 50% more damage.\nIron Defense lasts 4 extra seconds.",
        Bonuses = {
            ShieldAbsorbBonus  = 0.50,   -- fraction extra absorb
            IronDefenseDurBonus = 4,     -- seconds added to IronDefense buff duration
        },
    },

    ArcaneOverload = {
        DisplayName = "Arcane Overload",
        RequiredAbilities = { "ArcaneOrb", "ElementalBurst" },
        Color       = Color3.fromRGB(200, 80, 255),
        Description = "Arcane Orb damage +30%.\nElemental Burst also applies Slow on hit.",
        Bonuses = {
            ArcaneOrbDmgMult    = 1.30,
            ElementalBurstSlow  = true,
        },
    },

    -- Spirit User combos
    SpiritualHunger = {
        DisplayName = "Spiritual Hunger",
        RequiredAbilities = { "SoulDrain", "ChakraStrike" },
        Color       = Color3.fromRGB(100, 220, 200),
        Description = "Soul Drain heals an extra 40 HP.\nChakra Strike restores an extra 25 Haki.",
        Bonuses = {
            SoulDrainHealBonus   = 40,
            ChakraStrikeMPBonus  = 25,
        },
    },

    BankaiBerserk = {
        DisplayName = "Bankai Berserk",
        RequiredAbilities = { "BankaiFrenzy", "BladeTornado" },
        Color       = Color3.fromRGB(255, 100, 30),
        Description = "Bankai Frenzy also grants +25% crit chance.\nBlade Tornado deals +40% damage while Bankai is active.",
        Bonuses = {
            BankaiCritBonus        = 0.25,
            BankaiTornadoDmgMult   = 1.40,
        },
    },

    -- ── CHAIN REACTION SYNERGIES ───────────────────────────────────────────────

    -- Killing any enemy immediately resets ShadowStep cooldown
    Reaper = {
        DisplayName      = "Reaper",
        RequiredAbilities = { "ShadowStep", "PoisonBlade" },
        Color            = Color3.fromRGB(80, 0, 120),
        Description      = "Killing any enemy instantly resets ShadowStep cooldown.\nPoison duration +3 s on all poison applications.",
        Bonuses = {
            KillResetShadowStep = true,
            PoisonDurBonus      = 3,
        },
    },

    -- ThunderClap / BladeTornado / SkywardSlash: every damage hit chains to 2 nearby enemies
    StormKing = {
        DisplayName      = "Storm King",
        RequiredAbilities = { "ThunderClap", "BladeTornado", "SkywardSlash" },
        Color            = Color3.fromRGB(200, 230, 80),
        Description      = "LEGENDARY — Every ability hit chains lightning to 2 nearby enemies at 45% power.\nThunderClap damage ×1.5.",
        Legendary        = true,
        Bonuses = {
            ChainLightningCount = 2,
            ThunderClapDmgMult  = 1.50,
        },
    },

    -- ── SCALING SYNERGIES ──────────────────────────────────────────────────────

    -- Each kill builds Void Stacks (+2% all damage per stack, max 20, persists across rooms)
    VoidEater = {
        DisplayName      = "Void Eater",
        RequiredAbilities = { "SoulDrain", "DeathMark" },
        Color            = Color3.fromRGB(100, 20, 160),
        Description      = "Each kill builds a Void Stack (+2% all damage, max 20).\nStacks persist across rooms.",
        Bonuses = {
            VoidStackOnKill = true,
        },
    },

    -- Below 50% HP, missing HP multiplies damage (scales to 2× at 0 HP)
    BloodRage = {
        DisplayName      = "Blood Rage",
        RequiredAbilities = { "HeavyPunch", "RagingRush", "Taunt" },
        Color            = Color3.fromRGB(220, 30, 30),
        Description      = "LEGENDARY — Below 50% HP, missing HP translates to bonus damage (up to ×2.0 at 0 HP).\nRagingRush always stuns enemies it hits.",
        Legendary        = true,
        Bonuses = {
            BloodRageMissingHPMult = true,
            OniRushStun            = true,
        },
    },

    -- ── COOLDOWN RESET SYNERGIES ───────────────────────────────────────────────

    -- Killing a poisoned enemy resets DeathMark CD + grants 3 free PoisonCoat stacks
    DeathBringer = {
        DisplayName      = "Death Bringer",
        RequiredAbilities = { "DeathMark", "VenomStrike", "PoisonBlade" },
        Color            = Color3.fromRGB(140, 200, 20),
        Description      = "LEGENDARY — Killing a poisoned enemy resets DeathMark cooldown and grants 3 free Poison Coat stacks.\nPoison and venom deal +30% damage.",
        Legendary        = true,
        Bonuses = {
            PoisonKillResetDeathMark = true,
        },
    },

    -- MagicBolt hits reduce ArcaneOrb CD by 1 s; ArcaneOrb detonation triggers a free mini burst
    ArcaneFusion = {
        DisplayName      = "Arcane Fusion",
        RequiredAbilities = { "MagicBolt", "ArcaneOrb", "ElementalBurst" },
        Color            = Color3.fromRGB(200, 60, 255),
        Description      = "LEGENDARY — MagicBolt hits reduce ArcaneOrb cooldown by 1 s.\nArcaneOrb detonation triggers a free ElementalBurst AOE at 80% power.",
        Legendary        = true,
        Bonuses = {
            MagicBoltReducesArcaneOrbCD = true,
            ArcaneOrbFreeBurst          = true,
        },
    },

    -- While BankaiFrenzy active: SoulDrain heals 3×, ChakraStrike auto-crits
    SoulReap = {
        DisplayName      = "Soul Reap",
        RequiredAbilities = { "BankaiFrenzy", "SoulDrain", "ChakraStrike" },
        Color            = Color3.fromRGB(255, 80, 180),
        Description      = "LEGENDARY — While Bankai Frenzy is active: SoulDrain heals ×3 and ChakraStrike auto-crits.\nBankai duration +6 s.",
        Legendary        = true,
        Bonuses = {
            SoulReapBankaiHealMult  = 3.0,
            SoulReapChakraAutoCrit  = true,
            SoulReapBankaiDurBonus  = 6,
        },
    },

    -- RagingRush always stuns; GroundSlam leaves a 5-second burning field
    OniRush = {
        DisplayName      = "Oni Rush",
        RequiredAbilities = { "RagingRush", "GroundSlam" },
        Color            = Color3.fromRGB(255, 120, 0),
        Description      = "RagingRush hit enemies are always Stunned for 1.5 s.\nGroundSlam leaves a burning hazard field dealing 8 damage/0.5 s for 5 s.",
        Bonuses = {
            OniRushStun     = true,
            OniSlamFireField = true,
        },
    },
}

-- ────────────────────────────────────────────────
-- PUBLIC API
-- ────────────────────────────────────────────────

-- GetActiveSynergies(activeSlots)
-- activeSlots: array[1..5] of abilityName or false
-- Returns: { [synergyName] = synergyData } for every synergy whose required abilities
-- are ALL present in activeSlots.
function SynergySystem.GetActiveSynergies(activeSlots)
    local nameSet = {}
    for _, name in ipairs(activeSlots) do
        if name then nameSet[name] = true end
    end

    local active = {}
    for synName, syn in pairs(SynergySystem.Synergies) do
        local hasAll = true
        for _, req in ipairs(syn.RequiredAbilities) do
            if not nameSet[req] then hasAll = false; break end
        end
        if hasAll then
            active[synName] = syn
        end
    end
    return active
end

-- GetBonus(activeSynergies, bonusKey)
-- Convenience: reads a specific bonus value from the active synergy set.
-- Returns the value if found in ANY active synergy, or nil.
function SynergySystem.GetBonus(activeSynergies, bonusKey)
    for _, syn in pairs(activeSynergies) do
        if syn.Bonuses[bonusKey] ~= nil then
            return syn.Bonuses[bonusKey]
        end
    end
    return nil
end

return SynergySystem
