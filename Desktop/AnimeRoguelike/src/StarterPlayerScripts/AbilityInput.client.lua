-- AbilityInput.client.lua
-- Captures keyboard input for ability use and sends to server.
-- Blocks ability input while the Ability Book panel is open.

local Players               = game:GetService("Players")
local UserInputService      = game:GetService("UserInputService")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local RunService            = game:GetService("RunService")

local player = Players.LocalPlayer

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local UseAbility   = RemoteEvents:WaitForChild("UseAbility")

-- Ability slots: number keys 1-5
local KeyBindings = {
    [Enum.KeyCode.One]   = 1,
    [Enum.KeyCode.Two]   = 2,
    [Enum.KeyCode.Three] = 3,
    [Enum.KeyCode.Four]  = 4,
    [Enum.KeyCode.Five]  = 5,
}

local ActiveSlots = {}  -- [slotIndex] = abilityName (populated from UpdateHUD)

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

local function fireAbilitySlot(slot)
    local abilityName = ActiveSlots[slot]
    if not abilityName then return end
    UseAbility:FireServer(abilityName, getTargetEnemy(), getAimDirection())
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or isAbilityBookOpen() then return end
    local slot = KeyBindings[input.KeyCode]
    if slot then
        fireAbilitySlot(slot)
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
