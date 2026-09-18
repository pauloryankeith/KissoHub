-- =================================================================
-- KissoHub — Ride-A-Pet  |  v1.4.0
-- =================================================================
local HttpService = game:GetService("HttpService")

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

-- =================================================================
-- SERVICES
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
local HUB_VERSION = "v1.4.0"

-- =================================================================
-- EGG LIST + RARITY TABLE
-- =================================================================
local FULL_EGG_LIST = {
    "Admin Egg", "Asteroid Egg", "Aurora Egg", "Blackhole Egg", "Brown Egg",
    "Cherub Egg", "Cracked Egg", "Crystal Egg", "Devil Fruit Egg", "Diamond Egg",
    "Dominus Egg", "Dragon Egg", "Easter Egg", "Flaming Egg", "Flower Egg",
    "Galaxy Egg", "Giant Egg", "Glass Egg", "Golden Egg", "Ice Egg",
    "Leaf Egg", "Mushroom Egg", "Sinister Egg", "Skull Egg",
    "Slime Egg", "Solaris Egg", "Soul Egg", "Stone Egg", "White Egg"
}

local RARITY_COLORS = {
    Common    = Color3.fromRGB(230, 230, 230),
    Uncommon  = Color3.fromRGB(80, 220, 100),
    Rare      = Color3.fromRGB(0, 200, 255),
    Epic      = Color3.fromRGB(190, 40, 220),
    Legendary = Color3.fromRGB(255, 200, 40),
    Mythic    = Color3.fromRGB(255, 130, 40),
    Secret    = Color3.fromRGB(255, 60, 60),
    Admin     = Color3.fromRGB(255, 100, 220),
}

local EGG_RARITY = {
    ["Brown Egg"]       = "Common",
    ["Cracked Egg"]     = "Common",
    ["White Egg"]       = "Common",

    ["Stone Egg"]       = "Uncommon",
    ["Leaf Egg"]        = "Uncommon",
    ["Mushroom Egg"]    = "Uncommon",
    ["Flower Egg"]      = "Uncommon",

    ["Ice Egg"]         = "Rare",
    ["Glass Egg"]       = "Rare",
    ["Slime Egg"]       = "Rare",
    ["Easter Egg"]      = "Rare",

    ["Golden Egg"]      = "Epic",
    ["Diamond Egg"]     = "Epic",
    ["Crystal Egg"]     = "Epic",
    ["Flaming Egg"]     = "Epic",

    ["Skull Egg"]       = "Legendary",
    ["Asteroid Egg"]    = "Legendary",
    ["Dominus Egg"]     = "Legendary",
    ["Sinister Egg"]    = "Legendary",

    ["Soul Egg"]        = "Mythic",
    ["Aurora Egg"]      = "Mythic",
    ["Galaxy Egg"]      = "Mythic",
    ["Giant Egg"]       = "Mythic",
    ["Dragon Egg"]      = "Mythic",

    ["Blackhole Egg"]   = "Secret",
    ["Cherub Egg"]      = "Secret",
    ["Solaris Egg"]     = "Secret",
    ["Devil Fruit Egg"] = "Secret",

    ["Admin Egg"]       = "Admin",
}

local function GetEggColor(eggName)
    local tier = EGG_RARITY[eggName]
    if tier and RARITY_COLORS[tier] then
        return RARITY_COLORS[tier], tier
    end
    return RARITY_COLORS.Common, "Common"
end

-- =================================================================
-- STATE
-- =================================================================
local SelectedEggsLookup = {}
local NestEggsLookup = {}
local ESPEggsLookup = {}
local ESPShowNames = true

local FlySpeed = 400
local AutofarmEnabled = false
local EggESPEnabled = false
local AutoNestEnabled = false
local AutoHatchEnabled = false
local AutoUpgradeLuckEnabled = false
local UpgradeInterval = 5
local InfZoomEnabled = false
local FastModeEnabled = false
local AntiAFKEnabled = false

local PlacementMode = "Random"
local PlaceInterval = 0.5
local BlueprintEnabled = false

local GRID_COLS = 5
local GRID_ROWS = 2

local GridGapX = 7
local GridGapZ = 7
local RowGap = 5
local GridRotation = 0

local BlueprintMarkers = {}
local BlueprintFolder = nil

local MAX_EGGS = 10

local ActiveHighlights = {}
local ActiveNameLabels = {}

local NoclipConnection = nil
local AntiAFKConnection = nil

local SessionStartTime = os.time()
local EggsGrabbedCount = 0
local EggsPlacedCount = 0
local EggsHatchedCount = 0

local PreviousCash = 0
local CashPerSecond = 0
local LastCashCheckTime = os.clock()

local OriginalLightingSettings = {
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd,
}

