#!/usr/bin/env bash
# Installe les dépendances de ces dotfiles et pose les symlinks.
# Cible : Arch Linux (fonctionne aussi sur Artix).
#
#   ./install.sh              tout faire
#   ./install.sh --no-deps    ne pas installer de paquets
#   ./install.sh --no-links   ne pas toucher aux symlinks
#   ./install.sh --no-build   ne pas compiler ni installer Nexus
set -euo pipefail

DOTFILES="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
do_deps=1 do_links=1 do_build=1

for arg in "$@"; do
    case "$arg" in
        --no-deps)  do_deps=0 ;;
        --no-links) do_links=0 ;;
        --no-build) do_build=0 ;;
        -h|--help)  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Option inconnue : $arg" >&2; exit 2 ;;
    esac
done

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

# ── Paquets ──────────────────────────────────────────────────────────────────
# yay est installé en premier, puis il installe tout (dépôts et AUR).
# Sur Arch, Brave, mpvpaper et les polices Geist viennent de l'AUR.
# "a|b" : a s'il existe dans les dépôts (Arch), sinon b depuis l'AUR (Artix).
PACKAGES=(
    # Gestionnaire de connexion
    ly
    # Session Hyprland
    hyprland hyprlock hyprsunset hyprtoolkit
    # Portails : partage d'écran sous Hyprland et sélecteur de fichiers GTK
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    # Brave : rendu WebGL sur la RTX 3050 Ti, via PRIME et XWayland.
    # nvidia-open correspond au noyau linux standard de cette machine.
    brave-bin nvidia-open nvidia-utils nvidia-prime xorg-xwayland desktop-file-utils
    # Terminal, shell, launcher, fichiers. Nexus sert lui-même les notifications ;
    # libnotify fournit notify-send et la bibliothèque qu'utilisent Electron et Brave.
    foot fish fuzzel libnotify thunar btop fastfetch
    # Audio, touches média, luminosité
    pipewire pipewire-pulse wireplumber playerctl brightnessctl
    # Fond d'écran animé
    mpv mpvpaper
    # jq : hypr-helper et la config Hyprland ; wl-clipboard : captures d'écran Nexus ;
    # wf-recorder : enregistrement d'écran (Nexus, Super+Shift+R) ; slurp pour niri-record
    jq slurp wl-clipboard wf-recorder
    # Neovim : plugins (git), treesitter (tree-sitter-cli + gcc), LSP (ceux de Vue passent par bun)
    neovim git gcc tree-sitter-cli ripgrep fd
    go gopls "bun|bun-bin" "lua-language-server|lua-language-server-git"
    # Conteneurs : moteur Docker, Compose et Buildx
    docker docker-compose docker-buildx
    # Agents de code : Claude Code, Codex CLI et T3 Code (AUR)
    claude-code openai-codex-bin t3code-bin
    # Discord : Equibop (AUR), ses couleurs suivent le thème Nexus via QuickCSS
    "equibop|equibop-bin"
    # Steam et pilotes Vulkan/OpenGL 32 bits (dépôt lib32 sur Artix, multilib sur Arch)
    steam lib32-nvidia-utils lib32-vulkan-intel
    # Compilation de Nexus (PAM pour son écran de verrouillage, dbus pour dbus-daemon/dbus-send)
    rust pkgconf gtk4 pam dbus
    # Nexus : NetworkManager pilote le Wi-Fi (cf. setup_network) ; polkit laisse le
    # groupe wheel enregistrer des réseaux. gtk4-layer-shell fournit aussi
    # gtk4-session-lock (écran de verrouillage).
    networkmanager gtk4-layer-shell swaybg bluez bluez-utils libpulse polkit
    # Pilote Vulkan de l’iGPU
    vulkan-intel
    # Curseur Bibata Modern Classic (AUR), thème GTK adw-gtk3 que Nexus recolore
    # avec les couleurs du wallpaper (applis GTK et Brave en mode GTK), icônes, polices
    bibata-cursor-theme-bin adw-gtk-theme adwaita-icon-theme adwaita-fonts
    otf-geist otf-geist-mono
)

