-- =====================
-- Movement.lua
-- Handles all character movement: teleport, noclip, freeze, camera.
-- =====================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace  = game:GetService("Workspace")

local Player   = Players.LocalPlayer
local Movement = {}

local _noclipActive = false

RunService.Stepped:Connect(function()
    if not _noclipActive then return end
    local char = Player.Character
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end)

function Movement:SetNoclip(value)
    _noclipActive = value
    if not value then
        local char = Player.Character
        if not char then return end
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

local function GetHRP()
    local char = Player.Character
    if char then return char:FindFirstChild("HumanoidRootPart") end
    return nil
end

function Movement:Teleport(cf)
    local hrp = GetHRP()
    if hrp and typeof(cf) == "CFrame" then hrp.CFrame = cf end
end

function Movement:Freeze()
    local hrp = GetHRP()
    if not hrp then return nil end
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent   = hrp
    return bv
end

function Movement:Unfreeze(bv)
    if bv and bv.Parent then bv:Destroy() end
end

-- Freeze the player at a specific CFrame (teleport + freeze)
function Movement:FreezeAtPosition(cf)
    self:Teleport(cf)
    return self:Freeze()
end

function Movement:FixCamera()
    pcall(function()
        local camera = Workspace.CurrentCamera
        if not camera then return end
        camera.CameraType = Enum.CameraType.Custom
        local char = Player.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then camera.CameraSubject = hum end
            if hrp then
                camera.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 5, 10), hrp.Position)
            end
        end
    end)
end

function Movement:GetCharacter(part)
    local char = Player.Character
    if not char then return nil end
    if not part then return char end
    return char:FindFirstChild(part) or nil
end

-- Focus camera on a specific part (used for stand combat)
function Movement:SetFocusOnPart(part)
    local char = Player.Character
    if not char then return end
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
    if char then
        local focus = char:FindFirstChild("FocusCam")
        if focus then focus:Destroy() end
    end
end

Player.CharacterAdded:Connect(function()
    task.wait(2)
    Movement:FixCamera()
end)

return Movement
