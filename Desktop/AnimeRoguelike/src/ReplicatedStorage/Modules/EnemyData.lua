-- EnemyData.lua
-- Enemy definitions with anime-style archetypes, scaling stats, and behavior flags.

local EnemyData = {}

-- Behavior flags
local B = {
    Melee      = "Melee",
    Ranged     = "Ranged",
    Charger    = "Charger",   -- rushes player on sight
    Dodger     = "Dodger",    -- rolls to avoid projectiles
    Shielder   = "Shielder",  -- blocks frontal attacks
    Summoner   = "Summoner",  -- spawns adds
    Berserk    = "Berserk",   -- enrages below 30% HP
    Boss       = "Boss",
}

EnemyData.Enemies = {
    -- ===== COMMON =====
    Demon_Grunt = {
        DisplayName = "Demon Grunt",
        HP = 60,
        Atk = 6,
        Def = 4,
        Spd = 10,
        XP = 15,
        Behaviors = { B.Melee, B.Charger },
        AttackRange = 5,
        DetectRange = 30,
        Abilities = {},
        LootTable = "Common",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(3, 5, 3),
        Color = Color3.fromRGB(180, 40, 40),
    },
    Demon_Berserker = {
        DisplayName = "Demon Berserker",
        HP = 100,
        Atk = 10,
        Def = 3,
        Spd = 14,
        XP = 30,
        Behaviors = { B.Melee, B.Charger, B.Berserk },
        AttackRange = 6,
        DetectRange = 35,
        Abilities = { "RagingRush" },
        LootTable = "Common",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(4, 6, 4),
        Color = Color3.fromRGB(220, 60, 40),
    },
    Demon_Mage = {
        DisplayName = "Demon Mage",
        HP = 70,
        Atk = 12,
        Def = 2,
        Spd = 8,
        XP = 35,
        Behaviors = { B.Ranged, B.Dodger },
        AttackRange = 30,
        DetectRange = 40,
        Abilities = { "MagicBolt", "ElementalBurst" },
        LootTable = "Uncommon",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(3, 5, 3),
        Color = Color3.fromRGB(160, 40, 180),
    },
    Shadow_Clone = {
        DisplayName = "Shadow Clone",
        HP = 40,
        Atk = 8,
        Def = 2,
        Spd = 16,
        XP = 20,
        Behaviors = { B.Melee, B.Dodger },
        AttackRange = 5,
        DetectRange = 30,
        Abilities = { "ShadowStep" },
        LootTable = "Common",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(3, 5, 3),
        Color = Color3.fromRGB(20, 20, 80),
    },
    Rogue_Ninja = {
        DisplayName = "Rogue Ninja",
        HP = 80,
        Atk = 9,
        Def = 5,
        Spd = 18,
        XP = 40,
        Behaviors = { B.Melee, B.Ranged, B.Dodger },
        AttackRange = 20,
        DetectRange = 40,
        Abilities = { "QuickDash", "PoisonBlade" },
        LootTable = "Uncommon",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(3, 5, 3),
        Color = Color3.fromRGB(40, 40, 60),
    },
    Puppet_Master = {
        DisplayName = "Puppet Master",
        HP = 90,
        Atk = 8,
        Def = 6,
        Spd = 7,
        XP = 50,
        Behaviors = { B.Ranged, B.Summoner },
        AttackRange = 25,
        DetectRange = 35,
        Abilities = { "SummonPuppet" },
        LootTable = "Uncommon",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(3, 5, 3),
        Color = Color3.fromRGB(100, 60, 40),
        SummonEnemy = "Shadow_Clone",
        MaxSummons = 3,
    },
    SeaGuardian = {
        DisplayName = "Sea Guardian",
        HP = 110,
        Atk = 8,
        Def = 8,
        Spd = 9,
        XP = 35,
        Behaviors = { B.Melee, B.Shielder },
        AttackRange = 6,
        DetectRange = 30,
        Abilities = {},
        LootTable = "Common",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(4, 6, 4),
        Color = Color3.fromRGB(40, 120, 160),
    },
    DevilFruit_User = {
        DisplayName = "Devil Fruit User",
        HP = 95,
        Atk = 13,
        Def = 4,
        Spd = 11,
        XP = 60,
        Behaviors = { B.Ranged, B.Dodger },
        AttackRange = 30,
        DetectRange = 40,
        Abilities = { "ElementalBurst", "SpiritBlast" },
        LootTable = "Rare",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(3, 5, 3),
        Color = Color3.fromRGB(200, 200, 40),
    },
    Hollow = {
        DisplayName = "Hollow",
        HP = 75,
        Atk = 10,
        Def = 3,
        Spd = 13,
        XP = 30,
        Behaviors = { B.Melee, B.Charger },
        AttackRange = 5,
        DetectRange = 40,
        Abilities = {},
        LootTable = "Common",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(3, 5, 3),
        Color = Color3.fromRGB(240, 240, 220),
    },
    Arrancar = {
        DisplayName = "Arrancar",
        HP = 130,
        Atk = 12,
        Def = 7,
        Spd = 15,
        XP = 70,
        Behaviors = { B.Melee, B.Ranged, B.Berserk },
        AttackRange = 20,
        DetectRange = 40,
        Abilities = { "SpiritBlast", "AuraWall" },
        LootTable = "Uncommon",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(3, 5, 3),
        Color = Color3.fromRGB(200, 200, 240),
    },
    Abnormal_Titan = {
        DisplayName = "Abnormal Titan",
        HP = 200,
        Atk = 15,
        Def = 10,
        Spd = 12,
        XP = 80,
        Behaviors = { B.Melee, B.Charger },
        AttackRange = 10,
        DetectRange = 50,
        Abilities = {},
        LootTable = "Uncommon",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(8, 14, 8),
        Color = Color3.fromRGB(220, 180, 140),
    },

    -- Theme 3: Cursed Sea Temple
    Fishman_Warrior = {
        DisplayName = "Fishman Warrior",
        HP = 90,
        Atk = 10,
        Def = 9,
        Spd = 10,
        XP = 40,
        Behaviors = { B.Melee, B.Shielder },
        AttackRange = 6,
        DetectRange = 35,
        Abilities = {},
        LootTable = "Common",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(4, 7, 4),
        Color = Color3.fromRGB(40, 140, 180),
    },

    -- Theme 4: Soul Society Catacombs
    Rogue_Reaper = {
        DisplayName = "Rogue Soul Reaper",
        HP = 115,
        Atk = 13,
        Def = 8,
        Spd = 14,
        XP = 55,
        Behaviors = { B.Melee, B.Ranged, B.Dodger },
        AttackRange = 18,
        DetectRange = 40,
        Abilities = { "BasicSlash", "ShadowStep" },
        LootTable = "Uncommon",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(3, 5, 3),
        Color = Color3.fromRGB(60, 60, 100),
    },

    -- Theme 5: Titan Fortress
    Armored_Titan = {
        DisplayName = "Armored Titan",
        HP = 300,
        Atk = 16,
        Def = 20,
        Spd = 7,
        XP = 90,
        Behaviors = { B.Melee, B.Charger, B.Shielder },
        AttackRange = 10,
        DetectRange = 45,
        Abilities = {},
        LootTable = "Uncommon",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(10, 18, 10),
        Color = Color3.fromRGB(160, 120, 80),
    },
    Beast_Titan = {
        DisplayName = "Beast Titan",
        HP = 260,
        Atk = 20,
        Def = 12,
        Spd = 11,
        XP = 85,
        Behaviors = { B.Ranged, B.Summoner, B.Berserk },
        AttackRange = 40,
        DetectRange = 55,
        Abilities = {},
        LootTable = "Uncommon",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(12, 22, 12),
        Color = Color3.fromRGB(180, 150, 100),
        SummonEnemy = "Abnormal_Titan",
        MaxSummons = 2,
    },

    -- ===== SPECIALTY ENEMIES =====

    -- Kamikaze: fast, low HP, explodes on death for AOE fire damage.
    -- The explosion is handled by GameManager (same as Explosive modifier).
    -- IsBomber attribute tells GM to treat its death like the Explosive modifier.
    Kamikaze_Imp = {
        DisplayName = "Kamikaze Imp",
        HP = 35,
        Atk = 4,
        Def = 0,
        Spd = 22,
        XP = 25,
        Behaviors = { B.Melee, B.Charger },
        AttackRange = 4,
        DetectRange = 40,
        Abilities = {},
        LootTable = "Common",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(2, 3, 2),
        Color = Color3.fromRGB(255, 80, 20),
        IsBomber = true,           -- triggers death explosion in GameManager
        BombRadius = 10,
        BombDamage = 30,
    },

    -- Necromancer: slow, low HP, ranged. Every 15 seconds targets a recently dead enemy
    -- position (stored via DeadEnemyPositions) and "revives" it by spawning a Shadow_Clone.
    -- Implemented via Summoner behavior flag using SummonEnemy = "Shadow_Clone".
    Necromancer = {
        DisplayName = "Necromancer",
        HP = 80,
        Atk = 7,
        Def = 3,
        Spd = 5,
        XP = 60,
        Behaviors = { B.Ranged, B.Summoner },
        AttackRange = 28,
        DetectRange = 45,
        Abilities = { "SoulDrain" },
        LootTable = "Uncommon",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(3, 5, 3),
        Color = Color3.fromRGB(100, 20, 120),
        SummonEnemy = "Shadow_Clone",
        MaxSummons = 4,
        SummonCooldown = 12,  -- faster revive than regular Summoner
    },

    -- Shield Templar: frontal attacks only deal 10% damage (Shielder behavior).
    -- Must be flanked or hit from behind for full damage.
    -- In EnemyAI, Shielder behavior already blocks frontal attacks;
    -- Shield_Templar uses it with higher values.
    Shield_Templar = {
        DisplayName = "Shield Templar",
        HP = 160,
        Atk = 13,
        Def = 22,
        Spd = 8,
        XP = 70,
        Behaviors = { B.Melee, B.Shielder },
        AttackRange = 6,
        DetectRange = 30,
        Abilities = { "IronDefense" },
        LootTable = "Uncommon",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(4, 7, 4),
        Color = Color3.fromRGB(160, 160, 200),
        FrontalDamageReduct = 0.90,  -- 90% reduction from the front
    },

    -- ===== BOSSES =====
    -- Each boss carries:
    --   LoreKey         — key into LoreData.BossDialogue for personality + dialogue lines
    --   PhaseThresholds — HP% triggers for phase transitions (dialogue + stat escalation)
    --   PhaseAbilities  — additional abilities unlocked at each phase transition
    --   PhaseDescription— narrative summary of what changes per phase (read by HUD/GameManager)

    DemonLord = {
        DisplayName = "Demon Lord Muzan",
        LoreKey     = "DemonLord",
        Personality = "Contemptuous and ancient.  Does not consider you a threat until forced to.",
        HP = 1500,
        Atk = 26,
        Def = 18,
        Spd = 16,
        XP = 500,
        Behaviors = { B.Melee, B.Ranged, B.Berserk, B.Boss },
        AttackRange = 15,
        DetectRange = 60,
        Abilities = { "BladeTornado", "ElementalBurst", "BankaiFrenzy" },
        LootTable = "Boss",
        -- Portrait image shown on the boss's in-world billboard.
        -- Upload this image to Roblox to get an rbxassetid for production.
        PortraitImage = "https://cdn.openart.ai/openart-ai/production/2026-04/create-image/MD6jN5KEo6ZXHc8CsF8i/0217764008578350eb6750cc7dc4c5e11333efa00d940ee67adec_0_1776400868290_3c016158.jpeg",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(6, 10, 6),
        Color = Color3.fromRGB(20, 0, 30),
        -- Phase 1 → Phase 2 at 70% HP: gains speed and a new ability
        -- Phase 2 → Phase 3 at 40% HP: full enrage — attack speed doubles, leaves fire trails
        PhaseThresholds = { 0.7, 0.4 },
        PhaseAbilities  = {
            [1] = {},                              -- starting abilities
            [2] = { "RagingRush" },                -- phase 2 adds RagingRush
            [3] = { "UltimateKamehameha" },        -- phase 3 adds beam attack
        },
        PhaseDescriptions = {
            [2] = "Muzan's patience ends.  He starts charging — faster, angrier.",
            [3] = "Full demonic form.  The room fills with corruption.  He is no longer holding back.",
        },
        PhaseStatMults = {
            [2] = { AtkMult = 1.35, SpdAdd = 4 },
            [3] = { AtkMult = 1.70, SpdAdd = 8, LeaveFireTrails = true },
        },
        BossMusic = "rbxassetid://0",
    },

    ShadowLord = {
        DisplayName = "Shadow Lord Madara",
        LoreKey     = "ShadowLord",
        Personality = "Calm and deliberate.  Finds the fight academically interesting.",
        HP = 1800,
        Atk = 30,
        Def = 15,
        Spd = 20,
        XP = 600,
        Behaviors = { B.Melee, B.Ranged, B.Summoner, B.Dodger, B.Boss },
        AttackRange = 20,
        DetectRange = 60,
        Abilities = { "ShadowStep", "UltimateKamehameha", "DeathMark" },
        LootTable = "Boss",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(5, 9, 5),
        Color = Color3.fromRGB(10, 10, 40),
        SummonEnemy = "Shadow_Clone",
        MaxSummons = 6,
        -- Phase 1 → Phase 2 at 60%: begins summon spam + DeathMark on multiple targets
        -- Phase 2 → Phase 3 at 30%: teleports randomly every 3 seconds, disables dodge window
        PhaseThresholds = { 0.6, 0.3 },
        PhaseAbilities  = {
            [1] = {},
            [2] = { "ShadowStep", "DeathMark" },
            [3] = { "ShadowStep", "DeathMark", "UltimateKamehameha" },
        },
        PhaseDescriptions = {
            [2] = "Madara deploys shadow clones and begins marking targets with Death Marks.",
            [3] = "Madara stops holding formation.  He teleports constantly.  No clear pattern.",
        },
        PhaseStatMults = {
            [2] = { AtkMult = 1.35, SummonCooldownMult = 0.5 },
            [3] = { AtkMult = 1.60, RandomTeleport = true, TeleportInterval = 3 },
        },
        BossMusic = "rbxassetid://0",
    },

    AbyssalKing = {
        DisplayName = "Abyssal King Kaido",
        LoreKey     = "AbyssalKing",
        Personality = "Brutal, joyful, and loud.  Thinks battle is the only honest conversation.",
        HP = 2200,
        Atk = 34,
        Def = 22,
        Spd = 12,
        XP = 700,
        Behaviors = { B.Melee, B.Ranged, B.Berserk, B.Boss },
        AttackRange = 18,
        DetectRange = 60,
        Abilities = { "RagingRush", "AuraWall", "ThunderClap" },
        LootTable = "Boss",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(9, 15, 9),
        Color = Color3.fromRGB(20, 40, 120),
        -- Phase 1 → Phase 2 at 50%: grows larger, AOE attacks gain increased radius
        -- Phase 2 → Phase 3 at 25%: erupts, filling the room with tidal wave hazards every 8s
        PhaseThresholds = { 0.5, 0.25 },
        PhaseAbilities  = {
            [1] = {},
            [2] = { "RagingRush", "ThunderClap" },
            [3] = { "RagingRush", "ThunderClap", "AuraWall" },
        },
        PhaseDescriptions = {
            [2] = "Kaido LAUGHS.  His body swells.  Hit radius increases across the board.",
            [3] = "He stops pulling punches.  Tidal eruptions.  Stay mobile or get crushed.",
        },
        PhaseStatMults = {
            [2] = { AtkMult = 1.35, AOERadiusMult = 1.30 },
            [3] = { AtkMult = 1.75, AOERadiusMult = 1.60, TidalWaveInterval = 8 },
        },
        BossMusic = "rbxassetid://0",
    },

    VasteLorde = {
        DisplayName = "Vaste Lorde Aizen",
        LoreKey     = "VasteLorde",
        Personality = "Serene and condescending.  Has already calculated all outcomes — until now.",
        HP = 2000,
        Atk = 38,
        Def = 20,
        Spd = 18,
        XP = 800,
        Behaviors = { B.Ranged, B.Dodger, B.Summoner, B.Boss },
        AttackRange = 35,
        DetectRange = 60,
        Abilities = { "SpiritBlast", "BankaiFrenzy", "UltimateKamehameha", "ElementalBurst" },
        LootTable = "Boss",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(5, 9, 5),
        Color = Color3.fromRGB(240, 240, 255),
        SummonEnemy = "Arrancar",
        MaxSummons = 4,
        -- Phase 1 → Phase 2 at 60%: begins deploying illusion-clones (non-damaging decoys)
        -- Phase 2 → Phase 3 at 30%: "Final Calculation" — massive beam, defenses halved but Atk doubled
        PhaseThresholds = { 0.6, 0.3 },
        PhaseAbilities  = {
            [1] = {},
            [2] = { "SpiritBlast", "ElementalBurst" },
            [3] = { "SpiritBlast", "BankaiFrenzy", "UltimateKamehameha" },
        },
        PhaseDescriptions = {
            [2] = "Aizen summons decoy-clones.  Identify the real one.  The pattern isn't random.",
            [3] = "Final Calculation.  His defenses drop but so does everything else in the room.",
        },
        PhaseStatMults = {
            [2] = { AtkMult = 1.30, SummonDecoys = true, DecoysPerWave = 2 },
            [3] = { AtkMult = 2.0, DefMult = 0.5, FinalCalculation = true },
        },
        BossMusic = "rbxassetid://0",
    },

    ColossosTitan = {
        DisplayName = "Colossus Titan",
        LoreKey     = "ColossosTitan",
        Personality = "No words.  Pure Void-fused instinct.  The experiment that outlasted everything.",
        HP = 3000,
        Atk = 41,
        Def = 28,
        Spd = 8,
        XP = 1000,
        Behaviors = { B.Melee, B.Berserk, B.Boss },
        AttackRange = 20,
        DetectRange = 60,
        Abilities = { "RagingRush", "AuraWall" },
        LootTable = "Boss",
        ModelId = "rbxassetid://0",
        Size = Vector3.new(20, 40, 20),
        Color = Color3.fromRGB(200, 160, 120),
        -- Phase 1 → Phase 2 at 50%: erupts with steam — room shifts to permanent Lava Phase
        PhaseThresholds = { 0.5 },
        PhaseAbilities  = {
            [1] = {},
            [2] = { "RagingRush", "AuraWall" },
        },
        PhaseDescriptions = {
            [2] = "The Colossus erupts.  Steam fills the room.  The floor becomes lava.  Find the platforms.",
        },
        PhaseStatMults = {
            [2] = { AtkMult = 1.50, SpdAdd = 4, ForceLavaPhase = true },
        },
        BossMusic = "rbxassetid://0",
    },
}

