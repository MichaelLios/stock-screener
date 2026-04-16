-- WorldBuilder.server.lua  ("Dungeon Piece")
-- Builds the persistent world: lobby island, portal zone, 6 dungeon rooms.
-- Idempotent — only runs once per server session.

local Workspace = game:GetService("Workspace")
local Lighting  = game:GetService("Lighting")

if Workspace:FindFirstChild("_DPWorldBuilt") then return end
local _g = Instance.new("BoolValue"); _g.Name = "_DPWorldBuilt"; _g.Parent = Workspace

-- ─── helpers ─────────────────────────────────────────────────────────────────
local function P(par, sz, cf, col, mat, trans)
    local p = Instance.new("Part")
    p.Anchored=true; p.Locked=true; p.CanCollide=true
    p.Size=sz; p.CFrame=cf; p.Color=col or Color3.fromRGB(160,160,160)
    p.Material=mat or Enum.Material.SmoothPlastic; p.Transparency=trans or 0
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    p.Parent=par; return p
end
local function W(par,sz,cf,col,mat)
    local p=Instance.new("WedgePart"); p.Anchored=true; p.Locked=true
    p.Size=sz; p.CFrame=cf; p.Color=col or Color3.fromRGB(160,160,160)
    p.Material=mat or Enum.Material.SmoothPlastic
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

-- ─── palette ─────────────────────────────────────────────────────────────────
local C={
    ocean  =Color3.fromRGB(20,80,170),  water =Color3.fromRGB(35,115,200),
    sand   =Color3.fromRGB(238,214,160),grass =Color3.fromRGB(84,175,84),
    stone  =Color3.fromRGB(130,130,135),dkSt  =Color3.fromRGB(85,85,90),
    cobble =Color3.fromRGB(115,115,120),wood  =Color3.fromRGB(145,95,50),
    dkWood =Color3.fromRGB(90,57,26),   bark  =Color3.fromRGB(100,65,30),
    gold   =Color3.fromRGB(255,200,50), orange=Color3.fromRGB(255,130,40),
    red    =Color3.fromRGB(205,42,42),  maroon=Color3.fromRGB(140,20,20),
    blue   =Color3.fromRGB(55,120,230), navy  =Color3.fromRGB(20,50,135),
    teal   =Color3.fromRGB(0,185,165),  cyan  =Color3.fromRGB(75,220,255),
    green  =Color3.fromRGB(50,165,50),  dkGrn =Color3.fromRGB(25,95,25),
    leaf   =Color3.fromRGB(60,175,60),  white =Color3.fromRGB(242,242,242),
    cream  =Color3.fromRGB(245,230,200),brown =Color3.fromRGB(118,77,38),
    purple =Color3.fromRGB(138,43,215), dkPurp=Color3.fromRGB(55,8,100),
    pink   =Color3.fromRGB(255,105,180),yellow=Color3.fromRGB(255,235,60),
    ice    =Color3.fromRGB(185,235,255),iceB  =Color3.fromRGB(100,180,255),
    silver =Color3.fromRGB(195,195,205),black =Color3.fromRGB(18,18,22),
    rust   =Color3.fromRGB(170,75,20),  coral =Color3.fromRGB(255,100,80),
    coralB =Color3.fromRGB(0,165,185),
}

-- ─── root models ─────────────────────────────────────────────────────────────
local World  = Mdl(Workspace,"DungeonPiece_World")
local Lobby  = Mdl(World,"Lobby")
local PZone  = Mdl(World,"PortalZone")
local Dngns  = Mdl(World,"Dungeons")

-- ─── LIGHTING ────────────────────────────────────────────────────────────────
Lighting.Brightness=2.2; Lighting.ClockTime=13.5
Lighting.FogEnd=3000; Lighting.FogColor=Color3.fromRGB(175,210,255)
Lighting.Ambient=Color3.fromRGB(90,110,145); Lighting.OutdoorAmbient=Color3.fromRGB(130,155,200)
if not Lighting:FindFirstChildOfClass("Atmosphere") then
    local atm=Instance.new("Atmosphere"); atm.Density=0.3; atm.Offset=0.25
    atm.Color=Color3.fromRGB(185,215,255); atm.Decay=Color3.fromRGB(80,130,200)
    atm.Glare=0.1; atm.Haze=0.5; atm.Parent=Lighting
end
if not Lighting:FindFirstChildOfClass("ColorCorrection") then
    local cc=Instance.new("ColorCorrection"); cc.Brightness=0.02
    cc.Contrast=0.08; cc.Saturation=0.15; cc.Parent=Lighting
end
if not Lighting:FindFirstChildOfClass("Bloom") then
    local bl=Instance.new("Bloom"); bl.Intensity=0.4; bl.Size=24; bl.Threshold=0.95; bl.Parent=Lighting
end

-- ─── OCEAN + ISLAND BASE ────────────────────────────────────────────────────
local terrain = Workspace.Terrain
-- Ocean
terrain:FillBlock(CF(0,-12,0), V3(3000,24,3000), Enum.Material.Water)
-- Sand beach
terrain:FillBlock(CF(0,-1,20), V3(320,6,420), Enum.Material.Sand)
-- Grass island (overwrites center of sand)
terrain:FillBlock(CF(0,0,20), V3(290,8,390), Enum.Material.Grass)

-- ─── STONE PATHS ─────────────────────────────────────────────────────────────
-- N-S main path to portals
P(Lobby, V3(14,1,310), CF(0,1.5,-35), C.cobble, Enum.Material.Cobblestone)
-- E-W cross path
P(Lobby, V3(220,1,12), CF(0,1.5,20), C.cobble, Enum.Material.Cobblestone)
-- Central plaza
P(Lobby, V3(64,1,64), CF(0,1.5,20), C.stone, Enum.Material.SmoothPlastic)
-- Diagonal corner paths
for _,a in ipairs({45,135,225,315}) do
    P(Lobby,V3(8,1,90), CF(math.sin(R(a))*55,1.5,20+math.cos(R(a))*55)*Ang(0,R(a),0), C.cobble, Enum.Material.Cobblestone)
