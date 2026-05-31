-- =====================
-- Prestige.lua
-- Auto prestige / leveling module for WHITE HUB V2.
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

local isRunning = false
local stopRequested = false
local SAFE_SPOT = CFrame.new(978, -42, -49)
local HAMON_CHARGE_THRESHOLD = 90

function Prestige:Init(Modules)
    _config    = Modules.Config
    _inventory = Modules.Inventory
    _movement  = Modules.Movement
    _serverHop = Modules.ServerHop
    _webhook   = Modules.Webhook
    _ui        = Modules.UI
    _farm      = Modules.Farm
    if not _farm or not _farm.CollectItemFromGround then
        warn("[Prestige] Farm module missing CollectItemFromGround - will not work.")
    end
    if _config and _config:Get("HamonCharge") then
        HAMON_CHARGE_THRESHOLD = _config:Get("HamonCharge")
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

local function deepStabilize()
    _movement:Teleport(SAFE_SPOT)
    task.wait(0.5)
    local hum = Player.Character and Player.Character:FindFirstChildWhichIsA("Humanoid")
    if hum then
        local state = hum:GetState()
        if state ~= Enum.HumanoidStateType.Standing and state ~= Enum.HumanoidStateType.Running then
            hum:ChangeState(Enum.HumanoidStateType.Standing)
            task.wait(0.5)
        end
    end
    _movement:FixCamera()
    local re = _movement:GetCharacter("RemoteEvent")
    if re then re:FireServer("PressedPlay") end
    task.wait(1)
end

local function collectItem(itemName, targetCount)
    if not _farm then return false end
    deepStabilize()
    return _farm:CollectItemFromGround(itemName, targetCount)
end

local function useItem(itemName, learnWorthiness)
    local item = Player.Backpack:FindFirstChild(itemName)
    if not item then
        print("[Prestige] Item not found: " .. itemName)
        return false
    end
    local char = Player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return false end
    hum:EquipTool(item)
    task.wait(0.3)
    if learnWorthiness then
        local rf = char:FindFirstChild("RemoteFunction")
        if rf then
            rf:InvokeServer("LearnSkill", { Skill = "Worthiness", SkillTreeType = "Character" })
        end
    end
    item:Activate()
    return true
end

local function endDialogue(npc, dialogue, option)
    local re = _movement:GetCharacter("RemoteEvent")
    if re then
        re:FireServer("EndDialogue", { NPC = npc, Dialogue = dialogue, Option = option })
    end
end

local function chargeHamon()
    local char = Player.Character
    if not char then return end
    local hamonVal = char:FindFirstChild("Hamon")
    if not hamonVal then return end
    if hamonVal.Value <= HAMON_CHARGE_THRESHOLD then
        local remoteFunc = char:FindFirstChild("RemoteFunction")
        if remoteFunc then
            remoteFunc:InvokeServer("AssignSkillKey", { Type = "Spec", Key = "Enum.KeyCode.L", Skill = "Hamon Breathing" })
        end
        local remoteEvent = char:FindFirstChild("RemoteEvent")
        if remoteEvent then
            remoteEvent:FireServer("InputBegan", { Input = Enum.KeyCode.L })
        end
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
        if stopRequested then return false end
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
        chargeHamon()
        task.wait(0.5)
    end
    deepStabilize()
    print("[Prestige] Killed: " .. npcName)
    return true
end

local function allocateSkills()
    local rf = _movement:GetCharacter("RemoteFunction")
    if not rf then return end
    local skills = {
        "Destructive Power V",
        "Destructive Power IV",
        "Destructive Power III",
        "Destructive Power II",
        "Destructive Power I"
    }
    for _, skill in ipairs(skills) do
        pcall(function()
            rf:InvokeServer("LearnSkill", { Skill = skill, SkillTreeType = "Stand" })
        end)
    end
    if Player.PlayerStats.Spec.Value == "Hamon (William Zeppeli)" then
        local hamonSkills = {
            "Hamon Punch III",
            "Lung Capacity III",
            "Breathing Technique III"
        }
        for _, skill in ipairs(hamonSkills) do
            pcall(function()
                rf:InvokeServer("LearnSkill", { Skill = skill, SkillTreeType = "Spec" })
            end)
        end
    end
end

local function obtainHamonPhase()
    local autoHamon = _config and _config:Get("AutoHamon") or false
    if not autoHamon then
        print("[Prestige] AutoHamon disabled – skipping Hamon acquisition.")
        return true
    end
    print("[Prestige] Acquiring Hamon...")
    if _inventory:Count("Zeppeli's Hat") < 1 then
        if not collectItem("Zeppeli's Hat", 1) then return false end
    end
    local hat = Player.Backpack:FindFirstChild("Zeppeli's Hat")
    if not hat then
        print("[Prestige] Zeppeli's Hat not found.")
        return false
    end
    local char = Player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if hum then hum:EquipTool(hat) end
    task.wait(0.5)
    local lisa = game.ReplicatedStorage.NewDialogue:FindFirstChild("Lisa Lisa")
    if lisa then
        local remoteEvent = _movement:GetCharacter("RemoteEvent")
        if remoteEvent then
            remoteEvent:FireServer("PromptTriggered", lisa)
        end
    end
    task.wait(5)
    allocateSkills()
    print("[Prestige] Hamon acquired.")
    return true
