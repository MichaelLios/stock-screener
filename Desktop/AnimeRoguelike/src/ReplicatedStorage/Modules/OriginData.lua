-- OriginData.lua
-- Player Origins: sub-identities within each archetype that define playstyle flavor,
-- grant a unique starting passive, and affect NPC dialogue + visual presentation.
--
-- Origins are selected AFTER the archetype at run start (same screen, second step).
-- They do NOT change base stats — they add a single passive trait and visual identity.
-- Some Origins are locked behind Mastery milestones (unlockable via MetaProgression).
--
-- Integration:
--   CharacterStats.BuildStats(archetypeName, level, originId) applies origin passive.
--   GameManager stores origin in PlayerRun and sends it to NpcData for context dialogue.
--   HUD displays origin name + aura color alongside archetype.

local OriginData = {}

-- ──────────────────────────────────────────────────────────────────────────
-- ORIGIN DEFINITIONS
-- ──────────────────────────────────────────────────────────────────────────
-- Each origin belongs to an archetype.
-- PassiveTrait: applied as a stat or flag in the player's CombatSystem state.

OriginData.Origins = {

    -- ════════════════════════════════════════════════
    -- SWORDSMAN ORIGINS
    -- ════════════════════════════════════════════════

    {
        Id            = "DemonSlayer",
        ArchetypeKey  = "Swordsman",
        Name          = "Demon Slayer",
        Lore          = "You trained in the ancient breathing techniques passed down from the first generation of slayers.  You don't just fight demons — you end them.",
        AuraColor     = Color3.fromRGB(220, 80, 40),
        NamePrefix    = "Slayer",   -- shown as "Slayer [Name]" in lobby
        PassiveTrait  = {
            Id          = "BreathingTechnique",
            Name        = "Breathing Technique",
            Description = "Basic attacks against Demon-type enemies deal 30% bonus damage.  Crit hits on Demons restore 5 MP.",
            -- Applied by CombatSystem: bonus damage flag + on-crit MP restore
            DemonBonusDmg   = 0.30,
            OnCritVsDemon_MPRestore = 5,
        },
        Unlocked      = true,   -- available from the start
        FlavorQuote   = "Total Concentration... constant.",
    },

    {
        Id            = "HakiMaster",
        ArchetypeKey  = "Swordsman",
        Name          = "Haki Master",
        Lore          = "You've developed Conqueror's Haki — the rare ability to project your will as a physical force.  Not everyone survives the training.",
        AuraColor     = Color3.fromRGB(30, 30, 30),
        NamePrefix    = "King",
        PassiveTrait  = {
            Id          = "ConquerorsBurst",
            Name        = "Conqueror's Burst",
            Description = "Activating Awakening emits a shockwave that Stuns all nearby enemies for 1.5 seconds.",
            AwakeningShockwaveRadius = 15,
            AwakeningShockwaveStun   = 1.5,
        },
        Unlocked      = true,
        FlavorQuote   = "I don't dodge.  Attacks dodge me.",
    },

    {
        Id            = "Ronin",
        ArchetypeKey  = "Swordsman",
        Name          = "Ronin",
        Lore          = "No master.  No creed.  Just the blade and the long road between fights.  The Void didn't corrupt you — it has nothing to offer someone already walking alone.",
        AuraColor     = Color3.fromRGB(160, 160, 140),
        NamePrefix    = "Wanderer",
        PassiveTrait  = {
            Id          = "SoloBlade",
            Name        = "Solo Blade",
            Description = "If you are the only player in the dungeon, all damage dealt is increased by 15% and XP gain is increased by 20%.",
            SoloBonusDmg  = 0.15,
            SoloBonusXP   = 0.20,
        },
        Unlocked      = false,   -- requires MetaProgression unlock (25 runs)
        UnlockCondition = "Complete 10 total runs.",
        FlavorQuote   = "The road is long.  I walk it anyway.",
    },

    -- ════════════════════════════════════════════════
    -- MAGE ORIGINS
    -- ════════════════════════════════════════════════

    {
        Id            = "Alchemist",
        ArchetypeKey  = "Mage",
        Name          = "Alchemist",
        Lore          = "You study the fundamental elements of reality.  In the Drift Shards, reality is malleable — and that makes you dangerous.",
        AuraColor     = Color3.fromRGB(255, 160, 30),
        NamePrefix    = "Sage",
        PassiveTrait  = {
            Id          = "ElementalMastery",
            Name        = "Elemental Mastery",
            Description = "Fire and ice abilities deal 20% bonus damage.  ElementalBurst leaves a burn field for 5 seconds after use.",
            ElementBonusDmg  = 0.20,
            ElementalBurstField = true,    -- adds lingering fire AOE
            ElementalFieldDuration = 5,
            ElementalFieldDPS = 8,
        },
        Unlocked      = true,
        FlavorQuote   = "Everything breaks down into something simpler.",
    },

    {
        Id            = "HollowMage",
        ArchetypeKey  = "Mage",
        Name          = "Hollow Scholar",
        Lore          = "You studied the Void academically — probing its edges without stepping in.  Or so you told yourself.  The residue shows.",
        AuraColor     = Color3.fromRGB(40, 0, 80),
        NamePrefix    = "Void",
        PassiveTrait  = {
            Id          = "VoidAffinity",
            Name        = "Void Affinity",
            Description = "Abilities that hit multiple enemies generate 2× Awakening gauge.  Taking damage restores 3 MP.",
            AOEAwakeningMult = 2.0,
            OnDamageTaken_MPRestore = 3,
        },
        Unlocked      = true,
        FlavorQuote   = "The Void is just energy with opinions.",
    },

    {
        Id            = "NatureSage",
        ArchetypeKey  = "Mage",
        Name          = "Nature Sage",
        Lore          = "You draw power from living things.  In a corrupted Shard, the twisted flora and fauna still carry echoes of what they were — and you can hear them.",
        AuraColor     = Color3.fromRGB(50, 220, 80),
        NamePrefix    = "Elder",
        PassiveTrait  = {
            Id          = "NaturalOrder",
            Name        = "Natural Order",
            Description = "HealingSpring restores 50% more HP.  Every 30 seconds, passively restore 15 HP.",
            HealingSpringBonus  = 0.50,
            PassiveHealInterval = 30,
            PassiveHealAmount   = 15,
        },
        Unlocked      = false,
        UnlockCondition = "Complete a run reaching Floor 5 as the Mage.",
        FlavorQuote   = "Life finds a way.  I help.",
    },

    -- ════════════════════════════════════════════════
    -- BRAWLER ORIGINS
    -- ════════════════════════════════════════════════

    {
        Id            = "TitanShifter",
        ArchetypeKey  = "Brawler",
        Name          = "Titan Shifter",
        Lore          = "The power of the Titans runs through you — borrowed, controlled, but never fully tamed.  The Void recognized that power and gave it a wide berth.",
        AuraColor     = Color3.fromRGB(200, 150, 100),
        NamePrefix    = "Shifter",
        PassiveTrait  = {
            Id          = "TitanForce",
            Name        = "Titan Force",
            Description = "RagingRush deals 25% bonus damage and Stuns hit enemies for 1 second.  Every 3rd hit is guaranteed to knockback.",
            RagingRushBonus     = 0.25,
            RagingRushStun      = 1.0,
            ThirdHitKnockback   = true,
        },
        Unlocked      = true,
        FlavorQuote   = "I fight.  Simple as that.",
    },

    {
        Id            = "DevilFruitBrawler",
        ArchetypeKey  = "Brawler",
        Name          = "Devil Fruit User",
        Lore          = "You ate something you found in a Drift Shard.  It tasted terrible.  Your fists no longer follow the normal rules of physics.",
        AuraColor     = Color3.fromRGB(255, 200, 0),
        NamePrefix    = "Rubber",
        PassiveTrait  = {
            Id          = "RubberBody",
            Name        = "Rubber Body",
            Description = "Immune to lightning damage and the Stun debuff.  HeavyPunch range increased by 50%.",
            LightningImmune     = true,
            StunImmune          = true,
            HeavyPunchRangeMult = 1.50,
        },
        Unlocked      = true,
        FlavorQuote   = "I'm made of rubber.  You are not.",
    },

    {
        Id            = "AncientWarrior",
        ArchetypeKey  = "Brawler",
        Name          = "Ancient Warrior",
        Lore          = "Your lineage connects to the warriors of the first age — the ones who fought the Void King directly.  Something in the Shards still recognizes you.",
        AuraColor     = Color3.fromRGB(255, 215, 50),
        NamePrefix    = "Ancient",
        PassiveTrait  = {
            Id          = "LegacyStrength",
            Name        = "Legacy Strength",
            Description = "Gain +3 Defense for every floor reached (resets per run).  Taunt duration doubled.",
            DefPerFloor     = 3,
            TauntDurationMult = 2.0,
        },
        Unlocked      = false,
        UnlockCondition = "Defeat the Colossus Titan boss at least once.",
        FlavorQuote   = "My ancestors fought this.  I remember how they did it.",
    },

    -- ════════════════════════════════════════════════
    -- ASSASSIN ORIGINS
    -- ════════════════════════════════════════════════

    {
        Id            = "Shinobi",
        ArchetypeKey  = "Assassin",
        Name          = "Shinobi",
        Lore          = "You were trained in an art older than any faction in the Shards.  Shadow, silence, and the single strike that ends everything.",
        AuraColor     = Color3.fromRGB(20, 20, 60),
        NamePrefix    = "Shadow",
        PassiveTrait  = {
            Id          = "NinjaArt",
            Name        = "Ninja Art",
            Description = "ShadowStep cooldown reduced by 2 seconds.  The first ability used after ShadowStep deals 30% bonus damage.",
            ShadowStepCDReduce  = 2,
            PostShadowStepBonus = 0.30,
        },
        Unlocked      = true,
        FlavorQuote   = "You never see the attack that kills you.",
    },

    {
        Id            = "PhantomThief",
        ArchetypeKey  = "Assassin",
        Name          = "Phantom",
        Lore          = "You cross between the world of the living and the spirit world.  The Void occupies both — you've learned to use that against it.",
        AuraColor     = Color3.fromRGB(150, 50, 200),
        NamePrefix    = "Phantom",
        PassiveTrait  = {
            Id          = "PhaseShift",
            Name        = "Phase Shift",
            Description = "Once per room, the first hit that would kill you instead drops you to 1 HP and makes you invincible for 1.5 seconds.",
            DeathEscape    = true,
            DeathEscapeIFrames = 1.5,
        },
        Unlocked      = true,
        FlavorQuote   = "I'm already dead.  So there's nothing to be afraid of.",
    },

    {
        Id            = "BountyHunter",
        ArchetypeKey  = "Assassin",
        Name          = "Bounty Hunter",
        Lore          = "You track targets for pay.  The Waypoint Coalition was the best contract you've ever had: unlimited targets, unlimited Bounty.",
        AuraColor     = Color3.fromRGB(200, 150, 50),
        NamePrefix    = "Hunter",
        PassiveTrait  = {
            Id          = "TargetAcquired",
            Name        = "Target Acquired",
            Description = "Killing an enemy with a critical hit drops 10 extra gold.  Boss kills grant double gold.",
            CritKillGoldBonus = 10,
            BossGoldMult      = 2.0,
        },
        Unlocked      = false,
        UnlockCondition = "Complete the 'Bounty Hoarder' bounty contract.",
        FlavorQuote   = "Every target has a price.  I just collect.",
    },

    -- ════════════════════════════════════════════════
    -- SPIRIT USER ORIGINS
    -- ════════════════════════════════════════════════

    {
        Id            = "SoulReaper",
        ArchetypeKey  = "SpiritUser",
        Name          = "Soul Reaper",
        Lore          = "Your Zanpakuto is the bridge between your soul and your power.  In the Drift Shards, both are tested constantly.",
        AuraColor     = Color3.fromRGB(30, 30, 80),
        NamePrefix    = "Captain",
        PassiveTrait  = {
            Id          = "ZanpakutoMastery",
            Name        = "Zanpakuto Mastery",
            Description = "BankaiFrenzy lasts 4 seconds longer.  While BankaiFrenzy is active, all abilities have no MP cost.",
            BankaiFrenzyDurationBonus = 4,
            BankaiZeroCost            = true,
        },
        Unlocked      = true,
        FlavorQuote   = "Bankai.",
    },

    {
        Id            = "ChakraMonk",
        ArchetypeKey  = "SpiritUser",
        Name          = "Chakra Monk",
        Lore          = "You devoted years to refining the flow of energy through your body.  The Void is just another kind of energy.  Disruptive, but manageable.",
        AuraColor     = Color3.fromRGB(100, 220, 180),
        NamePrefix    = "Monk",
        PassiveTrait  = {
            Id          = "InnerHarmony",
            Name        = "Inner Harmony",
            Description = "MP regenerates at 5 MP/sec passively.  ChakraStrike heals you for 100% of the MP it restores.",
            PassiveMPRegen          = 5,
            ChakraStrikeHealOnRestore = true,
        },
        Unlocked      = true,
        FlavorQuote   = "Breathe.  Focus.  The energy does the rest.",
    },

    {
        Id            = "Esper",
        ArchetypeKey  = "SpiritUser",
        Name          = "Esper",
        Lore          = "Your power is psychic — not spiritual, not chakra, not reiatsu.  Pure mental force given form.  The Void tried to control you.  It failed.",
        AuraColor     = Color3.fromRGB(180, 80, 255),
        NamePrefix    = "Esper",
        PassiveTrait  = {
            Id          = "TelekineticSurge",
            Name        = "Telekinetic Surge",
            Description = "AuraWall pushes enemies 50% farther.  Knockback from any source restores 8 MP.",
            AuraWallKnockbackBonus    = 0.50,
            OnKnockback_MPRestore     = 8,
        },
        Unlocked      = false,
        UnlockCondition = "Defeat Vaste Lorde Aizen at least once.",
        FlavorQuote   = "I don't touch things.  I move them.",
    },

    -- ════════════════════════════════════════════════
    -- SPECIAL ORIGINS (unlocked through Bounties/Mastery)
    -- ════════════════════════════════════════════════

    {
        Id            = "VoidTouched",
        ArchetypeKey  = "Any",   -- available to all archetypes
        Name          = "Void-Touched",
        Lore          = "The Void didn't break you.  It left a mark.  Now you carry a piece of it — controlled, weaponized, pointed outward.",
        AuraColor     = Color3.fromRGB(50, 0, 80),
        NamePrefix    = "Void",
        PassiveTrait  = {
            Id          = "VoidResonance",
            Name        = "Void Resonance",
            Description = "Curse effects grant double their bonus (damage penalty unchanged).  Void-type damage deals 20% more.",
            CurseDoubleBenefit = true,
            VoidDmgBonus       = 0.20,
        },
        Unlocked      = false,
        UnlockCondition = "Complete the 'Shard Veteran' legendary bounty (25 runs).",
        FlavorQuote   = "The Void tried to consume me.  Now I consume it.",
    },

    {
        Id            = "AnchorBreaker",
        ArchetypeKey  = "Any",
        Name          = "Anchor Breaker",
        Lore          = "You've defeated every Corruption Anchor in the cycle.  The Drift Shards know your name.  Their bosses are afraid.",
        AuraColor     = Color3.fromRGB(255, 215, 0),
        NamePrefix    = "Legend",
        PassiveTrait  = {
            Id          = "BossSlayer",
            Name        = "Boss Slayer",
            Description = "Bosses deal 15% less damage to you.  Defeating a boss fully restores HP and MP.",
            BossDmgReduction = 0.15,
            BossKillFullRestore = true,
        },
        Unlocked      = false,
        UnlockCondition = "Complete the 'Anchor Collector' legendary bounty (defeat all 5 bosses).",
        FlavorQuote   = "I've seen every single one of them.  I've beaten every single one of them.",
    },
}

