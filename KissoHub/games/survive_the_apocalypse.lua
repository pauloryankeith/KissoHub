-- ═══════════════════════════════════════════════════════════════
--   KissoHub — Survive the Apocalypse Module  |  v1.3.5
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
local HUB_VERSION = "v1.3.5"
local SESSION_START = os.time()

-- =================================================================
-- SHARED STATE (single table to save registers)
-- =================================================================
local State = {
    -- Combat
    AutoShoot = false, AutoShootRange = 500, SilentAim = false,
    IgnorePlayers = true, CheckDamageable = true,
    -- Melee
    KillAura = false, KillAuraRange = 12, AutoSwing = false,
    ZeroWindUp = false, ZeroEndlag = false, SpeedMult = 1,
    MeleePriority = "Nearest",
    -- Reload
    AutoReload = false, InstantReload = false, RemoteReload = false,
    AutoTargetSync = false, NoRecoil = false, NoSpread = false,
    -- Loot
    AutoLoot = false, AutoLootRange = 20, AutoStore = false, ProxFallback = true,
    -- ESP
    ZombieESP = false, PlayerESP = false, SurvivorESP = false,
    AirdropESP = false, ItemESP = false,
    ESPShowNames = true, ESPShowDistance = true,
    -- Misc
    RemoveFog = false, Fullbright = false, InfZoom = false,
    InstantPrompts = false,
    -- Backpack
    BPRefresh = true,
}

-- Shared handles (filled by tab builders)
local Stats = {}          -- stat handles
local Remotes = { PickUpItem = nil, AdjustBackpack = nil }
local Filters = {
    LootItems = {}, ESPItems = {},
    LootDropdown = nil, ESPDropdown = nil,
}
local Prompts = {
    OriginalHold = {}, Connection = nil,
}

-- =================================================================
-- ITEM DATABASE
-- =================================================================
local ItemDatabase = { All = {}, ByCategory = {}, Lookup = {} }

