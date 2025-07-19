-- Test job execution to debug the issue
local function test_job()
	print("Testing job execution...")

	local output_lines = {}
	local error_lines = {}

	-- Test with a simple echo command first
	local job = vim.fn.jobstart('echo "Hello from job"', {
		on_stdout = function(job_id, data, event)
			print("STDOUT callback:", vim.inspect(data))
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						table.insert(output_lines, line)
						print("STDOUT line:", line)
					end
				end
			end
		end,

		on_stderr = function(job_id, data, event)
			print("STDERR callback:", vim.inspect(data))
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						table.insert(error_lines, line)
						print("STDERR line:", line)
					end
				end
			end
		end,

		on_exit = function(job_id, exit_code, event)
			print("Exit callback - code:", exit_code, "output:", table.concat(output_lines, "\n"))
		end,
	})

	print("Job started:", job)
	return job
end

-- Test the job
test_job()

-- Now test with gemini
vim.defer_fn(function()
	print("\nTesting gemini command...")

	local output_lines2 = {}
	local error_lines2 = {}

	local job2 = vim.fn.jobstart('gemini --prompt "Hello" --model gemini-2.5-pro --yolo --checkpointing', {
		on_stdout = function(job_id, data, event)
			print("GEMINI STDOUT:", vim.inspect(data))
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						table.insert(output_lines2, line)
						print("GEMINI STDOUT line:", line)
					end
				end
			end
		end,

		on_stderr = function(job_id, data, event)
			print("GEMINI STDERR:", vim.inspect(data))
			if data then
				for _, line in ipairs(data) do
					if line and line ~= "" then
						table.insert(error_lines2, line)
						print("GEMINI STDERR line:", line)
					end
				end
			end
		end,

		on_exit = function(job_id, exit_code, event)
			print("GEMINI Exit - code:", exit_code, "output lines:", #output_lines2, "error lines:", #error_lines2)
			print("GEMINI Output:", table.concat(output_lines2, "\n"))
			print("GEMINI Errors:", table.concat(error_lines2, "\n"))
		end,
	})

	print("Gemini job started:", job2)
end, 2000)

