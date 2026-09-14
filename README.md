⚡ WHITE HUB V3

Modular automation hub for YBA (Your Bizarre Adventure), rebuilt around diagnostics, modular loading, persistent configuration, and a new high-speed Merchant workflow.

Current UI build: FUTURE-GOLD-2026.09.14-R3

Primary live testing has been done on Delta. Executor capabilities differ, so some advanced paths automatically fall back when required APIs are unavailable.

✨ What is new in V3

⚡ Merchant Zero-Delay Auto Sell

The current YBA Merchant no longer behaves like the old EndDialogue flow. WHITE HUB V3 now uses a mapped internal dialogue route when the executor supports it.

Final live test results:

Pure Rokakaka sale: 0.727s.

Mysterious Arrow sale: 0.702s.

The Inventory module uses:

FINAL Zero-Delay route.

Hidden internal fallback.

Standard dialogue fallback.

Temporary patches are restored after each sale.

🎨 Future Gold UI

black/deep-gray surfaces;

white typography;

bright-gold accents;

compact ⚡ WHITE HUB launcher;

lightweight animated gold borders/glow;

Runtime Console integrated into the theme;

no separate Fast Sell toggle.

🧩 Modular architecture

Each major system is isolated into its own module and loaded by Main.lua.

🧪 Diagnostics

fail-fast boot;

independent boot-error screen;

Runtime Console;

copyable logs;

Runtime ID for each execution;

cache-busted module downloads.

📦 Files

File

Responsibility

Main.lua

Entry point, module download/validation, init, diagnostics

Config.lua

Persistent configuration

Webhook.lua

Discord webhook notifications

Movement.lua

Movement, noclip, freeze, and camera helpers

ServerHop.lua

Server hopping/rejoin logic

Inventory.lua

Item counts, Auto Sell, Merchant zero-delay logic

CombatFarm.lua

Quest/NPC combat controller

Farm.lua

Main item farming lifecycle

UI.lua

Future Gold interface

AutoPrestige.lua

Prestige/story/leveling worker

MerchantAnalyzer was a development tool used to reverse-engineer the new Merchant dialogue. It is not required for normal V3 usage.

🚀 Installation

Current repository name:

WHITEDRAGONx/WHITE-HUB-V3

Loader:

loadstring(game:HttpGet("https://raw.githubusercontent.com/WHITEDRAGONx/WHITE-HUB-V3/main/Main.lua"))()

Execute the loader after YBA has loaded.

🎮 Main systems

Farm

main farming lifecycle;

item collection;

pause/resume behavior;

integration with Auto Sell and config changes.

Items / Auto Sell

Choose which items should be sold automatically.

The fast Merchant path is now internal to Inventory.lua; there is no separate Fast Sell toggle in the UI.

Combat

Quest Farm and NPC Farm share the CombatFarm.lua controller.

Current work includes:

selecting another alive NPC when multiple NPCs share the same name;

immediate cancellation when the toggle is disabled;

player hover/freeze during combat;

Stand positioning;

camera stabilization;

migration away from legacy quest dialogue logic.

Auto Prestige

Auto Prestige remains a standalone worker, but Main.lua now downloads and compiles it during boot so failures are detected early.

Runtime Console

Use the Console tab to inspect INFO, WARN, and ERROR events and copy the complete runtime log when reporting bugs.

⚠️ Known limitations

WHITE HUB V3 is released and usable, but these areas are still under active validation:

Quest Farm dialogue acceptance;

NPC Farm lifecycle in some NPC/spawn combinations;

Stand/camera jitter in some combat situations;

strong knockback/void edge cases;

long-run Auto Prestige integration with the new quest system.

When reporting a bug, include the Runtime Console log whenever possible.

🛠️ Configuration

Settings are managed by Config.lua and, when the executor supports filesystem APIs, persisted in WhiteHubConfig.json.

The UI should be used for normal changes instead of manually editing the config file.

🔍 Troubleshooting

UI still looks old

Check the Runtime Console / Credits for the UI build:

FUTURE-GOLD-2026.09.14-R3

Main.lua uses cache-busted module URLs to reduce stale raw/module caching.

Auto Sell says the item must be held

The current Inventory build attempts to equip and verify the item before opening the Merchant. If it still happens, copy the Runtime Console log.

A module fails during boot

The fail-fast diagnostic should identify the module and stage. Copy that diagnostic instead of repeatedly re-executing the script.

Quest/NPC Farm behaves incorrectly

Copy the [CombatFarm] section from Runtime Console. Those systems are still the main active maintenance area.

🔗 Repository and loader

The official repository is now:

WHITEDRAGONx/WHITE-HUB-V3

Main.lua already points to the new repository:

local BASE_URL = "https://raw.githubusercontent.com/WHITEDRAGONx/WHITE-HUB-V3/main/"

The public GitHub loader is:

loadstring(game:HttpGet("https://raw.githubusercontent.com/WHITEDRAGONx/WHITE-HUB-V3/main/Main.lua"))()

If you use Pastebin as a loader, update the raw GitHub URL inside the Pastebin to WHITE-HUB-V3. If the Pastebin contains the full script and does not fetch Main.lua from GitHub, the repository rename does not affect it.

After changing a loader, test it from a fresh YBA session to make sure no old URL is still being used.

📜 Changelog

See CHANGELOG.md for the full development history and current priorities.

🔗 Community

Discord: https://discord.gg/Qwd23ZRNxJ

Made by WHITE DRAGON.

⚡ WHITE HUB V3 — built through testing, logs, and reverse engineering instead of blind delays.
