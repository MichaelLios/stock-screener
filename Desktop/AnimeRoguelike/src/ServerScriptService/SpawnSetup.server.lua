-- SpawnSetup.server.lua
-- Builds a Sailor Piece-style weathered wooden dock lobby before players join.

-- ── Colour constants ───────────────────────────────────────────────────────
local WOOD_DARK    = BrickColor.new("Brown")          -- dock planks
local WOOD_LIGHT   = BrickColor.new("Tan")            -- lighter planks
local STONE_GREY   = BrickColor.new("Dark stone grey")
local POST_COLOR   = BrickColor.new("Reddish brown")
local ROPE_COLOR   = BrickColor.new("Sand yellow")
local WATER_COLOR  = Color3.fromRGB(10, 60, 100)

local function makePart(name, size, cf, bc, mat, anchored, parent)
    local p = Instance.new("Part")
    p.Name       = name
    p.Size       = size
    p.CFrame     = cf
    p.BrickColor = bc
    p.Material   = mat or Enum.Material.Wood
    p.Anchored   = anchored ~= false
    p.Parent     = parent or workspace
    return p
end

-- ── Ocean floor (deep blue water plane) ──────────────────────────────────
local ocean = Instance.new("Part")
ocean.Name     = "Ocean"
ocean.Size     = Vector3.new(400, 1, 400)
ocean.CFrame   = CFrame.new(0, -6, 0)
ocean.Anchored = true
ocean.Color    = WATER_COLOR
ocean.Material = Enum.Material.Neon
ocean.Transparency = 0.35
ocean.CanCollide = false
ocean.Parent   = workspace

-- ── Rocky island base ────────────────────────────────────────────────────
makePart("IslandBase", Vector3.new(80, 6, 80),
    CFrame.new(0, -4, 0), STONE_GREY, Enum.Material.SmoothPlastic)

-- ── Sandy top of the island ───────────────────────────────────────────────
makePart("IslandSand", Vector3.new(70, 1.5, 70),
    CFrame.new(0, -1, 0), BrickColor.new("Sand yellow"), Enum.Material.Sand)

-- ── Dock platform (main wooden area) ─────────────────────────────────────
-- Alternating dark/light planks for visual texture
for i = 0, 5 do
    local bc = (i % 2 == 0) and WOOD_DARK or WOOD_LIGHT
    makePart("Plank_" .. i,
        Vector3.new(60, 1, 9),
        CFrame.new(0, 0.25, -22 + i * 9),
        bc, Enum.Material.Wood)
end

-- ── Dock posts ────────────────────────────────────────────────────────────
local postPositions = {
    Vector3.new(-28, 2, -22), Vector3.new(-28, 2, 22),
    Vector3.new( 28, 2, -22), Vector3.new( 28, 2, 22),
    Vector3.new(-28, 2,  0),  Vector3.new( 28, 2,  0),
}
for i, pos in ipairs(postPositions) do
    makePart("Post_" .. i, Vector3.new(1.4, 6, 1.4),
        CFrame.new(pos), POST_COLOR, Enum.Material.Wood)
end

-- ── Rope railings between posts ───────────────────────────────────────────
local ropeData = {
    { Vector3.new(-28, 4, -11), Vector3.new(60, 0.3, 0.3) },
    { Vector3.new(-28, 4,  11), Vector3.new(60, 0.3, 0.3) },
}
for i, r in ipairs(ropeData) do
    makePart("Rope_" .. i, r[2], CFrame.new(r[1]), ROPE_COLOR, Enum.Material.Fabric)
end

-- ── Wooden crates (scenery) ───────────────────────────────────────────────
local cratePositions = {
    { Vector3.new(-18, 1.5, 14), Vector3.new(3.5, 3.5, 3.5) },
    { Vector3.new(-14, 1.5, 14), Vector3.new(3.5, 3.5, 3.5) },
    { Vector3.new(-16, 5,   14), Vector3.new(3.5, 3.5, 3.5) },
    { Vector3.new( 18, 1.5,-16), Vector3.new(3, 3, 3) },
    { Vector3.new( 22, 1.5,-16), Vector3.new(3, 3, 3) },
}
for i, c in ipairs(cratePositions) do
    makePart("Crate_" .. i, c[2], CFrame.new(c[1]), WOOD_LIGHT, Enum.Material.Wood)
end

-- ── Treasure chest prop (amber glow) ─────────────────────────────────────
local chest = makePart("TreasureChest", Vector3.new(3, 2.5, 2),
    CFrame.new(10, 1.5, -18), BrickColor.new("Bright yellow"), Enum.Material.Neon)
chest.Transparency = 0.3

-- ── Torch posts (neon orange glow) ───────────────────────────────────────
local torchPosts = {
    Vector3.new(-26, 5, -20), Vector3.new(26, 5, -20),
    Vector3.new(-26, 5,  20), Vector3.new(26, 5,  20),
}
for i, pos in ipairs(torchPosts) do
    makePart("TorchPost_" .. i, Vector3.new(0.8, 5, 0.8),
        CFrame.new(pos), POST_COLOR, Enum.Material.Wood)
    local flame = makePart("TorchFlame_" .. i, Vector3.new(1.2, 1.2, 1.2),
        CFrame.new(pos + Vector3.new(0, 3, 0)),
        BrickColor.new("Bright orange"), Enum.Material.Neon)
    flame.Transparency = 0.2
end

-- ── SpawnLocation (on the dock) ───────────────────────────────────────────
local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Name       = "LobbySpawn"
spawnLoc.Size       = Vector3.new(6, 0.4, 6)
spawnLoc.CFrame     = CFrame.new(0, 1, 0)
spawnLoc.Anchored   = true
spawnLoc.Neutral    = true
spawnLoc.Duration   = 0
spawnLoc.BrickColor = BrickColor.new("Bright yellow")
spawnLoc.Material   = Enum.Material.Neon
spawnLoc.Transparency = 0.5
spawnLoc.Parent     = workspace

-- ── Overhead sign ─────────────────────────────────────────────────────────
local signPost = makePart("SignPost", Vector3.new(0.4, 8, 0.4),
    CFrame.new(0, 4, -25), POST_COLOR, Enum.Material.Wood)
local signBoard = makePart("SignBoard", Vector3.new(12, 3, 0.4),
    CFrame.new(0, 9, -25), BrickColor.new("Reddish brown"), Enum.Material.Wood)
local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Front
signGui.Parent = signBoard
local signLabel = Instance.new("TextLabel", signGui)
signLabel.Size = UDim2.new(1, 0, 1, 0)
signLabel.BackgroundTransparency = 1
signLabel.Text = "SAILOR PIECE"
signLabel.TextColor3 = Color3.fromRGB(251, 191, 36)
signLabel.TextScaled = true
signLabel.Font = Enum.Font.GothamBold

print("[SpawnSetup] Dock lobby built.")
