-- ═══════════════════════════════════════════════════════════════
--   KissoHub — Karinderya Module  |  v1.5.8
--   Author: pauloryankeith
--   Official: github.com/pauloryankeith/KissoHub
--   Unauthorized copies are not endorsed or supported.
-- ═══════════════════════════════════════════════════════════════
local HttpService = game:GetService("HttpService")
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local StatsService        = game:GetService("Stats")
local TeleportService     = game:GetService("TeleportService")
local Lighting            = game:GetService("Lighting")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local PathfindingService  = game:GetService("PathfindingService")
local LocalPlayer         = Players.LocalPlayer

local ASSET_ICON  = "rbxassetid://89387722763691"
local HUB_VERSION = "v1.5.8"

local Remotes              = ReplicatedStorage:WaitForChild("Remotes", 10)
local CounterRemotes       = Remotes and Remotes:WaitForChild("CounterRemotes", 5)
local KitchenRemotes       = Remotes and Remotes:WaitForChild("KitchenRemotes", 5)
local PropEquipEvent       = Remotes and Remotes:WaitForChild("PropEquipEvent")
local HitRunawayEvent      = Remotes and Remotes:WaitForChild("HitRunawayEvent")
local CustomerRanAwayEvent = Remotes and Remotes:WaitForChild("CustomerRanAwayEvent")
local AssignNPC            = CounterRemotes and CounterRemotes:WaitForChild("AssignNPC")
local StoveCookingStarted  = KitchenRemotes and KitchenRemotes:WaitForChild("StoveCookingStarted")
local StoveCookingFinished = KitchenRemotes and KitchenRemotes:WaitForChild("StoveCookingFinished")

local AutoServeEnabled     = false
local AutoWashEnabled      = false
local AutoRestockEnabled   = false
local AutoAssignEnabled    = false
local AutoStealEnabled     = false
local AutoEquipPanEnabled  = true
local InfZoomEnabled       = false
local FastModeEnabled      = false
local AntiAFKEnabled       = false
local WalkSpeedValue       = 16
local AutoNoclipEnabled    = true
local NoclipPathfindingEnabled = true
local HeightOffset         = 2
local WashHoldTime         = 30
local WashThreshold        = 12

local PATH_WAYPOINT_TIMEOUT = 2
local PATH_ARRIVE_DISTANCE  = 4

local PRE_TP_DELAY        = 0.05
local POST_TP_SETTLE      = 0.25
local POST_FIRE_WAIT      = 0.3

local ESpamEnabled        = true
local ESpamActive         = false
local ESpamSpeed          = 0.08
local ESpamConnection     = nil

local StolenCount      = 0
local ServedCount      = 0
local WashedCount      = 0
local RestockedCount   = 0
local AssignedCount    = 0
local ESpamFiredCount  = 0
local BurstCycleCount  = 0
local FireAttemptCount = 0
local MoveAttemptCount = 0

local ActiveStoves = {}
local RecentlyHit  = {}
local NoclipActive = false
local NoclipConnection = nil
local AntiAFKConnection = nil

local SessionStartTime  = os.time()
local PreviousCash      = 0
local CashPerSecond     = 0
local LastCashCheckTime = os.clock()

local OriginalLightingSettings = {
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd        = Lighting.FogEnd,
}

local MY_USERNAME = LocalPlayer.Name

-- HELPERS: Stats
local function GetStat(name)
    local v = 0
    pcall(function()
        if LocalPlayer:FindFirstChild("leaderstats") then
            local s = LocalPlayer.leaderstats:FindFirstChild(name)
            if s then v = s.Value end
        end
    end)
    return v
end

local function GetFriendBoost()
    local v = 0
    pcall(function()
        local fb = LocalPlayer:FindFirstChild("FriendBoost")
        if fb then v = fb.Value end
    end)
    return v
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

-- HELPERS: World
local CachedKarenderya = nil
local LastKarenderyaCheck = 0

local function ReadPlotOwner(k)
    local sign = k:FindFirstChild("Sign")
    if not sign then return nil end
    local signage = sign:FindFirstChild("Default") or sign:FindFirstChild("Signage")
    if not signage then return nil end
    local sign1 = signage:FindFirstChild("Sign1")
    if not sign1 then return nil end
    local gui = sign1:FindFirstChild("GUI")
    if not gui then return nil end
    local nameLabel = gui:FindFirstChild("Name")
    if not nameLabel or not nameLabel:IsA("TextLabel") then return nil end
    return nameLabel.Text
end

local function GetKarenderya()
    local now = os.clock()
    if CachedKarenderya and CachedKarenderya.Parent and (now - LastKarenderyaCheck) < 2 then
        return CachedKarenderya
    end
    LastKarenderyaCheck = now
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name:match("^Karenderya%d+$") then
            if ReadPlotOwner(obj) == MY_USERNAME then
                CachedKarenderya = obj
                return obj
            end
        end
    end
    CachedKarenderya = nil
    return nil
end

