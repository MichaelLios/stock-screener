-- StartingBonusData.lua
-- Defines pre-run starting bonuses players can choose before entering a dungeon.
-- One bonus is active per run.  Bonuses are applied by GameManager on InitPlayer.
-- Some are always available; others require MetaProgression unlocks.
--
-- Applied fields:
--   BonusGold          — added to initial gold
--   HPPercent          — multiplier on MaxHP (0.25 = +25%)
--   AtkPercent         — multiplier on Atk
--   MPPercent          — multiplier on MaxMP
--   CDReduction        — subtracted from all cooldowns as a fraction (0.10 = –10%)
--   BonusAbility       — names an ability pre-loaded into slot 5
--   FirstKillGoldMult  — multiplies gold from first kill
--   EvoXPMult          — ability evolution XP gain multiplier
--   StartFullHP        — override: start at full HP regardless of carry-over
--   UnlockSecretEvent  — makes hidden events appear during this run

local StartingBonusData = {}

StartingBonusData.Bonuses = {

    -- ── ALWAYS AVAILABLE ──────────────────────────────────────────────────
    {
        Id          = "None",
        Name        = "No Bonus",
        Icon        = "—",
        Description = "Start with no modifications.  For the purist.",
        Free        = true,
        Applied     = {},
    },

    {
        Id          = "TreasureHunter",
        Name        = "Treasure Hunter",
        Icon        = "💰",
        Description = "Start with 150 extra gold.",
        Free        = true,
        Applied     = { BonusGold = 150 },
    },

    {
        Id          = "Resilience",
        Name        = "Resilience",
        Icon        = "🛡",
        Description = "Start this run with +25% Max HP.",
        Free        = true,
        Applied     = { HPPercent = 0.25 },
    },

    {
        Id          = "MageFocus",
        Name        = "Mage's Focus",
        Icon        = "🔮",
        Description = "Start at full MP and with +15% Max MP.",
        Free        = true,
        Applied     = { MPPercent = 0.15, StartFullHP = true },
    },

    -- ── UNLOCKED THROUGH PROGRESSION ─────────────────────────────────────
    {
        Id             = "BerserkerEdge",
        Name           = "Berserker's Edge",
        Icon           = "⚔",
        Description    = "Start at 70% HP but gain +25% Attack for the full run.",
        Applied        = { AtkPercent = 0.25, StartHPFraction = 0.70 },
        RequirePassive = "BonusDamage",  -- must have at least 1 level in this passive
    },

    {
        Id             = "QuickStart",
        Name           = "Quick Start",
        Icon           = "⚡",
        Description    = "All cooldowns –15% this run.  Start with QuickDash pre-equipped.",
        Applied        = { CDReduction = 0.15, BonusAbility = "QuickDash" },
        RequirePassive = "CooldownMastery",
    },

    {
        Id             = "AssassinsMark",
        Name           = "Assassin's Mark",
        Icon           = "🗡",
        Description    = "Your first kill each room gives 3× gold.",
        Applied        = { FirstKillGoldMult = 3.0 },
        RequirePassive = "LootFortune",
    },

    {
        Id             = "ShardSavant",
        Name           = "Shard Savant",
        Icon           = "🌀",
        Description    = "Ability Evolution XP gains +75% this run.  Hidden events are more likely.",
        Applied        = { EvoXPMult = 1.75, UnlockSecretEvent = true },
        RequirePassive = "ShardMemoryBonus",
    },

    {
        Id             = "VeteranCache",
        Name           = "Veteran's Cache",
        Icon           = "📦",
        Description    = "Start with one random Uncommon item already in your inventory.",
        Applied        = { StartingItemRarity = "Uncommon" },
        RequirePassive = "LootFortune",
    },
}

-- ────────────────────────────────────────────────
-- UTILITY
-- ────────────────────────────────────────────────

function StartingBonusData.GetById(id)
    for _, b in ipairs(StartingBonusData.Bonuses) do
        if b.Id == id then return b end
    end
    return nil
end

-- Returns all bonuses available to a player given their meta passive levels
function StartingBonusData.GetAvailable(unlockedPassives)
    local available = {}
    for _, b in ipairs(StartingBonusData.Bonuses) do
        if b.Free then
            table.insert(available, b)
        elseif b.RequirePassive and unlockedPassives and (unlockedPassives[b.RequirePassive] or 0) >= 1 then
            table.insert(available, b)
        end
    end
    return available
end

return StartingBonusData