-- =================================================================
-- REMOTES
-- =================================================================
local Remotes       = ReplicatedStorage:WaitForChild("Remotes", 10)
local GameRemotes   = Remotes and Remotes:WaitForChild("Game", 10)
local EggPlaced     = GameRemotes and GameRemotes:WaitForChild("EggPlaced")
local HatchRemote   = GameRemotes and GameRemotes:WaitForChild("Hatch")
local PlotFolder    = GameRemotes and GameRemotes:WaitForChild("Plot", 5)
local UpgradeRemote = PlotFolder and PlotFolder:WaitForChild("Upgrades", 5)

-- =================================================================
-- HELPERS
-- =================================================================
local function GetPlayerCash()
    local cash = 0
    pcall(function()
        if LocalPlayer:FindFirstChild("SavedData") and LocalPlayer.SavedData:FindFirstChild("Cash") then
            cash = LocalPlayer.SavedData.Cash.Value
        elseif LocalPlayer:FindFirstChild("leaderstats") then
            local v = LocalPlayer.leaderstats:FindFirstChild("Cash")
                or LocalPlayer.leaderstats:FindFirstChild("Coins")
                or LocalPlayer.leaderstats:FindFirstChild("Money")
            if v then cash = v.Value end
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
        if LocalPlayer and LocalPlayer.GetNetworkPing then
            ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        elseif StatsService:FindFirstChild("Network") and StatsService.Network:FindFirstChild("ServerStatsItem") then
            local pi = StatsService.Network.ServerStatsItem:FindFirstChild("Data Ping")
            if pi then ping = math.floor(pi:GetValue()) end
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
    local cframe
    if plot:IsA("Model") then cframe = plot:GetPivot()
    elseif plot:IsA("BasePart") then cframe = plot.CFrame
    else
        local base = plot:FindFirstChild("Base") or plot:FindFirstChild("Baseplate") or plot:FindFirstChildWhichIsA("BasePart")
        cframe = base and base.CFrame or CFrame.new()
    end
    return cframe.Position + Vector3.new(0, 4, 0)
end

local function GetBaseplate()
    local plot = GetPlayerPlot()
    if not plot then return nil end
    return plot:FindFirstChild("Baseplate")
        or plot:FindFirstChild("Base")
        or plot:FindFirstChildWhichIsA("BasePart", true)
end

local function GetEggsFolder()
    local plot = GetPlayerPlot()
    if not plot then return nil end
    return plot:FindFirstChild("Eggs")
end

local function CountPlacedEggs()
    local eggsFolder = GetEggsFolder()
    if not eggsFolder then return 0 end
    local count = 0
    for _, _ in ipairs(eggsFolder:GetChildren()) do count += 1 end
    return count
end

-- =================================================================
-- ROTATION HELPER
-- =================================================================
local function RotateOffset(offset, degrees)
    if degrees == 0 then return offset end
    local rad = math.rad(degrees)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    return Vector3.new(
        offset.X * cosA - offset.Z * sinA,
        offset.Y,
        offset.X * sinA + offset.Z * cosA
    )
end

-- =================================================================
-- BLUEPRINT POSITION GENERATORS
-- =================================================================
local function GenerateGridSlots(baseplate)
    local slots = {}
    if not baseplate then return slots end
    local center = baseplate.Position

    local totalW = (GRID_COLS - 1) * GridGapX
    local totalH = (GRID_ROWS - 1) * GridGapZ
    local startX = -totalW / 2
    local startZ = -totalH / 2

    for r = 0, GRID_ROWS - 1 do
        for c = 0, GRID_COLS - 1 do
            local offset = Vector3.new(
                startX + c * GridGapX, 2, startZ + r * GridGapZ
            )
            offset = RotateOffset(offset, GridRotation)
            table.insert(slots, center + offset)
        end
    end
    return slots
end

local function GenerateRowSlots(baseplate)
    local slots = {}
    if not baseplate then return slots end
    local center = baseplate.Position
    local gap = math.max(2, RowGap)
    local total = (MAX_EGGS - 1) * gap
    local startX = -total / 2

    for i = 0, MAX_EGGS - 1 do
        local offset = Vector3.new(startX + i * gap, 2, 0)
        offset = RotateOffset(offset, GridRotation)
        table.insert(slots, center + offset)
    end
    return slots
end

local function GenerateRandomPosition(baseplate)
    if not baseplate then return nil end
    local size = baseplate.Size
    local center = baseplate.Position
    local halfX = (size.X / 2) - 5
    local halfZ = (size.Z / 2) - 5
    return Vector3.new(
        center.X + (math.random() * 2 - 1) * halfX,
        center.Y + 2,
        center.Z + (math.random() * 2 - 1) * halfZ
    )
end

local function GetOccupiedPositions()
    local occupied = {}
    local eggsFolder = GetEggsFolder()
    if not eggsFolder then return occupied end
    for _, egg in ipairs(eggsFolder:GetChildren()) do
        local coord = egg:GetAttribute("Coordinate")
        if typeof(coord) == "CFrame" then
            local k = math.floor(coord.Position.X) .. "|" .. math.floor(coord.Position.Z)
            occupied[k] = true
        else
            local bp = egg:IsA("BasePart") and egg or egg:FindFirstChildWhichIsA("BasePart", true)
            if bp then
                local k = math.floor(bp.Position.X) .. "|" .. math.floor(bp.Position.Z)
                occupied[k] = true
            end
        end
    end
    return occupied
end

local function IsOccupied(occupied, pos, tol)
    tol = tol or 3
    local x0 = math.floor(pos.X)
    local z0 = math.floor(pos.Z)
    for dx = -tol, tol do
        for dz = -tol, tol do
            if occupied[(x0 + dx) .. "|" .. (z0 + dz)] then return true end
        end
    end
    return false
end

local function FindFreePosition(baseplate, slotList, occupied)
    for _, pos in ipairs(slotList) do
        if not IsOccupied(occupied, pos, 3) then return pos end
    end

    if baseplate then
        local center = baseplate.Position
        local size = baseplate.Size
        local halfX = (size.X / 2) - 5
        local halfZ = (size.Z / 2) - 5
        for radius = 1, 12 do
            for angle = 0, 7 do
                local a = angle * math.pi / 4
                local testPos = Vector3.new(
                    center.X + math.cos(a) * radius * math.max(GridGapX, 5),
                    center.Y + 2,
                    center.Z + math.sin(a) * radius * math.max(GridGapZ, 5)
                )
                local inBounds = math.abs(testPos.X - center.X) < halfX
                    and math.abs(testPos.Z - center.Z) < halfZ
                if inBounds and not IsOccupied(occupied, testPos, 3) then
                    return testPos
                end
            end
        end
    end
    return nil
end

-- =================================================================
-- BLUEPRINT VISUALS
-- =================================================================
local function ClearBlueprintMarkers()
    if BlueprintFolder then
        BlueprintFolder:Destroy()
        BlueprintFolder = nil
    end
    table.clear(BlueprintMarkers)
end

local function BuildBlueprintMarkers(baseplate, slotList)
    ClearBlueprintMarkers()
    if not baseplate or not slotList or #slotList == 0 then return end

    local container = Instance.new("Folder")
    container.Name = "KissoHub_Blueprint"
    container.Parent = Workspace

    for i, pos in ipairs(slotList) do
        local dot = Instance.new("Part")
        dot.Name = "Slot_" .. i
        dot.Shape = Enum.PartType.Ball
        dot.Size = Vector3.new(2, 2, 2)
        dot.Position = pos
        dot.Anchored = true
        dot.CanCollide = false
        dot.CanTouch = false
        dot.Material = Enum.Material.Neon
        dot.Color = Color3.fromRGB(0, 200, 255)
        dot.Transparency = 0.2
        dot.Parent = container

        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(190, 40, 220)
        hl.OutlineColor = Color3.fromRGB(0, 200, 255)
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0
        hl.Adornee = dot
        hl.Parent = dot

        BlueprintMarkers[i] = dot
    end

    BlueprintFolder = container
end

local function RefreshBlueprint()
    if not BlueprintEnabled then
        ClearBlueprintMarkers()
        return
    end
    local baseplate = GetBaseplate()
    if not baseplate then return end

    local slots
    if PlacementMode == "Grid" then
        slots = GenerateGridSlots(baseplate)
    elseif PlacementMode == "Row" then
        slots = GenerateRowSlots(baseplate)
    else
        slots = {}
        for i = 1, MAX_EGGS do
            table.insert(slots, GenerateRandomPosition(baseplate))
        end
    end
    BuildBlueprintMarkers(baseplate, slots)
end

-- =================================================================
-- ESP NAME LABELS
-- =================================================================
local function ClearNameLabel(egg)
    if ActiveNameLabels[egg] then
        ActiveNameLabels[egg]:Destroy()
        ActiveNameLabels[egg] = nil
    end
end

local function ClearAllLabels()
    for egg, _ in pairs(ActiveNameLabels) do
        if egg and egg.Parent then
            local gui = egg:FindFirstChild("KissoHub_NameLabel")
            if gui then gui:Destroy() end
        end
    end
    table.clear(ActiveNameLabels)
end

local function BuildNameLabel(egg)
    if not egg or not egg.Parent then return end
    if ActiveNameLabels[egg] then return end

    local color = GetEggColor(egg.Name)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "KissoHub_NameLabel"
    billboard.Size = UDim2.new(0, 200, 0, 32)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 500
    billboard.LightInfluence = 0
    billboard.ResetOnSpawn = false
    billboard.Adornee = egg
    billboard.Parent = egg

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = egg.Name
    label.TextColor3 = color
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.3
    label.TextScaled = false
    label.TextSize = 16
    label.Font = Enum.Font.GothamBold
    label.TextWrapped = false
    label.Parent = billboard

    ActiveNameLabels[egg] = billboard
end

local function RefreshESPLabels()
    if not EggESPEnabled then
        ClearAllLabels()
        return
    end

    local renderedFolder = Workspace:FindFirstChild("RenderedEggs")
    if not renderedFolder then return end

    for _, egg in ipairs(renderedFolder:GetChildren()) do
        if ActiveNameLabels[egg] and not ActiveNameLabels[egg].Parent then
            ActiveNameLabels[egg] = nil
        end

        if not ESPShowNames then
            ClearNameLabel(egg)
        else
            local hasSelection = next(ESPEggsLookup) ~= nil
            local shouldLabel = (not hasSelection) or ESPEggsLookup[egg.Name] == true

            if shouldLabel then
                if not ActiveNameLabels[egg] then
                    BuildNameLabel(egg)
                else
                    local billboard = ActiveNameLabels[egg]
                    local label = billboard:FindFirstChildWhichIsA("TextLabel")
                    if label then
                        local color = GetEggColor(egg.Name)
                        label.Text = egg.Name
                        label.TextColor3 = color
                    end
                end
            else
                ClearNameLabel(egg)
            end
        end
    end

    for egg, gui in pairs(ActiveNameLabels) do
        if not egg or not egg.Parent then
            if gui then gui:Destroy() end
            ActiveNameLabels[egg] = nil
        end
    end
end

-- =================================================================
-- WINDOW
-- =================================================================
local Window = Rayfield:CreateWindow({
    name = "KissoHub",
    subtitle = "Ride-A-Pet",
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
        fileName = "RideAPetPrefs",
        customFolder = "KissoHubFolder",
    },
})

