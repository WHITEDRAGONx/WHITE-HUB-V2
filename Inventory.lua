-- =====================
-- Inventory.lua
-- Handles item counting, selling, buying, and keep-item logic.
-- Updated for YBA's new dialogue system (v1.7974+).
-- Prefers direct Merchant EndDialogue selling; falls back to DialogueGui automation.
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

local _runtimeLog = nil
local _rawPrint, _rawWarn = print, warn
local function moduleLog(level, ...)
    if _runtimeLog and type(_runtimeLog.Write) == "function" then
        pcall(_runtimeLog.Write, _runtimeLog, level, "Inventory", ...)
    end
    if level == "WARN" or level == "ERROR" then
        _rawWarn(...)
    else
        _rawPrint(...)
    end
end

-- =====================
-- INIT
-- =====================
function Inventory:Init(Modules)
    _runtimeLog = Modules.RuntimeLog
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
        moduleLog("INFO", "[Inventory] 2x gamepass detected — item caps doubled.")
    else
        moduleLog("INFO", "[Inventory] Initialized (no 2x gamepass).")
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
-- YBA 1.7974+ uses the newer client-side dialogue system.
-- The Merchant wording/options can change, so selling is intent-based
-- instead of depending on one exact sentence sequence.
-- =====================

local function normalizeText(text)
    text = tostring(text or ""):lower()
    text = text:gsub("[%c%p]", " ")
    text = text:gsub("%s+", " ")
    return text:match("^%s*(.-)%s*$") or ""
end

local function getButtonText(btn)
    if not btn then return "" end

    if btn:IsA("TextButton") then
        local direct = tostring(btn.Text or "")
        if direct ~= "" then
            return direct
        end
    end

    -- Some dialogue versions put the visible text in a child TextLabel.
    for _, child in ipairs(btn:GetDescendants()) do
        if child:IsA("TextLabel") and tostring(child.Text or "") ~= "" then
            return child.Text
        end
    end

    return ""
end

local function isActuallyVisible(guiObject)
    if not guiObject or not guiObject.Parent then return false end
    if guiObject:IsA("GuiObject") and guiObject.Visible == false then return false end

    local parent = guiObject.Parent
    while parent and parent ~= Player.PlayerGui do
        if parent:IsA("GuiObject") and parent.Visible == false then
            return false
        end
        parent = parent.Parent
    end

    return true
end

local function getDialogueGui()
    local direct = Player.PlayerGui:FindFirstChild("DialogueGui")
    if direct then return direct end

    -- Fallback for renamed/new dialogue containers.
    for _, obj in ipairs(Player.PlayerGui:GetChildren()) do
        local lowered = tostring(obj.Name):lower()
        if lowered:find("dialog", 1, true) then
            return obj
        end
    end

    return nil
end

local function getVisibleDialogueButtons()
    local dlg = getDialogueGui()
    if not dlg then return {} end

    local buttons = {}
    for _, obj in ipairs(dlg:GetDescendants()) do
        if obj:IsA("GuiButton") and isActuallyVisible(obj) then
            local text = getButtonText(obj)
            if normalizeText(text) ~= "" then
                table.insert(buttons, {
                    Button = obj,
                    Text = text,
                    Normalized = normalizeText(text),
                })
            end
        end
    end

    return buttons
end

local function describeButtons(buttons)
    local texts = {}
    for _, entry in ipairs(buttons) do
        table.insert(texts, tostring(entry.Text))
    end
    return table.concat(texts, " | ")
end

-- Internal click support lets Fast Sell drive dialogue without visibly clicking it.
local function hasInternalClickSupport()
    return type(firesignal) == "function" or type(getconnections) == "function"
end

