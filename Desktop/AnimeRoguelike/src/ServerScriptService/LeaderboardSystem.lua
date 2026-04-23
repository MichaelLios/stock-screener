-- LeaderboardSystem.lua
-- Global DataStore-backed leaderboards across four categories.
-- Persists top-100 per category; broadcasts top-10 on request or floor completion.

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local RemoteEvents       = ReplicatedStorage:WaitForChild("RemoteEvents")
local LeaderboardDataEvt = RemoteEvents:WaitForChild("LeaderboardData",    15)
local RequestLBEvt       = RemoteEvents:WaitForChild("RequestLeaderboard", 15)
local UpdateHUD          = RemoteEvents:WaitForChild("UpdateHUD",          15)

-- ── DataStore setup (graceful fallback in Studio) ─────────────────────────────

local Stores = {}
local CATEGORIES = {
    BestFloor       = true,   -- highest floor reached in one run (higher = better)
    TopRunDamage    = true,   -- highest total damage dealt in one run
    FastestFloor3   = false,  -- fastest Floor 3 clear in seconds (lower = better, stored negated)
    TotalKills      = true,   -- lifetime kill count
}

for cat in pairs(CATEGORIES) do
    local ok, store = pcall(function()
        return DataStoreService:GetOrderedDataStore("AR_LB_" .. cat .. "_v1")
    end)
    if ok then Stores[cat] = store end
end

-- In-memory best per player per session (avoid redundant DataStore writes)
local SessionBest = {}  -- [player][category] = value

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function getKey(player)
    return tostring(player.UserId)
end

-- Score is stored as-is for "higher = better"; for lower-is-better (FastestFloor3)
-- the caller passes a negated value so OrderedDataStore still sorts descending.
local function submitScore(player, category, value)
    local store = Stores[category]
    if not store then return end

    local key    = getKey(player)
    local sess   = SessionBest[player]
    if not sess then return end

    local prev = sess[category] or 0
    -- For lower-is-better categories (stored negated), a "better" value is more negative
    if value <= prev and CATEGORIES[category] == true then return end  -- not an improvement
    if value >= prev and CATEGORIES[category] == false then return end -- not an improvement (time)

    sess[category] = value
    pcall(function()
        store:SetAsync(key, value)
    end)
end

-- Returns top N entries as { { Name, Score } } sorted best-first
local function getTopN(category, n)
    local store = Stores[category]
    if not store then return {} end

    local ok, pages = pcall(function()
        return store:GetSortedAsync(false, n)   -- descending
    end)
    if not ok or not pages then return {} end

    local results = {}
    local ok2, entries = pcall(function() return pages:GetCurrentPage() end)
    if not ok2 then return {} end

    for _, entry in ipairs(entries) do
        local name = "[Unknown]"
        local ok3, player = pcall(function()
            return Players:GetNameFromUserIdAsync(tonumber(entry.key))
        end)
        if ok3 then name = player end

        local displayScore = entry.value
        -- Un-negate time categories for display
        if CATEGORIES[category] == false then displayScore = -displayScore end

        table.insert(results, { Name = name, Score = displayScore })
    end
    return results
end

-- ── Public API ────────────────────────────────────────────────────────────────

local LeaderboardSystem = {}

function LeaderboardSystem.SubmitRunStats(player, stats)
    -- stats = { BestFloor, TotalDamage, FastestFloor3Seconds, TotalKills }
    if stats.BestFloor then
        submitScore(player, "BestFloor", stats.BestFloor)
    end
    if stats.TotalDamage then
        submitScore(player, "TopRunDamage", stats.TotalDamage)
    end
    if stats.FastestFloor3Seconds and stats.FastestFloor3Seconds > 0 then
        -- Negate so lower time = higher OrderedDataStore score
        submitScore(player, "FastestFloor3", -stats.FastestFloor3Seconds)
    end
end

function LeaderboardSystem.IncrementKills(player, count)
    local sess = SessionBest[player]
    if not sess then return end
    sess.TotalKills = (sess.TotalKills or 0) + (count or 1)
    -- Kills are lifetime, so always overwrite
    local store = Stores["TotalKills"]
    if store then
        pcall(function()
            store:UpdateAsync(getKey(player), function(old)
                return math.max(old or 0, sess.TotalKills)
            end)
        end)
    end
end

-- Fires full leaderboard data to one player (or all clients if player == nil)
function LeaderboardSystem.BroadcastLeaderboards(targetPlayer)
    local data = {}
    for cat in pairs(CATEGORIES) do
        data[cat] = getTopN(cat, 10)
    end

    local packet = {
        LeaderboardData = true,
        Categories      = {
            { Id = "BestFloor",     Label = "Best Floor",         Unit = "Floor",    Entries = data.BestFloor },
            { Id = "TopRunDamage",  Label = "Top Run Damage",     Unit = "DMG",      Entries = data.TopRunDamage },
            { Id = "FastestFloor3", Label = "Fastest Floor 3",    Unit = "Seconds",  Entries = data.FastestFloor3 },
            { Id = "TotalKills",    Label = "Total Kills",        Unit = "Kills",    Entries = data.TotalKills },
        },
    }

    if targetPlayer then
        LeaderboardDataEvt:FireClient(targetPlayer, packet)
    else
        LeaderboardDataEvt:FireAllClients(packet)
    end
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    SessionBest[player] = { TotalKills = 0 }
end)

Players.PlayerRemoving:Connect(function(player)
    SessionBest[player] = nil
end)

-- ── Client request handler ────────────────────────────────────────────────────

if RequestLBEvt then
    RequestLBEvt.OnServerEvent:Connect(function(player)
        task.spawn(function()
            LeaderboardSystem.BroadcastLeaderboards(player)
        end)
    end)
end

print("[LeaderboardSystem] Loaded.")

return LeaderboardSystem
