vim.g.mapleader = " "

vim.keymap.set("n", "<leader>o", "o<Esc>")
vim.keymap.set("n", "<leader>O", "O<Esc>")
vim.keymap.set("n", "<leader>pv", ":Ex<CR>")

--Reset search
vim.keymap.set("n", "<leader>st", ":noh<CR>")

--Change around
vim.keymap.set("n", "<leader>gf", "<cmd>lua vim.lsp.buf.format()<CR>", {})
