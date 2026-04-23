-- GamblingSystem.lua
-- High-tension risk/reward interactions available at special Shrine rooms or
-- a dedicated "The Wanderer" NPC encounter mid-dungeon.
--
-- Four gambling types:
--   DevilsGambit   — Sacrifice 40% max HP (run-permanent) for a powerful randomised reward
--   VoidRoulette   — Bet ALL current gold; triple or lose it all (50/50)
--   SoulSwap       — Trade your entire active ability loadout for a random one
--                    guaranteed to have ≥ 1 active synergy
--   BloodPact      — Permanently reduce max HP by 20 for a permanent run-long Atk boost
--
-- Integration:
--   GameManager calls GamblingSystem.ShowOptions(player, roomId) when a
--   "Gamble" room is entered or The Wanderer NPC is interacted with.
--   Client fires PickGamble remoteEvent → OnServerEvent below resolves the bet.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SynergySystem   = require(ReplicatedStorage.Modules.SynergySystem)
local AbilitySystem   = require(ReplicatedStorage.Modules.AbilitySystem)
local CharacterStats  = require(ReplicatedStorage.Modules.CharacterStats)

local RemoteEvents    = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateHUD       = RemoteEvents:WaitForChild("UpdateHUD")
local PickGambleEvt   = RemoteEvents:WaitForChild("PickGamble")
local GambleResultEvt = RemoteEvents:WaitForChild("GambleResult")

-- CombatSystem is a lazy-require to avoid circular dependency
local function getCombatSystem()
    return require(script.Parent.CombatSystem)
end

local GamblingSystem = {}

-- ─── Option definitions ───────────────────────────────────────────────────────

GamblingSystem.Options = {
    {
        Id          = "DevilsGambit",
        Name        = "Devil's Gambit",
        Icon        = "😈",
        CostText    = "Sacrifice 40% Max HP (permanent this run)",
        RewardText  = "Receive a POWERFUL randomised boon: massive Atk boost, free Apex ability, or free Synergy activation",
        HazardLevel = 3,
        Tooltip     = "The reward is always significant. The cost is always real.",
    },
    {
        Id          = "VoidRoulette",
        Name        = "Void Roulette",
        Icon        = "🎰",
        CostText    = "Bet ALL your current gold (min 30 required)",
        RewardText  = "50% chance: triple your gold back. 50% chance: lose it all.",
        HazardLevel = 2,
        Tooltip     = "Pure chance. No skill. No mercy.",
    },
    {
        Id          = "SoulSwap",
        Name        = "Soul Swap",
        Icon        = "🔀",
        CostText    = "Lose your current ability loadout entirely",
        RewardText  = "Gain a randomly generated loadout guaranteed to have at least 1 active synergy",
        HazardLevel = 3,
        Tooltip     = "You might get something incredible. You might get trash. Only one way to find out.",
    },
    {
        Id          = "BloodPact",
        Name        = "Blood Pact",
        Icon        = "🩸",
        CostText    = "Permanently lose 20 Max HP this run",
        RewardText  = "Permanently gain +25 Attack for the rest of this run",
        HazardLevel = 1,
        Tooltip     = "A clean trade. Your call.",
    },
}

-- ─── Send options to a player ─────────────────────────────────────────────────

function GamblingSystem.ShowOptions(player)
    local state = getCombatSystem().GetPlayerState(player)
    if not state then return end
    UpdateHUD:FireClient(player, {
        GambleOpen = true,
        Options    = GamblingSystem.Options,
        Gold       = state.Gold or 0,
        HP         = state.HP,
        MaxHP      = state.Stats.MaxHP,
    })
end

-- ─── Reward pool for Devil's Gambit ───────────────────────────────────────────

