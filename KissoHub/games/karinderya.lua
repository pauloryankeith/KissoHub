-- ═══════════════════════════════════════════════════════════════
--   KissoHub — Karinderya Module  |  v1.6.5
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
local HUB_VERSION = "v1.6.5"

-- Ingredient catalog with emoji (alphabetical)
local INGREDIENTS_LIST = {
    { name = "Bacon",         emoji = "🥓" },
    { name = "Bangus",        emoji = "🐟" },
    { name = "Beef",          emoji = "🥩" },
    { name = "CarbonaraPack", emoji = "🍝" },
    { name = "Cheese",        emoji = "🧀" },
    { name = "Chicharon",     emoji = "🍘" },
    { name = "Chicken",       emoji = "🍗" },
    { name = "Condiments",    emoji = "🧂" },
    { name = "CornBeef",      emoji = "🥫" },
    { name = "Egg",           emoji = "🥚" },
    { name = "Hotdog",        emoji = "🌭" },
    { name = "Hungarian",     emoji = "🌭" },
    { name = "Kola",          emoji = "🥤" },
    { name = "Loyal",         emoji = "🥤" },
    { name = "Noodles",       emoji = "🍜" },
    { name = "Pork",          emoji = "🥩" },
    { name = "Rice",          emoji = "🍚" },
    { name = "Shrimp",        emoji = "🦐" },
    { name = "SpaghettiPack", emoji = "🍝" },
    { name = "Suprise",       emoji = "🥤" },
    { name = "Tapa",          emoji = "🥩" },
    { name = "Tocino",        emoji = "🥓" },
    { name = "Vegetable",     emoji = "🥬" },
}

local INGREDIENTS = {}
local INGREDIENT_EMOJI = {}
for _, entry in ipairs(INGREDIENTS_LIST) do
    table.insert(INGREDIENTS, entry.name)
    INGREDIENT_EMOJI[entry.name] = entry.emoji
end

-- Remotes
local Remotes              = ReplicatedStorage:WaitForChild("Remotes", 10)
local CounterRemotes       = Remotes and Remotes:WaitForChild("CounterRemotes", 5)
local KitchenRemotes       = Remotes and Remotes:WaitForChild("KitchenRemotes", 5)
local NPCRemotes           = Remotes and Remotes:WaitForChild("NPCRemotes", 5)
local ShopRemotes          = Remotes and Remotes:WaitForChild("ShopRemotes", 5)
local NotificationFolder   = Remotes and Remotes:WaitForChild("Notification", 5)

local PropEquipEvent       = Remotes and Remotes:WaitForChild("PropEquipEvent")
local HitRunawayEvent      = Remotes and Remotes:WaitForChild("HitRunawayEvent")
local CustomerRanAwayEvent = Remotes and Remotes:WaitForChild("CustomerRanAwayEvent")
local RunawayExitedEvent   = NPCRemotes and NPCRemotes:WaitForChild("RunawayExitedEvent", 5)
local AssignNPC            = CounterRemotes and CounterRemotes:WaitForChild("AssignNPC")
local StoveCookingStarted  = KitchenRemotes and KitchenRemotes:WaitForChild("StoveCookingStarted")
local StoveCookingFinished = KitchenRemotes and KitchenRemotes:WaitForChild("StoveCookingFinished")
local BuyIngredientRemote  = ShopRemotes and ShopRemotes:WaitForChild("BuyIngredient", 5)
local NotifyRemote         = NotificationFolder and NotificationFolder:WaitForChild("Notify", 5)

-- Core state
local AutoServeEnabled         = false
local AutoServeRunning         = false
local AutoWashEnabled          = false
local AutoAssignEnabled        = false
local AutoCatchRunawayEnabled  = false
local EquipPanBeforeCatchEnabled = true
local InfZoomEnabled           = false
local FastModeEnabled          = false
local AntiAFKEnabled           = false
local WalkSpeedValue           = 16
local NoclipPathfindingEnabled = true
local WashHoldTime             = 30
local WashThreshold            = 12
local CatchCooldown            = 3

-- [v1.6.5] Instant prompt feature
local InstantPromptEnabled     = true
local ModifiedPrompts          = {}   -- [ProximityPrompt] = original HoldDuration

-- Grocery automation state
local AutoBuyWhenLow           = false
local AutoBuyOnNotif           = false
local StockThreshold           = 30
local BuyQuantity              = 5
local MirrorSystemNotifs       = true
local SelectedIngredients      = {}
for _, name in ipairs(INGREDIENTS) do SelectedIngredients[name] = true end

