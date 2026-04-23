-- EnemyAvatars.lua
-- Procedural R6-style humanoid avatars for every enemy type.
-- EnemyAI.SpawnEnemy calls EnemyAvatars.Build(enemyName, model, origin, sizeHint)
-- after creating the bare Model.  This module populates the model with all
-- visible parts and welds them to the HumanoidRootPart so movement works.

local EnemyAvatars = {}

-- ─── helpers ─────────────────────────────────────────────────────────────────

local function P(parent, name, size, cf, color, mat, trans)
    local p = Instance.new("Part")
    p.Name          = name
    p.Size          = size
    p.CFrame        = cf
    p.Color         = color or Color3.new(0.8, 0.8, 0.8)
    p.Material      = mat   or Enum.Material.SmoothPlastic
    p.Transparency  = trans or 0
    p.Anchored      = false  -- welded to HRP; HRP itself is anchored
    p.CanCollide    = false
    p.CastShadow    = false
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent        = parent
    return p
end

local function W(parent, a, b)   -- WeldConstraint a ← b
    local w = Instance.new("WeldConstraint", parent)
    w.Part0 = a; w.Part1 = b
    return w
end

local function sphere(p)
    local m = Instance.new("SpecialMesh", p)
    m.MeshType = Enum.MeshType.Sphere
    return m
end

local function wedge(parent, name, size, cf, color, mat)
    local p = Instance.new("WedgePart")
    p.Name = name; p.Size = size; p.CFrame = cf
    p.Color = color or Color3.new(0.8,0.8,0.8)
    p.Material = mat or Enum.Material.SmoothPlastic
    p.Anchored = false; p.CanCollide = false; p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function glow(p, color, bright, range)
    local l = Instance.new("PointLight", p)
    l.Color = color; l.Brightness = bright or 2; l.Range = range or 15
    return l
end

-- ─── R6 base rig ─────────────────────────────────────────────────────────────
-- origin: world-space center of the model (waist/HRP height)
-- S: scale factor (1 = standard R6 character, ~5 studs tall)
-- bodyC: skin/limb color    clothC: torso+leg color    mat: material

local function buildR6(model, origin, S, bodyC, clothC, mat)
    clothC = clothC or bodyC
    mat    = mat or Enum.Material.SmoothPlastic

    -- HumanoidRootPart (anchored, invisible – all others weld to this)
    local hrp = Instance.new("Part")
    hrp.Name          = "HumanoidRootPart"
    hrp.Size          = Vector3.new(2*S, 2*S, S)
    hrp.CFrame        = CFrame.new(origin)
    hrp.Transparency  = 1
    hrp.Anchored      = true
    hrp.CanCollide    = false
    hrp.CastShadow    = false
    hrp.Material      = Enum.Material.SmoothPlastic
    hrp.Parent        = model
    model.PrimaryPart = hrp

    -- Torso
    local torso = P(model,"Torso",  Vector3.new(2*S,2*S,S),
        CFrame.new(origin + Vector3.new(0,S,0)),   clothC, mat)
    -- Head
    local head  = P(model,"Head",   Vector3.new(2*S,S,S),
        CFrame.new(origin + Vector3.new(0,2.6*S,0)), bodyC, mat)
    sphere(head)
    -- Arms
    local la = P(model,"Left Arm",  Vector3.new(S,2*S,S),
        CFrame.new(origin + Vector3.new(-1.5*S,S,0)), bodyC, mat)
    local ra = P(model,"Right Arm", Vector3.new(S,2*S,S),
        CFrame.new(origin + Vector3.new( 1.5*S,S,0)), bodyC, mat)
    -- Legs
    local ll = P(model,"Left Leg",  Vector3.new(S,2*S,S),
        CFrame.new(origin + Vector3.new(-0.5*S,-S,0)), clothC, mat)
    local rl = P(model,"Right Leg", Vector3.new(S,2*S,S),
        CFrame.new(origin + Vector3.new( 0.5*S,-S,0)), clothC, mat)

    -- Weld everything to HRP
    for _, p in ipairs({torso, head, la, ra, ll, rl}) do W(model, hrp, p) end

    return hrp, { Torso=torso, Head=head, LA=la, RA=ra, LL=ll, RL=rl }
end

-- ─── shared accessories ──────────────────────────────────────────────────────

local function addHorns(model, hrp, origin, S, color, count)
    count = count or 2
    local hornH  = 0.9*S; local hornW = 0.35*S
    local positions = (count == 1)
        and {{ 0, 0 }}
        or {{ -0.6*S, 0.1*S }, { 0.6*S, 0.1*S }}

    for _, pos in ipairs(positions) do
        local h = P(model,"Horn", Vector3.new(hornW, hornH, hornW),
            CFrame.new(origin + Vector3.new(pos[1], 3.2*S + hornH/2, pos[2])),
            color, Enum.Material.SmoothPlastic)
        local m = Instance.new("SpecialMesh", h)
        m.MeshType = Enum.MeshType.FileMesh
        m.MeshId   = "rbxasset://fonts/rightarm.mesh"
        m.Scale    = Vector3.new(0.8*S, 0.8*S, 0.8*S)
        W(model, hrp, h)
    end
