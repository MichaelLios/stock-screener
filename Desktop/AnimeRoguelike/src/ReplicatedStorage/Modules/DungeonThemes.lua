-- DungeonThemes.lua
-- One Piece / Sailor Piece island-themed dungeon environments.

local DungeonThemes = {}

DungeonThemes.Themes = {
    -- Floor 1, 6, 11… — East Blue pirate coast
    [1] = {
        Name        = "East Blue Coast",
        Description = "Rocky cliffs and rotting docks crawling with low-tier pirates.",
        FloorColor  = Color3.fromRGB(42, 60, 50),      -- mossy stone
        WallColor   = Color3.fromRGB(55, 75, 62),      -- weathered planks
        AmbientColor = Color3.fromRGB(120, 210, 160),  -- sea-green glow
        EnemyTypes  = { "Demon_Grunt", "Demon_Berserker", "Demon_Mage", "Kamikaze_Imp" },
        BossEnemy   = "DemonLord",
        MusicId     = "rbxassetid://0",
        TileSize    = Vector3.new(20, 8, 20),
        HazardChance = 0.08,
        HazardType  = "CannonTrap",
    },

    -- Floor 2, 7, 12… — Marine Fortress
    [2] = {
        Name        = "Marine Fortress",
        Description = "Towering white stone walls and iron gates manned by elite marines.",
        FloorColor  = Color3.fromRGB(200, 200, 190),   -- pale stone
        WallColor   = Color3.fromRGB(220, 220, 210),   -- bleached stone
        AmbientColor = Color3.fromRGB(100, 160, 230),  -- marine blue
        EnemyTypes  = { "Shadow_Clone", "Rogue_Ninja", "Puppet_Master", "Necromancer" },
        BossEnemy   = "ShadowLord",
        MusicId     = "rbxassetid://0",
        TileSize    = Vector3.new(20, 9, 20),
        HazardChance = 0.12,
        HazardType  = "SentinelTrap",
    },

    -- Floor 3, 8, 13… — Fishman Island
    [3] = {
        Name        = "Fishman Island",
        Description = "A glittering underwater kingdom lit by bioluminescent coral.",
        FloorColor  = Color3.fromRGB(10, 55, 80),      -- deep sea blue
        WallColor   = Color3.fromRGB(15, 75, 100),     -- dark ocean
        AmbientColor = Color3.fromRGB(60, 230, 210),   -- teal bioluminescent
        EnemyTypes  = { "SeaGuardian", "DevilFruit_User", "Fishman_Warrior" },
        BossEnemy   = "AbyssalKing",
        MusicId     = "rbxassetid://0",
        TileSize    = Vector3.new(20, 8, 20),
        HazardChance = 0.10,
        HazardType  = "CurrentTrap",
    },

    -- Floor 4, 9, 14… — Skypiea
    [4] = {
        Name        = "Skypiea",
        Description = "Golden ruins floating above the clouds, crackling with Mantra.",
        FloorColor  = Color3.fromRGB(210, 185, 100),   -- golden sandstone
        WallColor   = Color3.fromRGB(230, 210, 120),   -- sun-bleached gold
        AmbientColor = Color3.fromRGB(255, 235, 120),  -- holy golden light
        EnemyTypes  = { "Hollow", "Arrancar", "Rogue_Reaper", "Shield_Templar" },
        BossEnemy   = "VasteLorde",
        MusicId     = "rbxassetid://0",
        TileSize    = Vector3.new(20, 10, 20),
        HazardChance = 0.07,
        HazardType  = "LightningRod",
    },

    -- Floor 5, 10, 15… — Punk Hazard
    [5] = {
        Name        = "Punk Hazard",
        Description = "A forsaken island split between scorching fire and frozen tundra.",
        FloorColor  = Color3.fromRGB(110, 35, 25),     -- volcanic rock
        WallColor   = Color3.fromRGB(140, 45, 30),     -- red stone
        AmbientColor = Color3.fromRGB(255, 130, 60),   -- lava orange
        EnemyTypes  = { "Abnormal_Titan", "Armored_Titan", "Beast_Titan" },
        BossEnemy   = "ColossosTitan",
        MusicId     = "rbxassetid://0",
        TileSize    = Vector3.new(30, 14, 30),
        HazardChance = 0.06,
        HazardType  = "LavaBurst",
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
