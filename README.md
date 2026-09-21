# dotfiles

Mes configs : Hyprland, Neovim, foot, fuzzel, fish, mako, btop, GTK, Thunar, pipewire. Les fichiers vivent ici, `~/.config` pointe dessus par symlink.

## Installation

```sh
git clone https://github.com/Vitrixxl/dotfiles.git ~/dotfiles
for d in ~/dotfiles/config/*; do ln -s "$d" ~/.config/(basename "$d"); end  # fish
```
