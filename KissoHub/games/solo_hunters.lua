-- =================================================================
-- KissoHub — SoloHunter Edition (Gen2 Correct)
-- =================================================================
local HttpService = game:GetService("HttpService")

-- Rayfield Gen2 with failover
local Rayfield
local ok, res = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)
if ok and res then
    Rayfield = res
else
    Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLTD/Rayfield/main/source.lua"))()
end

-- =================================================================
-- SERVICES
-- =================================================================
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local UserInputService    = game:GetService("UserInputService")
local Lighting            = game:GetService("Lighting")
local TeleportService     = game:GetService("TeleportService")
local LocalPlayer         = Players.LocalPlayer

local ASSET_ICON = "rbxassetid://89387722763691"
local SessionStartTime = os.time()

-- =================================================================
-- HELPER: Bottom-Left Screen Position
-- =================================================================
local function getBottomLeftPos()
    local camera = workspace.CurrentCamera
    if camera then
        return 10, math.max(0, camera.ViewportSize.Y - 10)
    end
    return 10, 500
end

-- =================================================================
-- USER ACTIVITY TRACKER
-- =================================================================
local lastUserInputTime = 0
local isProgrammaticInput = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not isProgrammaticInput then
        local t = input.UserInputType
        if t == Enum.UserInputType.Touch
           or t == Enum.UserInputType.MouseButton1
           or t == Enum.UserInputType.MouseButton2
           or t == Enum.UserInputType.Keyboard then
            lastUserInputTime = os.clock()
        end
    end
end)

-- =================================================================
-- REMOTES
-- =================================================================
local remoteServices = ReplicatedStorage:WaitForChild("RemoteServices", 10)
local remotesFolder  = ReplicatedStorage:WaitForChild("Remotes", 10)

local healRemote         = remoteServices and remoteServices:WaitForChild("HealingService"):WaitForChild("RF"):WaitForChild("UseHeal")
local useWeaponRemote    = remoteServices and remoteServices:WaitForChild("CombatService"):WaitForChild("RF"):WaitForChild("UseWeapon")
local startDungeonRemote = remoteServices and remoteServices:WaitForChild("DungeonService"):WaitForChild("RF"):WaitForChild("StartDungeon")
local enterGateRemote    = remoteServices and remoteServices:WaitForChild("PortalService"):WaitForChild("RF"):WaitForChild("CanEnterGate")

local merchantService        = remoteServices and remoteServices:WaitForChild("MerchantService", 10)
local merchantRF             = merchantService and merchantService:WaitForChild("RF", 10)
local getMerchantItemsRemote = merchantRF and merchantRF:WaitForChild("GetItems", 10)
local buyMerchantRemote      = merchantRF and merchantRF:WaitForChild("Buy", 10)

local shadowExtractService = remoteServices and remoteServices:WaitForChild("ShadowExtractService", 10)
local shadowExtractRF      = shadowExtractService and shadowExtractService:WaitForChild("RF", 10)
local massExtractRemote    = shadowExtractRF and shadowExtractRF:WaitForChild("MassExtract", 10)

local teleportIntoDungeon = remoteServices and remoteServices:WaitForChild("DungeonService"):WaitForChild("RE"):WaitForChild("TeleportIntoDungeon")
local teleportedSignal    = remoteServices and remoteServices:WaitForChild("PortalService"):WaitForChild("RE"):WaitForChild("TeleportedSignal")

local fullDungeonRemote    = remotesFolder and remotesFolder:WaitForChild("FullDungeonRemote")
local dropCreatedRemote    = remoteServices and remoteServices:WaitForChild("DropsService"):WaitForChild("RE"):WaitForChild("DropCreatedSignal")
local collectDropRemote    = remoteServices and remoteServices:WaitForChild("DropsService"):WaitForChild("RF"):WaitForChild("CollectDrop")

local spawnChestRemote     = remoteServices and remoteServices:WaitForChild("BossDropsService"):WaitForChild("RE"):WaitForChild("SpawnChest")
local openChestRemote      = remoteServices and remoteServices:WaitForChild("BossDropsService"):WaitForChild("RF"):WaitForChild("OpenChest")
local retryDungeonRemote   = remoteServices and remoteServices:WaitForChild("DungeonService"):WaitForChild("RF"):WaitForChild("SpawnQuickPortal")

-- =================================================================
-- MERCHANT CONFIG
-- =================================================================
local merchantItemMap = {}
local merchantItemNames = {}

pcall(function()
    local merchantConfigModule = ReplicatedStorage:WaitForChild("Modules", 5)
        :WaitForChild("Shared", 5)
        :WaitForChild("Config", 5)
        :WaitForChild("Economy", 5)
        :WaitForChild("MerchantItems", 5)

    local configData = require(merchantConfigModule)
    if configData and configData["Normal"] then
        for index, itemInfo in ipairs(configData["Normal"]) do
            local itemName = itemInfo.Base or ("Item_" .. tostring(index))
            local slotKey = tostring(index)
            merchantItemMap[itemName] = slotKey
            table.insert(merchantItemNames, itemName)
        end
    end
end)

if #merchantItemNames == 0 then
    merchantItemNames = {
        "Demon Castle Ticket", "Powercell1", "Shadow Trace", "Shadow Essence",
        "Basic Scroll", "Epic Scroll", "Legendary Scroll", "Powercell2",
        "Powercell3", "Magic Fruit", "Stat Crystal", "Perfect Stat Cube"
    }
    for i, name in ipairs(merchantItemNames) do
        merchantItemMap[name] = tostring(i)
    end
end

-- =================================================================
-- CONFIG VARIABLES (unchanged)
-- =================================================================
local autoAttackEnabled   = false
local autoAttackRange     = 300
local autoEquipEnabled    = true
local filterMobsEnabled   = true
local M1_SPEED            = 0.12

local exactPartAlignment  = false
local attackDistance      = 3
local HOVER_HEIGHT        = 4

local autoSkillsEnabled   = false
local castF, castR, castC, castG, castV = false, false, false, false, false
local SKILL_INTERVAL      = 1.5

