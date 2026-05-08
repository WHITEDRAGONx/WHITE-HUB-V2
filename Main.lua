-- =====================
-- Main.lua
-- WHITE HUB — Entry point.
-- Loads all modules, initializes systems, and starts the farm.
--
-- HOW TO USE:
-- Host each .lua file on your GitHub repo and paste the raw URLs below.
-- The user only needs to run this file via their executor.
-- =====================

repeat task.wait(1) until game:IsLoaded()

print("[WHITE HUB] Loading...")
warn("[WHITE HUB] Loading...")
wait(6)
print("[WHITE HUB] Initialized.")
wait(2)

-- =====================
-- GITHUB RAW BASE URL
-- Change this to your own repo raw URL base.
-- Example: "https://raw.githubusercontent.com/YOUR_USER/WHITE-HUB/main/"
-- =====================
local BASE_URL = "https://raw.githubusercontent.com/YOUR_USER/WHITE-HUB/main/"

local function Load(file)
    local url = BASE_URL .. file
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    if not ok then
        warn("[WHITE HUB] Failed to load module: " .. file .. "\n" .. tostring(result))
        return nil
    end
    print("[WHITE HUB] Loaded: " .. file)
    return result
end

-- =====================
-- LOAD MODULES
-- =====================
local Modules = {}

Modules.Config    = Load("Config.lua")
Modules.Webhook   = Load("Webhook.lua")
Modules.Movement  = Load("Movement.lua")
Modules.ServerHop = Load("ServerHop.lua")
Modules.Inventory = Load("Inventory.lua")
Modules.UI        = Load("UI.lua")
Modules.Farm      = Load("Farm.lua")

-- Abort if any critical module failed
for name, mod in pairs(Modules) do
    if mod == nil then
        error("[WHITE HUB] Critical module failed to load: " .. name .. " — aborting.")
    end
end

-- =====================
-- LOAD CONFIG FIRST
-- (other modules depend on it)
-- =====================
Modules.Config:Load()

-- =====================
-- INITIALIZE MODULES
-- Each module receives the full Modules table so it can
-- reference other systems without tight coupling.
-- =====================
Modules.Webhook:Init(Modules)
Modules.Movement:Init(Modules)  -- Movement.lua has a light Init (currently no-op, reserved)
Modules.ServerHop:Init(Modules)
Modules.Inventory:Init(Modules)
Modules.UI:Init(Modules)
Modules.Farm:Init(Modules)

-- =====================
-- START UI
-- =====================
Modules.UI:Create()

-- =====================
-- START FARM
-- This call blocks (runs the infinite farm loop internally via task.spawn)
-- =====================
task.spawn(function()
    Modules.Farm:Start()
end)

print("[WHITE HUB] All systems running.")
