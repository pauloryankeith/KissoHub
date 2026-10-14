-- ═══════════════════════════════════════════════════════════════
--   KissoHub — Survive the Apocalypse Module  |  v1.11.3
--   Author: pauloryankeith
--   Official: github.com/pauloryankeith/KissoHub
--   Patched: Drone ownership detection via ToFollow.ObjectValue
--            (fixes cross-player drone confusion),
--            Overlay ↔ Hub toggle sync,
--            lowercase close glyph, empty-icon accents
-- ═══════════════════════════════════════════════════════════════

local HttpService       = game:GetService("HttpService")
local Rayfield          = loadstring(game:HttpGet("https://sirius.menu/gen2"))()
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local VirtualUser       = game:GetService("VirtualUser")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local ASSET_ICON  = "rbxassetid://89387722763691"
local HUB_VERSION = "v1.11.3"
local SESSION_START = os.time()

OnScreenUI = OnScreenUI or {}

-- =================================================================
-- SHARED STATE
-- =================================================================
local State = {
    AutoShoot = false, AutoShootRange = 500, SilentAim = false,
    PreciseHeadshot = true,
    AutoShootPriority = "Nearest",
    AutoShootPrediction = false, AutoShootPredictStr = 1.5,
    CheckDamageable = true,
    KillAura = false, KillAuraRange = 12, AutoSwing = false,
    ZeroWindUp = false, ZeroEndlag = false, SpeedMult = 1,
    MeleePriority = "Nearest",
    AutoReload = false, InstantReload = false, RemoteReload = false,
    AutoReloadHolstered = false, HolsteredReloadInterval = 1, ReloadEquippedToo = true,
    NoRecoil = false, NoSpread = false,
    AutoLoot = false, AutoLootRange = 20, AutoStore = false,
    PreventBaseLoot = false,
    ZombieESP = false, PlayerESP = false, SurvivorESP = false,
    AirdropESP = false, ItemESP = false, CrateESP = false,
    ESPShowNames = true, ESPShowDistance = true,
    RemoveFog = false, Fullbright = false, InfZoom = false,
    InstantPrompts = false, AntiAFK = false, BPRefresh = true,
    LiveStats = true,
    LootMultiSelect = false, ESPMultiSelect = false,
    AutoCombatDrone = false, CombatRange = 500,
    CombatPriority = "Nearest to Me",
    HoverHeight = 8, HoverInterval = 0.25,
    DroneAIMode = "Closest",
    CombatFollowTarget = nil, HealingFollowTarget = nil,
    ClassLevel = 1,
    DroneESP = false, DroneESPShowOwner = true,
    AutoRescanInterval = 25,
    GuardBasePosition = nil,
    GuardBaseRadius = 120,
    GuardBaseBindStreaming = false,
    UseCachedPad = true,
    AutoEquipPad = false,
    RapidFire = false, RapidFireMult = 2,
    SpeedHack = false, SpeedValue = 30, SpeedBypassMode = false,
    InfJump = false,
    HitboxExpand = false, HitboxSize = 5,
    AutoHeal = false, AutoHealThreshold = 50,
    AutoEat = false, AutoEatThreshold = 30,
    SmartHeal = false,
    SmartHealThreshold = 70,
    ShowOnScreenUI = false,
}

local Stats = {}
local Remotes = { PickUpItem = nil, AdjustBackpack = nil }
local Filters = { LootItems = {}, ESPItems = {},
                  LootDropdown = nil, ESPDropdown = nil,
                  CombatFollowDropdown = nil, HealingFollowDropdown = nil }
local Prompts = { OriginalHold = {}, Connection = nil }
local ESPRefs = { Toggles = {} }
local AntiAFKConnection = nil

local UI = {
    CombatAutoToggle = nil,
    HealAutoToggle   = nil,
    GuardBaseBindToggle = nil,
    SmartHealToggle = nil,
    ShowOnScreenUIToggle = nil,
}

-- Rayfield toggle references — used to keep overlay buttons and hub toggles in sync
local ToggleRefs = {}

-- Central setter: updates State, updates the Rayfield toggle, avoids recursion
local function SetFeature(name, value)
    if State[name] == value then return end
    State[name] = value
    local ref = ToggleRefs[name]
    if ref then pcall(function() ref:Set(value) end) end
end

-- =================================================================
-- ENEMY CACHE
-- =================================================================
local ZombieCache = { list = {}, lastScan = 0, totalFound = 0 }

local function IsPlayerCharacter(model)
    if not model then return false end
    if model:GetAttribute("Player") == true then return true end
    if Players:GetPlayerFromCharacter(model) then return true end
    return false
end

local function IsHostileModel(m)
    if not m or not m:IsA("Model") then return false end
    if not m:FindFirstChildOfClass("Humanoid") then return false end
    if IsPlayerCharacter(m) then return false end
    return true
end

local function ScanZombies()
    local out = {}
    local chars = Workspace:FindFirstChild("Characters")
    if not chars then
        ZombieCache.list = out; ZombieCache.lastScan = tick(); ZombieCache.totalFound = 0
        return out
    end
    for _, m in ipairs(chars:GetChildren()) do
        if IsHostileModel(m) then table.insert(out, m) end
    end
    ZombieCache.list = out
    ZombieCache.lastScan = tick()
    ZombieCache.totalFound = #out
    return out
end

local function GetZombieList()
    local interval = State.AutoRescanInterval or 0
    if interval > 0 and tick() - ZombieCache.lastScan >= interval then
        ScanZombies()
    end
    local alive = {}
    for _, z in ipairs(ZombieCache.list) do
        local hum = z.Parent and z:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then table.insert(alive, z) end
    end
    return alive
end

task.spawn(function() task.wait(1); ScanZombies() end)

task.spawn(function()
    local chars = Workspace:WaitForChild("Characters", 30)
    if not chars then return end
    chars.ChildAdded:Connect(function(child)
        if IsHostileModel(child) then
            table.insert(ZombieCache.list, child)
            ZombieCache.totalFound = #ZombieCache.list
        end
    end)
    chars.ChildRemoved:Connect(function(child)
        for i = #ZombieCache.list, 1, -1 do
            if ZombieCache.list[i] == child then table.remove(ZombieCache.list, i) end
        end
        ZombieCache.totalFound = #ZombieCache.list
    end)
end)

-- =================================================================
-- ITEM DATABASE
-- =================================================================
local ItemDatabase = { All = {}, ByCategory = {}, Lookup = {} }

local CategoryColors = {
    Fuel = Color3.fromRGB(255, 100, 100), Ammo = Color3.fromRGB(255, 200, 40),
    Resources = Color3.fromRGB(200, 200, 200), Food = Color3.fromRGB(100, 255, 100),
    Armor = Color3.fromRGB(100, 150, 255), Misc = Color3.fromRGB(220, 100, 255),
    AlienCrystals = Color3.fromRGB(0, 255, 200),
    Tool_Backpacks = Color3.fromRGB(180, 130, 90), Tool_CarAttachments = Color3.fromRGB(120, 170, 220),
    Tool_Consumable = Color3.fromRGB(255, 150, 50), Tool_Guns = Color3.fromRGB(255, 90, 60),
    Tool_Medical = Color3.fromRGB(255, 160, 200), Tool_Melee = Color3.fromRGB(200, 60, 60),
    Tool_Misc = Color3.fromRGB(180, 180, 200),
}

local function BuildItemDatabase()
    table.clear(ItemDatabase.All); table.clear(ItemDatabase.ByCategory); table.clear(ItemDatabase.Lookup)
    local Items = ReplicatedStorage:FindFirstChild("Items")
    if Items then for _, c in ipairs(Items:GetChildren()) do
        if c:IsA("Folder") then
            ItemDatabase.ByCategory[c.Name] = ItemDatabase.ByCategory[c.Name] or {}
            for _, i in ipairs(c:GetChildren()) do
                if i:IsA("Model") then
                    table.insert(ItemDatabase.All, i.Name); table.insert(ItemDatabase.ByCategory[c.Name], i.Name)
                    ItemDatabase.Lookup[i.Name] = c.Name
                end
            end
        end
    end end
    local Tools = ReplicatedStorage:FindFirstChild("Tools")
    if Tools then for _, c in ipairs(Tools:GetChildren()) do
        if c:IsA("Folder") then
            local cn = "Tool_" .. c.Name
            ItemDatabase.ByCategory[cn] = ItemDatabase.ByCategory[cn] or {}
            for _, i in ipairs(c:GetChildren()) do
                if i:IsA("Tool") or i:IsA("Model") then
                    table.insert(ItemDatabase.All, i.Name); table.insert(ItemDatabase.ByCategory[cn], i.Name)
                    ItemDatabase.Lookup[i.Name] = cn
                end
            end
        end
    end end
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
    if IsPlayerCharacter(character) then return false end
    for _, a in ipairs({"NPC","Friendly","Vendor","Pet","QuestGiver"}) do
        if character:GetAttribute(a) == true then return false end
    end
    return true
end

local function getTargetPart(character)
    if not character or not canBeDamaged(character) then return nil end
    return character:FindFirstChild("Head") or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart")
end

local function getLocalRootPosition()
    if LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Head")
        if hrp then return hrp.Position end
    end
    return Camera.CFrame.Position
end

local function GetModelPos(model)
    if not model then return nil end
    local hrp = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
    return hrp and hrp.Position or nil
end

local function GetTargetsInRange(maxDist)
    local myPos = getLocalRootPosition()
    local results = {}
    for _, char in ipairs(GetZombieList()) do
        if isZombieEnemy(char) and canBeDamaged(char) then
            local part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
            if part then
                local d = (part.Position - myPos).Magnitude
                if maxDist == 0 or d <= maxDist then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    table.insert(results, { model = char, part = part, dist = d, hp = hum and hum.Health or 0 })
                end
            end
        end
    end
    return results
end

local function SortTargets(targets)
    if State.AutoShootPriority == "Nearest" then
        table.sort(targets, function(a, b) return a.dist < b.dist end)
    elseif State.AutoShootPriority == "Lowest HP" then
        table.sort(targets, function(a, b) return a.hp < b.hp end)
    elseif State.AutoShootPriority == "Highest HP" then
        table.sort(targets, function(a, b) return a.hp > b.hp end)
    elseif State.AutoShootPriority == "Random" then
        for i = #targets, 2, -1 do
            local j = math.random(i); targets[i], targets[j] = targets[j], targets[i]
        end
    end
end

local function getClosestZombie(customMaxDist)
    local maxDist = customMaxDist or State.AutoShootRange
    local myPos = getLocalRootPosition()
    local best, bestMetric = nil, math.huge
    for _, char in ipairs(GetZombieList()) do
        if isZombieEnemy(char) and canBeDamaged(char) then
            local part = getTargetPart(char)
            if part then
                local d = (part.Position - myPos).Magnitude
                if (maxDist == 0 or d <= maxDist) and d < bestMetric then best = part; bestMetric = d end
            end
        end
    end
    return best
end

local function IsNearBaseBlocked()
    if not State.PreventBaseLoot then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    return char:GetAttribute("NearBase") == true
end

local function ResolveGuardBasePosition()
    local map = Workspace:FindFirstChild("Map")
    local tiles = map and map:FindFirstChild("Tiles")
    local center = tiles and tiles:FindFirstChild("Center")
    if center then
        if center:IsA("Model") then
            local pp = center.PrimaryPart or center:FindFirstChildWhichIsA("BasePart", true)
            if pp then return pp.Position end
            local ok, piv = pcall(function() return center:GetPivot() end)
            if ok and piv then return piv.Position end
        elseif center:IsA("BasePart") then
            return center.Position
        end
    end
    return State.GuardBasePosition
end

local function GetGuardBasePosition()
    if State.GuardBasePosition then return State.GuardBasePosition end
    local resolved = ResolveGuardBasePosition()
    if resolved then State.GuardBasePosition = resolved end
    return State.GuardBasePosition
end

task.spawn(function()
    task.wait(2)
    GetGuardBasePosition()
    local map = Workspace:WaitForChild("Map", 30)
    if not map then return end
    local tiles = map:WaitForChild("Tiles", 30)
    if not tiles then return end
    local center = tiles:WaitForChild("Center", 30)
    if center and not State.GuardBasePosition then
        local resolved = ResolveGuardBasePosition()
        if resolved then State.GuardBasePosition = resolved end
    end
end)

local function PickBestZombie(dronePos)
    local myPos = getLocalRootPosition()
    local pri = State.CombatPriority
    local guardPos = nil
    if pri == "Guard Base" then guardPos = GetGuardBasePosition() end
    local cands = {}
    for _, z in ipairs(GetZombieList()) do
        if isZombieEnemy(z) and canBeDamaged(z) then
            local hum = z:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local p = GetModelPos(z)
                if p then
                    local dMe    = (p - myPos).Magnitude
                    local dDrone = dronePos and (p - dronePos).Magnitude or 9999
                    local dGuard = guardPos and (p - guardPos).Magnitude or 9999
                    if State.CombatRange == 0 or dMe <= State.CombatRange then
                        local passGuard = true
                        if pri == "Guard Base" and guardPos then
                            passGuard = dGuard <= State.GuardBaseRadius
                        end
                        if passGuard then
                            table.insert(cands, { model = z, pos = p, dMe = dMe, dDrone = dDrone, dGuard = dGuard, hp = hum.Health })
                        end
                    end
                end
            end
        end
    end
    if #cands == 0 then return nil end
    if pri == "Nearest to Me" then
        table.sort(cands, function(a,b) return a.dMe < b.dMe end)
    elseif pri == "Nearest to Drone" then
        table.sort(cands, function(a,b) return a.dDrone < b.dDrone end)
    elseif pri == "Guard Base" then
        table.sort(cands, function(a,b) return a.dGuard < b.dGuard end)
    elseif pri == "Lowest HP" then
        table.sort(cands, function(a,b) return a.hp < b.hp end)
    elseif pri == "Highest HP" then
        table.sort(cands, function(a,b) return a.hp > b.hp end)
    elseif pri == "Random" then
        for i = #cands, 2, -1 do local j = math.random(i); cands[i], cands[j] = cands[j], cands[i] end
    end
    return cands[1]
end

-- =================================================================
-- CRAFTING RESOURCE READER
-- =================================================================
local function ReadCraftingResource(name)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("MainUI")
    local craft = main and main:FindFirstChild("Crafting")
    local res = craft and craft:FindFirstChild("Resources")
    local entry = res and res:FindFirstChild(name)
    local lbl = entry and entry:FindFirstChild("Label")
    if lbl and lbl:IsA("TextLabel") then
        local n = tonumber((lbl.Text or ""):match("%d+"))
        return n or 0
    end
    return 0
end

-- =================================================================
-- CRATE TIER COLORS
-- =================================================================
local CrateTierColors = {
    [1] = Color3.fromRGB(180, 180, 180),
    [2] = Color3.fromRGB(100, 255, 100),
    [3] = Color3.fromRGB(80, 160, 255),
    [4] = Color3.fromRGB(190, 100, 255),
    [5] = Color3.fromRGB(255, 200, 40),
}
local function GetCrateColor(tier)
    return CrateTierColors[tier] or Color3.fromRGB(255, 80, 80)
end

-- =================================================================
-- DRONE REFS + BACKGROUND PAD CACHE
-- =================================================================
local Drones = { Combat = nil, Healing = nil, ControlPad = nil, SetHover = nil, SetTargeting = nil, MyUserIdTag = nil }
local TargetingModes = { "Closest", "Strongest", "Weakest", "Fastest" }

local DroneRemoteCache = { SetHover = nil, SetTargeting = nil, PadRef = nil, LastCapture = 0 }

local function CaptureDroneRemotes()
    local c  = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local pad = (c  and c:FindFirstChild("Control Pad")) or (bp and bp:FindFirstChild("Control Pad"))
    if not pad then return false end
    local sh = pad:FindFirstChild("SetHover")
    local st = pad:FindFirstChild("SetTargeting")
    if sh then DroneRemoteCache.SetHover = sh end
    if st then DroneRemoteCache.SetTargeting = st end
    DroneRemoteCache.PadRef = pad
    DroneRemoteCache.LastCapture = tick()
    return sh ~= nil and st ~= nil
end

-- ═══ Drone ownership check ═══
-- Priority 1: ToFollow ObjectValue whose .Value == LocalPlayer (most reliable)
-- Priority 2: HasTag(tostring(UserId)) as fallback
local function IsMyDrone(model)
    if not model or not model:IsA("Model") then return false end
    local toFollow = model:FindFirstChild("ToFollow")
    if toFollow and toFollow:IsA("ObjectValue") then
        if toFollow.Value == LocalPlayer then return true end
        -- If ToFollow exists but points elsewhere, this is definitively NOT ours
        return false
    end
    -- Fallback: tag check
    local tag = tostring(LocalPlayer.UserId)
    local ok, isMine = pcall(function() return model:HasTag(tag) end)
    return ok and isMine
end

