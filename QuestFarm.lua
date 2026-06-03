-- =====================
-- QuestFarm.lua
-- Xenon V5 style quest farming: accept quest, kill NPCs (fixed stand + frozen player),
-- collect items, and handle quest cooldown.
-- =====================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local QuestFarm = {}

local _config    = nil
local _inventory = nil
local _movement  = nil
local _serverHop = nil
local _webhook   = nil

local isRunning = false
local stopRequested = false
local currentQuest = nil
local questCompleted = false
local questOnCooldown = false
local cooldownUntil = 0

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

    -- Monitor quest completion via GUI
    task.spawn(function()
        while true do
            task.wait(0.5)
            local hud = Player.PlayerGui:FindFirstChild("HUD")
            if hud then
                local completedFrame = hud:FindFirstChild("QuestCompleted")
                if completedFrame then
                    questCompleted = true
                    print("[QuestFarm] Quest completed frame detected.")
                    task.wait(1)
                    while completedFrame and completedFrame.Parent do
                        task.wait(0.5)
                    end
                end
            end
        end
    end)
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

-- Disable stand constraints
local function disableStandConstraints(standMorph)
    if not standMorph then return end
    local primary = standMorph.PrimaryPart
    if not primary then return end
    local standAttach = primary:FindFirstChild("StandAttach")
    if standAttach then
        local alignPos = standAttach:FindFirstChild("AlignPosition")
        local alignOri = standAttach:FindFirstChild("AlignOrientation")
        if alignPos then alignPos.Enabled = false end
        if alignOri then alignOri.Enabled = false end
    end
end

-- Accept quest (with cooldown detection)
local function acceptQuest(questName)
    -- Check cooldown
    if questOnCooldown and tick() < cooldownUntil then
        local remaining = math.ceil(cooldownUntil - tick())
        print("[QuestFarm] Quest on cooldown, waiting " .. remaining .. " seconds.")
        return false
    end
    questOnCooldown = false

    local dialogueNPC = workspace.Dialogues:FindFirstChild(questName)
    if not dialogueNPC then
        print("[QuestFarm] Dialogue NPC not found: " .. questName)
        return false
    end
    local dialogueValue = dialogueNPC:FindFirstChild("Dialogue")
    if not dialogueValue then
        print("[QuestFarm] No Dialogue value for " .. questName)
        return false
    end
    local remoteEvent = _movement:GetCharacter("RemoteEvent")
    if not remoteEvent then
        return false
    end
    local npcDialogue = dialogueValue.Value
    print("[QuestFarm] Accepting quest from " .. npcDialogue)

    -- Try to accept quest
    for i = 1, 10 do
        remoteEvent:FireServer("EndDialogue", {
            ["NPC"] = npcDialogue,
            ["Option"] = "Option1",
            ["Dialogue"] = "Dialogue" .. i
        })
        remoteEvent:FireServer("EndDialogue", {
            ["NPC"] = npcDialogue,
            ["Dialogue"] = "Dialogue" .. i
        })
        task.wait(0.2)
    end

    -- Check if quest was actually accepted (maybe cooldown message appeared)
    task.wait(1)
    -- If quest progress didn't change, assume cooldown
    local progress = Player.PlayerStats.QuestProgress.Value
    local maxProgress = Player.PlayerStats.QuestMaxProgress.Value
    if progress == 0 and maxProgress == 0 then
        print("[QuestFarm] Quest acceptance failed - possibly on cooldown. Waiting 60 seconds.")
        questOnCooldown = true
        cooldownUntil = tick() + 60
        return false
    end

    questCompleted = false
    return true
end

