-- ═══════════════════════════════════════════════════════════════
--   KissoHub — Survive the Apocalypse Module  |  v1.3.4
--   Author: pauloryankeith
--   Official: github.com/pauloryankeith/KissoHub
-- ═══════════════════════════════════════════════════════════════

local HttpService       = game:GetService("HttpService")
local Rayfield          = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local ASSET_ICON  = "rbxassetid://89387722763691"
local HUB_VERSION = "v1.3.4"
local SESSION_START = os.time()

-- =================================================================
-- SETTINGS
-- =================================================================
local Settings = {
    AutoShootEnabled   = false,
    AutoShootRange     = 500,
    SilentAimEnabled   = false,
    ShootDelay         = 0.05,
    IgnorePlayers      = true,
    CheckDamageable    = true,
}

local KillAuraEnabled     = false
local KillAuraRange       = 12
local MeleeAutoSwing      = false
local MeleeZeroWindUp     = false
local MeleeZeroEndlag     = false
local MeleeSpeedMult      = 1
local MeleeTargetPriority = "Nearest"
local AutoTargetSync      = false
local RemoteFastReload    = false
local InstantReload       = false
local AutoReloadEnabled   = false
local NoRecoilEnabled     = false
local NoSpreadEnabled     = false

local AutoLootEnabled     = false
local AutoLootRange       = 20
local AutoStoreEnabled    = false
local ProxFallbackEnabled = true
local LootRemotes = {
    PickUpItem      = nil,
    AdjustBackpack  = nil,
}

local InstantPromptsEnabled = false
local InstantPromptConn = nil

-- Backpack monitor
local BackpackAutoRefresh = true

-- =================================================================
-- DYNAMIC ITEM DATABASE
-- =================================================================
local ItemDatabase = {
    All        = {},
    ByCategory = {},
    Lookup     = {},
}

local CategoryColors = {
    Fuel          = Color3.fromRGB(255, 100, 100),
    Ammo          = Color3.fromRGB(255, 200, 40),
    Resources     = Color3.fromRGB(200, 200, 200),
    Food          = Color3.fromRGB(100, 255, 100),
    Armor         = Color3.fromRGB(100, 150, 255),
    Misc          = Color3.fromRGB(220, 100, 255),
    AlienCrystals = Color3.fromRGB(0, 255, 200),
    Tool_Backpacks        = Color3.fromRGB(180, 130, 90),
    Tool_CarAttachments   = Color3.fromRGB(120, 170, 220),
    Tool_Consumable       = Color3.fromRGB(255, 150, 50),
    Tool_Guns             = Color3.fromRGB(255, 90, 60),
    Tool_Medical          = Color3.fromRGB(255, 160, 200),
    Tool_Melee            = Color3.fromRGB(200, 60, 60),
    Tool_Misc             = Color3.fromRGB(180, 180, 200),
}

local function BuildItemDatabase()
    table.clear(ItemDatabase.All)
    table.clear(ItemDatabase.ByCategory)
    table.clear(ItemDatabase.Lookup)

    local Items = ReplicatedStorage:FindFirstChild("Items")
    if Items then
        for _, category in ipairs(Items:GetChildren()) do
            if category:IsA("Folder") then
                local catName = category.Name
                ItemDatabase.ByCategory[catName] = ItemDatabase.ByCategory[catName] or {}
                for _, item in ipairs(category:GetChildren()) do
                    if item:IsA("Model") then
                        table.insert(ItemDatabase.All, item.Name)
                        table.insert(ItemDatabase.ByCategory[catName], item.Name)
                        ItemDatabase.Lookup[item.Name] = catName
                    end
                end
            end
        end
    end

    local Tools = ReplicatedStorage:FindFirstChild("Tools")
    if Tools then
        for _, category in ipairs(Tools:GetChildren()) do
            if category:IsA("Folder") then
                local catName = "Tool_" .. category.Name
                ItemDatabase.ByCategory[catName] = ItemDatabase.ByCategory[catName] or {}
                for _, item in ipairs(category:GetChildren()) do
                    if item:IsA("Tool") or item:IsA("Model") then
                        table.insert(ItemDatabase.All, item.Name)
                        table.insert(ItemDatabase.ByCategory[catName], item.Name)
                        ItemDatabase.Lookup[item.Name] = catName
                    end
                end
            end
        end
    end

    table.sort(ItemDatabase.All)
    for _, list in pairs(ItemDatabase.ByCategory) do
        table.sort(list)
    end
    return #ItemDatabase.All > 0
end

BuildItemDatabase()

local SelectedLootItems = {}
local SelectedESPItems  = {}

-- =================================================================
-- SHARED FUNCTIONS
-- =================================================================
local function canBeDamaged(character)
    if not character then return false end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end
    if character:GetAttribute("Dead") or character:GetAttribute("Untargetable") then return false end
    if Settings.CheckDamageable then
        if character:FindFirstChildOfClass("ForceField") then return false end
        for _, attr in ipairs({"IsInvulnerable","Invulnerable","SafeZone","Protected","GodMode"}) do
            if character:GetAttribute(attr) == true then return false end
        end
    end
    return true
end

local function isZombieEnemy(character)
    if not character or character == LocalPlayer.Character then return false end
    if character:GetAttribute("Zombie") == true then return true end
    if character:GetAttribute("Player") == true then return false end
    if Settings.IgnorePlayers and Players:GetPlayerFromCharacter(character) then return false end
    return true
end

local function getTargetPart(character)
    if not character or not canBeDamaged(character) then return nil end
    return character:FindFirstChild("Head")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("HumanoidRootPart")
end

local function getLocalRootPosition()
    if LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Head")
        if hrp then return hrp.Position end
    end
    return Camera.CFrame.Position
end

local function getClosestZombie(customMaxDist, forceNearest)
    local maxDist = customMaxDist or Settings.AutoShootRange
    local myPos = getLocalRootPosition()
    local best, bestMetric = nil, math.huge

    local charsFolder = Workspace:FindFirstChild("Characters") or Workspace
    for _, char in ipairs(charsFolder:GetChildren()) do
        if char:IsA("Model") and isZombieEnemy(char) and canBeDamaged(char) then
            local part = getTargetPart(char)
            if part then
                local worldDist = (part.Position - myPos).Magnitude
                if maxDist == 0 or worldDist <= maxDist then
                    if worldDist < bestMetric then
                        best = part; bestMetric = worldDist
                    end
                end
            end
        end
    end
    return best
end

local function GetValidTargets()
    local targets = {}
    local charsFolder = Workspace:FindFirstChild("Characters") or Workspace
    for _, e in ipairs(charsFolder:GetChildren()) do
        if e:IsA("Model") and isZombieEnemy(e) and canBeDamaged(e) then table.insert(targets, e) end
    end
    return targets
end

local function ApplyNoRecoilSpread(tool)
    if not tool or not tool:IsA("Tool") then return end
    local stats = tool:FindFirstChild("Stats")
    if not stats then return end
    if NoRecoilEnabled then pcall(function() stats:SetAttribute("Recoil", 0) end) end
    if NoSpreadEnabled then pcall(function() stats:SetAttribute("Inaccuracy", 0) end) end
end

local function EnforceNoRecoilOnEquipped()
    if not (NoRecoilEnabled or NoSpreadEnabled) then return end
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool:GetAttribute("ToolType") == "Gun" then ApplyNoRecoilSpread(tool) end
end

local function ApplyMeleeStats(tool)
    if not tool or not tool:IsA("Tool") then return end
    local stats = tool:FindFirstChild("Stats")
    if not stats then return end
    if MeleeZeroWindUp then pcall(function() stats:SetAttribute("WindUp", 0) end) end
    if MeleeZeroEndlag then pcall(function() stats:SetAttribute("Endlag", 0) end) end
    if MeleeSpeedMult ~= 1 then
        pcall(function() stats:SetAttribute("AnimSpeed", (stats:GetAttribute("AnimSpeed") or 0.7) * MeleeSpeedMult) end)
    end
end

local function GetMeleeTargets()
    local myPos = getLocalRootPosition()
    local targets = {}
    local charsFolder = Workspace:FindFirstChild("Characters") or Workspace
    for _, char in ipairs(charsFolder:GetChildren()) do
        if char:IsA("Model") and isZombieEnemy(char) and canBeDamaged(char) then
            local pivot = char:GetPivot().Position
            local dist = (pivot - myPos).Magnitude
            if dist <= KillAuraRange then
                table.insert(targets, { model = char, dist = dist })
            end
        end
    end

    if MeleeTargetPriority == "Nearest" then
        table.sort(targets, function(a, b) return a.dist < b.dist end)
    elseif MeleeTargetPriority == "Lowest HP" then
        table.sort(targets, function(a, b)
            local ha = a.model:FindFirstChildOfClass("Humanoid")
            local hb = b.model:FindFirstChildOfClass("Humanoid")
            return (ha and ha.Health or 999) < (hb and hb.Health or 999)
        end)
    elseif MeleeTargetPriority == "Most Enemies" then
        table.sort(targets, function(a, b)
            local function crowdScore(t)
                local count = 0
                for _, other in ipairs(targets) do
                    if other.model ~= t.model and (other.model:GetPivot().Position - t.model:GetPivot().Position).Magnitude < 6 then
                        count += 1
                    end
                end
                return count
            end
            return crowdScore(a) > crowdScore(b)
        end)
    end

    local out = {}
    for _, t in ipairs(targets) do table.insert(out, t.model) end
    return out
end

local function ApplyInstantReload(tool)
    if not tool or not tool:IsA("Tool") then return end
    local stats = tool:FindFirstChild("Stats")
    if stats then
        pcall(function() stats:SetAttribute("ReloadTime", 0) end)
        pcall(function() stats:SetAttribute("ReloadAnimSpeed", 100) end)
    end
end

local function TriggerRemoteReload(tool)
    if not tool or not tool:IsA("Tool") then return end
    local reload = tool:FindFirstChild("Reload")
    if reload and reload:IsA("RemoteFunction") then pcall(function() reload:InvokeServer() end) end
    local sync = tool:FindFirstChild("SyncAmmo")
    if sync and sync:IsA("RemoteEvent") then pcall(function() sync:FireServer() end) end
end

local function ProcessTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    local toolType = tool:GetAttribute("ToolType")
    if toolType == "Gun" then
        if InstantReload then ApplyInstantReload(tool) end
        if RemoteFastReload then TriggerRemoteReload(tool) end
        if NoRecoilEnabled or NoSpreadEnabled then ApplyNoRecoilSpread(tool) end
    elseif toolType == "Melee" then
        ApplyMeleeStats(tool)
    end
end

local function ProcessAllTools()
    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then ProcessTool(item) end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then ProcessTool(item) end
        end
    end
end

local function ShouldLoot(itemName)
    if next(SelectedLootItems) == nil then return true end
    return SelectedLootItems[itemName] == true
end

local originalHoldDurations = {}

local function MakePromptInstant(prompt)
    if prompt:IsA("ProximityPrompt") then
        if originalHoldDurations[prompt] == nil then
            originalHoldDurations[prompt] = prompt.HoldDuration
        end
        pcall(function() prompt.HoldDuration = 0 end)
    end
end

local function ApplyInstantPrompts()
    for _, desc in ipairs(Workspace:GetDescendants()) do
        MakePromptInstant(desc)
    end
end

local function RestorePrompts()
    for prompt, orig in pairs(originalHoldDurations) do
        if prompt and prompt.Parent then
            pcall(function() prompt.HoldDuration = orig end)
        end
    end
end

-- =================================================================
-- BACKPACK STORAGE READER
-- =================================================================
local function ReadBackpackStorage()
    local bs = ReplicatedStorage:FindFirstChild("BackpackStorage")
    if not bs then return {}, 0, {} end
    local items = {}
    local byType = {}
    local total = 0

    for _, item in ipairs(bs:GetChildren()) do
        local itemType = item:GetAttribute("ItemType") or "Unknown"
        local info = {
            name = item.Name,
            type = itemType,
            attrs = item:GetAttributes(),
            model = item,
        }
        table.insert(items, info)
        byType[itemType] = (byType[itemType] or 0) + 1
        total += 1
    end

    table.sort(items, function(a, b)
        if a.type ~= b.type then return a.type < b.type end
        return a.name < b.name
    end)

    return items, total, byType
end

local function FormatItemDetails(info)
    local parts = {}
    for a, v in pairs(info.attrs) do
        if a ~= "ItemType" and a ~= "CanPickUp" then
            if typeof(v) == "number" then
                table.insert(parts, a .. "=" .. tostring(v))
            end
        end
    end
    if #parts > 0 then
        return info.name .. " (" .. table.concat(parts, ", ") .. ")"
    end
    return info.name
