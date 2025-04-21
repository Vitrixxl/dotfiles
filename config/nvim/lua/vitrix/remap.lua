vim.g.mapleader = " "

vim.keymap.set("n", "<leader>o", "o<Esc>")
vim.keymap.set("n", "<leader>O", "O<Esc>")
vim.keymap.set("n", "<leader>pv", ":Ex<CR>")

--Reset search
vim.keymap.set("n", "<leader>st", ":noh<CR>")

--Change around
vim.keymap.set("n", "<leader>gf", "<cmd>lua vim.lsp.buf.format()<CR>", {})

-- local function start_tsgo()
-- 	local root_files = { "tsconfig.json", "jsconfig.json", "package.json", ".git" }
-- 	local paths = vim.fs.find(root_files, { stop = vim.env.HOME })
-- 	local root_dir = vim.fs.dirname(paths[1])
--
-- 	if root_dir == nil then
-- 		-- root directory was not found
-- 		return
-- 	end
--
-- 	vim.lsp.start({
-- 		name = "tsgo",
-- 		cmd = { "/home/vitrix/code/typescript-go/built/local/tsgo", "lsp", "--stdio" },
-- 		root_dir = root_dir,
-- 		-- init_options = { hostInfo = "neovim" }, -- not implemented yet
-- 	})
-- end
--
-- vim.api.nvim_create_autocmd("FileType", {
-- 	pattern = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
-- 	desc = "Start tsgo LSP",
-- 	callback = start_tsgo,
-- :
-- })
