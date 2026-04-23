-- AbilityVFX.client.lua
-- Renders per-ability visual and sound effects on all clients via AbilityCast.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteEvents   = ReplicatedStorage:WaitForChild("RemoteEvents")
local AbilityCastEvt = RemoteEvents:WaitForChild("AbilityCast")

-- ─── Sound IDs (replace rbxassetid://0 with real asset IDs) ──────────────────
-- Category names are intentional so you can batch-replace by sound type.
-- Free Roblox Library audio IDs (widely available, no copyright claims)
local SFX = {
    Slash     = "rbxassetid://3200164609",  -- sword swing whoosh
    Dash      = "rbxassetid://2603306847",  -- fast movement whoosh
    Tornado   = "rbxassetid://3264923152",  -- wind vortex
    Thunder   = "rbxassetid://3694641438",  -- lightning crack
    MagicBolt = "rbxassetid://1369158767",  -- arcane zap
    Shield    = "rbxassetid://2697874439",  -- barrier hum
    Explosion = "rbxassetid://4612390321",  -- burst boom
    Punch     = "rbxassetid://186311262",   -- heavy impact
    Taunt     = "rbxassetid://154965962",   -- battle roar
    Rush      = "rbxassetid://2603306847",  -- charging rush
    Shadow    = "rbxassetid://2697874439",  -- teleport whoosh
    Poison    = "rbxassetid://3271905640",  -- venomous hiss
    Mark      = "rbxassetid://4564590570",  -- dark seal
    Spirit    = "rbxassetid://1369158767",  -- spirit energy
    Bankai    = "rbxassetid://4612390321",  -- power release
    Counter   = "rbxassetid://3200164609",  -- stance click
    Frost     = "rbxassetid://3006333287",  -- ice shatter
    Slam      = "rbxassetid://4612390321",  -- ground pound
    Haki      = "rbxassetid://3271905640",  -- energy crackle
    Smoke     = "rbxassetid://2697874439",  -- smoke pop
    Heal      = "rbxassetid://2697874439",  -- healing chime
    Beam      = "rbxassetid://1369158767",  -- energy beam
    Chakra    = "rbxassetid://1369158767",  -- chakra burst
    SoulDrain = "rbxassetid://3271905640",  -- life drain
}

local Players2 = game:GetService("Players")
local function getSFXVolume()
    local pg = Players2.LocalPlayer and Players2.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return 0.65 end
    local vf = pg:FindFirstChild("_VolumeState")
    if not vf then return 0.65 end
    local sv = vf:FindFirstChild("SFXVolume")
    return sv and sv.Value or 0.65
end

local function playSound(sfxKey, pos)
    local id = SFX[sfxKey]
    if not id then return end
    local anchor = Instance.new("Part")
    anchor.Size = Vector3.new(1, 1, 1)
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Position = pos
    anchor.Parent = workspace
    local snd = Instance.new("Sound")
    snd.SoundId = id
    snd.Volume = getSFXVolume()
    snd.RollOffMaxDistance = 90
    snd.Parent = anchor
    snd:Play()
    Debris:AddItem(anchor, 4)
end

-- ─── VFX helpers ──────────────────────────────────────────────────────────────

-- evoScale: returns a size multiplier and color shift based on evolution stage
-- Stage 0 = base, Stage 1 = +30% larger, Stage 2 = +80% larger + color shift
local function evoScale(stage)
    if stage == 2 then return 1.80 end
    if stage == 1 then return 1.30 end
    return 1.0
end

-- Returns a shifted color for evolved abilities:
-- Stage 1: slightly brighter/saturated; Stage 2: dramatic hue shift toward white-hot or void-purple
local function evoColor(baseColor, stage)
    if stage == 0 then return baseColor end
    local r, g, b = baseColor.R, baseColor.G, baseColor.B
    if stage == 1 then
        -- Slightly brighter
        return Color3.new(math.min(r + 0.15, 1), math.min(g + 0.15, 1), math.min(b + 0.15, 1))
    else
        -- Stage 2: blend toward white-gold (1, 1, 0.7)
        local t = 0.45
        return Color3.new(r + (1 - r) * t, g + (1 - g) * t, b + (0.7 - b) * t)
    end
end

local function neonPart(size, color, pos)
    local p = Instance.new("Part")
    p.Size = size
    p.Color = color
    p.Material = Enum.Material.Neon
    p.CanCollide = false
    p.CastShadow = false
    p.Anchored = true
    p.Position = pos
    p.Parent = workspace
    return p
end

local function tweenFade(part, duration)
    TweenService:Create(
        part,
        TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Transparency = 1 }
    ):Play()
    Debris:AddItem(part, duration + 0.05)
