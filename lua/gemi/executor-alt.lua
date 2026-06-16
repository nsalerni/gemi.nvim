-- Backward-compatible wrapper for the old alternate executor module.
local M = {}

function M.run_gemini_system(prompt, callback)
	return require("gemi.executor").run_gemini(prompt, callback)
end

return M