end

local function addCape(model, hrp, origin, S, color, mat)
    local cape = P(model,"Cape",
        Vector3.new(1.8*S, 3.5*S, 0.18*S),
        CFrame.new(origin + Vector3.new(0, 0.2*S, -0.6*S)),
        color, mat or Enum.Material.Fabric)
    W(model, hrp, cape)
    return cape
end

local function addShield(model, hrp, origin, S, color)
    local sh = P(model,"Shield",
        Vector3.new(1.6*S, 2.2*S, 0.22*S),
        CFrame.new(origin + Vector3.new(-2.4*S, S, 0.3*S)),
        color, Enum.Material.Metal)
    local rim = P(model,"ShieldRim",
        Vector3.new(1.7*S, 2.3*S, 0.1*S),
        CFrame.new(origin + Vector3.new(-2.4*S, S, 0.44*S)),
        Color3.fromRGB(200,200,220), Enum.Material.Metal)
    W(model,hrp,sh); W(model,hrp,rim)
end

local function addSword(model, hrp, origin, S, color)
    local blade = P(model,"Sword",
        Vector3.new(0.2*S, 3*S, 0.08*S),
        CFrame.new(origin + Vector3.new(2.2*S, -0.5*S, 0)),
        color or Color3.fromRGB(210,220,230), Enum.Material.Metal)
    local guard = P(model,"SwordGuard",
        Vector3.new(0.9*S, 0.2*S, 0.2*S),
        CFrame.new(origin + Vector3.new(2.2*S, 0.5*S, 0)),
        Color3.fromRGB(180,160,100), Enum.Material.Metal)
    W(model,hrp,blade); W(model,hrp,guard)
end

local function addStaff(model, hrp, origin, S, shaftColor, orbColor)
    local shaft = P(model,"Staff",
        Vector3.new(0.25*S, 4.5*S, 0.25*S),
        CFrame.new(origin + Vector3.new(2.2*S, 0.5*S, 0)),
        shaftColor or Color3.fromRGB(100,70,40), Enum.Material.Wood)
    local orb = P(model,"Orb",
        Vector3.new(0.8*S, 0.8*S, 0.8*S),
        CFrame.new(origin + Vector3.new(2.2*S, 3.2*S, 0)),
        orbColor or Color3.fromRGB(200,80,255), Enum.Material.Neon)
    sphere(orb); glow(orb, orbColor or Color3.fromRGB(180,60,255), 2, 12*S)
    W(model,hrp,shaft); W(model,hrp,orb)
end

local function addScythe(model, hrp, origin, S, color)
    local handle = P(model,"ScytheHandle",
        Vector3.new(0.25*S, 5*S, 0.25*S),
        CFrame.new(origin + Vector3.new(2.2*S, 0.8*S, 0)),
        Color3.fromRGB(30,20,20), Enum.Material.Wood)
    local blade = wedge(model,"ScytheBlade",
        Vector3.new(0.15*S, 2.2*S, 0.9*S),
        CFrame.new(origin + Vector3.new(2.8*S, 3.4*S, 0))
            * CFrame.Angles(0, 0, math.rad(-35)),
        color or Color3.fromRGB(190,210,230), Enum.Material.Metal)
    W(model,hrp,handle); W(model,hrp,blade)
end

local function addArmor(model, hrp, origin, S, color)
    local mat = Enum.Material.Metal
    local cp = P(model,"ChestPlate",
        Vector3.new(2.1*S, 1.9*S, 0.35*S),
        CFrame.new(origin + Vector3.new(0, S, 0.42*S)),
        color, mat)
    local lsp = P(model,"LShoulder",
        Vector3.new(1.1*S, 0.8*S, 1.1*S),
        CFrame.new(origin + Vector3.new(-1.5*S, 1.8*S, 0)),
        color, mat)
    local rsp = P(model,"RShoulder",
        Vector3.new(1.1*S, 0.8*S, 1.1*S),
        CFrame.new(origin + Vector3.new( 1.5*S, 1.8*S, 0)),
        color, mat)
    for _, p in ipairs({cp,lsp,rsp}) do W(model,hrp,p) end
end

local function addGlowEyes(model, hrp, origin, S, color)
    for _, x in ipairs({-0.5*S, 0.5*S}) do
        local eye = P(model,"Eye",
            Vector3.new(0.32*S, 0.32*S, 0.15*S),
            CFrame.new(origin + Vector3.new(x, 2.7*S, 0.55*S)),
            color, Enum.Material.Neon)
        sphere(eye); glow(eye, color, 1.5, 8*S)
        W(model, hrp, eye)
    end
end

