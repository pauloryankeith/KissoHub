-- ═══════════════════════════════════════════════════════════════
--   KissoHub — Karinderya Module  |  v1.2.0
--   Author: pauloryankeith
--   Official: github.com/pauloryankeith/KissoHub
--   Unauthorized copies are not endorsed or supported.
-- ═══════════════════════════════════════════════════════════════
local HttpService = game:GetService("HttpService")
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

-- =================================================================
-- SERVICES
-- =================================================================
local Players             = game:GetService("Players")
local Workspace           = game:GetService("Workspace")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local StatsService        = game:GetService("Stats")
local TeleportService     = game:GetService("TeleportService")
local Lighting            = game:GetService("Lighting")
local VirtualUser         = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer         = Players.LocalPlayer

local ASSET_ICON  = "rbxassetid://89387722763691"
local HUB_VERSION = "v1.2.0"

-- =================================================================
-- REMOTES
-- =================================================================
local Remotes              = ReplicatedStorage:WaitForChild("Remotes", 10)
local CounterRemotes       = Remotes and Remotes:WaitForChild("CounterRemotes", 5)
local KitchenRemotes       = Remotes and Remotes:WaitForChild("KitchenRemotes", 5)
local PropEquipEvent       = Remotes and Remotes:WaitForChild("PropEquipEvent")
local HitRunawayEvent      = Remotes and Remotes:WaitForChild("HitRunawayEvent")
local CustomerRanAwayEvent = Remotes and Remotes:WaitForChild("CustomerRanAwayEvent")

local AssignNPC            = CounterRemotes and CounterRemotes:WaitForChild("AssignNPC")
local StoveCookingStarted  = KitchenRemotes and KitchenRemotes:WaitForChild("StoveCookingStarted")
local StoveCookingFinished = KitchenRemotes and KitchenRemotes:WaitForChild("StoveCookingFinished")

-- =================================================================
-- TASK TYPES
-- =================================================================
local TASK_IDLE    = "Idle"
local TASK_ASSIGN  = "Auto Assign"
local TASK_SERVE   = "Auto Serve"
local TASK_WASH    = "Auto Wash"
local TASK_RESTOCK = "Auto Restock"
local TASK_STEAL   = "Auto Hit Runaways"

local TASK_LIST = { TASK_IDLE, TASK_ASSIGN, TASK_SERVE, TASK_WASH, TASK_RESTOCK, TASK_STEAL }

-- =================================================================
-- STATE
-- =================================================================
local QueueEnabled = false
local QueuePaused  = false
local QueueSlots   = {}
for i = 1, 10 do QueueSlots[i] = { task = TASK_IDLE, wait = 3 } end
QueueSlots[1] = { task = TASK_ASSIGN,  wait = 3 }
QueueSlots[2] = { task = TASK_SERVE,   wait = 5 }
QueueSlots[3] = { task = TASK_WASH,    wait = 2 }
QueueSlots[4] = { task = TASK_RESTOCK, wait = 2 }
QueueSlots[5] = { task = TASK_STEAL,   wait = 1 }

local AutoServeEnabled    = false
local AutoWashEnabled     = false
local AutoRestockEnabled  = false
local AutoAssignEnabled   = false
local AutoStealEnabled    = false
local AutoEquipPanEnabled = true
local InfZoomEnabled      = false
local FastModeEnabled     = false
local AntiAFKEnabled      = false
local WalkSpeedValue      = 16
local UseEKeyFallback     = true
local FastPickupEnabled   = false
local DishVerifyEnabled   = true   -- 🔍 Verify dish matches before serving

local StolenCount      = 0
local ServedCount      = 0
local WashedCount      = 0
local RestockedCount   = 0
local AssignedCount    = 0
local SkippedCount     = 0

local ActiveStoves = {}
local RecentlyHit  = {}
local ServeCooldowns = {}

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

-- =================================================================
-- HELPERS: Player Stats
-- =================================================================
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

-- =================================================================
-- HELPERS: World Discovery
-- =================================================================
local CachedKarenderya = nil
local LastKarenderyaCheck = 0

