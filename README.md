<div align="center">
<img src="https://github.com/user-attachments/assets/a1dffcaf-3105-459d-9a94-baef4ccfc8fd" width=200>
	
# RPi LED Sign Controller (中文版)
###### 适用于树莓派的 LED 矩阵显示屏控制器，支持基于 Web 的配置。

## 功能特性

- 控制连接到树莓派 GPIO 的 RGB LED 矩阵面板
- 基于 Web 的配置界面
- 支持自定义速度和颜色的文本滚动
- 支持图片及关键帧动画
- 提供两种驱动选项：原生 Rust（推荐）或 C++ 绑定
- 支持多种 LED 矩阵面板配置

## 快速安装

要在您的树莓派上快速安装或更新 LED 显示屏控制器，您可以使用此安装程序：

```bash
# 下载安装脚本
curl -sSL https://raw.githubusercontent.com/kxgx/RPi-LED-Sign-Controller-zh/main/scripts/install.sh -o install.sh
# 使用 sudo 运行
sudo bash install.sh
```

这将下载并运行安装脚本，它会检查现有安装、安装/更新依赖项、构建应用程序并帮助您配置 LED 面板。


## 截图

### 播放列表管理器

<div align="left">
  <img src="https://github.com/user-attachments/assets/954eea72-f67a-4603-b0e8-8d999f58529e" width=50%>
</div>

### 编辑器

<div align="left">
  <img src="https://github.com/user-attachments/assets/9995bb02-5345-4470-8f41-761f37b05a06" width=50%>
</div>

## 安装说明

### 前置要求

- 树莓派（已在 Pi 4 上测试）
- 兼容 HUB75 接口的 LED 矩阵面板
- Rust 工具链 (rustc, cargo)（如果不使用快速安装）

### 从源代码构建