end

local function BuildBackpackConsoleText()
    local items, total, byType = ReadBackpackStorage()
    local lines = {}

    if total == 0 then
        return "📦 Backpack storage is empty"
    end

    table.insert(lines, "═════════════════════════════════════")
    table.insert(lines, "  🎒 BACKPACK CONTENTS — " .. total .. " items")
    table.insert(lines, "═════════════════════════════════════")

    -- Group by type
    local grouped = {}
    for _, item in ipairs(items) do
        grouped[item.type] = grouped[item.type] or {}
        table.insert(grouped[item.type], item)
    end

    local sortedTypes = {}
    for t, _ in pairs(grouped) do table.insert(sortedTypes, t) end
    table.sort(sortedTypes)

    for _, t in ipairs(sortedTypes) do
        local list = grouped[t]
        table.insert(lines, "")
        table.insert(lines, "▬ " .. t .. " (" .. #list .. ") ▬")
        for _, info in ipairs(list) do
            table.insert(lines, "  • " .. FormatItemDetails(info))
        end
    end

    return table.concat(lines, "\n")
end

-- =================================================================
-- WINDOW
-- =================================================================
local Window = Rayfield:CreateWindow({
    name = "KissoHub",
    subtitle = "Survive the Apocalypse",
    sidebarLayout = true,
    icon = ASSET_ICON,
    theme = {
        WindowColor = ColorSequence.new(Color3.fromRGB(15, 17, 26), Color3.fromRGB(10, 12, 18)),
        SurfaceStroke = Color3.fromRGB(0, 200, 255),
        TitlingColor = Color3.fromRGB(255, 255, 255),
        ContentColor = Color3.fromRGB(255, 255, 255),
        ElementTextHoverColor = Color3.fromRGB(255, 255, 255),
        ActionColor = Color3.fromRGB(0, 200, 255),
        TabColor = Color3.fromRGB(255, 255, 255),
        TabBackground = ColorSequence.new(Color3.fromRGB(25, 20, 38), Color3.fromRGB(16, 14, 24)),
        TabStroke = ColorSequence.new(Color3.fromRGB(0, 200, 255), Color3.fromRGB(190, 40, 220)),
        ElementGradient = ColorSequence.new(Color3.fromRGB(22, 20, 35), Color3.fromRGB(15, 14, 25)),
        ElementStroke = Color3.fromRGB(60, 45, 90),
        ElementStrokeHover = Color3.fromRGB(190, 40, 220),
        ElementTransparency = 0,
        StatBackground = Color3.fromRGB(20, 18, 30),
        AccentColor = Color3.fromRGB(190, 40, 220),
        AccentStroke = Color3.fromRGB(0, 200, 255),
        ToggleTrack = Color3.fromRGB(35, 30, 50),
        ToggleKnobOff = Color3.fromRGB(200, 200, 220),
        FieldBackground = Color3.fromRGB(25, 22, 38),
        PlaceholderColor = Color3.fromRGB(255, 255, 255),
        DropdownHighlight = Color3.fromRGB(190, 40, 220),
    },
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "STAPrefs",
        customFolder = "KissoHubFolder",
    },
})

local StatusTag = Window:CreateTag({ text = HUB_VERSION, color = Color3.fromRGB(0, 200, 255) })
local StateTag  = Window:CreateTag({ text = "IDLE",       color = Color3.fromRGB(190, 40, 220) })

local function SafeNotify(title, content, duration)
    pcall(function() Window:Notify({ title = title or "KissoHub", content = content or "", duration = duration or 4, icon = ASSET_ICON }) end)
end

local function QuickToast(title, subtitle)
    pcall(function() Window:Toast({ title = title, subtitle = subtitle, position = "Top", icon = ASSET_ICON }) end)
end

-- =================================================================
-- TABS
-- =================================================================
local HomeTab     = Window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })
local CombatTab   = Window:CreateTab({ name = "🔫 Gun Combat" })
local MeleeTab    = Window:CreateTab({ name = "⚔️ Melee" })
local ItemsTab    = Window:CreateTab({ name = "📦 Items" })
local BackpackTab = Window:CreateTab({ name = "🎒 Backpack" })
local ESPTab      = Window:CreateTab({ name = "👁️ ESP" })
local MiscTab     = Window:CreateTab({ name = "🛠️ Misc" })
local InfoTab     = Window:CreateTab({ name = "ℹ️ Info" })

-- =================================================================
-- HOME TAB
-- =================================================================
HomeTab:CreateSection({ name = "📊 Session Stats" })

local StatsGrid  = HomeTab:CreateGroup()
local StatsLeft  = StatsGrid:CreateGroup({ direction = "column" })
local StatsRight = StatsGrid:CreateGroup({ direction = "column" })

local SessionStat  = StatsLeft:CreateStat({ name = "⏱️ Session", value = 0, suffix = " m", compact = true })
local FpsStat      = StatsLeft:CreateStat({ name = "🎮 FPS", value = 0, compact = true })
local PlayersStat  = StatsLeft:CreateStat({ name = "👥 Players", value = 1, compact = true })
local KillsStat    = StatsLeft:CreateStat({ name = "💀 Kills", value = 0, compact = true })

local FeaturesStat = StatsRight:CreateStat({ name = "⚙️ Features", value = 0, compact = true })
local TargetsStat  = StatsRight:CreateStat({ name = "🧟 Targets", value = 0, compact = true })
local AmmoStat     = StatsRight:CreateStat({ name = "🔫 Ammo Pool", value = 0, compact = true })
local HealthStat   = StatsRight:CreateStat({ name = "❤️ Health", value = 100, compact = true })

HomeTab:CreateDivider({ text = "server" })
HomeTab:CreateSection({ name = "🌐 Server Utilities" })
HomeTab:CreateButton({
    name = "📋 Copy Job ID",
    callback = function()
        if setclipboard then setclipboard(game.JobId); QuickToast("Copied", "Job ID copied") end
    end,
})
HomeTab:CreateButton({
    name = "🔄 Rejoin Server",
    callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end,
})

-- =================================================================
-- GUN COMBAT TAB
-- =================================================================
CombatTab:CreateSection({ name = "🔫 Shooting" })

CombatTab:CreateToggle({ name = "Auto-Shoot Target", flag = "AutoShoot", value = false,
    callback = function(v) Settings.AutoShootEnabled = v end })

CombatTab:CreateSlider({ name = "Auto-Shoot Range", flag = "AutoShootRange",
    range = { 25, 1000 }, increment = 25, value = 500, suffix = " studs",
    callback = function(v) Settings.AutoShootRange = v end })

CombatTab:CreateToggle({ name = "Silent Aim", flag = "SilentAim", value = false,
    callback = function(v) Settings.SilentAimEnabled = v end })

CombatTab:CreateToggle({ name = "Ignore Human Players", flag = "IgnorePlayers", value = true,
    callback = function(v) Settings.IgnorePlayers = v end })

CombatTab:CreateToggle({ name = "Check Damageable / SafeZones", flag = "CheckDamageable", value = true,
    callback = function(v) Settings.CheckDamageable = v end })

CombatTab:CreateDivider({ text = "recoil & spread" })
CombatTab:CreateSection({ name = "🎯 No Recoil / No Spread" })

CombatTab:CreateToggle({ name = "No Recoil", flag = "NoRecoil", value = false,
    callback = function(v) NoRecoilEnabled = v; if v then ProcessAllTools() end end })

CombatTab:CreateToggle({ name = "No Spread", flag = "NoSpread", value = false,
    callback = function(v) NoSpreadEnabled = v; if v then ProcessAllTools() end end })

CombatTab:CreateButton({
    name = "🎯 Apply Now to Equipped Gun",
    callback = function()
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool and tool:GetAttribute("ToolType") == "Gun" then
            ApplyNoRecoilSpread(tool)
            QuickToast("Applied", "No Recoil/Spread → " .. tool.Name)
        else
            SafeNotify("No Gun", "Equip a gun first", 3)
        end
    end,
})

CombatTab:CreateDivider({ text = "reload" })
CombatTab:CreateSection({ name = "🔄 Reload" })

CombatTab:CreateToggle({ name = "Auto Reload (When Empty)", flag = "AutoReload", value = false,
    callback = function(v) AutoReloadEnabled = v end })

CombatTab:CreateToggle({ name = "Instant Reload", flag = "InstantReload", value = false,
    callback = function(v) InstantReload = v; if v then ProcessAllTools() end end })

CombatTab:CreateToggle({ name = "Remote Bypass Reload", flag = "RemoteReload", value = false,
    callback = function(v) RemoteFastReload = v; if v then ProcessAllTools() end end })

CombatTab:CreateButton({
    name = "Force Instant Reload",
    callback = function()
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then ApplyInstantReload(tool); TriggerRemoteReload(tool) end
    end,
})

CombatTab:CreateToggle({ name = "Auto-Sync Targets (Server Radar)", flag = "AutoTargetSync", value = false,
    callback = function(v) AutoTargetSync = v end })

-- =================================================================
-- MELEE TAB
-- =================================================================
MeleeTab:CreateSection({ name = "⚔️ Auto Combat" })

MeleeTab:CreateToggle({ name = "Auto Swing", flag = "MeleeAutoSwing", value = false,
    callback = function(v) MeleeAutoSwing = v; if v then QuickToast("Auto Swing", "Spamming attacks") end end })

MeleeTab:CreateToggle({ name = "Kill Aura", flag = "KillAura", value = false,
    callback = function(v) KillAuraEnabled = v; if v then QuickToast("Kill Aura", "Enabled") end end })

MeleeTab:CreateSlider({ name = "Kill Aura Range", flag = "KillAuraRange",
    range = { 4, 30 }, increment = 1, value = 12, suffix = " studs",
    callback = function(v) KillAuraRange = v end })

MeleeTab:CreateDropdown({ name = "Target Priority", flag = "MeleeTargetPriority",
    options = { "Nearest", "Lowest HP", "Most Enemies" }, value = { "Nearest" }, multiSelect = false,
    callback = function(o) MeleeTargetPriority = type(o) == "table" and o[1] or o end })

MeleeTab:CreateDivider({ text = "stats" })
MeleeTab:CreateSection({ name = "⚡ Melee Stats" })

MeleeTab:CreateToggle({ name = "Zero WindUp", flag = "MeleeZeroWindUp", value = false,
    callback = function(v) MeleeZeroWindUp = v; ProcessAllTools() end })
MeleeTab:CreateToggle({ name = "Zero Endlag", flag = "MeleeZeroEndlag", value = false,
    callback = function(v) MeleeZeroEndlag = v; ProcessAllTools() end })
MeleeTab:CreateSlider({ name = "Animation Speed Multiplier", flag = "MeleeSpeedMult",
    range = { 1, 5 }, increment = 0.5, value = 1, suffix = "x",
    callback = function(v) MeleeSpeedMult = v; ProcessAllTools() end })

MeleeTab:CreateButton({
    name = "⚔️ Apply Melee Stats Now",
    callback = function()
        ProcessAllTools()
        QuickToast("Applied", "Melee stats updated")
    end,
})

-- =================================================================
-- ITEMS TAB
-- =================================================================
ItemsTab:CreateSection({ name = "🎁 Auto Loot" })

ItemsTab:CreateToggle({ name = "Auto Loot (PickUpItem Remote)", flag = "AutoLoot", value = false,
    callback = function(v) AutoLootEnabled = v end })

ItemsTab:CreateSlider({ name = "Loot Range", flag = "AutoLootRange",
    range = { 5, 25 }, increment = 1, value = 20, suffix = " studs",
    callback = function(v) AutoLootRange = v end })

ItemsTab:CreateToggle({ name = "Auto-Store After Pickup", flag = "AutoStore", value = false,
    callback = function(v) AutoStoreEnabled = v end })

ItemsTab:CreateToggle({ name = "Use ProximityPrompt Fallback", flag = "ProxFallback", value = true,
    callback = function(v) ProxFallbackEnabled = v end })

ItemsTab:CreateDivider({ text = "filter" })
ItemsTab:CreateSection({ name = "🎯 Loot Filter (Multi-Select)" })

local LootFilterDropdown = ItemsTab:CreateDropdown({
    name = "Items to Auto-Loot",
    flag = "LootFilterItems",
    options = ItemDatabase.All,
    value = {},
    multiSelect = true,
    callback = function(selected)
        table.clear(SelectedLootItems)
        if type(selected) == "table" then
            for _, name in ipairs(selected) do
                SelectedLootItems[name] = true
            end
        end
    end,
})

ItemsTab:CreateDivider({ text = "presets" })
ItemsTab:CreateSection({ name = "⚡ Quick Select" })

