-- Test non-blocking execution
-- This file can be used to test the non-blocking implementation

local M = {}

-- Test function to simulate asyncrun.vim behavior
function M.test_asyncrun_detection()
	local executor = require("gemi.executor-alt")

	-- Mock asyncrun.vim availability
	vim.fn.exists = function(cmd)
		if cmd == ":AsyncRun" then
			return 2 -- Command exists
		end
		return 0
	end

	print("Testing asyncrun.vim detection...")

	-- Test with asyncrun available
	local success, result = pcall(function()
		return executor.run_gemini_system("test prompt", function(success, output)
			print("Callback called with success:", success)
			print("Output:", output)
		end)
	end)

	if success then
		print("✓ Non-blocking execution setup successful")
		print("Job type:", result.job_id)
	else
		print("✗ Error:", result)
	end
end

-- Test function to simulate no asyncrun.vim
function M.test_fallback_execution()
	local executor = require("gemi.executor-alt")

	-- Mock asyncrun.vim NOT available
	vim.fn.exists = function(cmd)
		return 0 -- Command doesn't exist
	end

	print("Testing fallback execution...")

	-- Test fallback to jobstart
	local success, result = pcall(function()
		return executor.run_gemini_system("test prompt", function(success, output)
			print("Fallback callback called with success:", success)
			print("Output:", output)
		end)
	end)

	if success then
		print("✓ Fallback execution setup successful")
		print("Job type:", result.job_id)
	else
		print("✗ Error:", result)
	end
end

-- Test overlay toggling during execution
function M.test_overlay_toggle()
	local overlay = require("gemi.overlay")

	print("Testing overlay toggle during execution...")

	-- Start execution state
	overlay.start_execution()
	print("✓ Execution started")

	-- Show overlay
	overlay.show()
	print("✓ Overlay shown")

	-- Hide overlay (should work during execution)
	overlay.hide()
	print("✓ Overlay hidden during execution")

	-- Show overlay again
	overlay.show()
	print("✓ Overlay shown again")

	-- Stop execution
	overlay.stop_execution()
	print("✓ Execution stopped")

	-- Hide overlay
	overlay.hide()
	print("✓ Test completed")
end

return M

