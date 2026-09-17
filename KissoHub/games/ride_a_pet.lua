local HttpService = game:GetService("HttpService")
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

-- =================================================================
-- SERVICES & UTILITIES
-- =================================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local ASSET_ICON = "rbxassetid://89387722763691"

local SelectedEggsLookup = {}
local NestEggsLookup = {}
local FlySpeed = 400
local AutofarmEnabled = false
local EggESPEnabled = false
local AutoNestEnabled = false
local AutoHatchEnabled = false
local InfZoomEnabled = false
local FastModeEnabled = false
local AntiAFKEnabled = false

local ActiveHighlights = {}
local NoclipConnection = nil
local AntiAFKConnection = nil
local OriginalLightingSettings = {}

local SessionStartTime = os.time()
local EggsGrabbedCount = 0
local EggsPlacedCount = 0
local EggsHatchedCount = 0
local PetsSoldCount = 0

local PreviousCash = 0
local CashPerSecond = 0
local LastCashCheckTime = os.clock()

local ExtractedEggsList = {
    "Dragon Egg", "Giant Egg", "White Egg", "Brown Egg", "Cracked Egg",
    "Easter Egg", "Stone Egg", "Leaf Egg", "Mushroom Egg", "Flower Egg",
    "Slime Egg", "Ice Egg", "Glass Egg", "Golden Egg", "Diamond Egg",
    "Crystal Egg", "Skull Egg", "Asteroid Egg", "Dominus Egg", "Flaming Egg",
    "Sinister Egg", "Soul Egg", "Aurora Egg", "Galaxy Egg", "Blackhole Egg",
    "Cherub Egg"
}

OriginalLightingSettings = {
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd
}

-- =================================================================
-- HELPER FUNCTIONS
-- =================================================================
local function GetPlayerCash()
    local cash = 0
    pcall(function()
        if LocalPlayer:FindFirstChild("SavedData") and LocalPlayer.SavedData:FindFirstChild("Cash") then
            cash = LocalPlayer.SavedData.Cash.Value
        elseif LocalPlayer:FindFirstChild("leaderstats") then
            local cashVal = LocalPlayer.leaderstats:FindFirstChild("Cash") or LocalPlayer.leaderstats:FindFirstChild("Coins") or LocalPlayer.leaderstats:FindFirstChild("Money")
            if cashVal then cash = cashVal.Value end
        end
    end)
    return cash
end

local function GetPlayerIncome()
    local income = nil
    pcall(function()
        if LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Income/s") then
            income = LocalPlayer.leaderstats["Income/s"].Value
        end
    end)
    return income
end

local function GetPing()
    local ping = 0
    pcall(function()
        if LocalPlayer and LocalPlayer:FindFirstChild("GetNetworkPing") then
            ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        elseif StatsService:FindFirstChild("Network") and StatsService.Network:FindFirstChild("ServerStatsItem") then
            local pingItem = StatsService.Network.ServerStatsItem:FindFirstChild("Data Ping")
            if pingItem then ping = math.floor(pingItem:GetValue()) end
        end
    end)
    return ping
end

local function GetPlayerPlot()
    if not Workspace:FindFirstChild("Plots") then return nil end
    for _, plot in ipairs(Workspace.Plots:GetChildren()) do
        local data = plot:FindFirstChild("Data")
        if data and data:FindFirstChild("Owner") then
            local ownerVal = data.Owner.Value
            if ownerVal == LocalPlayer or ownerVal == LocalPlayer.Name then
                return plot
            end
        end
    end
    return nil
end

local function GetPlayerPlotCenter()
    local plot = GetPlayerPlot()
    if not plot then return nil end
    
    local centerCFrame
    if plot:IsA("Model") then
        centerCFrame = plot:GetPivot()
    elseif plot:IsA("BasePart") then
        centerCFrame = plot.CFrame
    else
        local base = plot:FindFirstChild("Base") or plot:FindFirstChild("Baseplate") or plot:FindFirstChildWhichIsA("BasePart")
        centerCFrame = base and base.CFrame or CFrame.new()
    end
    return centerCFrame.Position + Vector3.new(0, 4, 0)
end

