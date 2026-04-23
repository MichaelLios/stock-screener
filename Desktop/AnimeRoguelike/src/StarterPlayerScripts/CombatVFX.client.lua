-- CombatVFX.client.lua
-- All client-side combat visual feedback.
--
--   • Screen shake       — accumulator model, scales with hit weight
--   • Damage numbers     — type-coloured, crit-scaled, drop-shadowed
--   • Hit flash          — enemy briefly turns white (80 ms)
--   • Impact sparks      — neon particle burst at hit position
--   • Death VFX          — orb explosion + expanding ground ring
--   • Attack telegraph   — red floor circle 0.4 s before enemy hits
--   • Combo meter        — consecutive-hit counter with rank labels
--   • Damage vignette    — red edge flash when the player takes damage

local Players      = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local TakeDamage   = RemoteEvents:WaitForChild("TakeDamage")
local UpdateHUD    = RemoteEvents:WaitForChild("UpdateHUD")
local EnemyAttack  = RemoteEvents:WaitForChild("EnemyAttack")

-- ────────────────────────────────────────────────
-- DAMAGE TYPE PALETTE
-- ────────────────────────────────────────────────

local DamageColors = {
    Physical  = Color3.fromRGB(255, 160,  60),  -- warm orange
    Magic     = Color3.fromRGB(180,  90, 255),  -- violet
    Spirit    = Color3.fromRGB( 70, 220, 200),  -- teal
    Lightning = Color3.fromRGB(255, 240,  50),  -- electric yellow
    Fire      = Color3.fromRGB(255,  70,  20),  -- red-orange
    Ice       = Color3.fromRGB(120, 200, 255),  -- icy blue
    Poison    = Color3.fromRGB( 90, 220,  50),  -- acid green
    Default   = Color3.fromRGB(255, 255, 255),  -- white fallback
}
local CRIT_COLOR = Color3.fromRGB(255, 215, 0)  -- gold

-- ────────────────────────────────────────────────
-- ENEMY ID → MODEL CACHE  (O(1) lookup on TakeDamage)
-- ────────────────────────────────────────────────

local enemyById = {}  -- [EnemyId string] = Model

local function cacheDescendant(obj)
    if obj:IsA("Model") and obj:GetAttribute("IsEnemy") then
        local id = obj:GetAttribute("EnemyId")
        if id then enemyById[id] = obj end
    end
end

-- Seed from whatever is already in the world when this script loads
for _, obj in ipairs(workspace:GetDescendants()) do
    cacheDescendant(obj)
end

workspace.DescendantAdded:Connect(cacheDescendant)

-- ────────────────────────────────────────────────
-- SCREEN SHAKE
-- ────────────────────────────────────────────────

local shakeMag   = 0       -- current magnitude (studs)
local SHAKE_DECAY = 9      -- magnitude lost per second

RunService.RenderStepped:Connect(function(dt)
    if shakeMag < 0.005 then
        shakeMag = 0
        return
    end
    local ox = (math.random() * 2 - 1) * shakeMag
    local oy = (math.random() * 2 - 1) * shakeMag
    camera.CFrame = camera.CFrame * CFrame.new(ox, oy, 0)
    shakeMag = math.max(0, shakeMag - SHAKE_DECAY * dt)
end)

local function shake(amount)
    -- Clamp so rapid hits don't snowball into nausea territory
    shakeMag = math.min(shakeMag + amount, 1.4)
end

-- ────────────────────────────────────────────────
-- FLOATING DAMAGE NUMBERS
-- ────────────────────────────────────────────────

