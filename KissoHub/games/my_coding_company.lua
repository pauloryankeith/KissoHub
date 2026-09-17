-- =================================================================
-- KissoHub — Software Simulator Edition
-- =================================================================
local HttpService = game:GetService("HttpService")
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

-- =================================================================
-- SERVICES & UTILITIES
-- =================================================================
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local StatsService      = game:GetService("Stats")
local TeleportService   = game:GetService("TeleportService")
local Lighting          = game:GetService("Lighting")
local VirtualUser       = game:GetService("VirtualUser")
local LocalPlayer       = Players.LocalPlayer

local ASSET_ICON = "rbxassetid://89387722763691"

-- =================================================================
-- STATE
-- =================================================================
local SessionStartTime = os.time()

local Toggles = {
    CollectPrograms = false,
    PC              = false,
    Coding          = false,
    AutoSell        = false,
    Mining          = false,
    Fishing         = false,
    Meteors         = false,
    AntiAFK         = false,
    InfZoom         = false,
    FastMode        = false,
}

local OriginalLightingSettings = {
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd        = Lighting.FogEnd,
}

-- =================================================================
-- REMOTE RESOLUTION
-- =================================================================
local function getRemote(path)
    local current = ReplicatedStorage
    for _, name in ipairs(path) do
        current = current:WaitForChild(name, 5)
        if not current then return nil end
    end
    return current
end

local store    = getRemote({"Remotes", "Server", "Software", "Store"})
local sell     = getRemote({"Remotes", "Server", "Software", "Sell"})
local complete = getRemote({"Remotes", "Server", "CompletePlayerCodingProgram"})
local bubble   = getRemote({"Remotes", "Server", "PopProgrammingBubble"})
local ore      = getRemote({"Remotes", "Server", "Mining", "UpdateOreHealth"})
local fish     = getRemote({"Remotes", "Server", "Fishing", "ResolveFishingAttempt"})

-- =================================================================
-- GAME HELPERS (unchanged logic)
-- =================================================================
local function getPlayerOffice()
    local userIdStr = tostring(LocalPlayer.UserId)

    if Workspace:FindFirstChild("Interiors") and Workspace.Interiors:FindFirstChild("Offices") then
        local off = Workspace.Interiors.Offices:FindFirstChild(userIdStr)
        if off then return off end
    end

    if Workspace:FindFirstChild("Map")
       and Workspace.Map:FindFirstChild("Gameplay")
       and Workspace.Map.Gameplay:FindFirstChild("Offices") then
        local off = Workspace.Map.Gameplay.Offices:FindFirstChild(userIdStr)
        if off then return off end
    end

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == userIdStr and (obj.Parent.Name == "Offices" or obj:FindFirstChild("Items")) then
            return obj
        end
    end

    return nil
end

local function getSoftwareData()
    local payload = { ["Programs"] = {}, ["Apps"] = {} }

    local function parseStorageTable(t)
        if type(t) ~= "table" then return false end
        local found = false

        local progTable = rawget(t, "Programs") or rawget(t, "Software")
            or (t.Data and t.Data.ServerStorage and t.Data.ServerStorage.Programs)
        local appTable = rawget(t, "Apps") or rawget(t, "Applications")
            or (t.Data and t.Data.ServerStorage and t.Data.ServerStorage.Apps)

        if type(progTable) == "table" then
            for id, count in pairs(progTable) do
                local n = tonumber(count)
                if n and n > 0 then
                    payload["Programs"][tostring(id)] = n
                    found = true
                end
            end
        end

        if type(appTable) == "table" then
            for id, count in pairs(appTable) do
                local n = tonumber(count)
                if n and n > 0 then
                    payload["Apps"][tostring(id)] = n
                    found = true
                end
            end
        end

        return found
    end

    pcall(function()
        local officeScript = LocalPlayer:FindFirstChild("PlayerScripts")
            and LocalPlayer.PlayerScripts:FindFirstChild("Office")
            and LocalPlayer.PlayerScripts.Office:FindFirstChild("OfficeManage")

        if officeScript and typeof(getsenv) == "function" then
            local env = getsenv(officeScript)
            for _, v in pairs(env) do
                if parseStorageTable(v) then return end
            end

            if typeof(getupvalues) == "function" then
                for _, v in pairs(env) do
                    if type(v) == "function" then
                        for _, uv in pairs(getupvalues(v)) do
                            if parseStorageTable(uv) then return end
                        end
                    end
                end
            end
        end
    end)

    if next(payload["Programs"]) == nil and next(payload["Apps"]) == nil then
        pcall(function()
            if typeof(getgc) == "function" then
                for _, obj in ipairs(getgc(true)) do
                    if type(obj) == "table" then
                        if parseStorageTable(obj) then break end
                    end
                end
            end
        end)
    end

    return payload
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
        DropdownHighlight = Color3.fromRGB(190, 40, 220),
    },

    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "KissoHubFolder",
        FileName = "SoftwareSimPrefs",
    },
})