end

-- Flat expanding ring (Cylinder lying on its side)
local function expandRing(pos, color, maxRadius, duration)
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.3, maxRadius * 0.05, maxRadius * 0.05)
    ring.Color = color
    ring.Material = Enum.Material.Neon
    ring.CanCollide = false
    ring.CastShadow = false
    ring.Anchored = true
    ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
    ring.Parent = workspace
    TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.15, maxRadius, maxRadius),
        Transparency = 1,
    }):Play()
    Debris:AddItem(ring, duration + 0.05)
end

-- ─── Per-ability VFX (keyed by ability name matching AbilitySystem.Abilities) ──

local AbilityVFX = {}

-- ── SWORDSMAN ─────────────────────────────────────────────────────────────────

AbilityVFX.BasicSlash = function(pos, dir)
    playSound("Slash", pos)
    local angles = { -30, 0, 30 }
    for _, deg in ipairs(angles) do
        local p = neonPart(Vector3.new(8, 0.25, 0.25), Color3.fromRGB(255, 240, 150), pos)
        p.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(deg), 0) * CFrame.new(4, 0, 0)
        TweenService:Create(p, TweenInfo.new(0.2), {
            Size = Vector3.new(12, 0.1, 0.1),
            Transparency = 1,
        }):Play()
        Debris:AddItem(p, 0.25)
    end
end

AbilityVFX.QuickDash = function(pos, dir)
    playSound("Dash", pos)
    for i = 1, 6 do
        task.delay(i * 0.04, function()
            local trailPos = pos - dir * (i * 2.5)
            local p = neonPart(Vector3.new(1.2, 2, 0.6), Color3.fromRGB(100, 220, 255), trailPos)
            tweenFade(p, 0.3)
        end)
    end
end

AbilityVFX.BladeTornado = function(pos, dir)
    playSound("Tornado", pos)
    -- Ground ring burst
    expandRing(pos, Color3.fromRGB(180, 255, 70), 28, 0.65)
    expandRing(pos, Color3.fromRGB(255, 255, 120), 16, 0.45)
    -- Rising spiral vortex column (12 layers × 6 blades)
    for layer = 0, 11 do
        task.delay(layer * 0.045, function()
            local ht = layer * 2.2
            local baseAngle = (layer / 12) * math.pi * 4  -- two full rotations going up
            for b = 0, 2 do
                local angle = baseAngle + b * (math.pi * 2 / 3)
                local bx = math.cos(angle) * (5 + layer * 0.3)
                local bz = math.sin(angle) * (5 + layer * 0.3)
                local blade = neonPart(
                    Vector3.new(5 - layer * 0.2, 0.35, 0.35),
                    Color3.fromRGB(190 + layer * 5, 255, 80 + layer * 10),
                    pos + Vector3.new(bx, ht, bz)
                )
                blade.CFrame = CFrame.new(pos + Vector3.new(bx, ht, bz))
                    * CFrame.Angles(0, angle, math.rad(15))
                TweenService:Create(blade, TweenInfo.new(0.4), {
                    Transparency = 1,
                    Size = Vector3.new(1, 0.1, 0.1),
                }):Play()
                Debris:AddItem(blade, 0.45)
            end
        end)
    end
    -- Core vortex pillar
    local pillar = neonPart(Vector3.new(2.5, 1, 2.5), Color3.fromRGB(200, 255, 60), pos)
    pillar.Shape = Enum.PartType.Cylinder
    pillar.Transparency = 0.3
    TweenService:Create(pillar, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(1, 28, 1),
        CFrame = CFrame.new(pos + Vector3.new(0, 14, 0)) * CFrame.Angles(math.pi/2, 0, 0),
        Transparency = 1,
    }):Play()
    Debris:AddItem(pillar, 0.65)
end