local function HasOwnPlot() return GetKarenderya() ~= nil end

local function GetKitchen()
    local k = GetKarenderya(); if not k then return nil end
    return k:FindFirstChild("KitchenPlot1") or k:FindFirstChild("KitchenPlot") or k:FindFirstChild("Kitchen")
end

local function GetSink()
    local k = GetKarenderya(); if not k then return nil end
    local s = k:FindFirstChild("Sink")
    if not s then return nil end
    return s:FindFirstChild("Sink") or s
end

local function GetFridge()
    local k = GetKarenderya(); if not k then return nil end
    return k:FindFirstChild("Fridge")
end

local function GetServeFolder()
    local k = GetKarenderya(); if not k then return nil end
    return k:FindFirstChild("Serve") or k:FindFirstChild("Serving")
end

local function GetDiningPlot()
    local k = GetKarenderya(); if not k then return nil end
    return k:FindFirstChild("DiningPlot1") or k:FindFirstChild("DiningPlot") or k:FindFirstChild("Dining")
end

local function GetStealFolder()
    local k = GetKarenderya(); if not k then return nil end
    return k:FindFirstChild("Steal")
end

local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetPartFromObject(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") or obj:IsA("Tool") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    return obj:FindFirstChildWhichIsA("BasePart", true)
end

local function CountDirtyDishes()
    local sink = GetSink()
    if not sink then return 0 end
    local place = sink:FindFirstChild("place")
    if not place then return 0 end
    local c = 0
    for _, child in ipairs(place:GetChildren()) do
        if child.Name:match("^StackedDirty") then c += 1 end
    end
    return c
end

-- NOCLIP (no timeout, tied to toggle)
local function EnableNoclip()
    if NoclipActive then return end
    NoclipActive = true
    NoclipConnection = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

local function DisableNoclip()
    if not NoclipActive then return end
    NoclipActive = false
    if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil end
end

-- MOVEMENT (Pathfinding with Noclip toggle)
local function Move_Pathfinding(pos, offsetY)
    MoveAttemptCount += 1
    local hrp = GetHRP()
    if not hrp or not pos then return end

    local targetPos = pos + Vector3.new(0, offsetY or HeightOffset, 0)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- 🎯 Noclip Pathfinding ON → straight-line walk with NOCLIP
    if NoclipPathfindingEnabled then
        if not NoclipActive then EnableNoclip() end

        humanoid:MoveTo(targetPos)
        local deadline = os.clock() + 5
        while os.clock() < deadline do
            local curHRP = GetHRP()
            if not curHRP then return end
            if (curHRP.Position - targetPos).Magnitude < PATH_ARRIVE_DISTANCE then break end
            task.wait(0.05)
        end
        local stopChar = LocalPlayer.Character
        if stopChar and stopChar:FindFirstChildOfClass("Humanoid") and stopChar:FindFirstChild("HumanoidRootPart") then
            stopChar.Humanoid:MoveTo(stopChar.HumanoidRootPart.Position)
        end
        return
    end

    -- 🎯 Noclip OFF → real pathfinding around obstacles
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = false,
        WaypointSpacing = 4,
    })

    local ok = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)

    if not ok or path.Status ~= Enum.PathStatus.Success then
        humanoid:MoveTo(targetPos)
        local start = os.clock()
        while os.clock() - start < 3 do
            local curHRP = GetHRP()
            if not curHRP then return end
            if (curHRP.Position - targetPos).Magnitude < PATH_ARRIVE_DISTANCE then break end
            task.wait(0.1)
        end
        local stopChar = LocalPlayer.Character
        if stopChar and stopChar:FindFirstChildOfClass("Humanoid") and stopChar:FindFirstChild("HumanoidRootPart") then
            stopChar.Humanoid:MoveTo(stopChar.HumanoidRootPart.Position)
        end
        return
    end

    for _, wp in ipairs(path:GetWaypoints()) do
        local currentChar = LocalPlayer.Character
        local currentHRP = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
        if not currentHRP or not currentHum then return end

        if wp.Action == Enum.PathWaypointAction.Jump then
            currentHum.Jump = true
        end

        currentHum:MoveTo(wp.Position)

        local wpStart = os.clock()
        while os.clock() - wpStart < PATH_WAYPOINT_TIMEOUT do
            local curHRP = GetHRP()
            if not curHRP then return end
            if (curHRP.Position - wp.Position).Magnitude < 3 then break end
            task.wait(0.05)
        end
    end

    local finalChar = LocalPlayer.Character
    if finalChar and finalChar:FindFirstChildOfClass("Humanoid") and finalChar:FindFirstChild("HumanoidRootPart") then
        finalChar.Humanoid:MoveTo(finalChar.HumanoidRootPart.Position)
    end
end

local function MoveTo(pos, offsetY)
    Move_Pathfinding(pos, offsetY)
end

-- E-SPAM
local function PressE()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
    ESpamFiredCount += 1
end