end

-- ─── CENTRAL MONUMENT ───────────────────────────────────────────────────────
local Mon=Mdl(Lobby,"Monument")
P(Mon,V3(20,2,20),CF(0,2.5,20),C.dkSt,Enum.Material.Marble)
P(Mon,V3(14,2,14),CF(0,4.5,20),C.stone,Enum.Material.Marble)
Cyl(Mon,V3(5,8,5),CF(0,9.5,20),C.stone,Enum.Material.Marble)
local orb=Sph(Mon,V3(6,6,6),CF(0,14.5,20),C.gold,Enum.Material.Neon)
PL(orb,Color3.fromRGB(255,200,50),5,40)
for i=0,3 do
    local a=R(i*90+45); local sx,sz=math.sin(a)*8,20+math.cos(a)*8
    Cyl(Mon,V3(1.5,10,1.5),CF(sx,7,sz),C.dkSt,Enum.Material.SmoothPlastic)
    local sp=Sph(Mon,V3(2.5,2.5,2.5),CF(sx,12.5,sz),C.gold,Enum.Material.Neon)
    PL(sp,Color3.fromRGB(255,210,60),2,15)
end
-- "DUNGEON PIECE" sign post
Cyl(Mon,V3(1.2,18,1.2),CF(0,10,7),C.dkWood,Enum.Material.Wood)
local signB=P(Mon,V3(24,6,1),CF(0,20,7),C.dkWood,Enum.Material.Wood)
SGui(signB,"⚓  DUNGEON PIECE  ⚓",Enum.NormalId.Front,Color3.fromRGB(255,220,70),Color3.fromRGB(15,8,3))
SGui(signB,"⚓  DUNGEON PIECE  ⚓",Enum.NormalId.Back, Color3.fromRGB(255,220,70),Color3.fromRGB(15,8,3))
PL(signB,C.gold,3,28)

-- ─── BUILDINGS ───────────────────────────────────────────────────────────────
local function mkBuilding(par,cx,cz,bw,bd,bh,wc,rc,name,sign)
    local bm=Mdl(par,name)
    P(bm,V3(bw,1,bd),CF(cx,2,cz),C.stone,Enum.Material.SmoothPlastic)            -- floor
    P(bm,V3(bw,bh,1),CF(cx,2+bh/2,cz-bd/2),wc,Enum.Material.SmoothPlastic)      -- front wall
    P(bm,V3(bw,bh,1),CF(cx,2+bh/2,cz+bd/2),wc,Enum.Material.SmoothPlastic)      -- back wall
    P(bm,V3(1,bh,bd),CF(cx-bw/2,2+bh/2,cz),wc,Enum.Material.SmoothPlastic)      -- left
    P(bm,V3(1,bh,bd),CF(cx+bw/2,2+bh/2,cz),wc,Enum.Material.SmoothPlastic)      -- right
    -- door opening (black panel on front face, sized 5x8)
    P(bm,V3(5,8,0.6),CF(cx,6.5,cz-bd/2-0.1),C.black,Enum.Material.SmoothPlastic)
    -- roof
    P(bm,V3(bw+2,1,bd+2),CF(cx,2+bh+0.5,cz),rc,Enum.Material.SmoothPlastic)
    W(bm,V3(bw+2,5,bd/2+1),CF(cx,2+bh+3.5,cz-bd/4),rc,Enum.Material.SmoothPlastic)
    W(bm,V3(bw+2,5,bd/2+1),CF(cx,2+bh+3.5,cz+bd/4)*Ang(0,R(180),0),rc,Enum.Material.SmoothPlastic)
    if sign then
        local sp=P(bm,V3(bw*0.65,4,0.5),CF(cx,2+bh+1.5,cz-bd/2-0.5),C.dkWood,Enum.Material.Wood)
        SGui(sp,sign,Enum.NormalId.Front,C.gold,Color3.fromRGB(25,12,4))
        PL(sp,C.gold,2,18)
    end
end

mkBuilding(Lobby,-85,35,22,16,14,C.cream,C.maroon,"Shop","🛒  SHOP")
PL(P(Lobby,V3(1,1,1),CF(-85,9,35),C.gold,Enum.Material.Neon,1),Color3.fromRGB(255,210,130),3,28)

mkBuilding(Lobby,85,35,22,16,14,Color3.fromRGB(60,90,150),C.navy,"GuildHall","⚔  GUILD HALL")
PL(P(Lobby,V3(1,1,1),CF(85,9,35),C.blue,Enum.Material.Neon,1),Color3.fromRGB(130,180,255),3,28)

mkBuilding(Lobby,85,-30,20,14,12,C.dkSt,C.navy,"UpgradeStation","⚒  UPGRADES")
local forge=Sph(Lobby,V3(3,3,3),CF(85,5,-30),Color3.fromRGB(255,120,30),Enum.Material.Neon,0.2)
PL(forge,Color3.fromRGB(255,100,20),5,32)

-- Quest board (open structure)
local QB=Mdl(Lobby,"QuestBoard")
P(QB,V3(20,14,2),CF(90,10,-30),C.dkWood,Enum.Material.Wood)
Cyl(QB,V3(2,16,2),CF(79,9,-30),C.dkWood,Enum.Material.Wood)
Cyl(QB,V3(2,16,2),CF(101,9,-30),C.dkWood,Enum.Material.Wood)
local qbf=P(QB,V3(18,11,0.5),CF(90,10,-29),C.cream,Enum.Material.SmoothPlastic)
SGui(qbf,"📋  QUEST BOARD\n✦ Daily Missions\n✦ Boss Hunts\n✦ Dungeon Clears",
    Enum.NormalId.Front,Color3.fromRGB(50,25,8),Color3.fromRGB(235,215,170))
PL(qbf,Color3.fromRGB(255,230,160),2,20)

