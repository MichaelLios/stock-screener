-- LocalGame.client.lua
-- Client-side game logic: door touch detection, room-enter notification, and VFX triggers.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local RemoteEvents  = ReplicatedStorage:WaitForChild("RemoteEvents")
local EnterRoom     = RemoteEvents:WaitForChild("EnterRoom")
local UpdateHUD     = RemoteEvents:WaitForChild("UpdateHUD")
local RoomCleared   = RemoteEvents:WaitForChild("RoomCleared")
local TakeDamage    = RemoteEvents:WaitForChild("TakeDamage")
local LootDropEvt   = RemoteEvents:WaitForChild("LootDrop")
local FloorComplete = RemoteEvents:WaitForChild("FloorComplete")
local PlayerDied    = RemoteEvents:WaitForChild("PlayerDied")

-- ────────────────────────────────────────────────
-- DOOR TOUCH DETECTION
-- ────────────────────────────────────────────────

local trackedDoors = {}

local function registerDoors(folder)
    for _, child in ipairs(folder:GetDescendants()) do
        if child:IsA("Part") and child.Name:find("Door_To_") then
            if not trackedDoors[child] then
                trackedDoors[child] = true
                child.Touched:Connect(function(hit)
                    local char = hit.Parent
                    if char == player.Character then
                        local targetRoomId = tonumber(child:FindFirstChild("TargetRoomId") and child.TargetRoomId.Value)
                        if targetRoomId then
                            EnterRoom:FireServer(targetRoomId)
                        end
                    end
                end)
            end
        end
    end
end

workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Folder") and obj.Name:find("Floor_") then
        task.wait(0.1)
        registerDoors(obj)
    end
end)

-- ────────────────────────────────────────────────
-- FLOOR TRANSITION SCREEN EFFECT
-- ────────────────────────────────────────────────

local screenGui = player.PlayerGui:WaitForChild("HUD", 10)

UpdateHUD.OnClientEvent:Connect(function(data)
    if data.FloorStart then
        -- Flash screen with theme name
        local gui = player.PlayerGui:FindFirstChild("HUD")
        if gui then
            local overlay = gui:FindFirstChild("FloorOverlay")
            if overlay then
                overlay.BackgroundTransparency = 0
                overlay.TextLabel.Text = "Floor " .. data.Floor .. "\n" .. data.ThemeName
                TweenService:Create(overlay, TweenInfo.new(2), { BackgroundTransparency = 1 }):Play()
            end
        end
    end

    if data.BossUnlocked then
        -- Screen flash red with message
        local gui = player.PlayerGui:FindFirstChild("HUD")
        if gui then
            local overlay = gui:FindFirstChild("FloorOverlay")
            if overlay then
                overlay.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
                overlay.BackgroundTransparency = 0.3
                overlay.TextLabel.Text = data.Message or "Boss Chamber Open!"
                TweenService:Create(overlay, TweenInfo.new(2), { BackgroundTransparency = 1 }):Play()
                task.delay(2, function()
                    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                end)
            end
        end
    end

    if data.LevelUp then
        local gui = player.PlayerGui:FindFirstChild("HUD")
        if gui then
            local overlay = gui:FindFirstChild("FloorOverlay")
            if overlay then
                overlay.BackgroundColor3 = Color3.fromRGB(240, 200, 0)
                overlay.BackgroundTransparency = 0.2
                overlay.TextLabel.Text = "LEVEL UP!\nLevel " .. data.Level
                TweenService:Create(overlay, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
                task.delay(1.5, function()
                    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                end)
            end
        end
    end

    if data.GameOver then
        local gui = player.PlayerGui:FindFirstChild("HUD")
        if gui then
            local overlay = gui:FindFirstChild("FloorOverlay")
            if overlay then
                overlay.BackgroundColor3 = Color3.fromRGB(20, 0, 0)
                overlay.BackgroundTransparency = 0
                overlay.TextLabel.Text = "DEFEATED\nYou reached Floor " .. (data.Floor or 1)
                TweenService:Create(overlay, TweenInfo.new(3), { BackgroundTransparency = 0.1 }):Play()
            end
        end
    end
end)

-- ────────────────────────────────────────────────
-- LOOT NOTIFICATION
-- ────────────────────────────────────────────────

LootDropEvt.OnClientEvent:Connect(function(data)
    local gui = player.PlayerGui:FindFirstChild("HUD")
    if not gui then return end
    local lootLabel = gui:FindFirstChild("LootNotification")
    if not lootLabel then return end

    local rarity = data.Item and data.Item.Rarity or "Common"
    local rarityColors = {
        Common    = Color3.fromRGB(200, 200, 200),
        Uncommon  = Color3.fromRGB(80, 200, 80),
        Rare      = Color3.fromRGB(60, 120, 240),
        Epic      = Color3.fromRGB(160, 60, 240),
        Legendary = Color3.fromRGB(240, 180, 40),
    }
    lootLabel.Text = "+ " .. (data.Item and data.Item.Name or data.ItemName)
    lootLabel.TextColor3 = rarityColors[rarity] or Color3.new(1,1,1)
    lootLabel.TextTransparency = 0
    TweenService:Create(lootLabel, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        TextTransparency = 1,
        Position = lootLabel.Position + UDim2.new(0, 0, -0.05, 0),
    }):Play()
    task.delay(2, function()
        lootLabel.Position = lootLabel.Position + UDim2.new(0, 0, 0.05, 0)
    end)
end)

