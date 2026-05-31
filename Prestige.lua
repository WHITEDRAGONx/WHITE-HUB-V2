-- =====================
-- Prestige.lua
-- Auto prestige / leveling module for YBA.
-- Uses Farm:CollectItemFromGround() with extra character stabilization.
-- =====================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local Prestige = {}

local _config    = nil
local _inventory = nil
local _movement  = nil
local _serverHop = nil
local _webhook   = nil
local _ui        = nil
local _farm      = nil

local KEEP_STANDS = {
    ["The World"] = true,
    ["Star Platinum"] = true,
    ["Star Platinum: The World"] = true,
    ["Crazy Diamond"] = true,
    ["King Crimson"] = true,
    ["King Crimson Requiem"] = true
}

local isPrestigeRunning = false
local _stopRequested    = false
local SAFE_SPOT = CFrame.new(978, -42, -49)

function Prestige:Init(Modules)
    _config    = Modules.Config
    _inventory = Modules.Inventory
    _movement  = Modules.Movement
    _serverHop = Modules.ServerHop
    _webhook   = Modules.Webhook
    _ui        = Modules.UI
    _farm      = Modules.Farm
    if not _farm or not _farm.CollectItemFromGround then
        warn("[Prestige] Farm module missing CollectItemFromGround - item collection will fail")
    end
end

local function isMaxPrestige()
    return Player.PlayerStats.Prestige.Value >= 3 and Player.PlayerStats.Level.Value >= 50
end

local function disableAutoPrestige()
    if _config then _config:Set("AutoPrestige", false) end
    if _ui and _ui.SetToggleValue then
        _ui:SetToggleValue("Auto Prestige Mode", false)
    end
end

local function showPopup(msg)
    if _ui and _ui.ShowPopup then
        _ui:ShowPopup(msg, 4)
    else
        print("[Prestige] " .. msg)
    end
end

-- Full character stabilization (ensures not in ragdoll/freefall)
local function DeepStabilize()
    -- Teleport to safe spot under the map
    _movement:Teleport(SAFE_SPOT)
    task.wait(0.5)
    -- Force humanoid to be in normal state
    local hum = Player.Character and Player.Character:FindFirstChildWhichIsA("Humanoid")
    if hum and hum:GetState() ~= Enum.HumanoidStateType.Running and hum:GetState() ~= Enum.HumanoidStateType.Standing then
        hum:ChangeState(Enum.HumanoidStateType.Standing)
        task.wait(0.5)
    end
    -- Fix camera
    _movement:FixCamera()
    -- Ensure remote event is fired (PressedPlay) to re-enable controls
    local re = _movement:GetCharacter("RemoteEvent")
    if re then re:FireServer("PressedPlay") end
    task.wait(1)
end

local function CollectItem(itemName, targetCount)
    if not _farm or not _farm.CollectItemFromGround then
        print("[Prestige] Cannot collect " .. itemName .. " - Farm collection not available")
        return false
    end
    -- Stabilize before any collection attempt to prevent falling
    DeepStabilize()
    return _farm:CollectItemFromGround(itemName, targetCount)
end

local function UseItem(itemName, withWorthiness)
    local item = Player.Backpack:FindFirstChild(itemName)
    if not item then
        print("[Prestige] Item not found in backpack: " .. itemName)
        return false
    end
    local char = Player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return false end
    hum:EquipTool(item)
    task.wait(0.3)
    if withWorthiness then
        local remoteFunc = char:FindFirstChild("RemoteFunction")
        if remoteFunc then
            remoteFunc:InvokeServer("LearnSkill", {
                Skill = "Worthiness",
                SkillTreeType = "Character"
            })
        end
    end
    item:Activate()
    return true
end

local function endDialogue(npc, dialogue, option)
    local re = _movement:GetCharacter("RemoteEvent")
    if re then
        re:FireServer("EndDialogue", {
            NPC = npc,
            Dialogue = dialogue,
            Option = option
        })
    end
end

local function killNPC(npcName, distance)
    local npc = workspace.Living:FindFirstChild(npcName)
    if not npc then
        print("[Prestige] NPC not found: " .. npcName)
        return false
    end
    local hrp = _movement:GetCharacter("HumanoidRootPart")
    local remoteFunc = _movement:GetCharacter("RemoteFunction")
    if not hrp then return false end
    local startTime = tick()
    while true do
        if _stopRequested then return false end
        if not _config:Get("FarmEnabled") then return false end
        if tick() - startTime > 90 then
            print("[Prestige] Timeout killing " .. npcName)
            return false
        end
        npc = workspace.Living:FindFirstChild(npcName)
        if not npc then break end
        local npcHum = npc:FindFirstChildWhichIsA("Humanoid")
        local npcHRP = npc:FindFirstChild("HumanoidRootPart")
        if not npcHum or not npcHRP or npcHum.Health <= 0 then break end
        hrp.CFrame = CFrame.new(npcHRP.Position.X, npcHRP.Position.Y - distance, npcHRP.Position.Z)
        if remoteFunc then
            pcall(function() remoteFunc:InvokeServer("Attack", "m1") end)
        end
        task.wait(0.5)
    end
    -- After killing, deep stabilize to avoid falling during next collection
    DeepStabilize()
    print("[Prestige] Killed: " .. npcName)
    return true
end

