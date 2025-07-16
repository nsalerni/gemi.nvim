-- Simple test version to verify plugin loading
if vim.g.loaded_gemi_simple then
	return
end
vim.g.loaded_gemi_simple = 1
-- Create a simple test command
vim.api.nvim_create_user_command("GemiTest", function()
	print("Gemi plugin is working!")
end, { desc = "Test Gemi plugin" })
-- Create a simple test keymap
vim.keymap.set("n", "<leader>gt", function()
	print("Gemi test keymap works!")
end, { desc = "Test Gemi keymap" })
