-- =====================
-- ServerHop.lua (WHITE HUB V3)
-- Handles server hopping and auto rejoin.
-- =====================

local HttpService      = game:GetService("HttpService")
local TeleportService  = game:GetService("TeleportService")
local CoreGui          = game:GetService("CoreGui")
local Players          = game:GetService("Players")

local Player  = Players.LocalPlayer
local PlaceID = game.PlaceId

local ServerHop = {}
local _movement = nil
local _config = nil
local _kickConnection = nil

local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour

local fileOk = pcall(function()
    if type(readfile) == "function" then
        AllIDs = HttpService:JSONDecode(readfile("NotSameServers.json"))
    end
end)
if not fileOk or type(AllIDs) ~= "table" then
    AllIDs = { actualHour }
    pcall(function()
        if type(writefile) == "function" then
            writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
        end
    end)
end

local function saveIds()
    pcall(function()
        if type(writefile) == "function" then
            writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
        end
    end)
end

local function resetHourlyCacheIfNeeded()
    if tonumber(AllIDs[1]) ~= tonumber(actualHour) then
        AllIDs = { actualHour }
        pcall(function()
            if type(delfile) == "function" then delfile("NotSameServers.json") end
        end)
        saveIds()
    end
end

local function TPReturner()
    resetHourlyCacheIfNeeded()

    local url = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100"
    if foundAnything ~= "" then
        url = url .. "&cursor=" .. foundAnything
    end

    local Site = HttpService:JSONDecode(game:HttpGet(url))
    if Site.nextPageCursor and Site.nextPageCursor ~= "null" then
        foundAnything = Site.nextPageCursor
    end

    for _, server in ipairs(Site.data or {}) do
        local id = tostring(server.id)
        if tonumber(server.maxPlayers) > tonumber(server.playing) then
            local seen = false
            for i = 2, #AllIDs do
                if tostring(AllIDs[i]) == id then
                    seen = true
                    break
                end
            end

            if not seen then
                table.insert(AllIDs, id)
                saveIds()
                TeleportService:TeleportToPlaceInstance(PlaceID, id, Player)
                return true
            end
        end
    end
    return false
end

function ServerHop:Init(Modules)
    _movement = Modules.Movement
    _config = Modules.Config

    if _kickConnection then
        pcall(function() _kickConnection:Disconnect() end)
    end

    _kickConnection = CoreGui.DescendantAdded:Connect(function(child)
        if child.Name ~= "ErrorPrompt" then return end
        local grabError = child:FindFirstChild("ErrorMessage", true)
        if not grabError then return end

        task.spawn(function()
            local deadline = tick() + 5
            while grabError.Parent and grabError.Text == "Label" and tick() < deadline do
                task.wait(0.1)
            end
            if not grabError.Parent then return end
            print("[ServerHop] Kick detected: " .. tostring(grabError.Text) .. " — Rejoining...")
            task.wait(1)
            ServerHop:Rejoin()
        end)
    end)
end

function ServerHop:Hop()
    if _config and _config:Get("StayInPrivateServer") then
        print("[ServerHop] StayInPrivateServer is ON — skipping hop.")
        return false
    end

    print("[ServerHop] Hopping to a new server...")
    local ok, result = pcall(function()
        if TPReturner() then return true end
        if foundAnything ~= "" then return TPReturner() end
        return false
    end)

    if _movement then
        task.delay(3, function() _movement:FixCamera() end)
    end

    if not ok then warn("[ServerHop] Hop failed: " .. tostring(result)) end
    return ok and result == true
end

function ServerHop:Rejoin()
    print("[ServerHop] Rejoining game...")
    local ok, err = pcall(function()
        TeleportService:Teleport(PlaceID, Player)
    end)
    if not ok then warn("[ServerHop] Rejoin failed: " .. tostring(err)) end
    return ok
end

function ServerHop:Destroy()
    if _kickConnection then
        pcall(function() _kickConnection:Disconnect() end)
        _kickConnection = nil
    end
end

return ServerHop
