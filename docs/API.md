# LED 显示屏控制器 API 文档

本文档描述了 LED 显示屏控制器应用程序可用的 API 端点。

## 目录
- [播放列表管理](#播放列表管理)
  - [获取所有播放列表项](#获取所有播放列表项)
  - [创建播放列表项](#创建播放列表项)
  - [获取特定播放列表项](#获取特定播放列表项)
  - [更新播放列表项](#更新播放列表项)
  - [删除播放列表项](#删除播放列表项)
  - [重新排序播放列表项](#重新排序播放列表项)
- [内容载荷](#内容载荷)
  - [文本内容](#文本内容)
  - [图片内容](#图片内容)
- [设置](#设置)
  - [获取亮度](#获取亮度)
  - [更新亮度](#更新亮度)
- [预览模式](#预览模式)
  - [启动预览模式](#启动预览模式)
  - [更新预览内容](#更新预览内容)
  - [退出预览模式](#退出预览模式)
  - [检查预览状态](#检查预览状态)
  - [心跳检测预览会话](#心跳检测预览会话)
  - [检查会话所有权](#检查会话所有权)
- [图片库](#图片库)
  - [上传图片](#上传图片)
  - [获取图片](#获取图片)
- [实时事件](#实时事件)
  - [亮度事件](#亮度事件)
  - [编辑器锁定事件](#编辑器锁定事件)
  - [播放列表事件](#播放列表事件)

## 播放列表管理

### 获取所有播放列表项

获取播放列表中的所有项目。

- **URL**: `/api/playlist/items`
- **方法**: `GET`
- **响应**: 播放列表项数组
  
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "duration": 10,
    "repeat_count": null,
    "border_effect": { "Rainbow": null },
    "content": {
      "type": "Text",
      "data": {
        "type": "Text",
        "text": "Hello World",
        "scroll": false,
        "color": [255, 255, 255],
        "speed": 50.0,
        "text_segments": null
      }
    }
  },
  {
    "id": "44dc1488-be53-4d2d-b6b8-30c4fee522e8",
    "duration": null,
    "repeat_count": 3,
    "border_effect": null,
    "content": {
      "type": "Image",
      "data": {
        "type": "Image",
        "image_id": "c3c8d980-27a7-4a7a-9f56-1f4b1f8bb0fc",
        "natural_width": 128,
        "natural_height": 64,
        "transform": { "x": 0, "y": 0, "scale": 1 },
        "animation": {
          "keyframes": [
            { "timestamp_ms": 0, "x": 0, "y": 0, "scale": 1 },
            { "timestamp_ms": 2000, "x": -16, "y": 0, "scale": 1.5 }
          ],
          "iterations": null
        }
      }
    }
  }
]
```

### 创建播放列表项

创建一个新的播放列表项。

- **URL**: `/api/playlist/items`
- **方法**: `POST`
- **请求体**: 播放列表项（如果未提供 ID，将自动生成）
- **响应**: 包含 ID 的已创建播放列表项

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "duration": 10,
  "repeat_count": null,
  "border_effect": { "Rainbow": null },
  "content": {
    "type": "Text",
    "data": {
      "type": "Text",
      "text": "Hello World",
      "scroll": false,
      "color": [255, 255, 255],
      "speed": 50.0,
      "text_segments": null
    }
  }
}
```

### 获取特定播放列表项

通过 ID 获取特定的播放列表项。

- **URL**: `/api/playlist/items/:id`
- **方法**: `GET`
- **响应**: 播放列表项
- **错误代码**: 
  - `404` - 未找到项目

### 更新播放列表项

更新特定的播放列表项。

- **URL**: `/api/playlist/items/:id`
- **方法**: `PUT`
- **请求体**: 更新后的播放列表项
- **响应**: 更新后的播放列表项
- **错误代码**:
  - `404` - 未找到项目

### 删除播放列表项

删除特定的播放列表项。

- **URL**: `/api/playlist/items/:id`
- **方法**: `DELETE`
- **响应**: 仅状态码
- **错误代码**:
  - `404` - 未找到项目

### 重新排序播放列表项

重新排序所有播放列表项。

- **URL**: `/api/playlist/reorder`
- **方法**: `PUT`
- **请求体**: 有序的项目 ID 数组
```json
{
  "item_ids": ["id1", "id2", "id3"]
}
```
- **响应**: 重新排序后的播放列表项列表
- **错误代码**:
  - `400` - 无效的重新排序请求（缺少项目或数量不正确）

## 内容载荷

每个播放列表或预览项都包含一个 `content` 对象。外层的 `content.type` 帮助 UI/编辑器知道要渲染哪个工具，而嵌套的 `content.data` 是一个带标签的联合体，它重复了 `type` 字段并携带该内容类型的实际属性。

### 文本内容

文本载荷与原始实现相同，但现在位于 `content.data` 内部。

- `text` - 原始 UTF-8 文本
- `scroll` - 当为 `true` 时，消息会滚动，你必须提供 `repeat_count` 而不是 `duration`
- `color` - 基础 RGB 颜色三元组
- `speed` - 滚动速度 (0-100)
- `text_segments` - 用于颜色/格式化的可选覆盖（见前端文档）

静态文本 (`scroll: false`) 需要 `duration` 且必须省略 `repeat_count`。滚动文本需要 `repeat_count` 且必须省略 `duration`。

```json
"content": {
  "type": "Text",
  "data": {
    "type": "Text",
    "text": "Welcome!",
    "scroll": true,
    "color": [255, 255, 255],
    "speed": 50,
    "text_segments": [
      { "start": 0, "end": 7, "color": [255, 0, 0] }
    ]
  }
}
```

### 图片内容

图片可以是静态的也可以是动画的。通过 `POST /api/images` 上传图片以获取 `image_id`。后端将二进制 PNG 存储在 `/var/lib/led-matrix-controller/images` 下，播放列表项只需引用该 ID。

- `image_id` - 上传端点返回的 UUID
- `natural_width` / `natural_height` - 源尺寸，以便编辑器可以准确缩放
- `transform` - `{ "x": number, "y": number, "scale": number }` 描述位图相对于面板左上角的定位方式
- `animation` *(可选)* - 关键帧动画，如果存在则至少有两个条目
  - `keyframes` - 每个条目都有 `timestamp_ms`、`x`、`y` 和 `scale`
  - `iterations` - 循环次数 (`null` = 无限)

静态图片需要 `duration` 且必须省略 `repeat_count`。动画图片（两个或更多关键帧）需要 `repeat_count`，必须省略 `duration`，且前端会强制执行最小关键帧数。

```json
"content": {
  "type": "Image",
  "data": {
    "type": "Image",
    "image_id": "c3c8d980-27a7-4a7a-9f56-1f4b1f8bb0fc",
    "natural_width": 128,
    "natural_height": 64,
    "transform": { "x": -8, "y": 0, "scale": 1.25 },
    "animation": {
      "keyframes": [
        { "timestamp_ms": 0, "x": 0, "y": 0, "scale": 1 },
        { "timestamp_ms": 2500, "x": -16, "y": 0, "scale": 1.5 }
      ],
      "iterations": null
    }
  }
}
```

Set `"animation": null` (or omit it) to display a static image with a fixed transform.

### 时钟内容

时钟条目会在显示屏中央渲染树莓派的本地时间。它们始终使用 `duration` 进行计时，且必须省略 `repeat_count`。

- `format` - `"24h"` 或 `"12h"`
- `show_seconds` - `true` 表示每秒更新，`false` 表示仅分钟更新
- `color` - 数字的 RGB 元组

```json
"content": {
  "type": "Clock",
  "data": {
    "type": "Clock",
    "format": "24h",
    "show_seconds": false,
    "color": [255, 255, 255]
  }
}
```

时钟项支持与其他播放列表条目相同的边框效果。

## 设置

### 获取亮度

获取当前的亮度设置。

- **URL**: `/api/settings/brightness`
- **方法**: `GET`
- **响应**: 当前亮度 (0-100)
```json
{
  "brightness": 75
}
```

### 更新亮度

更新显示亮度。

- **URL**: `/api/settings/brightness`
- **方法**: `PUT`
- **请求体**: 新的亮度设置
```json
{
  "brightness": 75
}
```
- **响应**: 更新后的亮度设置
```json
{
  "brightness": 75
}
```

## 预览模式

### 启动预览模式

使用指定内容启动预览模式。如果另一个预览会话已经处于活动状态，则会失败。

- **URL**: `/api/preview`
- **方法**: `POST`
- **请求体**: 要预览的播放列表项（不需要会话 ID）
```json
{
  "id": "preview-item",
  "duration": 10,
  "border_effect": null,
  "content": {
    "type": "Text",
    "data": {
      "type": "Text",
      "text": "Preview Text",
      "scroll": false,
      "color": [255, 255, 255],
      "speed": 50.0,
      "text_segments": null
    }
  }
}
```
- **响应**: 包含服务器生成会话 ID 的预览模式响应
```json
{
  "item": {
    "id": "preview-item",
    "duration": 10,
    "border_effect": null,
    "content": {
      "type": "Text",
      "data": {
        "type": "Text",
        "text": "Preview Text",
        "scroll": false,
        "color": [255, 255, 255],
        "speed": 50.0,
        "text_segments": null
      }
    }
  },
  "session_id": "550e8400-e29b-41d4-a716-446655440000"
}
```
- **错误代码**:
  - `403` - 另一个预览会话已经处于活动状态

**注意**: 返回的会话 ID 必须保存并用于所有后续的预览操作（更新、心跳检测、退出）。 

### 更新预览内容

更新正在预览的内容。

- **URL**: `/api/preview`
- **方法**: `PUT`
- **请求体**: 更新后的项目和会话 ID
```json
{
  "item": {
    "id": "preview-item",
    "duration": 10,
    "border_effect": null,
    "content": {
      "type": "Text",
      "data": {
        "type": "Text",
        "text": "Updated Preview Text",
        "scroll": false,
        "color": [255, 0, 0],
        "speed": 50.0,
        "text_segments": null
      }
    }
  },
  "session_id": "550e8400-e29b-41d4-a716-446655440000"
}
```
- **响应**: 更新后的预览响应
- **错误代码**:
  - `403` - 会话不拥有预览锁
  - `404` - 未处于预览模式

### 退出预览模式

退出预览模式。

- **URL**: `/api/preview`
- **方法**: `DELETE`
- **请求体**: 用于授权的会话 ID
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000"
}
```
- **响应**: 仅状态码
- **错误代码**:
  - `403` - 会话不拥有预览锁
  - `404` - 未处于预览模式

**注意**: 只有启动预览模式的会话才能退出它。

### 检查预览状态

检查显示屏当前是否处于预览模式。

- **URL**: `/api/preview/status`
- **方法**: `GET`
- **响应**: 预览模式状态
```json
{
  "active": true
}
```

### 心跳检测预览会话

防止预览模式超时。只有启动预览的会话才能对其进行心跳检测。

- **URL**: `/api/preview/ping`
- **方法**: `POST`
- **请求体**: 用于授权的会话 ID
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000"
}
```
- **响应**: 仅状态码
- **错误代码**:
  - `403` - 会话不拥有预览锁
  - `404` - 未处于预览模式 

### 检查会话所有权

检查会话是否拥有当前的预览锁。

- **URL**: `/api/preview/session`
- **方法**: `POST`
- **请求体**: 要检查的会话 ID
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000"
}
```
- **响应**: 所有权状态
```json
{
  "is_owner": true
}
```

## 图片库

上传一次图片，然后通过返回的 `image_id` 在多个播放列表项中引用它。

### 上传图片

接受多部分上传，验证载荷，将所有内容转换为 PNG，并将字节存储在 `/var/lib/led-matrix-controller/images` 下。

- **URL**: `/api/images`
- **方法**: `POST`
- **请求体**: 带有单个 `file` 字段的 `multipart/form-data`（PNG/JPEG/GIF，最大 30 MB）
- **响应**:
```json
{
  "image_id": "c3c8d980-27a7-4a7a-9f56-1f4b1f8bb0fc",
  "width": 128,
  "height": 64,
  "thumbnail_width": 64,
  "thumbnail_height": 48
}
```
- **错误代码**:
  - `400` - 无效的多部分载荷或空文件
  - `413` - 文件超过 30 MB
  - `415` - 不支持的图片格式/解码器失败
  - `500` - 无法持久化 PNG

### 获取图片

返回存储的 PNG 字节用于预览或诊断。

- **URL**: `/api/images/:id`
- **方法**: `GET`
- **响应**: 原始 `image/png` 主体（直接在 `<img>` 标签或 `<canvas>` 中使用）
- **错误代码**:
  - `404` - 该 `image_id` 不存在图片

### 获取图片缩略图

返回预生成的缩略图（PNG），用于轻量级预览，例如播放列表卡片。缩略图在上传期间自动生成，如果缺失则按需延迟重新生成。

- **URL**: `/api/images/:id/thumbnail`
- **方法**: `GET`
- **响应**: 原始 `image/png` 缩略图（适应 128×96 以内并保持纵横比）
- **错误代码**:
  - `404` - 该 `image_id` 不存在图片

## 实时事件

应用程序提供服务器发送事件 (SSE) 以实现实时更新。

### 亮度事件

订阅亮度更改事件。

- **URL**: `/api/events/brightness`
- **方法**: `GET`
- **内容类型**: `text/event-stream`
- **事件格式**:
```json
{
  "brightness": 75
}
```

### 编辑器锁定事件

订阅编辑器锁定状态更改。

- **URL**: `/api/events/editor`
- **方法**: `GET`
- **内容类型**: `text/event-stream`
- **事件格式**:
```json
{
  "locked": true,
  "locked_by": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 播放列表事件

订阅播放列表更新事件。

- **URL**: `/api/events/playlist`
- **方法**: `GET`
- **内容类型**: `text/event-stream`
- **事件格式**:
```json
{
  "items": [/* array of playlist items */],
  "action": "Add" // One of: "Add", "Update", "Delete", "Reorder"
}
```
