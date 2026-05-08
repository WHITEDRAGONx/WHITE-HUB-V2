-- =====================
-- UI.lua
-- Handles all UI creation, tabs, toggles, animations, and drag behavior.
-- =====================

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local UI = {}

local _config  = nil
local _isOpen  = false
local _btnVisible = true

-- =====================
-- COLORS
-- =====================
local C = {
    BG        = Color3.fromRGB(15, 15, 20),
    BG2       = Color3.fromRGB(22, 22, 30),
    BG3       = Color3.fromRGB(30, 30, 42),
    Stroke    = Color3.fromRGB(60, 55, 85),
    StrokeHov = Color3.fromRGB(120, 90, 255),
    StrokeAct = Color3.fromRGB(160, 120, 255),
    Accent    = Color3.fromRGB(145, 95, 255),
    Text      = Color3.fromRGB(235, 235, 240),
    TextDim   = Color3.fromRGB(140, 140, 155),
    Red       = Color3.fromRGB(180, 50, 50),
    White     = Color3.fromRGB(255, 255, 255),
    Discord   = Color3.fromRGB(88, 101, 242),
    DiscordHov= Color3.fromRGB(110, 125, 255),
    Green     = Color3.fromRGB(50, 180, 80),
}

-- =====================
-- INIT
-- =====================
function UI:Init(Modules)
    _config = Modules.Config
end

-- =====================
-- CREDITS POPUP
-- =====================
local function CreateCreditsPopup()
    local gui = Instance.new("ScreenGui")
    gui.Parent       = PlayerGui
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size             = UDim2.new(0, 155, 0, 46)
    frame.Position         = UDim2.new(0, -165, 1, -160)
    frame.BackgroundColor3 = C.BG2
    frame.BorderSizePixel  = 0
    frame.Parent           = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color     = C.Stroke
    stroke.Thickness = 1.2

    local title = Instance.new("TextLabel", frame)
    title.Size               = UDim2.new(1,-10,0.52,0)
    title.Position           = UDim2.new(0,8,0,2)
    title.BackgroundTransparency = 1
    title.Text               = "WHITE HUB"
    title.TextColor3         = C.White
    title.TextScaled         = true
    title.Font               = Enum.Font.GothamBold
    title.TextXAlignment     = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", frame)
    sub.Size               = UDim2.new(1,-10,0.42,0)
    sub.Position           = UDim2.new(0,8,0.55,0)
    sub.BackgroundTransparency = 1
    sub.Text               = "by WHITE DRAGON"
    sub.TextColor3         = C.TextDim
    sub.TextScaled         = true
    sub.Font               = Enum.Font.Gotham
    sub.TextXAlignment     = Enum.TextXAlignment.Left

    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 8, 1, -160)
    }):Play()

    task.delay(5, function()
        local t = TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Position = UDim2.new(0, -165, 1, -160)
        })
        t:Play()
        t.Completed:Connect(function() gui:Destroy() end)
    end)
end

-- =====================
-- HELPERS
-- =====================
local function MakeSection(parent, text)
    local frame = Instance.new("Frame")
    frame.Size             = UDim2.new(1,-4,0,22)
    frame.BackgroundColor3 = C.BG2
    frame.BorderSizePixel  = 0
    frame.Parent           = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = C.Stroke

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1,-10,1,0)
    lbl.Position         = UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text
    lbl.TextColor3       = C.TextDim
    lbl.TextScaled       = true
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = frame
end

local function MakeToggle(parent, text, default, onChanged)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1,-4,0,28)
    holder.BackgroundColor3 = C.BG2
    holder.BorderSizePixel  = 0
    holder.Parent           = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 7)
    local stroke = Instance.new("UIStroke", holder)
    stroke.Color = C.Stroke

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(.65,0,1,0)
    lbl.Position         = UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text
    lbl.TextColor3       = C.Text
    lbl.TextScaled       = true
    lbl.Font             = Enum.Font.Gotham
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = holder

    local enabled = default

    local track = Instance.new("TextButton")
    track.Size             = UDim2.new(0,40,0,18)
    track.Position         = UDim2.new(1,-48,.5,-9)
    track.BackgroundColor3 = enabled and C.Accent or C.BG3
    track.Text             = ""
    track.BorderSizePixel  = 0
    track.Parent           = holder
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame")
    circle.Size             = UDim2.new(0,13,0,13)
    circle.Position         = enabled and UDim2.new(1,-16,.5,-6.5) or UDim2.new(0,3,.5,-6.5)
    circle.BackgroundColor3 = C.White
    circle.BorderSizePixel  = 0
    circle.Parent           = track
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    track.MouseButton1Click:Connect(function()
        enabled = not enabled
        TweenService:Create(track, TweenInfo.new(.18), {
            BackgroundColor3 = enabled and C.Accent or C.BG3
        }):Play()
        TweenService:Create(circle, TweenInfo.new(.18), {
            Position = enabled and UDim2.new(1,-16,.5,-6.5) or UDim2.new(0,3,.5,-6.5)
        }):Play()
        onChanged(enabled)
    end)