local CategoryColors = {
    Fuel = Color3.fromRGB(255, 100, 100),
    Ammo = Color3.fromRGB(255, 200, 40),
    Resources = Color3.fromRGB(200, 200, 200),
    Food = Color3.fromRGB(100, 255, 100),
    Armor = Color3.fromRGB(100, 150, 255),
    Misc = Color3.fromRGB(220, 100, 255),
    AlienCrystals = Color3.fromRGB(0, 255, 200),
    Tool_Backpacks = Color3.fromRGB(180, 130, 90),
    Tool_CarAttachments = Color3.fromRGB(120, 170, 220),
    Tool_Consumable = Color3.fromRGB(255, 150, 50),
    Tool_Guns = Color3.fromRGB(255, 90, 60),
    Tool_Medical = Color3.fromRGB(255, 160, 200),
    Tool_Melee = Color3.fromRGB(200, 60, 60),
    Tool_Misc = Color3.fromRGB(180, 180, 200),
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
    for _, list in pairs(ItemDatabase.ByCategory) do table.sort(list) end
end
BuildItemDatabase()

-- =================================================================
-- HELPERS
-- =================================================================
local function canBeDamaged(character)
    if not character then return false end
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end
    if character:GetAttribute("Dead") or character:GetAttribute("Untargetable") then return false end
    if State.CheckDamageable then
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
    if State.IgnorePlayers and Players:GetPlayerFromCharacter(character) then return false end
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

local function getClosestZombie(customMaxDist)
    local maxDist = customMaxDist or State.AutoShootRange
    local myPos = getLocalRootPosition()
    local best, bestMetric = nil, math.huge
    local charsFolder = Workspace:FindFirstChild("Characters") or Workspace
    for _, char in ipairs(charsFolder:GetChildren()) do
        if char:IsA("Model") and isZombieEnemy(char) and canBeDamaged(char) then
            local part = getTargetPart(char)
            if part then
                local d = (part.Position - myPos).Magnitude
                if maxDist == 0 or d <= maxDist then
                    if d < bestMetric then best = part; bestMetric = d end
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
    if State.NoRecoil then pcall(function() stats:SetAttribute("Recoil", 0) end) end
    if State.NoSpread then pcall(function() stats:SetAttribute("Inaccuracy", 0) end) end
end

local function ApplyMeleeStats(tool)
    if not tool or not tool:IsA("Tool") then return end
    local stats = tool:FindFirstChild("Stats")
    if not stats then return end
    if State.ZeroWindUp then pcall(function() stats:SetAttribute("WindUp", 0) end) end
    if State.ZeroEndlag then pcall(function() stats:SetAttribute("Endlag", 0) end) end
    if State.SpeedMult ~= 1 then
        pcall(function() stats:SetAttribute("AnimSpeed", (stats:GetAttribute("AnimSpeed") or 0.7) * State.SpeedMult) end)
    end
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
    local tt = tool:GetAttribute("ToolType")
    if tt == "Gun" then
        if State.InstantReload then ApplyInstantReload(tool) end
        if State.RemoteReload then TriggerRemoteReload(tool) end
        if State.NoRecoil or State.NoSpread then ApplyNoRecoilSpread(tool) end
    elseif tt == "Melee" then
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

local function GetMeleeTargets()
    local myPos = getLocalRootPosition()
    local targets = {}
    local charsFolder = Workspace:FindFirstChild("Characters") or Workspace
    for _, char in ipairs(charsFolder:GetChildren()) do
        if char:IsA("Model") and isZombieEnemy(char) and canBeDamaged(char) then
            local d = (char:GetPivot().Position - myPos).Magnitude
            if d <= State.KillAuraRange then table.insert(targets, { model = char, dist = d }) end
        end
    end
    if State.MeleePriority == "Nearest" then
        table.sort(targets, function(a, b) return a.dist < b.dist end)
    elseif State.MeleePriority == "Lowest HP" then
        table.sort(targets, function(a, b)
            local ha = a.model:FindFirstChildOfClass("Humanoid")
            local hb = b.model:FindFirstChildOfClass("Humanoid")
            return (ha and ha.Health or 999) < (hb and hb.Health or 999)
        end)
    end
    local out = {}
    for _, t in ipairs(targets) do table.insert(out, t.model) end
    return out
end

local function ShouldLoot(itemName)
    if next(Filters.LootItems) == nil then return true end
    return Filters.LootItems[itemName] == true
end

local function MakePromptInstant(prompt)
    if prompt:IsA("ProximityPrompt") then
        if Prompts.OriginalHold[prompt] == nil then
            Prompts.OriginalHold[prompt] = prompt.HoldDuration
        end
        pcall(function() prompt.HoldDuration = 0 end)
    end
end

local function ApplyInstantPrompts()
    for _, desc in ipairs(Workspace:GetDescendants()) do MakePromptInstant(desc) end
end

local function RestorePrompts()
    for prompt, orig in pairs(Prompts.OriginalHold) do
        if prompt and prompt.Parent then pcall(function() prompt.HoldDuration = orig end) end
    end
end

local function ReadBackpackStorage()
    local bs = ReplicatedStorage:FindFirstChild("BackpackStorage")
    if not bs then return {}, 0, {} end
    local items, byType, total = {}, {}, 0
    for _, item in ipairs(bs:GetChildren()) do
        local itemType = item:GetAttribute("ItemType") or "Unknown"
        table.insert(items, { name = item.Name, type = itemType, attrs = item:GetAttributes() })
        byType[itemType] = (byType[itemType] or 0) + 1
        total += 1
    end
    table.sort(items, function(a, b)
        if a.type ~= b.type then return a.type < b.type end
        return a.name < b.name
    end)
    return items, total, byType
end

local function BuildBackpackText()
    local items, total = ReadBackpackStorage()
    if total == 0 then return "📦 Backpack is empty" end
    local lines = { "═════════════════════════════════", "  🎒 BACKPACK — " .. total .. " items", "═════════════════════════════════" }
    local grouped = {}
    for _, item in ipairs(items) do
        grouped[item.type] = grouped[item.type] or {}
        table.insert(grouped[item.type], item)
    end
    local types = {}
    for t, _ in pairs(grouped) do table.insert(types, t) end
    table.sort(types)
    for _, t in ipairs(types) do
        table.insert(lines, "")
        table.insert(lines, "▬ " .. t .. " (" .. #grouped[t] .. ") ▬")
        for _, info in ipairs(grouped[t]) do
            local parts = {}
            for a, v in pairs(info.attrs) do
                if a ~= "ItemType" and a ~= "CanPickUp" and typeof(v) == "number" then
                    table.insert(parts, a .. "=" .. tostring(v))
                end
            end
            local detail = #parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or ""
            table.insert(lines, "  • " .. info.name .. detail)
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
        autoSave = true, autoLoad = true,
        fileName = "STAPrefs", customFolder = "KissoHubFolder",
    },
})

