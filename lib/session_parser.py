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
    """
    从 content 数组中提取文本
    注意：跳过 toolCall 和 thinking，只提取纯文本
    """
    if isinstance(content, str):
        return content
    
    if isinstance(content, list):
        texts = []
        for block in content:
            if isinstance(block, dict):
                block_type = block.get('type', '')
                if block_type == 'text':
                    texts.append(block.get('text', ''))
                # 跳过 thinking 和 toolCall，不输出
            elif isinstance(block, str):
                texts.append(block)
        return '\n'.join(texts)
    
    return ''


def parse_session_file(session_file: Path, last_entry_id: str = None) -> list:
    """
    解析 session JSONL 文件
    
    返回: [(entry_id, role, content, timestamp), ...]
    注意：只返回用户消息和助理文字回复，跳过工具调用和结果
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
                
                # 只处理用户和助理的文字消息
                if role == 'user':
                    text = extract_text_content(content)
                    if text:
                        entries.append((entry_id, 'user', text, ts))
                
                elif role == 'assistant':
                    text = extract_text_content(content)
                    if text:
                        entries.append((entry_id, 'assistant', text, ts))
                
                # 完全跳过 toolResult
    
    return entries


def clean_user_message(content: str) -> str:
    """清理用户消息中的 metadata"""
    clean_content = content
    
    # 移除 Conversation info (untrusted metadata) 块
    clean_content = re.sub(
        r'Conversation info \(untrusted metadata\):\s*```json\s*.*?```\s*', 
        '', clean_content, flags=re.DOTALL
    )
    
    # 移除 Sender (untrusted metadata) 块
    clean_content = re.sub(
        r'Sender \(untrusted metadata\):\s*```json\s*.*?```\s*', 
        '', clean_content, flags=re.DOTALL
    )
    
    # 移除单独的代码块
    clean_content = re.sub(r'```json\s*.*?```\s*', '', clean_content, flags=re.DOTALL)
    clean_content = re.sub(r'```\s*.*?```\s*', '', clean_content, flags=re.DOTALL)
    
    # 移除时间戳标记
    clean_content = re.sub(
        r'\[[A-Z][a-z]{2} \d{4}-\d{2}-\d{2} \d{2}:\d{2} GMT\+8\]\s*', 
        '', clean_content
    )
    
    # 移除 message_id 标记
    clean_content = re.sub(r'\[message_id:.*?\]\s*', '', clean_content)
    
    # 移除 System 指令
    clean_content = re.sub(r'\[System:.*?\]', '', clean_content, flags=re.DOTALL)
    
    # 移除用户名前缀
    clean_content = re.sub(r'^[^:\n]+:\s*', '', clean_content)
    
    # 清理空白
    clean_content = clean_content.strip()
    
    return clean_content


def extract_keywords(text: str, max_keywords: int = 2) -> list:
    """
    从文本中提取关键词
    策略：提取核心名词和动作，简洁为主
    """
    # 清理文本
    text = clean_user_message(text)
    
    keywords = []
    
    # 1. 提取冒号后的内容（通常是主题）
    match = re.search(r'[：:]\s*([^\s，。！？,：:\n]{2,8})', text)
    if match:
        kw = match.group(1)
        kw = re.sub(r'^(一个|这个|那个)', '', kw)
        if kw and len(kw) >= 2:
            keywords.append(kw)
    
    # 2. 提取"XX技能/项目/功能"格式
    if len(keywords) < max_keywords:
        match = re.search(r'([^\s，。！？,：:]{2,6})(技能|项目|功能)', text)
        if match:
            kw = match.group(0)
            if kw not in keywords:
                keywords.append(kw)
    
    # 3. 提取动作+对象
    if len(keywords) < max_keywords:
        match = re.search(r'(新建|创建|开发|完善|优化|修复|讨论)([^\s，。！？,：:\n]{2,6})', text)
        if match:
            kw = match.group(1) + match.group(2)
            # 过滤不合适的组合（包含代词或虚词）
            if not re.match(r'.*(一个|这个|那个|与你|与我|的是|的是你|的是我).*', kw):
                if kw not in keywords:
                    keywords.append(kw)
    
    # 4. 提取问题编号
    match = re.search(r'问题\s*(\d+)', text)
    if match:
        kw = '问题' + match.group(1)
        if kw not in keywords:
            if len(keywords) >= max_keywords:
                keywords[-1] = kw
            else:
                keywords.append(kw)
    
    # 5. 过滤掉太短或太抽象的关键词
    keywords = [kw for kw in keywords if len(kw) >= 2 and not re.match(r'^[a-zA-Z0-9]{6,}$', kw)]
    
    # 如果没有匹配到任何关键词，取第一句前10字符
    if not keywords:
        first_sentence = re.split(r'[，。！？,：:\n]', text)[0].strip()
        first_sentence = re.sub(r'^[\d.、\s]+', '', first_sentence)
        if first_sentence:
            if len(first_sentence) > 10:
                first_sentence = first_sentence[:10]
            keywords.append(first_sentence)
    
    return keywords[:max_keywords]


def detect_topic(messages: list, max_len: int = 20) -> str:
    """
    从消息中检测话题
    格式：关键词1-关键词2（简洁）
    """
    for entry_id, role, content, ts in messages:
        if role == 'user':
            keywords = extract_keywords(content)
            
            if keywords:
                topic = '-'.join(keywords)
                if len(topic) > max_len:
                    topic = topic[:max_len]
                return topic
            
            # 如果没提取到关键词，使用清理后的文本第一句
            clean_content = clean_user_message(content)
            if clean_content:
                first_sentence = re.split(r'[，。！？,：:\n]', clean_content)[0].strip()
                first_sentence = re.sub(r'^[\d.、\s]+', '', first_sentence)
                if len(first_sentence) > max_len:
                    first_sentence = first_sentence[:max_len]
                return first_sentence
            
    return "对话记录"


def format_messages_as_markdown(messages: list, date_str: str, time_str: str) -> str:
    """
    将消息格式化为 Markdown
    只输出用户消息和助理文字回复，不输出工具调用
    """
    lines = [f"## {date_str} {time_str}", ""]
    
    for entry_id, role, content, ts in messages:
        if role == 'user':
            # 清理 metadata
            clean_content = clean_user_message(content)
            
            lines.append(f"**用户：**")
            lines.append(clean_content)
            lines.append("")
        elif role == 'assistant':
            lines.append(f"**代理：**")
            lines.append(content)
            lines.append("")
    
    return '\n'.join(lines)


def get_dialog_dir(config: dict) -> Path:
    """
    获取对话保存目录
    支持新的 claw-对话/ 目录结构
    """
    obsidian_root = config.get('obsidianRoot')
    if not obsidian_root:
        return None
    
    # 获取对话目录配置
    dialog_dir_name = config.get('structure', {}).get('dialogDir', 'claw-对话')
    agent_name = config.get('agent', {}).get('name', 'Assistant')
    agent_host = config.get('agent', {}).get('host', 'localhost')
    
    output_dir = Path(obsidian_root)
    
    # 检查新结构是否存在
    new_dialog_dir = output_dir / dialog_dir_name / f"{agent_name}@{agent_host}"
    old_dialog_dir = output_dir / f"{agent_name}@{agent_host}"
    
    if new_dialog_dir.exists() or (output_dir / dialog_dir_name).exists():
        return output_dir / dialog_dir_name
    elif old_dialog_dir.exists():
        return output_dir
    else:
        # 默认使用新结构
        return output_dir / dialog_dir_name


def save_dialog_to_markdown(
    messages: list,
    output_dir: Path,
    agent_name: str,
    agent_host: str,
    topic: str = None,
    project: str = None,
    tags: list = None,
    config: dict = None
) -> Path:
    """
    保存对话到 Markdown 文件
    文件名格式：YYMMDDHHMM+话题.md
    
    支持新的目录结构：claw-对话/代理名@主机名/YYMMDD/
    """
    
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
    
    # 构建目录路径 - 支持新的 claw-对话/ 结构
    if config:
        dialog_base = get_dialog_dir(config)
        if dialog_base:
            agent_dir = dialog_base / f"{agent_name}@{agent_host}"
        else:
            agent_dir = output_dir / f"{agent_name}@{agent_host}"
    else:
        # 检查是否存在 claw-对话 目录
        dialog_dir_name = "claw-对话"
        if (output_dir / dialog_dir_name).exists():
            agent_dir = output_dir / dialog_dir_name / f"{agent_name}@{agent_host}"
        else:
            agent_dir = output_dir / f"{agent_name}@{agent_host}"
    
    date_dir = agent_dir / date_short
    
    if project:
        date_dir = date_dir / sanitize_filename(project)
    
    date_dir.mkdir(parents=True, exist_ok=True)
    
    # 文件名：YYMMDDHHMM+话题.md
    filename = f"{timestamp}+{topic_clean}.md"
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
        
        # 检查消息数量
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
            agent_host=agent_host
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


# ==================== 项目保存功能 ====================

def get_project_dir(output_dir: Path, agent_name: str, agent_host: str, project_name: str) -> Path:
    """
    获取项目目录路径
    格式：{agent}@{host}/{YYMMDD}/项目-{项目名}
    """
    date_short = format_date_short()
    agent_dir = output_dir / f"{agent_name}@{agent_host}"
    project_dir = agent_dir / date_short / f"项目-{project_name}"
    return project_dir


def get_next_version(project_dir: Path, topic: str) -> int:
    """
    获取下一个版本号
    检查目录中已有的文件，确定版本号
    """
    if not project_dir.exists():
        return 1
    
    # 查找匹配的文件
    max_version = 0
    pattern = re.compile(rf'^{re.escape(topic)}-v(\d+)\.md$')
    
    for f in project_dir.iterdir():
        if f.is_file() and f.suffix == '.md':
            match = pattern.match(f.name)
            if match:
                version = int(match.group(1))
                if version > max_version:
                    max_version = version
    
    return max_version + 1


def save_project_content(
    content: str,
    output_dir: Path,
    agent_name: str,
    agent_host: str,
    project_name: str,
    topic: str,
    version: int = None,
    tags: list = None
) -> Path:
    """
    保存项目成果到项目文件夹
    
    参数：
        content: 内容（Markdown格式）
        output_dir: Obsidian 根目录
        agent_name: 代理名称
        agent_host: 主机名称
        project_name: 项目名称
        topic: 主题
        version: 版本号（None 则自动递增）
        tags: 标签列表
    
    返回：
        保存的文件路径
    """
    # 获取项目目录
    project_dir = get_project_dir(output_dir, agent_name, agent_host, project_name)
    project_dir.mkdir(parents=True, exist_ok=True)
    
    # 清理主题作为文件名
    topic_clean = sanitize_filename(topic, max_len=30)
    
    # 确定版本号
    if version is None:
        version = get_next_version(project_dir, topic_clean)
    
    # 构建文件名
    filename = f"{topic_clean}-v{version}.md"
    filepath = project_dir / filename
    
    # 获取时间
    dt = get_shanghai_time()
    date_long = format_date_long(dt)
    time_str = format_time(dt)
    iso_time = format_iso_time(dt)
    
    # 格式化标签
    if tags is None:
        tags = ["项目成果", project_name]
    tags_str = ', '.join([f'"{tag}"' for tag in tags])
    
    # 构建 frontmatter
    frontmatter = f"""---