local autoPotionEnabled   = true
local safeSpotEnabled     = false
local safeHpPercent       = 25
local safeSpotActive      = false
local SAFE_HOVER_HEIGHT   = 100

local autoCollectDrops    = false
local autoOpenChests      = false
local autoMassExtract     = false

local tpAboveChestEnabled  = false
local tpAboveChestDistance = 500

local autoBuyMerchantEnabled = false
local selectedMerchantItems  = {}
local merchantBuyDelay       = 2

local espEnabled             = false
local autoDungeonEnabled     = true
local autoRetryEnabled       = false
local autoDemonCastleEnabled = false
local autoDungeonRange       = 50
local retryDelay             = 2.5

local lowVfxEnabled          = false
local ultraLowEnabled        = false

local movementMethod         = "Teleport"
local tweenSpeed             = 150
local positioningMode        = "Above"
local circleAngle            = 0

local isDungeonCleared       = false
local isFlyingToTarget       = false

-- =================================================================
-- VFX / GRAPHICS ENGINE
-- =================================================================
local function isVFXInstance(inst)
    return inst:IsA("ParticleEmitter") or inst:IsA("Smoke") or inst:IsA("Fire")
        or inst:IsA("Sparkles") or inst:IsA("Trail") or inst:IsA("Beam")
        or inst:IsA("Explosion")
end

local function applyLowVFXToInstance(inst)
    if not (lowVfxEnabled or ultraLowEnabled) then return end
    if isVFXInstance(inst) then
        pcall(function() inst.Enabled = false end)
    elseif inst:IsA("PostEffect") or inst:IsA("BloomEffect") or inst:IsA("BlurEffect")
        or inst:IsA("ColorCorrectionEffect") or inst:IsA("DepthOfFieldEffect") or inst:IsA("SunRaysEffect") then
        pcall(function() inst.Enabled = false end)
    end
end

local function applyUltraLowToInstance(inst)
    if not ultraLowEnabled then return end
    if inst:IsA("BasePart") then
        pcall(function()
            inst.Material = Enum.Material.SmoothPlastic
            inst.CastShadow = false
        end)
    elseif inst:IsA("Decal") or inst:IsA("Texture") then
        pcall(function() inst.Transparency = 1 end)
    elseif inst:IsA("SurfaceAppearance") then
        pcall(function() inst:Destroy() end)
    end
end

local function applyLowVFX()
    if lowVfxEnabled or ultraLowEnabled then
        for _, v in ipairs(workspace:GetDescendants()) do applyLowVFXToInstance(v) end
        for _, v in ipairs(Lighting:GetDescendants()) do applyLowVFXToInstance(v) end
    end
end

local function applyUltraLow()
    if ultraLowEnabled then
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
        end)
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            pcall(function()
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 0
            end)
        end
        for _, v in ipairs(workspace:GetDescendants()) do
            applyLowVFXToInstance(v)
            applyUltraLowToInstance(v)
        end
    end
end

workspace.DescendantAdded:Connect(function(child)
    if lowVfxEnabled or ultraLowEnabled then
        task.spawn(function()
            applyLowVFXToInstance(child)
            applyUltraLowToInstance(child)
        end)
    end
end)

Lighting.DescendantAdded:Connect(function(child)
    if lowVfxEnabled or ultraLowEnabled then
        task.spawn(function() applyLowVFXToInstance(child) end)
    end
end)

-- =================================================================
-- SIGNAL FIRER
-- =================================================================
local function safeFireSignal(event, ...)
    if firesignal then
        local ok2, err = pcall(firesignal, event, ...)
        if not ok2 then warn("KissoHub: Failed to fire signal - " .. tostring(err)) end
    else
        warn("KissoHub: Current executor does not support 'firesignal'.")
    end
end

-- =================================================================
-- NOCLIP
-- =================================================================
local characterParts = {}
local function cacheCharacterParts(char)
    characterParts = {}
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then table.insert(characterParts, part) end
    end
    char.DescendantAdded:Connect(function(part)
        if part:IsA("BasePart") then table.insert(characterParts, part) end
    end)
end

if LocalPlayer.Character then cacheCharacterParts(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(cacheCharacterParts)

local noclipConnection
local function updateNoclipState()
    local shouldNoclip = (autoAttackEnabled or safeSpotActive) and (movementMethod == "Tween")
    if shouldNoclip then
        if not noclipConnection then
            noclipConnection = RunService.Stepped:Connect(function()
                for i = #characterParts, 1, -1 do
                    local part = characterParts[i]
                    if part and part.Parent then
                        part.CanCollide = false
                    else
                        table.remove(characterParts, i)
                    end
                end
            end)
        end
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
    end
end

-- =================================================================
-- KISSOHUB WINDOW (GEN2 — CORRECT KEYS)
-- =================================================================
local Window = Rayfield:CreateWindow({
    name = "KissoHub",
    subtitle = "SoloHunter Edition",
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
        fileName = "SoloHunterPrefs",
        customFolder = "KissoHubFolder",
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
            title = title or "KissoHub",
            content = content or "",
            duration = duration or 4,
            icon = ASSET_ICON,
        })
    end)
end

