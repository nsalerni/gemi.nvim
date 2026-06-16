-- Main Gemi module
local M = {}

-- Plugin state
M._state = {
	is_running = false,
	current_job = nil,
	ui_visible = false,
	initialized = false,
	applied_keymaps = {},
}

-- Lazy load modules
local function get_config()
	return require("gemi.config")
end

local function get_overlay()
	return require("gemi.overlay")
end

local function get_installer()
	return require("gemi.installer")
end

local function get_executor()
	return require("gemi.executor")
end

local function get_tracker()
	return require("gemi.tracker")
end

local function clear_applied_keymaps()
	for mode, mappings in pairs(M._state.applied_keymaps) do
		for lhs, _ in pairs(mappings) do
			pcall(vim.keymap.del, mode, lhs)
		end
	end
	M._state.applied_keymaps = {}
end

local function set_configured_keymap(mode, lhs, rhs, desc)
	if type(lhs) ~= "string" or lhs == "" then
		return
	end

	vim.keymap.set(mode, lhs, rhs, { desc = desc, silent = true })
	M._state.applied_keymaps[mode] = M._state.applied_keymaps[mode] or {}
	M._state.applied_keymaps[mode][lhs] = true
end

local function setup_keymaps()
	local config = get_config()
	local keymaps = config.get("keymaps")
	if keymaps == false then
		clear_applied_keymaps()
		return
	end

	keymaps = keymaps or {}
	clear_applied_keymaps()
	set_configured_keymap("n", keymaps.toggle, M.toggle, "Toggle Gemi overlay")
	set_configured_keymap("n", keymaps.files, M.show_changed_files, "Show Gemi changed files")
	set_configured_keymap("n", keymaps.diff, M.show_diff, "Show Gemi diff")
	set_configured_keymap("n", keymaps.stop, M.stop, "Stop Gemi execution")
	set_configured_keymap("n", keymaps.install, M.install_cli, "Install Gemi CLI")
	set_configured_keymap("n", keymaps.logs, function()
		require("gemi.logger").show_logs()
	end, "Show Gemi logs")
	set_configured_keymap("n", keymaps.reload, M.force_reload_changed_files, "Force reload Gemi changed files")
	set_configured_keymap("n", keymaps.model, M.switch_model, "Switch Gemini model")
end

-- Setup function
function M.setup(opts)
	local config = get_config()
	config.setup(opts or {})
	local overlay = get_overlay()
	overlay.setup()
	if not M._state.initialized then
		local tracker = get_tracker()
		tracker.setup()
	end
	setup_keymaps()
	M._state.initialized = true
end

-- Show the overlay
function M.show()
	if not M._state.initialized then
		M.setup()
	end

	local overlay = get_overlay()
	overlay.show()
	M._state.ui_visible = true
end

-- Toggle the overlay
function M.toggle()
	if not M._state.initialized then
		M.setup()
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
	local conversation = require("gemi.conversation")

	-- Add user message to conversation history
	conversation.add_user_message(prompt)

	-- Build context prompt that includes conversation history
	local context_prompt = conversation.build_context_prompt(prompt)

	-- Create a snapshot before execution to capture the baseline
	tracker.create_snapshot("pre_execution")
	M._state.is_running = true
	M._state.current_job = executor.run_gemini(context_prompt, function(success, output)
		M._state.is_running = false
		M._state.current_job = nil
		if success then
			-- Add assistant response to conversation history
			conversation.add_assistant_response(output)
			-- Scan for changes after execution
			tracker.scan_for_changes()
		-- No success notification - let it happen silently
		else
			-- Check if this is a rate limit error and we should try fallback
			if M.is_rate_limit_error(output) and not M._state.using_fallback then
				M.handle_rate_limit_error(prompt, output)
			else
				vim.notify("Gemi failed: " .. (output or "Unknown error"), vim.log.levels.ERROR)
			end
		end
	end)
end

