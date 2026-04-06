use serde::{Deserialize, Serialize};

/// Animation presets supported by the controller.
/// This enum is represented as an internally tagged union so JSON payloads look like:
/// {"preset":"Pulse","colors":[...],"cycle_ms":2000}
#[derive(Clone, Serialize, Deserialize, Debug)]
#[serde(tag = "preset")]
pub enum AnimationContent {
    Pulse {
        colors: Vec<[u8; 3]>,
        #[serde(default = "default_cycle_ms")]
        cycle_ms: u32,
    },
    PaletteWave {
        colors: Vec<[u8; 3]>,
        #[serde(default = "default_cycle_ms")]
        cycle_ms: u32,
        #[serde(default = "default_wave_count")]
        wave_count: u8,
    },
    DualPulse {
        colors: Vec<[u8; 3]>,
        #[serde(default = "default_cycle_ms")]
        cycle_ms: u32,
        #[serde(default = "default_phase_offset")]
        phase_offset: f32,
    },
    ColorFade {
        colors: Vec<[u8; 3]>,
        #[serde(default = "default_wash_speed")]
        drift_speed: f32,
    },
    Strobe {
        colors: Vec<[u8; 3]>,
        #[serde(default = "default_flash_ms")]
        flash_ms: u32,
        #[serde(default = "default_fade_ms")]
        fade_ms: u32,
        #[serde(default)]
        randomize: bool,
        #[serde(default = "default_strobe_randomization_factor")]
        randomization_factor: f32,
    },
    Sparkle {
        colors: Vec<[u8; 3]>,
        #[serde(default = "default_sparkle_density")]
        density: f32,
        #[serde(default = "default_sparkle_cycle_ms")]
        twinkle_ms: u32,
    },
    MosaicTwinkle {
        colors: Vec<[u8; 3]>,
        #[serde(default = "default_mosaic_twinkle_tile_size")]
        tile_size: u8,
        #[serde(default = "default_mosaic_twinkle_speed")]
        flow_speed: f32,
        #[serde(default = "default_mosaic_twinkle_border_size")]
        border_size: u8,
        #[serde(default = "default_mosaic_twinkle_border_color")]
        border_color: [u8; 3],
    },
    Plasma {
        colors: Vec<[u8; 3]>,
        #[serde(default = "default_plasma_flow_speed")]
        flow_speed: f32,
        #[serde(default = "default_plasma_noise_scale")]
        noise_scale: f32,
    },
}

fn default_cycle_ms() -> u32 {
    2_000
}

fn default_wave_count() -> u8 {
    3
}

fn default_phase_offset() -> f32 {
    0.5
}

fn default_wash_speed() -> f32 {
    0.25
}

fn default_flash_ms() -> u32 {
    180
}

fn default_fade_ms() -> u32 {
    220
}

fn default_strobe_randomization_factor() -> f32 {
    0.35
}

fn default_sparkle_density() -> f32 {
    0.12
}

fn default_sparkle_cycle_ms() -> u32 {
    600
}

fn default_mosaic_twinkle_tile_size() -> u8 {
    1
}

fn default_mosaic_twinkle_speed() -> f32 {
    0.35
}

fn default_mosaic_twinkle_border_size() -> u8 {
    0
}

fn default_mosaic_twinkle_border_color() -> [u8; 3] {
    [50, 0, 0]
}

fn default_plasma_flow_speed() -> f32 {
    1.85
}

fn default_plasma_noise_scale() -> f32 {
    1.75
}

impl AnimationContent {
    /// Returns true if this animation requires at least one color in the palette.
    fn requires_palette(&self) -> bool {
        match self {
            AnimationContent::Sparkle { .. } => true,
            AnimationContent::Pulse { .. }
            | AnimationContent::PaletteWave { .. }
            | AnimationContent::DualPulse { .. }
            | AnimationContent::ColorFade { .. }
            | AnimationContent::Strobe { .. }
            | AnimationContent::MosaicTwinkle { .. }
            | AnimationContent::Plasma { .. } => true,
        }
    }

    /// Validate configuration values. Returns an error string on invalid inputs.
    pub fn validate(&self) -> Result<(), String> {
        let palette_len = self.palette().len();
        if self.requires_palette() && palette_len == 0 {
            return Err("动画预设至少需要一种颜色".to_string());
        }

        match self {
            AnimationContent::Pulse { cycle_ms, .. }
            | AnimationContent::PaletteWave { cycle_ms, .. }
            | AnimationContent::DualPulse { cycle_ms, .. } => {
                if *cycle_ms == 0 {
                    return Err("cycle_ms 必须大于零".to_string());
                }
            }
            AnimationContent::ColorFade { drift_speed, .. } => {
                if !drift_speed.is_finite() || *drift_speed <= 0.0 {
                    return Err("drift_speed 必须是正有限值".to_string());
                }
            }
            AnimationContent::Strobe {
                flash_ms,
                fade_ms,
                randomization_factor,
                ..
            } => {
                if *flash_ms == 0 {
                    return Err("flash_ms 必须大于零".to_string());
                }
                if *fade_ms == 0 {
                    return Err("fade_ms 必须大于零".to_string());
                }
                if !randomization_factor.is_finite()
                    || *randomization_factor < 0.0
                    || *randomization_factor > 1.0
                {
                    return Err("randomization_factor 必须在 0.0 到 1.0 之间".to_string());
                }
            }
            AnimationContent::Sparkle {
                density,
                twinkle_ms,
                ..
            } => {
                if !density.is_finite() || *density <= 0.0 || *density > 1.0 {
                    return Err("density 必须在 (0, 1] 范围内".to_string());
                }
                if *twinkle_ms == 0 {
                    return Err("twinkle_ms 必须大于零".to_string());
                }
            }
            AnimationContent::MosaicTwinkle {
                tile_size,
                flow_speed,
                border_size,
                ..
            } => {
                if *tile_size == 0 {
                    return Err("tile_size 必须至少为 1".to_string());
                }
                if !flow_speed.is_finite() || *flow_speed <= 0.0 {
                    return Err("flow_speed 必须是正有限值".to_string());
                }
                if *border_size > *tile_size {
                    return Err("border_size 必须小于或等于 tile_size".to_string());
                }
            }
            AnimationContent::Plasma {
                flow_speed,
                noise_scale,
                ..
            } => {
                if !flow_speed.is_finite() || *flow_speed <= 0.0 {
                    return Err("flow_speed 必须是正有限值".to_string());
                }
                if !noise_scale.is_finite() || *noise_scale <= 0.0 {
                    return Err("noise_scale 必须是正有限值".to_string());
                }
            }
        }

        match self {
            AnimationContent::PaletteWave { wave_count, .. } => {
                if *wave_count == 0 {
                    return Err("wave_count 必须至少为 1".to_string());
                }
            }
            AnimationContent::DualPulse { phase_offset, .. } => {
                if !phase_offset.is_finite() {
                    return Err("phase_offset 必须是有限值".to_string());
                }
            }
            _ => {}
        }

        Ok(())
    }

    /// Convenience accessor for color palette
    pub fn palette(&self) -> &Vec<[u8; 3]> {
        match self {
            AnimationContent::Pulse { colors, .. }
            | AnimationContent::PaletteWave { colors, .. }
            | AnimationContent::DualPulse { colors, .. }
            | AnimationContent::ColorFade { colors, .. }
            | AnimationContent::Strobe { colors, .. }
            | AnimationContent::Sparkle { colors, .. }
            | AnimationContent::MosaicTwinkle { colors, .. }
            | AnimationContent::Plasma { colors, .. } => colors,
        }
    }
}