local StatusTag = Window:CreateTag({ text = HUB_VERSION, color = Color3.fromRGB(0, 200, 255) })
local StateTag  = Window:CreateTag({ text = "IDLE",       color = Color3.fromRGB(190, 40, 220) })

-- =================================================================
-- NOTIFICATIONS
-- =================================================================
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
-- MOVEMENT HELPERS
-- =================================================================
local function TeleportToMyPlot()
    local center = GetPlayerPlotCenter()
    if center then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(center)
            QuickToast("Teleported", "Moved to your plot")
        end
    else
        SafeNotify("Teleport Error", "Could not find your plot!", 3)
    end
end

local function TeleportToStall(stallName)
    local stallsFolder = Workspace:FindFirstChild("Stalls")
    if not stallsFolder then SafeNotify("Teleport Error", "Workspace.Stalls not found!", 3); return end
    local stall = stallsFolder:FindFirstChild(stallName)
    if not stall then SafeNotify("Teleport Error", "Stall '" .. stallName .. "' not found!", 3); return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local targetCF
    if stall:IsA("Model") then targetCF = stall:GetPivot()
    elseif stall:IsA("BasePart") then targetCF = stall.CFrame
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
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end)
        end
    else
        if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil end
    end
end

local function CheckAndEquipNestEgg()
    if next(NestEggsLookup) == nil then return true end
    local char = LocalPlayer.Character
    if not char then return false end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") and NestEggsLookup[item.Name] then return true end
    end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and NestEggsLookup[item.Name] then
                humanoid:EquipTool(item)
                task.wait(0.1)
                return true
            end
        end
    end
    return false