local function StartESpam()
    if not ESpamEnabled or ESpamConnection then return end
    ESpamActive = true
    ESpamConnection = task.spawn(function()
        while ESpamActive do
            PressE()
            task.wait(ESpamSpeed)
        end
    end)
end

local function StopESpam()
    ESpamActive = false
    ESpamConnection = nil
end

local function HoldE(duration)
    duration = duration or WashHoldTime
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    end)
    task.wait(duration)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

-- CLEAN FIRE
local function FirePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    if not prompt.Enabled then return false end

    FireAttemptCount += 1

    local originalHold = prompt.HoldDuration
    if originalHold > 0 then prompt.HoldDuration = 0 end

    local ok = false
    if fireproximityprompt then
        ok = pcall(fireproximityprompt, prompt)
    else
        ok = pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.02)
            prompt:InputHoldEnd()
        end)
    end

    if originalHold > 0 then prompt.HoldDuration = originalHold end
    return ok
end

-- CUSTOMERS & SEATS
local function FindQueuedCustomer()
    local k = GetKarenderya()
    if not k then return nil end
    local line = k:FindFirstChild("Line")
    if not line then return nil end
    local front = line:FindFirstChild("1")
    if not front or not front:IsA("BasePart") then return nil end
    local frontPos = front.Position
    local npcFolder = Workspace:FindFirstChild("ClientNPCs")
    if not npcFolder then return nil end
    local closestNpc, closestDist = nil, 15
    for _, npc in ipairs(npcFolder:GetChildren()) do
        if npc:IsA("Model") then
            local hrp = npc:FindFirstChild("HumanoidRootPart")
            local hum = npc:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (hrp.Position - frontPos).Magnitude
                if d < closestDist then closestNpc, closestDist = npc, d end
            end
        end
    end
    return closestNpc
end

local function GetSortedTables()
    local result = {}
    local dining = GetDiningPlot()
    if not dining then return result end
    for _, child in ipairs(dining:GetChildren()) do
        local num = tonumber(child.Name:match("^Table(%d+)$"))
        if num then table.insert(result, { model = child, num = num }) end
    end
    table.sort(result, function(a, b) return a.num < b.num end)
    return result
end

local function FindFreeSeat()
    for _, entry in ipairs(GetSortedTables()) do
        local t = entry.model
        if not t:GetAttribute("OccupiedBy1") then return { Table = t, Seat = 1 } end
        if not t:GetAttribute("OccupiedBy2") then return { Table = t, Seat = 2 } end
    end
    return nil
end

local function IsCustomer(npc)
    if not npc or not npc:IsA("Model") then return false end
    if npc:GetAttribute("Hired") ~= nil then return false end
    if npc:GetAttribute("Order") == nil then return false end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return true
end

local function IsNpcSeated(npcName)
    for _, entry in ipairs(GetSortedTables()) do
        local t = entry.model
        if t:GetAttribute("OccupiedBy1") == npcName then return true end
        if t:GetAttribute("OccupiedBy2") == npcName then return true end
    end
    return false
end

-- AUTO SERVE HELPERS
local function GetHeldFoodItems()
    local playerFolder = Workspace:FindFirstChild(MY_USERNAME)
    if not playerFolder then return {} end
    local items = {}
    for _, child in ipairs(playerFolder:GetChildren()) do
        if child.Name:match("^Lugaw") or child.Name:match("Silog") or child.Name:match("Food$") then
            table.insert(items, { Name = child.Name, Tool = child })
        end
    end
    return items
end

local function FindAllCookedFood()
    local serveFolder = GetServeFolder()
    if not serveFolder then return {} end
    local result = {}
    local slots = {}
    for _, slot in ipairs(serveFolder:GetChildren()) do
        local num = tonumber(slot.Name)
        if num then table.insert(slots, { obj = slot, num = num }) end
    end
    table.sort(slots, function(a, b) return a.num < b.num end)
    for _, entry in ipairs(slots) do
        local slot = entry.obj
        for _, cooked in ipairs(slot:GetChildren()) do
            if cooked.Name:match("^Cooked_") then
                local plate = cooked:FindFirstChild("Plate")
                if plate then
                    local prompt = plate:FindFirstChild("ProximityPrompt")
                    if prompt then
                        table.insert(result, {
                            Prompt = prompt, Plate = plate, Slot = slot,
                            CookedModel = cooked,
                            FoodName = cooked.Name:match("^Cooked_(.+)$") or cooked.Name,
                        })
                    end
                end
            end
        end
    end
    return result
end

