-- GameManager.server.lua
-- Orchestrates the full game loop: lobby → archetype select → dungeon floors → death/win.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DungeonGenerator   = require(script.Parent.DungeonGenerator)
local EnemyAI            = require(script.Parent.EnemyAI)
local LootSystem         = require(script.Parent.LootSystem)
local CombatSystem       = require(script.Parent.CombatSystem)
local MetaProgression    = require(script.Parent.MetaProgression)
local RoomData           = require(ReplicatedStorage.Modules.RoomData)
local EnemyData          = require(ReplicatedStorage.Modules.EnemyData)

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateHUD        = RemoteEvents:WaitForChild("UpdateHUD")
local RoomCleared      = RemoteEvents:WaitForChild("RoomCleared")
local FloorComplete    = RemoteEvents:WaitForChild("FloorComplete")
local PlayerDied       = RemoteEvents:WaitForChild("PlayerDied")
local LootDropEvt      = RemoteEvents:WaitForChild("LootDrop")
local EnemyAttackEvt   = RemoteEvents:WaitForChild("EnemyAttack")
local LootChoiceEvt    = RemoteEvents:WaitForChild("LootChoice")
local BossPhaseEvt     = RemoteEvents:WaitForChild("BossPhase")
local ShrineOpenEvt    = RemoteEvents:WaitForChild("ShrineOpen")

-- ────────────────────────────────────────────────
-- GAME STATE
-- ────────────────────────────────────────────────

local GameState = {
    Phase        = "Lobby",    -- Lobby | ArchetypeSelect | Running | GameOver
    CurrentFloor = 0,
    FloorFolder  = nil,
    RoomGraph    = nil,
    Theme        = nil,
    ActiveRoomId = 1,
    CombatRoomsTotal   = 0,
    CombatRoomsCleared = 0,
    EliteRoomsCleared  = 0,
    EnemyModels  = {},  -- { [roomId] = { models... } }
    ShopStocks   = {},  -- { [roomId] = { stock... } }
    LootChoices  = {},  -- { [roomId] = { {ItemName, Item}... } }
    LootClaimed  = {},  -- { [roomId] = { [player] = true } }
    ShrineStocks = {},  -- { [roomId] = { upgrade options } }
    ShrineClaimed = {}, -- { [roomId] = { [player] = true } }
}

-- Per-player run state
local PlayerRun = {}  -- [player] = { ArchetypeName, Floor, CurrentRoomId, ... }

-- ────────────────────────────────────────────────
-- HELPERS
-- ────────────────────────────────────────────────

-- Initialise a player's combat state then layer on any meta passives they've unlocked.
local function initPlayerWithMeta(player, archetypeName, level)
    CombatSystem.InitPlayer(player, archetypeName, level)
    local state = CombatSystem.GetPlayerState(player)
    if state then
        MetaProgression.ApplyPassiveBonuses(player, state.Stats)
        -- If starting-gold bonus was applied, seed the run gold
        if state.Stats._StartingGold and state.Stats._StartingGold > 0 then
            state.Gold = (state.Gold or 0) + state.Stats._StartingGold
            state.Stats._StartingGold = 0
        end
    end
end

-- ────────────────────────────────────────────────
-- LOBBY / ARCHETYPE SELECTION
-- ────────────────────────────────────────────────

local function broadcastAll(data)
    for _, player in ipairs(Players:GetPlayers()) do
        UpdateHUD:FireClient(player, data)
    end
end

local function teleportToRoom(player, roomId)
    local roomFolder = GameState.FloorFolder
    if not roomFolder then return end
    local target = roomFolder:FindFirstChild("Room_" .. roomId .. "_" .. getRoomType(roomId))
    if not target then
        -- Fallback: search by prefix
        for _, child in ipairs(roomFolder:GetChildren()) do
            if child.Name:find("Room_" .. roomId .. "_") then
                target = child
                break
            end
        end
    end
    if not target then return end
    local spawn = target:FindFirstChild("SpawnPoint")
    if not spawn then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
    end
