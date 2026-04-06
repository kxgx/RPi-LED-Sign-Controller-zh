#!/bin/bash
set -e

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REQUIRED_NODE_VERSION="20.9.0"
NVM_VERSION="v0.39.7"
NODE_VERSION_TO_USE=""

echo -e "${BLUE}树莓派 LED 显示屏控制器 - 安装与更新脚本${NC}"
echo -e "==============================================="
echo -e "GitHub 仓库: ${GREEN}https://github.com/kxgx/RPi-LED-Sign-Controller-zh${NC}"

# 介绍
echo -e "\n${BLUE}关于本软件:${NC}"
echo -e "此脚本将安装或更新树莓派 LED 显示屏控制器，该控制器允许您从树莓派驱动"
echo -e "HUB75 兼容的 RGB LED 矩阵面板。该软件提供了一个 Web 界面，用于创建和管理"
echo -e "LED 面板上的文本显示、动画和播放列表。"

echo -e "\n${YELLOW}此脚本将会:${NC}"
echo -e "  • 检查应用是否已安装并提供更新选项"
echo -e "  • 检查并安装所需的依赖项 (Git, Rust, Node.js)"
echo -e "  • 克隆仓库（如果需要）"
echo -e "  • 从源代码构建应用程序"
echo -e "  • 帮助您配置 LED 面板"
echo -e "  • 将应用程序安装为 systemd 服务"
echo -e "  • 设置开机自动启动服务"

echo -e "\n${YELLOW}此脚本将对您的系统进行更改。${NC}"
echo -e "${YELLOW}您要继续安装/更新吗？${NC}"

read -p "继续？ [y/N]: " continue_install
if [[ "$continue_install" != "y" && "$continue_install" != "Y" ]]; then
    echo -e "${RED}安装已中止。${NC}"
    exit 1
fi
echo -e "${GREEN}正在继续安装...${NC}"

# First, add a helper function for standardized reading near the top of the script
read_input() {
    local prompt="$1"
    local var_name="$2"
    local result
    
    if [ -t 0 ]; then
        # Terminal is interactive, read normally
        read -p "$prompt" result
    else
        # Running from pipe or non-interactive, use /dev/tty
        read -p "$prompt" result </dev/tty
    fi
    
    # Use eval to set the variable by name in the parent scope
    eval "$var_name=\"\$result\""
}

# Helper functions to safely stash and restore local changes before pulling updates
stash_repo_changes() {
    local repo_dir="$1"
    local user="$2"
    local label="$3"
    local result_var="$4"
    local stashed=0
    local changes

    pushd "$repo_dir" > /dev/null

    changes=$(sudo -u $user git status --porcelain)
    if [ -n "$changes" ]; then
        echo -e "${YELLOW}${label} 仓库有本地更改。在更新前暂存...${NC}"
        if sudo -u $user git stash push -u -m "install-script-autostash-$(date +%s)"; then
            stashed=1
            echo -e "${GREEN}${label} 仓库的本地更改已暂存。${NC}"
        else
            echo -e "${RED}${label} 仓库的本地更改暂存失败。${NC}"
            popd > /dev/null
            exit 1
        fi
    fi

    popd > /dev/null
    eval "$result_var=$stashed"
}

# Then update the Raspberry Pi detection override
if ! grep -q "Raspberry Pi" /proc/cpuinfo && ! grep -q "BCM" /proc/cpuinfo; then
    echo -e "\n${RED}错误: 此脚本必须在树莓派上运行。${NC}"
    echo -e "${YELLOW}如果您正在树莓派上运行并看到此错误，${NC}"
    echo -e "${YELLOW}请输入 'y' 继续，或按其他键中止。${NC}"
    read -p "仍然继续？ [y/N]: " force_continue
    if [[ "$force_continue" != "y" && "$force_continue" != "Y" ]]; then
        echo -e "${RED}安装已中止。${NC}"
        exit 1
    fi
    echo -e "${YELLOW}尽管平台检查未通过，仍继续安装...${NC}"
else
    echo -e "\n${GREEN}检测到树莓派。${NC}"
fi

# Function to check if running on a Debian-based system
check_debian_based() {
    if ! command -v apt &> /dev/null && ! command -v apt-get &> /dev/null; then
        echo -e "${RED}错误: 此脚本需要基于 Debian 的系统（推荐使用树莓派 OS Lite）${NC}"
        echo -e "${RED}在您的系统上未找到 'apt' 包管理器。${NC}"
        echo -e "${YELLOW}如果您使用的是非 Debian 系统但仍想安装，请参考:${NC}"
        echo -e "${BLUE}https://github.com/kxgx/RPi-LED-Sign-Controller-zh${NC}"
        exit 1
    fi
    echo -e "${GREEN}检测到基于 Debian 的系统。${NC}"
}

# Add the reconfigure function here, before it's used
ask_reconfigure() {
    local reason=$1  # Why we're asking (update/no update)
    local default="N"
    
    if [ "$reason" == "update" ]; then
        echo -e "\n${GREEN}✓ 更新成功！${NC}"
        echo -e "${YELLOW}您想修改 LED 面板配置吗？${NC}"
    else
        echo -e "\n${GREEN}✓ 树莓派 LED 显示屏控制器已安装且为最新版本。${NC}"
        echo -e "${YELLOW}您想修改 LED 面板配置吗？${NC}"
    fi
    
    if [ -t 0 ]; then
        # Terminal is interactive, read normally
        read -p "重新配置 LED 面板设置？ [y/N]: " reconfigure
    else
        # Running from pipe or non-interactive, use /dev/tty
        read -p "Reconfigure LED panel settings? [y/N]: " reconfigure </dev/tty
    fi
    
    if [[ "$reconfigure" != "y" && "$reconfigure" != "Y" ]]; then
        if [ "$reason" == "update" ]; then
            echo -e "${GREEN}保持现有配置。${NC}"
            echo -e "${YELLOW}正在使用更新的二进制文件重启服务...${NC}"
            systemctl restart rpi-led-sign.service
            echo -e "${GREEN}服务重启成功。${NC}"
        else
            echo -e "${GREEN}无需更改。您的安装将继续使用现有设置。${NC}"
            
            # In "no_update" case, make sure service is running
            if ! systemctl is-active --quiet rpi-led-sign.service; then
                echo -e "${YELLOW}正在启动服务...${NC}"
                systemctl start rpi-led-sign.service
                echo -e "${GREEN}服务启动成功。${NC}"
            fi
        fi
        
        # 显示通用完成信息
        echo -e "\n${GREEN}===== 树莓派 LED 显示屏控制器信息 =====${NC}"
        echo -e "Web 界面地址: http://$(hostname -I | awk '{print $1}'):$(systemctl show rpi-led-sign.service -p Environment | grep LED_PORT | sed 's/.*LED_PORT=\([0-9]*\).*/\1/' || echo "3000")"
        echo -e "源代码位于: ${BLUE}/usr/local/src/rpi-led-sign-controller${NC}"
        echo -e "您可以使用以下命令管理服务: sudo systemctl [start|stop|restart|status] rpi-led-sign.service"
        echo -e ""
        echo -e "${BLUE}===== 更新与维护 =====${NC}"
        echo -e "将来要更新，您可以："
        echo -e "  • 再次运行此脚本: ${BLUE}curl -sSL https://raw.githubusercontent.com/kxgx/RPi-LED-Sign-Controller-zh/main/scripts/install.sh | sudo bash${NC}"
        echo -e "  • 或者从源代码目录: ${BLUE}cd /usr/local/src/rpi-led-sign-controller && sudo bash scripts/install.sh${NC}"
        echo -e ""
        echo -e "要卸载，请运行: ${BLUE}sudo bash /usr/local/src/rpi-led-sign-controller/scripts/uninstall.sh${NC}"
        echo -e ""
        echo -e "更多信息请访问: ${BLUE}https://github.com/kxgx/RPi-LED-Sign-Controller-zh${NC}"
        return 1  # Don't reconfigure
    fi
    
    echo -e "${YELLOW}正在继续配置...${NC}"
    
    # Stop the service before reconfiguration if it's running
    if systemctl is-active --quiet rpi-led-sign.service; then
        echo -e "${YELLOW}在重新配置前停止服务...${NC}"
        systemctl stop rpi-led-sign.service
    fi
    return 0  # Reconfigure
}

