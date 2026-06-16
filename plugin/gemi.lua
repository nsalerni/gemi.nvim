if vim.g.loaded_gemi then
	return
end
vim.g.loaded_gemi = 1

require("gemi.commands").setup()
