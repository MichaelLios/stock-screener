-- CombatSystem.server.lua
-- Handles ability execution, damage calculation, status effects, and hit detection.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local CharacterStats  = require(ReplicatedStorage.Modules.CharacterStats)
local AbilitySystem   = require(ReplicatedStorage.Modules.AbilitySystem)
local SynergySystem   = require(ReplicatedStorage.Modules.SynergySystem)
local AwakeningData   = require(ReplicatedStorage.Modules.AwakeningData)

local RemoteEvents       = ReplicatedStorage:WaitForChild("RemoteEvents")
local UseAbility         = RemoteEvents:WaitForChild("UseAbility")
local TakeDamage         = RemoteEvents:WaitForChild("TakeDamage")
local UpdateHUD          = RemoteEvents:WaitForChild("UpdateHUD")
local ActivateAwakeningEvt = RemoteEvents:WaitForChild("ActivateAwakening", 15)
local AwakeningStateEvt    = RemoteEvents:WaitForChild("AwakeningState",    15)

-- ────────────────────────────────────────────────
-- PLAYER STATE (server-authoritative)
-- ────────────────────────────────────────────────

local PlayerState = {}   -- [player] = { stats, hp, mp, buffs, debuffs, cooldowns, gold, inventory }
local EnemyDebuffs = {} -- [enemyModel] = { [debuffName] = { Duration, Data } }

local function getState(player)
    return PlayerState[player]
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        -- Default to Swordsman at level 1; GameManager will override on archetype selection
        local stats = CharacterStats.BuildStats("Swordsman", 1)
        PlayerState[player] = {
            Stats            = stats,
            HP               = stats.MaxHP,
            MP               = stats.MaxMP,
            Buffs            = {},
            Debuffs          = {},
            Cooldowns        = {},
            Gold             = 0,
            XP               = 0,
            Inventory        = {},
            KnownAbilities   = {},                             -- all learned ability names
            ActiveSlots      = { false,false,false,false,false }, -- equipped (1-5)
            AwakeningGauge   = 0,                              -- 0–100; fills during combat
        }
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    PlayerState[player] = nil
end)

-- ────────────────────────────────────────────────
-- STATUS EFFECT HELPERS
-- ────────────────────────────────────────────────

local function applyBuff(state, buff)
    state.Buffs[buff.Buff] = { Duration = buff.Duration, Data = buff }
end

local function applyDebuff(target, debuff)
    -- target is either a player state (table) or an enemy Model (Instance)
    if typeof(target) == "Instance" then
        if not EnemyDebuffs[target] then EnemyDebuffs[target] = {} end
        EnemyDebuffs[target][debuff.Debuff] = { Duration = debuff.Duration, Data = debuff }
    else
        if not target.Debuffs then target.Debuffs = {} end
        target.Debuffs[debuff.Debuff] = { Duration = debuff.Duration, Data = debuff }
    end
end

local function hasBuff(state, name)
    return state.Buffs[name] ~= nil
end

local function hasDebuff(target, name)
    if typeof(target) == "Instance" then
        return EnemyDebuffs[target] ~= nil and EnemyDebuffs[target][name] ~= nil
    end
    return target.Debuffs and target.Debuffs[name] ~= nil
end

-- Drain buffs/debuffs over time
RunService.Heartbeat:Connect(function(dt)
    for player, state in pairs(PlayerState) do
        -- Buff drain
        for name, entry in pairs(state.Buffs) do
            entry.Duration = entry.Duration - dt
            if entry.Duration <= 0 then
                state.Buffs[name] = nil
            end
        end
        -- Debuff drain — restore gameplay effects when a debuff expires
        for name, entry in pairs(state.Debuffs) do
            entry.Duration = entry.Duration - dt
            if entry.Duration <= 0 then
                state.Debuffs[name] = nil
                if name == "Slow" or name == "Stun" then
                    local char = player.Character
                    local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
                    if hum then hum.WalkSpeed = 16 end  -- restore Roblox default
                end
            end
        end
        -- Cooldown drain
        for name, remaining in pairs(state.Cooldowns) do
            state.Cooldowns[name] = remaining - dt
            if state.Cooldowns[name] <= 0 then
                state.Cooldowns[name] = nil
            end
        end
        -- Passive regen from items
        local stats = state.Stats
        if stats.HPRegen then
            state.HP = math.min(state.HP + stats.HPRegen * dt, stats.MaxHP)
        end
        if stats.MPRegen then
            state.MP = math.min(state.MP + stats.MPRegen * dt, stats.MaxMP)
        end
        -- Bankai burn (drains MP while active)
        if hasBuff(state, "BankaiState") then
            state.MP = math.max(0, state.MP - 5 * dt)
        end
    end
    -- Drain enemy debuffs and clean up removed enemies
    for model, debuffs in pairs(EnemyDebuffs) do
        if not model.Parent then
            EnemyDebuffs[model] = nil
        else
            for name, entry in pairs(debuffs) do
                entry.Duration = entry.Duration - dt
                if entry.Duration <= 0 then
                    debuffs[name] = nil
                end
            end
        end
    end
end)

