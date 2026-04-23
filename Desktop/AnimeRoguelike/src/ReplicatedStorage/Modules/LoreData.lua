-- LoreData.lua
-- Central world lore, dungeon narratives, boss personalities, and environmental storytelling.
--
-- World Concept: "The Shattered Grand Line"
-- Long ago, a godlike entity known as the Void King attempted to consume all of reality.
-- The greatest warriors across every world united to stop it — Demon Slayers, Soul Reapers,
-- Pirate Kings, Titan Hunters, and Spirit Masters. They won. But the cost was catastrophic.
-- The Grand Line itself shattered into thousands of "Drift Shards" — sealed pocket dimensions,
-- each a frozen fragment of a fallen world slowly being consumed by Void Corruption.
--
-- The player is a SHARD DIVER: a warrior recruited by the Waypoint Coalition to enter these
-- Drift Shards, cleanse the corruption within, and harvest "Resonance Crystals" — raw power
-- crystallized from each dying world.  Each floor is a deeper layer of a Drift Shard.
-- The boss is the Corruption Anchor — a powerful entity twisted by the Void — that keeps the
-- Shard locked in decay.  Defeat it, and the Shard briefly crystallizes, letting you escape
-- with its power before it reshapes for the next run.

local LoreData = {}

-- ──────────────────────────────────────────────────────────────────────────
-- WORLD LORE
-- ──────────────────────────────────────────────────────────────────────────

LoreData.WorldLore = {
    Title       = "The Shattered Grand Line",
    Tagline     = "Every Shard holds a world that died. Dive in. Claim its power. Get out alive.",

    WorldSummary = [[
The Void King is gone — but its hunger left cracks in every world it touched.
Those cracks became Drift Shards: sealed pocket-dimensions, each a frozen echo of
a place that once existed.  Demons, Soul Reapers, Titans, Pirates — all trapped inside
their own dying fragment, corrupted by the Void and endlessly reborn.

You are a Shard Diver.  The Waypoint Coalition found you, armed you, and threw you
into the deep end.  Your mission: enter the Shards, fight through their corruption,
and defeat the Anchor at the heart of each one.

The Anchor breaks — the Shard crystallizes — you walk out stronger.
Then it reforms.  And you go back in.

This is the life you chose.
]],

    PlayerRole = {
        Title       = "Shard Diver",
        Description = "An elite warrior who enters Drift Shards to cleanse Void Corruption.",
        RankTitle   = "Bounty",   -- gold is the in-world "reputation" metric
        RankLore    = [[
In the age after the Void War, power is currency.
Waypoint tracks every Shard Diver's contributions through a Bounty figure —
a measure of how dangerous the world considers you.
The higher your Bounty, the better gear the Coalition funnels to you.
The higher your Bounty... the harder the Shards it sends you into.
]],
    },

    WaypointLore = [[
The Waypoint is a miracle and a mystery.
It sits at the convergence point of every Drift Shard — a single island
untouched by the Void, somehow anchored to all realities at once.
Nobody built it.  It simply appeared after the Void War, fully furnished,
as if reality left a base camp for whoever survived.

Today it's home to merchants, trainers, information brokers, and the
ragged ranks of the Waypoint Coalition.  If you need it before a dive,
you'll find it here.
]],
}

-- ──────────────────────────────────────────────────────────────────────────
-- DUNGEON SHARD LORE  (indexed by DungeonThemes theme index 1-5)
-- ──────────────────────────────────────────────────────────────────────────

