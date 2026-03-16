#!/bin/bash

# dialog-save 通用工具函数

# 获取上海时间
get_shanghai_time() {
    TZ='Asia/Shanghai' date "$@"
}

# 格式化日期 YYMMDD
format_date_short() {
    get_shanghai_time +%y%m%d
}

# 格式化日期 YYYY-MM-DD
format_date_long() {
    get_shanghai_time +%Y-%m-%d
}

# 格式化时间 HH:MM
format_time() {
    get_shanghai_time +%H:%M
}

# 格式化时间戳 YYMMDDHHMM
format_timestamp() {
    get_shanghai_time +%y%m%d%H%M
}

# 格式化 ISO 时间
format_iso_time() {
    get_shanghai_time +%Y-%m-%dT%H:%M:%S+08:00
}

# 清理文件名（移除特殊字符）
sanitize_filename() {
    echo "$1" | sed 's/[\/\\:*?"<>|]//g' | sed 's/  */ /g' | tr -d '\n'
}

# 检查 WebDAV 连接
check_webdav_connection() {
    local URL="$1"
    if curl -s --connect-timeout 5 -I "$URL" | grep -q "200\|207"; then
        return 0
    else
        return 1
    fi
}

# 读取配置
get_config() {
    local KEY="$1"
    local CONFIG_FILE="$2"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        jq -r "$KEY" "$CONFIG_FILE" 2>/dev/null
    else
        echo ""
    fi
}