#!/bin/bash

# ============================================================
# dialog-save 统一管理脚本
# 作者：yeji
# 
# 单行安装命令：
# bash <(curl -sL https://raw.githubusercontent.com/firebird2003/dialog-save/main/install.sh)
# ============================================================

# ==================== 版本信息 ====================
VERSION="2.5.0"
RELEASE_DATE="2026-03-17"

CHANGELOG="
v2.5.0 (2026-03-17)
  - 优化配置流程：
    - 分两步引导：先指定 Obsidian 基础目录，再指定保存目录名
    - 自动检测 Obsidian 库目录
    - 支持自定义保存目录名（如 11clawrecord）
  - 配置时自动创建软链接
  - 改进配置确认信息显示

v2.4.0 (2026-03-17)
  - 新增软链接管理功能：
    - claw-对话/ 对话历史目录
    - claw-配置/ 代理配置文件链接
    - claw-工作区/ 共享工作区链接
  - 新增目录初始化：~/agents/ 目录结构
  - 新增迁移命令：migrate 迁移旧目录结构
  - 新增链接命令：links, links-status, link-agent
  - 配置文件新增 structure、links、agents 配置项

v2.3.0 (2026-03-17)
  - 新增项目文件夹功能：保存项目成果到独立目录
  - 新增版本化保存：文件名包含版本号，保留历史版本
  - 区分两种保存类型：
    - 对话保存：自动保存，格式 YYMMDDHHMM+话题.md
    - 项目成果：手动触发，保存到项目文件夹，带版本号
  - 新增命令：project-save, project-list, project-versions

v2.2.0 (2026-03-17)
  - 改进话题提取：智能提取关键词，用 - 连接
  - 文件名简化：移除 session_id 后缀
  - 内容清理：移除工具调用和结果，只保留文字对话

v2.1.0 (2026-03-17)
  - 改进安装体验：单行命令支持安装/升级
  - 智能处理目录已存在的情况
  - 依赖问题不会中断流程，仅警告

v1.3.2 (2026-03-16)
  - 新版本覆盖安装：目录已存在时自动 git pull 更新
  - 版本检测：显示当前版本和远程最新版本

v1.3.0 (2026-03-16)
  - 目录名格式改为 代理名@主机名（兼容iCloud同步）
  - 新增保存机制选项：自动/手动

v1.0.0 (2026-03-16)
  - 初始版本
"

# ==================== 路径配置 ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SKILL_DIR/config.json"
LOG_DIR="$SKILL_DIR/logs"
PID_FILE="$SKILL_DIR/.webdav.pid"
MONITOR_PID_FILE="$SKILL_DIR/.monitor.pid"
CACHE_DIR="$SKILL_DIR/.cache/pending"
STATE_FILE="$SKILL_DIR/.cache/save_state.json"
GITHUB_REPO="https://github.com/firebird2003/dialog-save.git"
INSTALL_DIR="$HOME/.openclaw/workspace/skills/dialog-save"

# ==================== 确保命令可用 ====================
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$PATH"

JQ_CMD=""
if [[ -x "/usr/local/bin/jq" ]]; then
    JQ_CMD="/usr/local/bin/jq"
elif [[ -x "/opt/homebrew/bin/jq" ]]; then
    JQ_CMD="/opt/homebrew/bin/jq"
elif command -v jq &> /dev/null; then
    JQ_CMD="jq"
fi

# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ==================== 打印函数 ====================
print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}dialog-save v${VERSION}${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  OpenClaw 对话保存技能                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# ==================== JSON 读取函数 ====================

# 查找代理级配置文件
find_agent_config() {
    # 检查当前工作目录及其父目录
    local DIR="$PWD"
    for i in {1..5}; do
        if [[ -f "$DIR/dialog-save-config.json" ]]; then
            echo "$DIR/dialog-save-config.json"
            return 0
        fi
        [[ "$DIR" == "/" ]] && break
        DIR="$(dirname "$DIR")"
    done
    # 检查 OPENCLAW_AGENT_DIR 环境变量
    if [[ -n "$OPENCLAW_AGENT_DIR" && -f "$OPENCLAW_AGENT_DIR/dialog-save-config.json" ]]; then
        echo "$OPENCLAW_AGENT_DIR/dialog-save-config.json"
        return 0
    fi
    return 1
}

read_config() {
    local KEY="$1"
    local CONFIG_TO_USE="$CONFIG_FILE"
    
    # 检查是否有代理级配置
    local AGENT_CONFIG=$(find_agent_config)
    if [[ -n "$AGENT_CONFIG" ]]; then
        # 对于代理相关配置，优先使用代理级配置
        case "$KEY" in
            '.agent.name'|'.agent.host'|'.agent.id')
                CONFIG_TO_USE="$AGENT_CONFIG"
                ;;
        esac
    fi
    
    if [[ -f "$CONFIG_TO_USE" ]]; then
        if [[ -n "$JQ_CMD" ]]; then
            "$JQ_CMD" -r "$KEY" "$CONFIG_TO_USE" 2>/dev/null
        else
            case "$KEY" in
                '.obsidianRoot') grep -o '"obsidianRoot"[^,]*' "$CONFIG_TO_USE" | cut -d'"' -f4 ;;
                '.agent.name') grep -o '"name"[^,]*' "$CONFIG_TO_USE" | head -1 | cut -d'"' -f4 ;;
                '.agent.host') grep -o '"host"[^,]*' "$CONFIG_TO_USE" | head -1 | cut -d'"' -f4 ;;
                '.agent.id') grep -o '"id"[^,]*' "$CONFIG_TO_USE" | head -1 | cut -d'"' -f4 ;;
                '.webdav.port') grep -o '"port"[^,}]*' "$CONFIG_TO_USE" | head -1 | grep -o '[0-9]*' ;;
                '.mode') grep -o '"mode"[^,]*' "$CONFIG_TO_USE" | cut -d'"' -f4 ;;
                '.autoStart') grep -o '"autoStart"[^,}]*' "$CONFIG_TO_USE" | grep -o 'true\|false' ;;
                '.saveMode') grep -o '"saveMode"[^,}]*' "$CONFIG_TO_USE" | cut -d'"' -f4 ;;
                '.version') grep -o '"version"[^,}]*' "$CONFIG_TO_USE" | head -1 | cut -d'"' -f4 ;;
                *) echo "" ;;
            esac
        fi
    else
        echo ""
    fi
}

# ==================== 系统检测 ====================
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos" ;;
        Linux*)     echo "linux" ;;
        *)          echo "unknown" ;;
    esac
}

