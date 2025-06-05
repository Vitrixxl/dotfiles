return {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    ---@module "ibl"
    ---@type ibl.config
    opts = {
        indent = {
            char = "·", -- ou "┊", ou "│"
            highlight = "NonText", -- ou une couleur custom comme "LineNr"
        },
        scope = {
            enabled = true,
        },
    },
    config = function() require("ibl").setup() end,
}