-- Human-style iris eyes (white sclera + colored iris, no glow)
local function addEyes(model, hrp, origin, S, irisColor)
    for _, x in ipairs({-0.5*S, 0.5*S}) do
        local scl = P(model,"Sclera",
            Vector3.new(0.35*S, 0.35*S, 0.12*S),
            CFrame.new(origin + Vector3.new(x, 2.7*S, 0.53*S)),
            Color3.fromRGB(240,240,240))
        sphere(scl); W(model,hrp,scl)
        local iris = P(model,"Iris",
            Vector3.new(0.22*S, 0.22*S, 0.13*S),
            CFrame.new(origin + Vector3.new(x, 2.7*S, 0.58*S)),
            irisColor or Color3.fromRGB(50,50,120))
        sphere(iris); W(model,hrp,iris)
    end
end

-- Anime-style hair: "short" (flat cap), "spiky" (5 upward spikes), "long" (back drape)
local function addHair(model, hrp, origin, S, color, style)
    if style == "spiky" then
        for i = 1, 5 do
            local sp = P(model,"Hair",
                Vector3.new(0.22*S, 0.75*S, 0.22*S),
                CFrame.new(origin + Vector3.new((-1+i*0.5)*S, 3.52*S, -0.08*S))
                    * CFrame.Angles(0, 0, (-2+i)*math.rad(12)),
                color)
            W(model,hrp,sp)
        end
    elseif style == "long" then
        local back = P(model,"Hair",
            Vector3.new(1.8*S, 2.4*S, 0.28*S),
            CFrame.new(origin + Vector3.new(0, 2.2*S, -0.72*S)),
            color, Enum.Material.Fabric)
        local top  = P(model,"HairTop",
            Vector3.new(2.06*S, 0.55*S, 1.95*S),
            CFrame.new(origin + Vector3.new(0, 3.35*S, -0.1*S)), color)
        W(model,hrp,back); W(model,hrp,top)
    else -- "short"
        local top = P(model,"Hair",
            Vector3.new(2.06*S, 0.55*S, 1.95*S),
            CFrame.new(origin + Vector3.new(0, 3.35*S, -0.1*S)), color)
        W(model,hrp,top)
    end
end

-- ─── per-enemy builders ──────────────────────────────────────────────────────

local B = {}

function B.Demon_Grunt(model, origin, S)
    -- Reddish-skinned demon humanoid in ragged dark armor
    local skin = Color3.fromRGB(200, 100, 80)
    local cloth= Color3.fromRGB(55, 20, 20)
    local hrp, _ = buildR6(model, origin, S, skin, cloth)
    for _, side in ipairs({-1, 1}) do
        local h = P(model,"Horn",
            Vector3.new(0.3*S, 0.7*S, 0.3*S),
            CFrame.new(origin + Vector3.new(side*0.6*S, 3.1*S, 0))
                * CFrame.Angles(0,0, side*math.rad(30)),
            Color3.fromRGB(120,40,40))
        sphere(h); W(model,hrp,h)
    end
    addHair(model, hrp, origin, S, Color3.fromRGB(25,8,8), "short")
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(255,180,0))
end

function B.Demon_Berserker(model, origin, S)
    -- Muscular reddish demon with dark pants and jagged shoulder spikes
    local skin = Color3.fromRGB(210, 120, 80)
    local cloth= Color3.fromRGB(70, 25, 15)
    local hrp, rig = buildR6(model, origin, S, skin, cloth)
    for _, side in ipairs({-1, 1}) do
        for i = 0, 2 do
            local sp = P(model,"Spike",
                Vector3.new(0.28*S, 0.9*S*(.9-i*.15), 0.28*S),
                CFrame.new(origin + Vector3.new(side*1.9*S, 1.7*S - i*0.4*S, 0)),
                Color3.fromRGB(80,25,15))
            sphere(sp); W(model,hrp,sp)
        end
    end
    addHair(model, hrp, origin, S, Color3.fromRGB(20,8,8), "short")
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(255,80,0))
    rig.LA.Size = Vector3.new(1.3*S, 2.2*S, 1.1*S)
    rig.RA.Size = Vector3.new(1.3*S, 2.2*S, 1.1*S)
end

function B.Demon_Mage(model, origin, S)
    -- Pale lavender-skinned robed mage with single horn and staff
    local skin = Color3.fromRGB(200, 170, 210)
    local robe = Color3.fromRGB(60, 10, 90)
    local hrp, _ = buildR6(model, origin, S, skin, robe, Enum.Material.Fabric)
    addHorns(model, hrp, origin, S, Color3.fromRGB(80,20,100), 1)
    addStaff(model, hrp, origin, S,
        Color3.fromRGB(80,50,100), Color3.fromRGB(200,80,255))
    -- Hood over head
    local hood = P(model,"Hood",
        Vector3.new(2.2*S, 1.1*S, 2.2*S),
        CFrame.new(origin + Vector3.new(0, 3.1*S, -0.2*S)),
        robe, Enum.Material.Fabric)
    sphere(hood); W(model,hrp,hood)
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(180,60,255))
end

