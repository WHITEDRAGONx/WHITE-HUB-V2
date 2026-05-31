-- =====================
-- Prestige.lua
-- Auto prestige / leveling module for YBA.
-- Item collection uses improved teleport (above the item).
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
local _stopRequested = false
local lastItemTime = tick()
local NO_ITEM_TIMEOUT = 20

local SpawnedItems = {}
local ItemSpawnFolder = nil

function Prestige:Init(Modules)
    _config    = Modules.Config
    _inventory = Modules.Inventory
    _movement  = Modules.Movement
    _serverHop = Modules.ServerHop
    _webhook   = Modules.Webhook
    _ui        = Modules.UI
end

local function isMaxPrestige()
    return Player.PlayerStats.Prestige.Value >= 3 and Player.PlayerStats.Level.Value >= 50
end

local function disableAutoPrestige()
    if _config then
        _config:Set("AutoPrestige", false)
    end
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
-- =====================
local function GetItemInfo(model)
    if not (model and model:IsA("Model") and model.Parent and model.Parent.Name == "Items") then return nil end
    local pp = model.PrimaryPart
    if not pp then return nil end
    local prompt
    for _, v in pairs(model:GetChildren()) do
        if v:IsA("ProximityPrompt") and v.MaxActivationDistance ~= 0 then prompt = v break end
    end
    if not prompt then return nil end
    return { Name = prompt.ObjectText, ProximityPrompt = prompt, Position = pp.Position }
end

local function InitItemDetection()
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
                end
            end
        end)
    end)
end

local SAFE_SPOT = CFrame.new(978, -42, -49)

-- =====================
-- COLLECT ITEM (IMPROVED: teleport above item, not below)
-- =====================
local function CollectItem(itemInfo, index)
    if not _config:Get("FarmEnabled") then return end
    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if not hrp then return end
    SpawnedItems[index] = nil
    if _inventory:HasMax(itemInfo.Name) then return end
    
    -- Freeze and noclip
    local bv = _movement:Freeze()
    _movement:SetNoclip(true)
    
    -- Teleport to item position + a bit above (to avoid falling through floor)
    local itemPos = itemInfo.Position
    local teleportPos = CFrame.new(itemPos.X, itemPos.Y + 3, itemPos.Z) -- 3 studs above item
    _movement:Teleport(teleportPos)
    task.wait(0.2)
    
    -- Fire proximity prompt
    pcall(function() fireproximityprompt(itemInfo.ProximityPrompt) end)
    task.wait(0.5)
    
    -- Unfreeze and return to safe spot
    _movement:Unfreeze(bv)
    _movement:Teleport(SAFE_SPOT)
    task.wait(0.3)
    _movement:SetNoclip(false)
    
    lastItemTime = tick()
    print("[Prestige] Collected: " .. itemInfo.Name)
end

-- =====================
-- FARM ITEM FROM GROUND (using snapshot, same as Farm)
-- =====================
local function FarmItemFromGround(itemName, targetCount)
    local startTime = tick()
    while _inventory:Count(itemName) < targetCount do
        if not _config:Get("FarmEnabled") then return false end
        if _stopRequested then return false end
        
        -- Timeout -> hop
        local elapsed = tick() - lastItemTime
        if elapsed > NO_ITEM_TIMEOUT then
            print("[Prestige] No items for " .. elapsed .. "s, hopping...")
            _serverHop:Hop()
            startTime = tick()
            lastItemTime = tick()
            task.wait(2)
        end
        
        -- Snapshot current items of the desired type
        local snapshot = {}
        for idx, info in pairs(SpawnedItems) do
            if info.Name == itemName then
                table.insert(snapshot, {Index=idx, ItemInfo=info})
            end
        end
        
        if #snapshot == 0 then
            print("[Prestige] Waiting for " .. itemName .. " to spawn...")
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
local function UseItem(itemName, worthinessLevel)
    local item = Player.Backpack:FindFirstChild(itemName)
    if not item then
        print("[Prestige] Item not found: " .. itemName)
        return false
    end
    local char = Player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if hum then
        hum:EquipTool(item)
        task.wait(0.3)
        if worthinessLevel then
            local remoteFunc = char:FindFirstChild("RemoteFunction")
            if remoteFunc then
                remoteFunc:InvokeServer("LearnSkill", { Skill = "Worthiness", SkillTreeType = "Character" })
            end
        end
        item:Activate()
        return true
    end
    return false
end