# ==================== 版本比较 ====================
version_gt() {
    # 返回 true 如果 $1 > $2
    [[ "$1" != "$2" && "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

# ==================== 检查更新 ====================
check_update() {
    print_step "检查版本更新..."
    
    cd "$SKILL_DIR" 2>/dev/null || return
    
    # 获取远程最新版本
    git fetch origin 2>/dev/null || true
    local REMOTE_VERSION=$(git show origin/main:config.json 2>/dev/null | grep -o '"version"[^,}]*' | head -1 | cut -d'"' -f4)
    
    if [[ -n "$REMOTE_VERSION" ]]; then
        echo "  当前版本: $VERSION"
        echo "  最新版本: $REMOTE_VERSION"
        
        if version_gt "$REMOTE_VERSION" "$VERSION"; then
            echo ""
            echo -e "${YELLOW}发现新版本！${NC}"
            echo -n "是否更新？[Y/n]: "
            read -r UPDATE_CHOICE
            
            if [[ ! "$UPDATE_CHOICE" =~ ^[Nn] ]]; then
                print_step "更新到最新版本..."
                if git pull origin main 2>/dev/null; then
                    print_success "更新成功！"
                    print_info "请重新运行脚本以使用新版本"
                    exit 0
                else
                    print_error "更新失败，请手动执行: git pull origin main"
                fi
            fi
        else
            print_success "已是最新版本"
        fi
    fi
}

# ==================== 依赖检查（不中断流程）====================

check_dependency() {
    local DEP="$1"
    case "$DEP" in
        rclone) command -v rclone &> /dev/null ;;
        jq)     [[ -n "$JQ_CMD" ]] ;;
        curl)   command -v curl &> /dev/null ;;
        git)    command -v git &> /dev/null ;;
        python3) command -v python3 &> /dev/null ;;
        *)      command -v "$DEP" &> /dev/null ;;
    esac
}

install_rclone() {
    print_info "安装 rclone..."
    
    local OS=$(detect_os)
    
    if [[ "$OS" == "macos" ]] && command -v brew &> /dev/null; then
        if HOMEBREW_NO_AUTO_UPDATE=1 brew install rclone 2>/dev/null; then
            print_success "rclone 安装成功"
            return 0
        fi
    fi
    
    if curl -sS https://rclone.org/install.sh | sudo bash 2>/dev/null; then
        print_success "rclone 安装成功"
        return 0
    fi
    
    print_warning "rclone 自动安装失败，请手动安装: https://rclone.org/install/"
    return 1
}

install_jq() {
    print_info "安装 jq..."
    
    local OS=$(detect_os)
    
    case $OS in
        macos)
            if command -v brew &> /dev/null; then
                HOMEBREW_NO_AUTO_UPDATE=1 brew install jq 2>/dev/null && print_success "jq 安装成功" && return 0
            fi
            ;;
        linux)
            if command -v apt-get &> /dev/null; then
                sudo apt-get update -qq && sudo apt-get install -y -qq jq && print_success "jq 安装成功" && return 0
            elif command -v yum &> /dev/null; then
                sudo yum install -y -q jq && print_success "jq 安装成功" && return 0
            fi
            ;;
    esac
    
    print_warning "jq 自动安装失败，请手动安装"
    return 1
}

check_all_dependencies() {
    print_step "检查依赖..."
    local MISSING=0
    
    if check_dependency git; then
        print_success "git 已安装"
    else
        print_warning "git 未安装 - 部分功能受限"
        ((MISSING++))
    fi
    
    if check_dependency jq; then
        print_success "jq 已安装"
    else
        print_warning "jq 未安装 - 尝试安装..."
        install_jq || true
        # 重新检测
        if [[ -x "/usr/local/bin/jq" ]]; then
            JQ_CMD="/usr/local/bin/jq"
        elif [[ -x "/opt/homebrew/bin/jq" ]]; then
            JQ_CMD="/opt/homebrew/bin/jq"
        elif command -v jq &> /dev/null; then
            JQ_CMD="jq"
        fi
    fi
    
    if check_dependency rclone; then
        print_success "rclone 已安装"
    else
        print_warning "rclone 未安装 - 尝试安装..."
        install_rclone || true
    fi
    
    if check_dependency curl; then
        print_success "curl 已安装"
    else
        print_warning "curl 未安装 - 部分功能受限"
        ((MISSING++))
    fi
    
    if check_dependency python3; then
        print_success "python3 已安装"
    else
        print_warning "python3 未安装 - 对话保存功能不可用"
        ((MISSING++))
    fi
    
    if [[ $MISSING -gt 0 ]]; then
        echo ""
        print_warning "缺少 $MISSING 个依赖，部分功能可能受限"
        print_info "继续运行..."
    fi
}

# ==================== 配置管理 ====================

