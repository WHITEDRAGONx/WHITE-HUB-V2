-- =====================
-- CombatFarm.lua
-- Unified combat farming: NPC, Quest, and future Player farming.
-- Xenon V5 style: stand follows NPC, player stays underground.
-- =====================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local CombatFarm = {}

local _config    = nil
local _inventory = nil
local _movement  = nil
local _serverHop = nil
local _webhook   = nil

local activeMode = nil   -- "NPC", "Quest", or "Player"
local isRunning = false
local stopRequested = false
local currentQuest = nil
local questCompleted = false
local questOnCooldown = false
local cooldownUntil = 0

-- Quest definitions
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

    -- Monitor quest completion (for Quest mode)
    task.spawn(function()
        while true do
            task.wait(0.5)
            local hud = Player.PlayerGui:FindFirstChild("HUD")
            if hud then
                local completedFrame = hud:FindFirstChild("QuestCompleted")
                if completedFrame then
                    questCompleted = true
                    print("[CombatFarm] Quest completed frame detected.")
                    task.wait(1)
                    while completedFrame and completedFrame.Parent do
                        task.wait(0.5)
                    end
                end
            end
        end
    end)
end

-- =====================
-- Helper functions (Xenon V5 style)
-- =====================
local function useSkill(skillKey)
    local re = _movement:GetCharacter("RemoteEvent")
    if re then
        re:FireServer("InputBegan", { Input = Enum.KeyCode[skillKey] })
    end
end

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

-- =====================
-- Combat core (fixed: only stand moves, player stays underground)
-- =====================
local function killTarget(targetName, isNPC, isQuest)
    local target = workspace.Living:FindFirstChild(targetName)
    if not target then
        print("[CombatFarm] Target not found: " .. targetName)
        return false
    end

    local hrp = _movement:GetCharacter("HumanoidRootPart")
    local remoteFunc = _movement:GetCharacter("RemoteFunction")
    if not hrp or not remoteFunc then
        return false
    end

    local oldCameraSubject = workspace.CurrentCamera and workspace.CurrentCamera.CameraSubject
    local oldPos = hrp.CFrame

    local hasStand = _inventory:HasStand()
    local standPart = nil
    if hasStand then
        equipStand()
        local standMorph = _movement:GetCharacter("StandMorph")
        if standMorph and standMorph.PrimaryPart then
            standPart = standMorph.PrimaryPart
        end
    end

    -- Focus camera on target (Xenon style)
    local focusCam = _movement:GetCharacter("FocusCam")
    if not focusCam then
        focusCam = Instance.new("ObjectValue")
        focusCam.Name = "FocusCam"
        focusCam.Parent = _movement:GetCharacter()
    end
    focusCam.Value = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart

    -- Set player underground position (once)
    local yOffset = -35
    if targetName == "The Idol" then yOffset = 35 end
    local playerUndergroundCF = CFrame.new(hrp.Position.X, hrp.Position.Y + yOffset, hrp.Position.Z)
    hrp.CFrame = playerUndergroundCF

    local startTime = tick()
    local killed = false

    while not stopRequested and tick() - startTime < 60 do
        target = workspace.Living:FindFirstChild(targetName)
        if not target then
            killed = true
            break
        end
        local targetHRP = target:FindFirstChild("HumanoidRootPart")
        local targetHum = target:FindFirstChildWhichIsA("Humanoid")
        if not targetHRP or not targetHum or targetHum.Health <= 0 then
            killed = true
            break
        end

        -- Move stand behind NPC (using task.spawn to avoid delays)
        if standPart and standPart.Parent then
            task.spawn(function()
                standPart.CFrame = targetHRP.CFrame - targetHRP.CFrame.LookVector * 1.1
            end)
        end

        -- Attack (async)
        task.spawn(function()
            useMove("m1")
        end)

        -- Auto skills (async)
        local skills = _config:Get("AutoSkills")
        if type(skills) == "table" then
            for _, sk in ipairs(skills) do
                local keyCode = Enum.KeyCode[sk]
                if keyCode then
                    task.spawn(function()
                        useMove(keyCode)
                    end)
                end
            end
        end

        task.wait(0.2)  -- Xenon V5 loop delay
    end

    -- Cleanup
    if focusCam then focusCam:Destroy() end
    if hrp then
        hrp.CFrame = oldPos
    end
    if oldCameraSubject then
        pcall(function() workspace.CurrentCamera.CameraSubject = oldCameraSubject end)
    end

    return killed
