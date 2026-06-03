-- =====================
-- NPCFarm.lua 
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

    local oldPos = hrp.CFrame
    local hasStand = _inventory:HasStand()
    if hasStand then
        _inventory:SummonStand()
        task.wait(0.3)
    end

    -- Foco manual na câmera (sem precisar de SetFocusOnPart)
    local standPart = nil
    if hasStand then
        local standMorph = _movement:GetCharacter("StandMorph")
        if standMorph and standMorph.PrimaryPart then
            standPart = standMorph.PrimaryPart
        end
    end

    _movement:SetNoclip(true)
    local startTime = tick()
    local killed = false

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

        if hasStand and standPart then
            -- Stand atrás do NPC
            standPart.CFrame = npcHRP.CFrame - npcHRP.CFrame.LookVector * 1.1
            -- Player embaixo do chão
            hrp.CFrame = standPart.CFrame + standPart.CFrame.LookVector * math.random(-3, -2) + Vector3.new(0, -35, 0)
        else
            hrp.CFrame = CFrame.new(npcHRP.Position.X, npcHRP.Position.Y - 15, npcHRP.Position.Z)
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

    _movement:SetNoclip(false)
    if hrp then
        hrp.CFrame = oldPos
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
    print("[NPCFarm] Starting NPC farming...")

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