local function fastClickButton(btn)
    if not btn or not btn.Parent then return false end

    -- Preferred path: directly fire the Roblox signal. This does not require
    -- the button to be visible on screen.
    if type(firesignal) == "function" then
        local ok = pcall(function()
            firesignal(btn.MouseButton1Click)
        end)
        if ok then return true end
    end

    -- Executor fallback: call MouseButton1Click connections directly.
    -- MouseButton1Click carries no arguments, so this is safer than trying
    -- to invoke Activated callbacks with fabricated InputObjects.
    if type(getconnections) == "function" then
        local ok, connections = pcall(function()
            return getconnections(btn.MouseButton1Click)
        end)
        if ok and type(connections) == "table" then
            local invoked = false
            for _, connection in ipairs(connections) do
                local enabled = true
                pcall(function()
                    if connection.Enabled ~= nil then
                        enabled = connection.Enabled
                    end
                end)

                if enabled then
                    local fn = nil
                    pcall(function() fn = connection.Function end)
                    if type(fn) == "function" then
                        if pcall(fn) then
                            invoked = true
                        end
                    end
                end
            end
            if invoked then return true end
        end
    end

    return false
end

-- Attempts an internal click first, then a physical-screen click as the
-- compatibility fallback used by the normal visible dialogue mode.
local function clickButton(btn)
    if fastClickButton(btn) then return true end
    if not btn or not btn.Parent then return false end

    local ok = pcall(function()
        local absPos  = btn.AbsolutePosition
        local absSize = btn.AbsoluteSize
        local x = absPos.X + absSize.X / 2
        local y = absPos.Y + absSize.Y / 2

        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)

    return ok
end

-- Fast Sell suppresses ScreenGui rendering while leaving the dialogue tree
-- alive. This means signals/connections can still be invoked internally.
local suppressedDialogueGuis = {}

local function suppressDialogueRendering()
    local dlg = getDialogueGui()
    if not dlg then return false end

    if dlg:IsA("ScreenGui") then
        if suppressedDialogueGuis[dlg] == nil then
            local state = { Enabled = dlg.Enabled, Connection = nil }
            state.Connection = dlg:GetPropertyChangedSignal("Enabled"):Connect(function()
                -- YBA may try to re-enable the dialogue while opening the next
                -- page. Keep it hidden for the duration of Fast Sell.
                if suppressedDialogueGuis[dlg] and dlg.Enabled then
                    dlg.Enabled = false
                end
            end)
            suppressedDialogueGuis[dlg] = state
        end
        dlg.Enabled = false
        return true
    end

    -- If YBA changes DialogueGui into a non-ScreenGui container, do not hide
    -- it here because Visible=false would also make our option scanner ignore it.
    return false
end

local function restoreDialogueRendering()
    for dlg, state in pairs(suppressedDialogueGuis) do
        if state and state.Connection then
            pcall(function() state.Connection:Disconnect() end)
        end
        if dlg and dlg.Parent and dlg:IsA("ScreenGui") then
            pcall(function() dlg.Enabled = state and state.Enabled ~= false end)
        end
        suppressedDialogueGuis[dlg] = nil
    end
end

local NEGATIVE_WORDS = {
    "buy", "leave", "cancel", "nevermind", "never mind",
    "no thanks", "no thank", "goodbye", "exit", "nothing",
}

local function containsAny(text, words)
    for _, word in ipairs(words) do
        if text:find(word, 1, true) then
            return true
        end
    end
    return false
end

