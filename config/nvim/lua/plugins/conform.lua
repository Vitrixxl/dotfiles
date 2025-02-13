return {
	"stevearc/conform.nvim",

	config = function()
		require("conform").setup({
			formatters = {
				deno_fmt = {
					command = "deno",
					args = { "fmt", "--indent-width=2", "--single-quote=true", "-" },
					stdin = true,
				},
				zig = {

					command = "zig",
					args = { "fmt", "--stdin" },
					stdin = true,
				},
				stylua = {
					command = "stylua",
				},
				black = {
					command = "black",
				},
			},
			formatters_by_ft = {
				lua = { "stylua" },
				css = { "prettierd" },
				html = { "deno_fmt" },
				javascript = { "deno_fmt" },
				typescript = { "deno_fmt" },
				json = { "prettierd" },
				jsonc = { "prettierd" },
				javascriptreact = { "deno_fmt" },
				typescriptreact = { "deno_fmt" },
				-- markdown = { "deno_fmt" },
				zig = { "zig" },
				prisma = { "prettierd" },
				python = { "black" },
			},
			format_on_save = {
				enabled = true,
				timeout_ms = 2000,
				lsp_fallback = false,
			},
		})
	end,
}
