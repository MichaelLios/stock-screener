-- HUD.client.lua
-- Dungeon Piece UI: dark stone panels, amber-gold accents, red HP, blue Energy.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateHUD    = RemoteEvents:WaitForChild("UpdateHUD")
local LootDropEvt  = RemoteEvents:WaitForChild("LootDrop")

-- ── Palette ─────────────────────────────────────────────────────────────────
local C = {
    PanelBG     = Color3.fromRGB(14, 11,  8),   -- near-black warm stone
    PanelBorder = Color3.fromRGB(180, 83,  6),  -- amber-700
    Amber       = Color3.fromRGB(217,119,  6),  -- amber-600 (primary accent)
    AmberLight  = Color3.fromRGB(251,191, 36),  -- amber-400 (highlights)
    HPFull      = Color3.fromRGB(220, 38, 38),  -- red
    HPLow       = Color3.fromRGB(248,113,113),  -- lighter red (< 30%)
    HakiFull    = Color3.fromRGB( 37, 99,235),  -- blue-600
    XPFill      = Color3.fromRGB(234,179,  8),  -- yellow-500
    TextMain    = Color3.fromRGB(245,235,215),  -- warm cream
    TextDim     = Color3.fromRGB(180,165,140),  -- muted cream
    Overlay     = Color3.fromRGB(  0,  0,  0),
    Green       = Color3.fromRGB( 34,197, 94),
    Red         = Color3.fromRGB(220, 38, 38),
}

-- ────────────────────────────────────────────────
-- BUILD MAIN HUD SCREENGUI
-- ────────────────────────────────────────────────

local hudGui = Instance.new("ScreenGui")
hudGui.Name = "HUD"
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.Parent = playerGui

-- ── Full-screen overlay (floor transitions, level-up, game over) ──
local overlay = Instance.new("Frame")
overlay.Name = "FloorOverlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = C.Overlay
overlay.BackgroundTransparency = 1
overlay.ZIndex = 20
overlay.Parent = hudGui
local overlayLabel = Instance.new("TextLabel")
overlayLabel.Name = "TextLabel"
overlayLabel.Size = UDim2.new(0.7, 0, 0.22, 0)
overlayLabel.Position = UDim2.new(0.15, 0, 0.38, 0)
overlayLabel.BackgroundTransparency = 1
overlayLabel.Text = ""
overlayLabel.TextColor3 = C.AmberLight
overlayLabel.TextScaled = true
overlayLabel.Font = Enum.Font.GothamBold
overlayLabel.ZIndex = 21
overlayLabel.Parent = overlay
-- Amber bottom border stripe on overlay text
do local s = Instance.new("UIStroke"); s.Color=C.Amber; s.Thickness=2; s.Parent=overlayLabel end

-- ── Stat bars helper ─────────────────────────────────────────────────────────
-- Returns: panelFrame, fillFrame, textLabel
local function makeBar(parent, yOffset, fillColor, labelPrefix, name, w, h)
    w = w or 300
    h = h or 30

    local panel = Instance.new("Frame")
    panel.Name = name
    panel.Size = UDim2.new(0, w, 0, h)
    panel.Position = UDim2.new(0, 16, 1, yOffset)
    panel.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
    panel.BorderSizePixel = 0
    panel.ZIndex = 5
    panel.Parent = parent
    local corner = Instance.new("UICorner", panel)
    corner.CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", panel)
    stroke.Color = C.PanelBorder
    stroke.Thickness = 1.5

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = fillColor
    fill.BorderSizePixel = 0
    fill.ZIndex = 6
    fill.Parent = panel
    local fillCorner = Instance.new("UICorner", fill)
    fillCorner.CornerRadius = UDim.new(0, 6)

    -- Gloss strip
    local gloss = Instance.new("Frame")
    gloss.Size = UDim2.new(1, 0, 0.4, 0)
    gloss.BackgroundColor3 = Color3.new(1, 1, 1)
    gloss.BackgroundTransparency = 0.88
    gloss.BorderSizePixel = 0
    gloss.ZIndex = 7
    gloss.Parent = panel
    Instance.new("UICorner", gloss).CornerRadius = UDim.new(0, 6)

    local txt = Instance.new("TextLabel")
    txt.Name = "ValueLabel"
    txt.Size = UDim2.new(1, -8, 1, 0)
    txt.Position = UDim2.new(0, 4, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = labelPrefix .. " 100 / 100"
    txt.TextColor3 = C.TextMain
    txt.TextScaled = true
    txt.Font = Enum.Font.GothamBold
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.ZIndex = 8
    txt.Parent = panel

    return panel, fill, txt
end

-- HP and Energy bars (bottom-left)
local hpFrame,   hpFill,   hpLabel   = makeBar(hudGui, -86, C.HPFull,   "HP",     "HPBar",   300, 30)
local mpFrame,   mpFill,   mpLabel   = makeBar(hudGui, -50, C.HakiFull, "Energy", "MPBar",   300, 30)

-- ── XP bar (thin strip at very bottom) ──
local xpTrack = Instance.new("Frame")
xpTrack.Name = "XPBar"
xpTrack.Size = UDim2.new(1, 0, 0, 6)
xpTrack.Position = UDim2.new(0, 0, 1, -6)
xpTrack.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
xpTrack.BorderSizePixel = 0
xpTrack.ZIndex = 5
xpTrack.Parent = hudGui
local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = C.XPFill
xpFill.BorderSizePixel = 0
xpFill.ZIndex = 6
xpFill.Parent = xpTrack

-- ── Level / Bounty labels (bottom-left) ──
local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.Size = UDim2.new(0, 200, 0, 22)
levelLabel.Position = UDim2.new(0, 18, 1, -114)
levelLabel.BackgroundTransparency = 1
levelLabel.Text = "Lv.1  Swordsman"
levelLabel.TextColor3 = C.AmberLight
levelLabel.TextScaled = true
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextXAlignment = Enum.TextXAlignment.Left
levelLabel.ZIndex = 5
levelLabel.Parent = hudGui

local goldLabel = Instance.new("TextLabel")
goldLabel.Name = "GoldLabel"
goldLabel.Size = UDim2.new(0, 160, 0, 22)
goldLabel.Position = UDim2.new(0, 18, 1, -136)
goldLabel.BackgroundTransparency = 1
goldLabel.Text = "Bounty:  0"
goldLabel.TextColor3 = C.Amber
goldLabel.TextScaled = true
goldLabel.Font = Enum.Font.Gotham
goldLabel.TextXAlignment = Enum.TextXAlignment.Left
goldLabel.ZIndex = 5
goldLabel.Parent = hudGui

-- ── Floor label (top center) ──
local floorBG = Instance.new("Frame")
floorBG.Name = "FloorBG"
floorBG.Size = UDim2.new(0, 280, 0, 38)
floorBG.Position = UDim2.new(0.5, -140, 0, 8)
floorBG.BackgroundColor3 = Color3.fromRGB(14, 11, 8)
floorBG.BackgroundTransparency = 0.25
floorBG.BorderSizePixel = 0
floorBG.ZIndex = 5
floorBG.Parent = hudGui
Instance.new("UICorner", floorBG).CornerRadius = UDim.new(0, 10)
do local s = Instance.new("UIStroke", floorBG); s.Color=C.Amber; s.Thickness=1.5 end

local floorLabel = Instance.new("TextLabel")
floorLabel.Name = "FloorLabel"
floorLabel.Size = UDim2.new(1, -8, 1, 0)
floorLabel.BackgroundTransparency = 1
floorLabel.Text = "Dungeon Piece — Floor 1"
floorLabel.TextColor3 = C.AmberLight
floorLabel.TextScaled = true
floorLabel.Font = Enum.Font.GothamBold
floorLabel.ZIndex = 6
floorLabel.Parent = floorBG

-- ── Room progression bar (below floor label at top center) ──
local roomProgressBG = Instance.new("Frame")
roomProgressBG.Name = "RoomProgressBG"
roomProgressBG.Size = UDim2.new(0, 280, 0, 18)
roomProgressBG.Position = UDim2.new(0.5, -140, 0, 52)
roomProgressBG.BackgroundColor3 = Color3.fromRGB(14, 11, 8)
roomProgressBG.BackgroundTransparency = 0.2
roomProgressBG.BorderSizePixel = 0
roomProgressBG.ZIndex = 5
roomProgressBG.Visible = false
roomProgressBG.Parent = hudGui
Instance.new("UICorner", roomProgressBG).CornerRadius = UDim.new(0, 8)
do local s = Instance.new("UIStroke", roomProgressBG); s.Color=C.PanelBorder; s.Thickness=1 end

local roomProgressFill = Instance.new("Frame")
roomProgressFill.Name = "Fill"
roomProgressFill.Size = UDim2.new(0, 0, 1, 0)
roomProgressFill.BackgroundColor3 = C.Amber
roomProgressFill.BorderSizePixel = 0
roomProgressFill.ZIndex = 6
roomProgressFill.Parent = roomProgressBG
Instance.new("UICorner", roomProgressFill).CornerRadius = UDim.new(0, 8)

local roomProgressLabel = Instance.new("TextLabel")
roomProgressLabel.Name = "RoomProgressLabel"
roomProgressLabel.Size = UDim2.new(1, 0, 1, 0)
roomProgressLabel.BackgroundTransparency = 1
roomProgressLabel.Text = "Rooms  0 / 0"
roomProgressLabel.TextColor3 = C.TextMain
roomProgressLabel.TextScaled = true
roomProgressLabel.Font = Enum.Font.Gotham
roomProgressLabel.ZIndex = 7
roomProgressLabel.Parent = roomProgressBG

-- ── Ability bar (bottom center) ──
local abilityBar = Instance.new("Frame")
abilityBar.Name = "AbilityBar"
abilityBar.Size = UDim2.new(0, 370, 0, 70)
abilityBar.Position = UDim2.new(0.5, -185, 1, -88)
abilityBar.BackgroundTransparency = 1
abilityBar.ZIndex = 5
abilityBar.Parent = hudGui

local abilityKeys = { "1", "2", "3", "4", "5" }
local abilitySlotFrames = {}

for i, key in ipairs(abilityKeys) do
    local slot = Instance.new("Frame")
    slot.Name = "Slot_" .. i
    slot.Size = UDim2.new(0, 64, 0, 64)
    slot.Position = UDim2.new(0, (i - 1) * 72, 0, 0)
    slot.BackgroundColor3 = Color3.fromRGB(18, 14, 10)
    slot.BorderSizePixel = 0
    slot.ZIndex = 5
    slot.Parent = abilityBar
    Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 10)
    local slotStroke = Instance.new("UIStroke", slot)
    slotStroke.Color = C.PanelBorder
    slotStroke.Thickness = 1.5

    -- Cooldown dark overlay (fills bottom-up)
    local cdOverlay = Instance.new("Frame")
    cdOverlay.Name = "Cooldown"
    cdOverlay.Size = UDim2.new(1, 0, 0, 0)
    cdOverlay.Position = UDim2.new(0, 0, 1, 0)
    cdOverlay.AnchorPoint = Vector2.new(0, 1)
    cdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    cdOverlay.BackgroundTransparency = 0.45
    cdOverlay.BorderSizePixel = 0
    cdOverlay.ZIndex = 7
    cdOverlay.Parent = slot

    -- Key badge (bottom-right)
    local keyBadge = Instance.new("Frame")
    keyBadge.Size = UDim2.new(0, 18, 0, 18)
    keyBadge.Position = UDim2.new(1, -20, 1, -20)
    keyBadge.BackgroundColor3 = C.PanelBorder
    keyBadge.BorderSizePixel = 0
    keyBadge.ZIndex = 8
    keyBadge.Parent = slot
    Instance.new("UICorner", keyBadge).CornerRadius = UDim.new(0, 4)
    local keyLbl = Instance.new("TextLabel")
    keyLbl.Size = UDim2.new(1, 0, 1, 0)
    keyLbl.BackgroundTransparency = 1
    keyLbl.Text = key
    keyLbl.TextColor3 = Color3.new(1, 1, 1)
    keyLbl.TextScaled = true
    keyLbl.Font = Enum.Font.GothamBold
    keyLbl.ZIndex = 9
    keyLbl.Parent = keyBadge

    -- Ability name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name = "AbilityName"
    nameLbl.Size = UDim2.new(1, -4, 0.45, 0)
    nameLbl.Position = UDim2.new(0, 2, 0.06, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = ""
    nameLbl.TextColor3 = C.TextMain
    nameLbl.TextScaled = true
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.ZIndex = 6
    nameLbl.Parent = slot

    abilitySlotFrames[i] = slot
end

-- ── Loot notification ──
local lootNotif = Instance.new("TextLabel")
lootNotif.Name = "LootNotification"
lootNotif.Size = UDim2.new(0, 280, 0, 36)
lootNotif.Position = UDim2.new(0.5, -140, 0.72, 0)
lootNotif.BackgroundTransparency = 1
lootNotif.Text = ""
lootNotif.TextColor3 = C.AmberLight
lootNotif.TextTransparency = 1
lootNotif.TextScaled = true
lootNotif.Font = Enum.Font.GothamBold
lootNotif.ZIndex = 10
lootNotif.Parent = hudGui

-- ────────────────────────────────────────────────
-- ARCHETYPE SELECTION SCREEN
-- ────────────────────────────────────────────────

local archetypeScreen = Instance.new("Frame")
archetypeScreen.Name = "ArchetypeScreen"
archetypeScreen.Size = UDim2.new(1, 0, 1, 0)
archetypeScreen.BackgroundColor3 = Color3.fromRGB(6, 10, 18)
archetypeScreen.BackgroundTransparency = 1
archetypeScreen.Visible = false
archetypeScreen.ZIndex = 15
archetypeScreen.Parent = hudGui

-- Subtle vignette gradient at edges (two overlapping frames)
local vignette = Instance.new("Frame")
vignette.Size = UDim2.new(1, 0, 1, 0)
vignette.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
vignette.BackgroundTransparency = 0.55
vignette.BorderSizePixel = 0
vignette.ZIndex = 15
vignette.Parent = archetypeScreen
local vigGrad = Instance.new("UIGradient", vignette)
vigGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 5, 14)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0, 5, 14)),
})
vigGrad.Rotation = 90

-- Title
local archTitle = Instance.new("TextLabel")
archTitle.Size = UDim2.new(0.7, 0, 0.08, 0)
archTitle.Position = UDim2.new(0.15, 0, 0.04, 0)
archTitle.BackgroundTransparency = 1
archTitle.Text = "Choose Your Fighting Style"
archTitle.TextColor3 = C.AmberLight
archTitle.TextScaled = true
archTitle.Font = Enum.Font.GothamBold
archTitle.ZIndex = 17
archTitle.Parent = archetypeScreen
do local s=Instance.new("UIStroke",archTitle); s.Color=C.PanelBorder; s.Thickness=1 end

local archSubtitle = Instance.new("TextLabel")
archSubtitle.Size = UDim2.new(0.6, 0, 0.04, 0)
archSubtitle.Position = UDim2.new(0.2, 0, 0.11, 0)
archSubtitle.BackgroundTransparency = 1
archSubtitle.Text = "Your path through the Dungeon Piece begins now"
archSubtitle.TextColor3 = C.TextDim
archSubtitle.TextScaled = true
archSubtitle.Font = Enum.Font.Gotham
archSubtitle.ZIndex = 17
archSubtitle.Parent = archetypeScreen

-- Amber divider
local divider = Instance.new("Frame")
divider.Size = UDim2.new(0.5, 0, 0, 2)
divider.Position = UDim2.new(0.25, 0, 0.155, 0)
divider.BackgroundColor3 = C.Amber
divider.BorderSizePixel = 0
divider.ZIndex = 17
divider.Parent = archetypeScreen

-- Card scroll
local cardScroll = Instance.new("ScrollingFrame")
cardScroll.Size = UDim2.new(1, -24, 0.76, 0)
cardScroll.Position = UDim2.new(0, 12, 0.19, 0)
cardScroll.BackgroundTransparency = 1
cardScroll.ScrollBarThickness = 4
cardScroll.ScrollBarImageColor3 = C.Amber
cardScroll.ScrollingDirection = Enum.ScrollingDirection.X
cardScroll.CanvasSize = UDim2.new(0, 0, 1, 0)
cardScroll.ZIndex = 16
cardScroll.Parent = archetypeScreen

do local l=Instance.new("UIListLayout",cardScroll); l.FillDirection=Enum.FillDirection.Horizontal; l.Padding=UDim.new(0,16); l.VerticalAlignment=Enum.VerticalAlignment.Center end

-- Archetype data
local archetypeData = {
    {
        Name  = "Swordsman",
        Title = "Swordsman",
        Sub   = "Blade master\nHigh ATK, mobile",
        AccentColor = Color3.fromRGB(220, 38, 38),   -- crimson
        BadgeText = "SLASH STYLE",
    },
    {
        Name  = "Mage",
        Title = "Devil Fruit User",
        Sub   = "Elemental caster\nHigh spell power",
        AccentColor = Color3.fromRGB(124, 58, 237),  -- violet
        BadgeText = "FRUIT POWER",
    },
    {
        Name  = "Brawler",
        Title = "Brawler",
        Sub   = "Tank fighter\nHigh HP and DEF",
        AccentColor = Color3.fromRGB(234, 88, 12),   -- orange
        BadgeText = "HAKI BODY",
    },
    {
        Name  = "Assassin",
        Title = "Assassin",
        Sub   = "Shadow arts\nHigh SPD and burst",
        AccentColor = Color3.fromRGB(30, 64, 175),   -- dark blue
        BadgeText = "SHADOW ART",
    },
    {
        Name  = "SpiritUser",
        Title = "Spirit User",
        Sub   = "Spirit energy\nBalanced, lifesteal",
        AccentColor = Color3.fromRGB(5, 150, 105),   -- teal
        BadgeText = "HAKI MASTER",
    },
}

