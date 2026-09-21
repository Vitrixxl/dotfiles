vim.g.mapleader=" "

vim.keymap.set("x","p",[["_dP]],{})
vim.keymap.set({"n","v"}, "<leader>d",[["_d]],{})
vim.keymap.set("i","<C-c>","<Esc>")
vim.keymap.set("n","<C-c>",":nohl<CR>",{desc = "Clear search highlighting", silent=true})
vim.keymap.set("v","<","<gv",{})
vim.keymap.set("v",">",">gv",{})

vim.keymap.set("n","J","mzJ`z",{})
vim.keymap.set("n","<leader>pv",":Ex<CR>",{})

vim.keymap.set("n", "gl", vim.diagnostic.open_float, {
  desc = "Open diagnostic",
})

vim.keymap.set("n","<C-h>","<C-w>h",{desc = "Go to left window"})
vim.keymap.set("n","<C-j>","<C-w>j",{desc = "Go to lower window"})
vim.keymap.set("n","<C-k>","<C-w>k",{desc = "Go to upper window"})
vim.keymap.set("n","<C-l>","<C-w>l",{desc = "Go to right window"})

-- netrw mappe <C-l> sur son refresh en local au buffer : on le remet sur la
-- navigation entre fenêtres (:e ou R rafraîchissent la liste au besoin).
vim.api.nvim_create_autocmd("FileType", {
	pattern = "netrw",
	desc = "Restore <C-l> window navigation in netrw",
	callback = function(args)
		vim.keymap.set("n", "<C-l>", "<C-w>l", { buffer = args.buf, desc = "Go to right window" })
	end,
})
