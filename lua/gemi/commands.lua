-- User command registration for gemi.nvim.
local M = {}

local function create_command(name, callback, opts)
	opts = vim.tbl_extend("force", { force = true }, opts or {})
	vim.api.nvim_create_user_command(name, callback, opts)
end

function M.setup()
	create_command("Gemi", function()
		require("gemi").show()
	end, { desc = "Open Gemi prompt interface" })

	create_command("GemiToggle", function()
		require("gemi").toggle()
	end, { desc = "Toggle Gemi prompt interface" })

	create_command("GemiStop", function()
		require("gemi").stop()
	end, { desc = "Stop Gemi execution" })

	create_command("GemiInstall", function()
		require("gemi").install_cli()
	end, { desc = "Install gemini-cli and dependencies" })

	create_command("GemiFiles", function()
		require("gemi").show_changed_files()
	end, { desc = "Show files changed by Gemi" })

	create_command("GemiShowChangedFiles", function()
		require("gemi").show_changed_files()
	end, { desc = "Show files changed by Gemi" })

	create_command("GemiDiff", function(opts)
		local file = opts.args ~= "" and opts.args or nil
		require("gemi").show_diff(file)
	end, {
		desc = "Show diff of changes made by Gemi",
		nargs = "?",
		complete = "file",
	})

	create_command("GemiShowDiff", function(opts)
		local file = opts.args ~= "" and opts.args or nil
		require("gemi").show_diff(file)
	end, {
		desc = "Show diff of changes made by Gemi",
		nargs = "?",
		complete = "file",
	})

	create_command("GemiLogs", function()
		require("gemi.logger").show_logs()
	end, { desc = "Show Gemi execution logs" })

	create_command("GemiClearLogs", function()
		require("gemi.logger").clear_logs()
	end, { desc = "Clear Gemi logs" })

	create_command("GemiReload", function()
		require("gemi").force_reload_changed_files()
	end, { desc = "Force reload all files changed by Gemi" })

	create_command("GemiDebug", function()
		require("gemi").debug_changes()
	end, { desc = "Debug Gemi change detection" })

	create_command("GemiModel", function(opts)
		local model = opts.args ~= "" and opts.args or nil
		require("gemi").switch_model(model)
	end, {
		desc = "Switch Gemini model",
		nargs = "?",
		complete = function()
			return { "gemini-2.5-flash", "gemini-2.5-pro", "gemini-1.5-flash", "gemini-1.5-pro" }
		end,
	})

	create_command("GemiCurrentModel", function()
		local model = require("gemi").get_current_model()
		vim.notify(string.format("Current model: %s", model), vim.log.levels.INFO)
	end, { desc = "Show current Gemini model" })

	create_command("GemiClearConversation", function()
		require("gemi").clear_conversation()
	end, { desc = "Clear Gemi conversation history" })

	create_command("GemiToggleContext", function()
		require("gemi").toggle_conversation_context()
	end, { desc = "Toggle Gemi conversation context" })
end

return M