-- Buy loop hardening
local ConsecutiveBuyFailures   = 0
local LastBuyError             = nil
local BUY_FAILURE_LIMIT        = 5

local PATH_WAYPOINT_TIMEOUT = 2
local PATH_ARRIVE_DISTANCE  = 4

local PRE_TP_DELAY        = 0.05
local POST_TP_SETTLE      = 0.25
local POST_FIRE_WAIT      = 0.3

local ESpamEnabled        = true
local ESpamActive         = false
local ESpamSpeed          = 0.08
local ESpamConnection     = nil

local CaughtRunawayCount = 0
local ServedCount        = 0
local WashedCount        = 0
local AssignedCount      = 0
local ESpamFiredCount    = 0
local BoughtCount        = 0
local FailedBuyCount     = 0

local ActiveStoves = {}
local RecentlyHit  = {}
local NoclipActive = false
local NoclipConnection = nil
local AntiAFKConnection = nil
local RecentSystemNotifs = {}

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

-- Ingredient stock reader
local function GetIngredientStock(name)
    local ing = LocalPlayer:FindFirstChild("Ingredients")
    if not ing then return 0 end
    local v = ing:FindFirstChild(name)
    if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
        return v.Value
    end
    return 0
end

-- Buy ingredient with hardening
local function TryBuyIngredient(name, qty)
    if not BuyIngredientRemote then return false end
    qty = math.max(1, math.floor(qty or 1))
    local ok, success = pcall(function()
        return BuyIngredientRemote:InvokeServer(name, qty, "Cash")
    end)
    if ok and success == true then
        BoughtCount += qty
        ConsecutiveBuyFailures = 0
        LastBuyError = nil
        return true
    end
    FailedBuyCount += 1
    ConsecutiveBuyFailures += 1
    LastBuyError = ok and tostring(success) or "pcall error"
    return false
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

local function GetPlotCenter()
    local k = GetKarenderya()
    if not k then return nil end
    local cframe
    if k:IsA("Model") then cframe = k:GetPivot()
    elseif k:IsA("BasePart") then cframe = k.CFrame
    else
        local base = k:FindFirstChild("Base") or k:FindFirstChild("Baseplate") or k:FindFirstChildWhichIsA("BasePart", true)
        cframe = base and base.CFrame or CFrame.new()
    end
    return cframe.Position + Vector3.new(0, 4, 0)
end

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

-- NOCLIP
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

-- MOVEMENT (Pathfinding)
local function Move_Pathfinding(pos, offsetY)
    local hrp = GetHRP()
    if not hrp or not pos then return end

    local targetPos = pos + Vector3.new(0, offsetY or 0, 0)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

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

    local path = PathfindingService:CreatePath({
        AgentRadius = 2, AgentHeight = 5,
        AgentCanJump = true, AgentCanClimb = false,
        WaypointSpacing = 4,
    })

    local ok = pcall(function() path:ComputeAsync(hrp.Position, targetPos) end)

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

local function FirePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    if not prompt.Enabled then return false end

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
        if child:IsA("Tool") then
            table.insert(items, { Name = child.Name, Tool = child })
        elseif child.Name:match("^Lugaw")
            or child.Name:match("Silog")
            or child.Name:match("Food$")
            or child.Name:match("^Cooked_") then
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

-- =================================================================
-- ⚡ INSTANT PROMPT WATCHER (v1.6.5)
-- Zeroes HoldDuration on Cooked_* pickup prompts and Table Serve prompts.
-- Restores originals when disabled.
-- =================================================================
task.spawn(function()
    while true do
        task.wait(1)
        if InstantPromptEnabled then
            local plot = GetKarenderya()
            if plot then
                -- 1. Pickup prompts: Serve["N"].Cooked_*.Plate.ProximityPrompt
                local serve = plot:FindFirstChild("Serve") or plot:FindFirstChild("Serving")
                if serve then
                    for _, slot in ipairs(serve:GetChildren()) do
                        if slot.Name:match("^%d+$") then
                            for _, cooked in ipairs(slot:GetChildren()) do
                                if cooked.Name:match("^Cooked_") then
                                    local plate = cooked:FindFirstChild("Plate")
                                    local prompt = plate and plate:FindFirstChild("ProximityPrompt")
                                    if prompt and prompt:IsA("ProximityPrompt") then
                                        if ModifiedPrompts[prompt] == nil then
                                            ModifiedPrompts[prompt] = prompt.HoldDuration
                                        end
                                        if prompt.HoldDuration > 0 then
                                            prompt.HoldDuration = 0
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                -- 2. Table serve prompts: TableAction == "Serve"
                for _, obj in ipairs(plot:GetDescendants()) do
                    if obj:IsA("ProximityPrompt")
                       and obj:GetAttribute("TableAction") == "Serve" then
                        if ModifiedPrompts[obj] == nil then
                            ModifiedPrompts[obj] = obj.HoldDuration
                        end
                        if obj.HoldDuration > 0 then
                            obj.HoldDuration = 0
                        end
                    end
                end
            end
        else
            -- Restore originals
            for prompt, originalHold in pairs(ModifiedPrompts) do
                if prompt and prompt.Parent then
                    pcall(function() prompt.HoldDuration = originalHold end)
                end
            end
            ModifiedPrompts = {}
        end
    end
end)

