-- DungeonMechanics.lua
-- Unique per-dungeon gameplay twists that change HOW players approach each Shard.
-- Each mechanic is keyed to a DungeonThemes index (1-5, cycling every 5 floors).
--
-- Integration points:
--   GameManager calls DungeonMechanics.OnRoomEnter(themeIndex, room, players) each room entry.
--   GameManager calls DungeonMechanics.OnHeartbeat(themeIndex, room, players) each 3-second tick.
--   CombatSystem reads DungeonMechanics.GetActiveModifiers(themeIndex) for stat adjustments.
--   Clients receive mechanic data via UpdateHUD { MechanicUpdate = ... } for VFX/UI.

local DungeonMechanics = {}

-- ──────────────────────────────────────────────────────────────────────────
-- MECHANIC DEFINITIONS
-- ──────────────────────────────────────────────────────────────────────────

DungeonMechanics.Mechanics = {

    -- ── Theme 1: Demon Coast ─────────────────────────────────────────────
    [1] = {
        Name        = "Void Corruption",
        ShortDesc   = "Demon blood zones spread corruption stacks. Too many stacks = explosion.",
        FullDesc    = [[
VOID CORRUPTION: Defeated demons leave corruption pools on the ground for 8 seconds.
Walking through a pool applies 1 Corruption stack (max 5).
At 5 stacks you take a 60-damage explosion and all stacks reset.
Stacks decay 1 every 4 seconds while out of pools.

TIP: Corruption decays faster when standing still.  Kite enemies OUT of the pools.
]],
        -- Stat adjustments applied to all players in this dungeon
        StatModifiers = {
            -- Nothing passive — the mechanic is entirely zone-based
        },
        -- Combat feel changes
        HazardInterval  = 8,    -- pool duration in seconds
        StackExplosionDmg = 60,
        MaxStacks       = 5,
        StackDecayTime  = 4,    -- seconds per stack to decay while out of pool
        -- UI signal sent to clients
        HUDLabel        = "Corruption",
        HUDColor        = Color3.fromRGB(160, 20, 20),
        -- Per-floor bonus: surviving an explosion drops a Demon Core (temporary buff pickup)
        ExplosionSurvivalReward = { Type = "Pickup", Name = "Demon Core", Effect = { Atk = 8, Duration = 20 } },
    },

    -- ── Theme 2: Marine Fortress ─────────────────────────────────────────
    [2] = {
        Name        = "Patrol Response",
        ShortDesc   = "Clear rooms fast — slow clears trigger reinforcement patrols that chase you.",
        FullDesc    = [[
PATROL RESPONSE: Every 25 seconds a room is left uncleared, 2 Patrol Marines enter from
the nearest door and immediately seek the player.
Patrol Marines have the Berserker modifier and drop no loot.

Clearing a room in under 25 seconds earns a SWIFT CLEAR bonus: +15 gold per room.
Clearing all combat rooms before any patrol spawns earns PERFECT OPERATION: +100 gold.

TIP: Focus fire.  Don't split attention.  Ranged archtypes shine here.
]],
        StatModifiers = {
            -- Marines are slightly more alert: enemy Detect range +5
            EnemyDetectRangeBonus = 5,
        },
        PatrolInterval  = 25,   -- seconds before patrol spawns
        PatrolEnemyType = "Shadow_Clone",
        PatrolCount     = 2,
        SwiftClearGoldBonus    = 15,
        PerfectOperationBonus  = 100,
        HUDLabel        = "Patrol Timer",
        HUDColor        = Color3.fromRGB(100, 160, 230),
        TimerVisible    = true,   -- show countdown on HUD
    },

    -- ── Theme 3: Fishman Island ───────────────────────────────────────────
    [3] = {
        Name        = "Deep Pressure",
        ShortDesc   = "Movement slowed by deep-sea pressure, but healing effects are amplified.",
        FullDesc    = [[
DEEP PRESSURE: You are in deep-sea conditions.
All player movement speed is reduced by 25%.
All incoming healing (potions, abilities, rest rooms) is amplified by 40%.

Wave-Type enemies periodically summon water currents that push players back.
Standing in a Current deals no damage but interrupts ability casts.

TIP: Healing builds are incredibly strong here.  Lean into sustain over burst.
Brawlers and Spirit Users (with SoulDrain) are top-tier in this Shard.
]],
        StatModifiers = {
            PlayerSpdMultiplier = 0.75,   -- 25% speed reduction
            HealingAmplifier    = 1.40,   -- 40% more healing received
        },
        CurrentInterval = 18,    -- seconds between current waves
        CurrentPushForce = 40,
        HUDLabel        = "Pressure",
        HUDColor        = Color3.fromRGB(0, 200, 230),
        -- Passive bonus for staying in the dungeon: gradual HP regen at 2/sec
        PassiveRegen    = 2,
    },

    -- ── Theme 4: Skypiea ─────────────────────────────────────────────────
    [4] = {
        Name        = "Divine Judgment",
        ShortDesc   = "Lightning strikes random floor zones every 12 seconds. Enemies telegraph longer.",
        FullDesc    = [[
DIVINE JUDGMENT: Unstable Mantra energy in the ruins causes lightning storms.
Every 12 seconds, 3 random floor zones are marked (visible 2-second warning) then struck.
Each strike deals 35 damage and applies Stun for 1 second.

Benefit: Enemy attack telegraphs are extended by 0.5 seconds (easier to dodge).
Mantra Vision: You can see enemy ability telegraphs from 50% farther than normal.

TIP: Keep moving.  The zones are random but small.  Stun enemies near lightning zones
to force them into the strike.
]],
        StatModifiers = {
            EnemyTelegraphBonus = 0.5,     -- extra seconds enemies pause before attacking
            MantraVisionRange   = 1.5,     -- multiplier on telegraph visibility range
        },
        LightningInterval   = 12,
        LightningZoneCount  = 3,
        LightningWarningTime = 2,
        LightningDamage     = 35,
        LightningStunDur    = 1,
        HUDLabel            = "Mantra Storm",
        HUDColor            = Color3.fromRGB(255, 235, 80),
    },

    -- ── Theme 5: Punk Hazard ─────────────────────────────────────────────
    [5] = {
        Name        = "Environmental Cycle",
        ShortDesc   = "Every 30s the room shifts between Lava Phase (floor burns) and Freeze Phase (movement slowed).",
        FullDesc    = [[
ENVIRONMENTAL CYCLE: The Inferno-Tundra Shard alternates between two states every 30 seconds.

LAVA PHASE (red warning): Standing on the main floor deals 8 damage/sec.
  — Stay on raised platforms to avoid burn damage.
  — Fire-type attacks deal 20% bonus damage.

FREEZE PHASE (blue warning): Movement speed reduced by 30% for all.
  — Enemies' movement is also reduced — use it to kite.
  — Ice-type attacks deal 20% bonus damage.

A 5-second warning horn sounds before each phase transition.

TIP: Learn the room layout.  Raised platforms are your safe zones during Lava Phase.
Brawlers (high HP) can tank the burn.  Assassins should never be caught in Lava Phase.
]],
        StatModifiers = {
            -- Applied conditionally based on active phase (handled in GameManager)
            LavaPhaseFloorDPS   = 8,
            LavaPhaseBonusDmgMult = 1.20,
            FreezePhaseSpeedMult  = 0.70,
            FreezePhaseBonusDmgMult = 1.20,
        },
        CycleInterval       = 30,
        TransitionWarning   = 5,
        HUDLabel            = "Phase",
        HUDColorLava        = Color3.fromRGB(255, 90, 30),
        HUDColorFreeze      = Color3.fromRGB(150, 220, 255),
        StartPhase          = "Lava",  -- which phase starts first
    },
}