do_config() {
    print_step "配置向导..."
    echo ""
    
    local CURRENT_ROOT="" CURRENT_PORT=8080
    local CURRENT_NAME="管理者" CURRENT_HOST="" CURRENT_MODE="local"
    local CURRENT_SAVEMODE="auto" CURRENT_SAVE_DIR=""
    
    if [[ -f "$CONFIG_FILE" ]]; then
        CURRENT_ROOT=$(read_config '.obsidianRoot')
        CURRENT_PORT=$(read_config '.webdav.port')
        CURRENT_NAME=$(read_config '.agent.name')
        CURRENT_HOST=$(read_config '.agent.host')
        CURRENT_MODE=$(read_config '.mode')
        CURRENT_SAVEMODE=$(read_config '.saveMode')
        CURRENT_SAVE_DIR=$(read_config '.saveDir')
    fi
    
    # ========== 第一步：Obsidian 基础目录 ==========
    echo -e "${BOLD}【第一步】Obsidian 基础目录${NC}"
    echo ""
    echo "请指定 Obsidian 笔记库的基础目录（库目录）"
    echo "示例: /Users/yeji/Library/Mobile Documents/iCloud~md~obsidian/Documents/YejiNote"
    echo ""
    
    # 尝试自动检测
    local DETECTED_ROOT=""
    if [[ -d "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents" ]]; then
        DETECTED_ROOT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
    fi
    
    if [[ -n "$CURRENT_ROOT" && "$CURRENT_ROOT" != "null" ]]; then
        echo -e "   当前配置: ${GREEN}$CURRENT_ROOT${NC}"
    elif [[ -n "$DETECTED_ROOT" ]]; then
        echo -e "   检测到: ${CYAN}$DETECTED_ROOT${NC}"
    fi
    
    echo ""
    echo -n "请输入 Obsidian 基础目录路径 [回车使用检测值]: "
    read -r OBSIDIAN_BASE
    
    # 如果用户没有输入，使用检测值或当前值
    if [[ -z "$OBSIDIAN_BASE" ]]; then
        if [[ -n "$CURRENT_ROOT" && "$CURRENT_ROOT" != "null" ]]; then
            # 从当前路径提取基础目录
            OBSIDIAN_BASE=$(dirname "$CURRENT_ROOT")
        elif [[ -n "$DETECTED_ROOT" ]]; then
            OBSIDIAN_BASE="$DETECTED_ROOT"
        else
            print_error "路径不能为空"
            return 1
        fi
    fi
    
    # 验证目录是否存在
    if [[ ! -d "$OBSIDIAN_BASE" ]]; then
        print_warning "目录不存在: $OBSIDIAN_BASE"
        echo -n "是否创建？[Y/n]: "
        read -r CREATE_DIR
        if [[ ! "$CREATE_DIR" =~ ^[Nn] ]]; then
            mkdir -p "$OBSIDIAN_BASE"
        else
            print_error "请指定一个有效的目录"
            return 1
        fi
    fi
    
    # ========== 第二步：保存目录名 ==========
    echo ""
    echo -e "${BOLD}【第二步】对话保存目录名${NC}"
    echo ""
    echo "请指定保存对话的目录名称（将在 Obsidian 基础目录下创建）"
    echo ""
    
    # 从当前配置提取保存目录名
    local CURRENT_DIR_NAME="00clawrecord"
    if [[ -n "$CURRENT_SAVE_DIR" && "$CURRENT_SAVE_DIR" != "null" ]]; then
        CURRENT_DIR_NAME="$CURRENT_SAVE_DIR"
    elif [[ -n "$CURRENT_ROOT" && "$CURRENT_ROOT" != "null" ]]; then
        CURRENT_DIR_NAME=$(basename "$CURRENT_ROOT")
    fi
    
    echo -e "   当前: ${GREEN}$CURRENT_DIR_NAME${NC}"
    echo ""
    echo -n "请输入目录名 [回车保留当前]: "
    read -r SAVE_DIR_NAME
    SAVE_DIR_NAME=${SAVE_DIR_NAME:-$CURRENT_DIR_NAME}
    
    # 构建完整路径
    OBSIDIAN_ROOT="$OBSIDIAN_BASE/$SAVE_DIR_NAME"
    
    echo ""
    echo -e "   完整路径: ${CYAN}$OBSIDIAN_ROOT${NC}"
    
    # ========== 第三步：代理配置 ==========
    echo ""
    echo -e "${BOLD}【第三步】代理配置${NC}"
    echo ""
    
    # 代理名
    echo -e "${YELLOW}代理名称${NC}"
    echo -e "   当前: $CURRENT_NAME"
    echo -n "   请输入 [回车保留当前]: "
    read -r AGENT_NAME
    AGENT_NAME=${AGENT_NAME:-$CURRENT_NAME}
    
    # 主机名
    local DEFAULT_HOST=$(hostname | sed 's/.local$//')
    [[ -n "$CURRENT_HOST" && "$CURRENT_HOST" != "null" ]] && DEFAULT_HOST="$CURRENT_HOST"
    echo ""
    echo -e "${YELLOW}主机名称${NC}"
    echo -e "   当前: $DEFAULT_HOST"
    echo -n "   请输入 [回车保留当前]: "
    read -r AGENT_HOST
    AGENT_HOST=${AGENT_HOST:-$DEFAULT_HOST}
    
    # ========== 第四步：保存机制 ==========
    echo ""
    echo -e "${BOLD}【第四步】保存机制${NC}"
    echo ""
    echo "   1) 手动 - 需要用户说'存入本地目录'才保存"
    echo "   2) 自动 - 自动保存所有对话（推荐）"
    echo -e "   当前: $CURRENT_SAVEMODE"
    echo ""
    echo -n "   请选择 [1/2, 回车保留当前]: "
    read -r SAVEMODE_CHOICE
    
    case "$SAVEMODE_CHOICE" in
        1) SAVE_MODE="manual" ;;
        2) SAVE_MODE="auto" ;;
        *)  SAVE_MODE=${CURRENT_SAVEMODE:-"auto"} ;;
    esac
    
    # ========== 第五步：运行模式 ==========
    echo ""
    echo -e "${BOLD}【第五步】运行模式${NC}"
    echo ""
    echo "   1) 本地模式 (本机运行 WebDAV 服务)"
    echo "   2) 远程模式 (连接其他主机的 WebDAV)"
    echo -e "   当前: $CURRENT_MODE"
    echo ""
    echo -n "   请选择 [1/2, 回车保留当前]: "
    read -r MODE_CHOICE
    
    case "$MODE_CHOICE" in
        1) MODE="local"; REMOTE_URL="" ;;
        2) 
            MODE="remote"
            echo -n "   请输入远程 WebDAV 地址: "
            read -r REMOTE_URL
            ;;
        *)  
            MODE="$CURRENT_MODE"
            REMOTE_URL=""
            ;;
    esac
    
    # ========== 第六步：软链接设置 ==========
    echo ""
    echo -e "${BOLD}【第六步】软链接设置${NC}"
    echo ""
    echo "是否创建以下软链接？"
    echo "  • claw-配置/管理者 → ~/.openclaw/workspace/"
    echo "  • claw-工作区/shared → ~/agents/shared/"
    echo ""
    echo -n "创建软链接？[Y/n]: "
    read -r LINKS_CHOICE
    local LINKS_ENABLED="true"
    [[ "$LINKS_CHOICE" =~ ^[Nn] ]] && LINKS_ENABLED="false"
    
    # WebDAV 端口
    echo ""
    echo -e "${YELLOW}WebDAV 服务端口${NC}"
    echo -e "   当前: $CURRENT_PORT"
    echo -n "   请输入 [回车保留当前]: "
    read -r WEBDAV_PORT
    WEBDAV_PORT=${WEBDAV_PORT:-$CURRENT_PORT}
    
    # 开机自启
    local AUTO_START="false"
    if [[ "$MODE" == "local" ]]; then
        echo ""
        echo -e "${YELLOW}开机自动启动服务？${NC}"
        echo -n "   [Y/n]: "
        read -r AUTO_CHOICE
        [[ ! "$AUTO_CHOICE" =~ ^[Nn] ]] && AUTO_START="true"
    fi
    
    # ========== 确认 ==========
    echo ""
    echo -e "${BOLD}========== 配置确认 ==========${NC}"
    echo ""
    echo "  Obsidian 基础目录: $OBSIDIAN_BASE"
    echo "  保存目录名: $SAVE_DIR_NAME"
    echo "  完整路径: $OBSIDIAN_ROOT"
    echo ""
    echo "  对话保存位置: $OBSIDIAN_ROOT/claw-对话/${AGENT_NAME}@${AGENT_HOST}/"
    echo "  配置文件链接: $OBSIDIAN_ROOT/claw-配置/${AGENT_NAME}/"
    echo "  工作区链接: $OBSIDIAN_ROOT/claw-工作区/shared/"
    echo ""
    echo "  代理名称: $AGENT_NAME"
    echo "  主机名称: $AGENT_HOST"
    echo "  保存机制: $SAVE_MODE"
    echo "  运行模式: $MODE"
    echo "  创建软链接: $LINKS_ENABLED"
    echo "  WebDAV 端口: $WEBDAV_PORT"
    echo "  开机自启: $AUTO_START"
    echo -e "${BOLD}==============================${NC}"
    echo ""
    echo -n "确认保存？[Y/n]: "
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[Nn] ]]; then
        print_warning "已取消"
        return 1
    fi
    
    # 写入配置
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" << EOF
{
  "version": "$VERSION",
  "obsidianRoot": "$OBSIDIAN_ROOT",
  "saveDir": "$SAVE_DIR_NAME",
  "webdav": {
    "enabled": true,
    "port": $WEBDAV_PORT,
    "host": "0.0.0.0"
  },
  "agent": {
    "name": "$AGENT_NAME",
    "host": "$AGENT_HOST"
  },
  "sync": {
    "retryIntervalMinutes": 1,
    "maxRetries": 3,
    "cacheDir": ".cache/pending"
  },
  "saveMode": "$SAVE_MODE",
  "mode": "$MODE",
  "remoteWebdavUrl": "$REMOTE_URL",
  "autoStart": $AUTO_START,
  "structure": {
    "dialogDir": "claw-对话",
    "configDir": "claw-配置",
    "workspaceDir": "claw-工作区"
  },
  "links": {
    "enabled": $LINKS_ENABLED,
    "manager": {
      "name": "$AGENT_NAME",
      "target": "~/.openclaw/workspace"
    },
    "shared": {
      "name": "shared",
      "target": "~/agents/shared"
    }
  },
  "agents": {
    "rootDir": "~/agents",
    "autoInit": true
  }
}
EOF
    
    print_success "配置已保存"
    
    # 创建保存目录
    mkdir -p "$OBSIDIAN_ROOT"
    
    # 如果启用软链接，创建链接
    if [[ "$LINKS_ENABLED" == "true" ]]; then
        echo ""
        init_agents_structure
        setup_links
    fi
    
    return 0
}