end

local function FlyToTarget(target)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
    local hrp = char.HumanoidRootPart

    while AutofarmEnabled and char and hrp do
        if typeof(target) == "Instance" then
            if not (target.Parent and target:IsDescendantOf(Workspace)) then return false end
        end

        local targetPos = typeof(target) == "Vector3" and target
            or (target:IsA("Model") and target:GetPivot().Position or target.Position)
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
        if fireproximityprompt then fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(0.05)
            prompt:InputHoldEnd()
        end
        EggsGrabbedCount += 1
    end
end

-- =================================================================
-- TABS
-- =================================================================
local HomeTab = Window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })
local FarmTab = Window:CreateTab({ name = "⚡ Egg Automation" })
local EggTab  = Window:CreateTab({ name = "🥚 Egg Management" })
local MiscTab = Window:CreateTab({ name = "🛠️ Misc" })
local InfoTab = Window:CreateTab({ name = "ℹ️ Info" })

-- =================================================================
-- HOME TAB — 2-COLUMN GRID LAYOUT
-- =================================================================
HomeTab:CreateSection({ name = "📊 Stats" })

-- Create a row-based grid; nest two columns inside
local StatsGrid = HomeTab:CreateGroup()

local StatsLeft = StatsGrid:CreateGroup({ direction = "column" })
local StatsRight = StatsGrid:CreateGroup({ direction = "column" })

-- Left column
local CashStat    = StatsLeft:CreateStat({ name = "💵 Cash", prefix = "$", value = 0, compact = true })
local GrabbedStat = StatsLeft:CreateStat({ name = "🥚 Eggs Grabbed", value = 0, compact = true })
local HatchedStat = StatsLeft:CreateStat({ name = "🐣 Eggs Hatched", value = 0, compact = true })

