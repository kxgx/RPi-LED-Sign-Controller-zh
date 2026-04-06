use crate::display::driver::LedCanvas;
use crate::display::renderer::{RenderContext, Renderer};
use crate::models::content::ContentDetails;
use crate::models::playlist::PlayListItem;
use crate::models::text::TextContent;
use ab_glyph::{Font, FontArc, ScaleFont};
use log::debug;
use std::sync::atomic::{AtomicU32, Ordering};
use std::time::Instant;

// 默认字体路径 (文泉驿微米黑，常见于 Linux/树莓派)
const DEFAULT_FONT_PATH: &str = "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc";
// 备选字体路径
const FALLBACK_FONT_PATHS: &[&str] = &[
    "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
];

pub struct TextRenderer {
    /// The text content to render
    content: TextContent,

    /// Context with display properties
    ctx: RenderContext,

    /// Loaded font
    font: Option<FontArc>,

    /// Width of the text in pixels
    text_width: f32,

    /// Current scroll position
    scroll_position: f32,

    /// Counter for completed scroll cycles
    completed_scrolls: u32,

    /// Timing accumulator for scroll animation
    accumulated_time: f32,

    /// Target number of repeats (None for duration-based)
    repeat_count: Option<u32>,

    /// Duration-based timing
    duration: Option<u64>,

    /// Timestamp when rendering started
    start_time: Instant,

    /// Last reported cycle (to avoid duplicate logging)
    last_reported_cycle: AtomicU32,
}

impl Renderer for TextRenderer {
    fn new(content: &PlayListItem, ctx: RenderContext) -> Self {
        // Extract the text content from the display content
        let text_content = match &content.content.data {
            ContentDetails::Text(tc) => tc.clone(),
            #[allow(unreachable_patterns)]
            _ => panic!("Expected text content"),
        };

        // Load font
        let font = Self::load_font();

        // Create text renderer with clone of ctx
        let ctx_clone = ctx.clone();
        let mut renderer = Self {
            content: text_content,
            ctx: ctx_clone,
            font,
            text_width: 0.0, // Will calculate on first render
            scroll_position: ctx.display_width as f32,
            completed_scrolls: 0,
            accumulated_time: 0.0,
            repeat_count: content.repeat_count,
            duration: content.duration,
            start_time: Instant::now(),
            last_reported_cycle: AtomicU32::new(0),
        };

        // Pre-calculate text width
        renderer.calculate_text_width();

        // Log the configuration to help diagnose issues
        debug!(
            "TextRenderer::new - text: '{}', scroll: {}, duration: {:?}, repeat_count: {:?}",
            renderer.content.text,
            renderer.content.scroll,
            renderer.duration,
            renderer.repeat_count
        );

        renderer
    }

    fn update(&mut self, dt: f32) {
        if self.content.scroll {
            self.accumulated_time += dt;
            let pixels_to_move = (self.accumulated_time * self.content.speed) as f32;

            if pixels_to_move > 0.0 {
                self.scroll_position -= pixels_to_move;
                self.accumulated_time = 0.0;

                // Reset position when text is off screen
                if self.scroll_position < -self.text_width {
                    self.scroll_position = self.ctx.display_width as f32;
                    self.completed_scrolls += 1;
                }
            }
        }
        // For duration-based content, track elapsed time
        else if let Some(_) = self.duration {
            // Calculate elapsed time in seconds
            let elapsed = Instant::now().duration_since(self.start_time).as_secs();
            // Track elapsed time for is_complete() functionality
            self.last_reported_cycle
                .store(elapsed as u32, Ordering::SeqCst);
        }
    }

    fn render(&self, canvas: &mut Box<dyn LedCanvas>) {
        if let Some(font) = &self.font {
            self.render_with_font(canvas, font);
        } else {
            debug!("No font loaded, skipping text rendering");
        }
    }

    fn is_complete(&self) -> bool {
        // For duration-based content
        if let Some(duration) = self.duration {
            return Instant::now().duration_since(self.start_time).as_secs() >= duration;
        }

        // For repeat-count based content
        if let Some(repeat_count) = self.repeat_count {
            if repeat_count == 0 {
                return false; // Infinite repeat
            }
            return self.completed_scrolls >= repeat_count;
        }

        false // Default case
    }

    fn reset(&mut self) {
        self.scroll_position = self.ctx.display_width as f32;
        self.completed_scrolls = 0;
        self.accumulated_time = 0.0;
        self.start_time = Instant::now();
        self.last_reported_cycle.store(0, Ordering::SeqCst);
    }

    fn update_context(&mut self, ctx: RenderContext) {
        // Update the context without changing animation state
        self.ctx = ctx;
    }

