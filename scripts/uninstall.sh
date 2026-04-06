#!/bin/bash
set -e

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}树莓派 LED 显示屏控制器 - 卸载脚本${NC}"
echo -e "==============================================="
echo -e "GitHub 仓库: ${GREEN}https://github.com/paviro/rpi-led-sign-controller${NC}"

# Check if script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (use sudo)${NC}"
  exit 1
fi

# Determine the actual user who ran the script
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

# 添加解释和确认
echo -e "\n${YELLOW}此卸载脚本将会:${NC}"
echo -e "  • 停止并移除树莓派 LED 显示屏控制器的 systemd 服务"
echo -e "  • 从 /usr/local/bin 移除应用程序二进制文件"
echo -e "  • 提供从 /usr/local/src/rpi-led-sign-controller 移除源代码的选项"
echo -e "  • 检查并提供移除 /var/lib/led-matrix-controller 中数据文件的选项"
echo -e "  • 询问是否要卸载 Rust, Git 和 NVM"
echo -e "  • 提供使用 apt autoremove 清理未使用包的选项"
echo -e "\n${YELLOW}您将被要求确认每一步操作。${NC}"

# 确认继续卸载
read -p "您要继续卸载吗？ [y/N]: " confirm_uninstall
if [[ "$confirm_uninstall" != "y" && "$confirm_uninstall" != "Y" ]]; then
    echo -e "${GREEN}卸载已取消。${NC}"
    exit 0
fi

echo -e "${YELLOW}开始卸载...${NC}"

# Function to get yes/no input
get_yes_no() {
    local prompt=$1
    local default=$2
    local value
    
    # Set the display and default value
    if [[ "$default" == "y" || "$default" == "Y" ]]; then
        default_display="Y/n"
        default_value=1
    else
        default_display="y/N"
        default_value=0
    fi
    
    # Format prompt consistently with other inputs
    read -p "${prompt} (default: $([ $default_value -eq 1 ] && echo "yes" || echo "no")) [${default_display}]: " value
    value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
    
    if [[ -z "$value" ]]; then
        echo $default_value
    elif [[ "$value" == "y" ]]; then
        echo 1
    else
        echo 0
    fi
}

# Stop and disable the systemd service
if systemctl is-active --quiet rpi-led-sign.service; then
    echo -e "${YELLOW}正在停止服务...${NC}"
    systemctl stop rpi-led-sign.service
fi

if systemctl is-enabled --quiet rpi-led-sign.service 2>/dev/null; then
    echo -e "${YELLOW}正在禁用服务...${NC}"
    systemctl disable rpi-led-sign.service
fi

# Remove the systemd service file
if [ -f /etc/systemd/system/rpi-led-sign.service ]; then
    echo -e "${YELLOW}正在移除 systemd 服务...${NC}"
    rm /etc/systemd/system/rpi-led-sign.service
    systemctl daemon-reload
    echo -e "${GREEN}Systemd 服务已移除。${NC}"
fi

# Remove the binary
if [ -f /usr/local/bin/rpi_led_sign_controller ]; then
    echo -e "${YELLOW}正在移除二进制文件...${NC}"
    rm /usr/local/bin/rpi_led_sign_controller
    echo -e "${GREEN}二进制文件已移除。${NC}"
fi

# Remove source code - improved to check current directory
REPO_DIR="/usr/local/src/rpi-led-sign-controller"
CURRENT_DIR=$(pwd)

# Determine if we're running from within a repository
IS_REPO_DIR=false
if [ -f "Cargo.toml" ] && grep -q "rpi_led_sign_controller" "Cargo.toml" 2>/dev/null; then
    IS_REPO_DIR=true
    echo -e "${YELLOW}正在从仓库目录中运行。${NC}"
fi

# Check if we're in a scripts subdirectory of a repository
if [ -f "../Cargo.toml" ] && grep -q "rpi_led_sign_controller" "../Cargo.toml" 2>/dev/null; then
    IS_REPO_DIR=true
    CURRENT_DIR=$(cd .. && pwd)
    echo -e "${YELLOW}正在从仓库的 scripts 目录中运行。${NC}"
fi

# Only offer to remove the standard repo location if:
# 1. It exists AND
# 2. We're not currently in it
if [ -d "$REPO_DIR" ] && [ "$CURRENT_DIR" != "$REPO_DIR" ]; then
    echo -e "${YELLOW}在 $REPO_DIR 找到源代码${NC}"
    REMOVE_SOURCE=$(get_yes_no "您想移除源代码吗？" "y")
    
    if [ "$REMOVE_SOURCE" -eq 1 ]; then
        echo -e "${YELLOW}正在移除源代码...${NC}"
        rm -rf $REPO_DIR
        echo -e "${GREEN}源代码已移除。${NC}"
    else
        echo -e "${BLUE}源代码保留在 $REPO_DIR${NC}"
    fi
elif [ -d "$REPO_DIR" ] && [ "$CURRENT_DIR" = "$REPO_DIR" ]; then
    echo -e "${YELLOW}当前位于 $REPO_DIR 的源代码目录中${NC}"
    echo -e "${BLUE}无法移除您当前所在的目录。${NC}"
    echo -e "${BLUE}源代码将保留在 $REPO_DIR${NC}"
fi

# If running from a non-standard repo location, inform the user
if [ "$IS_REPO_DIR" = true ] && [ "$CURRENT_DIR" != "$REPO_DIR" ]; then
    echo -e "${YELLOW}您似乎正在从非标准仓库位置运行此脚本:${NC}"
    echo -e "${BLUE}$CURRENT_DIR${NC}"
    echo -e "${YELLOW}此目录将不会被自动移除。${NC}"
fi