local function rollDevilsGambitReward(state, player)
    local roll = math.random(1, 4)

    if roll == 1 then
        -- Massive Atk spike for the run (+40% current Atk)
        local bonus = math.floor(state.Stats.Atk * 0.40)
        state.Stats.Atk = state.Stats.Atk + bonus
        return "POWER SURGE! +" .. bonus .. " permanent Attack this run."

    elseif roll == 2 then
        -- Instantly evolve a random equipped ability to Apex (stage 2)
        local AbilityEvolution = require(ReplicatedStorage.Modules.AbilityEvolution)
        local slots = state.ActiveSlots or {}
        local candidates = {}
        for _, name in ipairs(slots) do
            if name and AbilityEvolution.GetEvolution(name) then
                table.insert(candidates, name)
            end
        end
        if #candidates > 0 then
            local pick = candidates[math.random(#candidates)]
            state.EvoStage       = state.EvoStage or {}
            state.EvoStage[pick] = 2
            local stageName = AbilityEvolution.GetStageName(pick, 2)
            return "APEX UNLOCK! " .. pick .. " evolved to " .. stageName .. "!"
        end
        -- Fallback to Atk boost
        state.Stats.Atk = state.Stats.Atk + 15
        return "POWER SURGE! +15 permanent Attack this run."

    elseif roll == 3 then
        -- Full HP + MP restore AND grant 3 random abilities the player doesn't know
        state.HP = state.Stats.MaxHP
        state.MP = state.Stats.MaxMP
        UpdateHUD:FireClient(player, { HP = state.HP, MaxHP = state.Stats.MaxHP, MP = state.MP, MaxMP = state.Stats.MaxMP })
        local allAbilityNames = {}
        for name in pairs(AbilitySystem.Abilities) do table.insert(allAbilityNames, name) end
        local granted = 0
        local tries = 0
        while granted < 2 and tries < 40 do
            tries = tries + 1
            local pick = allAbilityNames[math.random(#allAbilityNames)]
            if getCombatSystem().GrantAbility(player, pick) then
                granted = granted + 1
            end
        end
        return "DIVINE GIFT! Full restore + " .. granted .. " new abilities granted!"

    else
        -- Permanent +50 max HP bonus
        state.Stats.MaxHP = state.Stats.MaxHP + 50
        state.HP          = math.min(state.HP + 50, state.Stats.MaxHP)
        UpdateHUD:FireClient(player, { HP = state.HP, MaxHP = state.Stats.MaxHP })
        return "VITALITY! +50 permanent Max HP this run."
    end
end

-- ─── Soul Swap helper ─────────────────────────────────────────────────────────

local function rollSoulSwap(state, player)
    -- Build all ability names
    local allNames = {}
    for name in pairs(AbilitySystem.Abilities) do table.insert(allNames, name) end

    -- Shuffle
    for i = #allNames, 2, -1 do
        local j = math.random(i)
        allNames[i], allNames[j] = allNames[j], allNames[i]
    end

    -- Try to build a loadout that activates at least 1 synergy
    local bestSlots = nil
    local attempts  = 0
    while attempts < 80 do
        attempts = attempts + 1
        local slots = {}
        for i = 1, 5 do slots[i] = allNames[math.random(#allNames)] end
        local syns  = SynergySystem.GetActiveSynergies(slots)
        local count = 0
        for _ in pairs(syns) do count = count + 1 end
        if count >= 1 then
            bestSlots = slots
            break
        end
    end
    if not bestSlots then
        -- Fallback: no synergy found, just use random 5
        bestSlots = {}
        for i = 1, 5 do bestSlots[i] = allNames[math.random(#allNames)] end
    end

    -- Grant all new abilities + set active slots
    state.KnownAbilities = {}
    for _, name in ipairs(bestSlots) do
        table.insert(state.KnownAbilities, name)
    end
    state.ActiveSlots = bestSlots

    local activeSyns = SynergySystem.GetActiveSynergies(state.ActiveSlots)
    local synNames   = {}
    for name in pairs(activeSyns) do table.insert(synNames, name) end

    UpdateHUD:FireClient(player, {
        ActiveSlots    = state.ActiveSlots,
        KnownAbilities = state.KnownAbilities,
        ActiveSynergies = synNames,
        Message  = "Soul Swap! New build with " .. (#synNames > 0 and synNames[1] or "a synergy") .. " active!",
        Duration = 4,
    })

    return "SOUL SWAP! New loadout — " .. (#synNames) .. " synerg" .. (#synNames == 1 and "y" or "ies") .. " active."
end

-- ─── PickGamble handler ───────────────────────────────────────────────────────

PickGambleEvt.OnServerEvent:Connect(function(player, optionId)
    local state = getCombatSystem().GetPlayerState(player)
    if not state then return end

    local function fireResult(success, headline, detail)
        GambleResultEvt:FireClient(player, {
            Success  = success,
            Headline = headline,
            Detail   = detail or "",
        })
        UpdateHUD:FireClient(player, {
            HP    = state.HP,    MaxHP = state.Stats.MaxHP,
            MP    = state.MP,    MaxMP = state.Stats.MaxMP,
            Gold  = state.Gold,
        })
    end

    -- ── Devil's Gambit ─────────────────────────────────────────────────────
    if optionId == "DevilsGambit" then
        local sacrifice = math.floor(state.Stats.MaxHP * 0.40)
        if state.HP <= sacrifice then
            fireResult(false, "Insufficient HP", "You need more than " .. sacrifice .. " HP to pay the price.")
            return
        end
        state.Stats.MaxHP = state.Stats.MaxHP - sacrifice
        state.HP = math.min(state.HP, state.Stats.MaxHP)
        local resultMsg = rollDevilsGambitReward(state, player)
        fireResult(true, "Devil's Gambit — DEAL STRUCK", resultMsg)

    -- ── Void Roulette ──────────────────────────────────────────────────────
    elseif optionId == "VoidRoulette" then
        local gold = state.Gold or 0
        if gold < 30 then
            fireResult(false, "Not Enough Gold", "You need at least 30 gold to play the Roulette.")
            return
        end
        local win = math.random() >= 0.50
        if win then
            local gained = gold * 2   -- net +2× (triple total, subtract original)
            state.Gold = gold + gained
            fireResult(true, "JACKPOT!", "You bet " .. gold .. " gold and won " .. state.Gold .. " total!")
        else
            state.Gold = 0
            fireResult(false, "BUST!", "You lost " .. gold .. " gold. The Void takes everything.")
        end

    -- ── Soul Swap ──────────────────────────────────────────────────────────
    elseif optionId == "SoulSwap" then
        local result = rollSoulSwap(state, player)
        fireResult(true, "SOUL SWAPPED", result)

    -- ── Blood Pact ─────────────────────────────────────────────────────────
    elseif optionId == "BloodPact" then
        if state.Stats.MaxHP <= 30 then
            fireResult(false, "Too Weak", "You don't have enough max HP to survive the pact.")
            return
        end
        state.Stats.MaxHP = state.Stats.MaxHP - 20
        state.HP = math.min(state.HP, state.Stats.MaxHP)
        state.Stats.Atk = state.Stats.Atk + 25
        fireResult(true, "BLOOD PACT SEALED", "-20 Max HP, +25 permanent Attack for this run.")

    else
        fireResult(false, "Unknown Option", "")
    end
end)

return GamblingSystem
