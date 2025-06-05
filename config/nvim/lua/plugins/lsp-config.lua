return {
    -- {
    --     "williamboman/mason.nvim",
    --     config = function() require("mason").setup() end,
    -- },
    -- {
    --     "williamboman/mason-lspconfig",
    --     config = function()
    --         require("mason-lspconfig").setup({
    --             ensure_installed = {
    --                 "lua_ls",
    --                 "tailwindcss",
    --                 "cssls",
    --                 "rust_analyzer",
    --                 "gopls",
    --                 "pyright",
    --             },
    --             automatic_installation = true,
    --         })
    --     end,
    -- },
    {
        "neovim/nvim-lspconfig",
        config = function()
            local lspconfig = require("lspconfig")
            local servers = {
                pyright = {},
                lua_ls = {},
                ts_ls = {
                    cmd = {
                        "npx",
                        "typescript-language-server",
                        "--stdio",
                    },
                    root_dir = function() return vim.loop.cwd() end,
                },
                cssls = {
                    cmd = {
                        "vscode-css-language-server",
                        "--stdio",
                    },
                    filetypes = { "css", "scss", "less" },
                },
                gopls = {},
                rust_analyzer = {
                    cmd = { "rust-analyzer" },
                    filetypes = { "rust" },
                    root_dir = require("lspconfig.util").root_pattern(
                        "Cargo.toml",
                        "Cargo.lock"
                    ),
                    settings = {
                        ["rust-analyzer"] = {
                            cargo = {
                                allFeatures = true,
                            },
                            procMacro = {
                                enable = true,
                            },
                        },
                    },
                },

                tailwindcss = {
                    cmd = {
                        "npx",
                        "tailwindcss-language-server",
                        "--stdio",
                    },
                    filetypes = {
                        "html",
                        "css",
                        "scss",
                        "javascript",
                        "javascriptreact",
                        "typescript",
                        "typescriptreact",
                        "vue",
                    },
                    root_dir = lspconfig.util.root_pattern(
                        "tailwind.config.js",
                        "package.json"
                    ),
                    settings = {},
                },
            }
            local capabilities = require("cmp_nvim_lsp").default_capabilities()
            for server_name, config in pairs(servers) do
                -- Si pas de config, on crée une table vide
                config = config or {}
                -- On ajoute/merge la config générique
                config.capabilities = capabilities

                -- Setup du serveur
                lspconfig[server_name].setup(config)
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
