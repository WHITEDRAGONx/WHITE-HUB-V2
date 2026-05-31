-- =====================
-- Farm.lua
-- Main farm controller.
-- =====================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local Player = Players.LocalPlayer
local Farm   = {}

local _config    = nil
local _inventory = nil
local _movement  = nil
local _serverHop = nil
local _webhook   = nil

local SpawnedItems    = {}
local ItemSpawnFolder = nil
local NO_ITEM_TIMEOUT = 20
local lastItemTime    = tick()

local lastSellItemsSnapshot = nil

function Farm:Init(Modules)
    _config    = Modules.Config
    _inventory = Modules.Inventory
    _movement  = Modules.Movement
    _serverHop = Modules.ServerHop
    _webhook   = Modules.Webhook
end

-- Config change detection
local function updateConfigSnapshot()
    lastSellItemsSnapshot = {}
    local sellItems = _config:GetSellItems()
    for k, v in pairs(sellItems) do
        lastSellItemsSnapshot[k] = v
    end
end

local function hasConfigChanged()
    if lastSellItemsSnapshot == nil then
        updateConfigSnapshot()
        return false
    end
    local current = _config:GetSellItems()
    for k, v in pairs(current) do
        if lastSellItemsSnapshot[k] ~= v then
            return true
        end
    end
    return false
end

-- Hooks & bypasses
local function ApplyHooks()
    pcall(function()
        local oldMag
        oldMag = hookmetamethod(Vector3.new(), "__index", newcclosure(function(self, index)
            local src = tostring(getcallingscript())
            if not checkcaller() and index == "magnitude" and src == "ItemSpawn" then return 0 end
            return oldMag(self, index)
        end))
    end)
    pcall(function()
        local oldNc
        oldNc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local args = {...}
            if not checkcaller() and rawequal(self.Name, "Returner") and rawequal(args[1], "idklolbrah2de") then
                return "  ___XP DE KEY"
            end
            return oldNc(self, ...)
        end))
    end)
end

local function ApplyCrashBypass()
    task.delay(3, function()
        pcall(function()
            local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
            if not Modules then return end
            local FuncLib = require(Modules:WaitForChild("FunctionLibrary", 10))
            if not FuncLib or type(FuncLib) ~= "table" then return end
            local OldPcall = FuncLib.pcall
            if type(OldPcall) ~= "function" then return end
            FuncLib.pcall = function(...)
                local f = ...
                if type(f) == "function" and #getupvalues(f) == 11 then return end
                return OldPcall(...)
            end
        end)
    end)
end

local function ApplyAntiAfk()
    pcall(function()
        Player.Idled:Connect(function()
            game:GetService("VirtualUser"):ClickButton2(Vector2.new())
        end)
    end)
end

local function SkipLoadingScreen()
    task.wait(1)
    pcall(function()
        if not Player.PlayerGui:FindFirstChild("HUD") then
            local HUD = ReplicatedStorage.Objects.HUD:Clone()
            HUD.Parent = Player.PlayerGui
        end
    end)
    task.spawn(function()
        pcall(function() Player.PlayerGui:WaitForChild("LoadingScreen1", 5):Destroy() end)
        task.wait(.5)
        pcall(function() Player.PlayerGui:WaitForChild("LoadingScreen", 5):Destroy() end)
        pcall(function() Workspace.LoadingScreen.Song:Destroy() end)
    end)
end

-- Item detection
local function GetItemInfo(model)
    if not (model and model:IsA("Model") and model.Parent and model.Parent.Name == "Items") then return nil end
    local pp = model.PrimaryPart
    if not pp then return nil end
    local prompt
    for _, v in pairs(model:GetChildren()) do
        if v:IsA("ProximityPrompt") and v.MaxActivationDistance ~= 0 then prompt = v break end
    end
    if not prompt then return nil end
    return { Name = prompt.ObjectText, ProximityPrompt = prompt, Position = pp.Position }
end