-- Leaderboard tower
local LB=Mdl(Lobby,"Leaderboard")
P(LB,V3(4,30,4),CF(-85,-30,-30),C.dkSt,Enum.Material.SmoothPlastic)
P(LB,V3(26,22,2),CF(-85,13,-30),C.navy,Enum.Material.SmoothPlastic)
local lbf=P(LB,V3(24,20,0.5),CF(-85,13,-28.8),C.black,Enum.Material.SmoothPlastic)
SGui(lbf,"🏆  TOP PIRATES\n\n#1  ???\n#2  ???\n#3  ???",
    Enum.NormalId.Front,Color3.fromRGB(255,215,50),Color3.fromRGB(5,5,15))
PL(lbf,Color3.fromRGB(160,190,255),2,24)
Sph(LB,V3(5,5,5),CF(-85,29,-30),C.gold,Enum.Material.Neon)
PL(P(LB,V3(1,1,1),CF(-85,29,-30),C.gold,Enum.Material.Neon,1),C.gold,4,30)

-- Party / gathering deck
local Pty=Mdl(Lobby,"PartyDeck")
P(Pty,V3(44,1,22),CF(0,1.5,110),C.dkWood,Enum.Material.Wood)
for _,x in ipairs({-21,21}) do
    for z=-9,9,6 do
        Cyl(Pty,V3(1.2,5,1.2),CF(x,4.5,110+z),C.wood,Enum.Material.Wood)
    end
    P(Pty,V3(1,1,22),CF(x,7.5,110),C.wood,Enum.Material.Wood)
end
local ptySign=P(Pty,V3(20,4,0.5),CF(0,8,98.8),C.dkWood,Enum.Material.Wood)
SGui(ptySign,"🎉  PARTY ZONE  🎉",Enum.NormalId.Front,C.yellow,Color3.fromRGB(20,10,5))
for _,ox in ipairs({-15,0,15}) do
    Cyl(Pty,V3(1.2,10,1.2),CF(ox,7,110),C.dkWood,Enum.Material.Wood)
    local ln=P(Pty,V3(2.5,2.5,2.5),CF(ox,12.5,110),C.orange,Enum.Material.Neon,0.15)
    PL(ln,C.orange,3,22)
end

-- Training Zone
local Trn=Mdl(Lobby,"TrainingZone")
P(Trn,V3(38,1,30),CF(-85,1.5,70),C.dkSt,Enum.Material.SmoothPlastic)
local trnSign=P(Trn,V3(20,4,0.5),CF(-85,6,55.8),C.dkWood,Enum.Material.Wood)
SGui(trnSign,"⚔  TRAINING ZONE",Enum.NormalId.Front,C.gold,Color3.fromRGB(12,8,4))
for i=0,4 do
    local dx=-100+i*9
    Cyl(Trn,V3(3,9,3),CF(dx,6.5,70),C.brown,Enum.Material.SmoothPlastic)
    Sph(Trn,V3(4.5,4.5,4.5),CF(dx,12,70),C.sand,Enum.Material.SmoothPlastic)
    P(Trn,V3(9,1.5,1.5),CF(dx,8,70),C.brown,Enum.Material.SmoothPlastic)
    Cyl(Trn,V3(1.5,13,1.5),CF(dx,2,70),C.dkWood,Enum.Material.Wood)
end

-- ─── MARKET STALLS ───────────────────────────────────────────────────────────
local function mkStall(par,cx,cz,col,label)
    local sm=Mdl(par,"Stall_"..label)
    for _,ox in ipairs({-5,5}) do
        Cyl(sm,V3(1.2,7,1.2),CF(cx+ox,4.5,cz-2.5),C.dkWood,Enum.Material.Wood)
        Cyl(sm,V3(1.2,7,1.2),CF(cx+ox,4.5,cz+2.5),C.dkWood,Enum.Material.Wood)
    end
    P(sm,V3(13,1,8),CF(cx,8.5,cz),col,Enum.Material.SmoothPlastic)
    W(sm,V3(13,2.5,3),CF(cx,7.3,cz-5.5),col,Enum.Material.SmoothPlastic)
    P(sm,V3(11,2,3.5),CF(cx,4,cz-2),C.wood,Enum.Material.Wood)
    local lp=P(sm,V3(0.1,0.1,0.1),CF(cx,9.5,cz),col,Enum.Material.Neon,1)
    BGui(lp,label,V3(0,0.5,0),160,38,C.white,Color3.fromRGB(5,5,12),0.4)
end

mkStall(Lobby,-50,55,C.red,    "⚓ Weapons")
mkStall(Lobby, 50,55,C.blue,   "🛡 Armor")
mkStall(Lobby,-50,-15,C.teal,  "✨ Abilities")
mkStall(Lobby, 50,-15,C.purple,"💎 Rare Items")

-- ─── PALM TREES ──────────────────────────────────────────────────────────────
local Trees=Mdl(Lobby,"Trees")
local function mkPalm(par,cx,cz)
    local tm=Mdl(par,"Palm")
    Cyl(tm,V3(2.5,10,2.5),CF(cx,6,cz)*Ang(0,0,R(4)),C.bark,Enum.Material.Wood)
    Cyl(tm,V3(2,5,2),CF(cx+0.6,13,cz)*Ang(0,0,R(9)),C.bark,Enum.Material.Wood)
    for i=0,6 do
        local a=R(i*(360/7))
        P(tm,V3(7,0.5,2.5),CF(cx+1+math.sin(a)*4.5,16-math.abs(math.sin(a))*0.5,cz+math.cos(a)*4.5)*Ang(0,a+R(15),R(-18)),C.leaf,Enum.Material.Grass)
    end
    Sph(tm,V3(6,4,6),CF(cx+1,17,cz),C.leaf,Enum.Material.Grass)
    for i=0,2 do
        local a=R(i*120)
        Sph(tm,V3(1.5,1.5,1.5),CF(cx+1+math.sin(a)*1.5,15,cz+math.cos(a)*1.5),C.brown,Enum.Material.SmoothPlastic)
    end
