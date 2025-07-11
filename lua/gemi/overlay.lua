-- lua/gemi/overlay.lua
-- Combined prompt and logs overlay window
local M = {}
local config = require("gemi.config")
local logger = require("gemi.logger")
-- Overlay state
M._state = {
  is_visible = false,
  main_buf = nil,
  main_win = nil,
  prompt_buf = nil,
  prompt_win = nil,
  model_indicator_buf = nil,
  model_indicator_win = nil,
  logs_start_line = 3, -- Line where logs start
  prompt_height = 1,
  current_prompt = "",
  saved_prompt_text = "", -- Persist text when toggling
  is_executing = false,
  spinner_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  spinner_index = 1,
  spinner_timer = nil,
}
-- Create the main overlay buffer

local function create_main_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buflisted", false)
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_option(buf, "filetype", "gemi-overlay")
  return buf
end
-- Create the prompt buffer

local function create_prompt_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buflisted", false)
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  -- Set prompt
  vim.fn.prompt_setprompt(buf, "Gemi: ")
  -- Set up prompt callback
  vim.fn.prompt_setcallback(buf, function(text)
    if text and text ~= "" then
      M.execute_prompt(text)
    end

  end)
  return buf
end
-- Get window configuration

local function get_window_config()
  local ui_config = config.get("ui") or {}
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  local width = math.floor(screen_width * (ui_config.width or 0.9))
  local height = math.floor(screen_height * 0.8)
  local row = math.floor((screen_height - height) / 2)
  local col = math.floor((screen_width - width) / 2)
  return {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = ui_config.border or "rounded",
    title = " Gemi - Prompt & Logs ",
    title_pos = "center",
  }
end
-- Start spinner

local function start_spinner()
  if M._state.spinner_timer then
    return
  end

  M._state.spinner_timer = vim.loop.new_timer()
  M._state.spinner_timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      if M._state.is_executing then
        M._state.spinner_index = (M._state.spinner_index % #M._state.spinner_chars) + 1
        M.update_logs()
      else
        M.stop_spinner()
      end

    end)
  )
end
-- Stop spinner

function M.stop_spinner()
  if M._state.spinner_timer then
    M._state.spinner_timer:stop()
    M._state.spinner_timer:close()
    M._state.spinner_timer = nil
  end

end
-- Update the logs section

