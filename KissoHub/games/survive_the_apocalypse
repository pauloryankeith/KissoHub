-- ═══════════════════════════════════════════════════════════════
--   KissoHub — Survive the Apocalypse Module  |  v1.0.0
--   Author: pauloryankeith
--   Official: github.com/pauloryankeith/KissoHub
-- ═══════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local Workspace       = game:GetService("Workspace")
local Lighting        = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local ASSET_ICON  = "rbxassetid://89387722763691"
local HUB_VERSION = "v1.0.0"
local SESSION_START = os.time()

-- =================================================================
-- SETTINGS
-- =================================================================
local Settings = {
    AimlockEnabled   = true,
    AutoShootEnabled = false,
    AutoShootRange   = 500,
    TargetNearest    = true,
    SilentAimEnabled = false,
    Keybind          = Enum.UserInputType.MouseButton2,
    CheckDamageable  = true,
    TargetMode       = "Distance",
    MaxDistance      = 500,
    AimMethod        = "Camera",
    IgnorePlayers    = true,
    Smoothness       = 0.5,
    FOVSize          = 100,
    ShowFOV          = true,
    ShootDelay       = 0.05,
    AimPitch         = 0.00325,
}

local KillAuraEnabled       = false
local KillAuraRange         = 25
local AutoTargetSyncEnabled = false
local RemoteFastReload      = false
local InstantReload         = false
local AutoReloadEnabled     = false
local NoRecoilEnabled       = false
local NoSpreadEnabled       = false
local AutoLootEnabled       = false
local AutoLootRange         = 30

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
    pcall(function()
        Window:Notify({ title = title or "KissoHub", content = content or "", duration = duration or 4, icon = ASSET_ICON })
    end)
end

local function QuickToast(title, subtitle)
    pcall(function()
        Window:Toast({ title = title, subtitle = subtitle, position = "Top", icon = ASSET_ICON })
    end)
end

-- =================================================================
-- CORE HELPERS
-- =================================================================
local FOVCircle = nil
if Drawing and Drawing.new then
    pcall(function()
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Color = Color3.fromRGB(255, 50, 50)
        FOVCircle.Thickness = 1.5
        FOVCircle.NumSides = 64
        FOVCircle.Radius = Settings.FOVSize
        FOVCircle.Filled = false
        FOVCircle.Visible = Settings.ShowFOV
    end)
end

local function canBeDamaged(character)
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return false end

    if character:GetAttribute("Dead") or character:GetAttribute("Untargetable") then return false end

    if Settings.CheckDamageable then
        if character:FindFirstChildOfClass("ForceField") or character:FindFirstChild("ForceField") then return false end
        for _, attr in ipairs({"IsInvulnerable","Invulnerable","SafeZone","Protected","GodMode"}) do
            if character:GetAttribute(attr) == true then return false end
        end
    end
    return true
end

local function isPlayerCharacter(character)
    if not character then return false end
    if Players:GetPlayerFromCharacter(character) then return true end
    for _, attr in ipairs({"IsPlayer","Player","IsHuman"}) do
        if character:GetAttribute(attr) == true then return true end
    end
    return character:FindFirstChild("IsPlayer") ~= nil or character:FindFirstChild("Player") ~= nil
end

local function isZombieEnemy(character)
    if not character then return false end
    if character == LocalPlayer.Character then return false end
    if Settings.IgnorePlayers and isPlayerCharacter(character) then return false end
    return true
end

local function getTargetPart(character)
    if not character or not canBeDamaged(character) then return nil end
    return character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
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
    local closestPart = nil
    local shortestMetric = math.huge
    local mousePos = UserInputService:GetMouseLocation()
    local myPos = getLocalRootPosition()
    local maxDist = customMaxDist or Settings.MaxDistance
    local useDistanceMode = forceNearest or (Settings.TargetMode == "Distance")

    local charsFolder = Workspace:FindFirstChild("Characters") or Workspace
    for _, char in ipairs(charsFolder:GetChildren()) do
        if char:IsA("Model") and isZombieEnemy(char) and canBeDamaged(char) then
            local part = getTargetPart(char)
            if part then
                local worldDistance = (part.Position - myPos).Magnitude
                if maxDist == 0 or worldDistance <= maxDist then
                    if useDistanceMode then
                        if worldDistance < shortestMetric then
                            shortestMetric = worldDistance
                            closestPart = part
                        end
                    else
                        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local cursorDistance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if cursorDistance <= Settings.FOVSize and cursorDistance < shortestMetric then
                                shortestMetric = cursorDistance
                                closestPart = part
                            end
                        end
                    end
                end
            end
        end
    end
    return closestPart