AbilityVFX.ThunderClap = function(pos, dir)
    playSound("Thunder", pos)
    -- Jagged vertical lightning bolt
    for i = 1, 10 do
        local boltPos = pos + Vector3.new(math.random(-3, 3) * 0.25, i * 1.3, math.random(-3, 3) * 0.25)
        local p = neonPart(Vector3.new(0.45, 1.4, 0.45), Color3.fromRGB(255, 255, 100), boltPos)
        tweenFade(p, 0.3)
    end
    expandRing(pos, Color3.fromRGB(255, 255, 60), 30, 0.4)
    expandRing(pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 220, 0), 20, 0.3)
end

-- ── MAGE ──────────────────────────────────────────────────────────────────────

AbilityVFX.MagicBolt = function(pos, dir)
    playSound("MagicBolt", pos)
    expandRing(pos, Color3.fromRGB(140, 80, 255), 10, 0.25)
    local flash = neonPart(Vector3.new(2, 2, 2), Color3.fromRGB(180, 120, 255), pos + Vector3.new(0, 1, 0))
    flash.Shape = Enum.PartType.Ball
    tweenFade(flash, 0.2)
end

AbilityVFX.ManaShield = function(pos, dir)
    playSound("Shield", pos)
    local sphere = neonPart(Vector3.new(2, 2, 2), Color3.fromRGB(80, 160, 255), pos)
    sphere.Shape = Enum.PartType.Ball
    sphere.Transparency = 0.4
    TweenService:Create(sphere, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(10, 10, 10),
        Transparency = 0.82,
    }):Play()
    -- Fade out over shield duration (~6s)
    task.delay(0.5, function()
        TweenService:Create(sphere, TweenInfo.new(5.5), { Transparency = 1 }):Play()
    end)
    Debris:AddItem(sphere, 7)
end

AbilityVFX.ElementalBurst = function(pos, dir)
    playSound("Explosion", pos)
    local cols = {
        Color3.fromRGB(255, 80, 0),    -- fire
        Color3.fromRGB(80, 200, 255),  -- ice
        Color3.fromRGB(255, 255, 100), -- lightning
    }
    -- Staggered shockwave rings
    for i, c in ipairs(cols) do
        task.delay((i - 1) * 0.1, function()
            expandRing(pos, c, 36 + i * 4, 0.7)
        end)
    end
    -- Eruption pillar: 10 rising fireballs along central column
    for i = 1, 10 do
        task.delay(i * 0.035, function()
            local ht = i * 3
            local col = cols[((i - 1) % 3) + 1]
            local ball = neonPart(Vector3.new(3.5, 3.5, 3.5), col, pos + Vector3.new(0, ht, 0))
            ball.Shape = Enum.PartType.Ball
            ball.Transparency = 0.15
            TweenService:Create(ball, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = Vector3.new(1, 1, 1),
                CFrame = CFrame.new(pos + Vector3.new(0, ht + 4, 0)),
                Transparency = 1,
            }):Play()
            Debris:AddItem(ball, 0.5)
        end)
    end
    -- Central detonation sphere
    local core = neonPart(Vector3.new(3, 3, 3), Color3.fromRGB(255, 200, 80), pos)
    core.Shape = Enum.PartType.Ball
    TweenService:Create(core, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(22, 22, 22),
        Transparency = 1,
    }):Play()
    Debris:AddItem(core, 0.5)
    -- 6 radial elemental streaks flying outward
    for k = 0, 5 do
        local angle = (k / 6) * math.pi * 2
        local streak = neonPart(Vector3.new(1, 1, 14), cols[(k % 3) + 1], pos)
        streak.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, math.rad(-20))
        TweenService:Create(streak, TweenInfo.new(0.5), {
            CFrame = CFrame.new(pos + Vector3.new(math.cos(angle)*20, 8, math.sin(angle)*20)),
            Size = Vector3.new(0.3, 0.3, 2),
            Transparency = 1,
        }):Play()
        Debris:AddItem(streak, 0.55)
    end
end

-- ── BRAWLER ───────────────────────────────────────────────────────────────────

