local ts=  require("nvim-treesitter")

local ensure_installed = {
	"go","rust","typescript","javascript","tsx","html","css","json","bash","markdown","dockerfile","vue","scss",
}

ts.install(ensure_installed)

-- nvim-treesitter (branche main) n'active plus le highlight tout seul, et la
-- syntaxe Vim intégrée traite un .vue comme du simple HTML (pas de TS ni de
-- `{{ }}`) : on démarre treesitter explicitement pour les SFC.
vim.api.nvim_create_autocmd("FileType", {
	pattern = "vue",
	desc = "Start treesitter highlighting for Vue SFC",
	callback = function(args)
		pcall(vim.treesitter.start, args.buf)
	end,
})