local function spawnNumber(position, damage, isCrit, damageType)
    local color = isCrit and CRIT_COLOR
        or (DamageColors[damageType] or DamageColors.Default)

    -- Invisible anchor part that rises during the tween
    local anchor = Instance.new("Part")
    anchor.Size        = Vector3.new(0.05, 0.05, 0.05)
    anchor.CFrame      = CFrame.new(position)
    anchor.Anchored    = true
    anchor.Transparency = 1
    anchor.CanCollide  = false
    anchor.Parent      = workspace
    Debris:AddItem(anchor, 1.5)

    -- BillboardGui attached to the anchor
    local bg = Instance.new("BillboardGui")
    bg.Size         = UDim2.new(0, isCrit and 100 or 72, 0, isCrit and 48 or 36)
    bg.StudsOffset  = Vector3.new((math.random() * 2 - 1) * 2, 3.5 + math.random(), 0)
    bg.AlwaysOnTop  = true
    bg.MaxDistance  = 80
    bg.Adornee      = anchor
    bg.Parent       = workspace
    Debris:AddItem(bg, 1.5)

    -- Drop shadow (offset 1 px, black)
    local shadow = Instance.new("TextLabel")
    shadow.Size                  = UDim2.new(1, 2, 1, 2)
    shadow.Position              = UDim2.new(0, 1, 0, 1)
    shadow.BackgroundTransparency = 1
    shadow.Text                  = isCrit and ("✦ " .. damage) or tostring(damage)
    shadow.TextColor3            = Color3.new(0, 0, 0)
    shadow.TextScaled            = true
    shadow.Font                  = Enum.Font.GothamBold
    shadow.ZIndex                = 4
    shadow.Parent                = bg

    -- Main label
    local lbl = Instance.new("TextLabel")
    lbl.Size                  = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = shadow.Text
    lbl.TextColor3            = color
    lbl.TextScaled            = true
    lbl.Font                  = Enum.Font.GothamBold
    lbl.ZIndex                = 5
    lbl.Parent                = bg

    if isCrit then
        -- Subtle outline so gold reads on any background
        lbl.TextStrokeColor3       = Color3.fromRGB(160, 90, 0)
        lbl.TextStrokeTransparency = 0.4
    end

    -- Rise + fade  (delay the fade so it's readable for ~0.5 s)
    local riseCF = anchor.CFrame + Vector3.new(0, isCrit and 5.5 or 3.5, 0)
    TweenService:Create(anchor,
        TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { CFrame = riseCF }
    ):Play()

    local fadeInfo = TweenInfo.new(0.7, Enum.EasingStyle.Linear,
        Enum.EasingDirection.In, 0, false, 0.55)
    TweenService:Create(lbl,    fadeInfo, { TextTransparency = 1 }):Play()
    TweenService:Create(shadow, fadeInfo, { TextTransparency = 1 }):Play()
end

-- ────────────────────────────────────────────────
-- HIT FLASH  (enemy turns white for 80 ms)
-- ────────────────────────────────────────────────

local flashCooldown = {}  -- prevent re-triggering before the restore finishes

local function hitFlash(model)
    if flashCooldown[model] then return end
    flashCooldown[model] = true

    local parts      = {}
    local origColors = {}
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            table.insert(parts, p)
            table.insert(origColors, p.Color)
            p.Color = Color3.new(1, 1, 1)
        end
    end

    task.delay(0.08, function()
        for i, p in ipairs(parts) do
            if p and p.Parent then p.Color = origColors[i] end
        end
        flashCooldown[model] = nil
    end)
end

-- ────────────────────────────────────────────────
-- IMPACT SPARKS
-- ────────────────────────────────────────────────

local function spawnSparks(position, color, count)
    for _ = 1, count do
        local spark = Instance.new("Part")
        spark.Shape    = Enum.PartType.Ball
        spark.Size     = Vector3.new(0.22, 0.22, 0.22)
        spark.Color    = color
        spark.Material = Enum.Material.Neon
        spark.CFrame   = CFrame.new(
            position + Vector3.new(
                (math.random() * 2 - 1) * 0.5,
                math.random() * 0.4,
                (math.random() * 2 - 1) * 0.5
            )
        )
        spark.Anchored    = false
        spark.CanCollide  = false
        spark.AssemblyLinearVelocity = Vector3.new(
            (math.random() * 2 - 1) * 32,
            math.random() * 22 + 8,
            (math.random() * 2 - 1) * 32
        )
        spark.Parent = workspace
        Debris:AddItem(spark, 0.55)

        TweenService:Create(spark,
            TweenInfo.new(0.45, Enum.EasingStyle.Quad),
            { Transparency = 1 }
        ):Play()
    end
end

-- ────────────────────────────────────────────────
-- DEATH VFX
-- ────────────────────────────────────────────────

local function playDeathVFX(model)
    local root = model.PrimaryPart
        or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChildWhichIsA("BasePart")
    if not root then return end

    local pos   = root.Position
    local color = root.Color
    local size  = root.Size

    -- Number of orbs scales with enemy physical size (small grunts → few, bosses → many)
    local orbCount = math.clamp(math.floor(size.Magnitude / 1.8), 5, 22)

    for _ = 1, orbCount do
        local orb = Instance.new("Part")
        orb.Shape    = Enum.PartType.Ball
        orb.Size     = Vector3.new(1, 1, 1) * (size.Magnitude / 14)
        orb.Color    = color
        orb.Material = Enum.Material.Neon
        orb.CFrame   = CFrame.new(
            pos + Vector3.new(
                (math.random() * 2 - 1) * size.X * 0.4,
                math.random() * size.Y * 0.5,
                (math.random() * 2 - 1) * size.Z * 0.4
            )
        )
        orb.Anchored   = false
        orb.CanCollide = false
        orb.AssemblyLinearVelocity = Vector3.new(
            (math.random() * 2 - 1) * 28,
            math.random() * 38 + 6,
            (math.random() * 2 - 1) * 28
        )
        orb.Parent = workspace
        Debris:AddItem(orb, 0.9)
        TweenService:Create(orb,
            TweenInfo.new(0.8, Enum.EasingStyle.Quad),
            { Transparency = 1 }
        ):Play()
    end

    -- Expanding ground ring
    local ring = Instance.new("Part")
    ring.Shape       = Enum.PartType.Cylinder
    ring.Size        = Vector3.new(0.25, 0.8, 0.8)
    ring.Color       = color
    ring.Material    = Enum.Material.Neon
    ring.CFrame      = CFrame.new(pos.X, pos.Y - size.Y * 0.5 + 0.15, pos.Z)
        * CFrame.Angles(0, 0, math.pi / 2)
    ring.Anchored    = true
    ring.CanCollide  = false
    ring.Transparency = 0.25
    ring.CastShadow  = false
    ring.Parent      = workspace
    Debris:AddItem(ring, 0.65)

    local ringDia = math.max(size.X, size.Z) * 2.8
    TweenService:Create(ring,
        TweenInfo.new(0.55, Enum.EasingStyle.Quad),
        {
            Size        = Vector3.new(0.1, ringDia, ringDia),
            Transparency = 1,
        }
    ):Play()
end

-- Hook into model removal.  pcall so a partially-removed model never breaks this.
workspace.DescendantRemoving:Connect(function(obj)
    if obj:IsA("Model") and obj:GetAttribute("IsEnemy") then
        local id = obj:GetAttribute("EnemyId")
        if id then
            enemyById[id] = nil
            pcall(playDeathVFX, obj)
        end
    end
end)

-- ────────────────────────────────────────────────
-- ATTACK TELEGRAPH
-- ────────────────────────────────────────────────
-- Server fires EnemyAttack { Position, Radius, Delay, AttackType }
-- just before the actual damage call.

local function showTelegraph(position, radius, delay)
    local indicator = Instance.new("Part")
    indicator.Shape       = Enum.PartType.Cylinder
    indicator.Size        = Vector3.new(0.18, radius * 2, radius * 2)
    indicator.CFrame      = CFrame.new(position.X, position.Y - 0.05, position.Z)
        * CFrame.Angles(0, 0, math.pi / 2)
    indicator.Anchored    = true
    indicator.CanCollide  = false
    indicator.Color       = Color3.fromRGB(220, 30, 30)
    indicator.Material    = Enum.Material.Neon
    indicator.Transparency = 0.6
    indicator.CastShadow  = false
    indicator.Parent      = workspace
    Debris:AddItem(indicator, delay + 0.1)

    -- Pulse toward solid → flash white at the moment of impact
    TweenService:Create(indicator,
        TweenInfo.new(delay * 0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        { Transparency = 0.28 }
    ):Play()

    task.delay(delay * 0.75, function()
        if not indicator.Parent then return end
        TweenService:Create(indicator,
            TweenInfo.new(delay * 0.25, Enum.EasingStyle.Quad),
            { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.75 }
        ):Play()
    end)
end

-- ────────────────────────────────────────────────
-- EXPLOSION VFX  (Explosive modifier on-death blast)
-- ────────────────────────────────────────────────
-- Called after the telegraph warning resolves.
-- Layers: central fireball → expanding shockwave ring → ember sparks → heavy shake.

local function showExplosionVFX(position, radius)
    -- 1. Central fireball — starts tight, expands then fades
    local fireball = Instance.new("Part")
    fireball.Shape       = Enum.PartType.Ball
    fireball.Size        = Vector3.new(1.5, 1.5, 1.5)
    fireball.CFrame      = CFrame.new(position)
    fireball.Anchored    = true
    fireball.CanCollide  = false
    fireball.Color       = Color3.fromRGB(255, 200, 40)
    fireball.Material    = Enum.Material.Neon
    fireball.Transparency = 0
    fireball.CastShadow  = false
    fireball.Parent      = workspace
    Debris:AddItem(fireball, 0.7)

    local fbDia = radius * 1.6
    TweenService:Create(fireball,
        TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = Vector3.new(fbDia, fbDia, fbDia), Transparency = 0.55 }
    ):Play()
    task.delay(0.35, function()
        if fireball.Parent then
            TweenService:Create(fireball,
                TweenInfo.new(0.25, Enum.EasingStyle.Linear),
                { Transparency = 1 }
            ):Play()
        end
    end)

    -- 2. Inner hot core (white-yellow flash, shorter-lived)
    local core = Instance.new("Part")
    core.Shape       = Enum.PartType.Ball
    core.Size        = Vector3.new(radius * 0.55, radius * 0.55, radius * 0.55)
    core.CFrame      = CFrame.new(position)
    core.Anchored    = true
    core.CanCollide  = false
    core.Color       = Color3.fromRGB(255, 255, 200)
    core.Material    = Enum.Material.Neon
    core.Transparency = 0.1
    core.CastShadow  = false
    core.Parent      = workspace
    Debris:AddItem(core, 0.35)

    TweenService:Create(core,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }
    ):Play()

    -- 3. Shockwave ring — flat cylinder that races outward along the ground
    local ring = Instance.new("Part")
    ring.Shape       = Enum.PartType.Cylinder
    ring.Size        = Vector3.new(0.22, 0.9, 0.9)
    ring.CFrame      = CFrame.new(position.X, position.Y - 0.05, position.Z)
        * CFrame.Angles(0, 0, math.pi / 2)
    ring.Anchored    = true
    ring.CanCollide  = false
    ring.Color       = Color3.fromRGB(255, 110, 20)
    ring.Material    = Enum.Material.Neon
    ring.Transparency = 0.25
    ring.CastShadow  = false
    ring.Parent      = workspace
    Debris:AddItem(ring, 0.5)

    local ringDia = radius * 2.2
    TweenService:Create(ring,
        TweenInfo.new(0.45, Enum.EasingStyle.Quad),
        { Size = Vector3.new(0.08, ringDia, ringDia), Transparency = 1 }
    ):Play()

    -- 4. Secondary smoke ring (darker, slightly delayed)
    local smoke = Instance.new("Part")
    smoke.Shape       = Enum.PartType.Cylinder
    smoke.Size        = Vector3.new(0.18, 0.4, 0.4)
    smoke.CFrame      = CFrame.new(position.X, position.Y + 0.6, position.Z)
        * CFrame.Angles(0, 0, math.pi / 2)
    smoke.Anchored    = true
    smoke.CanCollide  = false
    smoke.Color       = Color3.fromRGB(55, 40, 25)
    smoke.Material    = Enum.Material.SmoothPlastic
    smoke.Transparency = 0.55
    smoke.CastShadow  = false
    smoke.Parent      = workspace
    Debris:AddItem(smoke, 0.7)

    task.delay(0.08, function()
        if smoke.Parent then
            TweenService:Create(smoke,
                TweenInfo.new(0.55, Enum.EasingStyle.Quad),
                { Size = Vector3.new(0.1, radius * 1.7, radius * 1.7), Transparency = 1 }
            ):Play()
        end
    end)

    -- 5. Ember sparks — orange/yellow, more than a normal hit
    spawnSparks(position, Color3.fromRGB(255, 120, 20), 18)
    task.delay(0.06, function()
        spawnSparks(position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 220, 60), 10)
    end)

    -- 6. Heavy screen shake — largest in the game (boss-tier)
    shake(1.1)
    task.delay(0.08, function() shake(0.45) end)
