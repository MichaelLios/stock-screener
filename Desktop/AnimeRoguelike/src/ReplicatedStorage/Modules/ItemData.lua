-- ItemData.lua
-- Defines all collectable items: weapons, armor, accessories, consumables.
-- Anime-themed with roguelike randomization in mind.

local ItemData = {}

local Rarity = {
    Common    = { Name = "Common",    Color = Color3.fromRGB(200, 200, 200), DropWeight = 60 },
    Uncommon  = { Name = "Uncommon",  Color = Color3.fromRGB(80, 200, 80),   DropWeight = 25 },
    Rare      = { Name = "Rare",      Color = Color3.fromRGB(60, 120, 240),  DropWeight = 10 },
    Epic      = { Name = "Epic",      Color = Color3.fromRGB(160, 60, 240),  DropWeight = 4 },
    Legendary = { Name = "Legendary", Color = Color3.fromRGB(240, 180, 40),  DropWeight = 1 },
}
ItemData.Rarity = Rarity

ItemData.Items = {
    -- ===== WEAPONS =====
    IronKatana = {
        Name = "Iron Katana",
        Type = "Weapon",
        Rarity = "Common",
        Description = "A standard-issue katana. Reliable but unremarkable.",
        Stats = { Atk = 8 },
        Icon = "rbxassetid://0",
    },
    DemonSlayerBlade = {
        Name = "Demon Slayer Blade",
        Type = "Weapon",
        Rarity = "Rare",
        Description = "A blade forged with Sun Breathing essence. Demons take 50% extra damage.",
        Stats = { Atk = 22 },
        BonusEffect = { DamageTypeBonus = "Demon", Multiplier = 1.5 },
        Icon = "rbxassetid://0",
    },
    SamehadadaFin = {
        Name = "Samehada Fragment",
        Type = "Weapon",
        Rarity = "Epic",
        Description = "A sliver of a chakra-absorbing blade. Absorbs 10% of damage dealt as MP.",
        Stats = { Atk = 28 },
        BonusEffect = { MPDrainOnHit = 0.10 },
        Icon = "rbxassetid://0",
    },
    ZanpakutoProto = {
        Name = "Unnamed Zanpakuto",
        Type = "Weapon",
        Rarity = "Uncommon",
        Description = "An unawakened soul reaper's blade with dormant power.",
        Stats = { Atk = 15 },
        BonusEffect = { SpiritDamageBonus = 0.15 },
        Icon = "rbxassetid://0",
    },
    SeaKingSword = {
        Name = "Sea King Fang Sword",
        Type = "Weapon",
        Rarity = "Rare",
        Description = "Carved from a sea king's tooth. Deals bonus damage to large enemies.",
        Stats = { Atk = 20 },
        BonusEffect = { LargeBonusMult = 1.3 },
        Icon = "rbxassetid://0",
    },
    StormBreaker = {
        Name = "Storm Breaker",
        Type = "Weapon",
        Rarity = "Legendary",
        Description = "A legendary thunder-imbued blade that crackles with lightning on every hit.",
        Stats = { Atk = 40, Spd = 5 },
        BonusEffect = { OnHitLightning = true, LightningDamage = 15, StunChance = 0.10 },
        Icon = "rbxassetid://0",
    },

    -- ===== ARMOR =====
    ClothRobe = {
        Name = "Cloth Robe",
        Type = "Armor",
        Rarity = "Common",
        Description = "Basic cloth armor. Better than nothing.",
        Stats = { Def = 5 },
        Icon = "rbxassetid://0",
    },
    DemonHide = {
        Name = "Demon Hide Armor",
        Type = "Armor",
        Rarity = "Uncommon",
        Description = "Armor made from demon hide. Resists fire damage.",
        Stats = { Def = 12 },
        BonusEffect = { FireResist = 0.25 },
        Icon = "rbxassetid://0",
    },
    ChakraPlate = {
        Name = "Chakra Plate",
        Type = "Armor",
        Rarity = "Rare",
        Description = "Armor reinforced with chakra. Reduces all damage by 10%.",
        Stats = { Def = 18, HP = 40 },
        BonusEffect = { DamageReduction = 0.10 },
        Icon = "rbxassetid://0",
    },
    SoulReaperHaori = {
        Name = "Captain's Haori",
        Type = "Armor",
        Rarity = "Epic",
        Description = "A captain's haori that amplifies spirit pressure. Boosts spirit abilities.",
        Stats = { Def = 14, MP = 60 },
        BonusEffect = { SpiritAbilityBonus = 0.20 },
        Icon = "rbxassetid://0",
    },
    TitanNape = {
        Name = "Nape Fragment Armor",
        Type = "Armor",
        Rarity = "Legendary",
        Description = "Crystallized titan power. Massively boosts HP and regeneration.",
        Stats = { Def = 25, HP = 150 },
        BonusEffect = { HPRegenPerSec = 5 },
        Icon = "rbxassetid://0",
    },

    -- ===== ACCESSORIES =====
    LuckyCharm = {
        Name = "Lucky Charm",
        Type = "Accessory",
        Rarity = "Common",
        Description = "A small trinket that brings good fortune. Increases loot drop rate.",
        Stats = {},
        BonusEffect = { LootBonus = 0.10 },
        Icon = "rbxassetid://0",
    },
    ChakraCrystal = {
        Name = "Chakra Crystal",
        Type = "Accessory",
        Rarity = "Uncommon",
        Description = "A crystallized node of chakra energy. Reduces ability cooldowns by 15%.",
        Stats = { MP = 30 },
        BonusEffect = { CooldownReduction = 0.15 },
        Icon = "rbxassetid://0",
    },
    SpiritOrb = {
        Name = "Spirit Orb",
        Type = "Accessory",
        Rarity = "Rare",
        Description = "Glows with spirit energy. Restores 5 MP per second.",
        Stats = { MP = 50 },
        BonusEffect = { MPRegenPerSec = 5 },
        Icon = "rbxassetid://0",
    },
    DevilFruitFragment = {
        Name = "Devil Fruit Fragment",
        Type = "Accessory",
        Rarity = "Epic",
        Description = "A fragment of a devil fruit that grants a random elemental power.",
        Stats = { Atk = 10, MP = 40 },
        BonusEffect = { RandomElement = true },
        Icon = "rbxassetid://0",
    },
    DragonBall = {
        Name = "Dragon Scale",
        Type = "Accessory",
        Rarity = "Legendary",
        Description = "A scale from a legendary dragon. Grants 10% of max HP back on kill.",
        Stats = { HP = 80, Atk = 15 },
        BonusEffect = { HPOnKill = 0.10 },
        Icon = "rbxassetid://0",
    },

    -- ===== CONSUMABLES =====
    HealthPotion = {
        Name = "Healing Elixir",
        Type = "Consumable",
        Rarity = "Common",
        Description = "Restores 80 HP instantly.",
        Use = { Type = "Heal", Amount = 80 },
        Icon = "rbxassetid://0",
        Stackable = true,
        MaxStack = 9,
    },
    ManaPotion = {
        Name = "Spirit Elixir",
        Type = "Consumable",
        Rarity = "Common",
        Description = "Restores 60 MP instantly.",
        Use = { Type = "RestoreMP", Amount = 60 },
        Icon = "rbxassetid://0",
        Stackable = true,
        MaxStack = 9,
    },
    FullElixir = {
        Name = "Full Recovery Elixir",
        Type = "Consumable",
        Rarity = "Rare",
        Description = "Fully restores HP and MP.",
        Use = { Type = "FullHeal" },
        Icon = "rbxassetid://0",
        Stackable = true,
        MaxStack = 3,
    },
    BerserkPill = {
        Name = "Berserk Pill",
        Type = "Consumable",
        Rarity = "Uncommon",
        Description = "Doubles attack for 15 seconds. Side effect: take 20% more damage.",
        Use = { Type = "Buff", Buff = "BerserkMode", Duration = 15 },
        Icon = "rbxassetid://0",
        Stackable = true,
        MaxStack = 5,
    },
    -- ===== ABILITY SCROLLS =====
    -- Picking one up immediately teaches the ability (auto-applied in LootSystem).
    Scroll_ThunderClap = {
        Name = "Scroll: Thunder Clap",
        Type = "AbilityScroll",
        Rarity = "Rare",
        Description = "Teaches the Thunder Clap breathing technique.",
        AbilityName = "ThunderClap",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_SkywardSlash = {
        Name = "Scroll: Skyward Slash",
        Type = "AbilityScroll",
        Rarity = "Rare",
        Description = "Teaches the Skyward Slash swordsmanship.",
        AbilityName = "SkywardSlash",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_CounterStance = {
        Name = "Scroll: Counter Stance",
        Type = "AbilityScroll",
        Rarity = "Uncommon",
        Description = "Teaches the Counter Stance defensive technique.",
        AbilityName = "CounterStance",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_FrostNova = {
        Name = "Scroll: Frost Nova",
        Type = "AbilityScroll",
        Rarity = "Rare",
        Description = "Teaches the Frost Nova ice magic.",
        AbilityName = "FrostNova",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_ArcaneOrb = {
        Name = "Scroll: Arcane Orb",
        Type = "AbilityScroll",
        Rarity = "Rare",
        Description = "Teaches the Arcane Orb mana technique.",
        AbilityName = "ArcaneOrb",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_GroundSlam = {
        Name = "Scroll: Ground Slam",
        Type = "AbilityScroll",
        Rarity = "Uncommon",
        Description = "Teaches the Ground Slam Haki technique.",
        AbilityName = "GroundSlam",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_IronDefense = {
        Name = "Scroll: Iron Defense",
        Type = "AbilityScroll",
        Rarity = "Rare",
        Description = "Teaches Armament Haki body coating.",
        AbilityName = "IronDefense",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_SmokeBomb = {
        Name = "Scroll: Smoke Bomb",
        Type = "AbilityScroll",
        Rarity = "Common",
        Description = "Teaches the Smoke Bomb ninja technique.",
        AbilityName = "SmokeBomb",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_VenomStrike = {
        Name = "Scroll: Venom Strike",
        Type = "AbilityScroll",
        Rarity = "Uncommon",
        Description = "Teaches the Venom Strike poison technique.",
        AbilityName = "VenomStrike",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_SoulDrain = {
        Name = "Scroll: Soul Drain",
        Type = "AbilityScroll",
        Rarity = "Rare",
        Description = "Teaches the forbidden Soul Drain technique.",
        AbilityName = "SoulDrain",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_ChakraStrike = {
        Name = "Scroll: Chakra Strike",
        Type = "AbilityScroll",
        Rarity = "Rare",
        Description = "Teaches the focused Chakra Strike.",
        AbilityName = "ChakraStrike",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_HealingSpring = {
        Name = "Scroll: Healing Spring",
        Type = "AbilityScroll",
        Rarity = "Uncommon",
        Description = "Teaches the Healing Spring restoration technique.",
        AbilityName = "HealingSpring",
        Icon = "rbxassetid://0",
        Stackable = false,
    },
    Scroll_SpiritCannon = {
        Name = "Scroll: Spirit Cannon",
        Type = "AbilityScroll",
        Rarity = "Epic",
        Description = "Teaches the legendary Spirit Cannon technique.",
        AbilityName = "UltimateKamehameha",
        Icon = "rbxassetid://0",
        Stackable = false,
    },

    ReviveScroll = {
        Name = "Phoenix Scroll",
        Type = "Consumable",
        Rarity = "Epic",
        Description = "Automatically revives you with 50% HP on death. One time use.",
        Use = { Type = "AutoRevive", HPPercent = 0.5 },
        Icon = "rbxassetid://0",
        Stackable = false,
        MaxStack = 1,
    },
}

-- Loot tables mapping enemy rarity tiers to weighted item pools
ItemData.LootTables = {
    Common = {
        { Item = "HealthPotion",  Weight = 40 },
        { Item = "ManaPotion",    Weight = 35 },
        { Item = "IronKatana",    Weight = 10 },
        { Item = "ClothRobe",     Weight = 10 },
        { Item = "LuckyCharm",    Weight = 5 },
    },
    Uncommon = {
        { Item = "HealthPotion",       Weight = 18 },
        { Item = "BerserkPill",        Weight = 13 },
        { Item = "ZanpakutoProto",     Weight = 12 },
        { Item = "DemonHide",          Weight = 12 },
        { Item = "ChakraCrystal",      Weight = 15 },
        { Item = "IronKatana",         Weight = 12 },
        { Item = "Scroll_CounterStance", Weight = 6 },
        { Item = "Scroll_GroundSlam",  Weight = 6 },
        { Item = "Scroll_VenomStrike", Weight = 6 },
        { Item = "Scroll_HealingSpring", Weight = 6 },
        { Item = "Scroll_SmokeBomb",   Weight = 4 },
    },
    Rare = {
        { Item = "DemonSlayerBlade",   Weight = 12 },
        { Item = "SeaKingSword",       Weight = 12 },
        { Item = "ChakraPlate",        Weight = 12 },
        { Item = "SpiritOrb",          Weight = 12 },
        { Item = "FullElixir",         Weight = 12 },
        { Item = "Scroll_ThunderClap", Weight = 8 },
        { Item = "Scroll_SkywardSlash", Weight = 8 },
        { Item = "Scroll_FrostNova",   Weight = 8 },
        { Item = "Scroll_IronDefense", Weight = 7 },
        { Item = "Scroll_ArcaneOrb",   Weight = 5 },
        { Item = "Scroll_SoulDrain",   Weight = 4 },
    },
    Boss = {
        { Item = "SamehadadaFin",        Weight = 12 },
        { Item = "SoulReaperHaori",      Weight = 12 },
        { Item = "DevilFruitFragment",   Weight = 12 },
        { Item = "StormBreaker",         Weight = 8 },
        { Item = "TitanNape",            Weight = 8 },
        { Item = "DragonBall",           Weight = 8 },
        { Item = "ReviveScroll",         Weight = 10 },
        { Item = "FullElixir",           Weight = 8 },
        { Item = "Scroll_SpiritCannon",  Weight = 12 },
        { Item = "Scroll_ChakraStrike",  Weight = 10 },
    },
}

-- Roll loot from a table, returns item name or nil
function ItemData.RollLoot(tableName, luck)
    luck = luck or 1.0
    local pool = ItemData.LootTables[tableName]
    if not pool then return nil end
    local total = 0
    for _, entry in ipairs(pool) do
        total = total + entry.Weight * luck
    end
    local roll = math.random() * total
    local cumulative = 0
    for _, entry in ipairs(pool) do
        cumulative = cumulative + entry.Weight * luck
        if roll <= cumulative then
            return entry.Item
        end
    end
    return pool[#pool].Item
end

return ItemData
