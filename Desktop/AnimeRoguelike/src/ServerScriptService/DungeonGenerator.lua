-- DungeonGenerator.server.lua
-- Procedurally generates dungeon floors as a graph of rooms, then builds
-- physical geometry in the Workspace.

local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoomData      = require(ReplicatedStorage.Modules.RoomData)
local DungeonThemes = require(ReplicatedStorage.Modules.DungeonThemes)
local EnemyData     = require(ReplicatedStorage.Modules.EnemyData)

local DungeonGenerator = {}

-- ────────────────────────────────────────────────
-- ROOM GRAPH GENERATION
-- ────────────────────────────────────────────────

local function rollRoomType(weights)
    local total = 0
    for _, w in pairs(weights) do total = total + w end
    local roll = math.random() * total
    local cum = 0
    for typeName, w in pairs(weights) do
        cum = cum + w
        if roll <= cum then return typeName end
    end
end

local function buildRoomGraph(floor)
    local cfg = RoomData.FloorConfig
    local numRooms = math.random(cfg.MinRooms, cfg.MaxRooms)
    local rooms = {}

    -- Room 1 is always Entrance
    rooms[1] = { Id = 1, Type = RoomData.RoomTypes.Entrance, Connections = {}, Cleared = true, Position = Vector2.new(0, 0) }

    -- Guarantee certain room types
    local guaranteed = {}
    for _, t in ipairs(cfg.GuaranteedTypes) do
        table.insert(guaranteed, t)
    end

    -- Fill interior rooms
    local weights = table.clone(cfg.TypeWeights)
    for i = 2, numRooms - 1 do
        local t
        if #guaranteed > 0 then
            t = table.remove(guaranteed, 1)
        else
            t = rollRoomType(weights)
        end
        rooms[i] = { Id = i, Type = t, Connections = {}, Cleared = false, Position = Vector2.new(0, 0) }
    end

    -- Last room is Boss (locked)
    rooms[numRooms] = { Id = numRooms, Type = RoomData.RoomTypes.Boss, Connections = {}, Cleared = false, Locked = true, Position = Vector2.new(0, 0) }

    -- Connect rooms into a path-graph so every room is reachable
    -- Main path: 1 -> 2 -> ... -> numRooms
    for i = 1, numRooms - 1 do
        table.insert(rooms[i].Connections, rooms[i + 1].Id)
        table.insert(rooms[i + 1].Connections, rooms[i].Id)
    end

    -- Add random extra connections for branching (up to numRooms / 3)
    local extraLinks = math.floor(numRooms / 3)
    for _ = 1, extraLinks do
        local a = math.random(1, numRooms - 2)
        local b = math.random(a + 2, numRooms - 1)
        -- avoid duplicates
        local already = false
        for _, cid in ipairs(rooms[a].Connections) do
            if cid == b then already = true break end
        end
        if not already then
            table.insert(rooms[a].Connections, b)
            table.insert(rooms[b].Connections, a)
        end
    end

    -- Assign grid positions via BFS layout
    local visited = {}
    local queue = { 1 }
    visited[1] = true
    local dirs = { Vector2.new(1,0), Vector2.new(-1,0), Vector2.new(0,1), Vector2.new(0,-1) }
    local dirIdx = {}
    while #queue > 0 do
        local cur = table.remove(queue, 1)
        local dIdx = 1
        for _, nid in ipairs(rooms[cur].Connections) do
            if not visited[nid] then
                visited[nid] = true
                rooms[nid].Position = rooms[cur].Position + dirs[((dIdx - 1) % #dirs) + 1]
                dIdx = dIdx + 1
                table.insert(queue, nid)
            end
        end
    end

    return rooms
end

-- ────────────────────────────────────────────────
-- PHYSICAL ROOM BUILDING
-- ────────────────────────────────────────────────

-- Room spacing must equal the TileSize X/Z so doors align between adjacent rooms.
-- All themes now use 120×24×120 tiles → spacing is 120.
local ROOM_SPACING        = 120   -- studs between room centers
local DUNGEON_WORLD_OFFSET = Vector3.new(10000, 100, 0)  -- far from lobby to prevent visual overlap
local WALL_THICKNESS = 3
local DOOR_WIDTH     = 22   -- wide enough to dash through comfortably
local DOOR_HEIGHT    = 16   -- tall enough for jumping / aerial dashes

local function buildFloorPart(parent, size, cframe, color, name)
    local p = Instance.new("Part")
    p.Name = name or "Part"
    p.Size = size
    p.CFrame = cframe
    p.Anchored = true
    p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    p.Parent = parent
    return p
end

-- Build one wall face that may have a centred door gap.
-- spanAxis: "X" for N/S walls (spans left-right), "Z" for E/W walls (spans front-back)
local function buildWallFace(roomFolder, hasDoor, spanLen, rh, wallCF, theme, name)
    local wt = WALL_THICKNESS
    if not hasDoor then
        -- Solid wall
        local sz = (spanLen == "X_span")
            and Vector3.new(spanLen, rh, wt)
            or  Vector3.new(wt, rh, spanLen)
        -- spanLen is actually a number passed in; fix below
    end
    -- (implementation inlined per call site for clarity)
end

-- Build a wall spanning the X axis (North or South wall).
-- zOffset: signed half-depth of room (±rd/2)
local function buildXWall(roomFolder, hasDoor, rw, rh, wt, origin, zOff, theme, tag)
    if hasDoor then
        local sideW  = (rw - DOOR_WIDTH) / 2          -- width of each side pillar
        local headH  = rh - DOOR_HEIGHT                -- header strip above door
        -- Left pillar
        if sideW > 0 then
            buildFloorPart(roomFolder,
                Vector3.new(sideW, rh, wt),
                origin * CFrame.new(-(DOOR_WIDTH/2 + sideW/2), rh/2, zOff),
                theme.WallColor, tag.."_PillarL")
            -- Right pillar
            buildFloorPart(roomFolder,
                Vector3.new(sideW, rh, wt),
                origin * CFrame.new( (DOOR_WIDTH/2 + sideW/2), rh/2, zOff),
                theme.WallColor, tag.."_PillarR")
        end
        -- Header above door
        if headH > 0 then
            buildFloorPart(roomFolder,
                Vector3.new(DOOR_WIDTH, headH, wt),
                origin * CFrame.new(0, DOOR_HEIGHT + headH/2, zOff),
                theme.WallColor, tag.."_Header")
        end
    else
        buildFloorPart(roomFolder,
            Vector3.new(rw, rh, wt),
            origin * CFrame.new(0, rh/2, zOff),
            theme.WallColor, tag)
    end
end

-- Build a wall spanning the Z axis (East or West wall).
local function buildZWall(roomFolder, hasDoor, rd, rh, wt, origin, xOff, theme, tag)
    if hasDoor then
        local sideD = (rd - DOOR_WIDTH) / 2
        local headH = rh - DOOR_HEIGHT
        if sideD > 0 then
            buildFloorPart(roomFolder,
                Vector3.new(wt, rh, sideD),
                origin * CFrame.new(xOff, rh/2, -(DOOR_WIDTH/2 + sideD/2)),
                theme.WallColor, tag.."_PillarL")
            buildFloorPart(roomFolder,
                Vector3.new(wt, rh, sideD),
                origin * CFrame.new(xOff, rh/2,  (DOOR_WIDTH/2 + sideD/2)),
                theme.WallColor, tag.."_PillarR")
        end
        if headH > 0 then
            buildFloorPart(roomFolder,
                Vector3.new(wt, headH, DOOR_WIDTH),
                origin * CFrame.new(xOff, DOOR_HEIGHT + headH/2, 0),
                theme.WallColor, tag.."_Header")
        end
    else
        buildFloorPart(roomFolder,
            Vector3.new(wt, rh, rd),
            origin * CFrame.new(xOff, rh/2, 0),
            theme.WallColor, tag)
    end
end

-- roomsMap: { [id] = roomData } so we can look up neighbour positions
local function buildRoom(folder, roomData, theme, tileSize, roomsMap)
    local wx = roomData.Position.X * ROOM_SPACING + DUNGEON_WORLD_OFFSET.X
    local wz = roomData.Position.Y * ROOM_SPACING + DUNGEON_WORLD_OFFSET.Z
    local origin = CFrame.new(wx, DUNGEON_WORLD_OFFSET.Y, wz)

    local rw = tileSize.X   -- 20
    local rh = tileSize.Y   -- 8
    local rd = tileSize.Z   -- 20
    local wt = WALL_THICKNESS

    local roomFolder = Instance.new("Folder")
    roomFolder.Name = "Room_" .. roomData.Id .. "_" .. roomData.Type
    roomFolder.Parent = folder

    -- Floor and ceiling
    buildFloorPart(roomFolder, Vector3.new(rw, 1, rd),
        origin * CFrame.new(0, -0.5, 0), theme.FloorColor, "Floor")
    buildFloorPart(roomFolder, Vector3.new(rw, 1, rd),
        origin * CFrame.new(0, rh + 0.5, 0), theme.WallColor, "Ceiling")

    -- Determine which cardinal directions have a connected room
    local hasDoorN, hasDoorS, hasDoorE, hasDoorW = false, false, false, false
    for _, connId in ipairs(roomData.Connections) do
        local cr = roomsMap and roomsMap[connId]
        if cr then
            local dx = cr.Position.X - roomData.Position.X
            local dz = cr.Position.Y - roomData.Position.Y
            if     dx >  0.5 then hasDoorE = true
            elseif dx < -0.5 then hasDoorW = true
            end
            if     dz >  0.5 then hasDoorS = true
            elseif dz < -0.5 then hasDoorN = true
            end
        end
    end

    -- Build four walls, cutting door gaps where needed
    buildXWall(roomFolder, hasDoorN, rw, rh, wt, origin, -rd/2, theme, "WallN")
    buildXWall(roomFolder, hasDoorS, rw, rh, wt, origin,  rd/2, theme, "WallS")
    buildZWall(roomFolder, hasDoorW, rd, rh, wt, origin, -rw/2, theme, "WallW")
    buildZWall(roomFolder, hasDoorE, rd, rh, wt, origin,  rw/2, theme, "WallE")

    -- Spawn point (offset slightly from center so player isn't clipping enemies)
    local spawnPart = Instance.new("Part")
    spawnPart.Name = "SpawnPoint"
    spawnPart.Size = Vector3.new(2, 0.5, 2)
    spawnPart.CFrame = origin * CFrame.new(0, 0.25, rd * 0.35)  -- near south door
    spawnPart.Anchored = true
    spawnPart.Transparency = 1
    spawnPart.CanCollide = false
    spawnPart.Parent = roomFolder

    -- Room label billboard
    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 240, 0, 60)
    bg.StudsOffset = Vector3.new(0, rh + 4, 0)
    bg.AlwaysOnTop = true
    bg.Parent = spawnPart
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.4
    lbl.BackgroundColor3 = Color3.fromRGB(5, 5, 15)
    lbl.Text = roomData.Type .. "  #" .. roomData.Id
    lbl.TextColor3 = theme.AmbientColor
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = bg

    -- ── Ambient light in room center ─────────────────────────────────────
    local lightPart = buildFloorPart(roomFolder,
        Vector3.new(2, 2, 2),
        origin * CFrame.new(0, rh - 2, 0),
        theme.AmbientColor, "CenterLight")
    lightPart.Material = Enum.Material.Neon
    lightPart.Transparency = 0.3
    local pl = Instance.new("PointLight")
    pl.Color = theme.AmbientColor
    pl.Brightness = 3
    pl.Range = rw * 1.2
    pl.Parent = lightPart

    -- ── Corner pillar columns (give the player things to dash around) ─────
    local pillarH = rh - 2
    local pillarW = 4
    for _, offsets in ipairs({
        {rw * 0.32, rd * 0.32}, {-rw * 0.32, rd * 0.32},
        {rw * 0.32, -rd * 0.32}, {-rw * 0.32, -rd * 0.32},
    }) do
        local pil = buildFloorPart(roomFolder,
            Vector3.new(pillarW, pillarH, pillarW),
            origin * CFrame.new(offsets[1], pillarH / 2, offsets[2]),
            theme.WallColor, "Pillar")
        pil.Material = Enum.Material.SmoothPlastic
        -- Small glow cap on each pillar
        local cap = buildFloorPart(roomFolder,
            Vector3.new(pillarW + 1, 1, pillarW + 1),
            origin * CFrame.new(offsets[1], pillarH + 0.5, offsets[2]),
            theme.AmbientColor, "PillarCap")
        cap.Material = Enum.Material.Neon
        cap.Transparency = 0.5
    end

    -- ── Low cover blocks scattered around the midfield ────────────────────
    -- Gives melee/ranged players terrain to use during fights
    for _, off in ipairs({
        {rw * 0.18, 0}, {-rw * 0.18, 0},
        {0, rd * 0.18}, {0, -rd * 0.18},
    }) do
        buildFloorPart(roomFolder,
            Vector3.new(8, 4, 8),
            origin * CFrame.new(off[1], 2, off[2]),
            theme.FloorColor, "Cover")
    end

    -- Invisible door-trigger volumes placed in each gap so LocalGame.client.lua
    -- can detect room transitions when the player walks through.
    for _, connId in ipairs(roomData.Connections) do
        local cr = roomsMap and roomsMap[connId]
        if cr then
            local dx = cr.Position.X - roomData.Position.X
            local dz = cr.Position.Y - roomData.Position.Y
            local triggerCF
            if     dx >  0.5 then triggerCF = origin * CFrame.new( rw/2, DOOR_HEIGHT/2, 0)
            elseif dx < -0.5 then triggerCF = origin * CFrame.new(-rw/2, DOOR_HEIGHT/2, 0)
            elseif dz >  0.5 then triggerCF = origin * CFrame.new(0, DOOR_HEIGHT/2,  rd/2)
            elseif dz < -0.5 then triggerCF = origin * CFrame.new(0, DOOR_HEIGHT/2, -rd/2)
            end
            if triggerCF then
                local isDX = math.abs(dx) > 0.5
                local doorTrigger = Instance.new("Part")
                doorTrigger.Name = "Door_To_" .. connId
                doorTrigger.Size = isDX
                    and Vector3.new(wt + 4, DOOR_HEIGHT, DOOR_WIDTH)
                    or  Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, wt + 4)
                doorTrigger.CFrame = triggerCF
                doorTrigger.Anchored = true
                doorTrigger.Transparency = 1
                doorTrigger.CanCollide = false
                doorTrigger.Parent = roomFolder
                local tag = Instance.new("StringValue")
                tag.Name = "TargetRoomId"
                tag.Value = tostring(connId)
                tag.Parent = doorTrigger
            end
        end
    end

    -- Boss door barrier — glowing red wall sealing every door into the boss room.
    -- Built at each connection so it can't be bypassed from any direction.
    if roomData.Locked then
        for _, connId in ipairs(roomData.Connections) do
            local cr = roomsMap and roomsMap[connId]
            if cr then
                local dx = cr.Position.X - roomData.Position.X
                local dz = cr.Position.Y - roomData.Position.Y
                local barrierCF
                if     dx >  0.5 then barrierCF = origin * CFrame.new( rw/2 - wt, DOOR_HEIGHT/2, 0)
                elseif dx < -0.5 then barrierCF = origin * CFrame.new(-rw/2 + wt, DOOR_HEIGHT/2, 0)
                elseif dz >  0.5 then barrierCF = origin * CFrame.new(0, DOOR_HEIGHT/2,  rd/2 - wt)
                elseif dz < -0.5 then barrierCF = origin * CFrame.new(0, DOOR_HEIGHT/2, -rd/2 + wt)
                end
                if barrierCF then
                    local isDX = math.abs(dx) > 0.5
                    local barrierSize = isDX
                        and Vector3.new(wt + 1, DOOR_HEIGHT, DOOR_WIDTH)
                        or  Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, wt + 1)
                    local lockBarrier = buildFloorPart(roomFolder,
                        barrierSize, barrierCF,
                        Color3.fromRGB(200, 0, 0), "BossDoor")
                    lockBarrier.Material = Enum.Material.Neon
                    lockBarrier.Transparency = 0.35
                    local lockVal = Instance.new("BoolValue")
                    lockVal.Name = "Locked"; lockVal.Value = true
                    lockVal.Parent = lockBarrier
                    -- Particle-like glow ring
                    local gl = Instance.new("PointLight")
                    gl.Color = Color3.fromRGB(255, 30, 30)
                    gl.Brightness = 4; gl.Range = 30
                    gl.Parent = lockBarrier
                end
            end
        end
    end

    return roomFolder