-- ──────────────────────────────────────────────────────────────────────────
-- ROOM-ENTRY NARRATIVE HOOKS
-- Each room type in this dungeon can optionally fire a short lore line.
-- ──────────────────────────────────────────────────────────────────────────

DungeonMechanics.RoomEntryLines = {
    [1] = {
        Combat   = { "Demonic howling ahead.", "The walls are sweating.", "Something doesn't want you here." },
        Elite    = { "This one is different.  Stronger.  More Void in it.", "An elite presence.  Even the lesser demons are afraid." },
        Rest     = { "A hollow in the cliff.  Still.  Safe — for now.", "The corruption hasn't reached here yet." },
        Boss     = { "The air pressure drops.  The Corruption Anchor is close.", "This is it.  The source of everything in this Shard." },
        Treasure = { "Someone stashed supplies before the demons found them.", "Loot from the last diver who didn't make it out." },
        Shop     = { "A merchant made it in somehow.  Don't ask how.", "A makeshift stall.  'Open for business.  Questions cost extra.'" },
        Shrine   = { "An old shrine predates the corruption.  Its power still holds.", "Something holy, here.  The Void hasn't touched it yet." },
    },
    [2] = {
        Combat   = { "Patrol detected.  They have perfect formation.", "Marines.  They haven't blinked in hours." },
        Elite    = { "An officer.  Look at the insignia — this one was important.", "High-value target.  High risk." },
        Rest     = { "A decommissioned cell block.  Quiet.", "The barracks.  Neat rows of beds, all still made." },
        Boss     = { "The command room.  He's waiting.", "A locked door.  Heavy.  Whatever is behind it wants you to turn back." },
    },
    [3] = {
        Combat   = { "The currents carry sound differently here.  You hear them before you see them.", "Bioluminescent shimmer ahead.  Something is in the water." },
        Elite    = { "A guardian-class.  The coral darkens around it.", "Armored.  Old.  This one was here before the Void." },
        Rest     = { "A pressure-sealed air pocket.  The water stays out.", "Warm light.  Coral above.  A moment to breathe." },
        Boss     = { "The trench.  The pressure here should kill you.  It hasn't — yet.", "Something vast shifts in the darkness below." },
    },
    [4] = {
        Combat   = { "Hollow wind.  The Hollows don't breathe — they just... appear.", "The ruins glow.  Not from the sun.  From them." },
        Elite    = { "Arrancar.  Once human.  Now something the Void finds useful.", "This one has a mask fragment.  Still part of whatever it used to be." },
        Rest     = { "A temple alcove.  The Mantra here is calm.", "Ancient stonework.  Untouched by corruption." },
        Boss     = { "The Sanctum.  Perfect quiet.  He's been here the whole time.", "The golden light intensifies.  Everything that happened here — he allowed it." },
    },
    [5] = {
        Combat   = { "The ground vibrates.  Titans don't announce themselves.", "Temperature spike — you're on the fire side.", "Temperature drop — ice side.  Watch your step." },
        Elite    = { "Armored.  You're going to need to get around the plating.", "An abnormal one.  Unpredictable movement pattern." },
        Rest     = { "A research bunker.  Sealed.  The scientists inside didn't make it — but they left supplies.", "Between the fire and the ice.  The safe strip.  For now." },
        Boss     = { "GROUND SHAKES.  The Colossus turns.", "Steam on the horizon.  The experiment stands at the far end." },
    },
}

-- ──────────────────────────────────────────────────────────────────────────
-- API
-- ──────────────────────────────────────────────────────────────────────────

-- Get the active mechanic for a floor number
function DungeonMechanics.GetMechanic(floor)
    local index = ((floor - 1) % 5) + 1
    return DungeonMechanics.Mechanics[index]
end

-- Get a random room-entry flavor line (returns nil if none defined for type)
function DungeonMechanics.GetRoomEntryLine(floor, roomType)
    local index = ((floor - 1) % 5) + 1
    local bank = DungeonMechanics.RoomEntryLines[index]
    if not bank then return nil end
    local lines = bank[roomType]
    if not lines or #lines == 0 then return nil end
    return lines[math.random(#lines)]
end

-- Returns stat modifiers that GameManager/CombatSystem should apply to players this floor
function DungeonMechanics.GetStatModifiers(floor)
    local mech = DungeonMechanics.GetMechanic(floor)
    if not mech then return {} end
    return mech.StatModifiers or {}
end

return DungeonMechanics