-- Scores an option by SELL intent. This intentionally does not require
-- exact English sentences so wording/format changes are less likely to break it.
local function scoreSellOption(entry)
    local text = entry.Normalized
    if text == "" then return -math.huge end
    if containsAny(text, NEGATIVE_WORDS) then return -1000 end

    local score = 0
    local hasSell = text:find("sell", 1, true) ~= nil
    local hasAll = text:find("all", 1, true) ~= nil
    local hasEverything = text:find("everything", 1, true) ~= nil
    local hasMax = text:find("max", 1, true) ~= nil

    -- Quantity selection: strongly prefer ALL/MAX/EVERYTHING.
    if hasSell and (hasAll or hasEverything or hasMax) then score = score + 220 end
    if hasAll or hasEverything or hasMax then score = score + 150 end

    -- General sell route / currently equipped item route.
    if hasSell then score = score + 100 end
    if text:find("this", 1, true) and hasSell then score = score + 30 end
    if text:find("item", 1, true) and hasSell then score = score + 20 end

    -- Confirmation pages in the new dialogue system.
    if text:find("deal", 1, true) then score = score + 90 end
    if text:find("confirm", 1, true) then score = score + 80 end
    if text == "yes" or text:find("yes ", 1, true) == 1 then score = score + 70 end
    if text == "ok" or text == "okay" or text:find("sure", 1, true) then score = score + 55 end

    -- If quantity choices are numbers only, prefer the largest-looking option
    -- only as a weak fallback; explicit ALL/MAX always wins above.
    local quantity = tonumber(text:match("(%d+)%s*x")) or tonumber(text:match("sell%s+(%d+)"))
    if quantity then
        score = score + math.min(quantity, 50)
    end

    return score
end

local function waitForDialogueButtons(timeout, fastMode)
    timeout = timeout or 3
    local started = tick()

    while tick() - started < timeout do
        local buttons = getVisibleDialogueButtons()
        if #buttons > 0 then
            return buttons
        end
        task.wait(fastMode and 0.02 or 0.1)
    end

    return {}
end

local function chooseBestSellButton(buttons)
    local bestEntry = nil
    local bestScore = -math.huge

    for _, entry in ipairs(buttons) do
        local score = scoreSellOption(entry)
        if score > bestScore then
            bestScore = score
            bestEntry = entry
        end
    end

    if bestScore <= 0 then
        return nil, bestScore
    end

    return bestEntry, bestScore
end

local function findMerchantPrompt()
    -- Known/new dialogue storage path first.
    local dlgFolder = ReplicatedStorage:FindFirstChild("Dialogue")
    if dlgFolder then
        local merchant = dlgFolder:FindFirstChild("Merchant", true)
        if merchant then
            local prompt = merchant:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then return prompt end
        end
    end

    -- Search models/folders whose ancestry identifies the Merchant.
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local parent = obj.Parent
            local matchedMerchant = false
            local depth = 0
            while parent and parent ~= workspace and depth < 6 do
                if tostring(parent.Name):lower():find("merchant", 1, true) then
                    matchedMerchant = true
                    break
                end
                parent = parent.Parent
                depth = depth + 1
            end

            local objectText = normalizeText(obj.ObjectText)
            local actionText = normalizeText(obj.ActionText)
            if matchedMerchant or objectText:find("merchant", 1, true) or actionText:find("merchant", 1, true) then
                return obj
            end
        end
    end

    return nil
end

local function closeDialogueIfOpen()
    local dlg = getDialogueGui()
    if not dlg then return end

    -- Prefer a harmless close/cancel button after a failed attempt.
    local buttons = getVisibleDialogueButtons()
    for _, entry in ipairs(buttons) do
        local t = entry.Normalized
        if t:find("leave", 1, true) or t:find("cancel", 1, true)
            or t:find("nevermind", 1, true) or t:find("never mind", 1, true)
            or t:find("goodbye", 1, true) or t:find("exit", 1, true) then
            clickButton(entry.Button)
            task.wait(0.2)
            return
        end
    end
end

