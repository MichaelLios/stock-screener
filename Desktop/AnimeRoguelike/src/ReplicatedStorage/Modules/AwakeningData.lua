-- AwakeningData.lua
-- Per-archetype awakening definitions.
-- Each Awakening is a short-duration power surge tied to the player's archetype.
--
-- Fields:
--   Name          Display name shown on the activation overlay
--   Description   One-line flavour / tooltip
--   Duration      How many seconds the awakening lasts
--   AuraColor     BrickColor-style Color3 for the client aura VFX
--   AtkMult       Damage multiplier applied by CombatSystem during the window
--   ZeroCost      true → all ability MP costs are refunded while active
--   AutoCrit      true → every hit is a critical hit while active
--   DefMult       Damage received multiplier (< 1 reduces incoming damage)
--   GaugeOnDamageDealt   Gauge fill per 1 point of damage dealt to enemies
--   GaugeOnDamageTaken   Gauge fill per 1 point of damage received
--   MaxGauge             Gauge threshold required to activate (default 100)
--   BonusBuffs           Extra buff names applied during awakening (listed in STATUS_COLORS)

local AwakeningData = {}

AwakeningData.Awakenings = {

    Swordsman = {
        Name        = "Demon King's Blade",
        Description = "The swordsman transcends mortal limits. All slashes cleave through enemies.",
        Duration    = 15,
        AuraColor   = Color3.fromRGB(230, 50, 30),    -- crimson
        AtkMult     = 2.5,
        ZeroCost    = false,
        AutoCrit    = false,
        DefMult     = 1.0,
        -- Swordsman fills gauge by hitting hard; also gains from taking punishment
        GaugeOnDamageDealt = 0.4,
        GaugeOnDamageTaken = 0.6,
        MaxGauge    = 100,
        BonusBuffs  = {},
    },

    Mage = {
        Name        = "Arcane Overload",
        Description = "Spirit energy overflows. All abilities cost zero MP for the duration.",
        Duration    = 12,
        AuraColor   = Color3.fromRGB(120, 180, 255),  -- electric blue
        AtkMult     = 2.2,
        ZeroCost    = true,
        AutoCrit    = false,
        DefMult     = 1.0,
        -- Mage charges faster by dealing damage (reward aggressive casting)
        GaugeOnDamageDealt = 0.6,
        GaugeOnDamageTaken = 0.3,
        MaxGauge    = 100,
        BonusBuffs  = {},
    },

    Brawler = {
        Name        = "Iron Titan",
        Description = "The brawler becomes an unstoppable colossus. Damage received is halved.",
        Duration    = 18,
        AuraColor   = Color3.fromRGB(255, 140, 20),   -- amber-orange
        AtkMult     = 1.8,
        ZeroCost    = false,
        AutoCrit    = false,
        DefMult     = 0.5,   -- 50% incoming damage
        -- Brawler fills gauge by absorbing punishment
        GaugeOnDamageDealt = 0.2,
        GaugeOnDamageTaken = 0.9,
        MaxGauge    = 100,
        BonusBuffs  = {},
    },

    Assassin = {
        Name        = "Shadow God",
        Description = "The assassin becomes death itself. Every strike is a critical hit.",
        Duration    = 10,
        AuraColor   = Color3.fromRGB(160, 40, 255),   -- deep purple
        AtkMult     = 3.0,
        ZeroCost    = false,
        AutoCrit    = true,
        DefMult     = 1.0,
        -- Assassin charges exclusively through dealing damage — reward aggression
        GaugeOnDamageDealt = 0.8,
        GaugeOnDamageTaken = 0.1,
        MaxGauge    = 100,
        BonusBuffs  = {},
    },

    SpiritUser = {
        Name        = "Final Bankai",
        Description = "Absolute spirit release. Attack and spirit-restore effects are massively amplified.",
        Duration    = 15,
        AuraColor   = Color3.fromRGB(100, 240, 220),  -- teal-white
        AtkMult     = 2.5,
        ZeroCost    = false,
        AutoCrit    = false,
        DefMult     = 1.0,
        -- Spirit User fills gauge through a balance of offense and defense
        GaugeOnDamageDealt = 0.5,
        GaugeOnDamageTaken = 0.4,
        MaxGauge    = 100,
        BonusBuffs  = {},
    },
}

-- Returns the awakening config for an archetype name, or nil if none defined.
function AwakeningData.GetAwakening(archetypeName)
    return AwakeningData.Awakenings[archetypeName]
end

return AwakeningData
