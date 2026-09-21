//! A single GLES shader draws the frozen texture, tint and selection border.
//! No widget toolkit and no CPU bitmap painting in the frame loop.
use anyhow::{bail, ensure, Result};
use glow::HasContext;
use std::{
    ffi::{c_void, CString},
    ptr,
};
use wayland_client::{protocol::wl_surface::WlSurface, Connection, Proxy};
use wayland_egl::WlEglSurface;

type Handle = *mut c_void;
#[link(name = "EGL")]
extern "C" {
    fn eglGetDisplay(native: Handle) -> Handle;
    fn eglInitialize(d: Handle, major: *mut i32, minor: *mut i32) -> u32;
    fn eglBindAPI(api: u32) -> u32;
    fn eglChooseConfig(
        d: Handle,
        attrs: *const i32,
        configs: *mut Handle,
        size: i32,
        count: *mut i32,
    ) -> u32;
    fn eglCreateContext(d: Handle, config: Handle, share: Handle, attrs: *const i32) -> Handle;
    fn eglCreateWindowSurface(d: Handle, config: Handle, win: Handle, attrs: *const i32) -> Handle;
    fn eglMakeCurrent(d: Handle, draw: Handle, read: Handle, ctx: Handle) -> u32;
    fn eglSwapInterval(d: Handle, interval: i32) -> u32;
    fn eglSwapBuffers(d: Handle, surface: Handle) -> u32;
    fn eglGetProcAddress(name: *const i8) -> *const c_void;
    fn eglDestroySurface(d: Handle, surface: Handle) -> u32;
    fn eglDestroyContext(d: Handle, ctx: Handle) -> u32;
}

pub struct Gpu {
    display: Handle,
    context: Handle,
    surface: Handle,
    window: WlEglSurface,
    gl: glow::Context,
    program: glow::Program,
    buffer: glow::Buffer,
    texture: glow::Texture,
    pub renderer: String,
    size: (i32, i32),
    frozen: bool,
}

impl Gpu {
    pub fn new(
        conn: &Connection,
        surface: &WlSurface,
        width: i32,
        height: i32,
        image: Option<&image::RgbaImage>,
    ) -> Result<Self> {
        unsafe {
            let display = eglGetDisplay(conn.backend().display_ptr().cast());
            ensure!(
                !display.is_null() && eglInitialize(display, ptr::null_mut(), ptr::null_mut()) != 0,
                "EGL initialization failed"
            );
            ensure!(eglBindAPI(0x30A0) != 0, "OpenGL ES unavailable");
            let attrs = [
                0x3033, 4, 0x3040, 4, 0x3024, 8, 0x3023, 8, 0x3022, 8, 0x3021, 8, 0x3038,
            ];
            let mut config = ptr::null_mut();
            let mut count = 0;
            ensure!(
                eglChooseConfig(display, attrs.as_ptr(), &mut config, 1, &mut count) != 0
                    && count > 0,
                "No RGBA EGL config"
            );
            let context = eglCreateContext(
                display,
                config,
                ptr::null_mut(),
                [0x3098, 2, 0x3038].as_ptr(),
            );
            ensure!(!context.is_null(), "Cannot create GPU context");
            let window = WlEglSurface::new(surface.id(), width, height)?;
            let egl_surface = eglCreateWindowSurface(
                display,
                config,
                window.ptr().cast_mut().cast(),
                [0x3038].as_ptr(),
            );
            ensure!(!egl_surface.is_null(), "Cannot create GPU surface");
            ensure!(
                eglMakeCurrent(display, egl_surface, egl_surface, context) != 0,
                "Cannot activate GPU context"
            );
            // Wayland frame callbacks pace rendering; a second EGL throttle would halve the rate.
            eglSwapInterval(display, 0);
            let gl = glow::Context::from_loader_function(|name| {
                eglGetProcAddress(CString::new(name).unwrap().as_ptr())
            });
            let renderer = gl.get_parameter_string(glow::RENDERER);
            let program = gl.create_program().map_err(anyhow::Error::msg)?;
            for (kind, source) in [
                (glow::VERTEX_SHADER, VERTEX),
                (glow::FRAGMENT_SHADER, FRAGMENT),
            ] {
                let shader = gl.create_shader(kind).map_err(anyhow::Error::msg)?;
                gl.shader_source(shader, source);
                gl.compile_shader(shader);
                if !gl.get_shader_compile_status(shader) {
                    bail!("Shader: {}", gl.get_shader_info_log(shader));
                }
                gl.attach_shader(program, shader);
                gl.delete_shader(shader);
            }
            gl.bind_attrib_location(program, 0, "position");
            gl.link_program(program);
            ensure!(
                gl.get_program_link_status(program),
                "Shader link: {}",
                gl.get_program_info_log(program)
            );
            let buffer = gl.create_buffer().map_err(anyhow::Error::msg)?;
            gl.bind_buffer(glow::ARRAY_BUFFER, Some(buffer));
            let vertices: [f32; 8] = [-1., -1., 1., -1., -1., 1., 1., 1.];
            gl.buffer_data_u8_slice(
                glow::ARRAY_BUFFER,
                std::slice::from_raw_parts(vertices.as_ptr().cast(), 32),
                glow::STATIC_DRAW,
            );
            let texture = gl.create_texture().map_err(anyhow::Error::msg)?;
            gl.bind_texture(glow::TEXTURE_2D, Some(texture));
            for attr in [glow::TEXTURE_MIN_FILTER, glow::TEXTURE_MAG_FILTER] {
                gl.tex_parameter_i32(glow::TEXTURE_2D, attr, glow::LINEAR as i32);
            }
            for attr in [glow::TEXTURE_WRAP_S, glow::TEXTURE_WRAP_T] {
                gl.tex_parameter_i32(glow::TEXTURE_2D, attr, glow::CLAMP_TO_EDGE as i32);
            }
            let fallback = image::RgbaImage::new(1, 1);
            let pixels = image.unwrap_or(&fallback);
            gl.tex_image_2d(
                glow::TEXTURE_2D,
                0,
                glow::RGBA as i32,
                pixels.width() as i32,
                pixels.height() as i32,
                0,
                glow::RGBA,
                glow::UNSIGNED_BYTE,
                glow::PixelUnpackData::Slice(Some(pixels.as_raw())),
            );
            Ok(Self {
                display,
                context,
                surface: egl_surface,
                window,
                gl,
                program,
                buffer,
                texture,
                renderer,
                size: (width, height),
                frozen: image.is_some(),
            })
        }
    }

