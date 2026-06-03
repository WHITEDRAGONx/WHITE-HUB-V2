-- =====================
-- NPCFarm.lua (stand fixed with BodyVelocity + anchoring)
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
    local freezeBV = nil
    local standVelocity = nil

    -- Summon stand
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
            
            -- Disable original constraints
            local standAttach = standPart:FindFirstChild("StandAttach")
            if standAttach then
                local alignPos = standAttach:FindFirstChild("AlignPosition")
                local alignOri = standAttach:FindFirstChild("AlignOrientation")
                if alignPos then alignPos.Enabled = false end
                if alignOri then alignOri.Enabled = false end
            end
            
            -- Make stand physically stable
            standPart.CanCollide = true
            standPart.CustomPhysicalProperties = PhysicalProperties.new(1, 0.1, 0.1)
            
            -- BodyVelocity to keep stand in place (zero velocity, high force)
            standVelocity = Instance.new("BodyVelocity")
            standVelocity.Velocity = Vector3.new(0, 0, 0)
            standVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            standVelocity.Parent = standPart
        end
    end

    -- Focus camera
    if standPart then
        _movement:SetFocusOnPart(standPart)
    else
        _movement:SetFocusOnPart(npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart)
    end

    _movement:SetNoclip(true)
    local yOffset = -35
    if npcName == "The Idol" then yOffset = 35 end

    -- Freeze player underground
    local playerCF = CFrame.new(hrp.Position.X, hrp.Position.Y + yOffset, hrp.Position.Z)
    freezeBV = _movement:FreezeAtPosition(playerCF)

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

        if standPart and standPart.Parent then
            -- Teleport stand behind NPC
            local targetCF = npcHRP.CFrame - npcHRP.CFrame.LookVector * 1.1
            standPart.CFrame = targetCF
            
            -- Update player position
            local newPlayerCF = CFrame.new(standPart.Position.X, standPart.Position.Y + yOffset, standPart.Position.Z)
            if freezeBV and freezeBV.Parent then
                hrp.CFrame = newPlayerCF
            else
                freezeBV = _movement:FreezeAtPosition(newPlayerCF)
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

    -- Cleanup
    _movement:ClearFocus()
    _movement:Unfreeze(freezeBV)
    if standVelocity then standVelocity:Destroy() end
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
    print("[NPCFarm] Starting NPC farming (BodyVelocity lock)...")

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