# ==================== 服务管理 ====================

setup_autostart() {
    local ENABLE="$1"
    local OS=$(detect_os)
    
    case $OS in
        macos)
            local PLIST="$HOME/Library/LaunchAgents/com.openclaw.dialog-save.webdav.plist"
            if [[ "$ENABLE" == "true" ]]; then
                mkdir -p "$(dirname "$PLIST")"
                cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openclaw.dialog-save.webdav</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SKILL_DIR/scripts/manage.sh</string>
        <string>_start_service</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/webdav.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/webdav.error.log</string>
</dict>
</plist>
EOF
                launchctl load "$PLIST" 2>/dev/null || true
            else
                [[ -f "$PLIST" ]] && { launchctl unload "$PLIST" 2>/dev/null || true; rm -f "$PLIST"; }
            fi
            ;;
        linux)
            local SERVICE="/etc/systemd/system/dialog-save-webdav.service"
            if [[ "$ENABLE" == "true" ]] && [[ -w "/etc/systemd/system" ]]; then
                cat | sudo tee "$SERVICE" > /dev/null << EOF
[Unit]
Description=Dialog Save WebDAV Service
After=network.target

[Service]
Type=simple
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
ExecStart=/bin/bash $SKILL_DIR/scripts/manage.sh _start_service
Restart=on-failure
User=$USER

[Install]
WantedBy=multi-user.target
EOF
                sudo systemctl daemon-reload
                sudo systemctl enable dialog-save-webdav 2>/dev/null || true
            else
                [[ -f "$SERVICE" ]] && { sudo systemctl disable dialog-save-webdav 2>/dev/null || true; sudo rm -f "$SERVICE"; sudo systemctl daemon-reload; }
            fi
            ;;
    esac
}

start_webdav() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "请先配置"
        return 1
    fi
    
    local MODE=$(read_config '.mode')
    [[ "$MODE" == "remote" ]] && { print_info "远程模式，无需启动本地服务"; return 0; }
    
    local ROOT=$(read_config '.obsidianRoot')
    local NAME=$(read_config '.agent.name')
    local HOST=$(read_config '.agent.host')
    local PORT=$(read_config '.webdav.port')
    
    local WEBDAV_ROOT="$ROOT"
    
    if [[ -f "$PID_FILE" ]] && ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
        print_success "WebDAV 已运行 (PID: $(cat $PID_FILE))"
        return 0
    fi
    
    mkdir -p "$WEBDAV_ROOT" "$LOG_DIR"
    
    nohup rclone serve webdav "$WEBDAV_ROOT" \
        --addr "0.0.0.0:$PORT" \
        --read-only=false \
        --no-checksum \
        > "$LOG_DIR/webdav.log" 2> "$LOG_DIR/webdav.error.log" &
    
    echo $! > "$PID_FILE"
    sleep 1
    
    if ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
        print_success "WebDAV 已启动 (PID: $(cat $PID_FILE))"
        echo "  地址: http://localhost:$PORT"
        echo "  根目录: $WEBDAV_ROOT"
        echo "  对话目录: $ROOT/${NAME}@${HOST}"
        return 0
    else
        print_error "启动失败，查看日志: $LOG_DIR/webdav.error.log"
        return 1
    fi
}

stop_webdav() {
    if [[ -f "$PID_FILE" ]]; then
        local PID=$(cat "$PID_FILE")
        kill $PID 2>/dev/null || true
        rm -f "$PID_FILE"
        print_success "WebDAV 已停止"
    else
        print_info "WebDAV 未运行"
    fi
}

status_webdav() {
    if [[ -f "$PID_FILE" ]] && ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
        local PID=$(cat "$PID_FILE")
        local PORT=$(read_config '.webdav.port')
        [[ -z "$PORT" ]] && PORT="8080"
        print_success "WebDAV 运行中 (PID: $PID)"
        echo "  地址: http://localhost:$PORT"
    else
        print_info "WebDAV 未运行"
    fi
}

# ==================== 对话保存功能 ====================

# 运行 Python 解析器
run_parser() {
    local ARGS="$1"
    local PYTHON_CMD=""
    
    # 查找 Python
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        print_error "Python 未安装，对话保存功能不可用"
        return 1
    fi
    
    cd "$SKILL_DIR"
    $PYTHON_CMD lib/session_parser.py $ARGS
}

# 立即保存对话
save_now() {
    print_step "保存对话..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "请先配置"
        return 1
    fi
    
    run_parser "--auto"
    return $?
}

# 启动监控服务
start_monitor() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_warning "请先配置"
        return 1
    fi
    
    local SAVE_MODE=$(read_config '.saveMode')
    if [[ "$SAVE_MODE" != "auto" ]]; then
        print_warning "当前为手动模式，无需启动监控"
        print_info "如需自动保存，请选择菜单中的'修改配置'"
        return 0
    fi
    
    if [[ -f "$MONITOR_PID_FILE" ]] && ps -p $(cat "$MONITOR_PID_FILE") > /dev/null 2>&1; then
        print_success "监控服务已运行 (PID: $(cat $MONITOR_PID_FILE))"
        return 0
    fi
    
    mkdir -p "$LOG_DIR" "$CACHE_DIR"
    
    # 创建监控脚本
    local MONITOR_SCRIPT="$SKILL_DIR/.cache/monitor_loop.sh"
    cat > "$MONITOR_SCRIPT" << 'MONITOR_EOF'
#!/bin/bash
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$SKILL_DIR/logs/monitor.log"
STATE_FILE="$SKILL_DIR/.cache/save_state.json"

log() {
    echo "[$(TZ='Asia/Shanghai' date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Monitor started"

while true; do
    sleep 60
    
    if command -v python3 &> /dev/null; then
        cd "$SKILL_DIR"
        python3 lib/session_parser.py --auto >> "$LOG_FILE" 2>&1
    fi
done
MONITOR_EOF
    chmod +x "$MONITOR_SCRIPT"
    
    nohup "$MONITOR_SCRIPT" > "$LOG_DIR/monitor.log" 2>&1 &
    echo $! > "$MONITOR_PID_FILE"
    
    sleep 1
    
    if ps -p $(cat "$MONITOR_PID_FILE") > /dev/null 2>&1; then
        print_success "监控服务已启动 (PID: $(cat $MONITOR_PID_FILE))"
        echo "  日志: $LOG_DIR/monitor.log"
        echo "  检查间隔: 60 秒"
    else
        print_error "启动失败，查看日志: $LOG_DIR/monitor.log"
        return 1
    fi
}

# 停止监控服务
stop_monitor() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local PID=$(cat "$MONITOR_PID_FILE")
        kill $PID 2>/dev/null || true
        rm -f "$MONITOR_PID_FILE"
        print_success "监控服务已停止"
    else
        print_info "监控服务未运行"
    fi
}

# 监控服务状态
status_monitor() {
    if [[ -f "$MONITOR_PID_FILE" ]] && ps -p $(cat "$MONITOR_PID_FILE") > /dev/null 2>&1; then
        local PID=$(cat "$MONITOR_PID_FILE")
        print_success "监控服务运行中 (PID: $PID)"
        
        if [[ -f "$STATE_FILE" ]]; then
            local LAST_RUN=$("$JQ_CMD" -r '.last_run // "never"' "$STATE_FILE" 2>/dev/null)
            echo "  最后运行: $LAST_RUN"
        fi
        
        if [[ -f "$LOG_DIR/monitor.log" ]]; then
            local LAST_LOG=$(tail -1 "$LOG_DIR/monitor.log" 2>/dev/null)
            echo "  最近日志: $LAST_LOG"
        fi
    else
        print_info "监控服务未运行"
    fi
}

