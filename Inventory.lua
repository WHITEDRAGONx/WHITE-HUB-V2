-- =====================
-- Inventory.lua
-- Handles item counting, selling, buying, and keep-item logic.
-- =====================

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Player    = Players.LocalPlayer
local Inventory = {}

local _config   = nil
local _movement = nil

local LUCKY_STOP  = 9
local MONEY_STOP  = 1000000
local GAMEPASS_2X = 14597778
local _has2x      = false

local MaxItemAmounts = {
    ["Gold Coin"]                      = 45,
    ["Rokakaka"]                       = 25,
    ["Pure Rokakaka"]                  = 10,
    ["Mysterious Arrow"]               = 25,
    ["Diamond"]                        = 30,
    ["Ancient Scroll"]                 = 10,
    ["Caesar's Headband"]              = 10,
    ["Stone Mask"]                     = 10,
    ["Rib Cage of The Saint's Corpse"] = 20,
    ["Quinton's Glove"]                = 10,
    ["Zeppeli's Hat"]                  = 10,
    ["Lucky Arrow"]                    = 10,
    ["Lucky Stone Mask"]               = 10,
    ["Clackers"]                       = 10,
    ["Steel Ball"]                     = 10,
    ["Dio's Diary"]                    = 10,
}

function Inventory:Init(Modules)
    _config   = Modules.Config
    _movement = Modules.Movement
    pcall(function()
        _has2x = MarketplaceService:UserOwnsGamePassAsync(Player.UserId, GAMEPASS_2X)
    end)
    if _has2x then
        for k, v in pairs(MaxItemAmounts) do MaxItemAmounts[k] = v * 2 end
        print("[Inventory] 2x gamepass detected — item caps doubled.")
    end
end

function Inventory:Count(name)
    local count = 0
    if Player.Backpack then
        for _, tool in pairs(Player.Backpack:GetChildren()) do
            if tool.Name == name then count += 1 end
        end
    end
    if Player.Character then
        for _, obj in pairs(Player.Character:GetChildren()) do
            if obj:IsA("Tool") and obj.Name == name then count += 1 end
        end
    end
    return count
end

function Inventory:HasMax(name)
    local cap = MaxItemAmounts[name]
    if not cap then return false end
    return self:Count(name) >= cap
end

function Inventory:GetMax(name)
    return MaxItemAmounts[name] or 0
end

function Inventory:GetMoney()
    local ok, val = pcall(function() return Player.PlayerStats.Money.Value end)
    return ok and val or 0
end

function Inventory:GetLuckyStop()     return LUCKY_STOP end
function Inventory:GetMoneyStop()     return MONEY_STOP end
function Inventory:HasEnoughLucky()   return self:Count("Lucky Arrow") >= LUCKY_STOP end
function Inventory:IsMoneyMaxed()     return self:GetMoney() >= MONEY_STOP end
function Inventory:ShouldStopPhase1() return self:HasEnoughLucky() and self:IsMoneyMaxed() end

function Inventory:GetKeepItems()
    local sellItems = _config:GetSellItems()
    local list = {}
    for name, sell in pairs(sellItems) do
        if not sell and name ~= "Lucky Arrow" and name ~= "Lucky Stone Mask" then
            table.insert(list, name)
        end
    end
    return list
end

function Inventory:AllKeepItemsFull()
    local keepItems = self:GetKeepItems()
    if #keepItems == 0 then return true end
    for _, name in ipairs(keepItems) do
        if not self:HasMax(name) then return false end
    end
    return true
end

function Inventory:SellAll()
    if not _config:Get("FarmEnabled") then return end
    if self:IsMoneyMaxed() then
        print("[Inventory] Money already maxed — skipping sell.")
        return
    end
    if not _config:Get("AutoSell") then return end

    local sellItems = _config:GetSellItems()
    for name, sell in pairs(sellItems) do
        if sell and Player.Backpack and Player.Backpack:FindFirstChild(name) then
            pcall(function()
                local char = Player.Character
                if not char then return end
                local hum = char:FindFirstChildWhichIsA("Humanoid")
                if not hum then return end
                local re = char:FindFirstChild("RemoteEvent")
                if not re then
                    warn("[Inventory] RemoteEvent not found — sell skipped for: " .. name)
                    return
                end
                hum:EquipTool(Player.Backpack:FindFirstChild(name))
                re:FireServer("EndDialogue", {
                    NPC      = "Merchant",
                    Dialogue = "Dialogue5",
                    Option   = "Option2",
                })
            end)
            task.wait(.1)
        end
    end
end

function Inventory:BuyLucky()
    if not _config:Get("FarmEnabled") then return end
    if not _config:Get("BuyLucky") then return end
    if self:Count("Lucky Arrow") >= LUCKY_STOP then return end
    local money = self:GetMoney()
    if money < 75000 then return end

    print("[Inventory] Buying Lucky Arrows... ($" .. money .. ")")
    local attempts = 0

    while self:GetMoney() >= 75000 and attempts < 15 do
        pcall(function()
            local char = Player.Character
            if not char then return end
            local re = char:FindFirstChild("RemoteEvent")
            if not re then return end
            re:FireServer("PurchaseShopItem", { ItemName = "1x Lucky Arrow" })
        end)
        task.wait(1)
        attempts += 1
        local count = self:Count("Lucky Arrow")
        print("[Inventory] Lucky Arrows: " .. count .. "/" .. LUCKY_STOP)
        if count >= LUCKY_STOP then
            print("[Inventory] Reached " .. LUCKY_STOP .. " Lucky Arrows — stopping purchase (YBA bug).")
            break
        end
    end
end

-- =====================
-- Stand utilities (for quest/NPC farming)
-- =====================
function Inventory:GetCurrentStand()
    if Player and Player.PlayerStats and Player.PlayerStats.Stand then
        return Player.PlayerStats.Stand.Value
    end
    return "None"
end

function Inventory:HasStand()
    return self:GetCurrentStand() ~= "None"
end

function Inventory:SummonStand()
    local char = Player.Character
    if not char then return false end
    local remoteFunc = char:FindFirstChild("RemoteFunction")
    if not remoteFunc then return false end
    local summoned = char:FindFirstChild("SummonedStand")
    if summoned and summoned.Value == false then
        remoteFunc:InvokeServer("ToggleStand", "Toggle")
        task.wait(0.5)
        return true
    end
    return false
end

return Inventory