local function runStoryPhase()
    print("[Prestige] Phase: STORY")
    _movement:Teleport(CFrame.new(500, 2010, 500))
    DeepStabilize()
    local quests = {
        { name = "Help Giorno by Defeating Security Guards", npc = "Security Guard" },
        { name = "Defeat Leaky Eye Luca",                   npc = "Leaky Eye Luca" },
        { name = "Defeat Bucciarati",                       npc = "Bucciarati"     },
        { name = "Defeat Fugo And His Purple Haze",         npc = "Fugo"           },
        { name = "Defeat Pesci",                            npc = "Pesci"          },
        { name = "Defeat Ghiaccio",                         npc = "Ghiaccio"       },
        { name = "Defeat Diavolo",                          npc = "Diavolo"        },
    }
    for _, quest in ipairs(quests) do
        if not _config:Get("FarmEnabled") then return false end
        if _stopRequested then return false end
        print("[Prestige] Quest: " .. quest.name)
        if not killNPC(quest.npc, 15) then
            print("[Prestige] Failed " .. quest.npc .. " — hopping...")
            _serverHop:Hop()
            DeepStabilize()
            return false
        end
        task.wait(2)
        endDialogue("Storyline", "Dialogue1", "Option1")
        task.wait(1)
    end
    return true
end

local function obtainStandPhase()
    print("[Prestige] Phase: STAND FARM")
    _movement:Teleport(CFrame.new(500, 2010, 500))
    DeepStabilize()
    local currentStand = Player.PlayerStats.Stand.Value
    if currentStand ~= "None" and KEEP_STANDS[currentStand] then
        print("[Prestige] Already have desired stand: " .. currentStand)
        return true
    end
    if currentStand ~= "None" and not KEEP_STANDS[currentStand] then
        print("[Prestige] Unwanted stand: " .. currentStand .. " — using Rokakaka")
        if _inventory:Count("Rokakaka") < 1 then
            if not CollectItem("Rokakaka", 1) then return false end
        end
        UseItem("Rokakaka", true)
        DeepStabilize()
        task.wait(3)
        return false
    end
    if _inventory:Count("Mysterious Arrow") < 1 then
        if not CollectItem("Mysterious Arrow", 1) then return false end
    end
    UseItem("Mysterious Arrow", true)
    local waited = 0
    repeat
        task.wait(1)
        waited += 1
        if waited > 30 then
            print("[Prestige] Timeout waiting for stand — hopping")
            _serverHop:Hop()
            DeepStabilize()
            return false
        end
    until Player.PlayerStats.Stand.Value ~= "None" or _stopRequested
    if _stopRequested then return false end
    local newStand = Player.PlayerStats.Stand.Value
    if not KEEP_STANDS[newStand] then
        print("[Prestige] Got unwanted stand: " .. newStand .. " — will reset next cycle")
        return false
    end
    print("[Prestige] Obtained: " .. newStand)
    return true
end

local function levelUpPhase()
    print("[Prestige] Phase: LEVELING (waiting for level 50)")
    while Player.PlayerStats.Level.Value < 50 do
        if not _config:Get("FarmEnabled") then return false end
        if _stopRequested then return false end
        task.wait(5)
    end
    return true
end

local function prestigeCheckPhase()
    if Player.PlayerStats.Level.Value == 50 then
        local prestige = Player.PlayerStats.Prestige.Value
        if prestige < 3 then
            print("[Prestige] Prestiging: " .. prestige .. " → " .. (prestige+1))
            endDialogue("Prestige", "Dialogue2", "Option1")
            task.wait(2)
            _serverHop:Hop()
            DeepStabilize()
            return false
        end
        return true
    end
    return false
end

function Prestige:Start()
    if isPrestigeRunning then
        print("[Prestige] Already running.")
        return
    end
    if isMaxPrestige() then
        if not _config:Get("PrestigeMaxNotified") then
            if _webhook then _webhook:SendPrestigeComplete() end
            _config:Set("PrestigeMaxNotified", true)
        end
        showPopup("You are already Prestige 3, Level 50.\nAuto Prestige cannot be enabled.")
        disableAutoPrestige()
        print("[Prestige] Max prestige reached — disabling.")
        return
    end
    _stopRequested = false
    isPrestigeRunning = true
    print("[Prestige] Starting prestige automation...")
    DeepStabilize()
    while not _stopRequested do
        if not _config:Get("FarmEnabled") then
            print("[Prestige] Farm disabled — waiting...")
            repeat task.wait(1) until _config:Get("FarmEnabled") or _stopRequested
            if _stopRequested then break end
            DeepStabilize()
        end
        if isMaxPrestige() then
            if not _config:Get("PrestigeMaxNotified") then
                if _webhook then _webhook:SendPrestigeComplete() end
                _config:Set("PrestigeMaxNotified", true)
            end
            showPopup("Congratulations! Prestige 3, Level 50.\nAuto Prestige disabled.")
            disableAutoPrestige()
            break
        end
        if not runStoryPhase() then
            if _stopRequested or not _config:Get("FarmEnabled") then break end
            _serverHop:Hop()
            DeepStabilize()
            task.wait(5)
            continue
        end
        local standOk = false
        while not standOk and not _stopRequested and _config:Get("FarmEnabled") do
            standOk = obtainStandPhase()
            if not standOk then
                _serverHop:Hop()
                DeepStabilize()
                task.wait(5)
            end
        end
        if _stopRequested or not _config:Get("FarmEnabled") then break end
        if not levelUpPhase() then
            if _stopRequested or not _config:Get("FarmEnabled") then break end
            _serverHop:Hop()
            DeepStabilize()
            task.wait(5)
            continue
        end
        prestigeCheckPhase()
        task.wait(2)
    end
    isPrestigeRunning = false
    print("[Prestige] Stopped.")
end

function Prestige:Stop()
    _stopRequested = true
    isPrestigeRunning = false
    print("[Prestige] Stop requested.")
end

return Prestige
