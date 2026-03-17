#!/bin/bash

# ============================================================
# dialog-save 一键安装脚本
# 
# 使用方法：
# bash <(curl -sL https://raw.githubusercontent.com/firebird2003/dialog-save/main/install.sh)
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.openclaw/workspace/skills/dialog-save"
GITHUB_REPO="https://github.com/firebird2003/dialog-save.git"

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}dialog-save 安装程序${NC}                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  OpenClaw 对话保存技能                  ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# 检查 git
if ! command -v git &> /dev/null; then
    print_error "git 未安装，请先安装 git"
    exit 1
fi

# 检查目录是否存在
if [[ -d "$INSTALL_DIR" ]]; then
    print_warning "目录已存在: $INSTALL_DIR"
    echo ""
    
    # 检查是否是 git 仓库
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        echo "请选择操作："
        echo "  1) 更新到最新版本（保留配置）"
        echo "  2) 重新安装（重置配置）"
        echo "  3) 取消"
        echo ""
        echo -n "请选择 [1/2/3]: "
        read -r CHOICE
        
        case "$CHOICE" in
            1)
                print_step "更新到最新版本..."
                cd "$INSTALL_DIR"
                git fetch origin
                git pull origin main || {
                    print_warning "自动更新失败，尝试强制更新..."
                    git reset --hard origin/main
                }
                print_success "更新完成！"
                ;;
            2)
                print_step "重新安装..."
                read -p "是否保留已保存的对话数据？[Y/n]: " KEEP_DATA
                if [[ "$KEEP_DATA" =~ ^[Nn] ]]; then
                    rm -rf "$INSTALL_DIR"
                else
                    # 保留对话数据目录，只删除技能文件
                    if [[ -f "$INSTALL_DIR/config.json" ]]; then
                        CONFIG_BAK=$(cat "$INSTALL_DIR/config.json")
                    fi
                    rm -rf "$INSTALL_DIR"
                fi
                
                print_step "克隆仓库..."
                git clone "$GITHUB_REPO" "$INSTALL_DIR"
                
                # 恢复配置
                if [[ -n "$CONFIG_BAK" ]]; then
                    echo "$CONFIG_BAK" > "$INSTALL_DIR/config.json"
                    print_info "已恢复之前的配置"
                fi
                print_success "重新安装完成！"
                ;;
            3)
                print_info "已取消"
                exit 0
                ;;
            *)
                print_warning "无效选择，执行更新..."
                cd "$INSTALL_DIR"
                git pull origin main || true
                ;;
        esac
    else
        echo "请选择操作："
        echo "  1) 覆盖安装"
        echo "  2) 取消"
        echo ""
        echo -n "请选择 [1/2]: "
        read -r CHOICE
        
        case "$CHOICE" in
            1)
                print_step "删除旧目录..."
                rm -rf "$INSTALL_DIR"
                print_step "克隆仓库..."
                git clone "$GITHUB_REPO" "$INSTALL_DIR"
                print_success "安装完成！"
                ;;
            2)
                print_info "已取消"
                exit 0
                ;;
            *)
                print_warning "无效选择，已取消"
                exit 1
                ;;
        esac
    fi
else
    # 目录不存在，直接克隆
    print_step "克隆仓库..."
    
    # 确保父目录存在
    mkdir -p "$(dirname "$INSTALL_DIR")"
    
    git clone "$GITHUB_REPO" "$INSTALL_DIR"
    print_success "克隆完成！"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  安装成功！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "目录: $INSTALL_DIR"
echo ""

# 询问是否立即配置
echo -n "是否立即进入配置菜单？[Y/n]: "
read -r RUN_NOW

if [[ ! "$RUN_NOW" =~ ^[Nn] ]]; then
    cd "$INSTALL_DIR"
    exec bash scripts/manage.sh
else
    echo ""
    echo "稍后运行以下命令进入菜单："
    echo ""
    echo -e "  ${CYAN}bash $INSTALL_DIR/scripts/manage.sh${NC}"
    echo ""
fi