-- =====================
-- Webhook.lua
-- Handles all Discord webhook communication.
-- =====================

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local Player      = Players.LocalPlayer

local Webhook = {}
local _config = nil
local _runtimeLog = nil

function Webhook:Init(Modules)
    _config = Modules.Config
    _runtimeLog = Modules.RuntimeLog
end

local function log(level, message)
    if _runtimeLog and type(_runtimeLog.Write) == "function" then
        pcall(_runtimeLog.Write, _runtimeLog, level, "Webhook", message)
    end
end

local function Send(message)
    local url = _config:Get("WebhookURL")
    if not url or url == "" then
        log("INFO", "Webhook URL is empty; notification skipped.")
        return
    end
    local ok, err = pcall(function()
        local body = HttpService:JSONEncode({
            content = nil,
            embeds = {{
                title       = "WHITE HUB — Notification",
                description = message,
                color       = 7864319,
                footer      = { text = "WHITE HUB by WHITE DRAGON" },
                timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }}
        })
        local req = http_request or request or (syn and syn.request)
        if not req then
            error("No supported HTTP request function is available in this executor.")
        end
        req({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
    end)
    if ok then
        log("INFO", "Discord webhook request sent.")
    else
        log("ERROR", "Discord webhook failed: " .. tostring(err))
    end
end

function Webhook:Send(message)
    Send(message)
end

function Webhook:SendPhase1Complete(luckyCount, luckyStop, money)
    Send(
        "🎯 **Phase 1 complete — switching to keep-item farm!**\n"
        .. "Player: `" .. Player.Name .. "`\n"
        .. "Lucky Arrows: `" .. luckyCount .. "/" .. luckyStop .. "`\n"
        .. "Money: `$" .. tostring(money) .. "`"
    )
end

function Webhook:SendAllComplete(luckyCount, luckyStop, money)
    Send(
        "✅ **All farming complete!**\n"
        .. "Player: `" .. Player.Name .. "`\n"
        .. "Lucky Arrows: `" .. luckyCount .. "/" .. luckyStop .. "`\n"
        .. "Money: `$" .. tostring(money) .. "`\n"
        .. "All keep-items are maxed. Script is now idling."
    )
end

function Webhook:SendFarmDisabled()
    Send(
        "🛑 **Farm manually disabled**\n"
        .. "Player: `" .. Player.Name .. "`\n"
        .. "Farming has been paused by the user.\n"
        .. "Use the UI toggle to resume."
    )
end

function Webhook:SendFarmResumed()
    Send(
        "🟢 **Farm manually re-enabled**\n"
        .. "Player: `" .. Player.Name .. "`\n"
        .. "Farming has been resumed by the user."
    )
end

function Webhook:SendLuckyFound(luckyCount, luckyStop, money)
    Send(
        "✅ **Phase 1 conditions met!**\n"
        .. "Player: `" .. Player.Name .. "`\n"
        .. "Lucky Arrows: `" .. luckyCount .. "/" .. luckyStop .. "`\n"
        .. "Money: `$" .. tostring(money) .. "`"
    )
end

function Webhook:SendError(context)
    Send(
        "⚠️ **Error / Warning**\n"
        .. "Player: `" .. Player.Name .. "`\n"
        .. "Context: `" .. tostring(context) .. "`"
    )
end

-- Called when Auto Prestige reaches Prestige 3, Level 50
function Webhook:SendPrestigeComplete()
    Send(
        "🏆 **Prestige maxed out!**\n"
        .. "Player: `" .. Player.Name .. "`\n"
        .. "Reached **Prestige 3, Level 50**.\n"
        .. "Auto Prestige has been disabled automatically.\n"
        .. "The script will now return to normal item farming."
    )
end

return Webhook
