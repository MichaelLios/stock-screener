-- RoomData.lua
-- Room templates: layout types, encounter configs, and special room logic.

local RoomData = {}

RoomData.RoomTypes = {
    Combat    = "Combat",
    Elite     = "Elite",     -- harder combat room, better rewards
    Boss      = "Boss",      -- floor boss encounter
    Treasure  = "Treasure",  -- loot room, no enemies
    Shop      = "Shop",      -- merchant with random inventory
    Rest      = "Rest",      -- heal HP and MP
    Event     = "Event",     -- random narrative event
    Shrine    = "Shrine",    -- spend gold for a permanent stat blessing (pick 1 of 3)
    Ambush    = "Ambush",    -- surprise wave room — locked until cleared, guaranteed Rare reward
    Entrance  = "Entrance",  -- starting room each floor
    Exit      = "Exit",      -- leads to next floor
}

-- Floor layout: a graph of connected rooms generated at runtime
-- Each room node has a type, connections to other rooms, and a position in grid space
-- DungeonGenerator builds this from the following config

RoomData.FloorConfig = {
    MinRooms    = 9,
    MaxRooms    = 15,
    -- Weights for room type distribution (excluding Entrance, Boss, Exit which are forced)
    TypeWeights = {
        [RoomData.RoomTypes.Combat]   = 44,
        [RoomData.RoomTypes.Elite]    = 14,
        [RoomData.RoomTypes.Treasure] = 10,
        [RoomData.RoomTypes.Shop]     = 7,
        [RoomData.RoomTypes.Rest]     = 8,
        [RoomData.RoomTypes.Event]    = 5,
        [RoomData.RoomTypes.Shrine]   = 7,   -- permanent upgrade room
        [RoomData.RoomTypes.Ambush]   = 5,   -- wave ambush with guaranteed rare reward
    },
    -- Guaranteed rooms per floor
    GuaranteedTypes = {
        RoomData.RoomTypes.Rest,
        RoomData.RoomTypes.Shop,
    },
    -- Boss room always exists, unlocks after all Combat rooms cleared
    BossLocked = true,
}

-- Enemy count per room type
RoomData.EnemyCount = {
    [RoomData.RoomTypes.Combat]  = { Min = 2, Max = 5 },
    [RoomData.RoomTypes.Elite]   = { Min = 3, Max = 6, EliteCount = 1 },
    [RoomData.RoomTypes.Boss]    = { Min = 1, Max = 1, IsBoss = true },
    [RoomData.RoomTypes.Treasure]= { Min = 0, Max = 0 },
    [RoomData.RoomTypes.Shop]    = { Min = 0, Max = 0 },
    [RoomData.RoomTypes.Rest]    = { Min = 0, Max = 0 },
    [RoomData.RoomTypes.Event]   = { Min = 0, Max = 0 },
    [RoomData.RoomTypes.Shrine]  = { Min = 0, Max = 0 },
    -- Ambush: Wave 1 + Wave 2 (spawned in waves by GameManager, not up front)
    [RoomData.RoomTypes.Ambush]  = { Min = 3, Max = 5, IsAmbush = true, Waves = 2 },
}

-- Random narrative events (anime-flavored flavor text and rewards)
RoomData.Events = {
    {
        Id = "SpiritFragment",
        Title = "Wandering Spirit",
        Description = "A lost spirit floats before you, offering its power in exchange for passage.",
        Options = {
            { Text = "Accept the power",  Effect = { Type = "LearnAbility", Pool = "SpiritUser" }, Risk = false },
            { Text = "Ignore it",         Effect = nil },
        },
    },
    {
        Id = "DemonContract",
        Title = "Demon Contract",
        Description = "A demon offers to enhance your strength — at a cost.",
        Options = {
            { Text = "Sign the contract", Effect = { Type = "StatBoost", Atk = 10, HPCost = 30 } },
            { Text = "Refuse",            Effect = nil },
        },
    },
    {
        Id = "AncientScroll",
        Title = "Ancient Technique Scroll",
        Description = "You find a scroll detailing a forgotten technique.",
        Options = {
            { Text = "Study it",  Effect = { Type = "LearnAbility", Pool = "Random" } },
            { Text = "Leave it",  Effect = nil },
        },
    },
    {
        Id = "SageTraining",
        Title = "Sage Training",
        Description = "You stumble into a pocket dimension. A sage offers to train you.",
        Options = {
            { Text = "Train (+1 Level, skip next room)", Effect = { Type = "GainXP", Amount = "LevelUp", SkipNextRoom = true } },
            { Text = "Decline", Effect = nil },
        },
    },
    {
        Id = "RivalEncounter",
        Title = "Rival Encounter",
        Description = "A rival appears! They challenge you to a duel.",
        Options = {
            { Text = "Fight them",  Effect = { Type = "MiniCombat", Enemy = "Rogue_Ninja", Reward = "Rare" } },
            { Text = "Flee (-5% Max HP this floor)", Effect = { Type = "DebuffTemp", MaxHPReduction = 0.05 } },
        },
    },
}

-- Shop stock generation: pick N random items from pool
RoomData.ShopStockCount = 4

-- Rest room: how much HP/MP to restore
RoomData.RestConfig = {
    HPRestore = 0.40,  -- 40% of max HP
    MPRestore = 0.40,  -- 40% of max MP
    -- Option: spend gold to fully heal
    FullHealCost = 80,
}

return RoomData
