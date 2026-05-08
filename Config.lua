-- =====================
-- Config.lua
-- Handles all config loading, saving, and access.
-- =====================

local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "WhiteHubConfig.json"

local Config = {}

local _data = nil

local Defaults = {
    BuyLucky  = true,
    AutoSell  = true,
    WebhookURL = "",
    SellItems = {
        ["Gold Coin"]                        = true,
        ["Rokakaka"]                         = true,
        ["Pure Rokakaka"]                    = true,
        ["Mysterious Arrow"]                 = true,
        ["Diamond"]                          = true,
        ["Ancient Scroll"]                   = true,
        ["Caesar's Headband"]                = true,
        ["Stone Mask"]                       = true,
        ["Rib Cage of The Saint's Corpse"]   = true,
        ["Quinton's Glove"]                  = true,
        ["Zeppeli's Hat"]                    = true,
        ["Lucky Arrow"]                      = false,
        ["Lucky Stone Mask"]                 = false,
        ["Clackers"]                         = true,
        ["Steel Ball"]                       = true,
        ["Dio's Diary"]                      = true,
    }
}

-- Fills in any missing keys from defaults into an existing config table
local function ApplyDefaults(data)
    if data.BuyLucky   == nil then data.BuyLucky   = Defaults.BuyLucky   end
    if data.AutoSell   == nil then data.AutoSell   = Defaults.AutoSell   end
    if data.WebhookURL == nil then data.WebhookURL = Defaults.WebhookURL end
    if data.SellItems  == nil then data.SellItems  = {}                  end
    for k, v in pairs(Defaults.SellItems) do
        if data.SellItems[k] == nil then
            data.SellItems[k] = v
        end
    end
    return data
end

function Config:Load()
    if _data then return end -- already loaded

    local ok, result = pcall(function()
        if isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
    end)

    if ok and result and type(result) == "table" then
        _data = ApplyDefaults(result)
        print("[Config] Loaded from file.")
    else
        _data = ApplyDefaults({
            BuyLucky   = Defaults.BuyLucky,
            AutoSell   = Defaults.AutoSell,
            WebhookURL = Defaults.WebhookURL,
            SellItems  = {},
        })
        print("[Config] No existing config found — using defaults.")
    end
end

function Config:Save()
    if not _data then return end
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(_data))
    end)
end

-- Get a top-level config value
-- Examples: Config:Get("AutoSell")  Config:Get("SellItems")
function Config:Get(key)
    if not _data then self:Load() end
    return _data[key]
end

-- Set a top-level config value and auto-save
-- Example: Config:Set("AutoSell", true)
function Config:Set(key, value)
    if not _data then self:Load() end
    _data[key] = value
    self:Save()
end

-- Get a single SellItems entry
-- Example: Config:GetSellItem("Rokakaka")
function Config:GetSellItem(name)
    if not _data then self:Load() end
    return _data.SellItems[name]
end

-- Set a single SellItems entry and auto-save
-- Example: Config:SetSellItem("Rokakaka", false)
function Config:SetSellItem(name, value)
    if not _data then self:Load() end
    _data.SellItems[name] = value
    self:Save()
end

-- Returns the full SellItems table (by reference — read-only intent)
function Config:GetSellItems()
    if not _data then self:Load() end
    return _data.SellItems
end

return Config