local function ReadPlotOwner(k)
    local sign = k:FindFirstChild("Sign")
    if not sign then return nil end
    local signage = sign:FindFirstChild("Signage")
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
            local ownerText = ReadPlotOwner(obj)
            if ownerText == MY_USERNAME then
                CachedKarenderya = obj
                return obj
            end
        end
    end

    CachedKarenderya = nil
    return nil
end

local function HasOwnPlot()
    return GetKarenderya() ~= nil
end

local function GetKitchen() local k = GetKarenderya(); return k and k:FindFirstChild("KitchenPlot1") end
local function GetSink()
    local k = GetKarenderya(); if not k then return nil end
    local s = k:FindFirstChild("Sink")
    return s and s:FindFirstChild("Sink")
end
local function GetFridge() local k = GetKarenderya(); return k and k:FindFirstChild("Fridge") end
local function GetServeFolder() local k = GetKarenderya(); return k and k:FindFirstChild("Serve") end
local function GetDiningPlot() local k = GetKarenderya(); return k and k:FindFirstChild("DiningPlot1") end
local function GetStealFolder() local k = GetKarenderya(); return k and k:FindFirstChild("Steal") end

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

local function TeleportToPosition(pos)
    local hrp = GetHRP()
    if hrp and pos then hrp.CFrame = CFrame.new(pos) end
end

