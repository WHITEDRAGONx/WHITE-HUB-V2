# WHITE HUB V3 — Test Build

This folder contains the revised modular version. `Main.lua` remains the entry point for the modular build. For testing without GitHub, use the separate `WhiteHub_Monolithic.lua` file.

## Boot Diagnostics (New)

* `Main.lua` now uses a **fail-fast** boot process: if any critical module fails, initialization stops immediately.
* The bootstrap distinguishes between `DOWNLOAD`, `COMPILE`, `MODULE RUNTIME`, `VALIDATION`, `CONFIG LOAD`, `INIT`, `CREATE`, and `START / RUNTIME` failures.
* The error window is created directly by `Main.lua` and **does not depend on `UI.lua`**, so it still works even when the UI module itself is broken.
* The window displays the module that failed, the stage where it failed, and a summarized reason.
* The **Copy Detailed Log** button copies the runtime ID, module, stage, reason, traceback, PlaceId/JobId, executor information, and the complete boot log.
* If the executor does not provide a clipboard API, the full error is still printed to the console.
* `AutoPrestige.lua` is now downloaded and compiled during boot; a missing file or syntax error will prevent the Hub from silently starting in a partially broken state.

## Main Fixes

* CombatFarm now uses a unique execution token to prevent old Quest Farm and NPC Farm workers from continuing to run in parallel.
* Quest Farm and NPC Farm are mutually exclusive both in the UI and in the config.
* Movement now restores the original `CanCollide` state instead of setting every part to `true` when noclip is disabled.
* Noclip was optimized to use periodic passes instead of scanning all descendants every frame.
* `FreezeAtPosition()` was added for compatibility with older modules.
* Stand `AlignPosition` / `AlignOrientation` constraints are restored after CombatFarm finishes.
* Farm now has a proper lifecycle (`Start`, `Stop`, `Destroy`) and prevents duplicate workers from being started.
* Farm no longer sends phase-completion notifications when it was only paused or when Auto Prestige was enabled in the middle of a phase.
* Item collection is only marked as successful after confirmation through the inventory or removal of the item model.
* The Inventory dialogue click fallback was fixed: if `firesignal` is unavailable, it now properly falls back to `VirtualInputManager`.
* UI now destroys the previous execution, manages global connections, and prevents duplicated listeners when the script is re-executed.
* `UI:SetToggleValue()` now changes only the visual state and no longer writes incorrect config keys such as `"Auto Prestige"` to the JSON file.
* Auto Skills input capture now disconnects correctly when cancelled or after receiving a key.
* AutoPrestige now refreshes `Character`, `RemoteEvent`, `RemoteFunction`, and HRP references after respawning.
* The inverted `FocusCam` condition in the prestige checker was fixed.
* AutoPrestige hooks now only modify behavior while Auto Prestige is enabled.
* ServerHop now includes cleanup for the kick listener and uses a simpler server cache.
* Re-executing the Main script or monolithic build attempts to shut down modules from the previous execution before starting a new one.

## Active Files

`Config.lua`, `Webhook.lua`, `Movement.lua`, `ServerHop.lua`, `Inventory.lua`, `CombatFarm.lua`, `Farm.lua`, `UI.lua`, `AutoPrestige.lua`, and `Main.lua`.

`QuestFarm.lua` and `NPCFarm.lua` were moved to `Legacy_DO_NOT_LOAD`, because the current project already uses `CombatFarm.lua` for both features.

## Recommended Testing

1. First, execute `WhiteHub_Monolithic.lua` in the executor.
2. Open and close the UI a few times, then re-execute the file to confirm that duplicate interfaces do not appear.
3. Test Enable Farm ON/OFF during Phase 1 and confirm that pausing alone does not trigger a completion webhook.
4. Enable Quest Farm and then NPC Farm; only the most recently enabled mode should continue running.
5. Test death/respawn during CombatFarm and Auto Prestige.
6. If possible, test item selling in an executor without `firesignal` to validate the click fallback.
7. If anything breaks, copy the full console error and report which toggle/mode was active.

## Note

The syntax of all active files and the monolithic build was validated locally. This does not replace testing inside YBA, because game structures, remotes, and UI elements may change.
