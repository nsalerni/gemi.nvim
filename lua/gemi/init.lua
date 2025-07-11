-- Hello World
-- Gemi.nvim
-- Copyright (c) 2025 Nil Pointer
-- All rights reserved.
--
-- lua/gemi/init.lua
-- Main Gemi module

local M = {}

-- Plugin state
M._state = {
    is_running = false,
    current_job = nil,
    ui_visible = false,
    initialized = false,
}

-- Lazy load modules
local function get_config()
    return require('gemi.config')
end

local function get_overlay()
    return require('gemi.overlay')
end

local function get_installer()
    return require('gemi.installer')
end

local function get_executor()
    return require('gemi.executor')
end

local function get_tracker()
    return require('gemi.tracker')
end

-- Setup function
function M.setup(opts)
    if M._state.initialized then
        return
    end

    local config = get_config()
    config.setup(opts or {})

    local overlay = get_overlay()
    overlay.setup()

    local tracker = get_tracker()
    tracker.setup()

    M._state.initialized = true
end

-- Toggle the overlay
function M.toggle()
    -- Skip full setup for just showing overlay - only initialize config if needed
    if not M._state.initialized then
        local config = get_config()
        config.setup({}) -- Use minimal config
        M._state.initialized = true
    end

    local overlay = get_overlay()
    if M._state.ui_visible then
        overlay.hide()
        M._state.ui_visible = false
    else
        overlay.show()
        M._state.ui_visible = true
    end
end

-- Install gemini-cli and dependencies
function M.install_cli()
    if not M._state.initialized then
        M.setup()
    end

    local installer = get_installer()
    installer.install_dependencies()
end

-- Authenticate with Google
function M.authenticate()
    if not M._state.initialized then
        M.setup()
    end

    local executor = get_executor()
    executor.authenticate()
end

-- Show changed files
function M.show_changed_files()
    if not M._state.initialized then
        M.setup()
    end

    local tracker = get_tracker()
    tracker.show_changed_files()
end

-- Show diff view
function M.show_diff()
    if not M._state.initialized then
        M.setup()
    end

    local tracker = get_tracker()
    tracker.show_diff()
end

-- Execute gemini command
function M.execute_prompt(prompt)
    if not M._state.initialized then
        M.setup()
    end

    if M._state.is_running then
        vim.notify("Gemi is already running", vim.log.levels.WARN)
        return
    end

    local executor = get_executor()
    local tracker = get_tracker()

    -- Create a snapshot before execution to capture the baseline
    tracker.create_snapshot('pre_execution')

    M._state.is_running = true
    M._state.current_job = executor.run_gemini(prompt, function(success, output)
        M._state.is_running = false
        M._state.current_job = nil

        if success then
            -- Scan for changes after execution
            tracker.scan_for_changes()
            -- No success notification - let it happen silently
        else
            vim.notify("Gemi failed: " .. (output or "Unknown error"), vim.log.levels.ERROR)
        end
    end)
end

-- Stop current execution
function M.stop()
    if M._state.current_job then
        M._state.current_job:shutdown()
        M._state.current_job = nil
        M._state.is_running = false
        vim.notify("Gemi execution stopped", vim.log.levels.INFO)
    end
end

-- Force reload all changed files
function M.force_reload_changed_files()
    if not M._state.initialized then
        M.setup()
    end

    local tracker = get_tracker()
    tracker.force_reload_all_changed_files()
end

-- Debug change detection
function M.debug_changes()
    if not M._state.initialized then
        M.setup()
    end

    local tracker = get_tracker()
    return tracker.debug_change_detection()
end

return M