local function QuickToast(title, subtitle)
    pcall(function()
        Window:Toast({
            title = title,
            subtitle = subtitle,
            position = "Top",
            icon = ASSET_ICON,
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
local HomeTab    = Window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })
local HelpTab    = Window:CreateTab({ name = "📖 Help" })
local CombatTab  = Window:CreateTab({ name = "⚔️ Combat & Movement" })
local UtilityTab = Window:CreateTab({ name = "🧰 Utilities & HP" })
local ShopTab    = Window:CreateTab({ name = "🛒 Shop" })
local VisualsTab = Window:CreateTab({ name = "🎨 Visuals & Dungeons" })
local ConfigTab  = Window:CreateTab({ name = "⚙️ Configuration" })

-- =================================================================
-- HOME TAB
-- =================================================================
HomeTab:CreateSection({ name = "📊 Stats" })
local SessionStat  = HomeTab:CreateStat({ name = "⏱️ Session", value = 0, suffix = " m", compact = true })
local FeaturesStat = HomeTab:CreateStat({ name = "⚙️ Features", value = 0, compact = true })
local FpsStat      = HomeTab:CreateStat({ name = "🎮 FPS", value = 0, compact = true })
local PlayersStat  = HomeTab:CreateStat({ name = "👥 Players", value = 1, compact = true })
local TargetStat   = HomeTab:CreateStat({ name = "🎯 Target", value = 0, compact = true })

HomeTab:CreateDivider({ text = "controls" })
HomeTab:CreateSection({ name = "🌐 Server Utilities" })
HomeTab:CreateButton({
    name = "📋 Copy Job ID",
    callback = function()
        if setclipboard then
            setclipboard(game.JobId)
            QuickToast("Copied", "Job ID copied to clipboard")
        end
    end,
})

HomeTab:CreateButton({
    name = "🔄 Rejoin Server",
    callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end,
})

-- =================================================================
-- HELP TAB (using CreateText — the Gen2 correct element)
-- =================================================================
HelpTab:CreateSection({ name = "System Logic & Operations Manual" })

HelpTab:CreateText({
    name = "1. Auto Attack & Flight Engine",
    text = "• WHAT IT DOES: Locks onto the closest target within your 'Detection Range', flies your character directly above/around the mob, and automatically attacks.\n• HOW TO USE: Enable 'Auto Attack'. Choose 'Teleport' for instant positioning, or 'Tween' for smooth movement (includes automatic Noclip to bypass obstacles)."
})

HelpTab:CreateText({
    name = "2. Positioning Modes (Above vs Circle)",
    text = "• WHAT IT DOES: Determines where your character floats relative to the target mob.\n• ABOVE: Places you vertically above the mob at 'Classic Hover Height'. Best for avoiding ground attacks.\n• CIRCLE: Rotates your character in an orbital ring around the mob. Useful against bosses with frontal directional attacks."
})

HelpTab:CreateText({
    name = "3. Auto Skills System",
    text = "• WHAT IT DOES: Periodically triggers selected skill keys (F, R, C, G, V) when you are close enough to a locked enemy.\n• HOW TO USE: Toggle 'Auto Cast Skills', then turn on the specific Skill Binds you want to cast. Note: Requires 'Auto Attack' to be enabled."
})

HelpTab:CreateText({
    name = "4. Emergency Safe Spot System",
    text = "• WHAT IT DOES: Acts as an emergency cheat-death protocol. When your HP drops below the 'Trigger HP %', your character is instantly rocketed 100 studs into the air until your HP recovers to 90%.\n• HOW TO USE: Set 'Safe Spot Trigger HP %' lower than your potion threshold (e.g., 25%). Useful for soloing high-level raids or bosses."
})

HelpTab:CreateText({
    name = "5. Auto Retry & Demon Castle Logic",
    text = "• AUTO RETRY: Automatically triggers the retry remote or clicks the 'Replay/Retry' UI button upon dungeon completion.\n• AUTO DEMON CASTLE: Automatically listens for floor portal spawns and bypasses gate delays to instantly teleport you to the next floor."
})

HelpTab:CreateText({
    name = "6. Silent Merchant Auto-Buy",
    text = "• WHAT IT DOES: Automatically scans the Merchant's server inventory and purchases selected items directly via server remotes, without opening shop UIs or creating notifications.\n• HOW TO USE: Select items from the dropdown, toggle 'Auto Buy Merchant Items', and adjust the scan interval."
})

HelpTab:CreateText({
    name = "7. Low VFX & Ultra Low Graphics",
    text = "• LOW VFX: Disables particle effects, beams, trails, and lighting effects to reduce visual clutter.\n• ULTRA LOW GRAPHICS: Turns textures into SmoothPlastic, removes shadows/decals, and strips fog to maximize FPS on low-end devices."
})

-- =================================================================
-- COMBAT & MOVEMENT TAB
-- =================================================================
CombatTab:CreateSection({ name = "🎯 Attack Engine" })

CombatTab:CreateToggle({
    name = "Auto Attack (Lock, Fly & Attack)",
    flag = "MCE_AutoAttack",
    value = false,
    callback = function(Value)
        autoAttackEnabled = Value
        updateNoclipState()
        if Value then SetActivity(true, "COMBAT") end
    end,
})

CombatTab:CreateToggle({
    name = "Auto Cast Skills (Requires Auto Attack)",
    flag = "MCE_AutoSkills",
    value = false,
    callback = function(Value) autoSkillsEnabled = Value end,
})

CombatTab:CreateToggle({
    name = "Filter Mobs (Ignore Invincible/Immune/Extra)",
    flag = "MCE_FilterMobs",
    value = true,
    callback = function(Value) filterMobsEnabled = Value end,
})

CombatTab:CreateToggle({
    name = "Auto-Equip Weapon",
    flag = "MCE_AutoEquip",
    value = true,
    callback = function(Value) autoEquipEnabled = Value end,
})

CombatTab:CreateSlider({
    name = "Auto Attack Detection Range",
    flag = "MCE_AttackRange",
    range = { 10, 5000 },
    increment = 50,
    value = 300,
    suffix = " studs",
    callback = function(Value) autoAttackRange = Value end,
})

CombatTab:CreateToggle({
    name = "Exact Part Alignment (No Hitbox)",
    flag = "MCE_ExactAlignment",
    value = false,
    callback = function(Value) exactPartAlignment = Value end,
})

CombatTab:CreateSlider({
    name = "Attack Proximity Distance",
    flag = "MCE_ProximityDist",
    range = { 1, 15 },
    increment = 1,
    value = 3,
    suffix = " studs",
    callback = function(Value) attackDistance = Value end,
})

CombatTab:CreateSlider({
    name = "Classic Hover Height",
    flag = "MCE_HoverHeight",
    range = { 0, 30 },
    increment = 1,
    value = 4,
    suffix = " studs",
    callback = function(Value) HOVER_HEIGHT = Value end,
})

CombatTab:CreateDivider({ text = "skill binds" })
CombatTab:CreateSection({ name = "🔮 Individual Skill Binds" })

CombatTab:CreateToggle({ name = "Cast [F] Skill", flag = "MCE_CastF", value = false, callback = function(V) castF = V end })
CombatTab:CreateToggle({ name = "Cast [R] Skill", flag = "MCE_CastR", value = false, callback = function(V) castR = V end })
CombatTab:CreateToggle({ name = "Cast [C] Skill", flag = "MCE_CastC", value = false, callback = function(V) castC = V end })
CombatTab:CreateToggle({ name = "Cast [G] Skill", flag = "MCE_CastG", value = false, callback = function(V) castG = V end })
CombatTab:CreateToggle({ name = "Cast [V] Skill", flag = "MCE_CastV", value = false, callback = function(V) castV = V end })

-- =================================================================
-- UTILITIES & HP TAB
-- =================================================================
UtilityTab:CreateSection({ name = "📦 Chest Utilities" })

UtilityTab:CreateToggle({
    name = "Auto Open Chests",
    flag = "MCE_AutoOpenChests",
    value = false,
    callback = function(Value) autoOpenChests = Value end,
})

UtilityTab:CreateToggle({
    name = "TP Above Chest",
    flag = "MCE_TpAboveChest",
    value = false,
    callback = function(Value) tpAboveChestEnabled = Value end,
})

UtilityTab:CreateSlider({
    name = "TP Above Chest Distance Limit",
    flag = "MCE_TpAboveChestDistance",
    range = { 50, 1000 },
    increment = 25,
    value = 500,
    suffix = " studs",
    callback = function(Value) tpAboveChestDistance = Value end,
})

UtilityTab:CreateDivider({ text = "general" })
UtilityTab:CreateSection({ name = "🎁 Drops & Recovery" })

UtilityTab:CreateToggle({
    name = "Auto Collect Drops",
    flag = "MCE_AutoCollectDrops",
    value = false,
    callback = function(Value) autoCollectDrops = Value end,
})

UtilityTab:CreateToggle({
    name = "Auto Mass Extract Shadows",
    flag = "MCE_AutoMassExtract",
    value = false,
    callback = function(Value) autoMassExtract = Value end,
})

UtilityTab:CreateToggle({
    name = "Auto-Potion (Below 50% HP)",
    flag = "MCE_AutoPotion",
    value = true,
    callback = function(Value) autoPotionEnabled = Value end,
})

UtilityTab:CreateToggle({
    name = "Auto Safe Spot (Bypass Disconnect)",
    flag = "MCE_SafeSpot",
    value = false,
    callback = function(Value)
        safeSpotEnabled = Value
        if not Value then
            safeSpotActive = false
            updateNoclipState()
        end
    end,
})

UtilityTab:CreateSlider({
    name = "Safe Spot Trigger HP %",
    flag = "MCE_SafeSpotHP",
    range = { 10, 50 },
    increment = 5,
    value = 25,
    suffix = " %",
    callback = function(Value) safeHpPercent = Value end,
})

-- =================================================================
-- SHOP TAB
-- =================================================================
ShopTab:CreateSection({ name = "🛒 Merchant Vending Machine" })

ShopTab:CreateToggle({
    name = "Auto Buy Merchant Items",
    flag = "MCE_AutoBuyMerchant",
    value = false,
    callback = function(Value) autoBuyMerchantEnabled = Value end,
})

ShopTab:CreateDropdown({
    name = "Select Items to Auto-Buy",
    flag = "MCE_MerchantSelectItems",
    options = merchantItemNames,
    multiSelect = true,
    value = {},
    callback = function(Options)
        selectedMerchantItems = type(Options) == "table" and Options or { Options }
    end,
})

ShopTab:CreateSlider({
    name = "Check Stock Interval (Sec)",
    flag = "MCE_MerchantCheckDelay",
    range = { 1, 10 },
    increment = 0.5,
    value = 2,
    suffix = " s",
    callback = function(Value) merchantBuyDelay = Value end,
})

-- =================================================================
-- VISUALS & DUNGEONS TAB
-- =================================================================
VisualsTab:CreateSection({ name = "🎨 Graphics & Performance" })

VisualsTab:CreateToggle({
    name = "Low VFX (Disable Particles & Skill Effects)",
    flag = "MCE_LowVFX",
    value = false,
    callback = function(Value)
        lowVfxEnabled = Value
        applyLowVFX()
    end,
})

VisualsTab:CreateToggle({
    name = "Ultra Low Graphics (Potato Mode)",
    flag = "MCE_UltraLow",
    value = false,
    callback = function(Value)
        ultraLowEnabled = Value
        applyUltraLow()
    end,
})

VisualsTab:CreateDivider({ text = "dungeon" })
VisualsTab:CreateSection({ name = "🏰 Dungeon Automation" })

VisualsTab:CreateToggle({
    name = "Enemy ESP",
    flag = "MCE_EnemyESP",
    value = false,
    callback = function(Value)
        espEnabled = Value
        if not Value then
            local mobsFolder = workspace:FindFirstChild("Mobs")
            if mobsFolder then
                for _, v in ipairs(mobsFolder:GetDescendants()) do
                    if v.Name == "CombatEngineESP" then v:Destroy() end
                end
            end
        end
    end,
})

VisualsTab:CreateToggle({
    name = "Auto Start Dungeon",
    flag = "MCE_AutoDungeon",
    value = true,
    callback = function(Value) autoDungeonEnabled = Value end,
})

VisualsTab:CreateToggle({
    name = "Auto Retry Dungeon",
    flag = "MCE_AutoRetry",
    value = false,
    callback = function(Value) autoRetryEnabled = Value end,
})

VisualsTab:CreateSlider({
    name = "Auto Retry Delay (Seconds)",
    flag = "MCE_RetryDelay",
    range = { 0, 10 },
    increment = 0.5,
    value = 2.5,
    suffix = " s",
    callback = function(Value) retryDelay = Value end,
})

VisualsTab:CreateToggle({
    name = "Auto Demon Castle (Next Floor)",
    flag = "MCE_AutoDemonCastle",
    value = false,
    callback = function(Value) autoDemonCastleEnabled = Value end,
})

VisualsTab:CreateSlider({
    name = "Auto Dungeon Trigger Range",
    flag = "MCE_DungeonRange",
    range = { 10, 200 },
    increment = 10,
    value = 50,
    suffix = " studs",
    callback = function(Value) autoDungeonRange = Value end,
})

-- =================================================================
-- CONFIGURATION TAB
-- =================================================================
ConfigTab:CreateSection({ name = "🚀 Movement Settings" })

ConfigTab:CreateDropdown({
    name = "Movement Method",
    flag = "MCE_MovementMethod",
    options = { "Teleport", "Tween" },
    value = { "Teleport" },
    callback = function(Option)
        movementMethod = type(Option) == "table" and Option[1] or Option
        updateNoclipState()
    end,
})

ConfigTab:CreateSlider({
    name = "Tween Speed",
    flag = "MCE_TweenSpeed",
    range = { 25, 500 },
    increment = 25,
    value = 150,
    suffix = " studs/s",
    callback = function(Value) tweenSpeed = Value end,
})

ConfigTab:CreateDropdown({
    name = "Positioning Mode",
    flag = "MCE_PositioningMode",
    options = { "Above", "Circle" },
    value = { "Above" },
    callback = function(Option)
        positioningMode = type(Option) == "table" and Option[1] or Option
    end,
})

ConfigTab:CreateDivider({ text = "profile" })
ConfigTab:CreateSection({ name = "💾 Cache Management" })

ConfigTab:CreateButton({
    name = "💾 Save Config",
    callback = function()
        Window:Save()
        QuickToast("Config Saved", "Preferences saved successfully")
    end,
})

ConfigTab:CreateButton({
    name = "📂 Reload Config",
    callback = function()
        Window:Load()
        QuickToast("Config Reloaded", "Loaded user preferences")
    end,
})

ConfigTab:CreateButton({
    name = "🗑️ Reset Configuration",
    callback = function()
        if delfile then
            pcall(function() delfile("KissoHubFolder/SoloHunterPrefs.rfld") end)
            SafeNotify("System Reset", "Configuration cache purged successfully!", 5)
        end
    end,
})

-- =================================================================
-- TARGET IDENTIFICATION ENGINE
-- =================================================================
local targetEnemy = nil

local function isEnemy(model)
    if not (model and model:IsA("Model") and model ~= LocalPlayer.Character) then
        return false
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart

    if not (humanoid and root and humanoid.Health > 0) then
        return false
    end

    if model:GetAttribute("IsPlayerTeam") == true then return false end
    if model:GetAttribute("PlayerBelongsTo") ~= nil then return false end

    if filterMobsEnabled then
        if model:GetAttribute("ExcludeFromDungeonCount") == true then return false end
        if model:GetAttribute("Invincible") == true then return false end
        if model:GetAttribute("Immune") == true then return false end
    end

    return true
end

local function getClosestEnemy()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end

    local playerRoot = character.HumanoidRootPart
    local closestEnemy = nil
    local shortestDistance = autoAttackRange

    local mobsFolder = workspace:FindFirstChild("Mobs")
    if not mobsFolder then return nil end

    for _, mob in ipairs(mobsFolder:GetChildren()) do
        if isEnemy(mob) then
            local root = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
            if root then
                local distance = (playerRoot.Position - root.Position).Magnitude
                if distance <= shortestDistance then
                    closestEnemy = mob
                    shortestDistance = distance
                end
            end
        end
    end

    return closestEnemy
end

task.spawn(function()
    while true do
        if autoAttackEnabled then
            local found = getClosestEnemy()
            if found then
                local hum = found:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    targetEnemy = found
                else
                    targetEnemy = nil
                end
            else
                targetEnemy = nil
            end
        else
            targetEnemy = nil
        end
        task.wait(0.1)
    end
end)

-- =================================================================
-- DYNAMIC UI MODE SWITCHER
-- =================================================================
local originalDeviceMode = nil

local function setUIMode(mode)
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return end

    if mode == "PC" then
        isProgrammaticInput = true
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
        isProgrammaticInput = false
    end

    for _, gui in ipairs(pGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            local deviceSetting = gui:FindFirstChild("Device", true)
                or gui:FindFirstChild("UI_Mode", true)
                or gui:FindFirstChild("ControlMode", true)

            if deviceSetting then
                if deviceSetting:IsA("StringValue") or deviceSetting:IsA("TextLabel") then
                    if mode == "PC" then
                        if originalDeviceMode == nil then originalDeviceMode = deviceSetting.Value end
                        deviceSetting.Value = "PC"
                    elseif mode == "Restore" and originalDeviceMode then
                        deviceSetting.Value = originalDeviceMode
                    end
                end
            end
        end
    end
end

task.spawn(function()
    local wasAttacking = false
    while true do
        task.wait(0.1)
        local isActivelyAttacking = autoAttackEnabled
            and targetEnemy ~= nil
            and (targetEnemy:FindFirstChild("HumanoidRootPart") or targetEnemy.PrimaryPart) ~= nil
            and not safeSpotActive

        if isActivelyAttacking and not wasAttacking then
            wasAttacking = true
            setUIMode("PC")
        elseif not isActivelyAttacking and wasAttacking then
            wasAttacking = false
            setUIMode("Restore")
        end
    end
end)

-- =================================================================
-- FLIGHT & MOVEMENT
-- =================================================================
RunService.Heartbeat:Connect(function(deltaTime)
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return end

    local hasValidEnemy = targetEnemy
        and (targetEnemy:FindFirstChild("HumanoidRootPart") or targetEnemy.PrimaryPart)
        and targetEnemy:FindFirstChildOfClass("Humanoid")
        and targetEnemy:FindFirstChildOfClass("Humanoid").Health > 0

    local shouldFly = (autoAttackEnabled and hasValidEnemy) or (safeSpotActive and hasValidEnemy)

    if shouldFly then
        if not isFlyingToTarget then
            isFlyingToTarget = true
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end)
        end

        local enemyRoot = targetEnemy:FindFirstChild("HumanoidRootPart") or targetEnemy.PrimaryPart
        local targetPosition
        local lookTarget

        if safeSpotActive then
            targetPosition = enemyRoot.Position + Vector3.new(0.01, SAFE_HOVER_HEIGHT, 0)
            lookTarget = Vector3.new(enemyRoot.Position.X, targetPosition.Y, enemyRoot.Position.Z)
        else
            if positioningMode == "Above" then
                targetPosition = enemyRoot.Position + Vector3.new(0.01, HOVER_HEIGHT, 0)
            elseif positioningMode == "Circle" then
                circleAngle = circleAngle + (deltaTime * 2.5)
                local radius = attackDistance
                local offsetX = math.cos(circleAngle) * radius
                local offsetZ = math.sin(circleAngle) * radius
                targetPosition = enemyRoot.Position + Vector3.new(offsetX, HOVER_HEIGHT, offsetZ)
            end
            lookTarget = Vector3.new(enemyRoot.Position.X, targetPosition.Y, enemyRoot.Position.Z)
        end

        if movementMethod == "Teleport" and not safeSpotActive then
            root.CFrame = CFrame.lookAt(targetPosition, lookTarget)
        else
            local currentPos = root.Position
            local travelVector = (targetPosition - currentPos)
            local dist = travelVector.Magnitude

            if dist <= 1.5 then
                root.CFrame = CFrame.lookAt(targetPosition, lookTarget)
            else
                local operationalSpeed = safeSpotActive and 200 or tweenSpeed
                local glideStep = math.min(dist, operationalSpeed * deltaTime)
                local calculatedPosition = currentPos + (travelVector.Unit * glideStep)
                local targetLook = Vector3.new(lookTarget.X, calculatedPosition.Y, lookTarget.Z)
                root.CFrame = CFrame.lookAt(calculatedPosition, targetLook)
            end
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    else
        if isFlyingToTarget then
            isFlyingToTarget = false
            pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
            root.AssemblyLinearVelocity = Vector3.new(0, -30, 0)
        end
    end
end)

-- =================================================================
-- AUTO ATTACK LOOP
-- =================================================================
local lastRemoteCall = 0
task.spawn(function()
    while true do
        task.wait(M1_SPEED)
        if autoAttackEnabled and targetEnemy and not safeSpotActive then
            local character = LocalPlayer.Character
            if character and character:FindFirstChildOfClass("Tool") then
                if os.clock() - lastRemoteCall >= 0.25 then
                    lastRemoteCall = os.clock()
                    task.spawn(function()
                        if useWeaponRemote then pcall(function() useWeaponRemote:InvokeServer() end) end
                    end)
                end

                local clickX, clickY = getBottomLeftPos()
                isProgrammaticInput = true
                VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, true, game, 0)
                task.wait(0.01)
                VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, false, game, 0)
                isProgrammaticInput = false
            end
        end
    end
