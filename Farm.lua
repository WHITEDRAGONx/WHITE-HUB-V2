-- =====================
-- Farm.lua
-- =====================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
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

function Farm:Init(Modules)
    _config    = Modules.Config
    _inventory = Modules.Inventory
    _movement  = Modules.Movement
    _serverHop = Modules.ServerHop
    _webhook   = Modules.Webhook
end

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
        warn("[Farm] Item_Spawns/Items não encontrado.")
        return
    end
    print("[Farm] Item_Spawns/Items encontrado.")
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
                    print("[Farm] Item detectado: " .. info.Name)
                end
            end
        end)
    end)
end

local SAFE_SPOT = CFrame.new(978, -42, -49)

local function CollectItem(itemInfo, index)
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
    print("[Farm] Coletado: " .. itemInfo.Name)
end

local function DoHop()
    print("[Farm] Server seco — vendendo, comprando e trocando...")
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

    -- ✅ PATCH: repeat com timeout de 30s em vez de loop infinito
    local waitTime = 0
    repeat
        task.wait(0.5)
        waitTime += 0.5
        if waitTime > 30 then
            warn("[Farm] Timeout esperando RemoteEvent — continuando mesmo assim.")
            break
        end
    until _movement:GetCharacter("RemoteEvent")

    print("[Farm] Character carregado.")
    pcall(function()
        _movement:GetCharacter("RemoteEvent"):FireServer("PressedPlay")
    end)

    print("[Farm] Teleportando para safe spot...")
    _movement:Teleport(SAFE_SPOT)
    task.wait(1)
    _movement:FixCamera()

    local hrp = _movement:GetCharacter("HumanoidRootPart")
    if hrp then print("[Farm] Posição: " .. tostring(hrp.Position))
    else warn("[Farm] HumanoidRootPart não encontrado.") end

    print("[Farm] Aguardando 5s antes do loop...")
    task.wait(5)
end

function Farm:Start()
    ApplyHooks()
    ApplyCrashBypass()
    ApplyAntiAfk()
    InitItemDetection()
    SetupWebhookListener()
    Startup()

    print("[Farm] Loop iniciado.")

    while true do
        print("[Farm] >>> Phase 1 — farmando normalmente.")
        while not _inventory:ShouldStopPhase1() do
            local snapshot = {}
            for idx, info in pairs(SpawnedItems) do
                table.insert(snapshot, {Index=idx, ItemInfo=info})
            end
            for _, entry in ipairs(snapshot) do
                if _inventory:ShouldStopPhase1() then break end
                CollectItem(entry.ItemInfo, entry.Index)
            end
            local elapsed = tick() - lastItemTime
            if elapsed > NO_ITEM_TIMEOUT then
                if _inventory:ShouldStopPhase1() then break end
                DoHop()
            else
                if #snapshot == 0 then
                    print("[Farm] Aguardando items... (" .. math.floor(NO_ITEM_TIMEOUT - elapsed) .. "s até hop)")
                end
            end
            task.wait(1)
        end

        _inventory:SellAll()
        _inventory:BuyLucky()
        print("[Farm] >>> Phase 1 completa.")
        _webhook:SendPhase1Complete(_inventory:Count("Lucky Arrow"), _inventory:GetLuckyStop(), _inventory:GetMoney())

        local keepItems = _inventory:GetKeepItems()
        if #keepItems > 0 then
            print("[Farm] >>> Phase 2 — farmando keep-items: " .. table.concat(keepItems, ", "))
            while not _inventory:AllKeepItemsFull() do
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
                    if _inventory:AllKeepItemsFull() then break end
                    CollectItem(entry.ItemInfo, entry.Index)
                end
                local elapsed = tick() - lastItemTime
                if elapsed > NO_ITEM_TIMEOUT then
                    if _inventory:AllKeepItemsFull() then break end
                    print("[Farm] Phase 2 — server seco, trocando...")
                    _serverHop:Hop()
                    lastItemTime = tick()
                else
                    if #snapshot == 0 then
                        print("[Farm] Aguardando keep-items... (" .. math.floor(NO_ITEM_TIMEOUT - elapsed) .. "s até hop)")
                    end
                end
                task.wait(1)
            end
            print("[Farm] >>> Phase 2 completa.")
        else
            print("[Farm] >>> Sem keep-items — pulando Phase 2.")
        end

        print("[Farm] >>> Phase 3 — idling, só coletando Lucky Arrows.")
        _webhook:SendAllComplete(_inventory:Count("Lucky Arrow"), _inventory:GetLuckyStop(), _inventory:GetMoney())

        while true do
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
            task.wait(3)
        end
    end
end

function Farm:Stop()
    print("[Farm] Stop solicitado.")
end

return Farm
