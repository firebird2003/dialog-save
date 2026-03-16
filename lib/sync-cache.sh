#!/bin/bash

# dialog-save 离线缓存同步脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/utils.sh"

CONFIG_FILE="$SKILL_DIR/config.json"
CACHE_DIR="$SKILL_DIR/.cache/pending"

sync_cache() {
    local MODE=$(get_config '.mode' "$CONFIG_FILE")
    local WEBDAV_PORT=$(get_config '.webdav.port' "$CONFIG_FILE")
    local REMOTE_URL=$(get_config '.remoteWebdavUrl' "$CONFIG_FILE")
    
    local TARGET_URL
    if [[ "$MODE" == "remote" ]]; then
        TARGET_URL="$REMOTE_URL"
    else
        TARGET_URL="http://localhost:$WEBDAV_PORT"
    fi
    
    if [[ ! -d "$CACHE_DIR" ]]; then
        echo "缓存目录不存在"
        return 0
    fi
    
    if ! check_webdav_connection "$TARGET_URL"; then
        echo "无法连接到 WebDAV 服务: $TARGET_URL"
        return 1
    fi
    
    local SYNCED=0
    local FAILED=0
    
    find "$CACHE_DIR" -name "*.md" | while read FILE; do
        local REL_PATH="${FILE#$CACHE_DIR/}"
        
        if curl -s -X PUT -T "$FILE" "$TARGET_URL/$REL_PATH"; then
            rm -f "$FILE"
            ((SYNCED++))
            echo "已同步: $REL_PATH"
        else
            ((FAILED++))
            echo "同步失败: $REL_PATH"
        fi
    done
    
    echo "同步完成: 成功 $SYNCED, 失败 $FAILED"
}

sync_cache