function B.Shadow_Clone(model, origin, S)
    -- Supernatural semi-transparent shadow being — intentionally non-human
    local dark = Color3.fromRGB(20,20,80)
    local hrp, rig = buildR6(model, origin, S, dark, dark, Enum.Material.Neon)
    for _, p in ipairs({rig.Torso, rig.Head, rig.LA, rig.RA, rig.LL, rig.RL}) do
        p.Transparency = 0.45
        p.Color        = Color3.fromRGB(30,30,120)
        p.Material     = Enum.Material.Neon
    end
    glow(rig.Torso, Color3.fromRGB(60,60,200), 1.5, 12*S)
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(100,100,255))
end

function B.Rogue_Ninja(model, origin, S)
    -- Human shinobi with warm skin, dark navy outfit, and face mask
    local skin = Color3.fromRGB(230, 185, 150)
    local cloth= Color3.fromRGB(28, 28, 48)
    local hrp, _ = buildR6(model, origin, S, skin, cloth)
    local mask = P(model,"Mask",
        Vector3.new(2.05*S, 0.5*S, 0.65*S),
        CFrame.new(origin + Vector3.new(0, 2.5*S, 0.35*S)),
        Color3.fromRGB(55,55,75), Enum.Material.SmoothPlastic)
    W(model,hrp,mask)
    addHair(model, hrp, origin, S, Color3.fromRGB(18,14,28), "short")
    local kunai = P(model,"Kunai",
        Vector3.new(0.15*S, 1.4*S, 0.15*S),
        CFrame.new(origin + Vector3.new(2.1*S, 0.2*S, -0.3*S))
            * CFrame.Angles(0,0,math.rad(15)),
        Color3.fromRGB(200,210,220), Enum.Material.Metal)
    W(model,hrp,kunai)
    -- Ice-blue eyes visible above mask
    addEyes(model, hrp, origin, S, Color3.fromRGB(70,130,200))
end

function B.Puppet_Master(model, origin, S)
    -- Pale eccentric puppeteer in worn earthy robes and wide-brimmed hat
    local skin  = Color3.fromRGB(228, 198, 168)
    local robe  = Color3.fromRGB(80, 50, 30)
    local hrp, _ = buildR6(model, origin, S, skin, robe, Enum.Material.Fabric)
    for _, x in ipairs({-2*S, 2*S}) do
        for i = 1, 3 do
            local str = P(model,"String",
                Vector3.new(0.06*S, 1.5*S, 0.06*S),
                CFrame.new(origin + Vector3.new(x + (i-2)*0.3*S, -2.5*S, 0.2*S)),
                Color3.fromRGB(220,200,160))
            W(model,hrp,str)
        end
    end
    -- Golden amber eyes
    addEyes(model, hrp, origin, S, Color3.fromRGB(195,155,40))
    local brim = P(model,"HatBrim",
        Vector3.new(3.2*S, 0.2*S, 3.2*S),
        CFrame.new(origin + Vector3.new(0, 3.3*S, 0)),
        robe, Enum.Material.Fabric)
    local crown = P(model,"HatCrown",
        Vector3.new(1.5*S, 0.9*S, 1.5*S),
        CFrame.new(origin + Vector3.new(0, 3.75*S, 0)),
        robe, Enum.Material.Fabric)
    W(model,hrp,brim); W(model,hrp,crown)
end

function B.SeaGuardian(model, origin, S)
    -- Fishman: teal-blue creature skin, intentionally non-human
    local teal  = Color3.fromRGB(30,120,160)
    local dark  = Color3.fromRGB(20,70,110)
    local hrp, rig = buildR6(model, origin, S, teal, dark)
    local fin = wedge(model,"DorsalFin",
        Vector3.new(0.35*S, 2.5*S, 1.5*S),
        CFrame.new(origin + Vector3.new(0, 1.2*S, -0.8*S)),
        Color3.fromRGB(20,180,200), Enum.Material.SmoothPlastic)
    W(model,hrp,fin)
    addShield(model, hrp, origin, S, Color3.fromRGB(40,100,160))
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(100,255,230))
    rig.Torso.Size = Vector3.new(2.4*S, 2.2*S, S*1.1)
end

function B.DevilFruit_User(model, origin, S)
    -- Human fighter/pirate with tan skin, blue outfit, glowing devil fruit aura
    local skin = Color3.fromRGB(240, 185, 145)
    local cloth= Color3.fromRGB(30, 90, 170)
    local hrp, _ = buildR6(model, origin, S, skin, cloth)
    local aura = P(model,"Aura",
        Vector3.new(3.2*S, 5*S, 3.2*S),
        CFrame.new(origin + Vector3.new(0, 0.8*S, 0)),
        Color3.fromRGB(255,240,80), Enum.Material.Neon, 0.8)
    sphere(aura); glow(aura, Color3.fromRGB(255,230,50), 3, 18*S)
    W(model,hrp,aura)
    local mark = P(model,"FruitMark",
        Vector3.new(0.8*S, 0.8*S, 0.15*S),
        CFrame.new(origin + Vector3.new(0, S, 0.55*S)),
        Color3.fromRGB(255,100,30), Enum.Material.Neon)
    sphere(mark); W(model,hrp,mark)
    addHair(model, hrp, origin, S, Color3.fromRGB(18,14,14), "short")
    addEyes(model, hrp, origin, S, Color3.fromRGB(30,80,180))
