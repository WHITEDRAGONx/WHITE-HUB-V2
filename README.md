📘 README.md (para o GitHub)
markdown
# WHITE HUB V2

**Modular, executor‑compatible, feature‑rich script for YBA (Your Bizarre Adventure).**

WHITE HUB V2 is a complete rewrite of the original WHITE HUB. It features a modern UI, real‑time config change detection, an intelligent 3‑phase farming system, and now an optional Auto Prestige module.

---

## 🚀 Features

- **Smart 3‑phase farming**  
  Phase 1 → normal item farm until 9 Lucky Arrows + $1,000,000  
  Phase 2 → only collects items you have marked as “keep” (disabled sell)  
  Phase 3 → idle, collecting only Lucky Arrows / Lucky Stone Mask

- **Real‑time config change detection**  
  When idle (Phase 3), toggling any item in the UI restarts the farm instantly – no server hop needed.

- **Auto Prestige (optional)**  
  Fully automated story progression, stand farming, leveling to 50, and prestiging up to prestige 3.  
  Works alongside the normal farm – just enable the toggle in the UI.

- **Modern UI**  
  Tab‑based interface (Farm, Items, Webhook, Credits), touch‑friendly, with smooth animations.

- **Discord webhook integration**  
  Get notified when phases complete, when the farm finishes, or when you manually disable/enable the farm.

- **Executor compatibility**  
  Works on Delta, Synapse, Script‑Ware, Wave, Volt, and many more (full Lua 5.1 support).

---

## 📦 Installation

1. **Copy the loadstring** below and paste it into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/WHITEDRAGONx/WHITE-HUB-V2/main/Main.lua"))()
Execute it in YBA (Your Bizarre Adventure).

Wait a few seconds – the UI will appear on your screen.

🎮 How to use
UI controls
Farm tab

Enable Farm – master toggle to pause/resume all farming actions.

Auto Sell – automatically sells items you have marked in the Items tab.

Auto Buy Lucky – automatically buys Lucky Arrows when enough money is available.

Auto Prestige – enables the Auto Prestige mode (replaces normal farm with story/stand/leveling/prestige).

Items tab
Check which items you want to sell automatically.
Unchecked items are kept (they will not be sold).

Webhook tab
Paste your Discord webhook URL to receive notifications.
Use the Reset Webhook Flags button to re‑send Phase 1 complete or All farming complete notifications.

Credits tab
Contains credits and a click‑to‑copy Discord invite link.

Keyboard shortcuts
RightAlt – toggle the UI window.

RightControl – show/hide the floating toggle button.

🧩 Modules overview
Module	Responsibility
Config.lua	Load/save WhiteHubConfig.json, access configuration values.
Webhook.lua	Send Discord notifications.
Movement.lua	Teleport, noclip, freeze, camera fix.
ServerHop.lua	Server hopping and rejoin on kick.
Inventory.lua	Count items, check caps, sell, buy Lucky Arrows.
UI.lua	Create the interface toggles, tabs, and popups.
Farm.lua	Main farm loop (phases 1/2/3) with real‑time config detection.
AutoPrestige.lua	Standalone script for story/stand/leveling/prestige.
Main.lua	Entry point – loads all modules, creates UI, starts farm and auto‑prestige loader.
⚙️ Configuration
All settings are stored in WhiteHubConfig.json (created automatically in your executor’s workspace).

You can edit it manually, but the UI toggles will update it for you.

❓ Troubleshooting
UI does not appear
→ Make sure your executor supports LocalScript in StarterPlayerScripts.
→ Re‑execute the loadstring after the character loads.

Auto Prestige does not start
→ Ensure you have enabled the toggle in the Farm tab.
→ Check the console for errors (some executors may block certain functions).

Webhook not sending
→ Verify your webhook URL is correct (must start with https://discord.com/api/webhooks/...).
→ Check if your executor allows HTTP requests.

Farm or Prestige crashes
→ Try hopping to another server.
→ Disable other scripts that may conflict.

📜 License & Credits
WHITE HUB V2 – Made by WHITE DRAGON

Auto Prestige logic is based on the original standalone script, preserved and integrated with minimal changes.

🔗 Links
GitHub Repository: https://github.com/WHITEDRAGONx/WHITE-HUB-V2

Discord: https://discord.gg/Qwd23ZRNxJ

Happy farming! ⚡