AbilityVFX.HeavyPunch = function(pos, dir)
    playSound("Punch", pos)
    for i = 1, 6 do
        local angle = (i / 6) * math.pi * 2
        local p = neonPart(Vector3.new(5, 0.4, 0.4), Color3.fromRGB(255, 140, 0), pos)
        p.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, math.random(-20, 20) * 0.015)
        TweenService:Create(p, TweenInfo.new(0.22), {
            CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0) * CFrame.new(6, 0, 0),
            Size = Vector3.new(2, 0.15, 0.15),
            Transparency = 1,
        }):Play()
        Debris:AddItem(p, 0.27)
    end
end

AbilityVFX.Taunt = function(pos, dir)
    playSound("Taunt", pos)
    expandRing(pos, Color3.fromRGB(220, 50, 50), 50, 0.75)
    local col = neonPart(Vector3.new(3, 14, 3), Color3.fromRGB(200, 50, 50), pos + Vector3.new(0, 7, 0))
    col.Shape = Enum.PartType.Cylinder
    col.Transparency = 0.45
    tweenFade(col, 0.75)
end

AbilityVFX.RagingRush = function(pos, dir)
    playSound("Rush", pos)
    -- Ground speed lines trailing behind the charge
    for i = 1, 12 do
        task.delay(i * 0.025, function()
            local tp = pos - dir * (i * 2.8)
            local glow = neonPart(Vector3.new(2.5, 2.5, 2.5), Color3.fromRGB(255, 100 + i*8, 20), tp)
            glow.Shape = Enum.PartType.Ball
            tweenFade(glow, 0.3)
            -- Ground streak line
            local streak = neonPart(Vector3.new(0.4, 0.3, 4), Color3.fromRGB(255, 80, 0),
                tp + Vector3.new(0, -0.5, 0))
            streak.CFrame = CFrame.new(tp + Vector3.new(0, -0.5, 0), tp + dir * 5)
            tweenFade(streak, 0.25)
        end)
    end
    -- Impact shockwave rings at end point
    local endPos = pos + dir * 15
    expandRing(endPos, Color3.fromRGB(255, 80, 0),  24, 0.45)
    expandRing(endPos, Color3.fromRGB(255, 180, 60), 14, 0.35)
    -- Impact flash
    local flash = neonPart(Vector3.new(4, 4, 4), Color3.fromRGB(255, 140, 30), endPos)
    flash.Shape = Enum.PartType.Ball
    TweenService:Create(flash, TweenInfo.new(0.3), { Size = Vector3.new(14, 14, 14), Transparency = 1 }):Play()
    Debris:AddItem(flash, 0.35)
end

-- ── ASSASSIN ──────────────────────────────────────────────────────────────────

AbilityVFX.ShadowStep = function(pos, dir)
    playSound("Shadow", pos)
    local smoke = neonPart(Vector3.new(3, 4, 3), Color3.fromRGB(40, 20, 60), pos)
    smoke.Transparency = 0.3
    TweenService:Create(smoke, TweenInfo.new(0.45), {
        Size = Vector3.new(7, 8, 7),
        Transparency = 1,
    }):Play()
    Debris:AddItem(smoke, 0.5)
    expandRing(pos, Color3.fromRGB(100, 40, 140), 12, 0.4)
end

AbilityVFX.PoisonBlade = function(pos, dir)
    playSound("Poison", pos)
    expandRing(pos, Color3.fromRGB(80, 200, 30), 10, 0.4)
    for i = 1, 4 do
        local offset = Vector3.new(math.random(-2, 2), i * 1.4, math.random(-2, 2))
        local drop = neonPart(Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(100, 220, 50), pos + offset)
        drop.Shape = Enum.PartType.Ball
        -- Oscillating glow for poison coat duration
        TweenService:Create(drop, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 6, true), {
            Size = Vector3.new(1.2, 1.2, 1.2),
        }):Play()
        Debris:AddItem(drop, 10)
    end
end