end

EnemyAttack.OnClientEvent:Connect(function(data)
    if not data.Position then return end

    if data.AttackType == "Explosion" then
        -- Show the telegraph first, then trigger the blast VFX after the delay
        if data.Radius and data.Delay then
            showTelegraph(data.Position, data.Radius, data.Delay)
        end
        local blastDelay = data.Delay or 0
        task.delay(blastDelay, function()
            showExplosionVFX(data.Position, data.Radius or 12)
        end)
    elseif data.Radius and data.Delay then
        showTelegraph(data.Position, data.Radius, data.Delay)
    end
end)

-- ────────────────────────────────────────────────
-- COMBO METER
-- ────────────────────────────────────────────────

local COMBO_TIMEOUT = 2.5   -- seconds of inactivity before reset

local comboCount = 0
local comboTimer = 0

-- Rank thresholds
local RANKS = {
    { min = 40, label = "GODLIKE!!!",  color = Color3.fromRGB(255, 210,   0) },
    { min = 25, label = "INSANE!!",    color = Color3.fromRGB(220,  80, 255) },
    { min = 15, label = "Excellent!",  color = Color3.fromRGB( 80, 180, 255) },
    { min =  8, label = "Great!",      color = Color3.fromRGB(100, 220,  80) },
    { min =  3, label = "Good",        color = Color3.fromRGB(200, 220,  80) },
}