end

-- =====================
-- NPC farming
-- =====================
local function runNPCFarm()
    local npcName = _config:Get("SelectedNPC")
    if not npcName or npcName == "" then
        print("[CombatFarm] No NPC selected for NPC farm.")
        return false
    end
    return killTarget(npcName, true, false)
end

-- =====================
-- Quest farming
-- =====================
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

local function acceptQuest(questName)
    if questOnCooldown and tick() < cooldownUntil then
        local remaining = math.ceil(cooldownUntil - tick())
        print("[CombatFarm] Quest on cooldown, waiting " .. remaining .. " seconds.")
        return false
    end
    questOnCooldown = false

    local dialogueNPC = workspace.Dialogues:FindFirstChild(questName)
    if not dialogueNPC then
        print("[CombatFarm] Dialogue NPC not found: " .. questName)
        return false
    end
    local dialogueValue = dialogueNPC:FindFirstChild("Dialogue")
    if not dialogueValue then
        print("[CombatFarm] No Dialogue value for " .. questName)
        return false
    end
    local remoteEvent = _movement:GetCharacter("RemoteEvent")
    if not remoteEvent then
        return false
    end
    local npcDialogue = dialogueValue.Value
    print("[CombatFarm] Accepting quest from " .. npcDialogue)

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

    task.wait(1)
    local progress = Player.PlayerStats.QuestProgress.Value
    local maxProgress = Player.PlayerStats.QuestMaxProgress.Value
    if progress == 0 and maxProgress == 0 then
        print("[CombatFarm] Quest acceptance failed - possibly on cooldown. Waiting 60 seconds.")
        questOnCooldown = true
        cooldownUntil = tick() + 60
        return false
    end

    questCompleted = false
    return true
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
                movement:Teleport(itemModel.PrimaryPart.CFrame - Vector3.new(0, 10, 0))
                task.wait(0.3)
                local prompt = itemModel:FindFirstChildWhichIsA("ProximityPrompt")
                if prompt then fireproximityprompt(prompt) end
                task.wait(0.6)
                movement:Teleport(oldCF)
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

    print("[CombatFarm] Accepting quest: " .. currentQuest)
    local accepted = acceptQuest(currentQuest)
    if not accepted then
        return false
    end
    task.wait(2)

    if questCompleted then
        print("[CombatFarm] Quest already completed.")
        return true
    end

    local data = questInfo[currentQuest]
    if data.enemy then
        print("[CombatFarm] Killing " .. data.enemy)
        local ok = killTarget(data.enemy, true, true)
        if ok then
            local timeout = tick()
            while not questCompleted and tick() - timeout < 15 do
                task.wait(0.5)
            end
            return questCompleted
        end
        return false
    elseif data.item then
        print("[CombatFarm] Collecting " .. data.amount .. "x " .. data.item)
        return collectItem(data.item, data.amount)
    end
    return false
end

-- =====================
-- Player farming (future)
-- =====================
local function runPlayerFarm()
    -- TODO: implement player farming
    print("[CombatFarm] Player farming not yet implemented.")
    return false
end

-- =====================
-- Main loop
-- =====================
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
        elseif activeMode == "Player" then
            runPlayerFarm()
            task.wait(5)
        else
            break
        end
        task.wait(1)
    end
end

-- Public API
function CombatFarm:StartNPC()
    if isRunning then
        if activeMode == "NPC" then return end
        self:Stop()
    end
    activeMode = "NPC"
    stopRequested = false
    isRunning = true
    print("[CombatFarm] Starting NPC farming...")
    task.spawn(farmLoop)
end

function CombatFarm:StartQuest()
    if isRunning then
        if activeMode == "Quest" then return end
        self:Stop()
    end
    activeMode = "Quest"
    stopRequested = false
    isRunning = true
    questCompleted = false
    questOnCooldown = false
    print("[CombatFarm] Starting Quest farming...")
    task.spawn(farmLoop)
end

function CombatFarm:StartPlayer()
    if isRunning then
        if activeMode == "Player" then return end
        self:Stop()
    end
    activeMode = "Player"
    stopRequested = false
    isRunning = true
    print("[CombatFarm] Starting Player farming (coming soon)...")
    task.spawn(farmLoop)
end

function CombatFarm:Stop()
    stopRequested = true
    isRunning = false
    activeMode = nil
    print("[CombatFarm] Stopped.")
end

return CombatFarm