check_system_node_version() {
    local required_version="$1"

    if command -v node &> /dev/null; then
        local system_version
        system_version=$(node -v | tr -d 'v')
        if dpkg --compare-versions "$system_version" ge "$required_version"; then
            echo -e "${GREEN}系统 Node.js 版本 $system_version 满足最低要求 (>= $required_version)。${NC}"
        else
            echo -e "${YELLOW}系统 Node.js 版本 $system_version 低于要求的 $required_version。${NC}"
            echo -e "${YELLOW}Node.js 将通过 NVM 安装或更新。${NC}"
        fi
    else
        echo -e "${YELLOW}在系统 PATH 中未找到 Node.js。正在通过 NVM 安装...${NC}"
    fi
}

ensure_curl_installed() {
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}curl 未找到。正在安装 curl...${NC}"
        apt-get update
        apt-get install -y curl
        echo -e "${GREEN}curl 安装成功。${NC}"
    fi
}

ensure_nvm_installed() {
    local user="$1"
    local home_dir="$2"
    local nvm_dir="$home_dir/.nvm"

    if sudo -u "$user" bash -c "[ -s '$nvm_dir/nvm.sh' ]" >/dev/null 2>&1; then
        echo -e "${GREEN}NVM 已为用户 $user 安装。${NC}"
        return
    fi

    echo -e "${YELLOW}未找到 NVM。正在为用户 $user 安装 NVM ${NVM_VERSION}...${NC}"
    ensure_curl_installed
    sudo -u "$user" bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"
    echo -e "${GREEN}NVM 为用户 $user 安装成功。${NC}"
}

