-- =====================
-- UI.lua (WHITE HUB V2)
-- Full English, dynamic NPC list, dropdown auto-close on selection.
-- =====================

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService      = game:GetService("TextService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local UI = {}

local _config      = nil
local _webhook     = nil
local _combatFarm  = nil
local _runtimeLog   = nil

local toggleObjects = {}
local dropdownContainer = nil
local mainScreenGui = nil
local uiConnections = {}
local activeSkillCapture = nil

local function trackConnection(connection)
    if connection then table.insert(uiConnections, connection) end
    return connection
end

-- Dynamic NPC list (unique names)
local dynamicNPCList = {}
local npcDropdownRefresh = nil

function UI:Init(Modules)
    _config      = Modules.Config
    _webhook     = Modules.Webhook
    _combatFarm  = Modules.CombatFarm
    _runtimeLog  = Modules.RuntimeLog
end

local function runtimeLog(level, message)
    if _runtimeLog and type(_runtimeLog.Write) == "function" then
        pcall(_runtimeLog.Write, _runtimeLog, level, "UI", message)
    end
end

local function copyToClipboard(text)
    if type(setclipboard) == "function" then
        local ok = pcall(setclipboard, text)
        if ok then return true end
    end
    if type(toclipboard) == "function" then
        local ok = pcall(toclipboard, text)
        if ok then return true end
    end
    if Clipboard and type(Clipboard.set) == "function" then
        local ok = pcall(function() Clipboard.set(text) end)
        if ok then return true end
    end
    return false
end

-- =====================
-- CREDITS POPUP
-- =====================
local function CreateCreditsPopup()
    local gui = Instance.new("ScreenGui")
    gui.Name         = "WhiteHubCreditsPopup"
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

    local state = { enabled = (default == nil) and true or default }

    local track = Instance.new("TextButton")
    track.Size             = UDim2.new(0,44,0,22)
    track.Position         = UDim2.new(1,-52,0.5,-11)
    track.BackgroundColor3 = state.enabled and Color3.fromRGB(145,95,255) or Color3.fromRGB(30,30,42)
    track.Text             = ""
    track.BorderSizePixel  = 0
    track.Parent           = holder
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)

    local circle = Instance.new("Frame")
    circle.Size             = UDim2.new(0,15,0,15)
    circle.Position         = state.enabled and UDim2.new(1,-18,0.5,-7.5) or UDim2.new(0,3,0.5,-7.5)
    circle.BackgroundColor3 = Color3.fromRGB(255,255,255)
    circle.BorderSizePixel  = 0
    circle.Parent           = track
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)

    local function render(animated)
        local bg = state.enabled and Color3.fromRGB(145,95,255) or Color3.fromRGB(30,30,42)
        local pos = state.enabled and UDim2.new(1,-18,0.5,-7.5) or UDim2.new(0,3,0.5,-7.5)
        if animated then
            TweenService:Create(track, TweenInfo.new(0.18), {BackgroundColor3 = bg}):Play()
            TweenService:Create(circle, TweenInfo.new(0.18), {Position = pos}):Play()
        else
            track.BackgroundColor3 = bg
            circle.Position = pos
        end
    end

    track.MouseButton1Click:Connect(function()
        state.enabled = not state.enabled
        render(true)
        onChanged(state.enabled)
    end)

    toggleObjects[labelText] = {
        holder = holder,
        track = track,
        circle = circle,
        state = state,
        render = render,
    }
end

