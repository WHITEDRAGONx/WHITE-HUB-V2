-- =====================
-- UI.lua (Manual UI exportada do Studio com todos os scripts)
-- =====================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local UI = {}

function UI:Create()
    -- ========== ESTRUTURA VISUAL GERADA PELO HIERARCHY SAVER ==========
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = PlayerGui

    local MainFrame = Instance.new("Frame", ScreenGui)
    MainFrame.Name = "MainFrame"
    MainFrame.BackgroundColor3 = Color3.new(0.059,0.059,0.078)
    MainFrame.BorderColor3 = Color3.new(0,0,0)
    MainFrame.BorderSizePixel = 0
    MainFrame.Position = UDim2.new(0.5,-250,0.5,-160)
    MainFrame.Size = UDim2.new(0,500,0,320)
    MainFrame.Visible = false

    local UICorner = Instance.new("UICorner", MainFrame)
    UICorner.CornerRadius = UDim.new(0,12)
    local UIStroke = Instance.new("UIStroke", MainFrame)
    UIStroke.Color = Color3.new(0.235,0.216,0.333)
    UIStroke.Thickness = 1.5

    local TopBar = Instance.new("Frame", MainFrame)
    TopBar.Name = "TopBar"
    TopBar.BackgroundColor3 = Color3.new(0.086,0.086,0.118)
    TopBar.BorderColor3 = Color3.new(0,0,0)
    TopBar.BorderSizePixel = 0
    TopBar.Size = UDim2.new(1,0,0,40)

    local TopFix = Instance.new("Frame", TopBar)
    TopFix.Name = "TopFix"
    TopFix.BackgroundColor3 = Color3.new(0.086,0.086,0.118)
    TopFix.BorderColor3 = Color3.new(0,0,0)
    TopFix.BorderSizePixel = 0
    TopFix.Position = UDim2.new(0,0,0.5,0)
    TopFix.Size = UDim2.new(1,0,0.5,0)

    local Title = Instance.new("TextLabel", TopBar)
    Title.Name = "Title"
    Title.BackgroundColor3 = Color3.new(1,1,1)
    Title.BackgroundTransparency = 1
    Title.BorderColor3 = Color3.new(0,0,0)
    Title.BorderSizePixel = 0
    Title.FontFace = Font.new("rbxassetid://16658221428",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
    Title.Position = UDim2.new(0,12,0,0)
    Title.Size = UDim2.new(1,-50,1,0)
    Title.Text = "⚡ WHITE HUB"
    Title.TextColor3 = Color3.new(1,1,1)
    Title.TextSize = 24
    Title.TextWrapped = true
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local CloseButton = Instance.new("TextButton", TopBar)
    CloseButton.Name = "CloseButton"
    CloseButton.BackgroundColor3 = Color3.new(0.706,0.196,0.196)
    CloseButton.BorderColor3 = Color3.new(0,0,0)
    CloseButton.BorderSizePixel = 0
    CloseButton.FontFace = Font.new("rbxassetid://16658221428",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
    CloseButton.Position = UDim2.new(1,-30,0.5,-11)
    CloseButton.Size = UDim2.new(0,22,0,22)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.new(1,1,1)
    CloseButton.TextSize = 16

    local UICorner_2 = Instance.new("UICorner", CloseButton)
    UICorner_2.CornerRadius = UDim.new(1,0)

    local Sidebar = Instance.new("Frame", MainFrame)
    Sidebar.Name = "Sidebar"
    Sidebar.BackgroundColor3 = Color3.new(1,1,1)
    Sidebar.BackgroundTransparency = 1
    Sidebar.BorderColor3 = Color3.new(0,0,0)
    Sidebar.BorderSizePixel = 0
    Sidebar.Position = UDim2.new(0,8,0,42)
    Sidebar.Size = UDim2.new(0,95,1,-50)

    local UIListLayout = Instance.new("UIListLayout", Sidebar)
    UIListLayout.Padding = UDim.new(0,5)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local FarmButton = Instance.new("TextButton", Sidebar)
    FarmButton.Name = "FarmButton"
    FarmButton.BackgroundColor3 = Color3.new(0.086,0.086,0.118)
    FarmButton.BorderColor3 = Color3.new(0,0,0)
    FarmButton.BorderSizePixel = 0
    FarmButton.FontFace = Font.new("rbxassetid://16658221428",Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
    FarmButton.Size = UDim2.new(1,0,0,32)
    FarmButton.Text = "Farm"
    FarmButton.TextColor3 = Color3.new(0.922,0.922,0.941)
    FarmButton.TextSize = 18

    local UICorner_3 = Instance.new("UICorner", FarmButton)
    local UIStroke_1 = Instance.new("UIStroke", FarmButton)
    UIStroke_1.Color = Color3.new(0.235,0.216,0.333)

    local ItemsButton = Instance.new("TextButton", Sidebar)
    ItemsButton.Name = "ItemsButton"
    ItemsButton.BackgroundColor3 = Color3.new(0.086,0.086,0.118)
    ItemsButton.BorderColor3 = Color3.new(0,0,0)
    ItemsButton.BorderSizePixel = 0
    ItemsButton.FontFace = Font.new("rbxassetid://16658221428",Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
    ItemsButton.Size = UDim2.new(1,0,0,32)
    ItemsButton.Text = "Items"
    ItemsButton.TextColor3 = Color3.new(0.922,0.922,0.941)
    ItemsButton.TextSize = 18

    local UICorner_4 = Instance.new("UICorner", ItemsButton)
    local UIStroke_2 = Instance.new("UIStroke", ItemsButton)
    UIStroke_2.Color = Color3.new(0.235,0.216,0.333)

    local WebhookButton = Instance.new("TextButton", Sidebar)
    WebhookButton.Name = "WebhookButton"
    WebhookButton.BackgroundColor3 = Color3.new(0.086,0.086,0.118)
    WebhookButton.BorderColor3 = Color3.new(0,0,0)
    WebhookButton.BorderSizePixel = 0
    WebhookButton.FontFace = Font.new("rbxassetid://16658221428",Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
    WebhookButton.Size = UDim2.new(1,0,0,32)
    WebhookButton.Text = "Webhook"
    WebhookButton.TextColor3 = Color3.new(0.922,0.922,0.941)
    WebhookButton.TextSize = 18

    local UICorner_5 = Instance.new("UICorner", WebhookButton)
    local UIStroke_3 = Instance.new("UIStroke", WebhookButton)
    UIStroke_3.Color = Color3.new(0.235,0.216,0.333)

    local CreditsButton = Instance.new("TextButton", Sidebar)
    CreditsButton.Name = "CreditsButton"
    CreditsButton.BackgroundColor3 = Color3.new(0.086,0.086,0.118)
    CreditsButton.BorderColor3 = Color3.new(0,0,0)
    CreditsButton.BorderSizePixel = 0
    CreditsButton.FontFace = Font.new("rbxassetid://16658221428",Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
    CreditsButton.Size = UDim2.new(1,0,0,32)
    CreditsButton.Text = "Credits"
    CreditsButton.TextColor3 = Color3.new(0.922,0.922,0.941)
    CreditsButton.TextSize = 18

    local UICorner_6 = Instance.new("UICorner", CreditsButton)
    local UIStroke_4 = Instance.new("UIStroke", CreditsButton)
    UIStroke_4.Color = Color3.new(0.235,0.216,0.333)

    local Pages = Instance.new("Frame", MainFrame)
    Pages.Name = "Pages"
    Pages.BackgroundColor3 = Color3.new(1,1,1)
    Pages.BackgroundTransparency = 1
    Pages.BorderColor3 = Color3.new(0,0,0)
    Pages.BorderSizePixel = 0
    Pages.Position = UDim2.new(0,107,0,42)
    Pages.Size = UDim2.new(1,-115,1,-50)

    local FarmPage = Instance.new("ScrollingFrame", Pages)
    FarmPage.Name = "FarmPage"
    FarmPage.Active = true
    FarmPage.BackgroundColor3 = Color3.new(1,1,1)
    FarmPage.BackgroundTransparency = 1
    FarmPage.BorderColor3 = Color3.new(0,0,0)
    FarmPage.BorderSizePixel = 0
    FarmPage.CanvasSize = UDim2.new(0,0,0,0)
    FarmPage.ScrollBarImageColor3 = Color3.new(0,0,0)
    FarmPage.ScrollBarThickness = 3
    FarmPage.Size = UDim2.new(1,0,1,0)

    local UIListLayout_1 = Instance.new("UIListLayout", FarmPage)
    UIListLayout_1.Padding = UDim.new(0,5)
    UIListLayout_1.SortOrder = Enum.SortOrder.LayoutOrder
    local UIPadding = Instance.new("UIPadding", FarmPage)
    UIPadding.PaddingLeft = UDim.new(0,5)
    UIPadding.PaddingRight = UDim.new(0,5)
    UIPadding.PaddingTop = UDim.new(0,5)

    local FarmSection = Instance.new("Frame", FarmPage)
    FarmSection.Name = "FarmSection"
    FarmSection.BackgroundColor3 = Color3.new(0.086,0.086,0.118)
    FarmSection.BorderColor3 = Color3.new(0,0,0)
    FarmSection.BorderSizePixel = 0
    FarmSection.Position = UDim2.new(0,5,0,5)
    FarmSection.Size = UDim2.new(1,-10,0,40)

    local UICorner_7 = Instance.new("UICorner", FarmSection)
    local UIStroke_5 = Instance.new("UIStroke", FarmSection)
    UIStroke_5.Color = Color3.new(0.235,0.216,0.333)

    local TextLabel = Instance.new("TextLabel", FarmSection)
    TextLabel.BackgroundColor3 = Color3.new(1,1,1)
    TextLabel.BackgroundTransparency = 1
    TextLabel.BorderColor3 = Color3.new(0,0,0)
    TextLabel.BorderSizePixel = 0
    TextLabel.FontFace = Font.new("rbxassetid://16658221428",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
    TextLabel.Position = UDim2.new(0,10,0,0)
    TextLabel.Size = UDim2.new(1,-12,1,0)
    TextLabel.Text = "FARM SETTINGS"
    TextLabel.TextColor3 = Color3.new(0.549,0.549,0.608)
    TextLabel.TextSize = 18

    local AutoSellToggle = Instance.new("Frame", FarmPage)
    AutoSellToggle.Name = "AutoSellToggle"
    AutoSellToggle.BackgroundColor3 = Color3.new(0.086,0.086,0.118)
    AutoSellToggle.BorderColor3 = Color3.new(0,0,0)
    AutoSellToggle.BorderSizePixel = 0
    AutoSellToggle.Position = UDim2.new(0,5,0,52)
    AutoSellToggle.Size = UDim2.new(1,-10,0,38)

    local UICorner_8 = Instance.new("UICorner", AutoSellToggle)
    local UIStroke_6 = Instance.new("UIStroke", AutoSellToggle)
    UIStroke_6.Color = Color3.new(0.235,0.216,0.333)

    local TextLabel_1 = Instance.new("TextLabel", AutoSellToggle)
    TextLabel_1.BackgroundColor3 = Color3.new(1,1,1)
    TextLabel_1.BackgroundTransparency = 1
    TextLabel_1.BorderColor3 = Color3.new(0,0,0)
    TextLabel_1.BorderSizePixel = 0
    TextLabel_1.FontFace = Font.new("rbxassetid://16658221428",Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
    TextLabel_1.Position = UDim2.new(0,10,0,0)
    TextLabel_1.Size = UDim2.new(0.6,0,1,0)
    TextLabel_1.Text = "Auto Sell"
    TextLabel_1.TextColor3 = Color3.new(0.922,0.922,0.941)
    TextLabel_1.TextSize = 18

    local ToggleButton = Instance.new("TextButton", AutoSellToggle)
    ToggleButton.Name = "ToggleButton"
    ToggleButton.BackgroundColor3 = Color3.new(0.569,0.373,1)
    ToggleButton.BorderColor3 = Color3.new(0,0,0)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json",Enum.FontWeight.Regular,Enum.FontStyle.Normal)
    ToggleButton.Position = UDim2.new(1,-55,0.5,-10)
    ToggleButton.Size = UDim2.new(0,42,0,20)
    ToggleButton.Text = ""
    ToggleButton.TextColor3 = Color3.new(0,0,0)
    ToggleButton.TextSize = 14

    local UICorner_9 = Instance.new("UICorner", ToggleButton)
    UICorner_9.CornerRadius = UDim.new(1,0)

    local Circle = Instance.new("Frame", ToggleButton)
    Circle.Name = "Circle"
    Circle.BackgroundColor3 = Color3.new(1,1,1)
    Circle.BorderColor3 = Color3.new(0,0,0)
    Circle.BorderSizePixel = 0
    Circle.Position = UDim2.new(1,-16,0.5,-6)
    Circle.Size = UDim2.new(0,13,0,13)

    local UICorner_10 = Instance.new("UICorner", Circle)
    UICorner_10.CornerRadius = UDim.new(1,0)

    local BuyLuckyToggle = Instance.new("Frame", FarmPage)
    BuyLuckyToggle.Name = "BuyLuckyToggle"
    BuyLuckyToggle.BackgroundColor3 = Color3.new(0.086,0.086,0.118)
    BuyLuckyToggle.BorderColor3 = Color3.new(0,0,0)
    BuyLuckyToggle.BorderSizePixel = 0
    BuyLuckyToggle.Position = UDim2.new(0,5,0,52)
    BuyLuckyToggle.Size = UDim2.new(1,-10,0,38)

    local UICorner_11 = Instance.new("UICorner", BuyLuckyToggle)
    local UIStroke_7 = Instance.new("UIStroke", BuyLuckyToggle)
    UIStroke_7.Color = Color3.new(0.235,0.216,0.333)

    local TextLabel_2 = Instance.new("TextLabel", BuyLuckyToggle)
    TextLabel_2.BackgroundColor3 = Color3.new(1,1,1)
    TextLabel_2.BackgroundTransparency = 1
    TextLabel_2.BorderColor3 = Color3.new(0,0,0)
    TextLabel_2.BorderSizePixel = 0
    TextLabel_2.FontFace = Font.new("rbxassetid://16658221428",Enum.FontWeight.SemiBold,Enum.FontStyle.Normal)
    TextLabel_2.Position = UDim2.new(0,10,0,0)
    TextLabel_2.Size = UDim2.new(0.6,0,1,0)
    TextLabel_2.Text = "Auto Buy Lucky"
    TextLabel_2.TextColor3 = Color3.new(0.922,0.922,0.941)
    TextLabel_2.TextSize = 18

    local ToggleButton_1 = Instance.new("TextButton", BuyLuckyToggle)
    ToggleButton_1.Name = "ToggleButton"
    ToggleButton_1.BackgroundColor3 = Color3.new(0.569,0.373,1)
    ToggleButton_1.BorderColor3 = Color3.new(0,0,0)
    ToggleButton_1.BorderSizePixel = 0
    ToggleButton_1.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json",Enum.FontWeight.Regular,Enum.FontStyle.Normal)
    ToggleButton_1.Position = UDim2.new(1,-55,0.5,-10)
    ToggleButton_1.Size = UDim2.new(0,42,0,20)
    ToggleButton_1.Text = ""
    ToggleButton_1.TextColor3 = Color3.new(0,0,0)
    ToggleButton_1.TextSize = 14

    local UICorner_12 = Instance.new("UICorner", ToggleButton_1)
    UICorner_12.CornerRadius = UDim.new(1,0)

    local Circle_1 = Instance.new("Frame", ToggleButton_1)
    Circle_1.Name = "Circle"
    Circle_1.BackgroundColor3 = Color3.new(1,1,1)
    Circle_1.BorderColor3 = Color3.new(0,0,0)
    Circle_1.BorderSizePixel = 0
    Circle_1.Position = UDim2.new(1,-16,0.5,-6)
    Circle_1.Size = UDim2.new(0,13,0,13)

    local UICorner_13 = Instance.new("UICorner", Circle_1)
    UICorner_13.CornerRadius = UDim.new(1,0)

    local ItemsPage = Instance.new("ScrollingFrame", Pages)
    ItemsPage.Name = "ItemsPage"
    ItemsPage.Active = true
    ItemsPage.BackgroundColor3 = Color3.new(1,1,1)
    ItemsPage.BackgroundTransparency = 1
    ItemsPage.BorderColor3 = Color3.new(0,0,0)
    ItemsPage.BorderSizePixel = 0
    ItemsPage.ScrollBarImageColor3 = Color3.new(0,0,0)
    ItemsPage.ScrollBarThickness = 3
    ItemsPage.Size = UDim2.new(1,0,1,0)
    ItemsPage.Visible = false

    local UIListLayout_2 = Instance.new("UIListLayout", ItemsPage)
    UIListLayout_2.Padding = UDim.new(0,4)
    UIListLayout_2.SortOrder = Enum.SortOrder.LayoutOrder
    local UIPadding_1 = Instance.new("UIPadding", ItemsPage)
    UIPadding_1.PaddingLeft = UDim.new(0,5)
    UIPadding_1.PaddingRight = UDim.new(0,5)
    UIPadding_1.PaddingTop = UDim.new(0,5)

    local WebhookPage = Instance.new("ScrollingFrame", Pages)
    WebhookPage.Name = "WebhookPage"
    WebhookPage.Active = true
    WebhookPage.BackgroundColor3 = Color3.new(1,1,1)
    WebhookPage.BackgroundTransparency = 1
    WebhookPage.BorderColor3 = Color3.new(0,0,0)
    WebhookPage.BorderSizePixel = 0
    WebhookPage.ScrollBarImageColor3 = Color3.new(0,0,0)
    WebhookPage.ScrollBarThickness = 3
    WebhookPage.Size = UDim2.new(1,0,1,0)
    WebhookPage.Visible = false

    local UIListLayout_3 = Instance.new("UIListLayout", WebhookPage)
    UIListLayout_3.Padding = UDim.new(0,4)
    UIListLayout_3.SortOrder = Enum.SortOrder.LayoutOrder
    local UIPadding_2 = Instance.new("UIPadding", WebhookPage)
    UIPadding_2.PaddingLeft = UDim.new(0,5)
    UIPadding_2.PaddingRight = UDim.new(0,5)
    UIPadding_2.PaddingTop = UDim.new(0,5)

    local CreditsPage = Instance.new("ScrollingFrame", Pages)
    CreditsPage.Name = "CreditsPage"
    CreditsPage.Active = true
    CreditsPage.BackgroundColor3 = Color3.new(1,1,1)
    CreditsPage.BackgroundTransparency = 1
    CreditsPage.BorderColor3 = Color3.new(0,0,0)
    CreditsPage.BorderSizePixel = 0
    CreditsPage.ScrollBarImageColor3 = Color3.new(0,0,0)
    CreditsPage.ScrollBarThickness = 3
    CreditsPage.Size = UDim2.new(1,0,1,0)
    CreditsPage.Visible = false

    local UIListLayout_4 = Instance.new("UIListLayout", CreditsPage)
    UIListLayout_4.Padding = UDim.new(0,4)
    UIListLayout_4.SortOrder = Enum.SortOrder.LayoutOrder
    local UIPadding_3 = Instance.new("UIPadding", CreditsPage)
    UIPadding_3.PaddingLeft = UDim.new(0,5)
    UIPadding_3.PaddingRight = UDim.new(0,5)
    UIPadding_3.PaddingTop = UDim.new(0,5)

    local ToggleButton_2 = Instance.new("TextButton", ScreenGui)
    ToggleButton_2.Name = "ToggleButton"
    ToggleButton_2.BackgroundColor3 = Color3.new(0.086,0.086,0.118)
    ToggleButton_2.BorderColor3 = Color3.new(0,0,0)
    ToggleButton_2.BorderSizePixel = 0
    ToggleButton_2.FontFace = Font.new("rbxassetid://16658221428",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
    ToggleButton_2.Position = UDim2.new(0,8,1,-200)
    ToggleButton_2.Size = UDim2.new(0,100,0,26)
    ToggleButton_2.Text = "⚡ WHITE HUB"
    ToggleButton_2.TextColor3 = Color3.new(0.922,0.922,0.941)
    ToggleButton_2.TextSize = 14

    local UICorner_14 = Instance.new("UICorner", ToggleButton_2)
    UICorner_14.CornerRadius = UDim.new(0,6)
    local UIStroke_8 = Instance.new("UIStroke", ToggleButton_2)
    UIStroke_8.Color = Color3.new(0.235,0.216,0.333)
    UIStroke_8.Thickness = 1.3

    -- ========== FIM DA PARTE VISUAL ==========

    -- ========== SCRIPTS (preenchidos manualmente) ==========

    -- Script 1: Drag na TopBar
    local dragScript = Instance.new("LocalScript", TopBar)
    dragScript.Source = [[
        local topBar = script.Parent
        local mainFrame = topBar.Parent
        local UserInputService = game:GetService("UserInputService")
        local dragging = false
        local dragStart, startPos
        topBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = mainFrame.Position
            end
        end)
        topBar.InputEnded:Connect(function() dragging = false end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    ]]

    -- Script 2: CloseButton
    local closeScript = Instance.new("LocalScript", CloseButton)
    closeScript.Source = [[
        local button = script.Parent
        local mainFrame = button.Parent.Parent
        local TweenService = game:GetService("TweenService")
        button.MouseButton1Click:Connect(function()
            local tween = TweenService:Create(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
                Size = UDim2.new(0,0,0,0),
                Position = UDim2.new(0.5,0,0.5,0)
            })
            tween:Play()
            tween.Completed:Connect(function() mainFrame.Visible = false end)
        end)
    ]]

    -- Script 3: Sidebar (trocar páginas)
    local sidebarScript = Instance.new("LocalScript", Sidebar)
    sidebarScript.Source = [[
        local sidebar = script.Parent
        local pages = sidebar.Parent:FindFirstChild("Pages")
        if not pages then return end
        local farmPage = pages:FindFirstChild("FarmPage")
        local itemsPage = pages:FindFirstChild("ItemsPage")
        local webhookPage = pages:FindFirstChild("WebhookPage")
        local creditsPage = pages:FindFirstChild("CreditsPage")
        local function showPage(page)
            if farmPage then farmPage.Visible = (page == farmPage) end
            if itemsPage then itemsPage.Visible = (page == itemsPage) end
            if webhookPage then webhookPage.Visible = (page == webhookPage) end
            if creditsPage then creditsPage.Visible = (page == creditsPage) end
        end
        local farmBtn = sidebar:FindFirstChild("FarmButton")
        local itemsBtn = sidebar:FindFirstChild("ItemsButton")
        local webhookBtn = sidebar:FindFirstChild("WebhookButton")
        local creditsBtn = sidebar:FindFirstChild("CreditsButton")
        if farmBtn then farmBtn.MouseButton1Click:Connect(function() showPage(farmPage) end) end
        if itemsBtn then itemsBtn.MouseButton1Click:Connect(function() showPage(itemsPage) end) end
        if webhookBtn then webhookBtn.MouseButton1Click:Connect(function() showPage(webhookPage) end) end
        if creditsBtn then creditsBtn.MouseButton1Click:Connect(function() showPage(creditsPage) end) end
        showPage(farmPage)
    ]]

    -- Script 4: CanvasSize do FarmPage
    local farmCanvasScript = Instance.new("LocalScript", FarmPage)
    farmCanvasScript.Source = [[
        local scroll = script.Parent
        local list = scroll:FindFirstChildOfClass("UIListLayout")
        if not list then return end
        local function update()
            scroll.CanvasSize = UDim2.new(0,0,0,list.AbsoluteContentSize.Y + 10)
        end
        update()
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
    ]]

    -- Script 5: AutoSell Toggle
    local autoSellScript = Instance.new("LocalScript", ToggleButton)
    autoSellScript.Source = [[
        local button = script.Parent
        local circle = button:FindFirstChild("Circle")
        local modules = _G.WhiteHubModules
        local enabled = true
        if modules and modules.Config then
            enabled = modules.Config:Get("AutoSell")
            if enabled == nil then enabled = true end
        end
        local TweenService = game:GetService("TweenService")
        local function updateVisual()
            if enabled then
                button.BackgroundColor3 = Color3.fromRGB(145,95,255)
                if circle then TweenService:Create(circle, TweenInfo.new(0.18), {Position = UDim2.new(1,-16,0.5,-6.5)}):Play() end
            else
                button.BackgroundColor3 = Color3.fromRGB(30,30,42)
                if circle then TweenService:Create(circle, TweenInfo.new(0.18), {Position = UDim2.new(0,3,0.5,-6.5)}):Play() end
            end
        end
        updateVisual()
        button.MouseButton1Click:Connect(function()
            enabled = not enabled
            if modules and modules.Config then modules.Config:Set("AutoSell", enabled) end
            updateVisual()
        end)
    ]]

    -- Script 6: BuyLucky Toggle
    local buyLuckyScript = Instance.new("LocalScript", ToggleButton_1)
    buyLuckyScript.Source = [[
        local button = script.Parent
        local circle = button:FindFirstChild("Circle")
        local modules = _G.WhiteHubModules
        local enabled = true
        if modules and modules.Config then
            enabled = modules.Config:Get("BuyLucky")
            if enabled == nil then enabled = true end
        end
        local TweenService = game:GetService("TweenService")
        local function updateVisual()
            if enabled then
                button.BackgroundColor3 = Color3.fromRGB(145,95,255)
                if circle then TweenService:Create(circle, TweenInfo.new(0.18), {Position = UDim2.new(1,-16,0.5,-6.5)}):Play() end
            else
                button.BackgroundColor3 = Color3.fromRGB(30,30,42)
                if circle then TweenService:Create(circle, TweenInfo.new(0.18), {Position = UDim2.new(0,3,0.5,-6.5)}):Play() end
            end
        end
        updateVisual()
        button.MouseButton1Click:Connect(function()
            enabled = not enabled
            if modules and modules.Config then modules.Config:Set("BuyLucky", enabled) end
            updateVisual()
        end)
    ]]

    -- Script 7: ItemsPage (cria todos os toggles e CanvasSize)
    local itemsScript = Instance.new("LocalScript", ItemsPage)
    itemsScript.Source = [[
        local page = script.Parent
        local config = _G.WhiteHubModules and _G.WhiteHubModules.Config
        if not config then
            config = { GetSellItem = function() return true end, SetSellItem = function() end }
        end
        for _, child in ipairs(page:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
        local function makeSection(text)
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1,-4,0,22)
            frame.BackgroundColor3 = Color3.fromRGB(22,22,30)
            frame.BorderSizePixel = 0
            frame.Parent = page
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
            local stroke = Instance.new("UIStroke", frame)
            stroke.Color = Color3.fromRGB(60,55,85)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1,-10,1,0)
            lbl.Position = UDim2.new(0,8,0,0)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(140,140,155)
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = frame
        end
        local function makeToggle(itemName, defaultValue)
            local holder = Instance.new("Frame")
            holder.Size = UDim2.new(1,-4,0,28)
            holder.BackgroundColor3 = Color3.fromRGB(22,22,30)
            holder.BorderSizePixel = 0
            holder.Parent = page
            Instance.new("UICorner", holder).CornerRadius = UDim.new(0,7)
            local stroke = Instance.new("UIStroke", holder)
            stroke.Color = Color3.fromRGB(60,55,85)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0.65,0,1,0)
            lbl.Position = UDim2.new(0,8,0,0)
            lbl.BackgroundTransparency = 1
            lbl.Text = itemName
            lbl.TextColor3 = Color3.fromRGB(235,235,240)
            lbl.TextScaled = true
            lbl.Font = Enum.Font.Gotham
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = holder
            local enabled = defaultValue
            local track = Instance.new("TextButton")
            track.Size = UDim2.new(0,40,0,18)
            track.Position = UDim2.new(1,-48,0.5,-9)
            track.BackgroundColor3 = enabled and Color3.fromRGB(145,95,255) or Color3.fromRGB(30,30,42)
            track.Text = ""
            track.BorderSizePixel = 0
            track.Parent = holder
            Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
            local circle = Instance.new("Frame")
            circle.Size = UDim2.new(0,13,0,13)
            circle.Position = enabled and UDim2.new(1,-16,0.5,-6.5) or UDim2.new(0,3,0.5,-6.5)
            circle.BackgroundColor3 = Color3.fromRGB(255,255,255)
            circle.BorderSizePixel = 0
            circle.Parent = track
            Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)
            track.MouseButton1Click:Connect(function()
                enabled = not enabled
                local tween = game:GetService("TweenService")
                tween:Create(track, TweenInfo.new(0.18), {BackgroundColor3 = enabled and Color3.fromRGB(145,95,255) or Color3.fromRGB(30,30,42)}):Play()
                tween:Create(circle, TweenInfo.new(0.18), {Position = enabled and UDim2.new(1,-16,0.5,-6.5) or UDim2.new(0,3,0.5,-6.5)}):Play()
                config:SetSellItem(itemName, enabled)
            end)
        end
        makeSection("SELL ITEMS")
        local itemOrder = { "Gold Coin", "Diamond", "Rokakaka", "Pure Rokakaka", "Mysterious Arrow", "Lucky Arrow", "Lucky Stone Mask", "Ancient Scroll", "Caesar's Headband", "Stone Mask", "Rib Cage of The Saint's Corpse", "Quinton's Glove", "Zeppeli's Hat", "Clackers", "Steel Ball", "Dio's Diary" }
        for _, name in ipairs(itemOrder) do
            local defaultValue = config:GetSellItem(name)
            if defaultValue == nil then defaultValue = true end
            makeToggle(name, defaultValue)
        end
        task.wait(0.1)
        local list = page:FindFirstChildOfClass("UIListLayout")
        if list then
            local function updateCanvas()
                page.CanvasSize = UDim2.new(0,0,0,list.AbsoluteContentSize.Y + 10)
            end
            updateCanvas()
            list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
        end
    ]]

    -- Script 8: WebhookPage (cria textbox e salva)
    local webhookScript = Instance.new("LocalScript", WebhookPage)
    webhookScript.Source = [[
        local page = script.Parent
        local config = _G.WhiteHubModules and _G.WhiteHubModules.Config
        if not config then
            config = { Get = function() return "" end, Set = function() end }
        end
        for _, child in ipairs(page:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
        local function makeSection(text)
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1,-4,0,22)
            frame.BackgroundColor3 = Color3.fromRGB(22,22,30)
            frame.BorderSizePixel = 0
            frame.Parent = page
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
            local stroke = Instance.new("UIStroke", frame)
            stroke.Color = Color3.fromRGB(60,55,85)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1,-10,1,0)
            lbl.Position = UDim2.new(0,8,0,0)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(140,140,155)
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = frame
        end
        makeSection("DISCORD WEBHOOK")
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(1,-4,0,40)
        holder.BackgroundColor3 = Color3.fromRGB(22,22,30)
        holder.BorderSizePixel = 0
        holder.Parent = page
        Instance.new("UICorner", holder).CornerRadius = UDim.new(0,7)
        local stroke = Instance.new("UIStroke", holder)
        stroke.Color = Color3.fromRGB(60,55,85)
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1,-12,1,0)
        box.Position = UDim2.new(0,8,0,0)
        box.BackgroundTransparency = 0
        box.BackgroundColor3 = Color3.fromRGB(40,40,55)
        box.Text = config:Get("WebhookURL") or ""
        box.PlaceholderText = "https://discord.com/api/webhooks/..."
        box.TextColor3 = Color3.fromRGB(255,255,255)
        box.PlaceholderColor3 = Color3.fromRGB(160,160,180)
        box.TextScaled = false
        box.TextSize = 14
        box.Font = Enum.Font.Gotham
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.ClearTextOnFocus = false
        box.Parent = holder
        box.Focused:Connect(function()
            local tween = game:GetService("TweenService")
            tween:Create(stroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(120,90,255)}):Play()
            box.BackgroundColor3 = Color3.fromRGB(55,55,75)
        end)
        box.FocusLost:Connect(function()
            config:Set("WebhookURL", box.Text)
            local tween = game:GetService("TweenService")
            tween:Create(stroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(60,55,85)}):Play()
            box.BackgroundColor3 = Color3.fromRGB(40,40,55)
        end)
        task.wait(0.1)
        local list = page:FindFirstChildOfClass("UIListLayout")
        if list then
            local function updateCanvas()
                page.CanvasSize = UDim2.new(0,0,0,list.AbsoluteContentSize.Y + 10)
            end
            updateCanvas()
            list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
        end
    ]]

    -- Script 9: CreditsPage
    local creditsScript = Instance.new("LocalScript", CreditsPage)
    creditsScript.Source = [[
        local page = script.Parent
        for _, child in ipairs(page:GetChildren()) do
            if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
        local function makeSection(text)
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1,-4,0,22)
            frame.BackgroundColor3 = Color3.fromRGB(22,22,30)
            frame.BorderSizePixel = 0
            frame.Parent = page
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
            local stroke = Instance.new("UIStroke", frame)
            stroke.Color = Color3.fromRGB(60,55,85)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1,-10,1,0)
            lbl.Position = UDim2.new(0,8,0,0)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(140,140,155)
            lbl.TextScaled = true
            lbl.Font = Enum.Font.GothamBold
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = frame
        end
        makeSection("WHITE HUB")
        local creditLabel = Instance.new("TextLabel")
        creditLabel.Size = UDim2.new(1,-4,0,40)
        creditLabel.BackgroundColor3 = Color3.fromRGB(22,22,30)
        creditLabel.BorderSizePixel = 0
        creditLabel.Text = "Made by WHITE DRAGON"
        creditLabel.TextColor3 = Color3.fromRGB(235,235,240)
        creditLabel.TextScaled = true
        creditLabel.Font = Enum.Font.GothamBold
        creditLabel.Parent = page
        Instance.new("UICorner", creditLabel).CornerRadius = UDim.new(0,7)
        local creditStroke = Instance.new("UIStroke", creditLabel)
        creditStroke.Color = Color3.fromRGB(60,55,85)
        local discordBtn = Instance.new("TextButton")
        discordBtn.Size = UDim2.new(1,-4,0,32)
        discordBtn.BackgroundColor3 = Color3.fromRGB(88,101,242)
        discordBtn.BorderSizePixel = 0
        discordBtn.Text = "🔗 discord.gg/Qwd23ZRNxJ  —  Click to Copy"
        discordBtn.TextColor3 = Color3.fromRGB(255,255,255)
        discordBtn.TextScaled = true
        discordBtn.Font = Enum.Font.GothamBold
        discordBtn.Parent = page
        Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0,7)
        Instance.new("UIStroke", discordBtn).Color = Color3.fromRGB(60,70,200)
        discordBtn.MouseEnter:Connect(function()
            local tween = game:GetService("TweenService")
            tween:Create(discordBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(110,125,255)}):Play()
        end)
        discordBtn.MouseLeave:Connect(function()
            local tween = game:GetService("TweenService")
            tween:Create(discordBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(88,101,242)}):Play()
        end)
        discordBtn.MouseButton1Click:Connect(function()
            pcall(function() setclipboard("https://discord.gg/Qwd23ZRNxJ") end)
            local original = discordBtn.Text
            discordBtn.Text = "✅ Copied!"
            local tween = game:GetService("TweenService")
            tween:Create(discordBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(50,180,80)}):Play()
            task.delay(2, function()
                discordBtn.Text = original
                tween:Create(discordBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(88,101,242)}):Play()
            end)
        end)
        task.wait(0.1)
        local list = page:FindFirstChildOfClass("UIListLayout")
        if list then
            local function updateCanvas()
                page.CanvasSize = UDim2.new(0,0,0,list.AbsoluteContentSize.Y + 10)
            end
            updateCanvas()
            list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
        end
    ]]

    -- Script 10: ToggleButton flutuante (abrir/fechar)
    local toggleScript = Instance.new("LocalScript", ToggleButton_2)
    toggleScript.Source = [[
        local button = script.Parent
        local screenGui = button.Parent
        local mainFrame = screenGui:FindFirstChild("MainFrame")
        if not mainFrame then return end
        local TweenService = game:GetService("TweenService")
        local UserInputService = game:GetService("UserInputService")
        local isOpen = false
        local W, H = 500, 320
        local function ToggleWindow()
            isOpen = not isOpen
            if isOpen then
                mainFrame.Visible = true
                mainFrame.Size = UDim2.new(0,0,0,0)
                mainFrame.Position = UDim2.new(0.5,0,0.5,0)
                TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0,W,0,H), Position = UDim2.new(0.5,-W/2,0.5,-H/2)}):Play()
            else
                local t = TweenService:Create(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0)})
                t:Play()
                t.Completed:Connect(function() mainFrame.Visible = false end)
            end
        end
        button.MouseButton1Click:Connect(ToggleWindow)
        local stroke = button:FindFirstChildOfClass("UIStroke")
        button.MouseEnter:Connect(function()
            if stroke then TweenService:Create(stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(120,90,255)}):Play() end
        end)
        button.MouseLeave:Connect(function()
            if stroke then TweenService:Create(stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(60,55,85)}):Play() end
        end)
        local btnVisible = true
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.RightAlt then
                ToggleWindow()
            elseif input.KeyCode == Enum.KeyCode.RightControl then
                btnVisible = not btnVisible
                button.Visible = btnVisible
            end
        end)
    ]]
end

function UI:Init(Modules)
    -- Nothing needed, kept for compatibility
end

return UI
