-- DungeonThemes.lua
-- Drift Shard themes — each one a sealed fragment of a fallen world.
-- Indexed 1-5, cycling every 5 floors.  Deeper cycles use the same theme
-- with scaled enemy stats (see DungeonGenerator).
--
-- Each theme now carries:
--   ShardName       — lore name of this Drift Shard
--   EntryFlavor     — short text shown to player when the floor loads
--   MechanicKey     — index into DungeonMechanics for the floor's unique twist
--   BossKey         — key into LoreData.BossDialogue for boss personality lines

local DungeonThemes = {}

DungeonThemes.Themes = {

    -- ── Floor 1, 6, 11… — Demon Coast (East Blue Shard) ──────────────────
    [1] = {
        Name         = "Demon Coast",
        ShardName    = "The Bleeding Shore",
        Description  = "Rocky cliffs and rotting docks drowned in demonic corruption.",
        EntryFlavor  = "The salt air reeks of sulfur.  Somewhere ahead, something is screaming.  It doesn't sound human.",
        BossKey      = "DemonLord",
        MechanicKey  = 1,   -- Void Corruption: corruption stacks from enemy pools

        FloorColor   = Color3.fromRGB(42, 60, 50),      -- mossy stone
        WallColor    = Color3.fromRGB(55, 75, 62),      -- weathered planks
        AmbientColor = Color3.fromRGB(120, 210, 160),   -- sea-green glow
        EnemyTypes   = { "Demon_Grunt", "Demon_Berserker", "Demon_Mage", "Kamikaze_Imp" },
        BossEnemy    = "DemonLord",
        MusicId      = "rbxassetid://0",
        TileSize     = Vector3.new(120, 24, 120),
        HazardChance = 0.08,
        HazardType   = "CorruptionPool",

        -- ── Visual Identity ──────────────────────────────────────────────
        Lighting = {
            Ambient        = Color3.fromRGB(40,  75, 55),
            OutdoorAmbient = Color3.fromRGB(55,  90, 65),
            FogColor       = Color3.fromRGB(30,  65, 45),
            FogStart       = 55,
            FogEnd         = 280,
            Brightness     = 1.3,
            ClockTime      = 2.5,   -- dead of night
        },
        Atmosphere = {
            Density = 0.52, Offset = 0.15,
            Color   = Color3.fromRGB(55, 90, 60),
            Decay   = Color3.fromRGB(20, 50, 30),
            Glare   = 0.0, Haze = 1.2,
        },
        ParticleColor    = Color3.fromRGB(100, 200, 130),  -- corruption wisps
        AmbientSoundId   = "rbxassetid://0",               -- distant waves + demonic howls
        StatusEffectTint = Color3.fromRGB(80, 200, 100),   -- green corruption tint
    },

    -- ── Floor 2, 7, 12… — Iron Order (Marine Fortress Shard) ─────────────
    [2] = {
        Name         = "Iron Order",
        ShardName    = "The Fortress Eternal",
        Description  = "White stone corridors manned by marines who cannot remember why they're still fighting.",
        EntryFlavor  = "Every corridor looks exactly like the last.  The lights are still on.  Nobody comes to turn them off.",
        BossKey      = "ShadowLord",
        MechanicKey  = 2,   -- Patrol Response: slow clears trigger reinforcement spawns

        FloorColor   = Color3.fromRGB(200, 200, 190),   -- pale stone
        WallColor    = Color3.fromRGB(220, 220, 210),   -- bleached stone
        AmbientColor = Color3.fromRGB(100, 160, 230),   -- marine blue
        EnemyTypes   = { "Shadow_Clone", "Rogue_Ninja", "Puppet_Master", "Necromancer" },
        BossEnemy    = "ShadowLord",
        MusicId      = "rbxassetid://0",
        TileSize     = Vector3.new(120, 24, 120),
        HazardChance = 0.12,
        HazardType   = "SentinelTrap",

        -- ── Visual Identity ──────────────────────────────────────────────
        Lighting = {
            Ambient        = Color3.fromRGB(95,  125, 175),
            OutdoorAmbient = Color3.fromRGB(120, 150, 210),
            FogColor       = Color3.fromRGB(160, 185, 230),
            FogStart       = 120,
            FogEnd         = 600,
            Brightness     = 2.4,
            ClockTime      = 10.5,  -- overcast mid-morning
        },
        Atmosphere = {
            Density = 0.22, Offset = 0.28,
            Color   = Color3.fromRGB(160, 185, 220),
            Decay   = Color3.fromRGB(90, 125, 195),
            Glare   = 0.05, Haze = 0.35,
        },
        ParticleColor    = Color3.fromRGB(130, 180, 255),  -- blue dust motes
        AmbientSoundId   = "rbxassetid://0",               -- distant alarms + marching
        StatusEffectTint = Color3.fromRGB(100, 150, 255),  -- cold blue tint
    },

    -- ── Floor 3, 8, 13… — Drowned Kingdom (Fishman Island Shard) ─────────
    [3] = {
        Name         = "Drowned Kingdom",
        ShardName    = "The Abyssal Shard",
        Description  = "A bioluminescent underwater civilization sealed off from the surface and slowly eaten from below.",
        EntryFlavor  = "The bioluminescence is beautiful until you realize it's pulsing in sync with something large at the bottom of the trench.",
        BossKey      = "AbyssalKing",
        MechanicKey  = 3,   -- Deep Pressure: slowed movement, amplified healing

        FloorColor   = Color3.fromRGB(10, 55, 80),      -- deep sea blue
        WallColor    = Color3.fromRGB(15, 75, 100),     -- dark ocean
        AmbientColor = Color3.fromRGB(60, 230, 210),    -- teal bioluminescent
        EnemyTypes   = { "SeaGuardian", "DevilFruit_User", "Fishman_Warrior" },
        BossEnemy    = "AbyssalKing",
        MusicId      = "rbxassetid://0",
        TileSize     = Vector3.new(120, 24, 120),
        HazardChance = 0.10,
        HazardType   = "CurrentTrap",

        -- ── Visual Identity ──────────────────────────────────────────────
        Lighting = {
            Ambient        = Color3.fromRGB(10, 80, 100),
            OutdoorAmbient = Color3.fromRGB(15, 100, 130),
            FogColor       = Color3.fromRGB(8,  60,  90),
            FogStart       = 30,
            FogEnd         = 200,
            Brightness     = 0.9,
            ClockTime      = 0.0,   -- pitch black — only bioluminescence lights the way
        },
        Atmosphere = {
            Density = 0.68, Offset = 0.08,
            Color   = Color3.fromRGB(15, 90, 110),
            Decay   = Color3.fromRGB(5,  50,  70),
            Glare   = 0.0, Haze = 1.8,
        },
        ParticleColor    = Color3.fromRGB(50, 230, 210),   -- bioluminescent plankton
        AmbientSoundId   = "rbxassetid://0",               -- deep water pressure + whale song
        StatusEffectTint = Color3.fromRGB(50, 220, 200),   -- teal depth tint
    },

    -- ── Floor 4, 9, 14… — Heaven's Ruin (Skypiea Shard) ──────────────────
    [4] = {
        Name         = "Heaven's Ruin",
        ShardName    = "The Fallen Skies",
        Description  = "Golden ruins floating above the clouds.  Its people asked to be gods.  The Void answered.",
        EntryFlavor  = "The clouds below you are wrong.  Too still.  Too perfect.  Like a painting of clouds by someone who has never seen the sky.",
        BossKey      = "VasteLorde",
        MechanicKey  = 4,   -- Divine Judgment: lightning strikes + extended enemy telegraphs

        FloorColor   = Color3.fromRGB(210, 185, 100),   -- golden sandstone
        WallColor    = Color3.fromRGB(230, 210, 120),   -- sun-bleached gold
        AmbientColor = Color3.fromRGB(255, 235, 120),   -- holy golden light
        EnemyTypes   = { "Hollow", "Arrancar", "Rogue_Reaper", "Shield_Templar" },
        BossEnemy    = "VasteLorde",
        MusicId      = "rbxassetid://0",
        TileSize     = Vector3.new(120, 28, 120),
        HazardChance = 0.07,
        HazardType   = "LightningRod",

        -- ── Visual Identity ──────────────────────────────────────────────
        Lighting = {
            Ambient        = Color3.fromRGB(200, 185, 120),
            OutdoorAmbient = Color3.fromRGB(230, 215, 155),
            FogColor       = Color3.fromRGB(240, 230, 180),
            FogStart       = 200,
            FogEnd         = 1200,
            Brightness     = 3.5,
            ClockTime      = 13.0,  -- bright noon above the clouds
        },
        Atmosphere = {
            Density = 0.12, Offset = 0.42,
            Color   = Color3.fromRGB(235, 215, 160),
            Decay   = Color3.fromRGB(180, 150, 80),
            Glare   = 0.25, Haze = 0.18,
        },
        ParticleColor    = Color3.fromRGB(255, 245, 160),  -- holy golden motes
        AmbientSoundId   = "rbxassetid://0",               -- wind above the clouds + distant thunder
        StatusEffectTint = Color3.fromRGB(255, 235, 100),  -- golden divine tint
    },

    -- ── Floor 5, 10, 15… — The Broken World (Punk Hazard Shard) ──────────
    [5] = {
        Name         = "The Broken World",
        ShardName    = "Inferno-Tundra Shard",
        Description  = "An island torn in half by a catastrophic experiment.  The Void moved into the wound.",
        EntryFlavor  = "On your left: magma.  On your right: a glacier.  In the center: a forty-foot nightmare staring directly at you.",
        BossKey      = "ColossosTitan",
        MechanicKey  = 5,   -- Environmental Cycle: Lava Phase / Freeze Phase alternates

        FloorColor   = Color3.fromRGB(110, 35, 25),     -- volcanic rock
        WallColor    = Color3.fromRGB(140, 45, 30),     -- red stone
        AmbientColor = Color3.fromRGB(255, 130, 60),    -- lava orange
        EnemyTypes   = { "Abnormal_Titan", "Armored_Titan", "Beast_Titan" },
        BossEnemy    = "ColossosTitan",
        MusicId      = "rbxassetid://0",
        TileSize     = Vector3.new(120, 40, 120),
        HazardChance = 0.06,
        HazardType   = "LavaBurst",

        -- ── Visual Identity ──────────────────────────────────────────────
        Lighting = {
            Ambient        = Color3.fromRGB(160, 70, 30),
            OutdoorAmbient = Color3.fromRGB(200, 100, 40),
            FogColor       = Color3.fromRGB(140, 55, 20),
            FogStart       = 60,
            FogEnd         = 350,
            Brightness     = 1.8,
            ClockTime      = 17.5,  -- hellish sunset / eruption-light
        },
        Atmosphere = {
            Density = 0.45, Offset = 0.12,
            Color   = Color3.fromRGB(180, 80, 25),
            Decay   = Color3.fromRGB(100, 30, 10),
            Glare   = 0.08, Haze = 0.9,
        },
        ParticleColor    = Color3.fromRGB(255, 100, 20),   -- volcanic ash embers
        AmbientSoundId   = "rbxassetid://0",               -- magma rumble + ice cracking
        StatusEffectTint = Color3.fromRGB(255, 80, 20),    -- infernal orange tint
    },
}

-- Returns theme for a given floor number (cycles every 5 floors).
-- Also returns the cycle count (deeper = harder variant).
function DungeonThemes.GetThemeForFloor(floor)
    local themeCount = #DungeonThemes.Themes
    local index = ((floor - 1) % themeCount) + 1
    return DungeonThemes.Themes[index], math.floor((floor - 1) / themeCount) + 1
end

return DungeonThemes
