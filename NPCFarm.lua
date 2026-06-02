-- =====================
-- NPCFarm.lua
-- Handles farming a specific NPC repeatedly.
-- =====================

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local NPCFarm = {}

local _config    = nil
local _movement  = nil
local _serverHop = nil
local _webhook   = nil

local isRunning = false
local stopRequested = false

function NPCFarm:Init(Modules)
    _config    = Modules.Config
    _movement  = Modules.Movement
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
        print("[NPCFarm] NPC not found: " .. npcName .. " – waiting for respawn...")
        return false
    end
    local hrp = _movement:GetCharacter("HumanoidRootPart")
    local remoteFunc = _movement:GetCharacter("RemoteFunction")
    if not hrp then
        return false
    end
    local startTime = tick()
    while true do
        if stopRequested then
            return false
        end
        if tick() - startTime > 60 then
            print("[NPCFarm] Timeout killing " .. npcName .. " – retrying next cycle.")
            return false
        end
        npc = workspace.Living:FindFirstChild(npcName)
        if not npc then
            break
        end
        local npcHum = npc:FindFirstChildWhichIsA("Humanoid")
        local npcHRP = npc:FindFirstChild("HumanoidRootPart")
        if not npcHum or not npcHRP or npcHum.Health <= 0 then
            break
        end
        hrp.CFrame = CFrame.new(npcHRP.Position.X, npcHRP.Position.Y - 15, npcHRP.Position.Z)
        if remoteFunc then
            pcall(function() remoteFunc:InvokeServer("Attack", "m1") end)
        end
        local skills = _config:Get("AutoSkills")
        if type(skills) == "table" then
            for _, sk in ipairs(skills) do
                useSkill(sk)
            end
        end
        task.wait(0.3)
    end
    return true
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
                print("[NPCFarm] Failed to kill NPC or NPC not found. Waiting before retry...")
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
