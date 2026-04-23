-- LobbyInteraction.client.lua
-- Handles ProximityPrompt interactions on lobby kiosks.
-- Shows a proper info panel for each station.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

-- ── Panel builder ─────────────────────────────────────────────────────────────

local C = {
    BG      = Color3.fromRGB(12, 15, 24),
    Border  = Color3.fromRGB(0, 210, 255),
    Title   = Color3.fromRGB(0, 210, 255),
    Body    = Color3.fromRGB(200, 215, 235),
    Dim     = Color3.fromRGB(130, 150, 175),
    Accent  = Color3.fromRGB(255, 185, 30),
}

local activePanel = nil

local function closePanel()
    if activePanel and activePanel.Parent then
        TweenService:Create(activePanel, TweenInfo.new(0.22), {
            Position = UDim2.new(0.5, -220, 1.1, 0),
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.25, function()
            if activePanel and activePanel.Parent then activePanel:Destroy() end
            activePanel = nil
        end)
    end
end

local function openPanel(info)
    closePanel()

    local sGui = playerGui:FindFirstChild("LobbyPanelGui")
    if not sGui then
        sGui = Instance.new("ScreenGui")
        sGui.Name = "LobbyPanelGui"
        sGui.ResetOnSpawn = false
        sGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        sGui.Parent = playerGui
    end

    local panel = Instance.new("Frame")
    panel.Name               = "KioskPanel"
    panel.Size               = UDim2.new(0, 440, 0, info.height or 360)
    panel.Position           = UDim2.new(0.5, -220, 1.2, 0)
    panel.BackgroundColor3   = C.BG
    panel.BackgroundTransparency = 0.06
    panel.BorderSizePixel    = 0
    panel.ZIndex             = 30
    panel.Parent             = sGui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
    do
        local s = Instance.new("UIStroke", panel)
        s.Color = info.accent or C.Border
        s.Thickness = 2
    end

    activePanel = panel

    -- Header bar
    local header = Instance.new("Frame", panel)
    header.Size             = UDim2.new(1, 0, 0, 52)
    header.BackgroundColor3 = info.accent or C.Border
    header.BackgroundTransparency = 0.25
    header.BorderSizePixel  = 0
    header.ZIndex           = 31
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)

    local titleLbl = Instance.new("TextLabel", header)
    titleLbl.Size               = UDim2.new(1, -60, 1, 0)
    titleLbl.Position           = UDim2.new(0, 12, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text               = info.title
    titleLbl.TextColor3         = Color3.fromRGB(255, 255, 255)
    titleLbl.TextScaled         = true
    titleLbl.Font               = Enum.Font.GothamBold
    titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
    titleLbl.ZIndex             = 32

    -- Close button
    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size               = UDim2.new(0, 36, 0, 36)
    closeBtn.Position           = UDim2.new(1, -44, 0.5, -18)
    closeBtn.BackgroundColor3   = Color3.fromRGB(200, 50, 50)
    closeBtn.BackgroundTransparency = 0.2
    closeBtn.BorderSizePixel    = 0
    closeBtn.Text               = "✕"
    closeBtn.TextColor3         = Color3.fromRGB(255, 255, 255)
    closeBtn.TextScaled         = true
    closeBtn.Font               = Enum.Font.GothamBold
    closeBtn.ZIndex             = 33
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    closeBtn.MouseButton1Click:Connect(closePanel)

    -- Content scroll
    local scroll = Instance.new("ScrollingFrame", panel)
    scroll.Size              = UDim2.new(1, -16, 1, -64)
    scroll.Position          = UDim2.new(0, 8, 0, 56)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = info.accent or C.Border
    scroll.ZIndex            = 31
    scroll.CanvasSize        = UDim2.new(0, 0, 0, 0)
    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding    = UDim.new(0, 8)
    layout.SortOrder  = Enum.SortOrder.LayoutOrder

    -- Sub-header description
    local descLbl = Instance.new("TextLabel", scroll)
    descLbl.Size               = UDim2.new(1, -8, 0, 44)
    descLbl.BackgroundTransparency = 1
    descLbl.Text               = info.description
    descLbl.TextColor3         = C.Dim
    descLbl.TextScaled         = true
    descLbl.Font               = Enum.Font.Gotham
    descLbl.TextWrapped        = true
    descLbl.TextXAlignment     = Enum.TextXAlignment.Left
    descLbl.ZIndex             = 32
    descLbl.LayoutOrder        = 0

    -- Row entries
    for i, entry in ipairs(info.entries) do
        local row = Instance.new("Frame", scroll)
        row.Size             = UDim2.new(1, -4, 0, 58)
        row.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
        row.BorderSizePixel  = 0
        row.ZIndex           = 32
        row.LayoutOrder      = i
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        do local s=Instance.new("UIStroke",row); s.Color=info.accent or C.Border; s.Thickness=1; s.Transparency=0.6 end

        local nameLbl = Instance.new("TextLabel", row)
        nameLbl.Size               = UDim2.new(1,-12, 0, 26)
        nameLbl.Position           = UDim2.new(0, 10, 0, 4)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text               = entry.name
        nameLbl.TextColor3         = info.accent or C.Border
        nameLbl.TextScaled         = true
        nameLbl.Font               = Enum.Font.GothamBold
        nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
        nameLbl.ZIndex             = 33

        local detLbl = Instance.new("TextLabel", row)
        detLbl.Size               = UDim2.new(1,-12, 0, 24)
        detLbl.Position           = UDim2.new(0, 10, 0, 30)
        detLbl.BackgroundTransparency = 1
        detLbl.Text               = entry.detail
        detLbl.TextColor3         = C.Body
        detLbl.TextScaled         = true
        detLbl.Font               = Enum.Font.Gotham
        detLbl.TextWrapped        = true
        detLbl.TextXAlignment     = Enum.TextXAlignment.Left
        detLbl.ZIndex             = 33
    end

    scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)

    -- Slide in from below
    TweenService:Create(panel, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -220, 0.5, -(info.height or 360) / 2),
    }):Play()
