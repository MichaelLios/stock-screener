-- SeasonalEvents.lua
-- Defines weekly rotating world modifiers and seasonal themes.
-- Each modifier is globally active for one real-world week, cycling based on os.time().
-- Seasonal overlays (tied to calendar months) add a visual + lore flavour on top.

local SeasonalEvents = {}

-- ────────────────────────────────────────────────
-- WEEKLY MODIFIERS  (cycle index 0–11 = 12 weeks)
-- ────────────────────────────────────────────────

SeasonalEvents.WeeklyModifiers = {
    -- 0 ──────────────────────────────────────────
    {
        Id          = "BloodMoon",
        Name        = "Blood Moon Rising",
        Icon        = "🌑",
        Color       = Color3.fromRGB(220, 40, 40),
        Description = "Enemy HP +30%, but all gold drops doubled and boss loot rarity increased.",
        HUDLabel    = "☽ Blood Moon",
        Modifiers   = {
            EnemyHPMult    = 1.30,
            GoldDropMult   = 2.00,
            BossLootRarity = "Legendary",
        },
    },
    -- 1 ──────────────────────────────────────────
    {
        Id          = "VoidSurge",
        Name        = "Void Surge",
        Icon        = "🌀",
        Color       = Color3.fromRGB(130, 30, 220),
        Description = "All abilities deal +20% damage. Enemy spawn rate +1 per Combat room.",
        HUDLabel    = "∿ Void Surge",
        Modifiers   = {
            PlayerAbilityDmgMult = 1.20,
            BonusEnemyPerRoom    = 1,
        },
    },
    -- 2 ──────────────────────────────────────────
    {
        Id          = "GoldRush",
        Name        = "Golden Age",
        Icon        = "💰",
        Color       = Color3.fromRGB(255, 215, 0),
        Description = "Shop prices –25%. All gold drops +50%. Treasure rooms guaranteed Rare.",
        HUDLabel    = "⭐ Golden Age",
        Modifiers   = {
            ShopCostMult      = 0.75,
            GoldDropMult      = 1.50,
            TreasureMinRarity = "Rare",
        },
    },
    -- 3 ──────────────────────────────────────────
    {
        Id          = "SpeedTrial",
        Name        = "Speed Trial",
        Icon        = "⚡",
        Color       = Color3.fromRGB(100, 200, 255),
        Description = "Player WalkSpeed +20%. Enemy WalkSpeed +15%. All cooldowns –10%.",
        HUDLabel    = "⚡ Speed Trial",
        Modifiers   = {
            PlayerSpdMult  = 1.20,
            EnemySpdMult   = 1.15,
            CDMult         = 0.90,
        },
    },
    -- 4 ──────────────────────────────────────────
    {
        Id          = "AbilityEcho",
        Name        = "Ability Echo",
        Icon        = "✦",
        Color       = Color3.fromRGB(200, 80, 255),
        Description = "Every ability has a 20% chance to fire twice at no extra MP cost.",
        HUDLabel    = "✦ Ability Echo",
        Modifiers   = {
            AbilityEchoChance = 0.20,
        },
    },
    -- 5 ──────────────────────────────────────────
    {
        Id          = "EliteRising",
        Name        = "Elite Rising",
        Icon        = "⚔",
        Color       = Color3.fromRGB(255, 90, 30),
        Description = "All Combat rooms become Elite rooms. Guaranteed Rare reward for each.",
        HUDLabel    = "⚔ Elite Rising",
        Modifiers   = {
            AllCombatBecomesElite = true,
        },
    },
    -- 6 ──────────────────────────────────────────
    {
        Id          = "HealingTide",
        Name        = "Healing Tide",
        Icon        = "💚",
        Color       = Color3.fromRGB(50, 220, 100),
        Description = "All healing sources +50%. Rest rooms also restore 1 random buff.",
        HUDLabel    = "💚 Healing Tide",
        Modifiers   = {
            HealMult           = 1.50,
            RestGivesRandomBuff = true,
        },
    },
    -- 7 ──────────────────────────────────────────
    {
        Id          = "CritStorm",
        Name        = "Crit Storm",
        Icon        = "🎯",
        Color       = Color3.fromRGB(255, 210, 50),
        Description = "+15% global crit chance. Critical hits stun enemies for 0.5 s.",
        HUDLabel    = "🎯 Crit Storm",
        Modifiers   = {
            BonusCritChance   = 0.15,
            CritAppliesStun   = true,
            CritStunDuration  = 0.5,
        },
    },
    -- 8 ──────────────────────────────────────────
    {
        Id          = "VoidFamine",
        Name        = "Void Famine",
        Icon        = "💀",
        Color       = Color3.fromRGB(80, 80, 80),
        Description = "HARD: MP costs +50%, enemy HP +20%. Reward: triple Mastery Points.",
        HUDLabel    = "💀 Void Famine",
        Modifiers   = {
            MPCostMult     = 1.50,
            EnemyHPMult    = 1.20,
            MasteryMult    = 3.00,
        },
    },
    -- 9 ──────────────────────────────────────────
    {
        Id          = "RuneBlessing",
        Name        = "Rune Blessing",
        Icon        = "🔮",
        Color       = Color3.fromRGB(160, 120, 255),
        Description = "Shrine upgrades cost –50%. One free Shrine upgrade on floor entry.",
        HUDLabel    = "🔮 Rune Blessing",
        Modifiers   = {
            ShrineCostMult        = 0.50,
            FreeShineUpgradePerFloor = true,
        },
    },
    -- 10 ─────────────────────────────────────────
    {
        Id          = "BountyWeek",
        Name        = "Bounty Week",
        Icon        = "📋",
        Color       = Color3.fromRGB(255, 160, 30),
        Description = "Bounty (gold) rewards from all sources +100%. Board refreshes with 2 extra contracts.",
        HUDLabel    = "📋 Bounty Week",
        Modifiers   = {
            GoldDropMult         = 2.00,
            BountyBoardBonusSlots = 2,
        },
    },
    -- 11 ─────────────────────────────────────────
    {
        Id          = "EvoAcceleration",
        Name        = "Evo Acceleration",
        Icon        = "🌀",
        Color       = Color3.fromRGB(80, 255, 200),
        Description = "Ability Evolution XP gained +100%. Stage-2 visual FX enhanced.",
        HUDLabel    = "🌀 Evo Acceleration",
        Modifiers   = {
            EvoXPMult = 2.00,
        },
    },
}

