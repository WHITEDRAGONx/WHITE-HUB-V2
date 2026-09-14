-- =====================
-- CombatFarm.lua
-- Unified combat: NPC and Quest farming.
-- QUEST/COMBAT BUILD: INTERNAL-OPTION-R3-XENON-LOCK
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
    ["Officer Sam [Lvl. 1+]"] = { enemy = "Thug", autoChoose = true },
    ["Deputy Bertrude [Lvl. 10+]"] = { enemy = "Corrupt Police", autoChoose = true },

    -- The current game uses this no-dot level format. DialogueAnalyzer confirmed
    -- its updated quest dialogue is Option1 -> Option1 -> Option1.
    ["Abbacchio's Partner [Lvl 15+]"] = { enemy = "Alpha Thug", autoChoose = true },
    -- Alias retained in case YBA changes only the display punctuation.
    ["Abbacchio's Partner [Lvl. 15+]"] = { enemy = "Alpha Thug", autoChoose = true },

    -- Fetch/daily quest: selectable manually, but intentionally skipped by Auto Choose.
    ["Homeless Man Jill [Lvl. 15+]"] = { item = "Gold Coin", amount = 10, autoChoose = false },

    ["Dracula [Lvl. 20+]"] = { enemy = "Zombie Henchman", autoChoose = true },
    ["William Zeppeli [Lvl. 25+]"] = { enemy = "Vampire", autoChoose = true },
    ["Doppio [Lvl. 30+]"] = { enemy = "Dio", autoChoose = true },
    ["Dio [Lvl. 35+]"] = { enemy = "Jotaro", autoChoose = true },

    -- Detected level quests which need their own objective/controller mapping.
    ["Darius, The Executioner [Lvl. 20+]"] = { special = "PVP_STAND", autoChoose = false },
    ["Kars [Lvl. 30+]"] = { special = "PVP_HAMON", autoChoose = false },
    ["Pucci [Lvl. 40+]"] = { special = "PUCCI_CHAIN", autoChoose = false },
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

local function getNPCHealthState(npc)
    if not npc or not npc.Parent then
        return nil, "despawned"
    end

    -- YBA NPCs expose their authoritative combat health through a custom Health
    -- Value. Xenon V5 relied on this value instead of Humanoid.Health. The
    -- Humanoid may enter a death/ragdoll state before YBA has actually credited
    -- the kill, so prefer Health.Value whenever it exists.
    local healthValue = npc:FindFirstChild("Health")
    if healthValue then
        local hp = tonumber(healthValue.Value)
        if hp ~= nil then
            return hp, "HealthValue"
        end
    end

    local hum = npc:FindFirstChildWhichIsA("Humanoid")
    if hum then
        return tonumber(hum.Health), "Humanoid"
    end

    return nil, "unknown"
end

local function isNPCAlive(npc)
    if not npc or not npc.Parent then return false end
    local hp = getNPCHealthState(npc)
    if hp ~= nil then
        return hp > 0
    end
    return npc:FindFirstChild("HumanoidRootPart") ~= nil
end

