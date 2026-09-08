-- =====================
-- CombatFarm.lua
-- Unified combat: NPC and Quest farming.
-- Logic identical to Xenon V5 (stand positioning, attacks, death detection).
-- FIXED: player positioned underground (yOffset -35) with noclip for safety.
-- =====================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local CombatFarm = {}

local _config    = nil
local _inventory = nil
local _movement  = nil
local _serverHop = nil
local _webhook   = nil

local activeMode = nil
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

function CombatFarm:Init(Modules)
    _config    = Modules.Config
    _inventory = Modules.Inventory
    _movement  = Modules.Movement
    _serverHop = Modules.ServerHop
    _webhook   = Modules.Webhook

    task.spawn(function()
        while true do
            task.wait(0.5)
            local hud = Player.PlayerGui:FindFirstChild("HUD")
            if hud then
                local completedFrame = hud:FindFirstChild("QuestCompleted")
                if completedFrame and completedFrame.Visible then
                    questCompleted = true
                    print("[CombatFarm] Quest completed.")
                end
            end
        end
    end)
end

-- =============================================
-- HELPER FUNCTIONS
-- =============================================

local function useMove(move)
    local char = _movement:GetCharacter()
    if not char then return end
    if move == "m1" or move == "m2" then
        local remoteFunc = char:FindFirstChild("RemoteFunction")
        if remoteFunc then
            remoteFunc:InvokeServer("Attack", move)
        end
    elseif typeof(move) == "Enum" then
        local remoteEvent = char:FindFirstChild("RemoteEvent")
        if remoteEvent then
            remoteEvent:FireServer("InputBegan", { Input = move })
        end
    end
end

local function equipStand()
    local char = _movement:GetCharacter()
    if not char then return end
    local remoteFunc = char:FindFirstChild("RemoteFunction")
    if not remoteFunc then return end
    local summoned = char:FindFirstChild("SummonedStand")
    if summoned and summoned.Value == false then
        remoteFunc:InvokeServer("ToggleStand", "Toggle")
        task.wait(0.3)
    end
end