local function FindAllEnabledServePrompts()
    local plot = GetKarenderya()
    if not plot then return {} end
    local result = {}
    for _, obj in ipairs(plot:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled
           and obj:GetAttribute("TableAction") == "Serve" then
            local parentPart = obj.Parent
            if parentPart and parentPart:IsA("BasePart") then
                table.insert(result, { Prompt = obj, Part = parentPart })
            end
        end
    end
    return result
end

-- TASK RUNNERS
local function RunTask_Assign(budget)
    if not HasOwnPlot() or not AssignNPC then return end
    local deadline = os.clock() + budget
    while os.clock() < deadline do
        local npc = FindQueuedCustomer()
        if not npc then break end
        local seat = FindFreeSeat()
        if not seat then break end
        pcall(function()
            AssignNPC:FireServer({
                NpcId = npc.Name, Seat = seat.Seat,
                NPCName = npc.Name, Slot = seat.Table,
            })
        end)
        AssignedCount += 1
        task.wait(0.5)
    end
end

local function RunTask_Serve(budget)
    if not HasOwnPlot() then return end
    local deadline = os.clock() + budget
    BurstCycleCount += 1

    -- 🔥 Ensure noclip is on if the toggle says so
    if NoclipPathfindingEnabled and not NoclipActive then
        EnableNoclip()
    end

    local cookedFoods = FindAllCookedFood()
    for _, food in ipairs(cookedFoods) do
        if os.clock() >= deadline then break end
        local platePart = GetPartFromObject(food.Plate)
        if platePart then
            task.wait(PRE_TP_DELAY)
            MoveTo(platePart.Position, 1)
            task.wait(POST_TP_SETTLE)
            FirePrompt(food.Prompt)
            task.wait(POST_FIRE_WAIT)
        end
    end

    if os.clock() >= deadline then return end
    if #GetHeldFoodItems() == 0 then task.wait(0.3); return end

    local prompts = FindAllEnabledServePrompts()
    if #prompts == 0 then task.wait(0.3); return end

    for _, entry in ipairs(prompts) do
        if os.clock() >= deadline then break end
        if #GetHeldFoodItems() == 0 then break end

        task.wait(PRE_TP_DELAY)
        MoveTo(entry.Part.Position, 1)
        task.wait(POST_TP_SETTLE)
        FirePrompt(entry.Prompt)
        ServedCount += 1
        task.wait(POST_FIRE_WAIT)
    end

    task.wait(0.3)
end

local function RunTask_Wash(budget)
    if not HasOwnPlot() then return end
    local sink = GetSink()
    if not sink then return end
    local promptPart = sink:FindFirstChild("PromptPart")
    local washPrompt = promptPart and promptPart:FindFirstChild("Wash")
    if not washPrompt then return end

    local dishCount = CountDirtyDishes()
    if dishCount < WashThreshold then return end

    StopESpam()

    if PropEquipEvent then
        pcall(function() PropEquipEvent:FireServer("Sponge", true) end)
        task.wait(0.2)
    end

    local base = GetPartFromObject(promptPart) or GetPartFromObject(sink)
    if base then MoveTo(base.Position, 1); task.wait(0.3) end

    local holdTime = washPrompt.HoldDuration
    if holdTime <= 0 then holdTime = WashHoldTime end

    local deadline = os.clock() + math.max(budget, holdTime + 2)
    local washed = 0
    while os.clock() < deadline do
        if not washPrompt.Enabled then break end
        if CountDirtyDishes() == 0 then break end
        HoldE(holdTime)
        washed += 1
        task.wait(0.5)
        if washed > 30 then break end
    end
    WashedCount += washed
end

local function RunTask_Restock(budget)
    if not HasOwnPlot() then return end
    local fridge = GetFridge()
    if not fridge then return end
    local inv = fridge:FindFirstChild("Inventory")
    local inv2 = inv and inv:FindFirstChild("Inventory")
    local prompt = inv2 and inv2:FindFirstChild("ProximityPrompt")
    if not prompt then return end

    local part = GetPartFromObject(inv2)
    if part then MoveTo(part.Position, 1); task.wait(0.3) end

    local deadline = os.clock() + budget
    local restocked = 0
    while os.clock() < deadline do
        if not prompt.Enabled then break end
        FirePrompt(prompt)
        restocked += 1
        task.wait(0.3)
        if restocked > 20 then break end
    end
    RestockedCount += restocked
end

task.spawn(function() while true do task.wait(1.5); if AutoAssignEnabled then pcall(RunTask_Assign, 1.5) end end end)
task.spawn(function() while true do task.wait(1.0); if AutoServeEnabled then pcall(RunTask_Serve, 8.0) end end end)
task.spawn(function() while true do task.wait(2); if AutoWashEnabled then pcall(RunTask_Wash, 35.0) end end end)
task.spawn(function() while true do task.wait(5); if AutoRestockEnabled then pcall(RunTask_Restock, 3.0) end end end)

-- AUTO STEAL
local function EquipPan()
    if not AutoEquipPanEnabled or not PropEquipEvent then return end
    pcall(function() PropEquipEvent:FireServer("Pan", true) end)
end

if CustomerRanAwayEvent then
    CustomerRanAwayEvent.OnClientEvent:Connect(function(displayName, npcModelName)
        if not AutoStealEnabled or not npcModelName then return end
        if RecentlyHit[npcModelName] and (os.time() - RecentlyHit[npcModelName] < 3) then return end
        RecentlyHit[npcModelName] = os.time()
        task.spawn(function()
            pcall(function()
                local npcs = Workspace:FindFirstChild("ClientNPCs")
                local npc = (npcs and npcs:FindFirstChild(npcModelName)) or Workspace:FindFirstChild(npcModelName)
                if not npc then return end
                local npcPart = GetPartFromObject(npc)
                local hrp = GetHRP()
                if npcPart and hrp then hrp.CFrame = npcPart.CFrame + Vector3.new(0, 2, 0); task.wait(0.15) end
                EquipPan()
                task.wait(0.1)
                if HitRunawayEvent then
                    HitRunawayEvent:FireServer(npcModelName, "melee", "Pan")
                    StolenCount += 1
                end
            end)
        end)
    end)
end

task.spawn(function()
    while true do
        task.wait(30)
        for name, t in pairs(RecentlyHit) do
            if os.time() - t > 60 then RecentlyHit[name] = nil end
        end
    end
end)

if StoveCookingStarted then
    StoveCookingStarted.OnClientEvent:Connect(function(stoveName, foodName, cookTime)
        ActiveStoves[stoveName] = { food = foodName, started = os.time(), duration = cookTime or 5 }
    end)
end
if StoveCookingFinished then
    StoveCookingFinished.OnClientEvent:Connect(function(stoveName)
        ActiveStoves[stoveName] = nil
    end)
end

-- WINDOW
local Window = Rayfield:CreateWindow({
    name = "KissoHub",
    subtitle = "Karinderya",
    sidebarLayout = true,
    icon = ASSET_ICON,
    theme = "cobalt",
    configuration = {
        autoSave = true, autoLoad = true,
        fileName = "KarinderyaPrefs", customFolder = "KissoHubFolder",
    },
})

local StatusTag = Window:CreateTag({ text = HUB_VERSION, color = Color3.fromRGB(0, 200, 255) })
local StateTag  = Window:CreateTag({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })

local function SafeNotify(t, c, d)
    pcall(function() Window:Notify({ title = t or "KissoHub", content = c or "", duration = d or 4, icon = ASSET_ICON }) end)
end
local function QuickToast(t, s)
    pcall(function() Window:Toast({ title = t, subtitle = s, position = "Top", icon = ASSET_ICON }) end)
end

local HomeTab     = Window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })
local KitchenTab  = Window:CreateTab({ name = "🍳 Auto Kitchen" })
local CustomerTab = Window:CreateTab({ name = "👥 Auto Customers" })
local StealTab    = Window:CreateTab({ name = "🥷 Auto Steal" })
local MiscTab     = Window:CreateTab({ name = "🛠️ Misc" })
local InfoTab     = Window:CreateTab({ name = "ℹ️ Info" })

