-- =====================
-- Webhook.lua
-- Handles all Discord webhook communication.
-- =====================

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local Player      = Players.LocalPlayer

local Webhook = {}
local _config = nil

function Webhook:Init(Modules)
    _config = Modules.Config
end

local function Send(message)
    local url = _config:Get("WebhookURL")
    if not url or url == "" then return end

    pcall(function()
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
        if req then
            req({
                Url     = url,
                Method  = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body    = body,
            })
        end
    end)
end

-- Generic send
function Webhook:Send(message)
    Send(message)
end

-- Phase 1 complete
function Webhook:SendPhase1Complete(luckyCount, luckyStop, money)
    Send(
        "🎯 **Phase 1 complete — switching to keep-item farm!**\n"
        .. "Player: `" .. Player.Name .. "`\n"
        .. "Lucky Arrows: `" .. luckyCount .. "/" .. luckyStop .. "`\n"
        .. "Money: `$" .. tostring(money) .. "`"
    )
end

-- All farming complete
function Webhook:SendAllComplete(luckyCount, luckyStop, money)
    Send(
        "✅ **All farming complete!**\n"
        .. "Player: `" .. Player.Name .. "`\n"
        .. "Lucky Arrows: `" .. luckyCount .. "/" .. luckyStop .. "`\n"
        .. "Money: `$" .. tostring(money) .. "`\n"
        .. "All keep-items are maxed. Script is now idling."
    )
end

-- Lucky arrow milestone
function Webhook:SendLuckyFound(luckyCount, luckyStop, money)
    Send(
        "✅ **Phase 1 conditions met!**\n"
        .. "Player: `" .. Player.Name .. "`\n"
        .. "Lucky Arrows: `" .. luckyCount .. "/" .. luckyStop .. "`\n"
        .. "Money: `$" .. tostring(money) .. "`"
    )
end

-- Generic error notification
function Webhook:SendError(context)
    Send("⚠️ **Error / Warning**\nPlayer: `" .. Player.Name .. "`\nContext: `" .. tostring(context) .. "`")
end

return Webhook
