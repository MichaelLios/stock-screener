-- ChallengeTracker.lua
-- Tracks per-run challenge progress and fires ChallengeUpdate events to clients.
-- ChallengeData defines the conditions; this module tracks state during a live run.
-- GameManager calls TrackEvent() at key moments; CombatSystem tracks kill/damage events.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChallengeData   = require(ReplicatedStorage.Modules.ChallengeData)
local CosmeticsData   = require(ReplicatedStorage.Modules.CosmeticsData)

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local ChallengeUpdEvt  = RemoteEvents:WaitForChild("ChallengeUpdate",  15)
local UpdateHUD        = RemoteEvents:WaitForChild("UpdateHUD",        15)

-- ── Per-run state ─────────────────────────────────────────────────────────────

-- [player] = {
--   activeChallenges = { [id] = { data, progress, failed } },
--   kills            = 0,
--   damageTaken      = 0,      -- in current room
--   deathCount       = 0,
--   shopGoldSpent    = 0,
--   restRoomsUsed    = 0,
--   noDmgRoomStreak  = 0,
--   highestFloor     = 0,
--   bossNoDamage     = true,   -- flipped false if damage taken during boss room
--   inBossRoom       = false,
--   floorEnterTime   = {},     -- [floor] = tick()
--   floorClearTime   = {},     -- [floor] = seconds taken
-- }
local RunState = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getState(player)
    return RunState[player]
end

local function fireUpdate(player, challengeId, progress, total, completed, failed)
    if not ChallengeUpdEvt then return end
    ChallengeUpdEvt:FireClient(player, {
        ChallengeId = challengeId,
        Progress    = progress,
        Total       = total,
        Completed   = completed,
        Failed      = failed,
    })
end

local function failChallenge(player, state, id)
    local entry = state.activeChallenges[id]
    if not entry or entry.failed then return end
    entry.failed = true
    fireUpdate(player, id, 0, 1, false, true)
    if UpdateHUD then
        UpdateHUD:FireClient(player, {
            Message  = "Challenge Failed: " .. entry.data.Name,
            Duration = 3,
            Color    = Color3.fromRGB(200, 50, 50),
        })
    end
end

local function completeChallenge(player, state, id, metaProgression)
    local entry = state.activeChallenges[id]
    if not entry or entry.failed or entry.completed then return end
    entry.completed = true
    fireUpdate(player, id, 1, 1, true, false)

    local reward = entry.data.Reward
    local rewardText = reward and reward.DisplayText or ""

    if UpdateHUD then
        UpdateHUD:FireClient(player, {
            Message  = "✦ Challenge Complete: " .. entry.data.Name,
            SubText  = rewardText,
            Duration = 5,
            Color    = entry.data.Color,
        })
    end

    -- Apply reward
    if reward then
        if reward.Type == "MasteryPoints" and metaProgression then
            local meta = metaProgression.GetState and metaProgression.GetState(player)
            if meta then
                meta.MasteryPoints = (meta.MasteryPoints or 0) + reward.Amount
            end
        elseif reward.Type == "Cosmetic" and entry.data.AchievementKey then
            -- Unlock the cosmetic via MetaProgression achievement tracking
            if metaProgression and metaProgression.TrackAchievement then
                metaProgression.TrackAchievement(player, entry.data.AchievementKey)
            end
        end
    end
end

-- ── Public API ────────────────────────────────────────────────────────────────

local ChallengeTracker = {}
local _MetaProgression = nil

function ChallengeTracker.SetMetaProgression(mp)
    _MetaProgression = mp
end

-- Called by GameManager when a new run starts.
-- challengeIds: array of up to MaxActiveChallenges challenge IDs the player selected.
function ChallengeTracker.StartRun(player, challengeIds)
    local active = {}
    local count = 0
    for _, id in ipairs(challengeIds or {}) do
        if count >= ChallengeData.MaxActiveChallenges then break end
        local data = ChallengeData.GetById(id)
        if data then
            active[id] = { data = data, progress = 0, failed = false, completed = false }
            count = count + 1
            fireUpdate(player, id, 0, 1, false, false)
        end
    end
    RunState[player] = {
        activeChallenges = active,
        kills            = 0,
        damageTaken      = 0,
        deathCount       = 0,
        shopGoldSpent    = 0,
        restRoomsUsed    = 0,
        noDmgRoomStreak  = 0,
        highestFloor     = 0,
        bossNoDamage     = true,
        inBossRoom       = false,
        floorEnterTime   = {},
        floorClearTime   = {},
    }
end