local StateTag = Window:CreateTag({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
Window:CreateTag({ text = HUB_VERSION, color = Color3.fromRGB(0, 200, 255) })

local function Toast(t, s)
    pcall(function() Window:Toast({ title = t, subtitle = s, position = "Top", icon = ASSET_ICON }) end)
end

local function Notify(t, c, d)
    pcall(function() Window:Notify({ title = t or "KissoHub", content = c or "", duration = d or 4, icon = ASSET_ICON }) end)
end

-- =================================================================
-- BUILD HOME TAB
-- =================================================================
local HomeTab = Window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })
do
    HomeTab:CreateSection({ name = "📊 Session Stats" })
    local grid = HomeTab:CreateGroup()
    local left = grid:CreateGroup({ direction = "column" })
    local right = grid:CreateGroup({ direction = "column" })
    Stats.Session  = left:CreateStat({ name = "⏱️ Session", value = 0, suffix = " m", compact = true })
    Stats.Fps      = left:CreateStat({ name = "🎮 FPS", value = 0, compact = true })
    Stats.Players  = left:CreateStat({ name = "👥 Players", value = 1, compact = true })
    Stats.Kills    = left:CreateStat({ name = "💀 Kills", value = 0, compact = true })
    Stats.Features = right:CreateStat({ name = "⚙️ Features", value = 0, compact = true })
    Stats.Targets  = right:CreateStat({ name = "🧟 Targets", value = 0, compact = true })
    Stats.Ammo     = right:CreateStat({ name = "🔫 Ammo", value = 0, compact = true })
    Stats.Health   = right:CreateStat({ name = "❤️ HP", value = 100, compact = true })

    HomeTab:CreateDivider({ text = "backpack summary" })
    HomeTab:CreateSection({ name = "🎒 Backpack" })
    local bpgrid = HomeTab:CreateGroup()
    local bpleft = bpgrid:CreateGroup({ direction = "column" })
    local bpright = bpgrid:CreateGroup({ direction = "column" })
    Stats.BPTotal = bpleft:CreateStat({ name = "📦 Total", value = 0, compact = true })
    Stats.BPFuel  = bpleft:CreateStat({ name = "⛽ Fuel", value = 0, compact = true })
    Stats.BPFood  = bpleft:CreateStat({ name = "🍞 Food", value = 0, compact = true })
    Stats.BPRes   = bpright:CreateStat({ name = "🔧 Resources", value = 0, compact = true })
    Stats.BPAmmo  = bpright:CreateStat({ name = "💥 Ammo", value = 0, compact = true })
    Stats.BPOther = bpright:CreateStat({ name = "📋 Other", value = 0, compact = true })

    HomeTab:CreateDivider({ text = "server" })
    HomeTab:CreateSection({ name = "🌐 Server Utilities" })
    HomeTab:CreateButton({
        name = "📋 Copy Job ID",
        callback = function()
            if setclipboard then setclipboard(game.JobId); Toast("Copied", "Job ID copied") end
        end,
    })
    HomeTab:CreateButton({
        name = "🔄 Rejoin Server",
        callback = function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end,
    })
end

-- =================================================================
-- BUILD GUN COMBAT TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "🔫 Gun Combat" })
    tab:CreateSection({ name = "🔫 Shooting" })
    tab:CreateToggle({ name = "Auto-Shoot Target", flag = "AutoShoot", value = false,
        callback = function(v) State.AutoShoot = v end })
    tab:CreateSlider({ name = "Auto-Shoot Range", flag = "AutoShootRange",
        range = {25,1000}, increment = 25, value = 500, suffix = " studs",
        callback = function(v) State.AutoShootRange = v end })
    tab:CreateToggle({ name = "Silent Aim", flag = "SilentAim", value = false,
        callback = function(v) State.SilentAim = v end })
    tab:CreateToggle({ name = "Ignore Human Players", flag = "IgnorePlayers", value = true,
        callback = function(v) State.IgnorePlayers = v end })
    tab:CreateToggle({ name = "Check Damageable", flag = "CheckDamageable", value = true,
        callback = function(v) State.CheckDamageable = v end })

    tab:CreateDivider({ text = "recoil & spread" })
    tab:CreateSection({ name = "🎯 No Recoil / Spread" })
    tab:CreateToggle({ name = "No Recoil", flag = "NoRecoil", value = false,
        callback = function(v) State.NoRecoil = v; if v then ProcessAllTools() end end })
    tab:CreateToggle({ name = "No Spread", flag = "NoSpread", value = false,
        callback = function(v) State.NoSpread = v; if v then ProcessAllTools() end end })
    tab:CreateButton({
        name = "🎯 Apply Now to Equipped Gun",
        callback = function()
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool and tool:GetAttribute("ToolType") == "Gun" then
                ApplyNoRecoilSpread(tool); Toast("Applied", "→ " .. tool.Name)
            else Notify("No Gun", "Equip a gun first", 3) end
        end,
    })

    tab:CreateDivider({ text = "reload" })
    tab:CreateSection({ name = "🔄 Reload" })
    tab:CreateToggle({ name = "Auto Reload", flag = "AutoReload", value = false,
        callback = function(v) State.AutoReload = v end })
    tab:CreateToggle({ name = "Instant Reload", flag = "InstantReload", value = false,
        callback = function(v) State.InstantReload = v; if v then ProcessAllTools() end end })
    tab:CreateToggle({ name = "Remote Bypass Reload", flag = "RemoteReload", value = false,
        callback = function(v) State.RemoteReload = v; if v then ProcessAllTools() end end })
    tab:CreateButton({
        name = "Force Instant Reload",
        callback = function()
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool then ApplyInstantReload(tool); TriggerRemoteReload(tool) end
        end,
    })
    tab:CreateToggle({ name = "Auto-Sync Targets", flag = "AutoTargetSync", value = false,
        callback = function(v) State.AutoTargetSync = v end })
end

