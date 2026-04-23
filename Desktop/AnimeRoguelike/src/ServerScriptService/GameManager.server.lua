-- GameManager.server.lua
-- Orchestrates the full game loop: lobby → archetype select → dungeon floors → death/win.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local DungeonGenerator    = require(script.Parent.DungeonGenerator)
local EnemyAI             = require(script.Parent.EnemyAI)
local LootSystem          = require(script.Parent.LootSystem)
local CombatSystem        = require(script.Parent.CombatSystem)
local MetaProgression     = require(script.Parent.MetaProgression)
local DynamicEventManager   = require(script.Parent.DynamicEventManager)
local GamblingSystem        = require(script.Parent.GamblingSystem)
local LeaderboardSystem     = require(script.Parent.LeaderboardSystem)
local SeasonalEventManager  = require(script.Parent.SeasonalEventManager)
local ChallengeTracker      = require(script.Parent.ChallengeTracker)
local StartingBonusData     = require(ReplicatedStorage.Modules.StartingBonusData)
local ChallengeData         = require(ReplicatedStorage.Modules.ChallengeData)
ChallengeTracker.SetMetaProgression(MetaProgression)
local RoomData              = require(ReplicatedStorage.Modules.RoomData)
local EnemyData           = require(ReplicatedStorage.Modules.EnemyData)
local LoreData            = require(ReplicatedStorage.Modules.LoreData)
local DungeonMechanics    = require(ReplicatedStorage.Modules.DungeonMechanics)
local CurseData           = require(ReplicatedStorage.Modules.CurseData)
local BountyData          = require(ReplicatedStorage.Modules.BountyData)

local RemoteEvents     = ReplicatedStorage:WaitForChild("RemoteEvents")
local UpdateHUD        = RemoteEvents:WaitForChild("UpdateHUD")
local RoomCleared      = RemoteEvents:WaitForChild("RoomCleared")
local FloorComplete    = RemoteEvents:WaitForChild("FloorComplete")
local PlayerDied       = RemoteEvents:WaitForChild("PlayerDied")
local LootDropEvt      = RemoteEvents:WaitForChild("LootDrop")
local EnemyAttackEvt   = RemoteEvents:WaitForChild("EnemyAttack")
local LootChoiceEvt    = RemoteEvents:WaitForChild("LootChoice")
local BossPhaseEvt      = RemoteEvents:WaitForChild("BossPhase")
local ShrineOpenEvt     = RemoteEvents:WaitForChild("ShrineOpen")
local SelectBonusEvt    = RemoteEvents:WaitForChild("SelectBonus",    15)
local WeeklyModifierEvt = RemoteEvents:WaitForChild("WeeklyModifier", 15)

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
    -- Curse room state (per room, like shrines)
    CurseOptions  = {}, -- { [roomId] = { curse option array } }
    CurseClaimed  = {}, -- { [roomId] = { [player] = true } }
}

-- Per-player run state
local PlayerRun = {}  -- [player] = { ArchetypeName, OriginId, Floor, CurrentRoomId, ActiveCurseId, ... }

-- ── Bounty event helper: forward game events to MetaProgression.TrackBountyEvent ──
local function fireBountyEvent(player, eventName, data)
    MetaProgression.TrackBountyEvent(player, eventName, data or {})
