return {
    "stevearc/conform.nvim",

    config = function()
        require("conform").setup({

            formatters = {
                deno = {
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

                go = {
                    command = "gofmt",
                },
                dart = {
                    command = "dart",
                    args = { "format" },
                },
            },
            formatters_by_ft = {
                lua = { "stylua" },
                css = { "prettierd" },
                html = { "prettierd" },
                javascript = { "deno" },
                typescript = { "deno" },
                json = { "prettierd" },
                jsonc = { "prettierd" },
                javascriptreact = { "biome" },
                typescriptreact = { "biome" },
                -- markdown = { "deno_fmt" },
                zig = { "zig" },
                prisma = { "prettierd" },
                python = { "black" },
                go = { "gofmt" },
                rust = { "rustfmt" },
                dart = { "dart" },
                c = { "clang-format" },
            },
            format_on_save = {
                enabled = true,
                timeout_ms = 2000,
                lsp_fallback = false,
            },
        })
    end,
}