end

local function GetValidTargets()
    local targets = {}
    local charsFolder = Workspace:FindFirstChild("Characters") or Workspace
    for _, enemy in ipairs(charsFolder:GetChildren()) do
        if enemy:IsA("Model") and isZombieEnemy(enemy) and canBeDamaged(enemy) then
            table.insert(targets, enemy)
        end
    end
    return targets
end

-- =================================================================
-- NO RECOIL / NO SPREAD ENGINE
-- =================================================================
local function ApplyNoRecoilSpread(tool)
    if not tool or not tool:IsA("Tool") then return end

    local recoilAttrs = {"Recoil","RecoilX","RecoilY","RecoilAmount","RecoilPower","RecoilMultiplier","CameraRecoil","Kick","Kickback","VerticalRecoil","HorizontalRecoil"}
    local spreadAttrs = {"Spread","SpreadAmount","SpreadMultiplier","BulletSpread","AccuracySpread","BaseSpread","HipFireSpread","ADSSpread","Inaccuracy"}

    if NoRecoilEnabled then
        for _, attr in ipairs(recoilAttrs) do
            pcall(function()
                if tool:GetAttribute(attr) ~= nil then tool:SetAttribute(attr, 0) end
            end)
        end
    end

    if NoSpreadEnabled then
        for _, attr in ipairs(spreadAttrs) do
            pcall(function()
                if tool:GetAttribute(attr) ~= nil then tool:SetAttribute(attr, 0) end
            end)
        end
    end

    for _, desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("ValueBase") and (desc:IsA("NumberValue") or desc:IsA("IntValue")) then
            local name = desc.Name:lower()
            if NoRecoilEnabled and (name:find("recoil") or name:find("kick") or name:find("kickback")) then
                pcall(function() desc.Value = 0 end)
            end
            if NoSpreadEnabled and (name:find("spread") or name:find("accuracy") or name:find("inaccuracy")) then
                pcall(function() desc.Value = 0 end)
            end
        end
    end
end

local function EnforceNoRecoilOnEquipped()
    if not (NoRecoilEnabled or NoSpreadEnabled) then return end
    local char = LocalPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then ApplyNoRecoilSpread(tool) end
end

-- =================================================================
-- TABS
-- =================================================================
local HomeTab     = Window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })
local CombatTab   = Window:CreateTab({ name = "🎯 Combat" })
local ItemsTab    = Window:CreateTab({ name = "📦 Items & Crates" })
local MovementTab = Window:CreateTab({ name = "🏃 Movement" })
local ESPTab      = Window:CreateTab({ name = "👁️ ESP" })
local MiscTab     = Window:CreateTab({ name = "🛠️ Misc" })
local InfoTab     = Window:CreateTab({ name = "ℹ️ Info" })

-- =================================================================
-- HOME TAB (2-column grid)
-- =================================================================
HomeTab:CreateSection({ name = "📊 Session Stats" })

local StatsGrid = HomeTab:CreateGroup()
local StatsLeft = StatsGrid:CreateGroup({ direction = "column" })
local StatsRight = StatsGrid:CreateGroup({ direction = "column" })

local SessionStat = StatsLeft:CreateStat({ name = "⏱️ Session", value = 0, suffix = " m", compact = true })
local FpsStat     = StatsLeft:CreateStat({ name = "🎮 FPS", value = 0, compact = true })
local PlayersStat = StatsLeft:CreateStat({ name = "👥 Players", value = 1, compact = true })

local FeaturesStat = StatsRight:CreateStat({ name = "⚙️ Features", value = 0, compact = true })
local TargetsStat  = StatsRight:CreateStat({ name = "🧟 Targets", value = 0, compact = true })

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
-- COMBAT TAB
-- =================================================================
CombatTab:CreateSection({ name = "🎯 Aim & Fire" })

