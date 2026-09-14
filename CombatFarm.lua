-- =====================
-- CombatFarm.lua
-- WHITE HUB V3 - COMBAT ONLY R1
-- Based on the restored V3 stable release. This file is intentionally isolated:
-- it does NOT modify Inventory/Farm/Merchant selling logic.
-- =====================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local CombatFarm = {}

local _config = nil
local _inventory = nil
local _movement = nil
local _serverHop = nil
local _webhook = nil
local _runtimeLog = nil

local activeMode = nil
local isRunning = false
local stopRequested = false
local runId = 0

local questWatcherConnection = nil
local currentQuest = nil
local questCompleted = false
local modeReturnCF = nil
local lastNoTargetLogAt = 0
local lastStandToggleAt = 0
local pausedItemFarmWasEnabled = nil

-- Dio/Jotaro is intentionally excluded from Auto Choose for now. The user asked
-- to prioritize a stable Quest/NPC farm instead of special-casing that turn-in.
local questInfo = {
    ["Officer Sam [Lvl. 1+]"] = { enemy = "Thug", autoChoose = true },
    ["Deputy Bertrude [Lvl. 10+]"] = { enemy = "Corrupt Police", autoChoose = true },
    ["Homeless Man Jill [Lvl. 15+]"] = { item = "Gold Coin", amount = 10, autoChoose = false },
    ["Dracula [Lvl. 20+]"] = { enemy = "Zombie Henchman", autoChoose = true },
    ["William Zeppeli [Lvl. 25+]"] = { enemy = "Vampire", autoChoose = true },
    ["Doppio [Lvl. 30+]"] = { enemy = "Dio", autoChoose = true },
    ["Dio [Lvl. 35+]"] = { enemy = "Jotaro", autoChoose = false, experimental = true },
}

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
    _config = Modules.Config
    _inventory = Modules.Inventory
    _movement = Modules.Movement
    _serverHop = Modules.ServerHop
    _webhook = Modules.Webhook

    if questWatcherConnection then
        pcall(function() questWatcherConnection:Disconnect() end)
        questWatcherConnection = nil
    end

    local function hookHUD()
        local hud = Player.PlayerGui:FindFirstChild("HUD")
        if not hud then return end
        local completedFrame = hud:FindFirstChild("QuestCompleted")
        if completedFrame and completedFrame:IsA("GuiObject") then
            questWatcherConnection = completedFrame:GetPropertyChangedSignal("Visible"):Connect(function()
                if completedFrame.Visible then
                    questCompleted = true
                    moduleLog("INFO", "[CombatFarm] Quest completion HUD detected.")
                end
            end)
            if completedFrame.Visible then
                questCompleted = true
            end
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
-- GENERAL HELPERS
-- =============================================

local function isTokenActive(token, expectedMode)
    if stopRequested or token ~= runId then return false end
    if expectedMode and activeMode ~= expectedMode then return false end

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

local function useMove(move)
    local char = _movement:GetCharacter()
    if not char then return end

    if move == "m1" or move == "m2" then
        local rf = char:FindFirstChild("RemoteFunction")
        if rf then rf:InvokeServer("Attack", move) end
    elseif typeof(move) == "Enum" then
        local re = char:FindFirstChild("RemoteEvent")
        if re then re:FireServer("InputBegan", { Input = move }) end
    end
end

local function pauseItemFarmForCombat()
    if not _config or pausedItemFarmWasEnabled ~= nil then return end
    pausedItemFarmWasEnabled = _config:Get("FarmEnabled") == true
    if pausedItemFarmWasEnabled then
        -- Runtime-only pause. This does NOT save over the user's Farm setting and
        -- does not touch Inventory/SellAll. It only prevents the item farm from
        -- teleporting the player while CombatFarm owns movement.
        _config:Set("FarmEnabled", false, true)
        moduleLog("INFO", "[CombatFarm] Item Farm temporarily paused to avoid movement conflict.")
    end
end

local function restoreItemFarmAfterCombat()
    if pausedItemFarmWasEnabled == nil or not _config then return end
    if pausedItemFarmWasEnabled then
        _config:Set("FarmEnabled", true, true)
        moduleLog("INFO", "[CombatFarm] Item Farm resumed after combat.")
    end
    pausedItemFarmWasEnabled = nil