ensure_node_version() {
    local user="$1"
    local home_dir="$2"
    local required_version="$3"
    local result_var="$4"
    local nvm_dir="$home_dir/.nvm"
    local available_versions=""
    local selected_version=""

    # Get installed versions from nvm, filtering for actual installed versions (lines starting with spaces and 'v')
    available_versions=$(sudo -u "$user" bash -c 'export NVM_DIR="'"$nvm_dir"'"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; nvm ls --no-colors' 2>/dev/null | grep -E '^\s+v[0-9]+\.[0-9]+\.[0-9]+' | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' || true)
    
    if [ -n "$available_versions" ]; then
        # Find the highest version that meets the requirement
        while IFS= read -r version; do
            version_number=$(echo "$version" | sed 's/^v//')
            if dpkg --compare-versions "$version_number" ge "$required_version"; then
                if [ -z "$selected_version" ] || dpkg --compare-versions "$version_number" gt "$selected_version"; then
                    selected_version="$version_number"
                fi
            fi
        done <<< "$available_versions"
    fi

    if [ -z "$selected_version" ]; then
        echo -e "${YELLOW}正在通过 NVM 安装 Node.js $required_version...${NC}"
        sudo -u "$user" bash -c 'export NVM_DIR="'"$nvm_dir"'"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; nvm install '"$required_version"
        selected_version="$required_version"
    else
        echo -e "${GREEN}使用现有的 Node.js $selected_version (通过 NVM)。${NC}"
    fi

    # Try to set alias and use the selected version; if it fails, reinstall
    if ! sudo -u "$user" bash -c 'export NVM_DIR="'"$nvm_dir"'"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; nvm alias default '"$selected_version"' >/dev/null 2>&1'; then
        echo -e "${YELLOW}所选版本不可用。正在通过 NVM 安装 Node.js $required_version...${NC}"
        sudo -u "$user" bash -c 'export NVM_DIR="'"$nvm_dir"'"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; nvm install '"$required_version"
        selected_version="$required_version"
        sudo -u "$user" bash -c 'export NVM_DIR="'"$nvm_dir"'"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; nvm alias default '"$selected_version"' >/dev/null 2>&1'
    fi
    
    sudo -u "$user" bash -c 'export NVM_DIR="'"$nvm_dir"'"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; nvm use --silent '"$selected_version"' 2>&1' >/dev/null || true

    eval "$result_var=\"$selected_version\""
}

run_with_node() {
    local user="$1"
    local home_dir="$2"
    local node_version="$3"
    shift 3
    local command="$*"
    local nvm_dir="$home_dir/.nvm"

    if [ -z "$node_version" ]; then
        echo -e "${RED}Node.js 版本未设置。无法运行依赖 Node 的命令。${NC}"
        exit 1
    fi

    sudo -u "$user" bash -c 'export NVM_DIR="'"$nvm_dir"'"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"; nvm use --silent '"$node_version"' >/dev/null; '"$command"
}

# Call this function early in the script, right after the Raspberry Pi check
check_debian_based

# Check if script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请使用 root 权限运行此脚本 (使用 sudo)${NC}"
  exit 1
fi

# Determine the actual user who ran the script
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

# Check for and install git if necessary
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Git 未找到。正在安装 git...${NC}"
    apt-get update
    apt-get install -y git
    echo -e "${GREEN}Git 安装成功。${NC}"
else
    echo -e "${GREEN}Git 已安装。${NC}"
fi

# Check for and install Node.js (via NVM) if necessary
check_system_node_version "$REQUIRED_NODE_VERSION"
ensure_nvm_installed "$ACTUAL_USER" "$ACTUAL_HOME"
ensure_node_version "$ACTUAL_USER" "$ACTUAL_HOME" "$REQUIRED_NODE_VERSION" NODE_VERSION_TO_USE

# Check for and install rust if necessary
if ! sudo -u $ACTUAL_USER bash -c "source $ACTUAL_HOME/.cargo/env 2>/dev/null && command -v rustc &> /dev/null && command -v cargo &> /dev/null"; then
    echo -e "${YELLOW}Rust 未找到。正在为用户 $ACTUAL_USER 安装 rust...${NC}"
    apt-get update
    apt-get install -y curl build-essential
    
    # Install Rust for the actual user
    sudo -u $ACTUAL_USER bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
    echo -e "${GREEN}Rust 为用户 $ACTUAL_USER 安装成功。${NC}"
else
    echo -e "${GREEN}Rust 已为用户 $ACTUAL_USER 安装。${NC}"
fi

# Store current directory
CURRENT_DIR=$(pwd)

# Check if the app is already installed
APP_INSTALLED=0
if [ -f "/usr/local/bin/rpi_led_sign_controller" ]; then
    APP_INSTALLED=1
    echo -e "${GREEN}树莓派 LED 显示屏控制器已安装。${NC}"
else
    echo -e "${YELLOW}树莓派 LED 显示屏控制器尚未安装。${NC}"
fi

# Check if we're inside the repository directory
INSIDE_REPO=0
# Either we're directly in the repo dir
if [ -f "Cargo.toml" ] && grep -q "rpi_led_sign_controller" "Cargo.toml" 2>/dev/null; then
    INSIDE_REPO=1
    REPO_DIR=$(pwd)
    echo -e "${BLUE}已在项目目录中。${NC}"
# Or we're in the scripts subdirectory
elif [ -f "../Cargo.toml" ] && grep -q "rpi_led_sign_controller" "../Cargo.toml" 2>/dev/null; then
    INSIDE_REPO=1
    REPO_DIR=$(cd .. && pwd)
    echo -e "${BLUE}已在项目目录中 (scripts 子文件夹)。${NC}"
fi

# Set standard repository location if not already inside repo
if [ $INSIDE_REPO -eq 0 ]; then
    REPO_DIR="/usr/local/src/rpi-led-sign-controller"
fi

# Check if repo dir exists and fix ownership if needed
if [ -d "$REPO_DIR" ]; then
    # Check if any files in the repo have incorrect ownership
    if [ "$(find "$REPO_DIR" -not -user $ACTUAL_USER | wc -l)" -gt 0 ]; then
        echo -e "${YELLOW}正在修复仓库权限...${NC}"
        echo -e "${BLUE}这确保您的用户可以从 GitHub 拉取更新${NC}"
        chown -R $ACTUAL_USER:$ACTUAL_USER "$REPO_DIR"
        echo -e "${GREEN}仓库权限已修复。${NC}"
    fi
fi

# Track if we just cloned the repo (so we know to build it)
REPO_JUST_CLONED=0

# Determine if we need to clone or navigate to the repository
if [ $INSIDE_REPO -eq 0 ]; then
    # We're not in the repo directory, check if it exists at the standard location
    if [ -d "$REPO_DIR" ]; then
        echo -e "${BLUE}在标准位置找到现有仓库 $REPO_DIR${NC}"
        cd "$REPO_DIR"
    else
        echo -e "${YELLOW}正在创建仓库目录...${NC}"
        mkdir -p "$REPO_DIR"
        chown $ACTUAL_USER:$ACTUAL_USER "$REPO_DIR"
        
        echo -e "${YELLOW}正在以用户 $ACTUAL_USER 身份克隆仓库...${NC}"
        # Clone the repository as the regular user
        sudo -u $ACTUAL_USER git clone https://github.com/kxgx/RPi-LED-Sign-Controller-zh.git "$REPO_DIR"
        cd "$REPO_DIR"
        REPO_JUST_CLONED=1
    fi
fi

# If app is installed, always check for updates
if [ $APP_INSTALLED -eq 1 ]; then
    echo -e "${YELLOW}正在从 GitHub 获取最新更改...${NC}"
    sudo -u $ACTUAL_USER git fetch

    # Now check if we're behind the remote repository
    UPDATES_AVAILABLE=0
    git_status=$(sudo -u $ACTUAL_USER git status -uno)
    if echo "$git_status" | grep -q "Your branch is behind"; then
        UPDATES_AVAILABLE=1
        echo -e "${YELLOW}有可用更新。${NC}"
        
        # Stash local changes before pulling updates
        stash_repo_changes "$REPO_DIR" $ACTUAL_USER "Backend" "BACKEND_STASHED_PRIMARY"
        
        # Pull changes as the regular user
        if ! sudo -u $ACTUAL_USER git pull; then
            echo -e "${RED}更新后端仓库失败。${NC}"
            if [ "${BACKEND_STASHED_PRIMARY:-0}" -eq 1 ]; then
                echo -e "${YELLOW}您之前的本地更改已暂存。请使用 'git stash list' 后跟 'git stash pop' 手动恢复它们。${NC}"
            fi
            exit 1
        fi

        if [ "${BACKEND_STASHED_PRIMARY:-0}" -eq 1 ]; then
            echo -e "${YELLOW}本地后端更改仍保持暂存状态。准备好后运行 'git stash list' 和 'git stash pop' 恢复它们。${NC}"
        fi
        echo -e "${GREEN}仓库更新成功。${NC}"
    else
        echo -e "${GREEN}仓库已是最新版本。${NC}"
    fi
    
    # Create update marker file with proper ownership
    if [ $UPDATES_AVAILABLE -eq 1 ]; then
        echo "updated=$(date +%s)" > "$REPO_DIR/.update_status"
        chown $ACTUAL_USER:$ACTUAL_USER "$REPO_DIR/.update_status"
    fi
    
    # Only return to original directory if we don't need to build
    # This is critical - we need to stay in the repo dir for building
    if [ "$UPDATES_AVAILABLE" -eq 0 ] && [ ! -f "$REPO_DIR/.update_status" ]; then
        if [ "$CURRENT_DIR" != "$REPO_DIR" ]; then
            cd "$CURRENT_DIR"
        fi
    fi
fi

# Add code to ensure UPDATE_MARKER variable is defined
UPDATE_MARKER="$REPO_DIR/.update_status"

# Record the project directory
PROJECT_DIR=$(pwd)

# Set frontend repository location
FRONTEND_REPO_DIR="/usr/local/src/rpi-led-sign-controller-frontend"

# Check if we're inside the backend repository
INSIDE_BACKEND_REPO=0
# Either we're directly in the repo dir
if [ -f "Cargo.toml" ] && grep -q "rpi_led_sign_controller" "Cargo.toml" 2>/dev/null; then
    INSIDE_BACKEND_REPO=1
    REPO_DIR=$(pwd)
    echo -e "${BLUE}Already in backend project directory.${NC}"
# Or we're in the scripts subdirectory
elif [ -f "../Cargo.toml" ] && grep -q "rpi_led_sign_controller" "../Cargo.toml" 2>/dev/null; then
    INSIDE_BACKEND_REPO=1
    REPO_DIR=$(cd .. && pwd)
    echo -e "${BLUE}Already in backend project directory (scripts subfolder).${NC}"
fi

# Set standard repository location if not already inside repo
if [ $INSIDE_BACKEND_REPO -eq 0 ]; then
    REPO_DIR="/usr/local/src/rpi-led-sign-controller"
fi

# Now handle the frontend repository
echo -e "${YELLOW}正在检查前端仓库...${NC}"
FRONTEND_REPO_EXISTS=0
if [ -d "$FRONTEND_REPO_DIR" ]; then
    FRONTEND_REPO_EXISTS=1
    echo -e "${GREEN}前端仓库已存在于 $FRONTEND_REPO_DIR${NC}"
    
    # Check if any files in the frontend repo have incorrect ownership
    if [ "$(find "$FRONTEND_REPO_DIR" -not -user $ACTUAL_USER | wc -l)" -gt 0 ]; then
        echo -e "${YELLOW}正在修复前端仓库权限...${NC}"
        chown -R $ACTUAL_USER:$ACTUAL_USER "$FRONTEND_REPO_DIR"
        echo -e "${GREEN}前端仓库权限已修复。${NC}"
    fi
else
    echo -e "${YELLOW}未找到前端仓库，即将克隆。${NC}"
fi

# Track if we just cloned the frontend repo
FRONTEND_JUST_CLONED=0

# Clone frontend repository if it doesn't exist
if [ $FRONTEND_REPO_EXISTS -eq 0 ]; then
    echo -e "${YELLOW}正在创建前端仓库目录...${NC}"
    mkdir -p "$FRONTEND_REPO_DIR"
    chown $ACTUAL_USER:$ACTUAL_USER "$FRONTEND_REPO_DIR"
    
    echo -e "${YELLOW}正在以用户 $ACTUAL_USER 身份克隆前端仓库...${NC}"
    # Clone the repository as the regular user
    sudo -u $ACTUAL_USER git clone https://github.com/kxgx/RPi-LED-Sign-Controller-Frontend-zh.git "$FRONTEND_REPO_DIR"
    echo -e "${GREEN}前端仓库克隆成功。${NC}"
    FRONTEND_JUST_CLONED=1
fi

# Initialize update flags with default values
BACKEND_UPDATES_AVAILABLE=0
FRONTEND_UPDATES_AVAILABLE=0
FRONTEND_REBUILD_NEEDED=0

# If we just cloned the backend repo, mark it as needing a build
if [ $REPO_JUST_CLONED -eq 1 ]; then
    BACKEND_UPDATES_AVAILABLE=1
    echo -e "${GREEN}后端仓库已 freshly 克隆。${NC}"
fi

# Check for backend updates
if [ $APP_INSTALLED -eq 1 ] && [ $REPO_JUST_CLONED -eq 0 ]; then
    echo -e "${YELLOW}正在从 GitHub 获取后端最新更改...${NC}"
    cd "$REPO_DIR"
    sudo -u $ACTUAL_USER git fetch

    # Now check if we're behind the remote repository
    git_status=$(sudo -u $ACTUAL_USER git status -uno)
    if echo "$git_status" | grep -q "Your branch is behind"; then
        BACKEND_UPDATES_AVAILABLE=1
        echo -e "${YELLOW}发现后端可用更新。${NC}"
        
        # Stash local changes before pulling updates
        stash_repo_changes "$REPO_DIR" $ACTUAL_USER "Backend" "BACKEND_STASHED_SECONDARY"

        # Pull changes as the regular user
        if ! sudo -u $ACTUAL_USER git pull; then
            echo -e "${RED}更新后端仓库失败。${NC}"
            if [ "${BACKEND_STASHED_SECONDARY:-0}" -eq 1 ]; then
                echo -e "${YELLOW}您之前的本地更改已暂存。请使用 'git stash list' 后跟 'git stash pop' 手动恢复它们。${NC}"
            fi
            exit 1
        fi

        if [ "${BACKEND_STASHED_SECONDARY:-0}" -eq 1 ]; then
            echo -e "${YELLOW}本地后端更改仍保持暂存状态。准备好后运行 'git stash list' 和 'git stash pop' 恢复它们。${NC}"
        fi
        echo -e "${GREEN}后端仓库更新成功。${NC}"
    else
        echo -e "${GREEN}后端仓库已是最新版本。${NC}"
    fi
    
    # Create update marker file for backend with proper ownership
    if [ $BACKEND_UPDATES_AVAILABLE -eq 1 ]; then
        echo "updated=$(date +%s)" > "$REPO_DIR/.update_status"
        chown $ACTUAL_USER:$ACTUAL_USER "$REPO_DIR/.update_status"
    fi
fi

# If frontend was just cloned, mark it for rebuild
if [ $FRONTEND_JUST_CLONED -eq 1 ]; then
    FRONTEND_REBUILD_NEEDED=1
    echo -e "${GREEN}前端仓库已 freshly 克隆。${NC}"
fi

# Check for frontend updates
echo -e "${YELLOW}正在检查前端更新...${NC}"

# Only if frontend repo exists and wasn't just cloned, check for updates
if [ $FRONTEND_REPO_EXISTS -eq 1 ] && [ $FRONTEND_JUST_CLONED -eq 0 ]; then
    cd "$FRONTEND_REPO_DIR"
    sudo -u $ACTUAL_USER git fetch
    
    git_status=$(sudo -u $ACTUAL_USER git status -uno)
    if echo "$git_status" | grep -q "Your branch is behind"; then
        FRONTEND_UPDATES_AVAILABLE=1
        echo -e "${YELLOW}发现前端可用更新。${NC}"
        
        # Stash local changes before pulling updates
        stash_repo_changes "$FRONTEND_REPO_DIR" $ACTUAL_USER "Frontend" "FRONTEND_STASHED"

        # Pull changes as the regular user
        if ! sudo -u $ACTUAL_USER git pull; then
            echo -e "${RED}更新前端仓库失败。${NC}"
            if [ "${FRONTEND_STASHED:-0}" -eq 1 ]; then
                echo -e "${YELLOW}您之前的本地更改已暂存。请使用 'git stash list' 后跟 'git stash pop' 手动恢复它们。${NC}"
            fi
            exit 1
        fi

        if [ "${FRONTEND_STASHED:-0}" -eq 1 ]; then
            echo -e "${YELLOW}本前端更改仍保持暂存状态。准备好后运行 'git stash list' 和 'git stash pop' 恢复它们。${NC}"
        fi
        echo -e "${GREEN}前端仓库更新成功。${NC}"
        FRONTEND_REBUILD_NEEDED=1
    else
        echo -e "${GREEN}前端仓库已是最新版本。${NC}"
    fi
fi

# Check if frontend has already been compiled and copied - with improved detection for deleted files
FRONTEND_FILES_EXIST=0
if [ -d "$REPO_DIR/static" ] && [ -d "$REPO_DIR/static/_next" ] && [ "$(ls -A "$REPO_DIR/static" 2>/dev/null)" ]; then
    # Check if the static directory has actual content and wasn't emptied by an update
    echo -e "${GREEN}前端文件已存在于后端 static 目录中。${NC}"
    FRONTEND_FILES_EXIST=1
else
    # Static directory doesn't exist, is empty, or doesn't have the Next.js build files
    echo -e "${YELLOW}后端 static 目录中缺少或不完整的前端文件。${NC}"
    # Force rebuild of frontend
    FRONTEND_REBUILD_NEEDED=1
fi

# Build the frontend if needed or if backend was updated or if frontend files don't exist
if [ $FRONTEND_REBUILD_NEEDED -eq 1 ] || [ $BACKEND_UPDATES_AVAILABLE -eq 1 ] || [ $FRONTEND_FILES_EXIST -eq 0 ]; then
    echo -e "${YELLOW}正在构建前端...${NC}"
    cd "$FRONTEND_REPO_DIR"
    
    # Install dependencies and build
    echo -e "${YELLOW}正在安装前端依赖...${NC}"
    run_with_node "$ACTUAL_USER" "$ACTUAL_HOME" "$NODE_VERSION_TO_USE" npm install
    
    echo -e "${YELLOW}正在构建前端...${NC}"
    run_with_node "$ACTUAL_USER" "$ACTUAL_HOME" "$NODE_VERSION_TO_USE" npm run build
    
    echo -e "${GREEN}前端构建成功。${NC}"
    
    # Ensure static directory exists
    mkdir -p "$REPO_DIR/static"
    
    # Clean the static directory to remove any old files
    echo -e "${YELLOW}正在清理 static 目录...${NC}"
    rm -rf "$REPO_DIR/static/"*
    echo -e "${GREEN}Static 目录已清理。${NC}"
    
    # Copy the built files to the backend's static folder
    echo -e "${YELLOW}正在将前端文件复制到后端...${NC}"
    cp -r "$FRONTEND_REPO_DIR/out/"* "$REPO_DIR/static/"
    echo -e "${GREEN}前端文件复制成功。${NC}"
    
    # Force rebuilding backend if we rebuilt frontend
    # This is necessary because frontend files get embedded in the backend binary
    if [ $BACKEND_UPDATES_AVAILABLE -eq 0 ]; then
        echo -e "${YELLOW}前端已更新。标记后端需要重新构建...${NC}"
        echo "updated=$(date +%s)" > "$REPO_DIR/.update_status"
        chown $ACTUAL_USER:$ACTUAL_USER "$REPO_DIR/.update_status"
    fi
else
    echo -e "${GREEN}跳过前端构建，因为文件已存在且未发现更新。${NC}"
fi

# Build the application if new installation, update pulled, or rebuild requested
if [ "$BACKEND_UPDATES_AVAILABLE" -eq 1 ] || [ ! -f "/usr/local/bin/rpi_led_sign_controller" ] || [ -f "$REPO_DIR/.update_status" ]; then
    # Make sure we're in the repository directory
    if [ "$(pwd)" != "$REPO_DIR" ]; then
        echo -e "${YELLOW}Changing to repository directory for build...${NC}"
        cd "$REPO_DIR"
    fi

    echo -e "${YELLOW}Building backend application...${NC}"
    # Use the user's cargo environment
    sudo -u $ACTUAL_USER bash -c "source $ACTUAL_HOME/.cargo/env && cargo build --release"
    echo -e "${GREEN}Backend build completed.${NC}"

    # Stop the service before replacing the binary if it's running
    if [ -f "/etc/systemd/system/rpi-led-sign.service" ] && systemctl is-active --quiet rpi-led-sign.service; then
        echo -e "${YELLOW}Stopping service before updating binary...${NC}"
        systemctl stop rpi-led-sign.service
    fi

    # Install the binary (this requires root)
    echo -e "${YELLOW}Installing binary to /usr/local/bin...${NC}"
    cp target/release/rpi_led_sign_controller /usr/local/bin/
    chmod +x /usr/local/bin/rpi_led_sign_controller
    echo -e "${GREEN}Binary installed.${NC}"
    
    # Remove update marker if it exists
    if [ -f "$REPO_DIR/.update_status" ]; then
        rm "$REPO_DIR/.update_status"
    fi
    
    # After binary update section
    if [ -f "/etc/systemd/system/rpi-led-sign.service" ] && [ "$BACKEND_UPDATES_AVAILABLE" -eq 1 -o "$FRONTEND_UPDATES_AVAILABLE" -eq 1 ]; then
        if ! ask_reconfigure "update"; then
            # Make sure service is running before exit
            if systemctl is-active --quiet rpi-led-sign.service; then
                echo -e "${GREEN}Service is already running.${NC}"
            else
                echo -e "${YELLOW}Starting service before exit...${NC}"
                systemctl start rpi-led-sign.service
                echo -e "${GREEN}服务启动成功。${NC}"
            fi
            exit 0
        fi
        # Continue with configuration
    fi
fi

# Check if we need to ask for reconfiguration when there were no updates or it's a fresh install
if [ $APP_INSTALLED -eq 1 ] && [ $BACKEND_UPDATES_AVAILABLE -eq 0 ] && [ $FRONTEND_UPDATES_AVAILABLE -eq 0 ]; then
    if ! ask_reconfigure "no_update"; then
        # Make sure service is running before exit
        if systemctl is-active --quiet rpi-led-sign.service; then
            echo -e "${GREEN}Service is already running.${NC}"
        else
            echo -e "${YELLOW}Starting service before exit...${NC}"
            systemctl start rpi-led-sign.service
            echo -e "${GREEN}服务启动成功。${NC}"
        fi
        exit 0
    fi
    # Continue with configuration
fi

# If it's a fresh installation, always ask to configure
if [ $APP_INSTALLED -eq 0 ]; then
    echo -e "${GREEN}Fresh installation completed. Now let's configure your LED panel.${NC}"
    # Continue with configuration - no exit option here as configuration is required for first install
fi

###########################################
# Interactive LED panel configuration
###########################################

echo -e "${BLUE}LED 面板配置${NC}"
echo -e "-----------------------------------------------"
echo -e "让我们配置您的 LED 面板。您可以在最终确定之前测试配置。"
echo -e "对于每个选项，按 Enter 键使用默认值，或输入自定义值。"

# Default values - These should match the table exactly
DEFAULT_ROWS=32
DEFAULT_COLS=64
DEFAULT_CHAIN_LENGTH=1
DEFAULT_PARALLEL=1
DEFAULT_HARDWARE_MAPPING="regular"
DEFAULT_GPIO_SLOWDOWN=""
DEFAULT_PWM_BITS=11
DEFAULT_PWM_LSB_NANOSECONDS=130
DEFAULT_LED_SEQUENCE="RGB"
DEFAULT_DITHER_BITS=0
DEFAULT_PANEL_TYPE=""
DEFAULT_MULTIPLEXING=""
DEFAULT_PIXEL_MAPPER=""
DEFAULT_ROW_SETTER="direct"
DEFAULT_LIMIT_REFRESH_RATE=0
DEFAULT_MAX_BRIGHTNESS=100
DEFAULT_INTERLACED=0
DEFAULT_NO_HARDWARE_PULSE=0
DEFAULT_SHOW_REFRESH=0
DEFAULT_INVERSE_COLORS=0
DEFAULT_PI_CHIP=""
DEFAULT_WEB_PORT=3000
DEFAULT_WEB_INTERFACE="0.0.0.0"

# Actual values (will be set if not using defaults)
DRIVER=""  # Required - no default
ROWS=$DEFAULT_ROWS
COLS=$DEFAULT_COLS
CHAIN_LENGTH=$DEFAULT_CHAIN_LENGTH
PARALLEL=$DEFAULT_PARALLEL
HARDWARE_MAPPING=$DEFAULT_HARDWARE_MAPPING
GPIO_SLOWDOWN=$DEFAULT_GPIO_SLOWDOWN
PWM_BITS=$DEFAULT_PWM_BITS
PWM_LSB_NANOSECONDS=$DEFAULT_PWM_LSB_NANOSECONDS
LED_SEQUENCE=$DEFAULT_LED_SEQUENCE
DITHER_BITS=$DEFAULT_DITHER_BITS
PANEL_TYPE=$DEFAULT_PANEL_TYPE
MULTIPLEXING=$DEFAULT_MULTIPLEXING
PIXEL_MAPPER=$DEFAULT_PIXEL_MAPPER
ROW_SETTER=$DEFAULT_ROW_SETTER
LIMIT_REFRESH_RATE=$DEFAULT_LIMIT_REFRESH_RATE
MAX_BRIGHTNESS=$DEFAULT_MAX_BRIGHTNESS
INTERLACED=$DEFAULT_INTERLACED
NO_HARDWARE_PULSE=$DEFAULT_NO_HARDWARE_PULSE
SHOW_REFRESH=$DEFAULT_SHOW_REFRESH
INVERSE_COLORS=$DEFAULT_INVERSE_COLORS
PI_CHIP=$DEFAULT_PI_CHIP
WEB_PORT=$DEFAULT_WEB_PORT
WEB_INTERFACE=$DEFAULT_WEB_INTERFACE

# Update the get_input function
get_input() {
    local prompt=$1
    local default=$2
    local value
    
    read -p "${prompt} [${default}]: " value
    echo ${value:-$default}
}

# Update the get_yes_no function
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

# Function to test the current configuration
test_configuration() {
    echo -e "${YELLOW}正在使用当前配置测试 LED 面板...${NC}"
    echo -e "${RED}程序将运行 10 秒。如果需要，请按 Ctrl+C 提前停止。${NC}"
    
    # Build the command with required settings
    CMD="/usr/local/bin/rpi_led_sign_controller"
    CMD+=" --driver $DRIVER"
    
    # Add non-default parameters
    if [ "$ROWS" != "$DEFAULT_ROWS" ]; then
        CMD+=" --rows $ROWS"
    fi
    
    if [ "$COLS" != "$DEFAULT_COLS" ]; then
        CMD+=" --cols $COLS"
    fi
    
    if [ "$CHAIN_LENGTH" != "$DEFAULT_CHAIN_LENGTH" ]; then
        CMD+=" --chain-length $CHAIN_LENGTH"
    fi
    
    if [ "$PARALLEL" != "$DEFAULT_PARALLEL" ]; then
        CMD+=" --parallel $PARALLEL"
    fi
    
    if [ "$HARDWARE_MAPPING" != "$DEFAULT_HARDWARE_MAPPING" ]; then
        CMD+=" --hardware-mapping $HARDWARE_MAPPING"
    fi
    
    if [ ! -z "$GPIO_SLOWDOWN" ]; then
        CMD+=" --gpio-slowdown $GPIO_SLOWDOWN"
    fi
    
    if [ "$PWM_BITS" != "$DEFAULT_PWM_BITS" ]; then
        CMD+=" --pwm-bits $PWM_BITS"
    fi
    
    if [ "$PWM_LSB_NANOSECONDS" != "$DEFAULT_PWM_LSB_NANOSECONDS" ]; then
        CMD+=" --pwm-lsb-nanoseconds $PWM_LSB_NANOSECONDS"
    fi
    
    if [ "$DITHER_BITS" != "$DEFAULT_DITHER_BITS" ]; then
        CMD+=" --dither-bits $DITHER_BITS"
    fi
    
    if [ "$ROW_SETTER" != "$DEFAULT_ROW_SETTER" ]; then
        CMD+=" --row-setter $ROW_SETTER"
    fi
    
    if [ "$LED_SEQUENCE" != "$DEFAULT_LED_SEQUENCE" ]; then
        CMD+=" --led-sequence $LED_SEQUENCE"
    fi
    
    if [ "$LIMIT_REFRESH_RATE" != "$DEFAULT_LIMIT_REFRESH_RATE" ]; then
        CMD+=" --limit-refresh-rate $LIMIT_REFRESH_RATE"
    fi
    
    if [ "$MAX_BRIGHTNESS" != "$DEFAULT_MAX_BRIGHTNESS" ]; then
        CMD+=" --limit-max-brightness $MAX_BRIGHTNESS"
    fi
    
    if [ "$WEB_PORT" != "$DEFAULT_WEB_PORT" ]; then
        CMD+=" --port $WEB_PORT"
    fi
    
    if [ "$WEB_INTERFACE" != "$DEFAULT_WEB_INTERFACE" ]; then
        CMD+=" --interface $WEB_INTERFACE"
    fi
    
    # Add optional parameters if set
    if [ ! -z "$PANEL_TYPE" ]; then
        CMD+=" --panel-type $PANEL_TYPE"
    fi
    
    if [ ! -z "$MULTIPLEXING" ]; then
        CMD+=" --multiplexing $MULTIPLEXING"
    fi
    
    if [ ! -z "$PIXEL_MAPPER" ]; then
        CMD+=" --pixel-mapper $PIXEL_MAPPER"
    fi
    
    if [ ! -z "$PI_CHIP" ]; then
        CMD+=" --pi-chip $PI_CHIP"
    fi
    
    # Add switches if enabled
    if [ "$INTERLACED" -eq 1 ]; then
        CMD+=" --interlaced"
    fi
    
    if [ "$NO_HARDWARE_PULSE" -eq 1 ]; then
        CMD+=" --no-hardware-pulse"
    fi
    
    if [ "$SHOW_REFRESH" -eq 1 ]; then
        CMD+=" --show-refresh"
    fi
    
    if [ "$INVERSE_COLORS" -eq 1 ]; then
        CMD+=" --inverse-colors"
    fi
    
    echo -e "${YELLOW}Running: $CMD${NC}"
    timeout 10s $CMD || true  # Allow timeout without failing the script
    
    # For the configuration test
    if [ -t 0 ]; then
        read -p "LED 面板显示是否正确？ (y/n): " is_working
    else
        read -p "Did the LED panel display correctly? (y/n): " is_working </dev/tty
    fi
    
    if [[ $is_working == "y" || $is_working == "Y" ]]; then
        return 0  # Success
    else
        return 1  # Failure
    fi
}

configure_panel() {
    echo -e "${YELLOW}请提供以下 LED 面板信息:${NC}"
    
    echo -e "\n${BLUE}驱动选择 (必填)${NC}"
    echo "1. native (纯 Rust 驱动 - 推荐默认)"
    echo "2. binding (C++ 绑定驱动 - 旧版备选)"
    read -p "Select driver type [1]: " driver_choice
    if [[ $driver_choice == "2" ]]; then
        DRIVER="binding"
    else
        DRIVER="native"
    fi
    
    echo -e "\n${BLUE}面板尺寸${NC}"
    echo "默认: $DEFAULT_ROWS 行, $DEFAULT_COLS 列"
    ROWS=$(get_input "行数 (默认: $DEFAULT_ROWS)" $DEFAULT_ROWS)
    COLS=$(get_input "列数 (默认: $DEFAULT_COLS)" $DEFAULT_COLS)
    CHAIN_LENGTH=$(get_input "串联的面板数量 (默认: $DEFAULT_CHAIN_LENGTH)" $DEFAULT_CHAIN_LENGTH)
    PARALLEL=$(get_input "并行运行的链数 (1-3) (默认: $DEFAULT_PARALLEL)" $DEFAULT_PARALLEL)
    
    echo -e "\n${BLUE}硬件配置${NC}"
    echo "常见硬件映射:"
    echo "  - regular (默认) - 标准 GPIO 映射"
    echo "  - adafruit-hat - Adafruit RGB Matrix Bonnet/HAT"
    echo "  - adafruit-hat-pwm - 带硬件 PWM 的 Adafruit HAT"
    echo "  - regular-pi1 - Standard GPIO mapping for Raspberry Pi 1"
    echo "  - classic - Early version of matrix wiring"
    echo "  - classic-pi1 - Early version for Pi 1 Rev A"
    
    HARDWARE_MAPPING=$(get_input "硬件映射 (默认: $DEFAULT_HARDWARE_MAPPING)" $DEFAULT_HARDWARE_MAPPING)
    
    echo -e "\n${BLUE}GPIO 设置${NC}"
    echo "新树莓派型号需要 GPIO 减速:"
    echo "  - Pi 0-3: 通常为值 1 或 2"
    echo "  - Pi 4: 通常为值 3 或 4"
    echo "  - (留空以自动选择)"
    
    GPIO_SLOWDOWN=$(get_input "GPIO 减速因子 (留空自动选择)" "$DEFAULT_GPIO_SLOWDOWN")
    
    echo -e "\n${BLUE}面板性能设置${NC}"
    PWM_BITS=$(get_input "PWM 位数 (1-11) (默认: $DEFAULT_PWM_BITS)" $DEFAULT_PWM_BITS)
    PWM_LSB_NANOSECONDS=$(get_input "PWM LSB 纳秒 (基本时间单位) (默认: $DEFAULT_PWM_LSB_NANOSECONDS)" $DEFAULT_PWM_LSB_NANOSECONDS)
    DITHER_BITS=$(get_input "抖动位数 (0 为不抖动) (默认: $DEFAULT_DITHER_BITS)" $DEFAULT_DITHER_BITS)
    
    echo -e "\n${BLUE}行地址设置${NC}"
    echo "行设置器选项:"
    echo "  - direct (默认) - 直接行选择"
    echo "  - shiftregister - AB addressed panels"
    echo "  - directabcdline - Direct ABCD line selection"
    echo "  - abcshiftregister - ABC shift register selection"
    echo "  - sm5266 - SM5266 with ABC shifter + DE direct"
    
    ROW_SETTER=$(get_input "行设置器 (默认: $DEFAULT_ROW_SETTER)" $DEFAULT_ROW_SETTER)
    
    echo -e "\n${BLUE}颜色设置${NC}"
    echo "常见 LED 序列:"
    echo "  - RGB (大多数面板)"
    echo "  - RBG"
    echo "  - GRB"
    echo "  - GBR"
    echo "  - BRG"
    echo "  - BGR"
    
    LED_SEQUENCE=$(get_input "LED 颜色序列 (默认: $DEFAULT_LED_SEQUENCE)" $DEFAULT_LED_SEQUENCE)
    
    # Panel type
    echo -e "\n${BLUE}高级面板设置${NC}"
    echo "某些面板需要特殊初始化，例如 FM6126A"
    
    PANEL_TYPE=$(get_input "面板类型 (不需要则留空)" "$DEFAULT_PANEL_TYPE")
    
    # Multiplexing 
    echo "多路复用选项:"
    echo "  1. 无 (默认) - 无多路复用"
    echo "  2. Stripe - 传统的逐行扫描"
    echo "  3. Checkered/Checker - Alternate pixels on different scan lines"
    echo "  4. Spiral - Panel using spiral of matrix segments"
    echo "  5. ZStripe/ZStripe08 - Z-stripe with 8 pixel intervals"
    echo "  6. ZStripe44 - Z-stripe with 4x4 pixel intervals"
    echo "  7. ZStripe80 - Z-stripe with 8x0 pixel intervals"
    echo "  8. Coreman - Multiplexing used in some Colorlight controllers"
    echo "  9. Kaler2Scan - Scan pattern used in some Kaler panels"
    echo "  10. P10Z - P10 outdoor panels with Z layout"
    echo "  11. QiangLiQ8 - QiangLi Q8 panels"
    echo "  12. InversedZStripe - Inverted Z-stripe pattern"
    echo "  13. P10Outdoor1R1G1B1 - P10 outdoor panel variant 1"
    echo "  14. P10Outdoor1R1G1B2 - P10 outdoor panel variant 2"
    echo "  15. P10Outdoor1R1G1B3 - P10 outdoor panel variant 3"
    echo "  16. P10Coreman - P10 panels with Coreman multiplexing"
    echo "  17. P8Outdoor1R1G1B - P8 outdoor panels"
    echo "  18. FlippedStripe - Stripe pattern with flipped orientation"
    echo "  19. P10Outdoor32x16HalfScan - P10 32x16 outdoor panels with half-scan"

    read -p "Select multiplexing type [1]: " multiplex_choice
    case $multiplex_choice in
        2) MULTIPLEXING="Stripe";;
        3) MULTIPLEXING="Checkered";;
        4) MULTIPLEXING="Spiral";;
        5) MULTIPLEXING="ZStripe";;
        6) MULTIPLEXING="ZStripe44";;
        7) MULTIPLEXING="ZStripe80";;
        8) MULTIPLEXING="Coreman";;
        9) MULTIPLEXING="Kaler2Scan";;
        10) MULTIPLEXING="P10Z";;
        11) MULTIPLEXING="QiangLiQ8";;
        12) MULTIPLEXING="InversedZStripe";;
        13) MULTIPLEXING="P10Outdoor1R1G1B1";;
        14) MULTIPLEXING="P10Outdoor1R1G1B2";;
        15) MULTIPLEXING="P10Outdoor1R1G1B3";;
        16) MULTIPLEXING="P10Coreman";;
        17) MULTIPLEXING="P8Outdoor1R1G1B";;
        18) MULTIPLEXING="FlippedStripe";;
        19) MULTIPLEXING="P10Outdoor32x16HalfScan";;
        *) MULTIPLEXING="";;  # Default to no multiplexing
    esac
    
    # Pixel mapper
    echo "像素映射器 (分号分隔列表, 例如: 'U-mapper;Rotate:90')"
    echo "(不需要则留空)"
    
    PIXEL_MAPPER=$(get_input "像素映射器 (不需要则留空)" "$DEFAULT_PIXEL_MAPPER")
    
    # Advanced switch options
    echo -e "\n${BLUE}附加选项${NC}"
    INTERLACED=$(get_yes_no "启用隔行扫描模式?" "n")

    if [[ "$DRIVER" == "binding" ]]; then
        NO_HARDWARE_PULSE=$(get_yes_no "禁用硬件引脚脉冲生成?" "n")
        SHOW_REFRESH=$(get_yes_no "在终端显示刷新率统计?" "n")
        INVERSE_COLORS=$(get_yes_no "反转显示颜色?" "n")
    fi
    
    if [[ "$DRIVER" == "native" ]]; then
        echo "树莓派芯片型号 (例如: BCM2711, 留空自动检测)"
        PI_CHIP=$(get_input "Pi 芯片型号 (留空自动检测)" "$DEFAULT_PI_CHIP")
    fi
    
    LIMIT_REFRESH_RATE=$(get_input "限制刷新率 (Hz, 0 为不限制) (默认: $DEFAULT_LIMIT_REFRESH_RATE)" $DEFAULT_LIMIT_REFRESH_RATE)
    MAX_BRIGHTNESS=$(get_input "最大亮度限制 (0-100) (默认: $DEFAULT_MAX_BRIGHTNESS)" $DEFAULT_MAX_BRIGHTNESS)
    
    echo -e "\n${BLUE}Web 界面${NC}"
    WEB_PORT=$(get_input "Web 服务器端口 (默认: $DEFAULT_WEB_PORT)" $DEFAULT_WEB_PORT)
    WEB_INTERFACE=$(get_input "绑定的网络接口 (默认: $DEFAULT_WEB_INTERFACE)" $DEFAULT_WEB_INTERFACE)
}

