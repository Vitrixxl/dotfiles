require("config.lazy")
local vim = vim
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.g.loaded_sql_completion = 1
vim.g.omni_sql_no_default_maps = 1

vim.opt.cursorline = true

vim.cmd([[
  " colorscheme onedark
  highlight Normal guibg=NONE ctermbg=NONE
  highlight NormalNC guibg=NONE ctermbg=NONE
  " highlight TelescopeNormal guibg=NONE guifg=#C0CAF5
  " highlight TelescopeBorder guifg=#E18948 guibg=NONE
  " highlight TelescopePromptBorder guifg=#E18948 guibg=NONE
  " highlight TelescopeTitle guifg=NONE gui=bold
  " highlight WinSeparator guibg=NONE
  " highlight VertSplit guibg=NONE
  " highlight EndOfBuffer guifg=#666666
  " highlight NonText guifg=NONE
  " highlight Cursor guifg=NONE guibg=#E06C75
  " highlight iCursor guifg=NONE guibg=#E06C75
  " highlight CursorLine guibg=#1C4546
  " highlight CursorLineNr guifg=#E18948 guibg=#1C4546 gui=bold
  " highlight LineNr guibg=NONE guifg=#888888
  " highlight NormalFloat guibg=NONE guifg=#c0caf5
  " highlight FloatBorder guibg=NONE guifg=#E18948
  " highlight StatusLine guibg=#1C4546 guifg=#E18948
  " highlight StatusLineNC guibg=#1C4546 guifg=#E18948
  "
  " highlight BlinkCmpMenuBorder  guifg=#E18948  guibg=NONE
  " highlight BlinkCmpScrollBarThumb guibg=#E18948 guifg=NONE
  highlight Pmenu guibg=NONE 
  " highlight PmenuSel guibg=#1C4546 guifg=#E18948
    highlight WinBorder guibg=NONE 
  "
]])
-- -- Définit le style de bordure pour les fenêtres flottantes (comme Pmenu, etc.)
vim.o.winborder = "rounded" -- "single", "double", "rounded", "solid", etc.
