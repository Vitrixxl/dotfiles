return {
	"saghen/blink.cmp",
	dependencies = "rafamadriz/friendly-snippets",
	version = "*",
	sources = {
		completion = {
			enabled_providers = { "lsp", "path", "snippets", "buffer" },
			documentation = { auto_show = true, auto_show_delay_ms = 500 },
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