-- HOME
HomeTab:CreateSection({ name = "📊 Stats" })
local StatsGrid = HomeTab:CreateGroup()
local StatsL = StatsGrid:CreateGroup({ direction = "column" })
local StatsR = StatsGrid:CreateGroup({ direction = "column" })

local CashStat        = StatsL:CreateStat({ name = "💵 Cash", prefix = "₱", value = 0, compact = true })
local HeartStat       = StatsL:CreateStat({ name = "❤️ Heart", value = 0, compact = true })
local ServedTotalStat = StatsL:CreateStat({ name = "🍽️ Total Served", value = 0, compact = true })
local FriendBoostStat = StatsR:CreateStat({ name = "👥 Friend Boost", value = 0, compact = true })
local CpsStat         = StatsR:CreateStat({ name = "📈 ₱/s", prefix = "₱", value = 0, compact = true })
local SessionStat     = StatsR:CreateStat({ name = "⏱️ Session", value = 0, suffix = " m", compact = true })

HomeTab:CreateDivider({ spacing = 14 })
HomeTab:CreateSection({ name = "⚡ System Status" })
local SysGrid = HomeTab:CreateGroup()
local SysL = SysGrid:CreateGroup({ direction = "column" })
local SysR = SysGrid:CreateGroup({ direction = "column" })

local FeaturesStat = SysL:CreateStat({ name = "⚙️ Features", value = 0, compact = true })
local FpsStat      = SysL:CreateStat({ name = "🎮 FPS", value = 0, compact = true })
local PingStat     = SysL:CreateStat({ name = "📡 Ping", value = 0, suffix = " ms", compact = true })
local PlayersStat  = SysR:CreateStat({ name = "👥 Players", value = 1, compact = true })
local StovesStat   = SysR:CreateStat({ name = "🔥 Cooking", value = 0, compact = true })
local YourPlotStat = SysR:CreateStat({ name = "🏠 Your Plot", value = 0, compact = true })

HomeTab:CreateDivider({ spacing = 14 })
HomeTab:CreateSection({ name = "🎯 Session Activity" })
local ActGrid = HomeTab:CreateGroup()
local ActL = ActGrid:CreateGroup({ direction = "column" })
local ActR = ActGrid:CreateGroup({ direction = "column" })

