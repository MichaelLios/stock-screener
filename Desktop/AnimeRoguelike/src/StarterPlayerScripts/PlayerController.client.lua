-- PlayerController.client.lua
-- Sprint (Shift) and dash (Q) with VFX. Separate from ability slots.

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")

-- Respawn support
player.CharacterAdded:Connect(function(char)
    character = char
    humanoid  = char:WaitForChild("Humanoid")
end)

local WALK_SPEED    = 16
local SPRINT_SPEED  = 30
local DASH_COOLDOWN = 0.6   -- seconds
local DASH_FORCE    = 150   -- studs per second burst

local sprinting    = false
local lastDash     = 0

-- ── Sprint ────────────────────────────────────────────────────────────────────

local function setSprint(active)
    sprinting = active
    if humanoid then
        humanoid.WalkSpeed = active and SPRINT_SPEED or WALK_SPEED
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        setSprint(true)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
        setSprint(false)
    end
end)

-- ── Dash VFX ─────────────────────────────────────────────────────────────────

local function spawnDashTrail()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- After-image flash
    for i = 1, 5 do
        task.spawn(function()
            task.wait(i * 0.03)
            local ghost = Instance.new("Part")
            ghost.Anchored     = true
            ghost.CanCollide   = false
            ghost.Size         = Vector3.new(2, 3, 1)
            ghost.CFrame       = root.CFrame
            ghost.Color        = Color3.fromRGB(0, 180, 255)
            ghost.Material     = Enum.Material.Neon
            ghost.Transparency = 0.3
            ghost.Parent       = workspace
            TweenService:Create(ghost, TweenInfo.new(0.25), {
                Transparency = 1,
                Size = Vector3.new(0.5, 0.5, 0.5),
            }):Play()
            game:GetService("Debris"):AddItem(ghost, 0.3)
        end)
    end

    -- Speed lines
    for _ = 1, 6 do
        task.spawn(function()
            local ln = Instance.new("Part")
            ln.Anchored   = true
            ln.CanCollide = false
            ln.Size       = Vector3.new(0.12, 0.12, math.random(3, 7))
            local offset  = Vector3.new(math.random(-2,2), math.random(-1,2), math.random(-3, 3))
            ln.CFrame     = root.CFrame * CFrame.new(offset)
            ln.Color      = Color3.fromRGB(100, 210, 255)
            ln.Material   = Enum.Material.Neon
            ln.Transparency = 0.1
            ln.Parent     = workspace
            TweenService:Create(ln, TweenInfo.new(0.18), {
                Transparency = 1,
                Size = Vector3.new(0.05, 0.05, 0.2),
            }):Play()
            game:GetService("Debris"):AddItem(ln, 0.22)
        end)
    end
end

-- ── Dash logic ────────────────────────────────────────────────────────────────

local function doDash()
    local now = tick()
    if now - lastDash < DASH_COOLDOWN then return end
    local char = player.Character
    if not char then return end
    local hum  = char:FindFirstChildWhichIsA("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    lastDash = now

    -- Determine dash direction
    local dir = hum.MoveDirection.Magnitude > 0.1
        and hum.MoveDirection
        or root.CFrame.LookVector

    -- Apply velocity via a short-lived BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.Velocity     = dir * DASH_FORCE + Vector3.new(0, 6, 0)
    bv.MaxForce     = Vector3.new(1e5, 1e5, 1e5)
    bv.P            = 1e4
    bv.Parent       = root
    game:GetService("Debris"):AddItem(bv, 0.22)

    spawnDashTrail()
end

ContextActionService:BindActionAtPriority("DashAction", function(_, inputState, _)
    if inputState ~= Enum.UserInputState.Begin then
        return Enum.ContextActionResult.Pass
    end
    doDash()
    return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.Default.Value + 100, Enum.KeyCode.Q)

print("[PlayerController] Sprint (Shift) and Dash (Q) loaded.")