local function getRank(count)
    for _, r in ipairs(RANKS) do
        if count >= r.min then return r end
    end
    return nil
end

-- GUI widgets — built once after HUD is ready
local hudGui     = player.PlayerGui:WaitForChild("HUD", 15)
local comboFrame, comboHitLbl, comboRankLbl

if hudGui then
    comboFrame = Instance.new("Frame")
    comboFrame.Name                = "ComboMeter"
    comboFrame.Size                = UDim2.new(0, 158, 0, 54)
    comboFrame.Position            = UDim2.new(1, -174, 0.5, -104)
    comboFrame.BackgroundColor3    = Color3.fromRGB(14, 11, 8)
    comboFrame.BackgroundTransparency = 0.25
    comboFrame.BorderSizePixel     = 0
    comboFrame.Visible             = false
    comboFrame.ZIndex              = 10
    comboFrame.Parent              = hudGui
    Instance.new("UICorner", comboFrame).CornerRadius = UDim.new(0, 10)
    local cs = Instance.new("UIStroke", comboFrame)
    cs.Color     = Color3.fromRGB(180, 83, 6)
    cs.Thickness = 1.5

    comboHitLbl = Instance.new("TextLabel")
    comboHitLbl.Name                 = "HitLabel"
    comboHitLbl.Size                 = UDim2.new(1, -8, 0.54, 0)
    comboHitLbl.Position             = UDim2.new(0, 4, 0.04, 0)
    comboHitLbl.BackgroundTransparency = 1
    comboHitLbl.Text                 = ""
    comboHitLbl.TextColor3           = Color3.fromRGB(251, 191, 36)
    comboHitLbl.TextScaled           = true
    comboHitLbl.Font                 = Enum.Font.GothamBold
    comboHitLbl.ZIndex               = 11
    comboHitLbl.Parent               = comboFrame

    comboRankLbl = Instance.new("TextLabel")
    comboRankLbl.Name                 = "RankLabel"
    comboRankLbl.Size                 = UDim2.new(1, -8, 0.38, 0)
    comboRankLbl.Position             = UDim2.new(0, 4, 0.58, 0)
    comboRankLbl.BackgroundTransparency = 1
    comboRankLbl.Text                 = ""
    comboRankLbl.TextScaled           = true
    comboRankLbl.Font                 = Enum.Font.Gotham
    comboRankLbl.ZIndex               = 11
    comboRankLbl.Parent               = comboFrame