local AssignedCountStat = ActL:CreateStat({ name = "🪑 Assigned", value = 0, compact = true })
local ServedCountStat   = ActL:CreateStat({ name = "🍽️ Served", value = 0, compact = true })
local WashedCountStat   = ActR:CreateStat({ name = "🧼 Washed", value = 0, compact = true })
local StolenCountStat   = ActR:CreateStat({ name = "🥷 Stolen", value = 0, compact = true })
local DishesStackedStat = ActR:CreateStat({ name = "🍽️ On Sink", value = 0, suffix = "/12", compact = true })

HomeTab:CreateDivider({ text = "controls" })
HomeTab:CreateSection({ name = "🌐 Server Utilities" })
HomeTab:CreateButton({ name = "📋 Copy Job ID", callback = function()
    if setclipboard then setclipboard(game.JobId); QuickToast("Copied", "Job ID copied") end
end })
HomeTab:CreateButton({ name = "🔄 Rejoin Server", callback = function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end })

-- KITCHEN
KitchenTab:CreateSection({ name = "🍽️ Serving" })
KitchenTab:CreateToggle({ name = "Auto Serve Tables", flag = "AutoServe", value = false,
    callback = function(v) AutoServeEnabled = v; QuickToast("Auto Serve", v and "ON" or "OFF") end })

KitchenTab:CreateToggle({
    name = "🚀 Noclip Pathfinding",
    flag = "NoclipPathfinding",
    value = true,
    callback = function(v)
        NoclipPathfindingEnabled = v
        if v then
            EnableNoclip()
        else
            DisableNoclip()
        end
        QuickToast("Noclip Pathfinding", v and "ON" or "OFF")
    end,
})

KitchenTab:CreateText({
    name = "Noclip Pathfinding Info",
    text = "ON — Character walks STRAIGHT through walls and obstacles to targets. Faster but less realistic.\n\n" ..
           "OFF — Character uses REAL pathfinding to route around obstacles. Slower but looks like a normal player.",
})

KitchenTab:CreateDivider({ text = "cleaning" })
KitchenTab:CreateSection({ name = "🧼 Bussing" })
KitchenTab:CreateToggle({ name = "Auto Wash Dishes", flag = "AutoWash", value = false,
    callback = function(v) AutoWashEnabled = v end })
KitchenTab:CreateSlider({ name = "Wash Threshold (dishes)",
    flag = "WashThreshold",
    range = { 1, 12 }, increment = 1, value = 12, suffix = " dishes",
    callback = function(v) WashThreshold = v end })
KitchenTab:CreateSlider({ name = "Wash Hold Time",
    flag = "WashHoldTime",
    range = { 5, 60 }, increment = 1, value = 30, suffix = " s",
    callback = function(v) WashHoldTime = v end })
KitchenTab:CreateText({ name = "Wash Info",
    text = "Wash triggers when StackedDirty reaches the threshold.\nMax 12 dishes — the sink's cap." })

KitchenTab:CreateToggle({ name = "Auto Restock Fridge", flag = "AutoRestock", value = false,
    callback = function(v) AutoRestockEnabled = v end })

-- CUSTOMERS
CustomerTab:CreateSection({ name = "👥 Counter" })
CustomerTab:CreateToggle({ name = "Auto Assign Counter", flag = "AutoAssign", value = false,
    callback = function(v) AutoAssignEnabled = v; QuickToast("Auto Assign", v and "ON" or "OFF") end })
CustomerTab:CreateDivider({ text = "status" })
CustomerTab:CreateSection({ name = "📊 Live Info" })
local CustomerCountStat = CustomerTab:CreateStat({ name = "👥 Queued", value = 0, compact = true })
local SeatedCountStat   = CustomerTab:CreateStat({ name = "🪑 Seated", value = 0, compact = true })
local EmptySeatsStat    = CustomerTab:CreateStat({ name = "🪑 Free Seats", value = 0, compact = true })
local HeldFoodStat      = CustomerTab:CreateStat({ name = "🍽️ Holding Food", value = 0, compact = true })
local ReadyToServeStat  = CustomerTab:CreateStat({ name = "🎯 Serve Ready", value = 0, compact = true })

-- STEAL
StealTab:CreateSection({ name = "🥷 Runaway Detection" })
StealTab:CreateToggle({ name = "Auto Hit Runaways", flag = "AutoSteal", value = false,
    callback = function(v) AutoStealEnabled = v end })
StealTab:CreateToggle({ name = "Auto Equip Pan", flag = "AutoEquipPan", value = true,
    callback = function(v) AutoEquipPanEnabled = v end })
StealTab:CreateDivider({ text = "manual" })
StealTab:CreateSection({ name = "🎯 Manual Actions" })
StealTab:CreateButton({ name = "🥷 Equip Pan Now", callback = function()
    EquipPan(); QuickToast("Pan", "Equipped")
end })