end

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
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local roomFolder = GameState.FloorFolder
    if roomFolder then
        local prefix = "Room_" .. roomId .. "_"
        local target
        for _, child in ipairs(roomFolder:GetChildren()) do
            if child.Name:sub(1, #prefix) == prefix then
                target = child
                break
            end
        end
        if target then
            local spawn = target:FindFirstChild("SpawnPoint")
            if spawn then
                root.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
                return
            end
        end
    end
    -- Hard fallback: dungeon world offset (Room 1 entrance, safe height)
    root.CFrame = CFrame.new(10000, 108, 42)
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

    -- Use the spacing and world offset the generator exported
    local spacing = (GameState.FloorFolder and GameState.FloorFolder:GetAttribute("RoomSpacing")) or 20
    local offX    = (GameState.FloorFolder and GameState.FloorFolder:GetAttribute("WorldOffsetX")) or 0
    local offY    = (GameState.FloorFolder and GameState.FloorFolder:GetAttribute("WorldOffsetY")) or 0
    local offZ    = (GameState.FloorFolder and GameState.FloorFolder:GetAttribute("WorldOffsetZ")) or 0
    local cx = room.Position.X * spacing + offX
    local cz = room.Position.Y * spacing + offZ

    if cfg.IsBoss then
        local bossName = theme.BossEnemy
        local spawnPos = Vector3.new(cx, offY + 3, cz)
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
            -- Cluster enemies near room center so melee abilities reach them (±15 studs)
            local offset = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
            local spawnPos = Vector3.new(cx, offY + 3, cz) + offset
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

local function initFloor(floor, themeIndex)
    -- Clean up previous floor
    if GameState.FloorFolder then
        DungeonGenerator.DestroyFloor(GameState.FloorFolder)
    end
    GameState.EnemyModels = {}
    GameState.ShopStocks  = {}

    -- Generate new floor (themeIndex overrides the default floor→theme cycling)
    local folder, graph, theme = DungeonGenerator.GenerateFloor(floor, workspace, themeIndex)
    GameState.FloorFolder  = folder
    GameState.RoomGraph    = graph
    GameState.Theme        = theme
    GameState.CurrentFloor = floor
    GameState.ActiveRoomId = 1
    GameState.CombatRoomsTotal   = countCombatRooms(graph)
    GameState.CombatRoomsCleared = 0
    GameState.EliteRoomsCleared  = 0

    -- Reset per-floor loot/shrine/curse state
    GameState.LootChoices  = {}
    GameState.LootClaimed  = {}
    GameState.ShrineStocks = {}
    GameState.ShrineClaimed = {}
    GameState.CurseOptions  = {}
    GameState.CurseClaimed  = {}

    -- Grab lore + mechanic data for this floor
    local shardLore = LoreData.GetShardLore(floor)
    local mechanic  = DungeonMechanics.GetMechanic(floor)

    -- Spawn enemies and generate shop/shrine/curse stocks for relevant rooms
    for _, room in ipairs(graph) do
        local isCombat = room.Type == RoomData.RoomTypes.Combat
            or room.Type == RoomData.RoomTypes.Elite
            or room.Type == RoomData.RoomTypes.Boss
            or room.Type == RoomData.RoomTypes.Ambush
        if isCombat then
            GameState.EnemyModels[room.Id] = spawnEnemiesForRoom(room, folder, floor, theme)
        end
        -- Also spawn a couple of enemies in the Entrance room so players see action immediately
        if room.Type == RoomData.RoomTypes.Entrance then
            local welcomeRoom = { Id = room.Id, Position = room.Position,
                Type = RoomData.RoomTypes.Combat }
            GameState.EnemyModels[room.Id] = spawnEnemiesForRoom(welcomeRoom, folder, floor, theme)
        end
        if room.Type == RoomData.RoomTypes.Shop then
            GameState.ShopStocks[room.Id] = LootSystem.GenerateShopStock(floor)
        end
        if room.Type == RoomData.RoomTypes.Shrine then
            GameState.ShrineStocks[room.Id] = generateShrineOptions(floor)
        end
        if room.Type == RoomData.RoomTypes.SealedChamber then
            GameState.CurseOptions[room.Id] = CurseData.GenerateOptions()
        end
    end

    -- Notify all clients — now includes lore + mechanic context
    local themeCount = 5  -- number of dungeon themes (cycles every 5 floors)
    broadcastAll({
        FloorStart        = true,
        Floor             = floor,
        ThemeName         = theme.Name,
        ThemeIndex        = ((floor - 1) % themeCount) + 1,
        ShardName         = (shardLore and shardLore.ShardName) or theme.Name,
        EntryFlavor       = (shardLore and shardLore.EntryFlavor) or theme.Description,
        ThemeDescription  = theme.Description,
        RoomCount         = #graph,
        -- Dungeon mechanic info
        MechanicName      = (mechanic and mechanic.Name) or nil,
        MechanicShortDesc = (mechanic and mechanic.ShortDesc) or nil,
        MechanicFullDesc  = (mechanic and mechanic.FullDesc) or nil,
        MechanicHUDLabel  = (mechanic and mechanic.HUDLabel) or nil,
        MechanicHUDColor  = (mechanic and mechanic.HUDColor) or nil,
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

    -- ── Fire room-entry lore flavor line to the entering player ─────────
    local flavorLine = DungeonMechanics.GetRoomEntryLine(GameState.CurrentFloor, room.Type)
    if flavorLine then
        UpdateHUD:FireClient(player, { FlavorLine = flavorLine, Duration = 4 })
    end

    -- ── Dynamic event roll (Combat / Elite / Ambush rooms only) ─────────
    if room.Type == RoomData.RoomTypes.Combat
    or room.Type == RoomData.RoomTypes.Elite
    or room.Type == RoomData.RoomTypes.Ambush then
        DynamicEventManager.OnRoomEnter(
            Players:GetPlayers(), room.Type, roomId, GameState.CurrentFloor, CombatSystem)
    end

    -- ── Gamble room: show options if this is a special gamble room ───────
    if room.Type == "Gamble" then
        GamblingSystem.ShowOptions(player)
    end

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

    elseif room.Type == RoomData.RoomTypes.SealedChamber then
        -- Offer the player a curse (risk-reward)
        local options = GameState.CurseOptions[roomId]
        if not options then
            options = CurseData.GenerateOptions()
            GameState.CurseOptions[roomId] = options
        end
        local alreadyChosen = GameState.CurseClaimed[roomId]
            and GameState.CurseClaimed[roomId][player]
        -- Send curse options to client
        UpdateHUD:FireClient(player, {
            SealedChamberOpen = true,
            Options           = options,
            RoomId            = roomId,
            AlreadyChosen     = alreadyChosen or false,
            DoorText          = CurseData.SealedChamberConfig.DoorText,
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
            fireBountyEvent(player, "FloorReached", { Floor = nextFloor })
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
        -- Track enemy kill for bounties
        fireBountyEvent(killerPlayer, "EnemyKilled", { Floor = GameState.CurrentFloor })
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
                            -- Get boss defeat dialogue from LoreData
                            local bossKey    = GameState.Theme and GameState.Theme.BossKey
                            local defeatLine = bossKey and LoreData.GetDialogueLine(bossKey, "Defeat")
                            broadcastAll({
                                BossDefeated  = true,
                                BossName      = room.BossName or (GameState.Theme and GameState.Theme.BossEnemy),
                                BossDialogue  = defeatLine,
                                ClearFlavor   = (LoreData.GetShardLore(GameState.CurrentFloor) or {}).ClearFlavor,
                            })
                            FloorComplete:FireAllClients({ Floor = GameState.CurrentFloor })
                            -- Award mastery points for the floor
                            local masteryMult2 = SeasonalEventManager.GetMasteryMult()
                            for _, p in ipairs(Players:GetPlayers()) do
                                MetaProgression.AwardRunPoints(p, math.floor(GameState.CurrentFloor * masteryMult2), true, GameState.EliteRoomsCleared)
                                -- Fire bounty event: boss defeated
                                fireBountyEvent(p, "BossDefeated", {
                                    Floor   = GameState.CurrentFloor,
                                    BossKey = bossKey,
                                })
                                -- Challenge tracker: boss defeated
                                ChallengeTracker.TrackEvent(p, "BossDefeated", { Floor = GameState.CurrentFloor })
                                -- Leaderboard: submit run stats on boss kill
                                local cs = CombatSystem.GetPlayerState(p)
                                if cs then
                                    LeaderboardSystem.SubmitRunStats(p, {
                                        BestFloor   = GameState.CurrentFloor,
                                        TotalDamage = cs.TotalRunDamage or 0,
                                        FastestFloor3Seconds = (GameState.CurrentFloor == 3) and cs.Floor3ClearTime or nil,
                                    })
                                end
                                -- Shadow Gate achievement
                                if GameState.CurrentFloor >= 5 then
                                    MetaProgression.TrackAchievement(p, "ClearShadowGate")
                                end
                            end
                        end
                        -- Resolve active dynamic event for this room
                        DynamicEventManager.OnRoomCleared(
                            roomId, LootSystem, GameState.CurrentFloor, Players:GetPlayers())

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
                            for _, p in ipairs(Players:GetPlayers()) do
                                fireBountyEvent(p, "AmbushRoomCleared", { Floor = GameState.CurrentFloor })
                            end
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
    local masteryMult = SeasonalEventManager.GetMasteryMult()
    MetaProgression.AwardRunPoints(player, math.floor(GameState.CurrentFloor * masteryMult), false, GameState.EliteRoomsCleared)
    MetaProgression.TrackRunCompleted(player)
    -- Challenge and leaderboard: evaluate on death
    ChallengeTracker.TrackEvent(player, "PlayerDied", {})
    ChallengeTracker.EvaluateRunEnd(player)
    local cstate = CombatSystem.GetPlayerState(player)
    if cstate then
        LeaderboardSystem.SubmitRunStats(player, {
            BestFloor    = GameState.CurrentFloor,
            TotalDamage  = cstate.TotalRunDamage or 0,
        })
    end

    -- True death — reset run
    UpdateHUD:FireClient(player, { GameOver = true, Floor = GameState.CurrentFloor })
    local run = PlayerRun[player]
    if run then
        run.Floor           = 1
        run.ArchetypeChosen = false  -- go back to archetype screen on next spawn
        run.EnteredDungeon  = false  -- allow portal entry again after respawn
    end
    -- Kill the Roblox Humanoid after a short delay so the game-over screen
    -- has time to display before the character despawns and respawns.
    task.delay(2.5, function()
        if not player.Parent then return end  -- player left the game
        local char = player.Character
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum then
            hum.Health = 0  -- triggers Roblox respawn; CharacterAdded will show archetype screen
        end
    end)
end)

-- ────────────────────────────────────────────────
-- PLAYER JOIN / ARCHETYPE SELECTION
-- ────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    PlayerRun[player] = {
        ArchetypeName   = "Swordsman",
        OriginId        = nil,
        ActiveCurseId   = nil,
        Floor           = 1,
        CurrentRoomId   = 1,
        ArchetypeChosen = false,
        EnteredDungeon  = false,
        PortalDebounce  = false,
    }

    player.CharacterAdded:Connect(function(character)
        task.wait(0.5)  -- let character settle on lobby platform
        local run = PlayerRun[player]
        if not run then return end

        local humanoid = character:WaitForChild("Humanoid", 5)

        -- Always send back to lobby on any CharacterAdded.
        -- ReviveScroll never kills the character, so this path only fires on
        -- true death (planned via hum.Health = 0) or unexpected Roblox kills (void).
        -- Either way the correct destination is the lobby portal area.
        run.ArchetypeChosen  = false
        run.EnteredDungeon   = false
        run.PortalDebounce   = false
        if humanoid then
            humanoid.MaxHealth = math.huge
            humanoid.Health    = math.huge
            humanoid.HealthChanged:Connect(function(hp)
                if not run.ArchetypeChosen and hp < math.huge then
                    humanoid.Health = math.huge
                end
            end)
        end
        -- Teleport to lobby spawn near portals
        task.wait(0.3)
        local char2 = player.Character
        local root2 = char2 and char2:FindFirstChild("HumanoidRootPart")
        if root2 then
            root2.CFrame = CFrame.new(0, 6, 75)
        end
        initPlayerWithMeta(player, run.ArchetypeName, 1)
        UpdateHUD:FireClient(player, { ShowArchetypeScreen = true })
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    PlayerRun[player] = nil
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Archetype selection
-- ────────────────────────────────────────────────

local archetypeEvt = RemoteEvents:WaitForChild("SelectArchetype")

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

    -- Gather available origins for this archetype so the client can show the origin picker
    local OriginData = require(ReplicatedStorage.Modules.OriginData)
    -- TODO: pass player's UnlockedOrigins from MetaProgression for locked-origin filtering
    local availableOrigins = OriginData.GetForArchetype(archetypeName, {})
    local originChoices = {}
    for _, o in ipairs(availableOrigins) do
        table.insert(originChoices, {
            Id           = o.Id,
            Name         = o.Name,
            Lore         = o.Lore,
            AuraColor    = o.AuraColor,
            NamePrefix   = o.NamePrefix,
            PassiveName  = o.PassiveTrait and o.PassiveTrait.Name,
            PassiveDesc  = o.PassiveTrait and o.PassiveTrait.Description,
            FlavorQuote  = o.FlavorQuote,
        })
    end

    UpdateHUD:FireClient(player, {
        ArchetypeSelected = true,
        Archetype         = archetypeName,
        ShowOriginScreen  = true,   -- client should show origin picker before starting dungeon
        Origins           = originChoices,
    })

    -- Start a fresh challenge set (client may have sent desired challenge IDs via SelectBonus)
    local run2 = PlayerRun[player]
    ChallengeTracker.StartRun(player, run2 and run2.SelectedChallenges or {})

    -- Apply starting bonus if one was chosen
    local bonusId = run2 and run2.SelectedBonusId or "None"
    local bonusData = StartingBonusData.GetById(bonusId)
    if bonusData and bonusData.Applied then
        local cstate = CombatSystem.GetPlayerState(player)
        if cstate then
            local a = bonusData.Applied
            if a.HPPercent    then cstate.Stats.MaxHP = math.floor(cstate.Stats.MaxHP * (1 + a.HPPercent)); cstate.HP = cstate.Stats.MaxHP end
            if a.MPPercent    then cstate.Stats.MaxMP = math.floor(cstate.Stats.MaxMP * (1 + a.MPPercent)) end
            if a.AtkPercent   then cstate.Stats.Atk   = math.floor(cstate.Stats.Atk   * (1 + a.AtkPercent)) end
            if a.CDReduction  then cstate.Stats.CooldownReduction = (cstate.Stats.CooldownReduction or 0) + a.CDReduction end
            if a.BonusGold    then cstate.Gold = (cstate.Gold or 0) + a.BonusGold end
            if a.EvoXPMult    then cstate.BonusEvoXPMult = a.EvoXPMult end
            if a.StartHPFraction then cstate.HP = math.floor(cstate.Stats.MaxHP * a.StartHPFraction) end
        end
    end

    -- Player stays in lobby. Dungeon starts when they enter a portal.
    UpdateHUD:FireClient(player, {
        Message  = "Head to the portals south of the island to begin!",
        Duration = 6,
        Color    = Color3.fromRGB(251, 191, 36),
    })
end)

-- ────────────────────────────────────────────────
-- PORTAL ENTRY: proximity check (Heartbeat, no Touched dependency)
-- Positions from WorldBuilder PPOS table; y ignored (XZ only).
-- ────────────────────────────────────────────────

-- themeIndex maps each portal to the DungeonThemes.Themes entry that best fits it:
--   1=Demon Coast(dark docks) 2=Iron Order(white stone) 3=Drowned Kingdom(underwater)
--   4=Heaven's Ruin(sky/gold) 5=The Broken World(volcanic)
local PORTAL_DATA = {
    { name = "Coral Lagoon",  minLevel = 1,  startFloor = 1,  themeIndex = 3, x = -75, z = -155 },
    { name = "Pirate Cove",   minLevel = 5,  startFloor = 3,  themeIndex = 1, x =   0, z = -155 },
    { name = "Thunder Peak",  minLevel = 10, startFloor = 5,  themeIndex = 4, x =  75, z = -155 },
    { name = "Jungle Ruins",  minLevel = 20, startFloor = 7,  themeIndex = 5, x = -75, z = -182 },
    { name = "Glacial Keep",  minLevel = 30, startFloor = 9,  themeIndex = 2, x =   0, z = -182 },
    { name = "Shadow Gate",   minLevel = 50, startFloor = 12, themeIndex = 1, x =  75, z = -182 },
}
local PORTAL_RADIUS_SQ = 12 * 12  -- 12-stud XZ radius, squared to skip sqrt

local function tryEnterPortal(player, pd)
    local run = PlayerRun[player]
    if not run or run.EnteredDungeon or run.PortalDebounce then return end

    local state = CombatSystem.GetPlayerState(player)
    local playerLevel = (state and state.Stats and state.Stats.Level) or 1

    if playerLevel < pd.minLevel then
        local now = tick()
        if not run.LastLevelMsg or (now - run.LastLevelMsg) > 3 then
            run.LastLevelMsg = now
            UpdateHUD:FireClient(player, {
                Message  = "⛔  " .. pd.name .. " requires Level " .. pd.minLevel,
                Duration = 3,
                Color    = Color3.fromRGB(255, 80, 80),
            })
        end
        return
    end

    -- Auto-select Swordsman if no archetype chosen yet
    if not run.ArchetypeChosen then
        run.ArchetypeName   = "Swordsman"
        run.ArchetypeChosen = true
        initPlayerWithMeta(player, "Swordsman", 1)
        local char2 = player.Character
        local hum2  = char2 and char2:FindFirstChildWhichIsA("Humanoid")
        if hum2 then hum2.MaxHealth = 150; hum2.Health = 150 end
        UpdateHUD:FireClient(player, { Archetype = "Swordsman", Level = 1, HideArchetypeScreen = true })
    end

    run.PortalDebounce = true
    run.EnteredDungeon = true

    if GameState.Phase ~= "Running" then
        GameState.Phase = "Running"
        initFloor(pd.startFloor, pd.themeIndex)
        task.wait(1)
    end

    teleportToRoom(player, 1)
    ChallengeTracker.TrackEvent(player, "FloorEnter", { Floor = pd.startFloor })

    UpdateHUD:FireClient(player, {
        Message  = pd.name .. "  —  Floor " .. pd.startFloor .. "  |  Good luck!",
        Duration = 4,
        Color    = Color3.fromRGB(220, 80, 80),
    })

    print(("[GameManager] %s entered %s at level %d"):format(player.Name, pd.name, playerLevel))
end

-- Poll at ~10 Hz
local _portalTimer = 0
RunService.Heartbeat:Connect(function(dt)
    _portalTimer = _portalTimer + dt
    if _portalTimer < 0.1 then return end
    _portalTimer = 0
    for _, player in ipairs(Players:GetPlayers()) do
        local run = PlayerRun[player]
        if not run or run.EnteredDungeon or run.PortalDebounce then continue end
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        local px, pz = root.Position.X, root.Position.Z
        for _, pd in ipairs(PORTAL_DATA) do
            local dx, dz = px - pd.x, pz - pd.z
            if dx*dx + dz*dz <= PORTAL_RADIUS_SQ then
                task.spawn(tryEnterPortal, player, pd)
                break
            end
        end
    end
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Room door touched (notify enter)
-- ────────────────────────────────────────────────

local roomEnterEvt = RemoteEvents:WaitForChild("EnterRoom")

roomEnterEvt.OnServerEvent:Connect(function(player, roomId)
    handleRoomEnter(player, roomId)
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Pre-run bonus + challenge selection
-- data = { BonusId = string, ChallengeIds = {string...} }
-- ────────────────────────────────────────────────

if SelectBonusEvt then
    SelectBonusEvt.OnServerEvent:Connect(function(player, data)
        local run = PlayerRun[player]
        if not run then return end
        if type(data) ~= "table" then return end
        -- Validate bonus
        local meta = MetaProgression.GetState(player)
        local bonusId = data.BonusId or "None"
        local bonusData = StartingBonusData.GetById(bonusId)
        if bonusData then
            local available = StartingBonusData.GetAvailable(meta and meta.Unlocked or {})
            for _, b in ipairs(available) do
                if b.Id == bonusId then
                    run.SelectedBonusId = bonusId
                    break
                end
            end
        end
        -- Validate and store challenge selections
        local selected = {}
        for _, id in ipairs(data.ChallengeIds or {}) do
            if ChallengeData.GetById(id) and #selected < ChallengeData.MaxActiveChallenges then
                table.insert(selected, id)
            end
        end
        run.SelectedChallenges = selected
    end)
end

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Use consumable
-- ────────────────────────────────────────────────

local useItemEvt = RemoteEvents:WaitForChild("UseItem")

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

local buyItemEvt = RemoteEvents:WaitForChild("BuyItem")

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
        fireBountyEvent(player, "ItemBought", { Floor = GameState.CurrentFloor })
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

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Accept a Curse (Sealed Chamber room)
-- ────────────────────────────────────────────────

local pickCurseEvt = RemoteEvents:WaitForChild("PickCurse")

pickCurseEvt.OnServerEvent:Connect(function(player, curseId, roomId)
    if not GameState.CurseClaimed[roomId] then GameState.CurseClaimed[roomId] = {} end
    if GameState.CurseClaimed[roomId][player] then return end  -- already chose

    -- Validate the curse was one of the offered options
    local options = GameState.CurseOptions[roomId]
    if not options then return end
    local valid = false
    for _, opt in ipairs(options) do
        if opt.Id == curseId then valid = true; break end
    end
    if not valid then return end

    local run = PlayerRun[player]
    if not run then return end

    -- Apply curse to player's run (replaces any existing curse)
    run.ActiveCurseId = curseId
    GameState.CurseClaimed[roomId][player] = true

    -- Apply stat modifiers from the curse to the player's combat state
    local state = CombatSystem.GetPlayerState(player)
    if state then
        local statMods = CurseData.GetStatMods(curseId)
        -- Store the curse on the state so CombatSystem can reference it
        state.ActiveCurseId = curseId
        state.CurseStatMods = statMods

        -- Immediately apply HP-cap curses
        if statMods.MaxHPCapMultiplier then
            local newCap = math.floor(state.Stats.MaxHP * statMods.MaxHPCapMultiplier)
            state.Stats.MaxHP = newCap
            state.HP = math.min(state.HP, newCap)
        end
    end

    local curse = CurseData.GetById(curseId)
    UpdateHUD:FireClient(player, {
        CurseAccepted = true,
        CurseName     = curse and curse.Name or curseId,
        CurseIcon     = curse and curse.Icon or "💀",
        CurseDesc     = curse and curse.Description or "",
        Message       = (curse and curse.Name or curseId) .. " accepted.",
        Duration      = 4,
        HP            = state and state.HP,
        MaxHP         = state and state.Stats.MaxHP,
    })
end)

-- ────────────────────────────────────────────────
-- CLIENT → SERVER: Select an Origin (runs after archetype selection)
-- ────────────────────────────────────────────────

local selectOriginEvt = RemoteEvents:WaitForChild("SelectOrigin")

selectOriginEvt.OnServerEvent:Connect(function(player, originId)
    local OriginData = require(ReplicatedStorage.Modules.OriginData)
    local origin = OriginData.GetById(originId)
    if not origin then return end

    local run = PlayerRun[player]
    if not run or not run.ArchetypeChosen then return end

    -- Validate the origin is for the correct archetype
    if origin.ArchetypeKey ~= "Any" and origin.ArchetypeKey ~= run.ArchetypeName then return end

    run.OriginId = originId

    -- Re-init combat state with origin applied
    local level = CombatSystem.GetPlayerState(player) and CombatSystem.GetPlayerState(player).Stats.Level or 1
    local CharacterStats = require(ReplicatedStorage.Modules.CharacterStats)
    local stats = CharacterStats.BuildStats(run.ArchetypeName, level, originId)
    local state = CombatSystem.GetPlayerState(player)
    if state then
        state.Stats.OriginId    = originId
        state.Stats.OriginTrait = stats.OriginTrait
    end

    UpdateHUD:FireClient(player, {
        OriginSelected = true,
        OriginId       = originId,
        OriginName     = origin.Name,
        OriginLore     = origin.Lore,
        PassiveName    = origin.PassiveTrait and origin.PassiveTrait.Name,
        PassiveDesc    = origin.PassiveTrait and origin.PassiveTrait.Description,
    })
end)

print("[GameManager] Loaded and ready.")