-- ──────────────────────────────────────────────────────────────────────────
-- API
-- ──────────────────────────────────────────────────────────────────────────

-- Get an origin by Id
function OriginData.GetById(id)
    for _, o in ipairs(OriginData.Origins) do
        if o.Id == id then return o end
    end
    return nil
end

-- Get all origins available for an archetype (includes "Any" origins)
function OriginData.GetForArchetype(archetypeKey, unlockedIds)
    unlockedIds = unlockedIds or {}
    local results = {}
    for _, o in ipairs(OriginData.Origins) do
        if (o.ArchetypeKey == archetypeKey or o.ArchetypeKey == "Any") then
            local available = o.Unlocked
            if not available then
                for _, uid in ipairs(unlockedIds) do
                    if uid == o.Id then available = true; break end
                end
            end
            if available then
                table.insert(results, o)
            end
        end
    end
    return results
end

-- Apply origin passive to a player stat block (called from CharacterStats.BuildStats)
function OriginData.ApplyOrigin(stats, originId)
    if not originId then return end
    local origin = OriginData.GetById(originId)
    if not origin or not origin.PassiveTrait then return end

    local trait = origin.PassiveTrait
    -- Apply numeric stat modifiers
    if trait.DamageTakenMultiplier then
        stats.DamageTakenMult = (stats.DamageTakenMult or 1.0) * trait.DamageTakenMultiplier
    end
    if trait.AtkMultiplier then
        stats.Atk = math.floor(stats.Atk * trait.AtkMultiplier)
    end
    if trait.DefPerFloor then
        stats.DefPerFloor = (stats.DefPerFloor or 0) + trait.DefPerFloor
    end
    if trait.PassiveMPRegen then
        stats.MPRegen = (stats.MPRegen or 0) + trait.PassiveMPRegen
    end
    if trait.PassiveHealInterval then
        stats.PassiveHealInterval = trait.PassiveHealInterval
        stats.PassiveHealAmount   = trait.PassiveHealAmount or 0
    end

    -- Store the full trait on stats so CombatSystem can read flags
    stats.OriginTrait = trait
    stats.OriginId    = originId
end

return OriginData
