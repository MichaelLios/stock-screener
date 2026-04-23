-- SettingsInventory.client.lua
-- Settings (volume) + Inventory panels in their own ScreenGui.
-- Fully independent from HUD so any error here won't break the core HUD.

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateHUD    = RemoteEvents:WaitForChild("UpdateHUD")

-- ── Own ScreenGui (no dependency on HUD.client.lua) ──────────────────────────
local siGui = Instance.new("ScreenGui")
siGui.Name           = "SettingsInventoryGui"
siGui.ResetOnSpawn   = false
siGui.IgnoreGuiInset = true
siGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
siGui.Parent         = playerGui

-- ── Palette ──────────────────────────────────────────────────────────────────
local C = {
    PanelBG     = Color3.fromRGB(14, 11,  8),
    PanelBorder = Color3.fromRGB(180, 83,  6),
    Amber       = Color3.fromRGB(217,119,  6),
    AmberLight  = Color3.fromRGB(251,191, 36),
    TextMain    = Color3.fromRGB(245,235,215),
    TextDim     = Color3.fromRGB(180,165,140),
}

-- ── Volume state ─────────────────────────────────────────────────────────────
local function getOrCreateVolumeFolder()
    local vf = playerGui:FindFirstChild("_VolumeState")
    if not vf then
        vf = Instance.new("Folder")
        vf.Name   = "_VolumeState"
        vf.Parent = playerGui
    end
    local function nv(name, default)
        local n = vf:FindFirstChild(name)
        if not n then
            n = Instance.new("NumberValue")
            n.Name   = name
            n.Value  = default
            n.Parent = vf
        end
        return n
    end
    return nv("MusicVolume", 0.35), nv("SFXVolume", 0.7)
end

local musicVolRef, sfxVolRef = getOrCreateVolumeFolder()

-- ── Helper: icon button ───────────────────────────────────────────────────────
local function makeIconBtn(label, xOffset)
    local btn = Instance.new("TextButton")
    btn.Size                    = UDim2.new(0, 44, 0, 44)
    btn.Position                = UDim2.new(0, xOffset, 0, 70)
    btn.BackgroundColor3        = C.PanelBG
    btn.BackgroundTransparency  = 0.05
    btn.BorderSizePixel         = 0
    btn.Text                    = label
    btn.TextColor3              = C.AmberLight
    btn.TextScaled              = true
    btn.Font                    = Enum.Font.GothamBold
    btn.ZIndex                  = 10
    btn.Parent                  = siGui
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    do
        local s = Instance.new("UIStroke", btn)
        s.Color     = C.Amber
        s.Thickness = 1.5
    end
    return btn
end

-- ── Helper: panel frame ───────────────────────────────────────────────────────
local function makePanel(w, h, xOffset)
    local pf = Instance.new("Frame")
    pf.Size                    = UDim2.new(0, w, 0, h)
    pf.Position                = UDim2.new(0, xOffset, 0, 122)
    pf.BackgroundColor3        = C.PanelBG
    pf.BackgroundTransparency  = 0.05
    pf.BorderSizePixel         = 0
    pf.Visible                 = false
    pf.ZIndex                  = 25
    pf.Parent                  = siGui
    Instance.new("UICorner", pf).CornerRadius = UDim.new(0, 12)
    do
        local s = Instance.new("UIStroke", pf)
        s.Color     = C.Amber
        s.Thickness = 2
    end
    return pf
end