CombatTab:CreateToggle({
    name = "Enable Aimlock",
    flag = "AimlockEnabled",
    value = true,
    callback = function(v) Settings.AimlockEnabled = v end,
})

CombatTab:CreateToggle({
    name = "Auto-Shoot Target",
    flag = "AutoShootEnabled",
    value = false,
    callback = function(v) Settings.AutoShootEnabled = v end,
})

CombatTab:CreateSlider({
    name = "Auto-Shoot Range",
    flag = "AutoShootRange",
    range = {25, 1000}, increment = 25, value = 500, suffix = " studs",
    callback = function(v) Settings.AutoShootRange = v end,
})

CombatTab:CreateToggle({
    name = "Target Nearest Enemy",
    flag = "TargetNearest",
    value = true,
    callback = function(v) Settings.TargetNearest = v end,
})

CombatTab:CreateToggle({
    name = "Silent Aim",
    flag = "SilentAim",
    value = false,
    callback = function(v) Settings.SilentAimEnabled = v end,
})

CombatTab:CreateDivider({ text = "melee" })
CombatTab:CreateSection({ name = "⚔️ Kill Aura" })

CombatTab:CreateToggle({
    name = "Melee Kill Aura",
    flag = "KillAura",
    value = false,
    callback = function(v) KillAuraEnabled = v end,
})

CombatTab:CreateSlider({
    name = "Kill Aura Range",
    flag = "KillAuraRange",
    range = {10, 50}, increment = 5, value = 25, suffix = " studs",
    callback = function(v) KillAuraRange = v end,
})

CombatTab:CreateDivider({ text = "recoil & spread" })
CombatTab:CreateSection({ name = "🎯 No Recoil / No Spread" })

CombatTab:CreateToggle({
    name = "No Recoil (Zero Weapon Kick)",
    flag = "NoRecoil",
    value = false,
    callback = function(v)
        NoRecoilEnabled = v
        if v then QuickToast("No Recoil", "Enabled — applied to equipped gun") end
    end,
})

CombatTab:CreateToggle({
    name = "No Spread (Perfect Accuracy)",
    flag = "NoSpread",
    value = false,
    callback = function(v)
        NoSpreadEnabled = v
        if v then QuickToast("No Spread", "Enabled — perfect accuracy") end
    end,
})

CombatTab:CreateButton({
    name = "🎯 Apply Now to Equipped Gun",
    callback = function()
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildOfClass("Tool")
        if tool then
            ApplyNoRecoilSpread(tool)
            QuickToast("Applied", "No Recoil/Spread → " .. tool.Name)
        else
            SafeNotify("No Tool", "Equip a gun first", 3)
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
        if tool then
            ApplyInstantReload(tool)
            TriggerRemoteReload(tool)
        end
    end,
})

CombatTab:CreateToggle({
    name = "Auto-Sync Targets (Server Radar)",
    flag = "AutoTargetSync",
    value = false,
    callback = function(v) AutoTargetSyncEnabled = v end,
})

CombatTab:CreateDivider({ text = "aim config" })
CombatTab:CreateSection({ name = "⚙️ Aim Settings" })

CombatTab:CreateDropdown({
    name = "Target Mode",
    flag = "TargetMode",
    options = {"Distance", "Cursor"},
    value = {"Distance"},
    multiSelect = false,
    callback = function(o)
        Settings.TargetMode = type(o) == "table" and o[1] or o
    end,
})

CombatTab:CreateDropdown({
    name = "Aim Method",
    flag = "AimMethod",
    options = {"Camera", "MouseRel"},
    value = {"Camera"},
    multiSelect = false,
    callback = function(o)
        Settings.AimMethod = type(o) == "table" and o[1] or o
    end,
})

CombatTab:CreateSlider({
    name = "Smoothness",
    flag = "Smoothness",
    range = {0.1, 1.0}, increment = 0.05, value = 0.5,
    callback = function(v) Settings.Smoothness = v end,
})

CombatTab:CreateSlider({
    name = "FOV Size",
    flag = "FOVSize",
    range = {30, 500}, increment = 10, value = 100,
    callback = function(v)
        Settings.FOVSize = v
        if FOVCircle then FOVCircle.Radius = v end
    end,
})