-- ────────────────────────────────────────────────
-- FLOATING DAMAGE NUMBERS
-- ────────────────────────────────────────────────
-- Handled by CombatVFX.client.lua (typed colours, crits, sparks, screen shake).
-- Do not add a TakeDamage listener here — it would double-spawn numbers.

-- ────────────────────────────────────────────────
-- ROOM CLEARED EFFECT
-- ────────────────────────────────────────────────

RoomCleared.OnClientEvent:Connect(function(data)
    local gui = player.PlayerGui:FindFirstChild("HUD")
    if not gui then return end
    local overlay = gui:FindFirstChild("FloorOverlay")
    if not overlay then return end
    if data.PhaseChange then
        overlay.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
        overlay.TextLabel.Text = "PHASE " .. data.Phase .. "!"
        overlay.TextLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    elseif data.RoomType == "Boss" then
        overlay.BackgroundColor3 = Color3.fromRGB(30, 22, 0)
        overlay.TextLabel.Text = "BOSS DEFEATED!"
        overlay.TextLabel.TextColor3 = Color3.fromRGB(251, 191, 36)
    else
        overlay.BackgroundColor3 = Color3.fromRGB(0, 30, 14)
        overlay.TextLabel.Text = "Room Cleared!"
        overlay.TextLabel.TextColor3 = Color3.fromRGB(120, 230, 160)
    end
    overlay.BackgroundTransparency = 0.2
    TweenService:Create(overlay, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
    task.delay(1.2, function()
        overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        overlay.TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
end)

-- ────────────────────────────────────────────────
-- PLAYER DEATH: server fires this when custom HP hits 0;
-- client shows defeated overlay and fires back so the server can
-- run the respawn/reset logic.
-- ────────────────────────────────────────────────

PlayerDied.OnClientEvent:Connect(function()
    local gui = player.PlayerGui:FindFirstChild("HUD")
    if gui then
        local overlay = gui:FindFirstChild("FloorOverlay")
        if overlay then
            overlay.BackgroundColor3 = Color3.fromRGB(10, 0, 0)
            overlay.BackgroundTransparency = 0
            overlay.TextLabel.Text = "DEFEATED..."
            overlay.TextLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            TweenService:Create(overlay, TweenInfo.new(3), { BackgroundTransparency = 0.08 }):Play()
        end
    end
    -- Notify server so it runs the death/respawn handler
    task.wait(1)
    PlayerDied:FireServer()
end)

print("[LocalGame] Client ready.")
