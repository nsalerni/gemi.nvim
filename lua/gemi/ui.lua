-- lua/gemi/ui.lua
-- User interface management

local M = {}
local config = require('gemi.config')

-- UI state
M._state = {
    input_buf = nil,
    input_win = nil,
    status_buf = nil,
    status_win = nil,
    is_visible = false,
}

-- Create input buffer
local function create_input_buffer()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'prompt')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)

    -- Set prompt
    local prompt = config.get('ui.prompt') or 'Gemi: '
    vim.fn.prompt_setprompt(buf, prompt)

    -- Set up prompt callback
    vim.fn.prompt_setcallback(buf, function(text)
        if text and text ~= '' then
            M.execute_prompt(text)
        end
    end)

    return buf
end

-- Create status buffer
local function create_status_buffer()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'readonly', true)

    return buf
end

-- Calculate window dimensions
local function get_window_config()
    local ui_config = config.get('ui')
    local screen_width = vim.o.columns
    local screen_height = vim.o.lines

    local width = math.floor(screen_width * ui_config.width)
    local height = ui_config.height

    local row, col
    if ui_config.position == 'bottom' then
        row = screen_height - height - 3  -- Account for cmdline and statusline
        col = math.floor((screen_width - width) / 2)
    elseif ui_config.position == 'top' then
        row = 2
        col = math.floor((screen_width - width) / 2)
    else -- center
        row = math.floor((screen_height - height) / 2)
        col = math.floor((screen_width - width) / 2)
    end

    return {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = ui_config.border,
        title = ui_config.title,
        title_pos = 'center',
    }
end

-- Show the UI
function M.show()
    if M._state.is_visible then
        return
    end

    -- Create buffers (fast operations)
    M._state.input_buf = create_input_buffer()

    -- Create window (fast operation)
    local win_config = get_window_config()
    M._state.input_win = vim.api.nvim_open_win(M._state.input_buf, true, win_config)

    -- Set window options (fast)
    vim.api.nvim_win_set_option(M._state.input_win, 'winhighlight', 'Normal:GemiNormal,FloatBorder:GemiBorder')

    -- Set up keymaps for the input window (fast)
    local function close_ui()
        M.hide()
    end

    local opts = { buffer = M._state.input_buf, silent = true }
    vim.keymap.set('i', '<Esc>', close_ui, opts)
    vim.keymap.set('n', '<Esc>', close_ui, opts)
    vim.keymap.set('n', 'q', close_ui, opts)
    vim.keymap.set('i', '<C-c>', close_ui, opts)

    -- Enter insert mode immediately
    vim.cmd('startinsert')

    M._state.is_visible = true
end

-- Hide the UI
function M.hide()
    if not M._state.is_visible then
        return
    end

    -- Close windows
    if M._state.input_win and vim.api.nvim_win_is_valid(M._state.input_win) then
        vim.api.nvim_win_close(M._state.input_win, true)
    end
    if M._state.status_win and vim.api.nvim_win_is_valid(M._state.status_win) then
        vim.api.nvim_win_close(M._state.status_win, true)
    end

    -- Clean up state
    M._state.input_buf = nil
    M._state.input_win = nil
    M._state.status_buf = nil
    M._state.status_win = nil
    M._state.is_visible = false
end

-- Update status display
function M.update_status(message)
    if not M._state.is_visible then
        -- If UI is hidden, show notification instead
        vim.notify(message, vim.log.levels.INFO)
        return
    end

    if M._state.status_buf and vim.api.nvim_buf_is_valid(M._state.status_buf) then
        vim.api.nvim_buf_set_option(M._state.status_buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(M._state.status_buf, 0, -1, false, { message })
        vim.api.nvim_buf_set_option(M._state.status_buf, 'modifiable', false)
    end
end

-- Execute prompt
function M.execute_prompt(prompt)
    -- Clear the input
    if M._state.input_buf and vim.api.nvim_buf_is_valid(M._state.input_buf) then
        vim.api.nvim_buf_set_lines(M._state.input_buf, 0, -1, false, {})
    end

    -- Update status
    M.update_status('Executing: ' .. prompt)

    -- Execute via main module
    require('gemi').execute_prompt(prompt)
end

-- Setup function
function M.setup()
    -- Define highlight groups (fast operation)
    vim.api.nvim_set_hl(0, 'GemiNormal', { link = 'Normal' })
    vim.api.nvim_set_hl(0, 'GemiBorder', { link = 'FloatBorder' })
    vim.api.nvim_set_hl(0, 'GemiTitle', { link = 'Title' })
end

-- Pre-initialize UI setup to avoid delays
M.setup()

-- Check if UI is visible
function M.is_visible()
    return M._state.is_visible
end

return M
