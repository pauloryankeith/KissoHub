-- =================================================================
-- KissoHub Core
-- Shared theme, helpers, window builder, and game registry
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

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local ASSET_ICON = "rbxassetid://89387722763691"
local SessionStartTime = os.time()

-- =================================================================
-- GAME REGISTRY  →  PlaceId = module filename (no .lua)
-- =================================================================
local GAMES = {
    [136599248168660] = "solo_hunters",
    [109141895577255] = "my_coding_company",
    [124216119978534] = "ride_a_pet",
    [95517353097886]  = "anime_monster_collector",   
}

-- =================================================================
-- SHARED THEME (neon cyan / magenta)
-- =================================================================
local THEME = {
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
}

-- =================================================================
-- CORE MODULE TABLE
-- =================================================================
local KissoCore = {}
KissoCore.GAMES = GAMES
KissoCore.ASSET_ICON = ASSET_ICON
KissoCore.SessionStartTime = SessionStartTime
KissoCore.Rayfield = Rayfield
KissoCore.Theme = THEME

-- =================================================================
-- WINDOW BUILDER
-- =================================================================
function KissoCore.BuildWindow(subtitle, configFileName)
    local window = Rayfield:CreateWindow({
        name = "KissoHub",
        subtitle = subtitle or "Roblox Edition",
        sidebarLayout = true,
        icon = ASSET_ICON,
        theme = THEME,
        configuration = {
            autoSave = true,
            autoLoad = true,
            fileName = configFileName or "KissoHubPrefs",
            customFolder = "KissoHubFolder",
        },
    })
    return window
end

-- =================================================================
-- TAGS + NOTIFICATIONS
-- =================================================================
function KissoCore.BuildTags(window)
    local StatusTag = window:CreateTag({ text = "v1.0.0", color = Color3.fromRGB(0, 200, 255) })
    local StateTag  = window:CreateTag({ text = "IDLE",   color = Color3.fromRGB(190, 40, 220) })

    local function SetActivity(active, label)
        if active then
            StateTag:Set({ text = label or "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
        else
            StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
        end
    end

    return StatusTag, StateTag, SetActivity
end

function KissoCore.SafeNotify(window, title, content, duration)
    pcall(function()
        window:Notify({
            title = title or "KissoHub",
            content = content or "",
            duration = duration or 4,
            icon = ASSET_ICON,
        })
    end)
end

function KissoCore.QuickToast(window, title, subtitle)
    pcall(function()
        window:Toast({
            title = title,
            subtitle = subtitle,
            position = "Top",
            icon = ASSET_ICON,
        })
    end)
end

-- =================================================================
-- STANDARD HOME TAB
-- =================================================================
function KissoCore.BuildHomeTab(window, gameName)
    local HomeTab = window:CreateTab({ name = "🏠 Home", icon = ASSET_ICON })

    HomeTab:CreateSection({ name = "📊 Stats" })
    local SessionStat  = HomeTab:CreateStat({ name = "⏱️ Session", value = 0, suffix = " m", compact = true })
    local FeaturesStat = HomeTab:CreateStat({ name = "⚙️ Features", value = 0, compact = true })
    local FpsStat      = HomeTab:CreateStat({ name = "🎮 FPS", value = 0, compact = true })
    local PlayersStat  = HomeTab:CreateStat({ name = "👥 Players", value = 1, compact = true })

    HomeTab:CreateDivider({ text = "controls" })
    HomeTab:CreateSection({ name = "🌐 Server Utilities" })

    HomeTab:CreateButton({
        name = "📋 Copy Job ID",
        callback = function()
            if setclipboard then
                setclipboard(game.JobId)
                KissoCore.QuickToast(window, "Copied", "Job ID copied to clipboard")
            end
        end,
    })

    HomeTab:CreateButton({
        name = "🔄 Rejoin Server",
        callback = function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end,
    })

    HomeTab:CreateButton({
        name = "🎮 Game Info",
        callback = function()
            KissoCore.SafeNotify(window, gameName or "KissoHub",
                "PlaceId: " .. tostring(game.PlaceId) .. "\nJobId: " .. tostring(game.JobId), 6)
        end,
    })

    return HomeTab, {
        Session = SessionStat,
        Features = FeaturesStat,
        Fps = FpsStat,
        Players = PlayersStat,
    }
end

-- =================================================================
-- SHARED LIVE-REFRESH LOOP
-- =================================================================
function KissoCore.StartLiveRefresh(statsHandles, featureChecker)
    if not statsHandles then return end
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                local elapsedMinutes = math.floor((os.time() - SessionStartTime) / 60)
                local activeCount = type(featureChecker) == "function" and featureChecker() or 0

                if statsHandles.Session then statsHandles.Session:Set(elapsedMinutes) end
                if statsHandles.Features then statsHandles.Features:Set(activeCount) end
                if statsHandles.Fps then statsHandles.Fps:Set(math.floor(Workspace:GetRealPhysicsFPS() or 60)) end
                if statsHandles.Players then statsHandles.Players:Set(#Players:GetPlayers()) end
            end)
        end
    end)
end

-- =================================================================
-- UNSUPPORTED GAME HANDLER
-- =================================================================
function KissoCore.ShowUnsupported(placeId)
    local window = Rayfield:CreateWindow({
        name = "KissoHub",
        subtitle = "Unsupported Game",
        sidebarLayout = false,
        icon = ASSET_ICON,
        theme = THEME,
    })

    window:CreateTag({ text = "v1.0.0", color = Color3.fromRGB(0, 200, 255) })
    window:CreateTag({ text = "NOT SUPPORTED", color = Color3.fromRGB(255, 80, 80) })

    local tab = window:CreateTab({ name = "Info", icon = ASSET_ICON })
    tab:CreateSection({ name = "⚠️ Unsupported Game" })

    tab:CreateText({
        name = "This game isn't supported yet",
        text = "KissoHub doesn't have a script for:\n\n" ..
               "PlaceId: " .. tostring(placeId) .. "\n\n" ..
               "Supported games are listed in the README on GitHub.",
    })

    tab:CreateButton({
        name = "📋 Copy PlaceId",
        callback = function()
            if setclipboard then
                setclipboard(tostring(placeId))
                KissoCore.QuickToast(window, "Copied", "PlaceId copied to clipboard")
            end
        end,
    })
end

-- =================================================================
return KissoCore