AbilityVFX.DeathMark = function(pos, dir)
    playSound("Mark", pos)
    -- Dark eruption pillar rising from target
    local pillar = neonPart(Vector3.new(2, 1, 2), Color3.fromRGB(180, 10, 30), pos)
    pillar.Shape = Enum.PartType.Cylinder
    pillar.Transparency = 0.25
    TweenService:Create(pillar, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(1, 22, 1),
        CFrame = CFrame.new(pos + Vector3.new(0, 11, 0)) * CFrame.Angles(math.pi/2, 0, 0),
        Transparency = 1,
    }):Play()
    Debris:AddItem(pillar, 0.6)
    -- 3 spinning dark sigil rings
    for k = 1, 3 do
        task.delay((k - 1) * 0.08, function()
            expandRing(pos + Vector3.new(0, (k-1)*2.5, 0), Color3.fromRGB(180, 0, 30), 10 + k*3, 0.6)
        end)
    end
    -- 4 floating dark skull/mark symbols orbiting the target
    for k = 0, 3 do
        local angle = (k / 4) * math.pi * 2
        local sigil = neonPart(
            Vector3.new(1.8, 1.8, 0.2),
            Color3.fromRGB(220, 20, 50),
            pos + Vector3.new(math.cos(angle)*5, 2, math.sin(angle)*5)
        )
        TweenService:Create(sigil, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CFrame = CFrame.new(pos + Vector3.new(math.cos(angle)*8, 8, math.sin(angle)*8)),
            Size = Vector3.new(0.3, 0.3, 0.1),
            Transparency = 1,
        }):Play()
        Debris:AddItem(sigil, 0.85)
    end
end

-- ── SPIRIT USER ───────────────────────────────────────────────────────────────

AbilityVFX.SpiritBlast = function(pos, dir)
    playSound("Spirit", pos)
    expandRing(pos, Color3.fromRGB(50, 220, 255), 12, 0.3)
    local flash = neonPart(Vector3.new(2, 2, 2), Color3.fromRGB(100, 240, 255), pos + Vector3.new(0, 1, 0))
    flash.Shape = Enum.PartType.Ball
    tweenFade(flash, 0.25)
end

AbilityVFX.AuraWall = function(pos, dir)
    playSound("Spirit", pos)
    expandRing(pos, Color3.fromRGB(180, 240, 255), 30, 0.6)
    expandRing(pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(100, 200, 255), 22, 0.45)
    local wave = neonPart(Vector3.new(0.5, 5, 0.5), Color3.fromRGB(200, 240, 255), pos)
    wave.Shape = Enum.PartType.Cylinder
    wave.Transparency = 0.4
    TweenService:Create(wave, TweenInfo.new(0.5), {
        Size = Vector3.new(0.3, 30, 30),
        Transparency = 1,
    }):Play()
    Debris:AddItem(wave, 0.55)
end

AbilityVFX.BankaiFrenzy = function(pos, dir)
    playSound("Bankai", pos)
    -- Core eruption pillar (bright golden)
    local col = neonPart(Vector3.new(6, 1, 6), Color3.fromRGB(255, 240, 160), pos + Vector3.new(0, 1, 0))
    col.Shape = Enum.PartType.Cylinder
    col.Transparency = 0.15
    TweenService:Create(col, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(9, 38, 9),
    }):Play()
    task.delay(0.55, function()
        TweenService:Create(col, TweenInfo.new(0.8), { Transparency = 1 }):Play()
    end)
    Debris:AddItem(col, 1.45)
    -- Staggered shockwave rings
    expandRing(pos, Color3.fromRGB(255, 220, 80),  36, 1.0)
    expandRing(pos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 255, 180), 26, 0.85)
    expandRing(pos + Vector3.new(0, 5, 0), Color3.fromRGB(255, 200, 60),  18, 0.7)
    -- 8 golden energy shards launching outward and upward
    for k = 0, 7 do
        task.delay(k * 0.04, function()
            local angle = (k / 8) * math.pi * 2
            local shard = neonPart(Vector3.new(1.2, 6, 1.2), Color3.fromRGB(255, 230, 100),
                pos + Vector3.new(0, 2, 0))
            TweenService:Create(shard, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                CFrame = CFrame.new(pos + Vector3.new(math.cos(angle)*16, 12, math.sin(angle)*16)),
                Size = Vector3.new(0.3, 1, 0.3),
                Transparency = 1,
            }):Play()
            Debris:AddItem(shard, 0.75)
        end)
    end
    -- Top burst flash
    task.delay(0.3, function()
        local burst = neonPart(Vector3.new(5, 5, 5), Color3.fromRGB(255, 255, 220), pos + Vector3.new(0, 32, 0))
        burst.Shape = Enum.PartType.Ball
        TweenService:Create(burst, TweenInfo.new(0.4), { Size = Vector3.new(20, 20, 20), Transparency = 1 }):Play()
        Debris:AddItem(burst, 0.45)
    end)