function UI:AddLabel(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-4,0,24)
    lbl.Position = UDim2.new(0,2,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(235,235,240)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

local function ensureDropdownContainer()
    if not dropdownContainer or not dropdownContainer.Parent then
        dropdownContainer = Instance.new("ScreenGui")
        dropdownContainer.Name = "DropdownContainer"
        dropdownContainer.ResetOnSpawn = false
        dropdownContainer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        dropdownContainer.Parent = PlayerGui
    end
    return dropdownContainer
end

-- Styled dropdown with auto-close on selection (versão corrigida)
local function MakeStyledDropdown(parent, labelText, options, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1,-4,0,36)
    holder.BackgroundColor3 = Color3.fromRGB(22,22,30)
    holder.BorderSizePixel = 0
    holder.Parent = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0,7)
    local stroke = Instance.new("UIStroke", holder)
    stroke.Color = Color3.fromRGB(60,55,85)
    stroke.Thickness = 1.2

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5,0,1,0)
    lbl.Position = UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(235,235,240)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder

    local dropdownBtn = Instance.new("TextButton")
    dropdownBtn.Size = UDim2.new(0.45,0,1,0)
    dropdownBtn.Position = UDim2.new(0.5,0,0,0)
    dropdownBtn.BackgroundColor3 = Color3.fromRGB(40,40,55)
    dropdownBtn.BorderSizePixel = 0
    dropdownBtn.Text = options[1] or "None"
    dropdownBtn.TextColor3 = Color3.fromRGB(255,255,255)
    dropdownBtn.TextSize = 14
    dropdownBtn.Font = Enum.Font.Gotham
    dropdownBtn.Parent = holder
    Instance.new("UICorner", dropdownBtn).CornerRadius = UDim.new(0,7)
    local btnStroke = Instance.new("UIStroke", dropdownBtn)
    btnStroke.Color = Color3.fromRGB(80,70,140)
    btnStroke.Thickness = 1.2

    local currentOptions = options
    local menu = nil
    local outsideConnection = nil

    local function hideMenu()
        if outsideConnection then
            outsideConnection:Disconnect()
            outsideConnection = nil
        end
        if menu then
            menu:Destroy()
            menu = nil
        end
    end

    local function showMenu()
        hideMenu()
        local container = ensureDropdownContainer()
        menu = Instance.new("ScrollingFrame")
        menu.BackgroundColor3 = Color3.fromRGB(30,30,42)
        menu.BorderSizePixel = 0
        menu.ScrollBarThickness = 5
        menu.ZIndex = 20
        menu.Parent = container
        Instance.new("UICorner", menu).CornerRadius = UDim.new(0,7)
        local menuStroke = Instance.new("UIStroke", menu)
        menuStroke.Color = Color3.fromRGB(145,95,255)
        menuStroke.Thickness = 1.2

        local menuLayout = Instance.new("UIListLayout", menu)
        menuLayout.Padding = UDim.new(0,2)

        for _, opt in ipairs(currentOptions) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1,-5,0,30)
            btn.BackgroundColor3 = Color3.fromRGB(40,40,55)
            btn.Text = opt
            btn.TextColor3 = Color3.fromRGB(255,255,255)
            btn.TextSize = 14
            btn.Font = Enum.Font.Gotham
            btn.ZIndex = 21
            btn.Parent = menu
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0,4)
            btn.MouseButton1Click:Connect(function()
                dropdownBtn.Text = opt
                callback(opt)
                hideMenu()
            end)
        end

        local count = #currentOptions
        local height = math.min(math.max(count, 1) * 32, 150)
        menu.Size = UDim2.new(0, 200, 0, height)
        menu.CanvasSize = UDim2.new(0,0,0,count * 32)
        local btnAbsPos = dropdownBtn.AbsolutePosition
        local btnSize = dropdownBtn.AbsoluteSize
        menu.Position = UDim2.new(0, btnAbsPos.X, 0, btnAbsPos.Y + btnSize.Y)

        outsideConnection = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            task.wait()
            if not menu then return end
            local mousePos = UserInputService:GetMouseLocation()
            local p, s = menu.AbsolutePosition, menu.AbsoluteSize
            if mousePos.X < p.X or mousePos.X > p.X + s.X or mousePos.Y < p.Y or mousePos.Y > p.Y + s.Y then
                hideMenu()
            end
        end)
    end

    dropdownBtn.MouseButton1Click:Connect(function()
        if menu then hideMenu() else showMenu() end
    end)

    return dropdownBtn, function(newOptions)
        hideMenu()
        currentOptions = newOptions or {}
        if #currentOptions == 0 then
            dropdownBtn.Text = "None"
        elseif not table.find(currentOptions, dropdownBtn.Text) then
            dropdownBtn.Text = currentOptions[1]
        end
    end