-- Drives the current Merchant dialogue dynamically until the item count drops.
-- Returns true if at least one item was sold.
local function runMerchantSellDialogue(itemName, beforeCount, fastMode)
    local lastOptions = ""
    local repeatedSameState = 0
    local stepDelay = fastMode and 0.06 or 0.5

    for step = 1, 7 do
        if Inventory:Count(itemName) < beforeCount then
            return true
        end

        local timeout
        if fastMode then
            timeout = step == 1 and 0.9 or 0.65
        else
            timeout = step == 1 and 3 or 2
        end

        local buttons = waitForDialogueButtons(timeout, fastMode)
        if #buttons == 0 then
            task.wait(fastMode and 0.08 or 0.35)
            if Inventory:Count(itemName) < beforeCount then
                return true
            end
            moduleLog("WARN", "[Inventory][Dialogue] No visible dialogue options at step " .. tostring(step) .. ".")
            return false
        end

        if fastMode then
            suppressDialogueRendering()
        end

        local description = describeButtons(buttons)
        moduleLog("INFO", "[Inventory][Dialogue] Step " .. tostring(step) .. " options: " .. description)

        if description == lastOptions then
            repeatedSameState = repeatedSameState + 1
        else
            repeatedSameState = 0
            lastOptions = description
        end

        if repeatedSameState >= 2 then
            moduleLog("WARN", "[Inventory][Dialogue] Dialogue did not advance. Options: " .. description)
            return false
        end

        local chosen, score = chooseBestSellButton(buttons)
        if not chosen then
            moduleLog("WARN", "[Inventory][Dialogue] Could not identify a sell option. Options: " .. description)
            return false
        end

        moduleLog("INFO", "[Inventory][Dialogue] " .. (fastMode and "Fast-clicking: " or "Clicking: ")
            .. tostring(chosen.Text) .. " (score " .. tostring(score) .. ")")

        local clicked
        if fastMode then
            clicked = fastClickButton(chosen.Button)
        else
            clicked = clickButton(chosen.Button)
        end

        if not clicked then
            moduleLog("WARN", "[Inventory][Dialogue] Failed to activate option: " .. tostring(chosen.Text))
            return false
        end

        task.wait(stepDelay)
    end

    return Inventory:Count(itemName) < beforeCount
end

-- =====================
-- DIRECT / FALLBACK SELLING
-- Fast path first tries the old Merchant EndDialogue server action directly.
-- If the current YBA server rejects it, we fall back to the adaptive 1.7974+
-- DialogueGui driver above. The direct path never opens DialogueGui.
-- =====================
local DIRECT_SELL_ARGS = {
    NPC = "Merchant",
    Dialogue = "Dialogue5",
    Option = "Option1",
}

local function getCharacterRemoteEvent()
    local char = Player.Character
    return char and char:FindFirstChild("RemoteEvent") or nil
end

local function equipSellTool(itemName)
    local char = Player.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    if not hum then return nil end

    local tool = Player.Backpack:FindFirstChild(itemName)
    if not tool and char then
        tool = char:FindFirstChild(itemName)
    end
    if not tool then return nil end

    if tool.Parent == Player.Backpack then
        local ok = pcall(function() hum:EquipTool(tool) end)
        if not ok then return nil end
        task.wait(0.03)
    end

    return tool
end

-- Attempts to sell the equipped item without ever opening Merchant UI.
-- Returns:
--   true, soldAmount   -> direct server call worked
--   false, 0           -> no inventory progress; caller should use UI fallback
local function tryDirectMerchantSell(itemName)
    local before = Inventory:Count(itemName)
    if before <= 0 then return true, 0 end

    local tool = equipSellTool(itemName)
    if not tool then
        return false, 0
    end

    local remoteEvent = getCharacterRemoteEvent()
    if not remoteEvent then
        moduleLog("WARN", "[Inventory][DirectSell] Character RemoteEvent not found.")
        return false, 0
    end

    -- The pre-1.7974 Merchant used this exact action. Some current YBA systems
    -- still keep server compatibility even though the visible dialogue changed.
    -- Try twice only when the first packet makes no progress, then stop and let
    -- the new dialogue fallback handle it.
    for attempt = 1, 2 do
        local fired = pcall(function()
            remoteEvent:FireServer("EndDialogue", {
                NPC = DIRECT_SELL_ARGS.NPC,
                Dialogue = DIRECT_SELL_ARGS.Dialogue,
                Option = DIRECT_SELL_ARGS.Option,
            })
        end)

        if not fired then
            return false, 0
        end

        local deadline = tick() + 0.35
        while tick() < deadline do
            local now = Inventory:Count(itemName)
            if now < before then
                -- Give the server one tiny replication window; on the old route
                -- a single call normally removes the whole stack immediately.
                task.wait(0.04)
                local final = Inventory:Count(itemName)
                return true, before - final
            end
            task.wait(0.025)
        end
    end

    return false, 0
