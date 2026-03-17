#!/usr/bin/env python3
"""
OpenClaw Session Parser
解析 OpenClaw session JSONL 文件，提取对话内容并生成 Markdown
"""

import json
import os
import re
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Optional
import hashlib

# 上海时区
SHANGHAI_TZ = timezone(timedelta(hours=8))

# 默认配置路径
DEFAULT_CONFIG_PATH = Path(__file__).parent.parent / "config.json"
DEFAULT_SESSIONS_PATH = Path.home() / ".openclaw" / "agents" / "main" / "sessions"
DEFAULT_STATE_FILE = Path(__file__).parent.parent / ".cache" / "save_state.json"


def get_shanghai_time() -> datetime:
    """获取上海时间"""
    return datetime.now(SHANGHAI_TZ)


def format_date_short(dt: datetime = None) -> str:
    """格式化日期 YYMMDD"""
    if dt is None:
        dt = get_shanghai_time()
    return dt.strftime("%y%m%d")


def format_date_long(dt: datetime = None) -> str:
    """格式化日期 YYYY-MM-DD"""
    if dt is None:
        dt = get_shanghai_time()
    return dt.strftime("%Y-%m-%d")


def format_time(dt: datetime = None) -> str:
    """格式化时间 HH:MM"""
    if dt is None:
        dt = get_shanghai_time()
    return dt.strftime("%H:%M")


def format_timestamp(dt: datetime = None) -> str:
    """格式化时间戳 YYMMDDHHMM"""
    if dt is None:
        dt = get_shanghai_time()
    return dt.strftime("%y%m%d%H%M")


def format_iso_time(dt: datetime = None) -> str:
    """格式化 ISO 时间"""
    if dt is None:
        dt = get_shanghai_time()
    return dt.strftime("%Y-%m-%dT%H:%M:%S+08:00")


def sanitize_filename(text: str, max_len: int = 50) -> str:
    """清理文件名，移除特殊字符"""
    # 移除不允许的字符
    text = re.sub(r'[\/\\:*?"<>|\n\r\t]', '', text)
    # 合并多个空格
    text = re.sub(r'\s+', ' ', text)
    # 截断长度
    if len(text) > max_len:
        text = text[:max_len]
    return text.strip()


def load_config(config_path: Path = DEFAULT_CONFIG_PATH) -> dict:
    """加载配置文件"""
    if config_path.exists():
        with open(config_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}


def load_state(state_file: Path = DEFAULT_STATE_FILE) -> dict:
    """加载保存状态"""
    if state_file.exists():
        with open(state_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}


def save_state(state: dict, state_file: Path = DEFAULT_STATE_FILE):
    """保存状态"""
    state_file.parent.mkdir(parents=True, exist_ok=True)
    with open(state_file, 'w', encoding='utf-8') as f:
        json.dump(state, f, ensure_ascii=False, indent=2)


def parse_timestamp(ts) -> Optional[datetime]:
    """解析时间戳（支持毫秒时间戳和 ISO 格式）"""
    if ts is None:
        return None
    
    try:
        if isinstance(ts, (int, float)):
            # 毫秒时间戳
            if ts > 1e12:
                ts = ts / 1000
            return datetime.fromtimestamp(ts, tz=SHANGHAI_TZ)
        elif isinstance(ts, str):
            # ISO 格式
            if ts.endswith('Z'):
                ts = ts[:-1] + '+00:00'
            dt = datetime.fromisoformat(ts)
            return dt.astimezone(SHANGHAI_TZ)
    except Exception:
        pass
    return None


def extract_text_content(content) -> str:
    """从 content 数组中提取文本"""
    if isinstance(content, str):
        return content
    
    if isinstance(content, list):
        texts = []
        for block in content:
            if isinstance(block, dict):
                block_type = block.get('type', '')
                if block_type == 'text':
                    texts.append(block.get('text', ''))
                elif block_type == 'thinking':
                    # 跳过 thinking 块
                    pass
                elif block_type == 'toolCall':
                    # 工具调用，简化显示
                    tool_name = block.get('name', 'unknown')
                    texts.append(f"[调用工具: {tool_name}]")
            elif isinstance(block, str):
                texts.append(block)
        return '\n'.join(texts)
    
    return ''


def extract_tool_result_content(content) -> str:
    """提取工具结果内容"""
    if isinstance(content, str):
        return content
    
    if isinstance(content, list):
        texts = []
        for block in content:
            if isinstance(block, dict):
                if block.get('type') == 'text':
                    text = block.get('text', '')
                    # 截断过长的结果
                    if len(text) > 500:
                        text = text[:500] + '...'
                    texts.append(text)
            elif isinstance(block, str):
                if len(block) > 500:
                    texts.append(block[:500] + '...')
                else:
                    texts.append(block)
        return '\n'.join(texts)
    
    return ''


