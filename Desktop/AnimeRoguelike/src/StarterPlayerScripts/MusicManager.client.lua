-- MusicManager.client.lua
-- Plays background music on loop. Volume controlled by SettingsInventory panel.

local Players      = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

-- Volume state folder (shared with SettingsInventory)
local volumeFolder = playerGui:FindFirstChild("_VolumeState")
if not volumeFolder then
    volumeFolder = Instance.new("Folder")
    volumeFolder.Name   = "_VolumeState"
    volumeFolder.Parent = playerGui
end

local musicVol = volumeFolder:FindFirstChild("MusicVolume")
if not musicVol then
    musicVol = Instance.new("NumberValue")
    musicVol.Name   = "MusicVolume"
    musicVol.Value  = 0.5
    musicVol.Parent = volumeFolder
end

-- Playlist of audio asset IDs.
-- Replace these with audio you've uploaded to Roblox, or use free library IDs.
local PLAYLIST = {
    1843503735,
    1843503748,
    3006333287,
    5982459422,
}
local currentTrack = 0

-- Parent to SoundService for global (distance-independent) playback
local sound = Instance.new("Sound")
sound.Name   = "BGMusic"
sound.Volume = math.clamp(musicVol.Value, 0, 1)
sound.Looped = false
sound.Parent = SoundService

local function playNext()
    currentTrack = (currentTrack % #PLAYLIST) + 1
    sound.SoundId = "rbxassetid://" .. PLAYLIST[currentTrack]
    sound:Play()
end

sound.Ended:Connect(function()
    task.wait(0.5)
    playNext()
end)

musicVol.Changed:Connect(function(v)
    sound.Volume = math.clamp(v, 0, 1)
end)

playNext()
print("[MusicManager] Music started.")
