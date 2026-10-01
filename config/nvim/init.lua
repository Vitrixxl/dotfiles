require("vim._core.ui2").enable({})
require("keymaps")
require("options")
require("pack")
require("treesitter")
require("lsp")

-- Couleurs générées par Nexus (mode clair/sombre et accent du wallpaper) ;
-- moonfly sert de repli tant que Nexus ne les a pas écrites.
local function apply_colors()
    if not pcall(vim.cmd.colorscheme, "nexus") then
        vim.cmd.colorscheme("moonfly")
    end
end
apply_colors()

-- Nexus réécrit le fichier à chaque changement de thème : on le recharge à la volée.
local colors_dir = vim.fn.stdpath("data") .. "/site/colors"
local watcher = vim.uv.fs_stat(colors_dir) and vim.uv.new_fs_event()
if watcher then
    watcher:start(colors_dir, {}, vim.schedule_wrap(function(_, file)
        if file == "nexus.lua" and vim.g.colors_name == "nexus" then
            apply_colors()
        end
    end))
end