local function InitItemDetection()
    pcall(function()
        local spawns = Workspace:WaitForChild("Item_Spawns", 15)
        if spawns then ItemSpawnFolder = spawns:WaitForChild("Items", 15) end
    end)
    if not ItemSpawnFolder then
        pcall(function()
            local spawns = Workspace:FindFirstChild("Item_Spawns")
            if spawns then ItemSpawnFolder = spawns:FindFirstChild("Items") end
        end)
    end
    if not ItemSpawnFolder then
        warn("[Farm] ERROR: Item_Spawns/Items folder not found.")
        return
    end
    print("[Farm] Item_Spawns/Items folder found.")
    for _, model in pairs(ItemSpawnFolder:GetChildren()) do
        pcall(function()
            if model:IsA("Model") then
                local info = GetItemInfo(model)
                if info then SpawnedItems[model] = info end
            end
        end)
    end
    ItemSpawnFolder.ChildAdded:Connect(function(model)
        task.wait(1)
        pcall(function()
            if model:IsA("Model") then
                local info = GetItemInfo(model)
                if info then
                    SpawnedItems[model] = info
                    print("[Farm] Item detected: " .. info.Name)
                end
            end
        end)
    end)
end

local SAFE_SPOT = CFrame.new(978, -42, -49)

local function CollectItem(itemInfo, index)
    if not _config:Get("FarmEnabled") then return end
    
    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if not hrp then return end
    SpawnedItems[index] = nil
    if _inventory:HasMax(itemInfo.Name) then return end
    local bv = _movement:Freeze()
    _movement:SetNoclip(true)
    _movement:Teleport(CFrame.new(itemInfo.Position.X, itemInfo.Position.Y - 25, itemInfo.Position.Z))
    task.wait(.5)
    pcall(function() fireproximityprompt(itemInfo.ProximityPrompt) end)
    task.wait(.5)
    _movement:Unfreeze(bv)
    _movement:Teleport(SAFE_SPOT)
    task.wait(.3)
    _movement:SetNoclip(false)
    lastItemTime = tick()
    print("[Farm] Collected: " .. itemInfo.Name)
end

local function DoHop()
    if not _config:Get("FarmEnabled") then return end
    
    print("[Farm] Server dry — selling, buying, then hopping...")
    _inventory:SellAll()
    _inventory:BuyLucky()
    _serverHop:Hop()
    lastItemTime = tick()
end

local function SetupWebhookListener()
    Player.Backpack.ChildAdded:Connect(function(tool)
        if tool.Name == "Lucky Arrow" and _inventory:ShouldStopPhase1() then
            _webhook:SendLuckyFound(
                _inventory:Count("Lucky Arrow"),
                _inventory:GetLuckyStop(),
                _inventory:GetMoney()
            )
        end
    end)
end

local function Startup()
    SkipLoadingScreen()

    local waitTime = 0
    repeat
        task.wait(0.5)
        waitTime += 0.5
        if waitTime > 30 then
            warn("[Farm] Timeout waiting for RemoteEvent — continuing anyway.")
            break
        end
    until _movement:GetCharacter("RemoteEvent")

    print("[Farm] Character loaded.")
    pcall(function()
        _movement:GetCharacter("RemoteEvent"):FireServer("PressedPlay")
    end)

    print("[Farm] Teleporting to safe spot...")
    _movement:Teleport(SAFE_SPOT)
    task.wait(1)
    _movement:FixCamera()

    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if hrp then print("[Farm] Position: " .. tostring(hrp.Position))
    else warn("[Farm] HumanoidRootPart not found.") end

    print("[Farm] Waiting 5 seconds before starting farm loop...")
    task.wait(5)
end