end

local function sellItemViaDialogueFallback(itemName, merchantPrompt, fastMode)
    local initialCount = Inventory:Count(itemName)
    local currentCount = initialCount
    local attempts = 0

    while currentCount > 0 and attempts < 4 and not Inventory:IsMoneyMaxed() do
        attempts = attempts + 1

        local tool = equipSellTool(itemName)
        if not tool then break end

        closeDialogueIfOpen()
        restoreDialogueRendering()

        if fastMode then
            suppressDialogueRendering()
        end

        local opened = pcall(function()
            fireproximityprompt(merchantPrompt)
        end)
        if not opened then
            moduleLog("WARN", "[Inventory] Could not trigger Merchant prompt for " .. itemName)
            break
        end

        task.wait(fastMode and 0.06 or 0.45)

        local beforeAttempt = Inventory:Count(itemName)
        local dialogueWorked = runMerchantSellDialogue(itemName, beforeAttempt, fastMode)
        task.wait(fastMode and 0.12 or 0.75)

        local afterAttempt = Inventory:Count(itemName)

        if fastMode and afterAttempt >= beforeAttempt then
            moduleLog("WARN", "[Inventory] Hidden dialogue made no progress for " .. itemName
                .. " — retrying with visible dialogue fallback.")
            restoreDialogueRendering()
            closeDialogueIfOpen()
            task.wait(0.15)

            local reopened = pcall(function()
                fireproximityprompt(merchantPrompt)
            end)
            if reopened then
                task.wait(0.4)
                dialogueWorked = runMerchantSellDialogue(itemName, beforeAttempt, false)
                task.wait(0.65)
                afterAttempt = Inventory:Count(itemName)
            end
        end

        if afterAttempt < beforeAttempt then
            moduleLog("INFO", "[Inventory] Sold " .. tostring(beforeAttempt - afterAttempt) .. "x " .. itemName
                .. " through dialogue fallback (remaining: " .. tostring(afterAttempt) .. ")")
        elseif dialogueWorked then
            local deadline = tick() + 1.5
            while tick() < deadline and Inventory:Count(itemName) >= beforeAttempt do
                task.wait(0.1)
            end
            afterAttempt = Inventory:Count(itemName)
        end

        currentCount = Inventory:Count(itemName)
        if currentCount >= beforeAttempt then
            moduleLog("WARN", "[Inventory] Merchant dialogue made no inventory progress for: " .. itemName)
            closeDialogueIfOpen()
            restoreDialogueRendering()
            break
        end

        closeDialogueIfOpen()
        restoreDialogueRendering()
        task.wait(fastMode and 0.06 or 0.25)
    end

    return Inventory:Count(itemName) < initialCount, initialCount - Inventory:Count(itemName)
end

