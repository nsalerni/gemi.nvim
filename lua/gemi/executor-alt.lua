-- Alternative executor using asyncrun.vim for non-blocking execution
local M = {}
local config = require("gemi.config")
local logger = require("gemi.logger")
-- Check if asyncrun.vim is available

local function has_asyncrun()
  return vim.fn.exists(":AsyncRun") == 2
end
-- Execute gemini command with prompt using asyncrun.vim

function M.run_gemini_system(prompt, callback)
  if not prompt or prompt == "" then
    logger.error("No prompt provided")
    callback(false, "No prompt provided")
    return nil
  end

  logger.debug("Starting gemini execution", { prompt = prompt })
  -- Build command
  local cmd = "gemini --prompt " .. vim.fn.shellescape(prompt)
  local model = config.get("gemini.model")
  if model then
    cmd = cmd .. " --model " .. model
  end

  local debug = config.get("gemini.debug")
  if debug then
    cmd = cmd .. " --debug"
  end

  local all_files = config.get("gemini.all_files")
  if all_files then
    cmd = cmd .. " --all_files"
  end

  local yolo = config.get("gemini.yolo")
  if yolo then
    cmd = cmd .. " --yolo"
  end

  local checkpointing = config.get("gemini.checkpointing")
  if checkpointing then
    cmd = cmd .. " --checkpointing"
  end

  logger.debug("Executing command", { cmd = cmd })
  -- Start execution state
  local overlay = require("gemi.overlay")
  overlay.start_execution()
  if has_asyncrun() then
    -- Use asyncrun.vim for non-blocking execution
    logger.debug("Using asyncrun.vim for non-blocking execution")
    -- Create temporary output file
    local temp_file = vim.fn.tempname()
    local cmd_with_output = cmd .. " > " .. vim.fn.shellescape(temp_file) .. " 2>&1"
    -- Set up asyncrun autocmd to handle completion
    local group = vim.api.nvim_create_augroup("gemi_asyncrun", { clear = true })
    vim.api.nvim_create_autocmd("User", {
      pattern = "AsyncRunStop",
      group = group,
      callback = function()
        vim.schedule(function()
          -- Stop execution state
          overlay.stop_execution()
          -- Get the result from asyncrun
          local exit_code = vim.g.asyncrun_code or 0
          local output = ""
          -- Read output from temporary file
          local file = io.open(temp_file, "r")
          if file then
            output = file:read("*all") or ""
            file:close()
            -- Clean up temp file
            os.remove(temp_file)
          else
            -- Fallback: Get output from asyncrun quickfix buffer
            local qf_list = vim.fn.getqflist()
            if #qf_list > 0 then
              local output_lines = {}
              for _, item in ipairs(qf_list) do
                if item.text and item.text ~= "" then
                  table.insert(output_lines, item.text)
                end

              end

              output = table.concat(output_lines, "\n")
            end

          end

          local success = exit_code == 0
          if success then
            logger.debug("Command completed successfully")
            -- Log the full output separately to preserve formatting
            if output and output ~= "" then
              logger.log_output(output, false)
            end

            callback(true, output)
          else
            logger.error("Command failed", {
              exit_code = exit_code,
              command = cmd,
            })
            -- Log the full output separately to preserve formatting
            if output and output ~= "" then
              logger.log_output(output, true)
            end

            callback(false, output)
          end

          overlay.auto_refresh()
          -- Clean up autocmd
          vim.api.nvim_del_augroup_by_id(group)
        end)
      end,
      once = true,
    })
    -- Configure asyncrun to not auto-open quickfix
    vim.g.asyncrun_open = 0
    -- Run the command with asyncrun and redirect output to temp file
    vim.cmd("AsyncRun " .. cmd_with_output)
    logger.debug("Job started (asyncrun mode)", { temp_file = temp_file })
    return {
      job_id = "asyncrun",
      shutdown = function()
        logger.info("Stopping asyncrun job")
        vim.cmd("AsyncStop")
        overlay.stop_execution()
        overlay.auto_refresh()
        -- Clean up temp file on shutdown
        pcall(os.remove, temp_file)
      end,
    }
  else
    -- Fallback to jobstart for non-blocking execution
    logger.debug("asyncrun.vim not found, using jobstart fallback")
    local output_lines = {}
    local error_lines = {}
    local job = vim.fn.jobstart(cmd, {
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line and line ~= "" then
              table.insert(output_lines, line)
            end

          end

        end

      end,
      on_stderr = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line and line ~= "" then
              table.insert(error_lines, line)
            end

          end

        end

      end,
      on_exit = function(_, exit_code)
        vim.schedule(function()
          overlay.stop_execution()
          local success = exit_code == 0
          local output = table.concat(output_lines, "\n")
          local errors = table.concat(error_lines, "\n")
          if success then
            logger.debug("Command completed successfully")
            -- Log the full output separately to preserve formatting
            if output and output ~= "" then
              logger.log_output(output, false)
            end

            callback(true, output)
          else
            local error_msg = errors ~= "" and errors
              or "Command failed with exit code " .. exit_code
            logger.error("Command failed", {
              exit_code = exit_code,
              command = cmd,
            })
            -- Log the full output separately to preserve formatting
            if error_msg and error_msg ~= "" then
              logger.log_output(error_msg, true)
            end

            callback(false, error_msg)
          end

          overlay.auto_refresh()
        end)
      end,
      cwd = vim.fn.getcwd(),
      env = vim.fn.environ(),
    })
    if job <= 0 then
      logger.error("Failed to start gemini command")
      overlay.stop_execution()
      callback(false, "Failed to start gemini command")
      return nil
    end

    logger.debug("Job started (jobstart mode)", { job_id = job })
    return {
      job_id = job,
      shutdown = function()
        logger.info("Stopping jobstart job", { job_id = job })
        vim.fn.jobstop(job)
        overlay.stop_execution()
        overlay.auto_refresh()
      end,
    }
  end

end
return M
