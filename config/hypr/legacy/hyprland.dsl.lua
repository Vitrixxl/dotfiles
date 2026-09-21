-- Config Hyprland — source de vérité. Régénérer : lua ~/.config/hypr/build.lua
-- Traduction de ~/.config/niri/config.kdl, sans les binds molette pour changer
-- de workspace.

local mod    = "$mod"
local shift  = "$mod SHIFT"
local ctrl   = "$mod CTRL"
local mctrl  = "$mod SHIFT CTRL"

-- Flèches puis touches vim : les deux jeux reçoivent les mêmes binds.
local arrows = { { "Left", "l" }, { "Down", "d" }, { "Up", "u" }, { "Right", "r" } }
local vimish = { { "H", "l" }, { "J", "d" }, { "K", "u" }, { "L", "r" } }

local function directions(fn)
    for _, p in ipairs(arrows) do fn(p[1], p[2]) end
    for _, p in ipairs(vimish) do fn(p[1], p[2]) end
end

var("mod", "SUPER")
var("term", "foot")
var("menu", "fuzzel")
var("helper", "~/.local/bin/hypr-helper")
blank()

header("Moniteurs")
kw("monitor", "eDP-1", "2560x1600@240", "0x0", 1.25)
kw("monitor", "HDMI-A-1", "1920x1080@144", "auto-right", 1)
kw("monitor", "", "preferred", "auto", 1)
blank()

header("Environnement")
env("XDG_CURRENT_DESKTOP", "Hyprland")
env("XDG_SESSION_TYPE", "wayland")
env("XDG_SESSION_DESKTOP", "Hyprland")
env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
env("QT_QPA_PLATFORM", "wayland;xcb")
env("QT_WAYLAND_DISABLE_WINDOWDECORATION", 1)
blank()

section("xwayland", function()
    set("enabled", true)
    comment("Apps X11 rendues à l'échelle 1 puis agrandies par Hyprland : évite le flou et")
    comment("les fenêtres mal dimensionnées avec le scale 1.25 (AnyDesk, etc.).")
    set("force_zero_scaling", true)
end)
blank()

header("Démarrage")
-- Wallpaper vidéo : fichier déjà à la résolution de l'écran et à 30 fps, décodage
-- matériel, composition déléguée à Hyprland (dmabuf) et pause dès qu'une fenêtre
-- est maximisée ou plein écran. Sans ça l'iGPU monte à ~70 %.
local mpv_opts = table.concat({
    "no-audio",
    "loop",
    "panscan=1.0",
    "hwdec=auto-safe",
    "profile=fast",
}, " ")
set("exec-once", "pipewire")
set("exec-once", "waybar")
set("exec-once", ('mpvpaper -p -a MAX -o "%s" "*" "$HOME/Wallpapers/window-view-2560.mp4"')
    :format(mpv_opts))
set("exec-once", "hyprsunset")
blank()

header("Entrées")
section("input", function()
    set("kb_layout", "fr")
    set("numlock_by_default", true)
    set("follow_mouse", 1)
    section("touchpad", function()
        set("tap-to-click", true)
        set("natural_scroll", true)
    end)
end)
blank()
comment("Gestes touchpad : balayage horizontal à 3 doigts = changer de workspace")
kw("gesture", 3, "horizontal", "workspace")
blank()

header("Apparence (niri : gaps 0, focus-ring off, border off, coins carrés)")
section("general", function()
    set("gaps_in", 0)
    set("gaps_out", 0)
    set("border_size", 0)
    set("layout", "dwindle")
end)
blank()

section("decoration", function()
    set("rounding", 0)
    section("shadow", function() set("enabled", false) end)
    section("blur", function() set("enabled", false) end)
end)
blank()

section("animations", function()
    set("enabled", true)
    kw("bezier", "quick", 0.2, 0.8, 0.2, "1.0")
    kw("animation", "global", 1, 2, "quick")
    kw("animation", "windows", 1, 2, "quick", "popin 90%")
    kw("animation", "fade", 1, 1.5, "quick")
    kw("animation", "workspaces", 1, 2, "quick", "slide")
    kw("animation", "border", 0)
    kw("animation", "layers", 1, 1.5, "quick", "fade")
end)
blank()

section("dwindle", function() set("preserve_split", true) end)
blank()

section("misc", function()
    set("disable_hyprland_logo", true)
    set("disable_splash_rendering", true)
    set("force_default_wallpaper", 0)
end)
blank()

header("Règles de fenêtres")
kw("windowrule", "float on", "match:class ^(firefox)$", "match:title ^(Picture-in-Picture)$")
kw("windowrule", "opacity 0.9 0.9", "match:class ^(foot)$")
blank()

header("Binds")
comment("Apps")
bind(mod, "Return", "exec", "$term")
bind(mod, "D", "exec", "$menu")
bind(mod, "Space", "exec", "$menu")
bind(mod, "E", "exec", "thunar")
bind("$mod ALT", "L", "exec", "hyprlock")
bindl("$mod ALT", "S", "exec", "pkill orca || exec orca")
blank()