-- =================================================================
-- WINDOW & CUSTOM NEON CYAN / MAGENTA THEME (PURE WHITE TEXT)
-- =================================================================
local Window = Rayfield:CreateWindow({
    Name = "KissoHub",
    Title = "KissoHub",
    LoadingTitle = "KissoHub Loading...",
    LoadingSubtitle = "Brought to you by Kisso",
    sidebarLayout = true,
    
    ShowText = "KissoHub",
    Icon = ASSET_ICON,

    Theme = {
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
        DropdownHighlight = Color3.fromRGB(190, 40, 220)
    },

    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "KissoHubFolder",
        FileName = "UserPreferences"
    }
})

local StatusTag = Window:CreateTag({
    text = "v1.0.0",
    color = Color3.fromRGB(0, 200, 255)
})

local StateTag = Window:CreateTag({
    text = "IDLE",
    color = Color3.fromRGB(190, 40, 220)
})

local function SafeNotify(title, content, duration)
    pcall(function()
        Window:Notify({
            title = title or "KissoHub",
            content = content or "",
            duration = duration or 4,
            icon = ASSET_ICON
        })
    end)
end

local function QuickToast(title, subtitle)
    pcall(function()
        Window:Toast({
            title = title,
            subtitle = subtitle,
            position = "Top",
            icon = ASSET_ICON
        })
    end)
end

local function TeleportToMyPlot()
    local plotCenter = GetPlayerPlotCenter()
    if plotCenter then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(plotCenter)
            QuickToast("Teleported", "Moved to your plot")
        end
    else
        SafeNotify("Teleport Error", "Could not find your plot!", 3)
    end
end

local function TeleportToStall(stallName)
    local stallsFolder = Workspace:FindFirstChild("Stalls")
    if not stallsFolder then
        SafeNotify("Teleport Error", "Workspace.Stalls folder not found!", 3)
        return
    end

    local stall = stallsFolder:FindFirstChild(stallName)
    if not stall then
        SafeNotify("Teleport Error", "Stall '" .. stallName .. "' not found!", 3)
        return
    end

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local targetCF
    if stall:IsA("Model") then
        targetCF = stall:GetPivot()
    elseif stall:IsA("BasePart") then
        targetCF = stall.CFrame
    else
        local part = stall:FindFirstChildWhichIsA("BasePart", true)
        if part then targetCF = part.CFrame end
    end

    if targetCF then
        char.HumanoidRootPart.CFrame = targetCF * CFrame.new(0, 2, -6) * CFrame.Angles(0, math.pi, 0)
        QuickToast("Teleported", "Moved to " .. stallName)
    end
end