end

-- =====================
-- CREATE MAIN UI
-- =====================
function UI:Create()
    -- Credits popup first
    CreateCreditsPopup()

    local W, H = 380, 300

    local mainGui = Instance.new("ScreenGui")
    mainGui.Parent          = PlayerGui
    mainGui.ResetOnSpawn    = false
    mainGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling

    -- Toggle button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size             = UDim2.new(0,100,0,26)
    toggleBtn.Position         = UDim2.new(0,8,1,-200)
    toggleBtn.BackgroundColor3 = C.BG2
    toggleBtn.BorderSizePixel  = 0
    toggleBtn.Text             = "⚡ WHITE HUB"
    toggleBtn.TextColor3       = C.Text
    toggleBtn.TextScaled       = true
    toggleBtn.Font             = Enum.Font.GothamBold
    toggleBtn.Parent           = mainGui
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)
    local toggleStroke = Instance.new("UIStroke", toggleBtn)
    toggleStroke.Color     = C.Stroke
    toggleStroke.Thickness = 1.3

    toggleBtn.MouseEnter:Connect(function()
        TweenService:Create(toggleStroke, TweenInfo.new(.15), {Color=C.StrokeHov}):Play()
    end)
    toggleBtn.MouseLeave:Connect(function()
        TweenService:Create(toggleStroke, TweenInfo.new(.15), {Color=C.Stroke}):Play()
    end)

    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size             = UDim2.new(0,W,0,H)
    mainFrame.Position         = UDim2.new(.5,-W/2,.5,-H/2)
    mainFrame.BackgroundColor3 = C.BG
    mainFrame.BorderSizePixel  = 0
    mainFrame.Visible          = false
    mainFrame.Parent           = mainGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
    local mainStroke = Instance.new("UIStroke", mainFrame)
    mainStroke.Color     = C.Stroke
    mainStroke.Thickness = 1.5

    -- Topbar
    local topBar = Instance.new("Frame")
    topBar.Size             = UDim2.new(1,0,0,36)
    topBar.BackgroundColor3 = C.BG2
    topBar.BorderSizePixel  = 0
    topBar.Parent           = mainFrame
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)
    local topFix = Instance.new("Frame", topBar)
    topFix.Size             = UDim2.new(1,0,.5,0)
    topFix.Position         = UDim2.new(0,0,.5,0)
    topFix.BackgroundColor3 = C.BG2
    topFix.BorderSizePixel  = 0

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size             = UDim2.new(1,-50,1,0)
    titleLbl.Position         = UDim2.new(0,10,0,0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text             = "⚡ WHITE HUB"
    titleLbl.TextColor3       = C.White
    titleLbl.TextScaled       = true
    titleLbl.Font             = Enum.Font.GothamBold
    titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
    titleLbl.Parent           = topBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size             = UDim2.new(0,20,0,20)
    closeBtn.Position         = UDim2.new(1,-28,.5,-10)
    closeBtn.BackgroundColor3 = C.Red
    closeBtn.Text             = "✕"
    closeBtn.TextScaled       = true
    closeBtn.TextColor3       = C.White
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.BorderSizePixel  = 0
    closeBtn.Parent           = topBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

    -- =====================
    -- OPEN / CLOSE
    -- =====================
    local function ToggleWindow()
        _isOpen = not _isOpen
        if _isOpen then
            mainFrame.Visible  = true
            mainFrame.Size     = UDim2.new(0,0,0,0)
            mainFrame.Position = UDim2.new(.5,0,.5,0)
            TweenService:Create(mainFrame, TweenInfo.new(.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size     = UDim2.new(0,W,0,H),
                Position = UDim2.new(.5,-W/2,.5,-H/2),
            }):Play()
        else
            local t = TweenService:Create(mainFrame, TweenInfo.new(.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Size     = UDim2.new(0,0,0,0),
                Position = UDim2.new(.5,0,.5,0),
            })
            t:Play()
            t.Completed:Connect(function() mainFrame.Visible = false end)
        end
    end

    toggleBtn.MouseButton1Click:Connect(ToggleWindow)
    closeBtn.MouseButton1Click:Connect(ToggleWindow)

    UserInputService.InputBegan:Connect(function(i, gp)
        if gp then return end
        if i.KeyCode == Enum.KeyCode.RightAlt then ToggleWindow() end
        if i.KeyCode == Enum.KeyCode.RightControl then
            _btnVisible = not _btnVisible
            toggleBtn.Visible = _btnVisible
        end
    end)

    -- =====================
    -- DRAG
    -- =====================
    local dragging, dragStart, startPos = false, nil, nil
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            local d = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)

    -- =====================
    -- TABS
    -- =====================
    local tabNames = {"Farm", "Items", "Webhook", "Credits"}
    local pages    = {}

    local tabBar = Instance.new("Frame")
    tabBar.Size                = UDim2.new(0,90,1,-44)
    tabBar.Position            = UDim2.new(0,6,0,40)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent              = mainFrame
    local tabLayout = Instance.new("UIListLayout", tabBar)
    tabLayout.Padding = UDim.new(0, 4)

    local function CreatePage(name)
        local page = Instance.new("ScrollingFrame")
        page.Size               = UDim2.new(1,-104,1,-44)
        page.Position           = UDim2.new(0,98,0,40)
        page.BackgroundTransparency = 1
        page.BorderSizePixel    = 0
        page.ScrollBarThickness = 2
        page.Visible            = false
        page.Parent             = mainFrame
        local layout = Instance.new("UIListLayout", page)
        layout.Padding = UDim.new(0, 4)
        local pad = Instance.new("UIPadding", page)
        pad.PaddingTop   = UDim.new(0, 2)
        pad.PaddingRight = UDim.new(0, 4)
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 10)
        end)
        pages[name] = page
    end

    for _, name in ipairs(tabNames) do
        CreatePage(name)

        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(1,0,0,28)
        btn.BackgroundColor3 = C.BG2
        btn.Text             = name
        btn.TextColor3       = C.Text
        btn.TextScaled       = true
        btn.Font             = Enum.Font.GothamBold
        btn.BorderSizePixel  = 0
        btn.Parent           = tabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
        local bStroke = Instance.new("UIStroke", btn)
        bStroke.Color     = C.Stroke
        bStroke.Thickness = 1

        btn.MouseButton1Click:Connect(function()
            for n, p in pairs(pages) do p.Visible = (n == name) end
            for _, b in pairs(tabBar:GetChildren()) do
                if b:IsA("TextButton") then
                    local s = b:FindFirstChildOfClass("UIStroke")
                    if b.Text == name then
                        TweenService:Create(s, TweenInfo.new(.15), {Color=C.StrokeAct}):Play()
                        TweenService:Create(b, TweenInfo.new(.15), {BackgroundColor3=C.BG3}):Play()
                    else
                        TweenService:Create(s, TweenInfo.new(.15), {Color=C.Stroke}):Play()
                        TweenService:Create(b, TweenInfo.new(.15), {BackgroundColor3=C.BG2}):Play()
                    end
                end
            end
        end)
    end

    pages["Farm"].Visible = true

    -- =====================
    -- FARM TAB
    -- =====================
    MakeSection(pages["Farm"], "FARM SETTINGS")
    MakeToggle(pages["Farm"], "Auto Sell", _config:Get("AutoSell"), function(v)
        _config:Set("AutoSell", v)
    end)
    MakeToggle(pages["Farm"], "Auto Buy Lucky", _config:Get("BuyLucky"), function(v)
        _config:Set("BuyLucky", v)
    end)

    -- =====================
    -- ITEMS TAB
    -- =====================
    MakeSection(pages["Items"], "SELL ITEMS")

    local itemOrder = {
        "Gold Coin","Diamond","Rokakaka","Pure Rokakaka",
        "Mysterious Arrow","Lucky Arrow","Lucky Stone Mask","Ancient Scroll",
        "Caesar's Headband","Stone Mask","Rib Cage of The Saint's Corpse",
        "Quinton's Glove","Zeppeli's Hat","Clackers","Steel Ball","Dio's Diary",
    }
    for _, name in ipairs(itemOrder) do
        if _config:GetSellItem(name) ~= nil then
            MakeToggle(pages["Items"], name, _config:GetSellItem(name), function(v)
                _config:SetSellItem(name, v)
            end)
        end
    end

    -- =====================
    -- WEBHOOK TAB
    -- =====================
    MakeSection(pages["Webhook"], "DISCORD WEBHOOK")

    local whHolder = Instance.new("Frame")
    whHolder.Size             = UDim2.new(1,-4,0,32)
    whHolder.BackgroundColor3 = C.BG2
    whHolder.BorderSizePixel  = 0
    whHolder.Parent           = pages["Webhook"]
    Instance.new("UICorner", whHolder).CornerRadius = UDim.new(0, 7)
    local whStroke = Instance.new("UIStroke", whHolder)
    whStroke.Color = C.Stroke

    local whBox = Instance.new("TextBox")
    whBox.Size               = UDim2.new(1,-12,1,0)
    whBox.Position           = UDim2.new(0,8,0,0)
    whBox.BackgroundTransparency = 1
    whBox.Text               = _config:Get("WebhookURL")
    whBox.PlaceholderText    = "Paste Discord webhook URL here..."
    whBox.TextColor3         = C.Text
    whBox.PlaceholderColor3  = C.TextDim
    whBox.TextScaled         = true
    whBox.Font               = Enum.Font.Gotham
    whBox.TextXAlignment     = Enum.TextXAlignment.Left
    whBox.ClearTextOnFocus   = false
    whBox.Parent             = whHolder

    whBox.Focused:Connect(function()
        TweenService:Create(whStroke, TweenInfo.new(.1), {Color=C.StrokeAct}):Play()
    end)
    whBox.FocusLost:Connect(function()
        _config:Set("WebhookURL", whBox.Text)
        TweenService:Create(whStroke, TweenInfo.new(.1), {Color=C.Stroke}):Play()
    end)

    -- =====================
    -- CREDITS TAB
    -- =====================
    MakeSection(pages["Credits"], "WHITE HUB")

    local creditLbl = Instance.new("TextLabel")
    creditLbl.Size             = UDim2.new(1,-4,0,40)
    creditLbl.BackgroundColor3 = C.BG2
    creditLbl.BorderSizePixel  = 0
    creditLbl.Text             = "Made by WHITE DRAGON"
    creditLbl.TextColor3       = C.Text
    creditLbl.TextScaled       = true
    creditLbl.Font             = Enum.Font.GothamBold
    creditLbl.Parent           = pages["Credits"]
    Instance.new("UICorner", creditLbl).CornerRadius = UDim.new(0, 7)
    local creditStroke = Instance.new("UIStroke", creditLbl)
    creditStroke.Color = C.Stroke

    local discordBtn = Instance.new("TextButton")
    discordBtn.Size             = UDim2.new(1,-4,0,32)
    discordBtn.BackgroundColor3 = C.Discord
    discordBtn.BorderSizePixel  = 0
    discordBtn.Text             = "🔗 discord.gg/Qwd23ZRNxJ  —  Click to Copy"
    discordBtn.TextColor3       = C.White
    discordBtn.TextScaled       = true
    discordBtn.Font             = Enum.Font.GothamBold
    discordBtn.Parent           = pages["Credits"]
    Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0, 7)
    Instance.new("UIStroke", discordBtn).Color = Color3.fromRGB(60, 70, 200)

    discordBtn.MouseEnter:Connect(function()
        TweenService:Create(discordBtn, TweenInfo.new(.15), {BackgroundColor3=C.DiscordHov}):Play()
    end)
    discordBtn.MouseLeave:Connect(function()
        TweenService:Create(discordBtn, TweenInfo.new(.15), {BackgroundColor3=C.Discord}):Play()
    end)
    discordBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard("https://discord.gg/Qwd23ZRNxJ") end)
        local orig = discordBtn.Text
        discordBtn.Text = "✅ Copied!"
        TweenService:Create(discordBtn, TweenInfo.new(.15), {BackgroundColor3=C.Green}):Play()
        task.delay(2, function()
            discordBtn.Text = orig
            TweenService:Create(discordBtn, TweenInfo.new(.15), {BackgroundColor3=C.Discord}):Play()
        end)
    end)
end

-- =====================
-- NOTIFY (toast no topbar futuro)
-- =====================
function UI:Notify(msg)
    print("[UI Notify] " .. tostring(msg))
end

function UI:SetVisible(value)
    -- reserved for external control if needed
end

return UI