end

local function refreshCombo()
    if not comboFrame then return end
    if comboCount < 2 then
        comboFrame.Visible = false
        return
    end
    comboFrame.Visible = true
    if comboHitLbl  then comboHitLbl.Text  = comboCount .. " HITS" end
    local rank = getRank(comboCount)
    if comboRankLbl then
        comboRankLbl.Text      = rank and rank.label or ""
        comboRankLbl.TextColor3 = rank and rank.color or Color3.fromRGB(200, 180, 100)
    end
    -- Quick pop-scale illusion: briefly widen the frame then snap back
    TweenService:Create(comboFrame,
        TweenInfo.new(0.07, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 168, 0, 58) }
    ):Play()
    task.delay(0.1, function()
        if comboFrame then
            TweenService:Create(comboFrame,
                TweenInfo.new(0.1),
                { Size = UDim2.new(0, 158, 0, 54) }
            ):Play()
        end
    end)
end

local function resetCombo()
    comboCount = 0
    comboTimer = 0
    if comboFrame then
        TweenService:Create(comboFrame,
            TweenInfo.new(0.3),
            { BackgroundTransparency = 1 }
        ):Play()
        task.delay(0.3, function()
            if comboFrame then
                comboFrame.Visible = false
                comboFrame.BackgroundTransparency = 0.25
            end
        end)
    end
end

RunService.Heartbeat:Connect(function(dt)
    if comboCount > 0 then
        comboTimer = comboTimer + dt
        if comboTimer >= COMBO_TIMEOUT then
            resetCombo()
        end
    end
end)

-- ────────────────────────────────────────────────
-- PLAYER DAMAGE VIGNETTE
-- ────────────────────────────────────────────────

local vigFrame

if hudGui then
    vigFrame = Instance.new("Frame")
    vigFrame.Name                  = "DamageVignette"
    vigFrame.Size                  = UDim2.new(1, 0, 1, 0)
    vigFrame.BackgroundColor3      = Color3.fromRGB(180, 0, 0)
    vigFrame.BackgroundTransparency = 1
    vigFrame.BorderSizePixel       = 0
    vigFrame.ZIndex                = 18
    vigFrame.Parent                = hudGui

    -- Gradient: transparent centre → opaque edges (fake radial vignette)
    local g = Instance.new("UIGradient", vigFrame)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(180,0,0)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(180,0,0)),
    })
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,    1),
        NumberSequenceKeypoint.new(0.5,  0.55),
        NumberSequenceKeypoint.new(1,    0.3),
    })
end

local function playerHitEffect(damageAmount)
    if not vigFrame then return end
    local intensity = math.clamp(damageAmount / 120, 0.06, 0.7)
    vigFrame.BackgroundTransparency = 1 - intensity
    TweenService:Create(vigFrame,
        TweenInfo.new(0.7, Enum.EasingStyle.Quad),
        { BackgroundTransparency = 1 }
    ):Play()
    shake(intensity * 0.55)
end

UpdateHUD.OnClientEvent:Connect(function(data)
    if data.DamageTaken and data.DamageTaken > 0 then
        playerHitEffect(data.DamageTaken)
    end
end)

-- ────────────────────────────────────────────────
-- TakeDamage  (enemy hit by player)
-- ────────────────────────────────────────────────

TakeDamage.OnClientEvent:Connect(function(data)
    if not data.TargetId or not data.Damage then return end

    -- Resolve position
    local hitPos = data.Position
    if not hitPos then
        local model = enemyById[data.TargetId]
        if model then
            local root = model.PrimaryPart
                or model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChildWhichIsA("BasePart")
            hitPos = root and root.Position
        end
    end
    if not hitPos then return end

    local dmgType = data.DamageType or "Physical"
    local color   = DamageColors[dmgType] or DamageColors.Default

    -- Damage number
    spawnNumber(hitPos, data.Damage, data.IsCrit, dmgType)

    -- Hit flash on enemy model
    local model = enemyById[data.TargetId]
    if model then hitFlash(model) end

    -- Impact sparks (more on crit)
    spawnSparks(hitPos, color, data.IsCrit and 10 or 6)

    -- Screen shake
    shake(data.IsCrit and 0.28 or 0.11)

    -- Combo
    comboCount = comboCount + 1
    comboTimer = 0
    refreshCombo()
end)