# Main configuration flow
configure_panel

while ! test_configuration; do
    echo -e "${YELLOW}配置测试失败。让我们调整设置。${NC}"
    configure_panel
done

echo -e "${GREEN}太棒了！配置测试成功。${NC}"

# Create environment variables string for systemd service
ENV_VARS=""
# Driver is required, always add it
ENV_VARS+="Environment=\"LED_DRIVER=$DRIVER\"\n"

# Only add non-default values
if [ "$ROWS" != "$DEFAULT_ROWS" ]; then
    ENV_VARS+="Environment=\"LED_ROWS=$ROWS\"\n"
fi

if [ "$COLS" != "$DEFAULT_COLS" ]; then
    ENV_VARS+="Environment=\"LED_COLS=$COLS\"\n"
fi

if [ "$CHAIN_LENGTH" != "$DEFAULT_CHAIN_LENGTH" ]; then
    ENV_VARS+="Environment=\"LED_CHAIN_LENGTH=$CHAIN_LENGTH\"\n"
fi

if [ "$PARALLEL" != "$DEFAULT_PARALLEL" ]; then
    ENV_VARS+="Environment=\"LED_PARALLEL=$PARALLEL\"\n"
fi

if [ "$HARDWARE_MAPPING" != "$DEFAULT_HARDWARE_MAPPING" ]; then
    ENV_VARS+="Environment=\"LED_HARDWARE_MAPPING=$HARDWARE_MAPPING\"\n"
