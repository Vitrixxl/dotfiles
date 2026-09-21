local ts=  require("nvim-treesitter")

local ensure_installed = {
	"go","rust","typescript","javascript","tsx","html","css","json","bash","markdown","dockerfile",
}

ts.install(ensure_installed)

