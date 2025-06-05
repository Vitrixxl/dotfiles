return {
    { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
    {
        "baliestri/aura-theme",
        lazy = false,
        priority = 1000,
        config = function(plugin)
            vim.opt.rtp:append(plugin.dir .. "/packages/neovim")
            vim.cmd([[colorscheme aura-dark]])
            vim.api.nvim_set_hl(
                0,
                "CmpItemAbbrDeprecated",
                { bg = "NONE", strikethrough = true, fg = "#6d6d6d" }
            )
            vim.api.nvim_set_hl(0, "CmpItemAbbrMatch", { bg = "NONE", fg = "#82e2ff" })
            vim.api.nvim_set_hl(0, "CmpItemAbbrMatchFuzzy", { link = "CmpItemAbbrMatch" })
            vim.api.nvim_set_hl(0, "CmpItemKindVariable", { bg = "NONE", fg = "#61ffca" })
            vim.api.nvim_set_hl(
                0,
                "CmpItemKindInterface",
                { link = "CmpItemKindVariable" }
            )
            vim.api.nvim_set_hl(0, "CmpItemKindText", { link = "CmpItemKindVariable" })
            vim.api.nvim_set_hl(0, "CmpItemKindFunction", { bg = "NONE", fg = "#f694ff" })
            vim.api.nvim_set_hl(0, "CmpItemKindMethod", { link = "CmpItemKindFunction" })
            vim.api.nvim_set_hl(0, "CmpItemKindKeyword", { bg = "NONE", fg = "#edecee" })
            vim.api.nvim_set_hl(0, "CmpItemKindProperty", { link = "CmpItemKindKeyword" })
            vim.api.nvim_set_hl(0, "CmpItemKindUnit", { link = "CmpItemKindKeyword" })
        end,
    },
}
