-- lua/gemi/executor.lua
-- Gemini CLI execution and process management

local M = {}
local config = require('gemi.config')
local logger = require('gemi.logger')

-- Execute gemini command with prompt
function M.run_gemini(prompt, callback)
    -- Try alternative executor first
    local alt_executor = require('gemi.executor-alt')
    return alt_executor.run_gemini_system(prompt, callback)
end

-- Original jobstart implementation (for reference)
function M.run_gemini_jobstart(prompt, callback)
    if not prompt or prompt == '' then
        logger.error('No prompt provided')
        callback(false, 'No prompt provided')
        return nil
    end
    
    logger.info('Starting gemini execution', { prompt = prompt })
    
    -- Escape the prompt for shell execution
    local escaped_prompt = vim.fn.shellescape(prompt)
    
    -- Build gemini command
    local cmd = { 'gemini', '--prompt', escaped_prompt }
    
    -- Add model configuration if specified
    local model = config.get('gemini.model')
    if model then
        table.insert(cmd, '--model')
        table.insert(cmd, model)
    end
    
    -- Add debug flag if needed
    local debug = config.get('gemini.debug')
    if debug then
        table.insert(cmd, '--debug')
    end
    
    -- Add all_files flag if needed
    local all_files = config.get('gemini.all_files')
    if all_files then
        table.insert(cmd, '--all_files')
    end
    
    -- Add YOLO mode for automatic action acceptance
    local yolo = config.get('gemini.yolo')
    if yolo then
        table.insert(cmd, '--yolo')
    end
    
    -- Add checkpointing for file edits
    local checkpointing = config.get('gemini.checkpointing')
    if checkpointing then
        table.insert(cmd, '--checkpointing')
    end
    
    local cwd = vim.fn.getcwd()
    logger.log_command(cmd, cwd)
    
    -- Debug: print the exact command that will be executed
    local cmd_str = table.concat(cmd, ' ')
    print("DEBUG: Executing command: " .. cmd_str)
    vim.notify("Executing: " .. cmd_str, vim.log.levels.INFO)
    
    local output_lines = {}
    local error_lines = {}
    
    -- Start the job with better output handling
    local job = vim.fn.jobstart(cmd, {
        on_stdout = function(job_id, data, event)
            logger.debug('STDOUT callback triggered', { 
                job_id = job_id, 
                event = event, 
                data_count = data and #data or 0,
                data = data
            })
            
            if data then
                for _, line in ipairs(data) do
                    if line and line ~= '' then
                        table.insert(output_lines, line)
                        logger.debug('STDOUT line', { line = line })
                        
                        -- Update UI with real-time output if visible
                        local ui = require('gemi.ui')
                        if ui.is_visible() then
                            local preview = line:sub(1, 50) .. (line:len() > 50 and '...' or '')
                            ui.update_status('Running... ' .. preview)
                        end
                        
                        -- Show output in real-time
                        vim.notify('Gemi: ' .. line, vim.log.levels.INFO)
                    end
                end
            end
        end,
        
        on_stderr = function(job_id, data, event)
            logger.debug('STDERR callback triggered', { 
                job_id = job_id, 
                event = event, 
                data_count = data and #data or 0,
                data = data
            })
            
            if data then
                for _, line in ipairs(data) do
                    if line and line ~= '' then
                        table.insert(error_lines, line)
                        logger.debug('STDERR line', { line = line })
                        
                        -- Show errors in real-time
                        vim.notify('Gemi Error: ' .. line, vim.log.levels.WARN)
                    end
                end
            end
        end,
        
        on_exit = function(job_id, exit_code, event)
            logger.info('Job exit callback triggered', {
                job_id = job_id,
                exit_code = exit_code,
                event = event,
                output_lines_count = #output_lines,
                error_lines_count = #error_lines,
            })
            
            local success = exit_code == 0
            local output = table.concat(output_lines, '\n')
            local errors = table.concat(error_lines, '\n')
            
            logger.info('Command completed', {
                exit_code = exit_code,
                success = success,
                output_lines = #output_lines,
                error_lines = #error_lines,
                output_preview = output:sub(1, 100),
                errors_preview = errors:sub(1, 100),
            })
            
            if success then
                if #output_lines > 0 then
                    logger.log_output(output, false)
                    vim.notify('Gemi completed successfully! Check :GemiLogs for details', vim.log.levels.INFO)
                else
                    logger.warn('Gemi completed but produced no output')
                    vim.notify('Gemi completed but produced no output', vim.log.levels.WARN)
                end
                callback(true, output)
            else
                local error_msg = errors ~= '' and errors or 'Command failed with exit code ' .. exit_code
                logger.log_output(errors, true)
                callback(false, error_msg)
            end
        end,
        
        cwd = cwd,
        env = vim.fn.environ(),
        stdout_buffered = false,
        stderr_buffered = false,
    })
    
    if job <= 0 then
        logger.error('Failed to start gemini command')
        callback(false, 'Failed to start gemini command')
        return nil
    end
    
    logger.info('Job started', { job_id = job })
    
    return {
        job_id = job,
        shutdown = function()
            logger.info('Stopping job', { job_id = job })
            vim.fn.jobstop(job)
        end
    }