end
for _,pos in ipairs({
    {-120,-60},{120,-60},{-130,60},{130,60},{-108,108},{108,108},
    {-100,-80},{100,-80},{-140,20},{140,20},{-50,-80},{50,-80},
    {0,128},{-65,118},{65,118},{-15,-90},{15,-90}
}) do mkPalm(Trees,pos[1],pos[2]) end

-- ─── PROPS: barrels, lanterns, banners ───────────────────────────────────────
local Props=Mdl(Lobby,"Props")
local function mkBarrel(par,cx,cz,ry)
    local bm=Mdl(par,"Barrel")
    Cyl(bm,V3(3,3.5,3),CF(cx,3.25,cz)*Ang(0,ry or 0,0),C.dkWood,Enum.Material.Wood)
    for _,y in ipairs({2,3.25,4.5}) do
        Cyl(bm,V3(3.3,0.4,3.3),CF(cx,y,cz),C.brown,Enum.Material.Metal)
    end
end
local function mkLantern(par,cx,cz,col)
    local lm=Mdl(par,"Lantern"); col=col or C.gold
    Cyl(lm,V3(1,13,1),CF(cx,7.5,cz),C.dkSt,Enum.Material.Metal)
    local gw=P(lm,V3(2.2,2.2,2.2),CF(cx,14.5,cz),col,Enum.Material.Neon,0.1)
    P(lm,V3(3,1,3),CF(cx,15.7,cz),C.dkSt,Enum.Material.Metal)
    PL(gw,col,3,26)
end
local function mkBanner(par,cx,cz,col,txt)
    local bm=Mdl(par,"Banner")
    Cyl(bm,V3(1.2,22,1.2),CF(cx,12,cz),C.dkSt,Enum.Material.Metal)
    P(bm,V3(8,10,0.5),CF(cx+4.5,19,cz),col,Enum.Material.SmoothPlastic)
    Sph(bm,V3(2.5,2.5,2.5),CF(cx,23.5,cz),C.gold,Enum.Material.Neon)
    if txt then
        local tp=P(bm,V3(0.1,0.1,0.1),CF(cx+4.5,19,cz-0.5),col,Enum.Material.Neon,1)
        BGui(tp,txt,V3(0,0,-3),70,80,C.white,col,0.3)
    end
end

for _,bc in ipairs({{-62,-55},{62,-55},{-70,65},{70,65},{38,102},{-38,102}}) do
    mkBarrel(Props,bc[1],bc[2],0); mkBarrel(Props,bc[1]+4,bc[2]+2,R(28)); mkBarrel(Props,bc[1]+2,bc[2]-3,R(-12))
end
for z=-125,90,32 do
    mkLantern(Props,-9,z,C.gold); mkLantern(Props,9,z,C.gold)
end
for _,x in ipairs({-105,-70,70,105}) do mkLantern(Props,x,20,C.orange) end

mkBanner(Props,-28,-112,C.red,   "⚓"); mkBanner(Props,28,-112,C.blue,"⚓")
mkBanner(Props,-28,118,C.maroon,"⚔"); mkBanner(Props,28,118,C.navy, "⚔")
mkBanner(Props,-118,-8,C.orange,"🏴");mkBanner(Props,118,-8,C.purple,"🏴")

-- ─── WOODEN DOCKS ────────────────────────────────────────────────────────────
local Docks=Mdl(Lobby,"Docks")
local function mkDockSection(par,cx,cz)
    P(par,V3(8,1,5),CF(cx,1.5,cz),C.dkWood,Enum.Material.Wood)
    for _,ox in ipairs({-3.5,3.5}) do
        for _,oz in ipairs({-2,2}) do
            Cyl(par,V3(1,5,1),CF(cx+ox,4.5,cz+oz),C.wood,Enum.Material.Wood)
        end
    end
    P(par,V3(8,0.5,1),CF(cx,7,cz-2),C.wood,Enum.Material.Wood)
    P(par,V3(8,0.5,1),CF(cx,7,cz+2),C.wood,Enum.Material.Wood)
end
for _,dx in ipairs({-40,-20,20,40}) do
    for z=150,185,5 do mkDockSection(Docks,dx,z) end
    Cyl(Docks,V3(2,6,2),CF(dx,4,188),C.dkWood,Enum.Material.Wood)
end

-- Simple ships
for _,sx in ipairs({-55,55}) do
    local Shp=Mdl(Docks,"Ship_"..sx)
    P(Shp,V3(14,7,30),CF(sx,0.5,200),C.dkWood,Enum.Material.Wood)
    P(Shp,V3(14,1,28),CF(sx,4,200),C.wood,Enum.Material.Wood)
    Cyl(Shp,V3(1.5,24,1.5),CF(sx,14.5,194),C.dkWood,Enum.Material.Wood)
    Cyl(Shp,V3(1.5,16,1.5),CF(sx,10.5,206),C.dkWood,Enum.Material.Wood)
    P(Shp,V3(12,15,0.5),CF(sx,17,194),C.white,Enum.Material.SmoothPlastic)
    P(Shp,V3(10,11,0.5),CF(sx,10,206),C.maroon,Enum.Material.SmoothPlastic)
    local flag=P(Shp,V3(4,3,0.3),CF(sx,27,194),C.black,Enum.Material.SmoothPlastic)
    SGui(flag,"☠",Enum.NormalId.Front,C.white,C.black)
end

-- ─── PORTAL ZONE ─────────────────────────────────────────────────────────────
-- Grand entrance archway
P(PZone,V3(64,2,4),CF(0,2,-116),C.dkSt,Enum.Material.SmoothPlastic)
Cyl(PZone,V3(4,26,4),CF(-30,15,-116),C.stone,Enum.Material.SmoothPlastic)
Cyl(PZone,V3(4,26,4),CF( 30,15,-116),C.stone,Enum.Material.SmoothPlastic)
P(PZone,V3(64,6,4),CF(0,29,-116),C.stone,Enum.Material.SmoothPlastic)
local archGlow=P(PZone,V3(50,2,0.8),CF(0,29,-115.5),C.gold,Enum.Material.Neon,0.15)
PL(archGlow,C.gold,3,35)
local archSign=P(PZone,V3(32,5,1),CF(0,31,-115.3),C.dkWood,Enum.Material.Wood)
SGui(archSign,"⚔  DUNGEON PORTALS  ⚔",Enum.NormalId.Front,C.gold,Color3.fromRGB(8,4,2))
PL(archSign,C.gold,2,25)

