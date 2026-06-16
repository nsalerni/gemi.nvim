-- Gemini CLI execution and process management.
local M = {}

local config = require("gemi.config")
local logger = require("gemi.logger")

local function clean_gemini_output(output)
	output = output or ""
	output = output:gsub("^Loaded cached credentials%.\n", "")
	output = output:gsub("^Loaded cached credentials%.", "")
	output = output:gsub("\nLoaded cached credentials%.\n", "\n")
	output = output:gsub("\nLoaded cached credentials%.", "")
	return output
end

local function is_auth_error(output)
	if not output then
		return false
	end

	local output_lower = output:lower()
	return output_lower:find("authentication", 1, true) ~= nil
		or output_lower:find("auth", 1, true) ~= nil
		or output_lower:find("login", 1, true) ~= nil
		or output_lower:find("credential", 1, true) ~= nil
		or output_lower:find("unauthenticated", 1, true) ~= nil
		or output_lower:find("permission denied", 1, true) ~= nil
end

local function overlay_call(method)
	local ok, overlay = pcall(require, "gemi.overlay")
	if ok and overlay[method] then
		overlay[method]()
	end
end

function M._build_command(prompt)
	local cmd = { "gemini", "--prompt", prompt }

	local model = config.get("gemini.model")
	if model then
		table.insert(cmd, "--model")
		table.insert(cmd, model)
	end

	if config.get("gemini.debug") then
		table.insert(cmd, "--debug")
	end

	if config.get("gemini.all_files") then
		table.insert(cmd, "--all_files")
	end

	if config.get("gemini.yolo") then
		table.insert(cmd, "--yolo")
	end

	if config.get("gemini.checkpointing") then
		table.insert(cmd, "--checkpointing")
	end

	return cmd
end

function M.run_gemini(prompt, callback)
	if not prompt or prompt == "" then
		logger.error("No prompt provided")
		callback(false, "No prompt provided")
		return nil
	end

	if vim.fn.executable("gemini") ~= 1 then
		local message = "gemini executable not found. Run :GemiInstall or install @google/gemini-cli."
		logger.error(message)
		callback(false, message)
		return nil
	end

	local cmd = M._build_command(prompt)
	local cwd = vim.fn.getcwd()
	local output_lines = {}
	local error_lines = {}

	logger.debug("Starting gemini execution", {
		cwd = cwd,
		model = config.get("gemini.model"),
		prompt_preview = prompt:sub(1, 120),
	})
	overlay_call("start_execution")

	local job = vim.fn.jobstart(cmd, {
		cwd = cwd,
		env = vim.fn.environ(),
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					table.insert(output_lines, line)
				end
			end
		end,
		on_stderr = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					table.insert(error_lines, line)
				end
			end
		end,
		on_exit = function(_, exit_code)
			vim.schedule(function()
				overlay_call("stop_execution")

				local output = clean_gemini_output(table.concat(output_lines, "\n"))
				local errors = clean_gemini_output(table.concat(error_lines, "\n"))
				local success = exit_code == 0

				if success then
					logger.debug("Gemini command completed successfully", {
						output_bytes = #output,
					})
					if output ~= "" then
						logger.log_output(output, false)
					end
					callback(true, output)
					overlay_call("auto_refresh")
					return
				end

				local error_message = errors ~= "" and errors or output
				if error_message == "" then
					error_message = "Command failed with exit code " .. exit_code
				end

				logger.error("Gemini command failed", {
					exit_code = exit_code,
					error_preview = error_message:sub(1, 120),
				})
				logger.log_output(error_message, true)

				if is_auth_error(error_message) then
					error_message =
						"Authentication required. Run 'gemini' in your terminal to authenticate, then try again."
				end

				callback(false, error_message)
				overlay_call("auto_refresh")
			end)
		end,
	})

	if job <= 0 then
		overlay_call("stop_execution")
		local message = "Failed to start gemini command"
		logger.error(message)
		callback(false, message)
		return nil
	end

	logger.debug("Gemini job started", { job_id = job })
	return {
		job_id = job,
		shutdown = function()
			logger.info("Stopping gemini job", { job_id = job })
			vim.fn.jobstop(job)
			overlay_call("stop_execution")
			overlay_call("auto_refresh")
		end,
	}
end

return M
