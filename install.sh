#!/usr/bin/env bash
# Installe les dépendances de ces dotfiles et pose les symlinks.
# Cible : Arch Linux (fonctionne aussi sur Artix).
#
#   ./install.sh              tout faire
#   ./install.sh --no-deps    ne pas installer de paquets
#   ./install.sh --no-links   ne pas toucher aux symlinks
#   ./install.sh --no-build   ne pas compiler hypr-screenshot ni installer wifi-gui
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
    # Terminal, shell, launcher, notifications, fichiers
    foot fish fuzzel mako libnotify thunar btop fastfetch
    # Audio, touches média, luminosité
    pipewire pipewire-pulse wireplumber playerctl brightnessctl
    # Fond d'écran animé
    mpv mpvpaper
    # Captures et enregistrement d'écran (hypr-helper, hypr-screenshot, niri-record)
    jq grim slurp wl-clipboard wf-recorder
    # Neovim : plugins (git), treesitter (tree-sitter-cli + gcc), LSP (ceux de Vue passent par bun)
    neovim git gcc tree-sitter-cli ripgrep fd
    go gopls "bun|bun-bin" "lua-language-server|lua-language-server-git"
    # Conteneurs : moteur Docker, Compose et Buildx
    docker docker-compose docker-buildx
    # Compilation de hypr-screenshot et wifi-gui
    rust
    # wifi-gui : pilote Vulkan pour gpui (ici iGPU Intel) ; le reste est déclaré dans son PKGBUILD
    vulkan-intel
    # Curseur, icônes, polices (le thème Arc n'est pas installé : GTK retombe sur Adwaita sombre)
    breeze-cursors adwaita-icon-theme adwaita-fonts
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

install_deps() {
    command -v pacman >/dev/null || { warn "pacman introuvable : installe les paquets à la main."; return; }
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
        elif [ "$name" = gopls ]; then                 # paquet sur Arch, go install sinon
            if command -v gopls >/dev/null || [ -x "$(go env GOPATH 2>/dev/null)/bin/gopls" ]; then continue; fi
            if pacman -Si gopls >/dev/null 2>&1; then todo+=(gopls); else need_go_gopls=1; fi
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

install_links() {
    local d
    for d in "$DOTFILES"/config/*; do
        if [ "$(basename "$d")" = pipewire ] && has_systemd; then
            continue                                   # config réservée aux systèmes sans systemd
        fi
        link "$d" "$HOME/.config/$(basename "$d")"
    done
    for d in "$DOTFILES"/bin/*; do
        link "$d" "$HOME/.local/bin/$(basename "$d")"
    done
    link "$DOTFILES/hypr-screenshot" "$HOME/.local/share/hypr-screenshot"
    for d in "$DOTFILES"/applications/*.desktop; do
        link "$d" "$HOME/.local/share/applications/$(basename "$d")"
    done
    if command -v update-desktop-database >/dev/null; then
        update-desktop-database "$HOME/.local/share/applications" \
            || warn "Cache des lanceurs non actualisé."
    fi
}

# ── hypr-screenshot (Rust) ───────────────────────────────────────────────────
build_screenshot() {
    local dir="$DOTFILES/hypr-screenshot" cargo
    cargo="$(command -v cargo || true)"
    [ -z "$cargo" ] && [ -x "$HOME/.cargo/bin/cargo" ] && cargo="$HOME/.cargo/bin/cargo"
    if [ -x "$dir/hypr-screenshot-native" ] && [ "$dir/hypr-screenshot-native" -nt "$dir/native/src/main.rs" ] \
        && [ "$dir/hypr-screenshot-native" -nt "$dir/native/src/gpu.rs" ]; then
        info "hypr-screenshot est à jour."
        return
    fi
    [ -z "$cargo" ] && { warn "cargo introuvable : hypr-screenshot non compilé."; return; }
    info "Compilation de hypr-screenshot"
    (cd "$dir/native" && "$cargo" build --release --locked)
    install -m755 "$dir/native/target/release/hypr-screenshot-native" "$dir/hypr-screenshot-native"
}

# ── wifi-gui (dépôt séparé, installé comme paquet pacman) ────────────────────
WIFI_GUI_REPO="https://github.com/Vitrixxl/wifi-gui.git"
install_wifi_gui() {
    local dir="$HOME/.local/src/wifi-gui" before="" after
    command -v makepkg >/dev/null || { warn "makepkg introuvable : wifi-gui non installé."; return; }
    if [ -d "$dir/.git" ]; then
        before="$(git -C "$dir" rev-parse HEAD)"
        git -C "$dir" pull --ff-only --quiet || warn "wifi-gui : mise à jour impossible, version locale conservée."
    else
        info "Récupération de wifi-gui"
        mkdir -p "$(dirname "$dir")"
        git clone --depth 1 "$WIFI_GUI_REPO" "$dir" || { warn "wifi-gui : clone impossible."; return; }
    fi
    after="$(git -C "$dir" rev-parse HEAD)"
    if [ "$before" = "$after" ] && pacman -Qq wifi-gui-git >/dev/null 2>&1; then
        info "wifi-gui est à jour."
        return
    fi
    info "Compilation de wifi-gui (la première fois, gpui prend quelques minutes)"
    (cd "$dir/arch" && makepkg -sif --noconfirm)
    # Une ancienne installation manuelle masquerait /usr/bin dans le PATH.
    rm -f "$HOME/.local/bin/wifi-gui" "$HOME/.local/bin/wifi-guid"
    wifi-gui quit 2>/dev/null || true                  # le daemon repartira sur la nouvelle version
}

[ "$do_deps"  = 1 ] && { install_deps; setup_audio; setup_ly; setup_docker; }
[ "$do_links" = 1 ] && install_links
[ "$do_build" = 1 ] && { build_screenshot; install_wifi_gui; }

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