local function RefreshDroneRefs()
    Drones.MyUserIdTag = tostring(LocalPlayer.UserId)

    -- Iterate all Workspace children looking for OUR drone (by name variants)
    local function findMyDrone(names)
        for _, name in ipairs(names) do
            for _, obj in ipairs(Workspace:GetChildren()) do
                if obj:IsA("Model") and obj.Name == name and IsMyDrone(obj) then
                    return obj
                end
            end
        end
        return nil
    end

    Drones.Combat  = findMyDrone({ "Combat Drone", "CombatDrone" })
    Drones.Healing = findMyDrone({ "Healing Drone", "HealingDrone" })

    local c = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    Drones.ControlPad = (c and c:FindFirstChild("Control Pad")) or (bp and bp:FindFirstChild("Control Pad"))
    if Drones.ControlPad then
        Drones.SetHover     = Drones.ControlPad:FindFirstChild("SetHover")
        Drones.SetTargeting = Drones.ControlPad:FindFirstChild("SetTargeting")
    end
    if not DroneRemoteCache.SetHover or not DroneRemoteCache.SetTargeting then
        CaptureDroneRemotes()
    end
end

local function HasControlPad()
    if State.UseCachedPad then
        if DroneRemoteCache.SetHover and DroneRemoteCache.SetTargeting
           and DroneRemoteCache.PadRef and DroneRemoteCache.PadRef.Parent then
            return true
        end
        return CaptureDroneRemotes()
    end
    local c = LocalPlayer.Character
    return (c and c:FindFirstChild("Control Pad") ~= nil) or false
end

local function WithPadEquipped(fn)
    local c = LocalPlayer.Character
    if not c then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then return false end
    if c:FindFirstChild("Control Pad") then fn(); return true end
    local pad = bp:FindFirstChild("Control Pad")
    if not pad then return false end
    local prev = c:FindFirstChildOfClass("Tool")
    local prevName = prev and prev.Name or nil
    hum:EquipTool(pad)
    task.wait(0.05)
    fn()
    if prevName then
        task.wait(0.05)
        local restored = bp:FindFirstChild(prevName) or c:FindFirstChild(prevName)
        if restored then hum:EquipTool(restored) end
    end
    return true
end

local function SendHover(drone, worldPos)
    if not drone then return false end
    if not DroneRemoteCache.SetHover then CaptureDroneRemotes() end
    if not DroneRemoteCache.SetHover then return false end
    local function fire()
        if worldPos == nil then
            pcall(function() DroneRemoteCache.SetHover:FireServer(drone, nil) end)
        else
            local aimPos = worldPos + Vector3.new(0, State.HoverHeight or 8, 0)
            pcall(function() DroneRemoteCache.SetHover:FireServer(drone, aimPos) end)
        end
    end
    if State.UseCachedPad then fire(); return true end
    if State.AutoEquipPad then return WithPadEquipped(fire) end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Control Pad") then
        fire(); return true
    end
    return false
end

local function SetDroneTargeting(drone, mode)
    if not drone or not table.find(TargetingModes, mode) then return end
    if not DroneRemoteCache.SetTargeting then CaptureDroneRemotes() end
    if not DroneRemoteCache.SetTargeting then return end
    local function fire()
        pcall(function() DroneRemoteCache.SetTargeting:FireServer(drone, mode) end)
    end
    if State.UseCachedPad then fire(); return end
    if State.AutoEquipPad then WithPadEquipped(fire); return end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Control Pad") then
        fire()
    end
end

RefreshDroneRefs()
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    CaptureDroneRemotes()
    RefreshDroneRefs()
end)
task.spawn(function()
    while true do task.wait(1); RefreshDroneRefs() end
end)

-- =================================================================
-- GUARD BASE STREAMING BIND
-- =================================================================
local function UpdateGuardStreamingBind()
    if not State.GuardBaseBindStreaming then return end
    if State.CombatPriority ~= "Guard Base" then return end
    if not State.AutoCombatDrone then return end
    local guardPos = GetGuardBasePosition()
    if not guardPos then return end
    local myPos = getLocalRootPosition()
    local myDist = (myPos - guardPos).Magnitude
    if myDist > 150 then
        local map = Workspace:FindFirstChild("Map")
        local tiles = map and map:FindFirstChild("Tiles")
        local center = tiles and tiles:FindFirstChild("Center")
        if center and center:IsA("Model") then
            local pp = center.PrimaryPart or center:FindFirstChildWhichIsA("BasePart", true)
            if pp then pcall(function() LocalPlayer.ReplicationFocus = pp end) end
        elseif center and center:IsA("BasePart") then
            pcall(function() LocalPlayer.ReplicationFocus = center end)
        end
    else
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then pcall(function() LocalPlayer.ReplicationFocus = hrp end) end
    end
end

local function RestoreGuardStreamingBind()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then pcall(function() LocalPlayer.ReplicationFocus = hrp end) end
end

-- =================================================================
-- CLASS LEVEL / TURRET
-- =================================================================
local function GetClassLevel() return LocalPlayer:GetAttribute("ClassLevel") or 1 end

local function GetActiveTurret()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.SeatPart then return nil end
    local structures = Workspace:FindFirstChild("Structures")
    if not structures then return nil end
    local vehicle = hum.SeatPart
    while vehicle and vehicle.Parent ~= structures do vehicle = vehicle.Parent end
    if not vehicle then return nil end
    local attachments = vehicle:FindFirstChild("Attachments")
    if not attachments then return nil end
    for _, att in ipairs(attachments:GetChildren()) do
        local turret = att:FindFirstChild("Turret")
        if turret then
            local shootRemote = turret:FindFirstChild("Shoot")
            if shootRemote then
                local vertical = att:FindFirstChild("Vertical")
                local barrel = nil
                if vertical then barrel = vertical:FindFirstChild("Barrel1") or vertical:FindFirstChild("Barrel2") end
                return {
                    vehicle = vehicle, attachment = att, turret = turret,
                    shoot = shootRemote, updateAim = turret:FindFirstChild("UpdateAim"),
                    stats = att:FindFirstChild("AttachmentStats"), base = att:FindFirstChild("Base"),
                    vertical = vertical, barrel = barrel,
                }
            end
        end
    end
    return nil
end

-- =================================================================
-- NO RECOIL / MELEE / RELOAD
-- =================================================================
local function ApplyNoRecoilSpread(tool)
    if not tool or not tool:IsA("Tool") then return end
    local s = tool:FindFirstChild("Stats"); if not s then return end
    if State.NoRecoil then pcall(function() s:SetAttribute("Recoil", 0) end) end
    if State.NoSpread then pcall(function() s:SetAttribute("Inaccuracy", 0) end) end
end

local function ApplyMeleeStats(tool)
    if not tool or not tool:IsA("Tool") then return end
    local s = tool:FindFirstChild("Stats"); if not s then return end
    if State.ZeroWindUp then pcall(function() s:SetAttribute("WindUp", 0) end) end
    if State.ZeroEndlag then pcall(function() s:SetAttribute("Endlag", 0) end) end
    if State.SpeedMult ~= 1 then
        pcall(function() s:SetAttribute("AnimSpeed", (s:GetAttribute("AnimSpeed") or 0.7) * State.SpeedMult) end)
    end
end

local function GetMeleeTargets()
    local myPos = getLocalRootPosition(); local targets = {}
    for _, c in ipairs(GetZombieList()) do
        if isZombieEnemy(c) and canBeDamaged(c) then
            local d = (c:GetPivot().Position - myPos).Magnitude
            if d <= State.KillAuraRange then table.insert(targets, { model = c, dist = d }) end
        end
    end
    if State.MeleePriority == "Nearest" then
        table.sort(targets, function(a, b) return a.dist < b.dist end)
    elseif State.MeleePriority == "Lowest HP" then
        table.sort(targets, function(a, b)
            local ha = a.model:FindFirstChildOfClass("Humanoid"); local hb = b.model:FindFirstChildOfClass("Humanoid")
            return (ha and ha.Health or 999) < (hb and hb.Health or 999)
        end)
    end
    local out = {}
    for _, t in ipairs(targets) do table.insert(out, t.model) end
    return out
end

local function ApplyInstantReload(tool)
    if not tool or not tool:IsA("Tool") then return end
    local s = tool:FindFirstChild("Stats")
    if s then
        pcall(function() s:SetAttribute("ReloadTime", 0) end)
        pcall(function() s:SetAttribute("ReloadAnimSpeed", 100) end)
    end
end

local function TriggerRemoteReload(tool)
    if not tool or not tool:IsA("Tool") then return end
    local r = tool:FindFirstChild("Reload")
    if r and r:IsA("RemoteFunction") then pcall(function() r:InvokeServer() end) end
    local sy = tool:FindFirstChild("SyncAmmo")
    if sy and sy:IsA("RemoteEvent") then pcall(function() sy:FireServer() end) end
end