end

function B.Hollow(model, origin, S)
    -- Supernatural bone-white hollow — intentionally skeletal, not human
    local bone = Color3.fromRGB(240,240,220)
    local hrp, rig = buildR6(model, origin, S, bone, bone)
    local hole = P(model,"HollowHole",
        Vector3.new(0.9*S, 0.9*S, 0.4*S),
        CFrame.new(origin + Vector3.new(0, 0.9*S, 0.55*S)),
        Color3.fromRGB(0,0,0), Enum.Material.Neon, 0.05)
    sphere(hole)
    local holeGlow = Instance.new("PointLight",hole)
    holeGlow.Color = Color3.fromRGB(20,20,20); holeGlow.Brightness=1; holeGlow.Range=8*S
    W(model,hrp,hole)
    local frag = P(model,"MaskFrag",
        Vector3.new(1.1*S, 0.6*S, 0.2*S),
        CFrame.new(origin + Vector3.new(-0.4*S, 2.65*S, 0.6*S))
            * CFrame.Angles(0,0,math.rad(20)),
        bone, Enum.Material.SmoothPlastic)
    W(model,hrp,frag)
end

function B.Arrancar(model, origin, S)
    -- Humanoid hollow: very pale skin, white shinigami uniform, mask fragment
    local pale  = Color3.fromRGB(248, 242, 242)
    local white = Color3.fromRGB(245, 245, 255)
    local hrp, _ = buildR6(model, origin, S, pale, white)
    addCape(model, hrp, origin, S, white, Enum.Material.Fabric)
    local frag = P(model,"MaskFrag",
        Vector3.new(0.9*S, 0.5*S, 0.2*S),
        CFrame.new(origin + Vector3.new(0.5*S, 2.8*S, 0.6*S)),
        Color3.fromRGB(248,245,245), Enum.Material.SmoothPlastic)
    W(model,hrp,frag)
    local aura = P(model,"Reiatsu",
        Vector3.new(2.5*S, 4.5*S, 2.5*S),
        CFrame.new(origin + Vector3.new(0, 0.5*S, 0)),
        Color3.fromRGB(200,220,255), Enum.Material.Neon, 0.85)
    sphere(aura); glow(aura, Color3.fromRGB(180,200,255), 2, 14*S)
    W(model,hrp,aura)
    addHair(model, hrp, origin, S, Color3.fromRGB(38,38,52), "long")
    addEyes(model, hrp, origin, S, Color3.fromRGB(100,160,220))
end

function B.Abnormal_Titan(model, origin, S)
    -- Flesh-toned mindless titan, exposed sinew — intentionally monstrous
    local flesh = Color3.fromRGB(220,170,130)
    local pink  = Color3.fromRGB(255,160,160)
    local hrp, rig = buildR6(model, origin, S, flesh, flesh)
    glow(rig.Torso, Color3.fromRGB(255,200,160), 1.5, 24*S)
    local neck = P(model,"Neck",
        Vector3.new(1.2*S, 1.5*S, 1.1*S),
        CFrame.new(origin + Vector3.new(0, 2.1*S, 0)),
        pink, Enum.Material.SmoothPlastic)
    W(model,hrp,neck)
    rig.Head.Size = Vector3.new(3.4*S, 2.4*S, 2.2*S)
    rig.Head.Color= pink
end

function B.Fishman_Warrior(model, origin, S)
    -- Teal-skinned fishman with dorsal spines — intentionally non-human
    local teal  = Color3.fromRGB(40,140,180)
    local dkB   = Color3.fromRGB(20,80,120)
    local hrp, rig = buildR6(model, origin, S, teal, dkB)
    for i = 1, 4 do
        local sp = P(model,"Spine",
            Vector3.new(0.2*S, 0.7*S*(1+i*0.1), 0.2*S),
            CFrame.new(origin + Vector3.new(0, 1.6*S - i*0.35*S, -0.55*S)),
            Color3.fromRGB(20,180,180), Enum.Material.SmoothPlastic)
        sphere(sp); W(model,hrp,sp)
    end
    rig.LA.Size = Vector3.new(1.3*S, 2*S, 1.1*S)
    rig.RA.Size = Vector3.new(1.3*S, 2*S, 1.1*S)
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(50,255,200))
end

function B.Rogue_Reaper(model, origin, S)
    -- Pale shinigami in black robes with scythe and captain badge
    local skin  = Color3.fromRGB(228, 210, 215)
    local cloth = Color3.fromRGB(18, 13, 28)
    local hrp, _ = buildR6(model, origin, S, skin, cloth, Enum.Material.Fabric)
    addCape(model, hrp, origin, S, Color3.fromRGB(12,8,22), Enum.Material.Fabric)
    addScythe(model, hrp, origin, S, Color3.fromRGB(210,210,240))
    addHair(model, hrp, origin, S, Color3.fromRGB(12,8,22), "long")
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(200,80,255))
    local badge = P(model,"Badge",
        Vector3.new(0.7*S, 0.7*S, 0.2*S),
        CFrame.new(origin + Vector3.new(0.7*S, 1.8*S, 0.6*S)),
        Color3.fromRGB(240,200,50), Enum.Material.SmoothPlastic)
    sphere(badge); W(model,hrp,badge)