-- TASK RUNNERS
local function RunTask_Assign(budget)
    if not HasOwnPlot() or not AssignNPC then return end
    local deadline = os.clock() + budget
    while os.clock() < deadline do
        local npc = FindQueuedCustomer()
        if not npc then break end
        local seat = FindFreeSeat()
        if not seat then break end
        local success = pcall(function()
            AssignNPC:FireServer({
                NpcId = npc.Name, Seat = seat.Seat,
                NPCName = npc.Name, Slot = seat.Table,
            })
        end)
        if success then AssignedCount += 1 end
        task.wait(0.5)
    end
end

local function RunTask_Serve(budget)
    if AutoServeRunning then return end
    if not HasOwnPlot() then return end

    -- One run handles one fixed batch.
    -- Orders that appear after this snapshot wait for the next run.
    AutoServeRunning = true

    local ok = pcall(function()
        if NoclipPathfindingEnabled and not NoclipActive then
            EnableNoclip()
        end

        -- 1. Snapshot the orders that are currently waiting.
        local batchTargets = FindAllEnabledServePrompts()
        local batchSize = #batchTargets
        if batchSize == 0 then
            return
        end

        -- 2. Snapshot the cooked food that is currently available.
        -- Use the existing collection logic exactly as before:
        -- move to each plate, fire its prompt, then wait.
        local cookedFoods = FindAllCookedFood()
        local collected = 0

        for _, food in ipairs(cookedFoods) do
            if collected >= batchSize then
                break
            end

            local platePart = GetPartFromObject(food.Plate)
            if platePart then
                task.wait(PRE_TP_DELAY)
                MoveTo(platePart.Position, 1)
                task.wait(POST_TP_SETTLE)

                FirePrompt(food.Prompt)
                task.wait(POST_FIRE_WAIT)
                collected += 1
            end
        end

        if collected == 0 then
            return
        end

        -- 3. Serve only the orders from the original snapshot.
        -- Do not discover new orders while this batch is being served.
        local serveCount = math.min(collected, batchSize)

        for i = 1, serveCount do
            local entry = batchTargets[i]

            if entry
                and entry.Prompt
                and entry.Prompt.Parent
                and entry.Prompt.Enabled
                and entry.Part
                and entry.Part.Parent
                and #GetHeldFoodItems() > 0 then

                task.wait(PRE_TP_DELAY)
                MoveTo(entry.Part.Position, 1)
                task.wait(POST_TP_SETTLE)

                FirePrompt(entry.Prompt)
                ServedCount += 1
                task.wait(POST_FIRE_WAIT)
            end
        end

        task.wait(0.3)
    end)

    -- Always release the batch lock even if something inside the run errors.
    AutoServeRunning = false
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

-- Auto-buy loop: up to 3 buys per tick, 0.5s pacing
task.spawn(function()
    while true do
        task.wait(5)
        if AutoBuyWhenLow and BuyIngredientRemote then
            if ConsecutiveBuyFailures >= BUY_FAILURE_LIMIT then
                AutoBuyWhenLow = false
                QuickToast("Auto-Buy disabled", "Too many failures: " .. tostring(LastBuyError))
                ConsecutiveBuyFailures = 0
            else
                local buysThisTick = 0
                for _, name in ipairs(INGREDIENTS) do
                    if buysThisTick >= 3 then break end
                    if SelectedIngredients[name] then
                        local stock = GetIngredientStock(name)
                        if stock < StockThreshold then
                            TryBuyIngredient(name, BuyQuantity)
                            buysThisTick += 1
                            task.wait(0.5)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function() while true do task.wait(1.5); if AutoAssignEnabled then pcall(RunTask_Assign, 1.5) end end end)