-- =================================================================
-- BUILD MELEE TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "⚔️ Melee" })
    tab:CreateSection({ name = "⚔️ Auto Combat" })
    tab:CreateToggle({ name = "Auto Swing", flag = "AutoSwing", value = false,
        callback = function(v) State.AutoSwing = v end })
    tab:CreateToggle({ name = "Kill Aura", flag = "KillAura", value = false,
        callback = function(v) State.KillAura = v end })
    tab:CreateSlider({ name = "Kill Aura Range", flag = "KillAuraRange",
        range = {4,30}, increment = 1, value = 12, suffix = " studs",
        callback = function(v) State.KillAuraRange = v end })
    tab:CreateDropdown({ name = "Target Priority", flag = "MeleePriority",
        options = {"Nearest","Lowest HP"}, value = {"Nearest"}, multiSelect = false,
        callback = function(o) State.MeleePriority = type(o) == "table" and o[1] or o end })

    tab:CreateDivider({ text = "stats" })
    tab:CreateSection({ name = "⚡ Melee Stats" })
    tab:CreateToggle({ name = "Zero WindUp", flag = "ZeroWindUp", value = false,
        callback = function(v) State.ZeroWindUp = v; ProcessAllTools() end })
    tab:CreateToggle({ name = "Zero Endlag", flag = "ZeroEndlag", value = false,
        callback = function(v) State.ZeroEndlag = v; ProcessAllTools() end })
    tab:CreateSlider({ name = "Animation Speed", flag = "SpeedMult",
        range = {1,5}, increment = 0.5, value = 1, suffix = "x",
        callback = function(v) State.SpeedMult = v; ProcessAllTools() end })
    tab:CreateButton({ name = "⚔️ Apply Melee Stats", callback = function()
        ProcessAllTools(); Toast("Applied", "Melee stats updated")
    end })
end

-- =================================================================
-- BUILD ITEMS TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "📦 Items" })
    tab:CreateSection({ name = "🎁 Auto Loot" })
    tab:CreateToggle({ name = "Auto Loot", flag = "AutoLoot", value = false,
        callback = function(v) State.AutoLoot = v end })
    tab:CreateSlider({ name = "Loot Range", flag = "AutoLootRange",
        range = {5,25}, increment = 1, value = 20, suffix = " studs",
        callback = function(v) State.AutoLootRange = v end })
    tab:CreateToggle({ name = "Auto-Store After Pickup", flag = "AutoStore", value = false,
        callback = function(v) State.AutoStore = v end })
    tab:CreateToggle({ name = "ProximityPrompt Fallback", flag = "ProxFallback", value = true,
        callback = function(v) State.ProxFallback = v end })

    tab:CreateDivider({ text = "filter" })
    tab:CreateSection({ name = "🎯 Loot Filter" })
    Filters.LootDropdown = tab:CreateDropdown({
        name = "Items to Auto-Loot", flag = "LootFilterItems",
        options = ItemDatabase.All, value = {}, multiSelect = true,
        callback = function(sel)
            table.clear(Filters.LootItems)
            if type(sel) == "table" then
                for _, n in ipairs(sel) do Filters.LootItems[n] = true end
            end
        end,
    })

    tab:CreateDivider({ text = "presets" })
    tab:CreateSection({ name = "⚡ Quick Select" })
    local function SelectCat(catName)
        local list = ItemDatabase.ByCategory[catName]
        if not list then Notify("Missing", catName, 2); return end
        table.clear(Filters.LootItems)
        for _, n in ipairs(list) do Filters.LootItems[n] = true end
        pcall(function() Filters.LootDropdown:Set(list) end)
        Toast("Filter", catName .. " (" .. #list .. ")")
    end

    local g = tab:CreateGroup()
    local l = g:CreateGroup({ direction = "column" })
    local r = g:CreateGroup({ direction = "column" })
    l:CreateButton({ name = "💥 All Ammo",       callback = function() SelectCat("Ammo") end })
    l:CreateButton({ name = "🍞 All Food",       callback = function() SelectCat("Food") end })
    l:CreateButton({ name = "🔫 All Guns",       callback = function() SelectCat("Tool_Guns") end })
    l:CreateButton({ name = "⚔️ All Melee",      callback = function() SelectCat("Tool_Melee") end })
    l:CreateButton({ name = "🛡️ All Armor",      callback = function() SelectCat("Armor") end })
    l:CreateButton({ name = "💊 All Medical",    callback = function() SelectCat("Tool_Medical") end })
    r:CreateButton({ name = "⛽ All Fuel",       callback = function() SelectCat("Fuel") end })
    r:CreateButton({ name = "🔧 All Resources",  callback = function() SelectCat("Resources") end })
    r:CreateButton({ name = "💎 Alien Crystals", callback = function() SelectCat("AlienCrystals") end })
    r:CreateButton({ name = "🎒 All Backpacks",  callback = function() SelectCat("Tool_Backpacks") end })
    r:CreateButton({ name = "🚗 Car Attach.",    callback = function() SelectCat("Tool_CarAttachments") end })
    r:CreateButton({ name = "🗑️ Clear Filter",   callback = function()
        table.clear(Filters.LootItems)
        pcall(function() Filters.LootDropdown:Set({}) end)
        Toast("Cleared", "Looting everything")
    end })

    tab:CreateDivider()
    tab:CreateButton({ name = "🔄 Refresh Database", callback = function()
        BuildItemDatabase()
        pcall(function() Filters.LootDropdown:Refresh(ItemDatabase.All) end)
        Toast("Refreshed", #ItemDatabase.All .. " items")
    end })
end

-- =================================================================
-- BUILD BACKPACK TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "🎒 Backpack" })
    tab:CreateSection({ name = "📋 Contents" })
    local console = tab:CreateConsole({ name = "Stored Items", height = 280, follow = false, maxLines = 300 })
    Stats.BPConsole = console

    tab:CreateDivider({ text = "controls" })
    tab:CreateSection({ name = "⚙️ Controls" })
    tab:CreateButton({
        name = "🔄 Refresh Now",
        callback = function()
            pcall(function() console:Set(BuildBackpackText()) end)
            Toast("Refreshed", "Contents updated")
        end,
    })
    tab:CreateToggle({ name = "Auto-Refresh (1s)", flag = "BPRefresh", value = true,
        callback = function(v) State.BPRefresh = v end })
    tab:CreateButton({
        name = "📋 Copy Contents",
        callback = function()
            if setclipboard then
                setclipboard(BuildBackpackText())
                Toast("Copied", "Contents in clipboard")
            end
        end,
    })
    tab:CreateText({
        name = "About",
        text = "Reads ReplicatedStorage.BackpackStorage live.\nGroups items by ItemType and shows attributes.",
    })