fi

if [ "$PWM_BITS" != "$DEFAULT_PWM_BITS" ]; then
    ENV_VARS+="Environment=\"LED_PWM_BITS=$PWM_BITS\"\n"
fi

if [ "$PWM_LSB_NANOSECONDS" != "$DEFAULT_PWM_LSB_NANOSECONDS" ]; then
    ENV_VARS+="Environment=\"LED_PWM_LSB_NANOSECONDS=$PWM_LSB_NANOSECONDS\"\n"
fi

if [ "$DITHER_BITS" != "$DEFAULT_DITHER_BITS" ]; then
    ENV_VARS+="Environment=\"LED_DITHER_BITS=$DITHER_BITS\"\n"
fi

if [ "$ROW_SETTER" != "$DEFAULT_ROW_SETTER" ]; then
    ENV_VARS+="Environment=\"LED_ROW_SETTER=$ROW_SETTER\"\n"
fi

if [ "$LED_SEQUENCE" != "$DEFAULT_LED_SEQUENCE" ]; then
    ENV_VARS+="Environment=\"LED_SEQUENCE=$LED_SEQUENCE\"\n"
fi

if [ "$LIMIT_REFRESH_RATE" != "$DEFAULT_LIMIT_REFRESH_RATE" ]; then
    ENV_VARS+="Environment=\"LED_LIMIT_REFRESH_RATE=$LIMIT_REFRESH_RATE\"\n"
