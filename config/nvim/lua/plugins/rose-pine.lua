return {
	"rose-pine/neovim",
	name = "rose-pine",
	config = function()
		require("rose-pine").setup({
			variant = "main", -- auto, main, moon, or dawn
			dark_variant = "main", -- main, moon, or dawn
			dim_inactive_windows = true,
			extend_background_behind_borders = true,

			enable = {
				terminal = true,
				-- legacy_highlights = true, -- Improve compatibility for previous versions of Neovim
				migrations = true, -- Handle deprecated options automatically
			},

			styles = {
				bold = true,
				italic = true,
				transparency = true,
			},

			groups = {
				border = "pine",
				link = "iris",
				panel = "surface",

				error = "love",
				hint = "iris",
				info = "foam",
				note = "pine",
				todo = "rose",
				warn = "gold",

				git_add = "foam",
				git_change = "rose",
				git_delete = "love",
				git_dirty = "rose",
				git_ignore = "muted",
				git_merge = "iris",
				git_rename = "pine",
				git_stage = "iris",
				git_text = "rose",
				git_untracked = "subtle",

				h1 = "iris",
				h2 = "foam",
				h3 = "rose",
				h4 = "gold",
				h5 = "pine",
				h6 = "foam",
			},
		})

		vim.cmd("colorscheme rose-pine")

		vim.opt.cursorline = true -- Active le surlignement
		vim.cmd([[highlight CursorLine guibg=#2a273f]])

		-- vim.opt.guicursor = "n-v-c:block,i:ver25"

		vim.api.nvim_set_hl(0, "LineNr", { fg = "#626262" }) -- Gris pour les numéros relatifs
		vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#9ccfd8", bold = true }) -- Blanc clair pour le numéro actuel
		vim.cmd([[
      highlight Cursor guifg=#000000 guibg=#ff69b4
      highlight iCursor guifg=#000000 guibg=#ff69b4
      set guicursor=n-v-c:block-Cursor
      set guicursor+=i:ver25-iCursor
    ]])

		-- vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#3a3a3a' })
	end,
}
