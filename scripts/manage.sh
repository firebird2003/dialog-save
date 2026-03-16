#!/bin/bash

# ============================================================
# dialog-save 统一管理脚本
# 作者：yeji
# ============================================================

# ==================== 版本信息 ====================
VERSION="1.3.2"
RELEASE_DATE="2026-03-16"

CHANGELOG="
v1.3.2 (2026-03-16)
  - 新版本覆盖安装：目录已存在时自动 git pull 更新
  - 版本检测：显示当前版本和远程最新版本

v1.3.1 (2026-03-16)
  - 优化安装体验：检测已存在配置

v1.3.0 (2026-03-16)
  - 目录名格式改为 代理名@主机名（兼容iCloud同步）
  - 新增保存机制选项：自动/手动

v1.2.0 (2026-03-16)
  - 移除中间子目录
  - 修复 PATH 环境变量问题

v1.0.0 (2026-03-16)
  - 初始版本
"

# ==================== 路径配置 ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SKILL_DIR/config.json"
LOG_DIR="$SKILL_DIR/logs"
PID_FILE="$SKILL_DIR/.webdav.pid"
CACHE_DIR="$SKILL_DIR/.cache/pending"

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
read_config() {
    local KEY="$1"
    if [[ -z "$JQ_CMD" ]]; then
        case "$KEY" in
            '.obsidianRoot') grep -o '"obsidianRoot"[^,]*' "$CONFIG_FILE" | cut -d'"' -f4 ;;
            '.agent.name') grep -o '"name"[^,]*' "$CONFIG_FILE" | head -1 | cut -d'"' -f4 ;;
            '.agent.host') grep -o '"host"[^,]*' "$CONFIG_FILE" | head -1 | cut -d'"' -f4 ;;
            '.webdav.port') grep -o '"port"[^,}]*' "$CONFIG_FILE" | head -1 | grep -o '[0-9]*' ;;
            '.mode') grep -o '"mode"[^,]*' "$CONFIG_FILE" | cut -d'"' -f4 ;;
            '.autoStart') grep -o '"autoStart"[^,}]*' "$CONFIG_FILE" | grep -o 'true\|false' ;;
            '.saveMode') grep -o '"saveMode"[^,}]*' "$CONFIG_FILE" | cut -d'"' -f4 ;;
            '.version') grep -o '"version"[^,}]*' "$CONFIG_FILE" | head -1 | cut -d'"' -f4 ;;
            *) echo "" ;;
        esac
    else
        "$JQ_CMD" -r "$KEY" "$CONFIG_FILE" 2>/dev/null
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

# ==================== 版本检查 ====================
check_update() {
    print_step "检查版本更新..."
    
    cd "$SKILL_DIR"
    
    # 获取远程最新版本
    local REMOTE_VERSION=$(git fetch origin 2>/dev/null && git show origin/main:config.json 2>/dev/null | grep -o '"version"[^,}]*' | head -1 | cut -d'"' -f4)
    
    if [[ -n "$REMOTE_VERSION" ]]; then
        echo "  当前版本: $VERSION"
        echo "  最新版本: $REMOTE_VERSION"
        
        if [[ "$REMOTE_VERSION" != "$VERSION" ]]; then
            echo ""
            echo -n "发现新版本，是否更新？[Y/n]: "
            read -r UPDATE_CHOICE
            
            if [[ ! "$UPDATE_CHOICE" =~ ^[Nn] ]]; then
                print_step "更新到最新版本..."
                if git pull origin main 2>/dev/null; then
                    print_success "更新成功，请重新运行脚本"
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

# ==================== 依赖检查与安装 ====================

check_dependency() {
    local DEP="$1"
    case "$DEP" in
        rclone) command -v rclone &> /dev/null ;;
        jq)     [[ -n "$JQ_CMD" ]] ;;
        curl)   command -v curl &> /dev/null ;;
        *)      command -v "$DEP" &> /dev/null ;;
    esac
}