-- Right column
local CpsStat     = StatsRight:CreateStat({ name = "📈 $/s", prefix = "$", value = 0, compact = true })
local PlacedStat  = StatsRight:CreateStat({ name = "🌱 Eggs Placed", value = 0, compact = true })
local PlacedNowStat = StatsRight:CreateStat({ name = "📦 On Plot", value = 0, suffix = "/10", compact = true })

HomeTab:CreateDivider({ spacing = 14 })
HomeTab:CreateSection({ name = "⚡ System Status" })

local SystemGrid = HomeTab:CreateGroup()

local SystemLeft = SystemGrid:CreateGroup({ direction = "column" })
local SystemRight = SystemGrid:CreateGroup({ direction = "column" })

-- Left column
local SessionStat  = SystemLeft:CreateStat({ name = "⏱️ Session", value = 0, suffix = " m", compact = true })
local FpsStat      = SystemLeft:CreateStat({ name = "🎮 FPS", value = 0, compact = true })
local PlayersStat  = SystemLeft:CreateStat({ name = "👥 Players", value = 1, compact = true })

-- Right column
local FeaturesStat = SystemRight:CreateStat({ name = "⚙️ Features", value = 0, compact = true })
local PingStat     = SystemRight:CreateStat({ name = "📡 Ping", value = 0, suffix = " ms", compact = true })

HomeTab:CreateDivider({ text = "controls" })
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
-- FARM TAB
-- =================================================================
FarmTab:CreateSection({ name = "👁️ Visuals & Movement" })

FarmTab:CreateToggle({
    name = "Egg ESP",
    flag = "EggESP",
    value = false,
    callback = function(Value)
        EggESPEnabled = Value
        if not Value then
            for egg, hl in pairs(ActiveHighlights) do
                if hl then hl:Destroy() end
            end
            table.clear(ActiveHighlights)
            ClearAllLabels()
        end
    end,
})

FarmTab:CreateToggle({
    name = "Show Egg Names",
    flag = "ESPShowNames",
    value = true,
    callback = function(Value)
        ESPShowNames = Value
        if not Value then
            ClearAllLabels()
        else
            RefreshESPLabels()
        end
    end,
})

FarmTab:CreateDropdown({
    name = "Select ESP Egg Names",
    flag = "ESPEggs",
    options = FULL_EGG_LIST,
    value = {},
    multiSelect = true,
    callback = function(Options)
        table.clear(ESPEggsLookup)
        if type(Options) == "table" then
            for k, v in pairs(Options) do
                if type(k) == "number" then ESPEggsLookup[v] = true
                elseif type(k) == "string" and (v == true or v == k) then ESPEggsLookup[k] = true end
            end
        end
        RefreshESPLabels()
    end,
})

FarmTab:CreateSlider({
    name = "Autofarm Fly Speed",
    flag = "FlySpeed",
    range = {100, 3000}, increment = 50, suffix = " studs/sec", value = 400,
    callback = function(Value) FlySpeed = Value end,
})

FarmTab:CreateDivider({ text = "execution" })
FarmTab:CreateSection({ name = "🌾 Farm Controls" })

