-- plugin/gemi.lua
-- Main plugin entry point
if vim.g.loaded_gemi then
  return
end
vim.g.loaded_gemi = 1
-- Create user commands
vim.api.nvim_create_user_command("GemiToggle", function()
  require("gemi").toggle()
end, { desc = "Toggle Gemi prompt interface" })
vim.api.nvim_create_user_command("GemiInstall", function()
  require("gemi").install_cli()
end, { desc = "Install gemini-cli and dependencies" })
vim.api.nvim_create_user_command("GemiFiles", function()
  require("gemi").show_changed_files()
end, { desc = "Show files changed by Gemi" })
vim.api.nvim_create_user_command("GemiDiff", function()
  require("gemi").show_diff()
end, { desc = "Show diff of changes made by Gemi" })
vim.api.nvim_create_user_command("GemiLogs", function()
  require("gemi.logger").show_logs()
end, { desc = "Show Gemi execution logs" })
vim.api.nvim_create_user_command("GemiClearLogs", function()
  require("gemi.logger").clear_logs()
end, { desc = "Clear Gemi logs" })
vim.api.nvim_create_user_command("GemiReload", function()
  require("gemi").force_reload_changed_files()
end, { desc = "Force reload all files changed by Gemi" })
vim.api.nvim_create_user_command("GemiDebug", function()
  require("gemi").debug_changes()
end, { desc = "Debug Gemi change detection" })
vim.api.nvim_create_user_command("GemiModel", function(opts)
  if opts.args and opts.args ~= "" then
    require("gemi").switch_model(opts.args)
  else
    require("gemi").switch_model()
  end
end, {
  desc = "Switch Gemini model",
  nargs = "?",
  complete = function()
    return { "gemini-2.5-flash", "gemini-2.5-pro", "gemini-1.5-flash", "gemini-1.5-pro" }
  end,
})
vim.api.nvim_create_user_command("GemiCurrentModel", function()
  local model = require("gemi").get_current_model()
  vim.notify(string.format("Current model: %s", model), vim.log.levels.INFO)
end, { desc = "Show current Gemini model" })
-- Default keymaps (can be overridden by user)
vim.keymap.set("n", "<C-g>", function()
  require("gemi").toggle()
end, { desc = "Toggle Gemi overlay" })
vim.keymap.set("i", "<C-g>", function()
  require("gemi").toggle()
end, { desc = "Toggle Gemi overlay" })
vim.keymap.set("n", "<leader>gf", function()
  require("gemi").show_changed_files()
end, { desc = "Show Gemi changed files" })
vim.keymap.set("n", "<leader>gd", function()
  require("gemi").show_diff()
end, { desc = "Show Gemi diff" })
vim.keymap.set("n", "<leader>gs", function()
  require("gemi").stop()
end, { desc = "Stop Gemi execution" })
vim.keymap.set("n", "<leader>gi", function()
  require("gemi").install_cli()
end, { desc = "Install Gemi CLI" })
vim.keymap.set("n", "<leader>gl", function()
  require("gemi.logger").show_logs()
end, { desc = "Show Gemi logs" })
vim.keymap.set("n", "<leader>gr", function()
  require("gemi").force_reload_changed_files()
end, { desc = "Force reload Gemi changed files" })
vim.keymap.set("n", "<leader>gm", function()
  require("gemi").switch_model()
end, { desc = "Switch Gemini model" })