end

-- ── SWORDSMAN UNLOCKABLE ──────────────────────────────────────────────────────

AbilityVFX.SkywardSlash = function(pos, dir)
    playSound("Slash", pos)
    -- 3 converging vertical slash streaks
    for k = -1, 1 do
        local xOff = k * 1.5
        local slash = neonPart(Vector3.new(0.5, 5, 0.5), Color3.fromRGB(255, 255, 160), pos + Vector3.new(xOff, 0, 0))
        TweenService:Create(slash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.15, 26, 0.15),
            Transparency = 1,
            CFrame = CFrame.new(pos + Vector3.new(xOff, 13, 0)),
        }):Play()
        Debris:AddItem(slash, 0.45)
    end
    -- Horizontal slash wave at apex
    task.delay(0.25, function()
        local wave = neonPart(Vector3.new(20, 0.4, 0.4), Color3.fromRGB(255, 240, 80), pos + Vector3.new(0, 20, 0))
        TweenService:Create(wave, TweenInfo.new(0.3), { Size = Vector3.new(30, 0.1, 0.1), Transparency = 1 }):Play()
        Debris:AddItem(wave, 0.35)
    end)
    expandRing(pos, Color3.fromRGB(255, 240, 80), 22, 0.5)
    -- Ground shockwave
    expandRing(pos, Color3.fromRGB(255, 255, 200), 12, 0.35)
end

AbilityVFX.CounterStance = function(pos, dir)
    playSound("Counter", pos)
    expandRing(pos, Color3.fromRGB(80, 200, 255), 12, 0.4)
    local aura = neonPart(Vector3.new(5, 7, 5), Color3.fromRGB(100, 220, 255), pos)
    aura.Shape = Enum.PartType.Cylinder
    aura.Transparency = 0.6
    -- Linger for stance duration (~5s)
    TweenService:Create(aura, TweenInfo.new(5.0), { Transparency = 1 }):Play()
    Debris:AddItem(aura, 5.1)
end

-- ── MAGE UNLOCKABLE ───────────────────────────────────────────────────────────

AbilityVFX.FrostNova = function(pos, dir)
    playSound("Frost", pos)
    expandRing(pos, Color3.fromRGB(180, 240, 255), 28, 0.55)
    expandRing(pos + Vector3.new(0, 1, 0), Color3.fromRGB(140, 200, 255), 20, 0.45)
    for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2
        local spkPos = pos + Vector3.new(math.cos(angle) * 6, 1, math.sin(angle) * 6)
        local spk = neonPart(Vector3.new(0.6, 3.5, 0.6), Color3.fromRGB(200, 235, 255), spkPos)
        spk.CFrame = CFrame.new(spkPos) * CFrame.Angles(0, angle, math.pi / 6)
        tweenFade(spk, 0.65)
    end
end

AbilityVFX.ArcaneOrb = function(pos, dir)
    playSound("MagicBolt", pos)
    local orb = neonPart(Vector3.new(2, 2, 2), Color3.fromRGB(200, 50, 255), pos + Vector3.new(0, 1.5, 0))
    orb.Shape = Enum.PartType.Ball
    orb.Transparency = 0.15
    TweenService:Create(orb, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(4.5, 4.5, 4.5),
    }):Play()
    task.delay(0.3, function()
        TweenService:Create(orb, TweenInfo.new(0.5), { Transparency = 1 }):Play()
    end)
    Debris:AddItem(orb, 0.85)
    expandRing(pos, Color3.fromRGB(180, 40, 255), 14, 0.4)
end

-- ── BRAWLER UNLOCKABLE ────────────────────────────────────────────────────────

AbilityVFX.GroundSlam = function(pos, dir)
    playSound("Slam", pos)
    expandRing(pos, Color3.fromRGB(200, 140, 50), 24, 0.55)
    expandRing(pos, Color3.fromRGB(255, 180, 80), 16, 0.42)
    for i = 1, 6 do
        local dustPos = pos + Vector3.new(math.random(-7, 7), 1, math.random(-7, 7))
        local dust = neonPart(Vector3.new(3.5, 3.5, 3.5), Color3.fromRGB(180, 140, 80), dustPos)
        dust.Shape = Enum.PartType.Ball
        dust.Transparency = 0.35
        tweenFade(dust, 0.65)
    end
