//! wifi-gui — petite fenêtre gpui pour lister les réseaux Wi-Fi et s'y connecter.
//! Palette et typo reprises de config/hypr/hyprtoolkit.conf.

mod nm;

use std::time::Duration;

use gpui::{
    div, prelude::*, px, rgb, size, App, Application, Bounds, Context, FocusHandle,
    FontWeight, KeyDownEvent, Rgba, SharedString, Window, WindowBounds, WindowDecorations,
    WindowOptions,
};
use nm::Network;

const REFRESH_EVERY: Duration = Duration::from_secs(10);

fn bg() -> Rgba { rgb(0x0f1115) }
fn base() -> Rgba { rgb(0x161920) }
fn selection() -> Rgba { rgb(0x1c2029) }
fn text() -> Rgba { rgb(0xe6e9ef) }
fn bright() -> Rgba { rgb(0xffffff) }
fn muted() -> Rgba { rgb(0x6b7280) }
fn dim() -> Rgba { rgb(0x2a2f3a) }
fn accent() -> Rgba { rgb(0x7fc8ff) }
fn danger() -> Rgba { rgb(0xf07178) }

struct WifiApp {
    focus: FocusHandle,
    state: nm::State,
    loaded: bool,
    scanning: bool,
    /// SSID de la ligne dépliée.
    selected: Option<String>,
    password: String,
    reveal: bool,
    /// Libellé de l'action nmcli en cours ; bloque les autres actions.
    busy: Option<SharedString>,
    error: Option<SharedString>,
}

impl WifiApp {
    fn new(cx: &mut Context<Self>) -> Self {
        let mut this = Self {
            focus: cx.focus_handle(),
            state: nm::State::default(),
            loaded: false,
            scanning: false,
            selected: None,
            password: String::new(),
            reveal: false,
            busy: None,
            error: None,
        };
        this.refresh(true, cx);
        cx.spawn(async move |this, cx| loop {
            cx.background_executor().timer(REFRESH_EVERY).await;
            if this.update(cx, |this, cx| this.refresh(false, cx)).is_err() {
                break;
            }
        })
        .detach();
        this
    }

    fn refresh(&mut self, rescan: bool, cx: &mut Context<Self>) {
        if self.scanning || self.busy.is_some() {
            return;
        }
        self.scanning = true;
        cx.notify();
        cx.spawn(async move |this, cx| {
            let result = cx.background_executor().spawn(async move { nm::scan(rescan) }).await;
            this.update(cx, |this, cx| {
                this.scanning = false;
                this.loaded = true;
                match result {
                    Ok(state) => this.state = state,
                    Err(e) => this.error = Some(e.into()),
                }
                cx.notify();
            })
            .ok();
        })
        .detach();
    }

    /// Lance une action nmcli en arrière-plan puis rafraîchit la liste.
    fn run(
        &mut self,
        label: impl Into<SharedString>,
        cx: &mut Context<Self>,
        action: impl FnOnce() -> Result<(), String> + Send + 'static,
    ) {
        if self.busy.is_some() {
            return;
        }
        self.busy = Some(label.into());
        self.error = None;
        cx.notify();
        cx.spawn(async move |this, cx| {
            let result = cx.background_executor().spawn(async move { action() }).await;
            this.update(cx, |this, cx| {
                this.busy = None;
                match result {
                    Ok(()) => this.select(None),
                    Err(e) => this.error = Some(e.into()),
                }
                this.refresh(false, cx);
            })
            .ok();
        })
        .detach();
    }

    fn select(&mut self, ssid: Option<String>) {
        if self.selected != ssid {
            self.selected = ssid;
            self.password.clear();
            self.reveal = false;
        }
    }

    fn selected_network(&self) -> Option<&Network> {
        let ssid = self.selected.as_ref()?;
        self.state.networks.iter().find(|n| &n.ssid == ssid)
    }

    fn needs_password(net: &Network) -> bool {
        !net.in_use && net.profile.is_none() && !net.is_open() && !net.is_enterprise()
    }

    fn password_ok(&self, net: &Network) -> bool {
        // WPA-PSK : 8 à 63 caractères. Pour le WEP on laisse nmcli trancher.
        !Self::needs_password(net) || net.security.contains("WEP") || self.password.len() >= 8
    }

    fn move_selection(&mut self, delta: isize) {
        let nets = &self.state.networks;
        if nets.is_empty() {
            return;
        }
        let current = self.selected.as_ref().and_then(|s| nets.iter().position(|n| &n.ssid == s));
        let next = match current {
            Some(ix) => (ix as isize + delta).clamp(0, nets.len() as isize - 1) as usize,
            None => 0,
        };
        self.select(Some(nets[next].ssid.clone()));
    }