task.spawn(function()
    while true do
        task.wait(1.0)
        if AutoServeEnabled and not AutoServeRunning then
            pcall(RunTask_Serve, 8.0)
        end
    end
end)
task.spawn(function() while true do task.wait(2); if AutoWashEnabled then pcall(RunTask_Wash, 35.0) end end end)

-- =================================================================
-- 🚨 AUTO CATCH RUNAWAY
-- =================================================================
local function EquipPanFromBackpack()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return false end
    local pan = backpack:FindFirstChild("Pan")
    if not pan then return false end
    humanoid:EquipTool(pan)
    return true
end

local function ClickMouse()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

if CustomerRanAwayEvent then
    CustomerRanAwayEvent.OnClientEvent:Connect(function(displayName, npcModelName)
        if not AutoCatchRunawayEnabled or not npcModelName then return end
        if RecentlyHit[npcModelName] and (os.time() - RecentlyHit[npcModelName] < CatchCooldown) then return end
        RecentlyHit[npcModelName] = os.time()

        task.spawn(function()
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                if not hrp or not humanoid then return end

                local originalCF = hrp.CFrame

                local npcs = Workspace:FindFirstChild("ClientNPCs")
                local npc = (npcs and npcs:FindFirstChild(npcModelName)) or Workspace:FindFirstChild(npcModelName)
                if not npc then return end

                if EquipPanBeforeCatchEnabled then
                    EquipPanFromBackpack()
                    task.wait(0.15)
                end

                local npcPart = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
                if not npcPart then return end
                hrp.CFrame = npcPart.CFrame + Vector3.new(0, 2, 0)
                task.wait(0.15)

                ClickMouse()
                if HitRunawayEvent then
                    task.spawn(pcall, function()
                        HitRunawayEvent:FireServer(npc.Name, "melee", "Pan")
                    end)
                end
                CaughtRunawayCount += 1

                task.wait(0.2)

                if hrp and hrp.Parent then
                    hrp.CFrame = originalCF
                end
            end)
        end)
    end)
end

if RunawayExitedEvent then
    RunawayExitedEvent.OnClientEvent:Connect(function(npcModelName)
        if not npcModelName then return end
        RecentlyHit[npcModelName] = nil
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

-- KITCHEN TRACKING
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

-- System feed console — declared early so notification handler can append
local NotifConsole

-- Notification interceptor
if NotifyRemote then
    NotifyRemote.OnClientEvent:Connect(function(msg, source, duration)
        if type(msg) ~= "string" then return end
        local now = os.clock()
        if RecentSystemNotifs[msg] and (now - RecentSystemNotifs[msg]) < 2 then return end
        RecentSystemNotifs[msg] = now

        if MirrorSystemNotifs and source == "System" then
            QuickToast("⚠️ System", msg)
        end

        if NotifConsole then
            pcall(function()
                NotifConsole:Append(("[%s] %s"):format(source or "?", msg))
            end)
        end

        if AutoBuyOnNotif and (source == "System" or source == "Warning") then
            local ingredient = msg:match("^Out of (%w+)")
            if ingredient and SelectedIngredients[ingredient] then
                local ok = TryBuyIngredient(ingredient, BuyQuantity)
                if ok then
                    QuickToast("🛒 Bought " .. ingredient, "×" .. BuyQuantity)
                end
            end
        end
    end)
end

-- TABS
local HomeTab       = Window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })
local KitchenTab    = Window:CreateTab({ name = "🍳 Auto Kitchen" })
local CustomerTab   = Window:CreateTab({ name = "👥 Auto Customers" })
local IngredientTab = Window:CreateTab({ name = "🧺 Ingredients" })
local MiscTab       = Window:CreateTab({ name = "🛠️ Misc" })
local InfoTab       = Window:CreateTab({ name = "ℹ️ Info" })

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
local CaughtCountStat   = ActR:CreateStat({ name = "🚨 Caught", value = 0, compact = true })
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
    name = "⚡ Instant Pickup Prompts",
    description = "Removes HoldDuration on Cooked_* plate prompts and table serve prompts — one click collects, no hold needed.",
    flag = "InstantPrompt",
    value = true,
    callback = function(v)
        InstantPromptEnabled = v
        QuickToast("Instant Prompts", v and "ON" or "OFF")
    end,
})

