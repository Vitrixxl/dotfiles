require("config.lazy")

local vim = vim

vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
-- vim.lsp.start_client({
--     name = 'dartls',            -- Nom du serveur
--     -- cmd = { '~/development/flutter/bin/dart', 'language-server', '--protocol=lsp' }, -- Commande pour démarrer le serveur
--     root_dir = vim.fn.getcwd(), -- Utiliser le répertoire actuel comme racine
--     capabilities = vim.lsp.protocol.make_client_capabilities(),
-- })
vim.g.loaded_sql_completion = 1
vim.g.omni_sql_no_default_maps = 1

-- Configuration des popups dans Neovim
vim.api.nvim_set_hl(0, "NormalFloat", {
	bg = "#1e1e2e", -- Couleur de fond plus sombre
	fg = "#bac2de", -- Couleur du texte plus claire
})

vim.api.nvim_set_hl(0, "FloatBorder", {
	bg = "#1e1e2e",
	fg = "#89b4fa", -- Bordure bleue
})
vim.api.nvim_set_hl(0, "ErrorBorder", {
	bg = "#1e1e2e",
	fg = "#f38ba8",
})

-- Configuration globale des fenêtres flottantes
vim.opt.pumblend = 0 -- Transparence du popup (0-100)

-- Configuration des bordures et du style pour les popups LSP
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

-- Configuration du positionnement du popup
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

vim.diagnostic.config({
	float = {
		border = {
			{ "╭" },
			{ "─" },
			{ "╮" },
			{ "│" },
			{ "╯" },
			{ "─" },
			{ "╰" },
			{ "│" },
		},
		focusable = true,
		style = "minimal",
	},
})
vim.diagnostic.config({
	virtual_text = false, -- Désactiver le texte virtuel si encombrant
	signs = true, -- Afficher les icônes à gauche des lignes
	underline = true, -- Souligner les lignes avec des diagnostics
	update_in_insert = false, -- Évite les diagnostics pendant l'insertion
	float = {
		source = "always", -- Ajoute la source à chaque diagnostic
		border = {
			{ "╭", "ErrorBorder" },
			{ "─", "ErrorBorder" },
			{ "╮", "ErrorBorder" },
			{ "│", "ErrorBorder" },
			{ "╯", "ErrorBorder" },
			{ "─", "ErrorBorder" },
			{ "╰", "ErrorBorder" },
			{ "│", "ErrorBorder" },
		},
		format = function(diagnostic)
			return string.format("%s [%s]", diagnostic.message, diagnostic.source)
		end,
	},
})

vim.cmd([[
  highlight Cursor guifg=NONE guibg=#eb6f92
  highlight iCursor guifg=NONE guibg=#eb6f92
  set guicursor=n-v-c:block-Cursor
  set guicursor+=i:ver25-iCursor
  highlight Pmenu guifg=#ffffff guibg=#000000
]])
vim.cmd("colorscheme terafox")
vim.g.lightline = { colorscheme = "terafox" }
vim.cmd([[
  highlight LspInlayHint guifg=#666666 guibg=NONE gui=italic
]])