end

function B.Armored_Titan(model, origin, S)
    -- Titan with flesh tone and crystalline armor plating
    local flesh  = Color3.fromRGB(200,160,110)
    local armor  = Color3.fromRGB(160,140,100)
    local hrp, rig = buildR6(model, origin, S, flesh, flesh)
    addArmor(model, hrp, origin, S, armor)
    for _, xOff in ipairs({-0.5*S, 0.5*S}) do
        local kn = P(model,"KneePlate",
            Vector3.new(1.2*S, 0.5*S, 1.2*S),
            CFrame.new(origin + Vector3.new(xOff, -0.5*S, 0.3*S)),
            armor, Enum.Material.Metal)
        W(model,hrp,kn)
    end
    glow(rig.Torso, Color3.fromRGB(255,200,150), 1, 30*S)
end

function B.Beast_Titan(model, origin, S)
    -- Ape-like titan with elongated gorilla arms and thick fur mane
    local tan  = Color3.fromRGB(180,145,100)
    local dark = Color3.fromRGB(120,90,60)
    local hrp, rig = buildR6(model, origin, S, tan, dark)
    rig.LA.Size = Vector3.new(1.2*S, 3.5*S, 1.1*S)
    rig.RA.Size = Vector3.new(1.2*S, 3.5*S, 1.1*S)
    rig.LA.CFrame = CFrame.new(origin + Vector3.new(-1.8*S, 0.2*S, 0))
    rig.RA.CFrame = CFrame.new(origin + Vector3.new( 1.8*S, 0.2*S, 0))
    local mane = P(model,"Mane",
        Vector3.new(3.4*S, 1.4*S, 2.2*S),
        CFrame.new(origin + Vector3.new(0, 1.7*S, 0)),
        dark, Enum.Material.Fabric)
    W(model,hrp,mane)
    rig.Head.Size = Vector3.new(3*S, 2.2*S, 2*S)
end

function B.Kamikaze_Imp(model, origin, S)
    -- Small orange-skinned imp in red outfit with bomb strapped to chest
    local skin  = Color3.fromRGB(240, 155, 95)
    local cloth = Color3.fromRGB(178, 38, 10)
    local hrp, _ = buildR6(model, origin, S, skin, cloth)
    for _, side in ipairs({-1,1}) do
        local h = P(model,"Horn",
            Vector3.new(0.22*S, 0.5*S, 0.22*S),
            CFrame.new(origin + Vector3.new(side*0.55*S, 3.1*S, 0))
                * CFrame.Angles(0,0,side*math.rad(20)),
            Color3.fromRGB(150,50,10))
        sphere(h); W(model,hrp,h)
    end
    local bomb = P(model,"Bomb",
        Vector3.new(0.9*S, 0.9*S, 0.9*S),
        CFrame.new(origin + Vector3.new(0, 0.6*S, 0.8*S)),
        Color3.fromRGB(30,30,30), Enum.Material.SmoothPlastic)
    sphere(bomb)
    local fuse = P(model,"Fuse",
        Vector3.new(0.1*S, 0.7*S, 0.1*S),
        CFrame.new(origin + Vector3.new(0.2*S, 1.3*S, 0.8*S)),
        Color3.fromRGB(200,150,30), Enum.Material.SmoothPlastic)
    local spark = P(model,"Spark",
        Vector3.new(0.3*S, 0.3*S, 0.3*S),
        CFrame.new(origin + Vector3.new(0.2*S, 1.7*S, 0.8*S)),
        Color3.fromRGB(255,220,50), Enum.Material.Neon)
    sphere(spark); glow(spark, Color3.fromRGB(255,180,0), 3, 10*S)
    for _, p in ipairs({bomb,fuse,spark}) do W(model,hrp,p) end
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(255,200,50))
end

function B.Necromancer(model, origin, S)
    -- Deathly-pale necromancer in dark purple robes with floating skull
    local skin  = Color3.fromRGB(215, 195, 220)
    local robe  = Color3.fromRGB(60, 10, 90)
    local hrp, _ = buildR6(model, origin, S, skin, robe, Enum.Material.Fabric)
    addCape(model, hrp, origin, S, robe, Enum.Material.Fabric)
    addStaff(model, hrp, origin, S,
        Color3.fromRGB(40,30,50), Color3.fromRGB(150,30,200))
    local skull = P(model,"Skull",
        Vector3.new(0.9*S, 0.9*S, 0.9*S),
        CFrame.new(origin + Vector3.new(-1.5*S, 4.2*S, 0)),
        Color3.fromRGB(230,225,210), Enum.Material.SmoothPlastic)
    sphere(skull); glow(skull, Color3.fromRGB(140,0,180), 2, 10*S)
    W(model,hrp,skull)
    addHair(model, hrp, origin, S, Color3.fromRGB(198,190,208), "long")
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(180,30,220))
end