local SelectArchetype = RemoteEvents:WaitForChild("SelectArchetype", 15)
local CARD_W = 170

local function pickArchetype(arch)
    if SelectArchetype then
        SelectArchetype:FireServer(arch.Name)
    end
    levelLabel.Text = "Lv.1  " .. arch.Title
    TweenService:Create(archetypeScreen, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
    task.wait(0.5)
    archetypeScreen.Visible = false
end

for _, arch in ipairs(archetypeData) do
    -- Outer card (dark stone panel)
    local card = Instance.new("TextButton")
    card.Size = UDim2.new(0, CARD_W, 1, -16)
    card.BackgroundColor3 = Color3.fromRGB(18, 14, 10)
    card.BorderSizePixel = 0
    card.Text = ""
    card.AutoButtonColor = false
    card.ZIndex = 17
    card.Parent = cardScroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color = arch.AccentColor
    cardStroke.Thickness = 2

    -- Accent color bar at top of card
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0.06, 0)
    topBar.BackgroundColor3 = arch.AccentColor
    topBar.BorderSizePixel = 0
    topBar.ZIndex = 18
    topBar.Parent = card
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

    -- Class badge pill
    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.new(0.88, 0, 0.10, 0)
    badge.Position = UDim2.new(0.06, 0, 0.08, 0)
    badge.BackgroundColor3 = arch.AccentColor
    badge.BackgroundTransparency = 0.25
    badge.Text = arch.BadgeText
    badge.TextColor3 = Color3.new(1, 1, 1)
    badge.TextScaled = true
    badge.Font = Enum.Font.GothamBold
    badge.ZIndex = 18
    badge.Parent = card
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 8)

    -- Title
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -8, 0.18, 0)
    nameLbl.Position = UDim2.new(0, 4, 0.20, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = arch.Title
    nameLbl.TextColor3 = C.AmberLight
    nameLbl.TextScaled = true
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.ZIndex = 18
    nameLbl.Parent = card

    -- Amber divider
    local cardDiv = Instance.new("Frame")
    cardDiv.Size = UDim2.new(0.8, 0, 0, 1)
    cardDiv.Position = UDim2.new(0.1, 0, 0.39, 0)
    cardDiv.BackgroundColor3 = C.Amber
    cardDiv.BackgroundTransparency = 0.6
    cardDiv.BorderSizePixel = 0
    cardDiv.ZIndex = 18
    cardDiv.Parent = card

    -- Description
    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -8, 0.28, 0)
    descLbl.Position = UDim2.new(0, 4, 0.42, 0)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = arch.Sub
    descLbl.TextColor3 = C.TextDim
    descLbl.TextScaled = true
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextWrapped = true
    descLbl.ZIndex = 18
    descLbl.Parent = card

    -- Select button
    local selBtn = Instance.new("TextButton")
    selBtn.Size = UDim2.new(0.84, 0, 0.13, 0)
    selBtn.Position = UDim2.new(0.08, 0, 0.83, 0)
    selBtn.BackgroundColor3 = arch.AccentColor
    selBtn.Text = "SELECT"
    selBtn.TextColor3 = Color3.new(1, 1, 1)
    selBtn.TextScaled = true
    selBtn.Font = Enum.Font.GothamBold
    selBtn.BorderSizePixel = 0
    selBtn.ZIndex = 19
    selBtn.Parent = card
    Instance.new("UICorner", selBtn).CornerRadius = UDim.new(0, 8)

    local function select()
        pickArchetype(arch)
    end
    card.MouseButton1Click:Connect(select)
    selBtn.MouseButton1Click:Connect(select)

    card.MouseEnter:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(26, 20, 14)
        }):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.12), {
            Thickness = 3
        }):Play()
    end)
    card.MouseLeave:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.12), {
            BackgroundColor3 = Color3.fromRGB(18, 14, 10)
        }):Play()
        TweenService:Create(cardStroke, TweenInfo.new(0.12), {
            Thickness = 2
        }):Play()
    end)
end

cardScroll.CanvasSize = UDim2.new(0, #archetypeData * (CARD_W + 16) + 16, 1, 0)

-- ────────────────────────────────────────────────
-- SHOP UI  ("Black Market Dealer")
-- ────────────────────────────────────────────────

local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.Size = UDim2.new(0, 520, 0, 420)
shopFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
shopFrame.BackgroundColor3 = Color3.fromRGB(14, 11, 8)
shopFrame.Visible = false
shopFrame.ZIndex = 12
shopFrame.Parent = hudGui
Instance.new("UICorner", shopFrame).CornerRadius = UDim.new(0, 14)
do local s=Instance.new("UIStroke",shopFrame); s.Color=C.Amber; s.Thickness=2 end

-- Header stripe
local shopHeader = Instance.new("Frame")
shopHeader.Size = UDim2.new(1, 0, 0.13, 0)
shopHeader.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
shopHeader.BorderSizePixel = 0
shopHeader.ZIndex = 13
shopHeader.Parent = shopFrame
Instance.new("UICorner", shopHeader).CornerRadius = UDim.new(0, 12)

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(0.8, 0, 1, 0)
shopTitle.Position = UDim2.new(0.02, 0, 0, 0)
shopTitle.BackgroundTransparency = 1
shopTitle.Text = "Black Market Dealer"
shopTitle.TextColor3 = C.AmberLight
shopTitle.TextScaled = true
shopTitle.Font = Enum.Font.GothamBold
shopTitle.TextXAlignment = Enum.TextXAlignment.Left
shopTitle.ZIndex = 14
shopTitle.Parent = shopHeader

local shopClose = Instance.new("TextButton")
shopClose.Size = UDim2.new(0, 36, 0, 36)
shopClose.Position = UDim2.new(1, -42, 0, 8)
shopClose.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
shopClose.Text = "✕"
shopClose.TextColor3 = Color3.new(1, 1, 1)
shopClose.TextScaled = true
shopClose.Font = Enum.Font.GothamBold
shopClose.BorderSizePixel = 0
shopClose.ZIndex = 14
shopClose.Parent = shopFrame
Instance.new("UICorner", shopClose).CornerRadius = UDim.new(0, 8)
shopClose.MouseButton1Click:Connect(function() shopFrame.Visible = false end)

local shopItemContainer = Instance.new("ScrollingFrame")
shopItemContainer.Size = UDim2.new(1, -16, 0.83, 0)
shopItemContainer.Position = UDim2.new(0, 8, 0.14, 0)
shopItemContainer.BackgroundTransparency = 1
shopItemContainer.ScrollBarThickness = 4
shopItemContainer.ScrollBarImageColor3 = C.Amber
shopItemContainer.ZIndex = 13
shopItemContainer.Parent = shopFrame
local shopLayout = Instance.new("UIListLayout", shopItemContainer)
shopLayout.Padding = UDim.new(0, 6)

local BuyItemEvt = RemoteEvents:WaitForChild("BuyItem", 10)
local currentShopRoomId = nil

local rarityColors = {
    Common    = Color3.fromRGB(200, 200, 200),
    Uncommon  = Color3.fromRGB(74, 222, 128),
    Rare      = Color3.fromRGB(96, 165, 250),
    Epic      = Color3.fromRGB(192, 132, 252),
    Legendary = C.AmberLight,
}

local function buildShopItem(entry, roomId)
    local rColor = rarityColors[entry.Item.Rarity] or C.TextMain

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 64)
    row.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
    row.BorderSizePixel = 0
    row.ZIndex = 14
    row.Parent = shopItemContainer
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local rowStroke = Instance.new("UIStroke", row)
    rowStroke.Color = Color3.fromRGB(50, 38, 24)
    rowStroke.Thickness = 1

    -- Rarity pip on the left
    local pip = Instance.new("Frame")
    pip.Size = UDim2.new(0, 4, 1, -10)
    pip.Position = UDim2.new(0, 4, 0, 5)
    pip.BackgroundColor3 = rColor
    pip.BorderSizePixel = 0
    pip.ZIndex = 15
    pip.Parent = row
    Instance.new("UICorner", pip).CornerRadius = UDim.new(0, 4)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0.52, 0, 0.48, 0)
    nameLbl.Position = UDim2.new(0, 14, 0, 4)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = entry.Item.Name
    nameLbl.TextColor3 = rColor
    nameLbl.TextScaled = true
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 15
    nameLbl.Parent = row

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(0.52, 0, 0.42, 0)
    descLbl.Position = UDim2.new(0, 14, 0.5, 0)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = entry.Item.Description or ""
    descLbl.TextColor3 = C.TextDim
    descLbl.TextScaled = true
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.ZIndex = 15
    descLbl.Parent = row

    local priceLbl = Instance.new("TextLabel")
    priceLbl.Size = UDim2.new(0.18, 0, 0.5, 0)
    priceLbl.Position = UDim2.new(0.57, 0, 0.25, 0)
    priceLbl.BackgroundTransparency = 1
    priceLbl.Text = entry.Price .. " B"
    priceLbl.TextColor3 = C.Amber
    priceLbl.TextScaled = true
    priceLbl.Font = Enum.Font.GothamBold
    priceLbl.ZIndex = 15
    priceLbl.Parent = row

    local buyBtn = Instance.new("TextButton")
    buyBtn.Size = UDim2.new(0.16, 0, 0.55, 0)
    buyBtn.Position = UDim2.new(0.82, 0, 0.22, 0)
    buyBtn.BackgroundColor3 = C.PanelBorder
    buyBtn.Text = "BUY"
    buyBtn.TextColor3 = Color3.new(1, 1, 1)
    buyBtn.TextScaled = true
    buyBtn.Font = Enum.Font.GothamBold
    buyBtn.BorderSizePixel = 0
    buyBtn.ZIndex = 15
    buyBtn.Parent = row
    Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 6)
    buyBtn.MouseButton1Click:Connect(function()
        if BuyItemEvt then BuyItemEvt:FireServer(entry.ItemName, roomId) end
        row:Destroy()
    end)
    buyBtn.MouseEnter:Connect(function()
        TweenService:Create(buyBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.Amber }):Play()
    end)
    buyBtn.MouseLeave:Connect(function()
        TweenService:Create(buyBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.PanelBorder }):Play()
    end)
end

-- ────────────────────────────────────────────────
-- TOAST HELPER
-- ────────────────────────────────────────────────

local function showToast(text, bgColor, duration)
    duration = duration or 2
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 320, 0, 42)
    toast.Position = UDim2.new(0.5, -160, 0.6, 0)
    toast.BackgroundColor3 = bgColor or Color3.fromRGB(22, 17, 12)
    toast.BackgroundTransparency = 0.1
    toast.BorderSizePixel = 0
    toast.ZIndex = 16
    toast.Parent = hudGui
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
    local toastStroke = Instance.new("UIStroke", toast)
    toastStroke.Color = C.Amber
    toastStroke.Thickness = 1.5

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C.TextMain
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.ZIndex = 17
    lbl.Parent = toast

    TweenService:Create(toast, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1,
        Position = toast.Position + UDim2.new(0, 0, -0.05, 0),
    }):Play()
    TweenService:Create(lbl, TweenInfo.new(duration), { TextTransparency = 1 }):Play()
    game:GetService("Debris"):AddItem(toast, duration)
end

-- ────────────────────────────────────────────────
-- HUD UPDATE HANDLER
-- ────────────────────────────────────────────────