-- ────────────────────────────────────────────────
-- DAMAGE APPLICATION
-- ────────────────────────────────────────────────

local function applyDamageToPlayer(player, rawDamage, damageType)
    local state = getState(player)
    if not state then return end
    local stats = state.Stats

    local dmg = CharacterStats.CalcDamage(rawDamage, stats.Def)

    -- Mana Shield absorbs damage first
    if hasBuff(state, "ManaShield") then
        local shield = state.Buffs["ManaShield"]
        local absorb = shield.Data.AbsorbAmount or 0
        local absorbed = math.min(dmg, absorb)
        shield.Data.AbsorbAmount = absorb - absorbed
        dmg = dmg - absorbed
        if shield.Data.AbsorbAmount <= 0 then
            state.Buffs["ManaShield"] = nil
        end
    end

    -- IronBody passive
    if stats.PassiveBonus == "IronBody" and state.HP < stats.MaxHP * 0.5 then
        dmg = math.floor(dmg * 0.8)
    end

    -- Awakening DefMult (e.g. Brawler 0.5 = take half damage)
    if hasBuff(state, "AwakeningActive") then
        local defMult = state.Buffs["AwakeningActive"].Data.DefMult or 1.0
        if defMult < 1.0 then
            dmg = math.max(1, math.floor(dmg * defMult))
        end
    end

    -- Chakra Plate item
    if stats.DamageReduction then
        dmg = math.floor(dmg * (1 - stats.DamageReduction))
    end

    dmg = math.max(1, dmg)
    state.HP = math.max(0, state.HP - dmg)

    -- ── Awakening gauge fill (damage taken) ─────────────────────────────────
    if not hasBuff(state, "AwakeningActive") then
        local awData = AwakeningData.GetAwakening(state.Stats.Archetype)
        if awData then
            local fill = dmg * (awData.GaugeOnDamageTaken or 0.6)
            state.AwakeningGauge = math.min(100, (state.AwakeningGauge or 0) + fill)
        end
    end

    -- Notify client HUD.  DamageTaken lets CombatVFX trigger the screen shake
    -- and red-vignette without needing a separate RemoteEvent.
    UpdateHUD:FireClient(player, {
        HP              = state.HP,
        MaxHP           = stats.MaxHP,
        MP              = state.MP,
        MaxMP           = stats.MaxMP,
        DamageTaken     = dmg,
        AwakeningGauge  = state.AwakeningGauge or 0,
    })

    if state.HP <= 0 then
        RemoteEvents.PlayerDied:FireClient(player)
    end

    return dmg
end