local function panelTitle(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size                    = UDim2.new(1, -12, 0, 38)
    lbl.Position                = UDim2.new(0, 6, 0, 4)
    lbl.BackgroundTransparency  = 1
    lbl.Text                    = text
    lbl.TextColor3              = C.AmberLight
    lbl.TextScaled              = true
    lbl.Font                    = Enum.Font.GothamBold
    lbl.ZIndex                  = 26
    return lbl
end

local function closeBtn(parent, onClose)
    local btn = Instance.new("TextButton", parent)
    btn.Size               = UDim2.new(0, 90, 0, 34)
    btn.Position           = UDim2.new(0.5, -45, 1, -44)
    btn.BackgroundColor3   = C.PanelBorder
    btn.BorderSizePixel    = 0
    btn.Text               = "Close"
    btn.TextColor3         = C.TextMain
    btn.TextScaled         = true
    btn.Font               = Enum.Font.GothamBold
    btn.ZIndex             = 26
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(onClose)
end

-- ── SETTINGS ─────────────────────────────────────────────────────────────────

local settingsOpen  = false
local settingsBtn   = makeIconBtn("SET", 8)
local settingsPanel = makePanel(300, 220, 8)

panelTitle(settingsPanel, "Settings")

local function makeVolumeRow(parent, label, yPos, volRef)
    local rowLbl = Instance.new("TextLabel", parent)
    rowLbl.Size               = UDim2.new(0, 110, 0, 28)
    rowLbl.Position           = UDim2.new(0, 10, 0, yPos)
    rowLbl.BackgroundTransparency = 1
    rowLbl.Text               = label
    rowLbl.TextColor3         = C.TextMain
    rowLbl.TextScaled         = true
    rowLbl.Font               = Enum.Font.Gotham
    rowLbl.TextXAlignment     = Enum.TextXAlignment.Left
    rowLbl.ZIndex             = 26

    local sliderBG = Instance.new("Frame", parent)
    sliderBG.Size             = UDim2.new(0, 160, 0, 14)
    sliderBG.Position         = UDim2.new(0, 126, 0, yPos + 7)
    sliderBG.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
    sliderBG.BorderSizePixel  = 0
    sliderBG.ZIndex           = 26
    Instance.new("UICorner", sliderBG).CornerRadius = UDim.new(1, 0)

    local sliderFill = Instance.new("Frame", sliderBG)
    sliderFill.Size             = UDim2.new(volRef.Value, 0, 1, 0)
    sliderFill.BackgroundColor3 = C.Amber
    sliderFill.BorderSizePixel  = 0
    sliderFill.ZIndex           = 27
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", sliderBG)
    knob.Size              = UDim2.new(0, 18, 0, 18)
    knob.Position          = UDim2.new(volRef.Value, -9, 0.5, -9)
    knob.BackgroundColor3  = C.AmberLight
    knob.BorderSizePixel   = 0
    knob.ZIndex            = 28
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local dragging = false
    knob.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseMovement
        and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local rel = math.clamp((inp.Position.X - sliderBG.AbsolutePosition.X) / sliderBG.AbsoluteSize.X, 0, 1)
        sliderFill.Size  = UDim2.new(rel, 0, 1, 0)
        knob.Position    = UDim2.new(rel, -9, 0.5, -9)
        volRef.Value     = rel
    end)
end

makeVolumeRow(settingsPanel, "Music", 54, musicVolRef)
makeVolumeRow(settingsPanel, "SFX",   98, sfxVolRef)
closeBtn(settingsPanel, function()
    settingsPanel.Visible = false
    settingsOpen = false
end)

settingsBtn.MouseButton1Click:Connect(function()
    settingsOpen = not settingsOpen
    settingsPanel.Visible = settingsOpen
end)

-- ── INVENTORY ────────────────────────────────────────────────────────────────

local inventoryOpen = false
local inventoryBtn  = makeIconBtn("INV", 58)
local invPanel      = makePanel(380, 460, 8)

panelTitle(invPanel, "Inventory")

local invDiv = Instance.new("Frame", invPanel)
invDiv.Size             = UDim2.new(1, -20, 0, 2)
invDiv.Position         = UDim2.new(0, 10, 0, 48)
invDiv.BackgroundColor3 = C.PanelBorder
invDiv.BorderSizePixel  = 0
invDiv.ZIndex           = 26

local invAbilLabel = Instance.new("TextLabel", invPanel)
invAbilLabel.Size               = UDim2.new(1, -12, 0, 24)
invAbilLabel.Position           = UDim2.new(0, 10, 0, 56)
invAbilLabel.BackgroundTransparency = 1
invAbilLabel.Text               = "Equipped Abilities  (keys 1-5)"
invAbilLabel.TextColor3         = C.TextDim
invAbilLabel.TextScaled         = true
invAbilLabel.Font               = Enum.Font.Gotham
invAbilLabel.TextXAlignment     = Enum.TextXAlignment.Left
invAbilLabel.ZIndex             = 26

local invSlotFrames = {}
local slotKeys      = { "1", "2", "3", "4", "5" }