end)

-- =================================================================
-- AUTO SKILLS
-- =================================================================
local skillBinds = {
    { Key = Enum.KeyCode.F, GetEnabled = function() return castF end, LastCast = 0 },
    { Key = Enum.KeyCode.R, GetEnabled = function() return castR end, LastCast = 0 },
    { Key = Enum.KeyCode.C, GetEnabled = function() return castC end, LastCast = 0 },
    { Key = Enum.KeyCode.G, GetEnabled = function() return castG end, LastCast = 0 },
    { Key = Enum.KeyCode.V, GetEnabled = function() return castV end, LastCast = 0 },
}

task.spawn(function()
    while true do
        task.wait(0.05)
        local canCastSkills = autoAttackEnabled
            and autoSkillsEnabled
            and targetEnemy ~= nil
            and not safeSpotActive

        if canCastSkills then
            local now = os.clock()
            local character = LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local enemyRoot = targetEnemy and (targetEnemy:FindFirstChild("HumanoidRootPart") or targetEnemy.PrimaryPart)

            if root and enemyRoot and character:FindFirstChildOfClass("Tool") then
                local flatDist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(enemyRoot.Position.X, 0, enemyRoot.Position.Z)).Magnitude

                if flatDist <= (attackDistance + 25) then
                    for _, skillData in ipairs(skillBinds) do
                        if skillData.GetEnabled() and (now - skillData.LastCast >= SKILL_INTERVAL) then
                            skillData.LastCast = now

                            isProgrammaticInput = true
                            VirtualInputManager:SendKeyEvent(true, skillData.Key, false, game)
                            task.wait(0.03)
                            VirtualInputManager:SendKeyEvent(false, skillData.Key, false, game)
                            isProgrammaticInput = false

                            task.wait(0.1)
                        end
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- AUTO POTION
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.4)
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if autoPotionEnabled and humanoid and humanoid.Health > 0 then
            if (humanoid.Health / humanoid.MaxHealth) <= 0.5 then
                if healRemote then task.spawn(pcall, function() healRemote:InvokeServer() end) end
                task.wait(1.5)
            end
        end
    end
