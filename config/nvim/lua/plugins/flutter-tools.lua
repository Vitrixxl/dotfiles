return {
    'nvim-flutter/flutter-tools.nvim',
    lazy = false,
    dependencies = {
        'nvim-lua/plenary.nvim',
        'stevearc/dressing.nvim', -- optional for vim.ui.select
    },
    config = function()
        require('flutter-tools').setup {
            flutter_path = "~/development/flutter/bin/flutter",
            dart_sdk_path = "~/development/flutter/bin/cache/dart-sdk",
            lsp = {
                cmd = { "/home/vitrix/development/flutter/bin/dart", "language-server", "--protocol=lsp" },
                -- autres configurations LSP
            },
            -- autres configurations
        }
    end

}