    fn update_content(&mut self, content: &PlayListItem) {
        // Extract the new text content
        let new_text_content = match &content.content.data {
            ContentDetails::Text(tc) => tc.clone(),
            #[allow(unreachable_patterns)]
            _ => panic!("Expected text content"),
        };

        // Track if we need to recalculate width
        let text_changed = self.content.text != new_text_content.text;

        // Update content properties
        self.content = new_text_content;
        self.repeat_count = content.repeat_count;
        self.duration = content.duration;

        // Only recalculate width if text changed
        if text_changed {
            self.calculate_text_width();

            // Don't reset scroll position completely, but ensure it's visible
            // if currently off-screen
            if self.content.scroll && self.scroll_position < -self.text_width {
                // Position text just off screen to the right
                self.scroll_position = self.ctx.display_width as f32;
            }
        }

        // Log that we're preserving animation state
        debug!("Updated TextRenderer content while preserving animation state");
    }
}

impl TextRenderer {
    fn load_font() -> Option<FontArc> {
        let paths = std::iter::once(DEFAULT_FONT_PATH)
            .chain(FALLBACK_FONT_PATHS.iter().copied());

        for path in paths {
            if let Ok(data) = std::fs::read(path) {
                match FontArc::try_from_vec(data) {
                    Ok(font) => {
                        debug!("Loaded font from: {}", path);
                        return Some(font);
                    }
                    Err(e) => debug!("Failed to parse font at {}: {:?}", path, e),
                }
            }
        }
        debug!("No suitable font found. Chinese characters will not render correctly.");
        None
    }

    // Calculate text width based on character count and font metrics
    fn calculate_text_width(&mut self) {
        if let Some(font) = &self.font {
            let scaled_font = font.as_scaled(16.0); // 16px height
            let mut total_advance = 0.0;
            for c in self.content.text.chars() {
                let glyph_id = font.glyph_id(c);
                total_advance += scaled_font.h_advance(glyph_id);
            }
            self.text_width = total_advance;
        } else {
            // Fallback estimation if no font is loaded
            self.text_width = (self.content.text.chars().count() as f32) * 10.0 + 2.0;
        }
    }

    fn render_with_font(&self, canvas: &mut Box<dyn LedCanvas>, font: &FontArc) {
        let scaled_font = font.as_scaled(16.0); // 16px height for better fit
        let [r, g, b] = self.ctx.apply_brightness(self.content.color);
        
        debug!("Rendering text: '{}', text_width: {}, display: {}x{}", 
               self.content.text, self.text_width, self.ctx.display_width, self.ctx.display_height);
        
        // Vertical centering for ab_glyph
        // In ab_glyph, position.y is the baseline
        // Text extends from (baseline - ascent) to (baseline - descent)
        // Visual center = baseline - (ascent + descent) / 2
        // For centering at screen center: baseline = display_height/2 + (ascent + descent)/2
        let ascent = scaled_font.ascent();
        let descent = scaled_font.descent();
        let font_height = ascent - descent;
        
        // Calculate baseline position for perfect vertical centering
        let y_pos = (self.ctx.display_height as f32 / 2.0) + (ascent + descent) / 2.0;
        
        debug!("y_pos: {}, ascent: {}, descent: {}, font_height: {}", y_pos, ascent, descent, font_height);

        let x_start = if self.content.scroll {
            self.scroll_position
        } else {
            ((self.ctx.display_width as f32) - self.text_width) / 2.0
        };
        debug!("x_start: {}", x_start);

        // Render each glyph
        let mut caret = x_start;
        let mut pixel_count = 0;
        for c in self.content.text.chars() {
            let glyph_id = font.glyph_id(c);
            let glyph = ab_glyph::Glyph {
                id: glyph_id,
                scale: ab_glyph::PxScale { x: 16.0, y: 16.0 },
                position: ab_glyph::point(caret, y_pos),
            };
            
            if let Some(outlined) = scaled_font.outline_glyph(glyph.clone()) {
                // px_bounds() returns the absolute bounding box in canvas coordinates
                // No need to add glyph.position again!
                let bb = outlined.px_bounds();
                debug!("Char '{}': position=({}, {}), absolute bounds=({}, {}, {}, {})",
                       c, glyph.position.x, glyph.position.y, bb.min.x, bb.min.y, bb.max.x, bb.max.y);
                
                // Draw the glyph pixels using absolute coordinates directly
                outlined.draw(|x, y, v| {
                    if v > 0.0 {
                        // x and y are u32 pixel coordinates in canvas space
                        let px = x as i32;
                        let py = y as i32;
                        
                        // Bounds check
                        if px >= 0 && px < self.ctx.display_width as i32 &&
                           py >= 0 && py < self.ctx.display_height as i32 {
                            canvas.set_pixel(px as usize, py as usize, r, g, b);
                            pixel_count += 1;
                        }
                    }
                });
                
                // Move to next character
                caret += scaled_font.h_advance(glyph.id);
            } else {
                debug!("Char '{}' has no outline", c);
            }
        }
        debug!("Total pixels drawn: {}", pixel_count);
    }
}
