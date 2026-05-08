-- =====================
-- Inventory.lua
-- Handles item counting, selling, buying, and keep-item logic.
-- =====================

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Player = Players.LocalPlayer

local Inventory = {}

local _config   = nil
local _movement = nil

-- =====================
-- STOP CONDITIONS
-- =====================
local LUCKY_STOP = 9
local MONEY_STOP = 1000000

-- Gamepass ID for 2x item cap
local GAMEPASS_2X = 14597778

local _has2x = false

local MaxItemAmounts = {
    ["Gold Coin"]                       = 45,
    ["Rokakaka"]                        = 25,
    ["Pure Rokakaka"]                   = 10,
    ["Mysterious Arrow"]                = 25,
    ["Diamond"]                         = 30,
    ["Ancient Scroll"]                  = 10,
    ["Caesar's Headband"]               = 10,
    ["Stone Mask"]                      = 10,
    ["Rib Cage of The Saint's Corpse"]  = 20,
    ["Quinton's Glove"]                 = 10,
    ["Zeppeli's Hat"]                   = 10,
    ["Lucky Arrow"]                     = 10,
    ["Lucky Stone Mask"]                = 10,
    ["Clackers"]                        = 10,
    ["Steel Ball"]                      = 10,
    ["Dio's Diary"]                     = 10,
}

function Inventory:Init(Modules)
    _config   = Modules.Config
    _movement = Modules.Movement

    -- Check 2x gamepass and double caps if owned
    pcall(function()
        _has2x = MarketplaceService:UserOwnsGamePassAsync(Player.UserId, GAMEPASS_2X)
    end)
    if _has2x then
        for k, v in pairs(MaxItemAmounts) do
            MaxItemAmounts[k] = v * 2
        end
        print("[Inventory] 2x gamepass detected — item caps doubled.")
    end
end

-- =====================
-- ITEM COUNTING
-- =====================
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

-- =====================
-- ECONOMY
-- =====================
function Inventory:GetMoney()
    local ok, val = pcall(function()
        return Player.PlayerStats.Money.Value
    end)
    return ok and val or 0
end

-- =====================
-- STOP CONDITIONS
-- =====================
function Inventory:GetLuckyStop()  return LUCKY_STOP end
function Inventory:GetMoneyStop()  return MONEY_STOP end

function Inventory:HasEnoughLucky()
    return self:Count("Lucky Arrow") >= LUCKY_STOP
end

function Inventory:IsMoneyMaxed()
    return self:GetMoney() >= MONEY_STOP
end

function Inventory:ShouldStopPhase1()
    return self:HasEnoughLucky() and self:IsMoneyMaxed()
end

-- =====================
-- KEEP-ITEM LOGIC
-- Items where SellItems[name] == false, excluding Lucky items
-- (Lucky Arrow and Lucky Stone Mask are handled separately)
-- =====================
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

-- =====================
-- SELL ALL ENABLED ITEMS
-- =====================
function Inventory:SellAll()
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
                char.Humanoid:EquipTool(Player.Backpack:FindFirstChild(name))
                char.RemoteEvent:FireServer("EndDialogue", {
                    NPC      = "Merchant",
                    Dialogue = "Dialogue5",
                    Option   = "Option2",
                })
            end)
            task.wait(.1)
        end
    end
end

-- =====================
-- BUY LUCKY ARROWS
-- Stops at LUCKY_STOP - 1 due to YBA bug on the last purchase
-- =====================
function Inventory:BuyLucky()
    if not _config:Get("BuyLucky") then return end
    if self:Count("Lucky Arrow") >= LUCKY_STOP then return end
    local money = self:GetMoney()
    if money < 75000 then return end

    print("[Inventory] Buying Lucky Arrows... ($" .. money .. ")")
    local attempts = 0

    while self:GetMoney() >= 75000 and attempts < 15 do
        pcall(function()
            Player.Character.RemoteEvent:FireServer("PurchaseShopItem", {
                ItemName = "1x Lucky Arrow"
            })
        end)
        task.wait(1)
        attempts += 1
        local count = self:Count("Lucky Arrow")
        print("[Inventory] Lucky Arrows: " .. count .. "/" .. LUCKY_STOP)
        if count >= LUCKY_STOP then
            print("[Inventory] Reached " .. LUCKY_STOP .. " Lucky Arrows — stopping (YBA bug prevents buying the last one).")
            break
        end
    end
end

return Inventory