-- Portal ground slab
P(PZone,V3(210,1,115),CF(0,1.5,-168),C.dkSt,Enum.Material.SmoothPlastic)
-- Rune ring
for i=0,11 do
    local a=R(i*30)
    Sph(PZone,V3(2,2,2),CF(math.sin(a)*95,2,-168+math.cos(a)*45),C.gold,Enum.Material.Neon,0.25)
end
-- Torches
for _,tx in ipairs({-95,-65,-35,35,65,95}) do
    Cyl(PZone,V3(1.5,9,1.5),CF(tx,5.5,-117),C.dkSt,Enum.Material.Metal)
    local fl=Sph(PZone,V3(2.8,3.5,2.8),CF(tx,10.5,-117),C.orange,Enum.Material.Neon,0.1)
    PL(fl,Color3.fromRGB(255,135,30),4,24)
end

-- Dungeon definitions
local DDATA = {
    {name="Coral Lagoon",  level="Lv 1-15",  diff="⭐ Easy",       portalCol=Color3.fromRGB(0,185,165),  glow=Color3.fromRGB(100,255,220), pos=V3(1000,0,0)},
    {name="Pirate Cove",   level="Lv 15-30", diff="⭐⭐ Normal",    portalCol=Color3.fromRGB(195,90,20),  glow=Color3.fromRGB(255,165,60),  pos=V3(2000,0,0)},
    {name="Thunder Peak",  level="Lv 30-50", diff="⭐⭐⭐ Hard",     portalCol=Color3.fromRGB(60,110,230), glow=Color3.fromRGB(150,210,255), pos=V3(3000,0,0)},
    {name="Jungle Ruins",  level="Lv 50-70", diff="⭐⭐⭐⭐ Expert",  portalCol=Color3.fromRGB(40,140,40),  glow=Color3.fromRGB(80,255,80),   pos=V3(4000,0,0)},
    {name="Glacial Keep",  level="Lv 70-90", diff="⭐⭐⭐⭐⭐ Master", portalCol=Color3.fromRGB(120,185,255),glow=Color3.fromRGB(200,235,255), pos=V3(5000,0,0)},
    {name="Shadow Gate",   level="Lv 90+",   diff="💀 EXTREME",     portalCol=Color3.fromRGB(120,20,220), glow=Color3.fromRGB(210,110,255), pos=V3(6000,0,0)},
}

-- Portal positions: 2 rows of 3
local PPOS = {
    {x=-75,z=-155},{x=0,z=-155},{x=75,z=-155},
    {x=-75,z=-182},{x=0,z=-182},{x=75,z=-182},
}

for i,dd in ipairs(DDATA) do
    local pp=PPOS[i]; local px,pz=pp.x,pp.z
    local pm=Mdl(PZone,"Portal_"..dd.name)
    local fw,fh=10,15
    -- Pillars
    Cyl(pm,V3(3.5,fh+5,3.5),CF(px-fw/2-2,((fh+5)/2)+1,pz),C.dkSt,Enum.Material.SmoothPlastic)
    Cyl(pm,V3(3.5,fh+5,3.5),CF(px+fw/2+2,((fh+5)/2)+1,pz),C.dkSt,Enum.Material.SmoothPlastic)
    Sph(pm,V3(4.5,4.5,4.5),CF(px-fw/2-2,fh+8,pz),dd.portalCol,Enum.Material.Neon)
    Sph(pm,V3(4.5,4.5,4.5),CF(px+fw/2+2,fh+8,pz),dd.portalCol,Enum.Material.Neon)
    PL(Sph(pm,V3(1,1,1),CF(px-fw/2-2,fh+8,pz),dd.glow,Enum.Material.Neon,1),dd.glow,3,18)
    PL(Sph(pm,V3(1,1,1),CF(px+fw/2+2,fh+8,pz),dd.glow,Enum.Material.Neon,1),dd.glow,3,18)
    -- Arch top
    P(pm,V3(fw+8,3.5,3.5),CF(px,fh+3,pz),C.stone,Enum.Material.SmoothPlastic)
    -- Portal inner frame
    P(pm,V3(fw,2,2),CF(px,1.5,pz),C.stone,Enum.Material.SmoothPlastic)
    P(pm,V3(2,fh,2),CF(px-fw/2+1,1+fh/2,pz),C.stone,Enum.Material.SmoothPlastic)
    P(pm,V3(2,fh,2),CF(px+fw/2-1,1+fh/2,pz),C.stone,Enum.Material.SmoothPlastic)
    -- Portal surface (glowing)
    local surf=P(pm,V3(fw-2,fh-1,0.4),CF(px,1.5+fh/2,pz),dd.portalCol,Enum.Material.Neon,0.22)
    PL(surf,dd.glow,5,38)
    -- Floating nameplate
    local np=P(pm,V3(0.1,0.1,0.1),CF(px,fh+11,pz),dd.glow,Enum.Material.Neon,1)
    BGui(np,dd.name.."\n"..dd.level.."  |  "..dd.diff,V3(0,0,0),230,62,
        C.white,Color3.fromRGB(4,4,14),0.3)
    PL(np,dd.glow,2,16)
end