local function getClosestNPC(npcName, excludeTarget)
    local closest = nil
    local closestDist = math.huge
    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if not hrp then return nil end

    for _, npc in pairs(workspace.Living:GetChildren()) do
        if npc ~= excludeTarget and npc.Name == npcName and isNPCAlive(npc) then
            local npcHRP = npc:FindFirstChild("HumanoidRootPart")
            if npcHRP then
                local dist = (hrp.Position - npcHRP.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closest = npc
                end
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

-- Forward declaration: killTarget waits for QuestProgress credit before the
-- concrete readQuestState implementation later in this module.
local readQuestState

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
    -- Lock one concrete NPC exactly like Xenon V5. Do not re-select by name until
    -- this model has actually died/despawned.
    local target = getClosestNPC(targetName)
    if not target then
        moduleLog("INFO", "[CombatFarm] No alive target found: " .. targetName)
        return false
    end

    local character = _movement:GetCharacter()
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local remoteFunc = character and character:FindFirstChild("RemoteFunction")
    if not character or not hrp or not remoteFunc then
        return false
    end

    local oldPos = hrp.CFrame
    local camera = workspace.CurrentCamera
    local oldCameraSubject = camera and camera.CameraSubject
    local oldCameraType = camera and camera.CameraType

    local questProgressBefore, questMaxBefore = nil, nil
    if activeMode == "Quest" then
        questProgressBefore, questMaxBefore = readQuestState()
    end

    local hasStand = _inventory:HasStand()
    if hasStand then
        equipStand()
    end

    -- Xenon keeps the Stand's native constraints/collision intact and simply
    -- drags its PrimaryPart behind the locked NPC every frame.
    local standMorph = hasStand and character:FindFirstChild("StandMorph") or nil
    local standPart = standMorph and standMorph.PrimaryPart or nil

    local focusCam = character:FindFirstChild("FocusCam")
    local createdFocusCam = false
    local previousFocusValue = focusCam and focusCam.Value or nil
    if not focusCam then
        focusCam = Instance.new("ObjectValue")
        focusCam.Name = "FocusCam"
        focusCam.Parent = character
        createdFocusCam = true
    end

    _movement:SetNoclip(true)

    local yOffset = -35
    if targetName == "The Idol" then yOffset = 35 end

    local startTime = tick()
    local killed = false
    local lastKnownHp, hpSource = getNPCHealthState(target)
    local missingPartsSince = nil
    local attackBusy = false

    moduleLog("INFO", ("[CombatFarm][XenonLock] Locked %s | hp=%s source=%s"):format(
        tostring(targetName), tostring(lastKnownHp), tostring(hpSource)
    ))

    while isTokenActive(token) and tick() - startTime < 60 do
        if not target or not target.Parent then
            -- A locked NPC disappearing from workspace.Living after being alive is
            -- treated as a real death/despawn, never as a reason to switch early.
            killed = true
            break
        end

        local hp, source = getNPCHealthState(target)
        if hp ~= nil then
            lastKnownHp = hp
            hpSource = source
            if hp <= 0 then
                -- Match Xenon's small post-zero settle before releasing the target.
                task.wait(0.215)
                killed = true
                break
            end
        end

        local enemyHRP = target:FindFirstChild("HumanoidRootPart")
        local enemyHumanoid = target:FindFirstChildWhichIsA("Humanoid")

        if not enemyHRP or not enemyHumanoid then
            -- Do not abandon a still-alive YBA NPC because ragdoll/death code
            -- temporarily replaced a part. Give the locked target a grace window.
            if not missingPartsSince then missingPartsSince = tick() end
            if tick() - missingPartsSince > 1.0 then
                local currentHp = getNPCHealthState(target)
                if currentHp ~= nil and currentHp <= 0 then
                    killed = true
                    break
                elseif not target.Parent then
                    killed = true
                    break
                end
                -- Still alive: keep the same target and keep waiting for parts.
                missingPartsSince = tick()
            end
            task.wait(0.03)
            continue
        end
        missingPartsSince = nil

        -- Xenon camera behavior: FocusCam stays on the enemy HRP rather than the
        -- Stand. This avoids camera subject changes while the Stand is force-moved.
        if focusCam and focusCam.Parent then
            focusCam.Value = enemyHRP
        end

        -- Refresh StandMorph because YBA may recreate it after summon/animation.
        if hasStand and (not standPart or not standPart.Parent) then
            standMorph = character:FindFirstChild("StandMorph")
            standPart = standMorph and standMorph.PrimaryPart or nil
        end

        if standPart and standPart.Parent then
            local standCF = enemyHRP.CFrame - enemyHRP.CFrame.LookVector * 1.1
            standPart.CFrame = standCF
            -- Same spatial model as Xenon: player follows the Stand but remains
            -- vertically separated from combat to avoid knockback/void issues.
            hrp.CFrame = standCF + standCF.LookVector * -2.5 + Vector3.new(0, yOffset, 0)
        else
            hrp.CFrame = enemyHRP.CFrame - enemyHRP.CFrame.LookVector * 2.3 + Vector3.new(0, yOffset, 0)
        end

        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)

        -- Xenon attacks asynchronously so InvokeServer cannot stall the positioning
        -- loop and let the Stand fall away from the target.
        if not attackBusy then
            attackBusy = true
            task.spawn(function()
                pcall(function() remoteFunc:InvokeServer("Attack", "m1") end)
                attackBusy = false
            end)
        end

        local skills = _config:Get("AutoSkills")
        if type(skills) == "table" and #skills > 0 then
            task.spawn(function()
                for _, sk in ipairs(skills) do
                    if not isTokenActive(token) then break end
                    local keyCode = Enum.KeyCode[sk]
                    if keyCode then
                        pcall(function() useMove(keyCode) end)
                    end
                end
            end)
        end

        task.wait()
    end

    if killed and activeMode == "Quest" and isTokenActive(token, "Quest") then
        -- Do not select the next same-name spawn until YBA has had a chance to
        -- credit the kill. This directly addresses kills visually ending but not
        -- incrementing QuestProgress.
        local settleDeadline = tick() + 1.25
        while tick() < settleDeadline and isTokenActive(token, "Quest") do
            local progress, maxProgress = readQuestState()
            if questCompleted
                or progress ~= questProgressBefore
                or maxProgress ~= questMaxBefore
                or ((maxProgress or 0) > 0 and (progress or 0) >= (maxProgress or 0)) then
                moduleLog("INFO", ("[CombatFarm][XenonLock] Kill credited | progress=%s/%s"):format(
                    tostring(progress), tostring(maxProgress)
                ))
                break
            end
            task.wait(0.05)
        end
    elseif killed then
        task.wait(0.25)
    end

    -- Chain targeting: on a successful kill, hand camera/position directly to
    -- the next same-name NPC instead of bouncing back to the safe spot between
    -- kills. This removes the camera reset + teleport round-trip delay.
    local chainedToNext = false
    local questFinishedNow = false
    if killed and activeMode == "Quest" then
        local progress, maxProgress = readQuestState()
        questFinishedNow = questCompleted
            or ((maxProgress or 0) > 0 and (progress or 0) >= (maxProgress or 0))
    end

    if killed and token == runId and isTokenActive(token) and not questFinishedNow then
        local nextTarget = getClosestNPC(targetName, target)
        local nextHRP = nextTarget and nextTarget:FindFirstChild("HumanoidRootPart")
        if nextTarget and nextHRP and hrp and hrp.Parent then
            if focusCam and focusCam.Parent then
                focusCam.Value = nextHRP
            end

            if hasStand and (not standPart or not standPart.Parent) then
                standMorph = character:FindFirstChild("StandMorph")
                standPart = standMorph and standMorph.PrimaryPart or nil
            end

            if standPart and standPart.Parent then
                local nextStandCF = nextHRP.CFrame - nextHRP.CFrame.LookVector * 1.1
                standPart.CFrame = nextStandCF
                hrp.CFrame = nextStandCF + nextStandCF.LookVector * -2.5 + Vector3.new(0, yOffset, 0)
            else
                hrp.CFrame = nextHRP.CFrame - nextHRP.CFrame.LookVector * 2.3 + Vector3.new(0, yOffset, 0)
            end

            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)

            chainedToNext = true
            moduleLog("INFO", ("[CombatFarm][XenonChain] Handoff %s -> next spawn (no safe-spot/camera reset)"):format(tostring(targetName)))
        end
    end

    if not chainedToNext then
        if focusCam and focusCam.Parent then
            pcall(function()
                if createdFocusCam then
                    focusCam:Destroy()
                else
                    focusCam.Value = previousFocusValue
                end
            end)
        end

        if token == runId then
            _movement:SetNoclip(false)
            -- Do NOT return to oldPos after every successful kill. Staying at the
            -- combat location avoids the safe-spot round trip; Stop() still performs
            -- full cleanup when farming is disabled.
            if not killed and hrp and hrp.Parent then
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
    end

    if killed then
        moduleLog("INFO", ("[CombatFarm][XenonLock] Confirmed death: %s | lastHp=%s source=%s"):format(
            tostring(targetName), tostring(lastKnownHp), tostring(hpSource)
        ))
    else
        moduleLog("WARN", ("[CombatFarm][XenonLock] Target lock ended without confirmed death: %s | lastHp=%s source=%s"):format(
            tostring(targetName), tostring(lastKnownHp), tostring(hpSource)
        ))
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
local function questLevelFromName(name)
    local n = tostring(name or "")
    return tonumber(n:match("%[Lvl%.?%s*(%d+)%+%]"))
        or tonumber(n:match("[Ll]vl%.?%s*(%d+)%+"))
