vim.pack.add({
	"https://github.com/bluz71/vim-moonfly-colors",
	"https://github.com/nvim-mini/mini.nvim",
	"https://github.com/rafamadriz/friendly-snippets",
	{ src = "https://github.com/nvim-treesitter/nvim-treesitter", branch = "main" },
	"https://github.com/neovim/nvim-lspconfig",
	"https://github.com/tpope/vim-fugitive",
})

local MiniNotify = require("mini.notify")
require("mini.notify").setup({
	content = {
		format = function(notif)
			return notif.msg
		end,
	}
})

require("mini.cmdline").setup({
	autocorrect = { enable = false }
})

require("mini.surround").setup()

require("mini.pairs").setup()

local MiniPick = require("mini.pick")

MiniPick.setup()

vim.keymap.set("n", "<leader>pf", function() MiniPick.builtin.files() end, { desc = "Mini File Picker" })
vim.keymap.set("n", "<C-p>", function() MiniPick.builtin.grep_live() end, { desc = "Mini Text Search" })

local MiniCompletion = require("mini.completion")
MiniCompletion.setup({
	lsp_completion = {
		auto_setup = true,
		process_items = function(items, base)
			return MiniCompletion.default_process_items(items, base, {
				filtersort = "fuzzy",
			})
		end,
	}
})

-- local MiniSnippets = require("mini.snippets")
-- MiniSnippets.setup({
-- 	snippets = {
-- 		MiniSnippets.gen_loader.from_lang(),
-- 	},
-- 	expand = {
-- 		insert = function (snippet)
-- 			MiniSnippets.default_insert(snippet,{empty_tabstop=""})
-- 		end,
-- 	}
--
-- })
--
-- MiniSnippets.start_lsp_server({match=false})

-- <CR> valide l'entrée surlignée du popup, sinon saut de ligne normal.
-- Avec 'noinsert' dans completeopt, la 1re entrée est toujours présélectionnée,
-- donc pas besoin de <C-n> ni de <C-y>. Pour un vrai saut de ligne malgré le
-- popup : <C-e> (ferme le popup) puis <CR>.
local cr, ctrl_y = vim.keycode("<CR>"), vim.keycode("<C-y>")
vim.keymap.set("i", "<CR>", function()
	if vim.fn.pumvisible() == 0 then return cr end
	return vim.fn.complete_info({ "selected" }).selected ~= -1 and ctrl_y or cr
end, { expr = true, desc = "Valider la complétion ou nouvelle ligne" })