local function SetNoclip(enabled)
    if enabled then
        if not NoclipConnection then
            NoclipConnection = RunService.Stepped:Connect(function()
                local char = LocalPlayer.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end
    else
        if NoclipConnection then
            NoclipConnection:Disconnect()
            NoclipConnection = nil
        end
    end
end

local function IsNestFree(nest)
    if not nest then return false end
    if nest:GetAttribute("Occupied") == true or nest:GetAttribute("HasEgg") == true then
        return false
    end
    for _, child in ipairs(nest:GetChildren()) do
        if child:GetAttribute("EggKey") or child.Name:lower():find("egg") then
            return false
        end
    end
    return true
end

local function CheckAndEquipNestEgg()
    if next(NestEggsLookup) == nil then return true end

    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and NestEggsLookup[item.Name] then
                return true
            end
        end
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and NestEggsLookup[item.Name] then
                if char and char:FindFirstChildOfClass("Humanoid") then
                    char.Humanoid:EquipTool(item)
                end
                return true
            end
        end
    end

    return true
end

local function FlyToTarget(target)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
    local hrp = char.HumanoidRootPart

    while AutofarmEnabled and char and hrp do
        if typeof(target) == "Instance" then
            if not (target.Parent and target:IsDescendantOf(Workspace)) then
                return false
            end
        end

        local targetPos = typeof(target) == "Vector3" and target or (target:IsA("Model") and target:GetPivot().Position or target.Position)
        local currentPos = hrp.Position
        local distance = (targetPos - currentPos).Magnitude
        
        if distance <= 4 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            return true
        end

        local direction = (targetPos - currentPos).Unit
        local dt = RunService.Heartbeat:Wait()
        
        hrp.AssemblyLinearVelocity = Vector3.zero
        local moveStep = direction * (FlySpeed * dt)
        
        if moveStep.Magnitude > distance then
            hrp.CFrame = CFrame.new(targetPos, targetPos + direction)
            hrp.AssemblyLinearVelocity = Vector3.zero
            return true
        else
            hrp.CFrame = CFrame.new(currentPos + moveStep, currentPos + moveStep + direction)
        end
    end
    return false
end

local function InteractWithEgg(egg)
    if not (egg and egg.Parent and egg:IsDescendantOf(Workspace)) then return end
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(0.05)
            prompt:InputHoldEnd()
        end
        EggsGrabbedCount = EggsGrabbedCount + 1
    end
end

-- =================================================================
-- TABS & CONTROLS
-- =================================================================
local HomeTab = Window:CreateTab({ Name = "🏠 Home", Icon = ASSET_ICON })
local FarmTab = Window:CreateTab({ Name = "⚡ Egg Automation" })
local EggTab = Window:CreateTab({ Name = "🥚 Egg Management" })
local MiscTab = Window:CreateTab({ Name = "🛠️ Misc" })

-- Home Tab
HomeTab:CreateSection({ Name = "📊 Stats" })
local CashStat = HomeTab:CreateStat({ name = "💵 Cash", prefix = "$", value = 0, compact = true })
local CpsStat = HomeTab:CreateStat({ name = "📈 $/s", prefix = "$", value = 0, compact = true })
local GrabbedStat = HomeTab:CreateStat({ name = "🥚 Eggs Grabbed", value = 0, compact = true })
local HatchedStat = HomeTab:CreateStat({ name = "🐣 Eggs Hatched", value = 0, compact = true })
local SoldStat = HomeTab:CreateStat({ name = "🐶 Pets Sold", value = 0, compact = true })

HomeTab:CreateDivider({ spacing = 14 })
HomeTab:CreateSection({ Name = "⚡ System Status" })
local SessionStat = HomeTab:CreateStat({ name = "⏱️ Session", value = 0, suffix = " m", compact = true })
local FeaturesStat = HomeTab:CreateStat({ name = "⚙️ Features Active", value = 0, compact = true })
local FpsStat = HomeTab:CreateStat({ name = "🎮 FPS", value = 0, compact = true })
local PingStat = HomeTab:CreateStat({ name = "📡 Ping", value = 0, suffix = " ms", compact = true })
local PlayersStat = HomeTab:CreateStat({ name = "👥 Players", value = 1, compact = true })

HomeTab:CreateDivider({ text = "controls" })
HomeTab:CreateSection({ Name = "🌐 Server Utilities" })
HomeTab:CreateButton({
    Name = "📋 Copy Job ID",
    Callback = function()
        if setclipboard then
            setclipboard(game.JobId)
            QuickToast("Copied", "Job ID copied to clipboard")
        end
    end,
})

HomeTab:CreateButton({
    Name = "🔄 Rejoin Server",
    Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end,
})

-- Farm Tab
FarmTab:CreateSection({ Name = "👁️ Visuals & Movement" })
FarmTab:CreateToggle({
    Name = "Egg ESP",
    Flag = "EggESP",
    CurrentValue = false,
    Callback = function(Value)
        EggESPEnabled = Value
        if not Value then
            for egg, hl in pairs(ActiveHighlights) do
                if hl then hl:Destroy() end
            end
            table.clear(ActiveHighlights)
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Autofarm Fly Speed",
    Flag = "FlySpeed",
    Range = {100, 3000},
    Increment = 50,
    Suffix = " studs/sec",
    CurrentValue = 400,
    Callback = function(Value)
        FlySpeed = Value
    end,
})

FarmTab:CreateDivider({ text = "execution" })
FarmTab:CreateSection({ Name = "🌾 Farm Controls" })

FarmTab:CreateToggle({
    Name = "Autofarm Egg",
    Flag = "AutofarmEgg",
    CurrentValue = false,
    Callback = function(Value)
        AutofarmEnabled = Value
        SetNoclip(Value)
        
        if Value then
            StateTag:Set({ text = "FARMING", color = Color3.fromRGB(0, 220, 130) })
            QuickToast("Autofarm Active", "Harvesting target eggs")
            task.spawn(function()
                while AutofarmEnabled do
                    local renderedFolder = Workspace:FindFirstChild("RenderedEggs")
                    local plotCenter = GetPlayerPlotCenter()

                    if renderedFolder and plotCenter then
                        local targetEgg = nil
                        
                        if next(SelectedEggsLookup) ~= nil then
                            for _, egg in ipairs(renderedFolder:GetChildren()) do
                                if SelectedEggsLookup[egg.Name] then
                                    targetEgg = egg
                                    break
                                end
                            end
                        end

                        if targetEgg and targetEgg.Parent then
                            local reached = FlyToTarget(targetEgg)

                            if reached and targetEgg.Parent and targetEgg:IsDescendantOf(Workspace) then
                                InteractWithEgg(targetEgg)
                                task.wait(1.30)
                            end
                            
                            if AutofarmEnabled then
                                FlyToTarget(plotCenter)
                                task.wait(0.2)
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end,
})

FarmTab:CreateDropdown({
    Name = "Select Target Eggs",
    Flag = "SelectedEggs",
    Options = ExtractedEggsList,
    CurrentOption = {},
    MultipleOptions = true,
    Callback = function(Options)
        table.clear(SelectedEggsLookup)
        if type(Options) == "table" then
            for k, v in pairs(Options) do
                if type(k) == "number" then
                    SelectedEggsLookup[v] = true
                elseif type(k) == "string" and (v == true or v == k) then
                    SelectedEggsLookup[k] = true
                end
            end
        end
    end,
})

-- Egg Tab
EggTab:CreateSection({ Name = "🪹 Nest Configuration" })
EggTab:CreateDropdown({
    Name = "Select Eggs for Nest",
    Flag = "NestEggs",
    Options = ExtractedEggsList,
    CurrentOption = {},
    MultipleOptions = true,
    Callback = function(Options)
        table.clear(NestEggsLookup)
        if type(Options) == "table" then
            for k, v in pairs(Options) do
                if type(k) == "number" then
                    NestEggsLookup[v] = true
                elseif type(k) == "string" and (v == true or v == k) then
                    NestEggsLookup[k] = true
                end
            end
        end
    end,
})

EggTab:CreateDivider({ line = false, spacing = 16 })
EggTab:CreateSection({ Name = "🔄 Automation Loops" })

EggTab:CreateToggle({
    Name = "Auto Put Egg to Nest",
    Flag = "AutoPutEgg",
    CurrentValue = false,
    Callback = function(Value)
        AutoNestEnabled = Value
        if Value then
            task.spawn(function()
                while AutoNestEnabled do
                    local plot = GetPlayerPlot()
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    local gameRemotes = remotes and remotes:FindFirstChild("Game")
                    local eggPlaced = gameRemotes and gameRemotes:FindFirstChild("EggPlaced")

                    if plot and eggPlaced and CheckAndEquipNestEgg() then
                        local nestsFolder = plot:FindFirstChild("Nests")
                        if nestsFolder then
                            for nestId = 1, 5 do
                                if not AutoNestEnabled then break end
                                local nest = nestsFolder:FindFirstChild(tostring(nestId))
                                if nest and IsNestFree(nest) then
                                    eggPlaced:FireServer({ NestId = tostring(nestId) })
                                    EggsPlacedCount = EggsPlacedCount + 1
                                    task.wait(0.1)
                                end
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end,
})

EggTab:CreateToggle({
    Name = "Auto Hatch Egg",
    Flag = "AutoHatchEgg",
    CurrentValue = false,
    Callback = function(Value)
        AutoHatchEnabled = Value
        if Value then
            task.spawn(function()
                while AutoHatchEnabled do
                    local plot = GetPlayerPlot()
                    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                    local gameRemotes = remotes and remotes:FindFirstChild("Game")
                    local hatchRemote = gameRemotes and gameRemotes:FindFirstChild("Hatch")

                    if plot and hatchRemote then
                        local eggsFolder = plot:FindFirstChild("Eggs")
                        if eggsFolder then
                            for _, egg in ipairs(eggsFolder:GetChildren()) do
                                if not AutoHatchEnabled then break end
                                local eggKey = egg:GetAttribute("EggKey")
                                if eggKey then
                                    hatchRemote:FireServer({ EggKey = tostring(eggKey) })
                                    EggsHatchedCount = EggsHatchedCount + 1
                                    task.wait(0.1)
                                end
                            end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end,
})

-- Misc Tab
MiscTab:CreateSection({ Name = "💾 Settings Management" })
MiscTab:CreateButton({
    Name = "💾 Save Config (Manual)",
    Callback = function()
        Window:Save()
        QuickToast("Config Saved", "Preferences saved successfully")
    end,
})

MiscTab:CreateButton({
    Name = "📂 Reload Config File",
    Callback = function()
        Window:Load()
        QuickToast("Config Reloaded", "Loaded user preferences")
    end,
})

MiscTab:CreateDivider({ text = "teleports" })
MiscTab:CreateSection({ Name = "📍 Fast Teleports" })
MiscTab:CreateButton({ Name = "🥚 TP Egg Tracker Stall", Callback = function() TeleportToStall("EggTracker") end })
MiscTab:CreateButton({ Name = "🥩 TP Food Stall", Callback = function() TeleportToStall("Food") end })
MiscTab:CreateButton({ Name = "🏡 TP My Plot", Callback = function() TeleportToMyPlot() end })
MiscTab:CreateButton({ Name = "⚙️ TP Gears Stall", Callback = function() TeleportToStall("Gears") end })
MiscTab:CreateButton({ Name = "💰 TP Sell Stall", Callback = function() TeleportToStall("Sell") end })

MiscTab:CreateDivider({ text = "preferences" })
MiscTab:CreateSection({ Name = "⚙️ Player Options" })

MiscTab:CreateToggle({
    Name = "Infinite Zoom",
    Flag = "InfZoom",
    CurrentValue = false,
    Callback = function(Value)
        InfZoomEnabled = Value
        LocalPlayer.CameraMaxZoomDistance = Value and 100000 or 128
    end,
})

MiscTab:CreateToggle({
    Name = "Anti-AFK",
    Flag = "AntiAFK",
    CurrentValue = false,
    Callback = function(Value)
        AntiAFKEnabled = Value
        if Value then
            if not AntiAFKConnection then
                AntiAFKConnection = LocalPlayer.Idled:Connect(function()
                    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                    task.wait(1)
                    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                end)
            end
        else
            if AntiAFKConnection then
                AntiAFKConnection:Disconnect()
                AntiAFKConnection = nil
            end
        end
    end,
})

MiscTab:CreateDivider({ line = false, spacing = 12 })
MiscTab:CreateSection({ Name = "🚀 Optimization" })

MiscTab:CreateToggle({
    Name = "Fast Mode (FPS Booster)",
    Flag = "FastMode",
    CurrentValue = false,
    Callback = function(Value)
        FastModeEnabled = Value
        if Value then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9

            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 0
            end

            for _, v in ipairs(game:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.Material = Enum.Material.SmoothPlastic
                elseif v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("PostEffect") then
                    v.Enabled = false
                end
            end
            QuickToast("FPS Boost", "Graphics optimized")
        else
            Lighting.GlobalShadows = OriginalLightingSettings.GlobalShadows
            Lighting.FogEnd = OriginalLightingSettings.FogEnd
            QuickToast("Graphics Restored", "Standard settings restored")
        end
    end,
})

-- =================================================================
-- CUSTOM TOP HUD UI CREATION (MATCHED THEME COLORING)
-- =================================================================
local function BuildTopBarHUD()
    local parentGui = LocalPlayer:WaitForChild("PlayerGui")
    
    if parentGui:FindFirstChild("StallTeleportBar") then
        parentGui.StallTeleportBar:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "StallTeleportBar"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = -10
    ScreenGui.Parent = parentGui

    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Size = UDim2.new(0, 620, 0, 42)
    Container.Position = UDim2.new(0.5, 0, 0, 12)
    Container.AnchorPoint = Vector2.new(0.5, 0)
    Container.BackgroundTransparency = 1
    Container.Parent = ScreenGui

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.FillDirection = Enum.FillDirection.Horizontal
    UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 8)
    UIListLayout.Parent = Container

    local buttonsData = {
        { Text = "Egg Tracker 🥚", Target = "EggTracker", Color = Color3.fromRGB(20, 18, 30), Border = Color3.fromRGB(0, 200, 255) },
        { Text = "Food 🥩", Target = "Food", Color = Color3.fromRGB(20, 18, 30), Border = Color3.fromRGB(190, 40, 220) },
        { Text = "My Plot 🏡", Target = "MyPlot", Color = Color3.fromRGB(20, 18, 30), Border = Color3.fromRGB(0, 200, 255) },
        { Text = "Gears ⚙️", Target = "Gears", Color = Color3.fromRGB(20, 18, 30), Border = Color3.fromRGB(190, 40, 220) },
        { Text = "Sell 💰", Target = "Sell", Color = Color3.fromRGB(20, 18, 30), Border = Color3.fromRGB(0, 200, 255) }
    }

    for idx, data in ipairs(buttonsData) do
        local btn = Instance.new("TextButton")
        btn.Name = data.Target .. "Button"
        btn.Size = UDim2.new(0, 115, 1, 0)
        btn.BackgroundColor3 = data.Color
        btn.Text = data.Text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.FredokaOne
        btn.TextSize = 14
        btn.TextStrokeTransparency = 0.5
        btn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        btn.LayoutOrder = idx
        btn.Parent = Container

        local uiCorner = Instance.new("UICorner")
        uiCorner.CornerRadius = UDim.new(0, 8)
        uiCorner.Parent = btn

        local uiStroke = Instance.new("UIStroke")
        uiStroke.Color = data.Border
        uiStroke.Thickness = 2
        uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        uiStroke.Parent = btn

        btn.MouseEnter:Connect(function()
            btn.Size = UDim2.new(0, 117, 1, 2)
        end)
        btn.MouseLeave:Connect(function()
            btn.Size = UDim2.new(0, 115, 1, 0)
        end)
        btn.MouseButton1Click:Connect(function()
            if data.Target == "MyPlot" then
                TeleportToMyPlot()
            else
                TeleportToStall(data.Target)
            end
        end)
    end
end

BuildTopBarHUD()

MiscTab:CreateToggle({
    Name = "Show Top Teleport Bar",
    Flag = "ShowTopBar",
    CurrentValue = true,
    Callback = function(Value)
        local parentGui = LocalPlayer:FindFirstChild("PlayerGui")
        local bar = parentGui and parentGui:FindFirstChild("StallTeleportBar")
        if bar then
            bar.Enabled = Value
        end
    end,
})

-- =================================================================
-- LIVE REFRESH & ESP LOOPS
-- =================================================================
task.spawn(function()
    PreviousCash = GetPlayerCash()
    LastCashCheckTime = os.clock()

    while task.wait(0.5) do
        pcall(function()
            local elapsedMinutes = math.floor((os.time() - SessionStartTime) / 60)
            local activeFeatures = (AutofarmEnabled and 1 or 0) 
                + (EggESPEnabled and 1 or 0) 
                + (AutoNestEnabled and 1 or 0) 
                + (AutoHatchEnabled and 1 or 0) 
                + (InfZoomEnabled and 1 or 0) 
                + (FastModeEnabled and 1 or 0) 
                + (AntiAFKEnabled and 1 or 0)

            local currentCash = GetPlayerCash()
            local directIncome = GetPlayerIncome()

            if directIncome then
                CashPerSecond = directIncome
            else
                local now = os.clock()
                local timeDiff = now - LastCashCheckTime
                if timeDiff >= 1 then
                    CashPerSecond = math.max(0, math.floor((currentCash - PreviousCash) / timeDiff))
                    PreviousCash = currentCash
                    LastCashCheckTime = now
                end
            end

            CashStat:Set(currentCash)
            CpsStat:Set(CashPerSecond)
            GrabbedStat:Set(EggsGrabbedCount)
            HatchedStat:Set(EggsHatchedCount)
            SoldStat:Set(PetsSoldCount)

            SessionStat:Set(elapsedMinutes)
            FeaturesStat:Set(activeFeatures)
            FpsStat:Set(math.floor(Workspace:GetRealPhysicsFPS() or 60))
            PingStat:Set(GetPing())
            PlayersStat:Set(#Players:GetPlayers())
        end)
    end
end)

-- ESP Highlight Loop
task.spawn(function()
    while task.wait(1) do
        if EggESPEnabled then
            pcall(function()
                local renderedFolder = Workspace:FindFirstChild("RenderedEggs")
                if renderedFolder then
                    for _, egg in ipairs(renderedFolder:GetChildren()) do
                        if not ActiveHighlights[egg] then
                            local hl = Instance.new("Highlight")
                            hl.Adornee = egg
                            hl.FillColor = Color3.fromRGB(0, 200, 255)
                            hl.OutlineColor = Color3.fromRGB(190, 40, 220)
                            hl.Parent = egg
                            ActiveHighlights[egg] = hl
                        end
                    end
                end
            end)
        end
    end
end)

-- Deferred Config Load
task.defer(function()
    pcall(function()
        Window:Load()
    end)
end)