end

-- =================================================================
-- BUILD ESP TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "👁️ ESP" })
    local function CreateESP(target, tag, customName, color)
        if not target then return end
        local adornee = target:IsA("BasePart") and target
            or (target:IsA("Model") and (target.PrimaryPart or target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildOfClass("BasePart")))
        if not adornee then return end
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local distText = ""
        if hrp and State.ESPShowDistance then
            distText = " [" .. math.floor((hrp.Position - adornee.Position).Magnitude) .. "m]"
        end
        local display = State.ESPShowNames and ((customName or target.Name) .. distText) or distText:gsub("^%s+","")
        local existing = adornee:FindFirstChild(tag)
        if existing then
            local lbl = existing:FindFirstChildOfClass("TextLabel")
            if lbl then lbl.Text = display; lbl.TextColor3 = color end
            return
        end
        local gui = Instance.new("BillboardGui")
        gui.Name = tag; gui.Adornee = adornee
        gui.Size = UDim2.new(0,200,0,30); gui.StudsOffset = Vector3.new(0,2.5,0)
        gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.Parent = adornee
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
        lbl.Text = display; lbl.TextColor3 = color
        lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.new(0,0,0)
        lbl.TextSize = 14; lbl.Font = Enum.Font.SourceSansBold
        lbl.Parent = gui
    end
    local function RemoveESP(parent, tag)
        if not parent then return end
        for _, item in ipairs(parent:GetDescendants()) do
            if item:IsA("BillboardGui") and item.Name == tag then item:Destroy() end
        end
    end

    tab:CreateSection({ name = "⚙️ Config" })
    tab:CreateToggle({ name = "Show Names", flag = "ESPNames", value = true,
        callback = function(v) State.ESPShowNames = v end })
    tab:CreateToggle({ name = "Show Distance", flag = "ESPDistance", value = true,
        callback = function(v) State.ESPShowDistance = v end })

    tab:CreateDivider({ text = "characters" })
    tab:CreateSection({ name = "👁️ Character ESP" })
    tab:CreateToggle({ name = "Zombie ESP", flag = "ZombieESP", value = false,
        callback = function(v)
            State.ZombieESP = v
            if not v then RemoveESP(Workspace:FindFirstChild("Characters"), "ZombieESP")
            else task.spawn(function()
                while State.ZombieESP do
                    local chars = Workspace:FindFirstChild("Characters")
                    if chars then for _, c in ipairs(chars:GetChildren()) do
                        if c:IsA("Model") and isZombieEnemy(c) and canBeDamaged(c) then
                            CreateESP(c, "ZombieESP", c.Name, Color3.fromRGB(255,50,50))
                        end
                    end end
                    task.wait(0.2)
                end
            end) end
        end })
    tab:CreateToggle({ name = "Player ESP", flag = "PlayerESP", value = false,
        callback = function(v)
            State.PlayerESP = v
            if not v then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character then RemoveESP(p.Character, "PlayerESP") end
                end
            else task.spawn(function()
                while State.PlayerESP do
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character then
                            CreateESP(p.Character, "PlayerESP", p.Name, Color3.fromRGB(50,150,255))
                        end
                    end
                    task.wait(0.2)
                end
            end) end
        end })
    tab:CreateToggle({ name = "Survivor ESP", flag = "SurvivorESP", value = false,
        callback = function(v)
            State.SurvivorESP = v
            if not v then
                local m = Workspace:FindFirstChild("Map")
                local s = m and m:FindFirstChild("Survivors")
                RemoveESP(s, "SurvivorESP")
            else task.spawn(function()
                while State.SurvivorESP do
                    local m = Workspace:FindFirstChild("Map")
                    local s = m and m:FindFirstChild("Survivors")
                    if s then for _, x in ipairs(s:GetChildren()) do
                        if x:IsA("Model") then
                            CreateESP(x, "SurvivorESP", "Survivor: " .. x.Name, Color3.fromRGB(0,255,130))
                        end
                    end end
                    task.wait(0.3)
                end
            end) end
        end })
    tab:CreateToggle({ name = "Airdrop ESP", flag = "AirdropESP", value = false,
        callback = function(v)
            State.AirdropESP = v
            if not v then
                local m = Workspace:FindFirstChild("Map")
                local s = m and m:FindFirstChild("Special")
                RemoveESP(s, "AirdropESP")
            else task.spawn(function()
                while State.AirdropESP do
                    local m = Workspace:FindFirstChild("Map")
                    local s = m and m:FindFirstChild("Special")
                    if s then for _, x in ipairs(s:GetChildren()) do
                        if x:IsA("Model") or x:IsA("BasePart") then
                            CreateESP(x, "AirdropESP", "★ AIRDROP: " .. x.Name, Color3.fromRGB(255,0,200))
                        end
                    end end
                    task.wait(0.3)
                end
            end) end
        end })

    tab:CreateDivider({ text = "items" })
    tab:CreateSection({ name = "📦 Item ESP" })
    tab:CreateToggle({ name = "Enable Item ESP", flag = "ItemESP", value = false,
        callback = function(v)
            State.ItemESP = v
            if not v then RemoveESP(Workspace:FindFirstChild("DroppedItems"), "ItemESP") end
        end })
    Filters.ESPDropdown = tab:CreateDropdown({
        name = "Items to Highlight", flag = "ESPFilterItems",
        options = ItemDatabase.All, value = {}, multiSelect = true,
        callback = function(sel)
            table.clear(Filters.ESPItems)
            if type(sel) == "table" then
                for _, n in ipairs(sel) do Filters.ESPItems[n] = true end
            end
        end,
    })
    tab:CreateButton({ name = "🔄 Refresh ESP List", callback = function()
        BuildItemDatabase()
        pcall(function() Filters.ESPDropdown:Refresh(ItemDatabase.All) end)
        Toast("Refreshed", #ItemDatabase.All .. " items")
    end })
end

-- =================================================================
-- BUILD MISC TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "🛠️ Misc" })
    tab:CreateSection({ name = "🎨 Visuals" })
    tab:CreateToggle({ name = "Remove Fog", flag = "RemoveFog", value = false,
        callback = function(v)
            State.RemoveFog = v
            if v then
                Lighting.FogEnd = 9e9
                local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
                if atmo then atmo.Density = 0 end
                task.spawn(function()
                    while State.RemoveFog do
                        Lighting.FogEnd = 9e9
                        if atmo then atmo.Density = 0 end
                        RunService.RenderStepped:Wait()
                    end
                end)
            else
                Lighting.FogEnd = 1000
            end
        end })
    tab:CreateToggle({ name = "Fullbright", flag = "Fullbright", value = false,
        callback = function(v)
            State.Fullbright = v
            if v then
                task.spawn(function()
                    while State.Fullbright do
                        Lighting.Brightness = 2; Lighting.ClockTime = 14
                        Lighting.GlobalShadows = false
                        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
                        RunService.RenderStepped:Wait()
                    end
                end)
            else
                Lighting.Brightness = 1; Lighting.GlobalShadows = true
                Lighting.OutdoorAmbient = Color3.fromRGB(127,127,127)
            end
        end })
    tab:CreateToggle({ name = "Infinite Zoom", flag = "InfZoom", value = false,
        callback = function(v)
            State.InfZoom = v
            if v then
                LocalPlayer.CameraMaxZoomDistance = 99999
                task.spawn(function()
                    while State.InfZoom do
                        LocalPlayer.CameraMaxZoomDistance = 99999
                        RunService.RenderStepped:Wait()
                    end
                end)
            else LocalPlayer.CameraMaxZoomDistance = 128 end
        end })

    tab:CreateDivider({ text = "interaction" })
    tab:CreateSection({ name = "⚡ Prompts" })
    tab:CreateToggle({ name = "Instant Proximity Prompts", flag = "InstantPrompts", value = false,
        callback = function(v)
            State.InstantPrompts = v
            if v then
                ApplyInstantPrompts()
                if not Prompts.Connection then
                    Prompts.Connection = Workspace.DescendantAdded:Connect(function(desc)
                        if State.InstantPrompts then MakePromptInstant(desc) end
                    end)
                end
                Toast("Prompts", "Enabled")
            else
                if Prompts.Connection then Prompts.Connection:Disconnect(); Prompts.Connection = nil end
                RestorePrompts()
                Toast("Prompts", "Disabled")
            end
        end })
