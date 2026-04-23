-- NpcData.lua
-- Lobby NPC definitions: names, positions, appearances, dialogue banks, and shop roles.
-- NPCs are spawned by WorldBuilder.server.lua and managed by a lobby NPC controller.
--
-- Each NPC has:
--   • A fixed position on the Waypoint island
--   • Idle dialogue lines (rotate on interaction)
--   • Context-sensitive dialogue (triggered by player state: floor reached, archetype, etc.)
--   • Role (Lore / Shop / Trainer / QuestBoard / Portal Guide)

local NpcData = {}

NpcData.NPCs = {

    -- ─── THE ORACLE ──────────────────────────────────────────────────────────
    -- Stands at the central monument. Gives world lore and dungeon previews.
    {
        Id          = "Oracle",
        Name        = "The Oracle",
        Title       = "Keeper of Shard Memory",
        Role        = "Lore",
        Position    = Vector3.new(0, 3, 0),   -- at the monument base
        Color       = Color3.fromRGB(100, 220, 200),
        Size        = Vector3.new(3, 6, 3),
        EmoteIdle   = "Float",   -- slowly bobs in place
        IdleDialogue = {
            "Every Shard you clear... the Void grows a little thinner.  Keep going.",
            "The Grand Line shattered thirty years ago.  The Shards have been growing darker ever since.",
            "You carry resonance from each world you've visited.  Can you feel it?",
            "The Waypoint exists because something, somewhere, wants us to keep fighting.  I don't know what.  I'm working on it.",
            "Be careful in the deeper Shards.  The Void doesn't just corrupt enemies.  It corrupts memory.",
            "Those who enter enough Shards begin to hear the echoes.  Voices of the people who were there before.",
        },
        ContextDialogue = {
            -- Triggered first time player arrives (floor == 0)
            NewPlayer = {
                "You're new.  Good.  The Waypoint needs warm bodies.",
                "The Void War is over, but the Drift Shards aren't going anywhere.  Someone has to clean them up.",
                "Here's what you need to know: enter the Shard, fight through it, defeat the Anchor at the end, grab the Crystal, get out.  Simple.  Mostly.",
                "Your 'Bounty' number is how the Coalition measures your worth.  More gold means better gear means harder Shards.  You'll figure it out.",
            },
            -- Triggered when player reaches floor 5 for the first time
            Floor5 = {
                "Punk Hazard.  The Broken World.  Most divers don't make it that far on their first run.",
                "The Colossus was the experiment that ended that world.  It's... persistent.",
                "You've made it further than I expected.  I mean that as a compliment.",
            },
            -- Triggered when player reaches floor 10
            Floor10 = {
                "You've run the full cycle.  The Shards repeat — but they don't get easier.  They get more saturated.",
                "Something changes in you after ten floors.  The resonance starts to feel... natural.",
                "The second cycle is faster, darker, hungrier.  You've been warned.",
            },
            -- Triggered on death/return
            AfterDeath = {
                "Back already.  The Shard wasn't done with you.",
                "The Void doesn't kill you.  It just... resets you.",
                "Every run teaches you something, even the ones that end badly.",
            },
        },
        -- Oracle also offers dungeon preview: tells you what's in the next Shard
        HasDungeonPreview = true,
    },

    -- ─── NAVIGATOR NAMI ──────────────────────────────────────────────────────
    -- Runs the main shop building. Sells items, has gold-related commentary.
    {
        Id          = "ShopKeeper",
        Name        = "Navigator Nami",
        Title       = "Waypoint Market Overseer",
        Role        = "Shop",
        Position    = Vector3.new(-85, 3, 35),   -- inside the Shop building
        Color       = Color3.fromRGB(255, 180, 60),
        Size        = Vector3.new(3, 5, 3),
        EmoteIdle   = "Lean",
        IdleDialogue = {
            "Spending gold is an investment, not a loss.  Keep telling yourself that.",
            "I track every Bounty transaction on the Waypoint.  You're doing fine.  Statistically.",
            "The Coalition gives me inventory.  You give me Bounty.  Everyone wins.  Mostly me.",
            "Fresh stock in from Shard salvage.  Don't ask who didn't make it back.",
            "Buy something or I'm charging you a loitering fee.",
            "Higher floors drop better loot.  Obvious observation.  But you'd be surprised how many divers forget.",
        },
        ContextDialogue = {
            LowGold = {
                "You look like you're running low on Bounty.  That's a problem.",
                "I have a sale — just for you — on items you can afford.  Which is... this.",
            },
            HighGold = {
                "Big spender.  I like big spenders.",
                "You've clearly been clearing Shards efficiently.  Let me show you the good stuff.",
            },
            AfterBoss = {
                "Boss cleared?  You'll want to spend that haul before the next floor.  Come in.",
                "Anchor down.  Good timing — I just restocked.",
            },
        },
        HasShop = true,
    },

    -- ─── MASTER ZORO ─────────────────────────────────────────────────────────
    -- At the Guild Hall. Offers training insight and archetype advice.
    {
        Id          = "Trainer",
        Name        = "Master Zoro",
        Title       = "Guild Hall Overseer — Combat Division",
        Role        = "Trainer",
        Position    = Vector3.new(85, 3, 35),   -- inside the Guild Hall
        Color       = Color3.fromRGB(50, 180, 80),
        Size        = Vector3.new(3.5, 6, 3.5),
        EmoteIdle   = "CrossedArms",
        IdleDialogue = {
            "If you're here to chat, leave.  If you're here to get stronger, I'm listening.",
            "Your archetype is a starting point, not a ceiling.  Don't get comfortable.",
            "The best divers don't rely on one ability.  They build for every situation.",
            "I've trained warriors from a dozen Shards.  The ones who survive longest?  They adapt.",
            "Don't waste synergy potential.  Know which abilities chain together.",
            "Getting hit means you made a mistake.  Figure out which one.",
        },
        ContextDialogue = {
            -- Archetype-specific advice (triggered by player's archetype)
            Swordsman = {
                "Blade fighters live and die on their crit timing.  Learn when to be patient.",
                "BladeTornado into QuickDash.  Commit the combo to muscle memory.",
                "CounterStance is the highest-skill ability in your kit.  Master it.",
            },
            Mage = {
                "You're fragile.  ManaShield is not optional.  It's survival.",
                "ArcaneOverload synergy — ArcaneOrb plus ElementalBurst.  Once you get it, it changes everything.",
                "Your damage is the highest in the roster.  Your defense is the lowest.  Position accordingly.",
            },
            Brawler = {
                "Iron Titan awakening.  The longer you stay in a fight, the stronger you get.  That's the game plan.",
                "Taunt is your aggro tool.  If teammates are dying — that's on you.",
                "Brawlers who panic and back off die.  The ones who lean in and trust their HP survive.",
            },
            Assassin = {
                "NightVeil — your opening hit is everything.  Shadow Step IN, hit once, reposition.  Don't get greedy.",
                "DeathMark then ShadowStep backstab.  The combo one-shots most elite enemies at your tier.",
                "You have the highest speed in the roster.  Never stop moving.",
            },
            SpiritUser = {
                "BankaiFrenzy is your win condition.  Build toward it every fight.",
                "SpiritSurge passive means your healing is tied to your offense.  Hit hard to stay alive.",
                "SoulDrain plus ChakraStrike synergy.  Self-sustaining in any fight if you time it right.",
            },
        },
        -- Trainer can also offer a daily challenge (clears on run reset)
        HasDailyChallenge = true,
    },

    -- ─── WANTED BOARD KEEPER ─────────────────────────────────────────────────
    -- At the Quest Board. Manages bounty contracts and mission rewards.
    {
        Id          = "BountyKeeper",
        Name        = "The Collector",
        Title       = "Waypoint Bounty Board Administrator",
        Role        = "QuestBoard",
        Position    = Vector3.new(90, 3, -30),   -- near the quest board
        Color       = Color3.fromRGB(140, 100, 200),
        Size        = Vector3.new(3, 5.5, 3),
        EmoteIdle   = "ReadScroll",
        IdleDialogue = {
            "I have contracts.  You have time.  Let's talk.",
            "The Board updates each time the Waypoint resets.  Come back often.",
            "Most bounties are straightforward.  Some are not.  Read carefully.",
            "Payment on completion only.  I don't do advances.",
            "Interesting run you had.  The Board noticed.",
            "Every contract you complete is logged.  Your record follows you.",
        },
        ContextDialogue = {
            NewBounty = {
                "New contract posted.  Figured you'd want to know.",
                "High-value target spotted in the Shards.  Interested?",
            },
            BountyComplete = {
                "Contract fulfilled.  Well done.  Here's your cut.",
                "The Board pays its debts.  Take it.",
                "Efficient.  I'll have another for you shortly.",
            },
            NoBounties = {
                "Board's clear right now.  Come back after your next run.",
                "Nothing for you at the moment.  The Shards are quiet.",
            },
        },
        HasBountyBoard = true,
    },

    -- ─── THE WANDERER ─────────────────────────────────────────────────────────
    -- Near the portal zone. Shares dungeon-specific lore. Identity unknown.
    {
        Id          = "Wanderer",
        Name        = "The Wanderer",
        Title       = "Unknown",
        Role        = "PortalGuide",
        Position    = Vector3.new(0, 3, -110),   -- near the portal archway
        Color       = Color3.fromRGB(80, 80, 80),
        Size        = Vector3.new(3, 5, 3),
        EmoteIdle   = "LookAway",
        IdleDialogue = {
            "Every portal goes somewhere.  Not all of them go somewhere good.",
            "I've been in all of them.  I don't recommend most of them.",
            "The Void doesn't think.  It just grows.  That's almost scarier.",
            "You want to know about the Shards?  Ask me.  I've been there.",
            "The bosses weren't always like this.  Something changed them.",
            "...",
        },
        ContextDialogue = {
            -- Portal-specific lore drops (triggered by proximity to each portal)
            Portal_EastBlue = {
                "Demon Coast.  The first Shard most divers run.  Don't get cocky — the Void learned fast on this one.",
                "Muzan used to be something else.  The records don't agree on what.  The Void sealed that answer too.",
            },
            Portal_Marine = {
                "The Fortress was supposed to be impenetrable.  It was — just not from the inside.",
                "Madara's men followed orders for years after the Void got in.  Orders from something that wasn't him anymore.",
            },
            Portal_Fishman = {
                "The underwater pressure matters.  Don't let it catch you off guard.",
                "Kaido came TO this Shard.  Voluntarily.  That should tell you something about him.",
            },
            Portal_Skypiea = {
                "They wanted to be gods.  The Void obliged.  Now look at them.",
                "Aizen is the most dangerous Anchor in the cycle.  He plans.  He waits.  He knows you're coming.",
            },
            Portal_PunkHazard = {
                "The Colossus doesn't have a plan.  It just exists, endlessly.  That's not better.",
                "Two environments, one room.  Figure out the cycle fast.  It will kill you if you don't.",
            },
        },
    },

    -- ─── BLACKSMITH REX ──────────────────────────────────────────────────────
    -- At the Upgrade Station. Handles gear enhancement.
    {
        Id          = "Blacksmith",
        Name        = "Blacksmith Rex",
        Title       = "Shard-Tech Weaponsmith",
        Role        = "Upgrades",
        Position    = Vector3.new(85, 3, -30),   -- at the upgrade station
        Color       = Color3.fromRGB(200, 100, 40),
        Size        = Vector3.new(4, 5.5, 4),
        EmoteIdle   = "Hammer",
        IdleDialogue = {
            "Shard resonance changes metal.  The stuff that comes out of those portals — it's not normal.",
            "I've smithed for Coalition divers for twelve years.  The Shards keep changing.  My forge keeps adapting.",
            "Bring me Mastery Points, I'll build you something worth fighting with.",
            "The best gear isn't dropped.  It's built.  Remember that.",
            "Forge upgrades are permanent.  Don't rush the choice.",
        },
        ContextDialogue = {
            HighMastery = {
                "You've been busy.  Good.  I've got blueprints that need Mastery to unlock.",
                "High-tier diver.  High-tier needs.  Let's talk unlocks.",
            },
            LowMastery = {
                "Clear more Shards, earn more Mastery, come back.",
                "Not enough Mastery yet.  The good stuff takes time.",
            },
        },
        HasUpgradeStation = true,
    },
}

-- ──────────────────────────────────────────────────────────────────────────
-- HELPER
-- ──────────────────────────────────────────────────────────────────────────

function NpcData.GetNpcById(id)
    for _, npc in ipairs(NpcData.NPCs) do
        if npc.Id == id then return npc end
    end
    return nil
end

-- Returns a random idle line for an NPC
function NpcData.GetIdleLine(npcId)
    local npc = NpcData.GetNpcById(npcId)
    if not npc or not npc.IdleDialogue then return nil end
    return npc.IdleDialogue[math.random(#npc.IdleDialogue)]
end

-- Returns a context-specific line if one exists
function NpcData.GetContextLine(npcId, contextKey)
    local npc = NpcData.GetNpcById(npcId)
    if not npc or not npc.ContextDialogue then return nil end
    local bank = npc.ContextDialogue[contextKey]
    if not bank or #bank == 0 then return nil end
    return bank[math.random(#bank)]
end

return NpcData