-- Apply damage to an enemy model (enemy state is stored in model attributes)
local function applyDamageToEnemy(enemyModel, rawDamage, damageType, attackerState)
    local currentHP = enemyModel:GetAttribute("HP") or 0
    local def       = enemyModel:GetAttribute("Def") or 0
    local dmg = CharacterStats.CalcDamage(rawDamage, def)

    -- DeathMark debuff
    if hasDebuff(enemyModel, "DeathMark") then
        local mark = EnemyDebuffs[enemyModel]["DeathMark"]
        dmg = math.floor(dmg * (mark.Data.DamageMultiplier or 1))
        EnemyDebuffs[enemyModel]["DeathMark"] = nil
    end

    -- Demon Slayer Blade bonus vs demon enemies
    if attackerState and attackerState.Stats.DemonBonus and enemyModel:GetAttribute("EnemyType") == "Demon" then
        dmg = math.floor(dmg * attackerState.Stats.DemonBonus)
    end

    -- Shield Templar frontal damage reduction
    -- If the attacker is in front of the enemy (dot product > 0.3), reduce by FrontalDamageReduct
    local frontalReduct = enemyModel:GetAttribute("FrontalDamageReduct")
    if frontalReduct and attackerState then
        local player = nil
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if PlayerState[p] == attackerState then player = p; break end
        end
        if player then
            local char    = player.Character
            local pRoot   = char and char:FindFirstChild("HumanoidRootPart")
            local eRoot   = enemyModel:FindFirstChild("HumanoidRootPart") or enemyModel.PrimaryPart
            if pRoot and eRoot then
                local toPlayer = (pRoot.Position - eRoot.Position).Unit
                local facing   = eRoot.CFrame.LookVector
                local dot      = facing:Dot(toPlayer)
                if dot > 0.25 then  -- attacker is in the frontal cone
                    dmg = math.max(1, math.floor(dmg * (1 - frontalReduct)))
                end
            end
        end
    end

    dmg = math.max(1, dmg)

    -- ── Critical hit roll ────────────────────────────────────────────────────
    local isCrit = false
    if attackerState then
        local autoCrit = hasBuff(attackerState, "AwakeningActive")
            and attackerState.Buffs["AwakeningActive"].Data.AutoCrit
        if autoCrit then
            isCrit = true
            dmg    = math.floor(dmg * (attackerState.Stats.CritMult or 1.8))
        elseif attackerState.Stats.CritChance then
            local chance = attackerState.Stats.CritChance
            if math.random() < chance then
                isCrit = true
                dmg    = math.floor(dmg * (attackerState.Stats.CritMult or 1.8))
            end
        end
    end

    local newHP = math.max(0, currentHP - dmg)
    enemyModel:SetAttribute("HP", newHP)

    -- ── Post-hit attacker bonuses ────────────────────────────────────────────
    if attackerState then
        -- MP drain on hit (Samehada)
        if attackerState.Stats.MPDrainOnHit then
            attackerState.MP = math.min(
                attackerState.MP + dmg * attackerState.Stats.MPDrainOnHit,
                attackerState.Stats.MaxMP
            )
        end
        -- Spirit Surge passive: 10% of damage as HP
        if attackerState.Stats.PassiveBonus == "SpiritSurge" then
            attackerState.HP = math.min(attackerState.HP + dmg * 0.10, attackerState.Stats.MaxHP)
        end
        -- Life steal (run upgrade)
        if attackerState.Stats.LifeSteal then
            local heal = math.floor(dmg * attackerState.Stats.LifeSteal)
            if heal > 0 then
                attackerState.HP = math.min(attackerState.HP + heal, attackerState.Stats.MaxHP)
            end
        end
    end

    -- ── Awakening gauge fill (damage dealt) ─────────────────────────────────
    if attackerState and not hasBuff(attackerState, "AwakeningActive") then
        local awData = AwakeningData.GetAwakening(attackerState.Stats.Archetype)
        if awData then
            local fill = dmg * (awData.GaugeOnDamageDealt or 0.4)
            attackerState.AwakeningGauge = math.min(100, (attackerState.AwakeningGauge or 0) + fill)
            -- Find attacker player and broadcast gauge update
            for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                if PlayerState[p] == attackerState then
                    UpdateHUD:FireClient(p, { AwakeningGauge = attackerState.AwakeningGauge })
                    break
                end
            end
        end
    end

    -- ── Floating damage number (clients render this) ─────────────────────────
    local enemyRoot = enemyModel:FindFirstChild("HumanoidRootPart")
        or enemyModel.PrimaryPart
        or enemyModel:FindFirstChildWhichIsA("Part")
    TakeDamage:FireAllClients({
        TargetId   = enemyModel:GetAttribute("EnemyId"),
        Damage     = dmg,
        IsCrit     = isCrit,
        DamageType = damageType,
        Position   = enemyRoot and enemyRoot.Position,
    })

    return dmg, newHP, isCrit
end

-- ────────────────────────────────────────────────
-- ABILITY EXECUTION
-- ────────────────────────────────────────────────

-- activeSynergies is passed in from UseAbility and may be nil outside ability context
local function getAttackMultiplier(state, activeSynergies)
    local mult = 1
    if hasBuff(state, "BankaiState") then
        mult = mult * (state.Buffs["BankaiState"].Data.AtkMultiplier or 1)
    end
    if hasBuff(state, "BerserkMode") then
        mult = mult * 2
    end
    -- Passive NightVeil: first hit of combat x2 (then disarm)
    if state.Stats.PassiveBonus == "NightVeil" and state.NightVeilReady then
        mult = mult * 2
        state.NightVeilReady = false
    end
    -- ArcaneAmplify for mages
    if state.Stats.PassiveBonus == "ArcaneAmplify" then
        mult = mult * 1.2
    end
    -- CounterReady buff: consume on next attack for 3× (or 5× with PhantomCounter synergy)
    if hasBuff(state, "CounterReady") then
        local counterMult = (activeSynergies and SynergySystem.GetBonus(activeSynergies, "CounterMult"))
            or state.Buffs["CounterReady"].Data.DamageMultiplier
            or 3.0
        mult = mult * counterMult
        state.Buffs["CounterReady"] = nil  -- one-shot, consumed on use
    end
    -- Awakening active
    if hasBuff(state, "AwakeningActive") then
        mult = mult * (state.Buffs["AwakeningActive"].Data.AtkMult or 2.0)
    end
    return mult
end

local function findEnemiesInRadius(origin, radius)
    local found = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("IsEnemy") then
            local rootPart = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            if rootPart then
                local dist = (rootPart.Position - origin).Magnitude
                if dist <= radius then
                    table.insert(found, obj)
                end
            end
        end
    end
    return found
end