-- =====================
-- PUBLIC FUNCTION FOR PRESTIGE TO COLLECT ITEMS
-- =====================
function Farm:CollectItemFromGround(itemName, targetCount)
    print("[Farm] Collecting " .. targetCount .. "x " .. itemName .. " for Prestige")
    local startTime = tick()
    while _inventory:Count(itemName) < targetCount do
        if not _config:Get("FarmEnabled") then return false end
        
        local elapsed = tick() - lastItemTime
        if elapsed > NO_ITEM_TIMEOUT then
            print("[Farm] No " .. itemName .. " for " .. math.floor(elapsed) .. "s — hopping...")
            DoHop()
            startTime = tick()
            lastItemTime = tick()
            task.wait(2)
        end
        
        local snapshot = {}
        for idx, info in pairs(SpawnedItems) do
            if info.Name == itemName then
                table.insert(snapshot, {Index=idx, ItemInfo=info})
            end
        end
        
        if #snapshot == 0 then
            local waiting = math.floor(NO_ITEM_TIMEOUT - (tick() - lastItemTime))
            print("[Farm] Waiting for " .. itemName .. "... (" .. waiting .. "s until hop)")
            task.wait(2)
        else
            for _, entry in ipairs(snapshot) do
                if _inventory:Count(itemName) >= targetCount then break end
                CollectItem(entry.ItemInfo, entry.Index)
            end
        end
        task.wait(1)
    end
    return true
end