-- Handle rate limit errors with automatic model fallback
function M.handle_rate_limit_error(prompt, error_output)
	local current_model = M.get_current_model()
	local fallback_model = M.get_fallback_model(current_model)

	-- Log the fallback attempt
	local logger = require("gemi.logger")
	logger.info("Rate limit detected, attempting model fallback", {
		current_model = current_model,
		fallback_model = fallback_model,
		error_preview = error_output and tostring(error_output):sub(1, 100) or "No error details",
	})
	vim.notify(string.format("Rate limit hit for %s, trying %s...", current_model, fallback_model), vim.log.levels.WARN)

	-- Switch to fallback model
	local config = get_config()
	config.config.gemini.model = fallback_model

	-- Track that we're using fallback to avoid infinite loops
	M._state.using_fallback = true

	-- Retry with fallback model
	local executor = get_executor()
	local tracker = get_tracker()
	M._state.is_running = true
	M._state.current_job = executor.run_gemini(prompt, function(success, output)
		M._state.is_running = false
		M._state.current_job = nil
		M._state.using_fallback = false
		if success then
			-- Scan for changes after execution
			tracker.scan_for_changes()
			logger.info("Fallback model succeeded", { fallback_model = fallback_model })
			vim.notify(string.format("Successfully switched to %s model", fallback_model), vim.log.levels.INFO)
		else
			-- Both models failed
			if M.is_rate_limit_error(output) then
				logger.error("Both models hit rate limits", {
					original_model = current_model,
					fallback_model = fallback_model,
				})
				vim.notify(
					string.format(
						"Rate limit hit for both %s and %s models. Please wait and try again later.",
						current_model,
						fallback_model
					),
					vim.log.levels.ERROR
				)
			else
				logger.error("Fallback model failed", {
					fallback_model = fallback_model,
					error = output and tostring(output):sub(1, 100) or "No error details",
				})
				vim.notify(
					string.format("Fallback model %s also failed: %s", fallback_model, output or "Unknown error"),
					vim.log.levels.ERROR
				)
			end
			-- Restore original model
			config.config.gemini.model = current_model
			logger.debug("Restored original model", { model = current_model })
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

-- Switch between gemini models
function M.switch_model(model)
	if not M._state.initialized then
		M.setup()
	end
	local config = get_config()
	local valid_models = {
		"gemini-2.5-flash",
		"gemini-2.5-pro",
		"gemini-1.5-flash",
		"gemini-1.5-pro",
	}
	if model then
		-- Set specific model
		if vim.tbl_contains(valid_models, model) then
			config.config.gemini.model = model
			vim.notify(string.format("Switched to model: %s", model), vim.log.levels.INFO)
		else
			vim.notify(
				string.format("Invalid model: %s. Valid models: %s", model, table.concat(valid_models, ", ")),
				vim.log.levels.ERROR
			)
		end
	else
		-- Show model selection menu
		vim.ui.select(valid_models, {
			prompt = "Select Gemini model:",
			format_item = function(item)
				local current = config.get("gemini.model")
				if item == current then
					return item .. " (current)"
				end
				return item
			end,
		}, function(choice)
			if choice then
				config.config.gemini.model = choice
				vim.notify(string.format("Switched to model: %s", choice), vim.log.levels.INFO)
			end
		end)
	end
end

-- Get current model
function M.get_current_model()
	if not M._state.initialized then
		M.setup()
	end
	local config = get_config()
	return config.get("gemini.model")
end

-- Get fallback model for rate limit errors
function M.get_fallback_model(current_model)
	local fallback_pairs = {
		["gemini-2.5-flash"] = "gemini-2.5-pro",
		["gemini-2.5-pro"] = "gemini-2.5-flash",
		["gemini-1.5-flash"] = "gemini-1.5-pro",
		["gemini-1.5-pro"] = "gemini-1.5-flash",
	}
	return fallback_pairs[current_model] or "gemini-2.5-pro"
end

-- Check if error is a rate limit error (429)
function M.is_rate_limit_error(error_output)
	if not error_output then
		return false
	end
	local error_str = tostring(error_output):lower()
	return error_str:find("429")
		or error_str:find("rate limit")
		or error_str:find("quota")
		or error_str:find("too many requests")
end

-- Conversation management functions
function M.clear_conversation()
	local conversation = require("gemi.conversation")
	conversation.clear_history()
end

function M.toggle_conversation_context()
	local conversation = require("gemi.conversation")
	return conversation.toggle_context()
end

function M.get_conversation_history()
	local conversation = require("gemi.conversation")
	return conversation.get_history()
end

return M
