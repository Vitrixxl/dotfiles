require("config.lazy")

local vim = vim

vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.g.loaded_sql_completion = 1
vim.g.omni_sql_no_default_maps = 1

vim.opt.cursorline = true
vim.opt.termguicolors = true

vim.cmd("highlight Normal guibg=NONE ctermbg=NONE")