UpdateHUD.OnClientEvent:Connect(function(data)
    -- Archetype screen
    if data.ShowArchetypeScreen then
        archetypeScreen.BackgroundTransparency = 0
        archetypeScreen.Visible = true
    end
    if data.HideArchetypeScreen then
        TweenService:Create(archetypeScreen, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
        task.delay(0.45, function() archetypeScreen.Visible = false end)
    end

    -- HP bar
    if data.HP ~= nil and data.MaxHP ~= nil then
        local pct = math.clamp(data.HP / data.MaxHP, 0, 1)
        local fillColor = pct < 0.3 and C.HPLow or C.HPFull
        TweenService:Create(hpFill, TweenInfo.new(0.18), {
            Size = UDim2.new(pct, 0, 1, 0),
            BackgroundColor3 = fillColor,
        }):Play()
        hpLabel.Text = "HP  " .. math.floor(data.HP) .. " / " .. data.MaxHP
    end

    -- Haki (MP) bar
    if data.MP ~= nil and data.MaxMP ~= nil then
        local pct = math.clamp(data.MP / data.MaxMP, 0, 1)
        TweenService:Create(mpFill, TweenInfo.new(0.18), {
            Size = UDim2.new(pct, 0, 1, 0),
        }):Play()
        mpLabel.Text = "Energy  " .. math.floor(data.MP) .. " / " .. data.MaxMP
    end

    -- XP bar
    if data.XP ~= nil and data.XPNeeded ~= nil then
        local pct = math.clamp(data.XP / data.XPNeeded, 0, 1)
        TweenService:Create(xpFill, TweenInfo.new(0.22), {
            Size = UDim2.new(pct, 0, 1, 0),
        }):Play()
    end

    -- Level / archetype label
    if data.Level and data.Archetype then
        levelLabel.Text = "Lv." .. data.Level .. "  " .. data.Archetype
    elseif data.Level then
        local cur = levelLabel.Text
        levelLabel.Text = "Lv." .. data.Level .. "  " .. (cur:match("  (.+)$") or "")
    elseif data.Archetype then
        local cur = levelLabel.Text
        levelLabel.Text = (cur:match("^(Lv%.%d+)") or "Lv.1") .. "  " .. data.Archetype
    end

    -- Bounty (gold)
    if data.Gold then
        goldLabel.Text = "Bounty:  " .. data.Gold
    end

    -- Floor label + reset room progress bar
    if data.FloorStart then
        floorLabel.Text = "Dungeon Piece — F" .. data.Floor .. " · " .. (data.ShardName or data.ThemeName)
        roomProgressBG.Visible = true
        roomProgressFill.Size = UDim2.new(0, 0, 1, 0)
        roomProgressFill.BackgroundColor3 = C.Amber
        roomProgressLabel.Text = "Rooms  0 / ?"
    end

    -- Ability slots (server sends ActiveSlots; handled again below for AbilityBook sync)
    -- Note: the later ActiveSlots block also updates abilitySlotFrames — this early block
    -- is intentionally removed to avoid duplication. All slot updates go through the
    -- unified ActiveSlots handler below.

    -- Shop
    if data.ShopOpen and data.Stock then
        for _, child in ipairs(shopItemContainer:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        currentShopRoomId = data.RoomId
        for _, entry in ipairs(data.Stock) do
            buildShopItem(entry, currentShopRoomId)
        end
        shopItemContainer.CanvasSize = UDim2.new(0, 0, 0, shopLayout.AbsoluteContentSize.Y + 12)
        shopFrame.Visible = true
    end

    if data.ShopError then
        shopTitle.Text = data.Message or "Transaction Failed"
        task.delay(2, function() shopTitle.Text = "Black Market Dealer" end)
    end

    if data.Message and not data.ShopError then
        showToast(data.Message, Color3.fromRGB(22, 17, 12), data.Duration or 2)
    end

    if data.RestRoom then
        showToast("Rested — HP and Energy restored!", Color3.fromRGB(10, 30, 20), 2)
    end

    if data.Revived then
        showToast("Phoenix Scroll activated!", Color3.fromRGB(100, 50, 0), 2.5)
    end

    -- Floor start overlay (fallback: only fires when no EntryFlavor lore is present)
    if data.FloorStart and not data.EntryFlavor then
        overlay.BackgroundColor3 = Color3.fromRGB(0, 5, 14)
        overlayLabel.TextColor3 = C.AmberLight
        overlay.BackgroundTransparency = 0
        overlayLabel.TextTransparency = 0
        overlayLabel.Text = "Floor " .. data.Floor .. "\n" .. (data.ShardName or data.ThemeName)
        TweenService:Create(overlay, TweenInfo.new(2.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(overlayLabel, TweenInfo.new(2.5, Enum.EasingStyle.Quad), { TextTransparency = 1 }):Play()
        task.delay(2.6, function() overlayLabel.Text = ""; overlayLabel.TextTransparency = 0 end)
    end

    if data.BossUnlocked then
        overlay.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
        overlayLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        overlay.BackgroundTransparency = 0.2
        overlayLabel.Text = data.Message or "Boss Chamber Open!"
        TweenService:Create(overlay, TweenInfo.new(2.5), { BackgroundTransparency = 1 }):Play()
        task.delay(2.5, function() overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0) end)
    end

    if data.LevelUp then
        overlay.BackgroundColor3 = Color3.fromRGB(30, 22, 0)
        overlayLabel.TextColor3 = C.AmberLight
        overlay.BackgroundTransparency = 0.15
        overlayLabel.Text = "LEVEL UP!\nLevel " .. data.Level
        TweenService:Create(overlay, TweenInfo.new(1.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
        task.delay(1.8, function() overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0) end)
    end

    if data.GameOver then
        overlay.BackgroundColor3  = Color3.fromRGB(10, 0, 0)
        overlayLabel.TextColor3   = Color3.fromRGB(255, 80, 80)
        overlay.BackgroundTransparency = 0
        overlayLabel.TextTransparency  = 0
        overlayLabel.Text = "DEFEATED\nYou reached Floor " .. (data.Floor or 1)
        -- Hold for 3s then fade so the lobby is visible on respawn
        task.delay(3, function()
            TweenService:Create(overlay, TweenInfo.new(1.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(overlayLabel, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
            task.delay(1.6, function()
                overlayLabel.Text = ""
                overlayLabel.TextTransparency = 0
                overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            end)
        end)
    end

    -- Ability learned notification
    if data.GrantedAbility then
        local AbilitySystemMod = require(ReplicatedStorage.Modules.AbilitySystem)
        local ab = AbilitySystemMod.GetAbility(data.GrantedAbility)
        local name = ab and ab.Name or data.GrantedAbility
        showToast("Learned:  " .. name, Color3.fromRGB(0, 28, 50), 3.5)
    end

    -- Sync ability bar slots when ActiveSlots arrives
    if data.ActiveSlots then
        for i, name in ipairs(data.ActiveSlots) do
            local slot = abilitySlotFrames[i]
            if slot then
                local lbl = slot:FindFirstChild("AbilityName")
                if lbl then lbl.Text = name and name:sub(1, 7) or "" end
            end
        end
        -- Forward to book if open
        if bookActiveSlots then
            bookActiveSlots = data.ActiveSlots
            if abilityBook and abilityBook.Visible then
                refreshSlotVisuals()
                rebuildKnownGrid()
            else
                refreshSlotVisuals()
            end
        end
    end

    if data.KnownAbilities then
        bookKnownAbilities = data.KnownAbilities
        if abilityBook and abilityBook.Visible then
            rebuildKnownGrid()
        end
    end
end)

-- ────────────────────────────────────────────────
-- ABILITY BOOK  (Tab to open/close)
-- ────────────────────────────────────────────────

local AbilitySystemMod = require(ReplicatedStorage.Modules.AbilitySystem)
local SwapAbility      = RemoteEvents:WaitForChild("SwapAbility", 15)

-- Book state
local bookKnownAbilities = {}
local bookActiveSlots    = { false, false, false, false, false }
local selectedSlot       = nil   -- 1-5 or nil
local selectedAbilityName = nil  -- string or nil
local abilityCardMap     = {}    -- [abilityName] = cardFrame
local activeSlotButtons  = {}    -- [1..5] = button

-- ── Book frame ───────────────────────────────────────────────────────────────
local abilityBook = Instance.new("Frame")
abilityBook.Name = "AbilityBook"
abilityBook.Size = UDim2.new(0, 580, 0, 510)
abilityBook.Position = UDim2.new(0.5, -290, 0.5, -255)
abilityBook.BackgroundColor3 = Color3.fromRGB(14, 11, 8)
abilityBook.Visible = false
abilityBook.ZIndex = 22
abilityBook.Parent = hudGui
Instance.new("UICorner", abilityBook).CornerRadius = UDim.new(0, 14)
do local s=Instance.new("UIStroke",abilityBook); s.Color=C.Amber; s.Thickness=2 end

-- Header
local bookHeader = Instance.new("Frame")
bookHeader.Size = UDim2.new(1, 0, 0, 48)
bookHeader.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
bookHeader.BorderSizePixel = 0
bookHeader.ZIndex = 22
bookHeader.Parent = abilityBook
Instance.new("UICorner", bookHeader).CornerRadius = UDim.new(0, 12)
-- Fill the rounded bottom corners of the header strip
local hFill = Instance.new("Frame", bookHeader)
hFill.Size = UDim2.new(1, 0, 0.5, 0)
hFill.Position = UDim2.new(0, 0, 0.5, 0)
hFill.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
hFill.BorderSizePixel = 0
hFill.ZIndex = 22

local bookTitleLbl = Instance.new("TextLabel")
bookTitleLbl.Size = UDim2.new(0.5, 0, 1, 0)
bookTitleLbl.Position = UDim2.new(0.02, 0, 0, 0)
bookTitleLbl.BackgroundTransparency = 1
bookTitleLbl.Text = "ABILITY BOOK"
bookTitleLbl.TextColor3 = C.AmberLight
bookTitleLbl.TextScaled = true
bookTitleLbl.Font = Enum.Font.GothamBold
bookTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
bookTitleLbl.ZIndex = 23
bookTitleLbl.Parent = bookHeader

local bookHintLbl = Instance.new("TextLabel")
bookHintLbl.Size = UDim2.new(0.42, 0, 0.5, 0)
bookHintLbl.Position = UDim2.new(0.36, 0, 0.5, 0)
bookHintLbl.BackgroundTransparency = 1
bookHintLbl.Text = "Click ability → click slot  |  Right-click slot to clear"
bookHintLbl.TextColor3 = C.TextDim
bookHintLbl.TextScaled = true
bookHintLbl.Font = Enum.Font.Gotham
bookHintLbl.ZIndex = 23
bookHintLbl.Parent = bookHeader

local bookCloseBtn = Instance.new("TextButton")
bookCloseBtn.Size = UDim2.new(0, 36, 0, 36)
bookCloseBtn.Position = UDim2.new(1, -42, 0.5, -18)
bookCloseBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
bookCloseBtn.Text = "✕"
bookCloseBtn.TextColor3 = Color3.new(1, 1, 1)
bookCloseBtn.TextScaled = true
bookCloseBtn.Font = Enum.Font.GothamBold
bookCloseBtn.BorderSizePixel = 0
bookCloseBtn.ZIndex = 23
bookCloseBtn.Parent = abilityBook
Instance.new("UICorner", bookCloseBtn).CornerRadius = UDim.new(0, 8)

-- ── Active Slots section ─────────────────────────────────────────────────────
local slotsSect = Instance.new("Frame")
slotsSect.Size = UDim2.new(1, -16, 0, 108)
slotsSect.Position = UDim2.new(0, 8, 0, 54)
slotsSect.BackgroundTransparency = 1
slotsSect.ZIndex = 22
slotsSect.Parent = abilityBook

local slotsSectTitle = Instance.new("TextLabel")
slotsSectTitle.Size = UDim2.new(1, 0, 0, 20)
slotsSectTitle.BackgroundTransparency = 1
slotsSectTitle.Text = "ACTIVE SLOTS"
slotsSectTitle.TextColor3 = C.TextDim
slotsSectTitle.TextScaled = true
slotsSectTitle.Font = Enum.Font.GothamBold
slotsSectTitle.TextXAlignment = Enum.TextXAlignment.Left
slotsSectTitle.ZIndex = 23
slotsSectTitle.Parent = slotsSect

local SLOT_BTN_W = 104
local slotKeys = { "Q", "E", "R", "F", "T" }

local function getAbDisplayName(abilityName)
    if not abilityName then return "─ Empty ─" end
    local ab = AbilitySystemMod.GetAbility(abilityName)
    return ab and ab.Name or abilityName
end

local function getAbCost(abilityName)
    if not abilityName then return "" end
    local ab = AbilitySystemMod.GetAbility(abilityName)
    if not ab then return "" end
    return ab.MPCost > 0 and (ab.MPCost .. " Energy") or "Free"
end

-- Forward-declared so slot/card builders can call them
local refreshSlotVisuals
local refreshCardVisuals
local rebuildKnownGrid

local function trySwap()
    if selectedSlot and selectedAbilityName then
        if SwapAbility then
            SwapAbility:FireServer(selectedSlot, selectedAbilityName)
        end
        selectedSlot = nil
        selectedAbilityName = nil
    end
end

refreshSlotVisuals = function()
    for i, btn in ipairs(activeSlotButtons) do
        local abilityName = bookActiveSlots[i]
        local nLbl = btn:FindFirstChild("SlotAbilityName")
        local cLbl = btn:FindFirstChild("SlotCost")
        if nLbl then nLbl.Text = getAbDisplayName(abilityName) end
        if cLbl then cLbl.Text = getAbCost(abilityName) end
        local stroke = btn:FindFirstChildWhichIsA("UIStroke")
        if stroke then
            if selectedSlot == i then
                stroke.Color = C.AmberLight
                stroke.Thickness = 3
                btn.BackgroundColor3 = Color3.fromRGB(40, 30, 8)
            elseif abilityName then
                stroke.Color = C.Amber
                stroke.Thickness = 1.5
                btn.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
            else
                stroke.Color = Color3.fromRGB(50, 38, 24)
                stroke.Thickness = 1
                btn.BackgroundColor3 = Color3.fromRGB(16, 12, 9)
            end
        end
    end
end

for i = 1, 5 do
    local btn = Instance.new("TextButton")
    btn.Name = "ActiveSlot_" .. i
    btn.Size = UDim2.new(0, SLOT_BTN_W, 0, 84)
    btn.Position = UDim2.new(0, (i - 1) * (SLOT_BTN_W + 8), 0, 22)
    btn.BackgroundColor3 = Color3.fromRGB(16, 12, 9)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 23
    btn.Parent = slotsSect
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    local slotStroke = Instance.new("UIStroke", btn)
    slotStroke.Color = Color3.fromRGB(50, 38, 24)
    slotStroke.Thickness = 1

    -- Key badge
    local kb = Instance.new("Frame", btn)
    kb.Size = UDim2.new(0, 22, 0, 22)
    kb.Position = UDim2.new(0, 4, 0, 4)
    kb.BackgroundColor3 = C.PanelBorder
    kb.BorderSizePixel = 0
    kb.ZIndex = 24
    Instance.new("UICorner", kb).CornerRadius = UDim.new(0, 4)
    local kbLbl = Instance.new("TextLabel", kb)
    kbLbl.Size = UDim2.new(1, 0, 1, 0)
    kbLbl.BackgroundTransparency = 1
    kbLbl.Text = slotKeys[i]
    kbLbl.TextColor3 = Color3.new(1, 1, 1)
    kbLbl.TextScaled = true
    kbLbl.Font = Enum.Font.GothamBold
    kbLbl.ZIndex = 25

    local nLbl = Instance.new("TextLabel")
    nLbl.Name = "SlotAbilityName"
    nLbl.Size = UDim2.new(1, -6, 0.52, 0)
    nLbl.Position = UDim2.new(0, 3, 0.28, 0)
    nLbl.BackgroundTransparency = 1
    nLbl.Text = "─ Empty ─"
    nLbl.TextColor3 = C.TextMain
    nLbl.TextScaled = true
    nLbl.TextWrapped = true
    nLbl.Font = Enum.Font.Gotham
    nLbl.ZIndex = 24
    nLbl.Parent = btn

    local cLbl = Instance.new("TextLabel")
    cLbl.Name = "SlotCost"
    cLbl.Size = UDim2.new(1, -4, 0.22, 0)
    cLbl.Position = UDim2.new(0, 2, 0.76, 0)
    cLbl.BackgroundTransparency = 1
    cLbl.Text = ""
    cLbl.TextColor3 = C.HakiFull
    cLbl.TextScaled = true
    cLbl.Font = Enum.Font.Gotham
    cLbl.ZIndex = 24
    cLbl.Parent = btn

    btn.MouseButton1Click:Connect(function()
        if selectedAbilityName then
            selectedSlot = i
            trySwap()
            refreshSlotVisuals()
            refreshCardVisuals()
        else
            selectedSlot = (selectedSlot == i) and nil or i
            refreshSlotVisuals()
        end
    end)

    btn.MouseButton2Click:Connect(function()
        if SwapAbility then SwapAbility:FireServer(i, false) end
    end)

    activeSlotButtons[i] = btn
end

-- Divider
local bookDivider = Instance.new("Frame")
bookDivider.Size = UDim2.new(1, -16, 0, 1)
bookDivider.Position = UDim2.new(0, 8, 0, 168)
bookDivider.BackgroundColor3 = C.Amber
bookDivider.BackgroundTransparency = 0.5
bookDivider.BorderSizePixel = 0
bookDivider.ZIndex = 22
bookDivider.Parent = abilityBook

-- ── Known Abilities section ──────────────────────────────────────────────────
local knownSect = Instance.new("Frame")
knownSect.Size = UDim2.new(1, -16, 1, -184)
knownSect.Position = UDim2.new(0, 8, 0, 174)
knownSect.BackgroundTransparency = 1
knownSect.ZIndex = 22
knownSect.Parent = abilityBook

local knownSectTitle = Instance.new("TextLabel")
knownSectTitle.Size = UDim2.new(1, 0, 0, 20)
knownSectTitle.BackgroundTransparency = 1
knownSectTitle.Text = "KNOWN ABILITIES"
knownSectTitle.TextColor3 = C.TextDim
knownSectTitle.TextScaled = true
knownSectTitle.Font = Enum.Font.GothamBold
knownSectTitle.TextXAlignment = Enum.TextXAlignment.Left
knownSectTitle.ZIndex = 23
knownSectTitle.Parent = knownSect

local knownScroll = Instance.new("ScrollingFrame")
knownScroll.Size = UDim2.new(1, 0, 1, -24)
knownScroll.Position = UDim2.new(0, 0, 0, 24)
knownScroll.BackgroundTransparency = 1
knownScroll.ScrollBarThickness = 4
knownScroll.ScrollBarImageColor3 = C.Amber
knownScroll.ZIndex = 23
knownScroll.Parent = knownSect

local knownGrid = Instance.new("UIGridLayout", knownScroll)
knownGrid.CellSize = UDim2.new(0, 168, 0, 94)
knownGrid.CellPadding = UDim2.new(0, 8, 0, 8)
knownGrid.SortOrder = Enum.SortOrder.Name
do local p=Instance.new("UIPadding",knownScroll); p.PaddingLeft=UDim.new(0,4); p.PaddingTop=UDim.new(0,4) end

local function isAbilityEquipped(abilityName)
    for _, slotAbility in ipairs(bookActiveSlots) do
        if slotAbility == abilityName then return true end
    end
    return false
end

refreshCardVisuals = function()
    for name, card in pairs(abilityCardMap) do
        local stroke = card:FindFirstChildWhichIsA("UIStroke")
        local badge  = card:FindFirstChild("EquippedBadge")
        local equipped = isAbilityEquipped(name)
        if stroke then
            if selectedAbilityName == name then
                stroke.Color = C.AmberLight
                stroke.Thickness = 3
                card.BackgroundColor3 = Color3.fromRGB(40, 30, 8)
            elseif equipped then
                stroke.Color = C.Amber
                stroke.Thickness = 2
                card.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
            else
                stroke.Color = Color3.fromRGB(50, 38, 24)
                stroke.Thickness = 1
                card.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
            end
        end
        if badge then badge.Visible = equipped end
    end
end

local function buildAbilityCard(abilityName)
    if abilityCardMap[abilityName] then
        abilityCardMap[abilityName]:Destroy()
        abilityCardMap[abilityName] = nil
    end
    local ab = AbilitySystemMod.GetAbility(abilityName)
    if not ab then return end

    local equipped = isAbilityEquipped(abilityName)

    local card = Instance.new("TextButton")
    card.Name = abilityName
    card.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
    card.BorderSizePixel = 0
    card.Text = ""
    card.AutoButtonColor = false
    card.ZIndex = 24
    card.Parent = knownScroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local cardStroke = Instance.new("UIStroke", card)
    cardStroke.Color = equipped and C.Amber or Color3.fromRGB(50, 38, 24)
    cardStroke.Thickness = equipped and 2 or 1

    local cName = Instance.new("TextLabel")
    cName.Size = UDim2.new(1, -8, 0.38, 0)
    cName.Position = UDim2.new(0, 4, 0.04, 0)
    cName.BackgroundTransparency = 1
    cName.Text = ab.Name
    cName.TextColor3 = C.AmberLight
    cName.TextScaled = true
    cName.Font = Enum.Font.GothamBold
    cName.TextWrapped = true
    cName.TextXAlignment = Enum.TextXAlignment.Left
    cName.ZIndex = 25
    cName.Parent = card

    local cDesc = Instance.new("TextLabel")
    cDesc.Size = UDim2.new(1, -8, 0.30, 0)
    cDesc.Position = UDim2.new(0, 4, 0.42, 0)
    cDesc.BackgroundTransparency = 1
    local descText = ab.Description
    cDesc.Text = #descText > 52 and descText:sub(1, 52) .. "…" or descText
    cDesc.TextColor3 = C.TextDim
    cDesc.TextScaled = true
    cDesc.Font = Enum.Font.Gotham
    cDesc.TextWrapped = true
    cDesc.TextXAlignment = Enum.TextXAlignment.Left
    cDesc.ZIndex = 25
    cDesc.Parent = card

    -- Bottom cost/CD strip
    local strip = Instance.new("Frame")
    strip.Size = UDim2.new(1, 0, 0.22, 0)
    strip.Position = UDim2.new(0, 0, 0.78, 0)
    strip.BackgroundColor3 = Color3.fromRGB(10, 8, 6)
    strip.BackgroundTransparency = 0.3
    strip.BorderSizePixel = 0
    strip.ZIndex = 25
    strip.Parent = card
    Instance.new("UICorner", strip).CornerRadius = UDim.new(0, 8)

    local costTxt = Instance.new("TextLabel")
    costTxt.Size = UDim2.new(0.5, 0, 1, 0)
    costTxt.BackgroundTransparency = 1
    costTxt.Text = ab.MPCost > 0 and (ab.MPCost .. " Energy") or "Free"
    costTxt.TextColor3 = C.HakiFull
    costTxt.TextScaled = true
    costTxt.Font = Enum.Font.Gotham
    costTxt.ZIndex = 26
    costTxt.Parent = strip

    local cdTxt = Instance.new("TextLabel")
    cdTxt.Size = UDim2.new(0.5, 0, 1, 0)
    cdTxt.Position = UDim2.new(0.5, 0, 0, 0)
    cdTxt.BackgroundTransparency = 1
    cdTxt.Text = ab.Cooldown > 0 and (ab.Cooldown .. "s CD") or "Instant"
    cdTxt.TextColor3 = C.TextDim
    cdTxt.TextScaled = true
    cdTxt.Font = Enum.Font.Gotham
    cdTxt.ZIndex = 26
    cdTxt.Parent = strip

    -- "EQUIPPED" badge (top-right corner, hidden when not equipped)
    local badge = Instance.new("TextLabel")
    badge.Name = "EquippedBadge"
    badge.Size = UDim2.new(0, 68, 0, 18)
    badge.Position = UDim2.new(1, -72, 0, 4)
    badge.BackgroundColor3 = C.PanelBorder
    badge.BackgroundTransparency = 0.2
    badge.Text = "EQUIPPED"
    badge.TextColor3 = C.AmberLight
    badge.TextScaled = true
    badge.Font = Enum.Font.GothamBold
    badge.Visible = equipped
    badge.ZIndex = 26
    badge.Parent = card
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)

    card.MouseButton1Click:Connect(function()
        if selectedSlot then
            selectedAbilityName = abilityName
            trySwap()
            refreshSlotVisuals()
            refreshCardVisuals()
        else
            selectedAbilityName = (selectedAbilityName == abilityName) and nil or abilityName
            refreshCardVisuals()
            refreshSlotVisuals()
        end
    end)

    card.MouseEnter:Connect(function()
        if selectedAbilityName ~= abilityName and not isAbilityEquipped(abilityName) then
            TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(28, 22, 14) }):Play()
        end
    end)
    card.MouseLeave:Connect(function()
        if selectedAbilityName ~= abilityName and not isAbilityEquipped(abilityName) then
            TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(22, 17, 12) }):Play()
        end
    end)

    abilityCardMap[abilityName] = card
end

rebuildKnownGrid = function()
    for _, frame in pairs(abilityCardMap) do
        frame:Destroy()
    end
    abilityCardMap = {}
    for _, abilityName in ipairs(bookKnownAbilities) do
        buildAbilityCard(abilityName)
    end
    local cols = 3
    local rows = math.max(1, math.ceil(#bookKnownAbilities / cols))
    knownScroll.CanvasSize = UDim2.new(0, 0, 0, rows * (94 + 8) + 12)
    refreshSlotVisuals()
    refreshCardVisuals()
end

-- ── Synergy display strip (bottom of Ability Book) ──────────────────────────

local synergyStrip = Instance.new("Frame")
synergyStrip.Name = "SynergyStrip"
synergyStrip.Size = UDim2.new(1, -16, 0, 38)
synergyStrip.Position = UDim2.new(0, 8, 1, -46)
synergyStrip.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
synergyStrip.BackgroundTransparency = 0.2
synergyStrip.BorderSizePixel = 0
synergyStrip.ZIndex = 22
synergyStrip.Parent = abilityBook
Instance.new("UICorner", synergyStrip).CornerRadius = UDim.new(0, 8)
do local l=Instance.new("UIListLayout",synergyStrip); l.FillDirection=Enum.FillDirection.Horizontal; l.Padding=UDim.new(0,8); l.VerticalAlignment=Enum.VerticalAlignment.Center end
do local p=Instance.new("UIPadding",synergyStrip); p.PaddingLeft=UDim.new(0,6) end

local synTitleLbl = Instance.new("TextLabel")
synTitleLbl.Name = "SynTitle"
synTitleLbl.Size = UDim2.new(0, 130, 1, 0)
synTitleLbl.BackgroundTransparency = 1
synTitleLbl.Text = "SYNERGIES:"
synTitleLbl.TextColor3 = C.TextDim
synTitleLbl.TextScaled = true
synTitleLbl.Font = Enum.Font.GothamBold
synTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
synTitleLbl.ZIndex = 23
synTitleLbl.Parent = synergyStrip

local activeSynergyPills = {}

local SynergySystemClient = require(ReplicatedStorage.Modules.SynergySystem)

local function refreshSynergyPills(activeSynergyNames)
    -- Clear old pills
    for _, pill in ipairs(activeSynergyPills) do pill:Destroy() end
    activeSynergyPills = {}

    if not activeSynergyNames or #activeSynergyNames == 0 then
        local noneLbl = Instance.new("TextLabel")
        noneLbl.Size = UDim2.new(0, 120, 1, 0)
        noneLbl.BackgroundTransparency = 1
        noneLbl.Text = "None active"
        noneLbl.TextColor3 = C.TextDim
        noneLbl.TextScaled = true
        noneLbl.Font = Enum.Font.Gotham
        noneLbl.ZIndex = 23
        noneLbl.Parent = synergyStrip
        table.insert(activeSynergyPills, noneLbl)
        return
    end

    for _, name in ipairs(activeSynergyNames) do
        local syn = SynergySystemClient.Synergies[name]
        if syn then
            local pill = Instance.new("Frame")
            pill.Size = UDim2.new(0, 130, 0.7, 0)
            pill.BackgroundColor3 = syn.Color
            pill.BackgroundTransparency = 0.25
            pill.BorderSizePixel = 0
            pill.ZIndex = 23
            pill.Parent = synergyStrip
            Instance.new("UICorner", pill).CornerRadius = UDim.new(0.5, 0)
            local pillLbl = Instance.new("TextLabel")
            pillLbl.Size = UDim2.new(1, -8, 1, 0)
            pillLbl.Position = UDim2.new(0, 4, 0, 0)
            pillLbl.BackgroundTransparency = 1
            pillLbl.Text = syn.DisplayName
            pillLbl.TextColor3 = Color3.new(1, 1, 1)
            pillLbl.TextScaled = true
            pillLbl.Font = Enum.Font.GothamBold
            pillLbl.ZIndex = 24
            pillLbl.Parent = pill
            table.insert(activeSynergyPills, pill)
        end
    end
end

-- Refresh synergy pills when ability bar updates come in
UpdateHUD.OnClientEvent:Connect(function(data)
    if data.ActiveSynergies then
        refreshSynergyPills(data.ActiveSynergies)
        -- Also refresh when opening the book
    end
    if data.ActiveSlots and abilityBook and abilityBook.Visible then
        -- Re-compute synergies from equipped slots
        local activeSlotsList = data.ActiveSlots
        local activeSyn = SynergySystemClient.GetActiveSynergies(activeSlotsList)
        local names = {}
        for n in pairs(activeSyn) do table.insert(names, n) end
        refreshSynergyPills(names)
    end
end)

-- Initialize with no synergies
refreshSynergyPills(nil)

-- Close button
bookCloseBtn.MouseButton1Click:Connect(function()
    abilityBook.Visible = false
    selectedSlot = nil
    selectedAbilityName = nil
    refreshSlotVisuals()
    refreshCardVisuals()
end)

-- Tab key toggles the book (blocks ability input while open — handled in AbilityInput.client.lua)
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Tab then
        abilityBook.Visible = not abilityBook.Visible
        if not abilityBook.Visible then
            selectedSlot = nil
            selectedAbilityName = nil
            refreshSlotVisuals()
            refreshCardVisuals()
        else
            -- Refresh display when opening
            refreshSlotVisuals()
            rebuildKnownGrid()
        end
    end
end)

-- ────────────────────────────────────────────────
-- BOSS HEALTH BAR  (top-center, only visible during boss fight)
-- ────────────────────────────────────────────────

local BossPhaseEvt = RemoteEvents:WaitForChild("BossPhase", 15)

local bossBarFrame = Instance.new("Frame")
bossBarFrame.Name  = "BossBar"
bossBarFrame.Size  = UDim2.new(0, 500, 0, 52)
bossBarFrame.Position = UDim2.new(0.5, -250, 0, 54)
bossBarFrame.BackgroundColor3 = Color3.fromRGB(14, 8, 8)
bossBarFrame.BackgroundTransparency = 0.1
bossBarFrame.Visible = false
bossBarFrame.ZIndex  = 8
bossBarFrame.Parent  = hudGui
Instance.new("UICorner", bossBarFrame).CornerRadius = UDim.new(0, 10)
do local s=Instance.new("UIStroke",bossBarFrame); s.Color=Color3.fromRGB(220,30,30); s.Thickness=2 end

local bossNameLbl = Instance.new("TextLabel")
bossNameLbl.Size  = UDim2.new(1, -12, 0.40, 0)
bossNameLbl.Position = UDim2.new(0, 6, 0, 3)
bossNameLbl.BackgroundTransparency = 1
bossNameLbl.Text  = "BOSS"
bossNameLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
bossNameLbl.TextScaled = true
bossNameLbl.Font  = Enum.Font.GothamBold
bossNameLbl.ZIndex = 9
bossNameLbl.Parent = bossBarFrame

local bossFillBG = Instance.new("Frame")
bossFillBG.Size  = UDim2.new(1, -12, 0.38, 0)
bossFillBG.Position = UDim2.new(0, 6, 0.55, 0)
bossFillBG.BackgroundColor3 = Color3.fromRGB(50, 14, 14)
bossFillBG.BorderSizePixel = 0
bossFillBG.ZIndex = 9
bossFillBG.Parent = bossBarFrame
Instance.new("UICorner", bossFillBG).CornerRadius = UDim.new(0, 6)

local bossFill = Instance.new("Frame")
bossFill.Name  = "Fill"
bossFill.Size  = UDim2.new(1, 0, 1, 0)
bossFill.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
bossFill.BorderSizePixel = 0
bossFill.ZIndex = 10
bossFill.Parent = bossFillBG
Instance.new("UICorner", bossFill).CornerRadius = UDim.new(0, 6)

local bossPhaseLbl = Instance.new("TextLabel")
bossPhaseLbl.Size  = UDim2.new(0.25, 0, 0.38, 0)
bossPhaseLbl.Position = UDim2.new(0.75, 0, 0.55, 0)
bossPhaseLbl.BackgroundTransparency = 1
bossPhaseLbl.Text  = ""
bossPhaseLbl.TextColor3 = Color3.fromRGB(255, 200, 80)
bossPhaseLbl.TextScaled = true
bossPhaseLbl.Font  = Enum.Font.GothamBold
bossPhaseLbl.ZIndex = 11
bossPhaseLbl.Parent = bossBarFrame

-- Track the active boss model on the client side
local trackedBossModel = nil

local function watchBossModel(model)
    trackedBossModel = model
    bossNameLbl.Text = model:GetAttribute("BossName") or "BOSS"
    local totalPhases = model:GetAttribute("TotalPhases") or 1
    bossPhaseLbl.Text = "Phase 1 / " .. totalPhases
    bossBarFrame.Visible = true

    -- Live HP bar updates
    model:GetAttributeChangedSignal("HP"):Connect(function()
        if not model.Parent then return end
        local hp    = model:GetAttribute("HP") or 0
        local maxHP = model:GetAttribute("MaxHP") or 1
        local pct   = math.clamp(hp / maxHP, 0, 1)
        TweenService:Create(bossFill, TweenInfo.new(0.2), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
        -- Pulse red at low HP
        if pct < 0.25 then
            bossFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        elseif pct < 0.5 then
            bossFill.BackgroundColor3 = Color3.fromRGB(220, 60, 30)
        else
            bossFill.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
        end
    end)
end

-- Detect boss models appearing in workspace
workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") and obj:GetAttribute("IsBoss") then
        task.wait(0.2)  -- let all attributes settle
        watchBossModel(obj)
    end
end)

-- Hide bar when boss model is removed (dead)
workspace.DescendantRemoving:Connect(function(obj)
    if obj == trackedBossModel then
        trackedBossModel = nil
        TweenService:Create(bossBarFrame, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
        task.delay(0.9, function() bossBarFrame.Visible = false; bossBarFrame.BackgroundTransparency = 0.1 end)
    end
end)

-- Phase change: update phase label
if BossPhaseEvt then
    BossPhaseEvt.OnClientEvent:Connect(function(data)
        if trackedBossModel and trackedBossModel:GetAttribute("EnemyId") == data.EnemyId then
            bossPhaseLbl.Text = "Phase " .. data.Phase + 1 .. " / " .. data.TotalPhases
        end
        -- Phase flash overlay
        overlay.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
        overlayLabel.TextColor3  = Color3.fromRGB(255, 60, 60)
        overlay.BackgroundTransparency = 0.1
        local phaseNames = { [1] = "UNLEASHED", [2] = "BERSERK", [3] = "FINAL FORM" }
        overlayLabel.Text = "— PHASE " .. (data.Phase + 1) .. " —\n" .. (phaseNames[data.Phase] or "AWAKENED")
        TweenService:Create(overlay, TweenInfo.new(2.0, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
        task.delay(2.0, function() overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0) end)
    end)
end

-- ────────────────────────────────────────────────
-- LOOT CHOICE PANEL  (pick 1-of-3 after Elite / Boss clear)
-- ────────────────────────────────────────────────

local LootChoiceEvt = RemoteEvents:WaitForChild("LootChoice", 15)
local PickLootEvt   = RemoteEvents:WaitForChild("PickLoot",   15)

local lootChoiceFrame = Instance.new("Frame")
lootChoiceFrame.Name  = "LootChoicePanel"
lootChoiceFrame.Size  = UDim2.new(0, 660, 0, 340)
lootChoiceFrame.Position = UDim2.new(0.5, -330, 0.5, -170)
lootChoiceFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 6)
lootChoiceFrame.BackgroundTransparency = 0.08
lootChoiceFrame.Visible  = false
lootChoiceFrame.ZIndex   = 30
lootChoiceFrame.Parent   = hudGui
Instance.new("UICorner", lootChoiceFrame).CornerRadius = UDim.new(0, 16)
local lcStroke = Instance.new("UIStroke", lootChoiceFrame)
lcStroke.Color     = C.AmberLight
lcStroke.Thickness = 2

-- Header
local lcHeader = Instance.new("TextLabel")
lcHeader.Size  = UDim2.new(1, -16, 0, 42)
lcHeader.Position = UDim2.new(0, 8, 0, 8)
lcHeader.BackgroundTransparency = 1
lcHeader.Text  = "CLAIM YOUR REWARD"
lcHeader.TextColor3 = C.AmberLight
lcHeader.TextScaled = true
lcHeader.Font  = Enum.Font.GothamBold
lcHeader.ZIndex = 31
lcHeader.Parent = lootChoiceFrame

local lcSub = Instance.new("TextLabel")
lcSub.Size  = UDim2.new(1, -16, 0, 22)
lcSub.Position = UDim2.new(0, 8, 0, 46)
lcSub.BackgroundTransparency = 1
lcSub.Text  = "Choose one item to keep"
lcSub.TextColor3 = C.TextDim
lcSub.TextScaled = true
lcSub.Font  = Enum.Font.Gotham
lcSub.ZIndex = 31
lcSub.Parent = lootChoiceFrame

-- Card container
local lcCards = Instance.new("Frame")
lcCards.Size = UDim2.new(1, -24, 1, -86)
lcCards.Position = UDim2.new(0, 12, 0, 74)
lcCards.BackgroundTransparency = 1
lcCards.ZIndex = 31
lcCards.Parent = lootChoiceFrame
local lcLayout = Instance.new("UIListLayout", lcCards)
lcLayout.FillDirection = Enum.FillDirection.Horizontal
lcLayout.Padding = UDim.new(0, 12)
lcLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local currentLootRoomId = nil

local function buildLootChoiceCard(entry, roomId)
    local rColor = rarityColors[entry.Item.Rarity] or C.TextMain

    local card = Instance.new("TextButton")
    card.Size = UDim2.new(0, 198, 1, 0)
    card.BackgroundColor3 = Color3.fromRGB(18, 14, 10)
    card.BorderSizePixel = 0
    card.Text = ""
    card.AutoButtonColor = false
    card.ZIndex = 32
    card.Parent = lcCards
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    local cStroke = Instance.new("UIStroke", card)
    cStroke.Color     = rColor
    cStroke.Thickness = 1.5

    -- Rarity bar at top
    local rarBar = Instance.new("Frame")
    rarBar.Size = UDim2.new(1, 0, 0.05, 0)
    rarBar.BackgroundColor3 = rColor
    rarBar.BorderSizePixel = 0
    rarBar.ZIndex = 33
    rarBar.Parent = card
    Instance.new("UICorner", rarBar).CornerRadius = UDim.new(0, 10)

    -- Rarity badge
    local rarBadge = Instance.new("TextLabel")
    rarBadge.Size = UDim2.new(0.7, 0, 0.11, 0)
    rarBadge.Position = UDim2.new(0.15, 0, 0.07, 0)
    rarBadge.BackgroundColor3 = rColor
    rarBadge.BackgroundTransparency = 0.3
    rarBadge.Text = string.upper(entry.Item.Rarity)
    rarBadge.TextColor3 = Color3.new(1, 1, 1)
    rarBadge.TextScaled = true
    rarBadge.Font = Enum.Font.GothamBold
    rarBadge.ZIndex = 33
    rarBadge.Parent = card
    Instance.new("UICorner", rarBadge).CornerRadius = UDim.new(0, 6)

    local itemName = Instance.new("TextLabel")
    itemName.Size = UDim2.new(1, -8, 0.22, 0)
    itemName.Position = UDim2.new(0, 4, 0.20, 0)
    itemName.BackgroundTransparency = 1
    itemName.Text = entry.Item.Name
    itemName.TextColor3 = rColor
    itemName.TextScaled = true
    itemName.Font = Enum.Font.GothamBold
    itemName.TextWrapped = true
    itemName.ZIndex = 33
    itemName.Parent = card

    local itemDesc = Instance.new("TextLabel")
    itemDesc.Size = UDim2.new(1, -8, 0.30, 0)
    itemDesc.Position = UDim2.new(0, 4, 0.43, 0)
    itemDesc.BackgroundTransparency = 1
    itemDesc.Text = entry.Item.Description or ""
    itemDesc.TextColor3 = C.TextDim
    itemDesc.TextScaled = true
    itemDesc.Font = Enum.Font.Gotham
    itemDesc.TextWrapped = true
    itemDesc.ZIndex = 33
    itemDesc.Parent = card

    -- Claim button
    local claimBtn = Instance.new("TextButton")
    claimBtn.Size = UDim2.new(0.78, 0, 0.13, 0)
    claimBtn.Position = UDim2.new(0.11, 0, 0.83, 0)
    claimBtn.BackgroundColor3 = rColor
    claimBtn.Text = "CLAIM"
    claimBtn.TextColor3 = Color3.new(1, 1, 1)
    claimBtn.TextScaled = true
    claimBtn.Font = Enum.Font.GothamBold
    claimBtn.BorderSizePixel = 0
    claimBtn.ZIndex = 33
    claimBtn.Parent = card
    Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 8)

    local function claim()
        if PickLootEvt then PickLootEvt:FireServer(entry.ItemName, roomId) end
        -- Slide out and hide
        TweenService:Create(lootChoiceFrame,
            TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In),
            { Position = UDim2.new(0.5, -330, 1.1, 0) }
        ):Play()
        task.delay(0.4, function()
            lootChoiceFrame.Visible = false
            lootChoiceFrame.Position = UDim2.new(0.5, -330, 0.5, -170)
        end)
    end
    claimBtn.MouseButton1Click:Connect(claim)
    card.MouseButton1Click:Connect(claim)

    card.MouseEnter:Connect(function()
        TweenService:Create(cStroke, TweenInfo.new(0.1), { Thickness = 3 }):Play()
        TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(26, 20, 14) }):Play()
    end)
    card.MouseLeave:Connect(function()
        TweenService:Create(cStroke, TweenInfo.new(0.1), { Thickness = 1.5 }):Play()
        TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(18, 14, 10) }):Play()
    end)