fi

if [ "$MAX_BRIGHTNESS" != "$DEFAULT_MAX_BRIGHTNESS" ]; then
    ENV_VARS+="Environment=\"LED_LIMIT_MAX_BRIGHTNESS=$MAX_BRIGHTNESS\"\n"
fi

if [ "$WEB_PORT" != "$DEFAULT_WEB_PORT" ]; then
    ENV_VARS+="Environment=\"LED_PORT=$WEB_PORT\"\n"
fi

if [ "$WEB_INTERFACE" != "$DEFAULT_WEB_INTERFACE" ]; then
    ENV_VARS+="Environment=\"LED_INTERFACE=$WEB_INTERFACE\"\n"
fi

# Add optional parameters if set
if [ ! -z "$GPIO_SLOWDOWN" ]; then
    ENV_VARS+="Environment=\"LED_GPIO_SLOWDOWN=$GPIO_SLOWDOWN\"\n"
fi

if [ ! -z "$PANEL_TYPE" ]; then
    ENV_VARS+="Environment=\"LED_PANEL_TYPE=$PANEL_TYPE\"\n"
fi

if [ ! -z "$MULTIPLEXING" ]; then
    ENV_VARS+="Environment=\"LED_MULTIPLEXING=$MULTIPLEXING\"\n"
