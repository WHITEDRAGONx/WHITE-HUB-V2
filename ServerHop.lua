-- =====================
-- ServerHop.lua
-- Handles server hopping and auto rejoin.
-- Credit: https://github.com/Vcsk/RobloxScripts/blob/main/ServerHop.lua
-- =====================

local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui         = game:GetService("CoreGui")
local Players         = game:GetService("Players")

local Player  = Players.LocalPlayer
local PlaceID = game.PlaceId

local ServerHop = {}
local _movement = nil

local AllIDs        = {}
local foundAnything = ""
local actualHour    = os.date("!*t").hour

local fileOk = pcall(function()
    AllIDs = HttpService:JSONDecode(readfile("NotSameServers.json"))
end)
if not fileOk then
    table.insert(AllIDs, actualHour)
    pcall(function()
        writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
    end)
end

local function TPReturner()
    local Site
    if foundAnything == "" then
        Site = HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100"
        ))
    else
        Site = HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. foundAnything
        ))
    end

    if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
        foundAnything = Site.nextPageCursor
    end

    local ID  = ""
    local num = 0

    for _, v in pairs(Site.data) do
        local Possible = true
        ID = tostring(v.id)

        if tonumber(v.maxPlayers) > tonumber(v.playing) then
            for _, Existing in pairs(AllIDs) do
                if num ~= 0 then
                    if ID == tostring(Existing) then Possible = false end
                else
                    if tonumber(actualHour) ~= tonumber(Existing) then
                        pcall(function()
                            delfile("NotSameServers.json")
                            AllIDs = {}
                            table.insert(AllIDs, actualHour)
                        end)
                    end
                end
                num = num + 1
            end

            if Possible == true then
                table.insert(AllIDs, ID)
                task.wait()
                pcall(function()
                    writefile("NotSameServers.json", HttpService:JSONEncode(AllIDs))
                    task.wait()
                    TeleportService:TeleportToPlaceInstance(PlaceID, ID, Player)
                end)
                task.wait(4)
            end
        end
    end
end

function ServerHop:Init(Modules)
    _movement = Modules.Movement
end

function ServerHop:Hop()
    print("[ServerHop] Hopping to a new server...")
    pcall(function()
        TPReturner()
        if foundAnything ~= "" then
            TPReturner()
        end
    end)
    if _movement then
        task.wait(3)
        _movement:FixCamera()
    end
end

function ServerHop:Rejoin()
    print("[ServerHop] Rejoining game...")
    pcall(function()
        TeleportService:Teleport(PlaceID, Player)
    end)
end

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