end

-- =================================================================
-- BUILD INFO TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "ℹ️ Info" })
    tab:CreateSection({ name = "ℹ️ About" })
    tab:CreateText({ name = "KissoHub — Survive the Apocalypse",
        text = "Version: " .. HUB_VERSION .. "\nConfig: KissoHubFolder/STAPrefs.rfld" })
    tab:CreateDivider({ text = "changelog" })
    tab:CreateSection({ name = "📋 Changelog" })
    tab:CreateText({ name = HUB_VERSION .. " — Latest",
        text = "• FIX: Lua register overflow (wrapped tabs in scoped blocks)\n" ..
               "• Refactored state into single State table\n• Backpack tab remains with live console" })
    tab:CreateText({ name = "v1.3.4",
        text = "• Backpack tab with live contents viewer\n• Category summary stats on Home" })
end

-- =================================================================
-- REMOTE DISCOVERY
-- =================================================================
task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
    if not remotes then return end
    local interaction = remotes:WaitForChild("Interaction", 5)
    if interaction then Remotes.PickUpItem = interaction:WaitForChild("PickUpItem", 5) end
    local tf = remotes:WaitForChild("Tools", 5)
    if tf then Remotes.AdjustBackpack = tf:WaitForChild("AdjustBackpack", 5) end