fi

if [ ! -z "$PIXEL_MAPPER" ]; then
    ENV_VARS+="Environment=\"LED_PIXEL_MAPPER=$PIXEL_MAPPER\"\n"
fi

if [ ! -z "$PI_CHIP" ]; then
    ENV_VARS+="Environment=\"LED_PI_CHIP=$PI_CHIP\"\n"
fi

# Boolean options (inverse logic for hardware pulsing)
if [ "$INTERLACED" -eq 1 ]; then
    ENV_VARS+="Environment=\"LED_INTERLACED=1\"\n"
fi

if [ "$NO_HARDWARE_PULSE" -eq 1 ]; then
    ENV_VARS+="Environment=\"LED_HARDWARE_PULSING=0\"\n"
elif [ "$NO_HARDWARE_PULSE" -ne "$DEFAULT_NO_HARDWARE_PULSE" ]; then
    ENV_VARS+="Environment=\"LED_HARDWARE_PULSING=1\"\n"
fi

if [ "$SHOW_REFRESH" -eq 1 ]; then
    ENV_VARS+="Environment=\"LED_SHOW_REFRESH=1\"\n"
fi

if [ "$INVERSE_COLORS" -eq 1 ]; then
    ENV_VARS+="Environment=\"LED_INVERSE_COLORS=1\"\n"
