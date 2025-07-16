-- lua/gemi/executor.lua
-- Gemini CLI execution and process management
local M = {}
local config = require("gemi.config")
local logger = require("gemi.logger")

-- Execute gemini command with prompt
function M.run_gemini(prompt, callback)
	-- Try alternative executor first
	local alt_executor = require("gemi.executor-alt")
	return alt_executor.run_gemini_system(prompt, callback)
end

-- Original jobstart implementation (for reference)
function M.run_gemini_jobstart(prompt, callback)
	if not prompt or prompt == "" then
		logger.error("No prompt provided")
		callback(false, "No prompt provided")
		return nil
	end
	logger.info("Starting gemini execution", { prompt = prompt })

	-- Escape the prompt for shell execution
	local escaped_prompt = vim.fn.shellescape(prompt)

	-- Build gemini command
	local cmd = { "gemini", "--prompt", escaped_prompt }

	-- Add model configuration if specified
	local model = config.get("gemini.model")
	if model then
		table.insert(cmd, "--model")
		table.insert(cmd, model)
	end

	-- Add debug flag if needed
	local debug = config.get("gemini.debug")
	if debug then
		table.insert(cmd, "--debug")
	end

	-- Add all_files flag if needed
	local all_files = config.get("gemini.all_files")
	if all_files then
		table.insert(cmd, "--all_files")
	end

	-- Add YOLO mode for automatic action acceptance
	local yolo = config.get("gemini.yolo")
	if yolo then
		table.insert(cmd, "--yolo")
	end

	-- Add checkpointing for file edits
	local checkpointing = config.get("gemini.checkpointing")
	if checkpointing then
		table.insert(cmd, "--checkpointing")
	end
	local cwd = vim.fn.getcwd()
	logger.log_command(cmd, cwd)

	-- Debug: print the exact command that will be executed
	local cmd_str = table.concat(cmd, " ")
	print("DEBUG: Executing command: " .. cmd_str)
	vim.notify("Executing: " .. cmd_str, vim.log.levels.INFO)
	local output_lines = {}
	local error_lines = {}

	-- Start the job with better output handling
	local job = vim.fn.jobstart(cmd, {
		on_stdout = function(job_id, data, event)
			logger.debug("STDOUT callback triggered", {
				job_id = job_id,
				event = event,
				data_count = data and #data or 0,
				data = data,
			})
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						table.insert(output_lines, line)
						logger.debug("STDOUT line", { line = line })
						-- Update UI with real-time output if visible
						local ui = require("gemi.ui")
						if ui.is_visible() then
							local preview = line:sub(1, 50) .. (line:len() > 50 and "..." or "")
							ui.update_status("Running... " .. preview)
						end
						-- Show output in real-time
						vim.notify("Gemi: " .. line, vim.log.levels.INFO)
					end
				end
			end
		end,
		on_stderr = function(job_id, data, event)
			logger.debug("STDERR callback triggered", {
				job_id = job_id,
				event = event,
				data_count = data and #data or 0,
				data = data,
			})
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						table.insert(error_lines, line)
						logger.debug("STDERR line", { line = line })
						-- Show errors in real-time
						vim.notify("Gemi Error: " .. line, vim.log.levels.WARN)
					end
				end
			end
		end,
		on_exit = function(job_id, exit_code, event)
			logger.info("Job exit callback triggered", {
				job_id = job_id,
				exit_code = exit_code,
				event = event,
				output_lines_count = #output_lines,
				error_lines_count = #error_lines,
			})
			local success = exit_code == 0
			local output = table.concat(output_lines, "\n")
			local errors = table.concat(error_lines, "\n")
			logger.info("Command completed", {
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
					vim.notify("Gemi completed successfully! Check :GemiLogs for details", vim.log.levels.INFO)
				else
					logger.warn("Gemi completed but produced no output")
					vim.notify("Gemi completed but produced no output", vim.log.levels.WARN)
				end
				callback(true, output)
			else
				local error_msg = errors ~= "" and errors or "Command failed with exit code " .. exit_code
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
		logger.error("Failed to start gemini command")
		callback(false, "Failed to start gemini command")
		return nil
	end
	logger.info("Job started", { job_id = job })
	return {
		job_id = job,
		shutdown = function()
			logger.info("Stopping job", { job_id = job })
			vim.fn.jobstop(job)
		end,
	}
end
return M