KitchenTab:CreateToggle({
    name = "🚀 Noclip Pathfinding",
    flag = "NoclipPathfinding",
    value = true,
    callback = function(v)
        NoclipPathfindingEnabled = v
        if v then EnableNoclip() else DisableNoclip() end
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

-- CUSTOMERS
CustomerTab:CreateSection({ name = "👥 Counter" })
CustomerTab:CreateToggle({ name = "Auto Assign Counter", flag = "AutoAssign", value = false,
    callback = function(v) AutoAssignEnabled = v; QuickToast("Auto Assign", v and "ON" or "OFF") end })

CustomerTab:CreateDivider({ text = "runaway catching" })
CustomerTab:CreateSection({ name = "🚨 Auto Catch Runaway" })

CustomerTab:CreateToggle({
    name = "Auto Catch Runaways",
    flag = "AutoCatchRunaway",
    value = false,
    callback = function(v)
        AutoCatchRunawayEnabled = v
        QuickToast("Auto Catch", v and "ON" or "OFF")
    end,
})

CustomerTab:CreateToggle({
    name = "Equip Pan Before Catch",
    flag = "EquipPanBeforeCatch",
    value = true,
    callback = function(v) EquipPanBeforeCatchEnabled = v end,
})

CustomerTab:CreateSlider({
    name = "Catch Cooldown (sec)",
    flag = "CatchCooldown",
    range = { 1, 10 }, increment = 0.5, value = 3, suffix = " s",
    callback = function(v) CatchCooldown = v end,
})

CustomerTab:CreateText({
    name = "Catch Info",
    text = "When a customer runs away:\n" ..
           "1. Equip Pan from Backpack\n" ..
           "2. TP directly to NPC\n" ..
           "3. Click + fire HitRunawayEvent\n" ..
           "4. Return to pre-TP position",
})

CustomerTab:CreateDivider({ text = "status" })
CustomerTab:CreateSection({ name = "📊 Live Info" })
local CustomerCountStat = CustomerTab:CreateStat({ name = "👥 Queued", value = 0, compact = true })
local SeatedCountStat   = CustomerTab:CreateStat({ name = "🪑 Seated", value = 0, compact = true })
local EmptySeatsStat    = CustomerTab:CreateStat({ name = "🪑 Free Seats", value = 0, compact = true })
local HeldFoodStat      = CustomerTab:CreateStat({ name = "🍽️ Holding Food", value = 0, compact = true })
local ReadyToServeStat  = CustomerTab:CreateStat({ name = "🎯 Serve Ready", value = 0, compact = true })
local CaughtLiveStat    = CustomerTab:CreateStat({ name = "🚨 Caught This Session", value = 0, compact = true })

-- =================================================================
-- 🧺 INGREDIENTS TAB
-- =================================================================
IngredientTab:CreateSection({ name = "📦 Live Stock (updates every 0.5s)" })

local StockGrid = IngredientTab:CreateGroup()
local StockL = StockGrid:CreateGroup({ direction = "column" })
local StockR = StockGrid:CreateGroup({ direction = "column" })

local IngredientStats = {}
local colSwitch = 1
for _, entry in ipairs(INGREDIENTS_LIST) do
    local targetCol = (colSwitch == 1) and StockL or StockR
    IngredientStats[entry.name] = targetCol:CreateStat({
        name  = entry.emoji .. " " .. entry.name,
        value = 0,
        suffix = " ×",
        compact = true,
    })
    colSwitch = (colSwitch == 1) and 2 or 1
end

IngredientTab:CreateDivider({ text = "quick buy" })
IngredientTab:CreateSection({ name = "🛒 Auto-Buy Configuration" })

IngredientTab:CreateDropdown({
    name = "Which ingredients to auto-buy",
    description = "Selected stocks will be topped up when low.",
    options = INGREDIENTS,
    value = INGREDIENTS,
    multiSelect = true,
    flag = "AutoBuySelection",
    callback = function(selected)
        SelectedIngredients = {}
        for _, n in ipairs(selected) do SelectedIngredients[n] = true end
    end,
})

IngredientTab:CreateToggle({
    name = "Auto-Buy When Low",
    description = "Every 5s, buy up to 3 selected ingredients under the threshold.",
    flag = "AutoBuyWhenLow",
    value = false,
    callback = function(v)
        AutoBuyWhenLow = v
        ConsecutiveBuyFailures = 0
        QuickToast("Auto-Buy", v and "ON" or "OFF")
    end,
})

IngredientTab:CreateSlider({
    name = "Stock Threshold",
    description = "Auto-buy triggers when stock drops below this value.",
    flag = "StockThreshold",
    range = { 1, 100 }, increment = 1, value = 30, suffix = " stock",
    callback = function(v) StockThreshold = v end,
})

IngredientTab:CreateSlider({
    name = "Buy Quantity",
    description = "How many to buy per trigger.",
    flag = "BuyQuantity",
    range = { 1, 50 }, increment = 1, value = 5, suffix = " ×",
    callback = function(v) BuyQuantity = v end,
})

IngredientTab:CreateDivider({ text = "notification trigger" })
IngredientTab:CreateSection({ name = "🔔 Auto-Buy on 'Out of X' Notice" })

IngredientTab:CreateToggle({
    name = "Auto-Buy on Notification",
    description = "Buys the ingredient mentioned in 'Out of X' notices.",
    flag = "AutoBuyOnNotif",
    value = false,
    callback = function(v)
        AutoBuyOnNotif = v
        QuickToast("Notif Auto-Buy", v and "ON" or "OFF")
    end,
})

IngredientTab:CreateToggle({
    name = "Mirror System Notifications",
    description = "Show every System notice as a toast.",
    flag = "MirrorSystemNotifs",
    value = true,
    callback = function(v) MirrorSystemNotifs = v end,
})

IngredientTab:CreateDivider({ text = "system feed" })
IngredientTab:CreateSection({ name = "📜 Intercepted Notifications" })
NotifConsole = IngredientTab:CreateConsole({
    name = "System Feed",
    description = "Every game notification that fires.",
    height = 140,
    follow = true,
    maxLines = 100,
})

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
MiscTab:CreateSection({ name = "🎯 Pathfinding" })
MiscTab:CreateSlider({ name = "Path Waypoint Timeout", flag = "PathWpTimeout",
    range = { 0.5, 5 }, increment = 0.1, value = 2, suffix = " s",
    callback = function(v) PATH_WAYPOINT_TIMEOUT = v end })
MiscTab:CreateText({
    name = "Movement Info",
    text = "Character uses PathfindingService.\nToggle 'Noclip Pathfinding' in Kitchen tab to change behavior.",
})

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
    text = "• NEW: Instant Pickup Prompts toggle (default ON)\n" ..
           "• Removes HoldDuration on all Cooked_* plate prompts\n" ..
           "• Also removes HoldDuration on table serve prompts\n" ..
           "• Restores originals when toggled OFF",
})