end

if LootChoiceEvt then
    LootChoiceEvt.OnClientEvent:Connect(function(data)
        -- Clear previous cards
        for _, child in ipairs(lcCards:GetChildren()) do
            if child:IsA("GuiObject") and child.ClassName ~= "UIListLayout" then
                child:Destroy()
            end
        end
        currentLootRoomId = data.RoomId
        local title = (data.RoomType == "Boss") and "BOSS LOOT — CLAIM YOUR REWARD"
            or "ELITE LOOT — CLAIM YOUR REWARD"
        lcHeader.Text = title
        for _, entry in ipairs(data.Choices) do
            buildLootChoiceCard(entry, data.RoomId)
        end
        -- Slide in from below
        lootChoiceFrame.Position = UDim2.new(0.5, -330, 1.1, 0)
        lootChoiceFrame.Visible  = true
        TweenService:Create(lootChoiceFrame,
            TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = UDim2.new(0.5, -330, 0.5, -170) }
        ):Play()
    end)
end

-- ────────────────────────────────────────────────
-- SHRINE PANEL  (permanent stat upgrade for gold)
-- ────────────────────────────────────────────────

local ShrineOpenEvt = RemoteEvents:WaitForChild("ShrineOpen", 15)
local PickShrineEvt = RemoteEvents:WaitForChild("PickShrine", 15)