end

AbilityVFX.IronDefense = function(pos, dir)
    playSound("Haki", pos)
    local shell = neonPart(Vector3.new(1, 1, 1), Color3.fromRGB(20, 20, 20), pos)
    shell.Shape = Enum.PartType.Ball
    shell.Transparency = 0.45
    TweenService:Create(shell, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(9, 10, 9),
    }):Play()
    -- Linger for armor duration (~8s)
    task.delay(0.4, function()
        TweenService:Create(shell, TweenInfo.new(8.0), { Transparency = 1 }):Play()
    end)
    Debris:AddItem(shell, 9)
end

-- ── ASSASSIN UNLOCKABLE ───────────────────────────────────────────────────────

AbilityVFX.SmokeBomb = function(pos, dir)
    playSound("Smoke", pos)
    for i = 1, 7 do
        local sPos = pos + Vector3.new(math.random(-6, 6), math.random(0, 4), math.random(-6, 6))
        local s = neonPart(Vector3.new(4, 4, 4), Color3.fromRGB(140, 140, 140), sPos)
        s.Shape = Enum.PartType.Ball
        s.Transparency = 0.3
        TweenService:Create(s, TweenInfo.new(1.6), {
            Size = Vector3.new(11, 11, 11),
            Transparency = 1,
        }):Play()
        Debris:AddItem(s, 1.7)
    end
end

AbilityVFX.VenomStrike = function(pos, dir)
    playSound("Poison", pos)
    for i = 1, 6 do
        local angle = (i / 6) * math.pi * 2
        local p = neonPart(Vector3.new(0.4, 0.4, 4), Color3.fromRGB(80, 210, 30), pos)
        p.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0)
        TweenService:Create(p, TweenInfo.new(0.3), {
            CFrame = CFrame.new(pos) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -6),
            Size = Vector3.new(0.2, 0.2, 1.5),
            Transparency = 1,
        }):Play()
        Debris:AddItem(p, 0.35)
    end
end

-- ── SPIRIT USER UNLOCKABLE ────────────────────────────────────────────────────

AbilityVFX.SoulDrain = function(pos, dir)
    playSound("SoulDrain", pos)
    for i = 1, 6 do
        local angle = (i / 6) * math.pi * 2
        local startP = pos + Vector3.new(math.cos(angle) * 11, 0, math.sin(angle) * 11)
        local tendril = neonPart(Vector3.new(0.45, 0.45, 11), Color3.fromRGB(160, 60, 220), startP)
        tendril.CFrame = CFrame.new(startP, pos) * CFrame.new(0, 0, -5.5)
        TweenService:Create(tendril, TweenInfo.new(0.55), {
            CFrame = CFrame.new(pos),
            Size = Vector3.new(0.15, 0.15, 0.15),
            Transparency = 1,
        }):Play()
        Debris:AddItem(tendril, 0.6)
    end
    expandRing(pos, Color3.fromRGB(120, 40, 180), 28, 0.55)
end

AbilityVFX.ChakraStrike = function(pos, dir)
    playSound("Chakra", pos)
    expandRing(pos, Color3.fromRGB(80, 200, 255), 18, 0.4)
    local burst = neonPart(Vector3.new(1, 1, 1), Color3.fromRGB(180, 240, 255), pos)
    burst.Shape = Enum.PartType.Ball
    burst.Transparency = 0.1
    TweenService:Create(burst, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(12, 12, 12),
        Transparency = 1,
    }):Play()
    Debris:AddItem(burst, 0.43)
end

-- ── SHARED / UNLOCKABLE ───────────────────────────────────────────────────────

