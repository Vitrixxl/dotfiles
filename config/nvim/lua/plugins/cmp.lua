return {
	{

		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp", -- Source LSP
			"hrsh7th/cmp-buffer", -- Source buffer
			"hrsh7th/cmp-path", -- Source chemin fichiers
			"L3MON4D3/LuaSnip", -- Snippets
			"saadparwaiz1/cmp_luasnip", -- Source snippets
			"onsails/lspkind.nvim", -- Icônes
		},
		config = function()
			local cmp = require("cmp")
			local kind_icons = {
				Text = "𝐓",
				Method = "󰆧",
				Function = "󰊕",
				Constructor = "󰒿",
				Field = "",
				Variable = "",
				Class = "󰠱",
				Interface = "",
				Module = "",
				Property = "",
				Unit = "󰑭",
				Value = "󰎠",
				Enum = "",
				Keyword = "󰌋",
				Snippet = "",
				Color = "󰏘",
				File = "",
				Reference = "",
				Folder = "",
				EnumMember = "",
				Constant = "",
				Struct = "󰙅",
				Event = "",
				Operator = "󰆕",
				TypeParameter = "",
			}

			cmp.setup({
				snippet = {
					expand = function(args)
						require("luasnip").lsp_expand(args.body)
					end,
				},
				formatting = {
					format = function(entry, vim_item)
						-- Kind icons
						vim_item.kind = string.format("%s", kind_icons[vim_item.kind]) -- This concatenates the icons with the name of the item kind
						-- Source
						vim_item.menu = ({
							buffer = "[Buffer]",
							nvim_lsp = "[LSP]",
							luasnip = "[LuaSnip]",
							nvim_lua = "[Lua]",
							latex_symbols = "[LaTeX]",
						})[entry.source.name]
						return vim_item
					end,
				},
				mapping = {
					["<C-p>"] = cmp.mapping.select_prev_item(),
					["<C-n>"] = cmp.mapping.select_next_item(),
					["<C-d>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.close(),
					["<CR>"] = cmp.mapping.confirm({
						behavior = cmp.ConfirmBehavior.Replace,
						select = true,
					}),
				},
				sources = {
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "lsp_config" },
					{ name = "buffer" },
					{ name = "path" },
				},
				window = {
					completion = cmp.config.window.bordered({
						border = "rounded", -- Options: 'single', 'double', 'rounded', 'solid', 'shadow'
						winhighlight = "Normal:Normal,FloatBorder:BorderBG,CursorLine:PmenuSel,Search:None",
					}),
					documentation = cmp.config.window.bordered({
						border = "rounded",
						winhighlight = "Normal:Normal,FloatBorder:BorderBG,CursorLine:PmenuSel,Search:None",
					}),
				},
			})
		end,
	},
	{
		"L3MON4D3/LuaSnip",
		dependencies = {
			"rafamadriz/friendly-snippets", -- Ajout d'une collection de snippets prédéfinis
		},
		config = function()
			local luasnip = require("luasnip")
			local s = luasnip.snippet
			local t = luasnip.text_node
			local i = luasnip.insert_node

			-- Charger les snippets friendly-snippets
			require("luasnip.loaders.from_vscode").lazy_load()

			-- Ajouter le snippet pour les commentaires JSX
			luasnip.add_snippets("javascriptreact", {
				s("cc", {
					t("{/* "),
					i(1, ""),
					t(" */}"),
				}),
			})

			-- Même snippet pour TypeScript React
			luasnip.add_snippets("typescriptreact", {
				s("cc", {
					t("{/* "),
					i(1, ""),
					t(" */}"),
				}),
			})

			-- Charger les snippets friendly-snippets
			require("luasnip.loaders.from_vscode").lazy_load()

			-- Configuration des touches pour naviguer dans les snippets
			vim.keymap.set({ "i", "s" }, "<C-j>", function()
				if luasnip.expand_or_jumpable() then
					luasnip.expand_or_jump()
				end
			end)

			vim.keymap.set({ "i", "s" }, "<C-k>", function()
				if luasnip.jumpable(-1) then
					luasnip.jump(-1)
				end
			end)
		end,
	},
}
