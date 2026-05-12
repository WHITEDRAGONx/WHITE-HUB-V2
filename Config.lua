-- =====================
-- Config.lua
-- Handles all config loading, saving, and access.
-- =====================

local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "WhiteHubConfig.json"

local Config = {}
local _data  = nil

local Defaults = {
    BuyLucky   = true,
    AutoSell   = true,
    WebhookURL = "",
    Phase1Notified = false,   -- Prevents repeated webhook on server hop
    SellItems  = {
        ["Gold Coin"]                       = true,
        ["Rokakaka"]                        = true,
        ["Pure Rokakaka"]                   = true,
        ["Mysterious Arrow"]                = true,
        ["Diamond"]                         = true,
        ["Ancient Scroll"]                  = true,
        ["Caesar's Headband"]               = true,
        ["Stone Mask"]                      = true,
        ["Rib Cage of The Saint's Corpse"]  = true,
        ["Quinton's Glove"]                 = true,
        ["Zeppeli's Hat"]                   = true,
        ["Lucky Arrow"]                     = false,
        ["Lucky Stone Mask"]                = false,
        ["Clackers"]                        = true,
        ["Steel Ball"]                      = true,
        ["Dio's Diary"]                     = true,
    }
}

local function ApplyDefaults(data)
    if data.BuyLucky   == nil then data.BuyLucky   = Defaults.BuyLucky   end
    if data.AutoSell   == nil then data.AutoSell   = Defaults.AutoSell   end
    if data.WebhookURL == nil then data.WebhookURL = Defaults.WebhookURL end
    if data.Phase1Notified == nil then data.Phase1Notified = Defaults.Phase1Notified end
    if type(data.SellItems) ~= "table" then data.SellItems = {} end
    for k, v in pairs(Defaults.SellItems) do
        if data.SellItems[k] == nil then data.SellItems[k] = v end
    end
    return data
end

function Config:Load()
    if _data then return end
    local ok, result = pcall(function()
        if isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
    end)
    if ok and result and type(result) == "table" then
        _data = ApplyDefaults(result)
        print("[Config] Loaded from file.")
    else
        _data = ApplyDefaults({})
        print("[Config] No existing config found — using defaults.")
    end
end

function Config:Save()
    if not _data then return end
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(_data))
    end)
end

function Config:Get(key)
    if not _data then self:Load() end
    return _data[key]
end

function Config:Set(key, value)
    if not _data then self:Load() end
    _data[key] = value
    self:Save()
end

function Config:GetSellItem(name)
    if not _data then self:Load() end
    return _data.SellItems[name]
end

function Config:SetSellItem(name, value)
    if not _data then self:Load() end
    _data.SellItems[name] = value
    self:Save()
end

function Config:GetSellItems()
    if not _data then self:Load() end
    return _data.SellItems
end

return Config