end

local function getBestQuest()
    local level = Player.PlayerStats.Level.Value
    local best = nil
    local bestReq = -1

    for questName, data in pairs(questInfo) do
        if data.autoChoose == true then
            local req = questLevelFromName(questName)
            if req and req <= level and req > bestReq then
                bestReq = req
                best = questName
            elseif req and req <= level and req == bestReq and best then
                -- Prefer a quest whose exact dialogue object exists in the current server.
                local dialogues = workspace:FindFirstChild("Dialogues")
                if dialogues and dialogues:FindFirstChild(questName) and not dialogues:FindFirstChild(best) then
                    best = questName
                end
            end
        end
    end
    return best
end

readQuestState = function()
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


-- New YBA dialogue callbacks (v1.7974+) store the selected option in callback U[1].
-- DialogueAnalyzer confirmed the quest NPC uses the same ClientFunctions callback shape
-- as Merchant: one MouseButton1Click callback, with U[2] pointing at the option ImageLabel.
local function injectDialogueOption(optionName)
    local btn = findDialogueOption(optionName)
    if not btn or not btn.Visible then return false, "not-ready" end

    local getCon = type(getconnections) == "function" and getconnections or nil
    local setUp = type(setupvalue) == "function" and setupvalue
        or (debug and type(debug.setupvalue) == "function" and debug.setupvalue)
    local getUp = type(getupvalue) == "function" and getupvalue
        or (debug and type(debug.getupvalue) == "function" and debug.getupvalue)

    if not getCon or not setUp then return false, "unsupported" end

    local okConnections, connections = pcall(getCon, btn.MouseButton1Click)
    if not okConnections or type(connections) ~= "table" then
        return false, "no-connections"
    end

    for _, connection in ipairs(connections) do
        local fn = connection and (connection.Function or connection["function"])
        if type(fn) == "function" then
            local structurallyValid = true
            if getUp then
                local okU2, u2 = pcall(getUp, fn, 2)
                -- On the mapped ClientFunctions:2063 callback U[2] is the option ImageLabel.
                -- If the executor exposes U[2], reject unrelated callbacks instead of writing U[1].
                if okU2 and u2 ~= nil then
                    structurallyValid = typeof(u2) == "Instance" and (u2 == btn.Parent or btn:IsDescendantOf(u2))
                end
            end

            if structurallyValid then
                local okSet = pcall(setUp, fn, 1, optionName)
                if okSet then
                    if getUp then
                        local okVerify, selected = pcall(getUp, fn, 1)
                        if okVerify and selected ~= nil and tostring(selected) ~= tostring(optionName) then
                            -- The callback shape changed; do not claim success.
                        else
                            return true, "internal"
                        end
                    else
                        return true, "internal"
                    end
                end
            end
        end
    end

    return false, "callback-mismatch"