end

function getRoomType(roomId)
    if not GameState.RoomGraph then return "Unknown" end
    for _, room in ipairs(GameState.RoomGraph) do
        if room.Id == roomId then return room.Type end
    end
    return "Unknown"
end

-- ────────────────────────────────────────────────
-- FLOOR INITIALIZATION
-- ────────────────────────────────────────────────

local function countCombatRooms(graph)
    local count = 0
    for _, room in ipairs(graph) do
        if room.Type == RoomData.RoomTypes.Combat
        or room.Type == RoomData.RoomTypes.Elite
        or room.Type == RoomData.RoomTypes.Ambush then
            count = count + 1
        end
    end
    return count
end

local function getRoomData(roomId)
    if not GameState.RoomGraph then return nil end
    for _, r in ipairs(GameState.RoomGraph) do
        if r.Id == roomId then return r end
    end
    return nil
end

local function spawnEnemiesForRoom(room, floorFolder, floor, theme)
    local cfg = RoomData.EnemyCount[room.Type]
    if not cfg then return {} end

    local models = {}
    local count = 0

    -- Use the spacing the generator exported (attribute on floorFolder) or default 20
    local spacing = (GameState.FloorFolder and GameState.FloorFolder:GetAttribute("RoomSpacing")) or 20
    local cx = room.Position.X * spacing
    local cz = room.Position.Y * spacing

    if cfg.IsBoss then
        local bossName = theme.BossEnemy
        local spawnPos = Vector3.new(cx, 3, cz)
        -- Pass room.Type so SpawnEnemy knows not to roll a modifier on bosses
        local model, uid = EnemyAI.SpawnEnemy(bossName, spawnPos, floor, floorFolder, room.Type)
        table.insert(models, { Model = model, Id = uid, IsBoss = true })
        count = 1
    else
        count = math.random(cfg.Min, cfg.Max)
        for i = 1, count do
            local enemyPool = theme.EnemyTypes
            local enemyName = enemyPool[math.random(#enemyPool)]
            if cfg.EliteCount and i == 1 then
                enemyName = enemyPool[#enemyPool]
            end
            -- Keep offsets small so enemies stay inside the room (rooms are 20 studs)
            local offset = Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))
            local spawnPos = Vector3.new(cx, 3, cz) + offset
            local model, uid = EnemyAI.SpawnEnemy(enemyName, spawnPos, floor, floorFolder, room.Type)
            table.insert(models, { Model = model, Id = uid })
        end
    end

    return models
end

-- ────────────────────────────────────────────────
-- SHRINE OPTIONS
-- ────────────────────────────────────────────────

local SHRINE_UPGRADES = {
    {
        Id          = "BonusHP",
        Name        = "Vitality Blessing",
        Description = "Permanently increase Max HP by 12%.",
        Cost        = 80,
        Apply = function(state)
            local newMax = math.floor(state.Stats.MaxHP * 1.12)
            state.Stats.MaxHP = newMax
            state.HP = math.min(state.HP + math.floor(newMax * 0.12), newMax)
        end,
    },
    {
        Id          = "BonusAtk",
        Name        = "Warrior's Edge",
        Description = "Permanently increase Attack by 8.",
        Cost        = 80,
        Apply = function(state)
            state.Stats.Atk = state.Stats.Atk + 8
        end,
    },
    {
        Id          = "BonusDef",
        Name        = "Iron Shell",
        Description = "Permanently increase Defense by 6.",
        Cost        = 60,
        Apply = function(state)
            state.Stats.Def = state.Stats.Def + 6
        end,
    },
    {
        Id          = "BonusMP",
        Name        = "Haki Expansion",
        Description = "Permanently increase Max Haki by 30 and restore 30 Haki now.",
        Cost        = 70,
        Apply = function(state)
            state.Stats.MaxMP = state.Stats.MaxMP + 30
            state.MP = math.min(state.MP + 30, state.Stats.MaxMP)
        end,
    },
    {
        Id          = "CritBoost",
        Name        = "Killer Instinct",
        Description = "Permanently increase critical hit chance by 5%.",
        Cost        = 100,
        Apply = function(state)
            state.Stats.CritChance = (state.Stats.CritChance or 0.05) + 0.05
        end,
    },
    {
        Id          = "FullRestore",
        Name        = "Ancient Blessing",
        Description = "Fully restore HP and Haki right now.",
        Cost        = 120,
        Apply = function(state)
            state.HP = state.Stats.MaxHP
            state.MP = state.Stats.MaxMP
        end,
    },
}

local function generateShrineOptions(floor)
    -- Pick 3 distinct upgrades; later floors can afford slightly different costs
    local pool = {}
    for _, u in ipairs(SHRINE_UPGRADES) do
        table.insert(pool, u)
    end
    -- Shuffle
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local opts = {}
    for i = 1, math.min(3, #pool) do
        local u = pool[i]
        -- Scale cost with floor depth
        local scaledCost = math.floor(u.Cost * (1 + (floor - 1) * 0.08))
        opts[i] = { Id = u.Id, Name = u.Name, Description = u.Description, Cost = scaledCost }
    end
    return opts
end

local function initFloor(floor)
    -- Clean up previous floor
    if GameState.FloorFolder then
        DungeonGenerator.DestroyFloor(GameState.FloorFolder)
    end
    GameState.EnemyModels = {}
    GameState.ShopStocks  = {}

    -- Generate new floor
    local folder, graph, theme = DungeonGenerator.GenerateFloor(floor, workspace)
    GameState.FloorFolder  = folder
    GameState.RoomGraph    = graph
    GameState.Theme        = theme
    GameState.CurrentFloor = floor
    GameState.ActiveRoomId = 1
    GameState.CombatRoomsTotal   = countCombatRooms(graph)
    GameState.CombatRoomsCleared = 0
    GameState.EliteRoomsCleared  = 0

    -- Reset per-floor loot/shrine state
    GameState.LootChoices  = {}
    GameState.LootClaimed  = {}
    GameState.ShrineStocks = {}
    GameState.ShrineClaimed = {}

    -- Spawn enemies and generate shop/shrine stocks for relevant rooms
    for _, room in ipairs(graph) do
        if room.Type == RoomData.RoomTypes.Combat
        or room.Type == RoomData.RoomTypes.Elite
        or room.Type == RoomData.RoomTypes.Boss
        or room.Type == RoomData.RoomTypes.Ambush then
            GameState.EnemyModels[room.Id] = spawnEnemiesForRoom(room, folder, floor, theme)
        end
        if room.Type == RoomData.RoomTypes.Shop then
            GameState.ShopStocks[room.Id] = LootSystem.GenerateShopStock(floor)
        end
        if room.Type == RoomData.RoomTypes.Shrine then
            GameState.ShrineStocks[room.Id] = generateShrineOptions(floor)
        end
    end

    -- Notify all clients
    broadcastAll({
        FloorStart = true,
        Floor = floor,
        ThemeName = theme.Name,
        ThemeDescription = theme.Description,
        RoomCount = #graph,
    })

    print(("[GameManager] Floor %d initialized — %d rooms, theme: %s"):format(floor, #graph, theme.Name))
end

-- ────────────────────────────────────────────────
-- ROOM INTERACTION
-- ────────────────────────────────────────────────

local function handleRoomEnter(player, roomId)
    local run = PlayerRun[player]
    if not run then return end
    run.CurrentRoomId = roomId

    local room = getRoomData(roomId)
    if not room then return end

    if room.Type == RoomData.RoomTypes.Rest then
        -- Apply rest healing
        local state = CombatSystem.GetPlayerState(player)
        if state then
            local cfg = RoomData.RestConfig
            state.HP = math.min(state.HP + math.floor(state.Stats.MaxHP * cfg.HPRestore), state.Stats.MaxHP)
            state.MP = math.min(state.MP + math.floor(state.Stats.MaxMP * cfg.MPRestore), state.Stats.MaxMP)
            UpdateHUD:FireClient(player, {
                HP = state.HP, MaxHP = state.Stats.MaxHP,
                MP = state.MP, MaxMP = state.Stats.MaxMP,
                RestRoom = true,
            })
        end

    elseif room.Type == RoomData.RoomTypes.Shop then
        local stock = GameState.ShopStocks[roomId]
        UpdateHUD:FireClient(player, { ShopOpen = true, Stock = stock, RoomId = roomId })

    elseif room.Type == RoomData.RoomTypes.Event then
        local events = RoomData.Events
        local evt = events[math.random(#events)]

        -- Auto-resolve ability-granting events
        local grantedAbility = nil
        if evt.Id == "SpiritFragment" or evt.Id == "AncientScroll" then
            local CharacterStats = require(ReplicatedStorage.Modules.CharacterStats)
            local run2 = PlayerRun[player]
            local arch = run2 and CharacterStats.Archetypes[run2.ArchetypeName]
            if arch and arch.AbilityPool then
                -- Find abilities in the pool the player doesn't know yet
                local candidates = {}
                for _, abilityName in ipairs(arch.AbilityPool) do
                    if not CombatSystem.KnowsAbility(player, abilityName) then
                        table.insert(candidates, abilityName)
                    end
                end
                if #candidates > 0 then
                    local pick = candidates[math.random(#candidates)]
                    if CombatSystem.GrantAbility(player, pick) then
                        grantedAbility = pick
                    end
                end
            end
        end

        UpdateHUD:FireClient(player, {
            EventOpen      = true,
            Event          = evt,
            GrantedAbility = grantedAbility,
            Message        = grantedAbility and ("Learned: " .. grantedAbility) or nil,
            Duration       = grantedAbility and 3 or nil,
        })

    elseif room.Type == RoomData.RoomTypes.Shrine then
        local stock = GameState.ShrineStocks[roomId]
        if not stock then
            stock = generateShrineOptions(GameState.CurrentFloor)
            GameState.ShrineStocks[roomId] = stock
        end
        local alreadyChosen = GameState.ShrineClaimed[roomId]
            and GameState.ShrineClaimed[roomId][player]
        ShrineOpenEvt:FireClient(player, {
            Options       = stock,
            RoomId        = roomId,
            AlreadyChosen = alreadyChosen or false,
        })

    elseif room.Type == RoomData.RoomTypes.Exit then
        -- Check if boss is cleared
        local bossCleared = true
        for _, room2 in ipairs(GameState.RoomGraph) do
            if room2.Type == RoomData.RoomTypes.Boss and not room2.Cleared then
                bossCleared = false
                break
            end
        end
        if bossCleared then
            -- Advance to next floor
            local nextFloor = GameState.CurrentFloor + 1
            run.Floor = nextFloor
            task.wait(2)
            initFloor(nextFloor)
            initPlayerWithMeta(player, run.ArchetypeName, CombatSystem.GetPlayerState(player) and CombatSystem.GetPlayerState(player).Stats.Level or nextFloor)
            teleportToRoom(player, 1)
        else
            UpdateHUD:FireClient(player, { Message = "Defeat the boss to advance!", Duration = 3 })
        end
    end
end

-- ────────────────────────────────────────────────
-- ENEMY DEATH HANDLING
-- ────────────────────────────────────────────────

local function onEnemyDied(enemyModel, killerPlayer)
    local xp         = enemyModel:GetAttribute("XP") or 0
    local lootTable  = enemyModel:GetAttribute("LootTable") or "Common"
    local enemyPos   = (enemyModel.PrimaryPart or enemyModel:FindFirstChildWhichIsA("Part")).Position

    -- Award XP
    if killerPlayer then
        CombatSystem.GiveXP(killerPlayer, xp)
    end

    -- ── Explosive modifier: AOE blast on death ───────────────────────────────
    local modifier = enemyModel:GetAttribute("Modifier")
    if modifier == "Explosive" then
        local BLAST_RADIUS = 12
        local blastDmg     = 40 + GameState.CurrentFloor * 3

        -- Warn all clients so they can dodge / see the explosion coming
        EnemyAttackEvt:FireAllClients({
            AttackType = "Explosion",
            Position   = enemyPos,
            Radius     = BLAST_RADIUS,
            Delay      = 0.30,
        })

        -- Apply damage after the brief telegraph window
        task.delay(0.30, function()
            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - enemyPos).Magnitude <= BLAST_RADIUS then
                    CombatSystem.DamagePlayer(p, blastDmg, "Fire")
                end
            end
        end)
    end

    -- ── Kamikaze Imp: instant death explosion ────────────────────────────────
    if enemyModel:GetAttribute("EnemyType") == "Kamikaze_Imp" then
        local bombRadius = 10
        local bombDmg    = math.floor(30 * (1 + (GameState.CurrentFloor - 1) * 0.10))
        EnemyAttackEvt:FireAllClients({
            AttackType = "Explosion",
            Position   = enemyPos,
            Radius     = bombRadius,
            Delay      = 0.15,   -- faster than Explosive modifier
        })
        task.delay(0.15, function()
            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root and (root.Position - enemyPos).Magnitude <= bombRadius then
                    CombatSystem.DamagePlayer(p, bombDmg, "Fire")
                end
            end
        end)
    end

    -- Drop loot
    LootSystem.DropLoot(lootTable, enemyPos, GameState.CurrentFloor)

    -- Find which room this enemy belonged to and check if room is now clear
    for roomId, models in pairs(GameState.EnemyModels) do
        for i, entry in ipairs(models) do
            if entry.Model == enemyModel then
                table.remove(models, i)
                -- Check room cleared
                if #models == 0 then
                    local room = getRoomData(roomId)
                    if room then

                        -- Ambush: wave 2 triggers after wave 1 is cleared
                        if room.Type == RoomData.RoomTypes.Ambush and not room.Wave2Spawned then
                            room.Wave2Spawned = true
                            broadcastAll({ Message = "Second wave incoming!", Duration = 2 })
                            task.delay(1.5, function()
                                local wave2 = spawnEnemiesForRoom(room, GameState.FloorFolder, GameState.CurrentFloor, GameState.Theme)
                                -- Wave 2 enemies are elites with forced modifier
                                for _, entry in ipairs(wave2) do
                                    if entry.Model then
                                        entry.Model:SetAttribute("Modifier", "Berserker")
                                    end
                                    table.insert(GameState.EnemyModels[roomId], entry)
                                end
                            end)
                            break  -- don't clear the room yet; wait for wave 2
                        end

                        room.Cleared = true
                        if room.Type == RoomData.RoomTypes.Combat
                        or room.Type == RoomData.RoomTypes.Elite
                        or room.Type == RoomData.RoomTypes.Ambush then
                            GameState.CombatRoomsCleared = GameState.CombatRoomsCleared + 1
                        end
                        if room.Type == RoomData.RoomTypes.Elite then
                            GameState.EliteRoomsCleared = GameState.EliteRoomsCleared + 1
                        end
                        if room.Type == RoomData.RoomTypes.Boss then
                            -- Spawn exit room marker
                            broadcastAll({ BossDefeated = true, BossName = room.BossName })
                            FloorComplete:FireAllClients({ Floor = GameState.CurrentFloor })
                            -- Award mastery points for the floor
                            for _, p in ipairs(Players:GetPlayers()) do
                                MetaProgression.AwardRunPoints(p, GameState.CurrentFloor, true, GameState.EliteRoomsCleared)
                            end
                        end
                        RoomCleared:FireAllClients({
                            RoomId    = roomId,
                            RoomType  = room.Type,
                            Cleared   = GameState.CombatRoomsCleared,
                            Total     = GameState.CombatRoomsTotal,
                        })

                        -- Elite / Boss room: offer each player a pick-1-of-3 reward
                        if room.Type == RoomData.RoomTypes.Elite
                        or room.Type == RoomData.RoomTypes.Boss then
                            local lootTable = (room.Type == RoomData.RoomTypes.Boss) and "Boss" or "Rare"
                            local choices = LootSystem.GenerateLootChoices(lootTable, GameState.CurrentFloor, 3)
                            GameState.LootChoices[roomId] = choices
                            GameState.LootClaimed[roomId] = {}
                            task.wait(0.6)  -- let death VFX breathe
                            LootChoiceEvt:FireAllClients({
                                Choices  = choices,
                                RoomId   = roomId,
                                RoomType = room.Type,
                            })
                        end

                        -- Ambush room: guaranteed Rare reward on clear
                        if room.Type == RoomData.RoomTypes.Ambush then
                            local choices = LootSystem.GenerateLootChoices("Rare", GameState.CurrentFloor, 3)
                            GameState.LootChoices[roomId] = choices
                            GameState.LootClaimed[roomId] = {}
                            task.wait(0.6)
                            LootChoiceEvt:FireAllClients({
                                Choices  = choices,
                                RoomId   = roomId,
                                RoomType = room.Type,
                            })
                        end

                        -- Unlock boss door if all combat rooms cleared
                        if GameState.CombatRoomsCleared >= GameState.CombatRoomsTotal then
                            for _, r in ipairs(GameState.RoomGraph) do
                                if r.Type == RoomData.RoomTypes.Boss then
                                    r.Locked = false
                                end
                            end
                            -- Destroy the boss door barrier
                            if GameState.FloorFolder then
                                for _, child in ipairs(GameState.FloorFolder:GetDescendants()) do
                                    if child.Name == "BossDoor" then
                                        child:Destroy()
                                    end
                                end
                            end
                            broadcastAll({ BossUnlocked = true, Message = "The boss chamber has opened!" })
                        end
                    end
                end
                break
            end
        end
    end
end

-- Watch for enemy HP reaching 0
-- We poll via a DescendantAdded / attribute change pattern
workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") and obj:GetAttribute("IsEnemy") then
        obj:GetAttributeChangedSignal("HP"):Connect(function()
            local hp = obj:GetAttribute("HP") or 0
            if hp <= 0 then
                -- Find nearest killer (closest player who attacked recently — simplified: just pick nearest)
                local killer = nil
                local minDist = 60
                if obj.PrimaryPart or obj:FindFirstChildWhichIsA("Part") then
                    local pos = (obj.PrimaryPart or obj:FindFirstChildWhichIsA("Part")).Position
                    for _, p in ipairs(Players:GetPlayers()) do
                        local char = p.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        if root then
                            local d = (root.Position - pos).Magnitude
                            if d < minDist then minDist = d; killer = p end
                        end
                    end
                end
                onEnemyDied(obj, killer)
            end
        end)
    end
end)

-- ────────────────────────────────────────────────
-- PLAYER DEATH
-- ────────────────────────────────────────────────

PlayerDied.OnServerEvent:Connect(function(player)
    local run = PlayerRun[player]
    -- Ignore death if player hasn't picked an archetype yet (still in lobby)
    if not run or not run.ArchetypeChosen then return end

    local state = CombatSystem.GetPlayerState(player)
    if not state then return end

    -- Check for phoenix scroll auto-revive
    local inv = LootSystem.GetInventory(player)
    if inv["ReviveScroll"] and inv["ReviveScroll"] > 0 then
        local effect = LootSystem.UseConsumable(player, "ReviveScroll")
        if effect then
            state.HP = math.floor(state.Stats.MaxHP * effect.HPPercent)
            UpdateHUD:FireClient(player, {
                HP = state.HP, MaxHP = state.Stats.MaxHP,
                MP = state.MP, MaxMP = state.Stats.MaxMP,
                Revived = true,
            })
            return
        end
    end

    -- Award mastery points for progress so far (no boss kill credit)
    MetaProgression.AwardRunPoints(player, GameState.CurrentFloor, false, GameState.EliteRoomsCleared)

    -- True death — reset run
    UpdateHUD:FireClient(player, { GameOver = true, Floor = GameState.CurrentFloor })
    local run = PlayerRun[player]
    if run then
        run.Floor           = 1
        run.ArchetypeChosen = false  -- go back to archetype screen on next spawn
    end
    -- Roblox will respawn the character; CharacterAdded will show the archetype screen again.
end)

-- ────────────────────────────────────────────────
-- PLAYER JOIN / ARCHETYPE SELECTION
-- ────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    PlayerRun[player] = {
        ArchetypeName = "Swordsman",
        Floor = 1,
        CurrentRoomId = 1,
        ArchetypeChosen = false,
    }

    player.CharacterAdded:Connect(function(character)
        task.wait(0.5)  -- let character settle on lobby platform
        local run = PlayerRun[player]
        if not run then return end

        local humanoid = character:WaitForChild("Humanoid", 5)

        if run.ArchetypeChosen then
            -- Player already picked an archetype — this is a respawn after death.
            -- Restore normal health and teleport back to floor 1 room 1.
            if humanoid then
                humanoid.MaxHealth = 100
                humanoid.Health    = 100
            end
            initPlayerWithMeta(player, run.ArchetypeName, run.Floor or 1)
            task.wait(0.2)
            teleportToRoom(player, 1)
        else
            -- First spawn — protect with infinite health until archetype selected.
            if humanoid then
                humanoid.MaxHealth = math.huge
                humanoid.Health    = math.huge
                -- Re-apply protection if Roblox ever resets health (e.g. fall into void)
                humanoid.HealthChanged:Connect(function(hp)
                    if not run.ArchetypeChosen and hp < math.huge then
                        humanoid.Health = math.huge
                    end
                end)
            end
            initPlayerWithMeta(player, run.ArchetypeName, 1)
            -- Show archetype screen; dungeon starts only after selection
            UpdateHUD:FireClient(player, { ShowArchetypeScreen = true })
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    PlayerRun[player] = nil
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Archetype selection
-- ────────────────────────────────────────────────

-- Listen for archetype selection via a RemoteFunction (add to project.json RemoteEvents)
local archetypeEvt = Instance.new("RemoteEvent")
archetypeEvt.Name = "SelectArchetype"
archetypeEvt.Parent = RemoteEvents

archetypeEvt.OnServerEvent:Connect(function(player, archetypeName)
    local CharacterStats = require(ReplicatedStorage.Modules.CharacterStats)
    if not CharacterStats.Archetypes[archetypeName] then return end
    local run = PlayerRun[player]
    if not run or run.ArchetypeChosen then return end
    run.ArchetypeName    = archetypeName
    run.ArchetypeChosen  = true

    -- Restore normal health now that player is entering the dungeon
    local char = player.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.MaxHealth = 100
        humanoid.Health    = 100
    end

    initPlayerWithMeta(player, archetypeName, 1)
    UpdateHUD:FireClient(player, { ArchetypeSelected = true, Archetype = archetypeName })

    -- Generate floor 1 (or reuse if already done)
    if GameState.Phase == "Lobby" or GameState.Phase == "ArchetypeSelect" then
        GameState.Phase = "Running"
        initFloor(1)
    end

    teleportToRoom(player, 1)
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Room door touched (notify enter)
-- ────────────────────────────────────────────────

local roomEnterEvt = Instance.new("RemoteEvent")
roomEnterEvt.Name = "EnterRoom"
roomEnterEvt.Parent = RemoteEvents

roomEnterEvt.OnServerEvent:Connect(function(player, roomId)
    handleRoomEnter(player, roomId)
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Use consumable
-- ────────────────────────────────────────────────

local useItemEvt = Instance.new("RemoteEvent")
useItemEvt.Name = "UseItem"
useItemEvt.Parent = RemoteEvents

useItemEvt.OnServerEvent:Connect(function(player, itemName)
    local effect = LootSystem.UseConsumable(player, itemName)
    if not effect then return end
    local state = CombatSystem.GetPlayerState(player)
    if not state then return end

    if effect.Type == "Heal" then
        state.HP = math.min(state.HP + effect.Amount, state.Stats.MaxHP)
    elseif effect.Type == "RestoreMP" then
        state.MP = math.min(state.MP + effect.Amount, state.Stats.MaxMP)
    elseif effect.Type == "FullHeal" then
        state.HP = state.Stats.MaxHP
        state.MP = state.Stats.MaxMP
    elseif effect.Type == "Buff" then
        state.Buffs[effect.Buff] = { Duration = effect.Duration, Data = effect }
    end

    UpdateHUD:FireClient(player, { HP = state.HP, MaxHP = state.Stats.MaxHP, MP = state.MP, MaxMP = state.Stats.MaxMP })
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Buy from shop
-- ────────────────────────────────────────────────

local buyItemEvt = Instance.new("RemoteEvent")
buyItemEvt.Name = "BuyItem"
buyItemEvt.Parent = RemoteEvents

buyItemEvt.OnServerEvent:Connect(function(player, itemName, roomId)
    local state = CombatSystem.GetPlayerState(player)
    if not state then return end

    local stock = GameState.ShopStocks[roomId]
    if not stock then return end

    local price = nil
    for _, entry in ipairs(stock) do
        if entry.ItemName == itemName then
            price = entry.Price
            break
        end
    end
    if not price then return end

    local success, newGold = LootSystem.BuyItem(player, itemName, price, state.Gold or 0)
    if success then
        state.Gold = newGold
        UpdateHUD:FireClient(player, { Gold = state.Gold })
    else
        UpdateHUD:FireClient(player, { ShopError = true, Message = newGold })
    end
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Pick loot reward (Elite / Boss room clear)
-- ────────────────────────────────────────────────

local pickLootEvt = RemoteEvents:WaitForChild("PickLoot")
pickLootEvt.OnServerEvent:Connect(function(player, itemName, roomId)
    local choices = GameState.LootChoices[roomId]
    if not choices then return end
    if not GameState.LootClaimed[roomId] then GameState.LootClaimed[roomId] = {} end
    if GameState.LootClaimed[roomId][player] then return end  -- already claimed

    -- Verify the item is one of the valid choices
    local valid = false
    for _, c in ipairs(choices) do
        if c.ItemName == itemName then valid = true; break end
    end
    if not valid then return end

    GameState.LootClaimed[roomId][player] = true
    LootSystem.GiveItemToPlayer(player, itemName)
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Pick shrine upgrade
-- ────────────────────────────────────────────────

local pickShrineEvt = RemoteEvents:WaitForChild("PickShrine")
pickShrineEvt.OnServerEvent:Connect(function(player, upgradeId, roomId)
    if not GameState.ShrineClaimed[roomId] then GameState.ShrineClaimed[roomId] = {} end
    if GameState.ShrineClaimed[roomId][player] then return end  -- already used shrine

    local options = GameState.ShrineStocks[roomId]
    if not options then return end

    -- Find the chosen option
    local chosen = nil
    for _, opt in ipairs(options) do
        if opt.Id == upgradeId then chosen = opt; break end
    end
    if not chosen then return end

    -- Deduct gold
    local state = CombatSystem.GetPlayerState(player)
    if not state then return end
    if (state.Gold or 0) < chosen.Cost then
        UpdateHUD:FireClient(player, { Message = "Not enough Bounty!", Duration = 2 })
        return
    end
    state.Gold = state.Gold - chosen.Cost

    -- Apply the upgrade
    for _, u in ipairs(SHRINE_UPGRADES) do
        if u.Id == upgradeId then
            u.Apply(state)
            break
        end
    end

    GameState.ShrineClaimed[roomId][player] = true

    UpdateHUD:FireClient(player, {
        HP    = state.HP,   MaxHP = state.Stats.MaxHP,
        MP    = state.MP,   MaxMP = state.Stats.MaxMP,
        Gold  = state.Gold,
        Message  = "Blessing granted: " .. chosen.Name,
        Duration = 3,
    })
end)

print("[GameManager] Loaded and ready.")