LoreData.ShardLore = {
    -- Theme 1: East Blue Coast  (Demon Coast Shard)
    [1] = {
        ShardName        = "Demon Coast Shard",
        LoreName         = "The Bleeding Shore",
        Origin           = "A coastal pirate island consumed by demonic infestation.",
        Corruption       = "The Void twisted its resident demons further — they no longer hunger for territory.  They hunger for everything.",
        EntryFlavor      = "The salt air reeks of sulfur.  Somewhere ahead, something is screaming.  It doesn't sound human.",
        EnvironmentalHints = {
            "Charred ship hulls are wedged into the cliffs — none of them belonged to pirates.",
            "Scorch marks in the shape of handprints line the cave walls.  They face inward.",
            "A rusted wanted poster flutters in the air.  The face on it has been burned away.",
        },
        BossContext      = "The demon infestation coalesced around a single point of Void energy and formed him: Muzan, the Demon Lord.  He was a pirate king once.  Now he's the reason there are no more pirates here.",
        ClearFlavor      = "The Shard cracks.  The demonic howling stops.  For a moment, all you can hear is the sea.",
    },

    -- Theme 2: Marine Fortress  (Iron Order Shard)
    [2] = {
        ShardName        = "Iron Order Shard",
        LoreName         = "The Fortress Eternal",
        Origin           = "A marine stronghold frozen at the moment of its fall.",
        Corruption       = "The marines who defended this fortress refused to retreat.  The Void honored their stubbornness — they fight forever now, in perfect formation, without hunger or fear.",
        EntryFlavor      = "Every corridor looks exactly like the last.  The lights are still on.  Nobody comes to turn them off.",
        EnvironmentalHints = {
            "A chalkboard in the barracks still lists the day's patrol rotations.  The date is decades old.",
            "The armory is perfectly stocked.  Nothing has been touched.  No one needed resupply.",
            "A shadow moves behind frosted glass, salutes, and continues its circuit.  It has no face.",
        },
        BossContext      = "Madara was the fortress commander.  When the Void came, he ordered his soldiers to hold the line.  They're still holding it.  He's still giving orders.",
        ClearFlavor      = "The soldiers stop.  One by one they stand down, frozen mid-salute.  The Void Anchor is broken.  The order they were following no longer exists.",
    },

    -- Theme 3: Fishman Island  (Abyssal Shard)
    [3] = {
        ShardName        = "Abyssal Shard",
        LoreName         = "The Drowned Kingdom",
        Origin           = "An underwater civilization sealed off from the surface after the Void tainted the sea above.",
        Corruption       = "The Fishmen sealed themselves in to survive.  But the Void got in anyway — from below.",
        EntryFlavor      = "The bioluminescence is beautiful until you realize it's pulsing in sync with something large at the bottom of the trench.",
        EnvironmentalHints = {
            "The coral formations grow in spirals pointing toward a single point in the deep.",
            "A mural on the cavern wall shows the kingdom thriving.  Someone has scratched a large X over the king's face.",
            "Water pressure readings on the wall gauge are pinned at maximum.  The gauge has been broken for years.",
        },
        BossContext      = "Kaido didn't start the corruption here — he arrived after it.  The Abyssal Shard called to him like a magnet.  He dove in, made it his throne, and became its king.",
        ClearFlavor      = "The pressure breaks.  Somewhere deep in the trench, a faint light flickers and goes out.  The Drowned Kingdom is quiet for the first time since the Void War.",
    },

    -- Theme 4: Skypiea  (Heaven's Ruin Shard)
    [4] = {
        ShardName        = "Heaven's Ruin Shard",
        LoreName         = "The Fallen Skies",
        Origin           = "A civilization that lived above the clouds, struck down for believing they could touch divinity.",
        Corruption       = "The Void didn't destroy them — it answered their prayer.  It gave them exactly what they wanted: to become something beyond human.  They became Hollows.",
        EntryFlavor      = "The clouds below you are wrong.  Too still.  Too perfect.  Like a painting of clouds by someone who has never seen the sky.",
        EnvironmentalHints = {
            "Golden statues of warriors line the approach.  Their expressions are peaceful.  Their eyes have been carved out.",
            "A bell the size of a building hangs motionless in the sky.  No wind moves it.  It rings anyway.",
            "Inscribed on the archway: 'Those who reach heaven forget what they left behind.'",
        },
        BossContext      = "Aizen was the philosopher-king of this fragment — a being of near-perfect intellect who watched his civilization transform and concluded it was beautiful.  The Void gave him clarity.  It also took everything else.",
        ClearFlavor      = "The golden light drains out of the ruins.  Whatever divinity the Void offered, it's been refused.  The clouds begin to move again.",
    },

    -- Theme 5: Punk Hazard  (The Inferno-Tundra Shard)
    [5] = {
        ShardName        = "Inferno-Tundra Shard",
        LoreName         = "The Broken World",
        Origin           = "An island torn in half by a catastrophic experiment that was never supposed to go wrong.",
        Corruption       = "The Void didn't cause the damage here.  It moved in afterward, into the wound.  The Titans were the experiment.  The Void made them permanent.",
        EntryFlavor      = "On your left: magma.  On your right: a glacier.  In the center: a forty-foot nightmare staring directly at you.",
        EnvironmentalHints = {
            "A research log, sealed in ice, reads: 'Day 44 — the subjects are adapting.  Disposal is no longer an option.'",
            "The fire side and ice side are perfectly symmetrical — as if the island was designed to be broken.",
            "A sign, half-melted and half-frozen: 'DANGER — GOVERNMENT EXPERIMENTS.  AUTHORIZED PERSONNEL ONLY.'",
        },
        BossContext      = "The Colossus Titan is the experiment that ended everything here.  It wasn't supposed to survive.  It did.  The Void found it still standing in the rubble and left it there as a guardian — or a warning.",
        ClearFlavor      = "The ground trembles and goes still.  The fire and ice don't merge — they simply stop fighting.  The Shard holds its breath.",
    },
}

-- ──────────────────────────────────────────────────────────────────────────
-- BOSS PERSONALITIES & DIALOGUE
-- ──────────────────────────────────────────────────────────────────────────

LoreData.BossDialogue = {

    DemonLord = {
        Personality  = "Contemptuous and ancient. Muzan does not see you as a threat — he sees you as an insult.",
        Intro        = {
            "So.  Another diver stumbles in thinking they can 'cleanse' my Shard.",
            "I have eaten a thousand warriors stronger than you.  Tell me — what makes this time different?",
            "You smell of the Waypoint.  Coalition-sent, then.  How disappointing.",
        },
        Phase2Taunt  = {  -- triggered at 70% HP
            "That actually... hurt.  Interesting.  Let me show you what 'hurt' really means.",
            "You've gotten my attention.  Congratulations.  This is the last thing you'll ever earn.",
        },
        Phase3Taunt  = {  -- triggered at 40% HP
            "ENOUGH.  I am the Demon Lord.  I do not fall to insects!",
            "Fine.  FINE.  If you want war — then I'll show you what I did to the last world that defied me!",
        },
        Defeat       = {
            "...how.  How does someone like you—",
            "The Void gave me everything.  And you... you had nothing.  How—",
            "Tell the Coalition... tell them... it doesn't matter.  Another will come.",
        },
    },

    ShadowLord = {
        Personality  = "Calm, deliberate, almost academic. Madara finds the whole encounter intellectually interesting.",
        Intro        = {
            "You entered the Fortress.  You fought through my men.  You found me.  Impressive.",
            "I've been watching you since the entrance.  You fight well.  It won't be enough.",
            "They sent one.  The Coalition sent one Shard Diver to challenge the Iron Order's last commander.  I'm almost flattered.",
        },
        Phase2Taunt  = {
            "Adaptable.  You've been reading my patterns.  Let's see if you can read this one.",
            "Good.  Very good.  Now the real engagement begins.",
        },
        Phase3Taunt  = {
            "You are... unexpectedly resilient.  The Void will be very interested in you.",
            "This formation ends now.  I am done holding back.",
        },
        Defeat       = {
            "A genuine surprise.  I have not been surprised in... a very long time.",
            "The Fortress falls.  So be it.  An order that cannot adapt deserves to end.",
            "Take the Resonance Crystal.  You earned it.  ...Tell me — what world are you from?",
        },
    },

    AbyssalKing = {
        Personality  = "Brutal, direct, and weirdly joyful. Kaido thinks battle is the only honest conversation.",
        Intro        = {
            "HAHAHAHA!  A diver!  FINALLY something worth hitting!",
            "You've got guts walking in here.  Let's see if you've got the strength to back it up.",
            "The last twelve divers ran.  You didn't.  I like you already.  Come on, then!",
        },
        Phase2Taunt  = {
            "GOOD!  THAT'S WHAT I'M TALKING ABOUT!  Hit me harder!",
            "Now we're having fun!  Don't die too quickly!",
        },
        Phase3Taunt  = {
            "You actually hurt me.  HAHHAHAHA!  You ACTUALLY HURT ME!",
            "Alright, fine — I'll stop playing around.  Show me everything you've got!",
        },
        Defeat       = {
            "...not bad.  Not bad at all.",
            "HA.  The Drowned King, beaten by a diver.  What a way to go.",
            "Go on, take the Crystal.  You earned it — by Shard standards, this was a good fight.",
        },
    },

    VasteLorde = {
        Personality  = "Serene and condescending. Aizen has already calculated every possible outcome and finds this one mildly surprising.",
        Intro        = {
            "You arrived here 4.7 seconds faster than my models predicted.  Interesting.",
            "I wondered when the Waypoint would produce someone worth observing.  Here you are.",
            "You are not what I expected.  That is... the first time I have said that in quite a while.",
        },
        Phase2Taunt  = {
            "You've forced me to revise my estimate.  A rare achievement.",
            "Mm.  Let me recalculate.",
        },
        Phase3Taunt  = {
            "Fascinating.  My models didn't account for you at all.",
            "Very well.  I'll stop letting you win and start trying.",
        },
        Defeat       = {
            "...I had accounted for every variable.  Every variable except one.",
            "You.  You were the variable I missed.  How... novel.",
            "Take the Crystal.  Watching you was worth the loss.",
        },
    },

    ColossosTitan = {
        Personality  = "No words. The Colossus is beyond language — pure instinct and Void-fused rage.",
        Intro        = {
            "...",     -- silence before the roar
            "[The ground shakes.  Steam rises from its shoulders.  It turns to face you.]",
            "[A sound like a collapsing mountain.  It has noticed you.]",
        },
        Phase2Taunt  = {
            "[Its wounds seal shut with Void-black energy.  It does not slow down.]",
            "[The temperature in the room drops fifteen degrees.  It starts to glow.]",
        },
        Phase3Taunt  = {
            "[ROAR — the walls crack.  Steam vents from every joint.  This is its true form.]",
            "[The Void Anchor pulses.  The Colossus grows.]",
        },
        Defeat       = {
            "[A sound like breaking ice.  The glow fades.  The Titan falls.]",
            "[Silence.  The Broken World holds still for the first time since the experiment.]",
            "[The Resonance Crystal drifts upward from where the Anchor once was.  The Shard is clear.]",
        },
    },
}

-- ──────────────────────────────────────────────────────────────────────────
-- COLLECTIBLE LORE FRAGMENTS
-- Scattered throughout dungeons as hidden interactable objects.
-- ThemeIndex matches DungeonThemes; Rarity: "Common" | "Rare" | "Legendary"
-- ──────────────────────────────────────────────────────────────────────────

LoreData.CollectibleFragments = {

    -- ── Theme 1: Demon Coast ─────────────────────────────────────────────
    {
        Id          = "DC_Fragment_01",
        ThemeIndex  = 1,
        Title       = "Diver's Last Note",
        Rarity      = "Common",
        Object      = "Torn journal wedged beneath a collapsed dock beam.",
        Text        = [[Day unknown.  The demons don't sleep.  I haven't either.  I found a way past the third patrol — there's a crack in the eastern cliff face.  If you're reading this, you made it further than I did.  The boss lives in the sulfur cave.  Don't fight him in the open.  He cheats.]],
    },
    {
        Id          = "DC_Fragment_02",
        ThemeIndex  = 1,
        Title       = "Coalition Field Report",
        Rarity      = "Common",
        Object      = "Laminated report card sealed in a Coalition waterproof sleeve.",
        Text        = [[WAYPOINT COALITION — FIELD ASSESSMENT\nShard Designation: Bleeding Shore\nClearance Attempts: 14\nSuccessful Clears: 1\nNotes: Anchor unusually stable.  Recommend experienced divers only.  The corruption here is... angry.  Not dormant.  Angry.]],
    },
    {
        Id          = "DC_Fragment_03",
        ThemeIndex  = 1,
        Title       = "What the Demons Remember",
        Rarity      = "Rare",
        Object      = "Stone tablet carved with symbols that predate the Void War.",
        Text        = [[Before the Void came, we were kings of the coast.  We hunted.  We fed.  We were feared.  Then the hunger grew beyond anything we could satisfy.  The Void didn't corrupt us.  It just... turned up the volume on what was already there.  We don't regret it.  We just wish there was still something left to devour.]],
    },

    -- ── Theme 2: Iron Order ─────────────────────────────────────────────
    {
        Id          = "IO_Fragment_01",
        ThemeIndex  = 2,
        Title       = "Standing Orders",
        Rarity      = "Common",
        Object      = "A framed order sheet pinned to a corkboard in the barracks.",
        Text        = [[STANDING ORDERS — IRON FORTRESS GARRISON\n1. Hold the eastern wall.\n2. Do not engage the anomaly directly.\n3. Await reinforcement from Fleet Command.\n\n[Note: dated four decades ago.  Fleet Command never answered.  The garrison is still waiting.]],
    },
    {
        Id          = "IO_Fragment_02",
        ThemeIndex  = 2,
        Title       = "The Commander's Private Journal",
        Rarity      = "Rare",
        Object      = "A locked journal; the lock has been corroded open.",
        Text        = [[I told them to hold.  I said we were stronger than the Void.  I believed it.  I still believe it.\n\nThe men never left.  They're still fighting.  I'm still giving orders.  I know what we are now.  I know what this is.\n\nBut if I stop giving orders — if I admit it — they'll stop fighting.  And then what was it all for?\n\nSo the orders continue.  The fortress holds.  The date on my watch stopped mattering a long time ago.]],
    },
    {
        Id          = "IO_Fragment_03",
        ThemeIndex  = 2,
        Title       = "Research Note: The Eternal Garrison",
        Rarity      = "Legendary",
        Object      = "A Waypoint Coalition research document with high-clearance markings.",
        Text        = [[CLASSIFIED — COALITION RESEARCH DIVISION\nSubject: Iron Order Shard — Anomalous Persistence\n\nThe garrison soldiers are not alive.  They are not undead.  They exist in a state the Void has created for which we have no word.  They retain tactical memory, formation discipline, and chain of command.  They feel nothing.  They fear nothing.\n\nWe believe the Void did not corrupt them.  We believe the Void PERFECTED them — as soldiers.  And we find that deeply alarming.]],
    },

    -- ── Theme 3: Drowned Kingdom ─────────────────────────────────────────
    {
        Id          = "DK_Fragment_01",
        ThemeIndex  = 3,
        Title       = "Sealed Decree",
        Rarity      = "Common",
        Object      = "A royal decree in a waterproof ceremonial tube.",
        Text        = [=[BY ORDER OF THE ABYSSAL THRONE\n\nThe surface is closed.  Any citizen who attempts to breach the upper seal will be considered a traitor.\n\nWe are safe down here.  The corruption cannot reach us.\n\n[Written in ink that has since turned the color of deep water.  There are twelve more decrees in this room.  They all say the same thing.  The seal was breached on the same day as the first decree.]]=],
    },
    {
        Id          = "DK_Fragment_02",
        ThemeIndex  = 3,
        Title       = "The Bioluminescence Study",
        Rarity      = "Rare",
        Object      = "A research note affixed to a coral formation.",
        Text        = [[The bioluminescence in sector 7 does not match any known Fishman biology.  It pulses at irregular intervals.  We have been tracking the pattern for three weeks.\n\nYesterday, we realized it is not random.  It is counting down.\n\nWe do not know what happens when it reaches zero.  We are leaving sector 7.]],
    },
    {
        Id          = "DK_Fragment_03",
        ThemeIndex  = 3,
        Title       = "The Throne's Last Message",
        Rarity      = "Legendary",
        Object      = "A crystallized recording sphere pulsing with residual Void energy.",
        Text        = [[This is King Poseidon.  If you find this... it means I failed.\n\nKaido came from below.  Not from the Void — he was already here, somewhere in the deep trench, dormant.  The Void just woke him up.  He doesn't serve it.  He just enjoys what it made.\n\nWe were not killed.  We were absorbed.  The kingdom still exists, in some form, inside him.  I don't know if that is mercy or cruelty.\n\nSink him.  That's all I ask.  Sink him to the bottom where even the Void can't find him.]],
    },

    -- ── Theme 4: Heaven's Ruin ───────────────────────────────────────────
    {
        Id          = "HR_Fragment_01",
        ThemeIndex  = 4,
        Title       = "The First Hollow's Testimony",
        Rarity      = "Common",
        Object      = "A golden tablet etched with scripture-like lettering.",
        Text        = [[I remember being afraid of death.  I remember wanting something more.  I remember the day the Void answered our prayers.\n\nI do not remember my name.  I do not remember my face.  I do not remember why those things mattered.\n\nI am still afraid.  But now I am afraid of nothing.  And that is worse.]],
    },
    {
        Id          = "HR_Fragment_02",
        ThemeIndex  = 4,
        Title       = "Aizen's Philosophy",
        Rarity      = "Rare",
        Object      = "A leather-bound philosophical treatise with extensive marginalia.",
        Text        = [=[The Void did not destroy us.  It fulfilled us.  We wanted to transcend humanity — and we did.  We became something purer.  Something that does not suffer.\n\nMy people complain that I call this a success.  But suffering was the price of being human.  We are no longer paying it.  That is, by any rational metric, an improvement.\n\n[Margin note, different handwriting: 'He has been saying this for forty years.  He smiles while he says it.  I do not think he believes it anymore.']=],
    },
    {
        Id          = "HR_Fragment_03",
        ThemeIndex  = 4,
        Title       = "What the Gods Left Behind",
        Rarity      = "Legendary",
        Object      = "An inscription carved into the foundation stone of the highest ruin.",
        Text        = [[BEFORE THE VOID WAR\nThis civilization had a name.  Their king was just.  Their scholars were wise.  Their warriors were brave.\n\nAFTER THE VOID WAR\nThis civilization has no name.  Their king calculates.  Their scholars converted.  Their warriors are Hollow.\n\nThe Waypoint Coalition marks this Shard as: PRIORITY CLEAR.\nReason: The Void here is not dormant.  It is recruiting.]],
    },

    -- ── Theme 5: Broken World ────────────────────────────────────────────
    {
        Id          = "BW_Fragment_01",
        ThemeIndex  = 5,
        Title       = "Experiment Log: Day 44",
        Rarity      = "Common",
        Object      = "A research log sealed in a block of ice, partially thawed.",
        Text        = [[Day 44.  The subjects are adapting faster than projected.  We have suspended the disposal protocol.\n\nDay 46.  Disposal is no longer an option.  We have requested evacuation.\n\nDay 47.  Evacuation denied.  Classified.\n\nDay 48.  There is no Day 49.]],
    },
    {
        Id          = "BW_Fragment_02",
        ThemeIndex  = 5,
        Title       = "The Titan Who Remembers",
        Rarity      = "Rare",
        Object      = "A massive handprint pressed into a cooled lava slab — too large to be human.",
        Text        = [[It left a message.  Not in words — in the handprint.  The researchers who studied it reported that looking at it for too long made them feel watched.  Not by the Titan.  By whatever the Titan was looking at when it made the print.\n\nWe believe the Colossus Titan retains enough cognition to be aware of its condition.  We believe it is not happy about it.  We do not believe that will make it easier to kill.]],
    },
    {
        Id          = "BW_Fragment_03",
        ThemeIndex  = 5,
        Title       = "The Void War's Final Report",
        Rarity      = "Legendary",
        Object      = "A Waypoint Coalition historical document — the oldest known record in the lobby archive.",
        Text        = [[WAYPOINT COALITION — HISTORICAL ARCHIVE\nFINAL WAR REPORT: THE VOID WAR\n\nThe Void King is gone.  The Grand Line is shattered.  The warriors who stopped it — Titan Hunters, Soul Reapers, Spirit Masters, Demon Slayers, Pirate Kings — they paid a price we are still counting.\n\nWe do not know how many Drift Shards exist.  Estimates range from hundreds to tens of thousands.  Each one a world that died.  Each one a Void Anchor waiting to be cleared.\n\nWe built the Waypoint.  We trained the first Shard Divers.  We began the work.\n\nWe will not live to see it finished.  But it will be finished.  It has to be.  We didn't win the Void War to let the Shards take everything back one at a time.]],
    },
}

-- ──────────────────────────────────────────────────────────────────────────
-- HELPER FUNCTIONS
-- ──────────────────────────────────────────────────────────────────────────

-- Get a random line from a dialogue table
function LoreData.GetDialogueLine(bossKey, phase)
    local boss = LoreData.BossDialogue[bossKey]
    if not boss then return nil end
    local lines = boss[phase]
    if not lines or #lines == 0 then return nil end
    return lines[math.random(#lines)]
end

-- Get the Shard lore for a given theme index (cycles every 5 floors)
function LoreData.GetShardLore(floor)
    local index = ((floor - 1) % 5) + 1
    return LoreData.ShardLore[index]
end

-- Get a random environmental hint for the current floor
function LoreData.GetRandomHint(floor)
    local shard = LoreData.GetShardLore(floor)
    if not shard or not shard.EnvironmentalHints then return nil end
    local hints = shard.EnvironmentalHints
    return hints[math.random(#hints)]
end

-- Get all collectible fragments for a given theme index
function LoreData.GetFragmentsForTheme(themeIndex)
    local results = {}
    for _, f in ipairs(LoreData.CollectibleFragments) do
        if f.ThemeIndex == themeIndex then
            table.insert(results, f)
        end
    end
    return results
end

-- Pick one random fragment for a floor, weighted toward lower rarity
function LoreData.GetRandomFragment(floor)
    local index = ((floor - 1) % 5) + 1
    local frags = LoreData.GetFragmentsForTheme(index)
    if #frags == 0 then return nil end
    -- Weighted: Common×3, Rare×2, Legendary×1
    local pool = {}
    for _, f in ipairs(frags) do
        local w = f.Rarity == "Common" and 3 or f.Rarity == "Rare" and 2 or 1
        for _ = 1, w do table.insert(pool, f) end
    end
    return pool[math.random(#pool)]
end

return LoreData
