-- =====================
-- Inventory.lua
-- Handles item counting, selling, buying, and keep-item logic.
-- Updated for YBA's new dialogue system (v1.7974+).
-- Uses DialogueGui clicking instead of the old EndDialogue remote.
-- =====================

local Players             = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local MarketplaceService  = game:GetService("MarketplaceService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local Player    = Players.LocalPlayer
local Inventory = {}

local _config   = nil
local _movement = nil

-- =====================
-- CONSTANTS
-- =====================
local LUCKY_STOP  = 9
local MONEY_STOP  = 1000000
local GAMEPASS_2X = 14597778
local _has2x      = false

-- Maximum item counts per item type (doubled if player owns 2x gamepass)
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

-- =====================
-- INIT
-- =====================
function Inventory:Init(Modules)
    _config   = Modules.Config
    _movement = Modules.Movement

    -- Detect 2x gamepass and double all item caps
    pcall(function()
        _has2x = MarketplaceService:UserOwnsGamePassAsync(Player.UserId, GAMEPASS_2X)
    end)
    if _has2x then
        for k, v in pairs(MaxItemAmounts) do
            MaxItemAmounts[k] = v * 2
        end
        print("[Inventory] 2x gamepass detected — item caps doubled.")
    else
        print("[Inventory] Initialized (no 2x gamepass).")
    end
end

-- =====================
-- ITEM COUNTING
-- =====================

-- Counts how many of a given item the player currently has
-- (checks both Backpack and Character)
function Inventory:Count(name)
    local count = 0

    -- Count in backpack
    if Player.Backpack then
        for _, tool in pairs(Player.Backpack:GetChildren()) do
            if tool.Name == name then
                count = count + 1
            end
        end
    end

    -- Count equipped tools in character
    if Player.Character then
        for _, obj in pairs(Player.Character:GetChildren()) do
            if obj:IsA("Tool") and obj.Name == name then
                count = count + 1
            end
        end
    end

    return count
end

-- Returns true if the player has reached the max cap for the item
function Inventory:HasMax(name)
    local cap = MaxItemAmounts[name]
    if not cap then return false end
    return self:Count(name) >= cap
end

-- Returns the max cap for the given item (or 0 if unknown)
function Inventory:GetMax(name)
    return MaxItemAmounts[name] or 0
end

-- =====================
-- PLAYER STATS HELPERS
-- =====================

-- Returns the player's current money (from PlayerStats)
function Inventory:GetMoney()
    local ok, val = pcall(function()
        return Player.PlayerStats.Money.Value
    end)
    return ok and val or 0
end

-- Phase 1 thresholds
function Inventory:GetLuckyStop()     return LUCKY_STOP end
function Inventory:GetMoneyStop()     return MONEY_STOP end
function Inventory:HasEnoughLucky()   return self:Count("Lucky Arrow") >= LUCKY_STOP end
function Inventory:IsMoneyMaxed()     return self:GetMoney() >= MONEY_STOP end
function Inventory:ShouldStopPhase1() return self:HasEnoughLucky() and self:IsMoneyMaxed() end

-- =====================
-- KEEP ITEMS LOGIC
-- =====================

-- Returns a list of items the user wants to keep (sell = false)
-- Lucky Arrow and Lucky Stone Mask are always excluded
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

-- Returns true if ALL keep-items are at max capacity
function Inventory:AllKeepItemsFull()
    local keepItems = self:GetKeepItems()
    if #keepItems == 0 then return true end
    for _, name in ipairs(keepItems) do
        if not self:HasMax(name) then
            return false
        end
    end
    return true
end

-- =====================
-- DIALOGUE CLICKING HELPERS
-- (YBA v1.7974+ uses a client-side DialogueGui — no more sell remote)
-- =====================

-- Attempts to click a GuiButton using multiple methods
-- Returns true if at least one method was attempted successfully
local function clickButton(btn)
    if not btn then return false end

    -- Method 1: firesignal (fastest, works if executor supports it)
    local ok1 = pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
        end
    end)
    if ok1 then
        return true
    end

    -- Method 2: VirtualInputManager (physical click via screen coords)
    -- This always works as long as the button is visible on screen
    local ok2 = pcall(function()
        local absPos  = btn.AbsolutePosition
        local absSize = btn.AbsoluteSize
        local x = absPos.X + absSize.X / 2
        local y = absPos.Y + absSize.Y / 2

        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true,  game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)

    return ok2
end

-- Searches DialogueGui.Options for an option whose TextButton contains
-- the given text. Returns the TextButton (or nil on timeout).
local function findOptionByText(text, timeout)
    timeout = timeout or 5
    local start = tick()

    while tick() - start < timeout do
        local dlg = Player.PlayerGui:FindFirstChild("DialogueGui")
        if dlg then
            local opts = dlg:FindFirstChild("Options")
            if opts then
                for _, opt in ipairs(opts:GetChildren()) do
                    local btn = opt:FindFirstChild("TextButton", true)
                    if btn then
                        local btnText = btn.Text or ""
                        if btnText:find(text, 1, true) then
                            return btn
                        end
                    end
                end
            end
        end
        task.wait(0.15)
    end

    return nil
end

-- Waits for an option matching the text and clicks it.
-- Returns true on success, false on timeout.
local function waitAndClick(text, timeout)
    local btn = findOptionByText(text, timeout)
    if btn then
        clickButton(btn)
        return true
    end
    return false
end