-- ─── DUNGEON ROOMS ────────────────────────────────────────────────────────────
local function mkRoom(par,cx,cz,fc,wc,cc,fm,wm,ac)
    local dm=Mdl(par,"Room")
    local RW,RD,RH=120,120,28
    -- Floor, ceiling, walls (with south door gap)
    P(dm,V3(RW,2,RD),CF(cx,1,cz),fc,fm)
    P(dm,V3(RW+2,2,RD+2),CF(cx,RH+2,cz),cc,wm)
    P(dm,V3(RW+2,RH,2),CF(cx,2+RH/2,cz-RD/2),wc,wm)       -- north
    P(dm,V3((RW-16)/2,RH,2),CF(cx-(RW+16)/4,2+RH/2,cz+RD/2),wc,wm)  -- south L
    P(dm,V3((RW-16)/2,RH,2),CF(cx+(RW+16)/4,2+RH/2,cz+RD/2),wc,wm)  -- south R
    P(dm,V3(16,RH-18,2),CF(cx,RH-7,cz+RD/2),wc,wm)         -- south above door
    P(dm,V3(2,RH,RD+2),CF(cx-RW/2-1,2+RH/2,cz),wc,wm)     -- west
    P(dm,V3(2,RH,RD+2),CF(cx+RW/2+1,2+RH/2,cz),wc,wm)     -- east
    -- Atmosphere lights
    for li=0,3 do
        local a=R(li*90+45)
        local lp=P(dm,V3(2,2,2),CF(cx+math.sin(a)*(RW/2-12),RH,cz+math.cos(a)*(RD/2-12)),ac,Enum.Material.Neon,0.18)
        PL(lp,ac,4,65)
    end
    PL(P(dm,V3(3,3,3),CF(cx,RH-1,cz),ac,Enum.Material.Neon,0.18),ac,5,85)
    return dm
end

-- ── Dungeon 1: Coral Lagoon ──
local D1=Mdl(Dngns,"CoralLagoon"); local c1x=1000
mkRoom(D1,c1x,0,Color3.fromRGB(15,120,130),Color3.fromRGB(10,80,95),Color3.fromRGB(8,70,85),
    Enum.Material.SmoothPlastic,Enum.Material.SmoothPlastic,Color3.fromRGB(0,220,200))
-- Coral pillars
for i=0,6 do
    local a=R(i*(360/7)); local cpx=c1x+math.sin(a)*40
    Cyl(D1,V3(4,18,4),CF(cpx,11,math.cos(a)*40),Color3.fromRGB(255,100,100),Enum.Material.SmoothPlastic)
    Sph(D1,V3(7,5,7),CF(cpx,21,math.cos(a)*40),Color3.fromRGB(255,130,110),Enum.Material.SmoothPlastic)
    PL(Sph(D1,V3(1,1,1),CF(cpx,21,math.cos(a)*40),Color3.fromRGB(255,140,120),Enum.Material.Neon,1),Color3.fromRGB(255,180,160),2,18)
end
-- Water pools
for i=1,5 do
    local wx=c1x+math.random(-38,38); local wz=math.random(-38,38)
    P(D1,V3(10,0.5,10),CF(wx,1.4,wz),Color3.fromRGB(30,160,210),Enum.Material.Neon,0.5)
    PL(P(D1,V3(1,1,1),CF(wx,2,wz),Color3.fromRGB(30,160,210),Enum.Material.Neon,1),Color3.fromRGB(30,200,255),2,20)
end
-- Treasure chests
for i=1,4 do
    local tx=c1x+math.random(-35,35); local tz=math.random(-35,35)
    P(D1,V3(4,3,3),CF(tx,3.5,tz),C.dkWood,Enum.Material.Wood)
    P(D1,V3(4,1.5,3.1),CF(tx,5.1,tz),C.brown,Enum.Material.Wood)
    P(D1,V3(2,1,0.5),CF(tx,3.8,tz-1.7),C.gold,Enum.Material.Neon)
end
local d1np=P(D1,V3(0.1,0.1,0.1),CF(c1x,32,60),C.teal,Enum.Material.Neon,1)
BGui(d1np,"🪸 Coral Lagoon\nLv 1-15  |  ⭐ Easy",V3(0,0,0),260,65,C.white,Color3.fromRGB(0,50,55),0.3)

-- ── Dungeon 2: Pirate Cove ──
local D2=Mdl(Dngns,"PirateCove"); local c2x=2000
mkRoom(D2,c2x,0,Color3.fromRGB(80,55,25),Color3.fromRGB(55,38,18),Color3.fromRGB(35,22,10),
    Enum.Material.Wood,Enum.Material.SmoothPlastic,Color3.fromRGB(255,150,50))
-- Wrecked ship hull
P(D2,V3(32,8,16),CF(c2x-22,6,0)*Ang(0,R(18),R(7)),C.dkWood,Enum.Material.Wood)
Cyl(D2,V3(2,22,2),CF(c2x-18,13,-8),C.dkWood,Enum.Material.Wood)
P(D2,V3(15,0.5,10),CF(c2x-18,24,-8)*Ang(0,0,R(-28)),C.white,Enum.Material.SmoothPlastic)
-- Chains
for i=0,4 do
    Cyl(D2,V3(1.5,9,1.5),CF(c2x-40+i*20,5.5,-42),C.silver,Enum.Material.Metal)
    if i<4 then P(D2,V3(20,1,1),CF(c2x-30+i*20,10,-42),C.silver,Enum.Material.Metal) end
end
-- Gold pile
local gp=Sph(D2,V3(10,5,10),CF(c2x,4,0),C.gold,Enum.Material.Neon,0.25)
PL(gp,C.gold,6,32)
for i=1,10 do Sph(D2,V3(1.5,1.5,1.5),CF(c2x+math.random(-5,5),3,math.random(-5,5)),C.gold,Enum.Material.Neon,0.1) end
-- Barrels
for i=1,14 do Cyl(D2,V3(3,3.5,3),CF(c2x+math.random(-50,50),3.25,math.random(-50,50)),C.dkWood,Enum.Material.Wood) end
local d2np=P(D2,V3(0.1,0.1,0.1),CF(c2x,32,60),C.rust,Enum.Material.Neon,1)
BGui(d2np,"☠ Pirate Cove\nLv 15-30  |  ⭐⭐ Normal",V3(0,0,0),260,65,C.white,Color3.fromRGB(30,15,5),0.3)

