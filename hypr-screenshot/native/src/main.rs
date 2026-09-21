// SPDX-License-Identifier: GPL-3.0-only
mod gpu;
use anyhow::{bail, ensure, Context, Result};
use image::{
    codecs::png::{CompressionType, FilterType, PngEncoder},
    ImageEncoder, RgbaImage,
};
use serde_json::Value;
use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_layer, delegate_output, delegate_pointer, delegate_registry,
    delegate_seat,
    output::{OutputHandler, OutputState},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    seat::{
        pointer::{PointerEvent, PointerEventKind, PointerHandler},
        Capability, SeatHandler, SeatState,
    },
    shell::{
        wlr_layer::{
            Anchor, KeyboardInteractivity, Layer, LayerShell, LayerShellHandler, LayerSurface,
            LayerSurfaceConfigure,
        },
        WaylandSurface,
    },
};
use std::{
    fs,
    io::Write,
    os::fd::AsRawFd,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    sync::mpsc,
    time::{Duration, Instant},
};
use wayland_client::{
    globals::registry_queue_init,
    protocol::{wl_keyboard, wl_output, wl_pointer, wl_seat, wl_surface},
    Connection, Dispatch, QueueHandle, WEnum,
};
use wayland_protocols::wp::{
    cursor_shape::v1::client::{
        wp_cursor_shape_device_v1::{Shape, WpCursorShapeDeviceV1},
        wp_cursor_shape_manager_v1::WpCursorShapeManagerV1,
    },
    viewporter::client::{wp_viewport::WpViewport, wp_viewporter::WpViewporter},
};