-- =====================
-- SELL ALL
-- Sells every item marked as "sell = true" in the config.
-- Walks through the new dialogue flow:
--   1. "I'd like to sell this..."
--   2. "Deal."
--   3. "I'll sell ALL of these."
-- =====================
function Inventory:SellAll()
    -- Guard clauses
    if not _config:Get("FarmEnabled") then return end
    if self:IsMoneyMaxed() then
        print("[Inventory] Money already maxed — skipping sell.")
        return
    end
    if not _config:Get("AutoSell") then
        print("[Inventory] AutoSell disabled — skipping sell.")
        return
    end

    -- Build list of items to sell
    local sellItems = _config:GetSellItems()
    local toSell = {}

    for name, sell in pairs(sellItems) do
        if sell then
            local count = self:Count(name)
            if count > 0 then
                table.insert(toSell, name)
            end
        end
    end

    if #toSell == 0 then
        print("[Inventory] No items to sell.")
        return
    end

    print("[Inventory] Selling " .. #toSell .. " item type(s)...")

    -- Locate the Merchant ProximityPrompt
    local merchantPrompt
    local dlgFolder = ReplicatedStorage:FindFirstChild("Dialogue")
    if dlgFolder then
        local merchant = dlgFolder:FindFirstChild("Merchant")
        if merchant then
            merchantPrompt = merchant:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
    end

    -- Fallback: search workspace
    if not merchantPrompt then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:find("Merchant") then
                local pp = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
                if pp then
                    merchantPrompt = pp
                    break
                end
            end
        end
    end

    if not merchantPrompt then
        warn("[Inventory] Merchant ProximityPrompt not found — cannot sell.")
        return
    end

    local soldCount   = 0
    local failedCount = 0

    -- Sell each item type
    for _, itemName in ipairs(toSell) do
        -- Re-fetch the tool (might be in backpack or equipped)
        local tool = Player.Backpack:FindFirstChild(itemName)
        if not tool and Player.Character then
            tool = Player.Character:FindFirstChild(itemName)
        end

        if tool then
            -- Equip the item so the server knows which one to sell
            local char = Player.Character
            local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
            if hum and tool.Parent == Player.Backpack then
                hum:EquipTool(tool)
                task.wait(0.15)
            end

            -- Open the dialogue via ProximityPrompt
            pcall(function() fireproximityprompt(merchantPrompt) end)
            task.wait(0.8)

            -- Step 1: "I'd like to sell this..."
            local step1 = waitAndClick("I'd like to sell this", 3)
            if not step1 then
                step1 = waitAndClick("sell", 2)
            end
            task.wait(0.6)

            -- Step 2: "Deal."
            if step1 then
                local step2 = waitAndClick("Deal.", 3)
                if not step2 then
                    step2 = waitAndClick("Deal", 2)
                end
                task.wait(0.6)

                -- Step 3: "I'll sell ALL of these."
                if step2 then
                    local step3 = waitAndClick("sell ALL", 3)
                    if not step3 then
                        step3 = waitAndClick("ALL", 2)
                    end

                    -- Fallback: click the last option in the menu
                    if not step3 then
                        local dlg = Player.PlayerGui:FindFirstChild("DialogueGui")
                        if dlg then
                            local opts = dlg:FindFirstChild("Options")
                            if opts then
                                local children = opts:GetChildren()
                                local last = children[#children]
                                if last then
                                    local btn = last:FindFirstChild("TextButton", true)
                                    if btn then
                                        clickButton(btn)
                                        step3 = true
                                    end
                                end
                            end
                        end
                    end

                    task.wait(1.2)

                    -- Verify the item was actually sold
                    local stillHas = Player.Backpack:FindFirstChild(itemName)
                    if not stillHas and Player.Character then
                        stillHas = Player.Character:FindFirstChild(itemName)
                    end

                    if not stillHas then
                        soldCount = soldCount + 1
                        print("[Inventory] ✅ Sold: " .. itemName)
                    else
                        failedCount = failedCount + 1
                        warn("[Inventory] ❌ Failed to sell: " .. itemName)
                    end
                else
                    failedCount = failedCount + 1
                    warn("[Inventory] ❌ 'Deal.' not found for: " .. itemName)
                end
            else
                failedCount = failedCount + 1
                warn("[Inventory] ❌ 'I'd like to sell this...' not found for: " .. itemName)
            end

            task.wait(0.3)
        end
    end

    print("[Inventory] SellAll done — Sold: " .. soldCount .. " | Failed: " .. failedCount)
end

-- =====================
-- BUY LUCKY ARROWS
-- =====================
function Inventory:BuyLucky()
    if not _config:Get("FarmEnabled") then return end
    if not _config:Get("BuyLucky")     then return end
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
        attempts = attempts + 1

        local count = self:Count("Lucky Arrow")
        print("[Inventory] Lucky Arrows: " .. count .. "/" .. LUCKY_STOP)

        if count >= LUCKY_STOP then
            print("[Inventory] Reached " .. LUCKY_STOP .. " Lucky Arrows — stopping purchase (YBA bug).")
            break
        end
    end
end

-- =====================
-- STAND UTILITIES (used by CombatFarm)
-- =====================

-- Returns the name of the player's currently equipped stand
function Inventory:GetCurrentStand()
    if Player and Player.PlayerStats and Player.PlayerStats.Stand then
        return Player.PlayerStats.Stand.Value
    end
    return "None"
end

-- Returns true if the player has any stand equipped
function Inventory:HasStand()
    return self:GetCurrentStand() ~= "None"
end

-- Attempts to summon the stand if it is currently unsummoned.
-- Returns true if the stand was summoned by this call.
function Inventory:SummonStand()
    local char = Player.Character
    if not char then return false end

    local remoteFunc = char:FindFirstChild("RemoteFunction")
    if not remoteFunc then return false end

    local summoned = char:FindFirstChild("SummonedStand")
    if summoned and summoned.Value == false then
        remoteFunc:InvokeServer("ToggleStand", "Toggle")
        task.wait(0.3)
        return true
    end

    return false
end

return Inventory
