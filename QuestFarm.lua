-- =====================
-- QuestFarm.lua
-- Handles automatic quest farming for YBA.
-- =====================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local QuestFarm = {}

local _config    = nil
local _inventory = nil
local _movement  = nil
local _serverHop = nil
local _webhook   = nil
local _farm      = nil

local isRunning = false
local stopRequested = false
local currentQuest = nil

local questInfo = {
    ["Officer Sam [Lvl. 1+]"] = { enemy = "Thug" },
    ["Deputy Bertrude [Lvl. 10+]"] = { enemy = "Corrupt Police" },
    ["Homeless Man Jill [Lvl. 15+]"] = { item = "Gold Coin", amount = 10 },
    ["Dracula [Lvl. 20+]"] = { enemy = "Zombie Henchman" },
    ["William Zeppeli [Lvl. 25+]"] = { enemy = "Vampire" },
    ["Doppio [Lvl. 30+]"] = { enemy = "Dio" },
    ["Dio [Lvl. 35+]"] = { enemy = "Jotaro" },
}

function QuestFarm:Init(Modules)
    _config    = Modules.Config
    _inventory = Modules.Inventory
    _movement  = Modules.Movement
    _serverHop = Modules.ServerHop
    _webhook   = Modules.Webhook
    _farm      = Modules.Farm
end

local function getBestQuest()
    local level = Player.PlayerStats.Level.Value
    local best = nil
    local bestReq = 0
    for questName, _ in pairs(questInfo) do
        local lvlStr = string.match(questName, "Lvl%. (%d+)%+")
        if lvlStr then
            local req = tonumber(lvlStr)
            if req and req <= level and req > bestReq then
                bestReq = req
                best = questName
            end
        end
    end
    return best
end

local function useSkill(skillKey)
    local re = _movement:GetCharacter("RemoteEvent")
    if re then
        re:FireServer("InputBegan", { Input = Enum.KeyCode[skillKey] })
    end
end

local function killNPC(npcName)
    local npc = workspace.Living:FindFirstChild(npcName)
    if not npc then
        print("[QuestFarm] NPC not found: " .. npcName)
        return false
    end
    local hrp = _movement:GetCharacter("HumanoidRootPart")
    local remoteFunc = _movement:GetCharacter("RemoteFunction")
    if not hrp then
        return false
    end
    local startTime = tick()
    while true do
        if stopRequested then
            return false
        end
        if tick() - startTime > 60 then
            print("[QuestFarm] Timeout killing " .. npcName)
            return false
        end
        npc = workspace.Living:FindFirstChild(npcName)
        if not npc then
            break
        end
        local npcHum = npc:FindFirstChildWhichIsA("Humanoid")
        local npcHRP = npc:FindFirstChild("HumanoidRootPart")
        if not npcHum or not npcHRP or npcHum.Health <= 0 then
            break
        end
        hrp.CFrame = CFrame.new(npcHRP.Position.X, npcHRP.Position.Y - 15, npcHRP.Position.Z)
        if remoteFunc then
            pcall(function() remoteFunc:InvokeServer("Attack", "m1") end)
        end
        local skills = _config:Get("AutoSkills")
        if type(skills) == "table" then
            for _, sk in ipairs(skills) do
                useSkill(sk)
            end
        end
        task.wait(0.3)
    end
    return true
end

-- Fixed item collection (no dependency on Farm.CollectItemFromGround)
local function collectItem(itemName, requiredAmount)
    local inventory = _inventory
    local movement  = _movement
    local startTime = tick()
    while inventory:Count(itemName) < requiredAmount and (tick() - startTime) < 120 do
        local itemModel = nil
        local itemsFolder = workspace.Item_Spawns and workspace.Item_Spawns.Items
        if itemsFolder then
            for _, model in pairs(itemsFolder:GetChildren()) do
                if model:IsA("Model") then
                    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt")
                    if prompt and prompt.ObjectText == itemName and prompt.MaxActivationDistance == 8 then
                        itemModel = model
                        break
                    end
                end
            end
        end
        if itemModel and itemModel.PrimaryPart then
            local hrp = movement:GetCharacter("HumanoidRootPart")
            if hrp then
                local oldCF = hrp.CFrame
                hrp.CFrame = itemModel.PrimaryPart.CFrame - Vector3.new(0, 10, 0)
                task.wait(0.3)
                local prompt = itemModel:FindFirstChildWhichIsA("ProximityPrompt")
                if prompt then
                    fireproximityprompt(prompt)
                end
                task.wait(0.6)
                hrp.CFrame = oldCF
            end
        end
        task.wait(1)
    end
    return inventory:Count(itemName) >= requiredAmount
end

local function completeQuest(questName)
    local data = questInfo[questName]
    if not data then
        print("[QuestFarm] Unknown quest: " .. questName)
        return false
    end
    if data.enemy then
        return killNPC(data.enemy)
    elseif data.item then
        return collectItem(data.item, data.amount)
    end
    return false
end

function QuestFarm:Start()
    if isRunning then
        print("[QuestFarm] Already running.")
        return
    end
    stopRequested = false
    isRunning = true
    print("[QuestFarm] Starting quest farming...")
    
    while not stopRequested do
        local autoChoose = _config:Get("AutoChooseQuest")
        if autoChoose then
            currentQuest = getBestQuest()
        else
            currentQuest = _config:Get("SelectedQuest")
        end
        if not currentQuest or currentQuest == "" then
            print("[QuestFarm] No quest selected or found. Waiting...")
            task.wait(5)
        else
            print("[QuestFarm] Working on quest: " .. currentQuest)
            local ok = completeQuest(currentQuest)
            if ok then
                print("[QuestFarm] Quest completed! Moving to next.")
                task.wait(2)
            else
                print("[QuestFarm] Failed to complete quest, waiting before retry...")
                task.wait(5)
            end
        end
        task.wait(1)
    end
    isRunning = false
    print("[QuestFarm] Stopped.")
end

function QuestFarm:Stop()
    stopRequested = true
    isRunning = false
    print("[QuestFarm] Stop requested.")
end

return QuestFarm