-- ────────────────────────────────────────────────
-- BOSS PHASE TRANSITION VFX
-- ────────────────────────────────────────────────

local BossPhaseEvtVFX = RemoteEvents:WaitForChild("BossPhase", 15)

local function showPhaseTransitionVFX(phase)
    -- Full-screen red flash
    if vigFrame then
        vigFrame.BackgroundColor3 = Color3.fromRGB(160, 0, 0)
        vigFrame.BackgroundTransparency = 0
        TweenService:Create(vigFrame,
            TweenInfo.new(1.5, Enum.EasingStyle.Quad),
            { BackgroundTransparency = 1 }
        ):Play()
        task.delay(1.5, function()
            vigFrame.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
        end)
    end

    -- Sparks ring at camera center (world-space approximation)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local burstColor = phase == 1 and Color3.fromRGB(255, 60, 60)
            or phase == 2 and Color3.fromRGB(255, 120, 20)
            or Color3.fromRGB(255, 220, 50)
        spawnSparks(root.Position + Vector3.new(0, 3, 0), burstColor, 22)
    end

    -- Heavy screen shake
    shake(0.85)
    task.delay(0.1, function() shake(0.5) end)
    task.delay(0.25, function() shake(0.3) end)
end

if BossPhaseEvtVFX then
    BossPhaseEvtVFX.OnClientEvent:Connect(function(data)
        showPhaseTransitionVFX(data.Phase)
    end)
end

-- ────────────────────────────────────────────────
-- AWAKENING AURA VFX
-- ────────────────────────────────────────────────

local AwakeningStateVFX = RemoteEvents:WaitForChild("AwakeningState", 15)

-- Per-player aura parts table (cleaned up on deactivate)
local activeAuras = {}   -- [userId] = { list of Instances to destroy }

local function spawnAwakeningAura(targetPlayer, auraColor, duration)
    local char = targetPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local uid = targetPlayer.UserId
    -- Clean up any stale aura
    if activeAuras[uid] then
        for _, obj in ipairs(activeAuras[uid]) do
            pcall(function() obj:Destroy() end)
        end
        activeAuras[uid] = nil
    end

    local parts = {}

    -- 1. SelectionBox outline glow around entire character
    local selBox = Instance.new("SelectionBox")
    selBox.Color3              = auraColor
    selBox.LineThickness       = 0.08
    selBox.SurfaceTransparency = 0.85
    selBox.SurfaceColor3       = auraColor
    selBox.Adornee             = char
    selBox.Parent              = workspace
    table.insert(parts, selBox)

    -- 2. PointLight for warm ambient glow
    local pt = Instance.new("PointLight")
    pt.Color      = auraColor
    pt.Brightness = 6
    pt.Range      = 24
    pt.Parent     = root
    table.insert(parts, pt)

    -- 3. Rising wisp particle emitter
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, auraColor),
        ColorSequenceKeypoint.new(0.6, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, auraColor),
    })
    emitter.LightEmission  = 0.9
    emitter.LightInfluence = 0.1
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(0.5, 0.3),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.8, 0.6),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Rate        = 35
    emitter.Lifetime    = NumberRange.new(0.8, 1.6)
    emitter.Speed       = NumberRange.new(6, 14)
    emitter.SpreadAngle = Vector2.new(25, 25)
    emitter.RotSpeed    = NumberRange.new(-90, 90)
    emitter.Rotation    = NumberRange.new(0, 360)
    emitter.Parent      = root
    table.insert(parts, emitter)

    -- 4. Burst sparks on activation + heavy shake
    spawnSparks(root.Position + Vector3.new(0, 2, 0), auraColor, 30)
    shake(0.7)
    task.delay(0.15, function() shake(0.45) end)

    activeAuras[uid] = parts

    -- Auto-cleanup after duration in case Active=false event is missed
    task.delay(duration + 0.5, function()
        if activeAuras[uid] == parts then
            for _, obj in ipairs(parts) do
                pcall(function() obj:Destroy() end)
            end
            activeAuras[uid] = nil
        end
    end)
end

local function removeAwakeningAura(userId)
    local parts = activeAuras[userId]
    if not parts then return end
    -- Fade out particles first, then destroy after 1s
    for _, obj in ipairs(parts) do
        if obj:IsA("ParticleEmitter") then obj.Enabled = false end
    end
    task.delay(1.0, function()
        if activeAuras[userId] == parts then
            for _, obj in ipairs(parts) do
                pcall(function() obj:Destroy() end)
            end
            activeAuras[userId] = nil
        end
    end)
