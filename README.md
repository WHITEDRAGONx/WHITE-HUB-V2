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