function Farm:Start()
    ApplyHooks()
    ApplyCrashBypass()
    ApplyAntiAfk()
    InitItemDetection()
    SetupWebhookListener()
    Startup()

    print("[Farm] Farm loop started.")

    while true do
        while not _config:Get("FarmEnabled") do
            task.wait(1)
            print("[Farm] Farm disabled by user. Waiting...")
        end

        if _config:Get("AutoPrestige") then
            print("[Farm] Auto Prestige enabled – starting Prestige module.")
            if _webhook then
                _webhook:Send("🔄 **Auto Prestige started**\nPlayer: `" .. Player.Name .. "`")
            end
            local prestigeRunning = true
            local prestigeThread = task.spawn(function()
                local ok, err = pcall(function()
                    if _G.WhiteHubModules.Prestige and _G.WhiteHubModules.Prestige.Start then
                        _G.WhiteHubModules.Prestige:Start()
                    else
                        warn("[Farm] Prestige module not available.")
                    end
                end)
                if not ok then
                    warn("[Farm] Prestige crashed: " .. tostring(err))
                    if _webhook then _webhook:SendError("Prestige crashed: " .. tostring(err)) end
                end
                prestigeRunning = false
            end)
            while prestigeRunning and _config:Get("AutoPrestige") do
                task.wait(1)
            end
            if not _config:Get("AutoPrestige") then
                print("[Farm] Auto Prestige turned off – stopping Prestige module.")
                if _G.WhiteHubModules.Prestige and _G.WhiteHubModules.Prestige.Stop then
                    _G.WhiteHubModules.Prestige:Stop()
                end
                task.cancel(prestigeThread)
            end
            lastItemTime = tick()
            _config:Set("Phase1Notified", false)
            _config:Set("Phase3Notified", false)
            print("[Farm] Returning to normal farm.")
        end

        -- Normal farm loop (only runs when AutoPrestige is false)
        while not _config:Get("AutoPrestige") and _config:Get("FarmEnabled") do
            -- ===== PHASE 1 =====
            print("[Farm] >>> Phase 1 started — farming normally.")
            while not _inventory:ShouldStopPhase1() and not _config:Get("AutoPrestige") do
                if not _config:Get("FarmEnabled") then break end
                
                local snapshot = {}
                for idx, info in pairs(SpawnedItems) do
                    table.insert(snapshot, {Index=idx, ItemInfo=info})
                end
                for _, entry in ipairs(snapshot) do
                    if _inventory:ShouldStopPhase1() or _config:Get("AutoPrestige") then break end
                    CollectItem(entry.ItemInfo, entry.Index)
                end
                local elapsed = tick() - lastItemTime
                if elapsed > NO_ITEM_TIMEOUT then
                    if _inventory:ShouldStopPhase1() or _config:Get("AutoPrestige") then break end
                    DoHop()
                else
                    if #snapshot == 0 then
                        print("[Farm] Waiting for items... (" .. math.floor(NO_ITEM_TIMEOUT - elapsed) .. "s until hop)")
                    end
                end
                task.wait(1)
            end

            _inventory:SellAll()
            _inventory:BuyLucky()
            print("[Farm] >>> Phase 1 complete.")

            -- ===== PHASE 2 =====
            local keepItems = _inventory:GetKeepItems()
            if #keepItems > 0 then
                if not _config:Get("Phase1Notified") then
                    _webhook:SendPhase1Complete(_inventory:Count("Lucky Arrow"), _inventory:GetLuckyStop(), _inventory:GetMoney())
                    _config:Set("Phase1Notified", true)
                end

                print("[Farm] >>> Phase 2 started — farming keep-items: " .. table.concat(keepItems, ", "))
                while not _inventory:AllKeepItemsFull() and not _config:Get("AutoPrestige") do
                    if not _config:Get("FarmEnabled") then break end
                    
                    local snapshot = {}
                    for idx, info in pairs(SpawnedItems) do
                        local isKeep = _config:GetSellItem(info.Name) == false
                        if isKeep and not _inventory:HasMax(info.Name) then
                            table.insert(snapshot, {Index=idx, ItemInfo=info})
                        else
                            if not isKeep then SpawnedItems[idx] = nil end
                        end
                    end
                    for _, entry in ipairs(snapshot) do
                        if _inventory:AllKeepItemsFull() or _config:Get("AutoPrestige") then break end
                        CollectItem(entry.ItemInfo, entry.Index)
                    end
                    local elapsed = tick() - lastItemTime
                    if elapsed > NO_ITEM_TIMEOUT then
                        if _inventory:AllKeepItemsFull() or _config:Get("AutoPrestige") then break end
                        print("[Farm] Phase 2 — server dry, hopping...")
                        _serverHop:Hop()
                        lastItemTime = tick()
                    else
                        if #snapshot == 0 then
                            print("[Farm] Waiting for keep-items... (" .. math.floor(NO_ITEM_TIMEOUT - elapsed) .. "s until hop)")
                        end
                    end
                    task.wait(1)
                end
                print("[Farm] >>> Phase 2 complete — all keep-items maxed.")
            else
                print("[Farm] >>> No keep-items configured — skipping Phase 2.")
            end

            -- ===== PHASE 3 (IDLE) =====
            if not _config:Get("Phase3Notified") then
                print("[Farm] Sending 'All farming complete' webhook...")
                _webhook:SendAllComplete(_inventory:Count("Lucky Arrow"), _inventory:GetLuckyStop(), _inventory:GetMoney())
                _config:Set("Phase3Notified", true)
            else
                print("[Farm] 'All farming complete' already sent. Use UI reset if needed.")
            end
            print("[Farm] >>> Phase 3 — fully stopped. Idling, only collecting Lucky Arrows.")
            updateConfigSnapshot()

            while not _config:Get("AutoPrestige") and _config:Get("FarmEnabled") do
                if not _inventory:ShouldStopPhase1() then
                    print("[Farm] >>> Lucky count or money dropped — returning to Phase 1.")
                    _config:Set("Phase1Notified", false)
                    _config:Set("Phase3Notified", false)
                    lastItemTime = tick()
                    break
                end

                if hasConfigChanged() then
                    print("[Farm] >>> Config changed — returning to Phase 1.")
                    updateConfigSnapshot()
                    _config:Set("Phase1Notified", false)
                    _config:Set("Phase3Notified", false)
                    lastItemTime = tick()
                    break
                end

                local snapshot = {}
                for idx, info in pairs(SpawnedItems) do
                    if info.Name == "Lucky Arrow" or info.Name == "Lucky Stone Mask" then
                        table.insert(snapshot, {Index=idx, ItemInfo=info})
                    else
                        SpawnedItems[idx] = nil
                    end
                end
                for _, entry in ipairs(snapshot) do
                    CollectItem(entry.ItemInfo, entry.Index)
                end
                task.wait(1)
            end
        end
        task.wait(1)
    end
end

function Farm:Stop()
    print("[Farm] Stop requested.")
end

return Farm
