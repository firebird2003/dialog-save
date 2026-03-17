# dialog-save 技能

将 OpenClaw 对话自动保存为 Markdown 文件，支持 Obsidian 笔记库查看和 iCloud 同步。

## 功能特点

- **自动保存**：监控 OpenClaw session 文件，自动保存新对话
- **增量保存**：追踪已处理的对话，避免重复保存
- **智能话题检测**：自动从对话中提取主题作为文件名
- **Metadata 清理**：自动移除 Sender/Conversation info 等元数据
- **多平台支持**：macOS (iCloud)、Linux 均可使用

## 目录结构

```
Obsidian笔记库/                      # 主目录
├── 管理者@yejimaca2141/             # 代理名@主机名（兼容iCloud同步）
│   └── 260317/                      # YYMMDD
│       ├── 2603171457+测试新建会话_abc12345.md
│       └── 2603171500+对话保存技能配置_def67890.md
└── 其他笔记.md
```

**目录名格式**：`代理名@主机名`（使用 `@` 符号分隔，兼容 iCloud/Obsidian 同步）

**文件名格式**：`YYMMDDHHMM+话题_sessionId前8位.md`

## 保存机制

### 自动模式（saveMode: auto）
- 自动监控并保存所有对话
- 无需用户提示
- 适合需要完整记录的场景
- 增量保存，避免重复

### 手动模式（saveMode: manual）
- 需要用户说"存入本地目录"或"保存对话"才保存
- 适合选择性保存的场景

## 安装

```bash
cd ~/.openclaw/workspace/skills
git clone https://github.com/your-repo/dialog-save.git
cd dialog-save
bash scripts/manage.sh install
```

## 使用方法

### 命令行

```bash
# 安装/重新安装
bash scripts/manage.sh install

# 修改配置
bash scripts/manage.sh config

# 启动服务（WebDAV + 自动监控）
bash scripts/manage.sh start

# 停止服务
bash scripts/manage.sh stop

# 查看状态
bash scripts/manage.sh status

# 立即保存对话
bash scripts/manage.sh save-now

# 查看已保存的对话
bash scripts/manage.sh saved

# 重置保存状态（下次会重新处理所有对话）
bash scripts/manage.sh reset-state

# 检查更新
bash scripts/manage.sh update
```

### Python API

```python
from lib.session_parser import run_auto_save, save_dialog_to_markdown

# 运行自动保存
saved_files = run_auto_save()

# 手动保存特定 session
from pathlib import Path
messages = parse_session_file(Path("/path/to/session.jsonl"))
save_dialog_to_markdown(
    messages=messages,
    output_dir=Path("/path/to/obsidian/vault"),
    agent_name="管理者",
    agent_host="localhost",
    topic="自定义话题"
)
```

## 文件格式

```markdown
---
date: 2026-03-17
time: 14:57
agent: 管理者
host: yejimaca2141
topic: 测试新建会话
project: null
tags: ["对话"]
created: 2026-03-17T14:57:45+08:00
updated: 2026-03-17T14:57:45+08:00
---

# 测试新建会话

## 2026-03-17 14:57

**用户：**
测试新建会话

**代理：**
你好！我看到你在测试新会话。
```

## 时间处理

- 永远使用上海时间（GMT+8）
- 不使用 UTC

## 配置文件

```json
{
  "version": "2.0.0",
  "obsidianRoot": "/path/to/obsidian/vault",
  "webdav": {
    "enabled": true,
    "port": 8080,
    "host": "0.0.0.0"
  },
  "agent": {
    "name": "管理者",
    "host": "yejimaca2141"
  },
  "sync": {
    "retryIntervalMinutes": 1,
    "maxRetries": 3,
    "cacheDir": ".cache/pending"
  },
  "saveMode": "auto",
  "mode": "local",
  "remoteWebdavUrl": "",
  "autoStart": true
}
```

## 修改配置

运行配置脚本修改设置：

```bash
cd ~/.openclaw/workspace/skills/dialog-save && bash scripts/manage.sh config
```

或进入交互菜单选择"修改配置"。

## iCloud 兼容说明

- 目录名使用 `@` 符号分隔（如 `管理者@yejimaca2141`）
- 避免使用中间子目录
- 与现有 iCloud 同步结构兼容
- 防止同步冲突导致目录消失

## 技术细节

### Session 文件位置
- OpenClaw session 文件存储在 `~/.openclaw/agents/main/sessions/*.jsonl`
- 技能监控 `sessions.json` 获取活跃 session 列表
- 解析 JSONL 文件提取对话内容

### 增量保存
- 状态文件：`.cache/save_state.json`
- 记录每个 session 最后处理的 entry_id
- 下次运行时只处理新增的条目

### Metadata 清理
自动移除以下内容：
- `Conversation info (untrusted metadata)` 块
- `Sender (untrusted metadata)` 块
- JSON 代码块
- 时间戳标记 `[Tue 2026-03-17 14:20 GMT+8]`
- System 指令
- 用户名前缀

## 更新日志

### v2.0.0 (2026-03-17)
- 新增实际对话保存功能：解析 OpenClaw session 文件
- 自动保存模式：定时监控并保存新对话
- 增量保存：追踪已处理的对话，避免重复
- 智能话题检测：自动从对话中提取主题
- Metadata 清理：移除 Sender/Conversation info 等元数据

### v1.3.0 (2026-03-16)
- 目录名格式改为 代理名@主机名（兼容iCloud同步）
- 新增保存机制选项：自动/手动