-- =====================
-- Prestige.lua
-- Auto prestige / leveling module for YBA.
-- Item collection uses SAME logic as Farm.lua (teleport below item, noclip, etc.)
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
local lastItemTime      = tick()
local NO_ITEM_TIMEOUT   = 20

local SpawnedItems    = {}
local ItemSpawnFolder = nil

-- FIX 1: Use same SAFE_SPOT as Farm (under the map, stable position)
local SAFE_SPOT = CFrame.new(978, -42, -49)

function Prestige:Init(Modules)
    _config    = Modules.Config
    _inventory = Modules.Inventory
    _movement  = Modules.Movement
    _serverHop = Modules.ServerHop
    _webhook   = Modules.Webhook
    _ui        = Modules.UI
end

local function isMaxPrestige()
    return Player.PlayerStats.Prestige.Value >= 3
        and Player.PlayerStats.Level.Value >= 50
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

-- =====================
-- ITEM DETECTION (same as Farm)
-- FIX 2: InitItemDetection called before Start() loop so SpawnedItems
--        is populated before FarmItemFromGround needs it
-- =====================
local function GetItemInfo(model)
    if not (model and model:IsA("Model")
        and model.Parent
        and model.Parent.Name == "Items") then return nil end
    local pp = model.PrimaryPart
    if not pp then return nil end
    local prompt
    for _, v in pairs(model:GetChildren()) do
        if v:IsA("ProximityPrompt") and v.MaxActivationDistance ~= 0 then
            prompt = v break
        end
    end
    if not prompt then return nil end
    return { Name = prompt.ObjectText, ProximityPrompt = prompt, Position = pp.Position }
end

local _detectionInitialized = false
local function InitItemDetection()
    if _detectionInitialized then return end
    _detectionInitialized = true

    pcall(function()
        local spawns = workspace:WaitForChild("Item_Spawns", 15)
        if spawns then ItemSpawnFolder = spawns:WaitForChild("Items", 15) end
    end)
    if not ItemSpawnFolder then
        pcall(function()
            local spawns = workspace:FindFirstChild("Item_Spawns")
            if spawns then ItemSpawnFolder = spawns:FindFirstChild("Items") end
        end)
    end
    if not ItemSpawnFolder then
        warn("[Prestige] ERROR: Item_Spawns/Items folder not found.")
        return
    end
    print("[Prestige] Item_Spawns/Items folder found.")

    -- Scan existing items on the ground
    for _, model in pairs(ItemSpawnFolder:GetChildren()) do
        pcall(function()
            if model:IsA("Model") then
                local info = GetItemInfo(model)
                if info then SpawnedItems[model] = info end
            end
        end)
    end

    ItemSpawnFolder.ChildAdded:Connect(function(model)
        task.wait(1)
        pcall(function()
            if model:IsA("Model") then
                local info = GetItemInfo(model)
                if info then
                    SpawnedItems[model] = info
                    print("[Prestige] Item detected: " .. info.Name)
                    lastItemTime = tick()
                end
            end
        end)
    end)
end

-- =====================
-- COLLECT ITEM
-- FIX 3: validate prompt still exists before firing
--        validate item still in Items folder before teleporting
-- =====================
local function CollectItem(itemInfo, index)
    if not _config:Get("FarmEnabled") then return end

    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if not hrp then return end

    SpawnedItems[index] = nil

    if _inventory:HasMax(itemInfo.Name) then return end

    -- Validate the prompt and model still exist before doing anything
    local prompt = itemInfo.ProximityPrompt
    if not prompt or not prompt.Parent or not prompt.Parent.Parent
        or prompt.Parent.Parent.Name ~= "Items" then
        print("[Prestige] Item already gone: " .. itemInfo.Name)
        return
    end

    local bv = _movement:Freeze()
    _movement:SetNoclip(true)
    _movement:Teleport(CFrame.new(
        itemInfo.Position.X,
        itemInfo.Position.Y - 25,
        itemInfo.Position.Z
    ))
    task.wait(0.5)

    -- Re-validate before firing prompt
    if prompt and prompt.Parent and prompt.Parent.Parent
        and prompt.Parent.Parent.Name == "Items" then
        pcall(function() fireproximityprompt(prompt) end)
    end

    task.wait(0.5)
    _movement:Unfreeze(bv)
    _movement:Teleport(SAFE_SPOT)
    task.wait(0.3)
    _movement:SetNoclip(false)
    lastItemTime = tick()
    print("[Prestige] Collected: " .. itemInfo.Name)
end

-- =====================
-- FARM ITEM FROM GROUND
-- =====================
local function FarmItemFromGround(itemName, targetCount)
    while _inventory:Count(itemName) < targetCount do
        if not _config:Get("FarmEnabled") then return false end
        if _stopRequested then return false end

        local elapsed = tick() - lastItemTime
        if elapsed > NO_ITEM_TIMEOUT then
            print("[Prestige] No " .. itemName .. " for " .. math.floor(elapsed) .. "s — hopping...")
            _serverHop:Hop()
            lastItemTime = tick()
            task.wait(3)
        end

        local snapshot = {}
        for idx, info in pairs(SpawnedItems) do
            if info.Name == itemName then
                table.insert(snapshot, {Index=idx, ItemInfo=info})
            end
        end

        if #snapshot == 0 then
            local waiting = math.floor(NO_ITEM_TIMEOUT - (tick() - lastItemTime))
            print("[Prestige] Waiting for " .. itemName .. "... (" .. waiting .. "s until hop)")
            task.wait(2)
        else
            for _, entry in ipairs(snapshot) do
                if _inventory:Count(itemName) >= targetCount then break end
                CollectItem(entry.ItemInfo, entry.Index)
            end
        end

        task.wait(1)
    end
    return true