end)

-- =================================================================
-- MAIN LOOPS
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.05)
        if State.AutoShoot then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool and tool:GetAttribute("ToolType") == "Gun" then
                    local shoot = tool:FindFirstChild("Shoot")
                    if shoot then
                        local myPos = getLocalRootPosition()
                        local targetPart = getClosestZombie(State.AutoShootRange)
                        if targetPart and targetPart.Parent then
                            local sync = tool:FindFirstChild("SyncAmmo")
                            if sync then pcall(function() sync:FireServer() end) end
                            local payload = {{
                                Target = targetPart.Position,
                                HitData = {{ HitChar = targetPart.Parent, HitPos = targetPart.Position, HitPart = targetPart }},
                                EffectResults = {{ Origin = myPos, End = targetPart.Position }}
                            }}
                            pcall(function() shoot:FireServer(myPos, payload, 0, 4) end)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if State.KillAura or State.AutoSwing then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool and tool:GetAttribute("ToolType") == "Melee" then
                local swing = tool:FindFirstChild("Swing")
                local hit = tool:FindFirstChild("HitTargets")
                if swing and hit then
                    pcall(function() swing:FireServer() end)
                    if State.KillAura then
                        local targets = GetMeleeTargets()
                        if #targets > 0 then
                            task.wait(State.ZeroWindUp and 0.05 or 0.3)
                            pcall(function() hit:FireServer(targets) end)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.3)
        if State.AutoLoot then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local myPos = hrp.Position
                local dropped = Workspace:FindFirstChild("DroppedItems")
                if dropped and Remotes.PickUpItem then
                    for _, item in ipairs(dropped:GetChildren()) do
                        local d = (item:GetPivot().Position - myPos).Magnitude
                        if d <= State.AutoLootRange and ShouldLoot(item.Name) then
                            pcall(function() Remotes.PickUpItem:FireServer(item) end)
                            task.wait(0.05)
                            if State.AutoStore and Remotes.AdjustBackpack then
                                task.wait(0.15)
                                pcall(function() Remotes.AdjustBackpack:FireServer(item) end)
                            end
                        end
                    end
                end
                if State.ProxFallback then
                    for _, prompt in ipairs(Workspace:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                            local parent = prompt.Parent
                            local pos = parent:IsA("BasePart") and parent.Position
                                or (parent:IsA("Model") and parent.PrimaryPart and parent.PrimaryPart.Position)
                            if pos and (pos - myPos).Magnitude <= State.AutoLootRange and fireproximityprompt then
                                pcall(function() fireproximityprompt(prompt) end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.3)
        if State.ItemESP then
            local dropped = Workspace:FindFirstChild("DroppedItems")
            if dropped then
                local hasFilter = next(Filters.ESPItems) ~= nil
                for _, item in ipairs(dropped:GetChildren()) do
                    local show = (not hasFilter) or Filters.ESPItems[item.Name]
                    if show then
                        local cat = ItemDatabase.Lookup[item.Name] or "Misc"
                        local color = CategoryColors[cat] or Color3.fromRGB(255,255,150)
                        -- inline ESP build
                        local adornee = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
                        if adornee then
                            local existing = adornee:FindFirstChild("ItemESP")
                            if not existing then
                                local gui = Instance.new("BillboardGui")
                                gui.Name = "ItemESP"; gui.Adornee = adornee
                                gui.Size = UDim2.new(0,180,0,25); gui.StudsOffset = Vector3.new(0,2,0)
                                gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.Parent = adornee
                                local lbl = Instance.new("TextLabel")
                                lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
                                lbl.Text = item.Name; lbl.TextColor3 = color
                                lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.new(0,0,0)
                                lbl.TextSize = 13; lbl.Font = Enum.Font.SourceSansBold
                                lbl.Parent = gui
                            end
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.2) do
        if State.AutoReload then
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool and tool:GetAttribute("ToolType") == "Gun" then
                local ammo = tool:GetAttribute("Ammo")
                if type(ammo) == "number" and ammo <= 0 then
                    if State.InstantReload then ApplyInstantReload(tool) end
                    TriggerRemoteReload(tool)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        if State.AutoTargetSync then
            local char = LocalPlayer.Character
            local atc = char and char:FindFirstChild("AutoTargetClient")
            local remote = atc and atc:FindFirstChild("UpdateNearbyTargets")
            if remote then
                local t = GetValidTargets()
                if #t > 0 then pcall(function() remote:FireServer(t) end) end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if State.NoRecoil or State.NoSpread then
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool and tool:GetAttribute("ToolType") == "Gun" then ApplyNoRecoilSpread(tool) end
        end
    end