    fn connect_selected(&mut self, cx: &mut Context<Self>) {
        let Some(net) = self.selected_network().cloned() else { return };
        if net.in_use || net.is_enterprise() || !self.password_ok(&net) {
            return;
        }
        let password = Self::needs_password(&net).then(|| self.password.clone());
        self.run(format!("Connexion à {}…", net.ssid), cx, move || {
            nm::connect(&net, password.as_deref())
        });
    }

    fn disconnect(&mut self, cx: &mut Context<Self>) {
        let Some(iface) = self.state.iface.clone() else { return };
        self.run("Déconnexion…", cx, move || nm::disconnect(&iface));
    }

    fn forget_selected(&mut self, cx: &mut Context<Self>) {
        let Some(uuid) = self.selected_network().and_then(|n| n.profile.clone()) else { return };
        self.run("Suppression du profil…", cx, move || nm::forget(&uuid));
    }

    fn toggle_radio(&mut self, cx: &mut Context<Self>) {
        let on = !self.state.enabled;
        let label = if on { "Activation du Wi-Fi…" } else { "Désactivation du Wi-Fi…" };
        self.run(label, cx, move || nm::set_radio(on));
    }

    fn on_key(&mut self, event: &KeyDownEvent, _: &mut Window, cx: &mut Context<Self>) {
        let ks = &event.keystroke;
        let ctrl = ks.modifiers.control;
        let typing = self.selected_network().is_some_and(Self::needs_password);
        match ks.key.as_str() {
            "escape" if self.selected.is_some() => self.select(None),
            "escape" => cx.quit(),
            "down" => self.move_selection(1),
            "up" => self.move_selection(-1),
            "n" if ctrl => self.move_selection(1),
            "p" if ctrl => self.move_selection(-1),
            "r" if ctrl => self.refresh(true, cx),
            "enter" => self.connect_selected(cx),
            "backspace" if typing => drop(self.password.pop()),
            "u" if ctrl && typing => self.password.clear(),
            "v" if ctrl && typing => {
                if let Some(pasted) = cx.read_from_clipboard().and_then(|item| item.text()) {
                    self.password.extend(pasted.chars().filter(|c| !c.is_control()));
                }
            }
            _ if typing && !ctrl && !ks.modifiers.alt && !ks.modifiers.platform => {
                match &ks.key_char {
                    Some(typed) => self.password.extend(typed.chars().filter(|c| !c.is_control())),
                    None => return,
                }
            }
            _ => return,
        }
        cx.notify();
    }

    // ── Rendu ────────────────────────────────────────────────────────────────

    fn render_header(&self, cx: &mut Context<Self>) -> impl IntoElement {
        let enabled = self.state.enabled;
        let subtitle: SharedString = match (&self.state.iface, self.loaded) {
            (_, false) => "Recherche…".into(),
            (None, true) => "Aucune carte Wi-Fi".into(),
            (Some(iface), true) => iface.clone().into(),
        };
        div()
            .flex()
            .items_center()
            .justify_between()
            .px(px(22.))
            .pt(px(20.))
            .pb(px(14.))
            .child(
                div()
                    .flex()
                    .flex_col()
                    .child(
                        div()
                            .text_size(px(20.))
                            .font_weight(FontWeight::SEMIBOLD)
                            .text_color(bright())
                            .child("Wi-Fi"),
                    )
                    .child(div().text_size(px(11.)).text_color(muted()).child(subtitle)),
            )
            .child(
                div()
                    .flex()
                    .items_center()
                    .gap(px(12.))
                    .when(enabled, |el| {
                        el.child(
                            button("rescan", if self.scanning { "Scan…" } else { "Actualiser" }, false)
                                .on_click(cx.listener(|this, _, _, cx| this.refresh(true, cx))),
                        )
                    })
                    .when(self.state.iface.is_some(), |el| {
                        el.child(
                            div()
                                .id("radio")
                                .flex()
                                .items_center()
                                .w(px(38.))
                                .h(px(22.))
                                .px(px(3.))
                                .rounded_full()
                                .cursor_pointer()
                                .bg(if enabled { accent() } else { dim() })
                                .when(enabled, |el| el.justify_end())
                                .child(div().size(px(16.)).rounded_full().bg(if enabled {
                                    bg()
                                } else {
                                    muted()
                                }))
                                .on_click(cx.listener(|this, _, _, cx| this.toggle_radio(cx))),
                        )
                    }),
            )
    }

