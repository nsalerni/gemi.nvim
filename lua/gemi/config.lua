-- lua/gemi/config.lua
-- Configuration management for Gemi plugin
local M = {}
-- Default configuration
M.defaults = {
	-- UI settings
	ui = {
		width = 0.8, -- Overlay width as a fraction of screen width
		height = 0.8, -- Overlay height as a fraction of screen height
		position = "center", -- Overlay position: "center", "bottom", or "top"
		border = "rounded",
		title = " Gemi ",
		prompt = "> ", -- Prompt prefix shown in the overlay input
	},
	-- Conversation context
	conversation = {
		max_history_length = 20,
	},
	-- Keymaps
	keymaps = {
		toggle = "<leader>g",
		files = "<leader>gf",
		diff = "<leader>gd",
		stop = "<leader>gs",
		install = "<leader>gi",
		logs = "<leader>gl",
		reload = "<leader>gr",
		model = "<leader>gm",
	},
	-- gemini-cli settings
	gemini = {
		model = "gemini-2.5-flash", -- Default model with better rate limits
		debug = false, -- Enable debug mode
		all_files = false, -- Include all files in context
		yolo = true, -- Automatically accept all actions
		checkpointing = true, -- Enable checkpointing of file edits
	},
	-- File tracking
	tracking = {
		auto_scan = true,
		max_files = 2000,
		max_file_size = 1024 * 1024,
		store_snapshot_content = false,
		exclude_patterns = {
			"%.git/",
			"node_modules/",
			"%.DS_Store",
			"%.log$",
		},
	},
	-- Installation
	install = {
		check_node = true,
		node_min_version = "16.0.0",
		auto_install = false,
	},
	-- Logging
	logging = {
		debug = false, -- Enable verbose debug logging
		level = "INFO", -- Log level: DEBUG, INFO, WARN, ERROR
		max_entries = 500,
	},
}

-- Current configuration
M.config = {}

-- Setup function
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

-- Get configuration value
function M.get(key)
	local keys = vim.split(key, ".", { plain = true })
	local value = M.config
	for _, k in ipairs(keys) do
		if value[k] == nil then
			return nil
		end
		value = value[k]
	end
	return value
end
return M