local shrineFrame = Instance.new("Frame")
shrineFrame.Name  = "ShrinePanel"
shrineFrame.Size  = UDim2.new(0, 560, 0, 400)
shrineFrame.Position = UDim2.new(0.5, -280, 0.5, -200)
shrineFrame.BackgroundColor3 = Color3.fromRGB(8, 6, 4)
shrineFrame.BackgroundTransparency = 0.06
shrineFrame.Visible  = false
shrineFrame.ZIndex   = 30
shrineFrame.Parent   = hudGui
Instance.new("UICorner", shrineFrame).CornerRadius = UDim.new(0, 16)
local shStroke = Instance.new("UIStroke", shrineFrame)
shStroke.Color     = Color3.fromRGB(255, 215, 100)
shStroke.Thickness = 2

local shrineTitle = Instance.new("TextLabel")
shrineTitle.Size  = UDim2.new(1, -16, 0, 44)
shrineTitle.Position = UDim2.new(0, 8, 0, 8)
shrineTitle.BackgroundTransparency = 1
shrineTitle.Text  = "✦  ANCIENT SHRINE  ✦"
shrineTitle.TextColor3 = Color3.fromRGB(255, 215, 100)
shrineTitle.TextScaled = true
shrineTitle.Font  = Enum.Font.GothamBold
shrineTitle.ZIndex = 31
shrineTitle.Parent = shrineFrame

local shrineSub = Instance.new("TextLabel")
shrineSub.Size  = UDim2.new(1, -16, 0, 22)
shrineSub.Position = UDim2.new(0, 8, 0, 50)
shrineSub.BackgroundTransparency = 1
shrineSub.Text  = "Choose one permanent blessing (spend Bounty)"
shrineSub.TextColor3 = C.TextDim
shrineSub.TextScaled = true
shrineSub.Font  = Enum.Font.Gotham
shrineSub.ZIndex = 31
shrineSub.Parent = shrineFrame

local shrineClose = Instance.new("TextButton")
shrineClose.Size  = UDim2.new(0, 34, 0, 34)
shrineClose.Position = UDim2.new(1, -40, 0, 8)
shrineClose.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
shrineClose.Text  = "✕"
shrineClose.TextColor3 = Color3.new(1, 1, 1)
shrineClose.TextScaled = true
shrineClose.Font  = Enum.Font.GothamBold
shrineClose.BorderSizePixel = 0
shrineClose.ZIndex = 32
shrineClose.Parent = shrineFrame
Instance.new("UICorner", shrineClose).CornerRadius = UDim.new(0, 8)
shrineClose.MouseButton1Click:Connect(function() shrineFrame.Visible = false end)

local shrineOptContainer = Instance.new("Frame")
shrineOptContainer.Size = UDim2.new(1, -24, 1, -86)
shrineOptContainer.Position = UDim2.new(0, 12, 0, 78)
shrineOptContainer.BackgroundTransparency = 1
shrineOptContainer.ZIndex = 31
shrineOptContainer.Parent = shrineFrame
local shrineLayout = Instance.new("UIListLayout", shrineOptContainer)
shrineLayout.Padding = UDim.new(0, 10)
shrineLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function buildShrineOption(opt, roomId, alreadyChosen)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 82)
    row.BackgroundColor3 = Color3.fromRGB(20, 16, 10)
    row.BorderSizePixel = 0
    row.ZIndex = 32
    row.Parent = shrineOptContainer
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
    local rStroke = Instance.new("UIStroke", row)
    rStroke.Color = Color3.fromRGB(120, 90, 30)
    rStroke.Thickness = 1

    local optName = Instance.new("TextLabel")
    optName.Size = UDim2.new(0.55, 0, 0.44, 0)
    optName.Position = UDim2.new(0, 10, 0, 4)
    optName.BackgroundTransparency = 1
    optName.Text = opt.Name
    optName.TextColor3 = Color3.fromRGB(255, 215, 100)
    optName.TextScaled = true
    optName.Font = Enum.Font.GothamBold
    optName.TextXAlignment = Enum.TextXAlignment.Left
    optName.ZIndex = 33
    optName.Parent = row

    local optDesc = Instance.new("TextLabel")
    optDesc.Size = UDim2.new(0.55, 0, 0.44, 0)
    optDesc.Position = UDim2.new(0, 10, 0.50, 0)
    optDesc.BackgroundTransparency = 1
    optDesc.Text = opt.Description
    optDesc.TextColor3 = C.TextDim
    optDesc.TextScaled = true
    optDesc.Font = Enum.Font.Gotham
    optDesc.TextWrapped = true
    optDesc.TextXAlignment = Enum.TextXAlignment.Left
    optDesc.ZIndex = 33
    optDesc.Parent = row

    local costLbl = Instance.new("TextLabel")
    costLbl.Size = UDim2.new(0.2, 0, 0.5, 0)
    costLbl.Position = UDim2.new(0.60, 0, 0.25, 0)
    costLbl.BackgroundTransparency = 1
    costLbl.Text = opt.Cost .. " B"
    costLbl.TextColor3 = C.Amber
    costLbl.TextScaled = true
    costLbl.Font = Enum.Font.GothamBold
    costLbl.ZIndex = 33
    costLbl.Parent = row

    local buyBtn = Instance.new("TextButton")
    buyBtn.Size = UDim2.new(0.14, 0, 0.5, 0)
    buyBtn.Position = UDim2.new(0.83, 0, 0.25, 0)
    buyBtn.BackgroundColor3 = alreadyChosen and Color3.fromRGB(60, 50, 30) or Color3.fromRGB(120, 90, 20)
    buyBtn.Text = alreadyChosen and "USED" or "BLESS"
    buyBtn.TextColor3 = Color3.new(1, 1, 1)
    buyBtn.TextScaled = true
    buyBtn.Font = Enum.Font.GothamBold
    buyBtn.BorderSizePixel = 0
    buyBtn.Active = not alreadyChosen
    buyBtn.ZIndex = 33
    buyBtn.Parent = row
    Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 8)

    if not alreadyChosen then
        buyBtn.MouseButton1Click:Connect(function()
            if PickShrineEvt then PickShrineEvt:FireServer(opt.Id, roomId) end
            shrineFrame.Visible = false
        end)
        buyBtn.MouseEnter:Connect(function()
            TweenService:Create(buyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(200, 155, 30) }):Play()
        end)
        buyBtn.MouseLeave:Connect(function()
            TweenService:Create(buyBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(120, 90, 20) }):Play()
        end)
    end
end

if ShrineOpenEvt then
    ShrineOpenEvt.OnClientEvent:Connect(function(data)
        for _, child in ipairs(shrineOptContainer:GetChildren()) do
            if child:IsA("GuiObject") and child.ClassName ~= "UIListLayout" then
                child:Destroy()
            end
        end
        for _, opt in ipairs(data.Options) do
            buildShrineOption(opt, data.RoomId, data.AlreadyChosen)
        end
        shrineFrame.Visible = true
    end)
end

-- ────────────────────────────────────────────────
-- ROOM CLEARED BANNER
-- ────────────────────────────────────────────────

local RoomClearedEvt = RemoteEvents:WaitForChild("RoomCleared", 15)

local clearedBanner = Instance.new("Frame")
clearedBanner.Size  = UDim2.new(0, 380, 0, 60)
clearedBanner.Position = UDim2.new(0.5, -190, 0, -70)
clearedBanner.BackgroundColor3 = Color3.fromRGB(10, 30, 10)
clearedBanner.BackgroundTransparency = 0.12
clearedBanner.Visible = false
clearedBanner.ZIndex  = 25
clearedBanner.Parent  = hudGui
Instance.new("UICorner", clearedBanner).CornerRadius = UDim.new(0, 12)
local cbStroke = Instance.new("UIStroke", clearedBanner)
cbStroke.Color = C.Green
cbStroke.Thickness = 2

local cbLabel = Instance.new("TextLabel")
cbLabel.Size  = UDim2.new(1, -12, 0.6, 0)
cbLabel.Position = UDim2.new(0, 6, 0.1, 0)
cbLabel.BackgroundTransparency = 1
cbLabel.Text  = "ROOM CLEARED!"
cbLabel.TextColor3 = C.Green
cbLabel.TextScaled = true
cbLabel.Font  = Enum.Font.GothamBold
cbLabel.ZIndex = 26
cbLabel.Parent = clearedBanner

local cbProgressLbl = Instance.new("TextLabel")
cbProgressLbl.Size  = UDim2.new(1, -12, 0.32, 0)
cbProgressLbl.Position = UDim2.new(0, 6, 0.62, 0)
cbProgressLbl.BackgroundTransparency = 1
cbProgressLbl.Text  = ""
cbProgressLbl.TextColor3 = C.TextDim
cbProgressLbl.TextScaled = true
cbProgressLbl.Font  = Enum.Font.Gotham
cbProgressLbl.ZIndex = 26
cbProgressLbl.Parent = clearedBanner

local function showClearedBanner(roomType, cleared, total)
    if roomType == "Boss" then
        cbLabel.Text = "BOSS DEFEATED!"
        cbLabel.TextColor3 = C.AmberLight
        cbStroke.Color = C.AmberLight
        clearedBanner.BackgroundColor3 = Color3.fromRGB(30, 20, 0)
    elseif roomType == "Elite" then
        cbLabel.Text = "ELITE ROOM CLEARED!"
        cbLabel.TextColor3 = Color3.fromRGB(180, 100, 255)
        cbStroke.Color = Color3.fromRGB(180, 100, 255)
        clearedBanner.BackgroundColor3 = Color3.fromRGB(20, 0, 30)
    else
        cbLabel.Text = "ROOM CLEARED!"
        cbLabel.TextColor3 = C.Green
        cbStroke.Color = C.Green
        clearedBanner.BackgroundColor3 = Color3.fromRGB(10, 30, 10)
    end
    if cleared and total then
        cbProgressLbl.Text = cleared .. " / " .. total .. " rooms cleared"
    else
        cbProgressLbl.Text = ""
    end

    clearedBanner.Position = UDim2.new(0.5, -190, 0, -70)
    clearedBanner.Visible  = true
    -- Slide down from top
    TweenService:Create(clearedBanner,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -190, 0, 16) }
    ):Play()
    -- Hold then slide back up
    task.delay(2.2, function()
        TweenService:Create(clearedBanner,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(0.5, -190, 0, -70) }
        ):Play()
        task.delay(0.3, function() clearedBanner.Visible = false end)
    end)
end

if RoomClearedEvt then
    RoomClearedEvt.OnClientEvent:Connect(function(data)
        showClearedBanner(data.RoomType, data.Cleared, data.Total)
        -- Update floor progress in floor label
        if data.Cleared and data.Total and floorLabel then
            local cur = floorLabel.Text
            -- Strip old progress suffix if present
            local base = cur:match("^(.-)%s*·%s*%d+/%d+") or cur
            floorLabel.Text = base .. "  ·  " .. data.Cleared .. "/" .. data.Total
        end
    end)
end

-- ────────────────────────────────────────────────
-- BUFF / DEBUFF ICON STRIP  (below HP bar)
-- ────────────────────────────────────────────────

local statusStrip = Instance.new("Frame")
statusStrip.Name  = "StatusStrip"
statusStrip.Size  = UDim2.new(0, 300, 0, 26)
statusStrip.Position = UDim2.new(0, 16, 1, -162)
statusStrip.BackgroundTransparency = 1
statusStrip.ZIndex = 5
statusStrip.Parent = hudGui
local statusLayout = Instance.new("UIListLayout", statusStrip)
statusLayout.FillDirection = Enum.FillDirection.Horizontal
statusLayout.Padding = UDim.new(0, 4)
statusLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local activeStatusIcons = {}  -- { name = frame }

local STATUS_COLORS = {
    -- Buffs (green shades)
    BankaiState   = Color3.fromRGB(100, 220, 200),
    DefenseUp     = Color3.fromRGB(60, 200, 100),
    IronSkin      = Color3.fromRGB(160, 170, 255),
    ManaShield    = Color3.fromRGB(80, 120, 255),
    CounterReady  = Color3.fromRGB(255, 200, 50),
    PoisonCoat    = Color3.fromRGB(80, 220, 80),
    BerserkMode   = Color3.fromRGB(255, 80, 80),
    AwakeningActive = Color3.fromRGB(255, 160, 30),
    -- Debuffs (red/purple shades)
    Slow          = Color3.fromRGB(120, 200, 255),
    Stun          = Color3.fromRGB(255, 240, 60),
    Poison        = Color3.fromRGB(80, 220, 50),
    Burn          = Color3.fromRGB(255, 90, 20),
    DeathMark     = Color3.fromRGB(255, 30, 30),
}

local STATUS_ABBREV = {
    BankaiState = "BKI", DefenseUp = "DEF", IronSkin = "IRN", ManaShield = "SHD",
    CounterReady = "CTR", PoisonCoat = "PSN", BerserkMode = "BRK", AwakeningActive = "AWK",
    Slow = "SLW", Stun = "STN", Poison = "PSN", Burn = "BRN", DeathMark = "MRK",
}

local function refreshStatusIcons(buffs, debuffs)
    -- Mark all existing as stale
    for name, icon in pairs(activeStatusIcons) do
        icon._stale = true
    end

    local function upsertIcon(name, isDebuff)
        if activeStatusIcons[name] then
            activeStatusIcons[name]._stale = nil
            return
        end
        local color = STATUS_COLORS[name] or (isDebuff and Color3.fromRGB(220, 80, 80) or Color3.fromRGB(80, 200, 80))
        local icon = Instance.new("Frame")
        icon.Size = UDim2.new(0, 26, 0, 26)
        icon.BackgroundColor3 = color
        icon.BackgroundTransparency = 0.25
        icon.BorderSizePixel = 0
        icon.ZIndex = 6
        icon.Parent = statusStrip
        Instance.new("UICorner", icon).CornerRadius = UDim.new(0, 6)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = STATUS_ABBREV[name] or name:sub(1, 3):upper()
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.ZIndex = 7
        lbl.Parent = icon
        -- Debuffs get a subtle red underline
        if isDebuff then
            local underline = Instance.new("Frame")
            underline.Size = UDim2.new(1, 0, 0.08, 0)
            underline.Position = UDim2.new(0, 0, 0.92, 0)
            underline.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
            underline.BorderSizePixel = 0
            underline.ZIndex = 8
            underline.Parent = icon
        end
        activeStatusIcons[name] = icon
    end

    if buffs then
        for _, name in ipairs(buffs) do upsertIcon(name, false) end
    end
    if debuffs then
        for _, name in ipairs(debuffs) do upsertIcon(name, true) end
    end

    -- Remove stale icons
    for name, icon in pairs(activeStatusIcons) do
        if icon._stale then
            icon:Destroy()
            activeStatusIcons[name] = nil
        end
    end
end

-- Server will send StatusEffects in UpdateHUD
local _origUpdateHUDConn = UpdateHUD.OnClientEvent
UpdateHUD.OnClientEvent:Connect(function(data)
    if data.StatusEffects then
        refreshStatusIcons(data.StatusEffects.Buffs, data.StatusEffects.Debuffs)
    end
end)

-- ────────────────────────────────────────────────
-- AWAKENING GAUGE  (amber glow bar, bottom-left)
-- ────────────────────────────────────────────────

local AwakeningStateEvt = RemoteEvents:WaitForChild("AwakeningState", 15)

-- Container panel
local awakePanel = Instance.new("Frame")
awakePanel.Name              = "AwakeningGaugePanel"
awakePanel.Size              = UDim2.new(0, 220, 0, 22)
awakePanel.Position          = UDim2.new(0, 16, 1, -192)   -- just below the Haki bar
awakePanel.BackgroundColor3  = Color3.fromRGB(20, 15, 8)
awakePanel.BackgroundTransparency = 0.1
awakePanel.BorderSizePixel   = 0
awakePanel.ZIndex            = 5
awakePanel.Parent            = hudGui
Instance.new("UICorner", awakePanel).CornerRadius = UDim.new(0, 6)
local awakeStroke = Instance.new("UIStroke", awakePanel)
awakeStroke.Color     = Color3.fromRGB(200, 100, 10)
awakeStroke.Thickness = 1.5