comment("Média / luminosité (fonctionnent écran verrouillé)")
bindel("", "XF86AudioRaiseVolume", "exec", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0")
bindel("", "XF86AudioLowerVolume", "exec", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-")
bindl("", "XF86AudioMute", "exec", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
bindl("", "XF86AudioMicMute", "exec", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
for _, p in ipairs({ { "Play", "play-pause" }, { "Stop", "stop" }, { "Prev", "previous" }, { "Next", "next" } }) do
    bindl("", "XF86Audio" .. p[1], "exec", "playerctl " .. p[2])
end
bindel("", "XF86MonBrightnessUp", "exec", "brightnessctl --class=backlight set +10%")
bindel("", "XF86MonBrightnessDown", "exec", "brightnessctl --class=backlight set 10%-")
blank()

comment("Fenêtres")
bind(mod, "C", "killactive")
comment("bind = $mod, O, overview:toggle   # nécessite le plugin hyprexpo")
blank()

comment("Focus (niri : gauche/droite = colonnes, haut/bas = fenêtres de la colonne)")
directions(function(key, dir) bind(mod, key, "movefocus", dir) end)
blank()

comment("Déplacer (Shift+Bas/Haut : dans la colonne sinon vers le workspace suivant)")
directions(function(key, dir)
    if dir == "d" then
        bind(shift, key, "exec", "$helper move-or-ws down")
    elseif dir == "u" then
        bind(shift, key, "exec", "$helper move-or-ws up")
    else
        bind(shift, key, "movewindow", dir)
    end
end)
blank()

comment("Première / dernière colonne")
bind(mod, "Home", "exec", "$helper focus first")
bind(mod, "End", "exec", "$helper focus last")
bind(ctrl, "Home", "exec", "$helper move first")
bind(ctrl, "End", "exec", "$helper move last")
blank()

comment("Moniteurs")
directions(function(key, dir) bind(ctrl, key, "focusmonitor", dir) end)
directions(function(key, dir) bind(mctrl, key, "movewindow", "mon:" .. dir) end)
blank()

comment("Workspaces relatifs (r± = sur le moniteur courant, crée un workspace vide au bout comme niri)")
for _, p in ipairs({ { "Page_Down", "r+1" }, { "Page_Up", "r-1" }, { "U", "r+1" }, { "I", "r-1" } }) do
    bind(mod, p[1], "workspace", p[2])
end
for _, p in ipairs({ { "Page_Down", "r+1" }, { "Page_Up", "r-1" }, { "U", "r+1" }, { "I", "r-1" } }) do
    bind(ctrl, p[1], "movetoworkspace", p[2])
end
comment("niri move-workspace-down/up (réordonner les workspaces) : pas d'équivalent Hyprland.")
blank()

comment("Molette : pas de changement de workspace. Seulement le focus colonne.")
bind(shift, "mouse_down", "movefocus", "r")
bind(shift, "mouse_up", "movefocus", "l")
bind("$mod CTRL SHIFT", "mouse_down", "movewindow", "r")
bind("$mod CTRL SHIFT", "mouse_up", "movewindow", "l")
blank()

comment("Workspaces numérotés (clavier fr)")
local ws_keys = {
    "ampersand", "eacute", "quotedbl", "apostrophe", "parenleft",
    "minus", "egrave", "underscore", "ccedilla",
}
for i, key in ipairs(ws_keys) do bind(mod, key, "workspace", i) end
bind(mod, "G", "workspace", 10)
bind(mod, "S", "workspace", 11)
for i, key in ipairs(ws_keys) do bind(shift, key, "movetoworkspace", i) end
bind(shift, "G", "movetoworkspace", 10)
blank()

comment("Colonnes niri ≈ groupes Hyprland (onglets)")
bind(mod, "bracketleft", "movewindoworgroup", "l")
bind(mod, "bracketright", "movewindoworgroup", "r")
bind(mod, "comma", "moveintogroup", "l")
bind(mod, "period", "moveoutofgroup")
bind(mod, "W", "togglegroup")
blank()

comment("Tailles")
bind(mod, "R", "exec", "$helper preset width")
bind(mctrl, "R", "exec", "$helper preset height")
bind(ctrl, "R", "exec", "$helper preset height reset")
bind(mod, "F", "fullscreen", 1)
bind(shift, "F", "fullscreen", 0)
bind(mod, "M", "fullscreen", 1)
bind(ctrl, "F", "fullscreen", 1)
bind(ctrl, "C", "centerwindow")
bind(mod, "parenright", "resizeactive", "-10% 0")
bind(mod, "equal", "resizeactive", "10% 0")
bind(shift, "parenright", "resizeactive", "0 -10%")
bind(shift, "equal", "resizeactive", "0 10%")
blank()

comment("Flottant")
bind(mod, "V", "togglefloating")
bind(shift, "V", "exec", "$helper swap-floating-focus")
blank()

comment("Captures")
bind("", "Print", "exec", "~/.local/bin/hypr-screenshot --live --save")
bind("CTRL", "Print", "exec", "~/.local/bin/hypr-screenshot screen-to-disk")
bind("ALT", "Print", "exec", "~/.local/bin/hypr-screenshot window-to-disk")
bind(shift, "S", "exec", "~/.local/bin/hypr-screenshot")
bind(shift, "R", "exec", "~/.local/bin/niri-record")
blank()

comment("Passthrough (≈ toggle-keyboard-shortcuts-inhibit) : Mod+Escape pour entrer/sortir")
bind(mod, "Escape", "submap", "passthrough")
submap("passthrough", function()
    bind(mod, "Escape", "submap", "reset")
end)
blank()

header("Session")
bind(shift, "E", "exit")
bind("CTRL ALT", "Delete", "exit")
bind(shift, "P", "dpms", "off")
blank()

comment("Souris")
bindm(mod, "mouse:272", "movewindow")
bindm(mod, "mouse:273", "resizewindow")
