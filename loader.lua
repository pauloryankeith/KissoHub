-- =================================================================
-- KissoHub Loader
-- Single loadstring entry point with game verification
-- =================================================================
local HttpService = game:GetService("HttpService")

local BASE_URL = "https://raw.githubusercontent.com/pauloryankeith/KissoHub/main/"
local CORE_URL = BASE_URL .. "KissoHub/core.lua"
local GAMES_URL = BASE_URL .. "KissoHub/games/"

-- Fetch core module first
local coreOk, coreSource = pcall(function()
    return game:HttpGet(CORE_URL)
end)

if not coreOk or not coreSource or coreSource == "" then
    warn("[KissoHub] Failed to fetch core module.")
    return
end

-- Load core as a shared module
local coreFn, coreErr = loadstring(coreSource)
if not coreFn then
    warn("[KissoHub] Failed to compile core module: " .. tostring(coreErr))
    return
end

local KissoCore = coreFn()
if type(KissoCore) ~= "table" then
    warn("[KissoHub] Core module did not return a table.")
    return
end

-- Check if this game is supported
local moduleName = KissoCore.GAMES[game.PlaceId]

if not moduleName then
    KissoCore.ShowUnsupported(game.PlaceId)
    return
end

-- Fetch the game-specific module
local gameOk, gameSource = pcall(function()
    return game:HttpGet(GAMES_URL .. moduleName .. ".lua")
end)

if not gameOk or not gameSource or gameSource == "" then
    warn("[KissoHub] Failed to fetch module '" .. moduleName .. "' for PlaceId " .. tostring(game.PlaceId))
    return
end

-- Compile and run the game module with core injected
local gameFn, gameErr = loadstring(gameSource)
if not gameFn then
    warn("[KissoHub] Failed to compile module '" .. moduleName .. "': " .. tostring(gameErr))
    return
end

local ok, err = pcall(gameFn, KissoCore)
if not ok then
    warn("[KissoHub] Module '" .. moduleName .. "' errored: " .. tostring(err))
end
