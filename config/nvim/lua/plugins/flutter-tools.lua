return {

    "nvim-flutter/flutter-tools.nvim",
    lazy = false,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "stevearc/dressing.nvim", -- optional for vim.ui.select
    },
    config = function()
        require("flutter-tools").setup({
            flutter_path = "/usr/bin/flutter",
            dart_sdk_path = "/opt/flutter/bin/dart",
            lsp = {
                cmd = {
                    "/opt/flutter/bin/dart",
                    "language-server",
                    "--protocol=lsp",
                },
            },
            -- autres configurations
        })
    end,
}
