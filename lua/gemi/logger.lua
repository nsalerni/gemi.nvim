-- lua/gemi/logger.lua
-- Logging system for Gemi plugin
local M = {}
-- Log storage
M._logs = {}
M._current_session = os.date("%Y-%m-%d_%H-%M-%S")
-- Log levels
M.LEVELS = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}
-- Check if debug logging is enabled

function M.is_debug_enabled()
  local ok, config = pcall(require, "gemi.config")
  if ok then
    return config.get("logging.debug") == true
  end
  return false
end
-- Add log entry

function M.log(level, message, data)
  -- Skip debug messages unless debug is enabled
  if level == M.LEVELS.DEBUG and not M.is_debug_enabled() then
    return
  end

  local timestamp = os.date("%H:%M:%S")
  local log_entry = {
    timestamp = timestamp,
    level = level,
    message = message,
    data = data,
    session = M._current_session,
  }
  table.insert(M._logs, log_entry)
  -- Auto-refresh overlay if visible
  vim.schedule(function()
    local ok, overlay = pcall(require, "gemi.overlay")
    if ok then
      overlay.auto_refresh()
    end

  end)
  -- Also print to neovim if it's important
  if level >= M.LEVELS.WARN then
    local level_name = M._get_level_name(level)
    vim.notify(string.format("[Gemi %s] %s", level_name, message), vim.log.levels.WARN)
  end

end
-- Get level name

function M._get_level_name(level)
  for name, val in pairs(M.LEVELS) do
    if val == level then
      return name
    end

  end
  return "UNKNOWN"
end
-- Log shortcuts

function M.debug(message, data)
  M.log(M.LEVELS.DEBUG, message, data)
end


function M.info(message, data)
  M.log(M.LEVELS.INFO, message, data)
end


function M.warn(message, data)
  M.log(M.LEVELS.WARN, message, data)
end


function M.error(message, data)
  M.log(M.LEVELS.ERROR, message, data)
end
-- Log command execution

function M.log_command(cmd, working_dir)
  M.info("Executing command", {
    command = table.concat(cmd, " "),
    working_dir = working_dir,
  })
end
-- Log command output

function M.log_output(output, is_error)
  local level = is_error and M.LEVELS.ERROR or M.LEVELS.INFO
  local message = is_error and "Command error output" or "Gemini response"
  M.log(level, message, {
    output = output,
    is_error = is_error,
    preserve_formatting = true, -- Flag to preserve full output
  })
end
-- Show logs in a buffer

function M.show_logs()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "buflisted", false)
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_option(buf, "filetype", "gemi-log")
  -- Format log entries
  local lines = {}
  table.insert(lines, "=== Gemi Logs (Session: " .. M._current_session .. ") ===")
  table.insert(lines, "")
  for _, entry in ipairs(M._logs) do
    local level_name = M._get_level_name(entry.level)
    local line = string.format("[%s] %s: %s", entry.timestamp, level_name, entry.message)
    table.insert(lines, line)
    if entry.data then
      -- Pretty print the data
      for key, value in pairs(entry.data) do
        local value_str
        if type(value) == "table" then
          value_str = vim.inspect(value)
        else
          value_str = tostring(value)
        end
        -- Replace newlines with spaces to avoid the error
        value_str = value_str:gsub("\n", " "):gsub("\r", " ")
        -- Truncate very long values
        if #value_str > 200 then
          value_str = value_str:sub(1, 200) .. "..."
        end

        table.insert(lines, string.format("  %s: %s", key, value_str))
      end

      table.insert(lines, "")
    end

  end

  if #M._logs == 0 then
    table.insert(lines, "No logs available for this session.")
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  -- Open in a new window
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Gemi Logs ",
    title_pos = "center",
  })
  -- Set up keymaps
  local opts = { buffer = buf, silent = true }
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, opts)
  vim.keymap.set("n", "r", function()
    vim.api.nvim_win_close(win, true)
    M.show_logs()
  end, opts)
  -- Go to the bottom
  vim.api.nvim_win_set_cursor(win, { #lines, 0 })
  vim.notify(
    string.format('Showing %d log entries (press "r" to refresh, "q" to close)', #M._logs),
    vim.log.levels.INFO
  )
end
-- Clear logs

function M.clear_logs()
  M._logs = {}
  M._current_session = os.date("%Y-%m-%d_%H-%M-%S")
  vim.notify("Gemi logs cleared", vim.log.levels.INFO)
end
-- Get current logs

function M.get_logs()
  return M._logs
end
-- Get logs count

function M.get_logs_count()
  return #M._logs
end
return M