local function findEnemiesOnPath(startPos, endPos, halfWidth)
    local found = {}
    local dir = (endPos - startPos).Unit
    local length = (endPos - startPos).Magnitude
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:GetAttribute("IsEnemy") then
            local rootPart = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            if rootPart then
                local toEnemy = rootPart.Position - startPos
                local projLen = toEnemy:Dot(dir)
                if projLen >= 0 and projLen <= length then
                    local lateral = (toEnemy - dir * projLen).Magnitude
                    if lateral <= halfWidth then
                        table.insert(found, obj)
                    end
                end
            end
        end
    end
    return found
end

local function executeEffect(effect, player, state, targetEnemy, aimDirection, abilityName, activeSynergies)
    local stats = state.Stats
    local rawAtk = stats.Atk * getAttackMultiplier(state, activeSynergies)
    activeSynergies = activeSynergies or {}

    if effect.Type == "Damage" then
        local dmg = rawAtk * (effect.Multiplier or 1)
        if effect.IsCrit then dmg = dmg * 1.5 end

        -- Synergy: StormStyle (+20% on ThunderClap)
        if abilityName == "ThunderClap" and SynergySystem.GetBonus(activeSynergies, "ThunderClapDmgMult") then
            dmg = dmg * SynergySystem.GetBonus(activeSynergies, "ThunderClapDmgMult")
        end
        -- Synergy: ArcaneOverload (+30% on ArcaneOrb)
        if abilityName == "ArcaneOrb" and SynergySystem.GetBonus(activeSynergies, "ArcaneOrbDmgMult") then
            dmg = dmg * SynergySystem.GetBonus(activeSynergies, "ArcaneOrbDmgMult")
        end
        -- Synergy: PhantomCounter (ShadowStep crit ×1.25 extra)
        if abilityName == "ShadowStep" and effect.IsCrit and SynergySystem.GetBonus(activeSynergies, "ShadowStepCritMult") then
            dmg = dmg * SynergySystem.GetBonus(activeSynergies, "ShadowStepCritMult")
        end
        -- Synergy: BankaiBerserk (BladeTornado +40% while Bankai is active)
        if abilityName == "BladeTornado" and hasBuff(state, "BankaiState")
        and SynergySystem.GetBonus(activeSynergies, "BankaiTornadoDmgMult") then
            dmg = dmg * SynergySystem.GetBonus(activeSynergies, "BankaiTornadoDmgMult")
        end

        -- Check if this ability uses projectile travel
        local abDef = AbilitySystem.GetAbility(abilityName)
        if abDef and abDef.Projectile then
            -- Spawn a visible projectile that travels toward the target/aim direction
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                local spawnPos = root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0)
                -- Determine travel direction
                local travelDir
                if targetEnemy then
                    local ep = targetEnemy:FindFirstChild("HumanoidRootPart") or targetEnemy.PrimaryPart
                    if ep then
                        travelDir = (ep.Position - spawnPos).Unit
                    end
                end
                travelDir = travelDir or aimDirection.Unit

                -- Projectile appearance varies by ability
                local projColor = Color3.fromRGB(255, 220, 50)
                local projSize  = Vector3.new(1, 1, 1)
                if abilityName == "MagicBolt" then
                    projColor = Color3.fromRGB(120, 80, 255)
                    projSize  = Vector3.new(0.8, 0.8, 2)
                elseif abilityName == "ArcaneOrb" then
                    projColor = Color3.fromRGB(200, 50, 255)
                    projSize  = Vector3.new(1.5, 1.5, 1.5)
                elseif abilityName == "SpiritBlast" then
                    projColor = Color3.fromRGB(50, 220, 255)
                    projSize  = Vector3.new(1.2, 1.2, 2.5)
                elseif abilityName == "DeathMark" then
                    projColor = Color3.fromRGB(180, 0, 0)
                    projSize  = Vector3.new(0.6, 0.6, 1.8)
                end

                local capturedDmg   = dmg
                local capturedState = state
                task.spawn(function()
                    local proj = Instance.new("Part")
                    proj.Size        = projSize
                    proj.Shape       = Enum.PartType.Ball
                    proj.BrickColor  = BrickColor.new(projColor)
                    proj.Material    = Enum.Material.Neon
                    proj.CanCollide  = false
                    proj.CastShadow  = false
                    proj.Anchored    = false
                    proj.CFrame      = CFrame.new(spawnPos)
                    proj.Parent      = workspace
                    Debris:AddItem(proj, 4)  -- auto-clean if it misses

                    local bv = Instance.new("BodyVelocity")
                    bv.Velocity  = travelDir * 90
                    bv.MaxForce  = Vector3.new(1e5, 1e5, 1e5)
                    bv.Parent    = proj

                    local MAX_DIST = 120
                    local startPos = proj.Position
                    local alreadyHit = false
                    while proj.Parent and not alreadyHit do
                        task.wait(0.05)
                        if (proj.Position - startPos).Magnitude >= MAX_DIST then break end
                        local hitEnemies = findEnemiesInRadius(proj.Position, 3.5)
                        for _, enemy in ipairs(hitEnemies) do
                            applyDamageToEnemy(enemy, capturedDmg, effect.DamageType, capturedState)
                            alreadyHit = true
                            break
                        end
                    end
                    if proj.Parent then proj:Destroy() end
                end)
            end
        elseif targetEnemy then
            applyDamageToEnemy(targetEnemy, dmg, effect.DamageType, state)
        end

    elseif effect.Type == "AOE" then
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local enemies = findEnemiesInRadius(root.Position, effect.Radius)
        for _, enemy in ipairs(enemies) do
            if effect.Damage then
                local aoeDmg = rawAtk * (effect.Multiplier or 1)
                -- Synergy: BankaiBerserk (BladeTornado while Bankai)
                if abilityName == "BladeTornado" and hasBuff(state, "BankaiState")
                and SynergySystem.GetBonus(activeSynergies, "BankaiTornadoDmgMult") then
                    aoeDmg = aoeDmg * SynergySystem.GetBonus(activeSynergies, "BankaiTornadoDmgMult")
                end
                applyDamageToEnemy(enemy, aoeDmg, effect.DamageType, state)
            end
            if effect.Debuff then
                applyDebuff(enemy, { Debuff = effect.Debuff, Duration = effect.Duration })
            end
            -- Synergy: StormStyle (BladeTornado stuns)
            if abilityName == "BladeTornado" and SynergySystem.GetBonus(activeSynergies, "BladeTornadoStun") then
                applyDebuff(enemy, { Debuff = "Stun", Duration = 2 })
            end
            -- Synergy: ArcaneOverload (ElementalBurst also slows)
            if abilityName == "ElementalBurst" and SynergySystem.GetBonus(activeSynergies, "ElementalBurstSlow") then
                applyDebuff(enemy, { Debuff = "Slow", Duration = 3 })
            end
        end

    elseif effect.Type == "Knockback" then
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local enemies = findEnemiesInRadius(root.Position, 15)
        for _, enemy in ipairs(enemies) do
            local ep = (enemy:FindFirstChild("HumanoidRootPart") or enemy.PrimaryPart)
            if ep then
                local dir = (ep.Position - root.Position).Unit
                -- Use BodyVelocity for reliable physics-based knockback
                local existing = ep:FindFirstChild("_KnockbackBV")
                if existing then existing:Destroy() end
                local bv = Instance.new("BodyVelocity")
                bv.Name = "_KnockbackBV"
                bv.Velocity = dir * (effect.Force or 50)
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Parent = ep
                Debris:AddItem(bv, 0.15)
            end
        end

    elseif effect.Type == "Heal" then
        local healAmount = effect.Amount
        -- Synergy: SpiritualHunger (+40 HP on SoulDrain)
        if abilityName == "SoulDrain" and SynergySystem.GetBonus(activeSynergies, "SoulDrainHealBonus") then
            healAmount = healAmount + SynergySystem.GetBonus(activeSynergies, "SoulDrainHealBonus")
        end
        if effect.OverTime then
            coroutine.wrap(function()
                local ticks = effect.Duration / effect.Interval
                for _ = 1, ticks do
                    state.HP = math.min(state.HP + healAmount, stats.MaxHP)
                    UpdateHUD:FireClient(player, { HP = state.HP, MaxHP = stats.MaxHP, MP = state.MP, MaxMP = stats.MaxMP })
                    task.wait(effect.Interval)
                end
            end)()
        else
            state.HP = math.min(state.HP + healAmount, stats.MaxHP)
            UpdateHUD:FireClient(player, { HP = state.HP, MaxHP = stats.MaxHP, MP = state.MP, MaxMP = stats.MaxMP })
        end

    elseif effect.Type == "Buff" then
        local buffCopy = {}
        for k, v in pairs(effect) do buffCopy[k] = v end
        -- Synergy: Fortress (+50% ManaShield absorb)
        if buffCopy.Buff == "ManaShield" and SynergySystem.GetBonus(activeSynergies, "ShieldAbsorbBonus") then
            buffCopy.AbsorbAmount = math.floor((buffCopy.AbsorbAmount or 80) * (1 + SynergySystem.GetBonus(activeSynergies, "ShieldAbsorbBonus")))
        end
        -- Synergy: Fortress (+4s IronDefense)
        if buffCopy.Buff == "IronSkin" and SynergySystem.GetBonus(activeSynergies, "IronDefenseDurBonus") then
            buffCopy.Duration = (buffCopy.Duration or 8) + SynergySystem.GetBonus(activeSynergies, "IronDefenseDurBonus")
        end
        -- Synergy: BankaiBerserk (+25% crit while BankaiFrenzy active)
        if buffCopy.Buff == "BankaiState" and SynergySystem.GetBonus(activeSynergies, "BankaiCritBonus") then
            state.Stats.CritChance = (state.Stats.CritChance or 0.10) + SynergySystem.GetBonus(activeSynergies, "BankaiCritBonus")
            -- Schedule removal of crit bonus when BankaiState expires
            local critBonus = SynergySystem.GetBonus(activeSynergies, "BankaiCritBonus")
            task.delay(buffCopy.Duration or 10, function()
                if state then
                    state.Stats.CritChance = math.max(0.01, state.Stats.CritChance - critBonus)
                end
            end)
        end
        applyBuff(state, buffCopy)

    elseif effect.Type == "Debuff" then
        if targetEnemy then
            applyDebuff(targetEnemy, effect)
        end

    elseif effect.Type == "Teleport" then
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if effect.ToBehindTarget and targetEnemy then
            local ep = (targetEnemy:FindFirstChild("HumanoidRootPart") or targetEnemy.PrimaryPart)
            if ep then
                -- Negative Z places player behind the enemy (enemy faces +Z by default)
                local behind = ep.CFrame * CFrame.new(0, 0, -4)
                root.CFrame = behind
            end
        elseif effect.Distance then
            local fwd = root.CFrame.LookVector
            root.CFrame = root.CFrame + fwd * effect.Distance
        end
        -- Path damage for dash-through abilities
        if effect.HitOnPath then
            local newPos = root.Position
            local pathEnemies = findEnemiesOnPath(root.Position - root.CFrame.LookVector * effect.Distance, newPos, 4)
            for _, enemy in ipairs(pathEnemies) do
                applyDamageToEnemy(enemy, rawAtk * (effect.Multiplier or 0.6), "Physical", state)
            end
        end

    elseif effect.Type == "RestoreMP" then
        local mpAmount = effect.Amount
        -- Synergy: SpiritualHunger (+25 MP on ChakraStrike)
        if abilityName == "ChakraStrike" and SynergySystem.GetBonus(activeSynergies, "ChakraStrikeMPBonus") then
            mpAmount = mpAmount + SynergySystem.GetBonus(activeSynergies, "ChakraStrikeMPBonus")
        end
        state.MP = math.min(state.MP + mpAmount, stats.MaxMP)
        UpdateHUD:FireClient(player, { HP = state.HP, MaxHP = stats.MaxHP, MP = state.MP, MaxMP = stats.MaxMP })

    elseif effect.Type == "FullHeal" then
        state.HP = stats.MaxHP
        state.MP = stats.MaxMP
        UpdateHUD:FireClient(player, { HP = state.HP, MaxHP = stats.MaxHP, MP = state.MP, MaxMP = stats.MaxMP })
    end