function B.Shield_Templar(model, origin, S)
    -- Human knight with warm skin, blue tabard, full silver plate armor
    local skin  = Color3.fromRGB(235, 200, 170)
    local cloth = Color3.fromRGB(40, 60, 140)
    local hrp, _ = buildR6(model, origin, S, skin, cloth)
    addArmor(model, hrp, origin, S, Color3.fromRGB(180,190,210))
    addShield(model, hrp, origin, S, Color3.fromRGB(50,70,160))
    local visor = P(model,"Visor",
        Vector3.new(2.1*S, 0.45*S, 0.2*S),
        CFrame.new(origin + Vector3.new(0, 2.6*S, 0.6*S)),
        Color3.fromRGB(100,140,200), Enum.Material.Neon, 0.3)
    W(model,hrp,visor)
    glow(visor, Color3.fromRGB(100,140,255), 1.5, 12*S)
end

-- ─── BOSSES ──────────────────────────────────────────────────────────────────

function B.DemonLord(model, origin, S)
    -- Muzan-inspired: ghostly pale skin, elegant black suit, red glowing eyes
    local pale  = Color3.fromRGB(240, 228, 235)
    local black = Color3.fromRGB(12, 5, 20)
    local hrp, rig = buildR6(model, origin, S, pale, black)
    rig.Torso.Size = Vector3.new(2.1*S, 2.4*S, S)
    local collar = P(model,"Collar",
        Vector3.new(2.6*S, 1.4*S, 2.3*S),
        CFrame.new(origin + Vector3.new(0, 2.0*S, -0.2*S)),
        Color3.fromRGB(22, 8, 38), Enum.Material.Fabric)
    W(model,hrp,collar)
    addCape(model, hrp, origin, S*1.2, Color3.fromRGB(8,0,14), Enum.Material.Fabric)
    local aura = P(model,"CorruptionAura",
        Vector3.new(4.5*S, 7*S, 4.5*S),
        CFrame.new(origin + Vector3.new(0, S, 0)),
        Color3.fromRGB(80,0,120), Enum.Material.Neon, 0.85)
    sphere(aura); glow(aura, Color3.fromRGB(120,0,180), 5, 35*S)
    W(model,hrp,aura)
    addHair(model, hrp, origin, S, Color3.fromRGB(8,4,18), "spiky")
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(255,30,100))
    for _, side in ipairs({-1, 1}) do
        local claw = P(model,"Claw",
            Vector3.new(0.2*S, 0.8*S, 0.2*S),
            CFrame.new(origin + Vector3.new(side*2.3*S, -0.5*S, 0.4*S)),
            Color3.fromRGB(255,0,60), Enum.Material.Neon)
        glow(claw, Color3.fromRGB(255,0,60), 1.5, 8*S)
        W(model,hrp,claw)
    end
end

function B.ShadowLord(model, origin, S)
    -- Madara-inspired: tan warrior with spiky black hair, orange armor, Rinnegan eyes
    local skin  = Color3.fromRGB(175, 135, 105)
    local cloth = Color3.fromRGB(20, 20, 35)
    local hrp, _ = buildR6(model, origin, S, skin, cloth, Enum.Material.Metal)
    addArmor(model, hrp, origin, S, Color3.fromRGB(200,100,30))
    addHair(model, hrp, origin, S, Color3.fromRGB(14,10,18), "spiky")
    -- Rinnegan purple glow eyes
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(200,80,255))
    local fan = P(model,"Fan",
        Vector3.new(2.2*S, 0.15*S, 2*S),
        CFrame.new(origin + Vector3.new(-2.8*S, 0.5*S, -0.4*S)),
        Color3.fromRGB(180,30,30), Enum.Material.SmoothPlastic)
    W(model,hrp,fan)
    local aura = P(model,"ShadowAura",
        Vector3.new(5*S, 8*S, 5*S),
        CFrame.new(origin + Vector3.new(0, S, 0)),
        Color3.fromRGB(30,20,60), Enum.Material.Neon, 0.88)
    sphere(aura); glow(aura, Color3.fromRGB(100,50,200), 4, 40*S)
    W(model,hrp,aura)
end