-- ────────────────────────────────────────────────
-- SEASONAL OVERLAYS  (calendar month index 1–12)
-- Light cosmetic/lore changes on top of the weekly modifier.
-- ────────────────────────────────────────────────

SeasonalEvents.SeasonalOverlays = {
    [1]  = { Name = "Winter's End",   Icon = "❄",  Tint = Color3.fromRGB(185, 225, 255), AmbientNote = "frost-touched air" },
    [2]  = { Name = "Void Valentine", Icon = "💜", Tint = Color3.fromRGB(200, 80, 180),  AmbientNote = "strange crimson petals" },
    [3]  = { Name = "Shard Spring",   Icon = "🌸", Tint = Color3.fromRGB(255, 180, 210), AmbientNote = "cherry blossom echoes" },
    [4]  = { Name = "Rising Tide",    Icon = "🌊", Tint = Color3.fromRGB(60, 180, 220),  AmbientNote = "salt spray in the air" },
    [5]  = { Name = "Storm Season",   Icon = "⛈",  Tint = Color3.fromRGB(100, 130, 200), AmbientNote = "distant thunder overhead" },
    [6]  = { Name = "Solstice Blaze", Icon = "☀",  Tint = Color3.fromRGB(255, 210, 80),  AmbientNote = "blinding noon heat" },
    [7]  = { Name = "Bankai Summer",  Icon = "🔥", Tint = Color3.fromRGB(255, 100, 20),  AmbientNote = "scorched resonance" },
    [8]  = { Name = "Abyss Tide",     Icon = "🌊", Tint = Color3.fromRGB(20, 150, 180),  AmbientNote = "deep current pressure" },
    [9]  = { Name = "Void Harvest",   Icon = "🍂", Tint = Color3.fromRGB(200, 120, 40),  AmbientNote = "falling corrupted leaves" },
    [10] = { Name = "Shadow Month",   Icon = "🌑", Tint = Color3.fromRGB(80, 20, 120),   AmbientNote = "shadow monarch stirs" },
    [11] = { Name = "Resonance Eve",  Icon = "✨", Tint = Color3.fromRGB(200, 160, 255), AmbientNote = "crystalline harmonics" },
    [12] = { Name = "Year of Void",   Icon = "🎆", Tint = Color3.fromRGB(255, 80, 80),   AmbientNote = "end-of-cycle resonance" },
}

-- ────────────────────────────────────────────────
-- PUBLIC API
-- ────────────────────────────────────────────────

-- Returns the current weekly modifier based on real-world time.
function SeasonalEvents.GetCurrentWeeklyModifier()
    local weekIndex = math.floor(os.time() / 604800) % #SeasonalEvents.WeeklyModifiers
    return SeasonalEvents.WeeklyModifiers[weekIndex + 1]
end

-- Returns the seasonal overlay for the current calendar month.
function SeasonalEvents.GetCurrentSeasonalOverlay()
    local month = tonumber(os.date("%m"))
    return SeasonalEvents.SeasonalOverlays[month] or SeasonalEvents.SeasonalOverlays[1]
end

-- Returns a combined packet suitable for broadcasting to clients.
function SeasonalEvents.GetCurrentEventPacket()
    local weekly   = SeasonalEvents.GetCurrentWeeklyModifier()
    local seasonal = SeasonalEvents.GetCurrentSeasonalOverlay()
    return {
        WeeklyId          = weekly.Id,
        WeeklyName        = weekly.Name,
        WeeklyIcon        = weekly.Icon,
        WeeklyColor       = weekly.Color,
        WeeklyDescription = weekly.Description,
        WeeklyHUDLabel    = weekly.HUDLabel,
        WeeklyModifiers   = weekly.Modifiers,
        SeasonalName      = seasonal.Name,
        SeasonalIcon      = seasonal.Icon,
        SeasonalTint      = seasonal.Tint,
        SeasonalAmbient   = seasonal.AmbientNote,
    }
end

return SeasonalEvents
