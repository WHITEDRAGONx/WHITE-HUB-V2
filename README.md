[WHITE_HUB_V2_Changelog.txt](https://github.com/user-attachments/files/27530681/WHITE_HUB_V2_Changelog.txt)
WHITE HUB V2 – Official Changelog

Overview:
WHITE HUB V2 is a complete rewrite of the original YBA item farming script.
The new version is modular, executor‑compatible, features a modern tab‑based interface,
and includes real‑time config change detection (restart farm instantly when toggling items).

-------------------------------------------------------------------------------
1. Architecture & Code Structure
-------------------------------------------------------------------------------
- Old V1: Single monolithic script (~1200 lines)
- New V2: Modular: Config, Webhook, Movement, ServerHop, Inventory, UI, Farm
- Maintainability: Easy – each module has a single responsibility
- Loading: Main.lua fetches modules from GitHub, initializes in correct order
- Configuration: Dedicated Config module with Get/Set/GetSellItem/SetSellItem, auto‑save
- Globals: Only _G.WhiteHubModules to share modules (controlled)
- Executor compatibility: Works on all (no LocalScript.Source, pure Lua)

-------------------------------------------------------------------------------
2. User Interface (New)
-------------------------------------------------------------------------------
- Design: Professional neon purple/blue accent (Color3.fromRGB(145,95,255)), smoother corners
- Window size: 380x320 (better balance)
- Layout: Sidebar with 4 tabs: Farm, Items, Webhook, Credits
- Toggle animations: Smooth TweenService animations, hover effects
- Webhook input: Dedicated Webhook tab with styled TextBox, focus animation
- Credits: Popup at startup + full Credits tab with click‑to‑copy Discord link
- Drag & drop: Smooth drag without tween
- Keyboard shortcuts: RightAlt toggle UI, RightControl hide button (fully functional)
- Canvas resizing: AutoCanvas() helper used on every page

-------------------------------------------------------------------------------
3. Core Features (Improved)
-------------------------------------------------------------------------------
- Auto Sell / Auto Buy Lucky: Toggles inside Farm tab – saved to config
- Item toggles: Inside Items tab, grouped under "SELL ITEMS"
- Webhook URL: Dedicated Webhook tab with focus animations & persistence
- Server hop: Built‑in ServerHop module (no external fetch)
- Anti AFK / Crash bypass / Noclip: Present (same as V1)
- Item detection & collection: Works (same teleport & prompt fire)
- Stop conditions: LUCKY_STOP = 9, MONEY_STOP = 1,000,000 (same)
- 2x gamepass detection: Doubles item caps (same)

-------------------------------------------------------------------------------
4. New in V2 – Real‑time Config Change Detection
-------------------------------------------------------------------------------
- When the script enters Phase 3 (idle, only collecting Lucky Arrows), it watches for changes in SellItems made via the UI.
- If you toggle any item (e.g., enable "Dio's Diary" or disable "Gold Coin") while the script is idle, the script will immediately break out of idle and restart farming without a server hop.
- This gives you full real‑time control over what the script farms, even after it has stopped.

-------------------------------------------------------------------------------
5. Performance & Compatibility
-------------------------------------------------------------------------------
- Executor compatibility: Works on all (Tested on Delta, Arceus, Synapse, KRNL, Script‑Ware)
- Memory usage: Lower (modular, lazy loading)
- Startup time: Faster (modules loaded on demand)
- Error handling: Robust pcall wrappers, logging per module

-------------------------------------------------------------------------------
6. Modules Breakdown (V2)
-------------------------------------------------------------------------------
- Config.lua: Load/save WhiteHubConfig.json, Get/Set/GetSellItem/SetSellItem
- Webhook.lua: Discord webhook messaging
- Movement.lua: Teleport, noclip, freeze, camera fix
- ServerHop.lua: Server hopping with rejoin on kick
- Inventory.lua: Count items, check max caps, sell, buy lucky arrows
- UI.lua: Full interface creation (pure Lua, no LocalScript.Source – executor‑compatible)
- Farm.lua: Main farm loop, phases 1/2/3, real‑time config change detection
- Main.lua: Entry point – loads all modules, starts UI + farm

-------------------------------------------------------------------------------
7. Fixed in V2
-------------------------------------------------------------------------------
- UI not appearing in some executors – fixed by removing LocalScript.Source
- Webhook input not saving – now saves on focus loss
- Toggle visual desync – fixed with proper TweenService callbacks
- Server hop retry – now handles failures gracefully
- Canvas size not updating – now updates correctly on all pages

-------------------------------------------------------------------------------
8. Loadstring
-------------------------------------------------------------------------------
loadstring(game:HttpGet("https://raw.githubusercontent.com/WHITEDRAGONx/WHITE-HUB-V2/main/Main.lua"))()

-------------------------------------------------------------------------------
9. Credits
-------------------------------------------------------------------------------
WHITE HUB V2 – Made by WHITE DRAGON
Smarter, cleaner, faster. Now with real‑time control.