-- ── Dungeon 3: Thunder Peak ──
local D3=Mdl(Dngns,"ThunderPeak"); local c3x=3000
mkRoom(D3,c3x,0,Color3.fromRGB(65,65,78),Color3.fromRGB(48,48,60),Color3.fromRGB(30,30,42),
    Enum.Material.Slate,Enum.Material.SmoothPlastic,Color3.fromRGB(110,170,255))
for i=0,6 do
    local a=R(i*(360/7)); local rpx=c3x+math.sin(a)*38; local rpz=math.cos(a)*38
    local rh=math.random(12,22)
    Cyl(D3,V3(5+math.random(0,3),rh,5+math.random(0,3)),CF(rpx,rh/2,rpz),Color3.fromRGB(78,78,90),Enum.Material.Slate)
    Cyl(D3,V3(0.8,6,0.8),CF(rpx,rh+4,rpz),C.silver,Enum.Material.Metal)
    local eg=Sph(D3,V3(2.5,2.5,2.5),CF(rpx,rh+7.5,rpz),Color3.fromRGB(160,210,255),Enum.Material.Neon)
    PL(eg,Color3.fromRGB(130,190,255),4,26)
end
-- Storm ceiling clouds
for i=1,5 do
    local csx=c3x+math.random(-45,45); local csz=math.random(-45,45)
    Sph(D3,V3(18,7,18),CF(csx,24,csz),Color3.fromRGB(52,52,68),Enum.Material.SmoothPlastic,0.28)
    local lb=P(D3,V3(1,14,1),CF(csx,17,csz)*Ang(0,0,R(math.random(-18,18))),Color3.fromRGB(210,230,255),Enum.Material.Neon,0.35)
    PL(lb,Color3.fromRGB(180,215,255),3,22)
end
-- Electric floor marks
for i=1,10 do
    P(D3,V3(math.random(6,18),0.3,math.random(1,3)),CF(c3x+math.random(-48,48),2.3,math.random(-48,48))*Ang(0,R(math.random(0,180)),0),Color3.fromRGB(100,185,255),Enum.Material.Neon,0.45)
end
local d3np=P(D3,V3(0.1,0.1,0.1),CF(c3x,32,60),C.blue,Enum.Material.Neon,1)
BGui(d3np,"⚡ Thunder Peak\nLv 30-50  |  ⭐⭐⭐ Hard",V3(0,0,0),260,65,C.white,Color3.fromRGB(10,15,35),0.3)

-- ── Dungeon 4: Jungle Ruins ──
local D4=Mdl(Dngns,"JungleRuins"); local c4x=4000
mkRoom(D4,c4x,0,Color3.fromRGB(38,82,28),Color3.fromRGB(50,88,38),Color3.fromRGB(28,68,18),
    Enum.Material.Grass,Enum.Material.SmoothPlastic,Color3.fromRGB(80,230,80))
for i=0,5 do
    local a=R(i*60); local tpx=c4x+math.sin(a)*36; local tpz=math.cos(a)*36
    Cyl(D4,V3(5.5,20,5.5),CF(tpx,12,tpz),Color3.fromRGB(118,98,58),Enum.Material.Cobblestone)
    local rp=P(D4,V3(3.5,3.5,0.5),CF(tpx,7,tpz-3),Color3.fromRGB(80,255,80),Enum.Material.Neon,0.28)
    PL(rp,Color3.fromRGB(80,255,80),2,20)
end
-- Stone altar
P(D4,V3(13,2,13),CF(c4x,3,0),Color3.fromRGB(128,108,68),Enum.Material.Cobblestone)
P(D4,V3(8,2,8),CF(c4x,5,0),Color3.fromRGB(138,118,78),Enum.Material.Cobblestone)
local agl=Sph(D4,V3(5,5,5),CF(c4x,8.5,0),Color3.fromRGB(50,220,50),Enum.Material.Neon,0.12)
PL(agl,Color3.fromRGB(50,220,50),5,38)
-- Vines
for i=1,14 do
    Cyl(D4,V3(0.5,math.random(7,18),0.5),CF(c4x+math.random(-55,55),5,math.random(-55,55))*Ang(R(math.random(-18,18)),0,R(math.random(-12,12))),Color3.fromRGB(38,115,28),Enum.Material.Grass)
end
-- Glowing mushrooms
for i=1,9 do
    local mx=c4x+math.random(-48,48); local mz=math.random(-48,48)
    Cyl(D4,V3(1.5,4.5,1.5),CF(mx,3.25,mz),Color3.fromRGB(200,255,100),Enum.Material.Grass)
    local mc=Sph(D4,V3(5.5,3.5,5.5),CF(mx,6,mz),Color3.fromRGB(180,255,80),Enum.Material.Neon,0.18)
    PL(mc,Color3.fromRGB(120,255,60),2,16)
end
local d4np=P(D4,V3(0.1,0.1,0.1),CF(c4x,32,60),C.green,Enum.Material.Neon,1)
BGui(d4np,"🌿 Jungle Ruins\nLv 50-70  |  ⭐⭐⭐⭐ Expert",V3(0,0,0),270,65,C.white,Color3.fromRGB(8,20,5),0.3)

-- ── Dungeon 5: Glacial Keep ──
local D5=Mdl(Dngns,"GlacialKeep"); local c5x=5000
mkRoom(D5,c5x,0,Color3.fromRGB(200,228,255),Color3.fromRGB(158,198,248),Color3.fromRGB(175,215,255),
    Enum.Material.Glacier,Enum.Material.Glacier,Color3.fromRGB(180,230,255))
-- Ice spikes
for i=1,16 do
    local isx=c5x+math.random(-52,52); local isz=math.random(-52,52); local ish=math.random(4,20)
    local isk=P(D5,V3(math.random(2,5),ish,math.random(2,5)),CF(isx,ish/2,isz)*Ang(R(math.random(-10,10)),0,R(math.random(-8,8))),Color3.fromRGB(198,232,255),Enum.Material.Glacier)
    if math.random()>0.5 then PL(isk,Color3.fromRGB(155,218,255),1,14) end