fi

# Create systemd service with the configuration
echo -e "${YELLOW}正在使用您的配置创建 systemd 服务...${NC}"
cat > /etc/systemd/system/rpi-led-sign.service <<EOF
[Unit]
Description=RPi LED Sign Controller
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/rpi_led_sign_controller
$(echo -e $ENV_VARS)
Restart=on-failure
User=root

# Priority settings
Nice=-10
IOSchedulingClass=realtime
IOSchedulingPriority=0
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=99
OOMScoreAdjust=-900

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service (this requires root)
systemctl daemon-reload
systemctl enable rpi-led-sign.service
systemctl start rpi-led-sign.service
echo -e "${GREEN}Systemd 服务已安装并启动。${NC}"

# Return to the original directory
cd $CURRENT_DIR

echo -e "${GREEN}安装完成！${NC}"
echo -e "Web 界面地址: http://$(hostname -I | awk '{print $1}'):$WEB_PORT"
echo -e "源代码位于: ${BLUE}/usr/local/src/rpi-led-sign-controller${NC}"
echo -e "您可以使用以下命令管理服务: sudo systemctl [start|stop|restart|status] rpi-led-sign.service"
echo -e ""
echo -e "将来要更新，您可以："
echo -e "  • 再次运行此脚本: ${BLUE}curl -sSL https://raw.githubusercontent.com/kxgx/RPi-LED-Sign-Controller-zh/main/scripts/install.sh | sudo bash${NC}"
echo -e "  • 或者从源代码目录: ${BLUE}cd /usr/local/src/rpi-led-sign-controller && sudo bash scripts/install.sh${NC}"
echo -e ""
echo -e "要卸载，请运行: ${BLUE}sudo bash /usr/local/src/rpi-led-sign-controller/scripts/uninstall.sh${NC}"
echo -e ""
echo -e "更多信息请访问: ${BLUE}https://github.com/kxgx/RPi-LED-Sign-Controller-zh${NC}"
exit 0