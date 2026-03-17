# dialog-save 技能

将 OpenClaw 对话自动保存为 Markdown 文件，支持 Obsidian 笔记记库查看和 iCloud 同步。

## 一键安装/升级

```bash
bash <(curl -sL https://raw.githubusercontent.com/firebird2003/dialog-save/main/install.sh)
```

- **未安装**：自动克隆并进入配置菜单
- **已安装**：询问是更新还是重新安装
- 不会因目录已存在、缺少依赖等问题中断

## 功能特点

- **实际对话保存**：解析 OpenClaw session 文件，保存真实对话内容
- **自动监控**：定时检测新对话，自动保存
- **增量保存**：追踪已处理的对话，避免重复
- **智能话题检测**：自动从对话中提取主题作为文件名
- **Metadata 清理**：自动移除 Sender/Conversation info 等元数据
- **iCloud 兼容**：目录结构兼容 iCloud/Obsidian 同步

## 目录结构

```
Obsidian笔记库/                      # 主目录
├── 管理者@yejimaca2141/             # 代理名@主机名
│   └── 260317/                      # YYMMDD
│       ├── 2603171457+测试新建会话_abc12345.md
│       └── 2603171500+对话保存技能配置_def67890.md
└── 其他笔记.md
```

**文件名格式**：`YYMMDDHHMM+话题_sessionId前8位.md`

## 保存机制

### 自动模式（推荐）
- 自动监控并保存所有对话
- 增量保存，避免重复
- 无需用户提示

### 手动模式
- 需要说"存入本地目录"或"保存对话"才保存
- 适合选择性保存

## 使用方法

### 交互菜单

```bash
bash ~/.openclaw/workspace/skills/dialog-save/scripts/manage.sh
```

### 命令行

```bash
bash scripts/manage.sh install      # 安装/重新安装
bash scripts/manage.sh config       # 修改配置
bash scripts/manage.sh start        # 启动服务
bash scripts/manage.sh stop         # 停止服务
bash scripts/manage.sh status       # 查看状态
bash scripts/manage.sh save-now     # 立即保存
bash scripts/manage.sh saved        # 查看已保存
bash scripts/manage.sh update       # 检查更新
bash scripts/manage.sh uninstall    # 卸载
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
  "version": "2.1.0",
  "obsidianRoot": "/path/to/obsidian/vault",
  "webdav": {
    "enabled": true,
    "port": 8080
  },
  "agent": {
    "name": "管理者",
    "host": "yejimaca2141"
  },
  "saveMode": "auto",
  "mode": "local",
  "autoStart": true
}
```

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
- 时间戳标记
- System 指令

## iCloud 兼容说明

- 目录名使用 `@` 符号分隔（如 `管理者@yejimaca2141`）
- 与现有 iCloud 同步结构兼容

## 更新日志

### v2.1.0 (2026-03-17)
- 改进安装体验：单行命令支持安装/升级
- 智能处理目录已存在的情况
- 依赖问题不会中断流程，仅警告

### v2.0.0 (2026-03-17)
- 新增实际对话保存功能：解析 OpenClaw session 文件
- 自动保存模式：定时监控并保存新对话
- 增量保存：追踪已处理的对话，避免重复
- 智能话题检测：自动从对话中提取主题