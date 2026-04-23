-- WorldBuilderModule.lua
-- Shared module: call WorldBuilderModule.Build() from the server script OR the Studio plugin.
-- Parts land in Workspace permanently; WorldBuilder.server.lua skips if already built.

local WorldBuilderModule = {}

function WorldBuilderModule.Build(force)
    local Workspace = game:GetService("Workspace")
    local Lighting  = game:GetService("Lighting")

    if not force and Workspace:FindFirstChild("_DPWorldBuilt") then return end

    -- Clean up previous build so rebuilding is safe
    local old = Workspace:FindFirstChild("_DPWorldBuilt")
    if old then old:Destroy() end
    local oldWorld = Workspace:FindFirstChild("DungeonPiece_World")
    if oldWorld then oldWorld:Destroy() end
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("SpawnLocation") then child:Destroy() end
    end

    local guard = Instance.new("BoolValue")
    guard.Name = "_DPWorldBuilt"
    guard.Parent = Workspace

    -- ─── helpers ─────────────────────────────────────────────────────────────
    local function P(par,sz,cf,col,mat,trans)
        local p=Instance.new("Part")
        p.Anchored=true; p.Locked=true; p.CanCollide=true
        p.Size=sz; p.CFrame=cf; p.Color=col or Color3.fromRGB(160,160,160)
        p.Material=mat or Enum.Material.SmoothPlastic; p.Transparency=trans or 0
        p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
        p.Parent=par; return p
    end
    local function Cyl(par,sz,cf,col,mat,tr)
        local p=P(par,sz,cf,col,mat,tr)
        local m=Instance.new("SpecialMesh"); m.MeshType=Enum.MeshType.Cylinder; m.Parent=p; return p
    end
    local function Sph(par,sz,cf,col,mat,tr)
        local p=P(par,sz,cf,col,mat,tr)
        local m=Instance.new("SpecialMesh"); m.MeshType=Enum.MeshType.Sphere; m.Parent=p; return p
    end
    local function Mdl(par,name)
        local m=Instance.new("Model"); m.Name=name; m.Parent=par; return m
    end
    local function PL(par,col,bright,range)
        local l=Instance.new("PointLight")
        l.Color=col or Color3.fromRGB(255,220,150); l.Brightness=bright or 2; l.Range=range or 20
        l.Parent=par; return l
    end
    local function SGui(par,text,face,tc,bg)
        local sg=Instance.new("SurfaceGui"); sg.Face=face or Enum.NormalId.Front; sg.Parent=par
        local lb=Instance.new("TextLabel"); lb.Size=UDim2.new(1,0,1,0)
        lb.BackgroundColor3=bg or Color3.fromRGB(20,10,5); lb.BackgroundTransparency=0.1
        lb.Text=text; lb.TextColor3=tc or Color3.fromRGB(255,220,80)
        lb.TextScaled=true; lb.Font=Enum.Font.GothamBold
        lb.TextStrokeTransparency=0.5; lb.Parent=sg; return sg
    end
    local function BGui(par,text,off,wx,wy,tc,bgc,bgt)
        local bg=Instance.new("BillboardGui")
        bg.Size=UDim2.new(0,wx or 200,0,wy or 55)
        bg.StudsOffset=off or Vector3.new(0,3,0); bg.MaxDistance=120; bg.Parent=par
        local fr=Instance.new("Frame"); fr.Size=UDim2.new(1,0,1,0)
        fr.BackgroundColor3=bgc or Color3.fromRGB(5,5,15)
        fr.BackgroundTransparency=bgt or 0.35; fr.BorderSizePixel=0; fr.Parent=bg
        local cr=Instance.new("UICorner"); cr.CornerRadius=UDim.new(0,8); cr.Parent=fr
        local lb=Instance.new("TextLabel"); lb.Size=UDim2.new(1,-6,1,-4); lb.Position=UDim2.new(0,3,0,2)
        lb.BackgroundTransparency=1; lb.Text=text; lb.TextColor3=tc or Color3.fromRGB(255,255,255)
        lb.TextScaled=true; lb.Font=Enum.Font.GothamBold
        lb.TextStrokeTransparency=0.4; lb.Parent=fr; return bg
    end

    local V3=Vector3.new; local CF=CFrame.new; local Ang=CFrame.Angles; local R=math.rad

    -- ─── palette ─────────────────────────────────────────────────────────────
    local C={
        ocean=Color3.fromRGB(20,80,170),    water=Color3.fromRGB(35,115,200),
        sand=Color3.fromRGB(238,214,160),   grass=Color3.fromRGB(84,175,84),
        stone=Color3.fromRGB(130,130,135),  dkSt=Color3.fromRGB(85,85,90),
        cobble=Color3.fromRGB(115,115,120), wood=Color3.fromRGB(145,95,50),
        dkWood=Color3.fromRGB(90,57,26),    bark=Color3.fromRGB(100,65,30),
        gold=Color3.fromRGB(255,200,50),    orange=Color3.fromRGB(255,130,40),
        red=Color3.fromRGB(205,42,42),      maroon=Color3.fromRGB(140,20,20),
        blue=Color3.fromRGB(55,120,230),    navy=Color3.fromRGB(20,50,135),
        teal=Color3.fromRGB(0,185,165),     cyan=Color3.fromRGB(75,220,255),
        green=Color3.fromRGB(50,165,50),    dkGrn=Color3.fromRGB(25,95,25),
        leaf=Color3.fromRGB(60,175,60),     white=Color3.fromRGB(242,242,242),
        cream=Color3.fromRGB(245,230,200),  brown=Color3.fromRGB(118,77,38),
        purple=Color3.fromRGB(138,43,215),  dkPurp=Color3.fromRGB(55,8,100),
        pink=Color3.fromRGB(255,105,180),   yellow=Color3.fromRGB(255,235,60),
        ice=Color3.fromRGB(185,235,255),    iceB=Color3.fromRGB(100,180,255),
        silver=Color3.fromRGB(195,195,205), black=Color3.fromRGB(18,18,22),
        rust=Color3.fromRGB(170,75,20),     coral=Color3.fromRGB(255,100,80),
        coralB=Color3.fromRGB(0,165,185),
        futBlack=Color3.fromRGB(12,15,22),  futDark=Color3.fromRGB(22,28,40),
        futMetal=Color3.fromRGB(42,52,72),  futGray=Color3.fromRGB(68,80,105),
        futCyan=Color3.fromRGB(0,210,255),  futBlue=Color3.fromRGB(40,130,255),
        futTeal=Color3.fromRGB(0,195,175),  futPurp=Color3.fromRGB(155,80,255),
        futGreen=Color3.fromRGB(0,230,150), futAmb=Color3.fromRGB(255,185,30),
        futWhite=Color3.fromRGB(210,225,248),
    }

    -- ─── root models ─────────────────────────────────────────────────────────
    local World = Mdl(Workspace,"DungeonPiece_World")
    local Lobby = Mdl(World,"Lobby")
    local PZone = Mdl(World,"PortalZone")
    local Dngns = Mdl(World,"Dungeons")

    -- ─── LIGHTING ────────────────────────────────────────────────────────────
    Lighting.Brightness=2.2; Lighting.ClockTime=13.5
    Lighting.FogEnd=3000; Lighting.FogColor=Color3.fromRGB(175,210,255)
    Lighting.Ambient=Color3.fromRGB(90,110,145); Lighting.OutdoorAmbient=Color3.fromRGB(130,155,200)
    if not Lighting:FindFirstChildOfClass("Atmosphere") then
        local atm=Instance.new("Atmosphere"); atm.Density=0.3; atm.Offset=0.25
        atm.Color=Color3.fromRGB(185,215,255); atm.Decay=Color3.fromRGB(80,130,200)
        atm.Glare=0.1; atm.Haze=0.5; atm.Parent=Lighting
    end
    if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
        local cc=Instance.new("ColorCorrectionEffect"); cc.Brightness=0.02
        cc.Contrast=0.08; cc.Saturation=0.15; cc.Parent=Lighting
    end
    if not Lighting:FindFirstChildOfClass("BloomEffect") then
        local bl=Instance.new("BloomEffect"); bl.Intensity=0.4; bl.Size=24; bl.Threshold=0.95; bl.Parent=Lighting
    end

    -- ─── OCEAN + ISLAND BASE ─────────────────────────────────────────────────
    local terrain = Workspace.Terrain
    terrain:FillBlock(CF(0,-12,0), V3(3000,24,3000), Enum.Material.Water)
    terrain:FillBlock(CF(0,-1,20),  V3(320,6,420),   Enum.Material.Sand)
    terrain:FillBlock(CF(0,0,20),   V3(290,8,390),   Enum.Material.Concrete)

    -- ─── CITY ROADS ──────────────────────────────────────────────────────────
    P(Lobby,V3(280,1,380),CF(0,1.3,20),C.futBlack,Enum.Material.SmoothPlastic)
    P(Lobby,V3(26,1.1,310),CF(0,1.45,-35),C.futDark,Enum.Material.Metal)
    P(Lobby,V3(3,1.15,310),CF(0,1.5,-35),C.futCyan,Enum.Material.Neon,0.55)
    P(Lobby,V3(280,1.1,26),CF(0,1.45,20),C.futDark,Enum.Material.Metal)
    P(Lobby,V3(280,1.15,3),CF(0,1.5,20),C.futCyan,Enum.Material.Neon,0.55)
    for _,zz in ipairs({-80,-120,-160,-200,-240}) do
        P(Lobby,V3(18,1.16,6),CF(0,1.51,zz),C.futGray,Enum.Material.Neon,0.75)
    end
    for _,xx in ipairs({-100,-60,-20,20,60,100}) do
        P(Lobby,V3(6,1.16,18),CF(xx,1.51,20),C.futGray,Enum.Material.Neon,0.75)
    end
    P(Lobby,V3(80,1.2,80),CF(0,1.4,20),C.futBlack,Enum.Material.Metal)
    P(Lobby,V3(80,1.21,4),CF(0,1.42,20),C.futCyan,Enum.Material.Neon,0.5)
    P(Lobby,V3(4,1.21,80),CF(0,1.42,20),C.futCyan,Enum.Material.Neon,0.5)
    P(Lobby,V3(24,1.1,80),CF(0,1.45,-60),C.futDark,Enum.Material.Metal)
    P(Lobby,V3(3,1.15,80),CF(0,1.5,-60),C.futCyan,Enum.Material.Neon,0.6)
    P(Lobby,V3(24,1.1,80),CF(0,1.45,100),C.futDark,Enum.Material.Metal)
    P(Lobby,V3(3,1.15,80),CF(0,1.5,100),C.futCyan,Enum.Material.Neon,0.6)
    P(Lobby,V3(80,1.1,24),CF(-80,1.45,20),C.futDark,Enum.Material.Metal)
    P(Lobby,V3(80,1.15,3),CF(-80,1.5,20),C.futCyan,Enum.Material.Neon,0.6)
    P(Lobby,V3(80,1.1,24),CF(80,1.45,20),C.futDark,Enum.Material.Metal)
    P(Lobby,V3(80,1.15,3),CF(80,1.5,20),C.futCyan,Enum.Material.Neon,0.6)
    for _,cfg in ipairs({
        {V3(280,1.05,8),CF(0,1.35,64),C.futMetal},
        {V3(280,1.05,8),CF(0,1.35,-24),C.futMetal},
        {V3(8,1.05,380),CF(-48,1.35,20),C.futMetal},
        {V3(8,1.05,380),CF(48,1.35,20),C.futMetal},
    }) do P(Lobby,cfg[1],cfg[2],cfg[3],Enum.Material.Metal) end

    -- ─── CENTRAL BEACON TOWER ────────────────────────────────────────────────
    local Mon=Mdl(Lobby,"Monument")
    P(Mon,V3(26,2,26),CF(0,2,20),C.futBlack,Enum.Material.Metal)
    P(Mon,V3(22,0.5,22),CF(0,3.05,20),C.futCyan,Enum.Material.Neon,0.5)
    P(Mon,V3(7,22,7),CF(0,14,20),C.futDark,Enum.Material.Metal)
    for _,hy in ipairs({10,17,24}) do
        P(Mon,V3(8,0.6,8),CF(0,hy,20),C.futCyan,Enum.Material.Neon,0.35)
        PL(P(Mon,V3(1,1,1),CF(0,hy,20),C.futCyan,Enum.Material.Neon,1),C.futCyan,2,30)
    end
    local orb=Sph(Mon,V3(7,7,7),CF(0,27.5,20),C.futCyan,Enum.Material.Neon,0.08)
    PL(orb,C.futCyan,6,55)
    for i=0,3 do
        local a=R(i*90+45); local sx,sz=math.sin(a)*10,20+math.cos(a)*10
        P(Mon,V3(2,14,2),CF(sx,9,sz),C.futMetal,Enum.Material.Metal)
        local sp=Sph(Mon,V3(2.5,2.5,2.5),CF(sx,17,sz),C.futBlue,Enum.Material.Neon)
        PL(sp,C.futBlue,2,18)
    end
    local signB=P(Mon,V3(42,9,0.4),CF(0,24,12.2),C.futBlack,Enum.Material.SmoothPlastic)
    SGui(signB,"⚡  DUNGEON PIECE  ⚡",Enum.NormalId.Front,C.futCyan,C.futBlack)
    SGui(signB,"⚡  DUNGEON PIECE  ⚡",Enum.NormalId.Back,C.futCyan,C.futBlack)
    PL(signB,C.futCyan,5,50)

    -- ─── BUILDINGS ───────────────────────────────────────────────────────────
    local function mkFutBuilding(par,cx,cz,bw,bd,bh,accentCol,name,sign)
        local bm=Mdl(par,name)
        P(bm,V3(bw+6,2,bd+6),CF(cx,1,cz),C.futBlack,Enum.Material.Metal)
        P(bm,V3(bw,bh,bd),CF(cx,2+bh/2,cz),C.futDark,Enum.Material.SmoothPlastic)
        for _,ox in ipairs({-bw/2,bw/2}) do
            for _,oz in ipairs({-bd/2,bd/2}) do
                P(bm,V3(1.2,bh+2,1.2),CF(cx+ox,2+bh/2,cz+oz),C.futMetal,Enum.Material.Metal)
            end
        end
        for f=0.22,0.78,0.28 do
            local wst=P(bm,V3(bw+0.2,bh*0.09,bd+0.2),CF(cx,2+bh*f,cz),accentCol,Enum.Material.Neon,0.28)
            PL(wst,accentCol,1,25)
        end
        P(bm,V3(bw+2,1.5,bd+2),CF(cx,2+bh+0.75,cz),C.futMetal,Enum.Material.Metal)
        P(bm,V3(bw+2,0.4,bd+2),CF(cx,2+bh+1.75,cz),accentCol,Enum.Material.Neon,0.35)
        local bcn=Sph(bm,V3(3,3,3),CF(cx,2+bh+4,cz),accentCol,Enum.Material.Neon,0.08)
        PL(bcn,accentCol,5,48)
        P(bm,V3(6,8.5,0.8),CF(cx,7,cz-bd/2-0.1),C.futBlack,Enum.Material.SmoothPlastic)
        P(bm,V3(6,0.4,0.8),CF(cx,11.5,cz-bd/2-0.1),accentCol,Enum.Material.Neon,0.3)
        if sign then
            local sp=P(bm,V3(bw*0.65,3.5,0.4),CF(cx,2+bh-3,cz-bd/2-0.35),C.futBlack,Enum.Material.SmoothPlastic)
            SGui(sp,sign,Enum.NormalId.Front,accentCol,C.futBlack)
            PL(sp,accentCol,2,22)
        end
    end
    mkFutBuilding(Lobby,-85,35,22,16,16,C.futCyan,"Shop","🛒  SHOP")
    mkFutBuilding(Lobby,85,35,22,16,16,C.futBlue,"GuildHall","⚔  GUILD HALL")
    mkFutBuilding(Lobby,85,-30,20,14,14,C.futAmb,"UpgradeStation","⚒  UPGRADES")
    local forge=Sph(Lobby,V3(3,3,3),CF(85,5,-30),C.futAmb,Enum.Material.Neon,0.2)
    PL(forge,C.futAmb,4,30)

    local QB=Mdl(Lobby,"QuestBoard")
    P(QB,V3(22,2,6),CF(90,2,-30),C.futBlack,Enum.Material.Metal)
    P(QB,V3(18,0.4,4),CF(90,3.2,-30),C.futGreen,Enum.Material.Neon,0.5)
    Cyl(QB,V3(1,12,1),CF(79,8,-30),C.futMetal,Enum.Material.Metal)
    Cyl(QB,V3(1,12,1),CF(101,8,-30),C.futMetal,Enum.Material.Metal)
    P(QB,V3(22,0.6,4),CF(90,14.5,-30),C.futMetal,Enum.Material.Metal)
    local qbf=P(QB,V3(20,10,0.4),CF(90,9,-27.6),C.futBlack,Enum.Material.SmoothPlastic)
    SGui(qbf,"📋  QUEST BOARD\n✦ Daily Missions\n✦ Boss Hunts\n✦ Dungeon Clears",Enum.NormalId.Front,C.futGreen,C.futBlack)
    PL(qbf,C.futGreen,2,22)

    local LB=Mdl(Lobby,"Leaderboard")
    P(LB,V3(4,3,4),CF(-85,2.5,-30),C.futBlack,Enum.Material.Metal)
    P(LB,V3(3,28,3),CF(-85,16,-30),C.futMetal,Enum.Material.Metal)
    P(LB,V3(28,24,2),CF(-85,14,-30),C.futDark,Enum.Material.SmoothPlastic)
    P(LB,V3(28,0.5,2),CF(-85,26.5,-30),C.futBlue,Enum.Material.Neon,0.3)
    P(LB,V3(28,0.5,2),CF(-85,2,-30),C.futBlue,Enum.Material.Neon,0.3)
    local lbf=P(LB,V3(26,22,0.5),CF(-85,14,-28.8),C.futBlack,Enum.Material.SmoothPlastic)
    SGui(lbf,"🏆  TOP DIVERS\n\n#1  ???\n#2  ???\n#3  ???",Enum.NormalId.Front,C.futBlue,C.futBlack)
    PL(lbf,C.futBlue,2,26)
    local lbBeacon=Sph(LB,V3(4,4,4),CF(-85,30,-30),C.futBlue,Enum.Material.Neon,0.08)
    PL(lbBeacon,C.futBlue,5,35)

    local Pty=Mdl(Lobby,"PartyDeck")
    P(Pty,V3(48,1,26),CF(0,1.5,110),C.futBlack,Enum.Material.Metal)
    P(Pty,V3(48,0.4,2),CF(0,2.1,110),C.futPurp,Enum.Material.Neon,0.45)
    for _,x in ipairs({-22,22}) do
        for _,z in ipairs({-10,10}) do
            P(Pty,V3(1.5,12,1.5),CF(x,8,110+z),C.futMetal,Enum.Material.Metal)
            local ptop=Sph(Pty,V3(2.5,2.5,2.5),CF(x,15,110+z),C.futPurp,Enum.Material.Neon,0.1)
            PL(ptop,C.futPurp,3,22)
        end
    end
    P(Pty,V3(44,0.5,0.5),CF(0,15,120),C.futPurp,Enum.Material.Neon,0.5)
    P(Pty,V3(44,0.5,0.5),CF(0,15,100),C.futPurp,Enum.Material.Neon,0.5)
    local ptySign=P(Pty,V3(22,4,0.4),CF(0,7,98.6),C.futBlack,Enum.Material.SmoothPlastic)
    SGui(ptySign,"🔮  GATHER ZONE  🔮",Enum.NormalId.Front,C.futPurp,C.futBlack)
    PL(ptySign,C.futPurp,2,22)

    local Trn=Mdl(Lobby,"TrainingZone")
    P(Trn,V3(55,1,42),CF(0,1.5,130),C.futBlack,Enum.Material.Metal)
    P(Trn,V3(55,0.4,2),CF(0,2.1,110),C.futAmb,Enum.Material.Neon,0.45)
    local trnSign=P(Trn,V3(26,5,0.4),CF(0,7,110.6),C.futBlack,Enum.Material.SmoothPlastic)
    SGui(trnSign,"⚔  TRAINING ZONE",Enum.NormalId.Front,C.futAmb,C.futBlack)
    PL(trnSign,C.futAmb,3,24)
    for i=0,5 do
        local dx=-22+i*9
        Cyl(Trn,V3(2.5,10,2.5),CF(dx,7,130),C.futMetal,Enum.Material.Metal)
        local dHead=Sph(Trn,V3(4,4,4),CF(dx,13,130),C.futGray,Enum.Material.SmoothPlastic)
        P(Trn,V3(4.5,0.6,4.5),CF(dx,9,130),C.futAmb,Enum.Material.Neon,0.35)
        PL(dHead,C.futAmb,1,14)
    end
    do
        local pp=Instance.new("ProximityPrompt")
        pp.ActionText="Train"; pp.ObjectText="Training Zone"
        pp.HoldDuration=0; pp.MaxActivationDistance=14
        pp.Parent=trnSign
    end

    local function mkHoloKiosk(par,cx,cz,accentCol,label,interactText)
        local sm=Mdl(par,"Stall_"..label)
        P(sm,V3(14,1.5,9),CF(cx,2.25,cz),C.futBlack,Enum.Material.Metal)
        P(sm,V3(12,0.3,7),CF(cx,3.15,cz),accentCol,Enum.Material.Neon,0.5)
        for _,ox in ipairs({-6,6}) do
            for _,oz in ipairs({-3.5,3.5}) do
                P(sm,V3(0.8,10,0.8),CF(cx+ox,8,cz+oz),C.futMetal,Enum.Material.Metal)
            end
        end
        P(sm,V3(16,0.5,11),CF(cx,13.5,cz),C.futMetal,Enum.Material.Metal)
        P(sm,V3(14,0.3,9),CF(cx,14,cz),accentCol,Enum.Material.Neon,0.4)
        P(sm,V3(11,2,3.5),CF(cx,5,cz-2),C.futDark,Enum.Material.SmoothPlastic)
        P(sm,V3(9,0.3,2),CF(cx,6.15,cz-2),accentCol,Enum.Material.Neon,0.45)
        local lp=P(sm,V3(0.1,0.1,0.1),CF(cx,10,cz),accentCol,Enum.Material.Neon,1)
        BGui(lp,label,V3(0,0.5,0),160,38,C.white,Color3.fromRGB(5,5,15),0.4)
        PL(lp,accentCol,2,20)
        local pp=Instance.new("ProximityPrompt")
        pp.ActionText="Browse"; pp.ObjectText=interactText or label
        pp.HoldDuration=0; pp.MaxActivationDistance=10
        pp.Parent=sm
    end
    mkHoloKiosk(Lobby,-108,20,C.futCyan,"⚓ Weapons","Weapons")
    mkHoloKiosk(Lobby,108,20,C.futBlue,"🛡 Armor","Armor")
    mkHoloKiosk(Lobby,0,-90,C.futGreen,"✨ Abilities","Abilities")
    mkHoloKiosk(Lobby,60,20,C.futPurp,"💎 Rare Items","Rare Items")

    local Accents=Mdl(Lobby,"Accents")
    for z=-90,80,28 do
        for _,x in ipairs({-10,10}) do
            local pyl=P(Accents,V3(1,12,1),CF(x,7,z),C.futMetal,Enum.Material.Metal)
            local top=Sph(Accents,V3(1.8,1.8,1.8),CF(x,14,z),C.futCyan,Enum.Material.Neon,0.1)
            PL(top,C.futCyan,2,20)
        end
    end
    for _,a in ipairs({45,135,225,315}) do
        local ex=math.sin(R(a))*40; local ez=20+math.cos(R(a))*40
        local aorb=Sph(Accents,V3(2,2,2),CF(ex,4,ez),C.futBlue,Enum.Material.Neon,0.12)
        PL(aorb,C.futBlue,3,24)
    end

    -- ─── PORTAL ZONE ─────────────────────────────────────────────────────────
    P(PZone,V3(64,2,4),CF(0,2,-116),C.dkSt,Enum.Material.SmoothPlastic)
    Cyl(PZone,V3(4,26,4),CF(-30,15,-116),C.stone,Enum.Material.SmoothPlastic)
    Cyl(PZone,V3(4,26,4),CF(30,15,-116),C.stone,Enum.Material.SmoothPlastic)
    P(PZone,V3(64,6,4),CF(0,29,-116),C.stone,Enum.Material.SmoothPlastic)
    local archGlow=P(PZone,V3(50,2,0.8),CF(0,29,-115.5),C.gold,Enum.Material.Neon,0.15)
    PL(archGlow,C.gold,3,35)
    local archSign=P(PZone,V3(32,5,1),CF(0,31,-115.3),C.dkWood,Enum.Material.Wood)
    SGui(archSign,"⚔  DUNGEON PORTALS  ⚔",Enum.NormalId.Front,C.gold,Color3.fromRGB(8,4,2))
    PL(archSign,C.gold,2,25)
    P(PZone,V3(210,1,115),CF(0,1.5,-168),C.dkSt,Enum.Material.SmoothPlastic)
    for i=0,11 do
        local a=R(i*30)
        Sph(PZone,V3(2,2,2),CF(math.sin(a)*95,2,-168+math.cos(a)*45),C.gold,Enum.Material.Neon,0.25)
    end
    for _,tx in ipairs({-95,-65,-35,35,65,95}) do
        Cyl(PZone,V3(1.5,9,1.5),CF(tx,5.5,-117),C.dkSt,Enum.Material.Metal)
        local fl=Sph(PZone,V3(2.8,3.5,2.8),CF(tx,10.5,-117),C.orange,Enum.Material.Neon,0.1)
        PL(fl,Color3.fromRGB(255,135,30),4,24)
    end

    local DDATA = {
        {name="Coral Lagoon", level="Lv 1-15",  diff="⭐ Easy",       portalCol=Color3.fromRGB(0,185,165),  glow=Color3.fromRGB(100,255,220)},
        {name="Pirate Cove",  level="Lv 15-30", diff="⭐⭐ Normal",    portalCol=Color3.fromRGB(195,90,20),  glow=Color3.fromRGB(255,165,60)},
        {name="Thunder Peak", level="Lv 30-50", diff="⭐⭐⭐ Hard",     portalCol=Color3.fromRGB(60,110,230), glow=Color3.fromRGB(150,210,255)},
        {name="Jungle Ruins", level="Lv 50-70", diff="⭐⭐⭐⭐ Expert",  portalCol=Color3.fromRGB(40,140,40),  glow=Color3.fromRGB(80,255,80)},
        {name="Glacial Keep", level="Lv 70-90", diff="⭐⭐⭐⭐⭐ Master", portalCol=Color3.fromRGB(120,185,255),glow=Color3.fromRGB(200,235,255)},
        {name="Shadow Gate",  level="Lv 90+",   diff="💀 EXTREME",     portalCol=Color3.fromRGB(120,20,220), glow=Color3.fromRGB(210,110,255)},
    }
    local PPOS = {
        {x=-75,z=-155},{x=0,z=-155},{x=75,z=-155},
        {x=-75,z=-182},{x=0,z=-182},{x=75,z=-182},
    }
    for i,dd in ipairs(DDATA) do
        local pp=PPOS[i]; local px,pz=pp.x,pp.z
        local pm=Mdl(PZone,"Portal_"..dd.name)
        local fw,fh=10,15
        Cyl(pm,V3(3.5,fh+5,3.5),CF(px-fw/2-2,((fh+5)/2)+1,pz),C.dkSt,Enum.Material.SmoothPlastic)
        Cyl(pm,V3(3.5,fh+5,3.5),CF(px+fw/2+2,((fh+5)/2)+1,pz),C.dkSt,Enum.Material.SmoothPlastic)
        Sph(pm,V3(4.5,4.5,4.5),CF(px-fw/2-2,fh+8,pz),dd.portalCol,Enum.Material.Neon)
        Sph(pm,V3(4.5,4.5,4.5),CF(px+fw/2+2,fh+8,pz),dd.portalCol,Enum.Material.Neon)
        PL(Sph(pm,V3(1,1,1),CF(px-fw/2-2,fh+8,pz),dd.glow,Enum.Material.Neon,1),dd.glow,3,18)
        PL(Sph(pm,V3(1,1,1),CF(px+fw/2+2,fh+8,pz),dd.glow,Enum.Material.Neon,1),dd.glow,3,18)
        P(pm,V3(fw+8,3.5,3.5),CF(px,fh+3,pz),C.stone,Enum.Material.SmoothPlastic)
        P(pm,V3(fw,2,2),CF(px,1.5,pz),C.stone,Enum.Material.SmoothPlastic)
        P(pm,V3(2,fh,2),CF(px-fw/2+1,1+fh/2,pz),C.stone,Enum.Material.SmoothPlastic)
        P(pm,V3(2,fh,2),CF(px+fw/2-1,1+fh/2,pz),C.stone,Enum.Material.SmoothPlastic)
        local discCF=CF(px,1.5+fh/2,pz)*Ang(math.pi/2,0,0)
        local outerRing=Cyl(pm,V3(fh-1,0.4,fh-1),discCF,dd.glow,Enum.Material.Neon,0.5)
        outerRing.Name="PortalOuter"; outerRing.CanCollide=false
        outerRing:SetAttribute("IsPortalDisc",true); outerRing:SetAttribute("SpinSpeed",0.4)
        local midDisc=Cyl(pm,V3(fh-3,0.5,fh-3),discCF,dd.portalCol,Enum.Material.Neon,0.2)
        midDisc.Name="PortalMid"; midDisc.CanCollide=false
        midDisc:SetAttribute("IsPortalDisc",true); midDisc:SetAttribute("SpinSpeed",-0.7)
        local innerCore=Cyl(pm,V3(fh-7,0.6,fh-7),discCF,dd.glow,Enum.Material.Neon,0.12)
        innerCore.Name="PortalInner"; innerCore.CanCollide=false
        innerCore:SetAttribute("IsPortalDisc",true); innerCore:SetAttribute("SpinSpeed",1.2)
        PL(midDisc,dd.glow,5,38)
        local np=P(pm,V3(0.1,0.1,0.1),CF(px,fh+11,pz),dd.glow,Enum.Material.Neon,1)
        BGui(np,dd.name.."\n"..dd.level.."  |  "..dd.diff,V3(0,0,0),230,62,C.white,Color3.fromRGB(4,4,14),0.3)
        PL(np,dd.glow,2,16)
    end

    -- ─── DUNGEON ROOMS ───────────────────────────────────────────────────────
    local function mkRoom(par,cx,cz,fc,wc,cc,fm,wm,ac)
        local dm=Mdl(par,"Room")
        local RW,RD,RH=120,120,28
        P(dm,V3(RW,2,RD),CF(cx,1,cz),fc,fm)
        P(dm,V3(RW+2,2,RD+2),CF(cx,RH+2,cz),cc,wm)
        P(dm,V3(RW+2,RH,2),CF(cx,2+RH/2,cz-RD/2),wc,wm)
        P(dm,V3((RW-16)/2,RH,2),CF(cx-(RW+16)/4,2+RH/2,cz+RD/2),wc,wm)
        P(dm,V3((RW-16)/2,RH,2),CF(cx+(RW+16)/4,2+RH/2,cz+RD/2),wc,wm)
        P(dm,V3(16,RH-18,2),CF(cx,RH-7,cz+RD/2),wc,wm)
        P(dm,V3(2,RH,RD+2),CF(cx-RW/2-1,2+RH/2,cz),wc,wm)
        P(dm,V3(2,RH,RD+2),CF(cx+RW/2+1,2+RH/2,cz),wc,wm)
        for li=0,3 do
            local a=R(li*90+45)
            local lp=P(dm,V3(2,2,2),CF(cx+math.sin(a)*(RW/2-12),RH,cz+math.cos(a)*(RD/2-12)),ac,Enum.Material.Neon,0.18)
            PL(lp,ac,4,65)
        end
        PL(P(dm,V3(3,3,3),CF(cx,RH-1,cz),ac,Enum.Material.Neon,0.18),ac,5,85)
        return dm
    end

    local D1=Mdl(Dngns,"CoralLagoon"); local c1x=500
    mkRoom(D1,c1x,0,Color3.fromRGB(15,120,130),Color3.fromRGB(10,80,95),Color3.fromRGB(8,70,85),Enum.Material.SmoothPlastic,Enum.Material.SmoothPlastic,Color3.fromRGB(0,220,200))
    for i=0,6 do
        local a=R(i*(360/7)); local cpx=c1x+math.sin(a)*40
        Cyl(D1,V3(4,18,4),CF(cpx,11,math.cos(a)*40),Color3.fromRGB(255,100,100),Enum.Material.SmoothPlastic)
        Sph(D1,V3(7,5,7),CF(cpx,21,math.cos(a)*40),Color3.fromRGB(255,130,110),Enum.Material.SmoothPlastic)
        PL(Sph(D1,V3(1,1,1),CF(cpx,21,math.cos(a)*40),Color3.fromRGB(255,140,120),Enum.Material.Neon,1),Color3.fromRGB(255,180,160),2,18)
    end
    for i=1,5 do
        local wx=c1x+math.random(-38,38); local wz=math.random(-38,38)
        P(D1,V3(10,0.5,10),CF(wx,1.4,wz),Color3.fromRGB(30,160,210),Enum.Material.Neon,0.5)
        PL(P(D1,V3(1,1,1),CF(wx,2,wz),Color3.fromRGB(30,160,210),Enum.Material.Neon,1),Color3.fromRGB(30,200,255),2,20)
    end
    for i=1,4 do
        local tx=c1x+math.random(-35,35); local tz=math.random(-35,35)
        P(D1,V3(4,3,3),CF(tx,3.5,tz),C.dkWood,Enum.Material.Wood)
        P(D1,V3(4,1.5,3.1),CF(tx,5.1,tz),C.brown,Enum.Material.Wood)
        P(D1,V3(2,1,0.5),CF(tx,3.8,tz-1.7),C.gold,Enum.Material.Neon)
    end
    BGui(P(D1,V3(0.1,0.1,0.1),CF(c1x,32,60),C.teal,Enum.Material.Neon,1),"🪸 Coral Lagoon\nLv 1-15  |  ⭐ Easy",V3(0,0,0),260,65,C.white,Color3.fromRGB(0,50,55),0.3)

    local D2=Mdl(Dngns,"PirateCove"); local c2x=1000
    mkRoom(D2,c2x,0,Color3.fromRGB(80,55,25),Color3.fromRGB(55,38,18),Color3.fromRGB(35,22,10),Enum.Material.Wood,Enum.Material.SmoothPlastic,Color3.fromRGB(255,150,50))
    P(D2,V3(32,8,16),CF(c2x-22,6,0)*Ang(0,R(18),R(7)),C.dkWood,Enum.Material.Wood)
    Cyl(D2,V3(2,22,2),CF(c2x-18,13,-8),C.dkWood,Enum.Material.Wood)
    P(D2,V3(15,0.5,10),CF(c2x-18,24,-8)*Ang(0,0,R(-28)),C.white,Enum.Material.SmoothPlastic)
    for i=0,4 do
        Cyl(D2,V3(1.5,9,1.5),CF(c2x-40+i*20,5.5,-42),C.silver,Enum.Material.Metal)
        if i<4 then P(D2,V3(20,1,1),CF(c2x-30+i*20,10,-42),C.silver,Enum.Material.Metal) end
    end
    local gp=Sph(D2,V3(10,5,10),CF(c2x,4,0),C.gold,Enum.Material.Neon,0.25)
    PL(gp,C.gold,6,32)
    for i=1,10 do Sph(D2,V3(1.5,1.5,1.5),CF(c2x+math.random(-5,5),3,math.random(-5,5)),C.gold,Enum.Material.Neon,0.1) end
    for i=1,14 do Cyl(D2,V3(3,3.5,3),CF(c2x+math.random(-50,50),3.25,math.random(-50,50)),C.dkWood,Enum.Material.Wood) end
    BGui(P(D2,V3(0.1,0.1,0.1),CF(c2x,32,60),C.rust,Enum.Material.Neon,1),"☠ Pirate Cove\nLv 15-30  |  ⭐⭐ Normal",V3(0,0,0),260,65,C.white,Color3.fromRGB(30,15,5),0.3)

    local D3=Mdl(Dngns,"ThunderPeak"); local c3x=1500
    mkRoom(D3,c3x,0,Color3.fromRGB(65,65,78),Color3.fromRGB(48,48,60),Color3.fromRGB(30,30,42),Enum.Material.Slate,Enum.Material.SmoothPlastic,Color3.fromRGB(110,170,255))
    for i=0,6 do
        local a=R(i*(360/7)); local rpx=c3x+math.sin(a)*38; local rpz=math.cos(a)*38
        local rh=math.random(12,22)
        Cyl(D3,V3(5+math.random(0,3),rh,5+math.random(0,3)),CF(rpx,rh/2,rpz),Color3.fromRGB(78,78,90),Enum.Material.Slate)
        Cyl(D3,V3(0.8,6,0.8),CF(rpx,rh+4,rpz),C.silver,Enum.Material.Metal)
        PL(Sph(D3,V3(2.5,2.5,2.5),CF(rpx,rh+7.5,rpz),Color3.fromRGB(160,210,255),Enum.Material.Neon),Color3.fromRGB(130,190,255),4,26)
    end
    for i=1,5 do
        local csx=c3x+math.random(-45,45); local csz=math.random(-45,45)
        Sph(D3,V3(18,7,18),CF(csx,24,csz),Color3.fromRGB(52,52,68),Enum.Material.SmoothPlastic,0.28)
        PL(P(D3,V3(1,14,1),CF(csx,17,csz)*Ang(0,0,R(math.random(-18,18))),Color3.fromRGB(210,230,255),Enum.Material.Neon,0.35),Color3.fromRGB(180,215,255),3,22)
    end
    for i=1,10 do
        P(D3,V3(math.random(6,18),0.3,math.random(1,3)),CF(c3x+math.random(-48,48),2.3,math.random(-48,48))*Ang(0,R(math.random(0,180)),0),Color3.fromRGB(100,185,255),Enum.Material.Neon,0.45)
    end
    BGui(P(D3,V3(0.1,0.1,0.1),CF(c3x,32,60),C.blue,Enum.Material.Neon,1),"⚡ Thunder Peak\nLv 30-50  |  ⭐⭐⭐ Hard",V3(0,0,0),260,65,C.white,Color3.fromRGB(10,15,35),0.3)

    local D4=Mdl(Dngns,"JungleRuins"); local c4x=2000
    mkRoom(D4,c4x,0,Color3.fromRGB(38,82,28),Color3.fromRGB(50,88,38),Color3.fromRGB(28,68,18),Enum.Material.Grass,Enum.Material.SmoothPlastic,Color3.fromRGB(80,230,80))
    for i=0,5 do
        local a=R(i*60); local tpx=c4x+math.sin(a)*36; local tpz=math.cos(a)*36
        Cyl(D4,V3(5.5,20,5.5),CF(tpx,12,tpz),Color3.fromRGB(118,98,58),Enum.Material.Cobblestone)
        PL(P(D4,V3(3.5,3.5,0.5),CF(tpx,7,tpz-3),Color3.fromRGB(80,255,80),Enum.Material.Neon,0.28),Color3.fromRGB(80,255,80),2,20)
    end
    P(D4,V3(13,2,13),CF(c4x,3,0),Color3.fromRGB(128,108,68),Enum.Material.Cobblestone)
    P(D4,V3(8,2,8),CF(c4x,5,0),Color3.fromRGB(138,118,78),Enum.Material.Cobblestone)
    PL(Sph(D4,V3(5,5,5),CF(c4x,8.5,0),Color3.fromRGB(50,220,50),Enum.Material.Neon,0.12),Color3.fromRGB(50,220,50),5,38)
    for i=1,14 do
        Cyl(D4,V3(0.5,math.random(7,18),0.5),CF(c4x+math.random(-55,55),5,math.random(-55,55))*Ang(R(math.random(-18,18)),0,R(math.random(-12,12))),Color3.fromRGB(38,115,28),Enum.Material.Grass)
    end
    for i=1,9 do
        local mx=c4x+math.random(-48,48); local mz=math.random(-48,48)
        Cyl(D4,V3(1.5,4.5,1.5),CF(mx,3.25,mz),Color3.fromRGB(200,255,100),Enum.Material.Grass)
        PL(Sph(D4,V3(5.5,3.5,5.5),CF(mx,6,mz),Color3.fromRGB(180,255,80),Enum.Material.Neon,0.18),Color3.fromRGB(120,255,60),2,16)
    end
    BGui(P(D4,V3(0.1,0.1,0.1),CF(c4x,32,60),C.green,Enum.Material.Neon,1),"🌿 Jungle Ruins\nLv 50-70  |  ⭐⭐⭐⭐ Expert",V3(0,0,0),270,65,C.white,Color3.fromRGB(8,20,5),0.3)

    local D5=Mdl(Dngns,"GlacialKeep"); local c5x=2500
    mkRoom(D5,c5x,0,Color3.fromRGB(200,228,255),Color3.fromRGB(158,198,248),Color3.fromRGB(175,215,255),Enum.Material.Glacier,Enum.Material.Glacier,Color3.fromRGB(180,230,255))
    for i=1,16 do
        local isx=c5x+math.random(-52,52); local isz=math.random(-52,52); local ish=math.random(4,20)
        local isk=P(D5,V3(math.random(2,5),ish,math.random(2,5)),CF(isx,ish/2,isz)*Ang(R(math.random(-10,10)),0,R(math.random(-8,8))),Color3.fromRGB(198,232,255),Enum.Material.Glacier)
        if math.random()>0.5 then PL(isk,Color3.fromRGB(155,218,255),1,14) end
    end
    for i=0,5 do
        local a=R(i*60); local fpx=c5x+math.sin(a)*40; local fpz=math.cos(a)*40
        Cyl(D5,V3(5.5,24,5.5),CF(fpx,14,fpz),Color3.fromRGB(158,208,252),Enum.Material.Glacier)
        PL(Sph(D5,V3(3.5,3.5,3.5),CF(fpx,27,fpz),Color3.fromRGB(150,215,255),Enum.Material.Neon),Color3.fromRGB(138,200,255),3,26)
    end
    Sph(D5,V3(14,7,14),CF(c5x,5,0),Color3.fromRGB(178,228,255),Enum.Material.Glacier,0.35)
    PL(Sph(D5,V3(6,6,6),CF(c5x,5,0),Color3.fromRGB(100,185,255),Enum.Material.Neon,0.18),Color3.fromRGB(120,200,255),5,38)
    BGui(P(D5,V3(0.1,0.1,0.1),CF(c5x,32,60),C.iceB,Enum.Material.Neon,1),"❄ Glacial Keep\nLv 70-90  |  ⭐⭐⭐⭐⭐ Master",V3(0,0,0),280,65,C.white,Color3.fromRGB(5,15,30),0.3)

    local D6=Mdl(Dngns,"ShadowGate"); local c6x=3000
    mkRoom(D6,c6x,0,Color3.fromRGB(14,7,24),Color3.fromRGB(9,4,18),Color3.fromRGB(7,3,16),Enum.Material.SmoothPlastic,Enum.Material.SmoothPlastic,Color3.fromRGB(185,60,255))
    for i=1,14 do
        local crk=P(D6,V3(math.random(8,22),0.4,math.random(1,3)),CF(c6x+math.random(-52,52),2.3,math.random(-52,52))*Ang(0,R(math.random(0,180)),0),Color3.fromRGB(162,42,255),Enum.Material.Neon,0.18)
        PL(crk,Color3.fromRGB(142,28,255),1.5,16)
    end
    for i=0,5 do
        local a=R(i*60); local spx=c6x+math.sin(a)*44; local spz=math.cos(a)*44
        Cyl(D6,V3(7.5,26,7.5),CF(spx,15,spz),Color3.fromRGB(18,9,34),Enum.Material.SmoothPlastic)
        for j=1,3 do
            PL(P(D6,V3(5.5,1.2,0.5),CF(spx,j*7,spz-4.2),Color3.fromRGB(185,52,255),Enum.Material.Neon,0.28),Color3.fromRGB(165,38,255),1,11)
        end
    end
    local thx,thz=c6x,-42
    P(D6,V3(22,3,18),CF(thx,3.5,thz),Color3.fromRGB(14,7,30),Enum.Material.SmoothPlastic)
    P(D6,V3(15,4,13),CF(thx,7.5,thz),Color3.fromRGB(20,10,40),Enum.Material.SmoothPlastic)
    P(D6,V3(15,20,2.5),CF(thx,17,thz+6),Color3.fromRGB(12,6,28),Enum.Material.SmoothPlastic)
    P(D6,V3(2.5,3.5,12),CF(thx-7,12,thz),Color3.fromRGB(18,9,36),Enum.Material.SmoothPlastic)
    P(D6,V3(2.5,3.5,12),CF(thx+7,12,thz),Color3.fromRGB(18,9,36),Enum.Material.SmoothPlastic)
    PL(P(D6,V3(17,2,14),CF(thx,9.5,thz),Color3.fromRGB(145,32,255),Enum.Material.Neon,0.45),Color3.fromRGB(185,62,255),6,48)
    for i=1,10 do
        local crx=c6x+math.random(-48,48); local cry=math.random(8,22); local crz=math.random(-48,48)
        PL(P(D6,V3(2.5,9,2.5),CF(crx,cry,crz)*Ang(R(math.random(-30,30)),R(math.random(0,360)),0),Color3.fromRGB(155,32,255),Enum.Material.Neon,0.18),Color3.fromRGB(185,62,255),2,18)
    end
    for i=1,6 do
        PL(Sph(D6,V3(14,9,14),CF(c6x+math.random(-48,48),24,math.random(-48,48)),Color3.fromRGB(9,4,20),Enum.Material.SmoothPlastic,0.35),Color3.fromRGB(125,22,225),3,32)
    end
    local sgs=P(D6,V3(34,7,0.5),CF(c6x,17,61),Color3.fromRGB(75,5,160),Enum.Material.SmoothPlastic)
    SGui(sgs,"☠  SHADOW GATE  ☠\n— Inspired by Solo Leveling —",Enum.NormalId.Front,Color3.fromRGB(210,105,255),Color3.fromRGB(4,2,12))
    PL(sgs,Color3.fromRGB(185,62,255),3,32)
    BGui(P(D6,V3(0.1,0.1,0.1),CF(c6x,32,60),Color3.fromRGB(200,100,255),Enum.Material.Neon,1),"☠ Shadow Gate\nLv 90+  |  💀 EXTREME",V3(0,0,0),270,65,C.white,Color3.fromRGB(5,2,15),0.25)

    -- ─── SPAWN LOCATION ──────────────────────────────────────────────────────
    local sp=Instance.new("SpawnLocation")
    sp.Position=V3(0,3,75); sp.Size=V3(6,1,6); sp.Anchored=true
    sp.BrickColor=BrickColor.new("Gold"); sp.Material=Enum.Material.Neon
    sp.Transparency=0.6; sp.Duration=0; sp.Parent=Workspace

    print("[WorldBuilder] Dungeon Piece world built!")
end

return WorldBuilderModule