local function getClosestNPC(npcName)
    local closest = nil
    local closestDist = math.huge
    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if not hrp then return nil end
    for _, npc in pairs(workspace.Living:GetChildren()) do
        if npc.Name == npcName and npc:FindFirstChild("HumanoidRootPart") then
            local npcHRP = npc.HumanoidRootPart
            local dist = (hrp.Position - npcHRP.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = npc
            end
        end
    end
    return closest
end

-- =============================================
-- COMBAT CORE (Xenon V5 style)
-- =============================================
local function killTarget(targetName)
    local target = getClosestNPC(targetName) or workspace.Living:FindFirstChild(targetName)
    if not target then
        print("[CombatFarm] Target not found: " .. targetName)
        return false
    end

    local hrp = _movement:GetCharacter("HumanoidRootPart")
    local remoteFunc = _movement:GetCharacter("RemoteFunction")
    if not hrp or not remoteFunc then
        return false
    end

    local oldPos = hrp.CFrame
    local camera = workspace.CurrentCamera
    local oldCameraSubject = camera and camera.CameraSubject
    local oldCameraType = camera and camera.CameraType

    -- Equip stand
    local standPart = nil
    local hasStand = _inventory:HasStand()
    if hasStand then
        equipStand()
        local standMorph = _movement:GetCharacter("StandMorph")
        if standMorph and standMorph.PrimaryPart then
            standPart = standMorph.PrimaryPart
            local standAttach = standPart:FindFirstChild("StandAttach")
            if standAttach then
                local alignPos = standAttach:FindFirstChild("AlignPosition")
                local alignOri = standAttach:FindFirstChild("AlignOrientation")
                if alignPos then alignPos.Enabled = false end
                if alignOri then alignOri.Enabled = false end
            end
            standPart.CanCollide = true
        end
    end

    -- Focus camera
    local focusCam = _movement:GetCharacter("FocusCam")
    if not focusCam then
        focusCam = Instance.new("ObjectValue")
        focusCam.Name = "FocusCam"
        focusCam.Parent = _movement:GetCharacter()
    end
    focusCam.Value = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart

    -- Enable noclip so player can stay underground without collision
    _movement:SetNoclip(true)

    -- Y offset for player position (Xenon V5: player stays underground for safety)
    local yOffset = -35
    if targetName == "The Idol" then yOffset = 35 end

    local startTime = tick()
    local killed = false

    while not stopRequested and tick() - startTime < 60 do
        target = getClosestNPC(targetName) or workspace.Living:FindFirstChild(targetName)
        if not target then
            killed = true
            break
        end

        local enemyHRP = target:FindFirstChild("HumanoidRootPart")
        local enemyHumanoid = target:FindFirstChildWhichIsA("Humanoid")
        local enemyHealth = target:FindFirstChild("Health")

        if not enemyHRP or not enemyHumanoid or not enemyHealth or enemyHealth.Value <= 0 then
            killed = true
            break
        end

        -- XENON V5 POSITIONING: stand behind NPC, player underground
        if standPart and standPart.Parent then
            standPart.CFrame = enemyHRP.CFrame - enemyHRP.CFrame.LookVector * 1.1
            hrp.CFrame = standPart.CFrame + standPart.CFrame.LookVector * math.random(-3, -2) + Vector3.new(0, yOffset, 0)
        else
            hrp.CFrame = enemyHRP.CFrame - enemyHRP.CFrame.LookVector * 2.3 + Vector3.new(0, yOffset, 0)
        end

        -- Attack
        pcall(function()
            remoteFunc:InvokeServer("Attack", "m1")
        end)

        local skills = _config:Get("AutoSkills")
        if type(skills) == "table" then
            for _, sk in ipairs(skills) do
                local keyCode = Enum.KeyCode[sk]
                if keyCode then
                    pcall(function()
                        useMove(keyCode)
                    end)
                end
            end
        end

        task.wait()
    end

    -- Cleanup immediately after the combat loop.
    -- Existing combat offsets/distances are intentionally unchanged.
    if focusCam then
        pcall(function()
            focusCam.Value = nil
            focusCam:Destroy()
        end)
    end

    _movement:SetNoclip(false)

    if hrp and hrp.Parent then
        pcall(function()
            hrp.CFrame = oldPos
        end)
    end

    if camera and camera.Parent then
        pcall(function()
            if oldCameraSubject and oldCameraSubject.Parent then
                camera.CameraSubject = oldCameraSubject
            else
                local character = _movement:GetCharacter()
                local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
                if humanoid then
                    camera.CameraSubject = humanoid
                end
            end

            if oldCameraType then
                camera.CameraType = oldCameraType
            end
        end)
    end

    return killed
end

-- =============================================
-- NPC FARM
-- =============================================
local function runNPCFarm()
    local npcName = _config:Get("SelectedNPC")
    if not npcName or npcName == "" then
        print("[CombatFarm] No NPC selected.")
        return false
    end
    return killTarget(npcName)
end

-- =============================================
-- QUEST FARM
-- =============================================
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

local function readQuestState()
    local stats = Player:FindFirstChild("PlayerStats")
    if not stats then return nil, nil end

    local progressObj = stats:FindFirstChild("QuestProgress")
    local maxProgressObj = stats:FindFirstChild("QuestMaxProgress")

    local progress = progressObj and tonumber(progressObj.Value) or 0
    local maxProgress = maxProgressObj and tonumber(maxProgressObj.Value) or 0
    return progress, maxProgress
end

local function acceptQuest(questName)
    if questOnCooldown and tick() < cooldownUntil then
        local remaining = math.ceil(cooldownUntil - tick())
        print("[CombatFarm] Quest on cooldown, waiting " .. remaining .. " seconds.")
        return false
    end
    questOnCooldown = false

    local dialogues = workspace:FindFirstChild("Dialogues")
    if not dialogues then
        print("[CombatFarm] Dialogues folder not found.")
        return false
    end

    -- Recursive lookup also works when dialogue NPCs are nested in folders.
    local dialogueNPC = dialogues:FindFirstChild(questName, true)
    if not dialogueNPC then
        print("[CombatFarm] Dialogue NPC not found: " .. questName)
        return false
    end

    local dialogueValue = dialogueNPC:FindFirstChild("Dialogue", true)
    if not dialogueValue then
        print("[CombatFarm] No Dialogue value for " .. questName)
        return false
    end

    local remoteEvent = _movement:GetCharacter("RemoteEvent")
    if not remoteEvent then
        print("[CombatFarm] RemoteEvent not found.")
        return false
    end

    local npcDialogue = dialogueValue.Value
    local beforeProgress, beforeMax = readQuestState()

    -- Advance dialogue one step at a time and stop as soon as the quest
    -- state changes, instead of blindly sending the full sequence.
    for i = 1, 10 do
        local dialogueId = "Dialogue" .. i

        pcall(function()
            remoteEvent:FireServer("EndDialogue", {
                ["NPC"] = npcDialogue,
                ["Option"] = "Option1",
                ["Dialogue"] = dialogueId
            })
        end)

        task.wait(0.08)

        local progress, maxProgress = readQuestState()
        if (maxProgress or 0) > 0 or progress ~= beforeProgress or maxProgress ~= beforeMax then
            questCompleted = false
            print("[CombatFarm] Quest accepted: " .. questName)
            return true
        end

        -- Compatibility with dialogue implementations that expect a second
        -- packet without the Option field.
        pcall(function()
            remoteEvent:FireServer("EndDialogue", {
                ["NPC"] = npcDialogue,
                ["Dialogue"] = dialogueId
            })
        end)

        task.wait(0.08)

        progress, maxProgress = readQuestState()
        if (maxProgress or 0) > 0 or progress ~= beforeProgress or maxProgress ~= beforeMax then
            questCompleted = false
            print("[CombatFarm] Quest accepted: " .. questName)
            return true
        end
    end

    -- Short replication window rather than the previous 10-second polling.
    local timeout = tick() + 3
    while tick() < timeout do
        local progress, maxProgress = readQuestState()
        if (maxProgress or 0) > 0 or progress ~= beforeProgress or maxProgress ~= beforeMax then
            questCompleted = false
            print("[CombatFarm] Quest accepted: " .. questName)
            return true
        end
        task.wait(0.1)
    end

    print("[CombatFarm] Quest acceptance failed - possibly on cooldown.")
    questOnCooldown = true
    cooldownUntil = tick() + 60
    return false
end

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

local function runQuestFarm()
    local autoChoose = _config:Get("AutoChooseQuest")
    if autoChoose then
        currentQuest = getBestQuest()
    else
        currentQuest = _config:Get("SelectedQuest")
    end
    if not currentQuest or currentQuest == "" then
        print("[CombatFarm] No quest selected or found.")
        return false
    end

    if not acceptQuest(currentQuest) then
        return false
    end
    task.wait(2)

    if questCompleted then
        print("[CombatFarm] Quest already completed.")
        return true
    end

    local data = questInfo[currentQuest]
    if data.enemy then
        local ok = killTarget(data.enemy)
        if ok then
            local timeout = tick()
            while not questCompleted and tick() - timeout < 15 do
                task.wait(0.5)
            end
            return questCompleted
        end
        return false
    elseif data.item then
        return collectItem(data.item, data.amount)
    end
    return false
end

-- =============================================
-- MAIN LOOP
-- =============================================
local function farmLoop()
    while not stopRequested do
        if activeMode == "NPC" then
            local ok = runNPCFarm()
            if ok then
                print("[CombatFarm] NPC killed. Waiting for respawn...")
                task.wait(5)
            else
                print("[CombatFarm] NPC farm failed. Retrying in 5 seconds...")
                task.wait(5)
            end
        elseif activeMode == "Quest" then
            local ok = runQuestFarm()
            if ok then
                print("[CombatFarm] Quest completed! Moving to next.")
                task.wait(3)
                questCompleted = false
                questOnCooldown = false
            else
                if questOnCooldown then
                    print("[CombatFarm] Quest on cooldown, waiting 60 seconds...")
                    task.wait(60)
                else
                    print("[CombatFarm] Quest failed. Retrying in 5 seconds...")
                    task.wait(5)
                end
            end
        else
            break
        end
        task.wait(1)
    end
end

-- =============================================
-- PUBLIC API
-- =============================================
function CombatFarm:StartNPC()
    if isRunning and activeMode == "NPC" then return end
    if isRunning then self:Stop() end
    activeMode = "NPC"
    stopRequested = false
    isRunning = true
    print("[CombatFarm] Starting NPC farming (Xenon V5 style).")
    task.spawn(farmLoop)
end

function CombatFarm:StartQuest()
    if isRunning and activeMode == "Quest" then return end
    if isRunning then self:Stop() end
    activeMode = "Quest"
    stopRequested = false
    isRunning = true
    questCompleted = false
    questOnCooldown = false
    print("[CombatFarm] Starting Quest farming (Xenon V5 style).")
    task.spawn(farmLoop)
end

function CombatFarm:Stop()
    stopRequested = true
    isRunning = false
    activeMode = nil
    print("[CombatFarm] Stopped.")
end

return CombatFarm
