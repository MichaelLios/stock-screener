-- AbilityInput.client.lua
-- Captures keyboard input for ability use and sends to server.
-- Blocks ability input while the Ability Book panel is open.

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UseAbility   = RemoteEvents:WaitForChild("UseAbility")

-- Active slots: Q/E/R/F/T = slots 1-5
local KeyBindings = {
    [Enum.KeyCode.Q] = 1,
    [Enum.KeyCode.E] = 2,
    [Enum.KeyCode.R] = 3,
    [Enum.KeyCode.F] = 4,
    [Enum.KeyCode.T] = 5,
}

-- Client-side cooldown tracking (visual only; server enforces real CDs)
local ClientCooldowns = {}  -- [slotIndex] = endTime
local ActiveSlots     = {}  -- [slotIndex] = abilityName (populated from UpdateHUD)

local function isAbilityBookOpen()
    local gui = player.PlayerGui:FindFirstChild("HUD")
    if not gui then return false end
    local book = gui:FindFirstChild("AbilityBook")
    return book and book.Visible or false
end

-- Sync active slots from server broadcasts
local UpdateHUD = RemoteEvents:WaitForChild("UpdateHUD")
UpdateHUD.OnClientEvent:Connect(function(data)
    if data.ActiveSlots then
        for i, name in ipairs(data.ActiveSlots) do
            ActiveSlots[i] = name or nil
        end
    end
end)

-- Target acquisition: raycast from camera centre toward mouse
local function getTargetEnemy()
    local cam   = workspace.CurrentCamera
    local mouse = player:GetMouse()
    local ray    = cam:ViewportPointToRay(mouse.X, mouse.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * 200, RaycastParams.new())
    if not result then return nil end
    local model = result.Instance:FindFirstAncestorWhichIsA("Model")
    if model and model:GetAttribute("IsEnemy") then
        return model:GetAttribute("EnemyId")
    end
    return nil
end

local function getAimDirection()
    local cam   = workspace.CurrentCamera
    local mouse = player:GetMouse()
    local dir   = cam:ViewportPointToRay(mouse.X, mouse.Y).Direction
    return { X = dir.X, Y = dir.Y, Z = dir.Z }
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or isAbilityBookOpen() then return end

    local slot = KeyBindings[input.KeyCode]
    if not slot then return end

    local abilityName = ActiveSlots[slot]
    if not abilityName then return end

    -- Client-side cooldown gate (visual only)
    local now = tick()
    if ClientCooldowns[slot] and now < ClientCooldowns[slot] then return end

    UseAbility:FireServer(abilityName, getTargetEnemy(), getAimDirection())

    -- Approximate local cooldown until server confirms
    local AbilitySystem = require(ReplicatedStorage.Modules.AbilitySystem)
    local ab = AbilitySystem.GetAbility(abilityName)
    if ab and ab.Cooldown > 0 then
        ClientCooldowns[slot] = now + ab.Cooldown
    end
end)

-- ── G key: Activate Awakening ────────────────────────────────────────────────
local ActivateAwakeningEvt = RemoteEvents:WaitForChild("ActivateAwakening", 15)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or isAbilityBookOpen() then return end
    if input.KeyCode == Enum.KeyCode.G then
        if ActivateAwakeningEvt then
            ActivateAwakeningEvt:FireServer()
        end
    end
end)

-- Consumable slots: Z = slot 1, X = slot 2
local ConsumableBindings = {
    [Enum.KeyCode.Z] = 1,
    [Enum.KeyCode.X] = 2,
}
local ConsumableSlots = {}

UpdateHUD.OnClientEvent:Connect(function(data)
    if data.ConsumableSlots then
        for i, name in ipairs(data.ConsumableSlots) do
            ConsumableSlots[i] = name
        end
    end
end)

local UseItem = nil
RunService.Stepped:Connect(function()
    if not UseItem then
        UseItem = RemoteEvents:FindFirstChild("UseItem")
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or isAbilityBookOpen() then return end
    local slot = ConsumableBindings[input.KeyCode]
    if not slot then return end
    local itemName = ConsumableSlots[slot]
    if not itemName or not UseItem then return end
    UseItem:FireServer(itemName)
end)
