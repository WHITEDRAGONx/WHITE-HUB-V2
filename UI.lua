-- =====================
-- UI.lua (WHITE HUB V2)
-- =====================

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local UI = {}

local _config  = nil
local _webhook = nil

local toggleObjects = {}

function UI:Init(Modules)
    _config  = Modules.Config
    _webhook = Modules.Webhook
end

-- CREDITS POPUP (same as before, omitted for brevity – but include full code in actual file)
-- ... (keep the exact same CreditsPopup, AutoCanvas, MakeSection, MakeToggle, ShowPopup, SetToggleValue functions as in your working UI.lua) ...

function UI:Create()
    CreateCreditsPopup()

    local W, H = 380, 320

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.Parent         = PlayerGui

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name             = "MainFrame"
    MainFrame.BackgroundColor3 = Color3.fromRGB(15,15,20)
    MainFrame.BorderSizePixel  = 0
    MainFrame.Position         = UDim2.new(0.5,-W/2,0.5,-H/2)
    MainFrame.Size             = UDim2.new(0,W,0,H)
    MainFrame.Visible          = false
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,12)
    local mfStroke = Instance.new("UIStroke", MainFrame)
    mfStroke.Color     = Color3.fromRGB(60,55,85)
    mfStroke.Thickness = 1.5

    local TopBar = Instance.new("Frame", MainFrame)
    TopBar.Name             = "TopBar"
    TopBar.BackgroundColor3 = Color3.fromRGB(22,22,30)
    TopBar.BorderSizePixel  = 0
    TopBar.Size             = UDim2.new(1,0,0,40)
    Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0,12)
    local topFix = Instance.new("Frame", TopBar)
    topFix.BackgroundColor3 = Color3.fromRGB(22,22,30)
    topFix.BorderSizePixel  = 0
    topFix.Position         = UDim2.new(0,0,0.5,0)
    topFix.Size             = UDim2.new(1,0,0.5,0)

    local Title = Instance.new("TextLabel", TopBar)
    Title.BackgroundTransparency = 1
    Title.BorderSizePixel        = 0
    Title.Position               = UDim2.new(0,12,0,0)
    Title.Size                   = UDim2.new(1,-50,1,0)
    Title.Text                   = "⚡ WHITE HUB"
    Title.TextColor3             = Color3.fromRGB(255,255,255)
    Title.TextSize               = 22
    Title.Font                   = Enum.Font.GothamBold
    Title.TextXAlignment         = Enum.TextXAlignment.Left

    local CloseButton = Instance.new("TextButton", TopBar)
    CloseButton.BackgroundColor3 = Color3.fromRGB(180,50,50)
    CloseButton.BorderSizePixel  = 0
    CloseButton.Position         = UDim2.new(1,-30,0.5,-11)
    CloseButton.Size             = UDim2.new(0,24,0,24)
    CloseButton.Text             = "X"
    CloseButton.TextColor3       = Color3.fromRGB(255,255,255)
    CloseButton.TextSize         = 16
    CloseButton.Font             = Enum.Font.GothamBold
    Instance.new("UICorner", CloseButton).CornerRadius = UDim.new(1,0)

    local Sidebar = Instance.new("Frame", MainFrame)
    Sidebar.BackgroundTransparency = 1
    Sidebar.BorderSizePixel        = 0
    Sidebar.Position               = UDim2.new(0,6,0,42)
    Sidebar.Size                   = UDim2.new(0,90,1,-50)
    local sideLayout = Instance.new("UIListLayout", Sidebar)
    sideLayout.Padding   = UDim.new(0,5)
    sideLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local PagesFrame = Instance.new("Frame", MainFrame)
    PagesFrame.BackgroundTransparency = 1
    PagesFrame.BorderSizePixel        = 0
    PagesFrame.Position               = UDim2.new(0,104,0,42)
    PagesFrame.Size                   = UDim2.new(1,-116,1,-50)

    -- ... (rest of UI creation as in your working file, including FarmPage with the toggle for Auto Prestige Mode) ...

    -- Ensure you have the Auto Prestige Mode toggle in the Farm section:
    -- MakeToggle(FarmPage, "Auto Prestige Mode", _config and _config:Get("AutoPrestige"), ...)

    -- ... rest of the UI ...
end

return UI
