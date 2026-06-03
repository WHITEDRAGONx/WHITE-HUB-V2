-- =====================
-- NPCFarm.lua
-- Xenon V5 style NPC farming: stand fixed behind NPC, player frozen underground.
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

-- Disable stand constraints so it stays where we put it
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

    -- Save original position
    local oldPos = hrp.CFrame
    local freezeBV = nil

    -- Summon stand if available
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

    -- Focus camera on stand (or NPC if no stand)
    if standPart then
        _movement:SetFocusOnPart(standPart)
    else
        _movement:SetFocusOnPart(npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart)
    end

    -- Enable noclip and freeze player underground
    _movement:SetNoclip(true)
    local yOffset = -35  -- underground offset
    if npcName == "The Idol" then yOffset = 35 end

    local startTime = tick()
    local killed = false

    -- Initial freeze at position below NPC
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
            -- Place stand behind NPC (fixed position each loop)
            standPart.CFrame = npcHRP.CFrame - npcHRP.CFrame.LookVector * 1.1
            -- Keep player frozen at the same underground position (relative to stand)
            local standPos = standPart.Position
            local playerCF = CFrame.new(standPos.X, standPos.Y + yOffset, standPos.Z) +
                             standPart.CFrame.LookVector * math.random(-3, -2)
            if freezeBV and freezeBV.Parent then
                hrp.CFrame = playerCF
                -- BodyVelocity keeps velocity zero, but we also set CFrame each loop to be safe
            else
                freezeBV = _movement:FreezeAtPosition(playerCF)
            end
        else
            -- Fallback: just teleport player above/below NPC
            hrp.CFrame = CFrame.new(npcHRP.Position.X, npcHRP.Position.Y + yOffset, npcHRP.Position.Z)
        end

        -- Attack
        pcall(function() remoteFunc:InvokeServer("Attack", "m1") end)

        -- Auto skills
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
    _movement:SetNoclip(false)
    if hrp then
        hrp.CFrame = oldPos
    end
    -- Re-enable stand constraints (optional, but good practice)
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

function NPCFarm:Start()
    if isRunning then
        print("[NPCFarm] Already running.")
        return
    end
    stopRequested = false
    isRunning = true
    print("[NPCFarm] Starting NPC farming (fixed stand + frozen player)...")

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