-- =================================================================
-- HELPERS: Interaction
-- =================================================================
local function FirePrompt(prompt, useEFallback)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.05)
            prompt:InputHoldEnd()
        end
    end)
    if useEFallback ~= false and UseEKeyFallback then
        pcall(function()
            VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
    end
    return true
end

-- 🎯 Fire only "Serve" action prompts within a radius
local function FireServePromptsInRange(position, radius)
    radius = radius or 5
    local fired = 0
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local action = obj:GetAttribute("TableAction")
            if action == "Serve" and obj:GetAttribute("ReservedForServer") ~= true then
                local parent = obj.Parent
                local parentPart = parent and (parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart", true))
                if parentPart then
                    local dist = (parentPart.Position - position).Magnitude
                    if dist <= radius then
                        pcall(function()
                            if fireproximityprompt then
                                fireproximityprompt(obj)
                            else
                                obj:InputHoldBegin()
                                task.wait(obj.HoldDuration + 0.02)
                                obj:InputHoldEnd()
                            end
                        end)
                        fired += 1
                    end
                end
            end
        end
    end
    return fired
end

-- =================================================================
-- HELPERS: Customers & Seats
-- =================================================================
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

    local closestNpc = nil
    local closestDist = 15

    for _, npc in ipairs(npcFolder:GetChildren()) do
        if npc:IsA("Model") then
            local hrp = npc:FindFirstChild("HumanoidRootPart")
            local hum = npc:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local d = (hrp.Position - frontPos).Magnitude
                if d < closestDist then
                    closestNpc = npc
                    closestDist = d
                end
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
        if num then
            table.insert(result, { model = child, num = num })
        end
    end
    table.sort(result, function(a, b) return a.num < b.num end)
    return result
end

local function FindFreeSeat()
    for _, entry in ipairs(GetSortedTables()) do
        local tableModel = entry.model
        if not tableModel:GetAttribute("OccupiedBy1") then
            return { Table = tableModel, Seat = 1 }
        end
        if not tableModel:GetAttribute("OccupiedBy2") then
            return { Table = tableModel, Seat = 2 }
        end
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

-- =================================================================
-- AUTO SERVE HELPERS
-- =================================================================

-- 🎯 Find held food items in workspace.<YourName>.*
local function GetHeldFoodItems()
    local playerFolder = Workspace:FindFirstChild(MY_USERNAME)
    if not playerFolder then return {} end

    local items = {}
    for _, child in ipairs(playerFolder:GetChildren()) do
        local isFood = child.Name:match("^Lugaw") or child.Name:match("Food$")
        if isFood then
            local targetNpcValue = child:FindFirstChild("TargetNPCId")
            local targetNpcId = nil
            if targetNpcValue and targetNpcValue:IsA("StringValue") then
                targetNpcId = targetNpcValue.Value
            elseif targetNpcValue and targetNpcValue:IsA("ObjectValue") then
                targetNpcId = targetNpcValue.Value and targetNpcValue.Value.Name
            end

            table.insert(items, {
                Name = child.Name,
                Tool = child,
                TargetNPCId = targetNpcId,
            })
        end
    end
    return items
end

-- 🎯 Find ALL cooked food on Serve counter
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
                            Prompt = prompt,
                            Plate = plate,
                            Slot = slot,
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

-- 🎯 Find the table a specific NPC is seated at
local function FindTableForNPC(npcName)
    for _, entry in ipairs(GetSortedTables()) do
        local t = entry.model
        local o1 = t:GetAttribute("OccupiedBy1")
        local o2 = t:GetAttribute("OccupiedBy2")
        if o1 == npcName then return t, 1 end
        if o2 == npcName then return t, 2 end
    end
    return nil, nil
end

-- 🎯 Find the exact Serve prompt on a table + seat
local function FindServePrompt(tableModel, seatNum)
    if not tableModel or not seatNum then return nil end
    local currentTable = tableModel:FindFirstChild("CurrentTable")
    if not currentTable then return nil end
    local woodPlank = currentTable:FindFirstChild("WoodPlank")
    if not woodPlank then return nil end
    local serveSeat = woodPlank:FindFirstChild("Serve" .. tostring(seatNum))
    if not serveSeat then return nil end
    return serveSeat:FindFirstChild("ProximityPrompt")
end

-- 🔍 Verify the prompt's action text matches the dish we're carrying
local function DishMatchesPrompt(prompt, foodName)
    if not prompt then return false end
    if not DishVerifyEnabled then return true end  -- bypass check
    local actionText = prompt.ActionText
    if not actionText or actionText == "" then return true end  -- no data, allow
    return actionText:find(foodName, 1, true) ~= nil
end

-- =================================================================
-- TASK RUNNERS
-- =================================================================

-- AUTO ASSIGN
local function RunTask_Assign(budget)
    if not HasOwnPlot() then return end
    if not AssignNPC then return end

    local deadline = os.clock() + budget
    while os.clock() < deadline and not QueuePaused do
        local npc = FindQueuedCustomer()
        if not npc then break end

        local seat = FindFreeSeat()
        if not seat then break end

        pcall(function()
            AssignNPC:FireServer({
                NpcId   = npc.Name,
                Seat    = seat.Seat,
                NPCName = npc.Name,
                Slot    = seat.Table,
            })
        end)
        AssignedCount += 1
        task.wait(0.5)
    end
end

-- AUTO SERVE — TargetNPCId + Serve prompt
local function RunTask_Serve(budget)
    if not HasOwnPlot() then return end
    local deadline = os.clock() + budget

    local tpSettle     = FastPickupEnabled and 0.1 or 0.2
    local afterPickup  = FastPickupEnabled and 0.15 or 0.3
    local afterDeliver = FastPickupEnabled and 0.12 or 0.25

    -- ============================================================
    -- PHASE 1: PICK UP ALL FOOD FROM SERVE COUNTER
    -- ============================================================
    local cookedFoods = FindAllCookedFood()
    if #cookedFoods > 0 then
        for _, food in ipairs(cookedFoods) do
            if os.clock() >= deadline then break end

            local slotPart = GetPartFromObject(food.Slot) or GetPartFromObject(food.Plate)
            if slotPart then
                TeleportToPosition(slotPart.Position + Vector3.new(0, 3, 0))
                task.wait(tpSettle)

                if FastPickupEnabled then
                    FireServePromptsInRange(slotPart.Position, 4)
                else
                    FirePrompt(food.Prompt, false)
                end
                task.wait(afterPickup)
            end
        end
    end

    -- ============================================================
    -- PHASE 2: DELIVER EACH HELD FOOD TO ITS TARGET NPC
    -- ============================================================
    if os.clock() >= deadline then return end

    local heldFoods = GetHeldFoodItems()
    if #heldFoods == 0 then return end

    local npcFolder = Workspace:FindFirstChild("ClientNPCs")

    for _, food in ipairs(heldFoods) do
        if os.clock() >= deadline then break end
        if not food.TargetNPCId or not npcFolder then continue end

        local targetNpc = npcFolder:FindFirstChild(food.TargetNPCId)
        if not targetNpc then continue end

        local targetTable, seatNum = FindTableForNPC(food.TargetNPCId)

        -- Preferred: use the exact Serve prompt on their table
        local prompt = targetTable and FindServePrompt(targetTable, seatNum)

        if prompt and prompt.Enabled and DishMatchesPrompt(prompt, food.Name) then
            local tablePart = GetPartFromObject(targetTable)
            if tablePart then
                TeleportToPosition(tablePart.Position + Vector3.new(0, 4, 0))
                task.wait(tpSettle)

                pcall(function()
                    if fireproximityprompt then
                        fireproximityprompt(prompt)
                    else
                        prompt:InputHoldBegin()
                        task.wait(prompt.HoldDuration + 0.02)
                        prompt:InputHoldEnd()
                    end
                end)
                ServedCount += 1
            end
        else
            -- Fallback: TP to NPC + fire any Serve prompts in range
            local npcPart = GetPartFromObject(targetNpc)
            if npcPart then
                local hrp = GetHRP()
                if hrp then
                    hrp.CFrame = npcPart.CFrame
                    task.wait(tpSettle)
                end
                local fired = FireServePromptsInRange(npcPart.Position, 5)
                if fired > 0 then
                    ServedCount += 1
                else
                    SkippedCount += 1
                end
            end
        end

        ServeCooldowns[food.TargetNPCId] = os.time()
        task.wait(afterDeliver)
    end
end

-- AUTO WASH
local function RunTask_Wash(budget)
    if not HasOwnPlot() then return end
    local sink = GetSink()
    if not sink then return end
    local promptPart = sink:FindFirstChild("PromptPart")
    local washPrompt = promptPart and promptPart:FindFirstChild("Wash")
    if not washPrompt then return end

    if PropEquipEvent then pcall(function() PropEquipEvent:FireServer("Sponge", true) end) end

    local part = GetPartFromObject(sink)
    if part then
        TeleportToPosition(part.Position + Vector3.new(0, 3, 0))
        task.wait(0.2)
    end

    if FirePrompt(washPrompt) then WashedCount += 1 end
    task.wait(math.min(budget, 2))
end

-- AUTO RESTOCK
local function RunTask_Restock(budget)
    if not HasOwnPlot() then return end
    local fridge = GetFridge()
    if not fridge then return end
    local inv = fridge:FindFirstChild("Inventory")
    local inv2 = inv and inv:FindFirstChild("Inventory")
    local prompt = inv2 and inv2:FindFirstChild("ProximityPrompt")
    if not prompt then return end

    local part = GetPartFromObject(inv2)
    if part then
        TeleportToPosition(part.Position + Vector3.new(0, 3, 0))
        task.wait(0.2)
    end

    if FirePrompt(prompt) then RestockedCount += 1 end
    task.wait(math.min(budget, 2))
end

-- AUTO STEAL
local function RunTask_Steal(budget)
    task.wait(math.min(budget, 1))
end

-- =================================================================
-- PRIORITY QUEUE SCHEDULER
-- =================================================================
local TaskRunners = {
    [TASK_ASSIGN]  = RunTask_Assign,
    [TASK_SERVE]   = RunTask_Serve,
    [TASK_WASH]    = RunTask_Wash,
    [TASK_RESTOCK] = RunTask_Restock,
    [TASK_STEAL]   = RunTask_Steal,
}

task.spawn(function()
    while true do
        task.wait(0.3)
        if not QueueEnabled or QueuePaused then continue end

        for i = 1, 10 do
            if not QueueEnabled or QueuePaused then break end
            local slot = QueueSlots[i]
            if slot.task ~= TASK_IDLE then
                local runner = TaskRunners[slot.task]
                if runner then pcall(runner, slot.wait) end
                task.wait(0.2)
            end
        end
    end
end)

-- =================================================================
-- STANDALONE LOOPS
-- =================================================================
local function ShouldRunStandalone()
    return not QueueEnabled
end

task.spawn(function()
    while true do
        task.wait(1.5)
        if ShouldRunStandalone() and AutoAssignEnabled then pcall(RunTask_Assign, 1.0) end
    end
end)

task.spawn(function()
    while true do
        task.wait(1.5)
        if ShouldRunStandalone() and AutoServeEnabled then pcall(RunTask_Serve, 2.5) end
    end
end)

task.spawn(function()
    while true do
        task.wait(3)
        if ShouldRunStandalone() and AutoWashEnabled then pcall(RunTask_Wash, 2.0) end
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        if ShouldRunStandalone() and AutoRestockEnabled then pcall(RunTask_Restock, 2.0) end
    end
end)

-- =================================================================
-- AUTO STEAL (event-driven)
-- =================================================================
local function EquipPan()
    if not AutoEquipPanEnabled or not PropEquipEvent then return end
    pcall(function() PropEquipEvent:FireServer("Pan", true) end)
end

if CustomerRanAwayEvent then
    CustomerRanAwayEvent.OnClientEvent:Connect(function(displayName, npcModelName)
        local queueHasSteal = false
        for _, s in ipairs(QueueSlots) do
            if s.task == TASK_STEAL then queueHasSteal = true; break end
        end
        if not (AutoStealEnabled or (QueueEnabled and queueHasSteal)) then return end
        if not npcModelName then return end
        if RecentlyHit[npcModelName] and (os.time() - RecentlyHit[npcModelName] < 3) then return end
        RecentlyHit[npcModelName] = os.time()

        task.spawn(function()
            pcall(function()
                local npcs = Workspace:FindFirstChild("ClientNPCs")
                local npc = (npcs and npcs:FindFirstChild(npcModelName)) or Workspace:FindFirstChild(npcModelName)
                if not npc then return end

                local npcPart = GetPartFromObject(npc)
                local hrp = GetHRP()
                if npcPart and hrp then
                    hrp.CFrame = npcPart.CFrame + Vector3.new(0, 2, 0)
                    task.wait(0.15)
                end

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

-- =================================================================
-- KITCHEN TRACKING
-- =================================================================
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

-- =================================================================
-- WINDOW
-- =================================================================
local Window = Rayfield:CreateWindow({
    name = "KissoHub",
    subtitle = "Karinderya",
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
        fileName = "KarinderyaPrefs", customFolder = "KissoHubFolder",
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
-- TABS
-- =================================================================
local HomeTab     = Window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })
local PrioTab     = Window:CreateTab({ name = "⚡ Priority Queue" })
local KitchenTab  = Window:CreateTab({ name = "🍳 Auto Kitchen" })
local CustomerTab = Window:CreateTab({ name = "👥 Auto Customers" })
local StealTab    = Window:CreateTab({ name = "🥷 Auto Steal" })
local MiscTab     = Window:CreateTab({ name = "🛠️ Misc" })
local InfoTab     = Window:CreateTab({ name = "ℹ️ Info" })

-- =================================================================
-- HOME TAB
-- =================================================================
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
local SkippedCountStat  = ActR:CreateStat({ name = "⚠️ Skipped", value = 0, compact = true })

HomeTab:CreateDivider({ text = "controls" })
HomeTab:CreateSection({ name = "🌐 Server Utilities" })
HomeTab:CreateButton({ name = "📋 Copy Job ID", callback = function()
    if setclipboard then setclipboard(game.JobId); QuickToast("Copied", "Job ID copied") end
end })
HomeTab:CreateButton({ name = "🔄 Rejoin Server", callback = function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
end })

-- =================================================================
-- PRIORITY QUEUE TAB
-- =================================================================
PrioTab:CreateSection({ name = "⚡ Queue Controls" })
PrioTab:CreateToggle({
    name = "Enable Priority Queue", flag = "QueueEnabled", value = false,
    callback = function(Value)
        QueueEnabled = Value
        QuickToast("Queue", Value and "Enabled" or "Disabled")
    end,
})
PrioTab:CreateToggle({
    name = "Pause Queue", flag = "QueuePaused", value = false,
    callback = function(Value) QueuePaused = Value end,
})

PrioTab:CreateDivider({ text = "priority slots" })
PrioTab:CreateSection({ name = "📋 Priority Order" })
for i = 1, 10 do
    PrioTab:CreateDropdown({
        name = "Priority " .. i .. " Task",
        flag = "Prio_" .. i .. "_Task",
        options = TASK_LIST,
        value = { QueueSlots[i].task },
        multiSelect = false,
        callback = function(Option)
            QueueSlots[i].task = typeof(Option) == "table" and Option[1] or Option
        end,
    })
    PrioTab:CreateSlider({
        name = "Priority " .. i .. " Wait",
        flag = "Prio_" .. i .. "_Wait",
        range = { 1, 30 }, increment = 0.5, value = QueueSlots[i].wait, suffix = " s",
        callback = function(Value) QueueSlots[i].wait = Value end,
    })
    if i < 10 then PrioTab:CreateDivider({ line = false, spacing = 6 }) end
end

-- =================================================================
-- AUTO KITCHEN TAB
-- =================================================================
KitchenTab:CreateSection({ name = "🍽️ Serving" })
KitchenTab:CreateToggle({
    name = "Auto Serve Tables (Standalone)", flag = "AutoServe", value = false,
    callback = function(Value)
        AutoServeEnabled = Value
        if Value and QueueEnabled then
            SafeNotify("Note", "Priority Queue is ON — this toggle won't run until queue is off", 4)
        end
    end,
})

KitchenTab:CreateToggle({
    name = "⚡ Fast Pickup Mode",
    flag = "FastPickup",
    value = false,
    callback = function(Value)
        FastPickupEnabled = Value
        if Value then QuickToast("Fast Pickup", "Aggressive mode ON")
        else QuickToast("Fast Pickup", "Safe mode ON") end
    end,
})

KitchenTab:CreateText({
    name = "Fast Pickup Info",
    text = "Fast Pickup uses quicker teleport timings and E-key presses instead of proximity prompts.\n" ..
           "Faster but might fail more often. Toggle OFF for safer (slower) mode.",
})

KitchenTab:CreateToggle({
    name = "🔍 Verify Dish Before Serving",
    flag = "DishVerify",
    value = true,
    callback = function(Value)
        DishVerifyEnabled = Value
        if Value then
            QuickToast("Dish Verify", "Only serving matching dishes")
        else
            QuickToast("Dish Verify", "Serving without validation")
        end
    end,
})

KitchenTab:CreateText({
    name = "Dish Verify Info",
    text = "When ON, checks that the prompt's dish (ActionText) matches the food you're carrying.\n" ..
           "Prevents accidentally serving the wrong dish. Recommended: ON.",
})

KitchenTab:CreateDivider({ text = "cleaning" })
KitchenTab:CreateSection({ name = "🧼 Bussing" })
KitchenTab:CreateToggle({ name = "Auto Wash Dishes (Standalone)", flag = "AutoWash", value = false,
    callback = function(Value) AutoWashEnabled = Value end })
KitchenTab:CreateToggle({ name = "Auto Restock Fridge (Standalone)", flag = "AutoRestock", value = false,
    callback = function(Value) AutoRestockEnabled = Value end })

KitchenTab:CreateDivider({ text = "prompt options" })
KitchenTab:CreateSection({ name = "⚙️ Prompt Behavior" })
KitchenTab:CreateToggle({ name = "Use E-Key Fallback", flag = "UseEKey", value = true,
    callback = function(Value) UseEKeyFallback = Value end })

-- =================================================================
-- AUTO CUSTOMERS TAB
-- =================================================================
CustomerTab:CreateSection({ name = "👥 Counter" })
CustomerTab:CreateToggle({
    name = "Auto Assign Counter (Standalone)", flag = "AutoAssign", value = false,
    callback = function(Value)
        AutoAssignEnabled = Value
        if Value and QueueEnabled then
            SafeNotify("Note", "Priority Queue is ON — this toggle won't run until queue is off", 4)
        end
    end,
})

CustomerTab:CreateDivider({ text = "status" })
CustomerTab:CreateSection({ name = "📊 Live Info" })
local CustomerCountStat = CustomerTab:CreateStat({ name = "👥 Queued", value = 0, compact = true })
local SeatedCountStat   = CustomerTab:CreateStat({ name = "🪑 Seated", value = 0, compact = true })
local EmptySeatsStat    = CustomerTab:CreateStat({ name = "🪑 Free Seats", value = 0, compact = true })
local HeldFoodStat      = CustomerTab:CreateStat({ name = "🍽️ Holding Food", value = 0, compact = true })
local ReadyToServeStat  = CustomerTab:CreateStat({ name = "📋 On Counter", value = 0, compact = true })

-- =================================================================
-- AUTO STEAL TAB
-- =================================================================
StealTab:CreateSection({ name = "🥷 Runaway Detection" })
StealTab:CreateToggle({ name = "Auto Hit Runaways (Standalone)", flag = "AutoSteal", value = false,
    callback = function(Value) AutoStealEnabled = Value end })
StealTab:CreateToggle({ name = "Auto Equip Pan Before Hit", flag = "AutoEquipPan", value = true,
    callback = function(Value) AutoEquipPanEnabled = Value end })

StealTab:CreateDivider({ text = "manual" })
StealTab:CreateSection({ name = "🎯 Manual Actions" })
StealTab:CreateButton({ name = "🥷 Equip Pan Now", callback = function()
    EquipPan()
    QuickToast("Pan", "Equipped")
end })

-- =================================================================
-- MISC TAB
-- =================================================================
MiscTab:CreateSection({ name = "🚀 Movement" })
MiscTab:CreateSlider({
    name = "Walk Speed", flag = "WalkSpeed",
    range = { 16, 200 }, increment = 1, value = 16, suffix = " studs/s",
    callback = function(Value)
        WalkSpeedValue = Value
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = Value end
    end,
})

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

MiscTab:CreateDivider({ text = "teleports" })
MiscTab:CreateSection({ name = "📍 Fast Teleports" })

local function MakeTPButton(label, getter, yOffset)
    MiscTab:CreateButton({
        name = label,
        callback = function()
            local obj = getter()
            local part = GetPartFromObject(obj)
            if part then
                TeleportToPosition(part.Position + Vector3.new(0, yOffset or 4, 0))
                QuickToast("Teleported", label)
            else
                SafeNotify("TP Failed", label .. " not found (or not your plot)", 3)
            end
        end,
    })
end

MakeTPButton("🍳 TP Kitchen", GetKitchen, 4)
MakeTPButton("🧊 TP Fridge", GetFridge, 4)
MakeTPButton("🧼 TP Sink", GetSink, 4)
MakeTPButton("🍽️ TP Serve Counter", GetServeFolder, 4)
MakeTPButton("🪑 TP Dining Area", GetDiningPlot, 4)
MakeTPButton("🥷 TP Steal Spot 1", function()
    local s = GetStealFolder()
    return s and s:FindFirstChild("1")
end, 3)
MakeTPButton("🥷 TP Steal Spot 2", function()
    local s = GetStealFolder()
    return s and s:FindFirstChild("2")
end, 3)

MiscTab:CreateDivider({ text = "preferences" })
MiscTab:CreateSection({ name = "⚙️ Player Options" })
MiscTab:CreateToggle({ name = "Infinite Zoom", flag = "InfZoom", value = false,
    callback = function(Value)
        InfZoomEnabled = Value
        LocalPlayer.CameraMaxZoomDistance = Value and 100000 or 128
    end })
MiscTab:CreateToggle({ name = "Anti-AFK", flag = "AntiAFK", value = false,
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
    end })

MiscTab:CreateDivider({ line = false, spacing = 12 })
MiscTab:CreateSection({ name = "🚀 Optimization" })
MiscTab:CreateToggle({ name = "Fast Mode (FPS Booster)", flag = "FastMode", value = false,
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
            QuickToast("Graphics Restored", "Restored")
        end
    end })

-- =================================================================
-- INFO TAB
-- =================================================================
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
    text = "• NEW: Uses TableAction='Serve' prompt targeting (game's own filter)\n" ..
           "• NEW: Direct Serve prompt lookup on the NPC's table\n" ..
           "• NEW: 'Verify Dish' toggle (optional dish matching)\n" ..
           "• NEW: 'Skipped' stat shows failed delivery count\n" ..
           "• Fallback: prompt aura fires only Serve-action prompts",
})

InfoTab:CreateText({
    name = "v1.1.9",
    text = "• TargetNPCId delivery (from held food)",
})

InfoTab:CreateText({
    name = "v1.1.4",
    text = "• FIX: Table iteration numeric order",
})

InfoTab:CreateText({
    name = "v1.1.0",
    text = "• Priority Queue (10 slots)",
})

InfoTab:CreateDivider({ text = "how it works" })
InfoTab:CreateSection({ name = "💡 How It Works" })

InfoTab:CreateText({
    name = "Auto Serve (Serve Prompt)",
    text = "1. Sweep Serve counter — press E on each cooked food\n" ..
           "2. Food appears at workspace.<YourName>.<FoodName>\n" ..
           "3. Each food has TargetNPCId → identifies target customer\n" ..
           "4. Find customer's table via OccupiedBy1/2 attributes\n" ..
           "5. Find Serve prompt on table (TableN.CurrentTable.WoodPlank.ServeN)\n" ..
           "6. Verify dish matches (optional)\n" ..
           "7. TP + fire prompt → served",
})

InfoTab:CreateText({
    name = "Prompt Info",
    text = "Serve prompt has:\n" ..
           "  • TableAction = 'Serve' (used to filter)\n" ..
           "  • ActionText = 'Serve LugawPlain' (dish name)\n" ..
           "  • ObjectText = 'Table1' (table name)\n" ..
           "  • ReservedForServer (skipped if true)",
})

-- =================================================================
-- LIVE REFRESH
-- =================================================================
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
                + (QueueEnabled and 1 or 0)

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
            SkippedCountStat:Set(SkippedCount)

            local waiting = 0
            local npcs = Workspace:FindFirstChild("ClientNPCs")
            if npcs then
                for _, npc in ipairs(npcs:GetChildren()) do
                    if IsCustomer(npc) and not IsNpcSeated(npc.Name) then waiting += 1 end
                end
            end
            CustomerCountStat:Set(waiting)

            local seatedCount = 0
            local emptySeats = 0
            for _, entry in ipairs(GetSortedTables()) do
                local t = entry.model
                if t:GetAttribute("OccupiedBy1") then seatedCount += 1 else emptySeats += 1 end
                if t:GetAttribute("OccupiedBy2") then seatedCount += 1 else emptySeats += 1 end
            end
            SeatedCountStat:Set(seatedCount)
            EmptySeatsStat:Set(emptySeats)
            HeldFoodStat:Set(#GetHeldFoodItems())
            ReadyToServeStat:Set(#FindAllCookedFood())

            if QueueEnabled and not QueuePaused then
                StateTag:Set({ text = "QUEUE", color = Color3.fromRGB(0, 200, 255) })
            elseif QueuePaused then
                StateTag:Set({ text = "PAUSED", color = Color3.fromRGB(255, 200, 40) })
            elseif activeFeatures > 0 then
                StateTag:Set({ text = "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
            else
                StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
            end
        end)
    end
end)

SafeNotify("KissoHub", "Karinderya " .. HUB_VERSION .. " loaded", 3)