end

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

function UI:SetToggleValue(toggleName, value)
    local toggle = toggleObjects[toggleName]
    if toggle then
        toggle.state.enabled = value == true
        toggle.render(false)
        return true
    end
    warn("[UI] Toggle not found: " .. toggleName)
    return false
end

-- =====================
-- DYNAMIC NPC DETECTION (unique names, Xenon V5 style)
-- =====================
local function updateNPCList()
    local uniqueNames = {}
    local living = workspace:FindFirstChild("Living")
    if not living then
        dynamicNPCList = {}
        return dynamicNPCList
    end
    for _, obj in pairs(living:GetChildren()) do
        if obj:FindFirstChild("Spawn") then
            uniqueNames[obj.Name] = true
        end
    end
    local newList = {}
    for name in pairs(uniqueNames) do
        table.insert(newList, name)
    end
    table.sort(newList)
    dynamicNPCList = newList
    return newList
end

function UI:Create()
    self:Destroy()
    toggleObjects = {}

    for _, guiName in ipairs({"WhiteHubV3", "DropdownContainer", "WhiteHubCreditsPopup"}) do
        local old = PlayerGui:FindFirstChild(guiName)
        if old then old:Destroy() end
    end

    CreateCreditsPopup()

    -- Initial NPC scan
    updateNPCList()
    local living = workspace:FindFirstChild("Living")
    if living then
        trackConnection(living.ChildAdded:Connect(function(child)
            if child:FindFirstChild("Spawn") then
                updateNPCList()
                if npcDropdownRefresh then npcDropdownRefresh(dynamicNPCList) end
            end
        end))
        trackConnection(living.ChildRemoved:Connect(function()
            updateNPCList()
            if npcDropdownRefresh then npcDropdownRefresh(dynamicNPCList) end
        end))
    end

    local W, H = 380, 320

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "WhiteHubV3"
    mainScreenGui = ScreenGui
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
    local QuestPage   = MakePage("QuestPage")
    local WebhookPage = MakePage("WebhookPage")
    local ConsolePage = MakePage("ConsolePage")
    local CreditsPage = MakePage("CreditsPage")
    FarmPage.Visible = true

    local tabDefs = {
        { name="Farm",    page=FarmPage    },
        { name="Items",   page=ItemsPage   },
        { name="Quests/NPCs", page=QuestPage },
        { name="Webhook", page=WebhookPage },
        { name="Console", page=ConsolePage },
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
    -- FARM PAGE
    -- =====================
    MakeSection(FarmPage, "FARM SETTINGS")
    
    MakeToggle(FarmPage, "Enable Farm", _config and _config:Get("FarmEnabled"), function(v)
        if _config then _config:Set("FarmEnabled", v) end
        if not v then
            print("[UI] Farm disabled by user.")
            runtimeLog("INFO", "Farm disabled by user.")
            if _webhook then _webhook:SendFarmDisabled() end
        else
            print("[UI] Farm enabled. Resuming...")
            runtimeLog("INFO", "Farm enabled by user.")
            if _webhook then _webhook:SendFarmResumed() end
        end
    end)
    
    MakeToggle(FarmPage, "Auto Sell", _config and _config:Get("AutoSell"), function(v)
        if _config then _config:Set("AutoSell", v) end
    end)
    MakeToggle(FarmPage, "Fast Sell (Hidden Dialogue)", _config and _config:Get("FastSellHidden"), function(v)
        if _config then _config:Set("FastSellHidden", v) end
        runtimeLog("INFO", "Fast Sell (Hidden Dialogue) = " .. tostring(v))
    end)
    MakeToggle(FarmPage, "Auto Buy Lucky", _config and _config:Get("BuyLucky"), function(v)
        if _config then _config:Set("BuyLucky", v) end
    end)

    MakeToggle(FarmPage, "Stay in Private Server", _config and _config:Get("StayInPrivateServer"), function(v)
        if _config then _config:Set("StayInPrivateServer", v) end
        print("[UI] Stay in Private Server set to " .. tostring(v))
        runtimeLog("INFO", "Stay in Private Server = " .. tostring(v))
    end)

    MakeSection(FarmPage, "PRESTIGE")
    MakeToggle(FarmPage, "Auto Prestige", _config and _config:Get("AutoPrestige"), function(v)
        if _config then
            if v then
                _config:SetMany({ AutoPrestige = true, QuestFarmEnabled = false, NPCFarmEnabled = false })
            else
                _config:Set("AutoPrestige", false)
            end
        end
        getgenv().AutoPrestigeEnabled = v
        if v then
            UI:SetToggleValue("Quest Farm", false)
            UI:SetToggleValue("NPC Farm", false)
            if _combatFarm then _combatFarm:Stop() end
            print("[UI] Auto Prestige enabled.")
            runtimeLog("INFO", "Auto Prestige enabled.")
        else
            print("[UI] Auto Prestige disabled.")
            runtimeLog("INFO", "Auto Prestige disabled.")
        end
    end)

    AutoCanvas(FarmPage)

    -- =====================
    -- ITEMS PAGE
    -- =====================
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

    -- =====================
    -- QUESTS & NPCS TAB
    -- =====================
    MakeSection(QuestPage, "QUEST FARM")
    
    MakeToggle(QuestPage, "Auto Choose Quest", _config and _config:Get("AutoChooseQuest"), function(v)
        if _config then _config:Set("AutoChooseQuest", v) end
        print("[UI] Auto Choose Quest set to " .. tostring(v))
        runtimeLog("INFO", "Auto Choose Quest = " .. tostring(v))
    end)
    
    local questList = {
        "Officer Sam [Lvl. 1+]",
        "Deputy Bertrude [Lvl. 10+]",
        "Homeless Man Jill [Lvl. 15+]",
        "Dracula [Lvl. 20+]",
        "William Zeppeli [Lvl. 25+]",
        "Doppio [Lvl. 30+]",
        "Dio [Lvl. 35+]"
    }
    local questDropdown = MakeStyledDropdown(QuestPage, "Select Quest", questList, function(selected)
        if _config then _config:Set("SelectedQuest", selected) end
    end)
    local savedQuest = _config and _config:Get("SelectedQuest")
    if savedQuest and savedQuest ~= "" and table.find(questList, savedQuest) then
        questDropdown.Text = savedQuest
    end
    
    -- Quest/NPC are mutually exclusive and CombatFarm enforces one worker.
    MakeToggle(QuestPage, "Quest Farm", _config and _config:Get("QuestFarmEnabled"), function(v)
        if _config then
            if v then
                _config:SetMany({ QuestFarmEnabled = true, NPCFarmEnabled = false, AutoPrestige = false })
            else
                _config:Set("QuestFarmEnabled", false)
            end
        end
        if v then
            getgenv().AutoPrestigeEnabled = false
            UI:SetToggleValue("NPC Farm", false)
            UI:SetToggleValue("Auto Prestige", false)
            runtimeLog("INFO", "Quest Farm enabled.")
            if _combatFarm then _combatFarm:StartQuest() end
        else
            local running, mode = _combatFarm and _combatFarm:IsRunning()
            runtimeLog("INFO", "Quest Farm disabled.")
            if running and mode == "Quest" then _combatFarm:Stop() end
        end
    end)
    
    MakeSection(QuestPage, "NPC FARM")
    
    -- Dynamic NPC dropdown (unique names) with refresh support
    local npcBtn, npcRefresh = MakeStyledDropdown(QuestPage, "Select NPC", dynamicNPCList, function(selected)
        if _config then _config:Set("SelectedNPC", selected) end
    end)
    npcDropdownRefresh = npcRefresh
    local savedNPC = _config and _config:Get("SelectedNPC")
    if savedNPC and savedNPC ~= "" and table.find(dynamicNPCList, savedNPC) then
        npcBtn.Text = savedNPC
    end
    
    MakeToggle(QuestPage, "NPC Farm", _config and _config:Get("NPCFarmEnabled"), function(v)
        if _config then
            if v then
                _config:SetMany({ NPCFarmEnabled = true, QuestFarmEnabled = false, AutoPrestige = false })
            else
                _config:Set("NPCFarmEnabled", false)
            end
        end
        if v then
            getgenv().AutoPrestigeEnabled = false
            UI:SetToggleValue("Quest Farm", false)
            UI:SetToggleValue("Auto Prestige", false)
            runtimeLog("INFO", "NPC Farm enabled.")
            if _combatFarm then _combatFarm:StartNPC() end
        else
            local running, mode = _combatFarm and _combatFarm:IsRunning()
            runtimeLog("INFO", "NPC Farm disabled.")
            if running and mode == "NPC" then _combatFarm:Stop() end
        end
    end)
    
    MakeSection(QuestPage, "AUTO SKILLS")
    local skillsLabel = UI:AddLabel(QuestPage, "Skills: None")
    
    local function updateSkillsLabel()
        local skills = _config:Get("AutoSkills") or {}
        local text = #skills > 0 and "Skills: " .. table.concat(skills, ", ") or "Skills: None"
        skillsLabel.Text = text
    end
    updateSkillsLabel()
    
    MakeToggle(QuestPage, "Add Skill (press a key)", false, function(v)
        if activeSkillCapture then
            activeSkillCapture:Disconnect()
            activeSkillCapture = nil
        end
        if not v then return end

        activeSkillCapture = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            local key = input.KeyCode.Name
            if key and key ~= "Unknown" then
                local current = _config:Get("AutoSkills") or {}
                if not table.find(current, key) then
                    table.insert(current, key)
                    _config:Set("AutoSkills", current)
                    updateSkillsLabel()
                end
                if activeSkillCapture then
                    activeSkillCapture:Disconnect()
                    activeSkillCapture = nil
                end
                UI:SetToggleValue("Add Skill (press a key)", false)
            end
        end)
    end)
    
    MakeToggle(QuestPage, "Clear Skills", false, function(v)
        if v then
            _config:Set("AutoSkills", {})
            updateSkillsLabel()
            UI:SetToggleValue("Clear Skills", false)
        end
    end)
    
    AutoCanvas(QuestPage)

    -- =====================
    -- WEBHOOK PAGE
    -- =====================
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
            runtimeLog("INFO", "Webhook notification flags reset.")
            if _webhook then
                _webhook:Send("🔄 **Webhook flags reset**\nPlayer: `" .. Player.Name .. "`\nPhase1 and Phase3 notifications will be re‑sent on next completion.")
            end
        end
    end)
    resetBtn.MouseEnter:Connect(function()
        TweenService:Create(resetBtn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(110,125,255)}):Play()
    end)
    resetBtn.MouseLeave:Connect(function()
        TweenService:Create(resetBtn, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(88,101,242)}):Play()
    end)

    AutoCanvas(WebhookPage)

    -- =====================
    -- RUNTIME CONSOLE PAGE
    -- =====================
    MakeSection(ConsolePage, "RUNTIME CONSOLE")

    local consoleStatus = Instance.new("TextLabel")
    consoleStatus.Size = UDim2.new(1,-4,0,28)
    consoleStatus.BackgroundColor3 = Color3.fromRGB(22,22,30)
    consoleStatus.BorderSizePixel = 0
    consoleStatus.TextColor3 = Color3.fromRGB(200,200,215)
    consoleStatus.TextSize = 12
    consoleStatus.Font = Enum.Font.Gotham
    consoleStatus.TextXAlignment = Enum.TextXAlignment.Left
    consoleStatus.Text = " Runtime log unavailable"
    consoleStatus.Parent = ConsolePage
    Instance.new("UICorner", consoleStatus).CornerRadius = UDim.new(0,6)

    local consoleHolder = Instance.new("Frame")
    consoleHolder.Size = UDim2.new(1,-4,0,150)
    consoleHolder.BackgroundColor3 = Color3.fromRGB(12,12,17)
    consoleHolder.BorderSizePixel = 0
    consoleHolder.Parent = ConsolePage
    Instance.new("UICorner", consoleHolder).CornerRadius = UDim.new(0,7)
    local consoleStroke = Instance.new("UIStroke", consoleHolder)
    consoleStroke.Color = Color3.fromRGB(60,55,85)

    local logScroll = Instance.new("ScrollingFrame")
    logScroll.Size = UDim2.new(1,-8,1,-8)
    logScroll.Position = UDim2.new(0,4,0,4)
    logScroll.BackgroundTransparency = 1
    logScroll.BorderSizePixel = 0
    logScroll.ScrollBarThickness = 4
    logScroll.ScrollBarImageColor3 = Color3.fromRGB(140,90,255)
    logScroll.CanvasSize = UDim2.new(0,0,0,0)
    logScroll.Parent = consoleHolder

    local logLabel = Instance.new("TextLabel")
    logLabel.Size = UDim2.new(1,-8,0,20)
    logLabel.Position = UDim2.new(0,4,0,0)
    logLabel.BackgroundTransparency = 1
    logLabel.TextColor3 = Color3.fromRGB(215,215,225)
    logLabel.TextSize = 11
    logLabel.Font = Enum.Font.Code
    logLabel.TextXAlignment = Enum.TextXAlignment.Left
    logLabel.TextYAlignment = Enum.TextYAlignment.Top
    logLabel.TextWrapped = true
    logLabel.Text = "No runtime entries yet."
    logLabel.Parent = logScroll

    local consoleButtons = Instance.new("Frame")
    consoleButtons.Size = UDim2.new(1,-4,0,34)
    consoleButtons.BackgroundTransparency = 1
    consoleButtons.Parent = ConsolePage

    local copyLogBtn = Instance.new("TextButton")
    copyLogBtn.Size = UDim2.new(0.64,-2,1,0)
    copyLogBtn.BackgroundColor3 = Color3.fromRGB(115,72,190)
    copyLogBtn.BorderSizePixel = 0
    copyLogBtn.Text = "Copy Log"
    copyLogBtn.TextColor3 = Color3.fromRGB(255,255,255)
    copyLogBtn.TextSize = 13
    copyLogBtn.Font = Enum.Font.GothamBold
    copyLogBtn.Parent = consoleButtons
    Instance.new("UICorner", copyLogBtn).CornerRadius = UDim.new(0,7)

    local clearLogBtn = Instance.new("TextButton")
    clearLogBtn.Size = UDim2.new(0.36,-2,1,0)
    clearLogBtn.Position = UDim2.new(0.64,4,0,0)
    clearLogBtn.BackgroundColor3 = Color3.fromRGB(45,45,60)
    clearLogBtn.BorderSizePixel = 0
    clearLogBtn.Text = "Clear"
    clearLogBtn.TextColor3 = Color3.fromRGB(235,235,240)
    clearLogBtn.TextSize = 13
    clearLogBtn.Font = Enum.Font.GothamBold
    clearLogBtn.Parent = consoleButtons
    Instance.new("UICorner", clearLogBtn).CornerRadius = UDim.new(0,7)

    local function refreshConsole()
        if not _runtimeLog then
            consoleStatus.Text = " Runtime log unavailable"
            logLabel.Text = "RuntimeLog was not provided by Main.lua."
            return
        end

        local stats = _runtimeLog:GetStats()
        local lastIssue = _runtimeLog:GetLastError()
        consoleStatus.Text = (" INFO %d   WARN %d   ERROR %d"):format(stats.INFO, stats.WARN, stats.ERROR)
        if lastIssue then
            consoleStatus.Text = consoleStatus.Text .. "   | Last: " .. tostring(lastIssue.Module)
        end

        local text = _runtimeLog:GetText()
        logLabel.Text = text

        task.defer(function()
            if not logScroll.Parent then return end
            local width = math.max(120, logScroll.AbsoluteSize.X - 12)
            local ok, bounds = pcall(function()
                return TextService:GetTextSize(text, 11, Enum.Font.Code, Vector2.new(width, 100000))
            end)
            local height = ok and math.max(20, bounds.Y + 10) or math.max(20, (#text / 45) * 14)
            logLabel.Size = UDim2.new(1,-8,0,height)
            logScroll.CanvasSize = UDim2.new(0,0,0,height + 6)
            logScroll.CanvasPosition = Vector2.new(0, math.max(0, height - logScroll.AbsoluteSize.Y))
        end)
    end

    copyLogBtn.MouseButton1Click:Connect(function()
        local text = _runtimeLog and _runtimeLog:GetText() or "WHITE HUB V3 - RuntimeLog unavailable"
        if copyToClipboard(text) then
            copyLogBtn.Text = "Copied!"
            runtimeLog("INFO", "Runtime log copied to clipboard.")
        else
            copyLogBtn.Text = "No clipboard API"
            runtimeLog("WARN", "Clipboard API unavailable; runtime log printed to console.")
            print(text)
        end
        task.delay(2, function()
            if copyLogBtn and copyLogBtn.Parent then copyLogBtn.Text = "Copy Log" end
        end)
    end)

    clearLogBtn.MouseButton1Click:Connect(function()
        if _runtimeLog then _runtimeLog:Clear() end
        refreshConsole()
    end)

    if _runtimeLog and type(_runtimeLog.Subscribe) == "function" then
        local consoleRefreshPending = false
        trackConnection(_runtimeLog:Subscribe(function()
            if consoleRefreshPending then return end
            consoleRefreshPending = true
            task.delay(0.15, function()
                consoleRefreshPending = false
                if logLabel and logLabel.Parent then
                    refreshConsole()
                end
            end)
        end))
    end

    refreshConsole()
    AutoCanvas(ConsolePage)

    -- =====================
    -- CREDITS PAGE
    -- =====================
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
    -- TOGGLE BUTTON
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

    trackConnection(UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightAlt then ToggleWindow()
        elseif input.KeyCode == Enum.KeyCode.RightControl then
            ToggleBtn.Visible = not ToggleBtn.Visible
        end
    end))

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
    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))

    -- Restore a persisted combat mode, resolving old configs that had both enabled.
    if _config then
        if _config:Get("QuestFarmEnabled") then
            _config:Set("NPCFarmEnabled", false)
            UI:SetToggleValue("NPC Farm", false)
            if _combatFarm then _combatFarm:StartQuest() end
        elseif _config:Get("NPCFarmEnabled") then
            if _combatFarm then _combatFarm:StartNPC() end
        end
    end
end

function UI:Notify(msg) print("[UI] " .. tostring(msg)) end

function UI:SetVisible(value)
    if mainScreenGui then
        mainScreenGui.Enabled = value == true
    end
end

function UI:Destroy()
    if activeSkillCapture then
        pcall(function() activeSkillCapture:Disconnect() end)
        activeSkillCapture = nil
    end
    for _, connection in ipairs(uiConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(uiConnections)
    if dropdownContainer then
        pcall(function() dropdownContainer:Destroy() end)
        dropdownContainer = nil
    end
    if mainScreenGui then
        pcall(function() mainScreenGui:Destroy() end)
        mainScreenGui = nil
    end
    toggleObjects = {}
end

return UI
