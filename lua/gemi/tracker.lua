-- lua/gemi/tracker.lua
-- File change tracking and navigation

local M = {}
local config = require('gemi.config')

-- State for tracking changes
M._state = {
    changed_files = {},
    snapshots = {},
    current_diff_buf = nil,
    current_diff_win = nil,
}

-- Initialize file tracking
function M.setup()
    -- Create initial snapshot if auto_scan is enabled
    if config.get('tracking.auto_scan') then
        M.create_snapshot('initial')
    end
    
    -- Set up auto-reload for newly opened files
    M.setup_auto_reload_autocmds()
end

-- Create a snapshot of current file states
function M.create_snapshot(name)
    name = name or os.date('%Y%m%d_%H%M%S')
    
    local snapshot = {
        name = name,
        timestamp = os.time(),
        files = {},
    }
    
    -- Get all files in the project (excluding patterns)
    local files = M._get_project_files()
    
    for _, file in ipairs(files) do
        local content = M._read_file_safe(file)
        if content then
            snapshot.files[file] = {
                content = content,
                mtime = vim.fn.getftime(file),
                size = vim.fn.getfsize(file),
            }
        end
    end
    
    M._state.snapshots[name] = snapshot
    return snapshot
end

-- Get list of project files, excluding patterns
function M._get_project_files()
    local exclude_patterns = config.get('tracking.exclude_patterns') or {}
    local files = {}
    local logger = require('gemi.logger')
    
    -- Use git to get tracked files if in a git repo
    local handle = io.popen('git ls-files 2>/dev/null')
    if handle then
        for line in handle:lines() do
            local should_exclude = false
            for _, pattern in ipairs(exclude_patterns) do
                if line:match(pattern) then
                    should_exclude = true
                    break
                end
            end
            
            if not should_exclude and vim.fn.filereadable(line) == 1 then
                table.insert(files, line)
            end
        end
        handle:close()
    end
    
    -- If no git files found, fall back to recursive find
    if #files == 0 then
        logger.debug('No git files found, using find fallback')
        local find_handle = io.popen('find . -type f -not -path "./.git/*" 2>/dev/null | head -1000')
        if find_handle then
            for line in find_handle:lines() do
                local file = line:gsub('^%./', '')
                local should_exclude = false
                
                for _, pattern in ipairs(exclude_patterns) do
                    if file:match(pattern) then
                        should_exclude = true
                        break
                    end
                end
                
                if not should_exclude and vim.fn.filereadable(file) == 1 then
                    table.insert(files, file)
                end
            end
            find_handle:close()
        end
    end
    
    -- Also include any currently open buffers to ensure we catch changes
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
            local buf_name = vim.api.nvim_buf_get_name(buf)
            if buf_name ~= '' then
                local relative_path = vim.fn.fnamemodify(buf_name, ':.')
                local should_exclude = false
                
                for _, pattern in ipairs(exclude_patterns) do
                    if relative_path:match(pattern) then
                        should_exclude = true
                        break
                    end
                end
                
                if not should_exclude and vim.fn.filereadable(relative_path) == 1 then
                    -- Check if not already in the list
                    local found = false
                    for _, existing in ipairs(files) do
                        if existing == relative_path then
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(files, relative_path)
                    end
                end
            end
        end
    end
    
    logger.debug('Found project files', { count = #files, sample = vim.list_slice(files, 1, 5) })
    return files
end

-- Safely read file content
function M._read_file_safe(file)
    local f = io.open(file, 'r')
    if f then
        local content = f:read('*a')
        f:close()
        return content
    end
    return nil
end

-- Scan for changes since last snapshot
function M.scan_for_changes()
    local logger = require('gemi.logger')
    logger.debug('Starting scan for changes')
    
    local latest_snapshot = M._get_latest_snapshot()
    if not latest_snapshot then
        logger.debug('No baseline snapshot found. Creating one now...')
        vim.notify('No baseline snapshot found. Creating one now...', vim.log.levels.INFO)
        M.create_snapshot('baseline')
        return {}
    end
    
    logger.debug('Found snapshot', { snapshot_name = latest_snapshot.name, files_count = vim.tbl_count(latest_snapshot.files) })
    
    local changed_files = {}
    local current_files = M._get_project_files()
    
    logger.debug('Current project files', { count = #current_files })
    
    -- Check for modified and new files
    for _, file in ipairs(current_files) do
        local current_content = M._read_file_safe(file)
        local snapshot_data = latest_snapshot.files[file]
        
        if current_content then
            if not snapshot_data then
                -- New file
                logger.debug('New file detected', { file = file })
                table.insert(changed_files, {
                    file = file,
                    type = 'added',
                    old_content = '',
                    new_content = current_content,
                })
            elseif current_content ~= snapshot_data.content then
                -- Modified file
                logger.debug('Modified file detected', { file = file })
                table.insert(changed_files, {
                    file = file,
                    type = 'modified',
                    old_content = snapshot_data.content,
                    new_content = current_content,
                })
            end
        end
    end
    
    -- Check for deleted files
    for file, _ in pairs(latest_snapshot.files) do
        if vim.fn.filereadable(file) == 0 then
            logger.debug('Deleted file detected', { file = file })
            table.insert(changed_files, {
                file = file,
                type = 'deleted',
                old_content = latest_snapshot.files[file].content,
                new_content = '',
            })
        end
    end
    
    logger.debug('Scan complete', { changed_files_count = #changed_files })
    M._state.changed_files = changed_files
    
    -- Create new snapshot after detecting changes
    if #changed_files > 0 then
        logger.debug('Creating post-changes snapshot')
        M.create_snapshot('post_changes')
        
        -- Auto-reload changed files in Neovim
        logger.debug('Auto-reloading changed files')
        M.auto_reload_changed_files(changed_files)
    else
        logger.debug('No changes detected')
    end
    
    return changed_files
end

-- Get the latest snapshot
function M._get_latest_snapshot()
    local latest = nil
    local latest_time = 0
    
    for _, snapshot in pairs(M._state.snapshots) do
        if snapshot.timestamp > latest_time then
            latest = snapshot
            latest_time = snapshot.timestamp
        end
    end
    
    return latest
end

-- Show changed files in a quickfix list
function M.show_changed_files()
    local changed = M._state.changed_files
    
    if #changed == 0 then
        vim.notify('No file changes detected', vim.log.levels.INFO)
        return
    end
    
    local qf_list = {}
    for _, change in ipairs(changed) do
        table.insert(qf_list, {
            filename = change.file,
            text = string.format('[%s] %s', change.type:upper(), change.file),
            type = change.type == 'added' and 'I' or change.type == 'deleted' and 'E' or 'W',
        })
    end
    
    vim.fn.setqflist(qf_list, 'r')
    vim.cmd('copen')
    vim.notify(string.format('Found %d changed files', #changed), vim.log.levels.INFO)
end

-- Show diff for a specific file or all changes
function M.show_diff(file_path)
    local changed = M._state.changed_files
    
    if #changed == 0 then
        vim.notify('No file changes to show', vim.log.levels.INFO)
        return
    end
    
    if file_path then
        -- Show diff for specific file
        local change = nil
        for _, c in ipairs(changed) do
            if c.file == file_path then
                change = c
                break
            end
        end
        
        if not change then
            vim.notify('No changes found for file: ' .. file_path, vim.log.levels.WARN)
            return
        end
        
        M._show_file_diff(change)
    else
        -- Show diff selection menu
        M._show_diff_menu()
    end
end

-- Show diff selection menu
function M._show_diff_menu()
    local changed = M._state.changed_files
    
    if #changed == 1 then
        M._show_file_diff(changed[1])
        return
    end
    
    local items = {}
    for i, change in ipairs(changed) do
        table.insert(items, string.format('%d. [%s] %s', i, change.type:upper(), change.file))
    end
    
    vim.ui.select(items, {
        prompt = 'Select file to view diff:',
    }, function(choice, idx)
        if idx then
            M._show_file_diff(changed[idx])
        end
    end)
end

-- Show diff for a specific file change
function M._show_file_diff(change)
    -- Create temporary buffers for old and new content
    local old_buf = vim.api.nvim_create_buf(false, true)
    local new_buf = vim.api.nvim_create_buf(false, true)
    
    -- Set content
    local old_lines = vim.split(change.old_content, '\n', { plain = true })
    local new_lines = vim.split(change.new_content, '\n', { plain = true })
    
    vim.api.nvim_buf_set_lines(old_buf, 0, -1, false, old_lines)
    vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, new_lines)
    
    -- Set buffer options
    local function setup_diff_buffer(buf, title, readonly)
        vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
        vim.api.nvim_buf_set_option(buf, 'buflisted', false)
        vim.api.nvim_buf_set_option(buf, 'swapfile', false)
        vim.api.nvim_buf_set_option(buf, 'modifiable', not readonly)
        if readonly then
            vim.api.nvim_buf_set_option(buf, 'readonly', true)
        end
        
        -- Set filetype based on file extension
        local ft = vim.filetype.match({ filename = change.file }) or 'text'
        vim.api.nvim_buf_set_option(buf, 'filetype', ft)
        
        -- Set buffer name
        vim.api.nvim_buf_set_name(buf, title)
    end
    
    setup_diff_buffer(old_buf, change.file .. ' (before)', true)
    setup_diff_buffer(new_buf, change.file .. ' (after)', false)
    
    -- Open windows side by side
    vim.cmd('tabnew')
    local tab = vim.api.nvim_get_current_tabpage()
    
    -- Left window (old content)
    local left_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(left_win, old_buf)
    
    -- Right window (new content)
    vim.cmd('vsplit')
    local right_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(right_win, new_buf)
    
    -- Enable diff mode
    vim.api.nvim_win_call(left_win, function()
        vim.cmd('diffthis')
    end)
    vim.api.nvim_win_call(right_win, function()
        vim.cmd('diffthis')
    end)
    
    -- Set window titles
    vim.api.nvim_win_set_option(left_win, 'winfixwidth', true)
    vim.api.nvim_win_set_option(right_win, 'winfixwidth', true)
    
    -- Add keymaps for navigation
    local function close_diff()
        vim.cmd('tabclose')
    end
    
    local opts = { buffer = old_buf, silent = true }
    vim.keymap.set('n', 'q', close_diff, opts)
    vim.keymap.set('n', '<Esc>', close_diff, opts)
    
    opts = { buffer = new_buf, silent = true }
    vim.keymap.set('n', 'q', close_diff, opts)
    vim.keymap.set('n', '<Esc>', close_diff, opts)
    
    vim.notify(string.format('Showing diff for %s (%s)', change.file, change.type), vim.log.levels.INFO)
end

-- Get current changed files
function M.get_changed_files()
    return M._state.changed_files
end

-- Auto-reload changed files in Neovim
function M.auto_reload_changed_files(changed_files)
    local logger = require('gemi.logger')
    local reloaded_files = {}
    
    logger.debug('Starting auto-reload process', { files_to_check = #changed_files })
    
    for _, change in ipairs(changed_files) do
        if change.type == 'modified' or change.type == 'added' then
            local filepath = vim.fn.fnamemodify(change.file, ':p')
            logger.debug('Checking file for reload', { file = change.file, full_path = filepath })
            
            -- Check if file is currently open in any buffer
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
                    local buf_name = vim.api.nvim_buf_get_name(buf)
                    local buf_path = vim.fn.fnamemodify(buf_name, ':p')
                    
                    -- Multiple ways to match the file
                    local match = false
                    if buf_path == filepath then
                        match = true
                    elseif buf_name == change.file then
                        match = true
                    elseif buf_name == vim.fn.fnamemodify(change.file, ':p') then
                        match = true
                    elseif vim.fn.fnamemodify(buf_name, ':t') == vim.fn.fnamemodify(change.file, ':t') then
                        -- Last resort: match by filename only
                        match = true
                    end
                    
                    if match then
                        logger.debug('Found buffer to reload', { buf = buf, file = change.file, buf_name = buf_name, buf_path = buf_path, filepath = filepath })
                        
                        -- File is open, reload it immediately
                        vim.schedule(function()
                            -- Find all windows showing this buffer
                            local windows = {}
                            for _, win in ipairs(vim.api.nvim_list_wins()) do
                                if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
                                    table.insert(windows, win)
                                end
                            end
                            
                            logger.debug('Reloading buffer', { buf = buf, windows_count = #windows })
                            
                            -- Save cursor positions for all windows
                            local cursor_positions = {}
                            for _, win in ipairs(windows) do
                                if vim.api.nvim_win_is_valid(win) then
                                    cursor_positions[win] = vim.api.nvim_win_get_cursor(win)
                                end
                            end
                            
                            -- Force reload the buffer content
                            local success = pcall(function()
                                -- Clear the modified flag to allow reload
                                vim.api.nvim_buf_set_option(buf, 'modified', false)
                                
                                -- Use :e! to force reload from disk
                                vim.api.nvim_buf_call(buf, function()
                                    vim.cmd('silent! edit!')
                                end)
                            end)
                            
                            if success then
                                logger.debug('Successfully reloaded buffer', { buf = buf })
                                
                                -- Restore cursor positions for all windows
                                for _, win in ipairs(windows) do
                                    if vim.api.nvim_win_is_valid(win) and cursor_positions[win] then
                                        pcall(vim.api.nvim_win_set_cursor, win, cursor_positions[win])
                                    end
                                end
                                
                                -- Track reloaded file
                                table.insert(reloaded_files, change.file)
                            else
                                logger.error('Failed to reload buffer', { buf = buf, file = change.file })
                            end
                        end)
                        break
                    end
                end
            end
        end
    end
    
    -- Show notification if files were reloaded
    if #reloaded_files > 0 then
        vim.schedule(function()
            vim.notify(string.format('Auto-reloaded %d file(s): %s', 
                #reloaded_files, 
                table.concat(reloaded_files, ', ')), 
                vim.log.levels.INFO)
        end)
    end
end

-- Set up autocmds for automatic file reloading
function M.setup_auto_reload_autocmds()
    local group = vim.api.nvim_create_augroup('gemi_auto_reload', { clear = true })
    
    -- Auto-reload files when they're opened if they were recently modified by gemi
    vim.api.nvim_create_autocmd({'BufReadPost', 'BufNewFile'}, {
        group = group,
        callback = function(event)
            -- Check if this file was in our recent changes
            for _, change in ipairs(M._state.changed_files) do
                local filepath = vim.fn.fnamemodify(change.file, ':p')
                local buf_path = vim.fn.fnamemodify(event.match, ':p')
                
                if filepath == buf_path and (change.type == 'modified' or change.type == 'added') then
                    -- File was recently modified by gemi, ensure it's up to date
                    vim.schedule(function()
                        vim.cmd('checktime')
                    end)
                    break
                end
            end
        end
    })
    
    -- Detect external file changes and auto-reload
    vim.api.nvim_create_autocmd({'FocusGained', 'BufEnter', 'CursorHold'}, {
        group = group,
        callback = function()
            -- Check for external file changes
            vim.cmd('checktime')
        end
    })
end

-- Force reload all changed files immediately
function M.force_reload_all_changed_files()
    local changed_files = M._state.changed_files
    if #changed_files > 0 then
        M.auto_reload_changed_files(changed_files)
    else
        vim.notify('No changed files to reload', vim.log.levels.INFO)
    end
end

-- Debug function to test change detection
function M.debug_change_detection()
    local logger = require('gemi.logger')
    
    logger.info('=== DEBUG: Change Detection ===')
    logger.info('Current changed files', { count = #M._state.changed_files })
    
    for i, change in ipairs(M._state.changed_files) do
        logger.info('Changed file ' .. i, { 
            file = change.file, 
            type = change.type,
            old_content_length = #change.old_content,
            new_content_length = #change.new_content
        })
    end
    
    logger.info('Available snapshots', { count = vim.tbl_count(M._state.snapshots) })
    for name, snapshot in pairs(M._state.snapshots) do
        logger.info('Snapshot', { name = name, timestamp = snapshot.timestamp, files_count = vim.tbl_count(snapshot.files) })
    end
    
    local current_files = M._get_project_files()
    logger.info('Current project files', { count = #current_files })
    
    return M._state.changed_files
end

-- Clear change tracking
function M.clear_changes()
    M._state.changed_files = {}
    M._state.snapshots = {}
    vim.notify('Change tracking cleared', vim.log.levels.INFO)
end

return M