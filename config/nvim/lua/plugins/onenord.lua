return {
    { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
    {
        "AlexvZyl/nordic.nvim",
        lazy = false,
        priority = 1000,
        config = function() require("nordic").load() end,
    },
}
