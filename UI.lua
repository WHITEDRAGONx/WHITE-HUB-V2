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

-- Store toggle objects for external updates
local toggleObjects = {}

function UI:Init(Modules)
    _config  = Modules.Config
    _webhook = Modules.Webhook
end

-- =====================
-- CREDITS POPUP
-- =====================
local function CreateCreditsPopup()
    local gui = Instance.new("ScreenGui")
    gui.Parent       = PlayerGui
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size             = UDim2.new(0,155,0,46)
    frame.Position         = UDim2.new(0,-165,1,-160)
    frame.BackgroundColor3 = Color3.fromRGB(22,22,30)
    frame.BorderSizePixel  = 0
    frame.Parent           = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
    local fs = Instance.new("UIStroke", frame)
    fs.Color = Color3.fromRGB(60,55,85)
    fs.Thickness = 1.2

    local t1 = Instance.new("TextLabel", frame)
    t1.Size               = UDim2.new(1,-10,0.52,0)
    t1.Position           = UDim2.new(0,8,0,2)
    t1.BackgroundTransparency = 1
    t1.Text               = "WHITE HUB"
    t1.TextColor3         = Color3.fromRGB(255,255,255)
    t1.TextScaled         = true
    t1.Font               = Enum.Font.GothamBold
    t1.TextXAlignment     = Enum.TextXAlignment.Left

    local t2 = Instance.new("TextLabel", frame)
    t2.Size               = UDim2.new(1,-10,0.42,0)
    t2.Position           = UDim2.new(0,8,0.55,0)
    t2.BackgroundTransparency = 1
    t2.Text               = "by WHITE DRAGON"
    t2.TextColor3         = Color3.fromRGB(140,140,155)
    t2.TextScaled         = true
    t2.Font               = Enum.Font.Gotham
    t2.TextXAlignment     = Enum.TextXAlignment.Left

    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = UDim2.new(0,8,1,-160)
    }):Play()
    task.delay(5, function()
        local t = TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
            Position = UDim2.new(0,-165,1,-160)
        })
        t:Play()
        t.Completed:Connect(function() gui:Destroy() end)
    end)
end

-- =====================
-- UI HELPERS
-- =====================
local function AutoCanvas(scroll)
    local list = scroll:FindFirstChildOfClass("UIListLayout")
    if not list then return end
    local function update()
        scroll.CanvasSize = UDim2.new(0,0,0, list.AbsoluteContentSize.Y + 10)
    end
    update()
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
end

local function MakeSection(parent, text)
    local frame = Instance.new("Frame")
    frame.Size             = UDim2.new(1,-4,0,24)
    frame.BackgroundColor3 = Color3.fromRGB(22,22,30)
    frame.BorderSizePixel  = 0
    frame.Parent           = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(60,55,85)
    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1,-10,1,0)
    lbl.Position         = UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = text
    lbl.TextColor3       = Color3.fromRGB(140,140,155)
    lbl.TextScaled       = true
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = frame
end

local function MakeToggle(parent, labelText, default, onChanged)
    local holder = Instance.new("Frame")
    holder.Size             = UDim2.new(1,-4,0,32)
    holder.BackgroundColor3 = Color3.fromRGB(22,22,30)
    holder.BorderSizePixel  = 0
    holder.Parent           = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0,7)
    local stroke = Instance.new("UIStroke", holder)
    stroke.Color = Color3.fromRGB(60,55,85)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(0.65,0,1,0)
    lbl.Position         = UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = labelText
    lbl.TextColor3       = Color3.fromRGB(235,235,240)
    lbl.TextScaled       = true
    lbl.Font             = Enum.Font.Gotham
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = holder

    local enabled = (default == nil) and true or default

    local track = Instance.new("TextButton")
    track.Size             = UDim2.new(0,44,0,22)
    track.Position         = UDim2.new(1,-52,0.5,-11)
    track.BackgroundColor3 = enabled and Color3.fromRGB(145,95,255) or Color3.fromRGB(30,30,42)
    track.Text             = ""
    track.BorderSizePixel  = 0
    track.Parent           = holder
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)

    local circle = Instance.new("Frame")
    circle.Size             = UDim2.new(0,15,0,15)
    circle.Position         = enabled and UDim2.new(1,-18,0.5,-7.5) or UDim2.new(0,3,0.5,-7.5)
    circle.BackgroundColor3 = Color3.fromRGB(255,255,255)
    circle.BorderSizePixel  = 0
    circle.Parent           = track
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)

    track.MouseButton1Click:Connect(function()
        enabled = not enabled
        TweenService:Create(track, TweenInfo.new(0.18), {
            BackgroundColor3 = enabled and Color3.fromRGB(145,95,255) or Color3.fromRGB(30,30,42)
        }):Play()
        TweenService:Create(circle, TweenInfo.new(0.18), {
            Position = enabled and UDim2.new(1,-18,0.5,-7.5) or UDim2.new(0,3,0.5,-7.5)
        }):Play()
        onChanged(enabled)
    end)

    -- Store toggle for external access
    toggleObjects[labelText] = {
        holder = holder,
        track = track,
        circle = circle,
        enabled = enabled
    }
