use crate::models::border_effects::BorderEffect;
use crate::models::content::{ContentData, ContentDetails};
use crate::models::text::TextContent;
use crate::utils::uuid::generate_uuid_string;
use serde::{Deserialize, Serialize};

#[derive(Clone, Serialize, Deserialize)]
pub struct Playlist {
    pub items: Vec<PlayListItem>,
    pub active_index: usize,
    pub repeat: bool,
}

impl Default for Playlist {
    fn default() -> Self {
        Self {
            items: vec![], // Start with an empty playlist
            active_index: 0,
            repeat: true,
        }
    }
}

// Base structure for all display content items
#[derive(Clone, Serialize)]
pub struct PlayListItem {
    #[serde(default = "generate_uuid_string")]
    pub id: String,
    pub duration: Option<u64>, // Display duration in seconds (None = use repeat_count instead)
    pub repeat_count: Option<u32>, // Number of times to repeat (None = use duration instead)
    pub border_effect: Option<BorderEffect>, // Optional border effect
    pub content: ContentData,
}

// Custom deserialization to enforce mutual exclusivity and scroll validation
impl<'de> Deserialize<'de> for PlayListItem {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        #[derive(Deserialize)]
        struct Helper {
            #[serde(default = "generate_uuid_string")]
            id: String,
            duration: Option<u64>,
            repeat_count: Option<u32>,
            border_effect: Option<BorderEffect>,
            content: ContentData,
        }

        let helper = Helper::deserialize(deserializer)?;

        // Check that exactly one of duration or repeat_count is provided
        match (helper.duration, helper.repeat_count) {
            (Some(_), Some(_)) => {
                return Err(serde::de::Error::custom(
                    "不能同时提供 'duration' 和 'repeat_count'",
                ));
            }
            (None, None) => {
                return Err(serde::de::Error::custom(
                    "必须提供 'duration' 或 'repeat_count' 中的一个",
                ));
            }
            _ => {} // Exactly one is provided, which is valid
        }

        // Check for consistent configuration between content configuration and timing
        match &helper.content.data {
            ContentDetails::Text(text_content) => {
                if !text_content.scroll && helper.repeat_count.is_some() {
                    return Err(serde::de::Error::custom(
                        "当 'scroll' 为 false 时，必须使用 'duration' 而不是 'repeat_count'",
                    ));
                }
                if text_content.scroll && helper.duration.is_some() {
                    return Err(serde::de::Error::custom(
                        "当 'scroll' 为 true 时，必须使用 'repeat_count' 而不是 'duration'",
                    ));
                }
            }
            ContentDetails::Image(image_content) => {
                if image_content.image_id.trim().is_empty() {
                    return Err(serde::de::Error::custom(
                        "图片内容需要有效的 'image_id'",
                    ));
                }
                if image_content.natural_width == 0 || image_content.natural_height == 0 {
                    return Err(serde::de::Error::custom(
                        "图片内容需要非零的自然尺寸",
                    ));
                }

                if let Some(animation) = &image_content.animation {
                    if animation.keyframes.len() < 2 {
                        return Err(serde::de::Error::custom(
                            "动画图片至少需要两个关键帧",
                        ));
                    }
                    if helper.duration.is_some() {
                        return Err(serde::de::Error::custom(
                            "动画图片必须使用 'repeat_count' 而不是 'duration'",
                        ));
                    }
                } else if helper.duration.is_none() {
                    return Err(serde::de::Error::custom(
                        "静态图片需要 'duration' 而不是 'repeat_count'",
                    ));
                }
            }
            ContentDetails::Clock(_) => {
                if helper.duration.is_none() {
                    return Err(serde::de::Error::custom(
                        "时钟内容需要 'duration' 而不是 'repeat_count'",
                    ));
                }
                if helper.repeat_count.is_some() {
                    return Err(serde::de::Error::custom(
                        "时钟内容使用 'duration' 而不是 'repeat_count'",
                    ));
                }
            }
            ContentDetails::Animation(animation_content) => {
                if helper.duration.is_none() {
                    return Err(serde::de::Error::custom(
                        "动画内容需要 'duration' 而不是 'repeat_count'",
                    ));
                }
                if helper.repeat_count.is_some() {
                    return Err(serde::de::Error::custom(
                        "动画内容需要 'duration' 且不允许 'repeat_count'",
                    ));
                }
                if let Err(err) = animation_content.validate() {
                    return Err(serde::de::Error::custom(err));
                }
            }
        }

        // Determine whether repeat_count is required based on content
        let requires_repeat_count = match &helper.content.data {
            ContentDetails::Text(text_content) => text_content.scroll,
            ContentDetails::Image(image_content) => image_content.animation.is_some(),
            ContentDetails::Clock(_) => false,
            ContentDetails::Animation(_) => false,
        };

        // Check if repeat_count is required but missing
        if requires_repeat_count && helper.repeat_count.is_none() {
            let msg = match &helper.content.data {
                ContentDetails::Text(_) => {
                    "当 'scroll' 为 true 时，必须使用 'repeat_count' 而不是 'duration'"
                }
                ContentDetails::Image(_) => {
                    "动画图片需要 'repeat_count' 而不是 'duration'"
                }
                ContentDetails::Clock(_) => unreachable!(),
                ContentDetails::Animation(_) => {
                    "动画内容需要 'duration' 而不是 'repeat_count'"
                }
            };
            return Err(serde::de::Error::custom(msg));
        }

        // Additional check: static content that shouldn't repeat_count
        if !requires_repeat_count && helper.repeat_count.is_some() {
            return Err(serde::de::Error::custom(
                "重复计数只能用于滚动文本或动画图片",
            ));
        }

        Ok(PlayListItem {
            id: helper.id,
            duration: helper.duration,
            repeat_count: helper.repeat_count,
            border_effect: helper.border_effect,
            content: helper.content,
        })
    }
}

// Default implementation for PlayListItem
impl Default for PlayListItem {
    fn default() -> Self {
        Self {
            id: generate_uuid_string(),
            duration: Some(10), // Default to 10 seconds duration
            repeat_count: None, // No repeat count by default (exclusive with duration)
            border_effect: None,
            content: ContentData {
                content_type: crate::models::content::ContentType::Text,
                data: ContentDetails::Text(TextContent {
                    text: String::new(),
                    scroll: true,
                    color: [255, 255, 255],
                    speed: 50.0,
                    text_segments: None,
                }),
            },
        }
    }
}