-- =====================
-- SELL ALL
-- 1) Direct server sell: no Merchant prompt, no DialogueGui, near-instant.
-- 2) If rejected by the current YBA server, use adaptive dialogue fallback.
-- =====================
function Inventory:SellAll()
    if not _config:Get("FarmEnabled") then return end
    if self:IsMoneyMaxed() then
        moduleLog("INFO", "[Inventory] Money already maxed — skipping sell.")
        return
    end
    if not _config:Get("AutoSell") then
        moduleLog("INFO", "[Inventory] AutoSell disabled — skipping sell.")
        return
    end

    local sellItems = _config:GetSellItems()
    local toSell = {}

    for name, sell in pairs(sellItems) do
        if sell and self:Count(name) > 0 then
            table.insert(toSell, name)
        end
    end

    if #toSell == 0 then
        moduleLog("INFO", "[Inventory] No items to sell.")
        return
    end

    table.sort(toSell)
    moduleLog("INFO", "[Inventory] Selling " .. #toSell .. " item type(s)...")

    local soldTypes = 0
    local failedTypes = 0
    local merchantPrompt = nil

    local fastRequested = _config:Get("FastSellHidden") ~= false
    local fastSupported = hasInternalClickSupport()
    local fallbackFastMode = fastRequested and fastSupported

    for _, itemName in ipairs(toSell) do
        if self:IsMoneyMaxed() then
            moduleLog("INFO", "[Inventory] Money reached max while selling — stopping.")
            break
        end

        local initialCount = self:Count(itemName)
        local directWorked = false
        local directSold = 0

        if fastRequested then
            directWorked, directSold = tryDirectMerchantSell(itemName)
            if directWorked and directSold > 0 then
                moduleLog("INFO", "[Inventory][DirectSell] ✅ Sold " .. tostring(directSold) .. "x " .. itemName
                    .. " instantly without opening dialogue.")
            end
        end

        -- Xenon-style direct selling: keep equipping the next copy and fire the
        -- Merchant EndDialogue action until the stack is gone (or the server
        -- stops accepting the packet). This path never opens DialogueGui.
        if directWorked then
            local previous = self:Count(itemName)
            local directPasses = 0
            local maxDirectPasses = math.max(initialCount + 2, 8)

            while previous > 0 and directPasses < maxDirectPasses and not self:IsMoneyMaxed() do
                directPasses = directPasses + 1

                local ok, sold = tryDirectMerchantSell(itemName)
                local now = self:Count(itemName)

                if not ok or sold <= 0 or now >= previous then
                    break
                end

                directSold = directSold + sold
                previous = now
                task.wait()
            end

            if directSold > 0 then
                moduleLog("INFO", "[Inventory][DirectSell] Xenon route sold "
                    .. tostring(directSold) .. "x " .. itemName
                    .. " with no Merchant UI (remaining: " .. tostring(self:Count(itemName)) .. ").")
            end
        end

        local finalCount = self:Count(itemName)

        if finalCount >= initialCount then
            -- Direct route is not accepted by this server/build. Only now do we
            -- resolve/open Merchant and use the visible/new dialogue system.
            moduleLog("WARN", "[Inventory][DirectSell] Server made no progress for " .. itemName
                .. " — using 1.7974+ dialogue fallback.")

            if not merchantPrompt then
                merchantPrompt = findMerchantPrompt()
            end

            if merchantPrompt then
                local ok, sold = sellItemViaDialogueFallback(itemName, merchantPrompt, fallbackFastMode)
                finalCount = self:Count(itemName)
                if ok and sold > 0 then
                    moduleLog("INFO", "[Inventory] Dialogue fallback sold " .. tostring(sold) .. "x " .. itemName .. ".")
                end
            else
                moduleLog("WARN", "[Inventory] Merchant ProximityPrompt not found — cannot use fallback.")
            end
        end

        finalCount = self:Count(itemName)
        if finalCount < initialCount then
            soldTypes = soldTypes + 1
            moduleLog("INFO", "[Inventory] ✅ Sold " .. tostring(initialCount - finalCount) .. "/" .. tostring(initialCount)
                .. " of " .. itemName)
        else
            failedTypes = failedTypes + 1
            moduleLog("WARN", "[Inventory] ❌ Failed to sell: " .. itemName)
        end
    end

    closeDialogueIfOpen()
    restoreDialogueRendering()
    moduleLog("INFO", "[Inventory] SellAll done — Types sold: " .. soldTypes .. " | Failed: " .. failedTypes)
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

    moduleLog("INFO", "[Inventory] Buying Lucky Arrows... ($" .. money .. ")")
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
        moduleLog("INFO", "[Inventory] Lucky Arrows: " .. count .. "/" .. LUCKY_STOP)

        if count >= LUCKY_STOP then
            moduleLog("INFO", "[Inventory] Reached " .. LUCKY_STOP .. " Lucky Arrows — stopping purchase (YBA bug).")
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