    pub fn draw(
        &mut self,
        logical: (f64, f64),
        pixels: (i32, i32),
        rect: [f64; 4],
        radius: f64,
        border: f64,
        opacity: f64,
    ) -> Result<()> {
        unsafe {
            ensure!(
                eglMakeCurrent(self.display, self.surface, self.surface, self.context) != 0,
                "GPU context lost"
            );
            if pixels != self.size {
                self.window.resize(pixels.0, pixels.1, 0, 0);
                self.size = pixels;
            }
            let gl = &self.gl;
            gl.viewport(0, 0, pixels.0, pixels.1);
            gl.disable(glow::BLEND);
            gl.use_program(Some(self.program));
            gl.bind_buffer(glow::ARRAY_BUFFER, Some(self.buffer));
            gl.enable_vertex_attrib_array(0);
            gl.vertex_attrib_pointer_f32(0, 2, glow::FLOAT, false, 0, 0);
            gl.active_texture(glow::TEXTURE0);
            gl.bind_texture(glow::TEXTURE_2D, Some(self.texture));
            gl.uniform_1_i32(
                gl.get_uniform_location(self.program, "background").as_ref(),
                0,
            );
            gl.uniform_1_i32(
                gl.get_uniform_location(self.program, "frozen").as_ref(),
                self.frozen as i32,
            );
            gl.uniform_2_f32(
                gl.get_uniform_location(self.program, "size").as_ref(),
                logical.0 as f32,
                logical.1 as f32,
            );
            gl.uniform_4_f32(
                gl.get_uniform_location(self.program, "rect").as_ref(),
                rect[0] as f32,
                rect[1] as f32,
                rect[2] as f32,
                rect[3] as f32,
            );
            gl.uniform_3_f32(
                gl.get_uniform_location(self.program, "style").as_ref(),
                radius as f32,
                border as f32,
                opacity as f32,
            );
            gl.draw_arrays(glow::TRIANGLE_STRIP, 0, 4);
            ensure!(
                eglSwapBuffers(self.display, self.surface) != 0,
                "GPU swap failed"
            );
            Ok(())
        }
    }
}

impl Drop for Gpu {
    fn drop(&mut self) {
        unsafe {
            eglMakeCurrent(self.display, self.surface, self.surface, self.context);
            self.gl.delete_texture(self.texture);
            self.gl.delete_buffer(self.buffer);
            self.gl.delete_program(self.program);
            eglMakeCurrent(
                self.display,
                ptr::null_mut(),
                ptr::null_mut(),
                ptr::null_mut(),
            );
            eglDestroySurface(self.display, self.surface);
            eglDestroyContext(self.display, self.context);
        }
    }
}

const VERTEX: &str = "attribute vec2 position; varying vec2 uv; void main() { gl_Position=vec4(position,0.0,1.0); uv=vec2(position.x*0.5+0.5,0.5-position.y*0.5); }";
const FRAGMENT: &str = r#"
precision highp float;
varying vec2 uv;
uniform sampler2D background;
uniform bool frozen;
uniform vec2 size;
uniform vec4 rect;
uniform vec3 style;
void main() {
    float radius=min(style.x,min(rect.z,rect.w)*0.5);
    vec2 q=abs(uv*size-rect.xy-rect.zw*0.5)-(rect.zw*0.5-vec2(radius));
    float d=length(max(q,0.0))+min(max(q.x,q.y),0.0)-radius;
    float outside=smoothstep(-0.5,0.5,d);
    float ring=style.y>0.0 ? outside*(1.0-smoothstep(style.y-0.5,style.y+0.5,d)) : 0.0;
    float tint=outside*0.3*style.z;
    float edge=ring*style.z;
    vec3 tintColor=vec3(90.0,63.0,72.0)/255.0;
    vec3 edgeColor=vec3(255.0,176.0,202.0)/255.0;
    vec4 base=frozen ? texture2D(background,uv) : vec4(0.0);
    base=vec4(tintColor*tint+base.rgb*(1.0-tint),tint+base.a*(1.0-tint));
    gl_FragColor=vec4(edgeColor*edge+base.rgb*(1.0-edge),edge+base.a*(1.0-edge));
}
"#;
