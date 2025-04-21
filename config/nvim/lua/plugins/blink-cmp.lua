return {
    "saghen/blink.cmp",
    dependencies = "rafamadriz/friendly-snippets",

    version = "*",
    completion = {
        menu = {
            border = { "┏", "┛", "━", "━", "┓", "┏", "┛", "━" },
            draw = {
                components = {
                    kind_icon = {
                        text = function(ctx)
                            local kind_icon, _, _ =
                                require("mini.icons").get("lsp", ctx.kind)
                            return kind_icon
                        end,
                        -- (optional) use highlights from mini.icons
                        highlight = function(ctx)
                            local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
                            return hl
                        end,
                    },
                    kind = {
                        -- (optional) use highlights from mini.icons
                        highlight = function(ctx)
                            local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
                            return hl
                        end,
                    },
                },
            },
        },
    },

    sources = {
        completion = {
            enabled_providers = { "lsp", "path", "snippets", "buffer" },
        },
    },
    opts = {
        keymap = { preset = "enter" },
        appearance = {
            use_nvim_cmp_as_default = true,
            nerd_font_variant = "mono",
        },
        fuzzy = { implementation = "rust" },
    },
    opts_extend = { "sources.default" },
    signature = { enabled = true },
}