end

-- ────────────────────────────────────────────────
-- PUBLIC API
-- ────────────────────────────────────────────────

function DungeonGenerator.GenerateFloor(floor, parentFolder, themeIndex)
    math.randomseed(tick() + floor * 1000)

    local theme, cycle
    if themeIndex and DungeonThemes.Themes[themeIndex] then
        theme = DungeonThemes.Themes[themeIndex]
        cycle = math.floor((floor - 1) / #DungeonThemes.Themes) + 1
    else
        theme, cycle = DungeonThemes.GetThemeForFloor(floor)
    end
    local graph = buildRoomGraph(floor)

    local floorFolder = Instance.new("Folder")
    floorFolder.Name = "Floor_" .. floor
    floorFolder.Parent = parentFolder or workspace

    -- Store metadata
    local meta = Instance.new("Folder")
    meta.Name = "_Meta"
    meta.Parent = floorFolder

    local floorNum = Instance.new("IntValue")
    floorNum.Name = "FloorNumber"
    floorNum.Value = floor
    floorNum.Parent = meta

    local themeName = Instance.new("StringValue")
    themeName.Name = "ThemeName"
    themeName.Value = theme.Name
    themeName.Parent = meta

    local roomCount = Instance.new("IntValue")
    roomCount.Name = "RoomCount"
    roomCount.Value = #graph
    roomCount.Parent = meta

    -- Build a lookup table so buildRoom can check neighbour directions
    local roomsMap = {}
    for _, room in ipairs(graph) do
        roomsMap[room.Id] = room
    end

    -- Build each room (passing roomsMap so walls know where to put door gaps)
    local builtRooms = {}
    for _, room in ipairs(graph) do
        local folder = buildRoom(floorFolder, room, theme, theme.TileSize, roomsMap)
        builtRooms[room.Id] = { Folder = folder, Data = room }
    end

    -- Export spacing and world offset so GameManager places enemies at the right position
    floorFolder:SetAttribute("RoomSpacing",  ROOM_SPACING)
    floorFolder:SetAttribute("WorldOffsetX", DUNGEON_WORLD_OFFSET.X)
    floorFolder:SetAttribute("WorldOffsetY", DUNGEON_WORLD_OFFSET.Y)
    floorFolder:SetAttribute("WorldOffsetZ", DUNGEON_WORLD_OFFSET.Z)

    print(("[DungeonGenerator] Floor %d generated — Theme: %s, Rooms: %d, Cycle: %d"):format(
        floor, theme.Name, #graph, cycle))

    return floorFolder, graph, theme
end

-- Clean up a floor's geometry
function DungeonGenerator.DestroyFloor(floorFolder)
    if floorFolder and floorFolder.Parent then
        floorFolder:Destroy()
    end
end

return DungeonGenerator