local function SmartReloadGun(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if tool:GetAttribute("ToolType") ~= "Gun" then return false end
    local stats = tool:FindFirstChild("Stats"); if not stats then return false end
    local capacity = stats:GetAttribute("Capacity") or 0
    if capacity <= 0 then return false end
    local ammo = tool:GetAttribute("Ammo") or 0
    if ammo >= capacity then return false end
    local reloadRemote = tool:FindFirstChild("Reload")
    if not reloadRemote then return false end
    if reloadRemote:IsA("RemoteFunction") then
        local ok, result = pcall(function() return reloadRemote:InvokeServer() end)
        if ok and type(result) == "number" then
            pcall(function() tool:SetAttribute("Ammo", result) end)
        end
    elseif reloadRemote:IsA("RemoteEvent") then
        pcall(function() reloadRemote:FireServer() end)
        local sync = tool:FindFirstChild("SyncAmmo")
        if sync then pcall(function() sync:FireServer() end) end
    end
    return true
end

local function ProcessTool(tool)
    if not tool or not tool:IsA("Tool") then return end
    local tt = tool:GetAttribute("ToolType")
    if tt == "Gun" then
        if State.InstantReload then ApplyInstantReload(tool) end
        if State.RemoteReload then TriggerRemoteReload(tool) end
        if State.NoRecoil or State.NoSpread then ApplyNoRecoilSpread(tool) end
    elseif tt == "Melee" then ApplyMeleeStats(tool) end
end

local function ProcessAllTools()
    local char = LocalPlayer.Character
    if char then for _, i in ipairs(char:GetChildren()) do
        if i:IsA("Tool") then ProcessTool(i) end
    end end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then for _, i in ipairs(bp:GetChildren()) do
        if i:IsA("Tool") then ProcessTool(i) end
    end end
end

-- =================================================================
-- AUTO CONSUME
-- =================================================================
local function ItemIsKind(item, kind)
    if not item then return false end
    local it = item:GetAttribute("ItemType")
    if kind == "eat"  and it == "Food"    then return true end
    if kind == "heal" and it == "Medical" then return true end
    return false
end

local function AutoConsumeFromDropped(kind)
    local dropped = Workspace:FindFirstChild("DroppedItems")
    if not dropped or not Remotes.PickUpItem then return false end
    local myPos = getLocalRootPosition()
    for _, item in ipairs(dropped:GetChildren()) do
        if item:IsA("Model") and ItemIsKind(item, kind) then
            local primary = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
            if primary then
                local d = (primary.Position - myPos).Magnitude
                if d <= State.AutoLootRange then
                    pcall(function() Remotes.PickUpItem:FireServer(item) end)
                    return true
                end
            end
        end
    end
    return false
end

local function FindConsumable(kind)
    local containers = {}
    if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then table.insert(containers, bp) end
    for _, container in ipairs(containers) do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and ItemIsKind(tool, kind) then return tool end
        end
    end
    return nil
end

local function UseConsumable(tool)
    if not tool then return false end
    local used = false
    for _, child in ipairs(tool:GetChildren()) do
        if child:IsA("RemoteEvent") then
            pcall(function() child:FireServer() end); used = true
        elseif child:IsA("RemoteFunction") then
            pcall(function() child:InvokeServer() end); used = true
        end
    end
    if not used then pcall(function() tool:Activate() end) end
    return true
end

local function AutoUseBackpackTool(kind)
    local tool = FindConsumable(kind)
    if not tool then return false end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if LocalPlayer:GetAttribute("BackpackLocked") then return false end
    if char:GetAttribute("InVehicle") or char:GetAttribute("Dead") then return false end
    local prev = char:FindFirstChildOfClass("Tool")
    local prevName = prev and prev.Name or nil
    hum:EquipTool(tool)
    task.wait(0.15)
    UseConsumable(tool)
    task.wait(0.4)
    if prevName and prevName ~= tool.Name then
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        local restore = (bp and bp:FindFirstChild(prevName)) or char:FindFirstChild(prevName)
        if restore then hum:EquipTool(restore) end
    end
    return true
end

local function AutoUseConsumable(kind)
    if AutoConsumeFromDropped(kind) then return true end
    return AutoUseBackpackTool(kind)
end

-- =================================================================
-- LOOT HELPERS
-- =================================================================
local function ShouldLoot(itemName)
    if next(Filters.LootItems) == nil then return true end
    return Filters.LootItems[itemName] == true
end

local function ReadBackpackStorage()
    local bs = ReplicatedStorage:FindFirstChild("BackpackStorage")
    if not bs then return {}, 0, {} end
    local items, byType, total = {}, {}, 0
    for _, i in ipairs(bs:GetChildren()) do
        local t = i:GetAttribute("ItemType") or "Unknown"
        table.insert(items, { name = i.Name, type = t, attrs = i:GetAttributes() })
        byType[t] = (byType[t] or 0) + 1; total += 1
    end
    return items, total, byType
end

-- =================================================================
-- PROMPTS
-- =================================================================
local function MakePromptInstant(prompt)
    if prompt:IsA("ProximityPrompt") then
        if Prompts.OriginalHold[prompt] == nil then Prompts.OriginalHold[prompt] = prompt.HoldDuration end
        pcall(function() prompt.HoldDuration = 0 end)
    end
end
local function ApplyInstantPrompts()
    for _, d in ipairs(Workspace:GetDescendants()) do MakePromptInstant(d) end
end
local function RestorePrompts()
    for p, o in pairs(Prompts.OriginalHold) do
        if p and p.Parent then pcall(function() p.HoldDuration = o end) end
    end
end

-- =================================================================
-- WINDOW
-- =================================================================
local Window = Rayfield:CreateWindow({
    name = "KissoHub", subtitle = "Survive the Apocalypse",
    sidebarLayout = true, icon = ASSET_ICON,
    theme = {
        WindowColor = Color3.fromRGB(15, 17, 26), SurfaceStroke = Color3.fromRGB(0, 200, 255),
        TitlingColor = Color3.fromRGB(255, 255, 255), ContentColor = Color3.fromRGB(255, 255, 255),
        ElementTextHoverColor = Color3.fromRGB(255, 255, 255), ActionColor = Color3.fromRGB(0, 200, 255),
        TabColor = Color3.fromRGB(255, 255, 255), TabBackground = Color3.fromRGB(25, 20, 38),
        TabStroke = Color3.fromRGB(0, 200, 255), ElementGradient = Color3.fromRGB(22, 20, 35),
        ElementStroke = Color3.fromRGB(60, 45, 90), ElementStrokeHover = Color3.fromRGB(190, 40, 220),
        ElementTransparency = 0, StatBackground = Color3.fromRGB(20, 18, 30),
        AccentColor = Color3.fromRGB(190, 40, 220), AccentStroke = Color3.fromRGB(0, 200, 255),
        ToggleTrack = Color3.fromRGB(35, 30, 50), ToggleKnobOff = Color3.fromRGB(200, 200, 220),
        FieldBackground = Color3.fromRGB(25, 22, 38), PlaceholderColor = Color3.fromRGB(255, 255, 255),
        DropdownHighlight = Color3.fromRGB(190, 40, 220),
    },
    configuration = { autoSave = true, autoLoad = true, fileName = "STAPrefs", customFolder = "KissoHubFolder" },
})

local StateTag = Window:CreateTag({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
Window:CreateTag({ text = HUB_VERSION, color = Color3.fromRGB(0, 200, 255) })

local function Toast(t, s) pcall(function() Window:Toast({ title = t, subtitle = s, position = "Top" }) end) end
local function Notify(t, c, d) pcall(function() Window:Notify({ title = t or "KissoHub", content = c or "", duration = d or 4 }) end) end

task.spawn(function()
    local lastLevel = nil
    while task.wait(1) do
        local lvl = GetClassLevel()
        if lvl ~= lastLevel then
            State.ClassLevel = lvl
            lastLevel = lvl
            if lvl < 1 then State.AutoCombatDrone = false end
        end
    end
end)

-- =================================================================
-- HOME TAB
-- =================================================================
local HomeTab = Window:CreateTab({ name = "🏠 Home" })
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

    HomeTab:CreateDivider({ text = "performance" })
    ToggleRefs.LiveStats = HomeTab:CreateToggle({
        name = "⚡ Live Stats Refresh (0.5s)", flag = "LiveStats", value = true,
        callback = function(v)
            State.LiveStats = v
            if v then Toast("Live Stats", "Enabled — stats update every 0.5s")
            else Toast("Live Stats", "Disabled — 2s safety refresh") end
        end,
    })

    HomeTab:CreateDivider({ text = "crafting resources" })
    HomeTab:CreateSection({ name = "⚙️ Resources (live)" })
    local resGrid = HomeTab:CreateGroup()
    local rl = resGrid:CreateGroup({ direction = "column" })
    local rr = resGrid:CreateGroup({ direction = "column" })
    Stats.Scrap     = rl:CreateStat({ name = "🔩 Scrap", value = 0, compact = true })
    Stats.Batteries = rl:CreateStat({ name = "🔋 Batteries", value = 0, compact = true })
    Stats.Hearts    = rr:CreateStat({ name = "❤️ Hearts", value = 0, compact = true })

    HomeTab:CreateDivider({ text = "backpack summary" })
    HomeTab:CreateSection({ name = "🎒 Backpack" })
    local bpgrid = HomeTab:CreateGroup()
    local bpl = bpgrid:CreateGroup({ direction = "column" })
    local bpr = bpgrid:CreateGroup({ direction = "column" })
    Stats.BPTotal = bpl:CreateStat({ name = "📦 Total", value = 0, compact = true })
    Stats.BPFuel  = bpl:CreateStat({ name = "⛽ Fuel", value = 0, compact = true })
    Stats.BPFood  = bpl:CreateStat({ name = "🍞 Food", value = 0, compact = true })
    Stats.BPAmmo  = bpr:CreateStat({ name = "💥 Ammo", value = 0, compact = true })
    Stats.BPOther = bpr:CreateStat({ name = "📦 Other", value = 0, compact = true })

    HomeTab:CreateDivider({ text = "operator status" })
    HomeTab:CreateSection({ name = "🤖 Operator" })
    local opGrid = HomeTab:CreateGroup()
    local opl = opGrid:CreateGroup({ direction = "column" })
    local opr = opGrid:CreateGroup({ direction = "column" })
    Stats.ClassLevel = opl:CreateStat({ name = "🎖️ Class Lvl", value = 1, compact = true })
    Stats.DroneState = opl:CreateStat({ name = "🤖 Drones", value = 0, compact = true })
    Stats.ReviveCD   = opr:CreateStat({ name = "💚 Revive CD", value = 0, suffix = " s", compact = true })
    Stats.SelfRevCD  = opr:CreateStat({ name = "🔄 Self-Rev CD", value = 0, suffix = " s", compact = true })

    HomeTab:CreateDivider({ text = "server" })
    HomeTab:CreateSection({ name = "🌐 Server Utilities" })
    HomeTab:CreateButton({ name = "📋 Copy Job ID", callback = function()
        if setclipboard then setclipboard(game.JobId); Toast("Copied", "Job ID copied") end
    end })
    HomeTab:CreateButton({ name = "🔄 Rejoin Server", callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end })
end

-- =================================================================
-- PLAYER TAB
-- =================================================================
local PlayerTab = Window:CreateTab({ name = "❤️ Player" })
do
    PlayerTab:CreateSection({ name = "❤️ Auto Heal" })
    ToggleRefs.AutoHeal = PlayerTab:CreateToggle({ name = "Auto Heal", flag = "AutoHeal", value = false,
        callback = function(v)
            State.AutoHeal = v
            Toast("Auto Heal", v and "Enabled" or "Disabled")
        end })
    PlayerTab:CreateSlider({ name = "Heal Below HP %", flag = "AutoHealThreshold",
        range = {10, 90}, increment = 5, value = 50, suffix = " %",
        callback = function(v) State.AutoHealThreshold = v end })

    PlayerTab:CreateDivider({ text = "hunger" })
    PlayerTab:CreateSection({ name = "🍞 Auto Eat" })
    ToggleRefs.AutoEat = PlayerTab:CreateToggle({ name = "Auto Eat", flag = "AutoEat", value = false,
        callback = function(v)
            State.AutoEat = v
            Toast("Auto Eat", v and "Enabled" or "Disabled")
        end })
    PlayerTab:CreateSlider({ name = "Eat Below Hunger %", flag = "AutoEatThreshold",
        range = {10, 90}, increment = 5, value = 30, suffix = " %",
        callback = function(v) State.AutoEatThreshold = v end })
end

-- =================================================================
-- OPERATOR TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "🤖 Operator" })

    tab:CreateSection({ name = "⚡ Quick Actions" })

    tab:CreateButton({ name = "🏠 Combat Drone Follow Me", callback = function()
        RefreshDroneRefs()
        if not HasControlPad() then Notify("No Control Pad", "Equip once first", 3); return end
        if State.AutoCombatDrone then
            State.AutoCombatDrone = false
            pcall(function() UI.CombatAutoToggle:Set(false) end)
        end
        if State.CombatFollowTarget then
            State.CombatFollowTarget = nil
            pcall(function() Filters.CombatFollowDropdown:Set({}) end)
        end
        if Drones.Combat and DroneRemoteCache.SetHover then
            SendHover(Drones.Combat, nil)
            Toast("Combat Drone", "Following you")
        end
    end })

    tab:CreateButton({ name = "💚 Healing Drone Follow Me", callback = function()
        RefreshDroneRefs()
        if not HasControlPad() then Notify("No Control Pad", "Equip once first", 3); return end
        if State.SmartHeal then
            State.SmartHeal = false
            pcall(function() UI.SmartHealToggle:Set(false) end)
        end
        if State.HealingFollowTarget then
            State.HealingFollowTarget = nil
            pcall(function() Filters.HealingFollowDropdown:Set({}) end)
        end
        if Drones.Healing and DroneRemoteCache.SetHover then
            SendHover(Drones.Healing, nil)
            Toast("Healing Drone", "Following you")
        end
    end })

    tab:CreateButton({ name = "🛑 Recall Both Drones (Follow Me)", callback = function()
        RefreshDroneRefs()
        if not HasControlPad() then Notify("No Control Pad", "Equip once first", 3); return end
        if State.AutoCombatDrone then
            State.AutoCombatDrone = false
            pcall(function() UI.CombatAutoToggle:Set(false) end)
        end
        if State.SmartHeal then
            State.SmartHeal = false
            pcall(function() UI.SmartHealToggle:Set(false) end)
        end
        State.CombatFollowTarget = nil
        State.HealingFollowTarget = nil
        pcall(function() Filters.CombatFollowDropdown:Set({}) end)
        pcall(function() Filters.HealingFollowDropdown:Set({}) end)
        if Drones.Combat and DroneRemoteCache.SetHover then SendHover(Drones.Combat, nil) end
        if Drones.Healing and DroneRemoteCache.SetHover then SendHover(Drones.Healing, nil) end
        Toast("Drones", "Both recalled to follow you")
    end })

    tab:CreateDivider({ text = "combat drone follow" })
    tab:CreateSection({ name = "⚔️ Combat Drone Follow" })

    Filters.CombatFollowDropdown = tab:CreateDropdown({
        name = "Follow Target", flag = "CombatFollowTarget",
        options = (function()
            local out = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then table.insert(out, p.Name) end
            end
            return #out > 0 and out or {"(No other players)"}
        end)(),
        value = {}, multiSelect = false,
        callback = function(o)
            State.CombatFollowTarget = type(o) == "table" and o[1] or o
            if State.CombatFollowTarget and State.CombatFollowTarget ~= "(No other players)" then
                if State.AutoCombatDrone then
                    State.AutoCombatDrone = false
                    pcall(function() UI.CombatAutoToggle:Set(false) end)
                    Toast("Auto Combat Drone", "Turned off")
                end
                Toast("Combat Drone", "Following " .. State.CombatFollowTarget)
            end
        end,
    })

    tab:CreateButton({ name = "🔄 Refresh Player List", callback = function()
        local out = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(out, p.Name) end
        end
        if #out == 0 then out = {"(No other players)"} end
        pcall(function() Filters.CombatFollowDropdown:Refresh(out) end)
        Toast("Refreshed", #out .. " players")
    end })

    tab:CreateDivider({ text = "healing drone" })
    tab:CreateSection({ name = "💚 Healing Drone" })

    Filters.HealingFollowDropdown = tab:CreateDropdown({
        name = "Follow Target", flag = "HealingFollowTarget",
        options = (function()
            local out = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then table.insert(out, p.Name) end
            end
            return #out > 0 and out or {"(No other players)"}
        end)(),
        value = {}, multiSelect = false,
        callback = function(o)
            State.HealingFollowTarget = type(o) == "table" and o[1] or o
            if State.HealingFollowTarget and State.HealingFollowTarget ~= "(No other players)" then
                if State.SmartHeal then
                    State.SmartHeal = false
                    pcall(function() UI.SmartHealToggle:Set(false) end)
                    Toast("Smart Heal", "Disabled (manual follow selected)")
                end
                Toast("Healing Drone", "Following " .. State.HealingFollowTarget)
            end
        end,
    })

    tab:CreateButton({ name = "🔄 Refresh Player List", callback = function()
        local out = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(out, p.Name) end
        end
        if #out == 0 then out = {"(No other players)"} end
        pcall(function() Filters.HealingFollowDropdown:Refresh(out) end)
        Toast("Refreshed", #out .. " players")
    end })

    tab:CreateDivider({ text = "smart heal" })
    tab:CreateSection({ name = "🧠 Smart Heal (Auto-Follow Lowest HP Teammate)" })

    tab:CreateText({ name = "How it works",
        text = "• Scans all other players every 0.5s\n" ..
               "• Picks the teammate with lowest HP below threshold\n" ..
               "• Sends Healing Drone to hover above them\n" ..
               "• When teammate recovers or leaves, follows next target\n" ..
               "• If nobody is hurt, drone returns to you" })

    UI.SmartHealToggle = tab:CreateToggle({ name = "Enable Smart Heal", flag = "SmartHeal", value = false,
        callback = function(v)
            State.SmartHeal = v
            if v then
                if State.HealingFollowTarget then
                    State.HealingFollowTarget = nil
                    pcall(function() Filters.HealingFollowDropdown:Set({}) end)
                end
                if not HasControlPad() then
                    Notify("No Control Pad", "Equip once to seed cache", 3)
                    State.SmartHeal = false
                    pcall(function() UI.SmartHealToggle:Set(false) end)
                    return
                end
                Toast("Smart Heal", "Monitoring teammates at <" .. State.SmartHealThreshold .. "% HP")
            else
                Toast("Smart Heal", "Disabled")
            end
        end })

    tab:CreateSlider({ name = "Heal Below HP %", flag = "SmartHealThreshold",
        range = {20, 95}, increment = 5, value = 70, suffix = " %",
        callback = function(v)
            State.SmartHealThreshold = v
            if State.SmartHeal then
                Toast("Smart Heal", "Threshold → " .. v .. "%")
            end
        end })

    tab:CreateDivider({ text = "combat drone" })
    tab:CreateSection({ name = "⚔️ Combat Drone — Auto Mode" })

    UI.CombatAutoToggle = tab:CreateToggle({ name = "Auto Combat Drone", flag = "AutoCombatDrone", value = false,
        callback = function(v)
            State.AutoCombatDrone = v
            RefreshDroneRefs()
            if v then
                if State.CombatFollowTarget then
                    State.CombatFollowTarget = nil
                    pcall(function() Filters.CombatFollowDropdown:Set({}) end)
                    Toast("Combat Drone", "Follow Target cleared")
                end
                if not HasControlPad() then
                    Notify("No Control Pad", "Equip once to seed cache", 4)
                elseif not Drones.Combat then
                    Notify("Missing", "Combat Drone not found", 3)
                else
                    Toast("Combat Drone", "Hunting")
                end
            else
                RestoreGuardStreamingBind()
                if Drones.Combat and DroneRemoteCache.SetHover then
                    pcall(function() DroneRemoteCache.SetHover:FireServer(Drones.Combat, nil) end)
                end
                Toast("Combat Drone", "Idle")
            end
        end })

    tab:CreateSlider({ name = "Auto Combat Range", flag = "CombatRange",
        range = {50, 2000}, increment = 25, value = 500, suffix = " studs",
        callback = function(v) State.CombatRange = v end })

    tab:CreateDropdown({ name = "Target Priority", flag = "CombatPriority",
        options = {"Nearest to Me", "Nearest to Drone", "Guard Base", "Lowest HP", "Highest HP", "Random"},
        value = {"Nearest to Me"}, multiSelect = false,
        callback = function(o)
            local prev = State.CombatPriority
            State.CombatPriority = type(o) == "table" and o[1] or o
            if prev == "Guard Base" and State.CombatPriority ~= "Guard Base" then
                RestoreGuardStreamingBind()
            end
            if State.CombatPriority == "Guard Base" then
                local pos = GetGuardBasePosition()
                if pos then
                    Toast("Guard Base", string.format("Guarding (%.0f, %.0f, %.0f)", pos.X, pos.Y, pos.Z))
                else
                    Notify("Guard Base", "Map.Tiles.Center not found", 4)
                end
            end
        end })

    tab:CreateSlider({ name = "Guard Base Radius", flag = "GuardBaseRadius",
        range = {25, 500}, increment = 5, value = 120, suffix = " studs",
        callback = function(v) State.GuardBaseRadius = v end })

    tab:CreateButton({ name = "📍 Set Guard Position Here", callback = function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            State.GuardBasePosition = hrp.Position
            Toast("Guard Base", string.format("Set to (%.0f, %.0f, %.0f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z))
        else
            Notify("Set Guard", "No character", 3)
        end
    end })

    tab:CreateButton({ name = "🔄 Re-detect Base (Map.Tiles.Center)", callback = function()
        State.GuardBasePosition = nil
        local resolved = ResolveGuardBasePosition()
        if resolved then
            State.GuardBasePosition = resolved
            Toast("Guard Base", string.format("Detected at (%.0f, %.0f, %.0f)", resolved.X, resolved.Y, resolved.Z))
        else
            Notify("Guard Base", "Not found", 4)
        end
    end })

    UI.GuardBaseBindToggle = tab:CreateToggle({ name = "🔗 Bind Streaming to Base", flag = "GuardBaseBindStreaming", value = false,
        callback = function(v)
            State.GuardBaseBindStreaming = v
            if v then Toast("Guard Streaming", "Enemies near base stream in even when you're far")
            else RestoreGuardStreamingBind(); Toast("Guard Streaming", "Restored normal") end
        end })

    tab:CreateSlider({ name = "Hover Interval", flag = "HoverInterval",
        range = {0.1, 1.0}, increment = 0.05, value = 0.25, suffix = " s",
        callback = function(v) State.HoverInterval = v end })

    tab:CreateSlider({ name = "Hover Distance (vertical)", flag = "HoverHeight",
        range = {0, 25}, increment = 1, value = 8, suffix = " studs",
        callback = function(v) State.HoverHeight = v end })

    tab:CreateDropdown({ name = "Native Targeting", flag = "DroneAIMode",
        options = TargetingModes, value = {"Closest"}, multiSelect = false,
        callback = function(o)
            State.DroneAIMode = type(o) == "table" and o[1] or o
            if Drones.Combat then SetDroneTargeting(Drones.Combat, State.DroneAIMode) end
        end })

    tab:CreateDivider({ text = "on-screen overlay" })
    tab:CreateSection({ name = "📺 On-Screen Quick Actions" })

    UI.ShowOnScreenUIToggle = tab:CreateToggle({ name = "Show On-Screen Quick Actions", flag = "ShowOnScreenUI", value = false,
        callback = function(v)
            State.ShowOnScreenUI = v
            if OnScreenUI and OnScreenUI.Gui then
                OnScreenUI.Gui.Enabled = v
            end
            Toast("On-Screen UI", v and "Visible" or "Hidden")
        end })

    tab:CreateDivider({ text = "target scanning" })
    tab:CreateSection({ name = "🎯 Target Scanning" })

    local scanGrid = tab:CreateGroup()
    local sl = scanGrid:CreateGroup({ direction = "column" })
    local sr = scanGrid:CreateGroup({ direction = "column" })
    Stats.TargetsCached = sl:CreateStat({ name = "📋 Cached", value = 0, compact = true })
    Stats.LastScan = sr:CreateStat({ name = "⏱️ Ago", value = 0, suffix = " s", compact = true })

    tab:CreateButton({ name = "🔄 Refresh Target List", callback = function()
        ScanZombies()
        Toast("Targets Scanned", ZombieCache.totalFound .. " enemies cached")
    end })

    tab:CreateSlider({ name = "Auto-Rescan Interval", flag = "AutoRescanInterval",
        range = {0, 60}, increment = 1, value = 25, suffix = " s",
        callback = function(v)
            State.AutoRescanInterval = v
            if v == 0 then Toast("Target Scan", "Manual only — click Refresh")
            else Toast("Target Scan", "Rescan every " .. v .. "s") end
        end })

    tab:CreateDivider({ text = "background control pad" })
    tab:CreateSection({ name = "🔓 Background Control Pad" })

    tab:CreateToggle({ name = "🔓 Enable Background Pad", flag = "UseCachedPad", value = true,
        callback = function(v)
            State.UseCachedPad = v
            if v then
                State.AutoEquipPad = false
                CaptureDroneRemotes()
                local ok = DroneRemoteCache.SetHover and DroneRemoteCache.SetTargeting
                Toast("Control Pad", ok and "Remote cache active"
                                      or "Cache empty — equip pad once")
            else
                Toast("Control Pad", "Disabled")
            end
        end })

    tab:CreateToggle({ name = "🔁 Auto Equip-Swap (fallback)", flag = "AutoEquipPad", value = false,
        callback = function(v)
            State.AutoEquipPad = v
            if v then
                State.UseCachedPad = false
                Toast("Control Pad", "Server-validated mode")
            end
        end })

    tab:CreateButton({ name = "🔓 Refresh Pad Cache Now", callback = function()
        local ok = CaptureDroneRemotes()
        if ok then Toast("Control Pad", "Cache refreshed")
        else Notify("Cache Failed", "Equip the pad once, then retry", 3) end
    end })
end

-- =================================================================
-- GUN COMBAT TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "🔫 Gun Combat" })
    tab:CreateSection({ name = "🔫 Auto-Shoot (Gun + Turret)" })
    ToggleRefs.AutoShoot = tab:CreateToggle({ name = "Enable Auto-Shoot", flag = "AutoShoot", value = false,
        callback = function(v) State.AutoShoot = v end })
    tab:CreateSlider({ name = "Auto-Shoot Range", flag = "AutoShootRange",
        range = {25,1000}, increment = 25, value = 500, suffix = " studs",
        callback = function(v) State.AutoShootRange = v end })
    tab:CreateDropdown({ name = "Target Priority", flag = "AutoShootPriority",
        options = {"Nearest","Lowest HP","Highest HP","Random"}, value = {"Nearest"}, multiSelect = false,
        callback = function(o) State.AutoShootPriority = type(o) == "table" and o[1] or o end })

    tab:CreateDivider({ text = "rapid fire" })
    tab:CreateSection({ name = "⚡ Rapid Fire" })
    ToggleRefs.RapidFire = tab:CreateToggle({ name = "Enable Rapid Fire", flag = "RapidFire", value = false,
        callback = function(v)
            State.RapidFire = v
            Toast("Rapid Fire", v and ("Enabled — " .. State.RapidFireMult .. "x") or "Disabled")
        end })
    tab:CreateSlider({ name = "Fire Rate Multiplier", flag = "RapidFireMult",
        range = {1, 10}, increment = 0.5, value = 2, suffix = "x",
        callback = function(v)
            State.RapidFireMult = v
            if State.RapidFire then Toast("Rapid Fire", v .. "x") end
        end })

    tab:CreateDivider({ text = "precision" })
    tab:CreateToggle({ name = "🎯 Precise Headshot", flag = "PreciseHeadshot", value = true,
        callback = function(v) State.PreciseHeadshot = v end })

    tab:CreateDivider({ text = "filters" })
    tab:CreateToggle({ name = "Silent Aim", flag = "SilentAim", value = false,
        callback = function(v) State.SilentAim = v end })
    tab:CreateToggle({ name = "Check Damageable", flag = "CheckDamageable", value = true,
        callback = function(v) State.CheckDamageable = v end })

    tab:CreateDivider({ text = "recoil & spread" })
    tab:CreateToggle({ name = "No Recoil", flag = "NoRecoil", value = false,
        callback = function(v) State.NoRecoil = v; if v then ProcessAllTools() end end })
    tab:CreateToggle({ name = "No Spread", flag = "NoSpread", value = false,
        callback = function(v) State.NoSpread = v; if v then ProcessAllTools() end end })

    tab:CreateDivider({ text = "reload" })
    tab:CreateToggle({ name = "Auto Reload", flag = "AutoReload", value = false, callback = function(v) State.AutoReload = v end })
    tab:CreateToggle({ name = "Instant Reload", flag = "InstantReload", value = false,
        callback = function(v) State.InstantReload = v; if v then ProcessAllTools() end end })
    tab:CreateToggle({ name = "Remote Bypass Reload", flag = "RemoteReload", value = false,
        callback = function(v) State.RemoteReload = v; if v then ProcessAllTools() end end })
    tab:CreateToggle({ name = "Auto-Reload Holstered", flag = "AutoReloadHolstered", value = false,
        callback = function(v) State.AutoReloadHolstered = v end })
end

-- =================================================================
-- MELEE TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "⚔️ Melee" })
    tab:CreateSection({ name = "⚔️ Auto Combat" })
    tab:CreateToggle({ name = "Auto Swing", flag = "AutoSwing", value = false, callback = function(v) State.AutoSwing = v end })
    ToggleRefs.KillAura = tab:CreateToggle({ name = "Kill Aura", flag = "KillAura", value = false, callback = function(v) State.KillAura = v end })
    tab:CreateSlider({ name = "Kill Aura Range", flag = "KillAuraRange", range = {4,30}, increment = 1, value = 12, suffix = " studs", callback = function(v) State.KillAuraRange = v end })
    tab:CreateDivider({ text = "stats" })
    tab:CreateToggle({ name = "Zero WindUp", flag = "ZeroWindUp", value = false, callback = function(v) State.ZeroWindUp = v; ProcessAllTools() end })
    tab:CreateToggle({ name = "Zero Endlag", flag = "ZeroEndlag", value = false, callback = function(v) State.ZeroEndlag = v; ProcessAllTools() end })
    tab:CreateSlider({ name = "Animation Speed", flag = "SpeedMult", range = {1,5}, increment = 0.5, value = 1, suffix = "x", callback = function(v) State.SpeedMult = v; ProcessAllTools() end })
end

-- =================================================================
-- ITEMS TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "📦 Items" })

    tab:CreateSection({ name = "🎁 Auto Loot" })
    ToggleRefs.AutoLoot = tab:CreateToggle({ name = "Auto Loot", flag = "AutoLoot", value = false, callback = function(v) State.AutoLoot = v end })
    tab:CreateSlider({ name = "Loot Range", flag = "AutoLootRange", range = {5,25}, increment = 1, value = 20, suffix = " studs", callback = function(v) State.AutoLootRange = v end })
    ToggleRefs.AutoStore = tab:CreateToggle({ name = "Auto-Store After Pickup", flag = "AutoStore", value = false, callback = function(v) State.AutoStore = v end })
    ToggleRefs.PreventBaseLoot = tab:CreateToggle({ name = "🛡️ Prevent Base Looting", flag = "PreventBaseLoot", value = false,
        callback = function(v)
            State.PreventBaseLoot = v
            Toast("Base Loot Guard", v and "Auto-Loot disabled at base" or "Disabled")
        end })

    tab:CreateDivider({ text = "loot filter" })
    tab:CreateSection({ name = "🎯 Auto-Loot Filter" })
    Filters.LootDropdown = tab:CreateDropdown({
        name = "Items to Auto-Loot", flag = "LootFilterItems",
        options = ItemDatabase.All, value = {}, multiSelect = true,
        callback = function(sel)
            table.clear(Filters.LootItems)
            if type(sel) == "table" then for _, n in ipairs(sel) do Filters.LootItems[n] = true end end
        end,
    })

    tab:CreateToggle({ name = "Multi-Select Mode (Loot Presets)", flag = "LootMultiSelect", value = false,
        callback = function(v) State.LootMultiSelect = v; Toast("Loot Mode", v and "MULTI-SELECT" or "REPLACE") end })

    local function ApplyLootPreset(catName)
        local list = ItemDatabase.ByCategory[catName]
        if not list then Notify("Missing", catName, 2); return end
        if State.LootMultiSelect then
            local allSel = true
            for _, n in ipairs(list) do if not Filters.LootItems[n] then allSel = false break end end
            if allSel then
                for _, n in ipairs(list) do Filters.LootItems[n] = nil end
                Toast("Loot −", catName .. " removed")
            else
                for _, n in ipairs(list) do Filters.LootItems[n] = true end
                Toast("Loot +", catName .. " added (" .. #list .. ")")
            end
            local out = {}
            for n, _ in pairs(Filters.LootItems) do table.insert(out, n) end
            pcall(function() Filters.LootDropdown:Set(out) end)
        else
            table.clear(Filters.LootItems)
            for _, n in ipairs(list) do Filters.LootItems[n] = true end
            pcall(function() Filters.LootDropdown:Set(list) end)
            Toast("Loot Filter", catName .. " (" .. #list .. ")")
        end
    end

    local g = tab:CreateGroup()
    local l = g:CreateGroup({ direction = "column" })
    local r = g:CreateGroup({ direction = "column" })
    l:CreateButton({ name = "💥 All Ammo",       callback = function() ApplyLootPreset("Ammo") end })
    l:CreateButton({ name = "🍞 All Food",       callback = function() ApplyLootPreset("Food") end })
    l:CreateButton({ name = "🔫 All Guns",       callback = function() ApplyLootPreset("Tool_Guns") end })
    l:CreateButton({ name = "⚔️ All Melee",      callback = function() ApplyLootPreset("Tool_Melee") end })
    l:CreateButton({ name = "🛡️ All Armor",      callback = function() ApplyLootPreset("Armor") end })
    l:CreateButton({ name = "💊 All Medical",    callback = function() ApplyLootPreset("Tool_Medical") end })
    r:CreateButton({ name = "⛽ All Fuel",       callback = function() ApplyLootPreset("Fuel") end })
    r:CreateButton({ name = "🔧 All Resources",  callback = function() ApplyLootPreset("Resources") end })
    r:CreateButton({ name = "💎 Alien Crystals", callback = function() ApplyLootPreset("AlienCrystals") end })
    r:CreateButton({ name = "🎒 All Backpacks",  callback = function() ApplyLootPreset("Tool_Backpacks") end })
    r:CreateButton({ name = "🚗 Car Attach.",    callback = function() ApplyLootPreset("Tool_CarAttachments") end })
    r:CreateButton({ name = "🌐 Loot All Items", callback = function()
        table.clear(Filters.LootItems)
        pcall(function() Filters.LootDropdown:Set({}) end)
        Toast("Loot Filter", "Empty = loot EVERYTHING")
    end })

    tab:CreateDivider()
    tab:CreateButton({ name = "🔄 Refresh Item Database", callback = function()
        BuildItemDatabase()
        pcall(function() Filters.LootDropdown:Refresh(ItemDatabase.All) end)
        Toast("Refreshed", #ItemDatabase.All .. " items")
    end })
end

-- =================================================================
-- ESP TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "👁️ ESP" })

    local function CreateESP(target, tag, customName, color)
        if not target then return end
        local adornee = target:IsA("BasePart") and target
            or (target:IsA("Model") and (target.PrimaryPart or target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildOfClass("BasePart")))
        if not adornee then return end
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local dt = ""
        if hrp and State.ESPShowDistance then dt = " [" .. math.floor((hrp.Position - adornee.Position).Magnitude) .. "m]" end
        local display = State.ESPShowNames and ((customName or target.Name) .. dt) or dt:gsub("^%s+","")
        local existing = adornee:FindFirstChild(tag)
        if existing then
            local lbl = existing:FindFirstChildOfClass("TextLabel")
            if lbl then lbl.Text = display; lbl.TextColor3 = color end
            return
        end
        local gui = Instance.new("BillboardGui")
        gui.Name = tag; gui.Adornee = adornee; gui.Size = UDim2.new(0,200,0,30)
        gui.StudsOffset = Vector3.new(0,2.5,0); gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.Parent = adornee
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1; lbl.Text = display
        lbl.TextColor3 = color; lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.new(0,0,0)
        lbl.TextSize = 14; lbl.Font = Enum.Font.SourceSansBold; lbl.Parent = gui
    end

    local function RemoveESP(parent, tag)
        if not parent then return end
        for _, i in ipairs(parent:GetDescendants()) do
            if i:IsA("BillboardGui") and i.Name == tag then i:Destroy() end
        end
    end

    tab:CreateSection({ name = "⚙️ Config" })
    tab:CreateToggle({ name = "Show Names", flag = "ESPNames", value = true, callback = function(v) State.ESPShowNames = v end })
    tab:CreateToggle({ name = "Show Distance", flag = "ESPDistance", value = true, callback = function(v) State.ESPShowDistance = v end })

    tab:CreateDivider({ text = "characters" })
    ESPRefs.Toggles.ZombieESP = tab:CreateToggle({ name = "Zombie ESP", flag = "ZombieESP", value = false,
        callback = function(v)
            State.ZombieESP = v
            if not v then RemoveESP(Workspace:FindFirstChild("Characters"), "ZombieESP")
            else task.spawn(function()
                while State.ZombieESP do
                    for _, c in ipairs(GetZombieList()) do
                        if isZombieEnemy(c) and canBeDamaged(c) then
                            CreateESP(c, "ZombieESP", c.Name, Color3.fromRGB(255,50,50))
                        end
                    end
                    task.wait(0.2)
                end
            end) end
        end })

    ESPRefs.Toggles.PlayerESP = tab:CreateToggle({ name = "Player ESP", flag = "PlayerESP", value = false,
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

    tab:CreateDivider({ text = "items" })
    ToggleRefs.ItemESP = tab:CreateToggle({ name = "Enable Item ESP", flag = "ItemESP", value = false,
        callback = function(v)
            State.ItemESP = v
            if not v then RemoveESP(Workspace:FindFirstChild("DroppedItems"), "ItemESP") end
        end })

    Filters.ESPDropdown = tab:CreateDropdown({
        name = "Items to Highlight", flag = "ESPFilterItems",
        options = ItemDatabase.All, value = {}, multiSelect = true,
        callback = function(sel)
            table.clear(Filters.ESPItems)
            if type(sel) == "table" then for _, n in ipairs(sel) do Filters.ESPItems[n] = true end end
        end,
    })

    tab:CreateDivider({ text = "esp presets" })
    tab:CreateSection({ name = "⚡ Quick Select (ESP)" })

    tab:CreateToggle({ name = "Multi-Select Mode (Stack Presets)", flag = "ESPMultiSelect", value = false,
        callback = function(v) State.ESPMultiSelect = v; Toast("ESP Mode", v and "MULTI-SELECT" or "REPLACE") end })

    local function ApplyESPPreset(catName)
        local list = ItemDatabase.ByCategory[catName]
        if not list then Notify("Missing", catName, 2); return end
        if State.ESPMultiSelect then
            local allSel = true
            for _, n in ipairs(list) do if not Filters.ESPItems[n] then allSel = false break end end
            if allSel then
                for _, n in ipairs(list) do Filters.ESPItems[n] = nil end
                Toast("ESP −", catName .. " removed")
            else
                for _, n in ipairs(list) do Filters.ESPItems[n] = true end
                Toast("ESP +", catName .. " added (" .. #list .. ")")
            end
            local out = {}
            for n, _ in pairs(Filters.ESPItems) do table.insert(out, n) end
            pcall(function() Filters.ESPDropdown:Set(out) end)
        else
            table.clear(Filters.ESPItems)
            for _, n in ipairs(list) do Filters.ESPItems[n] = true end
            pcall(function() Filters.ESPDropdown:Set(list) end)
            Toast("ESP Filter", catName .. " (" .. #list .. ")")
        end
    end

    local eg = tab:CreateGroup()
    local el = eg:CreateGroup({ direction = "column" })
    local er = eg:CreateGroup({ direction = "column" })
    el:CreateButton({ name = "💥 All Ammo",       callback = function() ApplyESPPreset("Ammo") end })
    el:CreateButton({ name = "🍞 All Food",       callback = function() ApplyESPPreset("Food") end })
    el:CreateButton({ name = "🔫 All Guns",       callback = function() ApplyESPPreset("Tool_Guns") end })
    el:CreateButton({ name = "⚔️ All Melee",      callback = function() ApplyESPPreset("Tool_Melee") end })
    el:CreateButton({ name = "🛡️ All Armor",      callback = function() ApplyESPPreset("Armor") end })
    el:CreateButton({ name = "💊 All Medical",    callback = function() ApplyESPPreset("Tool_Medical") end })
    er:CreateButton({ name = "⛽ All Fuel",       callback = function() ApplyESPPreset("Fuel") end })
    er:CreateButton({ name = "🔧 All Resources",  callback = function() ApplyESPPreset("Resources") end })
    er:CreateButton({ name = "💎 Alien Crystals", callback = function() ApplyESPPreset("AlienCrystals") end })
    er:CreateButton({ name = "🎒 All Backpacks",  callback = function() ApplyESPPreset("Tool_Backpacks") end })
    er:CreateButton({ name = "🚗 Car Attach.",    callback = function() ApplyESPPreset("Tool_CarAttachments") end })
    er:CreateButton({ name = "🌐 Show All Items", callback = function()
        table.clear(Filters.ESPItems)
        pcall(function() Filters.ESPDropdown:Set({}) end)
        Toast("ESP Filter", "Empty = highlight EVERYTHING")
    end })

    tab:CreateButton({ name = "🔄 Refresh ESP List", callback = function()
        BuildItemDatabase()
        pcall(function() Filters.ESPDropdown:Refresh(ItemDatabase.All) end)
        Toast("Refreshed", #ItemDatabase.All .. " items")
    end })

    tab:CreateDivider({ text = "drones" })
    ESPRefs.Toggles.DroneESP = tab:CreateToggle({ name = "Enable Drone ESP", flag = "DroneESP", value = false,
        callback = function(v)
            State.DroneESP = v
            if not v then
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if obj:IsA("Model") then
                        for _, d in ipairs(obj:GetDescendants()) do
                            if d:IsA("BillboardGui") and d.Name == "DroneESP" then d:Destroy() end
                        end
                    end
                end
            end
        end })
    tab:CreateToggle({ name = "Show Drone Owner", flag = "DroneESPShowOwner", value = true,
        callback = function(v) State.DroneESPShowOwner = v end })

    task.spawn(function()
        local DroneESPGuis = {}
        while true do
            task.wait(0.3)
            if State.DroneESP then
                local found = {}
                local function processDrone(d, isMine)
                    if not d then return end
                    local isCombat = d.Name:lower():find("combat")
                    local color = isMine and (isCombat and Color3.fromRGB(255,165,50) or Color3.fromRGB(60,128,255))
                                        or Color3.fromRGB(200,200,200)
                    local adornee = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart", true)
                    if not adornee then return end
                    found[adornee] = true
                    local ownerStr = ""
                    if State.DroneESPShowOwner and not isMine then
                        local tf = d:FindFirstChild("ToFollow")
                        if tf and tf:IsA("ObjectValue") and tf.Value then
                            ownerStr = " [" .. tf.Value.Name .. "]"
                        end
                    end
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local dt = ""
                    if hrp and State.ESPShowDistance then
                        dt = " [" .. math.floor((hrp.Position - adornee.Position).Magnitude) .. "m]"
                    end
                    local prefix = isCombat and "⭐⚔️ " or "⭐💚 "
                    local display = (prefix .. d.Name .. ownerStr .. dt):gsub("^%s+", "")
                    local existing = DroneESPGuis[adornee]
                    if existing and existing.Parent then
                        local lbl = existing:FindFirstChildOfClass("TextLabel")
                        if lbl then lbl.Text = display; lbl.TextColor3 = color end
                    else
                        local gui = Instance.new("BillboardGui")
                        gui.Name = "DroneESP"; gui.Adornee = adornee
                        gui.Size = UDim2.new(0, 260, 0, 34); gui.StudsOffset = Vector3.new(0, 4, 0)
                        gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.Parent = adornee
                        local lbl = Instance.new("TextLabel")
                        lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
                        lbl.Text = display; lbl.TextColor3 = color
                        lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.new(0,0,0)
                        lbl.TextSize = 16; lbl.Font = Enum.Font.SourceSansBold; lbl.Parent = gui
                        DroneESPGuis[adornee] = gui
                    end
                end
                for _, obj in ipairs(Workspace:GetChildren()) do
                    if obj:IsA("Model") and (obj.Name == "Combat Drone" or obj.Name == "Healing Drone"
                        or obj.Name == "CombatDrone" or obj.Name == "HealingDrone") then
                        processDrone(obj, IsMyDrone(obj))
                    end
                end
                for adornee, gui in pairs(DroneESPGuis) do
                    if not found[adornee] or not adornee.Parent then
                        if gui and gui.Parent then gui:Destroy() end
                        DroneESPGuis[adornee] = nil
                    end
                end
            end
        end
    end)

    tab:CreateDivider({ text = "world" })
    tab:CreateSection({ name = "🗺️ World ESP" })

    ESPRefs.Toggles.SurvivorESP = tab:CreateToggle({ name = "Survivor ESP", flag = "SurvivorESP", value = false,
        callback = function(v)
            State.SurvivorESP = v
            if not v then
                local map = Workspace:FindFirstChild("Map")
                local surv = map and map:FindFirstChild("Survivors")
                if surv then for _, i in ipairs(surv:GetDescendants()) do
                    if i:IsA("BillboardGui") and i.Name == "SurvivorESP" then i:Destroy() end
                end end
            end
        end })

    ESPRefs.Toggles.AirdropESP = tab:CreateToggle({ name = "Airdrop ESP", flag = "AirdropESP", value = false,
        callback = function(v)
            State.AirdropESP = v
            if not v then
                local map = Workspace:FindFirstChild("Map")
                local sp = map and map:FindFirstChild("Special")
                if sp then for _, i in ipairs(sp:GetDescendants()) do
                    if i:IsA("BillboardGui") and i.Name == "AirdropESP" then i:Destroy() end
                end end
            end
        end })

    ToggleRefs.CrateESP = tab:CreateToggle({ name = "📦 Crate ESP (tier-colored)", flag = "CrateESP", value = false,
        callback = function(v)
            State.CrateESP = v
            if not v then
                local map = Workspace:FindFirstChild("Map")
                local crates = map and map:FindFirstChild("Crates")
                if crates then for _, i in ipairs(crates:GetDescendants()) do
                    if i:IsA("BillboardGui") and i.Name == "CrateESP" then i:Destroy() end
                end end
            end
        end })

    tab:CreateText({ name = "Crate Tier Colors",
        text = "T1 = Gray · T2 = Green · T3 = Blue · T4 = Purple · T5 = Gold · T6+ = Red" })

    task.spawn(function()
        local SurvivorESPGuis = {}
        local AirdropESPGuis  = {}
        local CrateESPGuis    = {}

        local function updOrCreate(cache, tag, adornee, text, color)
            local gui = cache[adornee]
            if gui and gui.Parent then
                local lbl = gui:FindFirstChildOfClass("TextLabel")
                if lbl then lbl.Text = text; lbl.TextColor3 = color end
            else
                gui = Instance.new("BillboardGui")
                gui.Name = tag; gui.Adornee = adornee
                gui.Size = UDim2.new(0, 220, 0, 30); gui.StudsOffset = Vector3.new(0, 2.5, 0)
                gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.Parent = adornee
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
                lbl.Text = text; lbl.TextColor3 = color
                lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
                lbl.TextSize = 14; lbl.Font = Enum.Font.SourceSansBold; lbl.Parent = gui
                cache[adornee] = gui
            end
        end

        local function cleanup(cache)
            for adornee, gui in pairs(cache) do
                if not adornee.Parent then
                    if gui and gui.Parent then gui:Destroy() end
                    cache[adornee] = nil
                end
            end
        end

        while true do
            task.wait(0.5)
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local myPos = hrp and hrp.Position

            if State.SurvivorESP or State.AirdropESP or State.CrateESP then
                local map = Workspace:FindFirstChild("Map")

                if State.SurvivorESP then
                    local surv = map and map:FindFirstChild("Survivors")
                    if surv then
                        for _, m in ipairs(surv:GetChildren()) do
                            if m:IsA("Model") then
                                local adornee = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
                                if adornee then
                                    local dist = (myPos and State.ESPShowDistance)
                                        and (" [" .. math.floor((myPos - adornee.Position).Magnitude) .. "m]") or ""
                                    local name = State.ESPShowNames and ("Survivor: " .. m.Name) or ""
                                    updOrCreate(SurvivorESPGuis, "SurvivorESP", adornee, name .. dist, Color3.fromRGB(0, 255, 130))
                                end
                            end
                        end
                    end
                    cleanup(SurvivorESPGuis)
                end

                if State.AirdropESP then
                    local sp = map and map:FindFirstChild("Special")
                    if sp then
                        for _, m in ipairs(sp:GetChildren()) do
                            if m:IsA("Model") or m:IsA("BasePart") then
                                local adornee = m:IsA("BasePart") and m
                                    or (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true))
                                if adornee then
                                    local dist = (myPos and State.ESPShowDistance)
                                        and (" [" .. math.floor((myPos - adornee.Position).Magnitude) .. "m]") or ""
                                    local name = State.ESPShowNames and ("★ AIRDROP: " .. m.Name) or ""
                                    updOrCreate(AirdropESPGuis, "AirdropESP", adornee, name .. dist, Color3.fromRGB(255, 0, 200))
                                end
                            end
                        end
                    end
                    cleanup(AirdropESPGuis)
                end

                if State.CrateESP then
                    local cratesRoot = map and map:FindFirstChild("Crates")
                    if cratesRoot then
                        local containers = { cratesRoot }
                        for _, sub in ipairs(cratesRoot:GetChildren()) do
                            if sub:IsA("Folder") then table.insert(containers, sub) end
                        end
                        for _, container in ipairs(containers) do
                            for _, m in ipairs(container:GetChildren()) do
                                if m:IsA("Model") and m:GetAttribute("Crate") == true then
                                    local tier = m:GetAttribute("Tier") or 1
                                    local rarity = m:GetAttribute("Rarity") or "?"
                                    local adornee = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
                                    if adornee then
                                        local color = GetCrateColor(tier)
                                        local dist = (myPos and State.ESPShowDistance)
                                            and (" [" .. math.floor((myPos - adornee.Position).Magnitude) .. "m]") or ""
                                        local text = State.ESPShowNames
                                            and ("📦 T" .. tier .. " " .. rarity .. dist) or dist:gsub("^%s+","")
                                        updOrCreate(CrateESPGuis, "CrateESP", adornee, text, color)
                                    end
                                end
                            end
                        end
                    end
                    cleanup(CrateESPGuis)
                end
            end
        end
    end)

    tab:CreateDivider({ text = "emergency" })
    tab:CreateButton({ name = "🚫 Hide All ESP", callback = function()
        State.ItemESP = false; State.ZombieESP = false; State.PlayerESP = false
        State.DroneESP = false; State.SurvivorESP = false; State.AirdropESP = false; State.CrateESP = false

        RemoveESP(Workspace:FindFirstChild("DroppedItems"), "ItemESP")
        RemoveESP(Workspace:FindFirstChild("Characters"), "ZombieESP")
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then RemoveESP(p.Character, "PlayerESP") end
        end
        local map = Workspace:FindFirstChild("Map")
        if map then
            local crates = map:FindFirstChild("Crates")
            if crates then for _, d in ipairs(crates:GetDescendants()) do
                if d:IsA("BillboardGui") and d.Name == "CrateESP" then d:Destroy() end
            end end
        end
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Model") then
                for _, d in ipairs(obj:GetDescendants()) do
                    if d:IsA("BillboardGui") and (d.Name == "DroneESP" or d.Name == "SurvivorESP" or d.Name == "AirdropESP") then
                        d:Destroy()
                    end
                end
            end
        end
        for _, toggle in pairs(ESPRefs.Toggles) do pcall(function() toggle:Set(false) end) end
        Toast("All ESP Hidden", "Clean screen restored")
    end })
end

-- =================================================================
-- MISC TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "🛠️ Misc" })

    tab:CreateSection({ name = "🏃 Movement" })
    ToggleRefs.SpeedHack = tab:CreateToggle({ name = "🏃 Speed Hack", flag = "SpeedHack", value = false,
        callback = function(v)
            State.SpeedHack = v
            Toast("Speed Hack", v and ("Enabled at " .. State.SpeedValue) or "Disabled")
        end })
    tab:CreateSlider({ name = "Walk Speed", flag = "SpeedValue",
        range = {16, 100}, increment = 1, value = 30, suffix = " spd",
        callback = function(v)
            State.SpeedValue = v
            if State.SpeedHack then Toast("Speed Hack", v .. " spd") end
        end })
    tab:CreateToggle({ name = "⚡ Bypass Mode (0.5s pulse)", flag = "SpeedBypassMode", value = false,
        callback = function(v)
            State.SpeedBypassMode = v
            if v then Toast("Speed Hack", "Bypass — 0.5s pulse pattern")
            else Toast("Speed Hack", "Direct — no pulse") end
        end })

    ToggleRefs.InfJump = tab:CreateToggle({ name = "🦘 Infinite Jump", flag = "InfJump", value = false,
        callback = function(v)
            State.InfJump = v
            Toast("Infinite Jump", v and "Enabled" or "Disabled")
        end })

    tab:CreateDivider({ text = "combat utility" })
    tab:CreateSection({ name = "🎯 Hitbox Expander" })
    ToggleRefs.HitboxExpand = tab:CreateToggle({ name = "Enable Hitbox Expander", flag = "HitboxExpand", value = false,
        callback = function(v)
            State.HitboxExpand = v
            Toast("Hitbox Expander", v and "Enabled" or "Disabled (restoring)")
        end })
    tab:CreateSlider({ name = "Hitbox Size", flag = "HitboxSize",
        range = {2, 15}, increment = 0.5, value = 5, suffix = " studs",
        callback = function(v) State.HitboxSize = v end })

    tab:CreateDivider({ text = "visuals" })
    tab:CreateSection({ name = "🎨 Visuals" })
    ToggleRefs.RemoveFog = tab:CreateToggle({ name = "Remove Fog", flag = "RemoveFog", value = false,
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
            else Lighting.FogEnd = 1000 end
        end })
    ToggleRefs.Fullbright = tab:CreateToggle({ name = "Fullbright", flag = "Fullbright", value = false,
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
    tab:CreateDivider({ text = "session" })
    ToggleRefs.AntiAFK = tab:CreateToggle({
        name = "Anti-AFK", flag = "AntiAFK", value = false,
        callback = function(v)
            State.AntiAFK = v
            if v then
                if not AntiAFKConnection then
                    AntiAFKConnection = LocalPlayer.Idled:Connect(function()
                        pcall(function()
                            VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                            task.wait(0.5)
                            VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                        end)
                    end)
                end
                Toast("Anti-AFK", "Enabled")
            else
                if AntiAFKConnection then AntiAFKConnection:Disconnect(); AntiAFKConnection = nil end
                Toast("Anti-AFK", "Disabled")
            end
        end,
    })
    tab:CreateDivider({ text = "interaction" })
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
            else
                if Prompts.Connection then Prompts.Connection:Disconnect(); Prompts.Connection = nil end
                RestorePrompts()
            end
        end })
end

-- =================================================================
-- INFO TAB
-- =================================================================
do
    local tab = Window:CreateTab({ name = "ℹ️ Info" })
    tab:CreateSection({ name = "ℹ️ About" })
    tab:CreateText({ name = "KissoHub — Survive the Apocalypse",
        text = "Version: " .. HUB_VERSION .. "\nConfig: KissoHubFolder/STAPrefs.rfld" })
    tab:CreateDivider({ text = "changelog" })
    tab:CreateSection({ name = "📋 Changelog" })
    tab:CreateText({ name = "v1.11.3 (latest)",
        text = "• 🎯 Drone ownership via ToFollow ObjectValue\n" ..
               "• 🐛 Fixed: drones ignored when another player has one\n" ..
               "• 🎨 Drone ESP owner names from ToFollow.Value.Name\n" ..
               "• 🔄 Overlay ↔ Hub toggle sync (SetFeature)" })
    tab:CreateText({ name = "v1.11.2",
        text = "• Toggle sync fix + emoji cleanup" })
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
-- COMBAT DRONE AUTO LOOP
-- =================================================================
task.spawn(function()
    while true do
        task.wait(State.HoverInterval + math.random() * 0.1)
        if State.AutoCombatDrone and HasControlPad() then
            if not Drones.Combat or not DroneRemoteCache.SetHover then RefreshDroneRefs() end
            if Drones.Combat and DroneRemoteCache.SetHover then
                if State.DroneAIMode and Drones.Combat:GetAttribute("Targeting") ~= State.DroneAIMode then
                    SetDroneTargeting(Drones.Combat, State.DroneAIMode)
                end
                local best = PickBestZombie(GetModelPos(Drones.Combat))
                if best then SendHover(Drones.Combat, best.pos) end
            end
            UpdateGuardStreamingBind()
        end
    end
end)

-- COMBAT FOLLOW LOOP
task.spawn(function()
    while true do
        task.wait(0.3)
        if State.CombatFollowTarget and State.CombatFollowTarget ~= "(No other players)" and HasControlPad() then
            if not Drones.Combat or not DroneRemoteCache.SetHover then RefreshDroneRefs() end
            if Drones.Combat and DroneRemoteCache.SetHover then
                local tPlr = Players:FindFirstChild(State.CombatFollowTarget)
                local tHRP = tPlr and tPlr.Character and tPlr.Character:FindFirstChild("HumanoidRootPart")
                if tHRP then SendHover(Drones.Combat, tHRP.Position)
                else State.CombatFollowTarget = nil; Notify("Combat Follow Lost", "Target left or died", 4) end
            end
        end
    end
end)

-- =================================================================
-- SMART HEAL LOOP
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if State.SmartHeal and HasControlPad() and Drones.Healing and DroneRemoteCache.SetHover then
            local bestPlr, bestHRP, bestPct = nil, nil, math.huge
            local myPct = 100
            local myChar = LocalPlayer.Character
            local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
            if myHum and myHum.MaxHealth > 0 then
                myPct = (myHum.Health / myHum.MaxHealth) * 100
            end

            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local char = p.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 and hum.MaxHealth > 0 then
                        local pct = (hum.Health / hum.MaxHealth) * 100
                        if pct < State.SmartHealThreshold and pct < bestPct then
                            local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
                            if hrp then
                                bestPlr = p
                                bestHRP = hrp
                                bestPct = pct
                            end
                        end
                    end
                end
            end

            if myPct < State.SmartHealThreshold and myPct < bestPct then
                bestHRP = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Head"))
                bestPlr = LocalPlayer
                bestPct = myPct
            end

            if bestHRP then
                SendHover(Drones.Healing, bestHRP.Position)
            else
                SendHover(Drones.Healing, nil)
            end
        end
    end
end)

-- HEALING DRONE MANUAL FOLLOW
task.spawn(function()
    while true do
        task.wait(0.3)
        if not State.SmartHeal
           and State.HealingFollowTarget
           and State.HealingFollowTarget ~= "(No other players)"
           and HasControlPad() then
            if not Drones.Healing or not DroneRemoteCache.SetHover then RefreshDroneRefs() end
            if Drones.Healing and DroneRemoteCache.SetHover then
                local tPlr = Players:FindFirstChild(State.HealingFollowTarget)
                local tHRP = tPlr and tPlr.Character and tPlr.Character:FindFirstChild("HumanoidRootPart")
                if tHRP then SendHover(Drones.Healing, tHRP.Position)
                else State.HealingFollowTarget = nil; Notify("Healing Follow Lost", "Target left or died", 4) end
            end
        end
    end
end)

-- =================================================================
-- AUTO-SHOOT LOOP
-- =================================================================
task.spawn(function()
    while true do
        local baseInterval = 0.05
        if State.RapidFire then baseInterval = baseInterval / math.max(1, State.RapidFireMult) end
        task.wait(baseInterval)
        if State.AutoShoot then
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local turretInfo = GetActiveTurret()
                if turretInfo and turretInfo.shoot then
                    local origin = turretInfo.barrel and turretInfo.barrel.WorldPosition or Camera.CFrame.Position
                    local targets = GetTargetsInRange(State.AutoShootRange)
                    if #targets > 0 then
                        SortTargets(targets)
                        local target = targets[1]
                        if target then
                            local hitPart = target.part
                            if State.PreciseHeadshot then
                                local head = target.model:FindFirstChild("Head")
                                if head then hitPart = head end
                            end
                            local tpos = hitPart.Position
                            if State.AutoShootPrediction then
                                local vel = hitPart.AssemblyLinearVelocity
                                if vel.Magnitude > 1 then
                                    local d = (tpos - origin).Magnitude
                                    tpos = tpos + vel * (d / 500) * State.AutoShootPredictStr
                                end
                            end
                            if turretInfo.updateAim then
                                local basePos = turretInfo.base and turretInfo.base.Position or origin
                                local offset = tpos - basePos
                                local yaw = math.atan2(-offset.X, -offset.Z)
                                local flatDist = math.sqrt(offset.X^2 + offset.Z^2)
                                local pitch = math.atan2(offset.Y, flatDist)
                                pcall(function() turretInfo.updateAim:FireServer(yaw, pitch) end)
                            end
                            local payload = {{
                                Target = tpos,
                                HitData = {{ HitChar = target.model, HitPos = tpos, HitPart = hitPart }},
                                EffectResults = {{ Origin = origin, End = tpos }},
                            }}
                            pcall(function() turretInfo.shoot:FireServer(origin, payload) end)
                        end
                    end
                else
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool and tool:GetAttribute("ToolType") == "Gun" then
                        local shoot = tool:FindFirstChild("Shoot")
                        if shoot then
                            local myPos = getLocalRootPosition()
                            local targets = GetTargetsInRange(State.AutoShootRange)
                            if #targets > 0 then
                                SortTargets(targets)
                                local target = targets[1]
                                if target then
                                    local hitPart = target.part
                                    if State.PreciseHeadshot then
                                        local head = target.model:FindFirstChild("Head")
                                        if head then hitPart = head end
                                    end
                                    local tpos = hitPart.Position
                                    if State.AutoShootPrediction then
                                        local vel = hitPart.AssemblyLinearVelocity
                                        if vel.Magnitude > 1 then
                                            local d = (tpos - myPos).Magnitude
                                            tpos = tpos + vel * (d / 500) * State.AutoShootPredictStr
                                        end
                                    end
                                    local payload = {{
                                        Target = tpos,
                                        HitData = {{ HitChar = target.model, HitPos = tpos, HitPart = hitPart }},
                                        EffectResults = {{ Origin = myPos, End = tpos }},
                                    }}
                                    pcall(function() shoot:FireServer(myPos, payload, 0, 4) end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Melee loop
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

-- AUTO LOOT
task.spawn(function()
    while true do
        task.wait(0.3)
        if State.AutoLoot and not IsNearBaseBlocked() then
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
            end
        end
    end
end)

-- Item ESP
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
                        local adornee = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
                        if adornee and not adornee:FindFirstChild("ItemESP") then
                            local gui = Instance.new("BillboardGui")
                            gui.Name = "ItemESP"; gui.Adornee = adornee
                            gui.Size = UDim2.new(0,180,0,25); gui.StudsOffset = Vector3.new(0,2,0)
                            gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.Parent = adornee
                            local lbl = Instance.new("TextLabel")
                            lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
                            lbl.Text = item.Name; lbl.TextColor3 = color
                            lbl.TextStrokeTransparency = 0; lbl.TextStrokeColor3 = Color3.new(0,0,0)
                            lbl.TextSize = 13; lbl.Font = Enum.Font.SourceSansBold; lbl.Parent = gui
                        end
                    end
                end
            end
        end
    end
end)

-- Auto reload
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
        task.wait(State.HolsteredReloadInterval or 1)
        if State.AutoReloadHolstered then
            local containers = {}
            if LocalPlayer.Character then table.insert(containers, LocalPlayer.Character) end
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            if bp then table.insert(containers, bp) end
            for _, container in ipairs(containers) do
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and tool:GetAttribute("ToolType") == "Gun" then
                        if SmartReloadGun(tool) then task.wait(0.1) end
                    end
                end
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

-- SPEED HACK
do
    local bypassTimer = 0
    local bypassPhase = 0
    RunService.Stepped:Connect(function(_, dt)
        if State.SpeedHack then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                if State.SpeedBypassMode then
                    bypassTimer += dt
                    if bypassTimer >= 0.5 then
                        bypassTimer = 0
                        bypassPhase = 1 - bypassPhase
                    end
                    hum.WalkSpeed = (bypassPhase == 0) and 0 or State.SpeedValue
                else
                    hum.WalkSpeed = State.SpeedValue
                end
            end
        end
    end)
end

-- INFINITE JUMP
UserInputService.JumpRequest:Connect(function()
    if State.InfJump then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end
end)

-- HITBOX EXPANDER
do
    local HitboxOriginals = {}
    task.spawn(function()
        while true do
            task.wait(0.3)
            if State.HitboxExpand then
                for _, z in ipairs(GetZombieList()) do
                    if z:IsA("Model") then
                        for _, partName in ipairs({"Head", "HumanoidRootPart", "Torso", "UpperTorso"}) do
                            local p = z:FindFirstChild(partName)
                            if p and p:IsA("BasePart") then
                                if not HitboxOriginals[p] then
                                    HitboxOriginals[p] = { size = p.Size, massless = p.Massless, cancollide = p.CanCollide }
                                end
                                local s = State.HitboxSize
                                p.Size = Vector3.new(s, s, s)
                                p.Massless = true
                                p.CanCollide = false
                            end
                        end
                    end
                end
            else
                for part, data in pairs(HitboxOriginals) do
                    if part and part.Parent then
                        pcall(function()
                            part.Size = data.size
                            part.Massless = data.massless
                            part.CanCollide = data.cancollide
                        end)
                    end
                end
                HitboxOriginals = {}
            end
        end
    end)
end

-- AUTO HEAL / EAT
task.spawn(function()
    while true do
        task.wait(0.5)
        if State.AutoHeal then
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local pct = (hum.Health / hum.MaxHealth) * 100
                if pct < State.AutoHealThreshold then AutoUseConsumable("heal") end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if State.AutoEat then
            local char = LocalPlayer.Character
            if char and char:FindFirstChildOfClass("Humanoid") then
                local hunger = char:GetAttribute("Hunger")
                if type(hunger) == "number" and hunger < State.AutoEatThreshold then
                    AutoUseConsumable("eat")
                end
            end
        end
    end
end)

-- BACKPACK + RESOURCE MONITOR
task.spawn(function()
    while true do
        task.wait(State.BPRefresh and 1 or 5)
        if State.BPRefresh then
            pcall(function()
                local items, total, byType = ReadBackpackStorage()
                if Stats.BPTotal then Stats.BPTotal:Set(total) end
                if Stats.BPFuel  then Stats.BPFuel:Set(byType.Fuel or 0) end
                if Stats.BPFood  then Stats.BPFood:Set(byType.Food or 0) end
                if Stats.BPAmmo  then Stats.BPAmmo:Set(byType.Ammo or 0) end
                local other = 0
                for t, n in pairs(byType) do
                    if t ~= "Fuel" and t ~= "Food" and t ~= "Resource" and t ~= "Ammo" then other += n end
                end
                if Stats.BPOther then Stats.BPOther:Set(other) end

                if Stats.Scrap     then Stats.Scrap:Set(ReadCraftingResource("Scrap")) end
                if Stats.Batteries then Stats.Batteries:Set(ReadCraftingResource("Batteries")) end
                if Stats.Hearts    then Stats.Hearts:Set(ReadCraftingResource("Hearts")) end
            end)
        end
    end
end)

-- SILENT AIM HOOK
if hookmetamethod and getnamecallmethod then
    pcall(function()
        local raw; raw = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if State.SilentAim and method == "FireServer" and tostring(self) == "Shoot" then
                local target = getClosestZombie()
                if target and target.Parent then
                    local args = {...}
                    local origin = args[1] or getLocalRootPosition()
                    local hitPart = target
                    if State.PreciseHeadshot then
                        local head = target.Parent:FindFirstChild("Head")
                        if head then hitPart = head end
                    end
                    args[2] = {{ Target = hitPart.Position,
                        HitData = {{ HitChar = target.Parent, HitPos = hitPart.Position, HitPart = hitPart }},
                        EffectResults = {{ Origin = origin, End = hitPart.Position }} }}
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
    while true do
        task.wait(State.LiveStats and 0.5 or 2.0)
        pcall(function()
            local mins = math.floor((os.time() - SESSION_START) / 60)
            local active = 0
            for _, k in ipairs({"AutoShoot","SilentAim","KillAura","AutoSwing","ZeroWindUp",
                "ZeroEndlag","NoRecoil","NoSpread","AutoReload","AutoLoot","AutoStore",
                "AutoReloadHolstered","PreciseHeadshot","RapidFire","SpeedHack","InfJump",
                "HitboxExpand","AutoHeal","AutoEat","PreventBaseLoot","SmartHeal",
                "ItemESP","ZombieESP","PlayerESP","SurvivorESP","AirdropESP","CrateESP","DroneESP",
                "InstantPrompts","AntiAFK","AutoCombatDrone"}) do
                if State[k] then active += 1 end
            end
            local targetCount = 0
            for _, c in ipairs(GetZombieList()) do
                if isZombieEnemy(c) and canBeDamaged(c) then targetCount += 1 end
            end
            local ammoTotal = 0
            local ammoConf = LocalPlayer:FindFirstChild("Ammo")
            if ammoConf then for _, a in ipairs({"Long","Shells","Pistol","Medium"}) do
                ammoTotal += (ammoConf:GetAttribute(a) or 0)
            end end
            local kills, health = 0, 100
            local ls = LocalPlayer:FindFirstChild("leaderstats")
            if ls then local k = ls:FindFirstChild("Kills"); if k then kills = k.Value end end
            local char = LocalPlayer.Character
            if char then local hum = char:FindFirstChildOfClass("Humanoid"); if hum then health = math.floor(hum.Health) end end

            if Stats.Session then Stats.Session:Set(mins) end
            if Stats.Features then Stats.Features:Set(active) end
            if Stats.Fps then Stats.Fps:Set(math.floor(Workspace:GetRealPhysicsFPS() or 60)) end
            if Stats.Players then Stats.Players:Set(#Players:GetPlayers()) end
            if Stats.Targets then Stats.Targets:Set(targetCount) end
            if Stats.Ammo then Stats.Ammo:Set(ammoTotal) end
            if Stats.Kills then Stats.Kills:Set(kills) end
            if Stats.Health then Stats.Health:Set(health) end

            if Stats.TargetsCached then Stats.TargetsCached:Set(ZombieCache.totalFound) end
            if Stats.LastScan then
                local ago = math.floor(tick() - ZombieCache.lastScan)
                Stats.LastScan:Set(ago)
            end

            State.ClassLevel = GetClassLevel()
            if Stats.ClassLevel then Stats.ClassLevel:Set(State.ClassLevel) end
            if Stats.DroneState then
                local bit = 0
                if Drones.Combat then bit = bit + 1 end
                if Drones.Healing then bit = bit + 2 end
                Stats.DroneState:Set(bit)
            end
            local healDrone = Drones.Healing
            if healDrone then
                local rcd  = healDrone:GetAttribute("ReviveCD") or 0
                local srcd = healDrone:GetAttribute("SelfReviveCD") or 0
                if Stats.ReviveCD  then Stats.ReviveCD:Set(math.ceil(rcd)) end
                if Stats.SelfRevCD then Stats.SelfRevCD:Set(math.ceil(srcd)) end
            end

            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not HasControlPad() and (State.AutoCombatDrone or State.CombatFollowTarget or State.HealingFollowTarget or State.SmartHeal) then
                StateTag:Set({ text = "PAD CACHE EMPTY", color = Color3.fromRGB(255, 80, 80) })
            elseif State.SmartHeal then
                StateTag:Set({ text = "SMART HEAL", color = Color3.fromRGB(0, 220, 180) })
            elseif State.CombatPriority == "Guard Base" and State.AutoCombatDrone then
                StateTag:Set({ text = "GUARDING BASE", color = Color3.fromRGB(255, 200, 40) })
            elseif State.SpeedHack and State.SpeedBypassMode then
                StateTag:Set({ text = "SPEED BYPASS", color = Color3.fromRGB(255, 100, 255) })
            elseif State.SpeedHack then
                StateTag:Set({ text = "SPEED " .. State.SpeedValue, color = Color3.fromRGB(255, 100, 255) })
            elseif State.RapidFire then
                StateTag:Set({ text = "RAPID " .. State.RapidFireMult .. "x", color = Color3.fromRGB(255, 150, 40) })
            elseif State.CombatFollowTarget then
                StateTag:Set({ text = "COMBAT → " .. tostring(State.CombatFollowTarget), color = Color3.fromRGB(255, 165, 50) })
            elseif State.HealingFollowTarget then
                StateTag:Set({ text = "HEAL → " .. tostring(State.HealingFollowTarget), color = Color3.fromRGB(60, 128, 255) })
            elseif State.AutoCombatDrone then
                StateTag:Set({ text = "COMBAT DRONE", color = Color3.fromRGB(255, 200, 40) })
            elseif hum and hum.SeatPart and State.AutoShoot then
                StateTag:Set({ text = "TURRET", color = Color3.fromRGB(255, 200, 40) })
            elseif State.AutoHeal then
                StateTag:Set({ text = "AUTO HEAL", color = Color3.fromRGB(255, 100, 150) })
            elseif State.AutoEat then
                StateTag:Set({ text = "AUTO EAT", color = Color3.fromRGB(200, 150, 100) })
            elseif State.AutoLoot then
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

-- =================================================================
-- ON-SCREEN QUICK ACTIONS OVERLAY
-- =================================================================
local function CreateQuickActionMenu()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    if OnScreenUI.Gui and OnScreenUI.Gui.Parent then return end

    local C = {
        bg          = Color3.fromRGB(10, 10, 15),
        panel       = Color3.fromRGB(16, 15, 22),
        surface     = Color3.fromRGB(22, 20, 30),
        surfaceHi   = Color3.fromRGB(30, 27, 40),
        border      = Color3.fromRGB(42, 38, 58),
        borderHi    = Color3.fromRGB(0, 185, 255),
        accentCyan  = Color3.fromRGB(0, 200, 255),
        accentRed   = Color3.fromRGB(255, 80, 80),
        textPri     = Color3.fromRGB(228, 224, 242),
        textSub     = Color3.fromRGB(148, 140, 168),
        textDim     = Color3.fromRGB(82, 76, 102),
        tabActive   = Color3.fromRGB(0, 185, 255),
        tabInactive = Color3.fromRGB(52, 48, 68),
        tabTextOff  = Color3.fromRGB(110, 104, 130),
        toggleOff   = Color3.fromRGB(28, 25, 38),
        knobOff     = Color3.fromRGB(82, 76, 102),
        triggerBg   = Color3.fromRGB(16, 15, 22),
    }

    local gui = Instance.new("ScreenGui")
    gui.Name = "KissoQuickActions"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 120
    gui.Enabled = true
    gui.Parent = playerGui
    OnScreenUI.Gui = gui

    local triggerW, triggerH = 28, 96

    local trigger = Instance.new("TextButton")
    trigger.Name = "Trigger"
    trigger.Size = UDim2.fromOffset(triggerW, triggerH)
    trigger.Position = UDim2.new(0, 0, 0.5, -triggerH / 2)
    trigger.BackgroundColor3 = C.triggerBg
    trigger.BorderSizePixel = 0
    trigger.Text = ""
    trigger.AutoButtonColor = false
    trigger.ZIndex = 10
    trigger.Parent = gui
    Instance.new("UICorner", trigger).CornerRadius = UDim.new(0, 8)

    local trigStroke = Instance.new("UIStroke")
    trigStroke.Color = C.border
    trigStroke.Thickness = 1
    trigStroke.Transparency = 0.3
    trigStroke.Parent = trigger

    local trigAccent = Instance.new("Frame")
    trigAccent.Size = UDim2.fromOffset(2, 48)
    trigAccent.Position = UDim2.new(1, -3, 0.5, -24)
    trigAccent.BackgroundColor3 = C.border
    trigAccent.BorderSizePixel = 0
    trigAccent.ZIndex = 11
    trigAccent.Parent = trigger
    Instance.new("UICorner", trigAccent).CornerRadius = UDim.new(1, 0)

    for i = 0, 2 do
        local bar = Instance.new("Frame")
        bar.Size = UDim2.fromOffset(12, 2)
        bar.Position = UDim2.new(0.5, -6, 0.5, -8 + i * 7)
        bar.BackgroundColor3 = C.textSub
        bar.BorderSizePixel = 0
        bar.ZIndex = 12
        bar.Parent = trigger
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    end

    local PANEL_W = 248
    local PANEL_CLOSED_X = -(PANEL_W + 4)
    local PANEL_OPEN_X   = triggerW

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromOffset(PANEL_W, 0)
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Position = UDim2.new(0, PANEL_CLOSED_X, 0.5, 0)
    panel.AnchorPoint = Vector2.new(0, 0.5)
    panel.BackgroundColor3 = C.panel
    panel.BorderSizePixel = 0
    panel.ClipsDescendants = true
    panel.ZIndex = 8
    panel.Parent = gui
    OnScreenUI.Frame = panel
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = C.border
    panelStroke.Thickness = 1
    panelStroke.Transparency = 0.2
    panelStroke.Parent = panel

    local panelGrad = Instance.new("UIGradient")
    panelGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 18, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 11, 18)),
    })
    panelGrad.Rotation = 145
    panelGrad.Parent = panel

    local stripe = Instance.new("Frame")
    stripe.Size = UDim2.new(1, 0, 0, 2)
    stripe.BackgroundColor3 = C.accentCyan
    stripe.BorderSizePixel = 0
    stripe.ZIndex = 9
    stripe.Parent = panel

    local stripeGrad = Instance.new("UIGradient")
    stripeGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 80, 180)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 200, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 80, 180)),
    })
    stripeGrad.Parent = stripe

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 50)
    header.Position = UDim2.fromOffset(0, 2)
    header.BackgroundTransparency = 1
    header.ZIndex = 9
    header.Parent = panel

    local statusDot = Instance.new("Frame")
    statusDot.Name = "StatusDot"
    statusDot.Size = UDim2.fromOffset(8, 8)
    statusDot.Position = UDim2.fromOffset(16, 21)
    statusDot.BackgroundColor3 = C.textDim
    statusDot.BorderSizePixel = 0
    statusDot.ZIndex = 10
    statusDot.Parent = header
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

    local statusGlow = Instance.new("ImageLabel")
    statusGlow.Name = "Glow"
    statusGlow.Size = UDim2.fromOffset(22, 22)
    statusGlow.Position = UDim2.fromOffset(-7, -7)
    statusGlow.BackgroundTransparency = 1
    statusGlow.Image = "rbxassetid://5028857084"
    statusGlow.ImageColor3 = C.textDim
    statusGlow.ImageTransparency = 0.6
    statusGlow.ZIndex = 9
    statusGlow.Parent = statusDot

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -60, 0, 16)
    titleLbl.Position = UDim2.fromOffset(32, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "Quick Actions"
    titleLbl.TextColor3 = C.textPri
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 14
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 10
    titleLbl.Parent = header

    local subLbl = Instance.new("TextLabel")
    subLbl.Size = UDim2.new(1, -60, 0, 12)
    subLbl.Position = UDim2.fromOffset(32, 29)
    subLbl.BackgroundTransparency = 1
    subLbl.Text = "KissoHub"
    subLbl.TextColor3 = C.textDim
    subLbl.Font = Enum.Font.Gotham
    subLbl.TextSize = 10
    subLbl.TextXAlignment = Enum.TextXAlignment.Left
    subLbl.ZIndex = 10
    subLbl.Parent = header

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Size = UDim2.fromOffset(24, 24)
    closeBtn.Position = UDim2.new(1, -32, 0, 13)
    closeBtn.BackgroundColor3 = Color3.fromRGB(32, 28, 44)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "x"
    closeBtn.TextColor3 = C.textDim
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 11
    closeBtn.Parent = header
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 7)

    local closeBtnStroke = Instance.new("UIStroke")
    closeBtnStroke.Color = C.border
    closeBtnStroke.Thickness = 1
    closeBtnStroke.Transparency = 0.5
    closeBtnStroke.Parent = closeBtn

    local hDiv = Instance.new("Frame")
    hDiv.Size = UDim2.new(1, 0, 0, 1)
    hDiv.Position = UDim2.fromOffset(0, 52)
    hDiv.BackgroundColor3 = C.border
    hDiv.BackgroundTransparency = 0.5
    hDiv.BorderSizePixel = 0
    hDiv.Parent = panel

    local TABS = {
        { id = "Drone",  label = "Drone"  },
        { id = "Loot",   label = "Loot"   },
        { id = "Combat", label = "Combat" },
        { id = "Player", label = "Player" },
    }
    local activeTab = "Drone"

    local tabBar = Instance.new("Frame")
    tabBar.Name = "TabBar"
    tabBar.Size = UDim2.new(1, -16, 0, 34)
    tabBar.Position = UDim2.fromOffset(8, 58)
    tabBar.BackgroundColor3 = Color3.fromRGB(12, 11, 18)
    tabBar.BorderSizePixel = 0
    tabBar.ZIndex = 9
    tabBar.Parent = panel
    Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 9)

    local tabBarStroke = Instance.new("UIStroke")
    tabBarStroke.Color = C.border
    tabBarStroke.Thickness = 1
    tabBarStroke.Transparency = 0.55
    tabBarStroke.Parent = tabBar

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 2)
    tabLayout.Parent = tabBar

    local tabPadding = Instance.new("UIPadding")
    tabPadding.PaddingLeft = UDim.new(0, 3)
    tabPadding.PaddingRight = UDim.new(0, 3)
    tabPadding.PaddingTop = UDim.new(0, 3)
    tabPadding.PaddingBottom = UDim.new(0, 3)
    tabPadding.Parent = tabBar

    local CONTENT_Y = 100

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 0, 0)
    content.Position = UDim2.fromOffset(0, CONTENT_Y)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.BackgroundTransparency = 1
    content.ZIndex = 8
    content.Parent = panel

    local bottomPad = Instance.new("Frame")
    bottomPad.Size = UDim2.new(1, 0, 0, 12)
    bottomPad.BackgroundTransparency = 1
    bottomPad.LayoutOrder = 999
    bottomPad.Parent = content

    local function makeRow(parent, name, icon, iconColor, labelText, isToggle, layoutOrder)
        local rowH = isToggle and 44 or 40

        local row = Instance.new("TextButton")
        row.Name = name
        row.Size = UDim2.new(1, -16, 0, rowH)
        row.BackgroundColor3 = C.surface
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.ZIndex = 9
        row.LayoutOrder = layoutOrder or 0
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

        local stk = Instance.new("UIStroke")
        stk.Name = "Stroke"
        stk.Color = C.border
        stk.Thickness = 1
        stk.Transparency = 0.6
        stk.Parent = row

        local badge = Instance.new("Frame")
        badge.Size = UDim2.fromOffset(28, 28)
        badge.Position = UDim2.new(0, 8, 0.5, -14)
        badge.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
        badge.BorderSizePixel = 0
        badge.ZIndex = 10
        badge.Parent = row
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 7)

        local badgeStroke = Instance.new("UIStroke")
        badgeStroke.Name = "BadgeStroke"
        badgeStroke.Color = iconColor
        badgeStroke.Thickness = 1
        badgeStroke.Transparency = 0.62
        badgeStroke.Parent = badge

        local iconLbl = Instance.new("TextLabel")
        iconLbl.Size = UDim2.fromScale(1, 1)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = icon
        iconLbl.TextColor3 = iconColor
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.TextSize = 13
        iconLbl.ZIndex = 11
        iconLbl.Parent = badge

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.Size = UDim2.new(1, isToggle and -108 or -66, 0, 16)
        lbl.Position = UDim2.new(0, 44, 0.5, -8)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = C.textPri
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 10
        lbl.Parent = row

        local track, knob
        if isToggle then
            track = Instance.new("Frame")
            track.Name = "Indicator"
            track.Size = UDim2.fromOffset(34, 18)
            track.Position = UDim2.new(1, -42, 0.5, -9)
            track.BackgroundColor3 = C.toggleOff
            track.BorderSizePixel = 0
            track.ZIndex = 10
            track.Parent = row
            Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

            local tStk = Instance.new("UIStroke")
            tStk.Name = "Stroke"
            tStk.Color = C.border
            tStk.Thickness = 1
            tStk.Transparency = 0.45
            tStk.Parent = track

            knob = Instance.new("Frame")
            knob.Name = "Knob"
            knob.Size = UDim2.fromOffset(12, 12)
            knob.Position = UDim2.fromOffset(3, 3)
            knob.BackgroundColor3 = C.knobOff
            knob.BorderSizePixel = 0
            knob.ZIndex = 11
            knob.Parent = track
            Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        else
            local chev = Instance.new("TextLabel")
            chev.Size = UDim2.fromOffset(14, 16)
            chev.Position = UDim2.new(1, -18, 0.5, -8)
            chev.BackgroundTransparency = 1
            chev.Text = ">"
            chev.TextColor3 = C.textDim
            chev.Font = Enum.Font.GothamBold
            chev.TextSize = 15
            chev.ZIndex = 10
            chev.Name = "Chevron"
            chev.Parent = row
        end

        row.MouseEnter:Connect(function()
            row.BackgroundColor3 = C.surfaceHi
            stk.Color = C.borderHi
            stk.Transparency = 0.3
            badge.BackgroundColor3 = Color3.fromRGB(14, 26, 44)
            badgeStroke.Transparency = 0.2
            if not isToggle then
                local ch = row:FindFirstChild("Chevron")
                if ch then ch.TextColor3 = C.accentCyan end
            end
        end)
        row.MouseLeave:Connect(function()
            row.BackgroundColor3 = C.surface
            stk.Color = C.border
            stk.Transparency = 0.6
            badge.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
            badgeStroke.Transparency = 0.62
            if not isToggle then
                local ch = row:FindFirstChild("Chevron")
                if ch then ch.TextColor3 = C.textDim end
            end
        end)

        return row, track, knob
    end

    local function makeSectionLbl(parent, text, layoutOrder)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -16, 0, 24)
        f.BackgroundTransparency = 1
        f.LayoutOrder = layoutOrder or 0
        f.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -8, 1, 0)
        lbl.Position = UDim2.fromOffset(8, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = C.textDim
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 9
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 9
        lbl.Parent = f
        return f
    end

    local function makeDivider(parent, layoutOrder)
        local d = Instance.new("Frame")
        d.Size = UDim2.new(1, -16, 0, 1)
        d.BackgroundColor3 = C.border
        d.BackgroundTransparency = 0.65
        d.BorderSizePixel = 0
        d.LayoutOrder = layoutOrder or 0
        d.Parent = parent
        return d
    end

    local function makeAccentBtn(parent, icon, iconColor, labelText, layoutOrder, onClick)
        local btn = Instance.new("TextButton")
        btn.Name = "AccentBtn_" .. labelText
        btn.Size = UDim2.new(1, -16, 0, 36)
        btn.BackgroundColor3 = Color3.fromRGB(10, 18, 34)
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.AutoButtonColor = false
        btn.ZIndex = 9
        btn.LayoutOrder = layoutOrder or 0
        btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

        local stk = Instance.new("UIStroke")
        stk.Color = iconColor
        stk.Thickness = 1
        stk.Transparency = 0.5
        stk.Parent = btn

        local hasIcon = icon and icon ~= ""

        if hasIcon then
            local iconL = Instance.new("TextLabel")
            iconL.Size = UDim2.fromOffset(20, 20)
            iconL.Position = UDim2.new(0.5, -50, 0.5, -10)
            iconL.BackgroundTransparency = 1
            iconL.Text = icon
            iconL.TextColor3 = iconColor
            iconL.Font = Enum.Font.GothamBold
            iconL.TextSize = 14
            iconL.ZIndex = 10
            iconL.Parent = btn
        end

        local txtL = Instance.new("TextLabel")
        txtL.Size = UDim2.fromOffset(140, 20)
        txtL.BackgroundTransparency = 1
        txtL.Text = labelText
        txtL.TextColor3 = iconColor
        txtL.Font = Enum.Font.GothamBold
        txtL.TextSize = 12
        txtL.ZIndex = 10
        txtL.Parent = btn

        if hasIcon then
            txtL.Position = UDim2.new(0.5, -34, 0.5, -10)
            txtL.TextXAlignment = Enum.TextXAlignment.Left
        else
            txtL.Position = UDim2.new(0.5, -70, 0.5, -10)
            txtL.TextXAlignment = Enum.TextXAlignment.Center
        end

        btn.MouseButton1Click:Connect(onClick)
        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(14, 28, 54)
            stk.Transparency = 0.1
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(10, 18, 34)
            stk.Transparency = 0.5
        end)
        return btn
    end

    local pages = {}

    local function makePage(tabId)
        local page = Instance.new("Frame")
        page.Name = "Page_" .. tabId
        page.Size = UDim2.new(1, 0, 0, 0)
        page.AutomaticSize = Enum.AutomaticSize.Y
        page.BackgroundTransparency = 1
        page.Visible = (tabId == activeTab)
        page.ZIndex = 8
        page.Parent = content

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 4)
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        layout.Parent = page

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 6)
        pad.PaddingBottom = UDim.new(0, 0)
        pad.Parent = page

        pages[tabId] = page
        return page
    end

    -- ── PAGE: Drone ───────────────────────────────────────────────────────
    local dronePage = makePage("Drone")
    makeSectionLbl(dronePage, "AUTOMATION", 1)

    local r_autoCombat, ind_autoCombat, knob_autoCombat = makeRow(
        dronePage, "RowAutoCombat",
        "C", Color3.fromRGB(255, 90, 70),
        "Auto Combat Drone", true, 2
    )
    r_autoCombat.MouseButton1Click:Connect(function()
        local newState = not State.AutoCombatDrone
        SetFeature("AutoCombatDrone", newState)
        RefreshDroneRefs()
        if newState then
            if not HasControlPad() then
                Notify("No Control Pad", "Equip once", 3)
                SetFeature("AutoCombatDrone", false)
                return
            end
            if State.CombatFollowTarget then
                State.CombatFollowTarget = nil
                pcall(function() Filters.CombatFollowDropdown:Set({}) end)
            end
            Toast("Auto Combat Drone", "Hunting")
        else
            Toast("Auto Combat Drone", "Idle")
        end
    end)

    local r_smartHeal, ind_smartHeal, knob_smartHeal = makeRow(
        dronePage, "RowSmartHeal",
        "+", Color3.fromRGB(60, 210, 150),
        "Smart Heal", true, 3
    )
    r_smartHeal.MouseButton1Click:Connect(function()
        local newState = not State.SmartHeal
        SetFeature("SmartHeal", newState)
        if newState then
            if not HasControlPad() then
                Notify("No Control Pad", "Equip once", 3)
                SetFeature("SmartHeal", false)
                return
            end
            if State.HealingFollowTarget then
                State.HealingFollowTarget = nil
                pcall(function() Filters.HealingFollowDropdown:Set({}) end)
            end
            Toast("Smart Heal", "Monitoring at <" .. State.SmartHealThreshold .. "%")
        else
            Toast("Smart Heal", "Disabled")
        end
    end)

    makeDivider(dronePage, 4)
    makeSectionLbl(dronePage, "COMMANDS", 5)

    local r_combatFollow = makeRow(
        dronePage, "RowCombatFollow",
        "*", Color3.fromRGB(255, 190, 40),
        "Combat Follow Me", false, 6
    )
    r_combatFollow.MouseButton1Click:Connect(function()
        RefreshDroneRefs()
        if not HasControlPad() then Notify("No Control Pad", "Equip once", 3); return end
        if State.AutoCombatDrone then SetFeature("AutoCombatDrone", false) end
        if State.CombatFollowTarget then
            State.CombatFollowTarget = nil
            pcall(function() Filters.CombatFollowDropdown:Set({}) end)
        end
        if Drones.Combat and DroneRemoteCache.SetHover then
            SendHover(Drones.Combat, nil)
            Toast("Combat Drone", "Following you")
        end
    end)

    local r_healFollow = makeRow(
        dronePage, "RowHealFollow",
        "+", Color3.fromRGB(100, 220, 140),
        "Healing Follow Me", false, 7
    )
    r_healFollow.MouseButton1Click:Connect(function()
        RefreshDroneRefs()
        if not HasControlPad() then Notify("No Control Pad", "Equip once", 3); return end
        if State.SmartHeal then SetFeature("SmartHeal", false) end
        if State.HealingFollowTarget then
            State.HealingFollowTarget = nil
            pcall(function() Filters.HealingFollowDropdown:Set({}) end)
        end
        if Drones.Healing and DroneRemoteCache.SetHover then
            SendHover(Drones.Healing, nil)
            Toast("Healing Drone", "Following you")
        end
    end)

    makeDivider(dronePage, 8)

    makeAccentBtn(dronePage,
        "", C.accentCyan, "Recall Both", 9,
        function()
            RefreshDroneRefs()
            if State.AutoCombatDrone then SetFeature("AutoCombatDrone", false) end
            if State.SmartHeal then SetFeature("SmartHeal", false) end
            State.CombatFollowTarget = nil
            State.HealingFollowTarget = nil
            pcall(function() Filters.CombatFollowDropdown:Set({}) end)
            pcall(function() Filters.HealingFollowDropdown:Set({}) end)
            if Drones.Combat and DroneRemoteCache.SetHover then SendHover(Drones.Combat, nil) end
            if Drones.Healing and DroneRemoteCache.SetHover then SendHover(Drones.Healing, nil) end
            Toast("Drones", "Both recalled")
        end
    )

    OnScreenUI.Buttons = {
        AutoCombat = { row = r_autoCombat, indicator = ind_autoCombat, knob = knob_autoCombat },
        SmartHeal  = { row = r_smartHeal,  indicator = ind_smartHeal,  knob = knob_smartHeal  },
    }

    -- ── PAGE: Loot ────────────────────────────────────────────────────────
    local lootPage = makePage("Loot")
    makeSectionLbl(lootPage, "AUTO LOOT", 1)

    local r_autoLoot, ind_autoLoot, knob_autoLoot = makeRow(
        lootPage, "RowAutoLoot",
        "B", Color3.fromRGB(255, 190, 40),
        "Auto Loot", true, 2
    )
    r_autoLoot.MouseButton1Click:Connect(function()
        local v = not State.AutoLoot
        SetFeature("AutoLoot", v)
        Toast("Auto Loot", v and "Enabled" or "Disabled")
    end)

    local r_autoStore, ind_autoStore, knob_autoStore = makeRow(
        lootPage, "RowAutoStore",
        "P", Color3.fromRGB(160, 130, 255),
        "Auto-Store After Pickup", true, 3
    )
    r_autoStore.MouseButton1Click:Connect(function()
        local v = not State.AutoStore
        SetFeature("AutoStore", v)
        Toast("Auto Store", v and "Enabled" or "Disabled")
    end)

    local r_preventBaseLoot, ind_preventBase, knob_preventBase = makeRow(
        lootPage, "RowPreventBase",
        "#", Color3.fromRGB(255, 100, 80),
        "Prevent Base Looting", true, 4
    )
    r_preventBaseLoot.MouseButton1Click:Connect(function()
        local v = not State.PreventBaseLoot
        SetFeature("PreventBaseLoot", v)
        Toast("Prevent Base Loot", v and "On" or "Off")
    end)

    makeDivider(lootPage, 5)
    makeSectionLbl(lootPage, "VISIBILITY", 6)

    local r_crateESP, ind_crateESP, knob_crateESP = makeRow(
        lootPage, "RowCrateESP",
        ".", Color3.fromRGB(255, 150, 40),
        "Crate ESP", true, 7
    )
    r_crateESP.MouseButton1Click:Connect(function()
        local v = not State.CrateESP
        SetFeature("CrateESP", v)
        Toast("Crate ESP", v and "On" or "Off")
    end)

    local r_itemESP, ind_itemESP, knob_itemESP = makeRow(
        lootPage, "RowItemESP",
        "+", Color3.fromRGB(180, 220, 255),
        "Item ESP", true, 8
    )
    r_itemESP.MouseButton1Click:Connect(function()
        local v = not State.ItemESP
        SetFeature("ItemESP", v)
        Toast("Item ESP", v and "On" or "Off")
    end)

    OnScreenUI.Buttons.AutoLoot       = { row = r_autoLoot,        indicator = ind_autoLoot,       knob = knob_autoLoot       }
    OnScreenUI.Buttons.AutoStore      = { row = r_autoStore,       indicator = ind_autoStore,      knob = knob_autoStore      }
    OnScreenUI.Buttons.PreventBase    = { row = r_preventBaseLoot, indicator = ind_preventBase,    knob = knob_preventBase    }
    OnScreenUI.Buttons.CrateESP       = { row = r_crateESP,        indicator = ind_crateESP,       knob = knob_crateESP       }
    OnScreenUI.Buttons.ItemESP        = { row = r_itemESP,         indicator = ind_itemESP,        knob = knob_itemESP        }

    -- ── PAGE: Combat ──────────────────────────────────────────────────────
    local combatPage = makePage("Combat")
    makeSectionLbl(combatPage, "SHOOTING", 1)

    local r_autoShoot, ind_autoShoot, knob_autoShoot = makeRow(
        combatPage, "RowAutoShoot",
        "@", Color3.fromRGB(255, 80, 80),
        "Auto Shoot", true, 2
    )
    r_autoShoot.MouseButton1Click:Connect(function()
        local v = not State.AutoShoot
        SetFeature("AutoShoot", v)
        Toast("Auto Shoot", v and "Enabled" or "Disabled")
    end)

    local r_rapidFire, ind_rapidFire, knob_rapidFire = makeRow(
        combatPage, "RowRapidFire",
        "!", Color3.fromRGB(255, 220, 40),
        "Rapid Fire", true, 3
    )
    r_rapidFire.MouseButton1Click:Connect(function()
        local v = not State.RapidFire
        SetFeature("RapidFire", v)
        Toast("Rapid Fire", v and ("Enabled - " .. State.RapidFireMult .. "x") or "Disabled")
    end)

    local r_killAura, ind_killAura, knob_killAura = makeRow(
        combatPage, "RowKillAura",
        "!", Color3.fromRGB(220, 60, 60),
        "Kill Aura", true, 4
    )
    r_killAura.MouseButton1Click:Connect(function()
        local v = not State.KillAura
        SetFeature("KillAura", v)
        Toast("Kill Aura", v and "Enabled" or "Disabled")
    end)

    makeDivider(combatPage, 5)
    makeSectionLbl(combatPage, "MOVEMENT", 6)

    local r_speedHack, ind_speedHack, knob_speedHack = makeRow(
        combatPage, "RowSpeedHack",
        ">", Color3.fromRGB(80, 200, 255),
        "Speed Hack", true, 7
    )
    r_speedHack.MouseButton1Click:Connect(function()
        local v = not State.SpeedHack
        SetFeature("SpeedHack", v)
        Toast("Speed Hack", v and ("Enabled - " .. State.SpeedValue .. " spd") or "Disabled")
    end)

    local r_infJump, ind_infJump, knob_infJump = makeRow(
        combatPage, "RowInfJump",
        "^", Color3.fromRGB(130, 255, 160),
        "Infinite Jump", true, 8
    )
    r_infJump.MouseButton1Click:Connect(function()
        local v = not State.InfJump
        SetFeature("InfJump", v)
        Toast("Infinite Jump", v and "Enabled" or "Disabled")
    end)

    local r_hitbox, ind_hitbox, knob_hitbox = makeRow(
        combatPage, "RowHitbox",
        "#", Color3.fromRGB(255, 150, 80),
        "Hitbox Expander", true, 9
    )
    r_hitbox.MouseButton1Click:Connect(function()
        local v = not State.HitboxExpand
        SetFeature("HitboxExpand", v)
        Toast("Hitbox Expander", v and "Enabled" or "Disabled")
    end)

    OnScreenUI.Buttons.AutoShoot  = { row = r_autoShoot,  indicator = ind_autoShoot,  knob = knob_autoShoot  }
    OnScreenUI.Buttons.RapidFire  = { row = r_rapidFire,  indicator = ind_rapidFire,  knob = knob_rapidFire  }
    OnScreenUI.Buttons.KillAura   = { row = r_killAura,   indicator = ind_killAura,   knob = knob_killAura   }
    OnScreenUI.Buttons.SpeedHack  = { row = r_speedHack,  indicator = ind_speedHack,  knob = knob_speedHack  }
    OnScreenUI.Buttons.InfJump    = { row = r_infJump,    indicator = ind_infJump,    knob = knob_infJump    }
    OnScreenUI.Buttons.Hitbox     = { row = r_hitbox,     indicator = ind_hitbox,     knob = knob_hitbox     }

    -- ── PAGE: Player ──────────────────────────────────────────────────────
    local playerPage = makePage("Player")
    makeSectionLbl(playerPage, "SURVIVAL", 1)

    local r_autoHeal, ind_autoHeal, knob_autoHeal = makeRow(
        playerPage, "RowAutoHeal",
        "+", Color3.fromRGB(255, 80, 100),
        "Auto Heal", true, 2
    )
    r_autoHeal.MouseButton1Click:Connect(function()
        local v = not State.AutoHeal
        SetFeature("AutoHeal", v)
        Toast("Auto Heal", v and ("Below " .. State.AutoHealThreshold .. "%") or "Disabled")
    end)

    local r_autoEat, ind_autoEat, knob_autoEat = makeRow(
        playerPage, "RowAutoEat",
        "%", Color3.fromRGB(255, 160, 60),
        "Auto Eat", true, 3
    )
    r_autoEat.MouseButton1Click:Connect(function()
        local v = not State.AutoEat
        SetFeature("AutoEat", v)
        Toast("Auto Eat", v and ("Below " .. State.AutoEatThreshold .. "%") or "Disabled")
    end)

    makeDivider(playerPage, 4)
    makeSectionLbl(playerPage, "VISUALS", 5)

    local r_removeFog, ind_removeFog, knob_removeFog = makeRow(
        playerPage, "RowRemoveFog",
        "~", Color3.fromRGB(160, 190, 220),
        "Remove Fog", true, 6
    )
    r_removeFog.MouseButton1Click:Connect(function()
        local v = not State.RemoveFog
        SetFeature("RemoveFog", v)
        Toast("Remove Fog", v and "Removed" or "Restored")
    end)

    local r_fullbright, ind_fullbright, knob_fullbright = makeRow(
        playerPage, "RowFullbright",
        "O", Color3.fromRGB(255, 240, 100),
        "Fullbright", true, 7
    )
    r_fullbright.MouseButton1Click:Connect(function()
        local v = not State.Fullbright
        SetFeature("Fullbright", v)
        Toast("Fullbright", v and "On" or "Off")
    end)

    makeDivider(playerPage, 8)
    makeSectionLbl(playerPage, "UTILITY", 9)

    local r_antiAfk, ind_antiAfk, knob_antiAfk = makeRow(
        playerPage, "RowAntiAFK",
        "T", Color3.fromRGB(100, 200, 255),
        "Anti-AFK", true, 10
    )
    r_antiAfk.MouseButton1Click:Connect(function()
        local v = not State.AntiAFK
        SetFeature("AntiAFK", v)
        Toast("Anti-AFK", v and "On" or "Off")
    end)

    OnScreenUI.Buttons.AutoHeal   = { row = r_autoHeal,    indicator = ind_autoHeal,   knob = knob_autoHeal   }
    OnScreenUI.Buttons.AutoEat    = { row = r_autoEat,     indicator = ind_autoEat,    knob = knob_autoEat    }
    OnScreenUI.Buttons.RemoveFog  = { row = r_removeFog,   indicator = ind_removeFog,  knob = knob_removeFog  }
    OnScreenUI.Buttons.Fullbright = { row = r_fullbright,  indicator = ind_fullbright, knob = knob_fullbright }
    OnScreenUI.Buttons.AntiAFK    = { row = r_antiAfk,     indicator = ind_antiAfk,    knob = knob_antiAfk    }

    local tabBtns = {}
    local function setActiveTab(tabId)
        activeTab = tabId
        for _, t in ipairs(TABS) do
            local btn = tabBtns[t.id]
            local pg  = pages[t.id]
            if t.id == tabId then
                btn.BackgroundColor3 = C.tabActive
                btn.TextColor3 = Color3.fromRGB(10, 10, 20)
                if pg then pg.Visible = true end
            else
                btn.BackgroundColor3 = C.tabInactive
                btn.TextColor3 = C.tabTextOff
                if pg then pg.Visible = false end
            end
        end
    end

    for i, t in ipairs(TABS) do
        local btn = Instance.new("TextButton")
        btn.Name = "Tab_" .. t.id
        btn.Size = UDim2.new(0.25, -2, 1, 0)
        btn.BackgroundColor3 = (t.id == activeTab) and C.tabActive or C.tabInactive
        btn.BorderSizePixel = 0
        btn.Text = t.label
        btn.TextColor3 = (t.id == activeTab) and Color3.fromRGB(10, 10, 20) or C.tabTextOff
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.AutoButtonColor = false
        btn.ZIndex = 10
        btn.LayoutOrder = i
        btn.Parent = tabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)

        tabBtns[t.id] = btn
        local tid = t.id
        btn.MouseButton1Click:Connect(function() setActiveTab(tid) end)
    end

    local panelOpen = false
    local TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    local function slidePanel(open)
        local targetX = open and PANEL_OPEN_X or PANEL_CLOSED_X
        panelOpen = open
        TweenService:Create(
            panel,
            TWEEN_INFO,
            { Position = UDim2.new(0, targetX, 0.5, 0) }
        ):Play()
    end

    trigger.MouseButton1Click:Connect(function()
        slidePanel(not panelOpen)
        trigAccent.BackgroundColor3 = panelOpen and C.accentCyan or C.border
    end)

    closeBtn.MouseEnter:Connect(function()
        closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
        closeBtn.BackgroundColor3 = Color3.fromRGB(50, 22, 28)
        closeBtnStroke.Color = Color3.fromRGB(255, 80, 80)
        closeBtnStroke.Transparency = 0.2
    end)
    closeBtn.MouseLeave:Connect(function()
        closeBtn.TextColor3 = C.textDim
        closeBtn.BackgroundColor3 = Color3.fromRGB(32, 28, 44)
        closeBtnStroke.Color = C.border
        closeBtnStroke.Transparency = 0.5
    end)
    closeBtn.MouseButton1Click:Connect(function()
        slidePanel(false)
        trigAccent.BackgroundColor3 = C.border
    end)

    trigger.MouseEnter:Connect(function()
        trigStroke.Color = C.borderHi
        trigStroke.Transparency = 0.15
    end)
    trigger.MouseLeave:Connect(function()
        trigStroke.Color = C.border
        trigStroke.Transparency = 0.3
    end)

    OnScreenUI.StatusDot  = statusDot
    OnScreenUI.StatusGlow = statusGlow
    OnScreenUI.Panel      = panel