-- Fill bar
local awakeFill = Instance.new("Frame")
awakeFill.Name              = "Fill"
awakeFill.Size              = UDim2.new(0, 0, 1, 0)   -- starts empty
awakeFill.BackgroundColor3  = Color3.fromRGB(255, 160, 30)
awakeFill.BorderSizePixel   = 0
awakeFill.ZIndex            = 6
awakeFill.Parent            = awakePanel
Instance.new("UICorner", awakeFill).CornerRadius = UDim.new(0, 6)

-- Gloss sheen
local awakeGloss = Instance.new("Frame")
awakeGloss.Size             = UDim2.new(1, 0, 0.4, 0)
awakeGloss.BackgroundColor3 = Color3.new(1, 1, 1)
awakeGloss.BackgroundTransparency = 0.82
awakeGloss.BorderSizePixel  = 0
awakeGloss.ZIndex           = 7
awakeGloss.Parent           = awakeFill
Instance.new("UICorner", awakeGloss).CornerRadius = UDim.new(0, 6)

-- Label: "AWAKENING" + percentage
local awakeLbl = Instance.new("TextLabel")
awakeLbl.Size              = UDim2.new(1, -6, 1, 0)
awakeLbl.Position          = UDim2.new(0, 3, 0, 0)
awakeLbl.BackgroundTransparency = 1
awakeLbl.Text              = "AWAKENING  0%"
awakeLbl.TextColor3        = Color3.fromRGB(255, 210, 100)
awakeLbl.TextScaled        = true
awakeLbl.Font              = Enum.Font.GothamBold
awakeLbl.TextXAlignment    = Enum.TextXAlignment.Left
awakeLbl.ZIndex            = 8
awakeLbl.Parent            = awakePanel

-- "READY" pulse animation when gauge is full
local awakeReadyPulse = false
local function pulseAwakeBar()
    if not awakeReadyPulse then return end
    TweenService:Create(awakeStroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Color = Color3.fromRGB(255, 240, 80) }):Play()
end

local function updateAwakeningGauge(pct)
    pct = math.clamp(pct, 0, 100)
    local ratio = pct / 100
    TweenService:Create(awakeFill, TweenInfo.new(0.2), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
    if pct >= 100 then
        awakeLbl.Text = "AWAKENING  READY! [G]"
        awakeLbl.TextColor3 = Color3.fromRGB(255, 240, 80)
        awakeReadyPulse = true
        pulseAwakeBar()
    else
        awakeLbl.Text = "AWAKENING  " .. math.floor(pct) .. "%"
        awakeLbl.TextColor3 = Color3.fromRGB(255, 210, 100)
        awakeReadyPulse = false
        awakeStroke.Color = Color3.fromRGB(200, 100, 10)
    end
end

-- Full-screen awakening activation flash
local awakeFlashFrame = Instance.new("Frame")
awakeFlashFrame.Size              = UDim2.new(1, 0, 1, 0)
awakeFlashFrame.BackgroundColor3  = Color3.fromRGB(255, 160, 30)
awakeFlashFrame.BackgroundTransparency = 1
awakeFlashFrame.ZIndex            = 35
awakeFlashFrame.Visible           = false
awakeFlashFrame.Parent            = hudGui

local awakeNameBanner = Instance.new("TextLabel")
awakeNameBanner.Size             = UDim2.new(0.7, 0, 0.18, 0)
awakeNameBanner.Position         = UDim2.new(0.15, 0, 0.38, 0)
awakeNameBanner.BackgroundTransparency = 1
awakeNameBanner.Text             = ""
awakeNameBanner.TextColor3       = Color3.fromRGB(255, 240, 80)
awakeNameBanner.TextScaled       = true
awakeNameBanner.Font             = Enum.Font.GothamBold
awakeNameBanner.ZIndex           = 36
awakeNameBanner.Parent           = awakeFlashFrame
local awakeStrokeLabel = Instance.new("UIStroke", awakeNameBanner)
awakeStrokeLabel.Color = Color3.fromRGB(200, 100, 0)
awakeStrokeLabel.Thickness = 3

local function showAwakeningActivation(name, auraColor)
    awakeFlashFrame.BackgroundColor3 = auraColor or Color3.fromRGB(255, 160, 30)
    awakeNameBanner.Text = name or "AWAKENING!"
    awakeFlashFrame.BackgroundTransparency = 0.4
    awakeFlashFrame.Visible = true

    TweenService:Create(awakeFlashFrame,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    ):Play()
    task.delay(0.8, function() awakeFlashFrame.Visible = false end)
end

-- UpdateHUD gauge updates
UpdateHUD.OnClientEvent:Connect(function(data)
    if data.AwakeningGauge ~= nil then
        updateAwakeningGauge(data.AwakeningGauge)
    end
end)

-- AwakeningState: activation flash (only for our own player; aura VFX in CombatVFX)
if AwakeningStateEvt then
    AwakeningStateEvt.OnClientEvent:Connect(function(data)
        local localPlayer = game:GetService("Players").LocalPlayer
        if data.PlayerUserId ~= localPlayer.UserId then return end
        if data.Active then
            local aColor = data.AuraColor
                and Color3.new(data.AuraColor.R, data.AuraColor.G, data.AuraColor.B)
                or Color3.fromRGB(255, 160, 30)
            showAwakeningActivation(data.AwakeningName, aColor)
            -- Drain gauge display to 0 (server already cleared it)
            updateAwakeningGauge(0)
        end
    end)
end

-- ────────────────────────────────────────────────
-- LEGACY PANEL  (Tab = open/close mastery shop)
-- ────────────────────────────────────────────────

local MetaSyncEvt    = RemoteEvents:WaitForChild("MetaSync",    15)
local MetaUpgradeEvt = RemoteEvents:WaitForChild("MetaUpgrade", 15)

-- Root frame — centered modal
local legacyPanel = Instance.new("Frame")
legacyPanel.Name              = "LegacyPanel"
legacyPanel.Size              = UDim2.new(0, 700, 0, 480)
legacyPanel.Position          = UDim2.new(0.5, -350, 0.5, -240)
legacyPanel.BackgroundColor3  = Color3.fromRGB(10, 8, 6)
legacyPanel.BackgroundTransparency = 0.06
legacyPanel.BorderSizePixel   = 0
legacyPanel.Visible           = false
legacyPanel.ZIndex            = 40
legacyPanel.Parent            = hudGui
Instance.new("UICorner", legacyPanel).CornerRadius = UDim.new(0, 14)
local legStroke = Instance.new("UIStroke", legacyPanel)
legStroke.Color     = C.Amber
legStroke.Thickness = 2

-- Title bar
local legTitle = Instance.new("TextLabel")
legTitle.Size              = UDim2.new(1, -20, 0, 40)
legTitle.Position          = UDim2.new(0, 10, 0, 8)
legTitle.BackgroundTransparency = 1
legTitle.Text              = "LEGACY  —  Mastery Upgrades"
legTitle.TextColor3        = C.AmberLight
legTitle.TextScaled        = true
legTitle.Font              = Enum.Font.GothamBold
legTitle.ZIndex            = 41
legTitle.Parent            = legacyPanel

-- Points label (top-right)
local legPointsLbl = Instance.new("TextLabel")
legPointsLbl.Size              = UDim2.new(0, 200, 0, 30)
legPointsLbl.Position          = UDim2.new(1, -210, 0, 14)
legPointsLbl.BackgroundTransparency = 1
legPointsLbl.Text              = "0 MP"
legPointsLbl.TextColor3        = C.AmberLight
legPointsLbl.TextScaled        = true
legPointsLbl.Font              = Enum.Font.GothamBold
legPointsLbl.TextXAlignment    = Enum.TextXAlignment.Right
legPointsLbl.ZIndex            = 42
legPointsLbl.Parent            = legacyPanel

-- Divider
local legDiv = Instance.new("Frame")
legDiv.Size             = UDim2.new(1, -20, 0, 1)
legDiv.Position         = UDim2.new(0, 10, 0, 52)
legDiv.BackgroundColor3 = C.PanelBorder
legDiv.BorderSizePixel  = 0
legDiv.ZIndex           = 41
legDiv.Parent           = legacyPanel

-- Scrollable container for passive cards
local legScroll = Instance.new("ScrollingFrame")
legScroll.Size              = UDim2.new(1, -20, 1, -70)
legScroll.Position          = UDim2.new(0, 10, 0, 58)
legScroll.BackgroundTransparency = 1
legScroll.BorderSizePixel   = 0
legScroll.ScrollBarThickness = 6
legScroll.ScrollBarImageColor3 = C.Amber
legScroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
legScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
legScroll.ZIndex            = 41
legScroll.Parent            = legacyPanel
local legLayout = Instance.new("UIListLayout", legScroll)
legLayout.Padding           = UDim.new(0, 8)
legLayout.SortOrder         = Enum.SortOrder.Name

-- Close hint
local legHint = Instance.new("TextLabel")
legHint.Size              = UDim2.new(1, 0, 0, 18)
legHint.Position          = UDim2.new(0, 0, 1, -22)
legHint.BackgroundTransparency = 1
legHint.Text              = "[TAB] close"
legHint.TextColor3        = C.TextDim
legHint.TextScaled        = true
legHint.Font              = Enum.Font.Gotham
legHint.ZIndex            = 41
legHint.Parent            = legacyPanel

-- ── Passive card builder ──────────────────────────────────────────────────────
local legacyData = {}   -- latest data from server: { MasteryPoints, Passives }

local RARITY_COLORS = {
    [1] = Color3.fromRGB(100, 200, 100),   -- Level 1: green
    [2] = Color3.fromRGB(80, 140, 255),    -- Level 2: blue
    [3] = Color3.fromRGB(180, 80, 255),    -- Level 3: purple
    [4] = Color3.fromRGB(255, 170, 30),    -- Level 4: gold
}

local function buildPassiveCard(passive, masteryPoints)
    local card = Instance.new("Frame")
    card.Name             = passive.Id
    card.Size             = UDim2.new(1, -8, 0, 80)
    card.BackgroundColor3 = Color3.fromRGB(22, 18, 12)
    card.BorderSizePixel  = 0
    card.ZIndex           = 42
    card.Parent           = legScroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    local cStroke = Instance.new("UIStroke", card)
    cStroke.Color     = (passive.Maxed and C.Amber) or Color3.fromRGB(80, 60, 30)
    cStroke.Thickness = 1.5

    -- Level pip strip (left side)
    local pipFrame = Instance.new("Frame")
    pipFrame.Size             = UDim2.new(0, 12, 1, -16)
    pipFrame.Position         = UDim2.new(0, 8, 0, 8)
    pipFrame.BackgroundTransparency = 1
    pipFrame.BorderSizePixel  = 0
    pipFrame.ZIndex           = 43
    pipFrame.Parent           = card
    local pipLayout = Instance.new("UIListLayout", pipFrame)
    pipLayout.FillDirection   = Enum.FillDirection.Vertical
    pipLayout.Padding         = UDim.new(0, 4)
    pipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    for i = 1, passive.MaxLevel do
        local pip = Instance.new("Frame")
        pip.Size              = UDim2.new(1, 0, 0, 10)
        pip.BackgroundColor3  = (i <= passive.CurrentLevel) and (RARITY_COLORS[i] or C.Amber) or Color3.fromRGB(50, 40, 25)
        pip.BorderSizePixel   = 0
        pip.ZIndex            = 44
        pip.Parent            = pipFrame
        Instance.new("UICorner", pip).CornerRadius = UDim.new(0, 3)
    end

    -- Name label
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size              = UDim2.new(1, -110, 0, 26)
    nameLbl.Position          = UDim2.new(0, 28, 0, 8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text              = passive.Name
    nameLbl.TextColor3        = passive.Maxed and C.AmberLight or C.TextMain
    nameLbl.TextScaled        = true
    nameLbl.Font              = Enum.Font.GothamBold
    nameLbl.TextXAlignment    = Enum.TextXAlignment.Left
    nameLbl.ZIndex            = 43
    nameLbl.Parent            = card

    -- Level indicator
    local levLbl = Instance.new("TextLabel")
    levLbl.Size              = UDim2.new(0, 90, 0, 18)
    levLbl.Position          = UDim2.new(0, 28, 0, 34)
    levLbl.BackgroundTransparency = 1
    levLbl.Text              = "Lv " .. passive.CurrentLevel .. " / " .. passive.MaxLevel
    levLbl.TextColor3        = C.TextDim
    levLbl.TextScaled        = true
    levLbl.Font              = Enum.Font.Gotham
    levLbl.TextXAlignment    = Enum.TextXAlignment.Left
    levLbl.ZIndex            = 43
    levLbl.Parent            = card

    -- Description
    local descLbl = Instance.new("TextLabel")
    descLbl.Size              = UDim2.new(1, -120, 0, 22)
    descLbl.Position          = UDim2.new(0, 28, 0, 52)
    descLbl.BackgroundTransparency = 1
    descLbl.Text              = passive.Description
    descLbl.TextColor3        = C.TextDim
    descLbl.TextScaled        = true
    descLbl.Font              = Enum.Font.Gotham
    descLbl.TextXAlignment    = Enum.TextXAlignment.Left
    descLbl.ZIndex            = 43
    descLbl.Parent            = card

    -- Upgrade button (right side)
    local nextCost = passive.Cost * (passive.CurrentLevel + 1)
    local canAfford = masteryPoints >= nextCost
    local btnBg = passive.Maxed and Color3.fromRGB(40, 30, 10)
        or (canAfford and Color3.fromRGB(140, 95, 5) or Color3.fromRGB(60, 45, 15))
    local upgradeBtn = Instance.new("TextButton")
    upgradeBtn.Size              = UDim2.new(0, 90, 0, 54)
    upgradeBtn.Position          = UDim2.new(1, -100, 0, 13)
    upgradeBtn.BackgroundColor3  = btnBg
    upgradeBtn.Text              = passive.Maxed and "MAXED"
        or ("↑ " .. nextCost .. " MP")
    upgradeBtn.TextColor3        = passive.Maxed and C.TextDim
        or (canAfford and C.AmberLight or Color3.fromRGB(160, 130, 70))
    upgradeBtn.TextScaled        = true
    upgradeBtn.Font              = Enum.Font.GothamBold
    upgradeBtn.AutoButtonColor   = not passive.Maxed
    upgradeBtn.ZIndex            = 43
    upgradeBtn.Parent            = card
    Instance.new("UICorner", upgradeBtn).CornerRadius = UDim.new(0, 8)

    if not passive.Maxed then
        upgradeBtn.MouseButton1Click:Connect(function()
            if MetaUpgradeEvt then
                MetaUpgradeEvt:FireServer(passive.Id)
            end
        end)
        upgradeBtn.MouseEnter:Connect(function()
            if canAfford then
                TweenService:Create(upgradeBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(200, 140, 10) }):Play()
            end
        end)
        upgradeBtn.MouseLeave:Connect(function()
            TweenService:Create(upgradeBtn, TweenInfo.new(0.1), { BackgroundColor3 = btnBg }):Play()
        end)
    end
end

local function rebuildLegacyPanel(data)
    -- Clear old cards
    for _, child in ipairs(legScroll:GetChildren()) do
        if child:IsA("GuiObject") and child.ClassName ~= "UIListLayout" then
            child:Destroy()
        end
    end
    legPointsLbl.Text = (data.MasteryPoints or 0) .. "  MP"
    for _, passive in ipairs(data.Passives or {}) do
        buildPassiveCard(passive, data.MasteryPoints or 0)
    end
end

if MetaSyncEvt then
    MetaSyncEvt.OnClientEvent:Connect(function(data)
        legacyData = data
        if legacyPanel.Visible then
            rebuildLegacyPanel(data)
        else
            -- Just update the points label in case it's peeked at
            legPointsLbl.Text = (data.MasteryPoints or 0) .. "  MP"
        end
    end)
end

-- L key toggles the Legacy panel (Tab is reserved for the Ability Book)
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.L then
        legacyPanel.Visible = not legacyPanel.Visible
        if legacyPanel.Visible and legacyData and legacyData.Passives then
            rebuildLegacyPanel(legacyData)
        end
    end
end)

-- ────────────────────────────────────────────────
-- DUNGEON MECHANIC HUD INDICATOR  (top-left, below floor label)
-- ────────────────────────────────────────────────

local mechanicPanel = Instance.new("Frame")
mechanicPanel.Name              = "MechanicPanel"
mechanicPanel.Size              = UDim2.new(0, 280, 0, 26)
mechanicPanel.Position          = UDim2.new(0, 16, 0, 54)
mechanicPanel.BackgroundColor3  = Color3.fromRGB(10, 8, 18)
mechanicPanel.BackgroundTransparency = 0.2
mechanicPanel.BorderSizePixel   = 0
mechanicPanel.Visible           = false
mechanicPanel.ZIndex            = 5
mechanicPanel.Parent            = hudGui
Instance.new("UICorner", mechanicPanel).CornerRadius = UDim.new(0, 8)
local mechStroke = Instance.new("UIStroke", mechanicPanel)
mechStroke.Color     = Color3.fromRGB(120, 60, 200)
mechStroke.Thickness = 1

local mechanicLabel = Instance.new("TextLabel")
mechanicLabel.Size              = UDim2.new(1, -8, 1, 0)
mechanicLabel.Position          = UDim2.new(0, 4, 0, 0)
mechanicLabel.BackgroundTransparency = 1
mechanicLabel.Text              = ""
mechanicLabel.TextColor3        = Color3.fromRGB(200, 160, 255)
mechanicLabel.TextScaled        = true
mechanicLabel.Font              = Enum.Font.Gotham
mechanicLabel.TextXAlignment    = Enum.TextXAlignment.Left
mechanicLabel.ZIndex            = 6
mechanicLabel.Parent            = mechanicPanel

