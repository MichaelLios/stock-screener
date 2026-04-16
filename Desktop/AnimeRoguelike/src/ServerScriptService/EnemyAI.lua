-- EnemyAI.server.lua
-- Controls enemy behavior: patrol, chase, attack, phase transitions.
-- Each spawned enemy model runs its AI in a coroutine managed here.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local EnemyData       = require(ReplicatedStorage.Modules.EnemyData)
local AbilitySystem   = require(ReplicatedStorage.Modules.AbilitySystem)
local EnemyModifiers  = require(ReplicatedStorage.Modules.EnemyModifiers)

-- CombatSystem is loaded lazily to avoid circular require on startup
local CombatSystem

-- EnemyAttack RemoteEvent — fire it before the actual damage call so clients
-- can display a telegraph (red floor circle) for the duration of TELEGRAPH_DELAY.
local EnemyAttackEvt  -- lazily resolved below

local TELEGRAPH_DELAY = 0.40  -- seconds of warning before damage lands

local EnemyAI = {}

local activeEnemies = {}  -- { [model] = { data, state, coroutineThread } }

-- ────────────────────────────────────────────────
-- PATHFINDING HELPERS
-- ────────────────────────────────────────────────

local PathfindingService = game:GetService("PathfindingService")

local function computePath(from, to)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = false,
        AgentCanClimb = false,
    })
    local success, err = pcall(function()
        path:ComputeAsync(from, to)
    end)
    if success and path.Status == Enum.PathStatus.Success then
        return path:GetWaypoints()
    end
    return nil
end

local function moveToward(rootPart, targetPos, speed, dt)
    local dir = (targetPos - rootPart.Position)
    if dir.Magnitude < 1 then return true end
    dir = dir.Unit
    rootPart.CFrame = CFrame.new(rootPart.Position + dir * speed * dt, rootPart.Position + dir)
    return false
end

-- ────────────────────────────────────────────────
-- FIND NEAREST PLAYER
-- ────────────────────────────────────────────────

local function getNearestPlayer(origin, maxRange)
    local nearest, nearestDist = nil, maxRange
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - origin).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = player
                end
            end
        end
    end
    return nearest, nearestDist
end

-- ────────────────────────────────────────────────
-- TELEGRAPH HELPER
-- ────────────────────────────────────────────────

local function fireTelegraph(targetPlayer, attackRange, attackType)
    if not EnemyAttackEvt then
        local re = ReplicatedStorage:FindFirstChild("RemoteEvents")
        EnemyAttackEvt = re and re:FindFirstChild("EnemyAttack")
    end
    if not EnemyAttackEvt then return end

    local tChar = targetPlayer.Character
    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then return end

    EnemyAttackEvt:FireAllClients({
        Position   = tRoot.Position,
        Radius     = attackRange * 0.55,   -- visual radius slightly inside the real range
        Delay      = TELEGRAPH_DELAY,
        AttackType = attackType,
    })
end

-- ────────────────────────────────────────────────
-- ATTACK LOGIC
-- ────────────────────────────────────────────────

local function meleeAttack(enemyState, data, targetPlayer)
    if not CombatSystem then
        CombatSystem = require(game.ServerScriptService.CombatSystem)
    end
    local rawDmg = data.Atk
    CombatSystem.DamagePlayer(targetPlayer, rawDmg, "Physical")
end

local function rangedAttack(enemyModel, data, targetPlayer)
    local root = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart
    local tChar = targetPlayer.Character
    if not root or not tChar then return end
    local tRoot = tChar:FindFirstChild("HumanoidRootPart")
    if not tRoot then return end

    -- Spawn a simple projectile part
    local proj = Instance.new("Part")
    proj.Name = "EnemyProjectile"
    proj.Size = Vector3.new(1, 1, 1)
    proj.Shape = Enum.PartType.Ball
    proj.Color = Color3.fromRGB(220, 60, 60)
    proj.Material = Enum.Material.Neon
    proj.CFrame = CFrame.new(root.Position)
    proj.Anchored = false
    proj.CanCollide = false
    proj.Parent = workspace

    local dir = (tRoot.Position - root.Position).Unit
    proj.AssemblyLinearVelocity = dir * 40

    -- Damage on touch
    proj.Touched:Connect(function(hit)
        local char = hit.Parent
        local player = Players:GetPlayerFromCharacter(char)
        if player then
            if not CombatSystem then
                CombatSystem = require(game.ServerScriptService.CombatSystem)
            end
            CombatSystem.DamagePlayer(player, data.Atk * 0.8, "Magic")
            proj:Destroy()
        end
    end)

    game:GetService("Debris"):AddItem(proj, 4)
end