end

-- Run authentication flow
function M.authenticate()
    logger.info('Starting Google authentication for gemini-cli')
    vim.notify('Starting Google authentication for gemini-cli...', vim.log.levels.INFO)
    
    -- First check if already authenticated
    local check_job = vim.fn.jobstart('gemini --help', {
        on_exit = function(_, exit_code)
            if exit_code == 0 then
                logger.info('gemini-cli found, checking authentication')
                -- CLI is working, try a simple command to check auth
                M._run_auth_check()
            else
                logger.error('gemini-cli not found')
                vim.notify('gemini-cli not found. Please install it first with :GemiInstall', vim.log.levels.ERROR)
            end
        end
    })
    
    if check_job <= 0 then
        logger.error('Failed to check gemini-cli status')
        vim.notify('Failed to check gemini-cli status', vim.log.levels.ERROR)
    end
end

-- Check authentication status
function M._run_auth_check()
    local job = vim.fn.jobstart('gemini --prompt "test"', {
        on_stdout = function(_, data)
            -- If we get output, auth is working
            vim.notify('Authentication appears to be working', vim.log.levels.INFO)
        end,
        
        on_stderr = function(_, data)
            if data then
                local error_text = table.concat(data, '\n')
                if error_text:find('auth') or error_text:find('login') or error_text:find('credential') then
                    -- Authentication needed
                    M._run_interactive_auth()
                else
                    vim.notify('Auth check error: ' .. error_text, vim.log.levels.WARN)
                end
            end
        end,
        
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                -- Likely needs authentication
                M._run_interactive_auth()
            end
        end,
        
        timeout = 5000,  -- 5 second timeout for auth check
    })
end

-- Run interactive authentication
function M._run_interactive_auth()
    vim.notify('Starting interactive authentication...', vim.log.levels.INFO)
    vim.notify('A browser window should open for Google authentication', vim.log.levels.INFO)
    
    -- Run gemini command that will trigger auth flow
    -- We'll use a terminal buffer to handle the interactive parts
    local term_buf = vim.api.nvim_create_buf(false, true)
    local term_win = vim.api.nvim_open_win(term_buf, true, {
        relative = 'editor',
        width = math.floor(vim.o.columns * 0.8),
        height = math.floor(vim.o.lines * 0.6),
        row = math.floor(vim.o.lines * 0.2),
        col = math.floor(vim.o.columns * 0.1),
        style = 'minimal',
        border = 'rounded',
        title = ' Google Authentication ',
        title_pos = 'center',
    })
    
    -- Start terminal with gemini command
    local job = vim.fn.termopen('gemini --prompt "Hello, this is a test prompt for authentication"', {
        on_exit = function(_, exit_code)
            vim.schedule(function()
                if vim.api.nvim_win_is_valid(term_win) then
                    vim.api.nvim_win_close(term_win, true)
                end
                
                if exit_code == 0 then
                    vim.notify('Authentication completed successfully!', vim.log.levels.INFO)
                else
                    vim.notify('Authentication failed or was cancelled', vim.log.levels.ERROR)
                end
            end)
        end
    })
    
    -- Set up keymaps to close the terminal
    local opts = { buffer = term_buf, silent = true }
    vim.keymap.set('n', '<Esc>', function()
        if vim.api.nvim_win_is_valid(term_win) then
            vim.api.nvim_win_close(term_win, true)
        end
    end, opts)
    vim.keymap.set('t', '<C-c>', function()
        if vim.api.nvim_win_is_valid(term_win) then
            vim.api.nvim_win_close(term_win, true)
        end
    end, opts)
end

-- Check if gemini-cli is authenticated
function M.is_authenticated()
    -- This is a simple check - we could make it more robust
    local handle = io.popen('gemini --prompt "test" 2>&1')
    if handle then
        local result = handle:read('*a')
        handle:close()
        
        -- Check for common authentication error patterns
        if result:find('auth') or result:find('login') or result:find('credential') then
            return false
        end
        return true
    end
    return false
end

return M