-- =====================
-- CombatFarm.lua
-- Unified combat: NPC and Quest farming.
-- Logic identical to Xenon V5 (stand positioning, attacks, death detection).
-- FIXED: player positioned underground (yOffset -35) with noclip for safety.
-- =====================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
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
local runId = 0
local questWatcherConnection = nil
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

local _runtimeLog = nil
local _rawPrint, _rawWarn = print, warn
local function moduleLog(level, ...)
    if _runtimeLog and type(_runtimeLog.Write) == "function" then
        pcall(_runtimeLog.Write, _runtimeLog, level, "CombatFarm", ...)
    end
    if level == "WARN" or level == "ERROR" then
        _rawWarn(...)
    else
        _rawPrint(...)
    end
end

function CombatFarm:Init(Modules)
    _runtimeLog = Modules.RuntimeLog
    _config    = Modules.Config
    _inventory = Modules.Inventory
    _movement  = Modules.Movement
    _serverHop = Modules.ServerHop
    _webhook   = Modules.Webhook

    if questWatcherConnection then
        pcall(function() questWatcherConnection:Disconnect() end)
        questWatcherConnection = nil
    end

    -- Event-driven quest completion watcher instead of a permanent 0.5s polling loop.
    local function hookHUD()
        local hud = Player.PlayerGui:FindFirstChild("HUD")
        if not hud then return end
        local completedFrame = hud:FindFirstChild("QuestCompleted")
        if completedFrame and completedFrame:IsA("GuiObject") then
            questWatcherConnection = completedFrame:GetPropertyChangedSignal("Visible"):Connect(function()
                if completedFrame.Visible then
                    questCompleted = true
                    moduleLog("INFO", "[CombatFarm] Quest completed.")
                end
            end)
            if completedFrame.Visible then questCompleted = true end
        end
    end

    hookHUD()
    if not questWatcherConnection then
        task.spawn(function()
            for _ = 1, 20 do
                task.wait(0.5)
                if questWatcherConnection then return end
                hookHUD()
            end
        end)
    end
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