end

local function dialogueStageSignature()
    local gui = Player.PlayerGui:FindFirstChild("DialogueGui")
    if not gui then return nil end
    local options = gui:FindFirstChild("Options", true)
    if not options then return nil end

    local parts = {}
    for i = 1, 8 do
        local option = options:FindFirstChild("Option" .. i)
        if option then
            local label = option:FindFirstChildWhichIsA("TextLabel", true)
            local button = option:FindFirstChildWhichIsA("TextButton", true)
            local text = (button and button.Text) or (label and label.Text) or ""
            parts[#parts + 1] = "Option" .. i .. "=" .. tostring(text)
        end
    end
    return #parts > 0 and table.concat(parts, " | ") or nil
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

    -- DialogueAnalyzer mapping (2026-09-14): this quest path uses the same
    -- ClientFunctions option callback as Merchant and accepts with:
    -- Option1 -> Option1 -> Option1. Prefer internal U[1] injection; retain the
    -- visible click path only as an executor-compatibility fallback.
    local deadline = tick() + 8
    local lastStageSignature = nil
    local lastAdvanceAt = 0
    local internalStages = 0
    local fallbackClicks = 0

    while tick() < deadline and isTokenActive(token, "Quest") do
        local progress, maxProgress = readQuestState()
        if (maxProgress or 0) > 0 or progress ~= beforeProgress or maxProgress ~= beforeMax then
            questCompleted = false
            moduleLog("INFO", ("[CombatFarm] Quest accepted through updated dialogue: %s | internalStages=%d fallbackClicks=%d")
                :format(questName, internalStages, fallbackClicks))
            return true
        end

        local btn = findDialogueOption("Option1")
        local signature = dialogueStageSignature()
        if btn and btn.Visible and signature then
            local isNewStage = signature ~= lastStageSignature
            local retryExpired = (tick() - lastAdvanceAt) >= 0.45
            if isNewStage or retryExpired then
                local injected = false
                local okInject, route = injectDialogueOption("Option1")
                if okInject then
                    injected = true
                    internalStages = internalStages + 1
                    lastStageSignature = signature
                    lastAdvanceAt = tick()
                    task.wait(0.04)
                end

                if not injected then
                    if clickDialogueButton(btn) then
                        fallbackClicks = fallbackClicks + 1
                        lastStageSignature = signature
                        lastAdvanceAt = tick()
                    end
                    task.wait(0.08)
                end
            else
                task.wait(0.03)
            end
        else
            task.wait(0.04)
            if not Player.PlayerGui:FindFirstChild("DialogueGui") and tick() + 0.5 < deadline then
                -- UI closed before PlayerStats changed: cooldown, requirement, or dialogue mismatch.
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

    moduleLog("INFO", "[CombatFarm] Quest acceptance failed/cooldown with new dialogue. Last stage: " .. tostring(dialogueStageSignature()))
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
        moduleLog("WARN", "[CombatFarm] Quest was detected by the UI but its objective is not mapped yet: " .. tostring(currentQuest) .. ". Run DialogueAnalyzer and send the quest log.")
        return false
    end
    if data.special then
        moduleLog("WARN", "[CombatFarm] Special quest is visible but not automated yet: " .. tostring(currentQuest) .. " (" .. tostring(data.special) .. "). It is excluded from Auto Choose.")
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
                if not waitToken(0.02, token, "Quest") then return false end
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
                if not waitCancelable(0.02, token) then break end
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