end

local function parkAtReturnPosition()
    if not _movement then return end

    _movement:SetNoclip(false)
    _movement:ClearFocus()

    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if hrp and modeReturnCF then
        pcall(function()
            hrp.CFrame = modeReturnCF
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    _movement:FixCamera()
end

local function getNPCHealthState(npc)
    if not npc or not npc.Parent then
        return nil, "despawned"
    end

    -- YBA's custom Health value is the authoritative source when available.
    local healthValue = npc:FindFirstChild("Health")
    if healthValue then
        local hp = tonumber(healthValue.Value)
        if hp ~= nil then return hp, "HealthValue" end
    end

    local hum = npc:FindFirstChildWhichIsA("Humanoid")
    if hum then return tonumber(hum.Health), "Humanoid" end
    return nil, "unknown"
end

local function isNPCAlive(npc)
    if not npc or not npc.Parent then return false end
    local hp = getNPCHealthState(npc)
    if hp ~= nil then return hp > 0 end
    return npc:FindFirstChild("HumanoidRootPart") ~= nil
end

local function getClosestNPC(npcName, excludeTarget)
    local living = workspace:FindFirstChild("Living")
    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if not living or not hrp then return nil end

    local closest, closestDist = nil, math.huge
    for _, npc in ipairs(living:GetChildren()) do
        if npc ~= excludeTarget and npc.Name == npcName and isNPCAlive(npc) then
            local npcHRP = npc:FindFirstChild("HumanoidRootPart")
            if npcHRP then
                local dist = (hrp.Position - npcHRP.Position).Magnitude
                if dist < closestDist then
                    closest, closestDist = npc, dist
                end
            end
        end
    end
    return closest
end

local function ensureStandSummoned(character)
    if not _inventory or not _inventory:HasStand() then return nil end
    character = character or _movement:GetCharacter()
    if not character then return nil end

    local summoned = character:FindFirstChild("SummonedStand")
    if summoned and summoned.Value == false and tick() - lastStandToggleAt >= 0.35 then
        local rf = character:FindFirstChild("RemoteFunction")
        if rf then
            lastStandToggleAt = tick()
            pcall(function() rf:InvokeServer("ToggleStand", "Toggle") end)
        end
    end

    local standMorph = character:FindFirstChild("StandMorph")
    if standMorph and standMorph.PrimaryPart then return standMorph.PrimaryPart end

    local deadline = tick() + 0.35
    while tick() < deadline do
        standMorph = character:FindFirstChild("StandMorph")
        if standMorph and standMorph.PrimaryPart then
            return standMorph.PrimaryPart
        end
        task.wait(0.02)
    end
    return nil
end

-- Forward declaration because combat waits for quest kill credit.
local readQuestState

-- =============================================
-- COMBAT CORE
-- =============================================

local function killTarget(targetName, token)
    local target = getClosestNPC(targetName)
    if not target then
        if tick() - lastNoTargetLogAt > 1.5 then
            lastNoTargetLogAt = tick()
            moduleLog("INFO", "[CombatFarm] No alive target found: " .. tostring(targetName))
        end
        parkAtReturnPosition()
        return false
    end

    local character = _movement:GetCharacter()
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local remoteFunc = character and character:FindFirstChild("RemoteFunction")
    if not character or not hrp or not remoteFunc then return false end

    local questProgressBefore, questMaxBefore = nil, nil
    if activeMode == "Quest" then
        questProgressBefore, questMaxBefore = readQuestState()
    end

    local hasStand = _inventory:HasStand()
    local standPart = hasStand and ensureStandSummoned(character) or nil

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

    local yOffset = targetName == "The Idol" and 35 or -35
    local startTime = tick()
    local killed = false
    local lastKnownHp, hpSource = getNPCHealthState(target)
    local missingPartsSince = nil
    local attackBusy = false
    local lastSkillAt = 0
    local skillIndex = 1

    moduleLog("INFO", ("[CombatFarm][Lock] %s | hp=%s source=%s stand=%s"):format(
        tostring(targetName), tostring(lastKnownHp), tostring(hpSource), tostring(_inventory:GetCurrentStand())
    ))

    while isTokenActive(token) and tick() - startTime < 60 do
        if not target or not target.Parent then
            killed = true
            break
        end

        local hp, source = getNPCHealthState(target)
        if hp ~= nil then
            lastKnownHp, hpSource = hp, source
            if hp <= 0 then
                task.wait(0.15)
                killed = true
                break
            end
        end

        local enemyHRP = target:FindFirstChild("HumanoidRootPart")
        if not enemyHRP then
            if not missingPartsSince then missingPartsSince = tick() end
            if tick() - missingPartsSince > 0.8 then
                local nowHp = getNPCHealthState(target)
                if nowHp ~= nil and nowHp <= 0 then
                    killed = true
                    break
                elseif not target.Parent then
                    killed = true
                    break
                end
                missingPartsSince = tick()
            end
            task.wait(0.03)
            continue
        end
        missingPartsSince = nil

        if focusCam and focusCam.Parent then
            focusCam.Value = enemyHRP
        end

        if hasStand then
            local summoned = character:FindFirstChild("SummonedStand")
            if (summoned and summoned.Value == false) or not standPart or not standPart.Parent then
                standPart = ensureStandSummoned(character)
            end

            if standPart and standPart.Parent then
                local standCF = enemyHRP.CFrame - enemyHRP.CFrame.LookVector * 1.1
                standPart.CFrame = standCF
                -- With a Stand equipped, the PLAYER always stays safely underneath.
                -- No "no damage => move player close" fallback exists in this build.
                hrp.CFrame = standCF + standCF.LookVector * -2.5 + Vector3.new(0, yOffset, 0)
                pcall(function()
                    standPart.AssemblyLinearVelocity = Vector3.zero
                    standPart.AssemblyAngularVelocity = Vector3.zero
                end)
            else
                -- Stand is still spawning: stay under the enemy instead of moving into melee.
                hrp.CFrame = enemyHRP.CFrame + Vector3.new(0, yOffset, 0)
            end
        else
            -- No Stand at all: the player must actually be in melee range for M1.
            hrp.CFrame = enemyHRP.CFrame - enemyHRP.CFrame.LookVector * 2.3
        end

        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)

        if not attackBusy then
            attackBusy = true
            task.spawn(function()
                pcall(function() remoteFunc:InvokeServer("Attack", "m1") end)
                attackBusy = false
            end)
        end

        -- Do not spam every configured skill every rendered frame. Use one skill
        -- at a time while M1 continues between skill windows.
        local skills = _config:Get("AutoSkills")
        if type(skills) == "table" and #skills > 0 and tick() - lastSkillAt >= 0.40 then
            local skillName = skills[skillIndex]
            skillIndex = skillIndex + 1
            if skillIndex > #skills then skillIndex = 1 end
            local keyCode = skillName and Enum.KeyCode[skillName]
            if keyCode then
                lastSkillAt = tick()
                task.spawn(function()
                    pcall(function() useMove(keyCode) end)
                end)
            end
        end

        task.wait(0.03)
    end

    if killed and activeMode == "Quest" and isTokenActive(token, "Quest") then
        local settleDeadline = tick() + 1.25
        while tick() < settleDeadline and isTokenActive(token, "Quest") do
            local progress, maxProgress = readQuestState()
            if questCompleted
                or progress ~= questProgressBefore
                or maxProgress ~= questMaxBefore
                or ((maxProgress or 0) > 0 and (progress or 0) >= (maxProgress or 0)) then
                moduleLog("INFO", ("[CombatFarm][Lock] Kill credited | progress=%s/%s"):format(
                    tostring(progress), tostring(maxProgress)
                ))
                break
            end
            task.wait(0.05)
        end
    elseif killed then
        task.wait(0.12)
    end

    local questFinishedNow = false
    if killed and activeMode == "Quest" then
        local progress, maxProgress = readQuestState()
        questFinishedNow = questCompleted
            or ((maxProgress or 0) > 0 and (progress or 0) >= (maxProgress or 0))
    end

    -- Seamless handoff to another alive NPC with the same name.
    local chained = false
    if killed and isTokenActive(token) and not questFinishedNow then
        local nextTarget = getClosestNPC(targetName, target)
        local nextHRP = nextTarget and nextTarget:FindFirstChild("HumanoidRootPart")
        if nextTarget and nextHRP and hrp and hrp.Parent then
            if focusCam and focusCam.Parent then focusCam.Value = nextHRP end
            if hasStand then
                standPart = (standPart and standPart.Parent) and standPart or ensureStandSummoned(character)
                if standPart and standPart.Parent then
                    local nextStandCF = nextHRP.CFrame - nextHRP.CFrame.LookVector * 1.1
                    standPart.CFrame = nextStandCF
                    hrp.CFrame = nextStandCF + nextStandCF.LookVector * -2.5 + Vector3.new(0, yOffset, 0)
                else
                    hrp.CFrame = nextHRP.CFrame + Vector3.new(0, yOffset, 0)
                end
            else
                hrp.CFrame = nextHRP.CFrame - nextHRP.CFrame.LookVector * 2.3
            end
            chained = true
        end
    end

    if not chained then
        if focusCam and focusCam.Parent then
            pcall(function()
                if createdFocusCam then
                    focusCam:Destroy()
                else
                    focusCam.Value = previousFocusValue
                end
            end)
        end
        parkAtReturnPosition()
    end

    if killed then
        moduleLog("INFO", ("[CombatFarm][Lock] Confirmed death: %s | lastHp=%s source=%s"):format(
            tostring(targetName), tostring(lastKnownHp), tostring(hpSource)
        ))
    else
        moduleLog("WARN", ("[CombatFarm][Lock] Target ended without confirmed death: %s | lastHp=%s source=%s"):format(
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
        parkAtReturnPosition()
        return false
    end
    return killTarget(npcName, token)
end

-- =============================================
-- QUEST DIALOGUE HELPERS (isolated from Inventory)
-- =============================================

local function questLevelFromName(name)
    local n = tostring(name or "")
    return tonumber(n:match("[Ll]vl%.?%s*(%d+)%+"))
end

local function getBestQuest()
    local stats = Player:FindFirstChild("PlayerStats")
    local levelObj = stats and stats:FindFirstChild("Level")
    local level = levelObj and tonumber(levelObj.Value) or 1

    local best, bestReq = nil, -1
    for questName, data in pairs(questInfo) do
        if data.autoChoose == true then
            local req = questLevelFromName(questName)
            if req and req <= level and req > bestReq then
                best, bestReq = questName, req
            end
        end
    end
    return best
end

readQuestState = function()
    local stats = Player:FindFirstChild("PlayerStats")
    if not stats then return 0, 0 end
    local p = stats:FindFirstChild("QuestProgress")
    local m = stats:FindFirstChild("QuestMaxProgress")
    return (p and tonumber(p.Value) or 0), (m and tonumber(m.Value) or 0)
end

local function getDialogueGui()
    return Player.PlayerGui:FindFirstChild("DialogueGui")
end

local function getDialogueOption(optionName)
    local gui = getDialogueGui()
    if not gui then return nil end
    local options = gui:FindFirstChild("Options", true)
    local option = options and options:FindFirstChild(optionName)
    if not option then return nil end
    return option:FindFirstChildWhichIsA("GuiButton", true)
end

local function getClickContinue()
    local gui = getDialogueGui()
    if not gui then return nil end
    local obj = gui:FindFirstChild("ClickContinue", true)
    return obj and obj:IsA("GuiButton") and obj or nil
end

local function rawConnections(signal)
    if type(getconnections) ~= "function" or not signal then return {} end
    local ok, conns = pcall(getconnections, signal)
    return ok and type(conns) == "table" and conns or {}
end

local function connectionFunction(conn)
    local fn = nil
    pcall(function() fn = conn.Function end)
    return fn
end

local function suppressDialogue(gui)
    if gui and gui:IsA("ScreenGui") then
        pcall(function() gui.Enabled = false end)
    end
end

local function physicalClick(btn)
    if not btn or not btn.Parent then return false end
    if type(firesignal) == "function" then
        local ok = pcall(function() firesignal(btn.MouseButton1Click) end)
        if ok then return true end
    end

    local ok = pcall(function()
        local pos, size = btn.AbsolutePosition, btn.AbsoluteSize
        local x, y = pos.X + size.X * 0.5, pos.Y + size.Y * 0.5
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)
    return ok
end

local function advanceOption1()
    local btn = getDialogueOption("Option1")
    if not btn then return false, "no-option1" end

    local conns = rawConnections(btn.MouseButton1Click)
    local setUp = type(setupvalue) == "function" and setupvalue
        or (debug and type(debug.setupvalue) == "function" and debug.setupvalue)

    -- Proven YBA callback shape: selected option is U[1]. This stays completely
    -- inside CombatFarm and never touches Inventory/Merchant code.
    if setUp then
        for _, conn in ipairs(conns) do
            local fn = connectionFunction(conn)
            if type(fn) == "function" then
                local ok = pcall(setUp, fn, 1, "Option1")
                if ok then
                    task.wait(0.02)
                    return true, "setupvalue"
                end
            end
        end
    end

    for _, conn in ipairs(conns) do
        local fired = false
        pcall(function()
            if type(conn.Fire) == "function" then
                conn:Fire()
                fired = true
            end
        end)
        if fired then return true, "connection:Fire" end

        local fn = connectionFunction(conn)
        if type(fn) == "function" and pcall(fn) then
            return true, "connection.Function"
        end
    end

    return physicalClick(btn), "fallback-click"
end

local function advanceContinue()
    local btn = getClickContinue()
    if not btn then return false, "no-continue" end

    local conns = rawConnections(btn.MouseButton1Click)
    -- This is the exact method the DialogueAnalyzer proved on Delta.
    for _, conn in ipairs(conns) do
        local fired = false
        pcall(function()
            if type(conn.Fire) == "function" then
                conn:Fire()
                fired = true
            end
        end)
        if fired then
            task.wait(0.04)
            return true, "connection:Fire"
        end
    end

    for _, conn in ipairs(conns) do
        local fn = connectionFunction(conn)
        if type(fn) == "function" and pcall(fn) then
            task.wait(0.04)
            return true, "connection.Function"
        end
    end

    if type(firesignal) == "function" then
        local ok = pcall(function() firesignal(btn.MouseButton1Click) end)
        if ok then
            task.wait(0.04)
            return true, "firesignal"
        end
    end

    return false, "no-working-continue-route"
end

local function driveQuestDialogue(token, timeout)
    local deadline = tick() + (timeout or 5)
    local gui = nil

    while tick() < deadline and isTokenActive(token, "Quest") do
        gui = getDialogueGui()
        if gui then break end
        task.wait(0.01)
    end
    if not gui then return false, "DialogueGui did not appear" end

    suppressDialogue(gui)
    local lastActionAt = 0
    local actions = 0

    while tick() < deadline and isTokenActive(token, "Quest") do
        gui = getDialogueGui()
        if not gui then
            return true, "closed"
        end
        suppressDialogue(gui)

        local acted, route = false, nil
        local option1 = getDialogueOption("Option1")
        if option1 and tick() - lastActionAt >= 0.04 then
            acted, route = advanceOption1()
        else
            local continueBtn = getClickContinue()
            if continueBtn and tick() - lastActionAt >= 0.04 then
                local conns = rawConnections(continueBtn.MouseButton1Click)
                if #conns > 0 then
                    acted, route = advanceContinue()
                end
            end
        end

        if acted then
            actions = actions + 1
            lastActionAt = tick()
            if actions > 12 then
                return false, "too many dialogue stages"
            end
            task.wait(0.03)
        else
            task.wait(0.01)
        end
    end

    return getDialogueGui() == nil, "timeout"
end

local function cleanQuestName(questName)
    local clean = tostring(questName or "")
    clean = clean:gsub("%s*%[Lvl%.%s*%d+%+%]%s*$", "")
    clean = clean:gsub("%s*%[Lvl%s*%d+%+%]%s*$", "")
    return clean
end

local function findQuestPrompt(questName)
    local cleanName = cleanQuestName(questName)
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
                    local q, c = questName:lower(), cleanName:lower()
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

local function interactQuestNPC(questName, token, reason)
    local prompt = findQuestPrompt(questName)
    if not prompt then
        moduleLog("WARN", "[CombatFarm] Quest ProximityPrompt not found: " .. tostring(questName))
        return false
    end

    moduleLog("INFO", "[CombatFarm] " .. tostring(reason or "Opening quest") .. ": " .. tostring(questName))
    local ok = pcall(function() fireproximityprompt(prompt) end)
    if not ok then return false end

    local worked, why = driveQuestDialogue(token, 5.5)
    if not worked then
        moduleLog("WARN", "[CombatFarm] Quest dialogue did not fully close: " .. tostring(why))
    end
    return true
end

local function waitForQuestState(predicate, token, timeout)
    local deadline = tick() + (timeout or 1.5)
    while tick() < deadline and isTokenActive(token, "Quest") do
        local p, m = readQuestState()
        if predicate(p, m) then return true, p, m end
        task.wait(0.03)
    end
    local p, m = readQuestState()
    return predicate(p, m), p, m
end

local function ensureQuestActive(questName, token)
    local progress, maxProgress = readQuestState()

    -- Already active and incomplete.
    if maxProgress > 0 and progress < maxProgress then
        questCompleted = false
        return true
    end

    -- Completed quest: turn it in first. This is generic and intentionally has
    -- no Dio/Jotaro-specific code.
    if maxProgress > 0 and progress >= maxProgress then
        questCompleted = true
        parkAtReturnPosition()
        interactQuestNPC(questName, token, "Turning in completed quest")
        waitForQuestState(function(p, m)
            return m == 0 or p < m
        end, token, 1.2)
        progress, maxProgress = readQuestState()
        questCompleted = false

        if maxProgress > 0 and progress < maxProgress then
            return true
        end
    end

    -- Accept/re-accept. Try twice because some NPCs use one interaction to close
    -- a completion page and a second interaction to offer the quest again.
    for attempt = 1, 2 do
        if not isTokenActive(token, "Quest") then return false end
        local beforeP, beforeM = readQuestState()
        interactQuestNPC(questName, token, attempt == 1 and "Opening quest dialogue" or "Reopening quest dialogue")

        local active = waitForQuestState(function(p, m)
            return m > 0 and p < m
        end, token, 1.5)
        if active then
            questCompleted = false
            local p, m = readQuestState()
            moduleLog("INFO", ("[CombatFarm] Quest active: %s | %s/%s"):format(
                tostring(questName), tostring(p), tostring(m)
            ))
            return true
        end

        local afterP, afterM = readQuestState()
        if afterM ~= beforeM or afterP ~= beforeP then
            task.wait(0.10)
        else
            task.wait(0.20)
        end
    end

    moduleLog("WARN", "[CombatFarm] Could not activate quest: " .. tostring(questName))
    return false
end

local function collectItem(itemName, requiredAmount, token)
    local startTime = tick()
    while isTokenActive(token, "Quest") and _inventory:Count(itemName) < requiredAmount and tick() - startTime < 120 do
        local itemModel = nil
        local itemsFolder = workspace:FindFirstChild("Item_Spawns")
        itemsFolder = itemsFolder and itemsFolder:FindFirstChild("Items")

        if itemsFolder then
            for _, model in ipairs(itemsFolder:GetChildren()) do
                if model:IsA("Model") then
                    local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if prompt and prompt.ObjectText == itemName then
                        itemModel = model
                        break
                    end
                end
            end
        end

        if itemModel and itemModel.PrimaryPart then
            local hrp = _movement:GetCharacter("HumanoidRootPart")
            if hrp then
                local oldCF = hrp.CFrame
                local freeze = _movement:Freeze()
                _movement:SetNoclip(true)
                _movement:Teleport(itemModel.PrimaryPart.CFrame - Vector3.new(0, 10, 0))
                task.wait(0.25)
                local prompt = itemModel:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then pcall(function() fireproximityprompt(prompt) end) end
                task.wait(0.45)
                _movement:Unfreeze(freeze)
                _movement:Teleport(oldCF)
                _movement:SetNoclip(false)
            end
        else
            task.wait(0.5)
        end
        task.wait(0.25)
    end

    return _inventory:Count(itemName) >= requiredAmount
end

local function runQuestFarm(token)
    local autoChoose = _config:Get("AutoChooseQuest")
    local selected = autoChoose and getBestQuest() or _config:Get("SelectedQuest")

    if selected ~= currentQuest then
        currentQuest = selected
        if autoChoose and currentQuest then
            moduleLog("INFO", "[CombatFarm] Auto Choose selected stable quest: " .. tostring(currentQuest))
        end
    end

    if not currentQuest or currentQuest == "" then
        moduleLog("INFO", "[CombatFarm] No quest selected or found.")
        parkAtReturnPosition()
        return false
    end

    local data = questInfo[currentQuest]
    if not data then
        moduleLog("WARN", "[CombatFarm] Unsupported quest mapping: " .. tostring(currentQuest))
        return false
    end

    if data.experimental then
        moduleLog("WARN", "[CombatFarm] Dio/Jotaro remains experimental and is excluded from Auto Choose. Manual selection will use the generic quest engine.")
    end

    if not ensureQuestActive(currentQuest, token) then
        parkAtReturnPosition()
        return false
    end

    if not waitToken(0.10, token, "Quest") then return false end

    if data.enemy then
        while isTokenActive(token, "Quest") do
            local progress, maxProgress = readQuestState()
            if questCompleted or (maxProgress > 0 and progress >= maxProgress) then
                questCompleted = true
                parkAtReturnPosition()
                return true
            end

            local killed = killTarget(data.enemy, token)
            if not isTokenActive(token, "Quest") then return false end
            if killed then
                if not waitToken(0.03, token, "Quest") then return false end
            else
                if not waitToken(0.45, token, "Quest") then return false end
            end
        end
        return false
    elseif data.item then
        local gotItems = collectItem(data.item, data.amount, token)
        if gotItems then
            task.wait(0.15)
            local p, m = readQuestState()
            if m > 0 and p >= m then questCompleted = true end
        end
        return gotItems
    end

    return false
end

-- =============================================
-- MAIN LOOP / PUBLIC API
-- =============================================

local function waitCancelable(seconds, token)
    local deadline = tick() + seconds
    while tick() < deadline do
        if not isTokenActive(token) then return false end
        task.wait(math.min(0.08, math.max(0, deadline - tick())))
    end
    return true
end

local function farmLoop(token)
    while isTokenActive(token) do
        if activeMode == "NPC" then
            local ok = runNPCFarm(token)
            if token ~= runId or stopRequested then break end
            if ok then
                if not waitCancelable(0.03, token) then break end
            else
                if not waitCancelable(0.45, token) then break end
            end

        elseif activeMode == "Quest" then
            local ok = runQuestFarm(token)
            if token ~= runId or stopRequested then break end
            if ok then
                moduleLog("INFO", "[CombatFarm] Quest objective complete. Turning in/re-taking...")
                questCompleted = false
                if not waitCancelable(0.35, token) then break end
            else
                if not waitCancelable(1.5, token) then break end
            end
        else
            break
        end

        if not waitCancelable(0.08, token) then break end
    end

    if token == runId then
        isRunning = false
        activeMode = nil
        parkAtReturnPosition()
        restoreItemFarmAfterCombat()
    end
end

local function startMode(mode)
    if isRunning and activeMode == mode then return end

    runId = runId + 1
    stopRequested = false
    activeMode = mode
    isRunning = true
    questCompleted = false
    currentQuest = nil

    pauseItemFarmForCombat()
    -- If the item farm was in the middle of one collection teleport, give that
    -- already-running action a short window to restore its old CFrame first.
    if pausedItemFarmWasEnabled then task.wait(0.70) end

    local hrp = _movement:GetCharacter("HumanoidRootPart")
    modeReturnCF = hrp and hrp.CFrame or modeReturnCF

    local token = runId
    moduleLog("INFO", "[CombatFarm] Starting " .. tostring(mode) .. " farming (COMBAT-ONLY-R1).")
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
    currentQuest = nil
    parkAtReturnPosition()
    restoreItemFarmAfterCombat()
    moduleLog("INFO", "[CombatFarm] Stopped and returned to pre-combat position.")
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
