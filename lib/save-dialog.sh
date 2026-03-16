#!/bin/bash

# dialog-save 对话保存核心逻辑

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/utils.sh"

CONFIG_FILE="$SKILL_DIR/config.json"

# 保存对话
save_dialog() {
    local TOPIC="$1"
    local CONTENT="$2"
    local PROJECT="$3"
    local TAGS="$4"
    
    local OBSIDIAN_ROOT=$(get_config '.obsidianRoot' "$CONFIG_FILE")
    local AGENT_NAME=$(get_config '.agent.name' "$CONFIG_FILE")
    local AGENT_HOST=$(get_config '.agent.host' "$CONFIG_FILE")
    
    local DATE_SHORT=$(format_date_short)
    local DATE_LONG=$(format_date_long)
    local TIME=$(format_time)
    local TIMESTAMP=$(format_timestamp)
    local ISO_TIME=$(format_iso_time)
    
    local TOPIC_CLEAN=$(sanitize_filename "$TOPIC")
    
    # 使用 @ 符号
    local AGENT_DIR="$OBSIDIAN_ROOT/${AGENT_NAME}@${AGENT_HOST}"
    local DATE_DIR="$AGENT_DIR/$DATE_SHORT"
    
    if [[ -n "$PROJECT" ]]; then
        DATE_DIR="$DATE_DIR/$(sanitize_filename "$PROJECT")"
    fi
    
    mkdir -p "$DATE_DIR"
    
    local FILENAME="${TIMESTAMP}+${TOPIC_CLEAN}.md"
    local FILEPATH="$DATE_DIR/$FILENAME"
    
    if [[ -z "$TAGS" ]]; then
        TAGS="对话"
    fi
    local TAGS_JSON=$(echo "$TAGS" | tr ',' '\n' | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//')
    
    local FRONTMATTER="---
date: $DATE_LONG
time: $TIME
agent: $AGENT_NAME
host: $AGENT_HOST
topic: $TOPIC
project: ${PROJECT:-null}
tags: [$TAGS_JSON]
created: $ISO_TIME
updated: $ISO_TIME
---"
    
    {
        echo "$FRONTMATTER"
        echo ""
        echo "# $TOPIC"
        echo ""
        echo "$CONTENT"
    } > "$FILEPATH"
    
    echo "$FILEPATH"
}

if [[ $# -ge 2 ]]; then
    save_dialog "$1" "$2" "${3:-}" "${4:-}"
fi