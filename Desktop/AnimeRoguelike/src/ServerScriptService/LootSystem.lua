-- LootSystem.server.lua
-- Handles item drops, pickup zones, inventory management, and shop stock.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

local ItemData = require(ReplicatedStorage.Modules.ItemData)

-- Lazy-loaded to avoid circular require (CombatSystem ← EnemyAI ← ... ← LootSystem)
local CombatSystem

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local LootDropEvt  = RemoteEvents:WaitForChild("LootDrop")
local UpdateHUD    = RemoteEvents:WaitForChild("UpdateHUD")

local LootSystem = {}

-- ────────────────────────────────────────────────
-- DROP A PHYSICAL LOOT ORB IN THE WORLD
-- ────────────────────────────────────────────────

function LootSystem.DropLoot(lootTableName, position, floor)
    local itemName = ItemData.RollLoot(lootTableName)
    if not itemName then return end

    local item = ItemData.Items[itemName]
    if not item then return end

    local rarity = ItemData.Rarity[item.Rarity]

    -- Create a glowing orb
    local orb = Instance.new("Part")
    orb.Name = "LootOrb_" .. itemName
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(1.5, 1.5, 1.5)
    orb.Color = rarity and rarity.Color or Color3.new(1,1,1)
    orb.Material = Enum.Material.Neon
    orb.Anchored = false
    orb.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))
    orb.CanCollide = false
    orb.Parent = workspace

    -- Floating animation via BodyPosition
    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(1e4, 1e4, 1e4)
    bp.P = 1000
    bp.Position = position + Vector3.new(0, 2, 0)
    bp.Parent = orb

    -- Store item name as attribute
    orb:SetAttribute("ItemName", itemName)
    orb:SetAttribute("Floor", floor)

    -- Label
    local bg = Instance.new("BillboardGui")
    bg.Size = UDim2.new(0, 150, 0, 30)
    bg.StudsOffset = Vector3.new(0, 1.5, 0)
    bg.AlwaysOnTop = false
    bg.Parent = orb
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = item.Name
    lbl.TextColor3 = rarity and rarity.Color or Color3.new(1,1,1)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = bg

    -- Pickup on touch
    local conn
    conn = orb.Touched:Connect(function(hit)
        local char = hit.Parent
        local player = Players:GetPlayerFromCharacter(char)
        if not player then return end
        conn:Disconnect()
        orb:Destroy()
        LootSystem.GiveItemToPlayer(player, itemName)
    end)

    -- Auto-despawn after 30 seconds
    Debris:AddItem(orb, 30)

    return orb
end

-- ────────────────────────────────────────────────
-- GIVE ITEM TO PLAYER
-- ────────────────────────────────────────────────

-- Player inventories: [player] = { [itemName] = count }
local Inventories = {}

Players.PlayerAdded:Connect(function(player)
    Inventories[player] = {}
end)
Players.PlayerRemoving:Connect(function(player)
    Inventories[player] = nil
end)

function LootSystem.GiveItemToPlayer(player, itemName)
    local inv = Inventories[player]
    if not inv then return end

    local item = ItemData.Items[itemName]
    if not item then return end

    if item.Stackable then
        inv[itemName] = math.min((inv[itemName] or 0) + 1, item.MaxStack or 99)
    else
        -- For non-stackable, just record ownership
        inv[itemName] = 1
    end

    -- Notify client
    LootDropEvt:FireClient(player, { ItemName = itemName, Item = item })

    -- Ability scrolls: teach the ability immediately on pickup
    if item.Type == "AbilityScroll" and item.AbilityName then
        if not CombatSystem then
            CombatSystem = require(game:GetService("ServerScriptService").CombatSystem)
        end
        local learned = CombatSystem.GrantAbility(player, item.AbilityName)
        if not learned then
            -- Already known — swap notification text
            LootDropEvt:FireClient(player, {
                ItemName = itemName,
                Item = { Name = item.Name .. " (already known)", Rarity = item.Rarity },
            })
            return  -- skip the regular loot notification below
        end
    end

    -- Auto-apply stat items
    if item.Type == "Weapon" or item.Type == "Armor" or item.Type == "Accessory" then
        local evt = ReplicatedStorage:FindFirstChild("_BindableItemApply")
        if evt then evt:Fire(player, item) end
    end

    print(("[LootSystem] %s received: %s (%s)"):format(player.Name, item.Name, item.Rarity))
