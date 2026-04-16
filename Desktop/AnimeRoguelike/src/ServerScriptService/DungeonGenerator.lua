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

-- Room spacing = tile size so rooms sit directly adjacent; door gaps align.
local ROOM_SPACING   = 20   -- studs between room centers (must equal TileSize X/Z)
local WALL_THICKNESS = 2
local DOOR_WIDTH     = 8    -- opening width (< TileSize so side-walls remain)
local DOOR_HEIGHT    = 6    -- opening height (< room height so header remains)

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
    local wx = roomData.Position.X * ROOM_SPACING
    local wz = roomData.Position.Y * ROOM_SPACING
    local origin = CFrame.new(wx, 0, wz)

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

    -- Spawn point
    local spawnPart = Instance.new("Part")
    spawnPart.Name = "SpawnPoint"
    spawnPart.Size = Vector3.new(2, 0.5, 2)
    spawnPart.CFrame = origin * CFrame.new(0, 0.25, 0)
    spawnPart.Anchored = true
    spawnPart.Transparency = 1
    spawnPart.CanCollide = false
    spawnPart.Parent = roomFolder

    -- Room label
    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 200, 0, 50)
    bg.StudsOffset = Vector3.new(0, 8, 0)
    bg.AlwaysOnTop = true
    bg.Parent = spawnPart
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = roomData.Type .. " #" .. roomData.Id
    lbl.TextColor3 = theme.AmbientColor
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = bg

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
                local doorTrigger = Instance.new("Part")
                doorTrigger.Name = "Door_To_" .. connId
                doorTrigger.Size = Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, wt + 2)
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

    -- Boss door barrier (glowing red wall blocking entrance to boss room)
    if roomData.Locked then
        -- Block the north door (first entrance direction found)
        local barrierZ = -rd/2 + wt
        local lockBarrier = buildFloorPart(roomFolder,
            Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, wt),
            origin * CFrame.new(0, DOOR_HEIGHT/2, barrierZ),
            Color3.fromRGB(180, 0, 0), "BossDoor")
        lockBarrier.Material = Enum.Material.Neon
        lockBarrier.Transparency = 0.4
        local lockVal = Instance.new("BoolValue")
        lockVal.Name = "Locked"
        lockVal.Value = true
        lockVal.Parent = lockBarrier
    end

    return roomFolder
end

-- ────────────────────────────────────────────────
-- PUBLIC API
-- ────────────────────────────────────────────────

function DungeonGenerator.GenerateFloor(floor, parentFolder)
    math.randomseed(tick() + floor * 1000)

    local theme, cycle = DungeonThemes.GetThemeForFloor(floor)
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

    -- Export the room spacing constant so GameManager can place enemies correctly
    floorFolder:SetAttribute("RoomSpacing", ROOM_SPACING)

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