end)

-- =================================================================
-- BACKPACK MONITOR
-- =================================================================
task.spawn(function()
    local lastSnapshot = ""
    while true do
        task.wait(State.BPRefresh and 1 or 5)
        if State.BPRefresh then
            pcall(function()
                local items, total, byType = ReadBackpackStorage()
                if Stats.BPTotal then Stats.BPTotal:Set(total) end
                if Stats.BPFuel  then Stats.BPFuel:Set(byType.Fuel or 0) end
                if Stats.BPFood  then Stats.BPFood:Set(byType.Food or 0) end
                if Stats.BPRes   then Stats.BPRes:Set(byType.Resource or 0) end
                if Stats.BPAmmo  then Stats.BPAmmo:Set(byType.Ammo or 0) end
                local other = 0
                for t, n in pairs(byType) do
                    if t ~= "Fuel" and t ~= "Food" and t ~= "Resource" and t ~= "Ammo" then
                        other += n
                    end
                end
                if Stats.BPOther then Stats.BPOther:Set(other) end

                local snap = tostring(total)
                for _, info in ipairs(items) do snap = snap .. "|" .. info.name end
                if snap ~= lastSnapshot then
                    lastSnapshot = snap
                    if Stats.BPConsole then pcall(function() Stats.BPConsole:Set(BuildBackpackText()) end) end
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
            if State.SilentAim and method == "FireServer" and tostring(self) == "Shoot" then
                local target = getClosestZombie()
                if target and target.Parent then
                    local args = {...}
                    local origin = args[1] or getLocalRootPosition()
                    args[2] = {{
                        Target = target.Position,
                        HitData = {{ HitChar = target.Parent, HitPos = target.Position, HitPart = target }},
                        EffectResults = {{ Origin = origin, End = target.Position }}
                    }}
                    return raw(self, table.unpack(args))
                end
            end
            return raw(self, ...)
        end)
    end)
end

-- =================================================================
-- LIVE REFRESH
-- =================================================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local mins = math.floor((os.time() - SESSION_START) / 60)
            local active = 0
            for _, k in ipairs({"AutoShoot","SilentAim","KillAura","AutoSwing","ZeroWindUp",
                "ZeroEndlag","NoRecoil","NoSpread","AutoReload","AutoLoot","AutoStore",
                "ItemESP","ZombieESP","PlayerESP","SurvivorESP","AirdropESP","InstantPrompts"}) do
                if State[k] then active += 1 end
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
            if ls then local k = ls:FindFirstChild("Kills"); if k then kills = k.Value end end
            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then health = math.floor(hum.Health) end
            end

            if Stats.Session then Stats.Session:Set(mins) end
            if Stats.Features then Stats.Features:Set(active) end
            if Stats.Fps then Stats.Fps:Set(math.floor(Workspace:GetRealPhysicsFPS() or 60)) end
            if Stats.Players then Stats.Players:Set(#Players:GetPlayers()) end
            if Stats.Targets then Stats.Targets:Set(targetCount) end
            if Stats.Ammo then Stats.Ammo:Set(ammoTotal) end
            if Stats.Kills then Stats.Kills:Set(kills) end
            if Stats.Health then Stats.Health:Set(health) end

            if State.AutoLoot then
                StateTag:Set({ text = "LOOTING", color = Color3.fromRGB(0,200,255) })
            elseif State.KillAura or State.AutoSwing then
                StateTag:Set({ text = "MELEE", color = Color3.fromRGB(255,130,40) })
            elseif State.AutoShoot then
                StateTag:Set({ text = "AUTO-SHOOT", color = Color3.fromRGB(255,80,80) })
            elseif active > 0 then
                StateTag:Set({ text = "ACTIVE", color = Color3.fromRGB(0,220,130) })
            else
                StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190,40,220) })
            end
        end)
    end
end)

Notify("KissoHub", "Survive the Apocalypse " .. HUB_VERSION .. " loaded", 3)