InfoTab:CreateText({
    name = "v1.6.4",
    text = "• Removed Auto Restock Fridge toggle + task\n" ..
           "• Cleaned up unused state vars",
})

InfoTab:CreateText({
    name = "v1.6.3",
    text = "• Emoji labels on all 23 ingredient stats\n" ..
           "• Buy loop hardened: max 3 buys/5s tick, 0.5s pacing\n" ..
           "• Auto-buy self-disables after 5 consecutive failures",
})

InfoTab:CreateText({
    name = "v1.6.2",
    text = "• NEW: Ingredients tab with realtime stock display\n" ..
           "• NEW: Quick Buy multiselect + threshold/quantity sliders\n" ..
           "• NEW: Auto-buy on 'Out of X' System notification\n" ..
           "• NEW: System Feed console",
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
                + (AutoAssignEnabled and 1 or 0)
                + (AutoCatchRunawayEnabled and 1 or 0)
                + (EquipPanBeforeCatchEnabled and 1 or 0)
                + (InfZoomEnabled and 1 or 0)
                + (FastModeEnabled and 1 or 0)
                + (AntiAFKEnabled and 1 or 0)
                + (ESpamActive and 1 or 0)
                + (NoclipPathfindingEnabled and 1 or 0)
                + (AutoBuyWhenLow and 1 or 0)
                + (AutoBuyOnNotif and 1 or 0)
                + (InstantPromptEnabled and 1 or 0)

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
            CaughtCountStat:Set(CaughtRunawayCount)
            DishesStackedStat:Set(CountDirtyDishes())

            for _, name in ipairs(INGREDIENTS) do
                local stat = IngredientStats[name]
                if stat then
                    stat:Set(GetIngredientStock(name))
                end
            end

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
            CaughtLiveStat:Set(CaughtRunawayCount)

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

-- Startup
if NoclipPathfindingEnabled then
    EnableNoclip()
end

if ESpamEnabled then
    StartESpam()
end

SafeNotify("KissoHub", "Karinderya " .. HUB_VERSION .. " loaded", 3)