function M.update_logs()
  if
    not M._state.is_visible
    or not M._state.main_buf
    or not vim.api.nvim_buf_is_valid(M._state.main_buf)
  then
    return
  end

  local logs = logger.get_logs()
  local lines = {}
  -- Header with spinner if executing
  local header = "=== Gemi ==="
  if M._state.is_executing then
    local spinner = M._state.spinner_chars[M._state.spinner_index]
    header = header .. " " .. spinner .. " Executing..."
  end

  table.insert(lines, header)
  table.insert(lines, "")
  -- Show logs
  for _, entry in ipairs(logs) do
    local level_name = logger._get_level_name and logger._get_level_name(entry.level) or "INFO"
    local line = string.format("[%s] %s: %s", entry.timestamp, level_name, entry.message)
    table.insert(lines, line)
    if entry.data then
      for key, value in pairs(entry.data) do
        local value_str
        if type(value) == "table" then
          value_str = vim.inspect(value)
        else
          value_str = tostring(value)
        end
        -- Special handling for gemini output
        if key == "output" and entry.data.preserve_formatting then
          -- For gemini output, preserve newlines and show full content
          local output_lines = vim.split(value_str, "\n")
          table.insert(lines, string.format("  %s:", key))
          for _, output_line in ipairs(output_lines) do
            table.insert(lines, "    " .. output_line)
          end

        else
          -- For other data, apply truncation
          value_str = value_str:gsub("\n", " "):gsub("\r", " ")
          if #value_str > 150 then
            value_str = value_str:sub(1, 150) .. "..."
          end

          table.insert(lines, string.format("  %s: %s", key, value_str))
        end

      end

    end

    table.insert(lines, "")
  end

  if #logs == 0 then
    table.insert(lines, "No logs yet. Enter a prompt below to get started.")
  end
  -- Add separator before prompt
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, "")
  -- Update buffer
  vim.api.nvim_buf_set_option(M._state.main_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M._state.main_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M._state.main_buf, "modifiable", false)
  -- Add model indicator to bottom right corner
  M.add_model_indicator()
  -- Scroll to bottom
  if M._state.main_win and vim.api.nvim_win_is_valid(M._state.main_win) then
    vim.api.nvim_win_set_cursor(M._state.main_win, { #lines, 0 })
  end

end
-- Show the overlay

function M.show()
  if M._state.is_visible then
    return
  end
  -- Create buffers
  M._state.main_buf = create_main_buffer()
  M._state.prompt_buf = create_prompt_buffer()
  -- Get window config
  local win_config = get_window_config()
  local prompt_height = 3
  -- Create main window (logs)
  local main_config = vim.tbl_deep_extend("force", win_config, {
    height = win_config.height - prompt_height,
    title = " Gemi Chat ",
  })
  M._state.main_win = vim.api.nvim_open_win(M._state.main_buf, false, main_config)
  -- Create prompt window (bottom)
  local prompt_config = vim.tbl_deep_extend("force", win_config, {
    height = prompt_height,
    row = win_config.row + win_config.height - prompt_height,
    title = " Prompt ",
    title_pos = "left",
  })
  M._state.prompt_win = vim.api.nvim_open_win(M._state.prompt_buf, true, prompt_config)
  -- Set up keymaps

  local function close_overlay()
    M.hide()
  end


  local function toggle_focus()
    if vim.api.nvim_get_current_win() == M._state.prompt_win then
      vim.api.nvim_set_current_win(M._state.main_win)
    else
      vim.api.nvim_set_current_win(M._state.prompt_win)
      vim.cmd("startinsert")
    end

  end
  -- Keymaps for both windows
  local main_opts = { buffer = M._state.main_buf, silent = true }
  local prompt_opts = { buffer = M._state.prompt_buf, silent = true }
  -- Close overlay
  vim.keymap.set("n", "<Esc>", close_overlay, main_opts)
  vim.keymap.set("n", "q", close_overlay, main_opts)
  vim.keymap.set("i", "<Esc>", close_overlay, prompt_opts)
  vim.keymap.set("n", "<Esc>", close_overlay, prompt_opts)
  vim.keymap.set("i", "<C-c>", close_overlay, prompt_opts)
  -- Toggle focus
  vim.keymap.set("n", "<Tab>", toggle_focus, main_opts)
  vim.keymap.set("n", "<Tab>", toggle_focus, prompt_opts)
  vim.keymap.set("i", "<C-Tab>", toggle_focus, prompt_opts)
  -- Ctrl-G to toggle overlay from prompt
  vim.keymap.set("i", "<C-g>", function()
    require("gemi").toggle()
  end, prompt_opts)
  vim.keymap.set("n", "<C-g>", function()
    require("gemi").toggle()
  end, prompt_opts)
  -- Refresh logs
  vim.keymap.set("n", "r", function()
    M.update_logs()
  end, main_opts)
  -- Set highlight groups
  vim.api.nvim_win_set_option(
    M._state.main_win,
    "winhighlight",
    "Normal:GemiNormal,FloatBorder:GemiBorder"
  )
  vim.api.nvim_win_set_option(
    M._state.prompt_win,
    "winhighlight",
    "Normal:GemiNormal,FloatBorder:GemiBorder"
  )
  -- Restore saved prompt text if any
  if M._state.saved_prompt_text ~= "" then
    vim.api.nvim_buf_set_lines(M._state.prompt_buf, 0, -1, false, { M._state.saved_prompt_text })
    -- Move cursor to end of line
    vim.schedule(function()
      local line_len = #M._state.saved_prompt_text
      vim.api.nvim_win_set_cursor(M._state.prompt_win, { 1, line_len })
    end)
  end
  -- Enter insert mode in prompt
  vim.cmd("startinsert")
  M._state.is_visible = true
  -- Update logs initially
  M.update_logs()
  -- Add model indicator
  M.add_model_indicator()
end
-- Hide the overlay

function M.hide()
  if not M._state.is_visible then
    return
  end
  -- Save current prompt text before hiding
  if M._state.prompt_buf and vim.api.nvim_buf_is_valid(M._state.prompt_buf) then
    local lines = vim.api.nvim_buf_get_lines(M._state.prompt_buf, 0, -1, false)
    if #lines > 0 then
      -- Remove the prompt prefix and save the actual text
      local text = lines[1] or ""
      M._state.saved_prompt_text = text
    end

  end
  -- Close windows
  if M._state.main_win and vim.api.nvim_win_is_valid(M._state.main_win) then
    vim.api.nvim_win_close(M._state.main_win, true)
  end

  if M._state.prompt_win and vim.api.nvim_win_is_valid(M._state.prompt_win) then
    vim.api.nvim_win_close(M._state.prompt_win, true)
  end

  if M._state.model_indicator_win and vim.api.nvim_win_is_valid(M._state.model_indicator_win) then
    vim.api.nvim_win_close(M._state.model_indicator_win, true)
  end
  -- Clean up state
  M._state.main_buf = nil
  M._state.main_win = nil
  M._state.prompt_buf = nil
  M._state.prompt_win = nil
  M._state.model_indicator_buf = nil
  M._state.model_indicator_win = nil
  M._state.is_visible = false
end
-- Execute prompt

function M.execute_prompt(prompt)
  -- Stop any currently running job first
  local gemi = require("gemi")
  if gemi._state.is_running then
    gemi.stop()
    vim.schedule(function()
      -- Wait a moment for the job to stop, then start new one
      vim.defer_fn(function()
        M._execute_prompt_internal(prompt)
      end, 100)
    end)
  else
    M._execute_prompt_internal(prompt)
  end

end
-- Internal execute function

function M._execute_prompt_internal(prompt)
  -- Store the current prompt
  M._state.current_prompt = prompt
  -- Immediately log the prompt so user sees it
  logger.info("User prompt", { prompt = prompt })
  -- Clear the prompt input
  if M._state.prompt_buf and vim.api.nvim_buf_is_valid(M._state.prompt_buf) then
    vim.api.nvim_buf_set_lines(M._state.prompt_buf, 0, -1, false, {})
  end
  -- Update logs to show the new prompt
  M.update_logs()
  -- Execute via main module
  require("gemi").execute_prompt(prompt)
end
-- Setup function

function M.setup()
  -- Define highlight groups
  vim.api.nvim_set_hl(0, "GemiNormal", { link = "Normal" })
  vim.api.nvim_set_hl(0, "GemiBorder", { link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "GemiTitle", { link = "Title" })
  vim.api.nvim_set_hl(0, "GemiModelIndicator", { fg = "#8a8a8a", bg = "NONE", italic = true })
end
-- Check if overlay is visible

function M.is_visible()
  return M._state.is_visible
end
-- Auto-refresh logs when new entries are added

function M.auto_refresh()
  if M._state.is_visible then
    M.update_logs()
  end

end
-- Start execution (called from executor)

function M.start_execution()
  M._state.is_executing = true
  start_spinner()
  M.update_logs()
end
-- Stop execution (called from executor)

function M.stop_execution()
  M._state.is_executing = false
  M.stop_spinner()
  M.update_logs()
end
-- Add model indicator to bottom right corner

function M.add_model_indicator()
  if not M._state.main_win or not vim.api.nvim_win_is_valid(M._state.main_win) then
    return
  end
  -- Get current model
  local ok, gemi = pcall(require, "gemi")
  if not ok then
    return
  end

  local current_model = gemi.get_current_model()
  if not current_model then
    return
  end
  -- Create a short model name for display
  local model_display = current_model
  if current_model:find("gemini-2.5-flash") then
    model_display = "2.5-flash"
  elseif current_model:find("gemini-2.5-pro") then
    model_display = "2.5-pro"
  elseif current_model:find("gemini-1.5-flash") then
    model_display = "1.5-flash"
  elseif current_model:find("gemini-1.5-pro") then
    model_display = "1.5-pro"
  end
  -- Get window dimensions
  local win_config = vim.api.nvim_win_get_config(M._state.main_win)
  local width = win_config.width
  local height = win_config.height
  -- Create model indicator text
  local model_text = string.format("[%s]", model_display)
  local model_col = width - #model_text - 1
  local model_row = height - 1
  -- Create floating window for model indicator
  if M._state.model_indicator_buf and vim.api.nvim_buf_is_valid(M._state.model_indicator_buf) then
    vim.api.nvim_buf_delete(M._state.model_indicator_buf, { force = true })
  end

  M._state.model_indicator_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M._state.model_indicator_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M._state.model_indicator_buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(M._state.model_indicator_buf, "buflisted", false)
  vim.api.nvim_buf_set_option(M._state.model_indicator_buf, "swapfile", false)
  vim.api.nvim_buf_set_option(M._state.model_indicator_buf, "modifiable", true)
  -- Set the model text
  vim.api.nvim_buf_set_lines(M._state.model_indicator_buf, 0, -1, false, { model_text })
  vim.api.nvim_buf_set_option(M._state.model_indicator_buf, "modifiable", false)
  -- Calculate absolute position
  local main_win_row = win_config.row or 0
  local main_win_col = win_config.col or 0
  -- Create floating window for model indicator
  if M._state.model_indicator_win and vim.api.nvim_win_is_valid(M._state.model_indicator_win) then
    vim.api.nvim_win_close(M._state.model_indicator_win, true)
  end

  M._state.model_indicator_win = vim.api.nvim_open_win(M._state.model_indicator_buf, false, {
    relative = "editor",
    width = #model_text,
    height = 1,
    row = main_win_row + model_row,
    col = main_win_col + model_col,
    style = "minimal",
    focusable = false,
    zindex = 1000,
  })
  -- Set highlight for model indicator
  vim.api.nvim_win_set_option(
    M._state.model_indicator_win,
    "winhighlight",
    "Normal:GemiModelIndicator"
  )
end
-- Pre-initialize
M.setup()
return M