-- Called by GameManager / CombatSystem at key game events.
-- event: string key, data: table of context
function ChallengeTracker.TrackEvent(player, event, data)
    local state = getState(player)
    if not state then return end
    data = data or {}

    -- ── Record raw stats ──────────────────────────────────────────────────
    if event == "EnemyKilled" then
        state.kills = state.kills + 1
    elseif event == "PlayerDamageTaken" then
        state.damageTaken = state.damageTaken + (data.Amount or 0)
        if state.inBossRoom then
            state.bossNoDamage = false
        end
    elseif event == "PlayerDied" then
        state.deathCount = state.deathCount + 1
        state.noDmgRoomStreak = 0
        state.bossNoDamage    = false
    elseif event == "ShopPurchase" then
        state.shopGoldSpent = state.shopGoldSpent + (data.Cost or 0)
    elseif event == "RestRoomUsed" then
        state.restRoomsUsed = state.restRoomsUsed + 1
    elseif event == "RoomCleared" then
        if data.RoomType == "Combat" or data.RoomType == "Elite" then
            if state.damageTaken == 0 then
                state.noDmgRoomStreak = state.noDmgRoomStreak + 1
            else
                state.noDmgRoomStreak = 0
            end
            state.damageTaken = 0  -- reset per-room counter
        end
    elseif event == "BossRoomEnter" then
        state.inBossRoom  = true
        state.bossNoDamage = true
    elseif event == "BossDefeated" then
        state.inBossRoom = false
    elseif event == "FloorEnter" then
        state.floorEnterTime[data.Floor] = tick()
        state.highestFloor = math.max(state.highestFloor, data.Floor)
    elseif event == "FloorCleared" then
        local enterTime = state.floorEnterTime[data.Floor]
        if enterTime then
            state.floorClearTime[data.Floor] = tick() - enterTime
        end
    end

    -- ── Evaluate active challenges ────────────────────────────────────────
    for id, entry in pairs(state.activeChallenges) do
        if entry.failed or entry.completed then continue end
        local cond = entry.data.Condition

        -- NoDeaths
        if cond.Type == "NoDeaths" and state.deathCount > (cond.Threshold or 0) then
            failChallenge(player, state, id)

        -- KillCount
        elseif cond.Type == "KillCount" then
            fireUpdate(player, id, state.kills, cond.Threshold, false, false)
            if state.kills >= cond.Threshold then
                completeChallenge(player, state, id, _MetaProgression)
            end

        -- NoShop
        elseif cond.Type == "NoShop" and state.shopGoldSpent > 0 then
            failChallenge(player, state, id)

        -- NoRest
        elseif cond.Type == "NoRest" and state.restRoomsUsed > 0 then
            failChallenge(player, state, id)

        -- NoDamageTakenRooms (streak)
        elseif cond.Type == "NoDamageTakenRooms" then
            fireUpdate(player, id, state.noDmgRoomStreak, cond.Threshold, false, false)
            if state.noDmgRoomStreak >= cond.Threshold then
                completeChallenge(player, state, id, _MetaProgression)
            end

        -- FloorSpeedClear
        elseif cond.Type == "FloorSpeedClear" then
            local clearSecs = state.floorClearTime[cond.Floor]
            if clearSecs then
                if clearSecs <= cond.TimeLimitSeconds then
                    completeChallenge(player, state, id, _MetaProgression)
                else
                    failChallenge(player, state, id)
                end
            end

        -- BossNoDamage
        elseif cond.Type == "BossNoDamage" and event == "BossDefeated" then
            if state.bossNoDamage then
                completeChallenge(player, state, id, _MetaProgression)
            else
                failChallenge(player, state, id)
            end
        end
    end
end

-- Called when run ends to evaluate floor-gated completions (NoDeaths + MinFloor, etc.)
function ChallengeTracker.EvaluateRunEnd(player)
    local state = getState(player)
    if not state then return end

    for id, entry in pairs(state.activeChallenges) do
        if entry.failed or entry.completed then continue end
        local cond = entry.data.Condition

        if cond.Type == "NoDeaths" then
            local meetsFloor = (not cond.MinFloor) or state.highestFloor >= cond.MinFloor
            local extraOK = true
            if cond.ExtraConditions then
                if cond.ExtraConditions.Type == "NoRest" then
                    extraOK = state.restRoomsUsed == 0
                elseif cond.ExtraConditions.Type == "BossNoDamage" then
                    extraOK = state.bossNoDamage
                end
            end
            if state.deathCount == 0 and meetsFloor and extraOK then
                completeChallenge(player, state, id, _MetaProgression)
            else
                failChallenge(player, state, id)
            end
        elseif cond.Type == "MaxAbilitySlots" then
            -- Validated externally by GameManager passing slot count
            -- If still active at run end and MinFloor met, complete
            if (not cond.MinFloor) or state.highestFloor >= cond.MinFloor then
                if not entry.slotViolated then
                    completeChallenge(player, state, id, _MetaProgression)
                end
            end
        end
    end

    RunState[player] = nil
end

-- Called if the player equips more slots than a MaxAbilitySlots challenge allows
function ChallengeTracker.OnAbilitySlotsChanged(player, filledCount)
    local state = getState(player)
    if not state then return end
    for id, entry in pairs(state.activeChallenges) do
        if entry.failed then continue end
        local cond = entry.data.Condition
        if cond.Type == "MaxAbilitySlots" and filledCount > cond.Threshold then
            entry.slotViolated = true
            failChallenge(player, state, id)
        end
    end
end

-- Returns active challenges for a player (used by HUD sync)
function ChallengeTracker.GetActive(player)
    local state = getState(player)
    if not state then return {} end
    local result = {}
    for id, entry in pairs(state.activeChallenges) do
        table.insert(result, {
            Id          = id,
            Name        = entry.data.Name,
            Color       = entry.data.Color,
            Tier        = entry.data.Tier,
            Failed      = entry.failed,
            Completed   = entry.completed,
            Progress    = entry.progress,
        })
    end
    return result
end

Players.PlayerRemoving:Connect(function(player)
    RunState[player] = nil
end)

print("[ChallengeTracker] Loaded.")

return ChallengeTracker