end)

-- =================================================================
-- SAFE SPOT
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.1)
        if safeSpotEnabled then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if humanoid and humanoid.Health > 0 then
                local hpPercent = (humanoid.Health / humanoid.MaxHealth) * 100

                if hpPercent <= safeHpPercent and not safeSpotActive then
                    safeSpotActive = true
                    updateNoclipState()
                elseif hpPercent >= 90 and safeSpotActive then
                    safeSpotActive = false
                    updateNoclipState()
                end
            end
        else
            if safeSpotActive then
                safeSpotActive = false
                updateNoclipState()
            end
        end
    end
end)

-- =================================================================
-- AUTO EQUIP
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if autoEquipEnabled then
            local character = LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                if not character:FindFirstChildOfClass("Tool") then
                    local backpack = LocalPlayer:FindFirstChild("Backpack")
                    local tool = backpack and backpack:FindFirstChildOfClass("Tool")
                    if tool then
                        humanoid:EquipTool(tool)
                    else
                        isProgrammaticInput = true
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
                        task.wait(0.02)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
                        isProgrammaticInput = false
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- AUTO DUNGEON
-- =================================================================
task.spawn(function()
    while true do
        task.wait(1.5)
        if autoDungeonEnabled then
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local mainGui = pGui and pGui:FindFirstChild("Main")
            local startBtn = mainGui and mainGui:FindFirstChild("StartBtn")

            if startBtn and startBtn.Visible and startDungeonRemote then
                task.spawn(pcall, function() startDungeonRemote:InvokeServer() end)
            end

            local gateGui = pGui and pGui:FindFirstChild("Gate")
            if gateGui and (gateGui.Enabled or (gateGui:FindFirstChild("Main") and gateGui.Main.Visible)) and enterGateRemote then
                task.spawn(pcall, function() enterGateRemote:InvokeServer() end)
            end
        end
    end
end)