首先编译前端并将输出文件复制到 `/static` 目录。您可以在 [此处](https://github.com/paviro/RPi-LED-Sign-Controller-Frontend) 找到前端代码。

之后您可以继续处理后端，前端文件将被嵌入到最终的二进制文件中。

```bash
# 克隆仓库
git clone https://github.com/kxgx/RPi-LED-Sign-Controller-zh.git
cd RPi-LED-Sign-Controller-zh

# 构建项目
cargo build --release

```

## 使用方法

该应用程序提供了一个 Web 界面，可通过 `http://<树莓派IP>:3000` 访问以配置显示内容。

运行应用程序：

```bash
# 使用原生 Rust 驱动的基本用法
sudo ./target/release/rpi_led_sign_controller --driver native --rows 32 --cols 64 --chain-length 1

# 使用 C++ 绑定驱动
sudo ./target/release/rpi_led_sign_controller --driver binding --rows 32 --cols 64 --chain-length 1
```

## 驱动选择

该应用程序支持两种不同的 LED 矩阵驱动：

1. **原生 (Native)** (`--driver native`): 来自 [rpi_led_panel](https://github.com/EmbersArc/rpi_led_panel) 的纯 Rust 实现
2. **绑定 (Binding)** (`--driver binding`): 对 Henner Zeller 的 [rpi-rgb-led-matrix](https://github.com/hzeller/rpi-rgb-led-matrix) 库的 C++ 绑定

## 命令行参数

| 参数 | 类型 | 描述 | 默认值 | 支持情况 |
|----------|------|-------------|---------|-------------|
| `--driver`, `-d` | 选项 | 驱动类型: "native" 或 "binding" (必填) | - | 两者 |
| `--rows`, `-r` | 选项 | 每个面板的行数 | 32 | 两者 |
| `--cols`, `-c` | 选项 | 每个面板的列数 | 64 | 两者 |
| `--parallel`, `-p` | 选项 | 并行运行的链数 | 1 | 两者 |
| `--chain-length`, `-n` | 选项 | 串联的面板数量 | 1 | 两者 |
| `--limit-max-brightness` | 选项 | 最大亮度限制 (0-100)。UI 的 100% 设置将等于此值 | 100 | 两者 |
| `--hardware-mapping` | 选项 | 显示接线配置 | "regular" | 两者 |
| `--limit-refresh-rate` | 选项 | 限制刷新率 (Hz) (0 = 无限制) | 0 | 两者 |
| `--pi-chip` | 选项 | 树莓派芯片型号 (例如 "BCM2711") | auto | 原生 |
| `--pwm-bits` | 选项 | 颜色深度的 PWM 位数 (1-11) | 11 | 两者 |
| `--pwm-lsb-nanoseconds` | 选项 | LSB 中开启时间的基本时间单位 | 130 | 两者 |
| `--gpio-slowdown` | 选项 | GPIO 减速因子 (0-4) | auto | 两者 |
| `--dither-bits` | 选项 | 时间抖动位数 | 0 | 两者 |
| `--panel-type` | 选项 | 面板初始化类型 (例如 "FM6126A") | - | 两者 |
| `--multiplexing` | 选项 | 多路复用类型 | - | 两者 |
| `--pixel-mapper` | 选项 | 像素映射器列表 ("U-mapper;Rotate:90") | - | 两者 |
| `--row-setter` | 选项 | 行地址设置器类型 | "direct" | 两者 |
| `--led-sequence` | 选项 | LED 颜色序列 | "RGB" | 两者 |
| `--interlaced` | 开关 | 启用隔行扫描模式 | 禁用 | 两者 |
| `--no-hardware-pulse` | 开关 | 禁用硬件引脚脉冲生成 | 禁用 | 绑定 |
| `--show-refresh` | 开关 | 在终端显示刷新率 | 禁用 | 绑定 |
| `--inverse-colors` | 开关 | 反转显示颜色 | 禁用 | 绑定 |


## 环境变量

所有命令行选项都可以通过带有 `LED_` 前缀的环境变量进行设置。

| 环境变量 | 等效的命令行参数 |
|----------------------|-------------------------|
| `LED_DRIVER` | `--driver` |
| `LED_ROWS` | `--rows` |
| `LED_COLS` | `--cols` |
| `LED_CHAIN_LENGTH` | `--chain-length` |
| `LED_PARALLEL` | `--parallel` |
| `LED_LIMIT_MAX_BRIGHTNESS` | `--limit-max-brightness` |
| `LED_HARDWARE_MAPPING` | `--hardware-mapping` |
| `LED_LIMIT_REFRESH_RATE` | `--limit-refresh-rate` |
| `LED_PI_CHIP` | `--pi-chip` |
| `LED_PWM_BITS` | `--pwm-bits` |
| `LED_PWM_LSB_NANOSECONDS` | `--pwm-lsb-nanoseconds` |
| `LED_GPIO_SLOWDOWN` | `--gpio-slowdown` |
| `LED_DITHER_BITS` | `--dither-bits` |
| `LED_PANEL_TYPE` | `--panel-type` |
| `LED_MULTIPLEXING` | `--multiplexing` |
| `LED_PIXEL_MAPPER` | `--pixel-mapper` |
| `LED_ROW_SETTER` | `--row-setter` |
| `LED_SEQUENCE` | `--led-sequence` |
| `LED_HARDWARE_PULSING` | `--no-hardware-pulse` (反向) |
| `LED_SHOW_REFRESH` | `--show-refresh` |
| `LED_INVERSE_COLORS` | `--inverse-colors` |

## 硬件映射选项

`--hardware-mapping` 参数取决于您的 LED 矩阵如何连接到树莓派。

| 映射值 | 别名 | 描述 | 驱动支持 |
|---------------|----------------|-------------|----------------|
| `regular` | | 标准 GPIO 映射 (默认) | 两者 |
| `adafruit-hat` | `AdafruitHat` | Adafruit RGB Matrix Bonnet/HAT | 两者 |
| `adafruit-hat-pwm` | `AdafruitHatPwm` | 带硬件 PWM 的 Adafruit HAT | 两者 |
| `regular-pi1` | `RegularPi1` | 树莓派 1 的标准 GPIO 映射 | 两者 |
| `classic` | | 早期版本的矩阵接线 (不建议用于新设置) | 两者 |
| `classic-pi1` | `ClassicPi1` | Pi 1 Rev A 的早期版本 | 两者 |

为了与两种驱动的向后兼容性，同时支持烤肉串命名法 (`adafruit-hat`) 和大驼峰命名法 (`AdafruitHat`)。

## 行设置器选项

`--row-setter` 参数控制如何在 LED 矩阵上设置行地址。支持以下选项：

| 选项值 | 别名 | 描述 |
|--------------|----------------|-------------|
| `direct` | `default` | 直接行选择 (默认) |
| `shiftregister` | `ab-addressed` | 移位寄存器选择 (AB 寻址面板) |
| `directabcdline` | `direct-row-select` | 直接 ABCD 线选择 |
| `abcshiftregister` | `abc-addressed` | ABC 移位寄存器选择 |
| `sm5266` | `abc-shift-de` | SM5266 带 ABC 移位器 + DE 直接 |

行设置器决定了如何配置 GPIO 引脚以寻址 LED 面板上的不同行。正确的值取决于您特定的 LED 面板类型和接线配置。

## 多路复用选项

`--multiplexing` 参数决定了显示屏的电气多路复用方式。

| 多路复用值 | 描述 |
|--------------------|-------------|
| `Stripe` | 传统的逐行多路复用 (绑定驱动的默认值) |
| `Checkered`, `Checker` | 交替像素位于不同的扫描线上 |
| `Spiral` | 使用矩阵段螺旋的面板 |
| `ZStripe`, `ZStripe08` | 8 像素间隔的 Z 型条纹 |
| `ZStripe44` | 4x4 像素间隔的 Z 型条纹 |
| `ZStripe80` | 8x0 像素间隔的 Z 型条纹 |
| `Coreman` | 某些 Colorlight 控制器中使用的多路复用 |
| `Kaler2Scan` | 某些 Kaler 面板中使用的扫描模式 |
| `P10Z` | 具有 Z 布局的 P10 户外面板 |
| `QiangLiQ8` | QiangLi Q8 面板 |
| `InversedZStripe` | 反向 Z 型条纹模式 |
| `P10Outdoor1R1G1B1` | P10 户外面板变体 1 |
| `P10Outdoor1R1G1B2` | P10 户外面板变体 2 |
| `P10Outdoor1R1G1B3` | P10 户外面板变体 3 |
| `P10Coreman` | 具有 Coreman 多路复用的 P10 面板 |
| `P8Outdoor1R1G1B` | P8 户外面板 |
| `FlippedStripe` | 翻转方向的条纹模式 |
| `P10Outdoor32x16HalfScan` | 半扫描的 P10 32x16 户外面板 |

正确的多路复用选项取决于您特定的面板类型。大多数常见面板使用 `Stripe` 或 `Checkered`。

## Web 服务器配置

该应用程序包含一个用于配置和控制 LED 矩阵的 Web 服务器。您可以使用以下选项自定义此 Web 服务器的绑定方式：

### Web 服务器选项

| 选项 | 描述 | 默认值 |
|--------|-------------|---------|
| `--port` | Web 服务器端口 | 3000 |
| `--interface` | 绑定的网络接口 | `0.0.0.0` (所有接口) |

### 环境变量

这些设置也可以使用环境变量进行配置：

- `LED_PORT` - 设置 Web 服务器端口
- `LED_INTERFACE` - 设置绑定接口

## 命令行使用说明

### 选项与开关

本应用程序使用两种具有不同行为的命令行参数：

#### 1. 命令行参数

- **选项** 需要值: `--rows 32`, `--cols 64`
- **开关** 是没有值的标志:
  - 启用: 包含开关 (例如 `--interlaced`)
  - 禁用: 完全省略开关

#### 2. 环境变量

所有参数（包括开关）在设置为环境变量时都接受值：

- 对于普通选项: `LED_ROWS=32`, `LED_COLS=64`
- 对于开关: 
  - 启用: `LED_INTERLACED=true` 或 `LED_INTERLACED=1`
  - 禁用: `LED_INTERLACED=false` 或 `LED_INTERLACED=0`

CLI 开关和环境变量之间的这种行为差异是由于环境变量的基本工作方式——它们必须始终有一个值，而 CLI 标志可以存在或不存在。

### 特例：硬件脉冲

请注意，环境变量 `LED_HARDWARE_PULSING` 与其命令行对应项 `--no-hardware-pulse` 是反向的：

- CLI: `--no-hardware-pulse` (禁用硬件脉冲)
- ENV: `LED_HARDWARE_PULSING=false` (也禁用硬件脉冲)

这种反转是因为 CLI 标志是一个“否定”开关。

## 免责声明

本项目是在 AI（特别是 Claude）的显著协助下开发的。虽然已努力确保代码质量，但实现中可能包含低效或非惯用的模式。欢迎贡献和改进！我并不是 Rust 开发者 🙈

## 致谢

- [rpi_led_panel](https://github.com/EmbersArc/rpi_led_panel) - 原生 Rust 驱动
- [rpi-rgb-led-matrix](https://github.com/hzeller/rpi-rgb-led-matrix) - C++ 库
- [rust-rpi-rgb-led-matrix](https://github.com/rust-rpi-led-matrix/rust-rpi-rgb-led-matrix) - Rust 绑定