# 重置状态
reset_state() {
    if [[ -f "$STATE_FILE" ]]; then
        rm -f "$STATE_FILE"
        print_success "状态已重置，下次保存将处理所有对话"
    else
        print_info "无状态文件"
    fi
}

# 查看保存历史
show_saved() {
    local ROOT=$(read_config '.obsidianRoot')
    local NAME=$(read_config '.agent.name')
    local HOST=$(read_config '.agent.host')
    
    if [[ -z "$ROOT" || "$ROOT" == "null" ]]; then
        print_warning "请先配置"
        return 1
    fi
    
    local AGENT_DIR="$ROOT/${NAME}@${HOST}"
    
    if [[ ! -d "$AGENT_DIR" ]]; then
        print_info "暂无保存的对话"
        return 0
    fi
    
    print_step "已保存的对话:"
    echo ""
    
    find "$AGENT_DIR" -type d -mindepth 1 -maxdepth 1 | sort -r | while read DATE_DIR; do
        local DATE_NAME=$(basename "$DATE_DIR")
        echo -e "${CYAN}$DATE_NAME${NC}"
        
        find "$DATE_DIR" -name "*.md" -type f | while read MD_FILE; do
            local FILENAME=$(basename "$MD_FILE" .md)
            local TOPIC=$(echo "$FILENAME" | sed -E 's/^[0-9]+\+//' | sed -E 's/_[a-f0-9]{6,8}$//')
            local SIZE=$(ls -lh "$MD_FILE" | awk '{print $5}')
            echo "  └─ $TOPIC ($SIZE)"
        done
        echo ""
    done
}

# ==================== 项目保存功能 ====================