type Rect = [f64; 4];
fn num(v: &Value) -> f64 {
    v.as_f64().unwrap_or(0.)
}
fn ipc(command: &str) -> Result<Value> {
    let out = Command::new("hyprctl").args([command, "-j"]).output()?;
    ensure!(out.status.success(), "hyprctl {command} failed");
    Ok(serde_json::from_slice(&out.stdout)?)
}
fn clip(r: Rect, w: f64, h: f64) -> Rect {
    let x = r[0].max(0.).min(w);
    let y = r[1].max(0.).min(h);
    [
        x,
        y,
        (r[0] + r[2]).min(w).max(x) - x,
        (r[1] + r[3]).min(h).max(y) - y,
    ]
}
fn pixel_box(r: Rect, logical: (f64, f64), pixels: (u32, u32)) -> (u32, u32, u32, u32) {
    let r = clip(r, logical.0, logical.1);
    let sx = pixels.0 as f64 / logical.0;
    let sy = pixels.1 as f64 / logical.1;
    let x = (r[0] * sx + 1e-7).floor().max(0.) as u32;
    let y = (r[1] * sy + 1e-7).floor().max(0.) as u32;
    let right = ((r[0] + r[2]) * sx - 1e-7)
        .ceil()
        .min(pixels.0 as f64)
        .max(x as f64) as u32;
    let bottom = ((r[1] + r[3]) * sy - 1e-7)
        .ceil()
        .min(pixels.1 as f64)
        .max(y as f64) as u32;
    (x, y, right - x, bottom - y)
}
fn client_rects(mon: &Value, clients: &Value) -> Vec<Rect> {
    let ws = if mon["specialWorkspace"]["name"]
        .as_str()
        .is_some_and(|s| !s.is_empty())
    {
        &mon["specialWorkspace"]["id"]
    } else {
        &mon["activeWorkspace"]["id"]
    };
    let mut visible: Vec<&Value> = clients
        .as_array()
        .into_iter()
        .flatten()
        .filter(|c| {
            c["mapped"] == true
                && c["hidden"] != true
                && (&c["workspace"]["id"] == ws || c["pinned"] == true)
        })
        .collect();
    visible.sort_by_key(|c| {
        (
            c["pinned"] != true,
            num(&c["fullscreen"]) == 0.,
            c["floating"] != true,
            c["focusHistoryID"].as_i64().unwrap_or(9999),
        )
    });
    visible
        .iter()
        .map(|c| {
            [
                num(&c["at"][0]) - num(&mon["x"]),
                num(&c["at"][1]) - num(&mon["y"]),
                num(&c["size"][0]),
                num(&c["size"][1]),
            ]
        })
        .collect()
}
fn capture(output: Option<&str>, path: &Path) -> Result<()> {
    let mut cmd = Command::new("grim");
    cmd.args(["-l", "0"]);
    if let Some(name) = output {
        cmd.args(["-o", name]);
    }
    ensure!(cmd.arg(path).status()?.success(), "Capture grim échouée");
    Ok(())
}
fn notify(text: &str) {
    // Direct notification on this user's Mako bus; no GTK/libnotify dependency.
    let mut address = std::env::var("DBUS_SESSION_BUS_ADDRESS").unwrap_or_default();
    if !address.starts_with("unix:") {
        if let Ok(pids) = Command::new("pgrep")
            .args(["-u", &unsafe { libc::getuid() }.to_string(), "-x", "mako"])
            .output()
        {
            for pid in String::from_utf8_lossy(&pids.stdout).split_whitespace() {
                if let Ok(data) = fs::read(format!("/proc/{pid}/environ")) {
                    if let Some(entry) = data
                        .split(|b| *b == 0)
                        .find(|s| s.starts_with(b"DBUS_SESSION_BUS_ADDRESS="))
                    {
                        address = String::from_utf8_lossy(&entry[25..]).to_string();
                        break;
                    }
                }
            }
        }
    }
    if address.starts_with("unix:") {
        let _ = Command::new("gdbus")
            .args([
                "call",
                "--address",
                &address,
                "--dest",
                "org.freedesktop.Notifications",
                "--object-path",
                "/org/freedesktop/Notifications",
                "--method",
                "org.freedesktop.Notifications.Notify",
                "Capture",
                "0",
                "camera-photo",
                "Capture d’écran",
                text,
                "[]",
                "{}",
                "2500",
            ])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn();
    }
}
fn publish(image: &RgbaImage, save: bool, output: Option<&Path>) -> Result<()> {
    let mut bytes = Vec::new();
    PngEncoder::new_with_quality(&mut bytes, CompressionType::Fast, FilterType::Adaptive)
        .write_image(
            image.as_raw(),
            image.width(),
            image.height(),
            image::ExtendedColorType::Rgba8,
        )?;
    if let Some(path) = output {
        fs::write(path, bytes)?;
        return Ok(());
    }
    let mut copy = Command::new("wl-copy")
        .args(["--type", "image/png"])
        .stdin(Stdio::piped())
        // wl-copy forks to keep owning the clipboard. Its daemon must not hold
        // the caller's output pipes open after the picker has exited.
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;
    copy.stdin.take().unwrap().write_all(&bytes)?;
    ensure!(
        copy.wait()?.success(),
        "Copie dans le presse-papiers échouée"
    );
    if save {
        let folder = PathBuf::from(std::env::var("HOME")?).join("Pictures/screenshots");
        fs::create_dir_all(&folder)?;
        let stamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)?
            .as_nanos();
        fs::write(folder.join(format!("Screenshot-{stamp}.png")), bytes)?;
    }
    notify(if save {
        "Copiée dans le presse-papiers et enregistrée."
    } else {
        "Copiée dans le presse-papiers."
    });
    Ok(())
}
#[derive(Default)]
struct Options {
    live: bool,
    save: bool,
    output: Option<PathBuf>,
    cancel_after: Option<f64>,
    test_region: Option<Rect>,
    preview: Option<Rect>,
    benchmark: bool,
    mode: String,
}
impl Options {
    fn parse() -> Result<Self> {
        let mut opts = Self::default();
        let mut args = std::env::args().skip(1);
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--live" => opts.live = true,
                "--save" => opts.save = true,
                "--benchmark" => opts.benchmark = true,
                "--output" => {
                    opts.output = Some(args.next().context("Missing output path")?.into())
                }
                "--cancel-after" => {
                    opts.cancel_after = Some(args.next().context("Missing duration")?.parse()?)
                }
                "--test-region" | "--preview-region" => {
                    let mut rect = [0.; 4];
                    for v in &mut rect {
                        *v = args
                            .next()
                            .context("Missing rectangle coordinate")?
                            .parse()?;
                    }
                    if arg == "--test-region" {
                        opts.test_region = Some(rect);
                    } else {
                        opts.preview = Some(rect);
                    }
                }
                "region" | "screen" | "window" | "screen-to-disk" | "window-to-disk" => {
                    opts.mode = arg
                }
                "--help" | "-h" => {
                    println!("hypr-screenshot [--live] [--save] [region|screen|window|screen-to-disk|window-to-disk]\nClic : fenêtre ; glisser : zone ; Échap/clic droit : annuler. Copie PNG automatique.\n--save : enregistrer aussi dans ~/Pictures/screenshots.");
                    std::process::exit(0);
                }
                _ => bail!("Unknown option: {arg}"),
            }
        }
        ensure!(
            opts.test_region.is_none() || opts.output.is_some(),
            "--test-region requires --output"
        );
        Ok(opts)
    }
}
struct View {
    // GPU/EGL resources must be destroyed before their Wayland surface.
    gpu: Option<gpu::Gpu>,
    layer: LayerSurface,
    viewport: WpViewport,
    monitor: Value,
    logical: (f64, f64),
    screenshot: Option<RgbaImage>,
    rects: Vec<Rect>,
    current: Rect,
    target: Rect,
    on_client: bool,
    drag: Option<(f64, f64)>,
    dragging: bool,
    mouse: Option<(f64, f64)>,
    pending: bool,
    configured: bool,
    dirty: bool,
    last: Instant,
}
impl View {
    fn hover(&mut self, p: (f64, f64)) {
        for rect in &self.rects {
            if p.0 >= rect[0]
                && p.1 >= rect[1]
                && p.0 < rect[0] + rect[2]
                && p.1 < rect[1] + rect[3]
            {
                let r = clip(*rect, self.logical.0, self.logical.1);
                self.dirty |= self.target != r || !self.on_client;
                self.target = r;
                self.on_client = true;
                break;
            }
        }
    }
    fn motion(&mut self, p: (f64, f64)) {
        self.mouse = Some(p);
        if let Some(start) = self.drag {
            if self.dragging || (p.0 - start.0).hypot(p.1 - start.1) >= 3. {
                self.dragging = true;
                self.on_client = false;
                self.target = clip(
                    [
                        start.0.min(p.0),
                        start.1.min(p.1),
                        (p.0 - start.0).abs(),
                        (p.1 - start.1).abs(),
                    ],
                    self.logical.0,
                    self.logical.1,
                );
                self.current = self.target;
                self.dirty = true;
            }
        } else {
            self.hover(p);
        }
    }
}
struct App {
    registry: RegistryState,
    outputs: OutputState,
    seats: SeatState,
    views: Vec<View>,
    keyboard: Option<wl_keyboard::WlKeyboard>,
    pointer: Option<wl_pointer::WlPointer>,
    cursor_manager: Option<WpCursorShapeManagerV1>,
    cursor: Option<WpCursorShapeDeviceV1>,
    opts: Options,
    start: Instant,
    exit: bool,
    closing: Option<Instant>,
    chosen: Option<(usize, Rect)>,
    error: Option<String>,
    focused: usize,
    border: f64,
    rounding: f64,
    frames: Vec<Instant>,
    refresh: Option<mpsc::Receiver<(Value, Value)>>,
}
impl App {
    fn close(
        &mut self,
        selected: Option<(usize, Rect)>,
        conn: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if self.closing.is_some() {
            return;
        }
        self.chosen = selected;
        self.closing = Some(Instant::now());
        for v in &mut self.views {
            v.layer
                .set_keyboard_interactivity(KeyboardInteractivity::None);
            v.dirty = true;
        }
        for i in 0..self.views.len() {
            self.draw(i, conn, qh);
        }
    }
    fn draw(&mut self, i: usize, conn: &Connection, qh: &QueueHandle<Self>) {
        if self.exit || !self.views[i].configured || self.views[i].pending {
            return;
        }
        let now = Instant::now();
        let elapsed = now.duration_since(self.start).as_secs_f64();
        if self.opts.cancel_after.is_some_and(|t| elapsed >= t) {
            self.exit = true;
            return;
        }
        if let Some(rect) = self.opts.test_region {
            if elapsed > 0.7 {
                self.opts.test_region = None;
                // Exercise the same press/drag/release path as real pointer input.
                if let Some(pointer) = self.pointer.clone() {
                    let surface = self.views[i].layer.wl_surface().clone();
                    let events = [
                        PointerEvent {
                            surface: surface.clone(),
                            position: (rect[0], rect[1]),
                            kind: PointerEventKind::Press {
                                button: 272,
                                serial: 0,
                                time: 0,
                            },
                        },
                        PointerEvent {
                            surface: surface.clone(),
                            position: (rect[0] + rect[2], rect[1] + rect[3]),
                            kind: PointerEventKind::Motion { time: 0 },
                        },
                        PointerEvent {
                            surface,
                            position: (rect[0] + rect[2], rect[1] + rect[3]),
                            kind: PointerEventKind::Release {
                                button: 272,
                                serial: 0,
                                time: 0,
                            },
                        },
                    ];
                    self.pointer_frame(conn, qh, &pointer, &events);
                } else {
                    self.error = Some("No pointer available for integration test".into());
                    self.exit = true;
                }
                return;
            }
        }
        if let Some(start) = self.closing {
            if now.duration_since(start).as_secs_f64() >= 0.18 {
                self.exit = true;
                return;
            }
        }
        if let Some(rx) = &self.refresh {
            let mut latest = None;
            while let Ok(update) = rx.try_recv() {
                latest = Some(update);
            }
            if let Some((monitors, clients)) = latest {
                for v in &mut self.views {
                    if let Some(m) = monitors
                        .as_array()
                        .and_then(|ms| ms.iter().find(|m| m["name"] == v.monitor["name"]))
                    {
                        v.monitor = m.clone();
                    }
                    v.rects = client_rects(&v.monitor, &clients);
                    if v.drag.is_none() {
                        if let Some(p) = v.mouse {
                            v.hover(p);
                        }
                    }
                }
            }
        }
        let v = &mut self.views[i];
        let dt = now.duration_since(v.last).as_secs_f64().min(0.1);
        v.last = now;
        if self.opts.benchmark {
            v.target = [500. + 150. * (elapsed * 3.).sin(), 300., 700., 500.];
            v.on_client = false;
        }
        let animating = v
            .current
            .iter()
            .zip(v.target)
            .any(|(a, b)| (a - b).abs() > 0.05);
        if v.drag.is_none() {
            for (a, b) in v.current.iter_mut().zip(v.target) {
                *a += (b - *a) * (1. - (-18. * dt).exp());
                if (*a - b).abs() < 0.05 {
                    *a = b;
                }
            }
        }
        let mut opacity = (elapsed / 0.15).min(1.);
        if let Some(start) = self.closing {
            let t = now.duration_since(start).as_secs_f64() / 0.18;
            opacity *= 1. - t;
            let f = 1. - (-32. * dt).exp();
            for (a, b) in v.current.iter_mut().zip([0., 0., v.logical.0, v.logical.1]) {
                *a += (b - *a) * f;
            }
        }
        let timed = self.opts.cancel_after.is_some() || self.opts.test_region.is_some();
        if !v.dirty
            && !animating
            && self.closing.is_none()
            && !self.opts.benchmark
            && !timed
            && elapsed > 0.2
        {
            return;
        }
        let scale = num(&v.monitor["scale"]).max(0.1);
        let pixels = (
            (v.logical.0 * scale).round() as i32,
            (v.logical.1 * scale).round() as i32,
        );
        let result = (|| -> Result<()> {
            if v.gpu.is_none() {
                let gpu = gpu::Gpu::new(
                    conn,
                    v.layer.wl_surface(),
                    pixels.0,
                    pixels.1,
                    v.screenshot.as_ref(),
                )?;
                if self.opts.benchmark {
                    eprintln!("GPU: {}", gpu.renderer);
                }
                v.gpu = Some(gpu);
            }
            v.layer.wl_surface().frame(qh, v.layer.wl_surface().clone());
            v.pending = true;
            v.gpu.as_mut().unwrap().draw(
                v.logical,
                pixels,
                v.current,
                if v.on_client { self.rounding } else { 0. },
                if v.on_client { self.border } else { 2. },
                opacity,
            )?;
            Ok(())
        })();
        if let Err(error) = result {
            self.error = Some(error.to_string());
            self.exit = true;
        }
        v.dirty = false;
        if self.opts.benchmark && elapsed > 0.5 && i == 0 {
            self.frames.push(now);
        }
    }
}
impl CompositorHandler for App {
    fn scale_factor_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: i32,
    ) {
    }
    fn transform_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: wl_output::Transform,
    ) {
    }
    fn surface_enter(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }
    fn surface_leave(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }
    fn frame(&mut self, c: &Connection, q: &QueueHandle<Self>, s: &wl_surface::WlSurface, _: u32) {
        if let Some(i) = self.views.iter().position(|v| v.layer.wl_surface() == s) {
            self.views[i].pending = false;
            self.draw(i, c, q);
        }
    }
}
impl OutputHandler for App {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.outputs
    }
    fn new_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn update_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn output_destroyed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {
        self.exit = true;
    }
}
impl LayerShellHandler for App {
    fn closed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &LayerSurface) {
        self.exit = true;
    }
    fn configure(
        &mut self,
        c: &Connection,
        q: &QueueHandle<Self>,
        layer: &LayerSurface,
        configure: LayerSurfaceConfigure,
        _: u32,
    ) {
        if let Some(i) = self.views.iter().position(|v| &v.layer == layer) {
            let v = &mut self.views[i];
            if configure.new_size.0 > 0 && configure.new_size.1 > 0 {
                v.logical = (configure.new_size.0 as f64, configure.new_size.1 as f64);
            }
            v.viewport
                .set_destination(v.logical.0 as i32, v.logical.1 as i32);
            v.configured = true;
            v.dirty = true;
            self.draw(i, c, q);
        }
    }
}
impl SeatHandler for App {
    fn seat_state(&mut self) -> &mut SeatState {
        &mut self.seats
    }
    fn new_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat) {}
    fn new_capability(
        &mut self,
        _: &Connection,
        q: &QueueHandle<Self>,
        seat: wl_seat::WlSeat,
        cap: Capability,
    ) {
        if cap == Capability::Keyboard && self.keyboard.is_none() {
            self.keyboard = Some(seat.get_keyboard(q, ()));
        }
        if cap == Capability::Pointer && self.pointer.is_none() {
            if let Ok(pointer) = self.seats.get_pointer(q, &seat) {
                if let Some(manager) = &self.cursor_manager {
                    self.cursor = Some(manager.get_pointer(&pointer, q, ()));
                }
                self.pointer = Some(pointer);
            }
        }
    }
    fn remove_capability(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: wl_seat::WlSeat,
        cap: Capability,
    ) {
        if cap == Capability::Keyboard {
            if let Some(k) = self.keyboard.take() {
                k.release();
            }
        }
        if cap == Capability::Pointer {
            if let Some(c) = self.cursor.take() {
                c.destroy();
            }
            if let Some(p) = self.pointer.take() {
                p.release();
            }
        }
    }
    fn remove_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat) {}
}
impl Dispatch<wl_keyboard::WlKeyboard, ()> for App {
    fn event(
        app: &mut Self,
        _: &wl_keyboard::WlKeyboard,
        event: wl_keyboard::Event,
        _: &(),
        c: &Connection,
        q: &QueueHandle<Self>,
    ) {
        match event {
            wl_keyboard::Event::Enter { surface, .. } => {
                if let Some(i) = app
                    .views
                    .iter()
                    .position(|v| v.layer.wl_surface() == &surface)
                {
                    app.focused = i;
                }
            }
            wl_keyboard::Event::Key {
                key,
                state: WEnum::Value(wl_keyboard::KeyState::Pressed),
                ..
            } => {
                if key == 1 {
                    app.close(None, c, q);
                } else if key == 28 && !app.views.is_empty() {
                    let i = app.focused;
                    app.close(Some((i, app.views[i].target)), c, q);
                }
            }
            _ => {}
        }
    }
}
impl PointerHandler for App {
    fn pointer_frame(
        &mut self,
        c: &Connection,
        q: &QueueHandle<Self>,
        _: &wl_pointer::WlPointer,
        events: &[PointerEvent],
    ) {
        for event in events {
            if self.closing.is_some() {
                break;
            }
            let Some(i) = self
                .views
                .iter()
                .position(|v| v.layer.wl_surface() == &event.surface)
            else {
                continue;
            };
            self.focused = i;
            match event.kind {
                PointerEventKind::Enter { serial } => {
                    if let Some(cursor) = &self.cursor {
                        cursor.set_shape(serial, Shape::Crosshair);
                    }
                    self.views[i].motion(event.position);
                }
                PointerEventKind::Motion { .. } => self.views[i].motion(event.position),
                PointerEventKind::Press { button: 272, .. } => {
                    let v = &mut self.views[i];
                    v.hover(event.position);
                    v.drag = Some(event.position);
                    v.dragging = false;
                }
                PointerEventKind::Press { button: 273, .. } => self.close(None, c, q),
                PointerEventKind::Release { button: 272, .. } => {
                    let v = &mut self.views[i];
                    if v.drag.is_some() {
                        v.motion(event.position);
                        v.drag = None;
                        let rect = v.target;
                        if rect[2] >= 1. && rect[3] >= 1. {
                            self.close(Some((i, rect)), c, q);
                        }
                    }
                }
                _ => {}
            }
            self.draw(i, c, q);
        }
    }
}
delegate_compositor!(App);
delegate_output!(App);
delegate_seat!(App);
delegate_pointer!(App);
delegate_layer!(App);
delegate_registry!(App);
wayland_client::delegate_noop!(App: ignore WpViewporter);
wayland_client::delegate_noop!(App: ignore WpViewport);
wayland_client::delegate_noop!(App: ignore WpCursorShapeManagerV1);
wayland_client::delegate_noop!(App: ignore WpCursorShapeDeviceV1);
impl ProvidesRegistryState for App {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry
    }
    registry_handlers![OutputState, SeatState];
}