-- MISC
MiscTab:CreateSection({ name = "🚀 Movement" })
MiscTab:CreateSlider({ name = "Walk Speed", flag = "WalkSpeed",
    range = { 16, 200 }, increment = 1, value = 16, suffix = " studs/s",
    callback = function(v)
        WalkSpeedValue = v
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end })

task.spawn(function()
    while true do
        task.wait(0.2)
        if WalkSpeedValue ~= 16 then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed ~= WalkSpeedValue then hum.WalkSpeed = WalkSpeedValue end
        end
    end
end)

MiscTab:CreateDivider({ text = "pathfinding" })
MiscTab:CreateSection({ name = "🎯 Movement" })
MiscTab:CreateSlider({ name = "Path Waypoint Timeout", flag = "PathWpTimeout",
    range = { 0.5, 5 }, increment = 0.1, value = 2, suffix = " s",
    callback = function(v) PATH_WAYPOINT_TIMEOUT = v end })
MiscTab:CreateText({
    name = "Movement Info",
    text = "Character uses PathfindingService.\nToggle 'Noclip Pathfinding' in Kitchen tab to change behavior.",
})

MiscTab:CreateDivider({ text = "timing" })
MiscTab:CreateSection({ name = "⏱️ Timing" })
MiscTab:CreateSlider({ name = "Post-TP Settle", flag = "PostTPSettle",
    range = { 0.05, 1 }, increment = 0.05, value = 0.25, suffix = " s",
    callback = function(v) POST_TP_SETTLE = v end })
MiscTab:CreateSlider({ name = "Post-Fire Wait", flag = "PostFireWait",
    range = { 0.05, 1 }, increment = 0.05, value = 0.3, suffix = " s",
    callback = function(v) POST_FIRE_WAIT = v end })

MiscTab:CreateDivider({ text = "e-spam" })
MiscTab:CreateSection({ name = "🎯 E-Spam (Serve Only)" })
MiscTab:CreateToggle({ name = "🎯 Enable E-Spam", flag = "ESpamEnabled", value = true,
    callback = function(v)
        ESpamEnabled = v
        if not v then StopESpam() end
        QuickToast("E-Spam", v and "ON" or "OFF")
    end })
MiscTab:CreateSlider({ name = "E-Spam Speed", flag = "ESpamSpeed",
    range = { 0.05, 0.5 }, increment = 0.01, value = 0.08, suffix = " s",
    callback = function(v) ESpamSpeed = v end })

MiscTab:CreateDivider({ text = "task settings" })
MiscTab:CreateSection({ name = "🛡️ Task Settings" })
MiscTab:CreateSlider({ name = "TP Height Offset", flag = "HeightOffset",
    range = { 0, 6 }, increment = 0.5, value = 2, suffix = " studs",
    callback = function(v) HeightOffset = v end })

MiscTab:CreateDivider({ text = "teleports" })
MiscTab:CreateSection({ name = "📍 Fast Teleports" })

local function MakeTPButton(label, getter, yOffset)
    MiscTab:CreateButton({
        name = label,
        callback = function()
            local obj = getter()
            local part = GetPartFromObject(obj)
            if part then MoveTo(part.Position, yOffset or 4); QuickToast("Teleported", label)
            else SafeNotify("TP Failed", label .. " not found", 3) end
        end,
    })
end

MakeTPButton("🍳 TP Kitchen", GetKitchen, 4)
MakeTPButton("🧊 TP Fridge", GetFridge, 4)
MakeTPButton("🧼 TP Sink", GetSink, 4)
MakeTPButton("🍽️ TP Serve Counter", GetServeFolder, 4)
MakeTPButton("🪑 TP Dining Area", GetDiningPlot, 4)
MakeTPButton("🥷 TP Steal Spot 1", function()
    local s = GetStealFolder(); return s and s:FindFirstChild("1")
end, 3)
MakeTPButton("🥷 TP Steal Spot 2", function()
    local s = GetStealFolder(); return s and s:FindFirstChild("2")
end, 3)

MiscTab:CreateDivider({ text = "preferences" })
MiscTab:CreateSection({ name = "⚙️ Player Options" })
MiscTab:CreateToggle({ name = "Infinite Zoom", flag = "InfZoom", value = false,
    callback = function(v)
        InfZoomEnabled = v
        LocalPlayer.CameraMaxZoomDistance = v and 100000 or 128
    end })
MiscTab:CreateToggle({ name = "Anti-AFK", flag = "AntiAFK", value = false,
    callback = function(v)
        AntiAFKEnabled = v
        if v then
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
    end })
MiscTab:CreateToggle({ name = "Fast Mode (FPS Booster)", flag = "FastMode", value = false,
    callback = function(v)
        FastModeEnabled = v
        if v then
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            for _, x in ipairs(game:GetDescendants()) do
                if x:IsA("ParticleEmitter") or x:IsA("Smoke") or x:IsA("Fire") or x:IsA("Sparkles") or x:IsA("PostEffect") then
                    x.Enabled = false
                end
            end
            QuickToast("FPS Boost", "Graphics optimized")
        else
            Lighting.GlobalShadows = OriginalLightingSettings.GlobalShadows
            Lighting.FogEnd = OriginalLightingSettings.FogEnd
            QuickToast("Graphics Restored", "Restored")
        end
    end })

