return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig",
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"ts_ls",
					"tailwindcss",
					"cssls",
					"rust_analyzer",
					"gopls",
					"zls",
					"pyright",
				},
				automatic_installation = true,
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = { "saghen/blink.cmp" },
		opts = {
			servers = {
				clangd = {},
				pyright = {},
				cssls = {},
				zls = {},
				lua_ls = {},
				ts_ls = {},
				tailwindcss = {},
				rust_analyzer = {},
				gopls = {},
				prismals = {},
			},
		},
		config = function(_, opts)
			local lspconfig = require("lspconfig")
			local capabilities = require("blink.cmp").get_lsp_capabilities()
			for server, config in pairs(opts.servers) do
				-- config.capabilities = require("blink.cmp").get_lsp_capabilities(config.capabilities)
				lspconfig[server].setup({ capabilities = capabilities }) -- Pass the config table here
			end

			vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation LSP" })
			vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action LSP" })
			vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Go to Definition LSP" })
			vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, { desc = "Go to References LSP" })
			vim.keymap.set("n", "gl", "<cmd>lua vim.diagnostic.open_float()<CR>")
			vim.keymap.set("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>")
			vim.keymap.set("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>")
			vim.keymap.set("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>")
		end,
	},
}
