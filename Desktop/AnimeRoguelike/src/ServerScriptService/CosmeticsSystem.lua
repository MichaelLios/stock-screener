-- CosmeticsSystem.lua
-- Server authority for cosmetic unlock/equip/sync.
-- Reads MetaProgression achievement data to validate unlocks.
-- Broadcasts equipped cosmetics to all clients via CosmeticSync.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticsData  = require(ReplicatedStorage.Modules.CosmeticsData)
local MetaProgression = require(script.Parent.MetaProgression)

local RemoteEvents      = ReplicatedStorage:WaitForChild("RemoteEvents")
local SetCosmeticEvt    = RemoteEvents:WaitForChild("SetCosmetic",   15)
local CosmeticSyncEvt   = RemoteEvents:WaitForChild("CosmeticSync",  15)

-- ── Per-player equipped cosmetics ─────────────────────────────────────────────

-- [player] = { Aura = key, Title = key, Trail = key }
local EquippedCosmetics = {}

local function defaultEquipped()
    return { Aura = "None", Title = "Newcomer", Trail = "None" }
end

-- ── Validation ────────────────────────────────────────────────────────────────

local function validateAndEquip(player, cosmeticType, cosmeticKey)
    local state = EquippedCosmetics[player]
    if not state then return false, "NotInitialized" end

    local meta = MetaProgression.GetState and MetaProgression.GetState(player)
    local ok = CosmeticsData.IsUnlocked(player, cosmeticType .. "s", cosmeticKey, meta)
    if not ok then
        return false, "NotUnlocked"
    end

    state[cosmeticType] = cosmeticKey
    return true
end

-- ── Sync helpers ──────────────────────────────────────────────────────────────

local function syncToAll(player)
    local state = EquippedCosmetics[player]
    if not state then return end
    CosmeticSyncEvt:FireAllClients({
        UserId  = player.UserId,
        Aura    = state.Aura,
        Title   = state.Title,
        Trail   = state.Trail,
    })
end

local function syncAllToNewPlayer(newPlayer)
    -- Send every existing player's cosmetics to the new arrival
    for existingPlayer, state in pairs(EquippedCosmetics) do
        CosmeticSyncEvt:FireClient(newPlayer, {
            UserId = existingPlayer.UserId,
            Aura   = state.Aura,
            Title  = state.Title,
            Trail  = state.Trail,
        })
    end
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    -- Initialize with defaults; in production, load from DataStore here
    EquippedCosmetics[player] = defaultEquipped()

    -- Small delay so their client scripts are ready
    task.delay(3, function()
        if EquippedCosmetics[player] then
            syncAllToNewPlayer(player)
            syncToAll(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    EquippedCosmetics[player] = nil
end)

-- ── SetCosmetic handler ───────────────────────────────────────────────────────
-- Client fires: { CosmeticType = "Aura"|"Title"|"Trail", CosmeticKey = string }

SetCosmeticEvt.OnServerEvent:Connect(function(player, data)
    if type(data) ~= "table" then return end
    local cosType = data.CosmeticType
    local cosKey  = data.CosmeticKey
    if type(cosType) ~= "string" or type(cosKey) ~= "string" then return end
    if cosType ~= "Aura" and cosType ~= "Title" and cosType ~= "Trail" then return end

    local ok, reason = validateAndEquip(player, cosType, cosKey)
    if ok then
        syncToAll(player)
    else
        -- Notify just this player that the request failed
        CosmeticSyncEvt:FireClient(player, {
            Error  = reason,
            UserId = player.UserId,
        })
    end
end)

-- ── Public API ────────────────────────────────────────────────────────────────

local CosmeticsSystem = {}

-- Called by MetaProgression when an achievement completes to unlock new cosmetics
function CosmeticsSystem.OnAchievementUnlocked(player, achievementKey)
    -- Nothing to force-equip; just sync so the client knows something changed
    syncToAll(player)
end

-- Retrieve equipped cosmetics for server-side logic (e.g., aura color for awakening)
function CosmeticsSystem.GetEquipped(player)
    return EquippedCosmetics[player] or defaultEquipped()
end

return CosmeticsSystem
