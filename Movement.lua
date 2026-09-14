-- =====================
-- Movement.lua (WHITE HUB V3)
-- Collision-safe noclip, freeze helpers, camera lifecycle.
-- =====================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Movement = {}

local _noclipActive = false
local _collisionState = {}
local _connections = {}
local _lastNoclipPass = 0

local function disconnectAll()
    for _, connection in ipairs(_connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(_connections)
end

local function shouldIgnorePart(char, part)
    local standMorph = char and char:FindFirstChild("StandMorph")
    return standMorph and part:IsDescendantOf(standMorph)
end

local function applyNoclipPass()
    if not _noclipActive then return end
    local char = Player.Character
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and not shouldIgnorePart(char, part) then
            if _collisionState[part] == nil then
                _collisionState[part] = part.CanCollide
            end
            if part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end

local function restoreCollisions()
    for part, previous in pairs(_collisionState) do
        if part and part.Parent then
            pcall(function() part.CanCollide = previous end)
        end
    end
    table.clear(_collisionState)
end

function Movement:Init()
    disconnectAll()

    table.insert(_connections, RunService.Stepped:Connect(function()
        if not _noclipActive then return end
        local now = os.clock()
        if now - _lastNoclipPass < 0.10 then return end
        _lastNoclipPass = now
        applyNoclipPass()
    end))

    table.insert(_connections, Player.CharacterAdded:Connect(function()
        table.clear(_collisionState)
        task.wait(1)
        if _noclipActive then applyNoclipPass() end
        Movement:FixCamera()
    end))
end

function Movement:SetNoclip(value)
    value = value == true
    if value == _noclipActive then
        if value then applyNoclipPass() end
        return
    end

    _noclipActive = value
    if value then
        applyNoclipPass()
    else
        restoreCollisions()
    end
end

local function GetHRP()
    local char = Player.Character
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

function Movement:Teleport(cf)
    local hrp = GetHRP()
    if hrp and typeof(cf) == "CFrame" then
        hrp.CFrame = cf
        return true
    end
    return false
end

function Movement:Freeze()
    local hrp = GetHRP()
    if not hrp then return nil end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "WhiteHubFreeze"
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = hrp
    return bv
end

-- Compatibility helper for legacy QuestFarm/NPCFarm modules.
function Movement:FreezeAtPosition(cf)
    if typeof(cf) == "CFrame" then
        self:Teleport(cf)
    end
    return self:Freeze()
end

function Movement:Unfreeze(bv)
    if bv and bv.Parent then
        bv:Destroy()
    end
end

function Movement:FixCamera()
    pcall(function()
        local camera = Workspace.CurrentCamera
        if not camera then return end
        camera.CameraType = Enum.CameraType.Custom
        local char = Player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum then camera.CameraSubject = hum end
        if hrp then
            camera.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 5, 10), hrp.Position)
        end
    end)
end

function Movement:GetCharacter(part)
    local char = Player.Character
    if not char then return nil end
    if not part then return char end
    return char:FindFirstChild(part)
end

function Movement:SetFocusOnPart(part)
    local char = Player.Character
    if not char or not part then return end
    local focus = char:FindFirstChild("FocusCam")
    if not focus then
        focus = Instance.new("ObjectValue")
        focus.Name = "FocusCam"
        focus.Parent = char
    end
    focus.Value = part
end

function Movement:ClearFocus()
    local char = Player.Character
    if not char then return end
    local focus = char:FindFirstChild("FocusCam")
    if focus then focus:Destroy() end
end

function Movement:Destroy()
    _noclipActive = false
    restoreCollisions()
    self:ClearFocus()
    disconnectAll()
end

return Movement