end

-- ────────────────────────────────────────────────
-- REMOTE: UseAbility
-- ────────────────────────────────────────────────

UseAbility.OnServerEvent:Connect(function(player, abilityName, targetEnemyId, aimDirectionRaw)
    local state = getState(player)
    if not state then return end

    local ab = AbilitySystem.GetAbility(abilityName)
    if not ab then return end

    -- Check ability is in an active slot
    local hasAbility = false
    for _, slotAbility in ipairs(state.ActiveSlots) do
        if slotAbility == abilityName then hasAbility = true; break end
    end
    if not hasAbility then return end

    -- Cooldown check
    if state.Cooldowns[abilityName] and state.Cooldowns[abilityName] > 0 then return end

    -- MP check
    if state.MP < ab.MPCost then return end

    -- Stun check
    if hasDebuff(state, "Stun") then return end

    -- Deduct MP and start cooldown
    state.MP = state.MP - ab.MPCost
    if ab.Cooldown > 0 then
        state.Cooldowns[abilityName] = ab.Cooldown
    end

    -- Find target enemy model by attribute id
    local targetEnemy = nil
    if targetEnemyId then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:GetAttribute("EnemyId") == targetEnemyId then
                targetEnemy = obj
                break
            end
        end
    end

    local aimDirection = Vector3.new(
        aimDirectionRaw and aimDirectionRaw.X or 0,
        aimDirectionRaw and aimDirectionRaw.Y or 0,
        aimDirectionRaw and aimDirectionRaw.Z or 1
    )

    -- Compute active synergies for this ability cast
    local activeSynergies = SynergySystem.GetActiveSynergies(state.ActiveSlots)

    -- Awakening: zero cost and apply extra crit if AutoCrit
    if hasBuff(state, "AwakeningActive") then
        local awData = state.Buffs["AwakeningActive"].Data
        if awData.ZeroCost then
            -- MP was already deducted, refund it
            state.MP = math.min(state.MP + ab.MPCost, state.Stats.MaxMP)
        end
    end

    -- Execute all effects
    for _, effect in ipairs(ab.Effects) do
        executeEffect(effect, player, state, targetEnemy, aimDirection, abilityName, activeSynergies)
    end

    -- PoisonCoat: tick down stacks on attack abilities
    if hasBuff(state, "PoisonCoat") and ab.Effects[1] and ab.Effects[1].Type == "Damage" then
        local coat = state.Buffs["PoisonCoat"]
        coat.Data.Stacks = (coat.Data.Stacks or 1) - 1
        if targetEnemy then
            applyDebuff(targetEnemy, { Debuff = "Poison", Duration = 4 })
        end
        if coat.Data.Stacks <= 0 then
            state.Buffs["PoisonCoat"] = nil
        end
    end

    -- Broadcast current synergies to client for Ability Book display
    local synergyNames = {}
    for name in pairs(activeSynergies) do table.insert(synergyNames, name) end

    -- Build status effect lists for buff/debuff icon strip
    local buffNames, debuffNames = {}, {}
    for name in pairs(state.Buffs) do table.insert(buffNames, name) end
    for name in pairs(state.Debuffs) do table.insert(debuffNames, name) end

    UpdateHUD:FireClient(player, {
        HP = state.HP, MaxHP = state.Stats.MaxHP,
        MP = state.MP, MaxMP = state.Stats.MaxMP,
        ActiveSynergies = synergyNames,
        StatusEffects   = { Buffs = buffNames, Debuffs = debuffNames },
    })
end)