    fn render_network(&self, ix: usize, net: &Network, cx: &mut Context<Self>) -> impl IntoElement {
        let selected = self.selected.as_deref() == Some(net.ssid.as_str());
        let status: SharedString = if net.in_use {
            "Connecté".into()
        } else if net.profile.is_some() {
            "Enregistré".into()
        } else if net.is_open() {
            "Ouvert".into()
        } else {
            net.security.clone().into()
        };
        let ssid = net.ssid.clone();

        div()
            .flex()
            .flex_col()
            .rounded(px(8.))
            .when(selected, |el| el.bg(selection()))
            .child(
                div()
                    .id(("network", ix))
                    .flex()
                    .items_center()
                    .gap(px(14.))
                    .h(px(46.))
                    .px(px(12.))
                    .rounded(px(8.))
                    .cursor_pointer()
                    .hover(|el| el.bg(selection()))
                    .on_click(cx.listener(move |this, _, _, cx| {
                        let toggled = (this.selected.as_ref() != Some(&ssid)).then(|| ssid.clone());
                        this.select(toggled);
                        cx.notify();
                    }))
                    .child(signal_bars(net.bars(), net.in_use))
                    .child(
                        div()
                            .flex_1()
                            .overflow_hidden()
                            .whitespace_nowrap()
                            .text_ellipsis()
                            .text_color(if net.in_use { bright() } else { text() })
                            .when(net.in_use, |el| el.font_weight(FontWeight::MEDIUM))
                            .child(net.ssid.clone()),
                    )
                    .child(
                        div()
                            .text_size(px(11.))
                            .text_color(if net.in_use { accent() } else { muted() })
                            .child(status),
                    ),
            )
            .when(selected, |el| el.child(self.render_details(net, cx)))
    }

    fn render_details(&self, net: &Network, cx: &mut Context<Self>) -> impl IntoElement {
        let busy = self.busy.is_some();
        let panel = div().flex().flex_col().gap(px(10.)).px(px(12.)).pb(px(12.));

        if net.is_enterprise() && net.profile.is_none() {
            return panel.child(
                div()
                    .text_size(px(11.))
                    .text_color(muted())
                    .child("Réseau d'entreprise (802.1X) : à configurer avec nmtui ou nmcli."),
            );
        }

        let panel = panel.when(Self::needs_password(net), |el| {
            let shown: SharedString = if self.password.is_empty() {
                "Mot de passe".into()
            } else if self.reveal {
                self.password.clone().into()
            } else {
                "•".repeat(self.password.chars().count()).into()
            };
            el.child(
                div()
                    .flex()
                    .items_center()
                    .gap(px(8.))
                    .h(px(36.))
                    .px(px(12.))
                    .rounded(px(8.))
                    .bg(base())
                    .child(
                        div()
                            .flex()
                            .flex_1()
                            .items_center()
                            .overflow_hidden()
                            .whitespace_nowrap()
                            .when(self.password.is_empty(), |el| {
                                el.child(caret()).text_color(muted()).child(shown.clone())
                            })
                            .when(!self.password.is_empty(), |el| {
                                // Les puces de Geist sont minuscules à 13 px.
                                el.when(!self.reveal, |el| el.text_size(px(20.)))
                                    .child(shown.clone())
                                    .child(caret())
                            }),
                    )
                    .child(
                        div()
                            .id("reveal")
                            .text_size(px(11.))
                            .text_color(muted())
                            .cursor_pointer()
                            .hover(|el| el.text_color(text()))
                            .child(if self.reveal { "Masquer" } else { "Afficher" })
                            .on_click(cx.listener(|this, _, _, cx| {
                                this.reveal = !this.reveal;
                                cx.notify();
                            })),
                    ),
            )
        });

        let mut actions = div().flex().justify_end().gap(px(8.));
        if net.profile.is_some() {
            actions = actions.child(
                button("forget", "Oublier", false)
                    .on_click(cx.listener(|this, _, _, cx| this.forget_selected(cx))),
            );
        }
        actions = if net.in_use {
            actions.child(
                button("disconnect", "Se déconnecter", false)
                    .on_click(cx.listener(|this, _, _, cx| this.disconnect(cx))),
            )
        } else {
            let ready = !busy && self.password_ok(net);
            actions.child(
                button("connect", "Se connecter", true)
                    .when(!ready, |el| el.opacity(0.4))
                    .on_click(cx.listener(|this, _, _, cx| this.connect_selected(cx))),
            )
        };
        panel.child(actions)
    }