AbilityVFX.HealingSpring = function(pos, dir)
    playSound("Heal", pos)
    local pool = neonPart(Vector3.new(14, 0.35, 14), Color3.fromRGB(80, 220, 100), pos)
    pool.Transparency = 0.5
    TweenService:Create(pool, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = Vector3.new(18, 0.35, 18),
    }):Play()
    -- Sparkle risers over heal duration (~6s)
    for i = 1, 10 do
        task.delay(i * 0.6, function()
            if not pool.Parent then return end
            local sparkPos = pool.Position + Vector3.new(math.random(-7, 7), 0.5, math.random(-7, 7))
            local sp = neonPart(Vector3.new(0.55, 0.55, 0.55), Color3.fromRGB(120, 255, 140), sparkPos)
            sp.Shape = Enum.PartType.Ball
            TweenService:Create(sp, TweenInfo.new(0.7), {
                CFrame = CFrame.new(sparkPos + Vector3.new(0, 3.5, 0)),
                Transparency = 1,
            }):Play()
            Debris:AddItem(sp, 0.75)
        end)
    end
    task.delay(5.6, function()
        if pool.Parent then
            TweenService:Create(pool, TweenInfo.new(0.5), { Transparency = 1 }):Play()
        end
    end)
    Debris:AddItem(pool, 7)
end

AbilityVFX.UltimateKamehameha = function(pos, dir)
    playSound("Beam", pos)
    -- Charge-up rings
    expandRing(pos, Color3.fromRGB(255, 255, 255), 22, 0.6)
    expandRing(pos, Color3.fromRGB(255, 240, 100), 14, 0.5)
    -- Beam fires after charge time (~1.5s)
    task.delay(1.5, function()
        local beamLen = 80
        local midCF = CFrame.new(pos + dir * (beamLen / 2), pos + dir * beamLen)
        local beam = neonPart(Vector3.new(4, 4, beamLen), Color3.fromRGB(255, 240, 100), pos + dir * (beamLen / 2))
        beam.CFrame = midCF
        beam.Transparency = 0.08
        TweenService:Create(beam, TweenInfo.new(0.9), {
            Size = Vector3.new(6, 6, beamLen),
            Transparency = 0.12,
        }):Play()
        task.delay(0.9, function()
            TweenService:Create(beam, TweenInfo.new(0.5), { Transparency = 1 }):Play()
        end)
        Debris:AddItem(beam, 1.5)
        -- Tip explosion
        local tipPos = pos + dir * beamLen
        expandRing(tipPos, Color3.fromRGB(255, 220, 80), 20, 0.5)
        local tip = neonPart(Vector3.new(4, 4, 4), Color3.fromRGB(255, 255, 180), tipPos)
        tip.Shape = Enum.PartType.Ball
        TweenService:Create(tip, TweenInfo.new(0.45), { Size = Vector3.new(12, 12, 12), Transparency = 1 }):Play()
        Debris:AddItem(tip, 0.5)
    end)
end

-- ─── Event listener ───────────────────────────────────────────────────────────

AbilityCastEvt.OnClientEvent:Connect(function(data)
    local abilityName  = data.AbilityName
    local casterUserId = data.CasterUserId
    local posRaw       = data.Position
    local dirRaw       = data.Direction
    local stage        = data.EvoStage or 0

    local pos = posRaw
    if not pos then
        for _, p in ipairs(Players:GetPlayers()) do
            if p.UserId == casterUserId then
                local char = p.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then pos = root.Position end
                break
            end
        end
    end
    if not pos then return end

    local dir = dirRaw or Vector3.new(0, 0, 1)

    local vfxFn = AbilityVFX[abilityName]
    if vfxFn then
        vfxFn(pos, dir, stage)
    end

    -- Evolution stage overlay: stage 1 = subtle shimmer ring, stage 2 = dramatic energy burst
    if stage >= 1 then
        local sc   = evoScale(stage)
        local col  = stage == 2 and Color3.fromRGB(255, 240, 160) or Color3.fromRGB(220, 200, 255)
        local ring1Rad = 14 * sc
        expandRing(pos, col, ring1Rad, 0.45)
        if stage == 2 then
            -- Additional large burst ring + central flash
            expandRing(pos, Color3.fromRGB(255, 255, 200), ring1Rad * 1.4, 0.65)
            local flash = neonPart(
                Vector3.new(sc * 3, sc * 3, sc * 3),
                Color3.fromRGB(255, 250, 210),
                pos + Vector3.new(0, 1.5, 0)
            )
            flash.Shape = Enum.PartType.Ball
            flash.Transparency = 0.05
            TweenService:Create(flash,
                TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = Vector3.new(sc * 9, sc * 9, sc * 9), Transparency = 1 }
            ):Play()
            Debris:AddItem(flash, 0.4)
        end
    end
end)
