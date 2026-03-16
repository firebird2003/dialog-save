#!/bin/bash

# dialog-save 话题检测辅助脚本

SWITCH_SIGNALS=(
    "换话题"
    "换个话题"
    "另外"
    "对了"
    "说到这个"
    "顺带一提"
    "顺便说下"
    "扯远了"
    "言归正传"
)

END_SIGNALS=(
    "就这样"
    "先这样"
    "好的没问题"
    "知道了"
)

detect_topic_switch() {
    local TEXT="$1"
    
    for SIGNAL in "${SWITCH_SIGNALS[@]}"; do
        if [[ "$TEXT" == *"$SIGNAL"* ]]; then
            echo "switch"
            return 0
        fi
    done
    
    echo "continue"
}

detect_end_signal() {
    local TEXT="$1"
    
    for SIGNAL in "${END_SIGNALS[@]}"; do
        if [[ "$TEXT" == *"$SIGNAL"* ]]; then
            echo "end"
            return 0
        fi
    done
    
    echo "continue"
}

if [[ $# -ge 1 ]]; then
    case "$1" in
        detect)
            detect_topic_switch "$2"
            ;;
        end)
            detect_end_signal "$2"
            ;;
    esac
fi