    fn render_list(&self, cx: &mut Context<Self>) -> impl IntoElement {
        let placeholder = if !self.loaded {
            Some("Recherche des réseaux…")
        } else if self.state.iface.is_none() {
            Some("Aucune carte Wi-Fi détectée.")
        } else if !self.state.enabled {
            Some("Le Wi-Fi est désactivé.")
        } else if self.state.networks.is_empty() {
            Some("Aucun réseau à portée.")
        } else {
            None
        };
        let list = div()
            .id("networks")
            .flex()
            .flex_col()
            .flex_1()
            .gap(px(2.))
            .px(px(10.))
            .pb(px(10.))
            .overflow_y_scroll();
        match placeholder {
            Some(message) => list.child(
                div().px(px(12.)).py(px(24.)).text_color(muted()).child(message),
            ),
            None => list.children(
                self.state
                    .networks
                    .iter()
                    .enumerate()
                    .map(|(ix, net)| self.render_network(ix, net, cx).into_any_element())
                    .collect::<Vec<_>>(),
            ),
        }
    }

    fn render_footer(&self) -> Option<impl IntoElement> {
        let (message, color) = match (&self.busy, &self.error) {
            (Some(busy), _) => (busy.clone(), muted()),
            (None, Some(error)) => (error.clone(), danger()),
            (None, None) => return None,
        };
        Some(
            div()
                .px(px(22.))
                .py(px(12.))
                .border_t_1()
                .border_color(selection())
                .text_size(px(11.))
                .text_color(color)
                .child(message),
        )
    }
}

impl Render for WifiApp {
    fn render(&mut self, _: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .track_focus(&self.focus)
            .on_key_down(cx.listener(Self::on_key))
            .size_full()
            .flex()
            .flex_col()
            .bg(bg())
            .text_color(text())
            .text_size(px(13.))
            .font_family("Geist")
            .child(self.render_header(cx))
            .child(self.render_list(cx))
            .children(self.render_footer())
    }
}

fn button(id: &'static str, label: &'static str, primary: bool) -> gpui::Stateful<gpui::Div> {
    div()
        .id(id)
        .flex()
        .items_center()
        .h(px(30.))
        .px(px(14.))
        .rounded(px(8.))
        .cursor_pointer()
        .text_size(px(12.))
        .font_weight(FontWeight::MEDIUM)
        .map(|el| {
            if primary {
                el.bg(accent()).text_color(bg()).hover(|el| el.bg(rgb(0x9bd4ff)))
            } else {
                el.bg(base()).text_color(text()).hover(|el| el.bg(dim()))
            }
        })
        .child(label)
}

fn signal_bars(bars: u8, active: bool) -> impl IntoElement {
    let on = if active { accent() } else { text() };
    div().flex().items_end().gap(px(2.)).h(px(14.)).children((1..=4u8).map(move |level| {
        div()
            .w(px(3.))
            .h(px(2. + 3. * level as f32))
            .rounded(px(1.))
            .bg(if level <= bars { on } else { dim() })
    }))
}

fn caret() -> impl IntoElement {
    div().w(px(1.5)).h(px(16.)).bg(accent())
}

/// Lancée depuis un bind Hyprland, l'app n'a pas de terminal : sans ça, un
/// plantage au démarrage (typiquement pas de pilote Vulkan) passe inaperçu.
fn notify_on_panic() {
    let default_hook = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        let message = info.to_string();
        let body = if message.contains("NoSupportedDeviceFound") {
            "Aucun pilote Vulkan trouvé : sudo pacman -S vulkan-intel".to_string()
        } else {
            message
        };
        let _ = std::process::Command::new("notify-send")
            .args(["-u", "critical", "-a", "wifi-gui", "wifi-gui a planté", &body])
            .status();
        default_hook(info);
    }));
}

fn main() {
    notify_on_panic();
    Application::new().run(|cx: &mut App| {
        let bounds = Bounds::centered(None, size(px(420.), px(560.)), cx);
        cx.open_window(
            WindowOptions {
                window_bounds: Some(WindowBounds::Windowed(bounds)),
                window_min_size: Some(size(px(320.), px(300.))),
                window_decorations: Some(WindowDecorations::Server),
                app_id: Some("wifi-gui".into()),
                titlebar: Some(gpui::TitlebarOptions {
                    title: Some("Wi-Fi".into()),
                    ..Default::default()
                }),
                ..Default::default()
            },
            |window, cx| {
                let view = cx.new(WifiApp::new);
                window.focus(&view.read(cx).focus);
                window.set_window_title("Wi-Fi");
                view
            },
        )
        .expect("impossible d'ouvrir la fenêtre");
        cx.on_window_closed(|cx| {
            if cx.windows().is_empty() {
                cx.quit();
            }
        })
        .detach();
        cx.activate(true);
    });
}
