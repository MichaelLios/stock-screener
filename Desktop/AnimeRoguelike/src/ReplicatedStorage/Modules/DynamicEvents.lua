-- DynamicEvents.lua
-- Dynamic room events that trigger randomly on room entry and alter gameplay mid-run.
-- Creates memorable moments of tension, excitement, and unexpected power spikes.
--
-- Integration:
--   DynamicEventManager.lua (server) uses this data to select and apply events.
--   Events are triggered on Combat, Elite, and Ambush room entry.
--   Active event data is sent to clients via UpdateHUD { DynamicEvent = data }.
--
-- Roll chances by room type (applied by DynamicEventManager):
--   Combat  → 18% chance
--   Elite   → 35% chance
--   Ambush  → 55% chance (always dramatic)
--   Boss    → never (boss fights are scripted)

local DynamicEvents = {}

DynamicEvents.RollChance = {
    Combat = 0.18,
    Elite  = 0.35,
    Ambush = 0.55,
}

DynamicEvents.Events = {

    -- ── TIER 1: POWER SPIKES (beneficial) ─────────────────────────────────────

    {
        Id          = "AncientBlessing",
        Name        = "Ancient Blessing",
        Tier        = 1,
        Rarity      = "Common",
        Weight      = 30,
        Icon        = "✨",
        Flavor      = "The Void retreats from this chamber for a breath. Ancient energy fills the room.",
        Description = "All players fully restored to max HP and MP on room entry.",
        HUDMessage  = "✨  ANCIENT BLESSING  — Full restore!",
        HUDColor    = Color3.fromRGB(100, 255, 160),
        Duration    = 0,   -- instant, no duration
        Modifiers   = {
            FullRestoreOnEntry = true,
        },
        Reward      = nil,
    },

    {
        Id          = "SpiritRush",
        Name        = "Spirit Rush",
        Tier        = 1,
        Rarity      = "Common",
        Weight      = 28,
        Icon        = "⚡",
        Flavor      = "Residual Void energy crackles through your abilities. Everything feels faster.",
        Description = "All ability cooldowns halved for 90 seconds.",
        HUDMessage  = "⚡  SPIRIT RUSH  — Cooldowns halved for 90s!",
        HUDColor    = Color3.fromRGB(100, 200, 255),
        Duration    = 90,
        Modifiers   = {
            CooldownMult = 0.5,
        },
        Reward      = nil,
    },

    {
        Id          = "ManaTide",
        Name        = "Mana Tide",
        Tier        = 1,
        Rarity      = "Common",
        Weight      = 25,
        Icon        = "💧",
        Flavor      = "A wave of spirit energy washes over the chamber. Your abilities flow without resistance.",
        Description = "All ability MP costs reduced to 0 for 60 seconds.",
        HUDMessage  = "💧  MANA TIDE  — Zero cost abilities for 60s!",
        HUDColor    = Color3.fromRGB(60, 130, 255),
        Duration    = 60,
        Modifiers   = {
            ZeroMPCost = true,
        },
        Reward      = nil,
    },

    -- ── TIER 2: RISK/REWARD ────────────────────────────────────────────────────

    {
        Id          = "BloodMoon",
        Name        = "Blood Moon",
        Tier        = 2,
        Rarity      = "Uncommon",
        Weight      = 20,
        Icon        = "🌑",
        Flavor      = "A Void eclipse. Enemies howl. The loot glows brighter.",
        Description = "All enemies have 50% more HP — but this room drops double gold.",
        HUDMessage  = "🌑  BLOOD MOON  — Enemies hardened, double gold!",
        HUDColor    = Color3.fromRGB(200, 50, 50),
        Duration    = 0,
        Modifiers   = {
            EnemyHPMult    = 1.50,
            GoldDropMult   = 2.0,
        },
        Reward      = nil,
    },

    {
        Id          = "EnemyWeakness",
        Name        = "Fractured Resonance",
        Tier        = 2,
        Rarity      = "Uncommon",
        Weight      = 22,
        Icon        = "💥",
        Flavor      = "Something interfered with the Void signal. These enemies are running on half power.",
        Description = "All enemies in this room have their HP halved.",
        HUDMessage  = "💥  FRACTURED RESONANCE  — Enemies weakened!",
        HUDColor    = Color3.fromRGB(255, 180, 50),
        Duration    = 0,
        Modifiers   = {
            EnemyHPMult = 0.50,
        },
        Reward      = nil,
    },

    {
        Id          = "VoidEcho",
        Name        = "Void Echo",
        Tier        = 2,
        Rarity      = "Uncommon",
        Weight      = 18,
        Icon        = "🌀",
        Flavor      = "The Void resonates with your power. For a moment, you feel unstoppable.",
        Description = "All players gain +100% Attack for 30 seconds.",
        HUDMessage  = "🌀  VOID ECHO  — Double Attack for 30s!",
        HUDColor    = Color3.fromRGB(160, 60, 255),
        Duration    = 30,
        Modifiers   = {
            PlayerAtkMult = 2.0,
        },
        Reward      = nil,
    },

    {
        Id          = "AbilityResonance",
        Name        = "Ability Resonance",
        Tier        = 2,
        Rarity      = "Uncommon",
        Weight      = 16,
        Icon        = "🔮",
        Flavor      = "The Shard amplifies your power signatures. Every ability crackles with extra force.",
        Description = "All ability damage +40% and each ability hit also triggers a small AOE blast.",
        HUDMessage  = "🔮  ABILITY RESONANCE  — +40% damage, chain AOE!",
        HUDColor    = Color3.fromRGB(220, 100, 255),
        Duration    = 0,
        Modifiers   = {
            AbilityDmgBonus    = 0.40,
            AbilityChainAOE    = true,
            AbilityChainRadius = 8,
            AbilityChainMult   = 0.35,
        },
        Reward      = nil,
    },

    -- ── TIER 3: VOLATILE (high risk, massive reward) ──────────────────────────

    {
        Id          = "ChaosMode",
        Name        = "Chaos Mode",
        Tier        = 3,
        Rarity      = "Rare",
        Weight      = 8,
        Icon        = "🎲",
        Flavor      = "Reality in this Shard fragment has stopped following rules.",
        Description = "All player and enemy stats are completely randomized each 15 seconds. Clear this room for a guaranteed RARE item.",
        HUDMessage  = "🎲  CHAOS MODE  — Stats randomize every 15s! Clear for rare loot!",
        HUDColor    = Color3.fromRGB(255, 80, 0),
        Duration    = 0,
        Modifiers   = {
            ChaosStatInterval = 15,
            ChaosStatMin      = 0.5,
            ChaosStatMax      = 2.5,
        },
        Reward      = { Type = "LootChoice", Table = "Rare", Choices = 3 },
    },

    {
        Id          = "VoidStorm",
        Name        = "Void Storm",
        Tier        = 3,
        Rarity      = "Rare",
        Weight      = 10,
        Icon        = "⛈",
        Flavor      = "The Void pulses violently. Your abilities echo back — twice as powerful, twice as costly.",
        Description = "Abilities fire TWICE per cast but cost double MP. Lasts the full room.",
        HUDMessage  = "⛈  VOID STORM  — Double casts, double costs!",
        HUDColor    = Color3.fromRGB(80, 0, 160),
        Duration    = 0,
        Modifiers   = {
            AbilityDoublefire  = true,
            MPCostMult         = 2.0,
        },
        Reward      = nil,
    },

    {
        Id          = "TimeWarp",
        Name        = "Time Warp",
        Tier        = 3,
        Rarity      = "Rare",
        Weight      = 7,
        Icon        = "⏳",
        Flavor      = "Time is folding in this room. Everything moves faster. You blink and a second has passed.",
        Description = "All entities (players AND enemies) move and attack 40% faster. Clear for 3× gold.",
        HUDMessage  = "⏳  TIME WARP  — Everything 40% faster! 3× gold on clear!",
        HUDColor    = Color3.fromRGB(255, 220, 0),
        Duration    = 0,
        Modifiers   = {
            AllSpdMult   = 1.40,
            GoldDropMult = 3.0,
        },
        Reward      = nil,
    },
}

-- ─── Weight table for weighted random selection ───────────────────────────────
local _weightTotal = 0
for _, evt in ipairs(DynamicEvents.Events) do
    _weightTotal = _weightTotal + (evt.Weight or 0)
end

-- ─── API ──────────────────────────────────────────────────────────────────────

function DynamicEvents.GetById(id)
    for _, evt in ipairs(DynamicEvents.Events) do
        if evt.Id == id then return evt end
    end
    return nil
end

function DynamicEvents.Roll(roomType)
    local chance = DynamicEvents.RollChance[roomType]
    if not chance or math.random() > chance then return nil end

    local roll = math.random() * _weightTotal
    local cumulative = 0
    for _, evt in ipairs(DynamicEvents.Events) do
        cumulative = cumulative + (evt.Weight or 0)
        if roll <= cumulative then return evt end
    end
    return DynamicEvents.Events[#DynamicEvents.Events]
end

return DynamicEvents
