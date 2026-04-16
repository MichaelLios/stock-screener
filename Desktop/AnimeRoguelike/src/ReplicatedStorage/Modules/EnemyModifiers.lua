-- EnemyModifiers.lua
-- Defines every modifier type that can be rolled onto normal and elite enemies.
-- A modifier layers on top of base enemy stats to create high-tension moments.
--
-- Server usage (EnemyAI.SpawnEnemy):
--   local mod, name = EnemyModifiers.Roll(roomType, floor)
--   if name then
--       EnemyModifiers.ApplyStats(scaledEnemyData, name)
--       model:SetAttribute("Modifier", name)
--   end
--
-- The client reads the "Modifier" attribute to decide the crown colour.

local EnemyModifiers = {}

-- ────────────────────────────────────────────────
-- MODIFIER DEFINITIONS
-- ────────────────────────────────────────────────
-- StatMult keys map 1:1 to EnemyData fields that SpawnEnemy puts on the model.
-- BehaviourNote describes what runAI does with this modifier.

EnemyModifiers.Modifiers = {

    -- Blazing fast — hard to kite, easy to outburst.
    Fast = {
        DisplayName   = "Fast",
        Color         = Color3.fromRGB( 80, 220, 200),   -- teal
        StatMult      = { Spd = 1.75, AttackRange = 1.25 },
        BehaviourNote = "Speed × 1.75, attack range × 1.25. No special hook.",
    },

    -- Tank that chips away forever unless you have armour-piercing.
    Armored = {
        DisplayName   = "Armored",
        Color         = Color3.fromRGB(170, 170, 170),   -- steel grey
        StatMult      = { Def = 2.5, Spd = 0.72 },
        BehaviourNote = "Def × 2.5, Spd × 0.72. No special hook.",
    },

    -- Must be burst down — every swing heals it.
    Vampiric = {
        DisplayName   = "Vampiric",
        Color         = Color3.fromRGB(160,  40, 210),   -- deep purple
        StatMult      = { Atk = 1.25, HP = 1.2 },
        HealPercent   = 0.18,    -- heals 18 % of Atk after each hit
        BehaviourNote = "After each attack, heals self for HealPercent × Atk.",
    },

    -- Keep your distance — lethal if you trade HP finishing it.
    Explosive = {
        DisplayName    = "Explosive",
        Color          = Color3.fromRGB(255, 110,  20),  -- orange
        StatMult       = { HP = 0.75, Atk = 1.35 },
        BlastRadius    = 12,      -- studs
        BlastBaseDamage = 40,    -- + floor * 3 in GameManager
        BehaviourNote  = "On death: AOE Fire blast to all players within BlastRadius.",
    },

    -- Every hit slows movement; pairs with high-Def combos to be oppressive.
    Freezing = {
        DisplayName   = "Freezing",
        Color         = Color3.fromRGB(120, 200, 255),   -- ice blue
        StatMult      = { Atk = 0.85, Spd = 0.80 },
        SlowDuration  = 3,       -- seconds
        SlowWalkSpeed = 5,       -- replaces Roblox's default 16
        BehaviourNote = "After each attack, applies Slow debuff to target for SlowDuration s.",
    },

    -- Pure aggression from the first frame — never give it time to ramp up.
    Berserker = {
        DisplayName   = "Berserker",
        Color         = Color3.fromRGB(220,  40,  40),   -- blood red
        StatMult      = { Atk = 1.5, HP = 1.3, Spd = 1.2 },
        BehaviourNote = "Treated as permanently enraged (bypasses the 30 % HP threshold).",
    },
}

-- ────────────────────────────────────────────────
-- ROLL TABLE
-- ────────────────────────────────────────────────

local ROLL_TABLE = {
    { name = "Fast",      weight = 20 },
    { name = "Armored",   weight = 20 },
    { name = "Vampiric",  weight = 15 },
    { name = "Explosive", weight = 15 },
    { name = "Freezing",  weight = 15 },
    { name = "Berserker", weight = 15 },
}

local TOTAL_WEIGHT = 0
for _, e in ipairs(ROLL_TABLE) do TOTAL_WEIGHT = TOTAL_WEIGHT + e.weight end

-- ────────────────────────────────────────────────
-- PUBLIC API
-- ────────────────────────────────────────────────

-- Roll(roomType, floor)  →  (modifierData | nil,  modifierName | nil)
--
-- Elite rooms:  guaranteed modifier (100 %)
-- Combat rooms: 20 % base chance, +2 %/floor deeper, capped at 45 %
-- All others:   never (bosses are already special)
function EnemyModifiers.Roll(roomType, floor)
    floor = floor or 1
    local chance
    if roomType == "Elite" then
        chance = 1.0
    elseif roomType == "Combat" then
        chance = math.min(0.20 + (floor - 1) * 0.02, 0.45)
    else
        return nil, nil
    end

    if math.random() > chance then return nil, nil end

    local roll = math.random() * TOTAL_WEIGHT
    local cum  = 0
    for _, e in ipairs(ROLL_TABLE) do
        cum = cum + e.weight
        if roll <= cum then
            return EnemyModifiers.Modifiers[e.name], e.name
        end
    end
    return EnemyModifiers.Modifiers["Fast"], "Fast"   -- float safety fallback
end

-- ApplyStats(enemyData, modifierName)
-- Mutates the already-floor-scaled enemy data table in place.
-- Called before attributes are written onto the model.
function EnemyModifiers.ApplyStats(enemyData, modifierName)
    local mod = EnemyModifiers.Modifiers[modifierName]
    if not mod then return end
    for stat, mult in pairs(mod.StatMult) do
        if enemyData[stat] then
            -- Spd and AttackRange stay floats; everything else is an integer
            if stat == "Spd" or stat == "AttackRange" then
                enemyData[stat] = enemyData[stat] * mult
            else
                enemyData[stat] = math.max(1, math.floor(enemyData[stat] * mult))
            end
        end
    end
end

return EnemyModifiers