# 保存项目成果
project_save() {
    local PROJECT_NAME="$1"
    local TOPIC="$2"
    local VERSION="$3"
    local CONTENT="$4"
    
    if [[ -z "$PROJECT_NAME" || -z "$TOPIC" ]]; then
        print_error "用法: $0 project-save <项目名> <主题> [版本号]"
        echo ""
        echo "示例:"
        echo "  $0 project-save 新建代理 问题1-代理配置 v1"
        echo "  echo '内容...' | $0 project-save 新建代理 问题1"
        return 1
    fi
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "请先配置"
        return 1
    fi
    
    # 获取内容
    if [[ -z "$CONTENT" ]]; then
        if [[ ! -t 0 ]]; then
            CONTENT=$(cat)
        else
            print_error "请通过 stdin 或参数提供内容"
            return 1
        fi
    fi
    
    local ROOT=$(read_config '.obsidianRoot')
    local NAME=$(read_config '.agent.name')
    local HOST=$(read_config '.agent.host')
    
    local DATE_SHORT=$(TZ='Asia/Shanghai' date +%y%m%d)
    local AGENT_DIR="$ROOT/${NAME}@${HOST}"
    local PROJECT_DIR="$AGENT_DIR/$DATE_SHORT/项目-$PROJECT_NAME"
    
    mkdir -p "$PROJECT_DIR"
    
    # 确定版本号
    if [[ -z "$VERSION" ]]; then
        local MAX_V=0
        if [[ -d "$PROJECT_DIR" ]]; then
            for f in "$PROJECT_DIR"/*.md; do
                [[ -f "$f" ]] || continue
                local V=$(basename "$f" .md | grep -o 'v[0-9]*$' | sed 's/v//')
                [[ -n "$V" && "$V" -gt "$MAX_V" ]] && MAX_V=$V
            done
        fi
        VERSION="v$((MAX_V + 1))"
    elif [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
    fi
    
    local FILENAME="${TOPIC}-${VERSION}.md"
    local FILEPATH="$PROJECT_DIR/$FILENAME"
    
    local DATE_LONG=$(TZ='Asia/Shanghai' date +%Y-%m-%d)
    local TIME=$(TZ='Asia/Shanghai' date +%H:%M)
    local ISO_TIME=$(TZ='Asia/Shanghai' date +%Y-%m-%dT%H:%M:%S+08:00)
    
    local FRONTMATTER="---
date: $DATE_LONG
time: $TIME
agent: $NAME
host: $HOST
project: $PROJECT_NAME
topic: $TOPIC
version: $VERSION
tags: [\"项目成果\", \"$PROJECT_NAME\"]
created: $ISO_TIME
updated: $ISO_TIME
type: project
---

# $TOPIC ($VERSION)

"
    
    echo "$FRONTMATTER$CONTENT" > "$FILEPATH"
    
    print_success "项目成果已保存"
    echo "  项目: $PROJECT_NAME"
    echo "  主题: $TOPIC"
    echo "  版本: $VERSION"
    echo "  文件: $FILEPATH"
}

# 列出项目
list_projects() {
    local ROOT=$(read_config '.obsidianRoot')
    local NAME=$(read_config '.agent.name')
    local HOST=$(read_config '.agent.host')
    
    if [[ -z "$ROOT" || "$ROOT" == "null" ]]; then
        print_warning "请先配置"
        return 1
    fi
    
    local AGENT_DIR="$ROOT/${NAME}@${HOST}"
    
    if [[ ! -d "$AGENT_DIR" ]]; then
        print_info "暂无项目"
        return 0
    fi
    
    print_step "项目列表:"
    echo ""
    
    local FOUND=0
    for DATE_DIR in "$AGENT_DIR"/*/; do
        [[ -d "$DATE_DIR" ]] || continue
        local DATE_NAME=$(basename "$DATE_DIR")
        
        for PROJECT_DIR in "$DATE_DIR"项目-*/; do
            [[ -d "$PROJECT_DIR" ]] || continue
            local PROJECT_NAME=$(basename "$PROJECT_DIR" | sed 's/^项目-//')
            local FILE_COUNT=$(find "$PROJECT_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
            
            echo -e "${CYAN}$PROJECT_NAME${NC} ($DATE_NAME, $FILE_COUNT 个文件)"
            
            # 列出版本
            for f in "$PROJECT_DIR"*.md; do
                [[ -f "$f" ]] || continue
                local FNAME=$(basename "$f" .md)
                local V=$(echo "$FNAME" | grep -o 'v[0-9]*$')
                local T=$(echo "$FNAME" | sed 's/-v[0-9]*$//')
                echo "  └─ $T ($V)"
            done
            echo ""
            FOUND=1
        done
    done
    
    [[ "$FOUND" -eq 0 ]] && print_info "暂无项目"
}

# 列出项目版本
list_project_versions() {
    local PROJECT_NAME="$1"
    
    if [[ -z "$PROJECT_NAME" ]]; then
        print_error "用法: $0 project-versions <项目名>"
        return 1
    fi
    
    local ROOT=$(read_config '.obsidianRoot')
    local NAME=$(read_config '.agent.name')
    local HOST=$(read_config '.agent.host')
    
    local AGENT_DIR="$ROOT/${NAME}@${HOST}"
    local FOUND=0
    
    for DATE_DIR in "$AGENT_DIR"/*/; do
        [[ -d "$DATE_DIR" ]] || continue
        local PROJECT_DIR="$DATE_DIR项目-$PROJECT_NAME"
        
        if [[ -d "$PROJECT_DIR" ]]; then
            local DATE_NAME=$(basename "$DATE_DIR")
            echo -e "${CYAN}日期: $DATE_NAME${NC}"
            
            for f in "$PROJECT_DIR"*.md; do
                [[ -f "$f" ]] || continue
                local FNAME=$(basename "$f" .md)
                local V=$(echo "$FNAME" | grep -o 'v[0-9]*$')
                local T=$(echo "$FNAME" | sed 's/-v[0-9]*$//')
                local SIZE=$(ls -lh "$f" | awk '{print $5}')
                echo "  └─ $T ($V, $SIZE)"
            done
            echo ""
            FOUND=1
        fi
    done
    
    [[ "$FOUND" -eq 0 ]] && print_info "未找到项目: $PROJECT_NAME"
}

# ==================== 软链接管理功能 ====================

# 展开路径（支持 ~）
expand_path() {
    echo "${1/#\~/$HOME}"
}

# 创建软链接
create_symlink() {
    local LINK_PATH="$1"
    local TARGET_PATH="$2"
    local FORCE="$3"
    
    TARGET_PATH=$(expand_path "$TARGET_PATH")
    
    # 确保目标目录存在
    mkdir -p "$(dirname "$LINK_PATH")"
    
    # 检查链接是否已存在
    if [[ -L "$LINK_PATH" ]]; then
        local CURRENT_TARGET=$(readlink "$LINK_PATH")
        if [[ "$CURRENT_TARGET" == "$TARGET_PATH" ]]; then
            print_info "链接已存在且正确: $LINK_PATH"
            return 0
        elif [[ "$FORCE" == "true" ]]; then
            rm -f "$LINK_PATH"
        else
            print_warning "链接已存在但指向不同: $LINK_PATH"
            print_info "  当前: $CURRENT_TARGET"
            print_info "  期望: $TARGET_PATH"
            return 1
        fi
    elif [[ -e "$LINK_PATH" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            rm -rf "$LINK_PATH"
        else
            print_warning "路径已存在（非链接）: $LINK_PATH"
            return 1
        fi
    fi
    
    # 创建链接
    ln -s "$TARGET_PATH" "$LINK_PATH"
    print_success "创建链接: $LINK_PATH -> $TARGET_PATH"
    return 0
}

# 初始化代理目录结构
init_agents_structure() {
    print_step "初始化代理目录结构..."
    
    local AGENTS_ROOT=$(read_config '.agents.rootDir')
    AGENTS_ROOT=$(expand_path "${AGENTS_ROOT:-~/agents}")
    
    # 创建目录结构
    mkdir -p "$AGENTS_ROOT/shared/projects"
    mkdir -p "$AGENTS_ROOT/shared/SOP"
    mkdir -p "$AGENTS_ROOT/shared/reports"
    mkdir -p "$AGENTS_ROOT/.templates"
    
    print_success "目录已创建: $AGENTS_ROOT/"
    echo "  ├── shared/"
    echo "  │   ├── projects/"
    echo "  │   ├── SOP/"
    echo "  │   └── reports/"
    echo "  └── .templates/"
    
    # 创建模板文件（如果不存在）
    local SOUL_TEMPLATE="$AGENTS_ROOT/.templates/SOUL.md.template"
    local JOB_TEMPLATE="$AGENTS_ROOT/.templates/JOB.md.template"
    
    if [[ ! -f "$SOUL_TEMPLATE" ]]; then
        cat > "$SOUL_TEMPLATE" << 'EOF'
# SOUL.md - 代理人格

- **Name:** {name}
- **Creature:** AI
- **Vibe:** 专业、可靠、主动
- **Emoji:** {emoji}

## Mission

{mission}

## Rules

1. 遵循工作流程
2. 主动报告进展
3. 遇到问题及时反馈
EOF
        print_info "创建模板: SOUL.md.template"
    fi
    
    if [[ ! -f "$JOB_TEMPLATE" ]]; then
        cat > "$JOB_TEMPLATE" << 'EOF'
# JOB.md - 工作职责

## 主要职责

{responsibilities}

## 技能列表

{skills}

## 工作流程

{workflow}

## 报告要求

{reporting}
EOF
        print_info "创建模板: JOB.md.template"
    fi
}

# 创建软链接
setup_links() {
    print_step "创建软链接..."
    
    local ROOT=$(read_config '.obsidianRoot')
    if [[ -z "$ROOT" || "$ROOT" == "null" ]]; then
        print_error "请先配置 obsidianRoot"
        return 1
    fi
    
    local LINKS_ENABLED=$(read_config '.links.enabled')
    if [[ "$LINKS_ENABLED" != "true" ]]; then
        print_info "软链接功能未启用"
        return 0
    fi
    
    # 获取目录名配置
    local DIALOG_DIR=$(read_config '.structure.dialogDir')
    local CONFIG_DIR=$(read_config '.structure.configDir')
    local WORKSPACE_DIR=$(read_config '.structure.workspaceDir')
    
    DIALOG_DIR="${DIALOG_DIR:-claw-对话}"
    CONFIG_DIR="${CONFIG_DIR:-claw-配置}"
    WORKSPACE_DIR="${WORKSPACE_DIR:-claw-工作区}"
    
    local MANAGER_NAME=$(read_config '.links.manager.name')
    local MANAGER_TARGET=$(read_config '.links.manager.target')
    local SHARED_NAME=$(read_config '.links.shared.name')
    local SHARED_TARGET=$(read_config '.links.shared.target')
    
    MANAGER_NAME="${MANAGER_NAME:-管理者}"
    MANAGER_TARGET="${MANAGER_TARGET:-~/.openclaw/workspace}"
    SHARED_NAME="${SHARED_NAME:-shared}"
    SHARED_TARGET="${SHARED_TARGET:-~/agents/shared}"
    
    # 创建 claw-配置/ 目录和链接
    local CONFIG_LINK="$ROOT/$CONFIG_DIR/$MANAGER_NAME"
    print_step "创建配置链接..."
    create_symlink "$CONFIG_LINK" "$MANAGER_TARGET" "true"
    
    # 创建 claw-工作区/ 目录和链接
    local WORKSPACE_LINK="$ROOT/$WORKSPACE_DIR/$SHARED_NAME"
    print_step "创建工作区链接..."
    create_symlink "$WORKSPACE_LINK" "$SHARED_TARGET" "true"
    
    print_success "软链接创建完成"
}

# 查看链接状态
links_status() {
    print_step "软链接状态:"
    echo ""
    
    local ROOT=$(read_config '.obsidianRoot')
    if [[ -z "$ROOT" || "$ROOT" == "null" ]]; then
        print_error "请先配置"
        return 1
    fi
    
    local DIALOG_DIR=$(read_config '.structure.dialogDir')
    local CONFIG_DIR=$(read_config '.structure.configDir')
    local WORKSPACE_DIR=$(read_config '.structure.workspaceDir')
    
    DIALOG_DIR="${DIALOG_DIR:-claw-对话}"
    CONFIG_DIR="${CONFIG_DIR:-claw-配置}"
    WORKSPACE_DIR="${WORKSPACE_DIR:-claw-工作区}"
    
    # 检查 claw-对话
    local DIALOG_PATH="$ROOT/$DIALOG_DIR"
    echo -e "${CYAN}$DIALOG_DIR/${NC}"
    if [[ -d "$DIALOG_PATH" ]]; then
        echo "  状态: 目录存在"
        echo "  文件数: $(find "$DIALOG_PATH" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')"
    else
        echo "  状态: ${YELLOW}不存在${NC}"
    fi
    echo ""
    
    # 检查 claw-配置
    local CONFIG_PATH="$ROOT/$CONFIG_DIR"
    echo -e "${CYAN}$CONFIG_DIR/${NC}"
    if [[ -d "$CONFIG_PATH" ]]; then
        echo "  内容:"
        for link in "$CONFIG_PATH"/*; do
            if [[ -L "$link" ]]; then
                local TARGET=$(readlink "$link")
                local NAME=$(basename "$link")
                echo "    ├── $NAME -> $TARGET"
            fi
        done
    else
        echo "  状态: ${YELLOW}不存在${NC}"
    fi
    echo ""
    
    # 检查 claw-工作区
    local WORKSPACE_PATH="$ROOT/$WORKSPACE_DIR"
    echo -e "${CYAN}$WORKSPACE_DIR/${NC}"
    if [[ -d "$WORKSPACE_PATH" ]]; then
        echo "  内容:"
        for link in "$WORKSPACE_PATH"/*; do
            if [[ -L "$link" ]]; then
                local TARGET=$(readlink "$link")
                local NAME=$(basename "$link")
                echo "    ├── $NAME -> $TARGET"
            fi
        done
    else
        echo "  状态: ${YELLOW}不存在${NC}"
    fi
}

# 添加代理配置链接
link_agent() {
    local AGENT_NAME="$1"
    local AGENT_TARGET="$2"
    
    if [[ -z "$AGENT_NAME" || -z "$AGENT_TARGET" ]]; then
        print_error "用法: $0 link-agent <代理名> <目标路径>"
        echo ""
        echo "示例:"
        echo "  $0 link-agent 人事主管 ~/agents/hr-manager"
        return 1
    fi
    
    local ROOT=$(read_config '.obsidianRoot')
    local CONFIG_DIR=$(read_config '.structure.configDir')
    CONFIG_DIR="${CONFIG_DIR:-claw-配置}"
    
    local CONFIG_LINK="$ROOT/$CONFIG_DIR/$AGENT_NAME"
    
    print_step "添加代理配置链接..."
    create_symlink "$CONFIG_LINK" "$AGENT_TARGET" "false"
}

# 迁移旧目录结构
migrate_structure() {
    print_step "迁移目录结构..."
    
    local ROOT=$(read_config '.obsidianRoot')
    local AGENT_NAME=$(read_config '.agent.name')
    local AGENT_HOST=$(read_config '.agent.host')
    
    if [[ -z "$ROOT" || "$ROOT" == "null" ]]; then
        print_error "请先配置"
        return 1
    fi
    
    local DIALOG_DIR=$(read_config '.structure.dialogDir')
    DIALOG_DIR="${DIALOG_DIR:-claw-对话}"
    
    local OLD_DIR="$ROOT/${AGENT_NAME}@${AGENT_HOST}"
    local NEW_DIR="$ROOT/$DIALOG_DIR/${AGENT_NAME}@${AGENT_HOST}"
    
    # 检查旧目录是否存在
    if [[ ! -d "$OLD_DIR" ]]; then
        print_info "旧目录不存在，无需迁移: $OLD_DIR"
        return 0
    fi
    
    # 检查新目录是否已存在
    if [[ -d "$NEW_DIR" ]]; then
        print_warning "新目录已存在: $NEW_DIR"
        echo -n "是否覆盖？[y/N]: "
        read -r CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
            print_info "已取消"
            return 0
        fi
        rm -rf "$NEW_DIR"
    fi
    
    # 创建新目录的父目录
    mkdir -p "$(dirname "$NEW_DIR")"
    
    # 移动目录
    mv "$OLD_DIR" "$NEW_DIR"
    
    print_success "迁移完成"
    echo "  旧: $OLD_DIR"
    echo "  新: $NEW_DIR"
}

# 完整初始化
full_init() {
    print_header
    print_step "完整初始化..."
    echo ""
    
    # 1. 初始化代理目录
    init_agents_structure
    echo ""
    
    # 2. 创建软链接
    setup_links
    echo ""
    
    # 3. 迁移旧目录（如果需要）
    local ROOT=$(read_config '.obsidianRoot')
    local AGENT_NAME=$(read_config '.agent.name')
    local AGENT_HOST=$(read_config '.agent.host')
    local OLD_DIR="$ROOT/${AGENT_NAME}@${AGENT_HOST}"
    
    if [[ -d "$OLD_DIR" ]]; then
        print_step "检测到旧目录结构"
        echo -n "是否迁移到新结构？[Y/n]: "
        read -r CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Nn] ]]; then
            migrate_structure
        fi
    fi
    
    echo ""
    print_success "初始化完成"
    links_status
}

# ==================== 安装/卸载 ====================

do_install() {
    print_header
    
    # 检查版本更新
    if [[ -d "$SKILL_DIR/.git" ]]; then
        check_update
    fi
    
    # 检查是否已配置
    if [[ -f "$CONFIG_FILE" ]]; then
        print_info "检测到已有配置"
        echo ""
        echo "当前配置："
        local ROOT=$(read_config '.obsidianRoot')
        local NAME=$(read_config '.agent.name')
        local HOST=$(read_config '.agent.host')
        local SAVE_MODE=$(read_config '.saveMode')
        local CFG_VERSION=$(read_config '.version')
        echo "  配置版本: ${CFG_VERSION:-未知}"
        echo "  对话目录: $ROOT/${NAME}@${HOST}"
        echo "  保存机制: $SAVE_MODE"
        echo ""
        echo -n "是否重新配置？[y/N]: "
        read -r RECONFIG
        if [[ ! "$RECONFIG" =~ ^[Yy] ]]; then
            print_info "保留现有配置"
            if [[ -f "$PID_FILE" ]] && ps -p $(cat "$PID_FILE") > /dev/null 2>&1; then
                print_success "服务已运行"
            else
                print_step "启动服务..."
                start_webdav
                local SAVE_MODE=$(read_config '.saveMode')
                [[ "$SAVE_MODE" == "auto" ]] && start_monitor
            fi
            return 0
        fi
    fi
    
    print_step "开始安装..."
    echo ""
    
    check_all_dependencies
    
    do_config || { print_warning "配置取消"; return 1; }
    
    print_step "创建目录..."
    mkdir -p "$CACHE_DIR" "$LOG_DIR"
    local ROOT=$(read_config '.obsidianRoot')
    local NAME=$(read_config '.agent.name')
    local HOST=$(read_config '.agent.host')
    
    local AGENT_DIR="$ROOT/${NAME}@${HOST}"
    if [[ -d "$AGENT_DIR" ]]; then
        print_info "目录已存在: $AGENT_DIR"
    else
        mkdir -p "$AGENT_DIR"
        print_success "目录已创建: $AGENT_DIR"
    fi
    
    local AUTO=$(read_config '.autoStart')
    [[ "$AUTO" == "true" ]] && setup_autostart "true"
    
    print_step "启动服务..."
    start_webdav
    
    local SAVE_MODE=$(read_config '.saveMode')
    [[ "$SAVE_MODE" == "auto" ]] && start_monitor
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}安装完成！技能已激活${NC}                  ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "  版本: $VERSION"
    echo "  配置文件: $CONFIG_FILE"
    echo "  对话目录: $ROOT/${NAME}@${HOST}"
    echo "  保存机制: $SAVE_MODE"
    if [[ "$SAVE_MODE" == "manual" ]]; then
        echo ""
        echo "  使用方法：对话中说 '存入本地目录' 或 '保存对话'"
    else
        echo ""
        echo "  自动保存已开启，所有对话将自动保存"
    fi
    echo ""
    echo "  修改配置: bash scripts/manage.sh config"
    echo "  检查更新: bash scripts/manage.sh update"
    echo ""
}

do_uninstall() {
    print_header
    print_step "开始卸载..."
    echo ""
    
    stop_monitor
    stop_webdav
    setup_autostart "false"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        local ROOT=$(read_config '.obsidianRoot')
        local NAME=$(read_config '.agent.name')
        local HOST=$(read_config '.agent.host')
        local AGENT_DIR="$ROOT/${NAME}@${HOST}"
        
        if [[ -d "$AGENT_DIR" ]]; then
            echo ""
            print_warning "发现对话目录: $AGENT_DIR"
            echo -n "是否删除？[y/N]: "
            read -r DEL
            [[ "$DEL" =~ ^[Yy] ]] && rm -rf "$AGENT_DIR" && print_success "对话目录已删除"
        fi
    fi
    
    echo ""
    echo -n "确认删除技能目录？[y/N]: "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy] ]]; then
        rm -rf "$SKILL_DIR"
        print_success "卸载完成"
    else
        print_info "已取消"
    fi
}

# ==================== 状态检查 ====================

do_status() {
    print_header
    
    echo -e "${BOLD}技能状态${NC}"
    echo "────────────────────────────────────"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        local ROOT=$(read_config '.obsidianRoot')
        local NAME=$(read_config '.agent.name')
        local HOST=$(read_config '.agent.host')
        local SAVE_MODE=$(read_config '.saveMode')
        local CFG_VERSION=$(read_config '.version')
        echo -e "配置文件: ${GREEN}已配置${NC}"
        echo "  版本: ${CFG_VERSION:-未知}"
        echo "  Obsidian: $ROOT"
        echo "  对话目录: $ROOT/${NAME}@${HOST}"
        echo "  代理: ${NAME}@${HOST}"
        echo "  保存机制: $SAVE_MODE"
        echo "  模式: $(read_config '.mode')"
    else
        echo -e "配置文件: ${YELLOW}未配置${NC}"
    fi
    
    echo ""
    echo -e "WebDAV 服务:"
    status_webdav
    
    echo ""
    echo -e "自动保存监控:"
    status_monitor
    
    echo ""
    echo -e "依赖:"
    check_dependency rclone && echo -e "  rclone: ${GREEN}已安装${NC}" || echo -e "  rclone: ${YELLOW}未安装${NC}"
    check_dependency jq && echo -e "  jq: ${GREEN}已安装${NC}" || echo -e "  jq: ${YELLOW}未安装${NC}"
    check_dependency curl && echo -e "  curl: ${GREEN}已安装${NC}" || echo -e "  curl: ${YELLOW}未安装${NC}"
    check_dependency python3 && echo -e "  python3: ${GREEN}已安装${NC}" || echo -e "  python3: ${RED}未安装${NC}"
}

# ==================== 更新日志 ====================

show_changelog() {
    print_header
    echo -e "${BOLD}版本更新日志${NC}"
    echo "────────────────────────────────────"
    echo "$CHANGELOG"
}

# ==================== 主菜单 ====================

show_menu() {
    print_header
    
    echo -e "${BOLD}请选择操作：${NC}"
    echo ""
    echo "  1) 安装/重新安装    - 安装依赖、配置、激活"
    echo "  2) 修改配置        - 更改设置"
    echo "  3) 启动服务        - 启动 WebDAV + 自动监控"
    echo "  4) 停止服务        - 停止所有服务"
    echo "  5) 查看状态        - 查看配置和服务状态"
    echo "  6) 立即保存        - 保存当前对话"
    echo "  7) 查看已保存      - 查看已保存的对话列表"
    echo "  8) 检查更新        - 检查并更新到最新版本"
    echo "  9) 更新日志        - 查看版本更新记录"
    echo "  0) 卸载            - 移除技能和数据"
    echo "  q) 退出"
    echo ""
    echo -n "请输入选项: "
}

main_menu() {
    while true; do
        show_menu
        read -r CHOICE
        
        case "$CHOICE" in
            1) do_install ;;
            2) do_config && { stop_webdav; start_webdav; } ;;
            3) start_webdav; start_monitor ;;
            4) stop_webdav; stop_monitor ;;
            5) do_status ;;
            6) save_now ;;
            7) show_saved ;;
            8) check_update ;;
            9) show_changelog ;;
            0) do_uninstall; return ;;
            q|Q) echo ""; print_info "再见"; exit 0 ;;
            *) print_warning "无效选项" ;;
        esac
        
        echo ""
        echo -n "按回车继续..."
        read -r
    done
}

# ==================== 命令行入口 ====================

case "${1:-}" in
    install)        do_install ;;
    uninstall)      do_uninstall ;;
    config)         do_config && { stop_webdav; start_webdav; } ;;
    status)         do_status ;;
    start)          start_webdav; start_monitor ;;
    stop)           stop_webdav; stop_monitor ;;
    update)         check_update ;;
    changelog)      show_changelog ;;
    
    save-now)       save_now ;;
    save)           save_now ;;
    start-monitor)  start_monitor ;;
    stop-monitor)   stop_monitor ;;
    status-monitor) status_monitor ;;
    reset-state)    reset_state ;;
    saved)          show_saved ;;
    
    # 项目相关命令
    project-save)   shift; project_save "$@" ;;
    project-list)   list_projects ;;
    projects)       list_projects ;;
    project-versions) shift; list_project_versions "$@" ;;
    
    # 软链接相关命令
    links)          setup_links ;;
    links-status)   links_status ;;
    link-agent)     shift; link_agent "$@" ;;
    init-agents)    init_agents_structure ;;
    migrate)        migrate_structure ;;
    init)           full_init ;;
    
    _start_service) 
        start_webdav
        local SAVE_MODE=$(read_config '.saveMode')
        [[ "$SAVE_MODE" == "auto" ]] && start_monitor
        ;;
    "")
        main_menu
        ;;
    *)
        echo "用法: $0 [命令]"
        echo ""
        echo "命令:"
        echo "  (无参数)          进入交互菜单"
        echo "  install          安装/重新安装"
        echo "  config           修改配置"
        echo "  start            启动服务"
        echo "  stop             停止服务"
        echo "  status           查看状态"
        echo "  save-now         立即保存对话"
        echo "  saved            查看已保存的对话"
        echo ""
        echo "项目命令:"
        echo "  project-save <项目名> <主题> [版本]"
        echo "                    保存项目成果"
        echo "  project-list     列出所有项目"
        echo "  project-versions <项目名>"
        echo "                    列出项目的所有版本"
        echo ""
        echo "链接与初始化:"
        echo "  init             完整初始化（推荐首次使用）"
        echo "  links            创建/更新软链接"
        echo "  links-status     查看链接状态"
        echo "  link-agent <名> <路径>"
        echo "                    添加代理配置链接"
        echo "  init-agents      初始化代理目录结构"
        echo "  migrate          迁移旧目录结构"
        echo ""
        echo "其他:"
        echo "  update           检查更新"
        echo "  uninstall        卸载"
        ;;
esac