-- =================================================================
-- AUTO RETRY + DEMON CASTLE
-- =================================================================
local isRetryPending = false

local function findAndClickRetryButton()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return false end

    local targetKeywords = { "retry", "replay", "again", "next", "restart", "playagain" }

    for _, gui in ipairs(pGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            for _, descendant in ipairs(gui:GetDescendants()) do
                if (descendant:IsA("TextButton") or descendant:IsA("ImageButton")) and descendant.Visible then
                    local btnName = descendant.Name:lower()
                    local btnText = (descendant:IsA("TextButton") and descendant.Text:lower()) or ""

                    for _, kw in ipairs(targetKeywords) do
                        if btnName:find(kw) or btnText:find(kw) then
                            pcall(function()
                                if firesignal then
                                    firesignal(descendant.MouseButton1Click)
                                    firesignal(descendant.Activated)
                                else
                                    isProgrammaticInput = true
                                    VirtualInputManager:SendMouseButtonEvent(descendant.AbsolutePosition.X + 10, descendant.AbsolutePosition.Y + 30, 0, true, game, 0)
                                    task.wait(0.05)
                                    VirtualInputManager:SendMouseButtonEvent(descendant.AbsolutePosition.X + 10, descendant.AbsolutePosition.Y + 30, 0, false, game, 0)
                                    isProgrammaticInput = false
                                end
                            end)
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function triggerAutoRetry(source)
    isDungeonCleared = true

    if not autoRetryEnabled or isRetryPending then return end
    isRetryPending = true

    task.spawn(function()
        while (os.clock() - lastUserInputTime) < 5 do
            task.wait(0.5)
        end

        task.wait(retryDelay)

        local success = false
        local attempts = 0

        while autoRetryEnabled and attempts < 3 and not success do
            attempts = attempts + 1

            if retryDungeonRemote then
                local pcallSuccess, res = pcall(function()
                    return retryDungeonRemote:InvokeServer("retry")
                end)
                if pcallSuccess and res ~= false then
                    success = true
                end
            end

            if not success then
                success = findAndClickRetryButton()
            end

            if success then
                isDungeonCleared = false
                SafeNotify("Auto Retry Executed", "Successfully retried via " .. (attempts == 1 and "Remote" or "UI Fallback") .. "!", 3)
                break
            end

            task.wait(2)
        end

        task.wait(3)
        isRetryPending = false
    end)
end

if fullDungeonRemote then
    fullDungeonRemote.OnClientEvent:Connect(function(action, ...)
        if action == "PortalSpawned" then
            if autoDemonCastleEnabled then
                task.spawn(pcall, function()
                    task.wait(0.1)
                    if teleportIntoDungeon then
                        safeFireSignal(teleportIntoDungeon.OnClientEvent, { Position = Vector3.new(20000, 0, 20000) })
                    end
                    task.wait(0.1)
                    if teleportedSignal then
                        safeFireSignal(teleportedSignal.OnClientEvent, "DemonCastle", "B", nil, {})
                    end
                end)
            end
        else
            triggerAutoRetry("FullDungeonRemote")
        end
    end)
end

if spawnChestRemote then
    spawnChestRemote.OnClientEvent:Connect(function(...)
        triggerAutoRetry("BossChestSpawned")
    end)
end

task.spawn(function()
    while true do
        task.wait(1)
        if not isRetryPending then
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            if pGui then
                local resultGui = pGui:FindFirstChild("DungeonResult")
                    or pGui:FindFirstChild("ClearGui")
                    or pGui:FindFirstChild("Result")
                    or pGui:FindFirstChild("VictoryGui")

                if resultGui and (resultGui.Enabled or (resultGui:FindFirstChild("Main") and resultGui.Main.Visible)) then
                    triggerAutoRetry("UIRecognition")
                end
            end
        end
    end
end)

-- =================================================================
-- POST-CLEAR AUTO CLICK
-- =================================================================
task.spawn(function()
    while true do
        task.wait(1.5)
        local timeSinceInput = os.clock() - lastUserInputTime

        if isDungeonCleared and (timeSinceInput >= 5) then
            local clickX, clickY = getBottomLeftPos()
            isProgrammaticInput = true
            VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, true, game, 0)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, false, game, 0)
            isProgrammaticInput = false
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    isDungeonCleared = false
    isFlyingToTarget = false