FarmTab:CreateToggle({
    name = "Autofarm Egg",
    flag = "AutofarmEgg",
    value = false,
    callback = function(Value)
        AutofarmEnabled = Value
        SetNoclip(Value)
        if Value then
            QuickToast("Autofarm Active", "Harvesting target eggs")
            task.spawn(function()
                while AutofarmEnabled do
                    local renderedFolder = Workspace:FindFirstChild("RenderedEggs")
                    local plotCenter = GetPlayerPlotCenter()
                    if renderedFolder and plotCenter then
                        local targetEgg = nil
                        if next(SelectedEggsLookup) ~= nil then
                            for _, egg in ipairs(renderedFolder:GetChildren()) do
                                if SelectedEggsLookup[egg.Name] then targetEgg = egg; break end
                            end
                        end
                        if targetEgg and targetEgg.Parent then
                            local reached = FlyToTarget(targetEgg)
                            if reached and targetEgg.Parent and targetEgg:IsDescendantOf(Workspace) then
                                InteractWithEgg(targetEgg)
                                task.wait(1.30)
                            end
                            if AutofarmEnabled then FlyToTarget(plotCenter); task.wait(0.2) end
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                char.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end,
})

FarmTab:CreateDropdown({
    name = "Select Target Eggs",
    flag = "SelectedEggs",
    options = FULL_EGG_LIST,
    value = {},
    multiSelect = true,
    callback = function(Options)
        table.clear(SelectedEggsLookup)
        if type(Options) == "table" then
            for k, v in pairs(Options) do
                if type(k) == "number" then SelectedEggsLookup[v] = true
                elseif type(k) == "string" and (v == true or v == k) then SelectedEggsLookup[k] = true end
            end
        end
    end,
})

-- =================================================================
-- EGG TAB
-- =================================================================
EggTab:CreateSection({ name = "🪹 Placement Settings" })

EggTab:CreateDropdown({
    name = "Placement Mode",
    flag = "PlacementMode",
    options = { "Random", "Grid", "Row" },
    value = { "Random" },
    multiSelect = false,
    callback = function(Option)
        local choice = typeof(Option) == "table" and Option[1] or Option
        PlacementMode = choice
        QuickToast("Placement Mode", choice)
        if BlueprintEnabled then RefreshBlueprint() end
    end,
})

EggTab:CreateToggle({
    name = "Turn On Blueprint",
    flag = "BlueprintEnabled",
    value = false,
    callback = function(Value)
        BlueprintEnabled = Value
        RefreshBlueprint()
        if Value then QuickToast("Blueprint", "Slot preview shown")
        else QuickToast("Blueprint", "Slot preview hidden") end
    end,
})

EggTab:CreateDivider({ text = "grid tuning (2 × 5 locked)" })

EggTab:CreateSlider({
    name = "Column Gap",
    flag = "GridGapX",
    range = { 2, 20 }, increment = 1, value = 7, suffix = " studs",
    callback = function(Value)
        GridGapX = Value
        if BlueprintEnabled and PlacementMode == "Grid" then RefreshBlueprint() end
    end,
})

EggTab:CreateSlider({
    name = "Row Gap (Grid)",
    flag = "GridGapZ",
    range = { 2, 20 }, increment = 1, value = 7, suffix = " studs",
    callback = function(Value)
        GridGapZ = Value
        if BlueprintEnabled and PlacementMode == "Grid" then RefreshBlueprint() end
    end,
})

EggTab:CreateDivider({ text = "row tuning" })

EggTab:CreateSlider({
    name = "Item Gap (Row)",
    flag = "RowGap",
    range = { 2, 20 }, increment = 1, value = 5, suffix = " studs",
    callback = function(Value)
        RowGap = Value
        if BlueprintEnabled and PlacementMode == "Row" then RefreshBlueprint() end
    end,
})

EggTab:CreateDivider({ text = "rotation" })

EggTab:CreateSlider({
    name = "Rotation",
    flag = "GridRotation",
    range = { 0, 360 }, increment = 15, value = 0, suffix = "°",
    callback = function(Value)
        GridRotation = Value
        if BlueprintEnabled and PlacementMode ~= "Random" then RefreshBlueprint() end
    end,
})

EggTab:CreateDivider({ text = "rate control" })

EggTab:CreateSlider({
    name = "Placement Interval",
    flag = "PlaceInterval",
    range = { 0.1, 3 }, increment = 0.05, value = 0.5, suffix = " s",
    callback = function(Value) PlaceInterval = Value end,
})

EggTab:CreateDivider({ text = "filters" })
EggTab:CreateSection({ name = "🎯 Egg Filters" })

EggTab:CreateDropdown({
    name = "Select Eggs for Nest",
    flag = "NestEggs",
    options = FULL_EGG_LIST,
    value = {},
    multiSelect = true,
    callback = function(Options)
        table.clear(NestEggsLookup)
        if type(Options) == "table" then
            for k, v in pairs(Options) do
                if type(k) == "number" then NestEggsLookup[v] = true
                elseif type(k) == "string" and (v == true or v == k) then NestEggsLookup[k] = true end
            end
        end
    end,
})

EggTab:CreateDivider({ text = "automation" })
EggTab:CreateSection({ name = "🔄 Automation Loops" })

EggTab:CreateToggle({
    name = "Auto Put Egg to Plot",
    flag = "AutoPutEgg",
    value = false,
    callback = function(Value)
        AutoNestEnabled = Value
        if Value then
            QuickToast("Auto Place", "Started placing eggs")
            task.spawn(function()
                while AutoNestEnabled do
                    local baseplate = GetBaseplate()
                    local eggsFolder = GetEggsFolder()

                    if baseplate and eggsFolder and EggPlaced then
                        local eggCount = CountPlacedEggs()
                        if eggCount >= MAX_EGGS then
                            task.wait(2)
                        elseif CheckAndEquipNestEgg() then
                            local occupied = GetOccupiedPositions()
                            local pos = nil

                            if PlacementMode == "Grid" then
                                pos = FindFreePosition(baseplate, GenerateGridSlots(baseplate), occupied)
                            elseif PlacementMode == "Row" then
                                pos = FindFreePosition(baseplate, GenerateRowSlots(baseplate), occupied)
                            else
                                for attempt = 1, 8 do
                                    local candidate = GenerateRandomPosition(baseplate)
                                    if candidate and not IsOccupied(occupied, candidate, 3) then
                                        pos = candidate; break
                                    end
                                end
                                if not pos then
                                    pos = FindFreePosition(baseplate, GenerateGridSlots(baseplate), occupied)
                                end
                            end

                            if pos then
                                EggPlaced:FireServer({ PlantPosition = pos })
                                EggsPlacedCount += 1
                                task.wait(PlaceInterval)
                            else
                                task.wait(2)
                            end
                        else
                            task.wait(1)
                        end
                    end
                    task.wait(0.2)
                end
            end)
        end
    end,
})

EggTab:CreateToggle({
    name = "Auto Hatch Egg",
    flag = "AutoHatchEgg",
    value = false,
    callback = function(Value)
        AutoHatchEnabled = Value
        if Value then
            QuickToast("Auto Hatch", "Started hatching eggs")
            task.spawn(function()
                while AutoHatchEnabled do
                    local eggsFolder = GetEggsFolder()
                    if eggsFolder and HatchRemote then
                        local eggs = eggsFolder:GetChildren()
                        if #eggs == 0 then
                            task.wait(2)
                        else
                            for _, egg in ipairs(eggs) do
                                if not AutoHatchEnabled then break end
                                local eggKey = egg:GetAttribute("EggKey")
                                if eggKey then
                                    HatchRemote:FireServer({ EggKey = tostring(eggKey) })
                                    EggsHatchedCount += 1
                                    task.wait(0.1)
                                end
                            end
                            task.wait(0.5)
                        end
                    else
                        task.wait(1)
                    end
                end
            end)
        end
    end,
})

-- =================================================================
-- MISC TAB
-- =================================================================
MiscTab:CreateSection({ name = "🍀 Hatch Luck" })

MiscTab:CreateToggle({
    name = "Auto Upgrade Hatch Luck",
    flag = "AutoUpgradeLuck",
    value = false,
    callback = function(Value)
        AutoUpgradeLuckEnabled = Value
        if Value then
            QuickToast("Hatch Luck", "Auto upgrade enabled")
            task.spawn(function()
                while AutoUpgradeLuckEnabled do
                    if UpgradeRemote then
                        pcall(function() UpgradeRemote:FireServer("Max") end)
                    end
                    task.wait(UpgradeInterval)
                end
            end)
        end
    end,
})

MiscTab:CreateSlider({
    name = "Upgrade Interval",
    flag = "UpgradeInterval",
    range = { 1, 60 }, increment = 1, value = 5, suffix = " s",
    callback = function(Value) UpgradeInterval = Value end,
})

MiscTab:CreateDivider({ text = "teleports" })
MiscTab:CreateSection({ name = "📍 Fast Teleports" })
MiscTab:CreateButton({ name = "🥚 TP Egg Tracker Stall", callback = function() TeleportToStall("EggTracker") end })
MiscTab:CreateButton({ name = "🥩 TP Food Stall", callback = function() TeleportToStall("Food") end })
MiscTab:CreateButton({ name = "🏡 TP My Plot", callback = function() TeleportToMyPlot() end })
MiscTab:CreateButton({ name = "⚙️ TP Gears Stall", callback = function() TeleportToStall("Gears") end })
MiscTab:CreateButton({ name = "💰 TP Sell Stall", callback = function() TeleportToStall("Sell") end })

MiscTab:CreateDivider({ text = "preferences" })
MiscTab:CreateSection({ name = "⚙️ Player Options" })

MiscTab:CreateToggle({
    name = "Infinite Zoom",
    flag = "InfZoom",
    value = false,
    callback = function(Value)
        InfZoomEnabled = Value
        LocalPlayer.CameraMaxZoomDistance = Value and 100000 or 128
    end,
})

MiscTab:CreateToggle({
    name = "Anti-AFK",
    flag = "AntiAFK",
    value = false,
    callback = function(Value)
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
            if AntiAFKConnection then AntiAFKConnection:Disconnect(); AntiAFKConnection = nil end
        end
    end,
})

MiscTab:CreateDivider({ line = false, spacing = 12 })
MiscTab:CreateSection({ name = "🚀 Optimization" })

MiscTab:CreateToggle({
    name = "Fast Mode (FPS Booster)",
    flag = "FastMode",
    value = false,
    callback = function(Value)
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
-- INFO TAB
-- =================================================================
InfoTab:CreateSection({ name = "ℹ️ About" })

InfoTab:CreateText({
    name = "KissoHub — Ride-A-Pet",
    text = "Version: " .. HUB_VERSION .. "\n" ..
           "Max Eggs per Plot: " .. MAX_EGGS .. "\n" ..
           "Total Eggs Tracked: " .. #FULL_EGG_LIST .. "\n" ..
           "Config: KissoHubFolder/RideAPetPrefs.rfld",
})

InfoTab:CreateDivider({ text = "changelog" })
InfoTab:CreateSection({ name = "📋 Changelog" })

InfoTab:CreateText({
    name = HUB_VERSION .. " — Latest",
    text = "• NEW: 2-column grid layout for Home stats\n" ..
           "• NEW: 2-column grid layout for System Status\n" ..
           "• Matches Rayfield Gen2 Example style",
})

InfoTab:CreateText({
    name = "v1.3.0",
    text = "• NEW: Egg name labels on ESP (BillboardGui)\n" ..
           "• NEW: Rarity-based label colors\n" ..
           "• NEW: Dedicated 'Select ESP Egg Names' dropdown\n" ..
           "• UPDATED: Full egg list — 29 eggs",
})

InfoTab:CreateText({
    name = "v1.2.0",
    text = "• NEW: Rotation slider (0° – 360°)\n" ..
           "• NEW: Grid locked to 2×5\n" ..
           "• Centered to baseplate center",
})

InfoTab:CreateDivider({ text = "rarity legend" })
InfoTab:CreateSection({ name = "🎨 Rarity Colors" })

InfoTab:CreateText({
    name = "Tier Colors",
    text = "• Common — White\n" ..
           "• Uncommon — Green\n" ..
           "• Rare — Cyan\n" ..
           "• Epic — Purple\n" ..
           "• Legendary — Gold\n" ..
           "• Mythic — Orange\n" ..
           "• Secret — Red\n" ..
           "• Admin — Pink",
})

InfoTab:CreateDivider({ text = "how it works" })
InfoTab:CreateSection({ name = "💡 How It Works" })

InfoTab:CreateText({
    name = "ESP Names",
    text = "With Egg ESP on:\n" ..
           "• Highlight shows on ALL eggs\n" ..
           "• Names show on ALL eggs by default\n" ..
           "• Use 'Select ESP Egg Names' to filter\n" ..
           "• If dropdown is EMPTY → names show on everything\n" ..
           "• If dropdown has entries → only those eggs get names",
})

InfoTab:CreateText({
    name = "Full auto loop",
    text = "For a hands-off farm:\n" ..
           "• Autofarm Egg\n" ..
           "• Auto Put Egg to Plot\n" ..
           "• Auto Hatch Egg\n" ..
           "• Auto Upgrade Hatch Luck",
})

-- =================================================================
-- TOP BAR HUD
-- =================================================================
local function BuildTopBarHUD()
    local parentGui = LocalPlayer:WaitForChild("PlayerGui")
    if parentGui:FindFirstChild("StallTeleportBar") then parentGui.StallTeleportBar:Destroy() end

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

        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        local uiStroke = Instance.new("UIStroke")
        uiStroke.Color = data.Border
        uiStroke.Thickness = 2
        uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        uiStroke.Parent = btn

        btn.MouseEnter:Connect(function() btn.Size = UDim2.new(0, 117, 1, 2) end)
        btn.MouseLeave:Connect(function() btn.Size = UDim2.new(0, 115, 1, 0) end)
        btn.MouseButton1Click:Connect(function()
            if data.Target == "MyPlot" then TeleportToMyPlot()
            else TeleportToStall(data.Target) end
        end)
    end
end

BuildTopBarHUD()

MiscTab:CreateToggle({
    name = "Show Top Teleport Bar",
    flag = "ShowTopBar",
    value = true,
    callback = function(Value)
        local parentGui = LocalPlayer:FindFirstChild("PlayerGui")
        local bar = parentGui and parentGui:FindFirstChild("StallTeleportBar")
        if bar then bar.Enabled = Value end
    end,
})

-- =================================================================
-- LIVE REFRESH
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
                + (AutoUpgradeLuckEnabled and 1 or 0)
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
            PlacedStat:Set(EggsPlacedCount)
            HatchedStat:Set(EggsHatchedCount)

            SessionStat:Set(elapsedMinutes)
            FeaturesStat:Set(activeFeatures)
            FpsStat:Set(math.floor(Workspace:GetRealPhysicsFPS() or 60))
            PingStat:Set(GetPing())
            PlayersStat:Set(#Players:GetPlayers())
            PlacedNowStat:Set(CountPlacedEggs())

            if AutofarmEnabled then
                StateTag:Set({ text = "FARMING", color = Color3.fromRGB(0, 220, 130) })
            elseif AutoNestEnabled and AutoHatchEnabled then
                StateTag:Set({ text = "FULL AUTO", color = Color3.fromRGB(0, 220, 130) })
            elseif AutoNestEnabled then
                StateTag:Set({ text = "PLACING", color = Color3.fromRGB(0, 200, 255) })
            elseif AutoHatchEnabled then
                StateTag:Set({ text = "HATCHING", color = Color3.fromRGB(190, 40, 220) })
            elseif activeFeatures > 0 then
                StateTag:Set({ text = "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
            else
                StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
            end
        end)
    end
end)

-- =================================================================
-- EGG ESP LOOP (Highlight)
-- =================================================================
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

                for egg, hl in pairs(ActiveHighlights) do
                    if not egg or not egg.Parent then
                        if hl then hl:Destroy() end
                        ActiveHighlights[egg] = nil
                    end
                end
            end)
        end
    end
end)

-- =================================================================
-- ESP NAME LABELS LOOP
-- =================================================================
task.spawn(function()
    while task.wait(0.5) do
        if EggESPEnabled and ESPShowNames then
            pcall(RefreshESPLabels)
        elseif not ESPShowNames then
            ClearAllLabels()
        end
    end
end)

SafeNotify("KissoHub", "Ride-A-Pet " .. HUB_VERSION .. " loaded", 3)