local function SelectCategory(catName)
    local list = ItemDatabase.ByCategory[catName]
    if not list then SafeNotify("Not found", catName .. " missing", 2); return end
    table.clear(SelectedLootItems)
    for _, name in ipairs(list) do
        SelectedLootItems[name] = true
    end
    pcall(function() LootFilterDropdown:Set(list) end)
    QuickToast("Filter Applied", catName .. " (" .. #list .. ")")
end

local PresetGrid = ItemsTab:CreateGroup()
local PresetLeft = PresetGrid:CreateGroup({ direction = "column" })
local PresetRight = PresetGrid:CreateGroup({ direction = "column" })

PresetLeft:CreateButton({ name = "💥 All Ammo",       callback = function() SelectCategory("Ammo") end })
PresetLeft:CreateButton({ name = "🍞 All Food",       callback = function() SelectCategory("Food") end })
PresetLeft:CreateButton({ name = "🛡️ All Armor",      callback = function() SelectCategory("Armor") end })
PresetLeft:CreateButton({ name = "🔫 All Guns",       callback = function() SelectCategory("Tool_Guns") end })
PresetLeft:CreateButton({ name = "⚔️ All Melee",      callback = function() SelectCategory("Tool_Melee") end })
PresetLeft:CreateButton({ name = "💊 All Medical",    callback = function() SelectCategory("Tool_Medical") end })

PresetRight:CreateButton({ name = "⛽ All Fuel",       callback = function() SelectCategory("Fuel") end })
PresetRight:CreateButton({ name = "🔧 All Resources",  callback = function() SelectCategory("Resources") end })
PresetRight:CreateButton({ name = "💎 Alien Crystals", callback = function() SelectCategory("AlienCrystals") end })
PresetRight:CreateButton({ name = "🎒 All Backpacks",  callback = function() SelectCategory("Tool_Backpacks") end })
PresetRight:CreateButton({ name = "🚗 Car Attachments", callback = function() SelectCategory("Tool_CarAttachments") end })
PresetRight:CreateButton({ name = "🗑️ Clear Filter",    callback = function()
    table.clear(SelectedLootItems)
    pcall(function() LootFilterDropdown:Set({}) end)
    QuickToast("Cleared", "Looting everything")
end })

ItemsTab:CreateDivider({ text = "database" })
ItemsTab:CreateButton({
    name = "🔄 Refresh Item Database",
    callback = function()
        BuildItemDatabase()
        pcall(function() LootFilterDropdown:Refresh(ItemDatabase.All) end)
        QuickToast("Refreshed", #ItemDatabase.All .. " items")
    end,
})

ItemsTab:CreateText({
    name = "Database Info",
    text = "Items loaded: " .. #ItemDatabase.All .. "\n" ..
           "Categories: " .. (function() local n = 0; for _ in pairs(ItemDatabase.ByCategory) do n += 1 end return n end)(),
})

-- =================================================================
-- BACKPACK TAB (NEW)
-- =================================================================
BackpackTab:CreateSection({ name = "📊 Storage Overview" })

local BPTotalStat = BackpackTab:CreateStat({ name = "🎒 Total Items", value = 0, compact = true })
local BPFuelStat  = BackpackTab:CreateStat({ name = "⛽ Fuel",       value = 0, compact = true })
local BPFoodStat  = BackpackTab:CreateStat({ name = "🍞 Food",       value = 0, compact = true })
local BPResStat   = BackpackTab:CreateStat({ name = "🔧 Resources",  value = 0, compact = true })
local BPAmmoStat  = BackpackTab:CreateStat({ name = "💥 Ammo",       value = 0, compact = true })
local BPMiscStat  = BackpackTab:CreateStat({ name = "📦 Other",      value = 0, compact = true })

BackpackTab:CreateDivider({ text = "contents" })
BackpackTab:CreateSection({ name = "📋 Live Contents" })

local BackpackConsole = BackpackTab:CreateConsole({
    name = "Stored Items",
    height = 220,
    follow = false,
    maxLines = 300,
})

local function RefreshBackpackConsole()
    local text = BuildBackpackConsoleText()
    pcall(function() BackpackConsole:Set(text) end)
end

BackpackTab:CreateDivider({ text = "controls" })
BackpackTab:CreateSection({ name = "⚙️ Controls" })

BackpackTab:CreateButton({
    name = "🔄 Refresh Backpack Now",
    callback = function()
        RefreshBackpackConsole()
        QuickToast("Refreshed", "Backpack contents updated")
    end,
})

BackpackTab:CreateToggle({
    name = "Auto-Refresh (every 1s)",
    flag = "BackpackAutoRefresh",
    value = true,
    callback = function(v) BackpackAutoRefresh = v end,
})

BackpackTab:CreateButton({
    name = "📋 Copy Contents to Clipboard",
    callback = function()
        local text = BuildBackpackConsoleText()
        if setclipboard then
            setclipboard(text)
            QuickToast("Copied", "Backpack contents copied")
        end
    end,
})

BackpackTab:CreateText({
    name = "About this panel",
    text = "Reads ReplicatedStorage.BackpackStorage live.\n" ..
           "Shows all items stored in your backpack, grouped by ItemType.\n" ..
           "Auto-refreshes every 1 second when toggled on.",
})

-- =================================================================
-- ESP TAB
-- =================================================================
ESPTab:CreateSection({ name = "⚙️ ESP Config" })

local ESPConfig = { ShowNames = true, ShowDistance = true }

ESPTab:CreateToggle({ name = "Show Names", flag = "ESPNames", value = true,
    callback = function(v) ESPConfig.ShowNames = v end })
ESPTab:CreateToggle({ name = "Show Distance", flag = "ESPDistance", value = true,
    callback = function(v) ESPConfig.ShowDistance = v end })

ESPTab:CreateDivider({ text = "characters" })
ESPTab:CreateSection({ name = "👁️ Character ESP" })

local ESPState = {
    Zombie   = false,
    Player   = false,
    Survivor = false,
    Airdrop  = false,
    Items    = false,
}

local function CreateOrUpdateESP(target, tag, customName, color)
    if not target then return end
    local adornee = target:IsA("BasePart") and target
        or (target:IsA("Model") and (target.PrimaryPart or target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildOfClass("BasePart")))
    if not adornee then return end

    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local distText = ""
    if hrp and ESPConfig.ShowDistance then
        distText = string.format(" [%dm]", math.floor((hrp.Position - adornee.Position).Magnitude))
    end

    local baseName = customName or target.Name
    local display = ""
    if ESPConfig.ShowNames and ESPConfig.ShowDistance then display = baseName .. distText
    elseif ESPConfig.ShowNames then display = baseName
    elseif ESPConfig.ShowDistance then display = distText:gsub("^%s*", "") end

    local existing = adornee:FindFirstChild(tag)
    if existing then
        local lbl = existing:FindFirstChildOfClass("TextLabel")
        if lbl then
            lbl.Text = display
            lbl.TextColor3 = color or Color3.fromRGB(255,255,255)
            lbl.Visible = display ~= ""
        end
        return
    end

    local gui = Instance.new("BillboardGui")
    gui.Name = tag
    gui.Adornee = adornee
    gui.Size = UDim2.new(0, 200, 0, 30)
    gui.StudsOffset = Vector3.new(0, 2.5, 0)
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Parent = adornee

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = display
    lbl.Visible = display ~= ""
    lbl.TextColor3 = color or Color3.fromRGB(255,255,255)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.SourceSansBold
    lbl.Parent = gui
end

local function RemoveESP(parent, tag)
    if not parent then return end
    for _, item in ipairs(parent:GetDescendants()) do
        if item:IsA("BillboardGui") and item.Name == tag then item:Destroy() end
    end
end

ESPTab:CreateToggle({
    name = "Zombie ESP", flag = "ZombieESP", value = false,
    callback = function(v)
        ESPState.Zombie = v
        if not v then
            RemoveESP(Workspace:FindFirstChild("Characters"), "ZombieESP")
        else
            task.spawn(function()
                while ESPState.Zombie do
                    local chars = Workspace:FindFirstChild("Characters")
                    if chars then
                        for _, c in ipairs(chars:GetChildren()) do
                            if c:IsA("Model") and isZombieEnemy(c) and canBeDamaged(c) then
                                CreateOrUpdateESP(c, "ZombieESP", c.Name, Color3.fromRGB(255,50,50))
                            end
                        end
                    end
                    task.wait(0.2)
                end
            end)
        end
    end,
})

ESPTab:CreateToggle({
    name = "Player ESP", flag = "PlayerESP", value = false,
    callback = function(v)
        ESPState.Player = v
        if not v then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character then RemoveESP(p.Character, "PlayerESP") end
            end
        else
            task.spawn(function()
                while ESPState.Player do
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character then
                            CreateOrUpdateESP(p.Character, "PlayerESP", p.Name, Color3.fromRGB(50,150,255))
                        end
                    end
                    task.wait(0.2)
                end
            end)
        end
    end,
})

ESPTab:CreateToggle({
    name = "Survivor ESP", flag = "SurvivorESP", value = false,
    callback = function(v)
        ESPState.Survivor = v
        if not v then
            local map = Workspace:FindFirstChild("Map")
            local surv = map and map:FindFirstChild("Survivors")
            RemoveESP(surv, "SurvivorESP")
        else
            task.spawn(function()
                while ESPState.Survivor do
                    local map = Workspace:FindFirstChild("Map")
                    local surv = map and map:FindFirstChild("Survivors")
                    if surv then
                        for _, s in ipairs(surv:GetChildren()) do
                            if s:IsA("Model") then
                                CreateOrUpdateESP(s, "SurvivorESP", "Survivor: " .. s.Name, Color3.fromRGB(0, 255, 130))
                            end
                        end
                    end
                    task.wait(0.3)
                end
            end)
        end
    end,
})

ESPTab:CreateToggle({
    name = "Airdrop ESP", flag = "AirdropESP", value = false,
    callback = function(v)
        ESPState.Airdrop = v
        if not v then
            local map = Workspace:FindFirstChild("Map")
            local spec = map and map:FindFirstChild("Special")
            RemoveESP(spec, "AirdropESP")
        else
            task.spawn(function()
                while ESPState.Airdrop do
                    local map = Workspace:FindFirstChild("Map")
                    local spec = map and map:FindFirstChild("Special")
                    if spec then
                        for _, s in ipairs(spec:GetChildren()) do
                            if s:IsA("Model") or s:IsA("BasePart") then
                                CreateOrUpdateESP(s, "AirdropESP", "★ AIRDROP: " .. s.Name, Color3.fromRGB(255, 0, 200))
                            end
                        end
                    end
                    task.wait(0.3)
                end
            end)
        end
    end,
})

ESPTab:CreateDivider({ text = "items" })
ESPTab:CreateSection({ name = "📦 Item ESP" })

ESPTab:CreateToggle({
    name = "Enable Item ESP", flag = "ItemESPEnabled", value = false,
    callback = function(v)
        ESPState.Items = v
        if not v then
            RemoveESP(Workspace:FindFirstChild("DroppedItems"), "ItemESP")
        end
    end,
})

local ESPFilterDropdown = ESPTab:CreateDropdown({
    name = "Items to Highlight",
    flag = "ESPFilterItems",
    options = ItemDatabase.All,
    value = {},
    multiSelect = true,
    callback = function(selected)
        table.clear(SelectedESPItems)
        if type(selected) == "table" then
            for _, name in ipairs(selected) do
                SelectedESPItems[name] = true
            end
        end
    end,
})

ESPTab:CreateButton({
    name = "🔄 Refresh ESP Item List",
    callback = function()
        BuildItemDatabase()
        pcall(function() ESPFilterDropdown:Refresh(ItemDatabase.All) end)
        QuickToast("Refreshed", #ItemDatabase.All .. " items")
    end,
})

-- =================================================================
-- MISC TAB
-- =================================================================
MiscTab:CreateSection({ name = "🎨 Visuals" })

local FogConn, BrightnessConn, ZoomConn = nil, nil, nil

MiscTab:CreateToggle({
    name = "Remove Fog", flag = "RemoveFog", value = false,
    callback = function(v)
        if v then
            Lighting.FogEnd = 9e9
            local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
            if atmo then atmo.Density = 0 end
            FogConn = RunService.RenderStepped:Connect(function()
                Lighting.FogEnd = 9e9
                if atmo then atmo.Density = 0 end
            end)
        else
            if FogConn then FogConn:Disconnect(); FogConn = nil end
            Lighting.FogEnd = 1000
        end
    end,
})

MiscTab:CreateToggle({
    name = "Fullbright", flag = "Fullbright", value = false,
    callback = function(v)
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
            BrightnessConn = RunService.RenderStepped:Connect(function()
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.GlobalShadows = false
                Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
            end)
        else
            if BrightnessConn then BrightnessConn:Disconnect(); BrightnessConn = nil end
            Lighting.Brightness = 1
            Lighting.GlobalShadows = true
            Lighting.OutdoorAmbient = Color3.fromRGB(127,127,127)
        end
    end,
})

MiscTab:CreateToggle({
    name = "Infinite Zoom", flag = "InfZoom", value = false,
    callback = function(v)
        if v then
            LocalPlayer.CameraMaxZoomDistance = 99999
            ZoomConn = RunService.RenderStepped:Connect(function()
                if LocalPlayer.CameraMaxZoomDistance ~= 99999 then
                    LocalPlayer.CameraMaxZoomDistance = 99999
                end
            end)
        else
            if ZoomConn then ZoomConn:Disconnect(); ZoomConn = nil end
            LocalPlayer.CameraMaxZoomDistance = 128
        end
    end,
})

MiscTab:CreateDivider({ text = "interaction" })
MiscTab:CreateSection({ name = "⚡ Prompts" })

MiscTab:CreateToggle({
    name = "Instant Proximity Prompts", flag = "InstantPrompts", value = false,
    callback = function(v)
        InstantPromptsEnabled = v
        if v then
            ApplyInstantPrompts()
            if not InstantPromptConn then
                InstantPromptConn = Workspace.DescendantAdded:Connect(function(desc)
                    if InstantPromptsEnabled then
                        MakePromptInstant(desc)
                    end
                end)
            end
            QuickToast("Instant Prompts", "Enabled")
        else
            if InstantPromptConn then
                InstantPromptConn:Disconnect()
                InstantPromptConn = nil
            end
            RestorePrompts()
            QuickToast("Instant Prompts", "Disabled")
        end
    end,
})

-- =================================================================
-- INFO TAB
-- =================================================================
InfoTab:CreateSection({ name = "ℹ️ About" })
InfoTab:CreateText({
    name = "KissoHub — Survive the Apocalypse",
    text = "Version: " .. HUB_VERSION .. "\n" ..
           "Config: KissoHubFolder/STAPrefs.rfld",
})

InfoTab:CreateDivider({ text = "changelog" })
InfoTab:CreateSection({ name = "📋 Changelog" })
InfoTab:CreateText({
    name = HUB_VERSION .. " — Latest",
    text = "• NEW: 🎒 Backpack tab with live contents viewer\n" ..
           "• NEW: Console panel showing stored items grouped by type\n" ..
           "• NEW: Category breakdown stats (Fuel/Food/Res/Ammo)\n" ..
           "• NEW: Copy contents to clipboard button\n" ..
           "• NEW: Auto-refresh every 1 second (toggleable)",
})

InfoTab:CreateText({
    name = "v1.3.3",
    text = "• Survivor ESP + Airdrop ESP\n" ..
           "• Instant Proximity Prompts\n" ..
           "• Expanded item database (Tools folders)\n" ..
           "• Backpack storage monitor (counts)",
})

-- =================================================================
-- AUTO-SHOOT LOOP
-- =================================================================
task.spawn(function()
    while true do
        task.wait(Settings.ShootDelay)
        if Settings.AutoShootEnabled then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and tool:GetAttribute("ToolType") == "Gun" then
                    local shootRemote = tool:FindFirstChild("Shoot")
                    if shootRemote then
                        local myPos = getLocalRootPosition()
                        local targetPart = getClosestZombie(Settings.AutoShootRange, true)
                        if targetPart and targetPart.Parent then
                            local targetModel = targetPart.Parent
                            local targetPos = targetPart.Position
                            local syncAmmo = tool:FindFirstChild("SyncAmmo")
                            if syncAmmo then pcall(function() syncAmmo:FireServer() end) end
                            local payload = {{
                                Target = targetPos,
                                HitData = {{ HitChar = targetModel, HitPos = targetPos, HitPart = targetPart }},
                                EffectResults = {{ Origin = myPos, End = targetPos }}
                            }}
                            pcall(function() shootRemote:FireServer(myPos, payload, 0, 4) end)
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- MELEE LOOP
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if KillAuraEnabled or MeleeAutoSwing then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool and tool:GetAttribute("ToolType") == "Melee" then
                local swingRemote = tool:FindFirstChild("Swing")
                local hitTargets = tool:FindFirstChild("HitTargets")
                if swingRemote and hitTargets then
                    pcall(function() swingRemote:FireServer() end)
                    if KillAuraEnabled then
                        local targets = GetMeleeTargets()
                        if #targets > 0 then
                            task.wait(MeleeZeroWindUp and 0.05 or 0.3)
                            pcall(function() hitTargets:FireServer(targets) end)
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- ENHANCED LOOT LOOP
-- =================================================================
task.spawn(function()
    task.spawn(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
        if not remotes then return end
        local interaction = remotes:WaitForChild("Interaction", 5)
        if interaction then
            LootRemotes.PickUpItem = interaction:WaitForChild("PickUpItem", 5)
        end
        local toolsF = remotes:WaitForChild("Tools", 5)
        if toolsF then
            LootRemotes.AdjustBackpack = toolsF:WaitForChild("AdjustBackpack", 5)
        end
    end)

    while true do
        task.wait(0.3)
        if AutoLootEnabled then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local myPos = hrp.Position
                local dropped = Workspace:FindFirstChild("DroppedItems")
                if dropped and LootRemotes.PickUpItem then
                    for _, item in ipairs(dropped:GetChildren()) do
                        local pivot = item:GetPivot().Position
                        local dist = (pivot - myPos).Magnitude
                        if dist <= AutoLootRange and ShouldLoot(item.Name) then
                            pcall(function() LootRemotes.PickUpItem:FireServer(item) end)
                            task.wait(0.05)
                            if AutoStoreEnabled and LootRemotes.AdjustBackpack then
                                task.wait(0.15)
                                pcall(function() LootRemotes.AdjustBackpack:FireServer(item) end)
                            end
                        end
                    end
                end

                if ProxFallbackEnabled then
                    for _, prompt in ipairs(Workspace:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                            local parent = prompt.Parent
                            local pos = parent:IsA("BasePart") and parent.Position
                                or (parent:IsA("Model") and parent.PrimaryPart and parent.PrimaryPart.Position)
                            if pos and (pos - myPos).Magnitude <= AutoLootRange then
                                if fireproximityprompt then
                                    pcall(function() fireproximityprompt(prompt) end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- ITEM ESP LOOP
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.3)
        if ESPState.Items then
            local dropped = Workspace:FindFirstChild("DroppedItems")
            if dropped then
                for _, item in ipairs(dropped:GetChildren()) do
                    local itemName = item.Name
                    local hasFilter = next(SelectedESPItems) ~= nil
                    local shouldShow = (not hasFilter) or SelectedESPItems[itemName] == true

                    if shouldShow then
                        local cat = ItemDatabase.Lookup[itemName] or "Misc"
                        local color = CategoryColors[cat] or Color3.fromRGB(255, 255, 150)
                        CreateOrUpdateESP(item, "ItemESP", itemName, color)
                    else
                        local adornee = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
                        if adornee then
                            local existing = adornee:FindFirstChild("ItemESP")
                            if existing then existing:Destroy() end
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- BACKPACK MONITOR LOOP
-- =================================================================
task.spawn(function()
    local lastSnapshot = ""
    while true do
        task.wait(BackpackAutoRefresh and 1 or 5)
        if BackpackAutoRefresh then
            pcall(function()
                local items, total, byType = ReadBackpackStorage()
                BPTotalStat:Set(total)
                BPFuelStat:Set(byType.Fuel or 0)
                BPFoodStat:Set(byType.Food or 0)
                BPResStat:Set(byType.Resource or 0)
                BPAmmoStat:Set(byType.Ammo or 0)
                local other = 0
                for t, n in pairs(byType) do
                    if t ~= "Fuel" and t ~= "Food" and t ~= "Resource" and t ~= "Ammo" then
                        other += n
                    end
                end
                BPMiscStat:Set(other)

                -- Update console if content changed
                local snapshot = tostring(total) .. ":" .. tostring(#items)
                for _, info in ipairs(items) do
                    snapshot = snapshot .. "|" .. info.name
                end
                if snapshot ~= lastSnapshot then
                    lastSnapshot = snapshot
                    RefreshBackpackConsole()
                end
            end)
        end
    end
end)

-- =================================================================
-- SILENT AIM HOOK
-- =================================================================
if hookmetamethod and getnamecallmethod then
    pcall(function()
        local raw; raw = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if Settings.SilentAimEnabled and method == "FireServer" and tostring(self) == "Shoot" then
                local targetPart = getClosestZombie()
                if targetPart and targetPart.Parent then
                    local args = {...}
                    local targetModel = targetPart.Parent
                    local origin = args[1] or getLocalRootPosition()
                    local targetPos = targetPart.Position
                    args[2] = {{
                        Target = targetPos,
                        HitData = {{ HitChar = targetModel, HitPos = targetPos, HitPart = targetPart }},
                        EffectResults = {{ Origin = origin, End = targetPos }}
                    }}
                    return raw(self, table.unpack(args))
                end
            end
            return raw(self, ...)
        end)
    end)
end

-- =================================================================
-- SUPPORT LOOPS
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.1)
        if NoRecoilEnabled or NoSpreadEnabled then pcall(EnforceNoRecoilOnEquipped) end
    end
end)

task.spawn(function()
    while task.wait(0.2) do
        if AutoReloadEnabled then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool and tool:GetAttribute("ToolType") == "Gun" then
                local ammo = tool:GetAttribute("Ammo")
                if type(ammo) == "number" and ammo <= 0 then
                    if InstantReload then ApplyInstantReload(tool) end
                    TriggerRemoteReload(tool)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        if AutoTargetSync then
            local char = LocalPlayer.Character
            local atc = char and char:FindFirstChild("AutoTargetClient")
            local remote = atc and atc:FindFirstChild("UpdateNearbyTargets")
            if remote then
                local targets = GetValidTargets()
                if #targets > 0 then pcall(function() remote:FireServer(targets) end) end
            end
        end
    end
end)

-- =================================================================
-- LIVE REFRESH
-- =================================================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local mins = math.floor((os.time() - SESSION_START) / 60)
            local active = 0
            for _, t in ipairs({
                Settings.AutoShootEnabled, Settings.SilentAimEnabled,
                KillAuraEnabled, MeleeAutoSwing, MeleeZeroWindUp, MeleeZeroEndlag,
                NoRecoilEnabled, NoSpreadEnabled, AutoReloadEnabled,
                AutoLootEnabled, AutoStoreEnabled,
                ESPState.Items, ESPState.Zombie, ESPState.Player,
                ESPState.Survivor, ESPState.Airdrop,
                InstantPromptsEnabled
            }) do
                if t then active += 1 end
            end

            local targetCount = 0
            local chars = Workspace:FindFirstChild("Characters")
            if chars then
                for _, c in ipairs(chars:GetChildren()) do
                    if c:IsA("Model") and isZombieEnemy(c) and canBeDamaged(c) then targetCount += 1 end
                end
            end

            local ammoTotal = 0
            local ammoConf = LocalPlayer:FindFirstChild("Ammo")
            if ammoConf then
                for _, a in ipairs({"Long","Shells","Pistol","Medium"}) do
                    ammoTotal += (ammoConf:GetAttribute(a) or 0)
                end
            end

            local kills, health = 0, 100
            local ls = LocalPlayer:FindFirstChild("leaderstats")
            if ls then
                local k = ls:FindFirstChild("Kills")
                if k then kills = k.Value end
            end
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then health = math.floor(hum.Health) end
            end

            SessionStat:Set(mins)
            FeaturesStat:Set(active)
            FpsStat:Set(math.floor(Workspace:GetRealPhysicsFPS() or 60))
            PlayersStat:Set(#Players:GetPlayers())
            TargetsStat:Set(targetCount)
            AmmoStat:Set(ammoTotal)
            KillsStat:Set(kills)
            HealthStat:Set(health)

            if AutoLootEnabled then
                StateTag:Set({ text = "LOOTING", color = Color3.fromRGB(0, 200, 255) })
            elseif KillAuraEnabled or MeleeAutoSwing then
                StateTag:Set({ text = "MELEE", color = Color3.fromRGB(255, 130, 40) })
            elseif Settings.AutoShootEnabled then
                StateTag:Set({ text = "AUTO-SHOOT", color = Color3.fromRGB(255, 80, 80) })
            elseif active > 0 then
                StateTag:Set({ text = "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
            else
                StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
            end
        end)
    end
end)

SafeNotify("KissoHub", "Survive the Apocalypse " .. HUB_VERSION .. " loaded", 3)-- ═══════════════════════════════════════════════════════════════
--   KissoHub — Survive the Apocalypse Module  |  v1.3.4
--   Author: pauloryankeith
--   Official: github.com/pauloryankeith/KissoHub
-- ═══════════════════════════════════════════════════════════════

local HttpService       = game:GetService("HttpService")
local Rayfield          = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local ASSET_ICON  = "rbxassetid://89387722763691"
local HUB_VERSION = "v1.3.4"
local SESSION_START = os.time()

-- =================================================================
-- SETTINGS
-- =================================================================
local Settings = {
    AutoShootEnabled   = false,
    AutoShootRange     = 500,
    SilentAimEnabled   = false,
    ShootDelay         = 0.05,
    IgnorePlayers      = true,
    CheckDamageable    = true,
}

local KillAuraEnabled     = false
local KillAuraRange       = 12
local MeleeAutoSwing      = false
local MeleeZeroWindUp     = false
local MeleeZeroEndlag     = false
local MeleeSpeedMult      = 1
local MeleeTargetPriority = "Nearest"
local AutoTargetSync      = false
local RemoteFastReload    = false
local InstantReload       = false
local AutoReloadEnabled   = false
local NoRecoilEnabled     = false
local NoSpreadEnabled     = false

local AutoLootEnabled     = false
local AutoLootRange       = 20
local AutoStoreEnabled    = false
local ProxFallbackEnabled = true
local LootRemotes = {
    PickUpItem      = nil,
    AdjustBackpack  = nil,
}

local InstantPromptsEnabled = false
local InstantPromptConn = nil

-- Backpack monitor
local BackpackAutoRefresh = true

-- =================================================================
-- DYNAMIC ITEM DATABASE
-- =================================================================
local ItemDatabase = {
    All        = {},
    ByCategory = {},
    Lookup     = {},
}

local CategoryColors = {
    Fuel          = Color3.fromRGB(255, 100, 100),
    Ammo          = Color3.fromRGB(255, 200, 40),
    Resources     = Color3.fromRGB(200, 200, 200),
    Food          = Color3.fromRGB(100, 255, 100),
    Armor         = Color3.fromRGB(100, 150, 255),
    Misc          = Color3.fromRGB(220, 100, 255),
    AlienCrystals = Color3.fromRGB(0, 255, 200),
    Tool_Backpacks        = Color3.fromRGB(180, 130, 90),
    Tool_CarAttachments   = Color3.fromRGB(120, 170, 220),
    Tool_Consumable       = Color3.fromRGB(255, 150, 50),
    Tool_Guns             = Color3.fromRGB(255, 90, 60),
    Tool_Medical          = Color3.fromRGB(255, 160, 200),
    Tool_Melee            = Color3.fromRGB(200, 60, 60),
    Tool_Misc             = Color3.fromRGB(180, 180, 200),
}

local function BuildItemDatabase()
    table.clear(ItemDatabase.All)
    table.clear(ItemDatabase.ByCategory)
    table.clear(ItemDatabase.Lookup)

    local Items = ReplicatedStorage:FindFirstChild("Items")
    if Items then
        for _, category in ipairs(Items:GetChildren()) do
            if category:IsA("Folder") then
                local catName = category.Name
                ItemDatabase.ByCategory[catName] = ItemDatabase.ByCategory[catName] or {}
                for _, item in ipairs(category:GetChildren()) do
                    if item:IsA("Model") then
                        table.insert(ItemDatabase.All, item.Name)
                        table.insert(ItemDatabase.ByCategory[catName], item.Name)
                        ItemDatabase.Lookup[item.Name] = catName
                    end
                end
            end
        end
    end

    local Tools = ReplicatedStorage:FindFirstChild("Tools")
    if Tools then
        for _, category in ipairs(Tools:GetChildren()) do
            if category:IsA("Folder") then
                local catName = "Tool_" .. category.Name
                ItemDatabase.ByCategory[catName] = ItemDatabase.ByCategory[catName] or {}
                for _, item in ipairs(category:GetChildren()) do
                    if item:IsA("Tool") or item:IsA("Model") then
                        table.insert(ItemDatabase.All, item.Name)
                        table.insert(ItemDatabase.ByCategory[catName], item.Name)
                        ItemDatabase.Lookup[item.Name] = catName
                    end
                end
            end
        end
    end

    table.sort(ItemDatabase.All)
    for _, list in pairs(ItemDatabase.ByCategory) do
        table.sort(list)
    end
    return #ItemDatabase.All > 0
end

BuildItemDatabase()

local SelectedLootItems = {}
local SelectedESPItems  = {}

-- =================================================================
-- SHARED FUNCTIONS
-- =================================================================
local function canBeDamaged(character)
    if not character then return false end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end
    if character:GetAttribute("Dead") or character:GetAttribute("Untargetable") then return false end
    if Settings.CheckDamageable then
        if character:FindFirstChildOfClass("ForceField") then return false end
        for _, attr in ipairs({"IsInvulnerable","Invulnerable","SafeZone","Protected","GodMode"}) do
            if character:GetAttribute(attr) == true then return false end
        end
    end
    return true
end

local function isZombieEnemy(character)
    if not character or character == LocalPlayer.Character then return false end
    if character:GetAttribute("Zombie") == true then return true end
    if character:GetAttribute("Player") == true then return false end
    if Settings.IgnorePlayers and Players:GetPlayerFromCharacter(character) then return false end
    return true
end

local function getTargetPart(character)
    if not character or not canBeDamaged(character) then return nil end
    return character:FindFirstChild("Head")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("HumanoidRootPart")
end

local function getLocalRootPosition()
    if LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Head")
        if hrp then return hrp.Position end
    end
    return Camera.CFrame.Position
end

local function getClosestZombie(customMaxDist, forceNearest)
    local maxDist = customMaxDist or Settings.AutoShootRange
    local myPos = getLocalRootPosition()
    local best, bestMetric = nil, math.huge

    local charsFolder = Workspace:FindFirstChild("Characters") or Workspace
    for _, char in ipairs(charsFolder:GetChildren()) do
        if char:IsA("Model") and isZombieEnemy(char) and canBeDamaged(char) then
            local part = getTargetPart(char)
            if part then
                local worldDist = (part.Position - myPos).Magnitude
                if maxDist == 0 or worldDist <= maxDist then
                    if worldDist < bestMetric then
                        best = part; bestMetric = worldDist
                    end
                end
            end
        end
    end
    return best
end

local function GetValidTargets()
    local targets = {}
    local charsFolder = Workspace:FindFirstChild("Characters") or Workspace
    for _, e in ipairs(charsFolder:GetChildren()) do
        if e:IsA("Model") and isZombieEnemy(e) and canBeDamaged(e) then table.insert(targets, e) end
    end
    return targets
end

local function ApplyNoRecoilSpread(tool)
    if not tool or not tool:IsA("Tool") then return end
    local stats = tool:FindFirstChild("Stats")
    if not stats then return end
    if NoRecoilEnabled then pcall(function() stats:SetAttribute("Recoil", 0) end) end
    if NoSpreadEnabled then pcall(function() stats:SetAttribute("Inaccuracy", 0) end) end
end

local function EnforceNoRecoilOnEquipped()
    if not (NoRecoilEnabled or NoSpreadEnabled) then return end
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool:GetAttribute("ToolType") == "Gun" then ApplyNoRecoilSpread(tool) end
end

local function ApplyMeleeStats(tool)
    if not tool or not tool:IsA("Tool") then return end
    local stats = tool:FindFirstChild("Stats")
    if not stats then return end
    if MeleeZeroWindUp then pcall(function() stats:SetAttribute("WindUp", 0) end) end
    if MeleeZeroEndlag then pcall(function() stats:SetAttribute("Endlag", 0) end) end
    if MeleeSpeedMult ~= 1 then
        pcall(function() stats:SetAttribute("AnimSpeed", (stats:GetAttribute("AnimSpeed") or 0.7) * MeleeSpeedMult) end)
    end
end

local function GetMeleeTargets()
    local myPos = getLocalRootPosition()
    local targets = {}
    local charsFolder = Workspace:FindFirstChild("Characters") or Workspace
    for _, char in ipairs(charsFolder:GetChildren()) do
        if char:IsA("Model") and isZombieEnemy(char) and canBeDamaged(char) then
            local pivot = char:GetPivot().Position
            local dist = (pivot - myPos).Magnitude
            if dist <= KillAuraRange then
                table.insert(targets, { model = char, dist = dist })
            end
        end
    end

    if MeleeTargetPriority == "Nearest" then
        table.sort(targets, function(a, b) return a.dist < b.dist end)
    elseif MeleeTargetPriority == "Lowest HP" then
        table.sort(targets, function(a, b)
            local ha = a.model:FindFirstChildOfClass("Humanoid")
            local hb = b.model:FindFirstChildOfClass("Humanoid")
            return (ha and ha.Health or 999) < (hb and hb.Health or 999)
        end)
    elseif MeleeTargetPriority == "Most Enemies" then
        table.sort(targets, function(a, b)
            local function crowdScore(t)
                local count = 0
                for _, other in ipairs(targets) do
                    if other.model ~= t.model and (other.model:GetPivot().Position - t.model:GetPivot().Position).Magnitude < 6 then
                        count += 1
                    end
                end
                return count
            end
            return crowdScore(a) > crowdScore(b)
        end)
    end

    local out = {}
    for _, t in ipairs(targets) do table.insert(out, t.model) end
    return out
end

local function ApplyInstantReload(tool)
    if not tool or not tool:IsA("Tool") then return end
    local stats = tool:FindFirstChild("Stats")
    if stats then
        pcall(function() stats:SetAttribute("ReloadTime", 0) end)
        pcall(function() stats:SetAttribute("ReloadAnimSpeed", 100) end)
    end
end

local function TriggerRemoteReload(tool)
    if not tool or not tool:IsA("Tool") then return end
    local reload = tool:FindFirstChild("Reload")
    if reload and reload:IsA("RemoteFunction") then pcall(function() reload:InvokeServer() end) end
    local sync = tool:FindFirstChild("SyncAmmo")
    if sync and sync:IsA("RemoteEvent") then pcall(function() sync:FireServer() end) end
end

local function ProcessTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    local toolType = tool:GetAttribute("ToolType")
    if toolType == "Gun" then
        if InstantReload then ApplyInstantReload(tool) end
        if RemoteFastReload then TriggerRemoteReload(tool) end
        if NoRecoilEnabled or NoSpreadEnabled then ApplyNoRecoilSpread(tool) end
    elseif toolType == "Melee" then
        ApplyMeleeStats(tool)
    end
end

local function ProcessAllTools()
    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then ProcessTool(item) end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then ProcessTool(item) end
        end
    end
end

local function ShouldLoot(itemName)
    if next(SelectedLootItems) == nil then return true end
    return SelectedLootItems[itemName] == true
end

local originalHoldDurations = {}

local function MakePromptInstant(prompt)
    if prompt:IsA("ProximityPrompt") then
        if originalHoldDurations[prompt] == nil then
            originalHoldDurations[prompt] = prompt.HoldDuration
        end
        pcall(function() prompt.HoldDuration = 0 end)
    end
end

local function ApplyInstantPrompts()
    for _, desc in ipairs(Workspace:GetDescendants()) do
        MakePromptInstant(desc)
    end
end

local function RestorePrompts()
    for prompt, orig in pairs(originalHoldDurations) do
        if prompt and prompt.Parent then
            pcall(function() prompt.HoldDuration = orig end)
        end
    end
end

-- =================================================================
-- BACKPACK STORAGE READER
-- =================================================================
local function ReadBackpackStorage()
    local bs = ReplicatedStorage:FindFirstChild("BackpackStorage")
    if not bs then return {}, 0, {} end
    local items = {}
    local byType = {}
    local total = 0

    for _, item in ipairs(bs:GetChildren()) do
        local itemType = item:GetAttribute("ItemType") or "Unknown"
        local info = {
            name = item.Name,
            type = itemType,
            attrs = item:GetAttributes(),
            model = item,
        }
        table.insert(items, info)
        byType[itemType] = (byType[itemType] or 0) + 1
        total += 1
    end

    table.sort(items, function(a, b)
        if a.type ~= b.type then return a.type < b.type end
        return a.name < b.name
    end)

    return items, total, byType
end

local function FormatItemDetails(info)
    local parts = {}
    for a, v in pairs(info.attrs) do
        if a ~= "ItemType" and a ~= "CanPickUp" then
            if typeof(v) == "number" then
                table.insert(parts, a .. "=" .. tostring(v))
            end
        end
    end
    if #parts > 0 then
        return info.name .. " (" .. table.concat(parts, ", ") .. ")"
    end
    return info.name
end

local function BuildBackpackConsoleText()
    local items, total, byType = ReadBackpackStorage()
    local lines = {}

    if total == 0 then
        return "📦 Backpack storage is empty"
    end

    table.insert(lines, "═════════════════════════════════════")
    table.insert(lines, "  🎒 BACKPACK CONTENTS — " .. total .. " items")
    table.insert(lines, "═════════════════════════════════════")

    -- Group by type
    local grouped = {}
    for _, item in ipairs(items) do
        grouped[item.type] = grouped[item.type] or {}
        table.insert(grouped[item.type], item)
    end

    local sortedTypes = {}
    for t, _ in pairs(grouped) do table.insert(sortedTypes, t) end
    table.sort(sortedTypes)

    for _, t in ipairs(sortedTypes) do
        local list = grouped[t]
        table.insert(lines, "")
        table.insert(lines, "▬ " .. t .. " (" .. #list .. ") ▬")
        for _, info in ipairs(list) do
            table.insert(lines, "  • " .. FormatItemDetails(info))
        end
    end

    return table.concat(lines, "\n")
end

-- =================================================================
-- WINDOW
-- =================================================================
local Window = Rayfield:CreateWindow({
    name = "KissoHub",
    subtitle = "Survive the Apocalypse",
    sidebarLayout = true,
    icon = ASSET_ICON,
    theme = {
        WindowColor = ColorSequence.new(Color3.fromRGB(15, 17, 26), Color3.fromRGB(10, 12, 18)),
        SurfaceStroke = Color3.fromRGB(0, 200, 255),
        TitlingColor = Color3.fromRGB(255, 255, 255),
        ContentColor = Color3.fromRGB(255, 255, 255),
        ElementTextHoverColor = Color3.fromRGB(255, 255, 255),
        ActionColor = Color3.fromRGB(0, 200, 255),
        TabColor = Color3.fromRGB(255, 255, 255),
        TabBackground = ColorSequence.new(Color3.fromRGB(25, 20, 38), Color3.fromRGB(16, 14, 24)),
        TabStroke = ColorSequence.new(Color3.fromRGB(0, 200, 255), Color3.fromRGB(190, 40, 220)),
        ElementGradient = ColorSequence.new(Color3.fromRGB(22, 20, 35), Color3.fromRGB(15, 14, 25)),
        ElementStroke = Color3.fromRGB(60, 45, 90),
        ElementStrokeHover = Color3.fromRGB(190, 40, 220),
        ElementTransparency = 0,
        StatBackground = Color3.fromRGB(20, 18, 30),
        AccentColor = Color3.fromRGB(190, 40, 220),
        AccentStroke = Color3.fromRGB(0, 200, 255),
        ToggleTrack = Color3.fromRGB(35, 30, 50),
        ToggleKnobOff = Color3.fromRGB(200, 200, 220),
        FieldBackground = Color3.fromRGB(25, 22, 38),
        PlaceholderColor = Color3.fromRGB(255, 255, 255),
        DropdownHighlight = Color3.fromRGB(190, 40, 220),
    },
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "STAPrefs",
        customFolder = "KissoHubFolder",
    },
})

local StatusTag = Window:CreateTag({ text = HUB_VERSION, color = Color3.fromRGB(0, 200, 255) })
local StateTag  = Window:CreateTag({ text = "IDLE",       color = Color3.fromRGB(190, 40, 220) })

local function SafeNotify(title, content, duration)
    pcall(function() Window:Notify({ title = title or "KissoHub", content = content or "", duration = duration or 4, icon = ASSET_ICON }) end)
end

local function QuickToast(title, subtitle)
    pcall(function() Window:Toast({ title = title, subtitle = subtitle, position = "Top", icon = ASSET_ICON }) end)
end

-- =================================================================
-- TABS
-- =================================================================
local HomeTab     = Window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })
local CombatTab   = Window:CreateTab({ name = "🔫 Gun Combat" })
local MeleeTab    = Window:CreateTab({ name = "⚔️ Melee" })
local ItemsTab    = Window:CreateTab({ name = "📦 Items" })
local BackpackTab = Window:CreateTab({ name = "🎒 Backpack" })
local ESPTab      = Window:CreateTab({ name = "👁️ ESP" })
local MiscTab     = Window:CreateTab({ name = "🛠️ Misc" })
local InfoTab     = Window:CreateTab({ name = "ℹ️ Info" })

-- =================================================================
-- HOME TAB
-- =================================================================
HomeTab:CreateSection({ name = "📊 Session Stats" })

local StatsGrid  = HomeTab:CreateGroup()
local StatsLeft  = StatsGrid:CreateGroup({ direction = "column" })
local StatsRight = StatsGrid:CreateGroup({ direction = "column" })

local SessionStat  = StatsLeft:CreateStat({ name = "⏱️ Session", value = 0, suffix = " m", compact = true })
local FpsStat      = StatsLeft:CreateStat({ name = "🎮 FPS", value = 0, compact = true })
local PlayersStat  = StatsLeft:CreateStat({ name = "👥 Players", value = 1, compact = true })
local KillsStat    = StatsLeft:CreateStat({ name = "💀 Kills", value = 0, compact = true })

local FeaturesStat = StatsRight:CreateStat({ name = "⚙️ Features", value = 0, compact = true })
local TargetsStat  = StatsRight:CreateStat({ name = "🧟 Targets", value = 0, compact = true })
local AmmoStat     = StatsRight:CreateStat({ name = "🔫 Ammo Pool", value = 0, compact = true })
local HealthStat   = StatsRight:CreateStat({ name = "❤️ Health", value = 100, compact = true })

HomeTab:CreateDivider({ text = "server" })
HomeTab:CreateSection({ name = "🌐 Server Utilities" })
HomeTab:CreateButton({
    name = "📋 Copy Job ID",
    callback = function()
        if setclipboard then setclipboard(game.JobId); QuickToast("Copied", "Job ID copied") end
    end,
})
HomeTab:CreateButton({
    name = "🔄 Rejoin Server",
    callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end,
})

-- =================================================================
-- GUN COMBAT TAB
-- =================================================================
CombatTab:CreateSection({ name = "🔫 Shooting" })

CombatTab:CreateToggle({ name = "Auto-Shoot Target", flag = "AutoShoot", value = false,
    callback = function(v) Settings.AutoShootEnabled = v end })

CombatTab:CreateSlider({ name = "Auto-Shoot Range", flag = "AutoShootRange",
    range = { 25, 1000 }, increment = 25, value = 500, suffix = " studs",
    callback = function(v) Settings.AutoShootRange = v end })

CombatTab:CreateToggle({ name = "Silent Aim", flag = "SilentAim", value = false,
    callback = function(v) Settings.SilentAimEnabled = v end })

CombatTab:CreateToggle({ name = "Ignore Human Players", flag = "IgnorePlayers", value = true,
    callback = function(v) Settings.IgnorePlayers = v end })

CombatTab:CreateToggle({ name = "Check Damageable / SafeZones", flag = "CheckDamageable", value = true,
    callback = function(v) Settings.CheckDamageable = v end })

CombatTab:CreateDivider({ text = "recoil & spread" })
CombatTab:CreateSection({ name = "🎯 No Recoil / No Spread" })

CombatTab:CreateToggle({ name = "No Recoil", flag = "NoRecoil", value = false,
    callback = function(v) NoRecoilEnabled = v; if v then ProcessAllTools() end end })

CombatTab:CreateToggle({ name = "No Spread", flag = "NoSpread", value = false,
    callback = function(v) NoSpreadEnabled = v; if v then ProcessAllTools() end end })

CombatTab:CreateButton({
    name = "🎯 Apply Now to Equipped Gun",
    callback = function()
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool and tool:GetAttribute("ToolType") == "Gun" then
            ApplyNoRecoilSpread(tool)
            QuickToast("Applied", "No Recoil/Spread → " .. tool.Name)
        else
            SafeNotify("No Gun", "Equip a gun first", 3)
        end
    end,
})

CombatTab:CreateDivider({ text = "reload" })
CombatTab:CreateSection({ name = "🔄 Reload" })

CombatTab:CreateToggle({ name = "Auto Reload (When Empty)", flag = "AutoReload", value = false,
    callback = function(v) AutoReloadEnabled = v end })

CombatTab:CreateToggle({ name = "Instant Reload", flag = "InstantReload", value = false,
    callback = function(v) InstantReload = v; if v then ProcessAllTools() end end })

CombatTab:CreateToggle({ name = "Remote Bypass Reload", flag = "RemoteReload", value = false,
    callback = function(v) RemoteFastReload = v; if v then ProcessAllTools() end end })

CombatTab:CreateButton({
    name = "Force Instant Reload",
    callback = function()
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then ApplyInstantReload(tool); TriggerRemoteReload(tool) end
    end,
})

CombatTab:CreateToggle({ name = "Auto-Sync Targets (Server Radar)", flag = "AutoTargetSync", value = false,
    callback = function(v) AutoTargetSync = v end })

-- =================================================================
-- MELEE TAB
-- =================================================================
MeleeTab:CreateSection({ name = "⚔️ Auto Combat" })

MeleeTab:CreateToggle({ name = "Auto Swing", flag = "MeleeAutoSwing", value = false,
    callback = function(v) MeleeAutoSwing = v; if v then QuickToast("Auto Swing", "Spamming attacks") end end })

MeleeTab:CreateToggle({ name = "Kill Aura", flag = "KillAura", value = false,
    callback = function(v) KillAuraEnabled = v; if v then QuickToast("Kill Aura", "Enabled") end end })

MeleeTab:CreateSlider({ name = "Kill Aura Range", flag = "KillAuraRange",
    range = { 4, 30 }, increment = 1, value = 12, suffix = " studs",
    callback = function(v) KillAuraRange = v end })

MeleeTab:CreateDropdown({ name = "Target Priority", flag = "MeleeTargetPriority",
    options = { "Nearest", "Lowest HP", "Most Enemies" }, value = { "Nearest" }, multiSelect = false,
    callback = function(o) MeleeTargetPriority = type(o) == "table" and o[1] or o end })

MeleeTab:CreateDivider({ text = "stats" })
MeleeTab:CreateSection({ name = "⚡ Melee Stats" })

MeleeTab:CreateToggle({ name = "Zero WindUp", flag = "MeleeZeroWindUp", value = false,
    callback = function(v) MeleeZeroWindUp = v; ProcessAllTools() end })
MeleeTab:CreateToggle({ name = "Zero Endlag", flag = "MeleeZeroEndlag", value = false,
    callback = function(v) MeleeZeroEndlag = v; ProcessAllTools() end })
MeleeTab:CreateSlider({ name = "Animation Speed Multiplier", flag = "MeleeSpeedMult",
    range = { 1, 5 }, increment = 0.5, value = 1, suffix = "x",
    callback = function(v) MeleeSpeedMult = v; ProcessAllTools() end })

MeleeTab:CreateButton({
    name = "⚔️ Apply Melee Stats Now",
    callback = function()
        ProcessAllTools()
        QuickToast("Applied", "Melee stats updated")
    end,
})

-- =================================================================
-- ITEMS TAB
-- =================================================================
ItemsTab:CreateSection({ name = "🎁 Auto Loot" })

ItemsTab:CreateToggle({ name = "Auto Loot (PickUpItem Remote)", flag = "AutoLoot", value = false,
    callback = function(v) AutoLootEnabled = v end })

ItemsTab:CreateSlider({ name = "Loot Range", flag = "AutoLootRange",
    range = { 5, 25 }, increment = 1, value = 20, suffix = " studs",
    callback = function(v) AutoLootRange = v end })

ItemsTab:CreateToggle({ name = "Auto-Store After Pickup", flag = "AutoStore", value = false,
    callback = function(v) AutoStoreEnabled = v end })

ItemsTab:CreateToggle({ name = "Use ProximityPrompt Fallback", flag = "ProxFallback", value = true,
    callback = function(v) ProxFallbackEnabled = v end })

ItemsTab:CreateDivider({ text = "filter" })
ItemsTab:CreateSection({ name = "🎯 Loot Filter (Multi-Select)" })

local LootFilterDropdown = ItemsTab:CreateDropdown({
    name = "Items to Auto-Loot",
    flag = "LootFilterItems",
    options = ItemDatabase.All,
    value = {},
    multiSelect = true,
    callback = function(selected)
        table.clear(SelectedLootItems)
        if type(selected) == "table" then
            for _, name in ipairs(selected) do
                SelectedLootItems[name] = true
            end
        end
    end,
})

ItemsTab:CreateDivider({ text = "presets" })
ItemsTab:CreateSection({ name = "⚡ Quick Select" })

local function SelectCategory(catName)
    local list = ItemDatabase.ByCategory[catName]
    if not list then SafeNotify("Not found", catName .. " missing", 2); return end
    table.clear(SelectedLootItems)
    for _, name in ipairs(list) do
        SelectedLootItems[name] = true
    end
    pcall(function() LootFilterDropdown:Set(list) end)
    QuickToast("Filter Applied", catName .. " (" .. #list .. ")")
end

local PresetGrid = ItemsTab:CreateGroup()
local PresetLeft = PresetGrid:CreateGroup({ direction = "column" })
local PresetRight = PresetGrid:CreateGroup({ direction = "column" })

PresetLeft:CreateButton({ name = "💥 All Ammo",       callback = function() SelectCategory("Ammo") end })
PresetLeft:CreateButton({ name = "🍞 All Food",       callback = function() SelectCategory("Food") end })
PresetLeft:CreateButton({ name = "🛡️ All Armor",      callback = function() SelectCategory("Armor") end })
PresetLeft:CreateButton({ name = "🔫 All Guns",       callback = function() SelectCategory("Tool_Guns") end })
PresetLeft:CreateButton({ name = "⚔️ All Melee",      callback = function() SelectCategory("Tool_Melee") end })
PresetLeft:CreateButton({ name = "💊 All Medical",    callback = function() SelectCategory("Tool_Medical") end })

PresetRight:CreateButton({ name = "⛽ All Fuel",       callback = function() SelectCategory("Fuel") end })
PresetRight:CreateButton({ name = "🔧 All Resources",  callback = function() SelectCategory("Resources") end })
PresetRight:CreateButton({ name = "💎 Alien Crystals", callback = function() SelectCategory("AlienCrystals") end })
PresetRight:CreateButton({ name = "🎒 All Backpacks",  callback = function() SelectCategory("Tool_Backpacks") end })
PresetRight:CreateButton({ name = "🚗 Car Attachments", callback = function() SelectCategory("Tool_CarAttachments") end })
PresetRight:CreateButton({ name = "🗑️ Clear Filter",    callback = function()
    table.clear(SelectedLootItems)
    pcall(function() LootFilterDropdown:Set({}) end)
    QuickToast("Cleared", "Looting everything")
end })

ItemsTab:CreateDivider({ text = "database" })
ItemsTab:CreateButton({
    name = "🔄 Refresh Item Database",
    callback = function()
        BuildItemDatabase()
        pcall(function() LootFilterDropdown:Refresh(ItemDatabase.All) end)
        QuickToast("Refreshed", #ItemDatabase.All .. " items")
    end,
})

ItemsTab:CreateText({
    name = "Database Info",
    text = "Items loaded: " .. #ItemDatabase.All .. "\n" ..
           "Categories: " .. (function() local n = 0; for _ in pairs(ItemDatabase.ByCategory) do n += 1 end return n end)(),
})

-- =================================================================
-- BACKPACK TAB (NEW)
-- =================================================================
BackpackTab:CreateSection({ name = "📊 Storage Overview" })

local BPTotalStat = BackpackTab:CreateStat({ name = "🎒 Total Items", value = 0, compact = true })
local BPFuelStat  = BackpackTab:CreateStat({ name = "⛽ Fuel",       value = 0, compact = true })
local BPFoodStat  = BackpackTab:CreateStat({ name = "🍞 Food",       value = 0, compact = true })
local BPResStat   = BackpackTab:CreateStat({ name = "🔧 Resources",  value = 0, compact = true })
local BPAmmoStat  = BackpackTab:CreateStat({ name = "💥 Ammo",       value = 0, compact = true })
local BPMiscStat  = BackpackTab:CreateStat({ name = "📦 Other",      value = 0, compact = true })

BackpackTab:CreateDivider({ text = "contents" })
BackpackTab:CreateSection({ name = "📋 Live Contents" })

local BackpackConsole = BackpackTab:CreateConsole({
    name = "Stored Items",
    height = 220,
    follow = false,
    maxLines = 300,
})

local function RefreshBackpackConsole()
    local text = BuildBackpackConsoleText()
    pcall(function() BackpackConsole:Set(text) end)
end

BackpackTab:CreateDivider({ text = "controls" })
BackpackTab:CreateSection({ name = "⚙️ Controls" })

BackpackTab:CreateButton({
    name = "🔄 Refresh Backpack Now",
    callback = function()
        RefreshBackpackConsole()
        QuickToast("Refreshed", "Backpack contents updated")
    end,
})

BackpackTab:CreateToggle({
    name = "Auto-Refresh (every 1s)",
    flag = "BackpackAutoRefresh",
    value = true,
    callback = function(v) BackpackAutoRefresh = v end,
})

BackpackTab:CreateButton({
    name = "📋 Copy Contents to Clipboard",
    callback = function()
        local text = BuildBackpackConsoleText()
        if setclipboard then
            setclipboard(text)
            QuickToast("Copied", "Backpack contents copied")
        end
    end,
})

BackpackTab:CreateText({
    name = "About this panel",
    text = "Reads ReplicatedStorage.BackpackStorage live.\n" ..
           "Shows all items stored in your backpack, grouped by ItemType.\n" ..
           "Auto-refreshes every 1 second when toggled on.",
})

-- =================================================================
-- ESP TAB
-- =================================================================
ESPTab:CreateSection({ name = "⚙️ ESP Config" })

local ESPConfig = { ShowNames = true, ShowDistance = true }

ESPTab:CreateToggle({ name = "Show Names", flag = "ESPNames", value = true,
    callback = function(v) ESPConfig.ShowNames = v end })
ESPTab:CreateToggle({ name = "Show Distance", flag = "ESPDistance", value = true,
    callback = function(v) ESPConfig.ShowDistance = v end })

ESPTab:CreateDivider({ text = "characters" })
ESPTab:CreateSection({ name = "👁️ Character ESP" })

local ESPState = {
    Zombie   = false,
    Player   = false,
    Survivor = false,
    Airdrop  = false,
    Items    = false,
}

local function CreateOrUpdateESP(target, tag, customName, color)
    if not target then return end
    local adornee = target:IsA("BasePart") and target
        or (target:IsA("Model") and (target.PrimaryPart or target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildOfClass("BasePart")))
    if not adornee then return end

    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local distText = ""
    if hrp and ESPConfig.ShowDistance then
        distText = string.format(" [%dm]", math.floor((hrp.Position - adornee.Position).Magnitude))
    end

    local baseName = customName or target.Name
    local display = ""
    if ESPConfig.ShowNames and ESPConfig.ShowDistance then display = baseName .. distText
    elseif ESPConfig.ShowNames then display = baseName
    elseif ESPConfig.ShowDistance then display = distText:gsub("^%s*", "") end

    local existing = adornee:FindFirstChild(tag)
    if existing then
        local lbl = existing:FindFirstChildOfClass("TextLabel")
        if lbl then
            lbl.Text = display
            lbl.TextColor3 = color or Color3.fromRGB(255,255,255)
            lbl.Visible = display ~= ""
        end
        return
    end

    local gui = Instance.new("BillboardGui")
    gui.Name = tag
    gui.Adornee = adornee
    gui.Size = UDim2.new(0, 200, 0, 30)
    gui.StudsOffset = Vector3.new(0, 2.5, 0)
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Parent = adornee

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = display
    lbl.Visible = display ~= ""
    lbl.TextColor3 = color or Color3.fromRGB(255,255,255)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.SourceSansBold
    lbl.Parent = gui
end

local function RemoveESP(parent, tag)
    if not parent then return end
    for _, item in ipairs(parent:GetDescendants()) do
        if item:IsA("BillboardGui") and item.Name == tag then item:Destroy() end
    end
end

ESPTab:CreateToggle({
    name = "Zombie ESP", flag = "ZombieESP", value = false,
    callback = function(v)
        ESPState.Zombie = v
        if not v then
            RemoveESP(Workspace:FindFirstChild("Characters"), "ZombieESP")
        else
            task.spawn(function()
                while ESPState.Zombie do
                    local chars = Workspace:FindFirstChild("Characters")
                    if chars then
                        for _, c in ipairs(chars:GetChildren()) do
                            if c:IsA("Model") and isZombieEnemy(c) and canBeDamaged(c) then
                                CreateOrUpdateESP(c, "ZombieESP", c.Name, Color3.fromRGB(255,50,50))
                            end
                        end
                    end
                    task.wait(0.2)
                end
            end)
        end
    end,
})

ESPTab:CreateToggle({
    name = "Player ESP", flag = "PlayerESP", value = false,
    callback = function(v)
        ESPState.Player = v
        if not v then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character then RemoveESP(p.Character, "PlayerESP") end
            end
        else
            task.spawn(function()
                while ESPState.Player do
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character then
                            CreateOrUpdateESP(p.Character, "PlayerESP", p.Name, Color3.fromRGB(50,150,255))
                        end
                    end
                    task.wait(0.2)
                end
            end)
        end
    end,
})

ESPTab:CreateToggle({
    name = "Survivor ESP", flag = "SurvivorESP", value = false,
    callback = function(v)
        ESPState.Survivor = v
        if not v then
            local map = Workspace:FindFirstChild("Map")
            local surv = map and map:FindFirstChild("Survivors")
            RemoveESP(surv, "SurvivorESP")
        else
            task.spawn(function()
                while ESPState.Survivor do
                    local map = Workspace:FindFirstChild("Map")
                    local surv = map and map:FindFirstChild("Survivors")
                    if surv then
                        for _, s in ipairs(surv:GetChildren()) do
                            if s:IsA("Model") then
                                CreateOrUpdateESP(s, "SurvivorESP", "Survivor: " .. s.Name, Color3.fromRGB(0, 255, 130))
                            end
                        end
                    end
                    task.wait(0.3)
                end
            end)
        end
    end,
})

ESPTab:CreateToggle({
    name = "Airdrop ESP", flag = "AirdropESP", value = false,
    callback = function(v)
        ESPState.Airdrop = v
        if not v then
            local map = Workspace:FindFirstChild("Map")
            local spec = map and map:FindFirstChild("Special")
            RemoveESP(spec, "AirdropESP")
        else
            task.spawn(function()
                while ESPState.Airdrop do
                    local map = Workspace:FindFirstChild("Map")
                    local spec = map and map:FindFirstChild("Special")
                    if spec then
                        for _, s in ipairs(spec:GetChildren()) do
                            if s:IsA("Model") or s:IsA("BasePart") then
                                CreateOrUpdateESP(s, "AirdropESP", "★ AIRDROP: " .. s.Name, Color3.fromRGB(255, 0, 200))
                            end
                        end
                    end
                    task.wait(0.3)
                end
            end)
        end
    end,
})

ESPTab:CreateDivider({ text = "items" })
ESPTab:CreateSection({ name = "📦 Item ESP" })

ESPTab:CreateToggle({
    name = "Enable Item ESP", flag = "ItemESPEnabled", value = false,
    callback = function(v)
        ESPState.Items = v
        if not v then
            RemoveESP(Workspace:FindFirstChild("DroppedItems"), "ItemESP")
        end
    end,
})

local ESPFilterDropdown = ESPTab:CreateDropdown({
    name = "Items to Highlight",
    flag = "ESPFilterItems",
    options = ItemDatabase.All,
    value = {},
    multiSelect = true,
    callback = function(selected)
        table.clear(SelectedESPItems)
        if type(selected) == "table" then
            for _, name in ipairs(selected) do
                SelectedESPItems[name] = true
            end
        end
    end,
})

ESPTab:CreateButton({
    name = "🔄 Refresh ESP Item List",
    callback = function()
        BuildItemDatabase()
        pcall(function() ESPFilterDropdown:Refresh(ItemDatabase.All) end)
        QuickToast("Refreshed", #ItemDatabase.All .. " items")
    end,
})

-- =================================================================
-- MISC TAB
-- =================================================================
MiscTab:CreateSection({ name = "🎨 Visuals" })

local FogConn, BrightnessConn, ZoomConn = nil, nil, nil

MiscTab:CreateToggle({
    name = "Remove Fog", flag = "RemoveFog", value = false,
    callback = function(v)
        if v then
            Lighting.FogEnd = 9e9
            local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
            if atmo then atmo.Density = 0 end
            FogConn = RunService.RenderStepped:Connect(function()
                Lighting.FogEnd = 9e9
                if atmo then atmo.Density = 0 end
            end)
        else
            if FogConn then FogConn:Disconnect(); FogConn = nil end
            Lighting.FogEnd = 1000
        end
    end,
})

MiscTab:CreateToggle({
    name = "Fullbright", flag = "Fullbright", value = false,
    callback = function(v)
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
            BrightnessConn = RunService.RenderStepped:Connect(function()
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.GlobalShadows = false
                Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
            end)
        else
            if BrightnessConn then BrightnessConn:Disconnect(); BrightnessConn = nil end
            Lighting.Brightness = 1
            Lighting.GlobalShadows = true
            Lighting.OutdoorAmbient = Color3.fromRGB(127,127,127)
        end
    end,
})

MiscTab:CreateToggle({
    name = "Infinite Zoom", flag = "InfZoom", value = false,
    callback = function(v)
        if v then
            LocalPlayer.CameraMaxZoomDistance = 99999
            ZoomConn = RunService.RenderStepped:Connect(function()
                if LocalPlayer.CameraMaxZoomDistance ~= 99999 then
                    LocalPlayer.CameraMaxZoomDistance = 99999
                end
            end)
        else
            if ZoomConn then ZoomConn:Disconnect(); ZoomConn = nil end
            LocalPlayer.CameraMaxZoomDistance = 128
        end
    end,
})

MiscTab:CreateDivider({ text = "interaction" })
MiscTab:CreateSection({ name = "⚡ Prompts" })

MiscTab:CreateToggle({
    name = "Instant Proximity Prompts", flag = "InstantPrompts", value = false,
    callback = function(v)
        InstantPromptsEnabled = v
        if v then
            ApplyInstantPrompts()
            if not InstantPromptConn then
                InstantPromptConn = Workspace.DescendantAdded:Connect(function(desc)
                    if InstantPromptsEnabled then
                        MakePromptInstant(desc)
                    end
                end)
            end
            QuickToast("Instant Prompts", "Enabled")
        else
            if InstantPromptConn then
                InstantPromptConn:Disconnect()
                InstantPromptConn = nil
            end
            RestorePrompts()
            QuickToast("Instant Prompts", "Disabled")
        end
    end,
})

-- =================================================================
-- INFO TAB
-- =================================================================
InfoTab:CreateSection({ name = "ℹ️ About" })
InfoTab:CreateText({
    name = "KissoHub — Survive the Apocalypse",
    text = "Version: " .. HUB_VERSION .. "\n" ..
           "Config: KissoHubFolder/STAPrefs.rfld",
})

InfoTab:CreateDivider({ text = "changelog" })
InfoTab:CreateSection({ name = "📋 Changelog" })
InfoTab:CreateText({
    name = HUB_VERSION .. " — Latest",
    text = "• NEW: 🎒 Backpack tab with live contents viewer\n" ..
           "• NEW: Console panel showing stored items grouped by type\n" ..
           "• NEW: Category breakdown stats (Fuel/Food/Res/Ammo)\n" ..
           "• NEW: Copy contents to clipboard button\n" ..
           "• NEW: Auto-refresh every 1 second (toggleable)",
})

InfoTab:CreateText({
    name = "v1.3.3",
    text = "• Survivor ESP + Airdrop ESP\n" ..
           "• Instant Proximity Prompts\n" ..
           "• Expanded item database (Tools folders)\n" ..
           "• Backpack storage monitor (counts)",
})

-- =================================================================
-- AUTO-SHOOT LOOP
-- =================================================================
task.spawn(function()
    while true do
        task.wait(Settings.ShootDelay)
        if Settings.AutoShootEnabled then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and tool:GetAttribute("ToolType") == "Gun" then
                    local shootRemote = tool:FindFirstChild("Shoot")
                    if shootRemote then
                        local myPos = getLocalRootPosition()
                        local targetPart = getClosestZombie(Settings.AutoShootRange, true)
                        if targetPart and targetPart.Parent then
                            local targetModel = targetPart.Parent
                            local targetPos = targetPart.Position
                            local syncAmmo = tool:FindFirstChild("SyncAmmo")
                            if syncAmmo then pcall(function() syncAmmo:FireServer() end) end
                            local payload = {{
                                Target = targetPos,
                                HitData = {{ HitChar = targetModel, HitPos = targetPos, HitPart = targetPart }},
                                EffectResults = {{ Origin = myPos, End = targetPos }}
                            }}
                            pcall(function() shootRemote:FireServer(myPos, payload, 0, 4) end)
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- MELEE LOOP
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if KillAuraEnabled or MeleeAutoSwing then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool and tool:GetAttribute("ToolType") == "Melee" then
                local swingRemote = tool:FindFirstChild("Swing")
                local hitTargets = tool:FindFirstChild("HitTargets")
                if swingRemote and hitTargets then
                    pcall(function() swingRemote:FireServer() end)
                    if KillAuraEnabled then
                        local targets = GetMeleeTargets()
                        if #targets > 0 then
                            task.wait(MeleeZeroWindUp and 0.05 or 0.3)
                            pcall(function() hitTargets:FireServer(targets) end)
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- ENHANCED LOOT LOOP
-- =================================================================
task.spawn(function()
    task.spawn(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
        if not remotes then return end
        local interaction = remotes:WaitForChild("Interaction", 5)
        if interaction then
            LootRemotes.PickUpItem = interaction:WaitForChild("PickUpItem", 5)
        end
        local toolsF = remotes:WaitForChild("Tools", 5)
        if toolsF then
            LootRemotes.AdjustBackpack = toolsF:WaitForChild("AdjustBackpack", 5)
        end
    end)

    while true do
        task.wait(0.3)
        if AutoLootEnabled then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local myPos = hrp.Position
                local dropped = Workspace:FindFirstChild("DroppedItems")
                if dropped and LootRemotes.PickUpItem then
                    for _, item in ipairs(dropped:GetChildren()) do
                        local pivot = item:GetPivot().Position
                        local dist = (pivot - myPos).Magnitude
                        if dist <= AutoLootRange and ShouldLoot(item.Name) then
                            pcall(function() LootRemotes.PickUpItem:FireServer(item) end)
                            task.wait(0.05)
                            if AutoStoreEnabled and LootRemotes.AdjustBackpack then
                                task.wait(0.15)
                                pcall(function() LootRemotes.AdjustBackpack:FireServer(item) end)
                            end
                        end
                    end
                end

                if ProxFallbackEnabled then
                    for _, prompt in ipairs(Workspace:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                            local parent = prompt.Parent
                            local pos = parent:IsA("BasePart") and parent.Position
                                or (parent:IsA("Model") and parent.PrimaryPart and parent.PrimaryPart.Position)
                            if pos and (pos - myPos).Magnitude <= AutoLootRange then
                                if fireproximityprompt then
                                    pcall(function() fireproximityprompt(prompt) end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- ITEM ESP LOOP
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.3)
        if ESPState.Items then
            local dropped = Workspace:FindFirstChild("DroppedItems")
            if dropped then
                for _, item in ipairs(dropped:GetChildren()) do
                    local itemName = item.Name
                    local hasFilter = next(SelectedESPItems) ~= nil
                    local shouldShow = (not hasFilter) or SelectedESPItems[itemName] == true

                    if shouldShow then
                        local cat = ItemDatabase.Lookup[itemName] or "Misc"
                        local color = CategoryColors[cat] or Color3.fromRGB(255, 255, 150)
                        CreateOrUpdateESP(item, "ItemESP", itemName, color)
                    else
                        local adornee = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
                        if adornee then
                            local existing = adornee:FindFirstChild("ItemESP")
                            if existing then existing:Destroy() end
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- BACKPACK MONITOR LOOP
-- =================================================================
task.spawn(function()
    local lastSnapshot = ""
    while true do
        task.wait(BackpackAutoRefresh and 1 or 5)
        if BackpackAutoRefresh then
            pcall(function()
                local items, total, byType = ReadBackpackStorage()
                BPTotalStat:Set(total)
                BPFuelStat:Set(byType.Fuel or 0)
                BPFoodStat:Set(byType.Food or 0)
                BPResStat:Set(byType.Resource or 0)
                BPAmmoStat:Set(byType.Ammo or 0)
                local other = 0
                for t, n in pairs(byType) do
                    if t ~= "Fuel" and t ~= "Food" and t ~= "Resource" and t ~= "Ammo" then
                        other += n
                    end
                end
                BPMiscStat:Set(other)

                -- Update console if content changed
                local snapshot = tostring(total) .. ":" .. tostring(#items)
                for _, info in ipairs(items) do
                    snapshot = snapshot .. "|" .. info.name
                end
                if snapshot ~= lastSnapshot then
                    lastSnapshot = snapshot
                    RefreshBackpackConsole()
                end
            end)
        end
    end
end)

-- =================================================================
-- SILENT AIM HOOK
-- =================================================================
if hookmetamethod and getnamecallmethod then
    pcall(function()
        local raw; raw = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if Settings.SilentAimEnabled and method == "FireServer" and tostring(self) == "Shoot" then
                local targetPart = getClosestZombie()
                if targetPart and targetPart.Parent then
                    local args = {...}
                    local targetModel = targetPart.Parent
                    local origin = args[1] or getLocalRootPosition()
                    local targetPos = targetPart.Position
                    args[2] = {{
                        Target = targetPos,
                        HitData = {{ HitChar = targetModel, HitPos = targetPos, HitPart = targetPart }},
                        EffectResults = {{ Origin = origin, End = targetPos }}
                    }}
                    return raw(self, table.unpack(args))
                end
            end
            return raw(self, ...)
        end)
    end)
end

-- =================================================================
-- SUPPORT LOOPS
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.1)
        if NoRecoilEnabled or NoSpreadEnabled then pcall(EnforceNoRecoilOnEquipped) end
    end
end)

task.spawn(function()
    while task.wait(0.2) do
        if AutoReloadEnabled then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool and tool:GetAttribute("ToolType") == "Gun" then
                local ammo = tool:GetAttribute("Ammo")
                if type(ammo) == "number" and ammo <= 0 then
                    if InstantReload then ApplyInstantReload(tool) end
                    TriggerRemoteReload(tool)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        if AutoTargetSync then
            local char = LocalPlayer.Character
            local atc = char and char:FindFirstChild("AutoTargetClient")
            local remote = atc and atc:FindFirstChild("UpdateNearbyTargets")
            if remote then
                local targets = GetValidTargets()
                if #targets > 0 then pcall(function() remote:FireServer(targets) end) end
            end
        end
    end
end)

-- =================================================================
-- LIVE REFRESH
-- =================================================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local mins = math.floor((os.time() - SESSION_START) / 60)
            local active = 0
            for _, t in ipairs({
                Settings.AutoShootEnabled, Settings.SilentAimEnabled,
                KillAuraEnabled, MeleeAutoSwing, MeleeZeroWindUp, MeleeZeroEndlag,
                NoRecoilEnabled, NoSpreadEnabled, AutoReloadEnabled,
                AutoLootEnabled, AutoStoreEnabled,
                ESPState.Items, ESPState.Zombie, ESPState.Player,
                ESPState.Survivor, ESPState.Airdrop,
                InstantPromptsEnabled
            }) do
                if t then active += 1 end
            end

            local targetCount = 0
            local chars = Workspace:FindFirstChild("Characters")
            if chars then
                for _, c in ipairs(chars:GetChildren()) do
                    if c:IsA("Model") and isZombieEnemy(c) and canBeDamaged(c) then targetCount += 1 end
                end
            end

            local ammoTotal = 0
            local ammoConf = LocalPlayer:FindFirstChild("Ammo")
            if ammoConf then
                for _, a in ipairs({"Long","Shells","Pistol","Medium"}) do
                    ammoTotal += (ammoConf:GetAttribute(a) or 0)
                end
            end

            local kills, health = 0, 100
            local ls = LocalPlayer:FindFirstChild("leaderstats")
            if ls then
                local k = ls:FindFirstChild("Kills")
                if k then kills = k.Value end
            end
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then health = math.floor(hum.Health) end
            end

            SessionStat:Set(mins)
            FeaturesStat:Set(active)
            FpsStat:Set(math.floor(Workspace:GetRealPhysicsFPS() or 60))
            PlayersStat:Set(#Players:GetPlayers())
            TargetsStat:Set(targetCount)
            AmmoStat:Set(ammoTotal)
            KillsStat:Set(kills)
            HealthStat:Set(health)

            if AutoLootEnabled then
                StateTag:Set({ text = "LOOTING", color = Color3.fromRGB(0, 200, 255) })
            elseif KillAuraEnabled or MeleeAutoSwing then
                StateTag:Set({ text = "MELEE", color = Color3.fromRGB(255, 130, 40) })
            elseif Settings.AutoShootEnabled then
                StateTag:Set({ text = "AUTO-SHOOT", color = Color3.fromRGB(255, 80, 80) })
            elseif active > 0 then
                StateTag:Set({ text = "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
            else
                StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
            end
        end)
    end
end)

SafeNotify("KissoHub", "Survive the Apocalypse " .. HUB_VERSION .. " loaded", 3)
