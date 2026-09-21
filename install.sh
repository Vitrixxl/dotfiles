#!/usr/bin/env bash
# Installe les dépendances de ces dotfiles et pose les symlinks.
# Cible : Arch Linux (fonctionne aussi sur Artix).
#
#   ./install.sh              tout faire
#   ./install.sh --no-deps    ne pas installer de paquets
#   ./install.sh --no-links   ne pas toucher aux symlinks
#   ./install.sh --no-build   ne pas compiler hypr-screenshot ni wifi-gui
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
# Sur Arch, seuls mpvpaper et les polices Geist viennent de l'AUR.
# "a|b" : a s'il existe dans les dépôts (Arch), sinon b depuis l'AUR (Artix).
PACKAGES=(
    # Session Hyprland
    hyprland hyprlock hyprsunset hyprtoolkit
    xdg-desktop-portal xdg-desktop-portal-gtk
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
    # Compilation de hypr-screenshot et wifi-gui
    rust
    # wifi-gui : nmcli, rendu gpui (Vulkan, ici iGPU Intel), lib requise à l'édition de liens
    networkmanager vulkan-intel libxkbcommon-x11
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

# ── wifi-gui (Rust, gpui) ────────────────────────────────────────────────────
build_wifi_gui() {
    local dir="$DOTFILES/wifi-gui" bin="$HOME/.local/bin/wifi-gui" cargo
    cargo="$(command -v cargo || true)"
    [ -z "$cargo" ] && [ -x "$HOME/.cargo/bin/cargo" ] && cargo="$HOME/.cargo/bin/cargo"
    if [ -x "$bin" ] && [ "$bin" -nt "$dir/src/main.rs" ] && [ "$bin" -nt "$dir/src/nm.rs" ]; then
        info "wifi-gui est à jour."
        return
    fi
    [ -z "$cargo" ] && { warn "cargo introuvable : wifi-gui non compilé."; return; }
    info "Compilation de wifi-gui (la première fois, gpui prend quelques minutes)"
    (cd "$dir" && "$cargo" build --release --locked)
    install -Dm755 "$dir/target/release/wifi-gui" "$bin"
}

[ "$do_deps"  = 1 ] && { install_deps; setup_audio; }
[ "$do_links" = 1 ] && install_links
[ "$do_build" = 1 ] && { build_screenshot; build_wifi_gui; }

# ── Rappels ──────────────────────────────────────────────────────────────────
echo
[ -f "$HOME/Wallpapers/window-view-2560.mp4" ] || warn "Fond d'écran absent : ~/Wallpapers/window-view-2560.mp4 (lancé par mpvpaper)."
case "$(getent passwd "$USER" | cut -d: -f7)" in
    */fish) ;;
    *) warn "Shell de login différent de fish : chsh -s $(command -v fish || echo /usr/bin/fish)" ;;
esac
info "Terminé. Les plugins Neovim s'installent au premier lancement de nvim."
