vim.keymap.set("n","gd",vim.lsp.buf.definition,opts,{})
vim.keymap.set("n","<leader>f",vim.lsp.buf.format,opts,{})

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend("force",capabilities, require("mini.completion").get_lsp_capabilities())


vim.lsp.config("*",{capabilities = capabilities})
-- TypeScript 7 (`tsc --lsp`) : sur `obj.`, le SEUL item qui porte un `textEdit`
-- est l'accès par crochets (`[Symbol.xxx]`, filterText ".Symbol"), et sa plage
-- d'édition commence *sur le point*. mini.completion déduit le début de
-- complétion du premier `textEdit` rencontré (H.get_completion_range), croit
-- donc que la base est "." au lieu de "", et le filtre fuzzy ne garde que cet
-- item. On retire ces items de la réponse : le calcul retombe alors sur le
-- mot-clé courant (colonne juste après le point) et tous les membres s'affichent.
local function drop_bracket_accessors(result)
	local items = type(result) == "table" and (result.items or result)
	if type(items) ~= "table" then return end
	for i = #items, 1, -1 do
		local te = items[i].textEdit
		if te and (te.range or te.insert) and vim.startswith(items[i].filterText or "", ".") then
			table.remove(items, i)
		end
	end
end

local function patch_completion(client)
	local request = client.request
	client.request = function(self, method, params, handler, bufnr)
		if method == "textDocument/completion" and handler then
			local inner = handler
			handler = function(err, result, ctx, cfg)
				drop_bracket_accessors(result)
				return inner(err, result, ctx, cfg)
			end
		end
		return request(self, method, params, handler, bufnr)
	end
end

vim.lsp.config("tsc", {
  on_init = patch_completion,

  cmd = { "bun", "x", "tsc", "--lsp", "--stdio" },

  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },

  root_markers = {
    "tsconfig.json",
    "jsconfig.json",
    "package.json",
    ".git",
  },
})
vim.lsp.enable({
	"lua_ls",
	"gopls",
	"tsc"
})
