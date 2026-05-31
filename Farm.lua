function Farm:Start()
    ApplyHooks()
    ApplyCrashBypass()
    ApplyAntiAfk()
    InitItemDetection()
    SetupWebhookListener()
    Startup()

    print("[Farm] Farm loop started.")

    -- Check if Auto Prestige is enabled
    if _config:Get("AutoPrestige") then
        print("[Farm] Auto Prestige enabled – delegating to Prestige module.")
        if _webhook then
            _webhook:Send("🔄 **Auto Prestige started**\nPlayer: `" .. Player.Name .. "`")
        end
        
        -- Run prestige in a protected thread
        task.spawn(function()
            local ok, err = pcall(function() 
                if Modules.Prestige and Modules.Prestige.Start then
                    Modules.Prestige:Start()
                else
                    warn("[Farm] Prestige module not available.")
                end
            end)
            if not ok then
                warn("[Farm] Prestige crashed: " .. tostring(err))
                if _webhook then _webhook:SendError("Prestige crashed: " .. tostring(err)) end
            end
        end)
        
        -- Keep the main loop alive but idle (checking for AutoPrestige turning off)
        while true do
            task.wait(5)
            if not _config:Get("AutoPrestige") then
                print("[Farm] Auto Prestige turned off, switching back to normal farm.")
                break
            end
        end
    end

    -- Normal farm loop (only runs if AutoPrestige is false)
    while true do
        -- ===== PHASE 1 =====
        print("[Farm] >>> Phase 1 started — farming normally.")
        while not _inventory:ShouldStopPhase1() do
            -- ... rest of your existing farm code exactly as before ...
            -- (no changes needed inside the phases)
        end
        -- ... rest of farm phases ...
    end
end