end

-- =====================
-- POPUP MESSAGE
-- =====================
function UI:ShowPopup(message, duration)
    duration = duration or 3
    local screenGui = PlayerGui:FindFirstChild("WhiteHubPopup")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "WhiteHubPopup"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = PlayerGui
    end
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 44)
    frame.Position = UDim2.new(1, -250, 1, -60)
    frame.BackgroundColor3 = Color3.fromRGB(22,22,30)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(145,95,255)
    stroke.Thickness = 1.2
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextWrapped = true
    label.Parent = frame
    
    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 0}):Play()
    task.delay(duration, function()
        TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
        task.wait(0.3)
        frame:Destroy()
    end)
end

-- =====================
-- SET TOGGLE VALUE EXTERNALLY
-- =====================
function UI:SetToggleValue(toggleName, value)
    local toggle = toggleObjects[toggleName]
    if toggle then
        toggle.enabled = value
        toggle.track.BackgroundColor3 = value and Color3.fromRGB(145,95,255) or Color3.fromRGB(30,30,42)
        toggle.circle.Position = value and UDim2.new(1,-18,0.5,-7.5) or UDim2.new(0,3,0.5,-7.5)
        if _config then _config:Set(toggleName, value) end
    else
        warn("[UI] Toggle not found: " .. toggleName)
    end
end