-- ────────────────────────────────────────────────
-- PHASE TRANSITION (boss mechanics)
-- ────────────────────────────────────────────────

-- Lazily resolved so this file doesn't depend on RemoteEvents being fully set up at require time
local BossPhaseEvt

local function checkPhase(enemyModel, enemyState, data, currentHP)
    if not data.PhaseThresholds then return end
    local maxHP = data.HP
    for i, threshold in ipairs(data.PhaseThresholds) do
        if enemyState.Phase < i and currentHP / maxHP <= threshold then
            enemyState.Phase = i
            print(("[EnemyAI] Boss '%s' entered phase %d"):format(data.DisplayName, i))

            -- Stat escalation per phase
            data.Atk = math.floor(data.Atk * 1.35)
            data.Spd = data.Spd + 5
            if i == 2 then
                data.AttackRange = data.AttackRange * 1.2
            end

            -- Fire BossPhase event to all clients
            if not BossPhaseEvt then
                local re = ReplicatedStorage:FindFirstChild("RemoteEvents")
                BossPhaseEvt = re and re:FindFirstChild("BossPhase")
            end
            if BossPhaseEvt then
                BossPhaseEvt:FireAllClients({
                    BossName    = data.DisplayName,
                    Phase       = i,
                    TotalPhases = #data.PhaseThresholds + 1,
                    EnemyId     = enemyModel:GetAttribute("EnemyId"),
                    CurrentHP   = currentHP,
                    MaxHP       = maxHP,
                })
            end
        end
    end
end

-- ────────────────────────────────────────────────
-- AI LOOP
-- ────────────────────────────────────────────────

local AI_TICK = 0.1  -- seconds between AI updates per enemy

