-- ═══════════════════════════════════════════════════════════════
--   KissoHub — Survive the Apocalypse Module  |  v1.3.1
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
local HUB_VERSION = "v1.3.1"
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

-- Enhanced Loot
local AutoLootEnabled     = false
local AutoLootRange       = 20
local AutoStoreEnabled    = false
local ProxFallbackEnabled = true
local LootFilter          = "All Items"
local LootRemotes = {
    PickUpItem      = nil,
    AdjustBackpack  = nil,
}

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

-- =================================================================
-- NO RECOIL / NO SPREAD
-- =================================================================
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

-- =================================================================
-- MELEE HELPERS
-- =================================================================
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

-- =================================================================
-- RELOAD
-- =================================================================
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

-- =================================================================
-- LOOT FILTER
-- =================================================================
local function ShouldLoot(itemName)
    if LootFilter == "All Items" then return true end
    local n = itemName:lower()
    if LootFilter == "Weapons & Ammo" then
        return n:find("ammo") or n:find("gun") or n:find("rifle") or n:find("pistol")
            or n:find("shotgun") or n:find("mag") or n:find("clip") or n:find("sniper")
            or n:find("uzi") or n:find("lmg") or n:find("ak")
    elseif LootFilter == "Food & Meds" then
        return n:find("food") or n:find("bandage") or n:find("med") or n:find("drink")
            or n:find("cola") or n:find("chips") or n:find("canned") or n:find("health")
            or n:find("carrot") or n:find("burger") or n:find("water") or n:find("food")
    elseif LootFilter == "Resources" then
        return n:find("wood") or n:find("scrap") or n:find("metal") or n:find("fuel")
            or n:find("cloth") or n:find("wire") or n:find("nail") or n:find("screw")
            or n:find("bucket") or n:find("spatula")
    elseif LootFilter == "Skip Junk" then
        return not (n:find("burger") or n:find("chips") or n:find("junk") or n:find("trash"))
    end
    return true
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
local HomeTab   = Window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })
local CombatTab = Window:CreateTab({ name = "🔫 Gun Combat" })
local MeleeTab  = Window:CreateTab({ name = "⚔️ Melee" })
local ItemsTab  = Window:CreateTab({ name = "📦 Items" })
local ESPTab    = Window:CreateTab({ name = "👁️ ESP" })
local MiscTab   = Window:CreateTab({ name = "🛠️ Misc" })
local InfoTab   = Window:CreateTab({ name = "ℹ️ Info" })

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

CombatTab:CreateToggle({
    name = "Auto-Shoot Target",
    flag = "AutoShoot",
    value = false,
    callback = function(v) Settings.AutoShootEnabled = v end,
})

CombatTab:CreateSlider({
    name = "Auto-Shoot Range",
    flag = "AutoShootRange",
    range = { 25, 1000 }, increment = 25, value = 500, suffix = " studs",
    callback = function(v) Settings.AutoShootRange = v end,
})

CombatTab:CreateToggle({
    name = "Silent Aim",
    flag = "SilentAim",
    value = false,
    callback = function(v) Settings.SilentAimEnabled = v end,
})

CombatTab:CreateToggle({
    name = "Ignore Human Players",
    flag = "IgnorePlayers",
    value = true,
    callback = function(v) Settings.IgnorePlayers = v end,
})

CombatTab:CreateToggle({
    name = "Check Damageable / SafeZones",
    flag = "CheckDamageable",
    value = true,
    callback = function(v) Settings.CheckDamageable = v end,
})

CombatTab:CreateDivider({ text = "recoil & spread" })
CombatTab:CreateSection({ name = "🎯 No Recoil / No Spread" })

CombatTab:CreateToggle({
    name = "No Recoil",
    flag = "NoRecoil",
    value = false,
    callback = function(v) NoRecoilEnabled = v; if v then ProcessAllTools() end end,
})

CombatTab:CreateToggle({
    name = "No Spread",
    flag = "NoSpread",
    value = false,
    callback = function(v) NoSpreadEnabled = v; if v then ProcessAllTools() end end,
})

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

CombatTab:CreateToggle({
    name = "Auto Reload (When Empty)",
    flag = "AutoReload",
    value = false,
    callback = function(v) AutoReloadEnabled = v end,
})

CombatTab:CreateToggle({
    name = "Instant Reload",
    flag = "InstantReload",
    value = false,
    callback = function(v) InstantReload = v; if v then ProcessAllTools() end end,
})

CombatTab:CreateToggle({
    name = "Remote Bypass Reload",
    flag = "RemoteReload",
    value = false,
    callback = function(v) RemoteFastReload = v; if v then ProcessAllTools() end end,
})

CombatTab:CreateButton({
    name = "Force Instant Reload",
    callback = function()
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then ApplyInstantReload(tool); TriggerRemoteReload(tool) end
    end,
})

CombatTab:CreateToggle({
    name = "Auto-Sync Targets (Server Radar)",
    flag = "AutoTargetSync",
    value = false,
    callback = function(v) AutoTargetSync = v end,
})

-- =================================================================
-- MELEE TAB
-- =================================================================
MeleeTab:CreateSection({ name = "⚔️ Auto Combat" })

MeleeTab:CreateToggle({
    name = "Auto Swing",
    flag = "MeleeAutoSwing",
    value = false,
    callback = function(v)
        MeleeAutoSwing = v
        if v then QuickToast("Auto Swing", "Spamming attacks") end
    end,
})