end

if AwakeningStateVFX then
    AwakeningStateVFX.OnClientEvent:Connect(function(data)
        -- Resolve the target player from their UserId
        local targetPlayer = nil
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p.UserId == data.PlayerUserId then
                targetPlayer = p; break
            end
        end
        if not targetPlayer then return end

        if data.Active then
            local aColor = data.AuraColor
                and Color3.new(data.AuraColor.R, data.AuraColor.G, data.AuraColor.B)
                or Color3.fromRGB(255, 160, 30)
            spawnAwakeningAura(targetPlayer, aColor, data.Duration or 12)
        else
            removeAwakeningAura(data.PlayerUserId)
        end
    end)
end

-- ────────────────────────────────────────────────
-- STATUS EFFECT VISUALS
-- ────────────────────────────────────────────────
-- Server fires StatusApplied { TargetId, StatusType, Duration } when a debuff lands.
-- We attach persistent particle/part effects to the enemy model for the debuff's duration.

local StatusAppliedEvt = RemoteEvents:WaitForChild("StatusApplied", 15)

-- Active status effect cleanup handles: [enemyId][statusType] = cancelFn
local activeStatusFX = {}

local STATUS_CFG = {
    Burn    = { color = Color3.fromRGB(255, 90,  20), style = "smoke",   rate = 18 },
    Poison  = { color = Color3.fromRGB(80,  220, 30), style = "drip",    rate = 14 },
    Freeze  = { color = Color3.fromRGB(160, 230, 255),style = "crystal", rate = 0  },
    Stun    = { color = Color3.fromRGB(255, 240, 60), style = "stars",   rate = 22 },
    Slow    = { color = Color3.fromRGB(150, 150, 200),style = "wisp",    rate = 10 },
    DeathMark = { color = Color3.fromRGB(180, 10, 10), style = "smoke",  rate = 8  },
}

local function cancelStatusFX(enemyId, statusType)
    if not activeStatusFX[enemyId] then return end
    local cancel = activeStatusFX[enemyId][statusType]
    if cancel then cancel() end
    activeStatusFX[enemyId][statusType] = nil
end

