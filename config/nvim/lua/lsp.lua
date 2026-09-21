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

-- Vue 3 : `tsc --lsp` (TypeScript 7) ne charge pas les plugins tsserver, or
-- vue_ls (v3, mode hybride) a besoin de `@vue/typescript-plugin` côté
-- TypeScript. Dans un projet Vue, c'est donc vtsls qui prend le relais de tsc
-- (y compris pour les .ts, sinon les imports de .vue ne sont pas typés).
-- Pas de node sur la machine : les serveurs sont installés avec
-- `bun add -g @vue/language-server @vtsls/language-server` et lancés par bun.
local bun_global = vim.fn.expand("~/.bun")
local vue_language_server_path = bun_global .. "/install/global/node_modules/@vue/language-server"

local function is_vue_project(bufnr)
	if vim.bo[bufnr].filetype == "vue" then return true end
	local name = vim.api.nvim_buf_get_name(bufnr)
	for _, pkg in ipairs(vim.fs.find("package.json", { path = vim.fs.dirname(name), upward = true, limit = math.huge })) do
		local ok, json = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(pkg), "\n")) end)
		if ok and type(json) == "table" then
			for _, field in ipairs({ "dependencies", "devDependencies", "peerDependencies" }) do
				local deps = json[field]
				if type(deps) == "table" and (deps.vue or deps.nuxt) then return true end
			end
		end
	end
	return false
end

local ts_root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" }

vim.lsp.config("vtsls", {
	cmd = { "bun", "--bun", bun_global .. "/bin/vtsls", "--stdio" },
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
	root_dir = function(bufnr, on_dir)
		if not is_vue_project(bufnr) then return end
		on_dir(vim.fs.root(bufnr, { { "bun.lock", "bun.lockb", "package-lock.json", "yarn.lock", "pnpm-lock.yaml" }, { ".git" } })
			or vim.fs.root(bufnr, ts_root_markers)
			or vim.fn.getcwd())
	end,
	settings = {
		vtsls = {
			tsserver = {
				globalPlugins = {
					{
						name = "@vue/typescript-plugin",
						location = vue_language_server_path,
						languages = { "vue" },
						configNamespace = "typescript",
					},
				},
			},
		},
	},
})

vim.lsp.config("vue_ls", {
	cmd = { "bun", "--bun", bun_global .. "/bin/vue-language-server", "--stdio" },
})

vim.lsp.config("tsc", {
  on_init = patch_completion,

  cmd = { "bun", "x", "tsc", "--lsp", "--stdio" },

  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },

  root_dir = function(bufnr, on_dir)
    if is_vue_project(bufnr) then return end
    local root = vim.fs.root(bufnr, ts_root_markers)
    if root then on_dir(root) end
  end,
})
vim.lsp.enable({
	"lua_ls",
	"gopls",
	"tsc",
	"vtsls",
	"vue_ls",
})