for i = 1, 5 do
    local sf = Instance.new("Frame", invPanel)
    sf.Size             = UDim2.new(0, 60, 0, 70)
    sf.Position         = UDim2.new(0, 8 + (i-1)*70, 0, 82)
    sf.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
    sf.BorderSizePixel  = 0
    sf.ZIndex           = 26
    Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 8)
    do local s = Instance.new("UIStroke", sf); s.Color = C.PanelBorder; s.Thickness = 1.5 end

    local keyLbl = Instance.new("TextLabel", sf)
    keyLbl.Size                 = UDim2.new(1, 0, 0, 20)
    keyLbl.BackgroundTransparency = 1
    keyLbl.Text                 = slotKeys[i]
    keyLbl.TextColor3           = C.Amber
    keyLbl.TextScaled           = true
    keyLbl.Font                 = Enum.Font.GothamBold
    keyLbl.ZIndex               = 27

    local nameLbl = Instance.new("TextLabel", sf)
    nameLbl.Name                = "AbilityName"
    nameLbl.Size                = UDim2.new(1, -4, 0, 44)
    nameLbl.Position            = UDim2.new(0, 2, 0, 22)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                = "—"
    nameLbl.TextColor3          = C.TextMain
    nameLbl.TextScaled          = true
    nameLbl.Font                = Enum.Font.Gotham
    nameLbl.TextWrapped         = true
    nameLbl.ZIndex              = 27

    invSlotFrames[i] = sf
end

local invItemLabel = Instance.new("TextLabel", invPanel)
invItemLabel.Size               = UDim2.new(1, -12, 0, 24)
invItemLabel.Position           = UDim2.new(0, 10, 0, 164)
invItemLabel.BackgroundTransparency = 1
invItemLabel.Text               = "Items"
invItemLabel.TextColor3         = C.TextDim
invItemLabel.TextScaled         = true
invItemLabel.Font               = Enum.Font.Gotham
invItemLabel.TextXAlignment     = Enum.TextXAlignment.Left
invItemLabel.ZIndex             = 26

local invItemScroll = Instance.new("ScrollingFrame", invPanel)
invItemScroll.Size                  = UDim2.new(1, -16, 0, 220)
invItemScroll.Position              = UDim2.new(0, 8, 0, 190)
invItemScroll.BackgroundTransparency = 1
invItemScroll.ScrollBarThickness    = 4
invItemScroll.ScrollBarImageColor3  = C.Amber
invItemScroll.ZIndex                = 26
invItemScroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
do
    local l = Instance.new("UIListLayout", invItemScroll)
    l.Padding   = UDim.new(0, 4)
    l.SortOrder = Enum.SortOrder.LayoutOrder
end

local invItems = {}

local function rebuildItemList()
    for _, c in ipairs(invItemScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    local rows = {}
    for name, count in pairs(invItems) do
        table.insert(rows, { name = name, count = count })
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    for _, row in ipairs(rows) do
        local rf = Instance.new("Frame", invItemScroll)
        rf.Size             = UDim2.new(1, -4, 0, 32)
        rf.BackgroundColor3 = Color3.fromRGB(22, 17, 12)
        rf.BorderSizePixel  = 0
        rf.ZIndex           = 27
        Instance.new("UICorner", rf).CornerRadius = UDim.new(0, 6)

        local rl = Instance.new("TextLabel", rf)
        rl.Size               = UDim2.new(1, -8, 1, 0)
        rl.Position           = UDim2.new(0, 6, 0, 0)
        rl.BackgroundTransparency = 1
        rl.Text               = row.name .. (row.count > 1 and "  x"..row.count or "")
        rl.TextColor3         = C.TextMain
        rl.TextScaled         = true
        rl.Font               = Enum.Font.Gotham
        rl.TextXAlignment     = Enum.TextXAlignment.Left
        rl.ZIndex             = 28
    end
    invItemScroll.CanvasSize = UDim2.new(0, 0, 0, #rows * 36)
end

closeBtn(invPanel, function()
    invPanel.Visible = false
    inventoryOpen    = false
end)

inventoryBtn.MouseButton1Click:Connect(function()
    inventoryOpen    = not inventoryOpen
    invPanel.Visible = inventoryOpen
    if inventoryOpen then rebuildItemList() end
end)

UpdateHUD.OnClientEvent:Connect(function(data)
    if data.ActiveSlots then
        for i, name in ipairs(data.ActiveSlots) do
            if invSlotFrames[i] then
                local lbl = invSlotFrames[i]:FindFirstChild("AbilityName")
                if lbl then lbl.Text = name or "—" end
            end
        end
    end
    if data.LootItem then
        local name = data.LootItem
        invItems[name] = (invItems[name] or 0) + 1
        if inventoryOpen then rebuildItemList() end
    end
    if data.OpenInventory then
        invPanel.Visible = true
        inventoryOpen    = true
        rebuildItemList()
    end
end)

print("[SettingsInventory] Loaded.")