date: {date_long}
time: {time_str}
agent: {agent_name}
host: {agent_host}
project: {project_name}
topic: {topic}
version: v{version}
tags: [{tags_str}]
created: {iso_time}
updated: {iso_time}
type: project
---

# {topic} (v{version})

"""
    
    full_content = frontmatter + content
    
    # 写入文件
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(full_content)
    
    return filepath


def list_projects(
    output_dir: Path,
    agent_name: str,
    agent_host: str
) -> list:
    """
    列出所有项目
    """
    agent_dir = output_dir / f"{agent_name}@{agent_host}"
    projects = []
    
    if not agent_dir.exists():
        return projects
    
    # 遍历日期目录
    for date_dir in agent_dir.iterdir():
        if not date_dir.is_dir():
            continue
        
        # 遍历项目目录
        for project_dir in date_dir.iterdir():
            if project_dir.is_dir() and project_dir.name.startswith('项目-'):
                project_name = project_dir.name[3:]  # 去掉"项目-"前缀
                # 统计文件数
                file_count = len(list(project_dir.glob('*.md')))
                projects.append({
                    'name': project_name,
                    'path': str(project_dir),
                    'date': date_dir.name,
                    'files': file_count
                })
    
    return projects


def list_project_versions(
    output_dir: Path,
    agent_name: str,
    agent_host: str,
    project_name: str
) -> list:
    """
    列出项目的所有版本
    """
    project_dir = get_project_dir(output_dir, agent_name, agent_host, project_name)
    
    if not project_dir.exists():
        return []
    
    versions = []
    for f in sorted(project_dir.glob('*.md')):
        # 解析文件名
        match = re.match(r'^(.+)-v(\d+)\.md$', f.name)
        if match:
            versions.append({
                'topic': match.group(1),
                'version': int(match.group(2)),
                'path': str(f),
                'size': f.stat().st_size,
                'modified': datetime.fromtimestamp(f.stat().st_mtime, tz=SHANGHAI_TZ).strftime('%Y-%m-%d %H:%M')
            })
    
    return versions


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='OpenClaw Session Parser')
    
    # 对话保存
    parser.add_argument('--auto', action='store_true', help='运行自动保存')
    parser.add_argument('--session', type=str, help='指定 session ID')
    parser.add_argument('--session-file', type=str, help='指定 session 文件路径')
    parser.add_argument('--output', type=str, help='输出目录')
    parser.add_argument('--topic', type=str, help='话题标题')
    parser.add_argument('--reset', action='store_true', help='重置状态')
    
    # 项目保存
    parser.add_argument('--project-save', action='store_true', help='保存项目成果')
    parser.add_argument('--project-name', type=str, help='项目名称')
    parser.add_argument('--project-topic', type=str, help='项目主题')
    parser.add_argument('--project-version', type=int, help='版本号')
    parser.add_argument('--project-content', type=str, help='项目内容（或从 stdin 读取）')
    parser.add_argument('--project-list', action='store_true', help='列出所有项目')
    parser.add_argument('--project-versions', type=str, help='列出项目的所有版本')
    
    args = parser.parse_args()
    
    config = load_config()
    state = load_state()
    
    # 重置状态
    if args.reset:
        state = {'sessions': {}}
        save_state(state)
        print("State reset complete")
        return
    
    # 列出项目
    if args.project_list:
        output_dir = Path(config.get('obsidianRoot', '.'))
        agent_name = config.get('agent', {}).get('name', 'Assistant')
        agent_host = config.get('agent', {}).get('host', 'localhost')
        
        projects = list_projects(output_dir, agent_name, agent_host)
        if projects:
            print(f"找到 {len(projects)} 个项目:")
            for p in projects:
                print(f"  - {p['name']} ({p['date']}, {p['files']} 个文件)")
        else:
            print("暂无项目")
        return
    
    # 列出项目版本
    if args.project_versions:
        output_dir = Path(config.get('obsidianRoot', '.'))
        agent_name = config.get('agent', {}).get('name', 'Assistant')
        agent_host = config.get('agent', {}).get('host', 'localhost')
        
        versions = list_project_versions(output_dir, agent_name, agent_host, args.project_versions)
        if versions:
            print(f"项目 '{args.project_versions}' 的版本:")
            for v in versions:
                print(f"  - v{v['version']}: {v['topic']} ({v['modified']})")
        else:
            print(f"项目 '{args.project_versions}' 暂无版本")
        return
    
    # 保存项目成果
    if args.project_save:
        if not args.project_name or not args.project_topic:
            print("错误: 需要指定 --project-name 和 --project-topic", file=sys.stderr)
            return
        
        output_dir = Path(config.get('obsidianRoot', '.'))
        agent_name = config.get('agent', {}).get('name', 'Assistant')
        agent_host = config.get('agent', {}).get('host', 'localhost')
        
        # 获取内容
        if args.project_content:
            content = args.project_content
        elif not sys.stdin.isatty():
            content = sys.stdin.read()
        else:
            print("错误: 请通过 --project-content 或 stdin 提供内容", file=sys.stderr)
            return
        
        saved_path = save_project_content(
            content=content,
            output_dir=output_dir,
            agent_name=agent_name,
            agent_host=agent_host,
            project_name=args.project_name,
            topic=args.project_topic,
            version=args.project_version
        )
        
        print(f"Saved: {saved_path}")
        return
    
    # 自动保存对话
    if args.auto:
        saved = run_auto_save(config, state)
        if saved:
            print(f"\nSaved {len(saved)} file(s)")
        else:
            print("No new messages to save")
        return
    
    # 查看指定 session
    if args.session_file:
        session_file = Path(args.session_file)
        messages = parse_session_file(session_file)
        
        if not messages:
            print("No messages found")
            return
        
        for entry_id, role, content, ts in messages:
            print(f"\n--- {role} ({ts}) ---")
            print(content[:200] + ('...' if len(content) > 200 else ''))
        return
    
    # 默认：打印帮助
    parser.print_help()


if __name__ == '__main__':
    main()