MeleeTab:CreateToggle({
    name = "Kill Aura",
    flag = "KillAura",
    value = false,
    callback = function(v)
        KillAuraEnabled = v
        if v then QuickToast("Kill Aura", "Enabled") end
    end,
})

MeleeTab:CreateSlider({
    name = "Kill Aura Range",
    flag = "KillAuraRange",
    range = { 4, 30 }, increment = 1, value = 12, suffix = " studs",
    callback = function(v) KillAuraRange = v end,
})

MeleeTab:CreateDropdown({
    name = "Target Priority",
    flag = "MeleeTargetPriority",
    options = { "Nearest", "Lowest HP", "Most Enemies" },
    value = { "Nearest" }, multiSelect = false,
    callback = function(o) MeleeTargetPriority = type(o) == "table" and o[1] or o end,
})

MeleeTab:CreateDivider({ text = "stats" })
MeleeTab:CreateSection({ name = "⚡ Melee Stats" })

MeleeTab:CreateToggle({
    name = "Zero WindUp",
    flag = "MeleeZeroWindUp",
    value = false,
    callback = function(v) MeleeZeroWindUp = v; ProcessAllTools() end,
})

MeleeTab:CreateToggle({
    name = "Zero Endlag",
    flag = "MeleeZeroEndlag",
    value = false,
    callback = function(v) MeleeZeroEndlag = v; ProcessAllTools() end,
})

MeleeTab:CreateSlider({
    name = "Animation Speed Multiplier",
    flag = "MeleeSpeedMult",
    range = { 1, 5 }, increment = 0.5, value = 1, suffix = "x",
    callback = function(v) MeleeSpeedMult = v; ProcessAllTools() end,
})

MeleeTab:CreateButton({
    name = "⚔️ Apply Melee Stats Now",
    callback = function()
        ProcessAllTools()
        QuickToast("Applied", "Melee stats updated")
    end,
})

-- =================================================================
-- ITEMS TAB (ENHANCED LOOT)
-- =================================================================
ItemsTab:CreateSection({ name = "🎁 Auto Loot" })

ItemsTab:CreateToggle({
    name = "Auto Loot (PickUpItem Remote)",
    flag = "AutoLoot",
    value = false,
    callback = function(v) AutoLootEnabled = v end,
})

ItemsTab:CreateSlider({
    name = "Loot Range",
    flag = "AutoLootRange",
    range = { 5, 25 }, increment = 1, value = 20, suffix = " studs",
    callback = function(v) AutoLootRange = v end,
})

ItemsTab:CreateToggle({
    name = "Auto-Store After Pickup",
    flag = "AutoStore",
    value = false,
    callback = function(v) AutoStoreEnabled = v end,
})

ItemsTab:CreateToggle({
    name = "Use ProximityPrompt Fallback",
    flag = "ProxFallback",
    value = true,
    callback = function(v) ProxFallbackEnabled = v end,
})

ItemsTab:CreateDivider({ text = "filters" })
ItemsTab:CreateSection({ name = "🎯 Item Filter" })

ItemsTab:CreateDropdown({
    name = "Loot Filter",
    flag = "LootFilter",
    options = { "All Items", "Weapons & Ammo", "Food & Meds", "Resources", "Skip Junk" },
    value = { "All Items" },
    multiSelect = false,
    callback = function(o) LootFilter = type(o) == "table" and o[1] or o end,
})

-- =================================================================
-- ESP TAB
-- =================================================================
ESPTab:CreateSection({ name = "⚙️ ESP Config" })

local ESPConfig = { ShowNames = true, ShowDistance = true }

ESPTab:CreateToggle({
    name = "Show Names",
    flag = "ESPNames",
    value = true,
    callback = function(v) ESPConfig.ShowNames = v end,
})

ESPTab:CreateToggle({
    name = "Show Distance",
    flag = "ESPDistance",
    value = true,
    callback = function(v) ESPConfig.ShowDistance = v end,
})

ESPTab:CreateDivider({ text = "targets" })
ESPTab:CreateSection({ name = "👁️ ESP Toggles" })

local ESPState = { Zombie = false, Player = false }

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
    name = "Zombie ESP",
    flag = "ZombieESP",
    value = false,
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
    name = "Player ESP",
    flag = "PlayerESP",
    value = false,
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

-- =================================================================
-- MISC TAB
-- =================================================================
MiscTab:CreateSection({ name = "🎨 Visuals" })

local FogConn, BrightnessConn, ZoomConn = nil, nil, nil

MiscTab:CreateToggle({
    name = "Remove Fog",
    flag = "RemoveFog",
    value = false,
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
    name = "Fullbright",
    flag = "Fullbright",
    value = false,
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
    name = "Infinite Zoom",
    flag = "InfZoom",
    value = false,
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
    text = "• NEW: Enhanced loot — PickUpItem remote direct fire\n" ..
           "• NEW: Auto-Store via AdjustBackpack remote\n" ..
           "• NEW: Item filter (Weapons / Food / Resources / Skip Junk)\n" ..
           "• NEW: ProximityPrompt fallback for items without remote\n" ..
           "• REAL RANGE: Server caps pickup at ~25 studs",
})

InfoTab:CreateText({
    name = "v1.3.0",
    text = "• Removed aimlock, loot aura, melee range circle, movement",
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
    -- Discover remotes async
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

                -- ProximityPrompt fallback
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
                AutoLootEnabled, AutoStoreEnabled
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