-- =====================
-- CREATE MAIN UI
-- =====================
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

    -- =====================
    -- BUILD PAGES
    -- =====================
    local function MakePage(name)
        local scroll = Instance.new("ScrollingFrame", PagesFrame)
        scroll.Name                    = name
        scroll.Active                  = true
        scroll.BackgroundTransparency  = 1
        scroll.BorderSizePixel         = 0
        scroll.ScrollBarThickness      = 6
        scroll.ScrollBarImageColor3    = Color3.fromRGB(140,90,255)
        scroll.Size                    = UDim2.new(1,0,1,0)
        scroll.Visible                 = false
        local layout = Instance.new("UIListLayout", scroll)
        layout.Padding   = UDim.new(0,4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        local pad = Instance.new("UIPadding", scroll)
        pad.PaddingLeft  = UDim.new(0,4)
        pad.PaddingRight = UDim.new(0,4)
        pad.PaddingTop   = UDim.new(0,4)
        return scroll
    end

    local FarmPage    = MakePage("FarmPage")
    local ItemsPage   = MakePage("ItemsPage")
    local WebhookPage = MakePage("WebhookPage")
    local CreditsPage = MakePage("CreditsPage")
    FarmPage.Visible = true

    local tabDefs = {
        { name="Farm",    page=FarmPage    },
        { name="Items",   page=ItemsPage   },
        { name="Webhook", page=WebhookPage },
        { name="Credits", page=CreditsPage },
    }
    local tabButtons = {}

    local C_BG2      = Color3.fromRGB(22,22,30)
    local C_BG3      = Color3.fromRGB(30,30,42)
    local C_Stroke   = Color3.fromRGB(60,55,85)
    local C_StrokeAct= Color3.fromRGB(160,120,255)
    local C_Text     = Color3.fromRGB(235,235,240)

    local function SetActiveTab(activePage)
        for _, def in ipairs(tabDefs) do
            def.page.Visible = (def.page == activePage)
            local btn = tabButtons[def.name]
            if btn then
                local s = btn:FindFirstChildOfClass("UIStroke")
                if def.page == activePage then
                    TweenService:Create(btn, TweenInfo.new(.15), {BackgroundColor3=C_BG3}):Play()
                    if s then TweenService:Create(s, TweenInfo.new(.15), {Color=C_StrokeAct}):Play() end
                else
                    TweenService:Create(btn, TweenInfo.new(.15), {BackgroundColor3=C_BG2}):Play()
                    if s then TweenService:Create(s, TweenInfo.new(.15), {Color=C_Stroke}):Play() end
                end
            end
        end
    end

    for _, def in ipairs(tabDefs) do
        local btn = Instance.new("TextButton", Sidebar)
        btn.BackgroundColor3 = C_BG2
        btn.BorderSizePixel  = 0
        btn.Size             = UDim2.new(1,0,0,36)
        btn.Text             = def.name
        btn.TextColor3       = C_Text
        btn.TextSize         = 16
        btn.Font             = Enum.Font.GothamBold
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
        local bs = Instance.new("UIStroke", btn)
        bs.Color = C_Stroke
        tabButtons[def.name] = btn
        btn.MouseButton1Click:Connect(function()
            SetActiveTab(def.page)
        end)
    end

    do
        local s = tabButtons["Farm"]:FindFirstChildOfClass("UIStroke")
        tabButtons["Farm"].BackgroundColor3 = C_BG3
        if s then s.Color = C_StrokeAct end
    end

    -- =====================
    -- PAGE CONTENTS
    -- =====================
    
    -- FARM PAGE
    MakeSection(FarmPage, "FARM SETTINGS")
    
    -- MASTER TOGGLE: Enable Farm
    MakeToggle(FarmPage, "Enable Farm", _config and _config:Get("FarmEnabled"), function(v)
        if _config then _config:Set("FarmEnabled", v) end
        if not v then
            print("[UI] Farm disabled by user.")
            task.spawn(function() if _webhook then _webhook:SendFarmDisabled() end end)
        else
            print("[UI] Farm enabled. Resuming...")
            task.spawn(function() if _webhook then _webhook:SendFarmResumed() end end)
        end
    end)
    
    -- AUTO PRESTIGE MODE TOGGLE
    MakeToggle(FarmPage, "Auto Prestige Mode", _config and _config:Get("AutoPrestige"), function(v)
        if _config then _config:Set("AutoPrestige", v) end
        print("[UI] Auto Prestige Mode set to " .. tostring(v))
        task.spawn(function()
            if v then
                if _webhook then _webhook:Send("🔄 **Auto Prestige enabled**\nPlayer: `" .. Player.Name .. "`") end
            else
                if _webhook then _webhook:Send("⏸️ **Auto Prestige disabled**\nPlayer: `" .. Player.Name .. "`") end
            end
        end)
    end)
    
    MakeToggle(FarmPage, "Auto Sell", _config and _config:Get("AutoSell"), function(v)
        if _config then _config:Set("AutoSell", v) end
    end)
    MakeToggle(FarmPage, "Auto Buy Lucky", _config and _config:Get("BuyLucky"), function(v)
        if _config then _config:Set("BuyLucky", v) end
    end)
    AutoCanvas(FarmPage)

    -- ITEMS PAGE
    MakeSection(ItemsPage, "SELL ITEMS")
    local itemOrder = { "Gold Coin","Diamond","Rokakaka","Pure Rokakaka","Mysterious Arrow","Lucky Arrow","Lucky Stone Mask","Ancient Scroll","Caesar's Headband","Stone Mask","Rib Cage of The Saint's Corpse","Quinton's Glove","Zeppeli's Hat","Clackers","Steel Ball","Dio's Diary", }
    for _, name in ipairs(itemOrder) do
        local default = _config and _config:GetSellItem(name)
        if default == nil then default = true end
        MakeToggle(ItemsPage, name, default, function(v)
            if _config then _config:SetSellItem(name, v) end
        end)
    end
    AutoCanvas(ItemsPage)

    -- WEBHOOK PAGE
    MakeSection(WebhookPage, "DISCORD WEBHOOK")
    local whHolder = Instance.new("Frame")
    whHolder.Size             = UDim2.new(1,-4,0,42)
    whHolder.BackgroundColor3 = Color3.fromRGB(22,22,30)
    whHolder.BorderSizePixel  = 0
    whHolder.Parent           = WebhookPage
    Instance.new("UICorner", whHolder).CornerRadius = UDim.new(0,7)
    local whStroke = Instance.new("UIStroke", whHolder)
    whStroke.Color = Color3.fromRGB(60,55,85)
    local whBox = Instance.new("TextBox")
    whBox.Size               = UDim2.new(1,-12,1,0)
    whBox.Position           = UDim2.new(0,8,0,0)
    whBox.BackgroundColor3   = Color3.fromRGB(40,40,55)
    whBox.BackgroundTransparency = 0
    whBox.Text               = (_config and _config:Get("WebhookURL")) or ""
    whBox.PlaceholderText    = "https://discord.com/api/webhooks/..."
    whBox.TextColor3         = Color3.fromRGB(255,255,255)
    whBox.PlaceholderColor3  = Color3.fromRGB(160,160,180)
    whBox.TextSize           = 14
    whBox.Font               = Enum.Font.Gotham
    whBox.TextXAlignment     = Enum.TextXAlignment.Left
    whBox.ClearTextOnFocus   = false
    whBox.Parent             = whHolder
    whBox.Focused:Connect(function()
        TweenService:Create(whStroke, TweenInfo.new(0.1), {Color=Color3.fromRGB(120,90,255)}):Play()
        whBox.BackgroundColor3 = Color3.fromRGB(55,55,75)
    end)
    whBox.FocusLost:Connect(function()
        if _config then _config:Set("WebhookURL", whBox.Text) end
        TweenService:Create(whStroke, TweenInfo.new(0.1), {Color=Color3.fromRGB(60,55,85)}):Play()
        whBox.BackgroundColor3 = Color3.fromRGB(40,40,55)
    end)
    
    -- Reset Webhook Flags Button
    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1,-4,0,36)
    resetBtn.Position = UDim2.new(0,0,0,50)
    resetBtn.BackgroundColor3 = Color3.fromRGB(88,101,242)
    resetBtn.BorderSizePixel = 0
    resetBtn.Text = "🔄 Reset Webhook Flags"
    resetBtn.TextColor3 = Color3.fromRGB(255,255,255)
    resetBtn.TextScaled = true
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.Parent = WebhookPage
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke", resetBtn).Color = Color3.fromRGB(60,70,200)
    resetBtn.MouseButton1Click:Connect(function()
        if _config then
            _config:Set("Phase1Notified", false)
            _config:Set("Phase3Notified", false)
            print("[UI] Webhook flags reset.")
            task.spawn(function()
                if _webhook then
                    _webhook:Send("🔄 **Webhook flags reset**\nPlayer: `" .. Player.Name .. "`\nPhase1 and Phase3 notifications will be re‑sent on next completion.")
                end
            end)
        end
    end)
    resetBtn.MouseEnter:Connect(function()
        TweenService:Create(resetBtn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(110,125,255)}):Play()
    end)
    resetBtn.MouseLeave:Connect(function()
        TweenService:Create(resetBtn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(88,101,242)}):Play()
    end)
    
    AutoCanvas(WebhookPage)

    -- CREDITS PAGE
    MakeSection(CreditsPage, "WHITE HUB")
    local creditLabel = Instance.new("TextLabel")
    creditLabel.Size             = UDim2.new(1,-4,0,44)
    creditLabel.BackgroundColor3 = Color3.fromRGB(22,22,30)
    creditLabel.BorderSizePixel  = 0
    creditLabel.Text             = "Made by WHITE DRAGON"
    creditLabel.TextColor3       = Color3.fromRGB(235,235,240)
    creditLabel.TextScaled       = true
    creditLabel.Font             = Enum.Font.GothamBold
    creditLabel.Parent           = CreditsPage
    Instance.new("UICorner", creditLabel).CornerRadius = UDim.new(0,7)
    local creditStroke = Instance.new("UIStroke", creditLabel)
    creditStroke.Color = Color3.fromRGB(60,55,85)
    local discordBtn = Instance.new("TextButton")
    discordBtn.Size             = UDim2.new(1,-4,0,36)
    discordBtn.BackgroundColor3 = Color3.fromRGB(88,101,242)
    discordBtn.BorderSizePixel  = 0
    discordBtn.Text             = "🔗 discord.gg/Qwd23ZRNxJ  —  Click to Copy"
    discordBtn.TextColor3       = Color3.fromRGB(255,255,255)
    discordBtn.TextScaled       = true
    discordBtn.Font             = Enum.Font.GothamBold
    discordBtn.Parent           = CreditsPage
    Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0,7)
    Instance.new("UIStroke", discordBtn).Color = Color3.fromRGB(60,70,200)
    discordBtn.MouseEnter:Connect(function()
        TweenService:Create(discordBtn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(110,125,255)}):Play()
    end)
    discordBtn.MouseLeave:Connect(function()
        TweenService:Create(discordBtn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(88,101,242)}):Play()
    end)
    discordBtn.MouseButton1Click:Connect(function()
        pcall(function() setclipboard("https://discord.gg/Qwd23ZRNxJ") end)
        local orig = discordBtn.Text
        discordBtn.Text = "✅ Copied!"
        TweenService:Create(discordBtn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(50,180,80)}):Play()
        task.delay(2, function()
            discordBtn.Text = orig
            TweenService:Create(discordBtn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(88,101,242)}):Play()
        end)
    end)
    AutoCanvas(CreditsPage)

    -- =====================
    -- TOGGLE BUTTON (open/close)
    -- =====================
    local ToggleBtn = Instance.new("TextButton", ScreenGui)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(22,22,30)
    ToggleBtn.BorderSizePixel  = 0
    ToggleBtn.Position         = UDim2.new(0,8,1,-280)
    ToggleBtn.Size             = UDim2.new(0,110,0,32)
    ToggleBtn.Text             = "⚡ WHITE HUB"
    ToggleBtn.TextColor3       = Color3.fromRGB(235,235,240)
    ToggleBtn.TextSize         = 14
    ToggleBtn.Font             = Enum.Font.GothamBold
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0,6)
    local tStroke = Instance.new("UIStroke", ToggleBtn)
    tStroke.Color     = Color3.fromRGB(60,55,85)
    tStroke.Thickness = 1.3

    ToggleBtn.MouseEnter:Connect(function()
        TweenService:Create(tStroke, TweenInfo.new(0.15), {Color=Color3.fromRGB(120,90,255)}):Play()
    end)
    ToggleBtn.MouseLeave:Connect(function()
        TweenService:Create(tStroke, TweenInfo.new(0.15), {Color=Color3.fromRGB(60,55,85)}):Play()
    end)

    local isOpen = false
    local function ToggleWindow()
        isOpen = not isOpen
        if isOpen then
            MainFrame.Visible = true
            MainFrame.Size = UDim2.new(0,0,0,0)
            MainFrame.Position = UDim2.new(0.5,0,0.5,0)
            TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                Size = UDim2.new(0,W,0,H),
                Position = UDim2.new(0.5,-W/2,0.5,-H/2),
            }):Play()
        else
            local t = TweenService:Create(MainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Size = UDim2.new(0,0,0,0),
                Position = UDim2.new(0.5,0,0.5,0),
            })
            t:Play()
            t.Completed:Connect(function() MainFrame.Visible = false end)
        end
    end

    ToggleBtn.MouseButton1Click:Connect(ToggleWindow)
    CloseButton.MouseButton1Click:Connect(function() if isOpen then ToggleWindow() end end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightAlt then ToggleWindow()
        elseif input.KeyCode == Enum.KeyCode.RightControl then
            ToggleBtn.Visible = not ToggleBtn.Visible
        end
    end)

    local dragging, dragStart, startPos = false, nil, nil
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

function UI:Notify(msg) print("[UI] " .. tostring(msg)) end
function UI:SetVisible(value) end

return UI