local StatusTag = Window:CreateTag({ text = "v1.0.0", color = Color3.fromRGB(0, 200, 255) })
local StateTag  = Window:CreateTag({ text = "IDLE",   color = Color3.fromRGB(190, 40, 220) })

-- =================================================================
-- NOTIFICATIONS
-- =================================================================
local function SafeNotify(title, content, duration)
    pcall(function()
        Window:Notify({
            title    = title or "KissoHub",
            content  = content or "",
            duration = duration or 4,
            icon     = ASSET_ICON,
        })
    end)
end

local function QuickToast(title, subtitle)
    pcall(function()
        Window:Toast({
            title    = title,
            subtitle = subtitle,
            position = "Top",
            icon     = ASSET_ICON,
        })
    end)
end

local function SetActivity(active, label)
    if active then
        StateTag:Set({ text = label or "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
    else
        StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
    end
end

-- =================================================================
-- TABS
-- =================================================================
local HomeTab = Window:CreateTab({ Name = "🏠 Home", Icon = ASSET_ICON })
local FarmTab = Window:CreateTab({ Name = "⚡ Farming Modules" })
local MiscTab = Window:CreateTab({ Name = "🛠️ Misc" })

-- =================================================================
-- HOME TAB
-- =================================================================
HomeTab:CreateSection({ Name = "📊 Stats" })
local SessionStat  = HomeTab:CreateStat({ name = "⏱️ Session", value = 0, suffix = " m", compact = true })
local FeaturesStat = HomeTab:CreateStat({ name = "⚙️ Features Active", value = 0, compact = true })
local FpsStat      = HomeTab:CreateStat({ name = "🎮 FPS", value = 0, compact = true })
local PlayersStat  = HomeTab:CreateStat({ name = "👥 Players", value = 1, compact = true })

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

-- =================================================================
-- FARM TAB — ported game logic
-- =================================================================
FarmTab:CreateSection({ Name = "💻 Office Automation" })

-- 1. COLLECT PROGRAMS
FarmTab:CreateToggle({
    Name = "Auto Collect Programs from PCs",
    Flag = "Toggle_CollectPrograms",
    CurrentValue = false,
    Callback = function(Value)
        Toggles.CollectPrograms = Value
        if Value then
            SetActivity(true, "FARMING")
            QuickToast("Collect Programs", "Started")
            task.spawn(function()
                while Toggles.CollectPrograms do
                    pcall(function()
                        local office = getPlayerOffice()
                        if office then
                            local container = (office:FindFirstChild("Items") and office.Items:FindFirstChild("Hardware")) or office

                            for _, v in ipairs(container:GetDescendants()) do
                                if not Toggles.CollectPrograms then break end

                                if v:IsA("Model") and (v.Name == "Pc" or v:GetAttribute("Id") ~= nil) then
                                    local pcId = v:GetAttribute("Id")

                                    if pcId and store then
                                        pcall(function() store:InvokeServer(pcId) end)
                                    end

                                    local prompt = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                                    if prompt then
                                        prompt.HoldDuration = 0
                                        if typeof(fireproximityprompt) == "function" then
                                            pcall(function() fireproximityprompt(prompt) end)
                                        end
                                    end

                                    task.wait(0.05)
                                end
                            end
                        end
                    end)
                    task.wait(0.5)
                end
            end)
        end
    end,
})

-- 2. AUTO SELL
FarmTab:CreateToggle({
    Name = "Auto Sell Programs & Apps",
    Flag = "Toggle_AutoSell",
    CurrentValue = false,
    Callback = function(Value)
        Toggles.AutoSell = Value
        if Value then
            QuickToast("Auto Sell", "Started")
            task.spawn(function()
                while Toggles.AutoSell do
                    pcall(function()
                        if sell then
                            local softwarePayload = getSoftwareData()

                            if next(softwarePayload["Programs"]) ~= nil or next(softwarePayload["Apps"]) ~= nil then
                                sell:FireServer(softwarePayload)
                            end
                        end
                    end)
                    task.wait(1)
                end
            end)
        end
    end,
})

-- 3. PC UPGRADE
FarmTab:CreateToggle({
    Name = "Auto Upgrade PC Hardware",
    Flag = "Toggle_PC",
    CurrentValue = false,
    Callback = function(Value)
        Toggles.PC = Value
        if Value then
            QuickToast("PC Upgrade", "Started")
            task.spawn(function()
                while Toggles.PC do
                    pcall(function()
                        local office = getPlayerOffice()
                        if office and office:FindFirstChild("Items") and office.Items:FindFirstChild("Hardware") then
                            for _, v in ipairs(office.Items.Hardware:GetDescendants()) do
                                if not Toggles.PC then break end
                                if v.Name == "Pc" and v:IsA("Model") then
                                    local id = v:GetAttribute("Id")
                                    if id and store then
                                        pcall(function() store:InvokeServer(id) end)
                                        task.wait(0.1)
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.5)
                end
            end)
        end
    end,
})

-- 4. CODING & BUBBLES
FarmTab:CreateToggle({
    Name = "Auto Complete Coding & Pop Bubbles",
    Flag = "Toggle_Coding",
    CurrentValue = false,
    Callback = function(Value)
        Toggles.Coding = Value
        if Value then
            QuickToast("Coding", "Started")
            task.spawn(function()
                while Toggles.Coding do
                    if complete then pcall(function() complete:InvokeServer() end) end
                    if bubble then pcall(function() bubble:FireServer("3") end) end
                    task.wait(0.2)
                end
            end)
        end
    end,
})

FarmTab:CreateDivider({ text = "gathering" })
FarmTab:CreateSection({ Name = "⛏️ Resource Farming" })

-- 5. MINING
FarmTab:CreateToggle({
    Name = "Auto Mine Ores",
    Flag = "Toggle_Mining",
    CurrentValue = false,
    Callback = function(Value)
        Toggles.Mining = Value
        if Value then
            QuickToast("Mining", "Started")
            task.spawn(function()
                while Toggles.Mining do
                    pcall(function()
                        local mines = Workspace:FindFirstChild("Interiors") and Workspace.Interiors:FindFirstChild("Mines")
                        if mines then
                            for m = 1, 3 do
                                if not Toggles.Mining then break end
                                local mine = mines:FindFirstChild("Mine" .. m)
                                if mine and mine:FindFirstChild("OreSpawns") then
                                    for a = 1, 3 do
                                        if not Toggles.Mining then break end
                                        local area = mine.OreSpawns:FindFirstChild("Area" .. a)
                                        if area and ore then
                                            for s = 1, #area:GetChildren() do
                                                if not Toggles.Mining then break end
                                                pcall(function() ore:InvokeServer(m, a, s) end)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.3)
                end
            end)
        end
    end,
})

-- 6. FISHING
FarmTab:CreateToggle({
    Name = "Auto Fishing",
    Flag = "Toggle_Fishing",
    CurrentValue = false,
    Callback = function(Value)
        Toggles.Fishing = Value
        if Value then
            QuickToast("Fishing", "Started")
            task.spawn(function()
                while Toggles.Fishing do
                    pcall(function()
                        local fishing = Workspace:FindFirstChild("Map")
                            and Workspace.Map:FindFirstChild("World1")
                            and Workspace.Map.World1:FindFirstChild("FishingSpots")

                        if fishing and fish then
                            for i = 1, #fishing:GetChildren() do
                                if not Toggles.Fishing then break end
                                pcall(function() fish:InvokeServer(i, true) end)
                            end
                        end
                    end)
                    task.wait(0.3)
                end
            end)
        end
    end,
})

-- 7. METEORS
FarmTab:CreateToggle({
    Name = "Bring & Collect Meteors",
    Flag = "Toggle_Meteors",
    CurrentValue = false,
    Callback = function(Value)
        Toggles.Meteors = Value
        if Value then
            QuickToast("Meteors", "Started")
            task.spawn(function()
                while Toggles.Meteors do
                    pcall(function()
                        local char = LocalPlayer.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        local meteors = Workspace:FindFirstChild("RunTime") and Workspace.RunTime:FindFirstChild("Meteors")

                        if root and meteors then
                            local cf = root.CFrame * CFrame.new(0, 0, -6)

                            for _, mtr in ipairs(meteors:GetChildren()) do
                                if not Toggles.Meteors then break end

                                for _, v in ipairs(mtr:GetDescendants()) do
                                    if v:IsA("BasePart") then
                                        v.Anchored = true
                                        v.AssemblyLinearVelocity = Vector3.zero
                                        v.AssemblyAngularVelocity = Vector3.zero
                                    end
                                end

                                if mtr:IsA("Model") then
                                    mtr:PivotTo(cf)
                                else
                                    local bp = mtr:FindFirstChildWhichIsA("BasePart", true)
                                    if bp then bp.CFrame = cf end
                                end

                                local prompt = mtr:FindFirstChildWhichIsA("ProximityPrompt", true)
                                if prompt then
                                    prompt.HoldDuration = 0
                                    if typeof(fireproximityprompt) == "function" then
                                        fireproximityprompt(prompt)
                                    end
                                end
                            end
                        end
                    end)
                    RunService.Heartbeat:Wait()
                end
            end)
        end
    end,
})

-- =================================================================
-- MISC TAB
-- =================================================================
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

MiscTab:CreateDivider({ text = "preferences" })
MiscTab:CreateSection({ Name = "⚙️ Player Options" })

MiscTab:CreateToggle({
    Name = "Infinite Zoom",
    Flag = "Toggle_InfZoom",
    CurrentValue = false,
    Callback = function(Value)
        Toggles.InfZoom = Value
        LocalPlayer.CameraMaxZoomDistance = Value and 100000 or 128
    end,
})

MiscTab:CreateToggle({
    Name = "Anti-AFK",
    Flag = "Toggle_AntiAFK",
    CurrentValue = false,
    Callback = function(Value)
        Toggles.AntiAFK = Value
        if Value then
            if not LocalPlayer:GetAttribute("KissoAntiAFK") then
                LocalPlayer:SetAttribute("KissoAntiAFK", true)
                LocalPlayer.Idled:Connect(function()
                    VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                    task.wait(1)
                    VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                end)
            end
        end
    end,
})

MiscTab:CreateDivider({ line = false, spacing = 12 })
MiscTab:CreateSection({ Name = "🚀 Optimization" })

MiscTab:CreateToggle({
    Name = "Fast Mode (FPS Booster)",
    Flag = "Toggle_FastMode",
    CurrentValue = false,
    Callback = function(Value)
        Toggles.FastMode = Value
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
                if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("PostEffect") then
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
-- LIVE REFRESH LOOP
-- =================================================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local elapsedMinutes = math.floor((os.time() - SessionStartTime) / 60)
            local activeFeatures = 0
            for _, v in pairs(Toggles) do
                if v == true then activeFeatures += 1 end
            end

            SessionStat:Set(elapsedMinutes)
            FeaturesStat:Set(activeFeatures)
            FpsStat:Set(math.floor(Workspace:GetRealPhysicsFPS() or 60))
            PlayersStat:Set(#Players:GetPlayers())

            -- Update activity tag based on which farm loop is running
            local anyFarm = Toggles.CollectPrograms or Toggles.PC or Toggles.Coding
                or Toggles.AutoSell or Toggles.Mining or Toggles.Fishing or Toggles.Meteors
            if anyFarm then
                StateTag:Set({ text = "FARMING", color = Color3.fromRGB(0, 220, 130) })
            else
                StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
            end
        end)
    end
end)

-- =================================================================
-- DEFERRED CONFIG LOAD
-- =================================================================
task.defer(function()
    pcall(function()
        Window:Load()
    end)
end)

SafeNotify("KissoHub", "Loaded successfully", 3)