end

-- ── Kiosk panel data ─────────────────────────────────────────────────────────

local KIOSK_DATA = {
    ["Weapons"] = {
        title       = "⚔  Weapons",
        description = "Weapons are found in dungeon loot rooms and boss drops.\nHigher floors drop rarer weapons with stronger base stats.",
        accent      = Color3.fromRGB(0, 210, 255),
        height      = 390,
        entries     = {
            { name = "Common — Iron Blade",      detail = "Low ATK. Found on floors 1-3." },
            { name = "Rare — Steel Edge",         detail = "+25% ATK, +15% crit chance. Floors 4-6." },
            { name = "Epic — Void Saber",         detail = "+50% ATK, life steal on hit. Floors 7+." },
            { name = "Legendary — Relic Weapon",  detail = "Unique passive effect. Boss drops only." },
        },
    },
    ["Armor"] = {
        title       = "🛡  Armor",
        description = "Armor drops from elite enemies and treasure rooms.\nEquip pieces to boost DEF and gain passive bonuses.",
        accent      = Color3.fromRGB(40, 130, 255),
        height      = 390,
        entries     = {
            { name = "Light Armor",   detail = "+10 DEF, +5% Speed. Good for Assassins." },
            { name = "Heavy Armor",   detail = "+30 DEF, -5% Speed. Ideal for Brawlers." },
            { name = "Mystic Robe",   detail = "+15 DEF, +20% ability power. Mage favorite." },
            { name = "Relic Armor",   detail = "Set bonus on 3 pieces. Floor 8+ only." },
        },
    },
    ["Abilities"] = {
        title       = "✨  Abilities",
        description = "Abilities are bound to number keys 1-5.\nQ = Dash. G = Awakening. Press Tab to swap ability slots.",
        accent      = Color3.fromRGB(0, 230, 150),
        height      = 410,
        entries     = {
            { name = "Key 1 — Ability 1",  detail = "Primary skill. Lowest cooldown." },
            { name = "Key 2 — Ability 2",  detail = "Secondary skill. Assigned at level-up or loot." },
            { name = "Key 3 — Ability 3",  detail = "Mid-tier skill. High impact." },
            { name = "Key 4 — Ability 4",  detail = "Power skill. High cooldown, massive damage." },
            { name = "Key 5 — Ability 5",  detail = "Ultimate move. Often unlocked at later floors." },
            { name = "Q — Dash",           detail = "Universal burst dash. Always active." },
        },
    },
    ["Rare Items"] = {
        title       = "💎  Rare Items",
        description = "Rare items are found in treasure rooms and boss vaults.\nThey grant powerful passive effects or consumables.",
        accent      = Color3.fromRGB(155, 80, 255),
        height      = 390,
        entries     = {
            { name = "Shard Crystal",    detail = "Boosts XP gain by 20% for the rest of the run." },
            { name = "Phoenix Scroll",   detail = "Revive once on death with 50% HP." },
            { name = "Void Elixir",      detail = "Doubles ability damage for 30 seconds." },
            { name = "Echo Stone",       detail = "Repeats your last ability cast (passive, 8s CD)." },
        },
    },
    ["Training Zone"] = {
        title       = "⚔  Training Zone",
        description = "Defeat training dummies to practice your skills.\n1-5 are your ability keys. Q = Dash.",
        accent      = Color3.fromRGB(255, 185, 30),
        height      = 340,
        entries     = {
            { name = "Q — Dash",       detail = "Quick burst dash. Shift to sprint first for extra range." },
            { name = "1 / 2 / 3 / 4 / 5",  detail = "Ability slots. Unlock more in dungeon runs." },
            { name = "Shift",          detail = "Hold to sprint at double walk speed." },
            { name = "Tab",            detail = "Open Ability Book to swap your equipped abilities." },
        },
    },
}

-- ── Connect to all lobby ProximityPrompts ─────────────────────────────────────

local world = workspace:WaitForChild("DungeonPiece_World", 30)
if not world then return end
local lobby = world:WaitForChild("Lobby", 15)
if not lobby then return end

local function connectPrompt(prompt)
    local info = KIOSK_DATA[prompt.ObjectText]
    if not info then return end
    prompt.Triggered:Connect(function()
        openPanel(info)
    end)
end

for _, desc in ipairs(lobby:GetDescendants()) do
    if desc:IsA("ProximityPrompt") then
        connectPrompt(desc)
    end
end

lobby.DescendantAdded:Connect(function(desc)
    if desc:IsA("ProximityPrompt") then
        connectPrompt(desc)
    end
end)

print("[LobbyInteraction] Loaded.")