CombatTab:CreateToggle({
    name = "Show FOV Circle",
    flag = "ShowFOV",
    value = true,
    callback = function(v)
        Settings.ShowFOV = v
        if FOVCircle then FOVCircle.Visible = v end
    end,
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

CombatTab:CreateSlider({
    name = "Max Lock Distance",
    flag = "MaxDistance",
    range = {0, 1000}, increment = 25, value = 500, suffix = " studs",
    callback = function(v) Settings.MaxDistance = v end,
})

-- =================================================================
-- ITEMS & CRATES TAB
-- =================================================================
ItemsTab:CreateSection({ name = "🎁 Loot" })

ItemsTab:CreateToggle({
    name = "Auto Loot Aura",
    flag = "AutoLoot",
    value = false,
    callback = function(v) AutoLootEnabled = v end,
})

ItemsTab:CreateSlider({
    name = "Loot Range",
    flag = "AutoLootRange",
    range = {10, 150}, increment = 5, value = 30, suffix = " studs",
    callback = function(v) AutoLootRange = v end,
})

ItemsTab:CreateDivider({ text = "targets" })
ItemsTab:CreateSection({ name = "🎯 Item / Crate Selector" })

local SelectedItemName = nil
local SelectedCrateName = nil

local function GetGroupedItemNames()
    local counts = {}
    local dropped = Workspace:FindFirstChild("DroppedItems")
    if dropped then
        for _, item in ipairs(dropped:GetChildren()) do
            counts[item.Name] = (counts[item.Name] or 0) + 1
        end
    end
    local options = {}
    for name, count in pairs(counts) do
        table.insert(options, string.format("%s x%d", name, count))
    end
    if #options == 0 then table.insert(options, "No items found")
    else table.sort(options) end
    return options
end

local ItemDropdown = ItemsTab:CreateDropdown({
    name = "Select Target Item",
    flag = "SelectedItem",
    options = GetGroupedItemNames(),
    value = {"No items found"},
    multiSelect = false,
    callback = function(o)
        local raw = type(o) == "table" and o[1] or o
        if raw and raw ~= "No items found" then
            SelectedItemName = raw:match("^(.-)%s*x%d+$") or raw
        else
            SelectedItemName = nil
        end
    end,
})

task.spawn(function()
    local last = ""
    while task.wait(1) do
        local cur = GetGroupedItemNames()
        local ser = table.concat(cur, "|")
        if ser ~= last then
            last = ser
            pcall(function() ItemDropdown:Refresh(cur) end)
        end
    end
end)

local function GetCrateNames()
    local names = {}
    local crates = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Crates")
    if crates then
        for i, c in ipairs(crates:GetChildren()) do
            table.insert(names, string.format("[%d] %s", i, c.Name))
        end
    end
    if #names == 0 then table.insert(names, "No crates found") end
    return names
end

local CrateDropdown = ItemsTab:CreateDropdown({
    name = "Select Crate / Chest",
    flag = "SelectedCrate",
    options = GetCrateNames(),
    value = {"No crates found"},
    multiSelect = false,
    callback = function(o)
        SelectedCrateName = type(o) == "table" and o[1] or o
    end,
})

ItemsTab:CreateButton({
    name = "🔄 Refresh Crate List",
    callback = function()
        pcall(function() CrateDropdown:Refresh(GetCrateNames()) end)
    end,
})

-- =================================================================
-- MOVEMENT TAB
-- =================================================================
MovementTab:CreateSection({ name = "🏃 Movement" })

MovementTab:CreateSlider({
    name = "WalkSpeed",
    flag = "WalkSpeed",
    range = {16, 120}, increment = 2, value = 16,
    callback = function(v)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end,
})

local NoclipConn = nil
MovementTab:CreateToggle({
    name = "Noclip",
    flag = "Noclip",
    value = false,
    callback = function(v)
        if v then
            if not NoclipConn then
                NoclipConn = RunService.Stepped:Connect(function()
                    local char = LocalPlayer.Character
                    if char then
                        for _, part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") then part.CanCollide = false end
                        end
                    end
                end)
            end
        else
            if NoclipConn then NoclipConn:Disconnect(); NoclipConn = nil end
        end
    end,
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

local ESPState = {
    Zombie   = false,
    Player   = false,
    Survivor = false,
    AllItems = false,
    Crates   = false,
    Airdrop  = false,
}

local function GetItemColor(name)
    local l = name:lower()
    if l:find("gun") or l:find("rifle") or l:find("pistol") or l:find("ammo") or l:find("shotgun") then
        return Color3.fromRGB(255, 85, 85)
    elseif l:find("med") or l:find("bandage") or l:find("heal") or l:find("food") or l:find("drink") then
        return Color3.fromRGB(85, 255, 85)
    elseif l:find("armor") or l:find("helmet") or l:find("vest") then
        return Color3.fromRGB(85, 170, 255)
    elseif l:find("card") or l:find("key") or l:find("gold") or l:find("chip") then
        return Color3.fromRGB(220, 100, 255)
    end
    return Color3.fromRGB(255, 255, 150)
end

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

ESPTab:CreateToggle({
    name = "All Items ESP",
    flag = "ItemsESP",
    value = false,
    callback = function(v)
        ESPState.AllItems = v
        if not v then
            RemoveESP(Workspace:FindFirstChild("DroppedItems"), "ItemESP")
        else
            task.spawn(function()
                while ESPState.AllItems do
                    local dropped = Workspace:FindFirstChild("DroppedItems")
                    if dropped then
                        for _, item in ipairs(dropped:GetChildren()) do
                            CreateOrUpdateESP(item, "ItemESP", item.Name, GetItemColor(item.Name))
                        end
                    end
                    task.wait(0.2)
                end
            end)
        end
    end,
})

ESPTab:CreateToggle({
    name = "Crates ESP",
    flag = "CratesESP",
    value = false,
    callback = function(v)
        ESPState.Crates = v
        if not v then
            local crates = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Crates")
            RemoveESP(crates, "CrateESP")
        else
            task.spawn(function()
                while ESPState.Crates do
                    local crates = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Crates")
                    if crates then
                        for _, c in ipairs(crates:GetChildren()) do
                            CreateOrUpdateESP(c, "CrateESP", c.Name, Color3.fromRGB(255,215,0))
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

MiscTab:CreateDivider({ text = "interaction" })
MiscTab:CreateSection({ name = "👆 Prompts" })

local PromptConn = nil
local origHold = {}

MiscTab:CreateToggle({
    name = "Instant Proximity Prompts",
    flag = "InstantPrompts",
    value = false,
    callback = function(v)
        if v then
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    origHold[d] = origHold[d] or d.HoldDuration
                    d.HoldDuration = 0
                end
            end
            if not PromptConn then
                PromptConn = Workspace.DescendantAdded:Connect(function(d)
                    if d:IsA("ProximityPrompt") then
                        origHold[d] = d.HoldDuration
                        d.HoldDuration = 0
                    end
                end)
            end
        else
            if PromptConn then PromptConn:Disconnect(); PromptConn = nil end
            for p, h in pairs(origHold) do
                if p and p.Parent then p.HoldDuration = h end
            end
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
    text = "• NEW: KissoHub branding + neon theme\n" ..
           "• NEW: No Recoil / No Spread (Combat tab)\n" ..
           "• NEW: 2-column Home grid layout\n" ..
           "• NEW: Info tab with changelog\n" ..
           "• IMPROVED: Gen2 UI (correct key syntax)\n" ..
           "• IMPROVED: Config auto-save",
})

InfoTab:CreateDivider({ text = "tips" })
InfoTab:CreateSection({ name = "💡 Tips" })
InfoTab:CreateText({
    name = "No Recoil / No Spread",
    text = "1. Toggle No Recoil and No Spread ON\n" ..
           "2. Equip a gun\n" ..
           "3. Settings auto-apply every frame\n" ..
           "4. Use 'Apply Now' button for instant effect",
})

-- =================================================================
-- COMBAT ENGINE LOOPS
-- =================================================================

-- Auto Shoot Loop
task.spawn(function()
    while true do
        task.wait(Settings.ShootDelay)
        if Settings.AutoShootEnabled then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local tool = char:FindFirstChildOfClass("Tool") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChildOfClass("Tool"))
                if tool then
                    local shootRemote = tool:FindFirstChild("Shoot")
                    if shootRemote then
                        local myPos = getLocalRootPosition()
                        local targetPart = getClosestZombie(Settings.AutoShootRange, Settings.TargetNearest)
                        if targetPart and targetPart.Parent then
                            local targetModel = targetPart.Parent
                            local targetPos = targetPart.Position

                            local syncAmmo = tool:FindFirstChild("SyncAmmo")
                            if syncAmmo then pcall(function() syncAmmo:FireServer() end) end

                            local torso = char:FindFirstChild("Torso")
                            if torso then
                                local aimRot = torso:FindFirstChild("AimRotate")
                                if aimRot and aimRot:FindFirstChild("ReplicateAim") then
                                    pcall(function() aimRot.ReplicateAim:FireServer(Settings.AimPitch, false) end)
                                end
                            end

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

-- Kill Aura Loop
task.spawn(function()
    while task.wait(0.1) do
        if KillAuraEnabled then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                local swing = tool:FindFirstChild("Swing")
                local hit = tool:FindFirstChild("HitTargets")
                if swing or hit then
                    local targets = {}
                    local chars = Workspace:FindFirstChild("Characters") or Workspace
                    for _, e in ipairs(chars:GetChildren()) do
                        if e:IsA("Model") and isZombieEnemy(e) and canBeDamaged(e) then
                            local p = getTargetPart(e)
                            if p and (p.Position - getLocalRootPosition()).Magnitude <= KillAuraRange then
                                table.insert(targets, e)
                            end
                        end
                    end
                    if #targets > 0 then
                        if swing then pcall(function() swing:FireServer() end) end
                        if hit then pcall(function() hit:FireServer(targets) end) end
                    end
                end
            end
        end
    end
end)

-- Auto Sync Loop
task.spawn(function()
    while true do
        task.wait(2)
        if AutoTargetSyncEnabled then
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

-- Silent Aim Hook
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
-- RELOAD FUNCTIONS
-- =================================================================
function ApplyInstantReload(tool)
    if not tool or not tool:IsA("Tool") then return end
    for _, attr in ipairs({"ReloadTime","ReloadDuration","ReloadSpeed","ReloadDelay","Cooldown"}) do
        if tool:GetAttribute(attr) ~= nil then tool:SetAttribute(attr, 0) end
    end
    for _, d in ipairs(tool:GetDescendants()) do
        if d:IsA("ValueBase") then
            local n = d.Name:lower()
            if (n:find("reloadtime") or n:find("reloaddelay") or n:find("reloadspeed")) and (d:IsA("NumberValue") or d:IsA("IntValue")) then
                d.Value = 0
            elseif n:find("reloading") and d:IsA("BoolValue") then
                d.Value = false
            end
        end
    end
end

function TriggerRemoteReload(tool)
    if not tool or not tool:IsA("Tool") then return end
    local reload = tool:FindFirstChild("Reload")
    local sync = tool:FindFirstChild("SyncAmmo")
    if reload and reload:IsA("RemoteFunction") then pcall(function() reload:InvokeServer() end)
    elseif reload and reload:IsA("RemoteEvent") then pcall(function() reload:FireServer() end) end
    if sync and sync:IsA("RemoteEvent") then pcall(function() sync:FireServer() end) end
end

function ProcessAllTools()
    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                ApplyInstantReload(item)
                if RemoteFastReload then TriggerRemoteReload(item) end
                if NoRecoilEnabled or NoSpreadEnabled then ApplyNoRecoilSpread(item) end
            end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then ApplyInstantReload(item) end
        end
    end
end

-- Auto Reload Loop
task.spawn(function()
    while task.wait(0.2) do
        if AutoReloadEnabled then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                local ammoObj = tool:FindFirstChild("Ammo") or tool:FindFirstChild("Clip") or tool:FindFirstChild("Mag")
                local cur = nil
                if ammoObj and ammoObj:IsA("ValueBase") then cur = ammoObj.Value
                else cur = tool:GetAttribute("Ammo") or tool:GetAttribute("Clip") end
                if cur == nil or (type(cur) == "number" and cur <= 0) then
                    if InstantReload then ApplyInstantReload(tool) end
                    TriggerRemoteReload(tool)
                end
            end
        end
    end
end)

-- No Recoil Enforcement Loop
task.spawn(function()
    while true do
        task.wait(0.1)
        if NoRecoilEnabled or NoSpreadEnabled then
            pcall(EnforceNoRecoilOnEquipped)
        end
    end
end)

-- Auto Loot Loop
task.spawn(function()
    while task.wait(0.15) do
        if AutoLootEnabled then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local myPos = hrp.Position
                for _, p in ipairs(Workspace:GetDescendants()) do
                    if p:IsA("ProximityPrompt") and p.Enabled then
                        local parent = p.Parent
                        local pos = parent:IsA("BasePart") and parent.Position
                            or (parent:IsA("Model") and parent.PrimaryPart and parent.PrimaryPart.Position)
                        if pos and (pos - myPos).Magnitude <= AutoLootRange then
                            if fireproximityprompt then pcall(function() fireproximityprompt(p) end) end
                        end
                    end
                end
                local dropped = Workspace:FindFirstChild("DroppedItems")
                if dropped then
                    for _, item in ipairs(dropped:GetChildren()) do
                        local handle = item:IsA("BasePart") and item
                            or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildOfClass("BasePart")))
                        if handle and (handle.Position - myPos).Magnitude <= AutoLootRange then
                            if firetouchinterest then
                                pcall(function()
                                    firetouchinterest(hrp, handle, 0)
                                    task.wait()
                                    firetouchinterest(hrp, handle, 1)
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- AIMLOCK RUNTIME
-- =================================================================
local lockedTarget = nil
local isAiming = false

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Settings.Keybind or input.KeyCode == Settings.Keybind then
        isAiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Settings.Keybind or input.KeyCode == Settings.Keybind then
        isAiming = false
        lockedTarget = nil
    end
end)

RunService.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Position = UserInputService:GetMouseLocation()
    end

    if Settings.AimlockEnabled and isAiming then
        if not lockedTarget or not lockedTarget.Parent or not canBeDamaged(lockedTarget.Parent) then
            lockedTarget = getClosestZombie()
        end
        if lockedTarget then
            local targetPos = lockedTarget.Position
            if Settings.AimMethod == "Camera" then
                local cur = Camera.CFrame
                local tgt = CFrame.new(Camera.CFrame.Position, targetPos)
                Camera.CFrame = cur:Lerp(tgt, Settings.Smoothness)
            elseif Settings.AimMethod == "MouseRel" and mousemoverel then
                local screen, onScreen = Camera:WorldToViewportPoint(targetPos)
                if onScreen then
                    local mouse = UserInputService:GetMouseLocation()
                    mousemoverel((screen.X - mouse.X) * Settings.Smoothness, (screen.Y - mouse.Y) * Settings.Smoothness)
                end
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
            if Settings.AimlockEnabled then active += 1 end
            if Settings.AutoShootEnabled then active += 1 end
            if Settings.SilentAimEnabled then active += 1 end
            if KillAuraEnabled then active += 1 end
            if NoRecoilEnabled then active += 1 end
            if NoSpreadEnabled then active += 1 end
            if AutoLootEnabled then active += 1 end
            if AutoReloadEnabled then active += 1 end

            local targetCount = 0
            local chars = Workspace:FindFirstChild("Characters")
            if chars then
                for _, c in ipairs(chars:GetChildren()) do
                    if c:IsA("Model") and isZombieEnemy(c) and canBeDamaged(c) then targetCount += 1 end
                end
            end

            SessionStat:Set(mins)
            FeaturesStat:Set(active)
            FpsStat:Set(math.floor(Workspace:GetRealPhysicsFPS() or 60))
            PlayersStat:Set(#Players:GetPlayers())
            TargetsStat:Set(targetCount)

            if Settings.AutoShootEnabled then
                StateTag:Set({ text = "AUTO-SHOOT", color = Color3.fromRGB(255, 80, 80) })
            elseif KillAuraEnabled then
                StateTag:Set({ text = "KILL AURA", color = Color3.fromRGB(255, 130, 40) })
            elseif active > 0 then
                StateTag:Set({ text = "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
            else
                StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
            end
        end)
    end
end)

SafeNotify("KissoHub", "Survive the Apocalypse " .. HUB_VERSION .. " loaded", 3)
