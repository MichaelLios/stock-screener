-- RoomData.lua
-- Room templates: layout types, encounter configs, and special room logic.

local RoomData = {}

RoomData.RoomTypes = {
    Combat    = "Combat",
    Elite     = "Elite",        -- harder combat room, better rewards
    Boss      = "Boss",         -- floor boss / Corruption Anchor encounter
    Treasure  = "Treasure",     -- loot room, no enemies
    Shop      = "Shop",         -- merchant with random inventory
    Rest      = "Rest",         -- heal HP and MP
    Event     = "Event",        -- random narrative event
    Shrine    = "Shrine",       -- spend gold for a permanent stat blessing (pick 1 of 3)
    Ambush    = "Ambush",       -- surprise wave room — locked until cleared, guaranteed Rare reward
    SealedChamber = "SealedChamber", -- risk-reward curse room (new)
    Entrance  = "Entrance",     -- starting room each floor
    Exit      = "Exit",         -- leads to next floor after boss defeated
}

-- Floor layout: a graph of connected rooms generated at runtime
-- Each room node has a type, connections to other rooms, and a position in grid space
-- DungeonGenerator builds this from the following config

RoomData.FloorConfig = {
    MinRooms    = 9,
    MaxRooms    = 15,
    -- Weights for room type distribution (excluding Entrance, Boss, Exit which are forced)
    TypeWeights = {
        [RoomData.RoomTypes.Combat]        = 42,
        [RoomData.RoomTypes.Elite]         = 13,
        [RoomData.RoomTypes.Treasure]      = 9,
        [RoomData.RoomTypes.Shop]          = 7,
        [RoomData.RoomTypes.Rest]          = 8,
        [RoomData.RoomTypes.Event]         = 6,
        [RoomData.RoomTypes.Shrine]        = 7,   -- permanent stat blessing
        [RoomData.RoomTypes.Ambush]        = 5,   -- wave ambush, guaranteed Rare reward
        [RoomData.RoomTypes.SealedChamber] = 3,   -- risk-reward curse offer (rare by design)
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
    [RoomData.RoomTypes.Combat]        = { Min = 2, Max = 5 },
    [RoomData.RoomTypes.Elite]         = { Min = 3, Max = 6, EliteCount = 1 },
    [RoomData.RoomTypes.Boss]          = { Min = 1, Max = 1, IsBoss = true },
    [RoomData.RoomTypes.Treasure]      = { Min = 0, Max = 0 },
    [RoomData.RoomTypes.Shop]          = { Min = 0, Max = 0 },
    [RoomData.RoomTypes.Rest]          = { Min = 0, Max = 0 },
    [RoomData.RoomTypes.Event]         = { Min = 0, Max = 0 },
    [RoomData.RoomTypes.Shrine]        = { Min = 0, Max = 0 },
    [RoomData.RoomTypes.SealedChamber] = { Min = 0, Max = 0 },  -- no enemies; curse negotiation only
    -- Ambush: Wave 1 + Wave 2 (spawned in waves by GameManager, not up front)
    [RoomData.RoomTypes.Ambush]        = { Min = 3, Max = 5, IsAmbush = true, Waves = 2 },
}

-- Random narrative events (Drift Shard–flavored encounters)
-- Each event ties into the world's lore: the Void War's aftermath, Shard echoes, and player agency.
RoomData.Events = {
    {
        Id = "SpiritFragment",
        Title = "Wandering Echo",
        Lore = "A fragment of consciousness — someone who died in this Shard and never left.",
        Description = "A faint light drifts toward you.  It speaks without a mouth: 'Take what I couldn't finish with.'",
        Options = {
            { Text = "Accept the echo",  Effect = { Type = "LearnAbility", Pool = "SpiritUser" }, Risk = false },
            { Text = "Let it pass",      Effect = nil },
        },
    },
    {
        Id = "DemonContract",
        Title = "Void Bargain",
        Lore = "The Void doesn't just corrupt — it negotiates.",
        Description = "A voice with no source: 'I can make you stronger.  The cost is small.  Relatively.'",
        Options = {
            { Text = "Accept the offer",  Effect = { Type = "StatBoost", Atk = 12, HPCost = 35 } },
            { Text = "Refuse",            Effect = nil },
        },
    },
    {
        Id = "AncientScroll",
        Title = "Technique Remnant",
        Lore = "The Shards preserve knowledge alongside their corruption.",
        Description = "Wedged beneath a collapsed pillar: a sealed scroll.  The seal is from a world that no longer exists.",
        Options = {
            { Text = "Break the seal",  Effect = { Type = "LearnAbility", Pool = "Random" } },
            { Text = "Leave it",        Effect = nil },
        },
    },
    {
        Id = "SageTraining",
        Title = "Resonance Pocket",
        Lore = "Certain Shard areas compress time — what feels like hours is seconds outside.",
        Description = "You step into a stillness.  The world holds its breath.  A figure waits.  'I can teach you something.  But time costs something here.'",
        Options = {
            { Text = "Train (gain one level)",   Effect = { Type = "GainXP", Amount = "LevelUp" } },
            { Text = "Decline",                  Effect = nil },
        },
    },
    {
        Id = "RivalEncounter",
        Title = "Rival Shard Diver",
        Lore = "You're not the only one diving Shards.  Not everyone from the Waypoint is friendly.",
        Description = "Another diver.  They've been here longer.  Their eyes have that hollow look.  'There's only so much resonance in a Shard.  And I was here first.'",
        Options = {
            { Text = "Fight them",                    Effect = { Type = "MiniCombat", Enemy = "Rogue_Ninja", Reward = "Rare" } },
            { Text = "Offer to share (-50 gold each)", Effect = { Type = "GoldTrade", SelfCost = 50, SelfGain = 0, AbilityChance = 0.3 } },
        },
    },
    {
        Id = "VoidWhisper",
        Title = "Void Whisper",
        Lore = "The deeper you go, the louder the Void speaks.",
        Description = "Something addresses you directly.  Not an enemy.  The Void itself.  'You've come far.  I'm impressed.  Let me offer you something real.'",
        Options = {
            { Text = "Listen",  Effect = { Type = "StatBoost", AtkPercent = 0.10, MPCostPercent = 0.10 } },
            { Text = "Refuse",  Effect = nil },
        },
    },
    {
        Id = "FallenDiver",
        Title = "Fallen Diver's Cache",
        Lore = "Not everyone makes it back from a Shard run.",
        Description = "A body.  Coalition gear.  A pack still sealed.  They didn't make it out — but they left something behind.",
        Options = {
            { Text = "Take the pack",       Effect = { Type = "LootDrop", Table = "Uncommon" } },
            { Text = "Leave it (respect)",  Effect = { Type = "StatBoost", MaxHPPercent = 0.05 } },  -- honor gives a small permanent boost
        },
    },
    {
        Id = "ShardMemory",
        Title = "Shard Memory",
        Lore = "Shards sometimes replay their most traumatic moments.",
        Description = "For a second, the room shifts — you're watching the moment this world ended.  A warrior facing something enormous.  Then it's gone.  But you remember their technique.",
        Options = {
            { Text = "Focus on the memory",  Effect = { Type = "LearnAbility", Pool = "Random" } },
            { Text = "Look away",            Effect = nil },
        },
    },
    {
        Id = "AncientBlessing",
        Title = "Old World Shrine",
        Lore = "Some power in the Shards predates the Void War entirely.",
        Description = "A shrine that has no right to exist here, untouched by corruption.  Its inscription: 'For the worthy who still walk.'",
        Options = {
            { Text = "Pray at the shrine",  Effect = { Type = "FullRestore" }, Risk = false },
            { Text = "Pass by",             Effect = nil },
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