-- =====================
-- DIALOGUE & NPC KILLING (only for quests)
-- =====================
local function endDialogue(npc, dialogue, option)
    local remoteEvent = _movement:GetCharacter("RemoteEvent")
    if remoteEvent then
        remoteEvent:FireServer("EndDialogue", {
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
    if not hrp then return false end
    local remoteFunc = _movement:GetCharacter("RemoteFunction")
    local startTime = tick()
    while npc and npc.Parent and npc.Humanoid and npc.Humanoid.Health > 0 do
        if not _config:Get("FarmEnabled") then return false end
        if _stopRequested then return false end
        if tick() - startTime > 60 then
            print("[Prestige] Timeout killing " .. npcName)
            return false
        end
        -- Teleport close to NPC
        local npcPos = npc.HumanoidRootPart.Position
        hrp.CFrame = CFrame.new(npcPos.X, npcPos.Y - distance, npcPos.Z)
        -- Attack
        if remoteFunc then
            remoteFunc:InvokeServer("Attack", "m1")
        end
        task.wait(0.5)
    end
    return true
end

-- =====================
-- PRESTIGE PHASES
-- =====================
local function runStoryPhase()
    print("[Prestige] Phase: STORY")
    _movement:Teleport(CFrame.new(500, 2010, 500))
    local quests = {
        { name = "Help Giorno by Defeating Security Guards", npc = "Security Guard" },
        { name = "Defeat Leaky Eye Luca", npc = "Leaky Eye Luca" },
        { name = "Defeat Bucciarati", npc = "Bucciarati" },
        { name = "Defeat Fugo And His Purple Haze", npc = "Fugo" },
        { name = "Defeat Pesci", npc = "Pesci" },
        { name = "Defeat Ghiaccio", npc = "Ghiaccio" },
        { name = "Defeat Diavolo", npc = "Diavolo" }
    }
    for _, quest in ipairs(quests) do
        if not _config:Get("FarmEnabled") then return false end
        if _stopRequested then return false end
        print("[Prestige] Starting quest: " .. quest.name)
        if not killNPC(quest.npc, 15) then
            print("[Prestige] Failed to kill " .. quest.npc .. ", hopping...")
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
    local currentStand = Player.PlayerStats.Stand.Value
    if currentStand ~= "None" and KEEP_STANDS[currentStand] then
        print("[Prestige] Already have desired stand: " .. currentStand)
        return true
    end
    if _inventory:Count("Mysterious Arrow") < 1 then
        if not FarmItemFromGround("Mysterious Arrow", 1) then return false end
    end
    UseItem("Mysterious Arrow", "II")
    repeat task.wait(1) until Player.PlayerStats.Stand.Value ~= "None" or _stopRequested
    if _stopRequested then return false end
    local newStand = Player.PlayerStats.Stand.Value
    if not KEEP_STANDS[newStand] then
        print("[Prestige] Got undesired stand: " .. newStand .. ", using Rokakaka")
        if _inventory:Count("Rokakaka") < 1 then
            if not FarmItemFromGround("Rokakaka", 1) then return false end
        end
        UseItem("Rokakaka", "II")
        task.wait(2)
        return false
    end
    print("[Prestige] Obtained desired stand: " .. newStand)
    return true
end

local function levelUpPhase()
    print("[Prestige] Phase: LEVELING (passive)")
    while Player.PlayerStats.Level.Value < 50 do
        if not _config:Get("FarmEnabled") then return false end
        if _stopRequested then return false end
        task.wait(5)
        if Player.PlayerStats.Level.Value >= 50 then break end
    end
    return true
end

local function prestigeCheckPhase()
    if Player.PlayerStats.Level.Value == 50 then
        local prestige = Player.PlayerStats.Prestige.Value
        if prestige < 3 then
            print("[Prestige] Prestiging from " .. prestige .. " to " .. (prestige+1))
            endDialogue("Prestige", "Dialogue2", "Option1")
            task.wait(2)
            _serverHop:Hop()
            return false
        else
            print("[Prestige] Already max prestige.")
            return true
        end
    end
    return false
end

-- =====================
-- MAIN LOOP
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
        print("[Prestige] Max prestige reached, disabling Auto Prestige.")
        return
    end
    
    _stopRequested = false
    isPrestigeRunning = true
    print("[Prestige] Starting prestige automation...")
    InitItemDetection()
    
    while not _stopRequested do
        if not _config:Get("FarmEnabled") then
            print("[Prestige] Farm disabled, waiting...")
            repeat task.wait(1) until _config:Get("FarmEnabled") or _stopRequested
            if _stopRequested then break end
        end
        
        if isMaxPrestige() then
            if not _config:Get("PrestigeMaxNotified") then
                if _webhook then _webhook:SendPrestigeComplete() end
                _config:Set("PrestigeMaxNotified", true)
            end
            showPopup("Congratulations! You reached Prestige 3, Level 50.\nAuto Prestige will now disable.")
            disableAutoPrestige()
            break
        end
        
        -- Story
        local storySuccess = runStoryPhase()
        if not storySuccess then
            if not _config:Get("FarmEnabled") then break end
            if _stopRequested then break end
            _serverHop:Hop()
            task.wait(5)
        else
            -- Stand
            local standSuccess = false
            while not standSuccess and not _stopRequested and _config:Get("FarmEnabled") do
                standSuccess = obtainStandPhase()
                if not standSuccess then
                    _serverHop:Hop()
                    task.wait(5)
                end
            end
            if _stopRequested or not _config:Get("FarmEnabled") then break end
            
            -- Level
            local levelSuccess = levelUpPhase()
            if not levelSuccess then
                if not _config:Get("FarmEnabled") then break end
                if _stopRequested then break end
                _serverHop:Hop()
                task.wait(5)
            else
                -- Prestige
                prestigeCheckPhase()
            end
        end
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