def parse_session_file(session_file: Path, last_entry_id: str = None) -> list:
    """
    解析 session JSONL 文件
    
    返回: [(entry_id, role, content, timestamp, is_tool_result), ...]
    """
    entries = []
    found_last = last_entry_id is None
    
    if not session_file.exists():
        return entries
    
    with open(session_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            
            entry_type = entry.get('type', '')
            entry_id = entry.get('id', '')
            
            # 跳过已处理的条目
            if not found_last:
                if entry_id == last_entry_id:
                    found_last = True
                continue
            
            if entry_type == 'message':
                message = entry.get('message', {})
                role = message.get('role', '')
                content = message.get('content', [])
                ts = parse_timestamp(entry.get('timestamp') or message.get('timestamp'))
                
                if role == 'user':
                    text = extract_text_content(content)
                    if text:
                        entries.append((entry_id, 'user', text, ts, False))
                
                elif role == 'assistant':
                    text = extract_text_content(content)
                    if text:
                        entries.append((entry_id, 'assistant', text, ts, False))
                
                elif role == 'toolResult':
                    tool_name = message.get('toolName', 'unknown')
                    result_text = extract_tool_result_content(content)
                    is_error = message.get('isError', False)
                    entries.append((entry_id, 'tool_result', 
                                  f"[{tool_name}{' ❌' if is_error else ''}]\n{result_text}", 
                                  ts, True))
    
    return entries


def detect_topic(messages: list, max_len: int = 20) -> str:
    """从消息中检测话题"""
    # 取第一条用户消息的前面部分作为话题
    for entry_id, role, content, ts, is_tool in messages:
        if role == 'user' and not is_tool:
            # 清理各种 metadata 和标记
            clean_content = content
            
            # 移除 Conversation info (untrusted metadata) 块（包含整个 markdown 代码块）
            # 格式: Conversation info...\n```json\n...\n```
            clean_content = re.sub(
                r'Conversation info \(untrusted metadata\):\s*```json\s*.*?```\s*', 
                '', clean_content, flags=re.DOTALL
            )
            
            # 移除 Sender (untrusted metadata) 块
            clean_content = re.sub(
                r'Sender \(untrusted metadata\):\s*```json\s*.*?```\s*', 
                '', clean_content, flags=re.DOTALL
            )
            
            # 移除单独的 json 代码块
            clean_content = re.sub(r'```json\s*.*?```\s*', '', clean_content, flags=re.DOTALL)
            clean_content = re.sub(r'```\s*.*?```\s*', '', clean_content, flags=re.DOTALL)
            
            # 移除时间戳标记 [Tue 2026-03-17 14:20 GMT+8]
            clean_content = re.sub(
                r'\[[A-Z][a-z]{2} \d{4}-\d{2}-\d{2} \d{2}:\d{2} GMT\+8\]\s*', 
                '', clean_content
            )
            
            # 移除 message_id 标记
            clean_content = re.sub(r'\[message_id:.*?\]\s*', '', clean_content)
            
            # 移除 System 指令（多行）
            clean_content = re.sub(r'\[System:.*?\]', '', clean_content, flags=re.DOTALL)
            
            # 移除用户名前缀 (如 "叶骥: "，匹配到第一个冒号)
            clean_content = re.sub(r'^[^:\n]+:\s*', '', clean_content)
            
            # 移除多余空白和换行
            clean_content = re.sub(r'\n+', ' ', clean_content)
            clean_content = re.sub(r'\s+', ' ', clean_content).strip()
            
            if clean_content:
                # 截断到指定长度
                if len(clean_content) > max_len:
                    return clean_content[:max_len] + '...'
                return clean_content
    return "对话记录"


def generate_topic_hash(messages: list) -> str:
    """生成话题哈希，用于检测对话是否变化"""
    content = ''.join([f"{role}:{content[:100]}" for entry_id, role, content, ts, is_tool in messages[:3]])
    return hashlib.md5(content.encode()).hexdigest()[:8]


def format_messages_as_markdown(messages: list, date_str: str, time_str: str) -> str:
    """将消息格式化为 Markdown"""
    lines = [f"## {date_str} {time_str}", ""]
    
    for entry_id, role, content, ts, is_tool in messages:
        if is_tool:
            # 工具结果，缩进显示
            lines.append(f"```\n{content}\n```")
            lines.append("")
        elif role == 'user':
            # 清理 metadata（使用与 detect_topic 相同的清理逻辑）
            clean_content = content
            
            # 移除 Conversation info 和 Sender metadata 块
            clean_content = re.sub(
                r'Conversation info \(untrusted metadata\):\s*```json\s*.*?```\s*', 
                '', clean_content, flags=re.DOTALL
            )
            clean_content = re.sub(
                r'Sender \(untrusted metadata\):\s*```json\s*.*?```\s*', 
                '', clean_content, flags=re.DOTALL
            )
            
            # 移除单独的代码块
            clean_content = re.sub(r'```json\s*.*?```\s*', '', clean_content, flags=re.DOTALL)
            clean_content = re.sub(r'```\s*.*?```\s*', '', clean_content, flags=re.DOTALL)
            
            # 移除时间戳和标记
            clean_content = re.sub(r'\[[A-Z][a-z]{2} \d{4}-\d{2}-\d{2} \d{2}:\d{2} GMT\+8\]\s*', '', clean_content)
            clean_content = re.sub(r'\[message_id:.*?\]\s*', '', clean_content)
            clean_content = re.sub(r'\[System:.*?\]', '', clean_content, flags=re.DOTALL)
            
            # 移除用户名前缀
            clean_content = re.sub(r'^[^:\n]+:\s*', '', clean_content)
            
            # 清理空白
            clean_content = clean_content.strip()
            
            lines.append(f"**用户：**")
            lines.append(clean_content)
            lines.append("")
        elif role == 'assistant':
            lines.append(f"**代理：**")
            lines.append(content)
            lines.append("")
    
    return '\n'.join(lines)


def save_dialog_to_markdown(
    messages: list,
    output_dir: Path,
    agent_name: str,
    agent_host: str,
    topic: str = None,
    project: str = None,
    tags: list = None,
    session_id: str = None
) -> Path:
    """保存对话到 Markdown 文件"""
    
    if not messages:
        return None
    
    # 检测话题
    if topic is None:
        topic = detect_topic(messages)
    
    # 获取时间
    dt = get_shanghai_time()
    date_short = format_date_short(dt)
    date_long = format_date_long(dt)
    time_str = format_time(dt)
    timestamp = format_timestamp(dt)
    iso_time = format_iso_time(dt)
    
    # 清理话题作为文件名
    topic_clean = sanitize_filename(topic, max_len=30)
    
    # 构建目录路径
    agent_dir = output_dir / f"{agent_name}@{agent_host}"
    date_dir = agent_dir / date_short
    
    if project:
        date_dir = date_dir / sanitize_filename(project)
    
    date_dir.mkdir(parents=True, exist_ok=True)
    
    # 构建文件路径 - 使用 session_id 确保唯一性
    if session_id:
        unique_id = session_id[:8]
    else:
        unique_id = hashlib.md5(f"{timestamp}{topic}".encode()).hexdigest()[:6]
    
    filename = f"{timestamp}+{topic_clean}_{unique_id}.md"
    filepath = date_dir / filename
    
    # 格式化消息
    content_md = format_messages_as_markdown(messages, date_long, time_str)
    
    # 格式化标签
    if tags is None:
        tags = ["对话"]
    tags_str = ', '.join([f'"{tag}"' for tag in tags])
    
    # 构建文件内容
    frontmatter = f"""---
date: {date_long}
time: {time_str}
agent: {agent_name}
host: {agent_host}
topic: {topic}
project: {project or 'null'}
tags: [{tags_str}]
created: {iso_time}
updated: {iso_time}
---

# {topic}

"""
    
    full_content = frontmatter + content_md
    
    # 写入文件
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(full_content)
    
    return filepath


def get_active_sessions(sessions_file: Path = DEFAULT_SESSIONS_PATH / "sessions.json") -> list:
    """获取活跃的 session 列表"""
    if not sessions_file.exists():
        return []
    
    with open(sessions_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    sessions = []
    for session_key, session_data in data.items():
        if session_key.startswith('agent:main:'):
            session_id = session_data.get('sessionId')
            session_file_path = session_data.get('sessionFile')
            updated_at = session_data.get('updatedAt')
            
            if session_id:
                sessions.append({
                    'key': session_key,
                    'id': session_id,
                    'file': session_file_path,
                    'updated_at': updated_at
                })
    
    # 按更新时间排序，最新的在前
    sessions.sort(key=lambda x: x.get('updated_at', 0) or 0, reverse=True)
    
    return sessions


def get_session_file_path(session_id: str) -> Path:
    """获取 session 文件路径"""
    return DEFAULT_SESSIONS_PATH / f"{session_id}.jsonl"


def run_auto_save(
    config: dict = None,
    state: dict = None,
    save_state_after: bool = True
) -> list:
    """
    运行自动保存
    
    返回: [保存的文件路径, ...]
    """
    if config is None:
        config = load_config()
    
    if state is None:
        state = load_state()
    
    # 检查配置
    save_mode = config.get('saveMode', 'manual')
    if save_mode != 'auto':
        return []
    
    obsidian_root = config.get('obsidianRoot')
    if not obsidian_root:
        print("Error: obsidianRoot not configured", file=sys.stderr)
        return []
    
    agent_name = config.get('agent', {}).get('name', 'Assistant')
    agent_host = config.get('agent', {}).get('host', 'localhost')
    
    output_dir = Path(obsidian_root)
    
    # 获取活跃 sessions
    sessions = get_active_sessions()
    if not sessions:
        return []
    
    saved_files = []
    processed_sessions = state.get('sessions', {})
    
    for session in sessions:
        session_id = session['id']
        session_file = session.get('file')
        
        if not session_file:
            session_file = str(get_session_file_path(session_id))
        
        session_path = Path(session_file)
        if not session_path.exists():
            continue
        
        # 获取上次处理的 entry id
        last_entry_id = processed_sessions.get(session_id, {}).get('last_entry_id')
        
        # 解析新消息
        messages = parse_session_file(session_path, last_entry_id)
        
        if not messages:
            continue
        
        # 检查消息数量，太少可能只是单条消息
        user_messages = [m for m in messages if m[1] == 'user']
        assistant_messages = [m for m in messages if m[1] == 'assistant']
        
        # 只有当有用户和助手消息时才保存
        if not user_messages or not assistant_messages:
            # 只更新状态，不保存
            processed_sessions[session_id] = {
                'last_entry_id': messages[-1][0] if messages else last_entry_id,
                'updated_at': format_iso_time()
            }
            continue
        
        # 保存对话
        saved_path = save_dialog_to_markdown(
            messages=messages,
            output_dir=output_dir,
            agent_name=agent_name,
            agent_host=agent_host,
            session_id=session_id
        )
        
        if saved_path:
            saved_files.append(str(saved_path))
            print(f"Saved: {saved_path}")
            
            # 更新状态
            processed_sessions[session_id] = {
                'last_entry_id': messages[-1][0],
                'updated_at': format_iso_time(),
                'last_saved_file': str(saved_path)
            }
    
    # 保存状态
    if save_state_after:
        state['sessions'] = processed_sessions
        state['last_run'] = format_iso_time()
        save_state(state)
    
    return saved_files


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='OpenClaw Session Parser')
    parser.add_argument('--auto', action='store_true', help='运行自动保存')
    parser.add_argument('--session', type=str, help='指定 session ID')
    parser.add_argument('--session-file', type=str, help='指定 session 文件路径')
    parser.add_argument('--output', type=str, help='输出目录')
    parser.add_argument('--topic', type=str, help='话题标题')
    parser.add_argument('--all', action='store_true', help='处理所有未保存的消息')
    parser.add_argument('--reset', action='store_true', help='重置状态，重新处理所有消息')
    
    args = parser.parse_args()
    
    config = load_config()
    state = load_state()
    
    if args.reset:
        state = {'sessions': {}}
        save_state(state)
        print("State reset complete")
        return
    
    if args.auto:
        saved = run_auto_save(config, state)
        if saved:
            print(f"\nSaved {len(saved)} file(s)")
        else:
            print("No new messages to save")
        return
    
    if args.session_file:
        session_file = Path(args.session_file)
        messages = parse_session_file(session_file)
        
        if not messages:
            print("No messages found")
            return
        
        # 打印消息
        for entry_id, role, content, ts, is_tool in messages:
            print(f"\n--- {role} ({ts}) ---")
            print(content[:200] + ('...' if len(content) > 200 else ''))
        return
    
    if args.session:
        session_file = get_session_file_path(args.session)
        messages = parse_session_file(session_file)
        
        if not messages:
            print("No messages found")
            return
        
        # 使用配置的输出目录
        output_dir = Path(config.get('obsidianRoot', '.'))
        agent_name = config.get('agent', {}).get('name', 'Assistant')
        agent_host = config.get('agent', {}).get('name', 'localhost')
        
        saved_path = save_dialog_to_markdown(
            messages=messages,
            output_dir=output_dir,
            agent_name=agent_name,
            agent_host=agent_host,
            topic=args.topic
        )
        
        if saved_path:
            print(f"Saved: {saved_path}")
        return
    
    # 默认：打印帮助
    parser.print_help()


if __name__ == '__main__':
    main()