-- ────────────────────────────────────────────────
-- ACTIVE CURSE INDICATOR  (below awakening gauge, bottom-left)
-- ────────────────────────────────────────────────

local curseIndicator = Instance.new("Frame")
curseIndicator.Name              = "CurseIndicator"
curseIndicator.Size              = UDim2.new(0, 220, 0, 22)
curseIndicator.Position          = UDim2.new(0, 16, 1, -218)
curseIndicator.BackgroundColor3  = Color3.fromRGB(20, 5, 5)
curseIndicator.BackgroundTransparency = 0.15
curseIndicator.BorderSizePixel   = 0
curseIndicator.Visible           = false
curseIndicator.ZIndex            = 5
curseIndicator.Parent            = hudGui
Instance.new("UICorner", curseIndicator).CornerRadius = UDim.new(0, 8)
local curseStroke = Instance.new("UIStroke", curseIndicator)
curseStroke.Color     = Color3.fromRGB(200, 40, 40)
curseStroke.Thickness = 1

local curseLbl = Instance.new("TextLabel")
curseLbl.Size              = UDim2.new(1, -8, 1, 0)
curseLbl.Position          = UDim2.new(0, 4, 0, 0)
curseLbl.BackgroundTransparency = 1
curseLbl.Text              = ""
curseLbl.TextColor3        = Color3.fromRGB(255, 120, 120)
curseLbl.TextScaled        = true
curseLbl.Font              = Enum.Font.GothamBold
curseLbl.TextXAlignment    = Enum.TextXAlignment.Left
curseLbl.ZIndex            = 6
curseLbl.Parent            = curseIndicator

-- ────────────────────────────────────────────────
-- ORIGIN SELECTION SCREEN  (shown after archetype selection)
-- ────────────────────────────────────────────────

local SelectOriginEvt = RemoteEvents:WaitForChild("SelectOrigin", 15)

local originScreen = Instance.new("Frame")
originScreen.Name              = "OriginScreen"
originScreen.Size              = UDim2.new(1, 0, 1, 0)
originScreen.BackgroundColor3  = Color3.fromRGB(6, 10, 18)
originScreen.BackgroundTransparency = 1
originScreen.Visible           = false
originScreen.ZIndex            = 16
originScreen.Parent            = hudGui

local originTitle = Instance.new("TextLabel")
originTitle.Size              = UDim2.new(0.7, 0, 0, 50)
originTitle.Position          = UDim2.new(0.15, 0, 0, 60)
originTitle.BackgroundTransparency = 1
originTitle.Text              = "CHOOSE YOUR ORIGIN"
originTitle.TextColor3        = C.AmberLight
originTitle.TextScaled        = true
originTitle.Font              = Enum.Font.GothamBold
originTitle.ZIndex            = 17
originTitle.Parent            = originScreen
Instance.new("UIStroke", originTitle).Color = C.PanelBorder

local originSub = Instance.new("TextLabel")
originSub.Size              = UDim2.new(0.7, 0, 0, 28)
originSub.Position          = UDim2.new(0.15, 0, 0, 114)
originSub.BackgroundTransparency = 1
originSub.Text              = "Your origin grants a permanent passive trait for this entire run."
originSub.TextColor3        = C.TextDim
originSub.TextScaled        = true
originSub.Font              = Enum.Font.Gotham
originSub.ZIndex            = 17
originSub.Parent            = originScreen

local originCardScroll = Instance.new("ScrollingFrame")
originCardScroll.Size              = UDim2.new(0.9, 0, 0, 340)
originCardScroll.Position          = UDim2.new(0.05, 0, 0, 154)
originCardScroll.BackgroundTransparency = 1
originCardScroll.BorderSizePixel   = 0
originCardScroll.ScrollBarThickness = 8
originCardScroll.ScrollBarImageColor3 = C.Amber
originCardScroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
originCardScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
originCardScroll.ScrollingDirection = Enum.ScrollingDirection.X
originCardScroll.ZIndex            = 17
originCardScroll.Parent            = originScreen

local originCardLayout = Instance.new("UIListLayout", originCardScroll)
originCardLayout.FillDirection     = Enum.FillDirection.Horizontal
originCardLayout.Padding           = UDim.new(0, 16)
originCardLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local function buildOriginCard(origin)
    local aura = origin.AuraColor
    local auraColor = (aura and typeof(aura) == "Color3") and aura
        or Color3.fromRGB(200, 150, 30)

    local card = Instance.new("Frame")
    card.Size              = UDim2.new(0, 200, 0, 300)
    card.BackgroundColor3  = Color3.fromRGB(14, 11, 8)
    card.BorderSizePixel   = 0
    card.ZIndex            = 18
    card.Parent            = originCardScroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
    local cStroke = Instance.new("UIStroke", card)
    cStroke.Color     = auraColor
    cStroke.Thickness = 2

    local auraStrip = Instance.new("Frame")
    auraStrip.Size             = UDim2.new(1, 0, 0, 7)
    auraStrip.BackgroundColor3 = auraColor
    auraStrip.BorderSizePixel  = 0
    auraStrip.ZIndex           = 18
    auraStrip.Parent           = card
    Instance.new("UICorner", auraStrip).CornerRadius = UDim.new(0, 6)

    local namePfx = Instance.new("TextLabel")
    namePfx.Size              = UDim2.new(1, -12, 0, 18)
    namePfx.Position          = UDim2.new(0, 6, 0, 12)
    namePfx.BackgroundTransparency = 1
    namePfx.Text              = origin.NamePrefix or ""
    namePfx.TextColor3        = auraColor
    namePfx.TextScaled        = true
    namePfx.Font              = Enum.Font.Gotham
    namePfx.ZIndex            = 19
    namePfx.Parent            = card

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size              = UDim2.new(1, -12, 0, 28)
    nameLbl.Position          = UDim2.new(0, 6, 0, 32)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text              = origin.Name
    nameLbl.TextColor3        = C.TextMain
    nameLbl.TextScaled        = true
    nameLbl.Font              = Enum.Font.GothamBold
    nameLbl.ZIndex            = 19
    nameLbl.Parent            = card

    local passiveName = Instance.new("TextLabel")
    passiveName.Size              = UDim2.new(1, -12, 0, 18)
    passiveName.Position          = UDim2.new(0, 6, 0, 64)
    passiveName.BackgroundTransparency = 1
    passiveName.Text              = "◆  " .. (origin.PassiveName or "")
    passiveName.TextColor3        = C.AmberLight
    passiveName.TextScaled        = true
    passiveName.Font              = Enum.Font.GothamBold
    passiveName.ZIndex            = 19
    passiveName.Parent            = card

    local passiveDesc = Instance.new("TextLabel")
    passiveDesc.Size              = UDim2.new(1, -12, 0, 62)
    passiveDesc.Position          = UDim2.new(0, 6, 0, 84)
    passiveDesc.BackgroundTransparency = 1
    passiveDesc.Text              = origin.PassiveDesc or ""
    passiveDesc.TextColor3        = C.TextDim
    passiveDesc.TextScaled        = true
    passiveDesc.TextWrapped       = true
    passiveDesc.Font              = Enum.Font.Gotham
    passiveDesc.ZIndex            = 19
    passiveDesc.Parent            = card

    local quoteLabel = Instance.new("TextLabel")
    quoteLabel.Size              = UDim2.new(1, -12, 0, 50)
    quoteLabel.Position          = UDim2.new(0, 6, 0, 152)
    quoteLabel.BackgroundTransparency = 1
    quoteLabel.Text              = origin.FlavorQuote and ('"' .. origin.FlavorQuote .. '"') or ""
    quoteLabel.TextColor3        = Color3.fromRGB(150, 140, 120)
    quoteLabel.TextScaled        = true
    quoteLabel.TextWrapped       = true
    quoteLabel.Font              = Enum.Font.GothamItalic
    quoteLabel.ZIndex            = 19
    quoteLabel.Parent            = card

    local pickBtn = Instance.new("TextButton")
    pickBtn.Size              = UDim2.new(1, -16, 0, 38)
    pickBtn.Position          = UDim2.new(0, 8, 1, -48)
    pickBtn.BackgroundColor3  = auraColor
    pickBtn.Text              = "CHOOSE"
    pickBtn.TextColor3        = Color3.fromRGB(8, 6, 4)
    pickBtn.TextScaled        = true
    pickBtn.Font              = Enum.Font.GothamBold
    pickBtn.BorderSizePixel   = 0
    pickBtn.ZIndex            = 20
    pickBtn.Parent            = card
    Instance.new("UICorner", pickBtn).CornerRadius = UDim.new(0, 8)

    pickBtn.MouseButton1Click:Connect(function()
        if SelectOriginEvt then SelectOriginEvt:FireServer(origin.Id) end
        TweenService:Create(originScreen, TweenInfo.new(0.4, Enum.EasingStyle.Quad),
            { BackgroundTransparency = 1 }):Play()
        task.delay(0.4, function() originScreen.Visible = false end)
    end)
    pickBtn.MouseEnter:Connect(function()
        TweenService:Create(pickBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.AmberLight }):Play()
    end)
    pickBtn.MouseLeave:Connect(function()
        TweenService:Create(pickBtn, TweenInfo.new(0.1), { BackgroundColor3 = auraColor }):Play()
    end)
end

UpdateHUD.OnClientEvent:Connect(function(data)
    if data.ShowOriginScreen and data.Origins then
        for _, child in ipairs(originCardScroll:GetChildren()) do
            if child:IsA("GuiObject") and child.ClassName ~= "UIListLayout" then child:Destroy() end
        end
        for _, o in ipairs(data.Origins) do buildOriginCard(o) end
        originScreen.BackgroundTransparency = 1
        originScreen.Visible = true
        TweenService:Create(originScreen, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
    end
end)

-- ────────────────────────────────────────────────
-- SEALED CHAMBER CURSE PANEL
-- ────────────────────────────────────────────────

local PickCurseEvt = RemoteEvents:WaitForChild("PickCurse", 15)

local curseFrame = Instance.new("Frame")
curseFrame.Name              = "CursePanel"
curseFrame.Size              = UDim2.new(0, 600, 0, 440)
curseFrame.Position          = UDim2.new(0.5, -300, 0.5, -220)
curseFrame.BackgroundColor3  = Color3.fromRGB(8, 4, 4)
curseFrame.BackgroundTransparency = 0.06
curseFrame.Visible           = false
curseFrame.ZIndex            = 30
curseFrame.Parent            = hudGui
Instance.new("UICorner", curseFrame).CornerRadius = UDim.new(0, 16)
local curseFrameStroke = Instance.new("UIStroke", curseFrame)
curseFrameStroke.Color     = Color3.fromRGB(180, 20, 20)
curseFrameStroke.Thickness = 2

local cursePanelTitle = Instance.new("TextLabel")
cursePanelTitle.Size              = UDim2.new(1, -60, 0, 46)
cursePanelTitle.Position          = UDim2.new(0, 10, 0, 8)
cursePanelTitle.BackgroundTransparency = 1
cursePanelTitle.Text              = "⚠  SEALED CHAMBER"
cursePanelTitle.TextColor3        = Color3.fromRGB(255, 80, 80)
cursePanelTitle.TextScaled        = true
cursePanelTitle.Font              = Enum.Font.GothamBold
cursePanelTitle.ZIndex            = 31
cursePanelTitle.Parent            = curseFrame

local cursePanelClose = Instance.new("TextButton")
cursePanelClose.Size              = UDim2.new(0, 34, 0, 34)
cursePanelClose.Position          = UDim2.new(1, -42, 0, 10)
cursePanelClose.BackgroundColor3  = Color3.fromRGB(120, 20, 20)
cursePanelClose.Text              = "✕"
cursePanelClose.TextColor3        = Color3.new(1, 1, 1)
cursePanelClose.TextScaled        = true
cursePanelClose.Font              = Enum.Font.GothamBold
cursePanelClose.BorderSizePixel   = 0
cursePanelClose.ZIndex            = 32
cursePanelClose.Parent            = curseFrame
Instance.new("UICorner", cursePanelClose).CornerRadius = UDim.new(0, 8)
cursePanelClose.MouseButton1Click:Connect(function() curseFrame.Visible = false end)

local cursePanelSub = Instance.new("TextLabel")
cursePanelSub.Size              = UDim2.new(1, -16, 0, 36)
cursePanelSub.Position          = UDim2.new(0, 8, 0, 56)
cursePanelSub.BackgroundTransparency = 1
cursePanelSub.Text              = "Accept a curse in exchange for power.  Only one curse can be active."
cursePanelSub.TextColor3        = C.TextDim
cursePanelSub.TextScaled        = true
cursePanelSub.Font              = Enum.Font.Gotham
cursePanelSub.TextWrapped       = true
cursePanelSub.ZIndex            = 31
cursePanelSub.Parent            = curseFrame

local curseOptContainer = Instance.new("Frame")
curseOptContainer.Size              = UDim2.new(1, -24, 1, -102)
curseOptContainer.Position          = UDim2.new(0, 12, 0, 96)
curseOptContainer.BackgroundTransparency = 1
curseOptContainer.ZIndex            = 31
curseOptContainer.Parent            = curseFrame
local curseOptLayout = Instance.new("UIListLayout", curseOptContainer)
curseOptLayout.Padding              = UDim.new(0, 10)
curseOptLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center

local CURSE_TIER_COLORS = {
    [1] = Color3.fromRGB(180, 100, 100),
    [2] = Color3.fromRGB(220, 60, 60),
    [3] = Color3.fromRGB(255, 20, 20),
}

local function buildCurseOption(opt, roomId, alreadyChosen)
    local tierColor = CURSE_TIER_COLORS[opt.Tier] or CURSE_TIER_COLORS[1]

    local row = Instance.new("Frame")
    row.Size              = UDim2.new(1, 0, 0, 96)
    row.BackgroundColor3  = Color3.fromRGB(20, 8, 8)
    row.BorderSizePixel   = 0
    row.ZIndex            = 32
    row.Parent            = curseOptContainer
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
    local rStroke = Instance.new("UIStroke", row)
    rStroke.Color     = tierColor
    rStroke.Thickness = 1

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size              = UDim2.new(0, 46, 0.6, 0)
    iconLbl.Position          = UDim2.new(0, 6, 0.2, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text              = opt.Icon or "💀"
    iconLbl.TextScaled        = true
    iconLbl.ZIndex            = 33
    iconLbl.Parent            = row

    local curseName = Instance.new("TextLabel")
    curseName.Size              = UDim2.new(0.44, 0, 0.36, 0)
    curseName.Position          = UDim2.new(0, 56, 0, 4)
    curseName.BackgroundTransparency = 1
    curseName.Text              = opt.Name or ""
    curseName.TextColor3        = tierColor
    curseName.TextScaled        = true
    curseName.Font              = Enum.Font.GothamBold
    curseName.TextXAlignment    = Enum.TextXAlignment.Left
    curseName.ZIndex            = 33
    curseName.Parent            = row

    local curseDesc = Instance.new("TextLabel")
    curseDesc.Size              = UDim2.new(0.58, 0, 0.42, 0)
    curseDesc.Position          = UDim2.new(0, 56, 0.40, 0)
    curseDesc.BackgroundTransparency = 1
    curseDesc.Text              = opt.Description or ""
    curseDesc.TextColor3        = C.TextDim
    curseDesc.TextScaled        = true
    curseDesc.TextWrapped       = true
    curseDesc.Font              = Enum.Font.Gotham
    curseDesc.TextXAlignment    = Enum.TextXAlignment.Left
    curseDesc.ZIndex            = 33
    curseDesc.Parent            = row

    local bonusLbl = Instance.new("TextLabel")
    bonusLbl.Size              = UDim2.new(0.3, 0, 0.44, 0)
    bonusLbl.Position          = UDim2.new(0.57, 0, 0.06, 0)
    bonusLbl.BackgroundTransparency = 1
    bonusLbl.Text              = opt.Bonus or ""
    bonusLbl.TextColor3        = C.Green
    bonusLbl.TextScaled        = true
    bonusLbl.TextWrapped       = true
    bonusLbl.Font              = Enum.Font.Gotham
    bonusLbl.TextXAlignment    = Enum.TextXAlignment.Left
    bonusLbl.ZIndex            = 33
    bonusLbl.Parent            = row

    local acceptBtn = Instance.new("TextButton")
    acceptBtn.Size              = UDim2.new(0, 80, 0.45, 0)
    acceptBtn.Position          = UDim2.new(1, -90, 0.52, 0)
    acceptBtn.BackgroundColor3  = alreadyChosen and Color3.fromRGB(60, 20, 20) or tierColor
    acceptBtn.Text              = alreadyChosen and "SEALED" or "ACCEPT"
    acceptBtn.TextColor3        = alreadyChosen and C.TextDim or Color3.new(1, 1, 1)
    acceptBtn.TextScaled        = true
    acceptBtn.Font              = Enum.Font.GothamBold
    acceptBtn.BorderSizePixel   = 0
    acceptBtn.Active            = not alreadyChosen
    acceptBtn.ZIndex            = 33
    acceptBtn.Parent            = row
    Instance.new("UICorner", acceptBtn).CornerRadius = UDim.new(0, 8)

    if not alreadyChosen then
        acceptBtn.MouseButton1Click:Connect(function()
            if PickCurseEvt then PickCurseEvt:FireServer(opt.Id, roomId) end
            curseFrame.Visible = false
        end)
        acceptBtn.MouseEnter:Connect(function()
            TweenService:Create(acceptBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(255, 80, 80) }):Play()
        end)
        acceptBtn.MouseLeave:Connect(function()
            TweenService:Create(acceptBtn, TweenInfo.new(0.1), { BackgroundColor3 = tierColor }):Play()
        end)
    end
end

UpdateHUD.OnClientEvent:Connect(function(data)
    -- Open Sealed Chamber curse selection
    if data.SealedChamberOpen and data.Options then
        for _, child in ipairs(curseOptContainer:GetChildren()) do
            if child:IsA("GuiObject") and child.ClassName ~= "UIListLayout" then child:Destroy() end
        end
        cursePanelSub.Text = data.DoorText or "Accept a curse in exchange for power."
        for _, opt in ipairs(data.Options) do
            buildCurseOption(opt, data.RoomId, data.AlreadyChosen)
        end
        curseFrame.Position = UDim2.new(0.5, -300, 1.1, 0)
        curseFrame.Visible  = true
        TweenService:Create(curseFrame,
            TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Position = UDim2.new(0.5, -300, 0.5, -220) }):Play()
    end

    -- Show active curse in bottom-left indicator
    if data.CurseAccepted then
        curseLbl.Text = (data.CurseIcon or "💀") .. "  " .. (data.CurseName or "Cursed")
        curseIndicator.Visible = true
    end
end)