fn run(opts: Options) -> Result<()> {
    let runtime = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    let lock = fs::OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(false)
        .open(format!("{runtime}/hypr-screenshot-{}.lock", unsafe {
            libc::getuid()
        }))?;
    if unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
        return Ok(());
    }
    let temp = tempfile::Builder::new()
        .prefix("hypr-screenshot-native-")
        .tempdir_in(&runtime)?;
    if !opts.mode.is_empty() && opts.mode != "region" {
        let path = temp.path().join("capture.png");
        if opts.mode.starts_with("window") {
            let win = ipc("activewindow")?;
            ensure!(win["mapped"] == true, "Aucune fenêtre active");
            let geom = format!(
                "{},{} {}x{}",
                num(&win["at"][0]),
                num(&win["at"][1]),
                num(&win["size"][0]),
                num(&win["size"][1])
            );
            ensure!(
                Command::new("grim")
                    .args(["-l", "0", "-g", &geom])
                    .arg(&path)
                    .status()?
                    .success(),
                "Capture échouée"
            );
        } else {
            capture(None, &path)?;
        }
        return publish(
            &image::open(path)?.to_rgba8(),
            opts.save || opts.mode.ends_with("-to-disk"),
            opts.output.as_deref(),
        );
    }
    let monitors = ipc("monitors")?;
    let clients = ipc("clients")?;
    let cursor = ipc("cursorpos")?;
    let option = |name: &str| -> f64 {
        Command::new("hyprctl")
            .args(["getoption", name, "-j"])
            .output()
            .ok()
            .and_then(|o| serde_json::from_slice::<Value>(&o.stdout).ok())
            .map_or(0., |v| num(&v["int"]))
    };
    let border = option("general:border_size");
    let rounding = option("decoration:rounding");
    let conn = Connection::connect_to_env()?;
    let (globals, mut queue) = registry_queue_init::<App>(&conn)?;
    let q = queue.handle();
    let compositor = CompositorState::bind(&globals, &q)?;
    let shell = LayerShell::bind(&globals, &q)?;
    let viewporter: WpViewporter = globals.bind(&q, 1..=1, ())?;
    let cursor_manager = globals.bind(&q, 1..=1, ()).ok();
    let mut app = App {
        registry: RegistryState::new(&globals),
        outputs: OutputState::new(&globals, &q),
        seats: SeatState::new(&globals, &q),
        views: vec![],
        keyboard: None,
        pointer: None,
        cursor_manager,
        cursor: None,
        opts,
        start: Instant::now(),
        exit: false,
        closing: None,
        chosen: None,
        error: None,
        focused: 0,
        border,
        rounding,
        frames: vec![],
        refresh: None,
    };
    queue.roundtrip(&mut app)?;
    for mon in monitors.as_array().context("No monitors")? {
        let name = mon["name"].as_str().context("Unnamed monitor")?;
        let output = app
            .outputs
            .outputs()
            .find(|o| {
                app.outputs
                    .info(o)
                    .is_some_and(|info| info.name.as_deref() == Some(name))
            })
            .context("Wayland output missing")?;
        let scale = num(&mon["scale"]).max(0.1);
        let rotated = mon["transform"].as_u64().unwrap_or(0) % 2 == 1;
        let physical = if rotated {
            (num(&mon["height"]), num(&mon["width"]))
        } else {
            (num(&mon["width"]), num(&mon["height"]))
        };
        let logical = ((physical.0 / scale).round(), (physical.1 / scale).round());
        let screenshot = if app.opts.live {
            None
        } else {
            let path = temp.path().join(format!("{name}.png"));
            capture(Some(name), &path)?;
            Some(image::open(path)?.to_rgba8())
        };
        let surface = compositor.create_surface(&q);
        let viewport = viewporter.get_viewport(&surface, &q, ());
        let layer = shell.create_layer_surface(
            &q,
            surface,
            Layer::Overlay,
            Some("hypr-screenshot"),
            Some(&output),
        );
        layer.set_anchor(Anchor::TOP | Anchor::BOTTOM | Anchor::LEFT | Anchor::RIGHT);
        layer.set_exclusive_zone(-1);
        layer.set_keyboard_interactivity(KeyboardInteractivity::Exclusive);
        layer.set_size(0, 0);
        let rects = client_rects(mon, &clients);
        let initial = app.opts.preview.unwrap_or_else(|| {
            rects.first().copied().unwrap_or([
                logical.0 / 2. - 100.,
                logical.1 / 2. - 100.,
                200.,
                200.,
            ])
        });
        let mut view = View {
            gpu: None,
            layer,
            viewport,
            monitor: mon.clone(),
            logical,
            screenshot,
            rects,
            current: initial,
            target: initial,
            on_client: app.opts.preview.is_none(),
            drag: None,
            dragging: false,
            mouse: None,
            pending: false,
            configured: false,
            dirty: true,
            last: Instant::now(),
        };
        if app.opts.preview.is_none() {
            view.hover((
                num(&cursor["x"]) - num(&mon["x"]),
                num(&cursor["y"]) - num(&mon["y"]),
            ));
            view.current = view.target;
        }
        app.views.push(view);
    }
    ensure!(!app.views.is_empty(), "No active outputs");
    if app.opts.live {
        let (tx, rx) = mpsc::channel();
        app.refresh = Some(rx);
        std::thread::spawn(move || loop {
            std::thread::sleep(Duration::from_millis(250));
            if let (Ok(m), Ok(c)) = (ipc("monitors"), ipc("clients")) {
                if tx.send((m, c)).is_err() {
                    break;
                }
            }
        });
    }
    app.start = Instant::now();
    for v in &app.views {
        v.layer.commit();
    }
    while !app.exit {
        queue.blocking_dispatch(&mut app)?;
    }
    // Unmap and synchronize before live capture so no tint/cursor overlay leaks into the PNG.
    for v in &app.views {
        v.layer.wl_surface().attach(None, 0, 0);
        v.layer.commit();
    }
    conn.flush()?;
    queue.roundtrip(&mut app)?;
    if let Some(error) = app.error {
        bail!(error);
    }
    if app.opts.benchmark && app.frames.len() > 2 {
        let mut ms: Vec<f64> = app
            .frames
            .windows(2)
            .map(|w| w[1].duration_since(w[0]).as_secs_f64() * 1000.)
            .collect();
        ms.sort_by(f64::total_cmp);
        eprintln!(
            "BENCHMARK {:.1} fps; median {:.2} ms; p95 {:.2} ms; {} frames",
            (app.frames.len() - 1) as f64
                / app
                    .frames
                    .last()
                    .unwrap()
                    .duration_since(app.frames[0])
                    .as_secs_f64(),
            ms[ms.len() / 2],
            ms[ms.len() * 95 / 100],
            app.frames.len()
        );
    }
    if let Some((i, rect)) = app.chosen {
        let v = &app.views[i];
        let live;
        let source = if let Some(image) = &v.screenshot {
            image
        } else {
            std::thread::sleep(Duration::from_millis(20));
            let path = temp.path().join("live.png");
            capture(v.monitor["name"].as_str(), &path)?;
            live = image::open(path)?.to_rgba8();
            &live
        };
        let (x, y, w, h) = pixel_box(rect, v.logical, source.dimensions());
        ensure!(w > 0 && h > 0, "Empty selection");
        let crop = image::imageops::crop_imm(source, x, y, w, h).to_image();
        publish(&crop, app.opts.save, app.opts.output.as_deref())?;
    }
    Ok(())
}
fn main() {
    if let Err(err) = Options::parse().and_then(run) {
        eprintln!("hypr-screenshot: {err:#}");
        notify(&format!("Échec de capture : {err}"));
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn fractional_scale() {
        assert_eq!(
            pixel_box([80., 40., 400., 240.], (2048., 1280.), (2560, 1600)),
            (100, 50, 500, 300)
        );
    }
    #[test]
    fn full_frame() {
        assert_eq!(
            pixel_box([0., 0., 2048., 1280.], (2048., 1280.), (2560, 1600)),
            (0, 0, 2560, 1600)
        );
    }
    #[test]
    fn negative_origin() {
        assert_eq!(
            clip([-50., -10., 150., 100.], 200., 100.),
            [0., 0., 100., 90.]
        );
    }
    #[test]
    fn pixel_edges() {
        assert_eq!(
            pixel_box([1., 1., 1., 1.], (100., 100.), (125, 125)),
            (1, 1, 2, 2)
        );
    }
    #[test]
    fn stack_order() {
        let m = serde_json::json!({"x":-1920,"y":100,"activeWorkspace":{"id":4}});
        let c = serde_json::json!([
        {"at":[-1900,120],"size":[500,300],"mapped":true,"workspace":{"id":4}},
        {"at":[-1850,120],"size":[500,300],"mapped":true,"workspace":{"id":4},"floating":true},
        {"at":[-1800,120],"size":[500,300],"mapped":true,"workspace":{"id":2}}]);
        assert_eq!(
            client_rects(&m, &c),
            vec![[70., 20., 500., 300.], [20., 20., 500., 300.]]
        );
    }
}
