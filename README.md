# dotfiles

Mes configs : Hyprland, Nexus, Neovim, foot, fish, mako, btop, GTK, Thunar, pipewire.
Les fichiers vivent ici, `~/.config` pointe dessus par symlink, sauf Hyprland : ses fichiers locaux restent indépendants et sont conservés à l’installation.

## Installation

```sh
git clone https://github.com/Vitrixxl/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

Le script cible Arch Linux et fonctionne aussi sur Artix. Il installe `yay`, puis toutes les dépendances avec `yay`.
Il pose ensuite les symlinks, compile `hypr-screenshot` et installe [Nexus](https://github.com/Vitrixxl/nexus)
(centre de contrôle Rust/GTK et daemon) depuis son dépôt dans `~/.local/bin`. Un fichier déjà présent est
déplacé dans `~/.dotfiles-backup/`, jamais écrasé. Le script peut être relancé sans risque.

Sur un système avec systemd, la config `pipewire` du repo n'est pas liée : le script active les
services utilisateur pipewire à la place.
Il active aussi `ly@tty2.service` au prochain démarrage et désactive `getty@tty2.service`
ainsi que l'ancien gestionnaire de connexion, sans interrompre la session en cours.
Sur Artix, l'activation de Ly reste à faire avec le système d'init utilisé.

Le partage d'écran (Google Meet, etc.) utilise `xdg-desktop-portal-hyprland`,
installé avec les dépendances, ainsi que PipeWire et WirePlumber. Si le portail
vient d'être installé dans une session Hyprland déjà ouverte, reconnecte-toi ou,
avec systemd, relance les portails puis recharge la page de l'appel :

```sh
systemctl --user restart xdg-desktop-portal-hyprland
systemctl --user restart xdg-desktop-portal
```

Le script installe aussi Docker, Compose et Buildx, crée le groupe `docker` si nécessaire
et y ajoute ton utilisateur. Avec systemd, il active et démarre Docker et containerd.
Déconnecte-toi puis reconnecte-toi après l'installation pour utiliser Docker sans `sudo`.
Sur Artix, le service Docker doit être activé avec le système d'init utilisé.

Il installe aussi Claude Code, Codex CLI (`openai-codex-bin`) et T3 Code (`t3code-bin`) depuis l'AUR.
Claude Code et Codex sont ignorés si `claude` ou `codex` sont déjà présents (installeur natif).

Pour Steam, le script active le dépôt 32 bits dans `/etc/pacman.conf` s'il est commenté :
`[lib32]` sur Artix, `[multilib]` sur Arch (sauvegarde dans `/etc/pacman.conf.bak`,
puis `pacman -Syu`). Il installe ensuite `steam`, `lib32-nvidia-utils` et `lib32-vulkan-intel`.

Options : `--no-deps`, `--no-links`, `--no-build`.

## Nexus : barre, launcher et réglages

La barre intégrée à Nexus affiche les espaces de travail, l’heure, le Wi-Fi, le Bluetooth, le volume,
la luminosité, la batterie et le bouton d’alimentation. Les boutons ouvrent la
page correspondante de Nexus. L’interface de Nexus est en anglais.

- `Super+Space` ou `Super+D` : launcher intégré ; ↑/↓ ou Ctrl+N/P, Entrée pour ouvrir, Échap pour fermer.
- `Super+W` : Wi-Fi ; `Super+Alt+N` : Nexus.
- `Super+Alt+B` : Bluetooth ; `Super+Alt+A` : son.
- `Super+Alt+P` ou `Ctrl+Alt+Delete` : écran Sleep / Restart / Shutdown.
- Appearance : thème clair/sombre, choix du wallpaper et couleurs générées en option.

`nexus-session` démarre le daemon et le shell Nexus depuis Hyprland, avec ou sans systemd.
Nexus utilise volontairement ConnMan ; le script ne remplace ni n’active le
gestionnaire réseau existant (NetworkManager reste inchangé).
Les wallpapers sélectionnés utilisent `swaybg` et remplacent le fond vidéo.
Les paramètres et les couleurs générées restent dans `~/.config/nexus`.
Nexus construit aussi les thèmes GTK `Nexus` / `Nexus-dark` sur adw-gtk3 avec ces couleurs
(accent du wallpaper compris) et les sélectionne : les applis GTK3, Thunar compris, les suivent
en direct ; Brave les utilise quand son thème est réglé sur GTK (Paramètres › Apparence).
Les applis libadwaita les prennent à leur prochain lancement (bloc généré dans
`~/.config/gtk-4.0/gtk.css`, ignoré par git).

Curseur : Bibata Modern Classic (AUR `bibata-cursor-theme-bin`), appliqué à Hyprland,
GTK et XWayland.

Pour autoriser l’alimentation sans sudo si elogind/logind la refuse :

```sh
sudo install -Dm644 ~/.local/share/nexus/49-nexus-power.rules /etc/polkit-1/rules.d/49-nexus-power.rules
```

Cette règle est limitée aux sessions locales actives. `loginctl poweroff` permet
ensuite d’éteindre depuis un terminal. Les boutons Nexus passent par la même API.

## Brave et rendu 3D NVIDIA

L'installation inclut `brave-bin`, `nvidia-open`, `nvidia-utils`, `nvidia-prime`
et `xorg-xwayland`. Ce choix de pilote cible la RTX 3050 Ti de cette machine et
le noyau Arch standard `linux` ; pour un autre GPU ou noyau, adapter les paquets
avant de lancer l'installation. Les hooks des paquets régénèrent l'initramfs.
Après la première installation du pilote, redémarrer puis vérifier `nvidia-smi`.

Le lanceur `applications/brave-browser.desktop` est lié dans
`~/.local/share/applications/` et prend priorité sur celui du paquet. Il utilise
la commande validée pour le rendu WebGL sur NVIDIA, y compris en navigation privée :

```sh
prime-run /opt/brave-bin/brave --ozone-platform=x11 --use-gl=angle --use-angle=gl
```

Quitter complètement Brave avant de le relancer depuis son icône : une instance
déjà ouverte conserve son GPU. Vérifier dans `brave://gpu` que `GL_RENDERER`
mentionne NVIDIA et que WebGL indique `Hardware accelerated`.
Le lancement direct du binaire évite les options de `brave-flags.conf` qui
pourraient forcer l'Intel. La commande `brave` lancée dans un terminal reste inchangée.

Le partage d'écran utilise les composants PipeWire et portail Hyprland décrits
plus haut. Leur présence a été vérifiée ; le partage en visioconférence avec
cette configuration XWayland reste à tester.

## Contenu

- `config/` : lié dans `~/.config/`
- `bin/` : scripts utilisés par Hyprland, liés dans `~/.local/bin/`
- `applications/` : lanceurs liés dans `~/.local/share/applications/`
- `hypr-screenshot/` : sélecteur de capture en Rust, lié dans `~/.local/share/`

Le fond d'écran `~/Wallpapers/window-view-2560.mp4` n'est pas versionné.
