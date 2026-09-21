-- Config Hyprland (format Lua natif, Hyprland ≥ 0.55).
-- Traduction de ~/.config/niri/config.kdl, sans les binds molette pour changer
-- de workspace. Recharger : hyprctl reload

local mod    = "SUPER"
local shift  = "SUPER + SHIFT"
local ctrl   = "SUPER + CTRL"
local mctrl  = "SUPER + SHIFT + CTRL"

local term   = "foot"
local menu   = "pkill -x fuzzel || fuzzel"   -- bascule : un second appui referme
local helper = "~/.local/bin/hypr-helper"

local function key(mods, k) return mods .. " + " .. k end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end

-- Flèches puis touches vim : les deux jeux reçoivent les mêmes binds.
local arrows = { { "Left", "l" }, { "Down", "d" }, { "Up", "u" }, { "Right", "r" } }
local vimish = { { "H", "l" }, { "J", "d" }, { "K", "u" }, { "L", "r" } }

local function directions(fn)
    for _, p in ipairs(arrows) do fn(p[1], p[2]) end
    for _, p in ipairs(vimish) do fn(p[1], p[2]) end
end

-- ── Moniteurs ────────────────────────────────────────────────────────────────
hl.monitor({ output = "eDP-1",    mode = "2560x1600@240", position = "0x0",        scale = 1.25 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@144", position = "auto-right", scale = 1 })
hl.monitor({ output = "",         mode = "preferred",     position = "auto",       scale = 1 })

-- ── Environnement ────────────────────────────────────────────────────────────
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

hl.config({
    xwayland = {
        enabled = true,
        -- Apps X11 rendues à l'échelle 1 puis agrandies par Hyprland : évite le flou et
        -- les fenêtres mal dimensionnées avec le scale 1.25 (AnyDesk, etc.).
        force_zero_scaling = true,
    },
})

-- ── Démarrage ────────────────────────────────────────────────────────────────
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

hl.on("hyprland.start", function()
    hl.exec_cmd("pipewire")
    hl.exec_cmd("waybar")
    hl.exec_cmd(('mpvpaper -p -a MAX -o "%s" "*" "$HOME/Wallpapers/window-view-2560.mp4"'):format(mpv_opts))
    hl.exec_cmd("hyprsunset")
end)

-- ── Entrées ──────────────────────────────────────────────────────────────────
hl.config({
    input = {
        kb_layout          = "fr",
        numlock_by_default = true,
        follow_mouse       = 1,
        touchpad = {
            tap_to_click   = true,
            natural_scroll = true,
        },
    },
})

-- Gestes touchpad : balayage horizontal à 3 doigts = changer de workspace
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- ── Apparence (niri : gaps 0, focus-ring off, border off, coins carrés) ──────
hl.config({
    general = {
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 0,
        layout      = "dwindle",
    },
    decoration = {
        rounding = 0,
        shadow   = { enabled = false },
        blur     = { enabled = false },
    },
    animations = { enabled = true },
    dwindle    = { preserve_split = true },
    misc = {
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
    },
})

hl.curve("quick", { type = "bezier", points = { { 0.2, 0.8 }, { 0.2, 1.0 } } })
hl.animation({ leaf = "global",     enabled = true,  speed = 2,   bezier = "quick" })
hl.animation({ leaf = "windows",    enabled = true,  speed = 2,   bezier = "quick", style = "popin 90%" })
hl.animation({ leaf = "fade",       enabled = true,  speed = 1.5, bezier = "quick" })
hl.animation({ leaf = "workspaces", enabled = true,  speed = 2,   bezier = "quick", style = "slide" })
hl.animation({ leaf = "border",     enabled = false })
hl.animation({ leaf = "layers",     enabled = true,  speed = 1.5, bezier = "quick", style = "fade" })

-- ── Règles de fenêtres ───────────────────────────────────────────────────────
hl.window_rule({
    name  = "firefox-pip",
    match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" },
    float = true,
})
hl.window_rule({
    name    = "foot-opacity",
    match   = { class = "^(foot)$" },
    opacity = "0.9 0.9",
})
-- Spotify (web-app Brave) toujours sur le workspace S (11)
hl.window_rule({
    name      = "spotify-ws",
    match     = { class = "^(brave-pjibgclleladliembfgfagdaldikeohf-Default)$" },
    workspace = "11",
})

-- ── Binds ────────────────────────────────────────────────────────────────────
-- Apps
hl.bind(key(mod, "Return"), run(term))
hl.bind(key(mod, "D"),      run(menu))
hl.bind(key(mod, "Space"),  run(menu))
hl.bind(key(mod, "E"),      run("thunar"))
hl.bind("SUPER + ALT + L",  run("hyprlock"))
hl.bind("SUPER + ALT + S",  run("pkill orca || exec orca"), { locked = true })

-- Média / luminosité (fonctionnent écran verrouillé)
local lockrep = { locked = true, repeating = true }
local lock    = { locked = true }
hl.bind("XF86AudioRaiseVolume", run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"), lockrep)
hl.bind("XF86AudioLowerVolume", run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"),        lockrep)
hl.bind("XF86AudioMute",        run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),        lock)
hl.bind("XF86AudioMicMute",     run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),      lock)
for _, p in ipairs({ { "Play", "play-pause" }, { "Stop", "stop" }, { "Prev", "previous" }, { "Next", "next" } }) do
    hl.bind("XF86Audio" .. p[1], run("playerctl " .. p[2]), lock)
end
hl.bind("XF86MonBrightnessUp",   run("brightnessctl --class=backlight set +10%"), lockrep)
hl.bind("XF86MonBrightnessDown", run("brightnessctl --class=backlight set 10%-"), lockrep)

-- Fenêtres
hl.bind(key(mod, "C"), hl.dsp.window.close())
-- hl.bind(key(mod, "O"), hl.dsp.layout("overview:toggle"))   -- nécessite le plugin hyprexpo

-- Focus (niri : gauche/droite = colonnes, haut/bas = fenêtres de la colonne)
directions(function(k, dir) hl.bind(key(mod, k), hl.dsp.focus({ direction = dir })) end)

-- Déplacer (Shift+Bas/Haut : dans la colonne sinon vers le workspace suivant)
directions(function(k, dir)
    if dir == "d" then
        hl.bind(key(shift, k), run(helper .. " move-or-ws down"))
    elseif dir == "u" then
        hl.bind(key(shift, k), run(helper .. " move-or-ws up"))
    else
        hl.bind(key(shift, k), hl.dsp.window.move({ direction = dir }))
    end
end)

-- Première / dernière colonne
hl.bind(key(mod,  "Home"), run(helper .. " focus first"))
hl.bind(key(mod,  "End"),  run(helper .. " focus last"))
hl.bind(key(ctrl, "Home"), run(helper .. " move first"))
hl.bind(key(ctrl, "End"),  run(helper .. " move last"))

-- Moniteurs
directions(function(k, dir) hl.bind(key(ctrl,  k), hl.dsp.focus({ monitor = dir })) end)
directions(function(k, dir) hl.bind(key(mctrl, k), hl.dsp.window.move({ monitor = dir })) end)

-- Workspaces relatifs (r± = sur le moniteur courant, crée un workspace vide au bout comme niri)
local relws = { { "Page_Down", "r+1" }, { "Page_Up", "r-1" }, { "U", "r+1" }, { "I", "r-1" } }
for _, p in ipairs(relws) do hl.bind(key(mod,  p[1]), hl.dsp.focus({ workspace = p[2] })) end
for _, p in ipairs(relws) do hl.bind(key(ctrl, p[1]), hl.dsp.window.move({ workspace = p[2] })) end
-- niri move-workspace-down/up (réordonner les workspaces) : pas d'équivalent Hyprland.

-- Molette : pas de changement de workspace. Seulement le focus colonne.
hl.bind(key(shift, "mouse_down"), hl.dsp.focus({ direction = "r" }))
hl.bind(key(shift, "mouse_up"),   hl.dsp.focus({ direction = "l" }))
hl.bind(key(mctrl, "mouse_down"), hl.dsp.window.move({ direction = "r" }))
hl.bind(key(mctrl, "mouse_up"),   hl.dsp.window.move({ direction = "l" }))

-- Workspaces numérotés (clavier fr)
local ws_keys = {
    "ampersand", "eacute", "quotedbl", "apostrophe", "parenleft",
    "minus", "egrave", "underscore", "ccedilla",
}
for i, k in ipairs(ws_keys) do hl.bind(key(mod, k), hl.dsp.focus({ workspace = i })) end
hl.bind(key(mod, "G"), hl.dsp.focus({ workspace = 10 }))
hl.bind(key(mod, "S"), hl.dsp.focus({ workspace = 11 }))
for i, k in ipairs(ws_keys) do hl.bind(key(shift, k), hl.dsp.window.move({ workspace = i })) end
hl.bind(key(shift, "G"), hl.dsp.window.move({ workspace = 10 }))

-- Colonnes niri ≈ groupes Hyprland (onglets)
hl.bind(key(mod, "bracketleft"),  hl.dsp.window.move({ direction = "l", group_aware = true }))
hl.bind(key(mod, "bracketright"), hl.dsp.window.move({ direction = "r", group_aware = true }))
hl.bind(key(mod, "comma"),        hl.dsp.window.move({ into_group = "l" }))
hl.bind(key(mod, "period"),       hl.dsp.window.move({ out_of_group = true }))
hl.bind(key(mod, "W"),            hl.dsp.group.toggle())

-- Tailles
hl.bind(key(mod,   "R"), run(helper .. " preset width"))
hl.bind(key(mctrl, "R"), run(helper .. " preset height"))
hl.bind(key(ctrl,  "R"), run(helper .. " preset height reset"))
hl.bind(key(mod,   "F"), hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(key(shift, "F"), hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(key(mod,   "M"), hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(key(ctrl,  "F"), hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(key(ctrl,  "C"), hl.dsp.window.center())

-- resize ne prend que des pixels : on calcule ±10 % de la taille courante.
local function resize_pct(px, py)
    return function()
        local w = hl.get_active_window()
        if not w then return end
        hl.dispatch(hl.dsp.window.resize({
            x = math.floor(w.size.x * px),
            y = math.floor(w.size.y * py),
            relative = true,
        }))
    end
end
hl.bind(key(mod,   "parenright"), resize_pct(-0.1, 0))
hl.bind(key(mod,   "equal"),      resize_pct(0.1, 0))
hl.bind(key(shift, "parenright"), resize_pct(0, -0.1))
hl.bind(key(shift, "equal"),      resize_pct(0, 0.1))

-- Flottant
hl.bind(key(mod,   "V"), hl.dsp.window.float())
hl.bind(key(shift, "V"), run(helper .. " swap-floating-focus"))

-- Captures
hl.bind("Print",         run("~/.local/bin/hypr-screenshot --live --save"))
hl.bind("CTRL + Print",  run("~/.local/bin/hypr-screenshot screen-to-disk"))
hl.bind("ALT + Print",   run("~/.local/bin/hypr-screenshot window-to-disk"))
hl.bind(key(shift, "S"), run("~/.local/bin/hypr-screenshot"))
hl.bind(key(shift, "R"), run("~/.local/bin/niri-record"))

-- Passthrough (≈ toggle-keyboard-shortcuts-inhibit) : Mod+Escape pour entrer/sortir
hl.bind(key(mod, "Escape"), hl.dsp.submap("passthrough"))
hl.define_submap("passthrough", function()
    hl.bind(key(mod, "Escape"), hl.dsp.submap("reset"))
end)

-- ── Session ──────────────────────────────────────────────────────────────────
hl.bind(key(shift, "E"),     hl.dsp.exit())
hl.bind("CTRL + ALT + Delete", hl.dsp.exit())
-- dpms directement dans un bind = comportement indéfini (wiki) : passer par un timer.
hl.bind(key(shift, "P"), function()
    hl.timer(function()
        hl.dispatch(hl.dsp.dpms({ action = "disable" }))
    end, { timeout = 500, type = "oneshot" })
end)

-- Souris
hl.bind(key(mod, "mouse:272"), hl.dsp.window.drag(),   { mouse = true })
hl.bind(key(mod, "mouse:273"), hl.dsp.window.resize(), { mouse = true })
