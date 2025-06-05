return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },

    config = function()
        require("telescope").setup({
            defaults = {
                file_ignore_patterns = {
                    "node_modules/",
                    ".next/",
                },
            },
            winbled = 0,
            pickers = {
                find_files = {
                    theme = "dropdown",
                    hidden = true,
                },
            },
            extensions = {
                fzf = {},
            },
        })
        -- require("telescope").load_extension("fzf")
        local builtin = require("telescope.builtin")

        vim.keymap.set(
            "n",
            "<leader>pf",
            builtin.find_files,
            { desc = "find files TELESCOPE" }
        )
        vim.keymap.set(
            "n",
            "<C-p>",
            builtin.live_grep,
            { desc = "grep codebase TELESCOPE" }
        )
    end,
}
