-- PortalAnimator.client.lua
-- Finds all portal disc parts tagged IsPortalDisc and spins them
-- at individual speeds to create a swirling animated portal effect.

local RunService = game:GetService("RunService")

-- Wait for the world to finish building (the idempotency flag is set last)
local world = workspace:WaitForChild("DungeonPiece_World", 30)
if not world then return end

-- Collect all portal discs and their initial CFrames + accumulated angles
local discs = {}

local function collectDiscs()
    for _, part in ipairs(world:GetDescendants()) do
        if part:IsA("BasePart") and part:GetAttribute("IsPortalDisc") then
            table.insert(discs, {
                part        = part,
                initialCF   = part.CFrame,
                angle       = 0,
                speed       = part:GetAttribute("SpinSpeed") or 0.5,
            })
        end
    end
end

-- The world may still be building; retry briefly if no discs found
task.delay(2, function()
    collectDiscs()
    if #discs == 0 then
        task.delay(3, collectDiscs)
    end
end)

RunService.Heartbeat:Connect(function(dt)
    for _, d in ipairs(discs) do
        if d.part and d.part.Parent then
            d.angle = d.angle + d.speed * dt
            -- Rotate around the disc's own local Y axis (= world-Z after the 90° X tilt)
            -- This spins the disc face like a clock = swirling portal effect
            d.part.CFrame = d.initialCF * CFrame.Angles(0, d.angle, 0)
        end
    end
end)

print("[PortalAnimator] Loaded.")
