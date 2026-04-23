-- CurseData.lua
-- Risk-reward curse system.  Players can accept a Curse to gain a significant
-- bonus at the cost of a meaningful handicap.  Curses last the entire run.
--
-- Curses are offered in a new "Sealed Chamber" room type (see RoomData.lua).
-- Only one Curse can be active per run.  Accepting a second offer replaces the first.
--
-- Integration:
--   CombatSystem reads CurseData.GetActiveStatModifiers(player) each heartbeat.
--   LootSystem reads CurseData.GetLootModifiers(player) before drop tables.
--   GameManager reads CurseData.GetShopModifiers(player) before shop price calc.
--   HUD displays active curse name + icon permanently once accepted.

local CurseData = {}

-- ──────────────────────────────────────────────────────────────────────────
-- CURSE DEFINITIONS
-- ──────────────────────────────────────────────────────────────────────────

CurseData.Curses = {

    -- ─── TIER 1: Mild curse, mild reward ─────────────────────────────────

    {
        Id          = "VoidTaint",
        Name        = "Void Taint",
        Tier        = 1,
        Icon        = "🌑",
        FlavorText  = "A splinter of Void energy has lodged itself in your soul.  It costs you something.  But it also feeds you.",
        Description = "Take 15% more damage from all sources.",
        Bonus       = "Elite room loot quality increases by one tier (Uncommon→Rare, Rare→Boss-tier).",
        -- Stat modifiers applied to the player
        StatMods = {
            DamageTakenMultiplier = 1.15,
        },
        -- Loot modifiers applied by LootSystem
        LootMods = {
            EliteTableUpgrade = 1,   -- bump loot table by 1 tier for elite rooms
        },
        AuraColor   = Color3.fromRGB(80, 0, 120),
    },

    {
        Id          = "BloodPrice",
        Name        = "Blood Price",
        Tier        = 1,
        Icon        = "🩸",
        FlavorText  = "The Void demands a tax.  Every minute, it collects.",
        Description = "Lose 8 HP every 30 seconds (can't kill you below 1 HP).",
        Bonus       = "All enemy gold drops are increased by 50%.",
        StatMods = {
            PeriodicDamage     = 8,
            PeriodicDamageInterval = 30,
            PeriodicDamageFloor    = 1,   -- minimum HP the drain respects
        },
        LootMods = {
            GoldDropMultiplier = 1.50,
        },
        AuraColor   = Color3.fromRGB(180, 0, 0),
    },

    -- ─── TIER 2: Moderate curse, strong reward ────────────────────────────

    {
        Id          = "WeakenedArmor",
        Name        = "Shattered Guard",
        Tier        = 2,
        Icon        = "🛡",
        FlavorText  = "Your defensive resonance has been cracked open.  The Coalition vendor smells opportunity.",
        Description = "Defense reduced by 35% (multiplicative).",
        Bonus       = "All shop prices are reduced by 40%.",
        StatMods = {
            DefMultiplier = 0.65,   -- 35% def reduction
        },
        ShopMods = {
            PriceMultiplier = 0.60,   -- 40% discount
        },
        AuraColor   = Color3.fromRGB(100, 100, 40),
    },

    {
        Id          = "ManaHunger",
        Name        = "Mana Hunger",
        Tier        = 2,
        Icon        = "💧",
        FlavorText  = "Something in the Shard is drinking your energy.  But scarcity breeds resourcefulness.",
        Description = "Max MP reduced by 40%.  MP regeneration stops entirely.",
        Bonus       = "All ability damage increased by 25%.",
        StatMods = {
            MaxMPMultiplier   = 0.60,
            MPRegenMultiplier = 0,    -- disables all MP regen
            AbilityDmgBonus   = 1.25,
        },
        AuraColor   = Color3.fromRGB(20, 60, 180),
    },

    -- ─── TIER 3: Heavy curse, massive reward ─────────────────────────────

    {
        Id          = "BerserkerOath",
        Name        = "Berserker's Oath",
        Tier        = 3,
        Icon        = "⚔️",
        FlavorText  = "You swore to the Void: no retreat, no recovery.  In exchange, it answers your rage.",
        Description = "Cannot use any healing abilities, items, or rest rooms during this run.",
        Bonus       = "Awakening gauge fills at 2× the normal rate.",
        StatMods = {
            HealingBlocked   = true,   -- CombatSystem checks this before applying heals
            RestRoomBlocked  = true,   -- GameManager checks this before applying rest
            AwakeningGaugeMult = 2.0,
        },
        AuraColor   = Color3.fromRGB(220, 60, 0),
    },

    {
        Id          = "GlassCannon",
        Name        = "Glass Cannon",
        Tier        = 3,
        Icon        = "💎",
        FlavorText  = "The Void offers a trade: your resilience for raw power.  Everything in or everything out.",
        Description = "Maximum HP is capped at 50% of your normal max (current HP reduced to match if over cap).",
        Bonus       = "Attack increased by 45%.",
        StatMods = {
            MaxHPCapMultiplier = 0.50,
            AtkMultiplier      = 1.45,
        },
        AuraColor   = Color3.fromRGB(255, 220, 30),
    },

    {
        Id          = "EchoOfDeath",
        Name        = "Echo of Death",
        Tier        = 3,
        Icon        = "💀",
        FlavorText  = "A death mark follows you.  Every enemy in every room knows your face before you arrive.",
        Description = "All enemies in every room have the Berserker modifier forced on them.",
        Bonus       = "Boss loot table offers 4 choices instead of 3.  All Elite rewards are Boss-tier.",
        StatMods = {
            ForceEnemyModifier = "Berserker",
        },
        LootMods = {
            BossChoiceCount      = 4,
            EliteUseBossTable    = true,
        },
        AuraColor   = Color3.fromRGB(10, 10, 10),
    },
}

