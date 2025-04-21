return {
    {
        "williamboman/mason.nvim",
        config = function() require("mason").setup() end,
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
                -- dcm = {},
                -- tsgo = {},
            },
        },
        config = function(_, opts)
            local lspconfig = require("lspconfig")
            local capabilities = require("blink.cmp").get_lsp_capabilities()

            for server, config in pairs(opts.servers) do
                config.capabilities = capabilities
                lspconfig[server].setup(config)
            end

            -- Handlers LSP avec bordures
            vim.lsp.handlers["textDocument/hover"] =
                vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })

            vim.lsp.handlers["textDocument/signatureHelp"] =
                vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

            vim.diagnostic.config({
                float = { border = "rounded" },
            })

            -- Keymaps
            vim.keymap.set(
                "n",
                "K",
                function() vim.lsp.buf.hover({ border = "rounded" }) end,
                { desc = "Hover documentation LSP" }
            )
            vim.keymap.set(
                "n",
                "<leader>ca",
                vim.lsp.buf.code_action,
                { desc = "Code Action LSP" }
            )
            vim.keymap.set(
                "n",
                "gd",
                vim.lsp.buf.definition,
                { desc = "Go to Definition LSP" }
            )
            vim.keymap.set(
                "n",
                "<leader>gr",
                vim.lsp.buf.references,
                { desc = "Go to References LSP" }
            )
            vim.keymap.set(
                "n",
                "gl",
                function() vim.diagnostic.open_float({ border = "rounded" }) end,
                { desc = "Show Diagnostics Float" }
            )
            vim.keymap.set(
                "n",
                "gi",
                vim.lsp.buf.implementation,
                { desc = "Go to Implementation LSP" }
            )
        end,
    },
}