local function runAI(enemyModel, data)
    local root = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart
    if not root then return end

    local state = {
        Phase          = 0,
        AttackCooldown = 0,
        AbilityCooldown = 0,
        Patrolling     = true,
        PatrolTarget   = root.Position + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10)),
        SummonCooldown = 0,
        SummonCount    = 0,
    }

    local isBoss    = table.find(data.Behaviors, "Boss") ~= nil
    local isMelee   = table.find(data.Behaviors, "Melee") ~= nil
    local isRanged  = table.find(data.Behaviors, "Ranged") ~= nil
    local isCharger = table.find(data.Behaviors, "Charger") ~= nil
    local isSummon  = table.find(data.Behaviors, "Summoner") ~= nil
    local isBerserk = table.find(data.Behaviors, "Berserk") ~= nil

    -- Modifier flags — read once before the loop for performance
    local modName        = enemyModel:GetAttribute("Modifier")
    local isVampiric     = modName == "Vampiric"
    local isFreezing     = modName == "Freezing"
    local isBerserkerMod = modName == "Berserker"

    while enemyModel and enemyModel.Parent do
        task.wait(AI_TICK)

        root = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart
        if not root then break end

        local currentHP = enemyModel:GetAttribute("HP") or 0
        if currentHP <= 0 then break end

        -- Drain cooldowns
        state.AttackCooldown  = math.max(0, state.AttackCooldown - AI_TICK)
        state.AbilityCooldown = math.max(0, state.AbilityCooldown - AI_TICK)
        state.SummonCooldown  = math.max(0, state.SummonCooldown - AI_TICK)

        -- Phase check for bosses
        if isBoss then checkPhase(enemyModel, state, data, currentHP) end

        -- Berserk: speed boost below 30 % HP.
        -- Berserker modifier skips the threshold — always enraged.
        if (isBerserk and currentHP / data.HP <= 0.3) or isBerserkerMod then
            data.Spd = data.Spd + 0.01
        end

        -- Find nearest player
        local target, dist = getNearestPlayer(root.Position, data.DetectRange)

        if not target then
            -- Patrol
            local arrived = moveToward(root, state.PatrolTarget, data.Spd * 0.5, AI_TICK)
            if arrived then
                state.PatrolTarget = root.Position + Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
            end
        else
            local tChar = target.Character
            local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
            if not tRoot then continue end

            local targetPos = tRoot.Position

            -- Summoner logic
            if isSummon and state.SummonCooldown <= 0 and state.SummonCount < (data.MaxSummons or 3) then
                state.SummonCooldown = data.SummonCooldown or 12
                state.SummonCount = state.SummonCount + 1
                -- Notify GameManager to spawn an add via a BindableEvent or direct require
                local spawnEvent = ReplicatedStorage:FindFirstChild("RemoteEvents")
                if spawnEvent then
                    local summonEvt = spawnEvent:FindFirstChild("SummonEnemy")
                    if summonEvt then
                        summonEvt:Fire(data.SummonEnemy, root.Position + Vector3.new(math.random(-8,8), 0, math.random(-8,8)))
                    end
                end
            end

            -- Ability use
            if #data.Abilities > 0 and state.AbilityCooldown <= 0 then
                local ab = AbilitySystem.GetAbility(data.Abilities[math.random(#data.Abilities)])
                if ab then
                    state.AbilityCooldown = ab.Cooldown + 2
                    -- AOE ability
                    if ab.Effects[1] and ab.Effects[1].Type == "AOE" then
                        local radius = ab.Effects[1].Radius or 15
                        if dist <= radius then
                            -- fire AOE damage at players
                            for _, player in ipairs(Players:GetPlayers()) do
                                local pc = player.Character
                                local pr = pc and pc:FindFirstChild("HumanoidRootPart")
                                if pr and (pr.Position - root.Position).Magnitude <= radius then
                                    if not CombatSystem then
                                        CombatSystem = require(game.ServerScriptService.CombatSystem)
                                    end
                                    CombatSystem.DamagePlayer(player, data.Atk * (ab.Effects[1].Multiplier or 1), "Magic")
                                end
                            end
                        end
                    end
                end
            end

            -- Movement toward player (charger ignores pathfinding, others use it)
            if dist > data.AttackRange then
                if isCharger then
                    moveToward(root, targetPos, data.Spd, AI_TICK)
                else
                    -- Attempt pathfinding every 0.5s for non-charger
                    if not state.Waypoints or (tick() - (state.LastPathCalc or 0) > 0.5) then
                        state.Waypoints = computePath(root.Position, targetPos)
                        state.WaypointIndex = 2
                        state.LastPathCalc = tick()
                    end
                    if state.Waypoints and state.WaypointIndex and state.WaypointIndex <= #state.Waypoints then
                        local wp = state.Waypoints[state.WaypointIndex]
                        local arrived = moveToward(root, wp.Position, data.Spd, AI_TICK)
                        if arrived then state.WaypointIndex = state.WaypointIndex + 1 end
                    else
                        moveToward(root, targetPos, data.Spd, AI_TICK)
                    end
                end

            else
                -- In attack range
                if state.AttackCooldown <= 0 then
                    state.AttackCooldown = 1.5 + TELEGRAPH_DELAY
                    local didAttack = false

                    if isRanged and dist > 10 then
                        fireTelegraph(target, data.AttackRange, "Ranged")
                        task.wait(TELEGRAPH_DELAY)
                        rangedAttack(enemyModel, data, target)
                        didAttack = true
                    elseif isMelee then
                        fireTelegraph(target, data.AttackRange, "Melee")
                        task.wait(TELEGRAPH_DELAY)
                        meleeAttack(state, data, target)
                        didAttack = true
                    end

                    -- ── Post-attack modifier effects ────────────────────────
                    if didAttack then
                        -- Vampiric: heal self by 18 % of Atk after every hit
                        if isVampiric then
                            local hp    = enemyModel:GetAttribute("HP") or 0
                            local maxHP = enemyModel:GetAttribute("MaxHP") or 1
                            local heal  = math.floor(data.Atk * 0.18)
                            enemyModel:SetAttribute("HP", math.min(hp + heal, maxHP))
                        end

                        -- Freezing: slow the target player
                        if isFreezing then
                            if not CombatSystem then
                                CombatSystem = require(game.ServerScriptService.CombatSystem)
                            end
                            CombatSystem.DebuffPlayer(target, "Slow", 3)
                        end
                    end
                end
                -- Face the target
                root.CFrame = CFrame.lookAt(root.Position, Vector3.new(targetPos.X, root.Position.Y, targetPos.Z))
            end
        end
    end

    -- Enemy is dead or removed
    activeEnemies[enemyModel] = nil
    if enemyModel and enemyModel.Parent then
        enemyModel:Destroy()
    end
end

-- ────────────────────────────────────────────────
-- PUBLIC API
-- ────────────────────────────────────────────────

-- roomType is optional (e.g. "Combat", "Elite").  Used to roll a modifier.
function EnemyAI.SpawnEnemy(enemyName, position, floor, roomFolder, roomType)
    local data = EnemyData.GetScaledEnemy(enemyName, floor)

    local model = Instance.new("Model")
    model.Name = data.DisplayName

    local rootPart = Instance.new("Part")
    rootPart.Name = "HumanoidRootPart"
    rootPart.Size = data.Size
    rootPart.Color = data.Color
    rootPart.Material = Enum.Material.SmoothPlastic
    rootPart.CFrame = CFrame.new(position)
    rootPart.Anchored = true
    rootPart.Parent = model
    model.PrimaryPart = rootPart

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(data.Size.X * 0.6, data.Size.X * 0.6, data.Size.X * 0.6)
    head.Color = data.Color
    head.Material = Enum.Material.SmoothPlastic
    head.CFrame = CFrame.new(position + Vector3.new(0, data.Size.Y * 0.5 + data.Size.X * 0.3, 0))
    head.Anchored = true
    head.Parent = model

    -- Nametag
    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 180, 0, 40)
    bg.StudsOffset = Vector3.new(0, data.Size.Y * 0.8, 0)
    bg.AlwaysOnTop = false
    bg.Parent = head
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = data.DisplayName
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Parent = bg
    local hpBar = Instance.new("Frame")
    hpBar.Name = "HPBar"
    hpBar.Size = UDim2.new(1, 0, 0.4, 0)
    hpBar.Position = UDim2.new(0, 0, 0.6, 0)
    hpBar.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    hpBar.BorderSizePixel = 0
    hpBar.Parent = bg
    local hpFill = Instance.new("Frame")
    hpFill.Name = "Fill"
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBar

    -- Set attributes
    local uniqueId = tostring(math.random(1e9))
    model:SetAttribute("IsEnemy",   true)
    model:SetAttribute("EnemyId",   uniqueId)
    model:SetAttribute("EnemyType", enemyName)
    model:SetAttribute("HP",        data.HP)
    model:SetAttribute("MaxHP",     data.HP)
    model:SetAttribute("Def",       data.Def)
    model:SetAttribute("XP",        data.XP)
    model:SetAttribute("LootTable", data.LootTable)

    -- Mark bosses so the client can display the dedicated boss health bar
    if data.PhaseThresholds then
        model:SetAttribute("IsBoss",      true)
        model:SetAttribute("BossName",    data.DisplayName)
        model:SetAttribute("TotalPhases", #data.PhaseThresholds + 1)
    end

    -- Special enemy attributes
    if data.FrontalDamageReduct then
        model:SetAttribute("FrontalDamageReduct", data.FrontalDamageReduct)
    end
    if data.IsBomber then
        model:SetAttribute("IsBomber", true)
    end

    -- Update HP bar on attribute change
    model:GetAttributeChangedSignal("HP"):Connect(function()
        local hp = model:GetAttribute("HP") or 0
        local maxHP = model:GetAttribute("MaxHP") or 1
        hpFill.Size = UDim2.new(math.clamp(hp / maxHP, 0, 1), 0, 1, 0)
    end)

    -- ── Modifier roll ─────────────────────────────────────────────────────────
    -- Boss rooms never get a modifier (they are already uniquely defined).
    local modData, modName = EnemyModifiers.Roll(roomType, floor)

    if modName and not data.PhaseThresholds then   -- skip if this is a boss
        -- Mutate the scaled data table (HP, Def, Spd, etc.)
        EnemyModifiers.ApplyStats(data, modName)

        -- Write updated stats back onto model attributes
        model:SetAttribute("HP",       data.HP)
        model:SetAttribute("MaxHP",    data.HP)
        model:SetAttribute("Def",      data.Def)
        model:SetAttribute("Modifier", modName)

        -- ── Crown indicator (on rootPart so it moves with the body) ──────────
        local crownGui = Instance.new("BillboardGui")
        crownGui.Size        = UDim2.new(0, 170, 0, 24)
        crownGui.StudsOffset = Vector3.new(0, data.Size.Y * 0.5 + data.Size.X * 0.95, 0)
        crownGui.AlwaysOnTop = false
        crownGui.Parent      = rootPart

        local crownLbl = Instance.new("TextLabel")
        crownLbl.Size                  = UDim2.new(1, 0, 1, 0)
        crownLbl.BackgroundTransparency = 1
        crownLbl.Text                  = "★  " .. modData.DisplayName:upper()
        crownLbl.TextColor3            = modData.Color
        crownLbl.TextScaled            = true
        crownLbl.Font                  = Enum.Font.GothamBold
        crownLbl.ZIndex                = 6
        crownLbl.Parent                = crownGui

        -- ── Coloured SelectionBox outline so the modifier reads at a glance ──
        local selBox = Instance.new("SelectionBox")
        selBox.Adornee             = model
        selBox.Color3              = modData.Color
        selBox.LineThickness       = 0.055
        selBox.SurfaceTransparency = 0.90
        selBox.SurfaceColor3       = modData.Color
        selBox.Parent              = model
    end

    model.Parent = roomFolder or workspace

    -- Start AI coroutine
    local thread = coroutine.create(function()
        runAI(model, data)
    end)
    activeEnemies[model] = { data = data, thread = thread }
    coroutine.resume(thread)

    return model, uniqueId
end

function EnemyAI.GetActiveCount()
    local count = 0
    for _ in pairs(activeEnemies) do count = count + 1 end
    return count
end

return EnemyAI
