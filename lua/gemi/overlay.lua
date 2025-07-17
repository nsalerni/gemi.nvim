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
	execution_start_time = nil, -- Track when execution started
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
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "buflisted", false)
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_option(buf, "filetype", "gemi-prompt")
	-- Set up initial prompt text with cleaner indicator
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "> " })
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
	if not M._state.is_visible or not M._state.main_buf or not vim.api.nvim_buf_is_valid(M._state.main_buf) then
		return
	end
	local logs = logger.get_logs()
	local lines = {}

	-- Header with spinner and elapsed time if executing
	local header = "=== 🤖 Gemi Chat ==="
	if M._state.is_executing then
		local spinner = M._state.spinner_chars[M._state.spinner_index]
		local elapsed = ""
		if M._state.execution_start_time then
			local elapsed_seconds = math.floor(vim.loop.hrtime() / 1000000000) - M._state.execution_start_time
			elapsed = string.format(" (%ds)", elapsed_seconds)
		end
		header = header .. " " .. spinner .. " ⚡ Executing..." .. elapsed
	end

	table.insert(lines, header)
	table.insert(lines, "")

	-- Show conversation context status
	local conversation = require("gemi.conversation")
	if conversation.is_context_enabled() then
		local history_count = conversation.get_history_count()
		if history_count > 0 then
			local msg = string.format(
				"📝 Conversation context: %d messages (press 'x' to clear, 'c' to toggle)",
				history_count
			)
			table.insert(lines, msg)
		else
			table.insert(lines, "📝 Conversation context: enabled (press 'c' to disable)")
		end
	else
		table.insert(lines, "📝 Conversation context: disabled (press 'c' to enable)")
	end
	table.insert(lines, "")

	-- Show logs with modern styling
	for _, entry in ipairs(logs) do
		local level_name = logger._get_level_name and logger._get_level_name(entry.level) or "INFO"

		-- Format different types of messages with visual indicators
		if entry.data and entry.data.prompt then
			-- User prompt
			local icon = "💬"
			local line = string.format("%s [%s] You:", icon, entry.timestamp)
			table.insert(lines, line)
			table.insert(lines, "  " .. entry.data.prompt)
			table.insert(lines, "")
		elseif entry.data and entry.data.output and entry.data.preserve_formatting then
			-- Assistant response
			local icon = "🤖"
			local line = string.format("%s [%s] Assistant:", icon, entry.timestamp)
			table.insert(lines, line)
			-- For gemini output, preserve newlines and show full content
			local output_lines = vim.split(entry.data.output, "\n")
			for _, output_line in ipairs(output_lines) do
				table.insert(lines, "  " .. output_line)
			end
			table.insert(lines, "")
		elseif entry.data and entry.data.is_error then
			-- Error message
			local icon = "❌"
			local line = string.format("%s [%s] Error:", icon, entry.timestamp)
			table.insert(lines, line)
			table.insert(lines, "  " .. entry.message)
			if entry.data.output then
				local error_lines = vim.split(tostring(entry.data.output), "\n")
				for _, error_line in ipairs(error_lines) do
					table.insert(lines, "  " .. error_line)
				end
			end
			table.insert(lines, "")
		else
			-- Regular log message
			local icon = level_name == "ERROR" and "❌" or level_name == "WARN" and "⚠️" or "ℹ️"
			local line = string.format("%s [%s] %s", icon, entry.timestamp, entry.message)
			table.insert(lines, line)

			-- Handle other data
			if entry.data then
				for key, value in pairs(entry.data) do
					local skip_keys = { "prompt", "output", "preserve_formatting", "is_error" }
					local should_skip = false
					for _, skip_key in ipairs(skip_keys) do
						if key == skip_key then
							should_skip = true
							break
						end
					end
					if not should_skip then
						local value_str
						if type(value) == "table" then
							value_str = vim.inspect(value)
						else
							value_str = tostring(value)
						end
						-- Apply truncation
						value_str = value_str:gsub("\n", " "):gsub("\r", " ")
						if #value_str > 100 then
							value_str = value_str:sub(1, 100) .. "..."
						end
						table.insert(lines, string.format("  %s: %s", key, value_str))
					end
				end
			end
			table.insert(lines, "")
		end
	end
	if #logs == 0 then
		table.insert(lines, "No logs yet. Enter a prompt below to get started.")
	end

	-- Add simple separator before prompt
	table.insert(lines, "")
	table.insert(lines, string.rep("─", 50))
	table.insert(lines, "")

	-- Update buffer
	vim.api.nvim_buf_set_option(M._state.main_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(M._state.main_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(M._state.main_buf, "modifiable", false)
	-- Apply syntax highlighting
	M._apply_syntax_highlighting(lines)

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

	local function execute_current_prompt()
		local lines = vim.api.nvim_buf_get_lines(M._state.prompt_buf, 0, -1, false)
		local full_text = table.concat(lines, "\n")
		-- Remove the prompt prefix from the first line
		local prompt_prefix = "> "
		if full_text:sub(1, #prompt_prefix) == prompt_prefix then
			full_text = full_text:sub(#prompt_prefix + 1)
		end
		-- Trim whitespace
		full_text = full_text:match("^%s*(.-)%s*$")
		if full_text and full_text ~= "" then
			M.execute_prompt(full_text)
		end
	end

	-- Function to protect the prompt prefix
	local function protect_prompt_prefix()
		local lines = vim.api.nvim_buf_get_lines(M._state.prompt_buf, 0, -1, false)
		if #lines > 0 then
			local first_line = lines[1]
			if not first_line:match("^> ") then
				-- Restore the prompt prefix if it's missing
				if first_line == "" then
					vim.api.nvim_buf_set_lines(M._state.prompt_buf, 0, 1, false, { "> " })
				else
					vim.api.nvim_buf_set_lines(M._state.prompt_buf, 0, 1, false, { "> " .. first_line })
				end
				-- Move cursor to after the prefix
				vim.schedule(function()
					local cursor_pos = vim.api.nvim_win_get_cursor(M._state.prompt_win)
					local new_col = math.max(2, cursor_pos[2])
					vim.api.nvim_win_set_cursor(M._state.prompt_win, { cursor_pos[1], new_col })
				end)
			end
		end
	end

	-- Function to handle key presses that might delete the prefix
	local function handle_prefix_deletion(key)
		return function()
			local cursor_pos = vim.api.nvim_win_get_cursor(M._state.prompt_win)
			local col = cursor_pos[2]
			local line = cursor_pos[1]

			-- Prevent deletion if cursor is at or before the prefix
			if line == 1 and col <= 2 then
				return -- Block the deletion
			end

			-- Allow the key if it's safe
			vim.api.nvim_feedkeys(key, "n", false)

			-- Check and restore prefix after the operation
			vim.schedule(protect_prompt_prefix)
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
	-- Enter executes the prompt, Shift+Enter creates new line
	vim.keymap.set("i", "<CR>", execute_current_prompt, prompt_opts)
	vim.keymap.set("i", "<S-CR>", "<CR>", prompt_opts)
	vim.keymap.set("n", "<CR>", execute_current_prompt, prompt_opts)

	-- Protect the prompt prefix from deletion
	vim.keymap.set(
		"i",
		"<BS>",
		handle_prefix_deletion(vim.api.nvim_replace_termcodes("<BS>", true, false, true)),
		prompt_opts
	)
	vim.keymap.set(
		"i",
		"<Del>",
		handle_prefix_deletion(vim.api.nvim_replace_termcodes("<Del>", true, false, true)),
		prompt_opts
	)
	vim.keymap.set(
		"i",
		"<C-h>",
		handle_prefix_deletion(vim.api.nvim_replace_termcodes("<C-h>", true, false, true)),
		prompt_opts
	)
	vim.keymap.set(
		"i",
		"<C-w>",
		handle_prefix_deletion(vim.api.nvim_replace_termcodes("<C-w>", true, false, true)),
		prompt_opts
	)
	vim.keymap.set(
		"i",
		"<C-u>",
		handle_prefix_deletion(vim.api.nvim_replace_termcodes("<C-u>", true, false, true)),
		prompt_opts
	)

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

	-- Conversation management
	vim.keymap.set("n", "c", function()
		local conversation = require("gemi.conversation")
		conversation.toggle_context()
		M.update_logs()
	end, main_opts)

	vim.keymap.set("n", "x", function()
		local conversation = require("gemi.conversation")
		conversation.clear_history()
		M.update_logs()
	end, main_opts)

	-- Set highlight groups
	vim.api.nvim_win_set_option(M._state.main_win, "winhighlight", "Normal:GemiNormal,FloatBorder:GemiBorder")
	vim.api.nvim_win_set_option(M._state.prompt_win, "winhighlight", "Normal:GemiNormal,FloatBorder:GemiBorder")

	-- Add buffer modification autocmd to protect the prefix
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = M._state.prompt_buf,
		callback = protect_prompt_prefix,
	})

	-- Restore saved prompt text if any
	if M._state.saved_prompt_text ~= "" then
		vim.api.nvim_buf_set_lines(M._state.prompt_buf, 0, -1, false, { "> " .. M._state.saved_prompt_text })
		-- Move cursor to end of line
		vim.schedule(function()
			local line_len = #("> " .. M._state.saved_prompt_text)
			vim.api.nvim_win_set_cursor(M._state.prompt_win, { 1, line_len })
		end)
	else
		-- Position cursor after prompt prefix
		vim.schedule(function()
			vim.api.nvim_win_set_cursor(M._state.prompt_win, { 1, 2 }) -- 2 = length of "> "
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
			local prompt_prefix = "> "
			if text:sub(1, #prompt_prefix) == prompt_prefix then
				text = text:sub(#prompt_prefix + 1)
			end
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

	-- Clear the prompt input and reset with prompt prefix
	if M._state.prompt_buf and vim.api.nvim_buf_is_valid(M._state.prompt_buf) then
		vim.api.nvim_buf_set_lines(M._state.prompt_buf, 0, -1, false, { "> " })
	end

	-- Update logs to show the new prompt
	M.update_logs()

	-- Execute via main module
	require("gemi").execute_prompt(prompt)
end

-- Setup function
function M.setup()
	-- Define modern highlight groups with color variations
	vim.api.nvim_set_hl(0, "GemiNormal", { link = "Normal" })
	vim.api.nvim_set_hl(0, "GemiBorder", { link = "FloatBorder" })
	vim.api.nvim_set_hl(0, "GemiTitle", { link = "Title" })
	vim.api.nvim_set_hl(0, "GemiModelIndicator", { fg = "#8a8a8a", bg = "NONE", italic = true })

	-- Chat message styling
	vim.api.nvim_set_hl(0, "GemiUserPrompt", { fg = "#7aa2f7", bold = true }) -- Blue for user prompts
	vim.api.nvim_set_hl(0, "GemiUserPromptIcon", { fg = "#7aa2f7", bold = true }) -- Blue for user icon
	vim.api.nvim_set_hl(0, "GemiAssistantResponse", { fg = "#9ece6a", bold = true }) -- Green for assistant
	vim.api.nvim_set_hl(0, "GemiAssistantIcon", { fg = "#9ece6a", bold = true }) -- Green for assistant icon
	vim.api.nvim_set_hl(0, "GemiTimestamp", { fg = "#565f89", italic = true }) -- Muted for timestamps
	vim.api.nvim_set_hl(0, "GemiContext", { fg = "#f7768e", italic = true }) -- Pink for context status
	vim.api.nvim_set_hl(0, "GemiSeparator", { fg = "#414868" }) -- Muted for separators
	vim.api.nvim_set_hl(0, "GemiError", { fg = "#f7768e", bold = true }) -- Red for errors
	vim.api.nvim_set_hl(0, "GemiSuccess", { fg = "#9ece6a" }) -- Green for success
	vim.api.nvim_set_hl(0, "GemiExecuting", { fg = "#e0af68", bold = true }) -- Yellow for executing
	vim.api.nvim_set_hl(0, "GemiPromptIndicator", { fg = "#bb9af7", bold = true }) -- Purple for prompt indicator
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
	M._state.execution_start_time = math.floor(vim.loop.hrtime() / 1000000000)
	start_spinner()
	M.update_logs()
end

-- Stop execution (called from executor)
function M.stop_execution()
	M._state.is_executing = false
	M._state.execution_start_time = nil
	M.stop_spinner()
	M.update_logs()
end

-- Apply syntax highlighting to the chat buffer
function M._apply_syntax_highlighting(lines)
	if not M._state.main_buf or not vim.api.nvim_buf_is_valid(M._state.main_buf) then
		return
	end

	-- Clear existing highlights
	vim.api.nvim_buf_clear_namespace(M._state.main_buf, -1, 0, -1)

	local ns_id = vim.api.nvim_create_namespace("gemi_highlight")

	for i, line in ipairs(lines) do
		local line_num = i - 1 -- 0-indexed

		-- Highlight header and status
		if line:match("^=== 🤖 Gemi Chat ===") then
			if line:match("⚡ Executing") then
				vim.api.nvim_buf_add_highlight(M._state.main_buf, ns_id, "GemiExecuting", line_num, 0, -1)
			else
				vim.api.nvim_buf_add_highlight(M._state.main_buf, ns_id, "GemiTitle", line_num, 0, -1)
			end
		-- Highlight conversation context
		elseif line:match("^📝 Conversation context:") then
			vim.api.nvim_buf_add_highlight(M._state.main_buf, ns_id, "GemiContext", line_num, 0, -1)
		-- Highlight user prompts
		elseif line:match("^💬 %[") then
			local timestamp_start, timestamp_end = line:find("%[%d%d:%d%d:%d%d%]")
			if timestamp_start then
				vim.api.nvim_buf_add_highlight(M._state.main_buf, ns_id, "GemiUserPromptIcon", line_num, 0, 2)
				vim.api.nvim_buf_add_highlight(
					M._state.main_buf,
					ns_id,
					"GemiTimestamp",
					line_num,
					timestamp_start - 1,
					timestamp_end
				)
				vim.api.nvim_buf_add_highlight(M._state.main_buf, ns_id, "GemiUserPrompt", line_num, timestamp_end, -1)
			end
		-- Highlight assistant responses
		elseif line:match("^🤖 %[") then
			local timestamp_start, timestamp_end = line:find("%[%d%d:%d%d:%d%d%]")
			if timestamp_start then
				vim.api.nvim_buf_add_highlight(M._state.main_buf, ns_id, "GemiAssistantIcon", line_num, 0, 2)
				vim.api.nvim_buf_add_highlight(
					M._state.main_buf,
					ns_id,
					"GemiTimestamp",
					line_num,
					timestamp_start - 1,
					timestamp_end
				)
				vim.api.nvim_buf_add_highlight(
					M._state.main_buf,
					ns_id,
					"GemiAssistantResponse",
					line_num,
					timestamp_end,
					-1
				)
			end
		-- Highlight errors
		elseif line:match("^❌ %[") then
			local timestamp_start, timestamp_end = line:find("%[%d%d:%d%d:%d%d%]")
			if timestamp_start then
				vim.api.nvim_buf_add_highlight(M._state.main_buf, ns_id, "GemiError", line_num, 0, 2)
				vim.api.nvim_buf_add_highlight(
					M._state.main_buf,
					ns_id,
					"GemiTimestamp",
					line_num,
					timestamp_start - 1,
					timestamp_end
				)
				vim.api.nvim_buf_add_highlight(M._state.main_buf, ns_id, "GemiError", line_num, timestamp_end, -1)
			end
		-- Highlight info messages
		elseif line:match("^ℹ️ %[") then
			local timestamp_start, timestamp_end = line:find("%[%d%d:%d%d:%d%d%]")
			if timestamp_start then
				vim.api.nvim_buf_add_highlight(M._state.main_buf, ns_id, "GemiSuccess", line_num, 0, 2)
				vim.api.nvim_buf_add_highlight(
					M._state.main_buf,
					ns_id,
					"GemiTimestamp",
					line_num,
					timestamp_start - 1,
					timestamp_end
				)
			end
		-- Highlight separators
		elseif line:match("^─+$") then
			vim.api.nvim_buf_add_highlight(M._state.main_buf, ns_id, "GemiSeparator", line_num, 0, -1)
		end
	end
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
	vim.api.nvim_win_set_option(M._state.model_indicator_win, "winhighlight", "Normal:GemiModelIndicator")
end

-- Pre-initialize
M.setup()
return M
