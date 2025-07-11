-- Alternative executor using blocking vim.fn.system
local M = {}
local config = require('gemi.config')
local logger = require('gemi.logger')

-- Execute gemini command with prompt using blocking system call
function M.run_gemini_system(prompt, callback)
    if not prompt or prompt == '' then
        logger.error('No prompt provided')
        callback(false, 'No prompt provided')
        return nil
    end
    
    logger.info('Starting gemini execution', { prompt = prompt })
    
    -- Build command
    local cmd = 'gemini --prompt ' .. vim.fn.shellescape(prompt)
    
    local model = config.get('gemini.model')
    if model then
        cmd = cmd .. ' --model ' .. model
    end
    
    local debug = config.get('gemini.debug')
    if debug then
        cmd = cmd .. ' --debug'
    end
    
    local all_files = config.get('gemini.all_files')
    if all_files then
        cmd = cmd .. ' --all_files'
    end
    
    local yolo = config.get('gemini.yolo')
    if yolo then
        cmd = cmd .. ' --yolo'
    end
    
    local checkpointing = config.get('gemini.checkpointing')
    if checkpointing then
        cmd = cmd .. ' --checkpointing'
    end
    
    logger.info('Executing command', { cmd = cmd })
    
    -- Start execution state
    local overlay = require('gemi.overlay')
    overlay.start_execution()
    
    -- Use vim.defer_fn to run the blocking call without blocking the UI
    vim.defer_fn(function()
        local output = vim.fn.system(cmd)
        local exit_code = vim.v.shell_error
        
        -- Stop execution state
        overlay.stop_execution()
        
        local success = exit_code == 0
        
        if success then
            logger.info('Command completed successfully', {
                output = output and output:gsub('\n', ' '):gsub('\r', ' ') or 'No output',
            })
            callback(true, output)
        else
            logger.error('Command failed', {
                exit_code = exit_code,
                command = cmd,
                output = output and output:gsub('\n', ' '):gsub('\r', ' ') or 'No output',
            })
            callback(false, output)
        end
        
        overlay.auto_refresh()
    end, 0)
    
    logger.info('Job started (blocking mode)')
    
    -- Return dummy job handle
    return {
        job_id = 'blocking',
        shutdown = function()
            logger.info('Cannot stop blocking job')
            overlay.stop_execution()
            overlay.auto_refresh()
        end
    }
end

return M