-- Scale enemy stats for deeper floors
function EnemyData.GetScaledEnemy(enemyName, floor)
    local base = EnemyData.Enemies[enemyName]
    assert(base, "EnemyData: unknown enemy '" .. tostring(enemyName) .. "'")
    local scale = 1 + (floor - 1) * 0.12
    return {
        DisplayName = base.DisplayName,
        HP = math.floor(base.HP * scale),
        Atk = math.floor(base.Atk * scale),
        Def = math.floor(base.Def * scale),
        Spd = base.Spd,
        XP = math.floor(base.XP * (1 + (floor - 1) * 0.08)),
        Behaviors = base.Behaviors,
        AttackRange = base.AttackRange,
        DetectRange = base.DetectRange,
        Abilities   = { table.unpack(base.Abilities) },  -- shallow copy so phase ability inserts don't mutate the base
        LootTable = base.LootTable,
        Size = base.Size,
        Color = base.Color,
        ModelId = base.ModelId,
        SummonEnemy         = base.SummonEnemy,
        MaxSummons          = base.MaxSummons,
        SummonCooldown      = base.SummonCooldown,
        -- Boss-specific fields (nil for regular enemies)
        PhaseThresholds     = base.PhaseThresholds,
        PhaseAbilities      = base.PhaseAbilities,
        PhaseDescriptions   = base.PhaseDescriptions,
        PhaseStatMults      = base.PhaseStatMults,
        LoreKey             = base.LoreKey,
        Personality         = base.Personality,
        PortraitImage       = base.PortraitImage,
        BossMusic           = base.BossMusic,
        -- Modifier / specialty fields
        FrontalDamageReduct = base.FrontalDamageReduct,
        IsBomber            = base.IsBomber,
        BombRadius          = base.BombRadius,
        BombDamage          = base.BombDamage,
    }
end

return EnemyData
