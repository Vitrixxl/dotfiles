return {
	"nvim-flutter/flutter-tools.nvim",
	lazy = false,
	dependencies = {
		"nvim-lua/plenary.nvim",
		"stevearc/dressing.nvim", -- optional for vim.ui.select
	},
	config = function()
		require("flutter-tools").setup({
			flutter_path = "~/.flutter/flutter/bin/flutter",
			dart_sdk_path = "~/.flutter/flutter/bin/cache/dart-sdk",
			lsp = {
				cmd = { "/home/vitrix/.flutter/flutter/bin/dart", "language-server", "--protocol=lsp" },
			},
			-- autres configurations
		})
	end,
}