-- ────────────────────────────────────────────────
-- REMOTE: ActivateAwakening (G key)
-- ────────────────────────────────────────────────

if ActivateAwakeningEvt then
    ActivateAwakeningEvt.OnServerEvent:Connect(function(player)
        local state = getState(player)
        if not state then return end

        -- Must have full gauge and not already awakened
        if (state.AwakeningGauge or 0) < 100 then return end
        if hasBuff(state, "AwakeningActive") then return end

        local awData = AwakeningData.GetAwakening(state.Stats.Archetype)
        if not awData then return end

        -- Consume the gauge
        state.AwakeningGauge = 0

        -- Apply the AwakeningActive buff
        local buffData = {
            Buff         = "AwakeningActive",
            Duration     = awData.Duration,
            AtkMult      = awData.AtkMult,
            ZeroCost     = awData.ZeroCost,
            AutoCrit     = awData.AutoCrit,
            DefMult      = awData.DefMult,
            AwakeningName = awData.Name,
        }
        state.Buffs["AwakeningActive"] = { Duration = awData.Duration, Data = buffData }

        -- Notify ALL clients to show aura VFX on this player
        if AwakeningStateEvt then
            AwakeningStateEvt:FireAllClients({
                PlayerUserId  = player.UserId,
                AwakeningName = awData.Name,
                AuraColor     = { R = awData.AuraColor.R, G = awData.AuraColor.G, B = awData.AuraColor.B },
                Duration      = awData.Duration,
                Active        = true,
            })
        end

        -- HUD update for the activating player
        UpdateHUD:FireClient(player, {
            HP = state.HP, MaxHP = state.Stats.MaxHP,
            MP = state.MP, MaxMP = state.Stats.MaxMP,
            AwakeningGauge = 0,
            Message  = awData.Name .. "!",
            Duration = 3,
            StatusEffects = { Buffs = (function()
                local names = {}
                for name in pairs(state.Buffs) do table.insert(names, name) end
                return names
            end)(), Debuffs = {} },
        })

        -- Schedule deactivation broadcast when buff expires
        task.delay(awData.Duration, function()
            if AwakeningStateEvt and player.Parent then
                AwakeningStateEvt:FireAllClients({
                    PlayerUserId = player.UserId,
                    Active       = false,
                })
            end
        end)

        print(("[CombatSystem] %s activated: %s"):format(player.Name, awData.Name))
    end)
