-- CombatSystem.server.lua
-- Handles ability execution, damage calculation, status effects, and hit detection.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local CharacterStats   = require(ReplicatedStorage.Modules.CharacterStats)
local AbilitySystem    = require(ReplicatedStorage.Modules.AbilitySystem)
local SynergySystem    = require(ReplicatedStorage.Modules.SynergySystem)
local AwakeningData    = require(ReplicatedStorage.Modules.AwakeningData)
local AbilityEvolution = require(ReplicatedStorage.Modules.AbilityEvolution)

-- Lazy-require DynamicEventManager to avoid load-order issues
local _DynEvtMgr = nil
local function getDynEvtMgr()
    if not _DynEvtMgr then
        local ok, m = pcall(require, script.Parent.DynamicEventManager)
        if ok then _DynEvtMgr = m end
    end
    return _DynEvtMgr
end

local RemoteEvents       = ReplicatedStorage:WaitForChild("RemoteEvents")
local UseAbility         = RemoteEvents:WaitForChild("UseAbility")
local TakeDamage         = RemoteEvents:WaitForChild("TakeDamage")
local UpdateHUD          = RemoteEvents:WaitForChild("UpdateHUD")
local AbilityCastEvt       = RemoteEvents:WaitForChild("AbilityCast",       15)
local ActivateAwakeningEvt = RemoteEvents:WaitForChild("ActivateAwakening", 15)
local AwakeningStateEvt    = RemoteEvents:WaitForChild("AwakeningState",    15)
local PickGambleEvt        = RemoteEvents:WaitForChild("PickGamble",        15)
local GambleResultEvt      = RemoteEvents:WaitForChild("GambleResult",      15)
local StatusAppliedEvt     = RemoteEvents:WaitForChild("StatusApplied",     15)

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
            ComboCount        = 0,   -- consecutive hits for damage bonus
            LastHitTime       = 0,   -- tick() of last hit landing
            EvoXP             = {},  -- [abilityName] = hits landed with it this run
            EvoStage          = {},  -- [abilityName] = current evolution stage (0–2)
            VoidStacks        = 0,   -- VoidEater synergy kill accumulator (max 20)
            LastUsedAbility   = nil, -- most-recently fired ability (for evolution XP)
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
        -- Broadcast to clients for status effect VFX
        if StatusAppliedEvt then
            StatusAppliedEvt:FireAllClients({
                TargetId     = target:GetAttribute("EnemyId"),
                StatusType   = debuff.Debuff,
                Duration     = debuff.Duration,
            })
        end
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
        -- Combo decay: reset if no hit landed in the last 2.5 seconds
        if (state.ComboCount or 0) > 0 and tick() - (state.LastHitTime or 0) > 2.5 then
            state.ComboCount = 0
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
    state.ComboCount = 0  -- taking a hit breaks the combo

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

    if state.HP <= 0 and not state.IsDead then
        state.IsDead = true
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

    -- ── Combo tracking: increment on each successful hit ────────────────────
    if attackerState then
        attackerState.ComboCount  = (attackerState.ComboCount  or 0) + 1
        attackerState.LastHitTime = tick()
    end

    -- ── Ability evolution: XP tracking + per-hit stage bonuses ──────────────
    if attackerState and attackerState.LastUsedAbility then
        local evAbName = attackerState.LastUsedAbility
        local evoData  = AbilityEvolution.GetEvolution(evAbName)
        if evoData then
            local xp       = (attackerState.EvoXP[evAbName] or 0) + 1
            attackerState.EvoXP[evAbName] = xp
            local curStage = attackerState.EvoStage[evAbName] or 0
            local threshold = evoData.XPThresholds[curStage + 1]
            if threshold and xp >= threshold then
                local newStage = curStage + 1
                attackerState.EvoStage[evAbName] = newStage
                curStage = newStage
                local stageDef = evoData.Stages[newStage]
                -- Notify the attacking player
                for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                    if PlayerState[p] == attackerState then
                        UpdateHUD:FireClient(p, {
                            Message  = "✨  " .. (stageDef and stageDef.Name or evAbName) .. "  EVOLVED!",
                            Duration = 4,
                        })
                        break
                    end
                end
            end
            -- Apply per-hit bonuses for current stage
            if curStage > 0 and evoData.Stages[curStage] then
                local bonus = evoData.Stages[curStage].Bonus
                if bonus.LifeSteal then
                    attackerState.HP = math.min(
                        attackerState.HP + math.max(1, math.floor(dmg * bonus.LifeSteal)),
                        attackerState.Stats.MaxHP
                    )
                end
                if bonus.CDRefund and attackerState.Cooldowns[evAbName] then
                    attackerState.Cooldowns[evAbName] = math.max(0,
                        attackerState.Cooldowns[evAbName] - bonus.CDRefund)
                end
                if bonus.MPRestore then
                    attackerState.MP = math.min(
                        attackerState.MP + bonus.MPRestore, attackerState.Stats.MaxMP)
                end
            end
        end
    end

    -- ── Kill processing: synergy hooks ───────────────────────────────────────
    if newHP == 0 and attackerState then
        local killSyns = SynergySystem.GetActiveSynergies(attackerState.ActiveSlots)
        -- Reaper: kill resets ShadowStep cooldown
        if SynergySystem.GetBonus(killSyns, "KillResetShadowStep") then
            attackerState.Cooldowns["ShadowStep"] = nil
        end
        -- DeathBringer: kill of poisoned enemy resets DeathMark + free PoisonCoat stacks
        if SynergySystem.GetBonus(killSyns, "PoisonKillResetDeathMark")
        and hasDebuff(enemyModel, "Poison") then
            attackerState.Cooldowns["DeathMark"] = nil
            local coat = attackerState.Buffs["PoisonCoat"]
            if coat then
                coat.Data.Stacks = (coat.Data.Stacks or 0) + 3
            else
                attackerState.Buffs["PoisonCoat"] = {
                    Duration = 15,
                    Data     = { Buff = "PoisonCoat", Stacks = 3 },
                }
            end
        end
        -- VoidEater: +1 Void Stack per kill (max 20, persists across rooms)
        if SynergySystem.GetBonus(killSyns, "VoidStackOnKill") then
            attackerState.VoidStacks = math.min(20, (attackerState.VoidStacks or 0) + 1)
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
    -- Combo multiplier: +3% per consecutive hit, capped at 10 hits (+30%)
    local combo = state.ComboCount or 0
    if combo > 1 then
        mult = mult * (1 + math.min(combo - 1, 9) * 0.03)
    end
    -- VoidEater synergy: +2% per Void Stack (max 20 stacks = +40%)
    local voidStacks = state.VoidStacks or 0
    if voidStacks > 0 then
        mult = mult * (1 + voidStacks * 0.02)
    end
    -- BloodRage synergy: below 50% HP, damage scales up toward 2× at 0 HP
    if activeSynergies and SynergySystem.GetBonus(activeSynergies, "BloodRageMissingHPMult") then
        local hpPct = state.HP / math.max(state.Stats.MaxHP, 1)
        if hpPct < 0.50 then
            mult = mult * (1 + (1 - hpPct))  -- +50% at half HP, +100% at 0 HP
        end
    end
    -- DynamicEvent player Atk multiplier
    local dyn = getDynEvtMgr()
    if dyn then
        local dynPlayer = nil
        for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
            if PlayerState[p] == state then dynPlayer = p; break end
        end
        if dynPlayer then
            mult = mult * dyn.GetPlayerAtkMult(dynPlayer)
        end
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
                    table.insert(found, { model = obj, dist = dist })
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
    local result = {}
    for _, entry in ipairs(found) do table.insert(result, entry.model) end
    return result
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

        -- Apply ability evolution DmgMult bonus
        local evoStage = (state.EvoStage and state.EvoStage[abilityName]) or 0
        local evoBonus = nil
        if evoStage > 0 then
            local evoData2 = AbilityEvolution.GetEvolution(abilityName)
            if evoData2 and evoData2.Stages[evoStage] then
                evoBonus = evoData2.Stages[evoStage].Bonus
                if evoBonus.DmgMult then
                    dmg = dmg * evoBonus.DmgMult
                end
            end
        end
        -- SoulReap: ChakraStrike auto-crits while BankaiFrenzy is active
        if abilityName == "ChakraStrike" and hasBuff(state, "BankaiState")
        and SynergySystem.GetBonus(activeSynergies, "SoulReapChakraAutoCrit") then
            dmg = dmg * (stats.CritMult or 1.8)
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
        else
            -- No projectile: auto-target the nearest enemy within ability range (melee / targeted)
            local actualTarget = targetEnemy
            if not actualTarget then
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local abDef2 = AbilitySystem.GetAbility(abilityName)
                    local range = (abDef2 and abDef2.Range) or 8
                    local nearby = findEnemiesInRadius(root.Position, range)
                    if #nearby > 0 then actualTarget = nearby[1] end
                end
            end
            if actualTarget then
                applyDamageToEnemy(actualTarget, dmg, effect.DamageType, state)

                -- StormKing: chain lightning to nearby enemies
                if SynergySystem.GetBonus(activeSynergies, "ChainLightningCount") then
                    local chainCount = SynergySystem.GetBonus(activeSynergies, "ChainLightningCount")
                    local chainDmg   = math.floor(dmg * 0.45)
                    local cRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if cRoot then
                        local nearby = findEnemiesInRadius(cRoot.Position, 22)
                        local chained = 0
                        for _, chEnemy in ipairs(nearby) do
                            if chEnemy ~= actualTarget and chained < chainCount then
                                applyDamageToEnemy(chEnemy, chainDmg, "Lightning", state)
                                chained = chained + 1
                            end
                        end
                    end
                end

                -- ArcaneFusion: MagicBolt hits reduce ArcaneOrb cooldown by 1 s
                if abilityName == "MagicBolt"
                and SynergySystem.GetBonus(activeSynergies, "MagicBoltReducesArcaneOrbCD")
                and state.Cooldowns["ArcaneOrb"] then
                    state.Cooldowns["ArcaneOrb"] = math.max(0, state.Cooldowns["ArcaneOrb"] - 1)
                end

                -- ArcaneFusion: ArcaneOrb detonation fires a free ElementalBurst AOE
                if abilityName == "ArcaneOrb"
                and SynergySystem.GetBonus(activeSynergies, "ArcaneOrbFreeBurst") then
                    local epiRoot = actualTarget:FindFirstChild("HumanoidRootPart") or actualTarget.PrimaryPart
                    if epiRoot then
                        for _, bEnemy in ipairs(findEnemiesInRadius(epiRoot.Position, 14)) do
                            applyDamageToEnemy(bEnemy, rawAtk * 0.80, "Magic", state)
                        end
                    end
                end

                -- OniRush: RagingRush stuns hit enemies
                if abilityName == "RagingRush"
                and SynergySystem.GetBonus(activeSynergies, "OniRushStun") then
                    applyDebuff(actualTarget, { Debuff = "Stun", Duration = 1.5 })
                end

                -- AbilityResonance dynamic event: chain mini-AOE on every hit
                local dyn4 = getDynEvtMgr()
                local chainAOE = dyn4 and dyn4.GetAbilityChainAOE()
                if chainAOE then
                    local epiRoot2 = actualTarget:FindFirstChild("HumanoidRootPart") or actualTarget.PrimaryPart
                    if epiRoot2 then
                        for _, rEnemy in ipairs(findEnemiesInRadius(epiRoot2.Position, chainAOE.Radius)) do
                            if rEnemy ~= actualTarget then
                                applyDamageToEnemy(rEnemy, math.floor(dmg * chainAOE.Mult), effect.DamageType, state)
                            end
                        end
                    end
                end

                -- Evolution ExtraAOEOnHit
                if evoBonus and evoBonus.ExtraAOEOnHit then
                    local epiRoot3 = actualTarget:FindFirstChild("HumanoidRootPart") or actualTarget.PrimaryPart
                    if epiRoot3 then
                        for _, aEnemy in ipairs(findEnemiesInRadius(epiRoot3.Position, evoBonus.ExtraAOEOnHit.Radius)) do
                            if aEnemy ~= actualTarget then
                                applyDamageToEnemy(aEnemy,
                                    math.floor(dmg * evoBonus.ExtraAOEOnHit.Multiplier),
                                    effect.DamageType, state)
                            end
                        end
                    end
                end
            end
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

        -- OniRush: GroundSlam leaves a burning hazard field for 5 seconds
        if abilityName == "GroundSlam"
        and SynergySystem.GetBonus(activeSynergies, "OniSlamFireField") then
            local fieldPos = root.Position
            task.spawn(function()
                local elapsed = 0
                while elapsed < 5 do
                    task.wait(0.5)
                    elapsed = elapsed + 0.5
                    for _, fEnemy in ipairs(findEnemiesInRadius(fieldPos, 10)) do
                        applyDamageToEnemy(fEnemy, math.floor(rawAtk * 0.25), "Fire", state)
                    end
                end
            end)
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
        -- SoulReap: SoulDrain heals 3× while BankaiFrenzy is active
        if abilityName == "SoulDrain" and hasBuff(state, "BankaiState")
        and SynergySystem.GetBonus(activeSynergies, "SoulReapBankaiHealMult") then
            healAmount = math.floor(healAmount * SynergySystem.GetBonus(activeSynergies, "SoulReapBankaiHealMult"))
        end
        -- Evolution heal multiplier
        local evoHStage = (state.EvoStage and state.EvoStage[abilityName]) or 0
        if evoHStage > 0 then
            local evoHData = AbilityEvolution.GetEvolution(abilityName)
            if evoHData and evoHData.Stages[evoHStage] and evoHData.Stages[evoHStage].Bonus.HealAmountMult then
                healAmount = math.floor(healAmount * evoHData.Stages[evoHStage].Bonus.HealAmountMult)
            end
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

    -- Deduct MP and start cooldown (apply CooldownReduction + dynamic event modifiers)
    local dyn2 = getDynEvtMgr()
    local zeroMP    = dyn2 and dyn2.IsZeroMPCost()
    local cdEvtMult = dyn2 and dyn2.GetCooldownMult() or 1
    local mpEvtMult = dyn2 and dyn2.GetMPCostMult()  or 1
    if not zeroMP then
        state.MP = state.MP - math.floor(ab.MPCost * 0.5 * mpEvtMult)
    end
    if ab.Cooldown > 0 then
        local cdR = state.Stats.CooldownReduction or 0
        state.Cooldowns[abilityName] = math.max(0.5,
            ab.Cooldown * (1 - cdR) * cdEvtMult)
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

    -- Track last-used ability for evolution XP
    state.LastUsedAbility = abilityName

    -- Execute all effects (double-fire if VoidStorm dynamic event is active)
    local dyn3      = getDynEvtMgr()
    local doubleFire = dyn3 and dyn3.IsDoublefire()
    for _, effect in ipairs(ab.Effects) do
        executeEffect(effect, player, state, targetEnemy, aimDirection, abilityName, activeSynergies)
        if doubleFire then
            executeEffect(effect, player, state, targetEnemy, aimDirection, abilityName, activeSynergies)
        end
    end

    -- Broadcast cast event to all clients for VFX/SFX
    if AbilityCastEvt then
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        AbilityCastEvt:FireAllClients({
            AbilityName  = abilityName,
            CasterUserId = player.UserId,
            Position     = root and root.Position,
            Direction    = aimDirection,
            EvoStage     = (state.EvoStage and state.EvoStage[abilityName]) or 0,
        })
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
        -- Notify MetaProgression for bounty tracking (lazy require to avoid circular deps)
        local ok, MetaProg = pcall(require, script.Parent.MetaProgression)
        if ok and MetaProg and MetaProg.TrackBountyEvent then
            MetaProg.TrackBountyEvent(player, "AwakeningActivated", {})
        end
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
    local oldArchetype = state.Stats and state.Stats.Archetype
    state.Stats = CharacterStats.BuildStats(archetypeName, level)
    state.HP = state.Stats.MaxHP
    state.MP = state.Stats.MaxMP
    state.NightVeilReady  = (archetypeName == "Assassin")
    state.AwakeningGauge  = 0
    state.ComboCount      = 0
    state.LastHitTime     = 0
    state.IsDead          = false
    state.EvoXP           = {}
    state.EvoStage        = {}
    state.VoidStacks      = 0
    state.LastUsedAbility = nil
    state.Buffs["AwakeningActive"] = nil  -- clear any lingering awakening on re-init

    -- Reset known + active abilities on first init OR when archetype changes.
    -- On respawn with the same archetype (level > 1), preserve earned abilities.
    local archetypeChanged = oldArchetype ~= archetypeName
    local isFirstInit = #state.KnownAbilities == 0 or archetypeChanged
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