-- ──────────────────────────────────────────────────────────────────────────
-- SEALED CHAMBER ROOM CONFIG
-- ──────────────────────────────────────────────────────────────────────────

CurseData.SealedChamberConfig = {
    -- How many curse options to show the player at once
    OptionCount         = 2,
    -- Weighting: higher tiers less likely to appear
    TierWeights         = { [1] = 50, [2] = 35, [3] = 15 },
    -- Flavor text shown on the room door
    DoorText            = "A sealed door pulses with dark energy.  Something inside is waiting.",
    AcceptText          = "You step inside.  The door seals behind you.  Something shifts in your chest.",
    DeclineText         = "You step away.  The door's light dims.  Some offers only come once.",
}

-- ──────────────────────────────────────────────────────────────────────────
-- API
-- ──────────────────────────────────────────────────────────────────────────

-- Get a curse by Id
function CurseData.GetById(id)
    for _, c in ipairs(CurseData.Curses) do
        if c.Id == id then return c end
    end
    return nil
end

-- Generate N random curse options (weighted by tier)
function CurseData.GenerateOptions(count)
    count = count or CurseData.SealedChamberConfig.OptionCount
    local pool = {}
    local tw = CurseData.SealedChamberConfig.TierWeights
    for _, c in ipairs(CurseData.Curses) do
        local w = tw[c.Tier] or 0
        for _ = 1, w do table.insert(pool, c) end
    end

    local picked = {}
    local seen   = {}
    local tries  = 0
    while #picked < count and tries < 200 do
        tries = tries + 1
        local idx = math.random(#pool)
        local c = pool[idx]
        if not seen[c.Id] then
            seen[c.Id] = true
            table.insert(picked, c)
        end
    end
    return picked
end

-- Return the stat modifiers for the active curse (nil if no curse)
function CurseData.GetStatMods(curseId)
    if not curseId then return {} end
    local c = CurseData.GetById(curseId)
    return (c and c.StatMods) or {}
end

-- Return loot modifiers for the active curse
function CurseData.GetLootMods(curseId)
    if not curseId then return {} end
    local c = CurseData.GetById(curseId)
    return (c and c.LootMods) or {}
end

-- Return shop modifiers for the active curse
function CurseData.GetShopMods(curseId)
    if not curseId then return {} end
    local c = CurseData.GetById(curseId)
    return (c and c.ShopMods) or {}
end

return CurseData