end

function LootSystem.GetInventory(player)
    return Inventories[player] or {}
end

-- ────────────────────────────────────────────────
-- LOOT CHOICE GENERATION  (pick-1-of-3)
-- ────────────────────────────────────────────────

-- Returns up to `count` distinct weighted-random items from a loot table.
-- Used for Elite / Boss room-clear reward panels.
function LootSystem.GenerateLootChoices(lootTableName, floor, count)
    count = count or 3
    local pool = ItemData.LootTables[lootTableName]
    if not pool then return {} end

    -- Work on a shallow copy so we can remove picked entries without mutating the pool
    local entries = {}
    for _, e in ipairs(pool) do
        table.insert(entries, { Item = e.Item, Weight = e.Weight })
    end

    local choices = {}
    for _ = 1, count do
        if #entries == 0 then break end
        local total = 0
        for _, e in ipairs(entries) do total = total + e.Weight end
        local roll = math.random() * total
        local cum  = 0
        for i, e in ipairs(entries) do
            cum = cum + e.Weight
            if roll <= cum then
                local item = ItemData.Items[e.Item]
                if item then
                    table.insert(choices, { ItemName = e.Item, Item = item })
                end
                table.remove(entries, i)
                break
            end
        end
    end

    return choices
end

-- ────────────────────────────────────────────────
-- SHOP GENERATION
-- ────────────────────────────────────────────────

local function pickRandomItems(n)
    local allItems = {}
    for name, data in pairs(ItemData.Items) do
        table.insert(allItems, { Name = name, Data = data })
    end
    -- Shuffle
    for i = #allItems, 2, -1 do
        local j = math.random(i)
        allItems[i], allItems[j] = allItems[j], allItems[i]
    end
    local result = {}
    for i = 1, math.min(n, #allItems) do
        result[i] = allItems[i]
    end
    return result
end

-- Rarity multiplier for shop prices
local rarityPrice = {
    Common    = 20,
    Uncommon  = 60,
    Rare      = 150,
    Epic      = 300,
    Legendary = 600,
}

function LootSystem.GenerateShopStock(floor)
    local count = 4 + math.floor(floor / 5)  -- more items on deeper floors
    local picks = pickRandomItems(count)
    local stock = {}
    for _, pick in ipairs(picks) do
        local basePrice = rarityPrice[pick.Data.Rarity] or 30
        -- Floor scaling
        local price = math.floor(basePrice * (1 + (floor - 1) * 0.05))
        table.insert(stock, {
            ItemName = pick.Name,
            Item = pick.Data,
            Price = price,
        })
    end
    return stock
end

-- ────────────────────────────────────────────────
-- PURCHASE
-- ────────────────────────────────────────────────

function LootSystem.BuyItem(player, itemName, price, playerGold)
    if playerGold < price then return false, "Not enough gold" end
    local item = ItemData.Items[itemName]
    if not item then return false, "Unknown item" end
    LootSystem.GiveItemToPlayer(player, itemName)
    return true, playerGold - price
end

-- ────────────────────────────────────────────────
-- USE CONSUMABLE
-- ────────────────────────────────────────────────

-- Returns the use effect table or nil
function LootSystem.UseConsumable(player, itemName)
    local inv = Inventories[player]
    if not inv or not inv[itemName] or inv[itemName] <= 0 then return nil end

    local item = ItemData.Items[itemName]
    if not item or item.Type ~= "Consumable" then return nil end

    inv[itemName] = inv[itemName] - 1
    if inv[itemName] <= 0 then inv[itemName] = nil end

    -- Return the use effect; CombatSystem applies it
    return item.Use
end

return LootSystem
