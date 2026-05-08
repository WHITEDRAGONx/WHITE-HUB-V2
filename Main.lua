-- =====================
-- Main.lua
-- WHITE HUB — Entry point.
-- =====================

repeat task.wait(1) until game:IsLoaded()

print("[WHITE HUB] Loading...")
warn("[WHITE HUB] Loading...")

task.wait(6)

print("[WHITE HUB] Initialized.")

task.wait(2)

-- =====================
-- GITHUB RAW BASE URL
-- =====================
local BASE_URL = "https://raw.githubusercontent.com/WHITEDRAGONx/WHITE-HUB-V2/main/"

-- =====================
-- SAFE MODULE LOADER
-- =====================
local function Load(file)
    local url = BASE_URL .. file

    print("[WHITE HUB] Fetching:", url)

    local success, response = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not success then
        warn("[WHITE HUB] Failed to fetch module:", file)
        warn(response)
        return nil
    end

    print("[WHITE HUB] Response received for:", file)

    local func, compileError = loadstring(response)

    if not func then
        warn("[WHITE HUB] Compile error in:", file)
        warn(compileError)
        return nil
    end

    local ok, result = pcall(func)

    if not ok then
        warn("[WHITE HUB] Runtime error in:", file)
        warn(result)
        return nil
    end

    print("[WHITE HUB] Loaded:", file)

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

-- =====================
-- VERIFY MODULES
-- =====================
for name, mod in pairs(Modules) do
    if mod == nil then
        error("[WHITE HUB] Critical module failed to load: " .. name)
    end
end

print("[WHITE HUB] All modules loaded successfully.")

-- =====================
-- LOAD CONFIG FIRST
-- =====================
if Modules.Config.Load then
    Modules.Config:Load()
else
    warn("[WHITE HUB] Config.Load() missing.")
end

-- =====================
-- INITIALIZE MODULES
-- =====================
local initOrder = {
    "Webhook",
    "Movement",
    "ServerHop",
    "Inventory",
    "UI",
    "Farm"
}

for _, moduleName in ipairs(initOrder) do
    local module = Modules[moduleName]

    if module and module.Init then
        local ok, err = pcall(function()
            module:Init(Modules)
        end)

        if not ok then
            warn("[WHITE HUB] Init failed for:", moduleName)
            warn(err)
        else
            print("[WHITE HUB] Initialized:", moduleName)
        end
    else
        warn("[WHITE HUB] Missing Init() in:", moduleName)
    end
end

-- =====================
-- CREATE UI
-- =====================
if Modules.UI.Create then
    local ok, err = pcall(function()
        Modules.UI:Create()
    end)

    if not ok then
        warn("[WHITE HUB] UI creation failed.")
        warn(err)
    end
else
    warn("[WHITE HUB] UI.Create() missing.")
end

-- =====================
-- START FARM
-- =====================
if Modules.Farm.Start then
    task.spawn(function()
        local ok, err = pcall(function()
            Modules.Farm:Start()
        end)

        if not ok then
            warn("[WHITE HUB] Farm crashed.")
            warn(err)
        end
    end)
else
    warn("[WHITE HUB] Farm.Start() missing.")
end

print("[WHITE HUB] All systems running.")
