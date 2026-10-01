vim.keymap.set("n","gd",vim.lsp.buf.definition,opts,{})

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
-- Postgres Language Server (binaire de la release GitHub dans ~/.local/bin).
-- Par défaut lspconfig exige un postgres-language-server.jsonc : on accepte
-- aussi un dépôt git ou un .sql isolé (analyse syntaxique seule). La connexion
-- à la base (complétion des tables/colonnes, typecheck) se règle dans le
-- postgres-language-server.jsonc du projet, section "db".
vim.lsp.config("postgres_lsp", {
	root_markers = { "postgres-language-server.jsonc", ".git" },
	workspace_required = false,
})

-- Formatage SQL : pgFormatter (~/.local/bin/pg_format, dépôt dans
-- ~/.local/share/pgformatter) plutôt que le formateur de postgres_lsp, qui
-- éclate chaque appel de fonction et réécrit le code (::text → CAST, $$ → $function$).
local pg_format = { "pg_format", "-u", "2", "-U", "2", "-f", "2", "--no-space-function", "-" }

local function format_sql(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local res = vim.system(pg_format, { stdin = table.concat(lines, "\n") .. "\n" }):wait()
	if res.code ~= 0 then
		vim.notify("pg_format : " .. (res.stderr or ""), vim.log.levels.ERROR)
		return
	end
	local out = vim.split(res.stdout:gsub("\n+$", ""), "\n") -- pg_format ajoute une ligne vide finale
	if vim.deep_equal(out, lines) then return end
	local view = vim.fn.winsaveview()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
	vim.fn.winrestview(view)
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = "sql",
	callback = function(args)
		vim.bo[args.buf].formatprg = table.concat(pg_format, " ")
	end,
})

-- Formatage du buffer : pg_format pour le SQL, sinon le LSP (sauf postgres_lsp).
-- Sans serveur capable de formater, on ne fait rien (pas d'erreur à chaque :w).
local function format(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if vim.bo[buf].filetype == "sql" then
		if vim.fn.executable("pg_format") == 1 then format_sql(buf) end
		return
	end
	local filter = function(client) return client.name ~= "postgres_lsp" end
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf, method = "textDocument/formatting" })) do
		if filter(client) then
			vim.lsp.buf.format({ bufnr = buf, filter = filter })
			return
		end
	end
end

vim.keymap.set("n", "<leader>f", function() format() end, { desc = "Formater le buffer" })

vim.api.nvim_create_autocmd("BufWritePre", {
	desc = "Formater à la sauvegarde",
	callback = function(args) format(args.buf) end,
})

vim.lsp.enable({
	"lua_ls",
	"gopls",
	"tsc",
	"vtsls",
	"vue_ls",
	"postgres_lsp",
})
