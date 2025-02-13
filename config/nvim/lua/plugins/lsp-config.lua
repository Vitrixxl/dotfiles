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
					"htmx",
					"zls",
					"pyright",
				},
				automatic_installation = true,
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		-- dependencies = {
		-- 	"ms-jpq/coq_nvim",
		-- },
		config = function()
			local lspconfig = require("lspconfig")
			local servers = {
				"clangd",
				"pyright",
				"htmx",
				"cssls",
				"zls",
				"lua_ls",
				"tailwindcss",
				"rust_analyzer",
				"gopls",
				"prismals",
			}

			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			for _, server in ipairs(servers) do
				lspconfig[server].setup({
					capabilities = capabilities,
				})
			end

			-- Configuration spéciale pour tsserver
			lspconfig.ts_ls.setup({
				capabilities = capabilities,
				on_attach = on_attach,
				init_options = {
					preferences = {
						includeCompletionsForModuleExports = true,
						includeCompletionsWithObjectLiteralMethodSnippets = true,
						importModuleSpecifierPreference = "non-relative",
					},
				},
			})

			vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation LSP" })
			vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action LSP" })
			vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Go to Definition LSP" })
			vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, { desc = "Go to References LSP" })
			vim.keymap.set("n", "gl", "<cmd>lua vim.diagnostic.open_float()<CR>")
			vim.keymap.set("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
			vim.keymap.set("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
			vim.keymap.set("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
		end,
	},
}