install_rclone() {
    print_info "安装 rclone..."
    
    local OS=$(detect_os)
    local ARCH=$(uname -m)
    
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
    
    case $ARCH in
        x86_64)  ARCH="amd64" ;;
        arm64)   ARCH="arm64" ;;
        armv7l)  ARCH="arm" ;;
    esac
    
    local OS_NAME=$(echo "$OS" | sed 's/macos/darwin/')
    local LATEST_URL=$(curl -s https://api.github.com/repos/rclone/rclone/releases/latest 2>/dev/null | \
        grep "browser_download_url" | grep "${OS_NAME}-${ARCH}" | head -1 | cut -d'"' -f4)
    
    if [[ -n "$LATEST_URL" ]]; then
        local TMP_DIR=$(mktemp -d)
        curl -L "$LATEST_URL" -o "$TMP_DIR/rclone.zip" 2>/dev/null
        unzip -q "$TMP_DIR/rclone.zip" -d "$TMP_DIR"
        sudo mv "$TMP_DIR"/rclone-*/rclone /usr/local/bin/ 2>/dev/null
        sudo chmod +x /usr/local/bin/rclone 2>/dev/null
        rm -rf "$TMP_DIR"
        print_success "rclone 安装成功"
        return 0
    fi
    
    print_error "rclone 安装失败，请手动安装: https://rclone.org/install/"
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
    
    print_error "jq 安装失败，请手动安装"
    return 1
}

ensure_dependencies() {
    print_step "检查依赖..."
    local NEED_INSTALL=0
    
    if check_dependency jq; then
        print_success "jq 已安装"
    else
        print_warning "jq 未安装"
        install_jq || ((NEED_INSTALL++))
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
        print_warning "rclone 未安装"
        install_rclone || ((NEED_INSTALL++))
    fi
    
    if check_dependency curl; then
        print_success "curl 已安装"
    else
        print_error "curl 未安装（通常系统自带）"
        ((NEED_INSTALL++))
    fi
    
    return $NEED_INSTALL
}

# ==================== 配置管理 ====================

do_config() {
    print_step "配置向导..."
    echo ""
    
    local CURRENT_ROOT="" CURRENT_PORT=8080
    local CURRENT_NAME="Assistant" CURRENT_HOST="" CURRENT_MODE="local"
    local CURRENT_SAVEMODE="manual"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        CURRENT_ROOT=$(read_config '.obsidianRoot')
        CURRENT_PORT=$(read_config '.webdav.port')
        CURRENT_NAME=$(read_config '.agent.name')
        CURRENT_HOST=$(read_config '.agent.host')
        CURRENT_MODE=$(read_config '.mode')
        CURRENT_SAVEMODE=$(read_config '.saveMode')
    fi
    
    # Obsidian 路径
    echo -e "${YELLOW}1. Obsidian 笔记库路径${NC}"
    [[ -n "$CURRENT_ROOT" && "$CURRENT_ROOT" != "null" ]] && echo -e "   当前: $CURRENT_ROOT"
    echo -n "   请输入路径: "
    read -r OBSIDIAN_ROOT
    OBSIDIAN_ROOT=${OBSIDIAN_ROOT:-$CURRENT_ROOT}
    
    if [[ -z "$OBSIDIAN_ROOT" || "$OBSIDIAN_ROOT" == "null" ]]; then
        print_error "路径不能为空"
        return 1
    fi
    
    # WebDAV 端口
    echo ""
    echo -e "${YELLOW}2. WebDAV 服务端口${NC}"
    echo -e "   当前: $CURRENT_PORT"
    echo -n "   请输入 [回车保留当前]: "
    read -r WEBDAV_PORT
    WEBDAV_PORT=${WEBDAV_PORT:-$CURRENT_PORT}
    
    # 代理名
    echo ""
    echo -e "${YELLOW}3. 代理名称${NC}"
    echo -e "   当前: $CURRENT_NAME"
    echo -n "   请输入 [回车保留当前]: "
    read -r AGENT_NAME
    AGENT_NAME=${AGENT_NAME:-$CURRENT_NAME}
    
    # 主机名
    local DEFAULT_HOST=$(hostname | sed 's/.local$//')
    [[ -n "$CURRENT_HOST" && "$CURRENT_HOST" != "null" ]] && DEFAULT_HOST="$CURRENT_HOST"
    echo ""
    echo -e "${YELLOW}4. 主机名称${NC}"
    echo -e "   当前: $DEFAULT_HOST"
    echo -n "   请输入 [回车保留当前]: "
    read -r AGENT_HOST
    AGENT_HOST=${AGENT_HOST:-$DEFAULT_HOST}
    
    # 保存机制
    echo ""
    echo -e "${YELLOW}5. 保存机制${NC}"
    echo "   1) 手动 - 需要用户说'存入本地目录'才保存"
    echo "   2) 自动 - 自动保存所有对话（无需用户提示）"
    echo -e "   当前: $CURRENT_SAVEMODE"
    echo -n "   请选择 [1/2, 回车保留当前]: "
    read -r SAVEMODE_CHOICE
    
    case "$SAVEMODE_CHOICE" in
        1) SAVE_MODE="manual" ;;
        2) SAVE_MODE="auto" ;;
        *)  SAVE_MODE=${CURRENT_SAVEMODE:-"manual"} ;;
    esac
    
    # 运行模式
    echo ""
    echo -e "${YELLOW}6. 运行模式${NC}"
    echo "   1) 本地模式 (本机运行 WebDAV 服务)"
    echo "   2) 远程模式 (连接其他主机的 WebDAV)"
    echo -e "   当前: $CURRENT_MODE"
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
    
    # 开机自启
    local AUTO_START="false"
    if [[ "$MODE" == "local" ]]; then
        echo ""
        echo -e "${YELLOW}7. 开机自动启动 WebDAV 服务？${NC}"
        echo -n "   [Y/n]: "
        read -r AUTO_CHOICE
        [[ ! "$AUTO_CHOICE" =~ ^[Nn] ]] && AUTO_START="true"
    fi
    
    # 确认
    echo ""
    echo -e "${BOLD}========== 配置确认 ==========${NC}"
    echo "  Obsidian 路径: $OBSIDIAN_ROOT"
    echo "  对话目录: $OBSIDIAN_ROOT/${AGENT_NAME}@${AGENT_HOST}"
    echo "  WebDAV 端口: $WEBDAV_PORT"
    echo "  代理名称: $AGENT_NAME"
    echo "  主机名称: $AGENT_HOST"
    echo "  保存机制: $SAVE_MODE"
    [[ "$SAVE_MODE" == "manual" ]] && echo "    （需要用户说'存入本地目录'才保存）"
    [[ "$SAVE_MODE" == "auto" ]] && echo "    （自动保存所有对话）"
    echo "  运行模式: $MODE"
    [[ "$MODE" == "remote" ]] && echo "  远程地址: $REMOTE_URL"
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
  "autoStart": $AUTO_START
}
EOF
    
    print_success "配置已保存"
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
        print_error "请先配置"
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