-- INFO
InfoTab:CreateSection({ name = "ℹ️ About" })
InfoTab:CreateText({
    name = "KissoHub — Karinderya",
    text = "Version: " .. HUB_VERSION .. "\n" ..
           "Genre: Simulation / Tycoon\n" ..
           "Max Server: 6 players\n" ..
           "Config: KissoHubFolder/KarinderyaPrefs.rfld",
})

InfoTab:CreateDivider({ text = "changelog" })
InfoTab:CreateSection({ name = "📋 Changelog" })
InfoTab:CreateText({
    name = HUB_VERSION .. " — Latest",
    text = "• Noclip now DIRECTLY tied to Noclip Pathfinding toggle\n" ..
           "• Removed auto-disable timeout (noclip persists)\n" ..
           "• Toggle ON → noclip enabled immediately\n" ..
           "• Toggle OFF → noclip disabled immediately\n" ..
           "• Fixes character getting stuck on tables",
})

InfoTab:CreateText({
    name = "v1.5.7",
    text = "• Noclip Pathfinding toggle added",
})

-- LIVE REFRESH
task.spawn(function()
    PreviousCash = GetStat("Cash")
    LastCashCheckTime = os.clock()

    while task.wait(0.5) do
        pcall(function()
            local elapsedMinutes = math.floor((os.time() - SessionStartTime) / 60)
            local activeFeatures = (AutoServeEnabled and 1 or 0)
                + (AutoWashEnabled and 1 or 0)
                + (AutoRestockEnabled and 1 or 0)
                + (AutoAssignEnabled and 1 or 0)
                + (AutoStealEnabled and 1 or 0)
                + (AutoEquipPanEnabled and 1 or 0)
                + (InfZoomEnabled and 1 or 0)
                + (FastModeEnabled and 1 or 0)
                + (AntiAFKEnabled and 1 or 0)
                + (ESpamActive and 1 or 0)
                + (NoclipPathfindingEnabled and 1 or 0)

            local currentCash = GetStat("Cash")
            local now = os.clock()
            local timeDiff = now - LastCashCheckTime
            if timeDiff >= 1 then
                CashPerSecond = math.max(0, math.floor((currentCash - PreviousCash) / timeDiff))
                PreviousCash = currentCash
                LastCashCheckTime = now
            end

            CashStat:Set(currentCash)
            HeartStat:Set(GetStat("Heart"))
            ServedTotalStat:Set(GetStat("TotalServed"))
            FriendBoostStat:Set(GetFriendBoost())
            CpsStat:Set(CashPerSecond)
            SessionStat:Set(elapsedMinutes)

            FeaturesStat:Set(activeFeatures)
            FpsStat:Set(math.floor(Workspace:GetRealPhysicsFPS() or 60))
            PingStat:Set(GetPing())
            PlayersStat:Set(#Players:GetPlayers())
            local stoveCount = 0
            for _ in pairs(ActiveStoves) do stoveCount += 1 end
            StovesStat:Set(stoveCount)
            YourPlotStat:Set(GetKarenderya() and 1 or 0)

            AssignedCountStat:Set(AssignedCount)
            ServedCountStat:Set(ServedCount)
            WashedCountStat:Set(WashedCount)
            StolenCountStat:Set(StolenCount)
            DishesStackedStat:Set(CountDirtyDishes())

            local waiting = 0
            local npcs = Workspace:FindFirstChild("ClientNPCs")
            if npcs then
                for _, npc in ipairs(npcs:GetChildren()) do
                    if IsCustomer(npc) and not IsNpcSeated(npc.Name) then waiting += 1 end
                end
            end
            CustomerCountStat:Set(waiting)

            local seatedCount, emptySeats = 0, 0
            for _, entry in ipairs(GetSortedTables()) do
                local t = entry.model
                if t:GetAttribute("OccupiedBy1") then seatedCount += 1 else emptySeats += 1 end
                if t:GetAttribute("OccupiedBy2") then seatedCount += 1 else emptySeats += 1 end
            end
            SeatedCountStat:Set(seatedCount)
            EmptySeatsStat:Set(emptySeats)
            HeldFoodStat:Set(#GetHeldFoodItems())
            ReadyToServeStat:Set(#FindAllEnabledServePrompts())

            if ESpamActive then
                StateTag:Set({ text = "SPAMMING", color = Color3.fromRGB(255, 200, 40) })
            elseif activeFeatures > 0 then
                StateTag:Set({ text = "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
            else
                StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
            end
        end)
    end
end)

-- 🔥 Enable noclip on startup since Noclip Pathfinding defaults to ON
if NoclipPathfindingEnabled then
    EnableNoclip()
end

SafeNotify("KissoHub", "Karinderya " .. HUB_VERSION .. " loaded", 3)