function B.AbyssalKing(model, origin, S)
    -- Kaido-inspired: massive blue-gray oni with spiky hair and dragon scales
    local skin  = Color3.fromRGB(95, 115, 175)
    local cloth = Color3.fromRGB(20, 30, 80)
    local hrp, rig = buildR6(model, origin, S, skin, cloth)
    rig.LA.Size = Vector3.new(1.4*S, 2.6*S, 1.3*S)
    rig.RA.Size = Vector3.new(1.4*S, 2.6*S, 1.3*S)
    rig.Torso.Size = Vector3.new(2.8*S, 2.6*S, 1.2*S)
    for _, side in ipairs({-1, 1}) do
        local horn = P(model,"OniHorn",
            Vector3.new(0.6*S, 1.8*S, 0.5*S),
            CFrame.new(origin + Vector3.new(side*0.8*S, 3.8*S, 0))
                * CFrame.Angles(0, 0, side*math.rad(15)),
            Color3.fromRGB(60,40,100), Enum.Material.SmoothPlastic)
        W(model,hrp,horn)
    end
    for i = 0, 3 do
        local scale = P(model,"DragonScale",
            Vector3.new(0.7*S, 0.5*S, 0.2*S),
            CFrame.new(origin + Vector3.new((-0.9+i*0.6)*S, (0.2+i*0.3)*S, 0.65*S)),
            Color3.fromRGB(60,100,220), Enum.Material.Neon, 0.3)
        W(model,hrp,scale)
    end
    addHair(model, hrp, origin, S, Color3.fromRGB(8,8,18), "spiky")
    glow(rig.Torso, Color3.fromRGB(60,80,255), 4, 50*S)
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(255,50,50))
end

function B.VasteLorde(model, origin, S)
    -- Aizen-inspired: fair-skinned elegant figure in pristine white captain's coat
    local skin  = Color3.fromRGB(245, 225, 210)
    local white = Color3.fromRGB(252, 252, 255)
    local hrp, _ = buildR6(model, origin, S, skin, white)
    local coat = P(model,"Coat",
        Vector3.new(3*S, 5.5*S, 0.25*S),
        CFrame.new(origin + Vector3.new(0, -0.2*S, -0.65*S)),
        white, Enum.Material.Fabric)
    W(model,hrp,coat)
    addSword(model, hrp, origin, S, Color3.fromRGB(190,200,255))
    for _, side in ipairs({-1, 1}) do
        local wing = P(model,"Wing",
            Vector3.new(side*3.5*S, 4*S, 0.1*S),
            CFrame.new(origin + Vector3.new(side*2.5*S, 0.5*S, -0.5*S)),
            Color3.fromRGB(180,200,255), Enum.Material.Neon, 0.55)
        W(model,hrp,wing)
    end
    local aura = P(model,"SpiritAura",
        Vector3.new(5.5*S, 8*S, 5.5*S),
        CFrame.new(origin + Vector3.new(0, S, 0)),
        Color3.fromRGB(255,255,200), Enum.Material.Neon, 0.88)
    sphere(aura); glow(aura, Color3.fromRGB(255,240,180), 5, 45*S)
    W(model,hrp,aura)
    -- Neat brown hair, dark serious eyes
    addHair(model, hrp, origin, S, Color3.fromRGB(65,42,28), "short")
    addEyes(model, hrp, origin, S, Color3.fromRGB(60,70,150))
end

function B.ColossosTitan(model, origin, S)
    -- Colossal Titan: enormous, no skin — exposed red muscle and steam everywhere
    local flesh = Color3.fromRGB(200,160,120)
    local dark  = Color3.fromRGB(160,110,80)
    local hrp, rig = buildR6(model, origin, S, flesh, dark)
    for _, p in ipairs({rig.LA, rig.RA}) do
        p.Color    = Color3.fromRGB(220,60,60)
        p.Material = Enum.Material.SmoothPlastic
    end
    for _, xOff in ipairs({-2.5*S, 2.5*S, 0}) do
        for i = 1, 3 do
            local steam = P(model,"Steam",
                Vector3.new(0.9*S, 2.5*S, 0.9*S),
                CFrame.new(origin + Vector3.new(xOff, 3.5*S + i*1.5*S, 0)),
                Color3.fromRGB(255,255,255), Enum.Material.Neon, 0.7 + i*0.08)
            sphere(steam)
            glow(steam, Color3.fromRGB(255,220,180), 2, 20*S)
            W(model,hrp,steam)
        end
    end
    rig.Head.Color = Color3.fromRGB(220,60,60)
    glow(rig.Torso, Color3.fromRGB(255,150,100), 6, 80*S)
end

-- ─── fallback generic builder ────────────────────────────────────────────────

local function buildGeneric(model, origin, S, color)
    local hrp, _ = buildR6(model, origin, S, color, color:lerp(Color3.new(0,0,0), 0.25))
    addGlowEyes(model, hrp, origin, S, Color3.fromRGB(255, 60, 60))
end

-- ─── PUBLIC API ──────────────────────────────────────────────────────────────

-- enemyName: key from EnemyData (e.g. "Demon_Grunt")
-- model:     the Model instance created by EnemyAI.SpawnEnemy
-- position:  world CFrame / Vector3 of the model center (waist height)
-- sizeHint:  data.Size Vector3 from EnemyData (used to compute scale)
function EnemyAvatars.Build(enemyName, model, position, sizeHint)
    local S = sizeHint and math.max(0.4, sizeHint.Y / 5) or 1
    local origin = (typeof(position) == "CFrame") and position.Position or position

    local builder = B[enemyName]
    if builder then
        builder(model, origin, S)
    else
        buildGeneric(model, origin, S, Color3.fromRGB(150, 80, 80))
    end
end

return EnemyAvatars