# ==================== 安装/卸载 ====================

do_install() {
    print_header
    
    # 检查版本更新
    check_update
    
    # 检查是否已安装
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
            fi
            return 0
        fi
    fi
    
    print_step "开始安装..."
    echo ""
    
    ensure_dependencies || print_warning "部分依赖安装失败，继续..."
    
    do_config || { print_error "配置失败"; return 1; }
    
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
    echo -e "依赖:"
    check_dependency rclone && echo -e "  rclone: ${GREEN}已安装${NC}" || echo -e "  rclone: ${RED}未安装${NC}"
    check_dependency jq && echo -e "  jq: ${GREEN}已安装${NC}" || echo -e "  jq: ${RED}未安装${NC}"
    check_dependency curl && echo -e "  curl: ${GREEN}已安装${NC}" || echo -e "  curl: ${RED}未安装${NC}"
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
    echo "  3) 启动服务        - 启动 WebDAV 服务"
    echo "  4) 停止服务        - 停止 WebDAV 服务"
    echo "  5) 查看状态        - 查看配置和服务状态"
    echo "  6) 检查更新        - 检查并更新到最新版本"
    echo "  7) 更新日志        - 查看版本更新记录"
    echo "  8) 卸载            - 移除技能和数据"
    echo "  0) 退出"
    echo ""
    echo -n "请输入选项 [0-8]: "
}

main_menu() {
    while true; do
        show_menu
        read -r CHOICE
        
        case "$CHOICE" in
            1) do_install ;;
            2) do_config && { stop_webdav; start_webdav; } ;;
            3) start_webdav ;;
            4) stop_webdav ;;
            5) do_status ;;
            6) check_update ;;
            7) show_changelog ;;
            8) do_uninstall; return ;;
            0) echo ""; print_info "再见"; exit 0 ;;
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
    config)         do_config ;;
    status)         do_status ;;
    start)          start_webdav ;;
    stop)           stop_webdav ;;
    update)         check_update ;;
    changelog)      show_changelog ;;
    _start_service) 
        start_webdav
        ;;
    "")
        main_menu
        ;;
    *)
        echo "用法: $0 [install|uninstall|config|status|start|stop|update|changelog]"
        echo ""
        echo "无参数运行进入交互菜单"
        ;;
esac