local function applyStatusFX(model, statusType, duration, cfg)
    local root = model and (model.PrimaryPart
        or model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChildWhichIsA("BasePart"))
    if not root then return end

    local alive = true
    local parts  = {}

    local function cleanup()
        alive = false
        for _, p in ipairs(parts) do
            pcall(function()
                TweenService:Create(p, TweenInfo.new(0.3), { Transparency = 1 }):Play()
                Debris:AddItem(p, 0.35)
            end)
        end
    end

    if cfg.style == "crystal" then
        -- Freeze: place 5 blue crystal spikes around the model's feet
        for i = 1, 5 do
            local angle = (i / 5) * math.pi * 2
            local cx = root.Position.X + math.cos(angle) * 1.8
            local cz = root.Position.Z + math.sin(angle) * 1.8
            local spike = Instance.new("Part")
            spike.Size        = Vector3.new(0.5, 0, 0.5)
            spike.Color       = cfg.color
            spike.Material    = Enum.Material.Neon
            spike.Transparency = 0.2
            spike.Anchored    = true
            spike.CanCollide  = false
            spike.CFrame      = CFrame.new(cx, root.Position.Y - root.Size.Y * 0.4, cz)
                * CFrame.Angles(math.random() * 0.3, math.random() * math.pi * 2, 0)
            spike.Parent      = workspace
            table.insert(parts, spike)
            TweenService:Create(spike, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = Vector3.new(0.5, math.random(2, 4) + 0.5, 0.5),
            }):Play()
            Debris:AddItem(spike, duration + 0.4)
        end
        -- PointLight tint
        local iceLight = Instance.new("PointLight")
        iceLight.Color      = cfg.color
        iceLight.Brightness = 3
        iceLight.Range      = 14
        iceLight.Parent     = root
        table.insert(parts, iceLight)
        Debris:AddItem(iceLight, duration)

    elseif cfg.style == "stars" then
        -- Stun: ring of yellow stars orbiting the head
        local headPos = root.Position + Vector3.new(0, root.Size.Y * 0.5 + 2.5, 0)
        local startTime = os.clock()
        local starParts = {}
        for i = 1, 4 do
            local star = Instance.new("Part")
            star.Shape       = Enum.PartType.Ball
            star.Size        = Vector3.new(0.5, 0.5, 0.5)
            star.Color       = cfg.color
            star.Material    = Enum.Material.Neon
            star.Anchored    = true
            star.CanCollide  = false
            star.Parent      = workspace
            table.insert(starParts, star)
            table.insert(parts, star)
            Debris:AddItem(star, duration + 0.35)
        end
        local conn = RunService.Heartbeat:Connect(function()
            if not alive then return end
            local t = os.clock() - startTime
            local basePos = root and root.Parent and root.Position
                or headPos
            for i, star in ipairs(starParts) do
                if star.Parent then
                    local a = (i / #starParts) * math.pi * 2 + t * 3.5
                    star.Position = (basePos + Vector3.new(0, root.Size.Y * 0.5 + 2.5, 0))
                        + Vector3.new(math.cos(a) * 2.2, math.sin(t * 4 + i) * 0.4, math.sin(a) * 2.2)
                end
            end
        end)
        table.insert(parts, { Destroy = function() conn:Disconnect() end, Parent = nil })

    else
        -- Particle emitter for smoke/drip/wisp styles
        local emitter = Instance.new("ParticleEmitter")
        emitter.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   cfg.color),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1,   cfg.color),
        })
        emitter.LightEmission  = 0.7
        emitter.LightInfluence = 0.3
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(0.5, 0.25),
            NumberSequenceKeypoint.new(1, 0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(0.8, 0.65),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Rate        = cfg.rate
        emitter.Lifetime    = NumberRange.new(0.5, 1.2)
        emitter.Speed       = NumberRange.new(2, 5)
        emitter.SpreadAngle = Vector2.new(30, 30)
        emitter.Parent      = root
        table.insert(parts, emitter)

        task.delay(duration, function()
            if emitter.Parent then
                emitter.Enabled = false
                Debris:AddItem(emitter, 1.5)
            end
        end)
    end

    task.delay(duration + 0.05, cleanup)
    return cleanup
end

if StatusAppliedEvt then
    StatusAppliedEvt.OnClientEvent:Connect(function(data)
        if not data.TargetId or not data.StatusType then return end
        local cfg = STATUS_CFG[data.StatusType]
        if not cfg then return end

        local model = enemyById[data.TargetId]
        if not model then return end

        local eid = data.TargetId
        if not activeStatusFX[eid] then activeStatusFX[eid] = {} end

        -- Cancel existing FX of same type first
        cancelStatusFX(eid, data.StatusType)

        local cancelFn = applyStatusFX(model, data.StatusType, data.Duration or 3, cfg)
        if cancelFn then
            activeStatusFX[eid][data.StatusType] = cancelFn
        end
    end)
end

-- Clean up status FX when an enemy dies
workspace.DescendantRemoving:Connect(function(obj)
    if obj:IsA("Model") and obj:GetAttribute("IsEnemy") then
        local id = obj:GetAttribute("EnemyId")
        if id and activeStatusFX[id] then
            for _, cancel in pairs(activeStatusFX[id]) do
                pcall(cancel)
            end
            activeStatusFX[id] = nil
        end
    end
end)

-- ────────────────────────────────────────────────
-- COSMETIC TITLE DISPLAY (CosmeticSync)
-- ────────────────────────────────────────────────
-- When any player equips a title, render it as a BillboardGui above their head.

local CosmeticSyncEvt = RemoteEvents:WaitForChild("CosmeticSync", 15)
local CosmeticsData   = require(ReplicatedStorage.Modules.CosmeticsData)

local titleBoards = {}  -- [userId] = BillboardGui

local function updateTitleBoard(targetPlayer, titleKey)
    local char = targetPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local uid = targetPlayer.UserId

    -- Remove old
    if titleBoards[uid] and titleBoards[uid].Parent then
        titleBoards[uid]:Destroy()
    end

    if not titleKey or titleKey == "" then return end
    local titleData = CosmeticsData.Titles[titleKey]
    if not titleData then return end

    local bg = Instance.new("BillboardGui")
    bg.Size         = UDim2.new(0, 200, 0, 32)
    bg.StudsOffset  = Vector3.new(0, 3.2, 0)
    bg.MaxDistance  = 60
    bg.AlwaysOnTop  = false
    bg.Adornee      = head
    bg.Parent       = char

    local fr = Instance.new("Frame")
    fr.Size                  = UDim2.new(1, 0, 1, 0)
    fr.BackgroundColor3      = Color3.fromRGB(5, 5, 12)
    fr.BackgroundTransparency = 0.3
    fr.BorderSizePixel       = 0
    fr.Parent                = bg
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", fr)
    stroke.Color     = titleData.Color
    stroke.Thickness = 1.2

    local lbl = Instance.new("TextLabel")
    lbl.Size                  = UDim2.new(1, -4, 1, 0)
    lbl.Position              = UDim2.new(0, 2, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = titleData.DisplayName
    lbl.TextColor3            = titleData.Color
    lbl.TextScaled            = true
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0.45
    lbl.Parent                = fr

    titleBoards[uid] = bg
end

if CosmeticSyncEvt then
    CosmeticSyncEvt.OnClientEvent:Connect(function(data)
        if data.Error then return end
        -- Find the player
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if p.UserId == data.UserId then
                if data.Title then
                    updateTitleBoard(p, data.Title)
                end
                break
            end
        end
    end)
end

print("[CombatVFX] Loaded.")
