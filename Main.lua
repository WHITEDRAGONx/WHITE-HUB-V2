-- =====================
-- Main.lua (modified for manual UI with active creation)
-- =====================

repeat task.wait(1) until game:IsLoaded()

local function LOG(tag, msg)
    print(("[WHITE HUB][%s] %s"):format(tag, tostring(msg)))
end
local function ERR(tag, msg)
    warn(("[WHITE HUB][ERROR][%s] %s"):format(tag, tostring(msg)))
end

LOG("BOOT", "Starting up...")
task.wait(6)
LOG("BOOT", "Initial wait done.")

local BASE_URL = "https://raw.githubusercontent.com/WHITEDRAGONx/WHITE-HUB-V2/main/"

local function Load(file)
    local url = BASE_URL .. file
    LOG("LOAD", "Fetching: " .. url)

    local response = nil
    local done = false

    task.spawn(function()
        local ok, res = pcall(function()
            return game:HttpGet(url, true)
        end)
        if ok and res then response = res end
        done = true
    end)

    local t = 0
    while not done and t < 15 do
        task.wait(0.5)
        t += 0.5
    end

    if not response then
        ERR("LOAD", "Timeout or fetch failed: " .. file)
        return nil
    end

    if response:find("<!DOCTYPE") or response:sub(1,3) == "404" then
        ERR("LOAD", "File not found on GitHub (404): " .. file)
        return nil
    end

    LOG("LOAD", "Download OK: " .. file .. " (" .. #response .. " bytes)")

    local func, compileErr = loadstring(response)
    if not func then
        ERR("COMPILE", file .. " — " .. tostring(compileErr))
        return nil
    end

    local ok, result = pcall(func)
    if not ok then
        ERR("RUNTIME", file .. " — " .. tostring(result))
        return nil
    end

    if result == nil then
        ERR("LOAD", file .. " returned nil. Make sure it has 'return Module' at the end.")
        return nil
    end

    LOG("LOAD", "✅ Loaded: " .. file)
    return result
end

-- Load modules
LOG("MODULES", "Loading modules...")
local Modules = {}
local moduleFiles = {
    { key = "Config",    file = "Config.lua"    },
    { key = "Webhook",   file = "Webhook.lua"   },
    { key = "Movement",  file = "Movement.lua"  },
    { key = "ServerHop", file = "ServerHop.lua" },
    { key = "Inventory", file = "Inventory.lua" },
    { key = "UI",        file = "UI.lua"        },
    { key = "Farm",      file = "Farm.lua"      },
}

local allLoaded = true
for _, entry in ipairs(moduleFiles) do
    LOG("MODULES", "Loading " .. entry.key .. "...")
    local mod = Load(entry.file)
    if mod == nil then
        ERR("MODULES", "CRITICAL — failed to load: " .. entry.key)
        allLoaded = false
    else
        Modules[entry.key] = mod
        LOG("MODULES", "✅ " .. entry.key .. " OK")
    end
end

if not allLoaded then
    ERR("BOOT", "Critical modules failed to load. Aborting.")
    return
end

LOG("MODULES", "All modules loaded successfully.")

-- Config
LOG("CONFIG", "Loading Config...")
if Modules.Config and Modules.Config.Load then
    local ok, err = pcall(function() Modules.Config:Load() end)
    if not ok then ERR("CONFIG", tostring(err))
    else LOG("CONFIG", "✅ Config loaded.") end
else
    ERR("CONFIG", "Config.Load() is missing.")
end

-- Initialize modules (including UI)
local initOrder = { "Webhook", "Movement", "ServerHop", "Inventory", "UI", "Farm" }

LOG("INIT", "Initializing modules...")
for _, moduleName in ipairs(initOrder) do
    local module = Modules[moduleName]
    if module and module.Init then
        LOG("INIT", "Initializing " .. moduleName .. "...")
        local ok, err = pcall(function() module:Init(Modules) end)
        if not ok then ERR("INIT", moduleName .. ":Init() — " .. tostring(err))
        else LOG("INIT", "✅ " .. moduleName .. " initialized.") end
    else
        ERR("INIT", moduleName .. " has no Init() — skipping.")
    end
end

-- Expose modules globally for the manual UI
_G.WhiteHubModules = Modules
LOG("UI", "Manual UI will use _G.WhiteHubModules")

-- ========== UI CREATION ==========
LOG("UI", "Creating UI...")
if Modules.UI and Modules.UI.Create then
    local ok, err = pcall(function() Modules.UI:Create() end)
    if not ok then ERR("UI", "UI:Create() — " .. tostring(err))
    else LOG("UI", "✅ UI created.") end
else
    ERR("UI", "UI.Create() is missing.")
end

-- Start Farm
LOG("FARM", "Starting Farm...")
if Modules.Farm and Modules.Farm.Start then
    task.spawn(function()
        LOG("FARM", "Farm:Start() called.")
        local ok, err = pcall(function() Modules.Farm:Start() end)
        if not ok then
            ERR("FARM", "Farm crashed — " .. tostring(err))
            task.wait(10)
            LOG("FARM", "Attempting Farm restart...")
            local ok2, err2 = pcall(function() Modules.Farm:Start() end)
            if not ok2 then ERR("FARM", "Farm restart failed — " .. tostring(err2)) end
        end
    end)
else
    ERR("FARM", "Farm.Start() is missing.")
end

LOG("BOOT", "✅ WHITE HUB — all systems running (manual UI active).")