end

-- ────────────────────────────────────────────────
-- PUBLIC API (for EnemyAI and GameManager)
-- ────────────────────────────────────────────────

local CombatSystem = {}

function CombatSystem.GetPlayerState(player)
    return PlayerState[player]
end

function CombatSystem.InitPlayer(player, archetypeName, level)
    local state = PlayerState[player]
    if not state then return end
    state.Stats = CharacterStats.BuildStats(archetypeName, level)
    state.HP = state.Stats.MaxHP
    state.MP = state.Stats.MaxMP
    state.NightVeilReady  = (archetypeName == "Assassin")
    state.AwakeningGauge  = 0
    state.Buffs["AwakeningActive"] = nil  -- clear any lingering awakening on re-init

    -- On first init (or archetype change), reset known + active abilities.
    -- On respawn (same archetype, level > 1), preserve what the player had.
    local isFirstInit = #state.KnownAbilities == 0
    if isFirstInit then
        state.KnownAbilities = table.clone(state.Stats.Abilities)
        state.ActiveSlots = { false, false, false, false, false }
        for i, name in ipairs(state.KnownAbilities) do
            state.ActiveSlots[i] = name
        end
    end

    UpdateHUD:FireClient(player, {
        HP             = state.HP,
        MaxHP          = state.Stats.MaxHP,
        MP             = state.MP,
        MaxMP          = state.Stats.MaxMP,
        Level          = state.Stats.Level,
        Archetype      = archetypeName,
        ActiveSlots    = state.ActiveSlots,
        KnownAbilities = state.KnownAbilities,
        AwakeningGauge = 0,
    })