-- ────────────────────────────────────────────────
-- FLOOR LORE, MECHANIC HUD, BOSS DIALOGUE, FLAVOR LINES
-- ────────────────────────────────────────────────

UpdateHUD.OnClientEvent:Connect(function(data)
    -- Mechanic HUD indicator: show active dungeon mechanic name
    if data.FloorStart and data.MechanicName then
        local hudLabel = data.MechanicHUDLabel or data.MechanicName
        local hColor   = data.MechanicHUDColor   -- Color3 value
        mechanicLabel.Text = "⚡  " .. hudLabel
        if hColor and typeof(hColor) == "Color3" then
            mechanicLabel.TextColor3 = hColor
            mechStroke.Color         = hColor
        end
        mechanicPanel.Visible = true
    end

    -- Floor start overlay: show ShardName + EntryFlavor lore text
    if data.FloorStart and data.EntryFlavor then
        local shardText = data.ShardName or data.ThemeName
        overlay.BackgroundColor3 = Color3.fromRGB(0, 5, 14)
        overlayLabel.TextColor3  = C.AmberLight
        overlay.BackgroundTransparency = 0
        overlayLabel.TextTransparency  = 0
        overlayLabel.Text = "Floor " .. data.Floor .. "  ·  " .. shardText
            .. "\n" .. data.EntryFlavor
        TweenService:Create(overlay,
            TweenInfo.new(3.2, Enum.EasingStyle.Quad),
            { BackgroundTransparency = 1 }):Play()
        TweenService:Create(overlayLabel,
            TweenInfo.new(3.2, Enum.EasingStyle.Quad),
            { TextTransparency = 1 }):Play()
        task.delay(3.3, function() overlayLabel.Text = ""; overlayLabel.TextTransparency = 0 end)
    end

    -- Boss defeated: show lore dialogue banner
    if data.BossDefeated then
        local displayText = "✦  " .. (data.BossName or "Boss") .. " Defeated"
        if data.BossDialogue then
            displayText = displayText .. '\n"' .. data.BossDialogue .. '"'
        end
        overlay.BackgroundColor3 = Color3.fromRGB(22, 12, 0)
        overlayLabel.TextColor3  = C.AmberLight
        overlay.BackgroundTransparency = 0.1
        overlayLabel.Text = displayText
        TweenService:Create(overlay,
            TweenInfo.new(3.5, Enum.EasingStyle.Quad),
            { BackgroundTransparency = 1 }):Play()
        if data.ClearFlavor then
            task.delay(3.6, function()
                overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                showToast(data.ClearFlavor, Color3.fromRGB(30, 20, 0), 4.5)
            end)
        else
            task.delay(3.6, function() overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0) end)
        end
    end

    -- Room entry flavor line: brief lore text toast
    if data.FlavorLine then
        showToast(data.FlavorLine, Color3.fromRGB(10, 8, 20), data.Duration or 3.5)
    end
end)

-- ────────────────────────────────────────────────
-- ROOM CLEARED → update progress bar toward boss
-- ────────────────────────────────────────────────

RoomClearedEvt.OnClientEvent:Connect(function(data)
    local cleared = data.Cleared or 0
    local total   = data.Total   or 1
    local pct     = math.clamp(cleared / total, 0, 1)

    roomProgressBG.Visible = true
    TweenService:Create(roomProgressFill,
        TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(pct, 0, 1, 0) }
    ):Play()

    if cleared >= total then
        TweenService:Create(roomProgressFill,
            TweenInfo.new(0.25),
            { BackgroundColor3 = Color3.fromRGB(200, 40, 40) }
        ):Play()
        roomProgressLabel.Text = "Boss Chamber Open!"
    else
        roomProgressLabel.Text = "Rooms  " .. cleared .. " / " .. total
    end
end)

-- ────────────────────────────────────────────────
-- GAMBLING UI
-- ────────────────────────────────────────────────

local PickGambleEvt   = RemoteEvents:WaitForChild("PickGamble")
local GambleResultEvt = RemoteEvents:WaitForChild("GambleResult")

-- Outer panel (slides in from bottom, same pattern as curse panel)
local gambleFrame = Instance.new("Frame")
gambleFrame.Name              = "GambleFrame"
gambleFrame.Size              = UDim2.new(0, 620, 0, 380)
gambleFrame.Position          = UDim2.new(0.5, -310, 1.2, 0)
gambleFrame.BackgroundColor3  = Color3.fromRGB(18, 10, 5)
gambleFrame.BorderSizePixel   = 0
gambleFrame.Visible           = false
gambleFrame.ZIndex            = 40
gambleFrame.Parent            = hudGui
Instance.new("UICorner", gambleFrame).CornerRadius = UDim.new(0, 14)
local gambleStroke = Instance.new("UIStroke", gambleFrame)
gambleStroke.Color     = Color3.fromRGB(180, 50, 0)
gambleStroke.Thickness = 2

local gambleTitleBg = Instance.new("Frame")
gambleTitleBg.Size             = UDim2.new(1, 0, 0, 52)
gambleTitleBg.BackgroundColor3 = Color3.fromRGB(120, 30, 0)
gambleTitleBg.BorderSizePixel  = 0
gambleTitleBg.ZIndex           = 41
gambleTitleBg.Parent           = gambleFrame
Instance.new("UICorner", gambleTitleBg).CornerRadius = UDim.new(0, 14)

local gambleTitle = Instance.new("TextLabel")
gambleTitle.Size                = UDim2.new(1, -20, 1, 0)
gambleTitle.Position            = UDim2.new(0, 10, 0, 0)
gambleTitle.BackgroundTransparency = 1
gambleTitle.Text                = "🎰  THE VOID OFFERS A DEAL"
gambleTitle.TextColor3          = Color3.fromRGB(255, 200, 80)
gambleTitle.TextScaled          = true
gambleTitle.Font                = Enum.Font.GothamBold
gambleTitle.ZIndex              = 42
gambleTitle.Parent              = gambleTitleBg

local gambleSubtitle = Instance.new("TextLabel")
gambleSubtitle.Size                = UDim2.new(1, -20, 0, 26)
gambleSubtitle.Position            = UDim2.new(0, 10, 0, 52)
gambleSubtitle.BackgroundTransparency = 1
gambleSubtitle.Text                = "Every deal costs something. Some rewards are worth it."
gambleSubtitle.TextColor3          = Color3.fromRGB(180, 150, 100)
gambleSubtitle.TextScaled          = true
gambleSubtitle.Font                = Enum.Font.Gotham
gambleSubtitle.ZIndex              = 41
gambleSubtitle.Parent              = gambleFrame

local gambleOptContainer = Instance.new("Frame")
gambleOptContainer.Size             = UDim2.new(1, -20, 1, -100)
gambleOptContainer.Position         = UDim2.new(0, 10, 0, 88)
gambleOptContainer.BackgroundTransparency = 1
gambleOptContainer.ZIndex           = 41
gambleOptContainer.Parent           = gambleFrame
local gambleLayout = Instance.new("UIListLayout", gambleOptContainer)
gambleLayout.Padding          = UDim.new(0, 6)
gambleLayout.SortOrder        = Enum.SortOrder.LayoutOrder

local gambleCloseBtn = Instance.new("TextButton")
gambleCloseBtn.Size             = UDim2.new(0, 80, 0, 28)
gambleCloseBtn.Position         = UDim2.new(1, -90, 0, 12)
gambleCloseBtn.BackgroundColor3 = Color3.fromRGB(60, 20, 10)
gambleCloseBtn.Text             = "LEAVE"
gambleCloseBtn.TextColor3       = Color3.fromRGB(200, 140, 80)
gambleCloseBtn.TextScaled       = true
gambleCloseBtn.Font             = Enum.Font.GothamBold
gambleCloseBtn.BorderSizePixel  = 0
gambleCloseBtn.ZIndex           = 42
gambleCloseBtn.Parent           = gambleFrame
Instance.new("UICorner", gambleCloseBtn).CornerRadius = UDim.new(0, 8)
gambleCloseBtn.MouseButton1Click:Connect(function()
    gambleFrame.Visible = false
end)

-- Hazard colour by level
local function hazardColor(level)
    if level == 1 then return Color3.fromRGB(80, 160, 80)
    elseif level == 2 then return Color3.fromRGB(200, 140, 30)
    else return Color3.fromRGB(200, 40, 40)
    end
end

local function buildGambleOption(opt)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 60)
    row.BackgroundColor3 = Color3.fromRGB(28, 16, 8)
    row.BorderSizePixel  = 0
    row.ZIndex           = 42
    row.Parent           = gambleOptContainer
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local rowStroke = Instance.new("UIStroke", row)
    rowStroke.Color     = hazardColor(opt.HazardLevel or 1)
    rowStroke.Thickness = 1.5

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size               = UDim2.new(0, 46, 1, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text               = opt.Icon or "?"
    iconLbl.TextScaled         = true
    iconLbl.ZIndex             = 43
    iconLbl.Parent             = row

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size               = UDim2.new(0.28, 0, 0.50, 0)
    nameLbl.Position           = UDim2.new(0, 50, 0, 2)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text               = opt.Name or ""
    nameLbl.TextColor3         = hazardColor(opt.HazardLevel or 1)
    nameLbl.TextScaled         = true
    nameLbl.Font               = Enum.Font.GothamBold
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
    nameLbl.ZIndex             = 43
    nameLbl.Parent             = row

    local costLbl = Instance.new("TextLabel")
    costLbl.Size               = UDim2.new(0.44, 0, 0.44, 0)
    costLbl.Position           = UDim2.new(0, 50, 0.50, 0)
    costLbl.BackgroundTransparency = 1
    costLbl.Text               = "COST: " .. (opt.CostText or "")
    costLbl.TextColor3         = C.Red
    costLbl.TextScaled         = true
    costLbl.Font               = Enum.Font.Gotham
    costLbl.TextXAlignment     = Enum.TextXAlignment.Left
    costLbl.ZIndex             = 43
    costLbl.Parent             = row

    local rewardLbl = Instance.new("TextLabel")
    rewardLbl.Size             = UDim2.new(0.28, 0, 0.85, 0)
    rewardLbl.Position         = UDim2.new(0.44, 4, 0.07, 0)
    rewardLbl.BackgroundTransparency = 1
    rewardLbl.Text             = opt.RewardText or ""
    rewardLbl.TextColor3       = C.Green
    rewardLbl.TextScaled       = true
    rewardLbl.TextWrapped      = true
    rewardLbl.Font             = Enum.Font.Gotham
    rewardLbl.TextXAlignment   = Enum.TextXAlignment.Left
    rewardLbl.ZIndex           = 43
    rewardLbl.Parent           = row

    local dealBtn = Instance.new("TextButton")
    dealBtn.Size               = UDim2.new(0, 74, 0.55, 0)
    dealBtn.Position           = UDim2.new(1, -84, 0.22, 0)
    dealBtn.BackgroundColor3   = hazardColor(opt.HazardLevel or 1)
    dealBtn.Text               = "DEAL"
    dealBtn.TextColor3         = Color3.new(1, 1, 1)
    dealBtn.TextScaled         = true
    dealBtn.Font               = Enum.Font.GothamBold
    dealBtn.BorderSizePixel    = 0
    dealBtn.ZIndex             = 43
    dealBtn.Parent             = row
    Instance.new("UICorner", dealBtn).CornerRadius = UDim.new(0, 8)
    dealBtn.MouseButton1Click:Connect(function()
        PickGambleEvt:FireServer(opt.Id)
        gambleFrame.Visible = false
    end)
    dealBtn.MouseEnter:Connect(function()
        TweenService:Create(dealBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(255, 255, 255) }):Play()
    end)
    dealBtn.MouseLeave:Connect(function()
        TweenService:Create(dealBtn, TweenInfo.new(0.1), { BackgroundColor3 = hazardColor(opt.HazardLevel or 1) }):Play()
    end)
end

-- Show gamble panel handler
UpdateHUD.OnClientEvent:Connect(function(data)
    if not data.GambleOpen or not data.Options then return end
    for _, child in ipairs(gambleOptContainer:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    for _, opt in ipairs(data.Options) do
        buildGambleOption(opt)
    end
    gambleFrame.Position = UDim2.new(0.5, -310, 1.2, 0)
    gambleFrame.Visible  = true
    TweenService:Create(gambleFrame,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, -310, 0.5, -190) }):Play()
end)

-- Gamble result notification
GambleResultEvt.OnClientEvent:Connect(function(data)
    if not data then return end
    local bg = data.Success and Color3.fromRGB(20, 60, 20) or Color3.fromRGB(60, 10, 10)
    local tc = data.Success and C.Green or C.Red
    local panel = Instance.new("Frame")
    panel.Size             = UDim2.new(0, 480, 0, 110)
    panel.Position         = UDim2.new(0.5, -240, 0.3, 0)
    panel.BackgroundColor3 = bg
    panel.BorderSizePixel  = 0
    panel.ZIndex           = 50
    panel.Parent           = hudGui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    local panelStroke = Instance.new("UIStroke", panel)
    panelStroke.Color = tc; panelStroke.Thickness = 2

    local headLbl = Instance.new("TextLabel", panel)
    headLbl.Size               = UDim2.new(1, -16, 0, 44)
    headLbl.Position           = UDim2.new(0, 8, 0, 4)
    headLbl.BackgroundTransparency = 1
    headLbl.Text               = data.Headline or (data.Success and "SUCCESS" or "FAILED")
    headLbl.TextColor3         = tc
    headLbl.TextScaled         = true
    headLbl.Font               = Enum.Font.GothamBold
    headLbl.ZIndex             = 51

    local detLbl = Instance.new("TextLabel", panel)
    detLbl.Size                = UDim2.new(1, -16, 0, 54)
    detLbl.Position            = UDim2.new(0, 8, 0, 50)
    detLbl.BackgroundTransparency = 1
    detLbl.Text                = data.Detail or ""
    detLbl.TextColor3          = C.TextMain
    detLbl.TextScaled          = true
    detLbl.TextWrapped         = true
    detLbl.Font                = Enum.Font.Gotham
    detLbl.ZIndex              = 51

    panel.BackgroundTransparency = 1
    TweenService:Create(panel, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
    task.delay(3.5, function()
        TweenService:Create(panel, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
        task.wait(0.45)
        if panel.Parent then panel:Destroy() end
    end)
end)

-- ────────────────────────────────────────────────
-- ABILITY COOLDOWN ANIMATION
-- ────────────────────────────────────────────────

local AbilityCastEvt = RemoteEvents:WaitForChild("AbilityCast", 15)
local AbilitySystemMod = require(ReplicatedStorage.Modules.AbilitySystem)

-- Track which slot each ability is in
local slotForAbility = {}  -- [abilityName] = slotIndex

UpdateHUD.OnClientEvent:Connect(function(data)
    if data.ActiveSlots then
        slotForAbility = {}
        for i, name in ipairs(data.ActiveSlots) do
            if name then slotForAbility[name] = i end
        end
    end
end)

local function startCooldownOverlay(slotIndex, cooldownSecs)
    local slot = abilitySlotFrames[slotIndex]
    if not slot then return end
    local overlay = slot:FindFirstChild("Cooldown")
    if not overlay then return end

    -- Show a cooldown timer label
    local timerLbl = slot:FindFirstChild("CooldownTimer")
    if not timerLbl then
        timerLbl = Instance.new("TextLabel")
        timerLbl.Name = "CooldownTimer"
        timerLbl.Size = UDim2.new(1, 0, 1, 0)
        timerLbl.BackgroundTransparency = 1
        timerLbl.TextColor3 = Color3.new(1, 1, 1)
        timerLbl.TextScaled = true
        timerLbl.Font = Enum.Font.GothamBold
        timerLbl.ZIndex = 9
        timerLbl.Parent = slot
    end

    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundTransparency = 0.4
    timerLbl.Text = tostring(math.ceil(cooldownSecs))
    timerLbl.TextTransparency = 0

    TweenService:Create(overlay, TweenInfo.new(cooldownSecs, Enum.EasingStyle.Linear), {
        Size = UDim2.new(1, 0, 0, 0),
    }):Play()

    local elapsed = 0
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        local remaining = cooldownSecs - elapsed
        if remaining <= 0 then
            overlay.Size = UDim2.new(1, 0, 0, 0)
            timerLbl.Text = ""
            conn:Disconnect()
        else
            timerLbl.Text = tostring(math.ceil(remaining))
        end
    end)
end

if AbilityCastEvt then
    AbilityCastEvt.OnClientEvent:Connect(function(data)
        if not data or data.CasterUserId ~= player.UserId then return end
        local ab = AbilitySystemMod.GetAbility(data.AbilityName)
        if not ab or ab.Cooldown <= 0 then return end
        local slot = slotForAbility[data.AbilityName]
        if slot then
            startCooldownOverlay(slot, ab.Cooldown)
        end
    end)
end

print("[HUD] Loaded — Dungeon Piece style.")
