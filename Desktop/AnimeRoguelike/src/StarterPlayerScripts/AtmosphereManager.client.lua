-- AtmosphereManager.client.lua
-- Listens for FloorStart events and transforms the Lighting service + spawns
-- ambient floating particles to give each dungeon a distinct visual identity.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")
local RunService        = game:GetService("RunService")

local DungeonThemes  = require(ReplicatedStorage.Modules.DungeonThemes)
local RemoteEvents   = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateHUD      = RemoteEvents:WaitForChild("UpdateHUD")

-- ── Lighting sub-objects (created by WorldBuilder, or found here) ─────────────

local function getOrCreate(className, parent)
    local existing = parent:FindFirstChildOfClass(className)
    if existing then return existing end
    local obj = Instance.new(className)
    obj.Parent = parent
    return obj
end

local atm = getOrCreate("Atmosphere",      Lighting)
local cc  = getOrCreate("ColorCorrectionEffect", Lighting)
local bl  = getOrCreate("BloomEffect",           Lighting)

-- Lobby / default values (captured once at startup)
local DEFAULT = {
    Ambient        = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogColor       = Lighting.FogColor,
    FogStart       = Lighting.FogStart,
    FogEnd         = Lighting.FogEnd,
    Brightness     = Lighting.Brightness,
    ClockTime      = Lighting.ClockTime,
    AtmDensity     = atm.Density,
    AtmOffset      = atm.Offset,
    AtmColor       = atm.Color,
    AtmDecay       = atm.Decay,
    AtmGlare       = atm.Glare,
    AtmHaze        = atm.Haze,
}

-- ── Ambient particle emitters ─────────────────────────────────────────────────

local PARTICLE_COUNT = 18
local particleParts  = {}   -- cleanup list
local particleRunning = false

local function clearParticles()
    particleRunning = false
    for _, p in ipairs(particleParts) do
        pcall(function() p:Destroy() end)
    end
    particleParts = {}
end

local function spawnAmbientParticles(color)
    clearParticles()
    particleRunning = true

    local player = Players.LocalPlayer
    -- Spawn particles in a wide band around where the player will be
    -- We don't know exact dungeon pos, so place them relative to current camera
    local camera = workspace.CurrentCamera

    for i = 1, PARTICLE_COUNT do
        task.delay(i * 0.18, function()
            if not particleRunning then return end

            local anchor = Instance.new("Part")
            anchor.Size        = Vector3.new(0.4, 0.4, 0.4)
            anchor.Anchored    = true
            anchor.CanCollide  = false
            anchor.CastShadow  = false
            anchor.Transparency = 0
            anchor.Color       = color
            anchor.Material    = Enum.Material.Neon

            -- Seed position: loose sphere around current camera focus
            local cf  = camera.CFrame
            local rx  = (math.random() * 2 - 1) * 50
            local rz  = (math.random() * 2 - 1) * 50
            local ry  = math.random() * 2
            anchor.Position = cf.Position + Vector3.new(rx, ry, rz)
            anchor.Parent   = workspace

            -- Slow drift upward
            local dur    = math.random() * 6 + 5
            local target = anchor.Position + Vector3.new(
                (math.random() * 2 - 1) * 6,
                math.random() * 14 + 8,
                (math.random() * 2 - 1) * 6
            )
            TweenService:Create(anchor,
                TweenInfo.new(dur, Enum.EasingStyle.Sine),
                { Position = target, Transparency = 1, Size = Vector3.new(0.12, 0.12, 0.12) }
            ):Play()

            Debris:AddItem(anchor, dur + 0.1)
            table.insert(particleParts, anchor)
        end)
    end
end

-- Continuously re-emit particles while a theme is active
local emitLoop = nil

local function startParticleLoop(color)
    if emitLoop then
        task.cancel(emitLoop)
        emitLoop = nil
    end
    spawnAmbientParticles(color)
    -- Re-burst every 12 seconds to keep the atmosphere alive
    emitLoop = task.spawn(function()
        while particleRunning do
            task.wait(12)
            if particleRunning then
                spawnAmbientParticles(color)
            end
        end
    end)
end

-- ── Theme application ─────────────────────────────────────────────────────────

local FADE_TIME = 3.0   -- seconds for full lighting transition

local function applyTheme(themeData)
    local L = themeData.Lighting
    local A = themeData.Atmosphere

    -- Tween primary Lighting properties
    TweenService:Create(Lighting, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine), {
        Ambient        = L.Ambient,
        OutdoorAmbient = L.OutdoorAmbient,
        FogColor       = L.FogColor,
        FogStart       = L.FogStart,
        FogEnd         = L.FogEnd,
        Brightness     = L.Brightness,
        ClockTime      = L.ClockTime,
    }):Play()

    -- Tween Atmosphere
    TweenService:Create(atm, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine), {
        Density = A.Density,
        Offset  = A.Offset,
        Color   = A.Color,
        Decay   = A.Decay,
        Glare   = A.Glare,
        Haze    = A.Haze,
    }):Play()

    -- Tune ColorCorrection and Bloom to match mood
    local isDark    = L.Brightness < 1.5
    local isVibrant = A.Density > 0.4
    TweenService:Create(cc, TweenInfo.new(FADE_TIME), {
        Brightness  = isDark    and -0.04 or 0.02,
        Contrast    = isVibrant and 0.18  or 0.08,
        Saturation  = isVibrant and 0.25  or 0.12,
    }):Play()
    TweenService:Create(bl, TweenInfo.new(FADE_TIME), {
        Intensity = isDark and 0.7 or 0.35,
        Size      = isDark and 32  or 20,
        Threshold = isDark and 0.88 or 0.95,
    }):Play()

    -- Ambient particles
    startParticleLoop(themeData.ParticleColor)
end

local function applyLobby()
    clearParticles()
    TweenService:Create(Lighting, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Sine), {
        Ambient        = DEFAULT.Ambient,
        OutdoorAmbient = DEFAULT.OutdoorAmbient,
        FogColor       = DEFAULT.FogColor,
        FogStart       = DEFAULT.FogStart,
        FogEnd         = DEFAULT.FogEnd,
        Brightness     = DEFAULT.Brightness,
        ClockTime      = DEFAULT.ClockTime,
    }):Play()
    TweenService:Create(atm, TweenInfo.new(FADE_TIME), {
        Density = DEFAULT.AtmDensity,
        Offset  = DEFAULT.AtmOffset,
        Color   = DEFAULT.AtmColor,
        Decay   = DEFAULT.AtmDecay,
        Glare   = DEFAULT.AtmGlare,
        Haze    = DEFAULT.AtmHaze,
    }):Play()
    TweenService:Create(cc, TweenInfo.new(FADE_TIME), { Brightness=0.02, Contrast=0.08, Saturation=0.15 }):Play()
    TweenService:Create(bl, TweenInfo.new(FADE_TIME), { Intensity=0.4, Size=24, Threshold=0.95 }):Play()
end

-- ── Event listener ────────────────────────────────────────────────────────────

UpdateHUD.OnClientEvent:Connect(function(data)
    if data.FloorStart and data.ThemeIndex then
        local theme = DungeonThemes.Themes[data.ThemeIndex]
        if theme and theme.Lighting then
            applyTheme(theme)
        end
    elseif data.ReturnToLobby then
        applyLobby()
    end
end)

print("[AtmosphereManager] Loaded.")
