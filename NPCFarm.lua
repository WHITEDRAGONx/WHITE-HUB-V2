-- =====================
-- NPCFarm.lua
-- Xenon V5 style NPC farming: stand behind NPC, player underground, camera on stand.
-- =====================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local NPCFarm = {}

local _config    = nil
local _movement  = nil
local _inventory = nil
local _serverHop = nil
local _webhook   = nil

local isRunning = false
local stopRequested = false

function NPCFarm:Init(Modules)
    _config    = Modules.Config
    _movement  = Modules.Movement
    _inventory = Modules.Inventory
    _serverHop = Modules.ServerHop
    _webhook   = Modules.Webhook
end

local function useSkill(skillKey)
    local re = _movement:GetCharacter("RemoteEvent")
    if re then
        re:FireServer("InputBegan", { Input = Enum.KeyCode[skillKey] })
    end
end

-- Xenon V5 kill logic
local function killNPC(npcName)
    local npc = workspace.Living:FindFirstChild(npcName)
    if not npc then
        print("[NPCFarm] NPC not found: " .. npcName)
        return false
    end

    local hrp = _movement:GetCharacter("HumanoidRootPart")
    local remoteFunc = _movement:GetCharacter("RemoteFunction")
    if not hrp or not remoteFunc then
        return false
    end

    -- Save original position and camera subject
    local oldPos = hrp.CFrame
    local oldCameraSubject = workspace.CurrentCamera and workspace.CurrentCamera.CameraSubject

    -- Summon stand if available
    local hasStand = _inventory:HasStand()
    if hasStand then
        _inventory:SummonStand()
        task.wait(0.3)
    end

    local standPart = nil
    if hasStand then
        local standMorph = _movement:GetCharacter("StandMorph")
        if standMorph and standMorph.PrimaryPart then
            standPart = standMorph.PrimaryPart
        end
    end

    -- Focus camera on stand (or on NPC if no stand)
    if standPart then
        _movement:SetFocusOnPart(standPart)
    else
        _movement:SetFocusOnPart(npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart)
    end

    -- Enable noclip to avoid physics issues
    _movement:SetNoclip(true)

    local startTime = tick()
    local killed = false
    local yOffset = -35  -- Standard underground offset (Xenon V5 uses -35 for most NPCs)
    if npcName == "The Idol" then
        yOffset = 35
    end

    while not stopRequested and tick() - startTime < 60 do
        -- Refresh NPC reference (might respawn)
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
            -- Place stand behind NPC (exactly like Xenon V5)
            standPart.CFrame = npcHRP.CFrame - npcHRP.CFrame.LookVector * 1.1
            -- Place player relative to stand: behind and far below
            hrp.CFrame = standPart.CFrame + standPart.CFrame.LookVector * math.random(-3, -2) + Vector3.new(0, yOffset, 0)
        else
            -- Fallback: just teleport player above/below NPC (less safe)
            hrp.CFrame = CFrame.new(npcHRP.Position.X, npcHRP.Position.Y + yOffset, npcHRP.Position.Z)
        end

        -- Attack (M1)
        pcall(function() remoteFunc:InvokeServer("Attack", "m1") end)

        -- Auto skills
        local skills = _config:Get("AutoSkills")
        if type(skills) == "table" then
            for _, sk in ipairs(skills) do
                useSkill(sk)
            end
        end

        task.wait(0.3)  -- Xenon V5 uses 0.3 sec loop
    end

    -- Cleanup
    _movement:ClearFocus()
    _movement:SetNoclip(false)
    if hrp then
        hrp.CFrame = oldPos
    end
    if oldCameraSubject then
        pcall(function()
            workspace.CurrentCamera.CameraSubject = oldCameraSubject
        end)
    end

    return killed
end

function NPCFarm:Start()
    if isRunning then
        print("[NPCFarm] Already running.")
        return
    end
    stopRequested = false
    isRunning = true
    print("[NPCFarm] Starting NPC farming (Xenon V5 style)...")

    while not stopRequested do
        local npcName = _config:Get("SelectedNPC")
        if not npcName or npcName == "" then
            print("[NPCFarm] No NPC selected. Waiting...")
            task.wait(5)
        else
            print("[NPCFarm] Farming NPC: " .. npcName)
            local ok = killNPC(npcName)
            if ok then
                print("[NPCFarm] Killed " .. npcName .. ". Waiting for respawn...")
                task.wait(5)
            else
                print("[NPCFarm] Failed to kill NPC. Waiting before retry...")
                task.wait(5)
            end
        end
        task.wait(1)
    end
    isRunning = false
    print("[NPCFarm] Stopped.")
end

function NPCFarm:Stop()
    stopRequested = true
    isRunning = false
    print("[NPCFarm] Stop requested.")
end

return NPCFarm
