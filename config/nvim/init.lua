require("config.lazy")

local vim = vim

-- Indentation
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

-- Désactiver l'autocomplétion SQL par défaut
vim.g.loaded_sql_completion = 1
vim.g.omni_sql_no_default_maps = 1

-- Apparence
vim.opt.pumblend = 0 -- Désactiver la transparence du popup
vim.opt.cursorline = true -- Surligner la ligne actuelle

-- Curseur
vim.cmd([[
  highlight Cursor guifg=NONE guibg=#E06C75
  highlight iCursor guifg=NONE guibg=#E06C75
  set guicursor=n-v-c:block-Cursor
  set guicursor+=i:ver25-iCursor
  colorscheme onedark
]])
--
-- Popup et fenêtres flottantes
local hl = vim.api.nvim_set_hl

hl(0, "Normal", { bg = "#282C34", fg = "#ABB2BF" }) -- Fond général
hl(0, "NormalFloat", { bg = "#282C34", fg = "#ABB2BF" }) -- Fond des fenêtres flottantes (comme Telescope)
hl(0, "FloatBorder", { bg = "#282C34", fg = "#61AFEF" }) -- Bordures bleues
hl(0, "Pmenu", { bg = "#21252B", fg = "#ABB2BF" }) -- Menu popup
hl(0, "CursorLine", { bg = "#2C323C" }) -- Ligne actuelle
hl(0, "LspInlayHint", { fg = "#5C6370", bg = "NONE", italic = true }) -- Inlay hints LSP
hl(0, "Visual", { bg = "#3E4452", fg = "NONE" })

-- LSP Handlers
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
	focusable = true,
	border = {
		{ "╭", "FloatBorder" },
		{ "─", "FloatBorder" },
		{ "╮", "FloatBorder" },
		{ "│", "FloatBorder" },
		{ "╯", "FloatBorder" },
		{ "─", "FloatBorder" },
		{ "╰", "FloatBorder" },
		{ "│", "FloatBorder" },
	},
})

vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
	border = {
		{ "╭", "FloatBorder" },
		{ "─", "FloatBorder" },
		{ "╮", "FloatBorder" },
		{ "│", "FloatBorder" },
		{ "╯", "FloatBorder" },
		{ "─", "FloatBorder" },
		{ "╰", "FloatBorder" },
		{ "│", "FloatBorder" },
	},
	relative = "cursor",
	row = 1,
	col = 0,
	style = "minimal",
	max_width = 80,
	max_height = 20,
})

-- Diagnostics
vim.diagnostic.config({
	virtual_text = false,
	signs = true,
	underline = true,
	update_in_insert = false,
	float = {
		source = "always",
		border = {
			{ "╭", "FloatBorder" },
			{ "─", "FloatBorder" },
			{ "╮", "FloatBorder" },
			{ "│", "FloatBorder" },
			{ "╯", "FloatBorder" },
			{ "─", "FloatBorder" },
			{ "╰", "FloatBorder" },
			{ "│", "FloatBorder" },
		},
		format = function(diagnostic)
			return string.format("%s [%s]", diagnostic.message, diagnostic.source)
		end,
	},
})
