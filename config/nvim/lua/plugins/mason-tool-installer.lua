return {
    "WhoIsSethDaniel/mason-tool-installer",

    config = function()
        local mason_tool_installer = require("mason-tool-installer")
        mason_tool_installer.ensure_installed = {
            "stylua",
            "prettierd",
        }
    end,
}