end

-- =====================
-- USE ITEM (equip + activate)
-- =====================
local function UseItem(itemName, withWorthiness)
    local item = Player.Backpack:FindFirstChild(itemName)
    if not item then
        print("[Prestige] Item not found in backpack: " .. itemName)
        return false
    end
    local char = Player.Character
    local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
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

-- =====================
-- END DIALOGUE
-- =====================
local function endDialogue(npc, dialogue, option)
    local re = _movement:GetCharacter("RemoteEvent")
    if re then
        re:FireServer("EndDialogue", {
            NPC      = npc,
            Dialogue = dialogue,
            Option   = option
        })
    end
end

-- =====================
-- KILL NPC
-- FIX 4: Added NPC existence check before loop
--        Added health check to avoid attacking items or dead models
--        m1 only fires when NPC is clearly alive and is a Living model
-- =====================
local function killNPC(npcName, distance)
    local npc = workspace.Living:FindFirstChild(npcName)
    if not npc then
        print("[Prestige] NPC not found: " .. npcName)
        return false
    end

    local hrp      = _movement:GetCharacter("HumanoidRootPart")
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

        -- Re-fetch NPC every iteration — it may have respawned or been removed
        npc = workspace.Living:FindFirstChild(npcName)
        if not npc then break end

        local npcHum = npc:FindFirstChildWhichIsA("Humanoid")
        local npcHRP = npc:FindFirstChild("HumanoidRootPart")

        -- Stop if dead
        if not npcHum or not npcHRP or npcHum.Health <= 0 then break end

        -- Teleport under the NPC to attack
        hrp.CFrame = CFrame.new(
            npcHRP.Position.X,
            npcHRP.Position.Y - distance,
            npcHRP.Position.Z
        )

        if remoteFunc then
            pcall(function()
                remoteFunc:InvokeServer("Attack", "m1")
            end)
        end

        task.wait(0.5)
    end

    print("[Prestige] Killed: " .. npcName)
    return true
end

-- =====================
-- PRESTIGE PHASES
-- =====================
local function runStoryPhase()
    print("[Prestige] Phase: STORY")
    _movement:Teleport(CFrame.new(500, 2010, 500))
    task.wait(1)

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
    task.wait(1)

    local currentStand = Player.PlayerStats.Stand.Value
    if currentStand ~= "None" and KEEP_STANDS[currentStand] then
        print("[Prestige] Already have desired stand: " .. currentStand)
        return true
    end

    -- Need Rokakaka to reset unwanted stand
    if currentStand ~= "None" and not KEEP_STANDS[currentStand] then
        print("[Prestige] Unwanted stand: " .. currentStand .. " — using Rokakaka")
        if _inventory:Count("Rokakaka") < 1 then
            if not FarmItemFromGround("Rokakaka", 1) then return false end
        end
        UseItem("Rokakaka", true)
        task.wait(3)
        return false
    end

    -- Get arrow
    if _inventory:Count("Mysterious Arrow") < 1 then
        if not FarmItemFromGround("Mysterious Arrow", 1) then return false end
    end

    UseItem("Mysterious Arrow", true)

    local waited = 0
    repeat
        task.wait(1)
        waited += 1
        if waited > 30 then
            print("[Prestige] Timeout waiting for stand — hopping")
            _serverHop:Hop()
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
            return false
        end
        return true
    end
    return false
end

-- =====================
-- MAIN LOOP
-- FIX 2 applied: InitItemDetection is called at the top of Start()
-- so SpawnedItems is populated before any phase needs it
-- =====================
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

    -- FIX 2: Initialize item detection first, before any farming starts
    InitItemDetection()

    while not _stopRequested do
        -- Pause if farm is disabled via UI
        if not _config:Get("FarmEnabled") then
            print("[Prestige] Farm disabled — waiting...")
            repeat task.wait(1) until _config:Get("FarmEnabled") or _stopRequested
            if _stopRequested then break end
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

        -- Story phase
        if not runStoryPhase() then
            if _stopRequested or not _config:Get("FarmEnabled") then break end
            _serverHop:Hop() task.wait(5)
            continue
        end

        -- Stand phase
        local standOk = false
        while not standOk and not _stopRequested and _config:Get("FarmEnabled") do
            standOk = obtainStandPhase()
            if not standOk then _serverHop:Hop() task.wait(5) end
        end
        if _stopRequested or not _config:Get("FarmEnabled") then break end

        -- Level phase
        if not levelUpPhase() then
            if _stopRequested or not _config:Get("FarmEnabled") then break end
            _serverHop:Hop() task.wait(5)
            continue
        end

        -- Prestige check
        prestigeCheckPhase()

        task.wait(2)
    end

    isPrestigeRunning = false
    print("[Prestige] Stopped.")
end

function Prestige:Stop()
    _stopRequested    = true
    isPrestigeRunning = false
    print("[Prestige] Stop requested.")
end

return Prestige