# Check for data directory
DATA_DIR="/var/lib/led-matrix-controller"
if [ -d "$DATA_DIR" ]; then
    echo -e "${YELLOW}在 $DATA_DIR 找到数据目录${NC}"
    REMOVE_DATA=$(get_yes_no "您想移除数据目录吗？这将删除所有播放列表和自定义内容。" "n")
    
    if [ "$REMOVE_DATA" -eq 1 ]; then
        echo -e "${YELLOW}正在移除数据目录...${NC}"
        rm -rf $DATA_DIR
        echo -e "${GREEN}数据目录已移除。${NC}"
    else
        echo -e "${BLUE}数据目录保留在 $DATA_DIR${NC}"
    fi
fi

# 询问是否卸载 Rust
echo -e "\n${BLUE}Rust 卸载${NC}"
if sudo -u $ACTUAL_USER bash -c "source $ACTUAL_HOME/.cargo/env 2>/dev/null && command -v rustc &> /dev/null && command -v cargo &> /dev/null"; then
    REMOVE_RUST=$(get_yes_no "您想卸载 Rust 吗？" "n")
    
    if [ "$REMOVE_RUST" -eq 1 ]; then
        echo -e "${YELLOW}正在为用户 $ACTUAL_USER 卸载 Rust...${NC}"
        if [ -f "$ACTUAL_HOME/.cargo/bin/rustup" ]; then
            sudo -u $ACTUAL_USER bash -c "$ACTUAL_HOME/.cargo/bin/rustup self uninstall -y"
            echo -e "${GREEN}Rust 卸载成功。${NC}"
        else
            echo -e "${RED}未找到 Rustup。请手动卸载 Rust。${NC}"
        fi
    else
        echo -e "${BLUE}保留 Rust 安装。${NC}"
    fi
else
    echo -e "${GREEN}用户 $ACTUAL_USER 未安装 Rust。${NC}"
fi

# 询问是否卸载 Git
echo -e "\n${BLUE}Git 卸载${NC}"
if command -v git &> /dev/null; then
    REMOVE_GIT=$(get_yes_no "您想卸载 Git 吗？" "n")
    
    if [ "$REMOVE_GIT" -eq 1 ]; then
        echo -e "${YELLOW}正在卸载 Git...${NC}"
        apt-get remove -y git
        echo -e "${GREEN}Git 卸载成功。${NC}"
    else
        echo -e "${BLUE}保留 Git 安装。${NC}"
    fi
else
    echo -e "${GREEN}Git 未安装。${NC}"
fi

# 询问是否运行 autoremove 以清理未使用的依赖项
echo -e "\n${BLUE}系统清理${NC}"
RUN_AUTOREMOVE=$(get_yes_no "您想运行 apt autoremove 来清理未使用的包吗？" "n") 

if [ "$RUN_AUTOREMOVE" -eq 1 ]; then
    echo -e "${YELLOW}正在运行 apt autoremove...${NC}"
    apt-get autoremove -y
    echo -e "${GREEN}系统清理成功。${NC}"
else
    echo -e "${BLUE}跳过系统清理。${NC}"
fi

# Remove frontend source code
FRONTEND_REPO_DIR="/usr/local/src/rpi-led-sign-controller-frontend"
if [ -d "$FRONTEND_REPO_DIR" ]; then
    echo -e "${YELLOW}在 $FRONTEND_REPO_DIR 找到前端源代码${NC}"
    REMOVE_FRONTEND=$(get_yes_no "您想移除前端源代码吗？" "y")
    
    if [ "$REMOVE_FRONTEND" -eq 1 ]; then
        echo -e "${YELLOW}正在移除前端源代码...${NC}"
        rm -rf $FRONTEND_REPO_DIR
        echo -e "${GREEN}前端源代码已移除。${NC}"
    else
        echo -e "${BLUE}前端源代码保留在 $FRONTEND_REPO_DIR${NC}"
    fi
fi

# 询问是否卸载 NVM
echo -e "\n${BLUE}NVM (Node 版本管理器) 卸载${NC}"
NVM_DIR="$ACTUAL_HOME/.nvm"
if [ -d "$NVM_DIR" ]; then
    REMOVE_NVM=$(get_yes_no "您想卸载 NVM 和所有已安装的 Node.js 版本吗？" "n")
    
    if [ "$REMOVE_NVM" -eq 1 ]; then
        echo -e "${YELLOW}正在为用户 $ACTUAL_USER 卸载 NVM...${NC}"
        # Remove the NVM directory
        rm -rf "$NVM_DIR"
        
        # Remove NVM lines from shell configuration files
        for rc_file in "$ACTUAL_HOME/.bashrc" "$ACTUAL_HOME/.bash_profile" "$ACTUAL_HOME/.zshrc" "$ACTUAL_HOME/.profile"; do
            if [ -f "$rc_file" ]; then
                # Create a backup
                cp "$rc_file" "${rc_file}.nvm-backup"
                # Remove NVM-related lines
                sed -i '/NVM_DIR/d' "$rc_file"
                sed -i '/nvm\.sh/d' "$rc_file"
                sed -i '/bash_completion/d' "$rc_file"
            fi
        done
        
        echo -e "${GREEN}NVM 卸载成功。${NC}"
        echo -e "${BLUE}Shell 配置备份已创建，扩展名为 .nvm-backup。${NC}"
    else
        echo -e "${BLUE}保留 NVM 安装。${NC}"
    fi
else
    echo -e "${GREEN}用户 $ACTUAL_USER 未安装 NVM。${NC}"
fi

echo -e "\n${GREEN}卸载完成！${NC}"
echo -e "树莓派 LED 显示屏控制器已从您的系统中移除。"
echo -e "更多信息请访问: ${BLUE}https://github.com/paviro/rpi-led-sign-controller${NC}"
exit 0 