end
-- Ice pillars
for i=0,5 do
    local a=R(i*60); local fpx=c5x+math.sin(a)*40; local fpz=math.cos(a)*40
    Cyl(D5,V3(5.5,24,5.5),CF(fpx,14,fpz),Color3.fromRGB(158,208,252),Enum.Material.Glacier)
    local ig=Sph(D5,V3(3.5,3.5,3.5),CF(fpx,27,fpz),Color3.fromRGB(150,215,255),Enum.Material.Neon)
    PL(ig,Color3.fromRGB(138,200,255),3,26)
end
-- Frozen centerpiece
Sph(D5,V3(14,7,14),CF(c5x,5,0),Color3.fromRGB(178,228,255),Enum.Material.Glacier,0.35)
local fcg=Sph(D5,V3(6,6,6),CF(c5x,5,0),Color3.fromRGB(100,185,255),Enum.Material.Neon,0.18)
PL(fcg,Color3.fromRGB(120,200,255),5,38)
local d5np=P(D5,V3(0.1,0.1,0.1),CF(c5x,32,60),C.iceB,Enum.Material.Neon,1)
BGui(d5np,"❄ Glacial Keep\nLv 70-90  |  ⭐⭐⭐⭐⭐ Master",V3(0,0,0),280,65,C.white,Color3.fromRGB(5,15,30),0.3)

-- ── Dungeon 6: Shadow Gate (Solo Leveling) ──
local D6=Mdl(Dngns,"ShadowGate"); local c6x=6000
mkRoom(D6,c6x,0,Color3.fromRGB(14,7,24),Color3.fromRGB(9,4,18),Color3.fromRGB(7,3,16),
    Enum.Material.SmoothPlastic,Enum.Material.SmoothPlastic,Color3.fromRGB(185,60,255))
-- Void cracks in floor
for i=1,14 do
    local crk=P(D6,V3(math.random(8,22),0.4,math.random(1,3)),
        CF(c6x+math.random(-52,52),2.3,math.random(-52,52))*Ang(0,R(math.random(0,180)),0),
        Color3.fromRGB(162,42,255),Enum.Material.Neon,0.18)
    PL(crk,Color3.fromRGB(142,28,255),1.5,16)
end
-- Shadow pillars with runes
for i=0,5 do
    local a=R(i*60); local spx=c6x+math.sin(a)*44; local spz=math.cos(a)*44
    Cyl(D6,V3(7.5,26,7.5),CF(spx,15,spz),Color3.fromRGB(18,9,34),Enum.Material.SmoothPlastic)
    for j=1,3 do
        local rp=P(D6,V3(5.5,1.2,0.5),CF(spx,j*7,spz-4.2),Color3.fromRGB(185,52,255),Enum.Material.Neon,0.28)
        PL(rp,Color3.fromRGB(165,38,255),1,11)
    end
end
-- Shadow Monarch Throne
local thx,thz=c6x,-42
P(D6,V3(22,3,18),CF(thx,3.5,thz),Color3.fromRGB(14,7,30),Enum.Material.SmoothPlastic)
P(D6,V3(15,4,13),CF(thx,7.5,thz),Color3.fromRGB(20,10,40),Enum.Material.SmoothPlastic)
P(D6,V3(15,20,2.5),CF(thx,17,thz+6),Color3.fromRGB(12,6,28),Enum.Material.SmoothPlastic)
P(D6,V3(2.5,3.5,12),CF(thx-7,12,thz),Color3.fromRGB(18,9,36),Enum.Material.SmoothPlastic)
P(D6,V3(2.5,3.5,12),CF(thx+7,12,thz),Color3.fromRGB(18,9,36),Enum.Material.SmoothPlastic)
local tcg=P(D6,V3(17,2,14),CF(thx,9.5,thz),Color3.fromRGB(145,32,255),Enum.Material.Neon,0.45)
PL(tcg,Color3.fromRGB(185,62,255),6,48)
-- Floating dark crystals
for i=1,10 do
    local crx=c6x+math.random(-48,48); local cry=math.random(8,22); local crz=math.random(-48,48)
    local crp=P(D6,V3(2.5,9,2.5),CF(crx,cry,crz)*Ang(R(math.random(-30,30)),R(math.random(0,360)),0),
        Color3.fromRGB(155,32,255),Enum.Material.Neon,0.18)
    PL(crp,Color3.fromRGB(185,62,255),2,18)
end
-- Ceiling void swirls
for i=1,6 do
    local vs=Sph(D6,V3(14,9,14),CF(c6x+math.random(-48,48),24,math.random(-48,48)),
        Color3.fromRGB(9,4,20),Enum.Material.SmoothPlastic,0.35)
    PL(vs,Color3.fromRGB(125,22,225),3,32)
end
-- "SHADOW GATE" sign + Solo Leveling tribute
local sgs=P(D6,V3(34,7,0.5),CF(c6x,17,61),Color3.fromRGB(75,5,160),Enum.Material.SmoothPlastic)
SGui(sgs,"☠  SHADOW GATE  ☠\n— Inspired by Solo Leveling —",Enum.NormalId.Front,Color3.fromRGB(210,105,255),Color3.fromRGB(4,2,12))
PL(sgs,Color3.fromRGB(185,62,255),3,32)
local d6np=P(D6,V3(0.1,0.1,0.1),CF(c6x,32,60),Color3.fromRGB(200,100,255),Enum.Material.Neon,1)
BGui(d6np,"☠ Shadow Gate\nLv 90+  |  💀 EXTREME",V3(0,0,0),270,65,C.white,Color3.fromRGB(5,2,15),0.25)

-- ─── SPAWN LOCATION ───────────────────────────────────────────────────────────
local sp=Instance.new("SpawnLocation")
sp.Position=V3(0,3,75); sp.Size=V3(6,1,6); sp.Anchored=true
sp.BrickColor=BrickColor.new("Gold"); sp.Material=Enum.Material.Neon
sp.Transparency=0.6; sp.Duration=0; sp.Parent=Workspace

print("[WorldBuilder] Dungeon Piece world built!")
print("  Lobby, 6 portals, 6 dungeon rooms (Coral Lagoon → Shadow Gate)")