ensure_yay() {
    command -v yay >/dev/null && return
    info "Installation de yay (AUR)"
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

# Paquets 32 bits (Steam) : dépôt [lib32] sur Artix, [multilib] sur Arch,
# commentés par défaut dans /etc/pacman.conf.
enable_lib32() {
    local conf=/etc/pacman.conf repo
    grep -qE '^\[(lib32|multilib)\]' "$conf" && return 0     # déjà activé
    if grep -qx '#\[lib32\]' "$conf"; then repo=lib32
    elif grep -qx '#\[multilib\]' "$conf"; then repo=multilib
    else warn "Dépôt 32 bits introuvable dans $conf : Steam ne pourra pas s'installer."; return 0
    fi
    info "Activation du dépôt [$repo] dans $conf"
    sudo cp "$conf" "$conf.bak"
    sudo sed -i "/^#\[$repo\]\$/,/^#Include/ s/^#//" "$conf"
    sudo pacman -Syu || warn "Synchronisation des dépôts incomplète."
}

install_deps() {
    command -v pacman >/dev/null || { warn "pacman introuvable : installe les paquets à la main."; return; }
    enable_lib32
    ensure_yay                                         # yay d'abord, tout le reste passe par lui

    local todo=() entry name fallback need_go_gopls=0
    for entry in "${PACKAGES[@]}"; do
        name="${entry%%|*}"; fallback="${entry##*|}"
        if pacman -Qq "$name" >/dev/null 2>&1 || pacman -Qq "$fallback" >/dev/null 2>&1; then
            continue                                   # déjà installé
        elif [ "$name" = rust ] && command -v cargo >/dev/null; then
            continue                                   # rustup déjà en place
        elif [ "$name" = bun ] && command -v bun >/dev/null; then
            continue
        elif [ "$name" = claude-code ] && command -v claude >/dev/null; then
            continue                                   # installeur natif déjà en place
        elif [ "$name" = openai-codex-bin ] && command -v codex >/dev/null; then
            continue
        elif [ "$name" = gopls ]; then                 # paquet sur Arch, go install sinon
            if command -v gopls >/dev/null || [ -x "$(go env GOPATH 2>/dev/null)/bin/gopls" ]; then continue; fi
            if pacman -Si gopls >/dev/null 2>&1; then todo+=(gopls); else need_go_gopls=1; fi
        elif [ "$name" = bibata-cursor-theme-bin ] && [ -d "$HOME/.icons/$CURSOR_THEME" ]; then
            continue                                   # curseur déjà installé à la main
        elif [ "$name" = adw-gtk-theme ] && [ -d "$HOME/.local/share/themes/adw-gtk3" ]; then
            continue                                   # thème déjà installé à la main
        elif [[ "$name" = otf-geist* ]] && fc-list : family 2>/dev/null | grep -i 'Geist' >/dev/null; then
            continue                                   # police déjà installée à la main
        elif [ "$name" = "$fallback" ] || pacman -Si "$name" >/dev/null 2>&1; then
            todo+=("$name")
        else
            todo+=("$fallback")                        # absent des dépôts : variante AUR
        fi
    done

    if [ ${#todo[@]} -gt 0 ]; then
        info "yay : ${todo[*]}"
        yay -S --needed "${todo[@]}" || warn "Installation incomplète : on continue."
    else
        info "Tous les paquets sont déjà installés."
    fi

    if [ "$need_go_gopls" = 1 ]; then
        info "Installation de gopls via go install"
        go install golang.org/x/tools/gopls@latest || warn "gopls non installé."
    fi

    install_bun_lsp
}

# Serveurs LSP Vue 3 de Neovim : pas de node ici, bun les installe (dans ~/.bun)
# et les lance (cf. config/nvim/lua/lsp.lua).
BUN_LSP=(@vue/language-server @vtsls/language-server)

install_bun_lsp() {
    local bun pkg todo=()
    bun="$(command -v bun || true)"
    [ -z "$bun" ] && [ -x "$HOME/.bun/bin/bun" ] && bun="$HOME/.bun/bin/bun"
    [ -z "$bun" ] && { warn "bun introuvable : serveurs LSP Vue non installés."; return; }
    for pkg in "${BUN_LSP[@]}"; do
        [ -d "$HOME/.bun/install/global/node_modules/$pkg" ] || todo+=("$pkg")
    done
    [ ${#todo[@]} -eq 0 ] && return
    info "bun add -g : ${todo[*]}"
    "$bun" add -g "${todo[@]}" || warn "Serveurs LSP Vue non installés."
}

# ── Audio ────────────────────────────────────────────────────────────────────
# Avec systemd (Arch), pipewire, pipewire-pulse et wireplumber sont des services
# utilisateur. Sans systemd (Artix), c'est config/pipewire + Hyprland qui les lancent.
has_systemd() { [ -d /run/systemd/system ]; }

setup_audio() {
    has_systemd || return 0
    info "Activation des services utilisateur pipewire"
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service \
        || warn "Services pipewire non activés (pas de session utilisateur ?)."
}

# ── Gestionnaire de connexion ────────────────────────────────────────────────
setup_ly() {
    if ! has_systemd; then
        warn "Ly : active le service avec le système d'init de ta distribution."
        return 0
    fi
    if ! systemctl cat ly@tty2.service >/dev/null 2>&1; then
        warn "Service ly@tty2.service introuvable : Ly non activé."
        return 0
    fi

    local current_dm
    current_dm="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
    info "Activation de Ly sur tty2 au prochain démarrage"
    # Sans --now : la session en cours reste ouverte.
    sudo systemctl enable ly@tty2.service \
        || { warn "Ly non activé."; return 0; }
    if [ -f "$current_dm" ] && [ "${current_dm##*/}" != 'ly@.service' ]; then
        sudo systemctl disable "${current_dm##*/}" \
            || warn "Ancien gestionnaire de connexion non désactivé : ${current_dm##*/}."
    fi
    sudo systemctl disable getty@tty2.service \
        || warn "getty@tty2.service non désactivé."
}

# ── Réseau ───────────────────────────────────────────────────────────────────
# Nexus pilote le Wi-Fi par NetworkManager. Un autre gestionnaire se disputerait
# l'interface : il est désactivé. Celui qui tourne encore garde la connexion
# jusqu'au redémarrage, le temps de cloner Nexus.
OTHER_NETWORK_UNITS=(connman.service iwd.service dhcpcd.service
    systemd-networkd.service systemd-networkd.socket)

setup_network() {
    local user="${SUDO_USER:-${USER:-$(id -un)}}"
    if ! id -nG "$user" | tr ' ' '\n' | grep -qx wheel; then
        warn "$user n'est pas dans le groupe wheel : Nexus ne pourra pas enregistrer de réseau Wi-Fi (sudo usermod -aG wheel $user)."
    fi
    if ! has_systemd; then
        warn "NetworkManager : active son service avec le système d'init de ta distribution et arrête ConnMan."
        return 0
    fi

    local unit running=() enabled=()
    for unit in "${OTHER_NETWORK_UNITS[@]}"; do
        systemctl is-active --quiet "$unit" && running+=("$unit")
        [ "$(systemctl is-enabled "$unit" 2>/dev/null)" = enabled ] && enabled+=("$unit")
    done
    if [ ${#enabled[@]} -gt 0 ]; then
        info "Désactivation de ${enabled[*]}"
        sudo systemctl disable "${enabled[@]}" || warn "Non désactivé : ${enabled[*]}."
    fi
    if systemctl is-active --quiet NetworkManager.service || [ ${#running[@]} -gt 0 ]; then
        info "Activation de NetworkManager au démarrage"
        sudo systemctl enable NetworkManager.service || warn "NetworkManager non activé."
    else
        info "Activation et démarrage de NetworkManager"
        sudo systemctl enable --now NetworkManager.service || warn "NetworkManager non activé."
    fi
    if [ ${#running[@]} -gt 0 ]; then
        warn "${running[*]} gère encore le réseau : redémarre pour passer à NetworkManager (Wi-Fi de Nexus)."
    fi
}

# ── Docker ───────────────────────────────────────────────────────────────────
setup_docker() {
    command -v dockerd >/dev/null || { warn "Docker non installé : configuration ignorée."; return 0; }

    local docker_user="${SUDO_USER:-${USER:-$(id -un)}}"
    if ! getent group docker >/dev/null; then
        sudo groupadd --system docker \
            || { warn "Impossible de créer le groupe docker."; return 0; }
    fi
    if [ "$docker_user" != root ] && ! id -nG "$docker_user" | tr ' ' '\n' | grep -qx docker; then
        info "Ajout de $docker_user au groupe docker"
        if sudo usermod -aG docker "$docker_user"; then
            info "Docker sans sudo : déconnecte-toi puis reconnecte-toi pour appliquer le groupe."
        else
            warn "Impossible d'ajouter $docker_user au groupe docker."
        fi
    fi

    if has_systemd; then
        info "Activation et démarrage de Docker"
        sudo systemctl enable --now containerd.service docker.service \
            || warn "Services Docker non activés ou non démarrés."
    else
        warn "Docker : active le service avec le système d'init de ta distribution."
    fi
}

# ── Curseur ──────────────────────────────────────────────────────────────────
# Hyprland le reçoit par XCURSOR_THEME (config/hypr/hyprland.lua) et GTK par
# settings.ini ; ce thème par défaut couvre XWayland et les autres applis.
CURSOR_THEME=Bibata-Modern-Classic
CURSOR_SIZE=24

setup_cursor() {
    local index="$HOME/.icons/default/index.theme"
    if ! grep -qx "Inherits=$CURSOR_THEME" "$index" 2>/dev/null; then
        info "Curseur par défaut : $CURSOR_THEME"
        mkdir -p "$(dirname "$index")"
        printf '[Icon Theme]\nName=Default\nComment=Default Cursor Theme\nInherits=%s\n' \
            "$CURSOR_THEME" > "$index"
    fi
    # Applis qui lisent GSettings (libadwaita, portail) ; sans session, settings.ini suffit.
    if command -v gsettings >/dev/null; then
        gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" 2>/dev/null \
            && gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" 2>/dev/null \
            || warn "Curseur non appliqué dans GSettings (pas de session ?)."
    fi
}

# ── Symlinks ─────────────────────────────────────────────────────────────────
link() {                                  # link <source dans le repo> <cible>
    local src="$1" dst="$2"
    if [ "$(readlink -f "$dst" 2>/dev/null)" = "$(readlink -f "$src")" ]; then
        return                                         # déjà en place
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mkdir -p "$BACKUP"
        mv "$dst" "$BACKUP/"
        warn "$dst existait : déplacé dans $BACKUP/"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    info "lien  $dst -> $src"
}

# Liens vers des fichiers retirés du dépôt (ancien sélecteur hypr-screenshot, mako) :
# ils ne pointent plus sur rien et sont supprimés.
remove_stale_links() {
    local l
    for l in "$HOME"/.config/* "$HOME"/.local/bin/* "$HOME/.local/share/hypr-screenshot"; do
        [ -L "$l" ] && [ ! -e "$l" ] || continue
        case "$(readlink "$l")" in
            "$DOTFILES"/*) rm "$l"; info "lien orphelin supprimé : $l" ;;
        esac
    done
}

install_links() {
    local d
    remove_stale_links
    for d in "$DOTFILES"/config/*; do
        if [ "$(basename "$d")" = pipewire ] && has_systemd; then
            continue                                   # config réservée aux systèmes sans systemd
        fi
        # La configuration Hyprland locale et celle du dépôt restent indépendantes.
        if [ "$(basename "$d")" = hypr ]; then
            if [ -L "$HOME/.config/hypr" ]; then
                mkdir -p "$BACKUP"
                cp -aL "$HOME/.config/hypr" "$BACKUP/hypr-copy"
                rm "$HOME/.config/hypr"
                cp -a "$BACKUP/hypr-copy" "$HOME/.config/hypr"
            fi
            mkdir -p "$HOME/.config/hypr"
            local source target
            for source in "$d"/*; do
                target="$HOME/.config/hypr/$(basename "$source")"
                if [ -L "$target" ]; then
                    cp -L "$target" "$target.nexus-copy"
                    rm "$target"
                    mv "$target.nexus-copy" "$target"
                elif [ ! -e "$target" ]; then
                    cp -a "$source" "$target"
                fi
            done
            info "Hyprland : fichiers locaux conservés, aucun lien vers le dépôt."
            continue
        fi
        link "$d" "$HOME/.config/$(basename "$d")"
    done
    for d in "$DOTFILES"/bin/*; do
        link "$d" "$HOME/.local/bin/$(basename "$d")"
    done
    for d in "$DOTFILES"/applications/*.desktop; do
        link "$d" "$HOME/.local/share/applications/$(basename "$d")"
    done
    if command -v update-desktop-database >/dev/null; then
        update-desktop-database "$HOME/.local/share/applications" \
            || warn "Cache des lanceurs non actualisé."
    fi
}

# ── Nexus (Rust + GTK, dépôt séparé) ─────────────────────────────────────────
NEXUS_REPO="https://github.com/Vitrixxl/nexus.git"
install_nexus() {
    local dir="${NEXUS_SOURCE:-$HOME/.local/src/nexus}"
    if [ -d "$dir/.git" ]; then
        git -C "$dir" pull --ff-only --quiet || warn "Nexus : version locale conservée."
    else
        mkdir -p "$(dirname "$dir")"
        git clone --depth 1 "$NEXUS_REPO" "$dir"
    fi
    info "Compilation et installation de Nexus"
    (cd "$dir" && ./install.sh)
    command -v nmcli >/dev/null || warn "Le Wi-Fi de Nexus nécessite NetworkManager."
}

[ "$do_deps"  = 1 ] && { install_deps; setup_audio; setup_network; setup_ly; setup_docker; }
[ "$do_links" = 1 ] && { install_links; setup_cursor; }
[ "$do_build" = 1 ] && install_nexus

if [ "$do_deps" = 1 ]; then
    info "NVIDIA : après la première installation du pilote, redémarre puis vérifie nvidia-smi."
fi

# ── Rappels ──────────────────────────────────────────────────────────────────
echo
[ -f "$HOME/Wallpapers/window-view-2560.mp4" ] || warn "Fond d'écran absent : ~/Wallpapers/window-view-2560.mp4 (lancé par mpvpaper)."
case "$(getent passwd "$USER" | cut -d: -f7)" in
    */fish) ;;
    *) warn "Shell de login différent de fish : chsh -s $(command -v fish || echo /usr/bin/fish)" ;;
esac
info "Terminé. Les plugins Neovim s'installent au premier lancement de nvim."
