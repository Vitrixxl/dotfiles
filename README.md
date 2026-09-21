# dotfiles

Mes configs : Hyprland, Neovim, foot, fuzzel, fish, mako, btop, GTK, Thunar, pipewire.
Les fichiers vivent ici, `~/.config` pointe dessus par symlink.

## Installation

```sh
git clone https://github.com/Vitrixxl/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

Le script cible Artix et Arch. Il installe `yay`, puis toutes les dépendances avec `yay`.
Il pose ensuite les symlinks et compile `hypr-screenshot`. Un fichier déjà présent est
déplacé dans `~/.dotfiles-backup/`, jamais écrasé. Le script peut être relancé sans risque.

Options : `--no-deps`, `--no-links`, `--no-build`.

## Contenu

- `config/` : lié dans `~/.config/`
- `bin/` : scripts utilisés par Hyprland, liés dans `~/.local/bin/`
- `hypr-screenshot/` : sélecteur de capture en Rust, lié dans `~/.local/share/`

Le fond d'écran `~/Wallpapers/window-view-2560.mp4` n'est pas versionné.