local function isNPCAlive(npc)
    if not npc or not npc.Parent then return false end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    local hum = npc:FindFirstChildWhichIsA("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end
    local healthValue = npc:FindFirstChild("Health")
    if healthValue and tonumber(healthValue.Value) and tonumber(healthValue.Value) <= 0 then
        return false
    end
    return true
end

local function getClosestNPC(npcName)
    local closest = nil
    local closestDist = math.huge
    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if not hrp then return nil end

    for _, npc in pairs(workspace.Living:GetChildren()) do
        if npc.Name == npcName and isNPCAlive(npc) then
            local npcHRP = npc:FindFirstChild("HumanoidRootPart")
            local dist = (hrp.Position - npcHRP.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = npc
            end
        end
    end
    return closest
end

local function isTokenActive(token, expectedMode)
    if stopRequested or token ~= runId then return false end
    if expectedMode and activeMode ~= expectedMode then return false end

    -- Extra safety: even if a UI callback ever fails, the persisted toggle state
    -- can still stop an old worker on the next frame.
    if _config then
        if activeMode == "NPC" and _config:Get("NPCFarmEnabled") ~= true then
            return false
        end
        if activeMode == "Quest" and _config:Get("QuestFarmEnabled") ~= true then
            return false
        end
    end
    return true
end

local function waitToken(seconds, token, expectedMode)
    local deadline = tick() + seconds
    while tick() < deadline do
        if not isTokenActive(token, expectedMode) then return false end
        task.wait(math.min(0.05, math.max(0, deadline - tick())))
    end
    return true
end

-- =============================================
-- COMBAT CORE (Xenon V5 style)
-- =============================================
local function killTarget(targetName, token)
    local target = getClosestNPC(targetName)
    if not target then
        moduleLog("INFO", "[CombatFarm] No alive target found: " .. targetName)
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
    local standAlignPos, standAlignOri = nil, nil
    local standAlignPosEnabled, standAlignOriEnabled = nil, nil
    local standCanCollide, standMassless = nil, nil
    local hasStand = _inventory:HasStand()
    if hasStand then
        equipStand()
        local standMorph = _movement:GetCharacter("StandMorph")
        if standMorph and standMorph.PrimaryPart then
            standPart = standMorph.PrimaryPart
            standCanCollide = standPart.CanCollide
            standMassless = standPart.Massless

            -- Collision was one of the main causes of Stand fling when its CFrame
            -- was forced into an NPC. Keep the Stand non-collidable and massless
            -- only while CombatFarm owns it.
            standPart.CanCollide = false
            standPart.Massless = true

            local standAttach = standPart:FindFirstChild("StandAttach")
            if standAttach then
                local alignPos = standAttach:FindFirstChild("AlignPosition")
                local alignOri = standAttach:FindFirstChild("AlignOrientation")
                standAlignPos, standAlignOri = alignPos, alignOri
                if alignPos then
                    standAlignPosEnabled = alignPos.Enabled
                    alignPos.Enabled = false
                end
                if alignOri then
                    standAlignOriEnabled = alignOri.Enabled
                    alignOri.Enabled = false
                end
            end
        end
    end

    -- YBA reads FocusCam internally. Roblox's own camera is pointed at a smooth,
    -- invisible anchor following the Stand so physics corrections do not shake
    -- the player's view every frame.
    local character = _movement:GetCharacter()
    local focusCam = character and character:FindFirstChild("FocusCam")
    local createdFocusCam = false
    local previousFocusValue = focusCam and focusCam.Value or nil
    if not focusCam and character then
        focusCam = Instance.new("ObjectValue")
        focusCam.Name = "FocusCam"
        focusCam.Parent = character
        createdFocusCam = true
    end

    local cameraAnchor = nil
    if camera then
        cameraAnchor = Instance.new("Part")
        cameraAnchor.Name = "WhiteHubCombatCamera"
        cameraAnchor.Size = Vector3.new(1, 1, 1)
        cameraAnchor.Transparency = 1
        cameraAnchor.Anchored = true
        cameraAnchor.CanCollide = false
        cameraAnchor.CanTouch = false
        cameraAnchor.CanQuery = false
        cameraAnchor.CFrame = (standPart and standPart.CFrame) or hrp.CFrame
        cameraAnchor.Parent = workspace
        pcall(function()
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = cameraAnchor
        end)
    end

    if focusCam then
        focusCam.Value = standPart or target:FindFirstChild("HumanoidRootPart")
    end

    _movement:SetNoclip(true)
    local combatFreeze = _movement:Freeze()

    local yOffset = -35
    if targetName == "The Idol" then yOffset = 35 end

    local startTime = tick()
    local killed = false
    local fixedPlayerDistance = -2.5

    while isTokenActive(token) and tick() - startTime < 60 do
        -- This invocation owns one concrete NPC. Once it dies we return so the
        -- outer loop can immediately choose another alive spawn with the same name.
        if not isNPCAlive(target) then
            killed = true
            break
        end

        local enemyHRP = target:FindFirstChild("HumanoidRootPart")
        if not enemyHRP then break end

        if standPart and standPart.Parent then
            local standCF = enemyHRP.CFrame - enemyHRP.CFrame.LookVector * 1.1
            standPart.CFrame = standCF
            hrp.CFrame = standCF + standCF.LookVector * fixedPlayerDistance + Vector3.new(0, yOffset, 0)

            pcall(function()
                standPart.AssemblyLinearVelocity = Vector3.zero
                standPart.AssemblyAngularVelocity = Vector3.zero
            end)

            if focusCam and focusCam.Parent then
                focusCam.Value = standPart
            end

            if cameraAnchor and cameraAnchor.Parent then
                -- Smooth camera tracking without lagging far behind the combat.
                cameraAnchor.CFrame = cameraAnchor.CFrame:Lerp(standPart.CFrame, 0.45)
            end
        else
            local playerCF = enemyHRP.CFrame - enemyHRP.CFrame.LookVector * 2.3 + Vector3.new(0, yOffset, 0)
            hrp.CFrame = playerCF
            if focusCam and focusCam.Parent then focusCam.Value = enemyHRP end
            if cameraAnchor and cameraAnchor.Parent then
                cameraAnchor.CFrame = cameraAnchor.CFrame:Lerp(enemyHRP.CFrame, 0.45)
            end
        end

        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)

        if not combatFreeze or not combatFreeze.Parent then
            combatFreeze = _movement:Freeze()
        end

        pcall(function()
            remoteFunc:InvokeServer("Attack", "m1")
        end)

        local skills = _config:Get("AutoSkills")
        if type(skills) == "table" then
            for _, sk in ipairs(skills) do
                if not isTokenActive(token) then break end
                local keyCode = Enum.KeyCode[sk]
                if keyCode then
                    pcall(function() useMove(keyCode) end)
                end
            end
        end

        task.wait()
    end

    _movement:Unfreeze(combatFreeze)

    if cameraAnchor and cameraAnchor.Parent then
        cameraAnchor:Destroy()
    end

    if focusCam and focusCam.Parent then
        pcall(function()
            if createdFocusCam then
                focusCam:Destroy()
            else
                focusCam.Value = previousFocusValue
            end
        end)
    end

    if standAlignPos and standAlignPos.Parent and standAlignPosEnabled ~= nil then
        pcall(function() standAlignPos.Enabled = standAlignPosEnabled end)
    end
    if standAlignOri and standAlignOri.Parent and standAlignOriEnabled ~= nil then
        pcall(function() standAlignOri.Enabled = standAlignOriEnabled end)
    end
    if standPart and standPart.Parent then
        pcall(function()
            if standCanCollide ~= nil then standPart.CanCollide = standCanCollide end
            if standMassless ~= nil then standPart.Massless = standMassless end
            standPart.AssemblyLinearVelocity = Vector3.zero
            standPart.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    -- Only the currently owning worker restores global movement/camera state.
    -- Stop() handles this itself when a worker is invalidated by toggling OFF.
    if token == runId then
        _movement:SetNoclip(false)
        if hrp and hrp.Parent then
            pcall(function() hrp.CFrame = oldPos end)
        end
        if camera and camera.Parent then
            pcall(function()
                if oldCameraSubject and oldCameraSubject.Parent then
                    camera.CameraSubject = oldCameraSubject
                else
                    local char = _movement:GetCharacter()
                    local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
                    if humanoid then camera.CameraSubject = humanoid end
                end
                if oldCameraType then camera.CameraType = oldCameraType end
            end)
        end
    end

    return killed
end

-- =============================================
-- NPC FARM
-- =============================================
local function runNPCFarm(token)
    local npcName = _config:Get("SelectedNPC")
    if not npcName or npcName == "" then
        moduleLog("INFO", "[CombatFarm] No NPC selected.")
        return false
    end
    return killTarget(npcName, token)
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

local function clickDialogueButton(btn)
    if not btn or not btn:IsA("GuiButton") then return false end

    if type(firesignal) == "function" then
        local ok = pcall(function()
            firesignal(btn.MouseButton1Click)
        end)
        if ok then return true end
    end

    local ok = pcall(function()
        local pos = btn.AbsolutePosition
        local size = btn.AbsoluteSize
        local x = pos.X + size.X * 0.5
        local y = pos.Y + size.Y * 0.5
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)
    return ok
end

local function findDialogueOption(optionName)
    local gui = Player.PlayerGui:FindFirstChild("DialogueGui")
    if not gui then return nil end
    local options = gui:FindFirstChild("Options", true)
    if not options then return nil end
    local option = options:FindFirstChild(optionName)
    if not option then return nil end
    return option:FindFirstChildWhichIsA("GuiButton", true)
end

local function findQuestPrompt(questName)
    local cleanName = tostring(questName):gsub("%s*%[Lvl%.%s*%d+%+%]%s*$", "")
    local roots = {
        workspace:FindFirstChild("Dialogues"),
        ReplicatedStorage:FindFirstChild("Dialogue"),
        ReplicatedStorage:FindFirstChild("NewDialogue"),
    }

    local best, bestScore = nil, -1
    for _, root in ipairs(roots) do
        if root then
            for _, obj in ipairs(root:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    local score = 0
                    local ancestry = obj:GetFullName():lower()
                    local q = questName:lower()
                    local c = cleanName:lower()
                    if ancestry:find(q, 1, true) then score = score + 100 end
                    if c ~= "" and ancestry:find(c, 1, true) then score = score + 60 end
                    local objectText = tostring(obj.ObjectText or ""):lower()
                    if objectText == q or objectText == c then score = score + 80 end
                    if c ~= "" and objectText:find(c, 1, true) then score = score + 40 end
                    if score > bestScore then
                        best, bestScore = obj, score
                    end
                end
            end
        end
    end
    return bestScore > 0 and best or nil
end

local function acceptQuest(questName, token)
    if questOnCooldown and tick() < cooldownUntil then
        local remaining = math.ceil(cooldownUntil - tick())
        moduleLog("INFO", "[CombatFarm] Quest on cooldown, waiting " .. remaining .. " seconds.")
        return false
    end
    questOnCooldown = false

    local beforeProgress, beforeMax = readQuestState()
    if (beforeMax or 0) > 0 then
        -- A quest is already active. Do not reopen the NPC dialogue.
        questCompleted = (beforeProgress or 0) >= (beforeMax or 0) and (beforeMax or 0) > 0
        return true
    end

    local prompt = findQuestPrompt(questName)
    if not prompt then
        moduleLog("WARN", "[CombatFarm] New quest ProximityPrompt not found: " .. questName)
        return false
    end

    moduleLog("INFO", "[CombatFarm] Opening updated quest dialogue: " .. questName)
    local opened = pcall(function() fireproximityprompt(prompt) end)
    if not opened then
        moduleLog("WARN", "[CombatFarm] Could not trigger quest prompt: " .. questName)
        return false
    end

    -- v1.7974+ quest dialogues are client UI driven. Historically quest choices
    -- are affirmative Option1, so advance only Option1 and stop the instant the
    -- PlayerStats quest state changes.
    local deadline = tick() + 8
    local nextClickAt = 0
    while tick() < deadline and isTokenActive(token, "Quest") do
        local progress, maxProgress = readQuestState()
        if (maxProgress or 0) > 0 or progress ~= beforeProgress or maxProgress ~= beforeMax then
            questCompleted = false
            moduleLog("INFO", "[CombatFarm] Quest accepted through updated dialogue: " .. questName)
            return true
        end

        local btn = findDialogueOption("Option1")
        if btn and btn.Visible and tick() >= nextClickAt then
            nextClickAt = tick() + 0.15
            clickDialogueButton(btn)
            task.wait(0.08)
        else
            task.wait(0.05)
            if not Player.PlayerGui:FindFirstChild("DialogueGui") and tick() + 0.5 < deadline then
                -- If the UI closed before quest state changed, do not keep blindly
                -- clicking anything else; this is usually cooldown/requirements.
                break
            end
        end
    end

    local progress, maxProgress = readQuestState()
    if (maxProgress or 0) > 0 or progress ~= beforeProgress or maxProgress ~= beforeMax then
        questCompleted = false
        moduleLog("INFO", "[CombatFarm] Quest accepted: " .. questName)
        return true
    end

    moduleLog("INFO", "[CombatFarm] Quest acceptance failed/cooldown with new dialogue.")
    questOnCooldown = true
    cooldownUntil = tick() + 60
    return false
end

local function collectItem(itemName, requiredAmount, token)
    local inventory = _inventory
    local movement  = _movement
    local startTime = tick()
    while isTokenActive(token, "Quest") and inventory:Count(itemName) < requiredAmount and (tick() - startTime) < 120 do
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

local function runQuestFarm(token)
    local autoChoose = _config:Get("AutoChooseQuest")
    if autoChoose then
        currentQuest = getBestQuest()
    else
        currentQuest = _config:Get("SelectedQuest")
    end
    if not currentQuest or currentQuest == "" then
        moduleLog("INFO", "[CombatFarm] No quest selected or found.")
        return false
    end

    if not acceptQuest(currentQuest, token) then
        return false
    end
    if not waitToken(0.35, token, "Quest") then return false end

    if questCompleted then
        moduleLog("INFO", "[CombatFarm] Quest already completed.")
        return true
    end

    local data = questInfo[currentQuest]
    if not data then
        moduleLog("WARN", "[CombatFarm] Unknown quest configuration: " .. tostring(currentQuest))
        return false
    end
    if data.enemy then
        -- Keep killing fresh alive spawns until the active quest reports complete.
        while isTokenActive(token, "Quest") do
            local progress, maxProgress = readQuestState()
            if questCompleted or ((maxProgress or 0) > 0 and (progress or 0) >= (maxProgress or 0)) then
                questCompleted = true
                return true
            end

            local ok = killTarget(data.enemy, token)
            if not isTokenActive(token, "Quest") then return false end
            if ok then
                if not waitToken(0.15, token, "Quest") then return false end
            else
                if not waitToken(0.75, token, "Quest") then return false end
            end
        end
        return false
    elseif data.item then
        return collectItem(data.item, data.amount, token)
    end
    return false
end

-- =============================================
-- MAIN LOOP
-- =============================================
local function waitCancelable(seconds, token)
    local deadline = tick() + seconds
    while tick() < deadline do
        if not isTokenActive(token) then return false end
        task.wait(math.min(0.10, math.max(0, deadline - tick())))
    end
    return true
end

local function farmLoop(token)
    while isTokenActive(token) do
        if activeMode == "NPC" then
            local ok = runNPCFarm(token)
            if token ~= runId or stopRequested then break end
            if ok then
                moduleLog("INFO", "[CombatFarm] NPC killed. Looking for another alive spawn...")
                if not waitCancelable(0.15, token) then break end
            else
                moduleLog("INFO", "[CombatFarm] No alive NPC found. Retrying shortly...")
                if not waitCancelable(0.75, token) then break end
            end

        elseif activeMode == "Quest" then
            local ok = runQuestFarm(token)
            if token ~= runId or stopRequested then break end

            if ok then
                moduleLog("INFO", "[CombatFarm] Quest completed! Moving to next.")
                if not waitCancelable(3, token) then break end
                questCompleted = false
                questOnCooldown = false
            else
                if questOnCooldown then
                    local remaining = math.max(1, math.ceil(cooldownUntil - tick()))
                    moduleLog("INFO", "[CombatFarm] Quest on cooldown, waiting " .. remaining .. " seconds...")
                    if not waitCancelable(remaining, token) then break end
                else
                    moduleLog("INFO", "[CombatFarm] Quest failed. Retrying in 5 seconds...")
                    if not waitCancelable(5, token) then break end
                end
            end
        else
            break
        end

        if not waitCancelable(0.25, token) then break end
    end

    if token == runId then
        isRunning = false
        activeMode = nil
    end
end

-- =============================================
-- PUBLIC API
-- =============================================
local function startMode(mode)
    if isRunning and activeMode == mode then return end

    -- Invalidate any previous worker before starting a new one.
    runId = runId + 1
    stopRequested = false
    activeMode = mode
    isRunning = true

    local token = runId
    if mode == "Quest" then
        questCompleted = false
        questOnCooldown = false
    end

    moduleLog("INFO", "[CombatFarm] Starting " .. mode .. " farming (single-worker mode).")
    task.spawn(function()
        farmLoop(token)
    end)
end

function CombatFarm:StartNPC()
    startMode("NPC")
end

function CombatFarm:StartQuest()
    startMode("Quest")
end

function CombatFarm:Stop()
    runId = runId + 1
    stopRequested = true
    isRunning = false
    activeMode = nil
    questCompleted = false
    _movement:SetNoclip(false)
    _movement:ClearFocus()
    _movement:FixCamera()
    moduleLog("INFO", "[CombatFarm] Stopped immediately and cleaned combat state.")
end

function CombatFarm:IsRunning()
    return isRunning, activeMode
end

function CombatFarm:Destroy()
    self:Stop()
    if questWatcherConnection then
        pcall(function() questWatcherConnection:Disconnect() end)
        questWatcherConnection = nil
    end
end

return CombatFarm
