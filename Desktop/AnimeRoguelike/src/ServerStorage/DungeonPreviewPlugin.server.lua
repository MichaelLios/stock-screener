-- DungeonPreviewPlugin.server.lua
-- Studio plugin: "Build World" button rebuilds the full game map in edit mode.
-- Parts are real geometry saved with the .rbxl file — not temporary previews.
--
-- HOW TO INSTALL (one-time):
--   1. Sync this project with Rojo so the script appears in ServerStorage.
--   2. In Studio, right-click the script → "Save as Local Plugin".
--   3. A toolbar button "Build World" will appear at the top of Studio.

if not plugin then return end

local toolbar  = plugin:CreateToolbar("Dungeon Rooms")
local buildBtn = toolbar:CreateButton(
    "Build World",
    "Build / rebuild the full game world in edit mode",
    ""
)

buildBtn.Click:Connect(function()
    buildBtn:SetActive(true)
    local SSS = game:GetService("ServerScriptService")
    local mod = SSS:FindFirstChild("WorldBuilderModule")
    if mod then
        require(mod).Build(true)
    else
        warn("[DungeonPlugin] WorldBuilderModule not found in ServerScriptService — make sure Rojo is synced.")
    end
    buildBtn:SetActive(false)
end)