end

CreateQuickActionMenu()

-- ═════════════════════════════════════════════════════════════════════
--  OVERLAY SYNC LOOP
-- ═════════════════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(0.2)
        if OnScreenUI and OnScreenUI.Gui and OnScreenUI.Gui.Parent and OnScreenUI.Buttons then
            local function setToggle(entry, isActive)
                if not entry or not entry.knob or not entry.indicator then return end
                if isActive then
                    entry.indicator.BackgroundColor3 = Color3.fromRGB(0, 130, 185)
                    entry.indicator.Stroke.Color = Color3.fromRGB(0, 200, 255)
                    entry.indicator.Stroke.Transparency = 0.1
                    entry.knob.BackgroundColor3 = Color3.fromRGB(230, 248, 255)
                    entry.knob.Position = UDim2.fromOffset(19, 3)
                else
                    entry.indicator.BackgroundColor3 = Color3.fromRGB(28, 25, 38)
                    entry.indicator.Stroke.Color = Color3.fromRGB(42, 38, 58)
                    entry.indicator.Stroke.Transparency = 0.45
                    entry.knob.BackgroundColor3 = Color3.fromRGB(82, 76, 102)
                    entry.knob.Position = UDim2.fromOffset(3, 3)
                end
            end

            setToggle(OnScreenUI.Buttons.AutoCombat,  State.AutoCombatDrone)
            setToggle(OnScreenUI.Buttons.SmartHeal,   State.SmartHeal)
            setToggle(OnScreenUI.Buttons.AutoLoot,    State.AutoLoot)
            setToggle(OnScreenUI.Buttons.AutoStore,   State.AutoStore)
            setToggle(OnScreenUI.Buttons.PreventBase, State.PreventBaseLoot)
            setToggle(OnScreenUI.Buttons.CrateESP,    State.CrateESP)
            setToggle(OnScreenUI.Buttons.ItemESP,     State.ItemESP)
            setToggle(OnScreenUI.Buttons.AutoShoot,   State.AutoShoot)
            setToggle(OnScreenUI.Buttons.RapidFire,   State.RapidFire)
            setToggle(OnScreenUI.Buttons.KillAura,    State.KillAura)
            setToggle(OnScreenUI.Buttons.SpeedHack,   State.SpeedHack)
            setToggle(OnScreenUI.Buttons.InfJump,     State.InfJump)
            setToggle(OnScreenUI.Buttons.Hitbox,      State.HitboxExpand)
            setToggle(OnScreenUI.Buttons.AutoHeal,    State.AutoHeal)
            setToggle(OnScreenUI.Buttons.AutoEat,     State.AutoEat)
            setToggle(OnScreenUI.Buttons.RemoveFog,   State.RemoveFog)
            setToggle(OnScreenUI.Buttons.Fullbright,  State.Fullbright)
            setToggle(OnScreenUI.Buttons.AntiAFK,     State.AntiAFK)

            local anyActive = State.AutoCombatDrone or State.SmartHeal
            local col = anyActive and Color3.fromRGB(0, 220, 130) or Color3.fromRGB(82, 76, 102)
            if OnScreenUI.StatusDot then
                OnScreenUI.StatusDot.BackgroundColor3 = col
            end
            if OnScreenUI.StatusGlow then
                OnScreenUI.StatusGlow.ImageColor3 = col
            end
        end
    end
end)

Notify("KissoHub", "Survive the Apocalypse " .. HUB_VERSION .. " loaded", 3)
