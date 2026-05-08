-- =====================
-- ServerHop.lua
-- Handles server hopping, auto rejoin, and post-hop recovery.
-- Source based on: https://github.com/Vcsk/RobloxScripts/blob/main/ServerHop.lua
-- Internalized — no external loadstring dependency.
-- =====================

local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui         = game:GetService("CoreGui")
local Players         = game:GetService("Players")

local Player  = Players.LocalPlayer
local PlaceID = game.PlaceId

local ServerHop = {}

local _movement = nil
local _config   = nil

-- Max server IDs stored per session to prevent unbounded file growth
local MAX_STORED_IDS = 200
local SERVER_FILE    = "NotSameServers.json"

local _visitedIDs  = {}
local _sessionHour = os.date("!*t").hour

-- =====================
-- VISITED ID PERSISTENCE
-- =====================
local function LoadVisitedIDs()
    local ok, data = pcall(function()
        if isfile(SERVER_FILE) then
            return HttpService:JSONDecode(readfile(SERVER_FILE))
        end
    end)
    if ok and data and type(data) == "table" then
        -- If the stored hour tag differs, the file is stale — reset it
        if tonumber(data[1]) ~= tonumber(_sessionHour) then
            _visitedIDs = { _sessionHour }
            print("[ServerHop] Stale server list — resetting.")
        else
            _visitedIDs = data
        end
    else
        _visitedIDs = { _sessionHour }
    end
end

local function SaveVisitedIDs()
    -- Cap size to prevent infinite growth
    while #_visitedIDs > MAX_STORED_IDS do
        table.remove(_visitedIDs, 2) -- keep index 1 (hour tag)
    end
    pcall(function()
        writefile(SERVER_FILE, HttpService:JSONEncode(_visitedIDs))
    end)
end

local function MarkVisited(id)
    table.insert(_visitedIDs, id)
    SaveVisitedIDs()
end

local function WasVisited(id)
    for i = 2, #_visitedIDs do -- skip index 1 (hour tag)
        if tostring(_visitedIDs[i]) == tostring(id) then
            return true
        end
    end
    return false
end

LoadVisitedIDs()

-- =====================
-- SERVER FETCH + TELEPORT
-- =====================
local _cursor = ""

local function FetchAndTeleport()
    local url = "https://games.roblox.com/v1/games/" .. PlaceID
        .. "/servers/Public?sortOrder=Asc&limit=100"
    if _cursor ~= "" then
        url = url .. "&cursor=" .. _cursor
    end

    local ok, site = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok or not site or not site.data then
        warn("[ServerHop] Failed to fetch server list.")
        return false
    end

    -- Advance cursor for next call
    if site.nextPageCursor and site.nextPageCursor ~= "null" and site.nextPageCursor ~= nil then
        _cursor = site.nextPageCursor
    else
        _cursor = "" -- reset when we hit the last page
    end

    for _, server in pairs(site.data) do
        local id = tostring(server.id)
        local hasRoom = tonumber(server.maxPlayers) > tonumber(server.playing)

        if hasRoom and not WasVisited(id) then
            MarkVisited(id)
            print("[ServerHop] Teleporting to server: " .. id)
            local teleOk = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceID, id, Player)
            end)
            if teleOk then
                task.wait(6)
                return true
            else
                warn("[ServerHop] TeleportToPlaceInstance failed for: " .. id)
            end
        end
    end

    return false
end

-- =====================
-- PUBLIC API
-- =====================
function ServerHop:Init(Modules)
    _movement = Modules.Movement
    _config   = Modules.Config
end

-- Main hop — tries current page then next page if needed
function ServerHop:Hop()
    print("[ServerHop] Hopping...")
    local hopStart = tick()

    local success = FetchAndTeleport()
    if not success then
        -- Try next page
        print("[ServerHop] No suitable server on first page — trying next page...")
        success = FetchAndTeleport()
    end

    if not success then
        warn("[ServerHop] Could not find a suitable server. Will retry next cycle.")
    end

    -- Timeout guard — if we're still here after 15s, hop likely failed
    if tick() - hopStart < 15 then
        task.wait(5)
        if not success then
            print("[ServerHop] Retry hop...")
            FetchAndTeleport()
        end
    end

    task.wait(3)
    if _movement then _movement:FixCamera() end
end

-- Force rejoin the same game (used by auto rejoin on kick)
function ServerHop:Rejoin()
    print("[ServerHop] Rejoining game...")
    pcall(function()
        TeleportService:Teleport(PlaceID, Player)
    end)
end

-- Recover character and camera after a hop
function ServerHop:RecoverCharacter()
    if _movement then
        task.wait(2)
        _movement:FixCamera()
    end
end

-- =====================
-- AUTO REJOIN ON KICK
-- =====================
CoreGui.DescendantAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        local grabError = child:FindFirstChild("ErrorMessage", true)
        if grabError then
            repeat task.wait() until grabError.Text ~= "Label"
            print("[ServerHop] Kick detected: " .. grabError.Text .. " — Rejoining...")
            task.wait(1)
            ServerHop:Rejoin()
        end
    end
end)

return ServerHop
