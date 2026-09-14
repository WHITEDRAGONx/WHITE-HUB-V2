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
local NO_ITEM_TIMEOUT = 10   -- <-- alterado de 20 para 10
local lastItemTime    = tick()

local lastSellItemsSnapshot = nil
local isRunning = false
local stopRequested = false
local runtimeSetup = false
local runtimeConnections = {}

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
    local env = getgenv and getgenv() or _G
    if env.__WhiteHubFarmHooksApplied then return end
    env.__WhiteHubFarmHooksApplied = true

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
        local connection = Player.Idled:Connect(function()
            game:GetService("VirtualUser"):ClickButton2(Vector2.new())
        end)
        table.insert(runtimeConnections, connection)
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
    return { Name = prompt.ObjectText, ProximityPrompt = prompt, Position = pp.Position, Model = model }
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
    local connection = ItemSpawnFolder.ChildAdded:Connect(function(model)
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
    table.insert(runtimeConnections, connection)
end

local SAFE_SPOT = CFrame.new(978, -42, -49)

local function CollectItem(itemInfo, index)
    if not _config:Get("FarmEnabled") or stopRequested then return false end

    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if not hrp or not itemInfo then return false end
    if _inventory:HasMax(itemInfo.Name) then
        SpawnedItems[index] = nil
        return false
    end

    local beforeCount = _inventory:Count(itemInfo.Name)
    local model = itemInfo.Model or index
    local oldCF = hrp.CFrame
    local bv = _movement:Freeze()
    _movement:SetNoclip(true)
    _movement:Teleport(CFrame.new(itemInfo.Position.X, itemInfo.Position.Y - 25, itemInfo.Position.Z))
    task.wait(.35)

    local fired = pcall(function()
        if itemInfo.ProximityPrompt and itemInfo.ProximityPrompt.Parent then
            fireproximityprompt(itemInfo.ProximityPrompt)
        end
    end)

    local deadline = tick() + 1.5
    local collected = false
    while tick() < deadline do
        if _inventory:Count(itemInfo.Name) > beforeCount then
            collected = true
            break
        end
        if model and not model.Parent then
            collected = true
            break
        end
        task.wait(0.1)
    end

    _movement:Unfreeze(bv)
    if oldCF and hrp.Parent then
        _movement:Teleport(SAFE_SPOT)
    end
    task.wait(.15)
    _movement:SetNoclip(false)

    if collected and fired then
        SpawnedItems[index] = nil
        lastItemTime = tick()
        print("[Farm] Collected: " .. itemInfo.Name)
        return true
    end

    -- Keep a live item in the queue so a transient prompt failure can retry.
    if model and model.Parent then
        local refreshed = GetItemInfo(model)
        if refreshed then SpawnedItems[index] = refreshed end
    else
        SpawnedItems[index] = nil
    end
    warn("[Farm] Collection was not confirmed: " .. tostring(itemInfo.Name))
    return false
end

-- Helper to check if we should skip hopping (based solely on UI toggle)
local function shouldSkipHop()
    local stay = _config:Get("StayInPrivateServer")
    if stay then
        print("[Farm] StayInPrivateServer is ON – skipping all hops.")
        return true
    end
    return false
end

local function DoHop()
    if not _config:Get("FarmEnabled") then return end

    if shouldSkipHop() then
        print("[Farm] DoHop aborted – skipping hop.")
        return
    end

    print("[Farm] Server dry — selling, buying, then hopping...")
    _inventory:SellAll()
    _inventory:BuyLucky()
    _serverHop:Hop()
    lastItemTime = tick()
end

local function SetupWebhookListener()
    local connection = Player.Backpack.ChildAdded:Connect(function(tool)
        if tool.Name == "Lucky Arrow" and _inventory:ShouldStopPhase1() then
            _webhook:SendLuckyFound(
                _inventory:Count("Lucky Arrow"),
                _inventory:GetLuckyStop(),
                _inventory:GetMoney()
            )
        end
    end)
    table.insert(runtimeConnections, connection)
end

local function Startup()
    SkipLoadingScreen()

    local waitTime = 0
    repeat
        task.wait(0.5)
        waitTime = waitTime + 0.5
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

local function shouldPauseCycle()
    return stopRequested or not _config:Get("FarmEnabled") or _config:Get("AutoPrestige")
end

local function runCycle()
    lastItemTime = tick()
    _config:SetMany({ Phase1Notified = false, Phase3Notified = false })

    -- ===== PHASE 1 =====
    print("[Farm] >>> Phase 1 started — farming normally.")
    while not stopRequested and _config:Get("FarmEnabled") and not _config:Get("AutoPrestige")
      and not _inventory:ShouldStopPhase1() do
        local snapshot = {}
        for idx, info in pairs(SpawnedItems) do
            table.insert(snapshot, {Index=idx, ItemInfo=info})
        end

        for _, entry in ipairs(snapshot) do
            if shouldPauseCycle() or _inventory:ShouldStopPhase1() then break end
            CollectItem(entry.ItemInfo, entry.Index)
        end

        if shouldPauseCycle() then return end

        local elapsed = tick() - lastItemTime
        if elapsed > NO_ITEM_TIMEOUT then
            if not _inventory:ShouldStopPhase1() then DoHop() end
        elseif #snapshot == 0 then
            print("[Farm] Waiting for items... (" .. math.max(0, math.floor(NO_ITEM_TIMEOUT - elapsed)) .. "s until hop)")
        end
        task.wait(1)
    end

    -- A pause/prestige transition is not a completed phase.
    if shouldPauseCycle() then return end

    _inventory:SellAll()
    if shouldPauseCycle() then return end
    _inventory:BuyLucky()
    if shouldPauseCycle() then return end
    print("[Farm] >>> Phase 1 complete.")

    -- ===== PHASE 2 =====
    local keepItems = _inventory:GetKeepItems()
    if #keepItems > 0 then
        if not _config:Get("Phase1Notified") then
            _webhook:SendPhase1Complete(_inventory:Count("Lucky Arrow"), _inventory:GetLuckyStop(), _inventory:GetMoney())
            _config:Set("Phase1Notified", true)
        end

        print("[Farm] >>> Phase 2 started — farming keep-items: " .. table.concat(keepItems, ", "))
        while not stopRequested and _config:Get("FarmEnabled") and not _config:Get("AutoPrestige")
          and not _inventory:AllKeepItemsFull() do
            local snapshot = {}
            for idx, info in pairs(SpawnedItems) do
                local isKeep = _config:GetSellItem(info.Name) == false
                if isKeep and not _inventory:HasMax(info.Name) then
                    table.insert(snapshot, {Index=idx, ItemInfo=info})
                elseif not isKeep then
                    SpawnedItems[idx] = nil
                end
            end

            for _, entry in ipairs(snapshot) do
                if shouldPauseCycle() or _inventory:AllKeepItemsFull() then break end
                CollectItem(entry.ItemInfo, entry.Index)
            end

            if shouldPauseCycle() then return end

            local elapsed = tick() - lastItemTime
            if elapsed > NO_ITEM_TIMEOUT then
                if not _inventory:AllKeepItemsFull() then
                    print("[Farm] Phase 2 — server dry, hopping...")
                    DoHop()
                end
            elseif #snapshot == 0 then
                print("[Farm] Waiting for keep-items... (" .. math.max(0, math.floor(NO_ITEM_TIMEOUT - elapsed)) .. "s until hop)")
            end
            task.wait(1)
        end

        if shouldPauseCycle() then return end
        print("[Farm] >>> Phase 2 complete — all keep-items maxed.")
    else
        print("[Farm] >>> No keep-items configured — skipping Phase 2.")
    end

    if shouldPauseCycle() then return end

    -- ===== PHASE 3 =====
    if not _config:Get("Phase3Notified") then
        print("[Farm] Sending 'All farming complete' webhook...")
        _webhook:SendAllComplete(_inventory:Count("Lucky Arrow"), _inventory:GetLuckyStop(), _inventory:GetMoney())
        _config:Set("Phase3Notified", true)
    end

    print("[Farm] >>> Phase 3 — idle; collecting Lucky Arrow / Lucky Stone Mask only.")
    updateConfigSnapshot()

    while not stopRequested and _config:Get("FarmEnabled") and not _config:Get("AutoPrestige") do
        if not _inventory:ShouldStopPhase1() then
            print("[Farm] >>> Lucky count or money dropped below minimum — returning to Phase 1.")
            _config:SetMany({ Phase1Notified = false, Phase3Notified = false })
            lastItemTime = tick()
            return
        end

        if hasConfigChanged() then
            print("[Farm] >>> Item configuration changed — returning to Phase 1.")
            updateConfigSnapshot()
            _config:SetMany({ Phase1Notified = false, Phase3Notified = false })
            lastItemTime = tick()
            return
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
            if shouldPauseCycle() then return end
            CollectItem(entry.ItemInfo, entry.Index)
        end
        task.wait(1)
    end
end

function Farm:Start()
    if isRunning then
        print("[Farm] Start ignored — already running.")
        return
    end

    isRunning = true
    stopRequested = false

    if not runtimeSetup then
        runtimeSetup = true
        ApplyHooks()
        ApplyCrashBypass()
        ApplyAntiAfk()
        InitItemDetection()
        SetupWebhookListener()
        Startup()
    end

    print("[Farm] Farm loop started.")

    while not stopRequested do
        while not stopRequested and not _config:Get("FarmEnabled") do
            task.wait(0.5)
        end
        while not stopRequested and _config:Get("AutoPrestige") do
            task.wait(0.5)
        end
        if stopRequested then break end

        local ok, err = pcall(runCycle)
        if not ok then
            warn("[Farm] Cycle error: " .. tostring(err))
            task.wait(2)
        end
    end

    isRunning = false
    _movement:SetNoclip(false)
    print("[Farm] Farm loop stopped.")
end

function Farm:Stop()
    stopRequested = true
    _movement:SetNoclip(false)
    print("[Farm] Stop requested.")
end

function Farm:IsRunning()
    return isRunning
end

function Farm:Destroy()
    self:Stop()
    for _, connection in ipairs(runtimeConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(runtimeConnections)
    runtimeSetup = false
    table.clear(SpawnedItems)
end

return Farm