end)

-- =================================================================
-- AUTO COLLECT DROPS
-- =================================================================
if dropCreatedRemote then
    dropCreatedRemote.OnClientEvent:Connect(function(dropId, dropType, dropBase, position, dropData)
        if autoCollectDrops and collectDropRemote then
            local isGlobal = false
            if type(dropData) == "table" and dropData.GlobalDrop ~= nil then
                isGlobal = dropData.GlobalDrop
            end
            task.spawn(pcall, function()
                collectDropRemote:InvokeServer(dropId, isGlobal)
            end)
        end
    end)
end

-- =================================================================
-- AUTO OPEN CHEST + TP ABOVE CHEST
-- =================================================================
local openedChestsCache = {}

local function handlePhysicalChest(chestObj)
    if openedChestsCache[chestObj] then return end
    openedChestsCache[chestObj] = true

    if tpAboveChestEnabled then
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local chestPos = nil

        if chestObj:IsA("BasePart") then
            chestPos = chestObj.Position
        elseif chestObj:IsA("Model") then
            local primary = chestObj.PrimaryPart or chestObj:FindFirstChildWhichIsA("BasePart", true)
            if primary then chestPos = primary.Position end
        end

        if root and chestPos then
            local distance = (root.Position - chestPos).Magnitude
            if distance <= tpAboveChestDistance then
                root.CFrame = CFrame.new(chestPos + Vector3.new(0, 5, 0))
            end
        end
    end

    if autoOpenChests then
        task.spawn(function()
            task.wait(0.3)

            if openChestRemote then
                task.spawn(pcall, function() openChestRemote:InvokeServer(chestObj) end)
                task.spawn(pcall, function() openChestRemote:InvokeServer(chestObj.Name) end)

                local chestID = chestObj:GetAttribute("ChestUUID")
                    or chestObj:GetAttribute("UUID")
                    or chestObj:GetAttribute("Id")
                    or chestObj:GetAttribute("ChestId")
                if chestID then
                    task.spawn(pcall, function() openChestRemote:InvokeServer(chestID) end)
                end
            end

            for _, prompt in ipairs(chestObj:GetDescendants()) do
                if prompt:IsA("ProximityPrompt") then
                    pcall(function()
                        if fireproximityprompt then
                            fireproximityprompt(prompt)
                        else
                            prompt:InputHoldBegin()
                            task.wait(prompt.HoldDuration + 0.05)
                            prompt:InputHoldEnd()
                        end
                    end)
                end
            end
        end)
    end