end

local function runStoryPhase()
    print("[Prestige] Phase: STORY")
    _movement:Teleport(CFrame.new(500, 2010, 500))
    deepStabilize()
    local quests = {
        { name = "Help Giorno by Defeating Security Guards", npc = "Security Guard" },
        { name = "Defeat Leaky Eye Luca",                   npc = "Leaky Eye Luca" },
        { name = "Defeat Bucciarati",                       npc = "Bucciarati"     },
        { name = "Defeat Fugo And His Purple Haze",         npc = "Fugo"           },
        { name = "Defeat Pesci",                            npc = "Pesci"          },
        { name = "Defeat Ghiaccio",                         npc = "Ghiaccio"       },
        { name = "Defeat Diavolo",                          npc = "Diavolo"        },
    }
    for _, q in ipairs(quests) do
        if not _config:Get("FarmEnabled") then return false end
        if stopRequested then return false end
        print("[Prestige] Quest: " .. q.name)
        if not killNPC(q.npc, 15) then
            print("[Prestige] Failed " .. q.npc .. " — hopping...")
            _serverHop:Hop()
            deepStabilize()
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
    deepStabilize()
    local currentStand = Player.PlayerStats.Stand.Value
    if _inventory:Count("Requiem Arrow") >= 1 and (currentStand == "King Crimson" or currentStand == "Star Platinum") then
        print("[Prestige] Auto Requiem triggered – using Requiem Arrow")
        useItem("Requiem Arrow", false)
        task.wait(3)
        return false
    end
    if currentStand ~= "None" and KEEP_STANDS[currentStand] then
        print("[Prestige] Already have desired stand: " .. currentStand)
        allocateSkills()
        return true
    end
    if currentStand ~= "None" and not KEEP_STANDS[currentStand] then
        print("[Prestige] Unwanted stand: " .. currentStand .. " — using Rokakaka")
        if _inventory:Count("Rokakaka") < 1 then
            if not collectItem("Rokakaka", 1) then return false end
        end
        useItem("Rokakaka", false)
        deepStabilize()
        task.wait(3)
        return false
    end
    if _inventory:Count("Mysterious Arrow") < 1 then
        if not collectItem("Mysterious Arrow", 1) then return false end
    end
    useItem("Mysterious Arrow", true)
    local waited = 0
    repeat
        task.wait(1)
        waited = waited + 1
        if waited > 30 then
            print("[Prestige] Timeout waiting for stand — hopping")
            _serverHop:Hop()
            deepStabilize()
            return false
        end
    until Player.PlayerStats.Stand.Value ~= "None" or stopRequested
    if stopRequested then return false end
    local newStand = Player.PlayerStats.Stand.Value
    if not KEEP_STANDS[newStand] then
        print("[Prestige] Got unwanted stand: " .. newStand .. " — will reset next cycle")
        return false
    end
    print("[Prestige] Obtained desired stand: " .. newStand)
    allocateSkills()
    return true
end

local function levelUpPhase()
    print("[Prestige] Phase: LEVELING (waiting for level 50)")
    while Player.PlayerStats.Level.Value < 50 do
        if not _config:Get("FarmEnabled") then return false end
        if stopRequested then return false end
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
            deepStabilize()
            return false
        end
    end
    return false
end

function Prestige:Start()
    if isRunning then
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
    stopRequested = false
    isRunning = true
    print("[Prestige] Starting prestige automation...")
    deepStabilize()
    while not stopRequested do
        if not _config:Get("FarmEnabled") then
            print("[Prestige] Farm disabled — waiting...")
            repeat task.wait(1) until _config:Get("FarmEnabled") or stopRequested
            if stopRequested then break end
            deepStabilize()
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
        -- Hamon (optional)
        if not obtainHamonPhase() then
            if stopRequested or not _config:Get("FarmEnabled") then break end
            _serverHop:Hop()
            deepStabilize()
            task.wait(5)
            continue
        end
        -- Story
        if not runStoryPhase() then
            if stopRequested or not _config:Get("FarmEnabled") then break end
            _serverHop:Hop()
            deepStabilize()
            task.wait(5)
            continue
        end
        -- Stand
        local standOk = false
        while not standOk and not stopRequested and _config:Get("FarmEnabled") do
            standOk = obtainStandPhase()
            if not standOk then
                _serverHop:Hop()
                deepStabilize()
                task.wait(5)
            end
        end
        if stopRequested or not _config:Get("FarmEnabled") then break end
        -- Level
        if not levelUpPhase() then
            if stopRequested or not _config:Get("FarmEnabled") then break end
            _serverHop:Hop()
            deepStabilize()
            task.wait(5)
            continue
        end
        -- Prestige
        prestigeCheckPhase()
        task.wait(2)
    end
    isRunning = false
    print("[Prestige] Stopped.")
end

function Prestige:Stop()
    stopRequested = true
    isRunning = false
    print("[Prestige] Stop requested.")
end

return Prestige