-- Xenon V5 kill logic (identical to NPCFarm)
local function killQuestNPC(npcName)
    local npc = workspace.Living:FindFirstChild(npcName)
    if not npc then
        print("[QuestFarm] NPC not found: " .. npcName)
        return false
    end

    local hrp = _movement:GetCharacter("HumanoidRootPart")
    local remoteFunc = _movement:GetCharacter("RemoteFunction")
    if not hrp or not remoteFunc then
        return false
    end

    local oldPos = hrp.CFrame
    local freezeBV = nil

    local hasStand = _inventory:HasStand()
    if hasStand then
        _inventory:SummonStand()
        task.wait(0.3)
    end

    local standPart = nil
    local standMorph = nil
    if hasStand then
        standMorph = _movement:GetCharacter("StandMorph")
        if standMorph and standMorph.PrimaryPart then
            standPart = standMorph.PrimaryPart
            disableStandConstraints(standMorph)
        end
    end

    if standPart then
        _movement:SetFocusOnPart(standPart)
    else
        _movement:SetFocusOnPart(npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart)
    end

    _movement:SetNoclip(true)
    local yOffset = -35

    local startTime = tick()
    local killed = false

    local targetPosCF = CFrame.new(hrp.Position.X, hrp.Position.Y + yOffset, hrp.Position.Z)
    freezeBV = _movement:FreezeAtPosition(targetPosCF)

    while not stopRequested and tick() - startTime < 60 do
        npc = workspace.Living:FindFirstChild(npcName)
        if not npc then
            killed = true
            break
        end
        local npcHRP = npc:FindFirstChild("HumanoidRootPart")
        local npcHum = npc:FindFirstChildWhichIsA("Humanoid")
        if not npcHRP or not npcHum or npcHum.Health <= 0 then
            killed = true
            break
        end

        if standPart and standPart.Parent then
            standPart.CFrame = npcHRP.CFrame - npcHRP.CFrame.LookVector * 1.1
            local standPos = standPart.Position
            local playerCF = CFrame.new(standPos.X, standPos.Y + yOffset, standPos.Z) +
                             standPart.CFrame.LookVector * math.random(-3, -2)
            if freezeBV and freezeBV.Parent then
                hrp.CFrame = playerCF
            else
                freezeBV = _movement:FreezeAtPosition(playerCF)
            end
        else
            hrp.CFrame = CFrame.new(npcHRP.Position.X, npcHRP.Position.Y + yOffset, npcHRP.Position.Z)
        end

        pcall(function() remoteFunc:InvokeServer("Attack", "m1") end)

        local skills = _config:Get("AutoSkills")
        if type(skills) == "table" then
            for _, sk in ipairs(skills) do
                useSkill(sk)
            end
        end
        task.wait(0.3)
    end

    _movement:ClearFocus()
    _movement:Unfreeze(freezeBV)
    _movement:SetNoclip(false)
    hrp.CFrame = oldPos

    if standMorph then
        local primary = standMorph.PrimaryPart
        if primary then
            local standAttach = primary:FindFirstChild("StandAttach")
            if standAttach then
                local alignPos = standAttach:FindFirstChild("AlignPosition")
                local alignOri = standAttach:FindFirstChild("AlignOrientation")
                if alignPos then alignPos.Enabled = true end
                if alignOri then alignOri.Enabled = true end
            end
        end
    end

    return killed
end

-- Collect ground items
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
                local bv = movement:Freeze()
                movement:SetNoclip(true)
                movement:Teleport(itemModel.PrimaryPart.CFrame - Vector3.new(0, 10, 0))
                task.wait(0.3)
                local prompt = itemModel:FindFirstChildWhichIsA("ProximityPrompt")
                if prompt then fireproximityprompt(prompt) end
                task.wait(0.6)
                movement:Unfreeze(bv)
                movement:Teleport(oldCF)
                movement:SetNoclip(false)
            end
        end
        task.wait(1)
    end
    return inventory:Count(itemName) >= requiredAmount
end

-- Execute one quest
local function runQuest(questName)
    local data = questInfo[questName]
    if not data then
        print("[QuestFarm] Unknown quest: " .. questName)
        return false
    end

    print("[QuestFarm] Accepting quest: " .. questName)
    local accepted = acceptQuest(questName)
    if not accepted then
        return false  -- Cooldown active, will retry later
    end
    task.wait(2)

    if questCompleted then
        print("[QuestFarm] Quest already completed.")
        return true
    end

    if data.enemy then
        print("[QuestFarm] Killing " .. data.enemy)
        local ok = killQuestNPC(data.enemy)
        if ok then
            local timeout = tick()
            while not questCompleted and tick() - timeout < 15 do
                task.wait(0.5)
            end
            return questCompleted
        end
        return false
    elseif data.item then
        print("[QuestFarm] Collecting " .. data.amount .. "x " .. data.item)
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
    questCompleted = false
    questOnCooldown = false
    print("[QuestFarm] Starting quest farming (with cooldown handling)...")

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
            local ok = runQuest(currentQuest)
            if ok then
                print("[QuestFarm] Quest completed! Moving to next.")
                task.wait(3)
                questCompleted = false
                questOnCooldown = false
            else
                if questOnCooldown then
                    print("[QuestFarm] Quest on cooldown, waiting...")
                    task.wait(60)  -- Wait for cooldown
                else
                    print("[QuestFarm] Failed to complete quest. Retrying in 5 seconds...")
                    task.wait(5)
                end
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