end

if spawnChestRemote then
    spawnChestRemote.OnClientEvent:Connect(function(...)
        local args = { ... }
        task.spawn(function()
            task.wait(0.2)
            for _, arg in ipairs(args) do
                if typeof(arg) == "Instance" then
                    handlePhysicalChest(arg)
                elseif type(arg) == "string" and autoOpenChests and openChestRemote then
                    task.spawn(pcall, function() openChestRemote:InvokeServer(arg) end)
                elseif type(arg) == "table" and autoOpenChests and openChestRemote then
                    local chestID = arg.ChestUUID or arg.UUID or arg.Id or arg.ChestId
                    if chestID then
                        task.spawn(pcall, function() openChestRemote:InvokeServer(chestID) end)
                    else
                        task.spawn(pcall, function() openChestRemote:InvokeServer(arg) end)
                    end
                end
            end
        end)
    end)
end

workspace.ChildAdded:Connect(function(child)
    if autoOpenChests or tpAboveChestEnabled then
        local childName = child.Name:lower()
        if childName:find("chest") or child.Name == "WhiteflameChest" then
            handlePhysicalChest(child)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1.5)
        if autoOpenChests or tpAboveChestEnabled then
            for _, obj in ipairs(workspace:GetChildren()) do
                local objName = obj.Name:lower()
                if objName:find("chest") or obj.Name == "WhiteflameChest" then
                    handlePhysicalChest(obj)
                end
            end
        end
    end
end)

-- =================================================================
-- ENEMY ESP
-- =================================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if espEnabled then
            local mobsFolder = workspace:FindFirstChild("Mobs")
            if mobsFolder then
                for _, obj in ipairs(mobsFolder:GetChildren()) do
                    if isEnemy(obj) and not obj:FindFirstChild("CombatEngineESP") then
                        local highlight = Instance.new("Highlight")
                        highlight.Name = "CombatEngineESP"
                        highlight.FillColor = Color3.fromRGB(255, 50, 50)
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.FillTransparency = 0.5
                        highlight.Adornee = obj
                        highlight.Parent = obj
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- AUTO MASS EXTRACT
-- =================================================================
task.spawn(function()
    while true do
        task.wait(3)
        if autoMassExtract and massExtractRemote then
            task.spawn(pcall, function()
                massExtractRemote:InvokeServer()
            end)
        end
    end
end)

-- =================================================================
-- AUTO BUY MERCHANT
-- =================================================================
local function getCurrentMerchantRefresh()
    local serverTime = workspace:GetServerTimeNow()
    return math.floor(serverTime / 300)
end

task.spawn(function()
    while true do
        task.wait(merchantBuyDelay)
        if autoBuyMerchantEnabled and getMerchantItemsRemote and buyMerchantRemote and #selectedMerchantItems > 0 then
            local getSuccess, stockResult = pcall(function()
                return getMerchantItemsRemote:InvokeServer()
            end)

            if getSuccess and type(stockResult) == "table" then
                local currentRefresh = getCurrentMerchantRefresh()

                for _, selectedName in ipairs(selectedMerchantItems) do
                    local slotKey = merchantItemMap[selectedName]
                    if slotKey and stockResult[slotKey] and stockResult[slotKey] > 0 then
                        task.spawn(function()
                            pcall(function()
                                return buyMerchantRemote:InvokeServer("Normal", tostring(slotKey), currentRefresh)
                            end)
                        end)
                        task.wait(0.2)
                    end
                end
            end
        end
    end
end)

-- =================================================================
-- LIVE REFRESH LOOP
-- =================================================================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local elapsedMinutes = math.floor((os.time() - SessionStartTime) / 60)

            local activeCount = 0
            if autoAttackEnabled then activeCount += 1 end
            if autoSkillsEnabled then activeCount += 1 end
            if autoCollectDrops then activeCount += 1 end
            if autoOpenChests then activeCount += 1 end
            if autoMassExtract then activeCount += 1 end
            if autoBuyMerchantEnabled then activeCount += 1 end
            if espEnabled then activeCount += 1 end
            if autoDungeonEnabled then activeCount += 1 end
            if autoRetryEnabled then activeCount += 1 end
            if autoDemonCastleEnabled then activeCount += 1 end
            if lowVfxEnabled then activeCount += 1 end
            if ultraLowEnabled then activeCount += 1 end
            if safeSpotEnabled then activeCount += 1 end

            SessionStat:Set(elapsedMinutes)
            FeaturesStat:Set(activeCount)
            FpsStat:Set(math.floor(workspace:GetRealPhysicsFPS() or 60))
            PlayersStat:Set(#Players:GetPlayers())
            TargetStat:Set(targetEnemy and 1 or 0)

            if autoAttackEnabled and targetEnemy then
                StateTag:Set({ text = "COMBAT", color = Color3.fromRGB(255, 80, 80) })
            elseif safeSpotActive then
                StateTag:Set({ text = "SAFE", color = Color3.fromRGB(255, 200, 0) })
            elseif activeCount > 0 then
                StateTag:Set({ text = "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
            else
                StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
            end
        end)
    end
end)

SafeNotify("KissoHub", "SoloHunter Edition loaded", 3)