end

function CombatSystem.DamagePlayer(player, rawDamage, damageType)
    return applyDamageToPlayer(player, rawDamage, damageType)
end

function CombatSystem.DamageEnemy(enemyModel, rawDamage, damageType, attackerPlayer)
    local attState = attackerPlayer and PlayerState[attackerPlayer] or nil
    return applyDamageToEnemy(enemyModel, rawDamage, damageType, attState)
end

function CombatSystem.GiveXP(player, amount)
    local state = PlayerState[player]
    if not state then return end
    state.XP = (state.XP or 0) + amount
    local needed = CharacterStats.XPForLevel(state.Stats.Level + 1)
    while state.XP >= needed do
        state.XP = state.XP - needed
        local newLevel = state.Stats.Level + 1
        state.Stats = CharacterStats.BuildStats(state.Stats.Archetype, newLevel)
        state.HP = math.min(state.HP + 30, state.Stats.MaxHP)  -- partial HP restore on level up
        state.MP = state.Stats.MaxMP                            -- full MP restore on level up
        needed = CharacterStats.XPForLevel(newLevel + 1)
        UpdateHUD:FireClient(player, {
            LevelUp = true, Level = newLevel,
            HP = state.HP, MaxHP = state.Stats.MaxHP,
            MP = state.MP, MaxMP = state.Stats.MaxMP,
        })
        print(("[CombatSystem] %s leveled up to %d!"):format(player.Name, newLevel))
    end
    UpdateHUD:FireClient(player, { XP = state.XP, XPNeeded = CharacterStats.XPForLevel(state.Stats.Level + 1) })
end

-- ────────────────────────────────────────────────
-- ABILITY MANAGEMENT
-- ────────────────────────────────────────────────

-- Grant a new ability to a player (from scrolls, events, etc.)
-- Returns true if newly learned, false if already known or invalid.
function CombatSystem.GrantAbility(player, abilityName)
    local state = PlayerState[player]
    if not state then return false end
    if not AbilitySystem.GetAbility(abilityName) then return false end
    for _, name in ipairs(state.KnownAbilities) do
        if name == abilityName then return false end
    end
    table.insert(state.KnownAbilities, abilityName)
    UpdateHUD:FireClient(player, {
        GrantedAbility = abilityName,
        KnownAbilities = state.KnownAbilities,
        ActiveSlots    = state.ActiveSlots,
    })
    return true
end

function CombatSystem.KnowsAbility(player, abilityName)
    local state = PlayerState[player]
    if not state then return false end
    for _, name in ipairs(state.KnownAbilities) do
        if name == abilityName then return true end
    end
    return false
end

-- ── SwapAbility remote (client assigns an ability to an active slot) ────────
local swapAbilityEvt = RemoteEvents:WaitForChild("SwapAbility")
swapAbilityEvt.OnServerEvent:Connect(function(player, slotIndex, abilityName)
    local state = PlayerState[player]
    if not state then return end
    if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > 5 then return end

    if abilityName then
        -- Validate ownership
        local known = false
        for _, name in ipairs(state.KnownAbilities) do
            if name == abilityName then known = true; break end
        end
        if not known then return end
        if not AbilitySystem.GetAbility(abilityName) then return end
    end

    state.ActiveSlots[slotIndex] = abilityName or false
    UpdateHUD:FireClient(player, { ActiveSlots = state.ActiveSlots })
end)

-- Apply a debuff to a player from an enemy ability (Freezing modifier, etc.)
-- Handles any gameplay effects that accompany the debuff (e.g. WalkSpeed for Slow).
function CombatSystem.DebuffPlayer(player, debuffName, duration)
    local state = PlayerState[player]
    if not state then return end

    -- Refresh duration if already active rather than stacking
    state.Debuffs[debuffName] = {
        Duration = duration,
        Data     = { Debuff = debuffName },
    }

    if debuffName == "Slow" then
        local char = player.Character
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum then hum.WalkSpeed = 5 end
        UpdateHUD:FireClient(player, { Message = "Slowed!", Duration = 1.2 })
    elseif debuffName == "Stun" then
        -- Stun already blocks ability use (checked in UseAbility handler).
        -- Optionally zero WalkSpeed here for a visual stop.
        local char = player.Character
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum then hum.WalkSpeed = 0 end
        UpdateHUD:FireClient(player, { Message = "Stunned!", Duration = 1.0 })
    end
end

function CombatSystem.AddItemStats(player, itemStats)
    local state = PlayerState[player]
    if not state then return end
    for stat, val in pairs(itemStats) do
        if state.Stats[stat] then
            state.Stats[stat] = state.Stats[stat] + val
        end
    end
    -- Clamp HP and MP
    state.HP = math.min(state.HP, state.Stats.MaxHP)
    state.MP = math.min(state.MP, state.Stats.MaxMP)
end

return CombatSystem
